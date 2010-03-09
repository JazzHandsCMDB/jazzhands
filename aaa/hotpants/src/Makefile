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

# $Id$
#
OS=$(shell uname -s)

ifeq ($(OS), SunOS)
INSTALL=/usr/ucb/install
else
INSTALL=/usr/bin/install
endif

INSTALLDIR=/prod/hotpants
BINDIR=$(INSTALLDIR)/bin
LIBDIR=$(INSTALLDIR)/lib
LIBEXECDIR=$(INSTALLDIR)/libexec
INCLUDEDIR=$(INSTALLDIR)/include

BINS=insertaladdindata tokutil synctokendata


all:
	cd perl && perl Makefile.PL && make
	cd lib && $(MAKE) INSTALLDIR=$(INSTALLDIR)

install:
	$(INSTALL) -o root -g bin -m 755 -d $(DESTDIR)/$(BINDIR)
	$(INSTALL) -o root -g bin -m 755 -d $(DESTDIR)/$(LIBDIR)
	$(INSTALL) -o root -g bin -m 755 -d $(DESTDIR)/$(INCLUDEDIR)
	$(INSTALL) -c -o root -g bin -m 444 include/hotpants.h \
		$(DESTDIR)/$(INCLUDEDIR)
	$(INSTALL) -c -o root -g bin -m 444 lib/libhotpants.so \
		$(DESTDIR)/$(LIBDIR)
	$(INSTALL) -c -o root -g bin -m 444 lib/crypto/libhotpants_crypto.so \
		$(DESTDIR)/$(LIBDIR)
	$(INSTALL) -c -o root -g bin -m 444 libexec/hotpants_rlm.pm \
		$(DESTDIR)/$(LIBEXECDIR)
	for file in $(BINS); do \
		$(INSTALL) -c -o root -g bin -m 555 bin/$${file}.pl \
			$(DESTDIR)/$(BINDIR)/$${file}; \
	done
	cd perl && $(MAKE) -e install

clean:
	cd perl && $(MAKE) clean
	cd lib && $(MAKE) clean
