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
 * Token manipulation routines for HOTPants
 *
 */

#include <hotpants.h>


static char __chartohex[16] =
{'0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
'a', 'b', 'c', 'd', 'e', 'f'};

void free_token(Token *);

void
free_token(Token * token)
{

	/* Destroy all token data structures, then the token itself */

	if (token->serial) {
		free(token->serial);
	}
	if (token->key) {
		if (token->key->data) {
			free(token->key->data);
		}
		free(token->key);
	}
	if (token->PIN) {
		free(token->PIN);
	}
	free(token);
}

/*
 *	keytohex - convert a wad of binary data to hex digits separated by a
 *		colon.  'key' is the structure containing the size and data, and
 *		'out' is a pointer to preallocated data to hold the string.  The
 *		size of the string is always exactly 3 * the size of the data,
 *		including terminating null.
 *
 *	This should probably be moved elsewhere and renamed 'bintohex', but
 *	it's only ever used to spit out printable keys
 */

void
keytohex(HPData * key, char *out)
{
	char *cursor;
	int size;

	size = key->size;
	cursor = key->data;
	for (cursor = key->data; size--; cursor++) {
		*(out++) = __chartohex[*cursor >> 4 & 0xf];
		*(out++) = __chartohex[*cursor & 0xf];
		*(out++) = ':';
	}
	*(--out) = '\0';
}
