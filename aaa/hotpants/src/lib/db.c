/*
* Copyright (c) 2005-2010, Vonage Holdings Corp.
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
*     * Redistributions of source code must retain the above copyright
*       notice, this list of conditions and the following disclaimer.
*     * Redistributions in binary form must reproduce the above copyright
*       notice, this list of conditions and the following disclaimer in the
*       documentation and/or other materials provided with the distribution.
*
* THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
* EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
* DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
* LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
* ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
/*
 * $Id$
 *
 * Database access routines for HOTPants
 *
 */

#include <hotpants_internals.h>

int __hpdb_open __P((HOTPants_DB *));
void __hpdb_close __P((HOTPants_DB *));
char *__hpdb_error __P((HOTPants_DB *));
int __fetch_config_param_from_db __P((HOTPants_DB *, char *, HPData *));

/*
 * initialize_HPdb_context
 *
 * initializes an hpdb context to call methods and store state
 */

HOTPants_DB *
initialize_HPdb_context(char *path)
{
	HOTPants_DB *hdb;

	if (!path) {
		return (HOTPants_DB *) NULL;
	}
	if ((hdb = (HOTPants_DB *) malloc(sizeof(HOTPants_DB))) == NULL) {
		return NULL;
	}
	memset(hdb, 0, sizeof(HOTPants_DB));

	/*
	 * Save path to environment
	 */

	strncpy(hdb->__dbpath, path, sizeof(hdb->__dbpath));

	hdb->open = __hpdb_open;
	hdb->close = __hpdb_close;
	hdb->error = __hpdb_error;
	hdb->get_config_param = __fetch_config_param_from_db;
	hdb->config_opaque = NULL;
	hdb->error_file = "db_error.log";

	return hdb;
}

/*
 * opendb(char *path) - open database files
 *
 * Arguments -
 *
 * char *path - directory containing database files
 */

