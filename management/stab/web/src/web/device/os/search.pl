#!/usr/bin/env perl
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

use strict;
use warnings;
use FileHandle;
use JazzHands::STAB;
use JazzHands::Common::Util qw(_dbx);

do_os_search();

############################################################################3
#
# everything else is a subroutine
#
############################################################################3

sub do_os_search {
	my $stab = new JazzHands::STAB || die "Could not create STAB";

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $osid = $stab->cgi_parse_param('OPERATING_SYSTEM_ID');

	if ( !defined($osid) ) {
		$stab->error_return('Must specify a Composite OS ID');
	}

	my $os = $stab->get_operating_system_from_id($osid);

	if ( !defined($osid) ) {
		$stab->error_return('Unknown Operating System');
	}

	my $url = ".?OPERATING_SYSTEM_ID=" . $os->{_dbx('OPERATING_SYSTEM_ID')};
	print $cgi->redirect($url);
	undef $stab;
}
