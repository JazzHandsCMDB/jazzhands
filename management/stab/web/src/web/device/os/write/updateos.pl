#!/usr/local/bin/perl
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
use JazzHands::STAB;
use URI;

do_os_update();

############################################################################

sub do_os_update {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";
	my $dbh  = $stab->dbh          || die "Could not create dbh";

	my $osid = $stab->cgi_parse_param('OPERATING_SYSTEM_ID');

	# print $cgi->header, $cgi->start_html, $cgi->Dump, $cgi->end_html;
	# exit;

	if ( !defined($osid) ) {
		$stab->error_return("Unspecified OS.  Try again.");
	}

	my $didstuff = 0;

	my $compid  = $stab->cgi_parse_param( 'COMPANY_ID',             $osid );
	my $name    = $stab->cgi_parse_param( 'NAME',                   $osid );
	my $version = $stab->cgi_parse_param( 'VERSION',                $osid );
	my $bits    = $stab->cgi_parse_param( 'PROCESSOR_ARCHITECTURE', $osid );

	my %newos = (
		OPERATING_SYSTEM_ID    => $osid,
		COMPANY_ID             => $compid,
		NAME                   => $name,
		VERSION                => => $version,
		PROCESSOR_ARCHITECTURE => $bits,
	);

	my $oldos = $stab->get_operating_system_from_id($osid);
	my $diffs = $stab->hash_table_diff( $oldos, \%newos );
	my $tally += keys %$diffs;
	$didstuff += $tally;

	if (
		$tally
		&& !$stab->build_update_sth_from_hash(
			"OPERATING_SYSTEM", "OPERATING_SYSTEM_ID",
			$osid,              $diffs
		)
	  )
	{
		$dbh->rollback;
		my $url = "../os.pl";
		$stab->error_return( "Unknown Error with Update", $url );
	}

	if ($didstuff) {
		$dbh->commit;
		my $refurl = "../os.pl?OPERATING_SYSTEM_ID=$osid";
		$stab->msg_return( "Device Updated", $refurl, 1 );
	} else {
		$stab->msg_return( "Nothing to do", undef, 1 );
		$dbh->rollback;
	}

	$dbh->rollback;
}
