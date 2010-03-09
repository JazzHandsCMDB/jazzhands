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

PL_SCRIPTS = syncpw index set-token-pin

SUPPORT_SCRIPTS = pwsync

PROG = safe-pwsync

SRCS = safe-pwsync.c

INSTALL = /usr/ucb/install

CGI_DEST = /prod/www/WWW.EXAMPLE.COM/cgi-bin
SUPPORT_DEST = /prod/www/WWW.EXAMPLE.COM/hidden
DOC_ROOT = /prod/www/WWW.EXAMPLE.COM/data

all: $(PROG)

$(PROG): $(SRCS)
	cc -o $@ $(SRCS)

install:
	$(INSTALL) -d -o root -g bin $(DESTDIR)/$(CGI_DEST)
	$(INSTALL) -d -o root -g bin $(DESTDIR)/$(SUPPORT_DEST)
	$(INSTALL) -d -o root -g bin $(DESTDIR)/$(DOC_ROOT)
	for file in $(PROG) ; do \
		$(INSTALL) -o root -g bin -m 555 $$file $(DESTDIR)/$(CGI_DEST)/$$file ;\
	done
	for file in $(SUPPORT_SCRIPTS) ; do \
		$(INSTALL) -o root -g bin -m 555 $$file.pl $(DESTDIR)/$(SUPPORT_DEST)/$$file ;\
	done
	for file in $(PL_SCRIPTS) ; do \
		$(INSTALL) -o root -g bin -m 555 $$file.pl $(DESTDIR)/$(DOC_ROOT)/$$file.pl ;\
	done

clean:
	rm -f safe-pwsync *.o

