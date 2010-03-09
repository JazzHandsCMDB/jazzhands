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

BINDIR=/usr/local/bin
LIBEXECDIR=/usr/site/libexec/acct-mgmt
INSTALL=/usr/ucb/install
OUTDIR=/prod/pwgen
DAILYDIR=/usr/site/libexec/daily-scripts

GROUP=jazzhands

PERL_BINFILES= appltool consacltool forceadcreate sudotool syncadaccts tokentool
SH_BINFILES=force-mkfiles
LIBEXEC_PL_FILES=mkpasswdfiles syncadaccts

all:

install:
	[ -d $(DESTDIR)/$(BINDIR) ] | mkdir  -p $(DESTDIR)/$(BINDIR)
	[ -d $(DESTDIR)/$(LIBEXECDIR) ] | mkdir  -p $(DESTDIR)/$(LIBEXECDIR)
	[ -d $(DESTDIR)/$(OUTDIR) ] | mkdir -p $(DESTDIR)/$(OUTDIR)
	for i in $(PERL_BINFILES) ; do \
		$(INSTALL) -c -o root -g $(GROUP) -m 550 $${i}.pl $(DESTDIR)/$(BINDIR)/$$i ;\
	done
	for i in $(SH_BINFILES) ; do \
		$(INSTALL) -c -o root -g $(GROUP) -m 550 $${i}.sh $(DESTDIR)/$(BINDIR)/$$i ;\
	done
	for i in $(LIBEXEC_PL_FILES) ; do \
		$(INSTALL) -c -o root -g bin -m 555 $${i}.pl $(DESTDIR)/$(LIBEXECDIR)/$$i ;\
	done

	# override ownership for tokenmgr and applmgr

	chgrp tokenmgmt $(DESTDIR)/$(BINDIR)/tokenmgr
	chgrp applmgr $(DESTDIR)/$(BINDIR)/applmgr

	chmod 555 $(DESTDIR)/$(BINDIR)/force-mkfiles

clean:
