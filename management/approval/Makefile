#
# Copyright (c) 2016, Todd M. Kover
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

PREFIX ?= ./usr/libexec/jazzhands/approval/

configure:
	echo Building perl modules
	cd lib && perl Makefile.PL INSTALLDIRS=vendor --default

all:
	echo Building perl modules
	cd lib && $(MAKE)

install:
	rm -rf $(DESTDIR)
	mkdir -p $(DESTDIR)/etc/init.d/

	install process-jira-issue-approvals.init.d $(DESTDIR)/etc/init.d/process-jira-issue-approvals
	install process-rt-queue-approvals.init.d $(DESTDIR)/etc/init.d/process-rt-queue-approvals
	install process-kace-queue-approvals.init.d $(DESTDIR)/etc/init.d/process-kace-queue-approvals

	install -d $(DESTDIR)/$(PREFIX)

	install approval-email.pl $(DESTDIR)/$(PREFIX)/approval-email
	install build-approvals.pl $(DESTDIR)/$(PREFIX)/build-approvals
	install process-rt-queue-approvals.pl $(DESTDIR)/$(PREFIX)/process-rt-queue-approvals
	install process-jira-issue-approvals.pl $(DESTDIR)/$(PREFIX)/process-jira-issue-approvals
	install process-kace-queue-approvals.pl $(DESTDIR)/$(PREFIX)/process-kace-queue-approvals

	# module stuff
	cd lib && make pure_install
	find $(DESTDIR) -type f -name .packlist -exec rm -f {} \;
	find $(DESTDIR) -depth -type d -exec rmdir {} 2>/dev/null \;

clean:
	cd lib && [ -f Makefile ]  && make distclean || true

distclean: clean
