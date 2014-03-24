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
/* stuff */

#include <stdio.h>
#include <stdlib.h>
#include "hotpants_crypt.h"

int
main(int argc, char **argv)
{
	char *pass;
	char *salt;
	char *hash;

	if ((salt = malloc(_PASSWORD_LEN)) == NULL) {
		fprintf(stderr, "Things suck\n");
	}
	if ((hash = malloc(_PASSWORD_LEN)) == NULL) {
		fprintf(stderr, "Things suck\n");
	}
	if ((pass = malloc(_PASSWORD_LEN)) == NULL) {
		fprintf(stderr, "Things suck\n");
	}
	if (pw_gensalt(salt, _PASSWORD_LEN, "sha1", "0") == -1) {
		fprintf(stderr, "Couldn't generate salt\n");
		exit(-1);
	};

	pass = "eatme";

	if (crypt_r(pass, salt, hash) == NULL) {
		fprintf(stderr, "Couldn't generate password\n");
		exit(-1);
	};

	printf("Salt: %s, Hash: %s\n", salt, hash);

	if (pw_gensalt(salt, _PASSWORD_LEN, "blowfish", "10") == -1) {
		fprintf(stderr, "Couldn't generate salt\n");
		exit(-1);
	};

	if (crypt_r(pass, salt, hash) == NULL) {
		fprintf(stderr, "Couldn't generate password\n");
		exit(-1);
	};

	printf("Salt: %s, Hash: %s\n", salt, hash);

	if (pw_gensalt(salt, _PASSWORD_LEN, "md5", NULL) == -1) {
		fprintf(stderr, "Couldn't generate salt\n");
		exit(-1);
	};

	if (crypt_r(pass, salt, hash) == NULL) {
		fprintf(stderr, "Couldn't generate password\n");
		exit(-1);
	};

	printf("Salt: %s, Hash: %s\n", salt, hash);

	if (pw_gensalt(salt, _PASSWORD_LEN, "old", NULL) == -1) {
		fprintf(stderr, "Couldn't generate salt\n");
		exit(-1);
	};

	if (crypt_r(pass, salt, hash) == NULL) {
		fprintf(stderr, "Couldn't generate password\n");
		exit(-1);
	};

	printf("Salt: %s, Hash: %s\n", salt, hash);

}
