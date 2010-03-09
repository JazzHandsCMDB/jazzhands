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
 */

#ifndef __HOTPANTS_CRYPT_H
#define __HOTPANTS_CRYPT_H

#include <sys/types.h>

#ifndef __BIT_TYPES_DEFINED__
#define __BIT_TYPES_DEFINED__
typedef unsigned char u_int8_t;

typedef unsigned short u_int16_t;

typedef unsigned int u_int32_t;

typedef unsigned long long u_int64_t;

#endif

char *__md5crypt_r(const char *pw, const char *salt, char *password);	/* XXX */
char *__bcrypt_r(const char *, const char *, char *password);	/* XXX */
char *__crypt_sha1_r(const char *pw, const char *salt, char *password);
unsigned int __crypt_sha1_iterations(unsigned int hint);
void __hmac_sha1(unsigned char *, size_t, unsigned char *, size_t, unsigned char *);
void __crypt_to64(char *s, u_int32_t v, int n);

int __gensalt_blowfish(char *salt, size_t saltlen, const char *option);
int __gensalt_old(char *salt, size_t saltsiz, const char *option);
int __gensalt_new(char *salt, size_t saltsiz, const char *option);
int __gensalt_md5(char *salt, size_t saltsiz, const char *option);
int __gensalt_sha1(char *salt, size_t saltsiz, const char *option);
char *crypt_r(const char *key, const char *setting, char *cryptresult);
int
pw_gensalt(char *salt, size_t saltlen, const char *type,
    const char *option);
int des_setkey(const char *key);
int des_cipher(const char *in, char *out, long salt, int num_iter);


#define SHA1_MAGIC "$sha1$"
#define SHA1_SIZE 20

/*
 * $Id$
 *
 * Random definitions to get things to compile correctly outside of a BSD
 * source tree
 */

#ifndef __P
#define __P(x) x
#endif

#ifndef _PASSWORD_LEN
#define _PASSWORD_LEN 128
#endif

#ifndef	_PASSWORD_EFMT1
#define _PASSWORD_EFMT1     '_'	/* extended DES encryption format */
#endif

#ifndef _PASSWORD_NONDES
#define _PASSWORD_NONDES    '$'	/* non-DES encryption formats */
#endif

#ifndef __UNCONST
#define __UNCONST(a)    ((void *)(unsigned long)(const void *)(a))
#endif

u_int32_t arc4random __P(());

#endif				/* __HOTPANTS_CRYPT_H */