int
__hpdb_open(HOTPants_DB * hdb)
{
	DB_ENV *Env;
	DB *user_db;
	DB *token_db;
	DB *config_db;
	DB_TXN *txn;

	int ret;
	char *errfn;
	FILE *errfile;

	/* If we have an environment, we need to get it destroyed */

	if (hdb->Env) {
		__hpdb_close(hdb);
	}
	if (!hdb->__dbpath) {
		return EINVAL;
	}
	/* Create a database environment object */

	ret = db_env_create(&Env, 0);
	if (ret != 0) {
		strcpy(hdb->__errmsg, "Unable to create DB environment");
		return -1;
	}
	/* Set error file handle */

	if (hdb->error_file) {
		if ((errfn = (char *) malloc(strlen(hdb->error_file) +
			    strlen(hdb->__dbpath) + 2)) == NULL) {
			return NULL;
		}
		sprintf(errfn, "%s/%s", hdb->__dbpath, hdb->error_file);
		if ((errfile = fopen(errfn, "a")) != NULL) {
			Env->set_errfile(Env, errfile);
			Env->set_msgfile(Env, errfile);
		}
	}
	ret = Env->set_lk_detect(Env, DB_LOCK_MINWRITE);
	if (ret) {
		snprintf(hdb->__errmsg, sizeof(hdb->__errmsg),
		    "Error setting lock detect: %s", db_strerror(ret));
		return -1;
	}
	/* Open the environment */

	ret = Env->open(Env, hdb->__dbpath,
	    DB_CREATE |		/* Create database if it doesn't exist */
	    DB_INIT_MPOOL |	/* Create in-memory cache */
	    DB_INIT_LOCK |	/* Initialize the locking subystem */
	    DB_INIT_LOG |	/* Initialize the database logging subystem */
	    DB_INIT_TXN |	/* Initialize the transation subsystem */
#ifdef DB_REGISTER
	    DB_REGISTER |	/* Register ourselves with the environment */
#endif
	    DB_THREAD |		/* Make thread-safe	 */
	    DB_RECOVER		/* Recover the database if necessary */
	    ,0600
	    );

	if (ret != 0) {
		sprintf(hdb->__errmsg, "Unable to open DB environment at %s",
		    hdb->__dbpath);
		fclose(errfile);
		return -1;
	}
	hdb->Env = Env;

	ret = Env->txn_begin(Env, (DB_TXN *) NULL, &txn, 0);
	if (ret != 0) {
		strcpy(hdb->__errmsg, "db_create() failed creating transaction to open databases");
		__hpdb_close(hdb);
		return -1;
	}
	ret = db_create(&user_db, Env, 0);
	if (ret != 0) {
		strcpy(hdb->__errmsg, "db_create() failed creating user_db");
		__hpdb_close(hdb);
		return -1;
	}
	hdb->user_db = user_db;

	ret = user_db->open(
	    user_db,
	    txn,		/* transaction ID */
	    __HOTPANTS_USER_DB_NAME,	/* Name of user database */
	    NULL,		/* No logical db name */
	    DB_HASH,		/* Create as a hash db */
	    DB_CREATE,		/* create the db and use transactions */
	    0);			/* default file mode */
	if (ret != 0) {
		sprintf(hdb->__errmsg, "Unable to open user database %s",
		    __HOTPANTS_USER_DB_NAME);
		txn->abort(txn);
		__hpdb_close(hdb);
		return -1;
	}
	ret = db_create(&token_db, Env, 0);
	if (ret != 0) {
		strcpy(hdb->__errmsg, "db_create() failed creating token_db");
		__hpdb_close(hdb);
		return -1;
	}
	hdb->token_db = token_db;

	ret = token_db->open(
	    token_db,
	    txn,		/* No transaction ID */
	    __HOTPANTS_TOKEN_DB_NAME,	/* Name of token database */
	    NULL,		/* No logical db name */
	    DB_HASH,		/* Create as a hash db */
	    DB_CREATE,		/* create the db and use transactions */
	    0);			/* default file mode */

	if (ret != 0) {
		sprintf(hdb->__errmsg, "Unable to open token database %s",
		    __HOTPANTS_TOKEN_DB_NAME);
		txn->abort(txn);
		__hpdb_close(hdb);
		return -1;
	}
	ret = db_create(&config_db, Env, 0);
	if (ret != 0) {
		strcpy(hdb->__errmsg, "db_create() failed creating config_db");
		__hpdb_close(hdb);
		return -1;
	}
	hdb->config_db = config_db;

	ret = config_db->open(
	    config_db,
	    txn,		/* No transaction ID */
	    __HOTPANTS_CONFIG_DB_NAME,	/* Name of token database */
	    NULL,		/* No logical db name */
	    DB_HASH,		/* Create as a hash db */
	    DB_CREATE,		/* create the db and use transactions */
	    0);			/* default file mode */

	if (ret != 0) {
		sprintf(hdb->__errmsg, "Unable to open config database %s",
		    __HOTPANTS_CONFIG_DB_NAME);
		txn->abort(txn);
		__hpdb_close(hdb);
		return -1;
	}
	txn->commit(txn, 0);

	return 0;
}

void
__hpdb_close(HOTPants_DB * hdb)
{
	FILE *errfile = NULL;

	if (!hdb)
		return;
	if (!hdb->Env)
		return;
	if (hdb->user_db) {
		hdb->user_db->close(hdb->user_db, 0);
	}
	if (hdb->token_db) {
		hdb->token_db->close(hdb->token_db, 0);
	}
	if (hdb->config_db) {
		hdb->config_db->close(hdb->config_db, 0);
	}
	/* close the error file if it's open */


	hdb->Env->get_errfile(hdb->Env, &errfile);
	if (errfile != NULL) {
		fclose(errfile);
	}
	hdb->Env->close(hdb->Env, 0);
	hdb->Env = (DB_ENV *) NULL;
	hdb->user_db = (DB *) NULL;
	hdb->token_db = (DB *) NULL;
	hdb->config_db = (DB *) NULL;
}

char *
__hpdb_error(HOTPants_DB * hdb)
{
	return (hdb == NULL) ? NULL : hdb->__errmsg;
}


