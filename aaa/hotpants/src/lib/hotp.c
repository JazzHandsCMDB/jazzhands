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
#include <hotpants_internals.h>
#include <openssl/hmac.h>

#ifdef __MAIN__
#include <stdio.h>
#endif

#define SEQTEXTSIZE 8

static int doubleDigits[] = {0, 2, 4, 5, 8, 1, 3, 5, 7, 9};
static int DIGITS_POWER[] = {
	1,			/* 0 */
	10,			/* 1 */
	100,			/* 2 */
	1000,			/* 3 */
	10000,			/* 4 */
	100000,			/* 5 */
	1000000,		/* 6 */
	10000000,		/* 7 */
	100000000		/* 8 */
};

/*
 * calcChecksum() - calculates a credit-card-type checksum digit
 */

int
calcChecksum(long num, int digits)
{
	int doubleDigit = 1;
	int total = 0;
	int result;

	while (digits-- > 0) {
		int digit = (int) (num % 10);

		num /= 10;
		if (doubleDigit) {
			digit = doubleDigits[digit];
		}
		total += digit;
		doubleDigit = 1 - doubleDigit;
	}
	result = total % 10;
	if (result > 0) {
		result = 10 - result;
	}
	return result;
}

/*
 * generateHOTP() - generate an HOTP one time password for a token
 *
 *	  otp		pointer to pre-allocated buffer with enough space to hold
 *				  the OTP plus a null
 *    key		pointer to an HMAC-SHA1 key
 *	  key_len	length of the key
 *	  sequence	counter, time modulo, or other value that changes per-use
 *	  digits	number of digits in the OTP
 *	  checksum	add a checksum digit to the OTP
 *
 *	  returns 0 on success or an errno value on failure
 */

int
generateHOTP(char *otpstring, const void *key, u_int32_t key_len,
    u_int32_t sequence, u_int32_t otpDigits)
{

	unsigned int addChecksum = 0;
	int truncationOffset = -1;

	unsigned char seqtext[SEQTEXTSIZE];
	int i;
	unsigned char *md;
	char *str, *tempstr;
	unsigned int length;
	unsigned int offset;
	unsigned int binary;
	unsigned int digits;
	unsigned int otp;

	*otpstring = '\0';
	digits = addChecksum ? (otpDigits + 1) : otpDigits;

	/* Put sequence into a char array */

	for (i = (sizeof(seqtext) - 1); i >= 0; i--) {
		seqtext[i] = (unsigned char) (sequence & 0xff);
		sequence >>= 8;
	}

	if ((md = malloc(EVP_MAX_MD_SIZE + 1)) == NULL) {
		return ENOMEM;
	}
	HMAC(EVP_sha1(), key, key_len, seqtext, SEQTEXTSIZE, md, &length);

	offset = md[length - 1] & 0xf;

	if ((truncationOffset >= 0) && (truncationOffset < (length - 4))) {
		offset = truncationOffset;
	}
	binary =
	    ((md[offset] & 0x7f) << 24) |
	    ((md[offset + 1] & 0xff) << 16) |
	    ((md[offset + 2] & 0xff) << 8) |
	    (md[offset + 3] & 0xff);
	free(md);
	otp = binary % DIGITS_POWER[otpDigits];

	if (addChecksum) {
		otp = (otp * 10) + calcChecksum(otp, otpDigits);
	}
	if ((str = malloc(digits + 1)) == NULL) {
		return ENOMEM;
	}
	length = sprintf(str, "%d", otp);
	tempstr = otpstring;
	length = digits - length;
	while (tempstr != otpstring + length) {
		*tempstr++ = '0';
	}
	strcpy(tempstr, str);
	free(str);

	return 0;
}

#ifdef __MAIN__
int
main(int argc, char **argv)
{
	unsigned char key[32] = {
		0xa4,
		0x7f,
		0x3e,
		0xd5,
		0xcc,
		0x35,
		0x2c,
		0x90,
		0x69,
		0x27,
		0x92,
		0xeb,
		0xdd,
		0xf0,
		0x84,
		0x22,
		0xa5,
		0x97,
		0x12,
		0xe9,
		0xef,
		0x85,
		0x6d,
		0x00,
		0x79,
		0x69,
		0xd0,
		0x3c,
		0x87,
		0x9b,
		0xcd,
		0x88
	};
	char *key2 = "12345678901234567890";
	int seq = 0;
	char otp[8];

	for (seq = 0; seq <= 1000; seq++) {
		if (generateHOTP(otp, key2, strlen(key2), seq, 6)) {
			printf("Dude... it failed.  WTF?!\n");
			exit(1);
		}
		printf("OTP: %s\n", otp);
	}
	/*
	 * if (generateHOTP(otp, key, sizeof(key), seq, 6)) { printf
	 * ("Dude... it failed.  WTF?!\n"); exit(1); } printf("OTP: %s\n",
	 * otp); if (generateHOTP(otp, key, sizeof(key), seq+1, 6)) { printf
	 * ("Dude... it failed.  WTF?!\n"); exit(1); } printf("OTP: %s\n",
	 * otp);
	 */
	exit(0);
}

#endif
