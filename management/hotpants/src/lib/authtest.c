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
#include <unistd.h>
#include <hotpants.h>

int
main(int argc, char **argv)
{
	HOTPants_DB *hdb;
	int ret;
	char user[60], *pass;

	if ((ret = hp_initialize("../test", &hdb, NULL))) {
		fprintf(stderr, "Unable to initialize HOTPants!\n");
		exit(1);
	}
	while (1) {
		fprintf(stderr, "Username: ");
		if (!fgets(user, sizeof(user), stdin)) {
			break;
		}
		if (!(pass = getpassphrase("OTP: "))) {
			break;
		}
		if (user[strlen(user) - 1] == '\n') {
			user[strlen(user) - 1] = '\0';
		}
		fprintf(stderr, "Checking to see if user %s is valid... ", user);
		ret = hp_check_user(hdb, user);
		if (ret == HP_SUCCESS) {
			fprintf(stderr, "indeed\n");
		} else {
			fprintf(stderr, "not so much: %s\n", hp_strerror(ret));
		}


		fprintf(stderr, "Attempting to auth %s with PIN %s\n", user, pass);
		ret = hp_authenticate(hdb, user, pass);
		if (ret == HP_SUCCESS) {
			fprintf(stderr, "You're cool.  Come on in.\n");
		} else {
			fprintf(stderr, "Dude, you suck: %s\n", hp_strerror(ret));
		}
	}
	hp_finalize(hdb);
}
