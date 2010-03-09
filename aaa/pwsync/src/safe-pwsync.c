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
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>

#define BUFSIZE	8192

int
main(int argc, char *argv[])
{
	char buf[BUFSIZE], *p;
	char **cmdargs;
	int i;

	putenv("PATH=/usr/bin:/bin");
	putenv("IFS=");

	strcpy(buf, argv[0]);
	p = strrchr(buf, '/');
	if (!p) {
		getcwd(buf, BUFSIZE);
		p = buf + strlen(buf);
	}
	strcpy(p, "/../../hidden/pwsync");

	cmdargs = malloc((argc + 1) * sizeof(cmdargs[0]));

	if (!cmdargs) {
		fprintf(stderr, "Out of Memory!!\n");
	}
	cmdargs[0] = buf;
	for (i = 1; i < argc; i++) {
		cmdargs[i] = argv[i];
	}
	cmdargs[i++] = NULL;

	execv(buf, cmdargs);
	fprintf(stderr, "Chaos!  I failed to execute the real deal: (%s)!\n", buf);
	exit(1);
}
