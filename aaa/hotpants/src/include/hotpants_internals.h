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
 * HOTPants internal private definitions and variables
 */
/*
 * All of these config parameters need to move to a config file somehow
 */

#ifndef __HOTPANTS_INTERNALS_H
#define __HOTPANTS_INTERNALS_H

#include <sys/param.h>
#include <db.h>

#define __HPDB_ERRSIZE	1024

typedef struct HPData_t {
	int size;		/* size of following data			 */
	void *data;		/* pointer to data					 */
}        HPData;

typedef struct HOTPants_DB_t {
	DB_ENV *Env;		/* store Berkeley DB Environment pointer */
	DB *user_db;		/* store pointer to user database */
	DB *token_db;		/* store pointer to token database */
	DB *config_db;		/* store pointer to config database */
	int (*open) __P((struct HOTPants_DB_t *));
	void (*close) __P((struct HOTPants_DB_t *));
	char *(*error) __P((struct HOTPants_DB_t *));
	int (*get_config_param) __P((struct HOTPants_DB_t *, char *, HPData *));
	void *config_opaque;	/* opaque data used by get_config_param()	 */
	char __dbpath[MAXPATHLEN];	/* path to db environment */
	char *error_file;	/* path to error file, if present */
	char __errmsg[__HPDB_ERRSIZE];	/* storage for error messages */
}             HOTPants_DB;

#include <hotpants.h>

#define	HOTPANTS_DEBUG				0

#define	MAX_BAD_PIN					5
#define MAX_AUTO_SEQUENCE_SKEW		8
#define MAX_MANUAL_SEQUENCE_SKEW	20

extern unsigned int hp_auth_debug;

static struct TokenTypeInfo_t {
	TokenType token_type;
	TokenSequenceType seq_type;
	u_int32_t digits;
	u_int32_t keylen;
	u_int32_t checksum;
}               TokenTypeInfo[] = {

	{
		TT_SOFT_SEQ, TST_COUNTER, 8, 32, 0
	},
	{
		TT_SOFT_TIME, TST_TIME, 8, 32, 0
	},
	{
		TT_ETOKEN_OTP32, TST_COUNTER, 6, 32, 0
	},
	{
		TT_ETOKEN_OTP64, TST_COUNTER, 6, 32, 0
	},
	{
		TT_DIGIPASS_GO3, TST_COUNTER, 6, 32, 0
	},
	{
		TT_ETOKEN_PASS, TST_COUNTER, 6, 32, 0
	},
	{
		TT_TOKMAX, 0, 0, 0
	}			/* This *must* be last */
};


#endif				/* __HOTPANTS_INTERNALS_H */