/*
 * fetch_token_from_db
 *		fetch the token with given tokenid from the open BDB handle stored
 *		in hdb->token_db and storing the pointer to it in tokptr.  If an
 *		explicit txnid is given, it is assumed that this is a fetch for a
 *		read/modify/write cycle and the BDB flag is set as such.
 *
 *		Returns 0 on success.
 *
 *		Returns EINVAL if a NULL BDB handle is passed, ENOMEM on memory
 *		allocation errors, or whatever is returned by the db->get call.
 *
 */
int
fetch_token_from_db(HOTPants_DB * hdb, u_int32_t tokenid,
    void *txn, Token ** tokptr)
{

	DBT key, data;
	int ret;
	HPData tokdata;
	u_int32_t flags = 0;
	DB_TXN *txnid;

	txnid = (DB_TXN *) txn;
	memset(&key, 0, sizeof(DBT));
	memset(&data, 0, sizeof(DBT));

	if (!hdb || !hdb->token_db) {
		tokptr = (Token **) NULL;
		return EINVAL;
	}
	/* tokenid needs to be in network byte order */

	tokenid = htonl(tokenid);
	key.data = &tokenid;
	key.size = sizeof(unsigned int);
	data.flags = DB_DBT_MALLOC;

	if (txnid) {
		flags = DB_RMW;
	}
	ret = hdb->token_db->get(hdb->token_db, txnid, &key, &data, flags);
	if (!ret) {
		tokdata.data = data.data;
		tokdata.size = data.size;
		if ((*tokptr = deserialize_token(&tokdata)) == (Token *) NULL) {
			free(data.data);
			return ENOMEM;
		}
		free(data.data);
	} else {
		tokptr = (Token **) NULL;
	}
	return ret;
}

/*
 * fetch_user_from_db
 *		fetch the token with given login from the open BDB handle stored
 *		in hdb->user_db and storing the pointer to it in userptr.  If an
 *		explicit txnid is given, it is assumed that this is a fetch for a
 *		read/modify/write cycle and the BDB flag is set as such.
 *
 *		Returns 0 on success.
 *
 *		Returns EINVAL if a NULL BDB handle is passed, ENOMEM on memory
 *		allocation errors, or whatever is returned by the db->get call.
 *
 */
int
fetch_user_from_db(HOTPants_DB * hdb, char *login, void *txn,
    User ** userptr)
{

	DBT key, data;
	int ret;
	HPData userdata;
	u_int32_t flags = 0;

	DB_TXN *txnid;

	txnid = (DB_TXN *) txn;
	memset(&key, 0, sizeof(DBT));
	memset(&data, 0, sizeof(DBT));

	if (!hdb || !hdb->user_db) {
		userptr = (User **) NULL;
		return EINVAL;
	}
	key.data = login;
	key.size = strlen(login);
	data.flags = DB_DBT_MALLOC;

	if (txnid) {
		flags = DB_RMW;
	}
	ret = hdb->user_db->get(hdb->user_db, txnid, &key, &data, flags);
	if (ret) {
		userptr = (User **) NULL;
		return ret;
	}
	userdata.data = data.data;
	userdata.size = data.size;
	if ((*userptr = deserialize_user(&userdata)) == (User *) NULL) {
		free(data.data);
		return ENOMEM;
	}
	free(data.data);
	return ret;
}

/*
 * fetch_config_param_from_db
 *		fetch a configuration parameter passed by *param from the database
 *		and return it to the higher level.  This is essentially just a
 *		not-so-fancy wrapper around db->get().  The calling function is
 *		responsible for freeing the memory returned by this function.
 *
 *		This function is declared in such a way and called indirectly
 *		to allow the application to override from where it gets its
 *		configuration by redefining the hook to the function.
 *
 *		Returns 0 on success.
 *
 *		Returns EINVAL if a NULL BDB handle is passed, ENOMEM on memory
 *		allocation errors, or whatever is returned by the db->get call.
 *
 */
