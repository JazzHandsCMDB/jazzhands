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
 * HOTPants routines to serialize structures for reading from and writing
 * to the database
 *
 */

#include <hotpants.h>
#include <strings.h>

#define	HP_USER_SERIALIZE_VERSION	1	/* Current version of
						 * serialization */
#define	HP_TOKEN_SERIALIZE_VERSION	1	/* Current version of
						 * serialization */

#define HP_SERIALIZE_PAGESIZE	1024	/* Size of allocation buffer page	 */

uint32_t __deserialize_int __P((char **));
char *__deserialize_string __P((char **));
int __serialize_int __P((HPData *, uint32_t));
int __serialize_string __P((HPData *, char *));

HPData *
serialize_user(User * user)
{
	HPData *s;
	char *buffer;
	unsigned int pages;
	uint32_t tokcount = 0;
	uint32_t *tokcountptr;
	unsigned int tokcount_offset;
	uint32_t *tok_array;

	if ((s = (HPData *) malloc(sizeof(HPData))) == NULL) {
		return (HPData *) NULL;
	}
	if ((buffer = (char *) malloc(HP_SERIALIZE_PAGESIZE)) == NULL) {
		free(s);
		return (HPData *) NULL;
	}
	s->size = 0;
	s->data = (void *) buffer;

	/* First serialize the version number (for unserialization) */


	if (__serialize_int(s, (uint32_t) HP_USER_SERIALIZE_VERSION) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	/* login name */

	if (__serialize_string(s, user->login) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	/* User status */

	if (__serialize_int(s, (uint32_t) user->status) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	/* Last user logon */

	if (__serialize_int(s, (uint32_t) user->last_login) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	/* Number of bad logins */

	if (__serialize_int(s, (uint32_t) user->bad_logins) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	/* User unlock time */

	if (__serialize_int(s, (uint32_t) user->unlock_time) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	/* User changed timestamp */

	if (__serialize_int(s, user->user_changed) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	/* Lock status changed timestamp */

	if (__serialize_int(s, user->lock_status_changed) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	/*
	 * Serialize the TokenIDs.  We need to store the number of values
	 * followed by all of the values, so we're going to cheat by writing
	 * a dummy value, then counting through the tokens as we write them,
	 * then going back and changing the dummy to the actual value.
	 * Unfortunately, we can't stash the pointer now, because there's a
	 * chance that a realloc() can happen and invalidate the pointer, so
	 * we just have to stash the offset.
	 * 
	 * We could theoretically zero-terminate the list, since TokenIDs are
	 * guaranteed to be non-zero, but it makes it a lot easier to
	 * deserialize later by having the record count before going through
	 * the records.
	 */

	tokcount_offset = s->size;

	if (__serialize_int(s, 0) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	tok_array = user->token_array;
	while (tok_array && *tok_array) {
		tokcount++;

		if (__serialize_int(s, *tok_array) != 0) {
			free(s->data);
			free(s);
			return (HPData *) NULL;
		}
		tok_array++;
	}
	tokcountptr = (uint32_t *) ((char *) s->data + tokcount_offset);
	*tokcountptr = tokcount;

	return s;
}

HPData *
serialize_token(Token * token)
{
	HPData *s;
	char *buffer;
	char *base64_s;
	int pages;

	if ((s = (HPData *) malloc(sizeof(HPData))) == NULL) {
		return (HPData *) NULL;
	}
	if ((buffer = (char *) malloc(HP_SERIALIZE_PAGESIZE)) == NULL) {
		free(s);
		return (HPData *) NULL;
	}
	s->size = 0;
	s->data = (void *) buffer;

	/* First serialize the version number (for unserialization) */


	if (__serialize_int(s, (uint32_t) HP_TOKEN_SERIALIZE_VERSION) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	/* Token ID */

	if (__serialize_int(s, token->tokenid) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	/* Type */

	if (__serialize_int(s, (uint32_t) token->type) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	/* Status */

	if (__serialize_int(s, (uint32_t) token->status) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	/* Serial number */

	if (__serialize_string(s, token->serial) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	/* Key */

	if ((base64_s = base64_encode(token->key)) == NULL) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	if (__serialize_string(s, base64_s) != 0) {
		free(base64_s);
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	free(base64_s);

	/* Sequence */

	if (__serialize_int(s, token->sequence) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	/* Start Time */

	if (__serialize_int(s, (uint32_t) token->zero_time) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	/* Time Modulo */

	if (__serialize_int(s, token->time_modulo) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	/* Skew Sequence */

	if (__serialize_int(s, token->skew_sequence) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	/* PIN */

	if (__serialize_string(s, token->PIN) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	/* Last token logon */

	if (__serialize_int(s, (uint32_t) token->last_login) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	/* Token Locked */

	if (__serialize_int(s, token->token_locked) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	/* Unlock Time */

	if (__serialize_int(s, (uint32_t) token->unlock_time) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	/* Bad Logins */

	if (__serialize_int(s, token->bad_logins) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	if (__serialize_int(s, token->sequence_changed) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	if (__serialize_int(s, token->token_changed) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	if (__serialize_int(s, token->lock_status_changed) != 0) {
		free(s->data);
		free(s);
		return (HPData *) NULL;
	}
	return s;
}

User *
deserialize_user(HPData * block)
{
	User *user;
	char *cursor;
	uint32_t serialversion;
	uint32_t tokcount;
	uint32_t *tok_array;

	cursor = (char *) block->data;

	if ((user = (User *) malloc(sizeof(User))) == NULL) {
		return (User *) NULL;
	}
	memset(user, 0, sizeof(User));

	/* First unserialize the version number so we know how to decode */

	serialversion = __deserialize_int(&cursor);

	switch (serialversion) {
	case 1:
		if ((user->login = __deserialize_string(&cursor)) ==
		    (char *) NULL) {
			free_user(user);
			return (User *) NULL;
		}
		user->status = __deserialize_int(&cursor);
		user->last_login = __deserialize_int(&cursor);
		user->user_changed = __deserialize_int(&cursor);
		tokcount = __deserialize_int(&cursor);
		if ((tok_array = (unsigned int *) malloc((tokcount + 1) *
			    sizeof(unsigned int))) == (unsigned int *) NULL) {
			free_user(user);
			return (User *) NULL;
		}
		user->token_array = tok_array;
		while (tokcount--) {
			*(tok_array++) = __deserialize_int(&cursor);
		}
		*tok_array = 0;
		break;
	case 2:
		if ((user->login = __deserialize_string(&cursor)) ==
		    (char *) NULL) {
			free_user(user);
			return (User *) NULL;
		}
		user->status = __deserialize_int(&cursor);
		user->last_login = __deserialize_int(&cursor);
		user->bad_logins = __deserialize_int(&cursor);
		user->user_locked = __deserialize_int(&cursor);
		user->unlock_time = __deserialize_int(&cursor);
		user->user_changed = __deserialize_int(&cursor);
		user->lock_status_changed = __deserialize_int(&cursor);
		tokcount = __deserialize_int(&cursor);
		if ((tok_array = (unsigned int *) malloc((tokcount + 1) *
			    sizeof(unsigned int))) == (unsigned int *) NULL) {
			free_user(user);
			return (User *) NULL;
		}
		user->token_array = tok_array;
		while (tokcount--) {
			*(tok_array++) = __deserialize_int(&cursor);
		}
		*tok_array = 0;
		break;
	default:
		return (User *) NULL;
	}
	return user;
}

Token *
deserialize_token(HPData * block)
{
	Token *token;
	char *cursor;
	uint32_t serialversion;
	char *base64_s;

	cursor = (char *) block->data;

	if ((token = (Token *) malloc(sizeof(Token))) == (Token *) NULL) {
		return (Token *) NULL;
	}
	memset(token, 0, sizeof(Token));

	/* First unserialize the version number so we know how to decode */

	serialversion = __deserialize_int(&cursor);

	switch (serialversion) {
	case 1:
		token->tokenid = __deserialize_int(&cursor);
		token->type = __deserialize_int(&cursor);
		token->status = __deserialize_int(&cursor);
		if ((token->serial = __deserialize_string(&cursor)) ==
		    (char *) NULL) {
			free_token(token);
			return (Token *) NULL;
		}
		if ((base64_s = __deserialize_string(&cursor)) ==
		    (char *) NULL) {
			free_token(token);
			return (Token *) NULL;
		}
		if ((token->key = base64_decode(base64_s)) ==
		    (HPData *) NULL) {
			free(base64_s);
			free_token(token);
			return (Token *) NULL;
		}
		free(base64_s);
		token->sequence = __deserialize_int(&cursor);
		token->zero_time = __deserialize_int(&cursor);
		token->time_modulo = __deserialize_int(&cursor);
		token->skew_sequence = __deserialize_int(&cursor);

		if ((token->PIN = __deserialize_string(&cursor)) ==
		    (char *) NULL) {
			free_token(token);
			return (Token *) NULL;
		}
		token->last_login = __deserialize_int(&cursor);
		token->token_locked = __deserialize_int(&cursor);
		token->unlock_time = __deserialize_int(&cursor);
		token->bad_logins = __deserialize_int(&cursor);
		token->sequence_changed = __deserialize_int(&cursor);
		token->token_changed = __deserialize_int(&cursor);
		token->lock_status_changed = __deserialize_int(&cursor);
		break;
	default:
		return (Token *) NULL;
	}
	return token;
}

int 
__serialize_string(HPData * s, char *str)
{
	char *buffer;
	int pages;
	int len;

	buffer = (char *) s->data;

	/*
	 * Calculate the size of the buffer and see if it's going to put us
	 * across our page boundary.  Rather than doing continual realloc()s,
	 * we malloc() a chunk (defined in HP_SERIALIZE_PAGESIZE) and
	 * realloc() more chunks if we need them.
	 */

	len = strlen(str) + 1;
	pages = (s->size + len) / HP_SERIALIZE_PAGESIZE;
	if (pages != (s->size / HP_SERIALIZE_PAGESIZE)) {
		if ((buffer = (char *) realloc(buffer,
			    HP_SERIALIZE_PAGESIZE * (pages + 1))) == (char *) NULL) {
			return -1;
		}
		s->data = buffer;
	}
	buffer += s->size;
	strcpy(buffer, str);
	s->size += len;
	return 0;
}

int 
__serialize_int(HPData * s, uint32_t i)
{
	char *buffer;
	int pages;

	buffer = s->data;

	/*
	 * Calculate the size of the buffer and see if it's going to put us
	 * across our page boundary.  Rather than doing continual realloc()s,
	 * we malloc() a chunk (defined in HP_SERIALIZE_PAGESIZE) and
	 * realloc() more chunks if we need them.
	 */

	pages = (s->size + sizeof(uint32_t)) / HP_SERIALIZE_PAGESIZE;
	if (pages != (s->size / HP_SERIALIZE_PAGESIZE)) {
		if ((buffer = (char *) realloc(buffer,
			    HP_SERIALIZE_PAGESIZE * (pages + 1))) == (char *) NULL) {
			return -1;
		}
		s->data = buffer;
	}
	buffer += s->size;
	*((uint32_t *) buffer) = htonl(i);
	s->size += sizeof(int);
	return 0;
}


uint32_t 
__deserialize_int(char **block)
{
	uint32_t i;

	i = **(uint32_t **) block;
	*block += sizeof(uint32_t);
	return ntohl(i);
}

char *
__deserialize_string(char **block)
{
	char *s;
	unsigned int length;

	length = strlen(*block) + 1;

	if ((s = (char *) malloc(length)) == (char *) NULL) {
		return (char *) NULL;
	}
	strcpy(s, *block);
	*block += length;

	return s;
}
