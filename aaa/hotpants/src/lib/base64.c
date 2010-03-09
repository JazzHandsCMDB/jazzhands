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
 * HOTPants routines to do base64 encoding/decoding
 * to the database
 *
 */

#include <hotpants.h>
#include <strings.h>

char *base64_encode __P((HPData *));
HPData *base64_decode __P((char *));
void __init_base64 __P(());

int __base64_initted = 0;
unsigned char __base64_encode_table[64];
unsigned char __base64_decode_table[255];

char *
base64_encode(HPData * d)
{
	unsigned char *buf, *in, *out;
	unsigned int size;
	unsigned int i;

	if (!__base64_initted) {
		__init_base64();
	}
	if (!d) {
		return (char *) NULL;
	}
	in = d->data;
	size = d->size;

	/*
	 * Allocate memory for base64 string.  This will always be no more
	 * than ((size / 3  + 1) * 4) + 3
	 */

	if ((buf = (unsigned char *) malloc(((d->size / 3 + 1) * 4) + 3)) == NULL) {
		return (char *) NULL;
	}
	out = buf;
	for (i = 0; i < size; i += 3) {
		out[0] = __base64_encode_table[in[0] >> 2];
		out[1] = __base64_encode_table[((in[0] & 3) << 4) |
		    (((i + 1 < d->size) ? in[1] : 0) >> 4)];
		out[2] = (i + 1 < size) ? __base64_encode_table[
		    ((in[1] & 0xf) << 2) | (((i + 2 < size) ? in[2] : 0) >> 6)] : '=';
		out[3] = (i + 2 < size) ? __base64_encode_table[in[2] & 0x3f] : '=';
		in += 3;
		out += 4;
	}

	*out = '\0';

	return (char *) buf;

}

HPData *
base64_decode(char *in)
{
	HPData *d;
	unsigned char *out, *buf;
	unsigned int i, size;

	if (!__base64_initted) {
		__init_base64();
	}
	if (!in) {
		return (HPData *) NULL;
	}
	if ((d = (HPData *) malloc(sizeof(HPData))) == (HPData *) NULL) {
		return (HPData *) NULL;
	}
	size = strlen(in);
	d->size = (size / 4) * 3;
	if ((buf = (unsigned char *) malloc(d->size)) ==
	    (unsigned char *) NULL) {
		free(d);
		return (HPData *) NULL;
	}
	d->data = out = buf;

	for (i = 0; i < size; i += 4) {
		out[0] = ((__base64_decode_table[in[0]]) << 2) |
		    ((__base64_decode_table[in[1]]) >> 4);
		out[1] = ((__base64_decode_table[in[1]]) << 4) |
		    ((__base64_decode_table[in[2]]) >> 2);
		out[2] = ((__base64_decode_table[in[2]]) << 6) |
		    (__base64_decode_table[in[3]]);
		if (in[3] == '=') {
			d->size--;
		}
		if (in[2] == '=') {
			d->size--;
		}
		out += 3;
		in += 4;
	}

	return d;
}

void
__init_base64()
{
	int i;

	memset(__base64_decode_table, 0xff, 256);

	for (i = 0; i < 26; i++) {
		__base64_encode_table[i] = 'A' + i;
		__base64_decode_table['A' + i] = i;
		__base64_encode_table[26 + i] = 'a' + i;
		__base64_decode_table['a' + i] = 26 + i;
	}
	for (i = 0; i <= 9; i++) {
		__base64_encode_table[52 + i] = '0' + i;
		__base64_decode_table['0' + i] = 52 + i;
	}
	__base64_encode_table[62] = '+';
	__base64_decode_table['+'] = 62;
	__base64_encode_table[63] = '/';
	__base64_decode_table['/'] = 63;
	__base64_decode_table['='] = 0;

	__base64_initted = 1;
}
