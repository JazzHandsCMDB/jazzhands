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
 * Authentication routines for HOTPants
 *
 */

#include <sys/types.h>
#include <hotpants_internals.h>
#include "crypto/hotpants_crypt.h"


int 
hp_initialize(char *path, HOTPants_DB ** hdbp, char **errmsg)
{
	int ret;
	HOTPants_DB *hdb;
	char *err;

	if (!path) {
		return EINVAL;
	}
	if (!hdbp) {
		return EINVAL;
	}
	if ((hdb = initialize_HPdb_context(path)) == (HOTPants_DB *) NULL) {
		return ENOMEM;
	}
	if (ret = hdb->open(hdb)) {
		if (errmsg) {
			err = hdb->error(hdb);
			if ((*errmsg = malloc(strlen(err))) != NULL) {
				strcpy(*errmsg, hdb->error(hdb));
			}
			*hdbp == (HOTPants_DB *) NULL;
		}
		return ret;
	}
	*hdbp = hdb;

	return 0;
}

int 
hp_finalize(HOTPants_DB * hdb)
{
	if (!hdb) {
		return 0;
	}
	hdb->close(hdb);
	free(hdb);
}

int 
hp_authenticate(HOTPants_DB * hdb, char *username, char *otp)
{
	User *user = (User *) NULL;
	Token *token = (Token *) NULL;
	u_int32_t tokenid, *tokenptr;
	int ret;
	unsigned int otplen, pinlen;
	u_int32_t sequence;
	char *pin, *hashed_pin, *sequence_otp = NULL;
	struct TokenTypeInfo_t *tokinfo;
	int auth_ok = HP_GENERIC_AUTH_FAILURE;
	u_int32_t normal_skew, verify_skew, max_bad_logins;
	time_t lockout_time;

	if (!username || !otp) {
		return EINVAL;
	}
	if (hdb == (HOTPants_DB *) NULL) {
		return EINVAL;
	}
	if (hp_auth_debug) {
		fprintf(stderr, "Begin authentication for user %s, otp %s\n",
		    username, otp);
	}
	if (ret = fetch_user_from_db(hdb, username, NULL, &user)) {
		if (ret == DB_KEYEMPTY || ret == DB_NOTFOUND) {
			return HP_USER_NOTFOUND;
		}
		if (hp_auth_debug) {
			fprintf(stderr, "Read user from database failed: %s\n",
			    db_strerror(ret));
		}
		auth_ok = ret;
		goto auth_error;
	}
	/*
	 * Check to make sure the user is not disabled
	 */
	if (user->status != US_ENABLED) {
		if (hp_auth_debug) {
			fprintf(stderr, "User %s is not enabled, status %d\n",
			    username, user->status);
		}
		auth_ok = HP_USER_DISABLED;
		goto auth_error;
	}
	/*
	 * Pull out each token individually looking for one with a matching
	 * PIN
	 */


	for (tokenptr = user->token_array; *tokenptr; tokenptr++) {
		if (hp_auth_debug) {
			fprintf(stderr, "Fetching token %08x for user %s.\n", *tokenptr,
			    username);
		}
		if (token)
			free_token(token);
		if (ret = fetch_token_from_db(hdb, *tokenptr, NULL, &token)) {
			if (ret == DB_KEYEMPTY) {
				continue;
			}
			if (hp_auth_debug) {
				fprintf(stderr, "Read token from database failed: %s\n",
				    db_strerror(ret));
			}
			auth_ok = ret;
			goto auth_error;
		}
		if (*(token->PIN) == '\0') {
			/*
			 * PIN for this token is not set; PIN must be
			 * initialized externally before the token can be
			 * used (at least for now)
			 */
			if (hp_auth_debug) {
				fprintf(stderr, "PIN not set for token %08x\n", *tokenptr);
			}
			continue;
		}
		/*
		 * Figure out what part of the OTP is the PIN and which is
		 * the PRN. Look up the length of the digits in the
		 * TokenTypeInfo table.
		 */

		for (tokinfo = TokenTypeInfo; tokinfo->token_type != token->type &&
		    tokinfo->token_type != TT_TOKMAX; tokinfo++);

		if (tokinfo->token_type == TT_TOKMAX) {
			if (hp_auth_debug) {
				fprintf(stderr,
				    "No token type information for token %08x, type %d\n",
				    *tokenptr, token->type);
			}
			continue;
		}
		otplen = strlen(otp);
		/*
		 * If we don't have enough digits, then it's definitely
		 * wrong.
		 */
		if (otplen <= tokinfo->digits) {
			continue;
		}
		pin = strdup(otp);
		pinlen = otplen - tokinfo->digits;
		pin[pinlen] = '\0';

		/*
		 * Check the PIN.  It's currently a blowfish crypt(3)-style
		 * hash, but it could be any hash that crypt(3) handles.
		 */
		if ((hashed_pin = malloc(_PASSWORD_LEN)) == NULL) {
			auth_ok = ENOMEM;
			goto auth_error;
		}
		__bcrypt_r(pin, token->PIN, hashed_pin);
		if (strncmp(hashed_pin, token->PIN, strlen(token->PIN))) {
			if (hp_auth_debug) {
				fprintf(stderr,
				    "PIN does not match\n  Theirs: %s\n  Ours: %s\n",
				    hashed_pin, token->PIN);
			}
			free(hashed_pin);
			free(pin);
			continue;
		}
		free(hashed_pin);
		free(pin);
		if (hp_auth_debug) {
			fprintf(stderr, "PIN matches for token %08x (%s)\n", *tokenptr,
			    token->serial);
		}
		break;
	}

	/*
	 * If we don't get a valid PIN, we can't really do anything to lock
	 * out the user yet.  This needs to change in the future.
	 */
	if (!*tokenptr) {
		if (hp_auth_debug) {
			fprintf(stderr, "No tokens for %s match the given PIN.\n",
			    username);
		}
		auth_ok = HP_BAD_PIN;
		goto auth_error;
	}
	/*
	 * The PIN is valid, so we have a token to auth against.  Check to
	 * see if the token is enabled.
	 */

	if (token->status != TS_ENABLED) {
		if (hp_auth_debug) {
			fprintf(stderr, "Token %08x, serial %s is disabled.\n",
			    token->tokenid, token->serial);
		}
		auth_ok = HP_TOKEN_DISABLED;
		goto auth_error;
	}
	if (token->token_locked) {
		/*
		 * If the token is locked, but it is past the unlock_time,
		 * unlock the token.
		 */
		if (token->unlock_time && token->unlock_time >= time((time_t *) NULL)) {
			token->token_locked = 0;
			token->unlock_time = 0;
			token->lock_status_changed = time((time_t *) NULL);
			if (hp_auth_debug) {
				fprintf(stderr, "Unlocking token %08x, serial %s.   Unlock time: %d, Current time: %d\n",
				    token->tokenid, token->serial,
				    token->unlock_time,
				    time((time_t *) NULL));
			}
			if (ret = put_token_into_db(hdb, token, NULL)) {
				fprintf(stderr,
				    "Unable to write token into token db while unlocking: %s\n",
				    db_strerror(ret));
				auth_ok = ret;
				goto auth_error;
			}
		} else {
			if (hp_auth_debug) {
				fprintf(stderr, "Token %08x, serial %s is locked.  Current time: %d, unlock time %d\n",
				    token->tokenid, token->serial,
				    time((time_t *) NULL), token->unlock_time);
			}
			auth_ok = HP_TOKEN_LOCKED;
			goto auth_error;
		}
	}
	/*
	 * Everything looks okay with the validity of the user and the token,
	 * so we'll start the auth.
	 */

	/* Allocate a buffer to store OTPs */

	if ((sequence_otp = malloc(tokinfo->digits + 1)) == NULL) {
		auth_ok = ENOMEM;
		goto auth_error;
	}
	otp += pinlen;

	/*
	 * check to see whether we're looking for a specific sequence number
	 * from a previous auth that was out of the sequence range
	 */

	if (token->skew_sequence) {
		sequence = token->skew_sequence + 1;
		if (ret = generateHOTP(sequence_otp, token->key->data,
			token->key->size, sequence, tokinfo->digits)) {
			auth_ok = ret;
			goto auth_error;
		}
		if (!strcmp(sequence_otp, otp)) {
			token->skew_sequence = 0;
			token->bad_logins = 0;
			token->sequence = sequence;
			put_token_into_db(hdb, token, (DB_TXN *) NULL);
			auth_ok = HP_SUCCESS;
			goto auth_complete;
		}
		if (hp_auth_debug) {
			fprintf(stderr,
			    "Next sequence mode expects %s for sequence %d; got %s\n",
			    sequence_otp,
			    token->skew_sequence,
			    otp);
			fprintf(stderr, "Dropping through to normal auth.\n");
		}
	}
	/*
	 * Fetch config parameters for this auth
	 */
	if ((ret = config_normal_seq_skew(hdb, &normal_skew))) {
		if (hp_auth_debug) {
			fprintf(stderr, "Invalid normal_skew config value: %d\n", ret);
		}
		auth_ok = HP_CONFIG_ERROR;
		goto auth_error;
	}
	if (hp_auth_debug) {
		fprintf(stderr, "Value for normal_skew is %d\n", normal_skew);
	}
	if ((ret = config_verify_seq_skew(hdb, &verify_skew))) {
		if (hp_auth_debug) {
			fprintf(stderr, "Invalid verify_skew config value: %d\n", ret);
		}
		auth_ok = HP_CONFIG_ERROR;
		goto auth_error;
	}
	if (hp_auth_debug) {
		fprintf(stderr, "Value for verify_skew is %d\n", verify_skew);
	}
	if ((ret = config_max_bad_logins(hdb, &max_bad_logins))) {
		if (hp_auth_debug) {
			fprintf(stderr, "Invalid max_bad_logins config value: %d\n", ret);
		}
		auth_ok = HP_CONFIG_ERROR;
		goto auth_error;
	}
	if (hp_auth_debug) {
		fprintf(stderr, "Value for max_bad_logins is %d\n", max_bad_logins);
	}
	if ((ret = config_lockout_time(hdb, &lockout_time))) {
		if (hp_auth_debug) {
			fprintf(stderr, "Invalid lockout_time config value: %d\n", ret);
		}
		auth_ok = HP_CONFIG_ERROR;
		goto auth_error;
	}
	if (hp_auth_debug) {
		fprintf(stderr, "Value for lockout_time is %d\n", lockout_time);
	}
	/*
	 * Go through the sequence values and see if we can find the given
	 * OTP
	 */
	for (sequence = token->sequence + 1;
	    sequence <= token->sequence + verify_skew; sequence++) {

		if (ret = generateHOTP(sequence_otp, token->key->data,
			token->key->size, sequence, tokinfo->digits)) {
			if (hp_auth_debug) {
				fprintf(stderr, "Error generating OTP\n");
			}
			auth_ok = ret;
			goto auth_error;
		}
		if (strcmp(sequence_otp, otp)) {
			if (hp_auth_debug) {
				fprintf(stderr,
				    "OTP does not match (seq: %d, given: %s, computed: %s)\n",
				    sequence,
				    otp,
				    sequence_otp);
			}
		} else {
			break;
		}
	}

	if (sequence > token->sequence + verify_skew) {
		/*
		 * Did not find a matching sequence number
		 */
		if (hp_auth_debug) {
			fprintf(stderr, "OTP given does not match a valid sequence\n");
		}
		token->bad_logins++;
		if (token->bad_logins > max_bad_logins) {
			token->token_locked = 1;
			if (lockout_time) {
				token->unlock_time = time((time_t *) NULL) + lockout_time;
			} else {
				token->unlock_time = (time_t) 0;
			}
			token->lock_status_changed = time((time_t *) NULL);
		}
		auth_ok = HP_BAD_OTP;
	} else if (sequence > token->sequence + normal_skew) {
		/*
		 * Mark token to require the next sequence number.
		 */
		if (hp_auth_debug) {
			fprintf(stderr, "OTP sequence %d outside of normal skew (expected %d).  Setting NEXT_OTP mode.\n",
			    sequence,
			    token->sequence);
		}
		token->skew_sequence = sequence;
		auth_ok = HP_NEXT_OTP;
	} else {
		/*
		 * Auth is okay.  Update the sequence and other parameters.
		 * 
		 */
		token->bad_logins = 0;
		token->sequence = sequence;
		user->last_login = time((time_t *) NULL);
		auth_ok = HP_SUCCESS;

		if ((put_user_into_db(hdb, user, (DB_TXN *) NULL)) != 0) {
			/*
			 * User successfully authed, but we couldn't update
			 * the database entry.  Since this is just setting
			 * the user's last_update parameter, this won't
			 * create a security issue, so we allow it.
			 */
			if (hp_auth_debug) {
				/* This needs to be a real logged error */
				fprintf(stderr, "hp_authenticate: warn: error writing user information back to database.\n");
			}
		}
	}

auth_complete:

	if ((put_token_into_db(hdb, token, (DB_TXN *) NULL)) != 0) {
		/*
		 * User successfully authed, but we couldn't update the
		 * database entry.  Since this would enable the token to be
		 * reused (and may be being reused undetected if the problem
		 * has persisted for some length of time), we are going to
		 * deny the login.  We will not, however, update the
		 * bad_login count, because that would just be mean.
		 */
		if (hp_auth_debug) {
			/* This needs to be a real logged error */
			fprintf(stderr, "hp_authenticate: error writing updated token back to database.  Denying authentication.\n");
		}
		auth_ok = HP_DB_WRITE_ERROR;
	}
auth_error:

	if (user)
		free_user(user);
	if (token)
		free_token(token);
	if (sequence_otp)
		free(sequence_otp);
	return auth_ok;
}

/* Verify that a user is provisioned in the system */

int 
hp_check_user(HOTPants_DB * hdb, char *username)
{
	User *user = NULL;
	int ret;

	if (!username) {
		return EINVAL;
	}
	if (hdb == (HOTPants_DB *) NULL) {
		return EINVAL;
	}
	if (hp_auth_debug) {
		fprintf(stderr, "Begin user verification for %s\n",
		    username);
	}
	if (ret = fetch_user_from_db(hdb, username, NULL, &user)) {
		if (ret == DB_KEYEMPTY || ret == DB_NOTFOUND) {
			return HP_USER_NOTFOUND;
		}
		if (hp_auth_debug) {
			fprintf(stderr, "Read user from database failed: %s\n",
			    db_strerror(ret));
		}
		return ret;
	}
	if (!*(user->token_array)) {
		if (hp_auth_debug) {
			fprintf(stderr, "No token assigned for user %s.\n", username);
		}
		return HP_USER_NOTFOUND;
	}
	/* If we get here, the user is provisioned */
	free_user(user);
	return HP_SUCCESS;
}
