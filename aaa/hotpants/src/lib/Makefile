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
ifeq ($(OS), SunOS)
	INSTALL=/usr/ucb/install
	CFLAGS=-I/usr/local/db4.4/include -I/usr/local/openssl-0.9.8/include -DSOLARIS
	LDFLAGS=-L/usr/local/db4.4/lib -R/usr/local/db4.4/lib -L/usr/local/openssl-0.9.8/lib -R/usr/local/openssl-0.9.8/lib -Lcrypto -R$(INSTALLDIR)/lib -lhotpants_crypto -lcrypto -ldb -lsocket -lnsl
endif
ifeq ($(OS), NetBSD)
	CFLAGS=-I/usr/pkg/include/db4
	LDFLAGS=-L/usr/pkg/lib -R/usr/pkg/lib -Lcrypto -lhotpants_crypt -ldb4
endif
CC=cc
DEBUG=-g

CFLAGS+=-I../include
COMMON_SRCS=db.c serialize.c base64.c user.c token.c config.c auth.c hotp.c \
	error.c
DBTEST_SRCS=dbtest.c
AUTHTEST_SRCS=authtest.c

all: crypto libhotpants.so
	
.PHONY: crypto clean
SUBDIRS=crypto

crypto/libhotpants_crypto.so: crypto

$(SUBDIRS):
	cd $@; gmake

OBJS=db.o serialize.o base64.o user.o token.o auth.o config.o hotp.o error.o


$(OBJS): ../include/hotpants.h
$(OBJS): %.o: %.c
	$(CC) -c $(CFLAGS) $(DEBUG) -Kpic $< -o $@

auth.o: ../include/hotpants.h ../include/hotpants_internals.h

libhotpants.so: crypto/libhotpants_crypto.so $(OBJS)
	ld -G -o $@ $(LDFLAGS) $(OBJS)

dbtest: libhotpants.so dbtest.o
	$(CC) -o $@ $(DEBUG) $(OBJS) dbtest.o -L. -lhotpants

authtest.o: authtest.c ../include/hotpants.h
	$(CC) -c $(CFLAGS) $(DEBUG) authtest.c

authtest: libhotpants.so authtest.o
	$(CC) -o $@ $(DEBUG) authtest.o -L. -Lcrypto -R`pwd` -lhotpants

clean:
	cd crypto; gmake clean
	rm -f $(OBJS) dbtest.o authtest.o
	rm -f libhotpants.so
	rm -f dbtest authtest hotp

depend:
	mkdep -- ${CFLAGS} ${COMMON_SRCS} ${DBTEST_SRCS}
