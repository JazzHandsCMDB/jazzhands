#
# Copyright (c) 2005-2010, Vonage Holdings Corp.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Makefile for HOTPants
#

OS=$(shell uname -s)

LDFLAGS += -L.
#CFLAGS += -DDEBUG
CFLAGS += -Dlibcrypto
LIBS +=-lhotpants_crypto

ifeq ($(OS), SunOS)
	CFLAGS += -DSOLARIS -DBYTE_ORDER=BIG_ENDIAN -I/usr/local/openssl-0.9.8/include
	LDFLAGS += -L/usr/local/openssl-0.9.8/lib -R/usr/local/openssl-0.9.8/lib
	LIBS += -lcrypto
	PIC = -Kpic
else
	LIBS += -lcrypto
	PIC = -fpic
endif
CC=cc
DEBUG=-g

VPATH=hash/md2:hash/md5:hash/rmd160:hash/sha1:hash/sha2:crypt

#CFLAGS+=-I../include

OBJS=md2.o hmac_md5.o rmd160.o hmac_sha1.o sha1.o sha2.o bcrypt.o blowfish.o \
	crypt-sha1.o md5crypt.o pw_gensalt.o arc4random.o md5c.o util.o crypt.o

all: libhotpants_crypto.so

$(OBJS): %.o: %.c
	$(CC) $(DEBUG) -I. -I$(<D) $(PIC) -c $(CFLAGS) $< -o $@

libhotpants_crypto.a: $(OBJS)
	ar rcu libhotpants_crypto.a $(OBJS)

libhotpants_crypto.so: $(OBJS)
	ld -G -o $@ $(OBJS)

test: test.c libhotpants_crypto.a
	$(CC) $(DEBUG) -I. $(CFLAGS) $< -o $@ $(LDFLAGS) $(LIBS)

.PHONY: clean

clean:
	rm -rf $(OBJS) libhotpants_crypto.so libhotpants_crypto.a test

