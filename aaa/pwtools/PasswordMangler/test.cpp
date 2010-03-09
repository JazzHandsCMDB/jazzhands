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
// ADTest.cpp : Defines the entry point for the console application.
//

#include <stdio.h>
#include <tchar.h>
#include <windows.h>
#include <string.h>
#include <ntsecapi.h>

extern DWORD FindUser(_TCHAR *);
extern BOOL NTAPI PasswordFilter( PUNICODE_STRING UserName, PUNICODE_STRING FullName, PUNICODE_STRING Password, BOOL SetOperation );
extern BOOL NTAPI InitializeChangeNotify(void);

int _tmain(int argc, _TCHAR *argv[])
{
	UNICODE_STRING user, pass;
	DWORD UserID;

	if (argc < 3) {
		printf ("Usage: %s <user>\n", argv[0]);
		return -1;
	}
	if (!InitializeChangeNotify()) {
		printf("Totally didn't initialize\n");
		return -1;
	}

	if (UserID = FindUser(argv[1])) {
		printf("SystemUserID for %ls is %d\n", argv[1], UserID);
	} else {
		printf("No SystemUserID for %ls\n", argv[1]);
	}
	user.Buffer = argv[1];
	user.Length = (USHORT)(wcslen(argv[1]) * sizeof(_TCHAR));
	user.MaximumLength = user.Length;

	pass.Buffer = argv[2];
	pass.Length = (USHORT)(wcslen(argv[2]) * sizeof(_TCHAR));
	pass.MaximumLength = pass.Length;

	if (PasswordFilter(&user, NULL, &pass, FALSE)) {
		printf("Hey, it worked\n");
	} else {
		printf("Totally failed!\n");
	}
	
	return 0;
}
