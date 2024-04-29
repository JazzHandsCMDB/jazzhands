#!/usr/bin/env perl
#
# Copyright (c) 2017 Todd Kover
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
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

#
# $Id$
#
# given a dns domain, find it and return a pointer to it, or return an
# error

use strict;
use warnings;
use JazzHands::STAB;
use URI;

do_domain_search();

sub do_domain_search {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";
	my $dbh  = $stab->dbh          || die "Could not create dbh";

	# The domain id parameter is supplied if the Go to Zone button is clicked
	# But not if the Go to Record button is clicked
	my $dnsdomid = $stab->cgi_parse_param('DNS_DOMAIN_ID');

	# The dnssearch parameter is supplied if the Go to Record button is clicked
	my $dnssearch = $stab->cgi_parse_param('DNS_SEARCH_RECORD_ID');

	# The addonly parameter is supplied if the Add Record (do not view zone) button is clicked
	my $addonly = $stab->cgi_parse_param('addonly');
	if ($addonly) {
		$addonly = ';addonly=1';
	} else {
		$addonly = '';
	}

	# Override the domain id from the record id if the dnssearch parameter is supplied
	if ($dnssearch) {
		my $dnsrecord = $stab->get_dns_record_from_id($dnssearch);
		$dnsdomid  = $dnsrecord->{'dns_domain_id'};
		$dnssearch = ';dnssearch=' . $dnssearch;
	} else {
		$dnssearch = '';
	}

	my $url = "index.pl?dnsdomainid=$dnsdomid$addonly$dnssearch";
	$cgi->redirect($url);
	undef $stab;
}
