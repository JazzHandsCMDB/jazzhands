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

STAB_DIR=/prod/stab/libexec/graphs

SUBDIRS=

SCRIPTS = daily-composite.pl daily-function.pl daily-mclass.pl \
	daily-stab-stats.sh graph-baseline.pl graph-devtotals.pl \
	graph-mclasstotals.pl


all:
	@echo nothing to do
	@#for subdir in $(SUBDIRS) ; do \
	@#	( cd $$subdir && $(MAKE) -e $(MFLAGS) all) 
	@#done

install:
	install -d -o root -g bin -m 755 $(DESTDIR)/$(STAB_DIR)
	@#for subdir in $(SUBDIRS) ; do \
	@#	here=`pwd` ;\
	@#	cd $$subdir && $(MAKE) -e $(MFLAGS) install ;\
	@#	cd $$here ;\
	@#done
	for script in $(SCRIPTS) ; do \
		echo 1>&2 installing $$script into $(DESTDIR)/$(STAB_DIR) ;\
		install -o root -g bin -m 755 $$script $(DESTDIR)/$(STAB_DIR)/$$script ;\
	done

clean:
	@echo nothing to do
