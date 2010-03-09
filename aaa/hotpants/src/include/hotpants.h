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
 * structures, types, and definitions for HOTPants
 *
 */

#ifndef __HOTPANTS_H
#define __HOTPANTS_H

#include <sys/param.h>
#include <sys/types.h>
#include <sys/errno.h>
#include <stdlib.h>
#include <strings.h>
#ifdef SOLARIS
#include <netinet/in.h>
#include <inttypes.h>
#endif

#ifndef __BIT_TYPES_DEFINED__
#define __BIT_TYPES_DEFINED__
typedef unsigned char u_int8_t;

typedef unsigned short u_int16_t;

typedef unsigned int u_int32_t;

typedef unsigned long long u_int64_t;

#endif

#undef __P
#define __P(protos) protos

#define __HOTPANTS_USER_DB_NAME	"user.db"
#define __HOTPANTS_TOKEN_DB_NAME	"token.db"
#define __HOTPANTS_CONFIG_DB_NAME	"config_db.db"
/* structure to hold database pointers */

#ifndef __HOTPANTS_INTERNALS_H

#define __HPDB_ERRSIZE	1024

typedef struct HPData_t {
	int size;		/* size of following data			 */
	void *data;		/* pointer to data					 */
}        HPData;

typedef struct HOTPants_DB_t {
	void *Env;		/* store Berkeley DB Environment pointer */
	void *user_db;		/* store pointer to user database */
	void *token_db;		/* store pointer to token database */
	void *config_db;	/* store pointer to config database */
	int (*open) __P((struct HOTPants_DB_t *));
	void (*close) __P((struct HOTPants_DB_t *));
	char *(*error) __P((struct HOTPants_DB_t *));
	int (*get_config_param) __P((struct HOTPants_DB_t *, char *, HPData *));
	void *config_opaque;	/* opaque data used by get_config_param()	 */
	char __dbpath[MAXPATHLEN];	/* path to db environment */
	char *error_file;	/* path to db environment */
	char __errmsg[__HPDB_ERRSIZE];	/* storage for error messages */
}             HOTPants_DB;

#endif				/* __HOTPANTS_INTERNALS_H */

typedef enum TokenType_t {
	TT_UNDEF,		/* Undefined or N/A				 */
	TT_SOFT_SEQ,		/* sequence-based soft token	 */
	TT_SOFT_TIME,		/* time-based soft token		 */
	TT_ETOKEN_OTP32,	/* Aladdin eToken OTP 32K		 */
	TT_ETOKEN_OTP64,	/* Aladdin eToken OTP 64K		 */
	TT_DIGIPASS_GO3,	/* Vasco Digipass Go3			 */
	TT_ETOKEN_PASS,		/* Aladdin eToken PASS			 */
	TT_TOKMAX
}           TokenType;

typedef enum TokenSequenceType_t {
	TST_UNDEF,		/* Undefined sequence type		 */
	TST_COUNTER,		/* Counter-based token			 */
	TST_TIME		/* Time-based token				 */
}                   TokenSequenceType;

typedef enum TokenStatus_t {
	TS_DISABLED,
	TS_ENABLED,
	TS_LOST,
	TS_STOLEN,
	TS_DESTROYED
}             TokenStatus;

/*
 * Errors defined here.
 */

#define	HP_SUCCESS				(0)	/* Success!						 */
#define	HP_GENERIC_AUTH_FAILURE	(-28900)	/* Unspecified auth failure		 */
#define	HP_NEXT_OTP				(-28901)	/* OTP was valid, but
								 * outside   */
 /* the valid sequence range.    */
 /* User must auth again with	 */
 /* the next	sequence			 */
#define	HP_TOKEN_NOTFOUND		(-28902)	/* Token not found in
							 * database	 */
#define	HP_USER_NOTFOUND		(-28903)	/* User not found in
							 * database	 */
#define	HP_BAD_PIN				(-28904)	/* PIN passed does not
								 * match a  */
 /* token						 */
#define	HP_BAD_OTP				(-28905)	/* OTP did not match a
								 * valid	 */
 /* sequence */
#define	HP_PIN_NOT_SET			(-28906)	/* PIN for the token is
							 * not set	 */
#define	HP_CONFIG_ERROR			(-28907)	/* Error in
							 * configuration data	 */
#define	HP_USER_DISABLED		(-28908)	/* User has been
							 * disabled		 */
#define	HP_USER_LOCKED			(-28909)	/* User account is
							 * locked		 */
#define	HP_TOKEN_DISABLED		(-28910)	/* Token has been
							 * disabled		 */
#define	HP_TOKEN_LOCKED			(-28911)	/* Token marked as
							 * locked		 */
#define	HP_DB_WRITE_ERROR		(-28912)	/* Error writing db
							 * entry		 */
#define	HP_DB_READ_ERROR		(-28913)	/* Error reading db
							 * entry		 */


typedef struct Token_t {
	u_int32_t tokenid;	/* internal TokenID (SystemDB)		 */
	TokenType type;		/* Type of token					 */
	TokenStatus status;	/* Token status						 */
	char *serial;		/* Serial Number					 */
	HPData *key;		/* Encryption Key					 */
	u_int32_t sequence;	/* OTP sequence						 */
	time_t zero_time;	/* zero time for time-based OTPs	 */
	u_int32_t time_modulo;	/* frequency of time change in secs	 */
	u_int32_t skew_sequence;/* OTP sequence last used if skew 	 */
	/* too great						 */
	time_t time_skew;	/* recorded difference between 		 */
	/* server and OTP time				 */
	char *PIN;		/* user-assigned PIN				 */
	u_int32_t token_locked;	/* zero if account is unlocked		 */
	time_t unlock_time;	/* Time that user account unlocks	 */
	time_t last_login;	/* Time token last logged in		 */
	u_int32_t bad_logins;	/* number of consecutive bad logins	 */
	time_t sequence_changed;/* time sequence was last changed	 */
	time_t token_changed;	/* time other non-lock params were  */
	/* changed	 */
	time_t lock_status_changed;	/* time lock status changed		 */
}       Token;

typedef enum UserStatus_t {
	US_DISABLED,
	US_ENABLED,
	US_DELETED
}            UserStatus;

typedef struct User_t {
	char *login;		/* User login name					 */
	UserStatus status;	/* User login status				 */
	time_t last_login;	/* Time user last logged in			 */
	u_int32_t bad_logins;	/* number of consecutive bad logins	 */
	u_int32_t user_locked;	/* zero if account is unlocked		 */
	time_t unlock_time;	/* Time that user account unlocks	 */
	time_t user_changed;	/* time any user parameter changed	 */
	time_t lock_status_changed;	/* time lock status changed			 */
	u_int32_t *token_array;	/* Array of token ids assigned 		 */
}      User;

/*
 * Default config values.  These are designed to be on the strict side.
 *
 *	HPCF_DEFAULT_NORMAL_SEQ_SKEW - Amount of skew which is considered normal;
 *		if the OTP given is less than this many sequence numbers ahead,
 *		just accept it
 *	HPCF_DEFAULT_VERIFY_SEQ_SKEW - Amount of skew allowed for a user to
 *		verify themselves by entering two sequential valid OTPs if sequence
 *		is off by more than	the normal_seq_skew value
 *	HPCF_DEFAULT_MAX_BAD_LOGINS - Maximum number of sequential bad logins per
 *		user/token before it is locked out.  '0' prevents tokens/users from
 *		being locked out
 *	HPCF_DEFAULT_LOCKOUT_TIME - amount of time to lock a token after
 *		max_bad_logins is hit.	A lock_time of '0' will force the token to
 *		be unlocked by an admin
 *
 */
#define HPCF_DEFAULT_NORMAL_SEQ_SKEW	5
#define HPCF_DEFAULT_VERIFY_SEQ_SKEW	50
#define HPCF_DEFAULT_MAX_BAD_LOGINS		5
#define HPCF_DEFAULT_LOCKOUT_TIME		0
#define HPCF_DEFAULT_DATABASE_DIR		"/prod/hotpants/db"

int hp_initialize(char *, HOTPants_DB **, char **);
int hp_authenticate __P((HOTPants_DB *, char *, char *));
int hp_check_user __P((HOTPants_DB *, char *));
int hp_finalize __P((HOTPants_DB *));
char *hp_strerror __P((int));
HOTPants_DB *initialize_HPdb_context __P((char *));
HPData *serialize_user __P((User *));
User *deserialize_user __P((HPData *));
HPData *serialize_token __P((Token *));
Token *deserialize_token __P((HPData *));
char *base64_encode __P((HPData *));
HPData *base64_decode __P((char *));
int put_user_into_db __P((HOTPants_DB *, User *, void *));
int put_token_into_db __P((HOTPants_DB *, Token *, void *));
int fetch_user_from_db __P((HOTPants_DB *, char *, void *, User **));
int fetch_token_from_db __P((HOTPants_DB *, u_int32_t, void *, Token **));
void free_user __P((User *));
void free_token __P((Token *));
void keytohex __P((HPData *, char *));
int generateHOTP __P((char *, const void *, u_int32_t, u_int32_t, u_int32_t));
int config_normal_seq_skew __P((HOTPants_DB *, u_int32_t *));
int config_verify_seq_skew __P((HOTPants_DB *, u_int32_t *));
int config_max_bad_logins __P((HOTPants_DB *, u_int32_t *));
int config_lockout_time __P((HOTPants_DB *, time_t *));

#endif				/* __HOTPANTS_H */
