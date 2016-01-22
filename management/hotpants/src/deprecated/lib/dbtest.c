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

#include <stdio.h>
#include <sys/types.h>
#include <hotpants.h>

int
main(int argc, char **argv)
{
	HOTPants_DB *hdb;
	HPData *s;
	User user;
	Token token1;
	Token token2;
	User *du;
	Token *dt;
	unsigned int tarray[3];
	unsigned int *toklist;
	HPData key;
	int ret;
	char *stuff;
	char timestr[32];
	char keystr[32 * 3];
	unsigned char keydata[32] = {
		0xa4,
		0x7f,
		0x3e,
		0xd5,
		0xcc,
		0x35,
		0x2c,
		0x90,
		0x69,
		0x27,
		0x92,
		0xeb,
		0xdd,
		0xf0,
		0x84,
		0x22,
		0xa5,
		0x97,
		0x12,
		0xe9,
		0xef,
		0x85,
		0x6d,
		0x00,
		0x79,
		0x69,
		0xd0,
		0x3c,
		0x87,
		0x9b,
		0xcd,
		0x88
	};

	key.data = keydata;
	key.size = 32;


	fprintf(stderr, "Opening database...\n");
	if ((hdb = initialize_HPdb_context("../test")) == (HOTPants_DB *) NULL) {
		fprintf(stderr, "Unable to initialize HPdb context!\n");
		exit(1);
	}
	fprintf(stderr, "Got context...\n");
	if (hdb->open(hdb)) {
		fprintf(stderr, "Error opening database: %s\n", hdb->error(hdb));
		exit(1);
	}
	fprintf(stderr, "DB opened...\n");

	memset(&token1, '\0', sizeof(token1));
	token1.tokenid = 0xf0adf00d;
	token1.type = TT_ETOKEN_OTP32;
	token1.serial = "ALNG00116F04";
	token1.status = TS_ENABLED;
	token1.key = &key;
	token1.sequence = 15;
	token1.zero_time = 0;
	token1.time_modulo = 0;
	token1.skew_sequence = 0;
	token1.time_skew = 0;
	token1.PIN = "JoMama";
	token1.token_locked = 0;
	token1.unlock_time = 0;
	token1.last_login = time((time_t *) NULL);
	token1.bad_logins = 0;

	memset(&token2, '\0', sizeof(token2));
	token2.tokenid = 12;
	token2.type = TT_ETOKEN_OTP32;
	token2.serial = "ALNG00116EB7";
	token2.status = TS_DISABLED;
	token2.key = &key;
	token2.sequence = 22;
	token2.zero_time = 0;
	token2.time_modulo = 0;
	token2.skew_sequence = 0;
	token2.time_skew = 0;
	token2.PIN = "nuts";
	token1.token_locked = 0;
	token1.unlock_time = 0;
	token1.last_login = time((time_t *) NULL);
	token1.bad_logins = 0;

	tarray[0] = token1.tokenid;
	tarray[1] = token2.tokenid;
	tarray[2] = 0;

	memset(&user, '\0', sizeof(user));
	user.login = "mdr";
	user.status = US_ENABLED;
	user.last_login = time((time_t *) NULL);
	user.token_array = tarray;

/*
	if (ret = put_token_into_db(hdb, &token1, NULL)) {
		fprintf(stderr, "Write token1 into database failed: %s\n",
			db_strerror(ret));
		goto error;
	}

	if (ret = put_token_into_db(hdb, &token2, NULL)) {
		fprintf(stderr, "Write token1 into database failed: %s\n",
			db_strerror(ret));
		goto error;
	}

	if (ret = put_user_into_db(hdb, &user, NULL)) {
		fprintf(stderr, "Write user into database failed: %s\n",
			db_strerror(ret));
		goto error;
	}
*/
	if (ret = fetch_user_from_db(hdb, user.login, NULL, &du)) {
		fprintf(stderr, "Read user from database failed: %s\n",
		    db_strerror(ret));
		goto error;
	}
	printf("\tLogin: %s\n", du->login);
	printf("\tStatus: %d\n", du->status);
	ctime_r(&(du->last_login), timestr, sizeof(timestr));
	printf("\tLast Login: %s", timestr);
	printf("\tTokens:\n");

	for (toklist = du->token_array; *toklist; toklist++) {

		if (ret = fetch_token_from_db(hdb, *toklist, NULL, &dt)) {
			printf("\t\t0x%x (not found)\n", *toklist);
			continue;
		}
		printf("\t\tTokenID: 0x%08x\n", dt->tokenid);
		printf("\t\tType: %d\n", dt->type);
		printf("\t\tSerial: %s\n", dt->serial);
		printf("\t\tStatus: %d\n", dt->status);
		keytohex(dt->key, keystr);
		printf("\t\tKey: %s\n", keystr);
		printf("\t\tSequence: %d\n", dt->sequence);
		ctime_r(&(dt->zero_time), timestr, sizeof(timestr));
		printf("\t\tZero Time: %s", timestr);
		printf("\t\tTime Modulo: %d seconds\n", dt->time_modulo);
		printf("\t\tSkew Sequence: %d\n", dt->skew_sequence);
		printf("\t\tTime Skew: %d\n", dt->time_skew);
		printf("\t\tPIN: %s\n", dt->PIN);
		ctime_r(&(dt->last_login), timestr, sizeof(timestr));
		printf("\t\tLast Login: %s", timestr);
		printf("\t\tToken Locked: %d\n", dt->token_locked);
		ctime_r(&(dt->unlock_time), timestr, sizeof(timestr));
		printf("\t\tUnlock Time: %s", timestr);
		printf("\t\tBad Logins: %d\n\n", dt->bad_logins);
		free_token(dt);
	}
	free_user(du);

error:
	hdb->close(hdb);
}
