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

PL_SCRIPTS = change-passwd change-netdev-passwd index

TEXT = choosing-good-passwords.html

HIDDEN_SCRIPTS = commit-cpw commit-cnpw

PROG = safe-commit-cpw
NETPROG= safe-commit-cnpw

SRCS = safe-commit-cpw.c
NETSRCS = safe-commit-cnpw.c

INSTALL = /usr/ucb/install

SCRIPT_DEST = /prod/www/WWW.EXAMPLE.COM/data/accounts
CGI_DEST = /prod/www/WWW.EXAMPLE.COM/cgi-bin/accounts

HIDDEN_DEST = /prod/www/WWW.EXAMPLE.COM/hidden/accounts

all: $(PROG) $(NETPROG)

$(PROG): $(SRCS)
	cc -o $@ $(SRCS)

$(NETPROG): $(NETSRCS)
	cc -o $@ $(NETSRCS)

install:
	$(INSTALL) -d -o root -g bin $(DESTDIR)/$(SCRIPT_DEST)
	$(INSTALL) -d -o root -g bin $(DESTDIR)/$(CGI_DEST)
	$(INSTALL) -d -o root -g bin $(DESTDIR)/$(HIDDEN_DEST)
	for file in $(PL_SCRIPTS) ; do \
		$(INSTALL) -o root -g bin -m 555 $$file.pl $(DESTDIR)/$(SCRIPT_DEST)/$$file.pl ;\
	done
	for file in $(TEXT) ; do \
		$(INSTALL) -o root -g bin -m 555 $$file $(DESTDIR)/$(SCRIPT_DEST)/$$file ;\
	done
	for file in $(PROG) ; do \
		$(INSTALL) -o root -g bin -m 555 $$file $(DESTDIR)/$(CGI_DEST)/$$file ;\
	done
	for file in $(NETPROG) ; do \
		$(INSTALL) -o root -g bin -m 555 $$file $(DESTDIR)/$(CGI_DEST)/$$file ;\
	done
	for file in $(HIDDEN_SCRIPTS) ; do \
		$(INSTALL) -o root -g bin -m 555 $$file.pl $(DESTDIR)/$(HIDDEN_DEST)/$$file.pl ;\
	done

clean:
	rm -f $(PROG) $(NETPROG) *.o


