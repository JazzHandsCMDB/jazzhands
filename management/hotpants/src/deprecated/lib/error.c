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
 * error routines for HOTPants
 *
 */

#include <hotpants_internals.h>

/*
 * char *hp_strerror(int error)
 *
 * returns a static error string representation of an error number
 */

char *
hp_strerror(int error)
{
	char *p;

	if (error == 0)
		return ("Success");
	if (error > 0) {
		if ((p = strerror(error)) != NULL)
			return (p);
		else
			return ("Unknown error?!");
	}
	/* Catch the BDB errors */

	if (error >= -30999 && error <= -30800) {
		return (db_strerror(error));
	}
	switch (error) {
	case HP_GENERIC_AUTH_FAILURE:
		return ("HP_GENERIC_AUTH_FAILURE: Unspecified auth failure");
	case HP_NEXT_OTP:
		return
		    ("HP_NEXT_OTP: sequence skew - next OTP required for validation");
	case HP_TOKEN_NOTFOUND:
		return ("HP_TOKEN_NOTFOUND: Token not found in database");
	case HP_USER_NOTFOUND:
		return ("HP_USER_NOTFOUND: User not found in database");
	case HP_BAD_PIN:
		return ("HP_BAD_PIN: PIN does not match an assigned token");
	case HP_BAD_OTP:
		return ("HP_BAD_OTP: OTP given does not match an expected sequence");
	case HP_PIN_NOT_SET:
		return ("HP_PIN_NOT_SET: PIN must be set prior to use");
	case HP_CONFIG_ERROR:
		return ("HP_CONFIG_ERROR: Error in configuration database");
	case HP_USER_DISABLED:
		return ("HP_USER_DISABLED: User has been disabled");
	case HP_USER_LOCKED:
		return ("HP_USER_LOCKED: User is locked");
	case HP_TOKEN_DISABLED:
		return ("HP_TOKEN_DISABLED: Token has been disabled");
	case HP_TOKEN_LOCKED:
		return ("HP_TOKEN_LOCKED: Token is locked");
	case HP_DB_WRITE_ERROR:
		return ("HP_DB_WRITE_ERROR: Unable to write database entry");
	case HP_DB_READ_ERROR:
		return ("HP_DB_READ_ERROR: Unable to read database entry");
	default:
		break;
	}
	return ("Unknown error?!");
}