int
__fetch_config_param_from_db(HOTPants_DB * hdb, char *param,
    HPData * valptr)
{

	DBT key, data;
	int ret;
	u_int32_t flags = 0;

	memset(&key, 0, sizeof(DBT));
	memset(&data, 0, sizeof(DBT));

	if (!hdb || !hdb->config_db) {
		valptr->data = NULL;
		valptr->size = 0;
		return EINVAL;
	}
	key.data = param;
	key.size = strlen(param);
	data.flags = DB_DBT_MALLOC;

	ret = hdb->config_db->get(hdb->config_db, (DB_TXN *) NULL, &key, &data,
	    flags);
	if (ret) {
		valptr->data = NULL;
		valptr->size = 0;
		return ret;
	}
	valptr->data = data.data;
	valptr->size = data.size;

	return ret;
}

/*
 * put_token_into_db
 *		put the token from the token pointer into BDB referenced by the open
 *		handle stored in hdb->token_db.  The txnid should be a valid BDB txnid
 *		or NULL.
 *
 *		Returns 0 on success.
 *
 *		Returns EINVAL if a NULL BDB handle is passed, ENOMEM on memory
 *		allocation errors, or whatever is returned by the db->put call.
 *
 *		It is the responsibility of the calling function to commit any
 *		pending transaction or handle any errors, including aborting and
 *		retrying transactions.
 */
int
put_token_into_db(HOTPants_DB * hdb, Token * token, void *txn)
{
	DBT key, data;
	int ret;
	HPData *tokdata;
	u_int32_t tokenid;

	DB_TXN *txnid;
	DB_TXN *mytxnid;

	txnid = (DB_TXN *) txn;
	memset(&key, 0, sizeof(DBT));
	memset(&data, 0, sizeof(DBT));

	if (!hdb || !hdb->token_db) {
		return EINVAL;
	}
	if ((tokdata = serialize_token(token)) == (HPData *) NULL) {
		return ENOMEM;
	}
	tokenid = htonl(token->tokenid);

	key.data = &tokenid;
	key.size = sizeof(u_int32_t);

	data.data = tokdata->data;
	data.size = tokdata->size;

	ret = hdb->Env->txn_begin(hdb->Env, txnid, &mytxnid, 0);
	if (ret) {
		return ret;
	}
	ret = hdb->token_db->put(hdb->token_db, mytxnid, &key, &data, 0);
	free(tokdata->data);
	free(tokdata);

	if (ret) {
		mytxnid->abort(mytxnid);
	} else {
		mytxnid->commit(mytxnid, 0);
	}
	return ret;
}


/*
 * put_user_into_db
 *		put the user from the user pointer into BDB referenced by the open
 *		handle stored in hdb->user_db.  The txnid should be a valid BDB txnid
 *		or NULL.
 *
 *		Returns 0 on success.
 *
 *		Returns EINVAL if a NULL BDB handle is passed, ENOMEM on memory
 *		allocation errors, or whatever is returned by the db->put call.
 *
 *		It is the responsibility of the calling function to commit any
 *		pending transaction or handle any errors, including aborting and
 *		retrying transactions.
 */
int
put_user_into_db(HOTPants_DB * hdb, User * user, void *txn)
{
	DBT key, data;
	int ret;
	HPData *userdata;
	DB_TXN *txnid;
	DB_TXN *mytxnid;

	txnid = (DB_TXN *) txn;

	memset(&key, 0, sizeof(DBT));
	memset(&data, 0, sizeof(DBT));

	if (!hdb || !hdb->user_db) {
		return EINVAL;
	}
	if ((userdata = serialize_user(user)) == (HPData *) NULL) {
		return ENOMEM;
	}
	key.data = user->login;
	key.size = strlen(user->login);

	data.data = userdata->data;
	data.size = userdata->size;

	ret = hdb->Env->txn_begin(hdb->Env, txnid, &mytxnid, 0);
	if (ret) {
		return ret;
	}
	ret = hdb->user_db->put(hdb->user_db, mytxnid, &key, &data, 0);
	free(userdata->data);
	free(userdata);

	if (ret) {
		mytxnid->abort(mytxnid);
	} else {
		mytxnid->commit(mytxnid, 0);
	}
	return ret;
}
