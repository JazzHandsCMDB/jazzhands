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

#
# this script validates input for an addition, and in the event of problem,
# will send an error message and present the user with an opportunity to
# fix.
#

use strict;
use warnings;
use JazzHands::STAB;
use JazzHands::Common qw(:all);
use DBI::Const::GetInfoType;
use URI;

do_domain_update();

sub do_domain_update {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $dbh  = $stab->dbh          || die "Could not create dbh";

	my $domid   = $stab->cgi_parse_param('DNS_DOMAIN_ID');
	my $genflip = $stab->cgi_parse_param('AutoGen');

	if ( !defined($domid) ) {
		$stab->error_return("Unknown Domain");
	}

	if ( defined($genflip) ) {
		if ( $genflip =~ /Off/ ) {
			toggle_domain_autogen( $stab, $domid, 'N' );
		} elsif ( $genflip =~ /On/ ) {
			toggle_domain_autogen( $stab, $domid, 'Y' );
		} else {
			$stab->error_return("Unknown Command.");
		}
	}

	process_domain_soa_changes( $stab, $domid );
}

sub toggle_domain_autogen {
	my ( $stab, $domid, $direction ) = @_;
	my $dbh = $stab->dbh || die "Could not create dbh";

	my $sth = $stab->prepare_cached(
		qq{
		update dns_domain
		   set	should_generate = :direction
		 where	dns_domain_id = :dom
	}
	) || $stab->return_db_err($dbh);
	$sth->bind_param( ':dom', $domid ) || $stab->return_db_err($dbh);
	$sth->bind_param( ':direction', $direction )
	  || $stab->return_db_err($dbh);
	$sth->execute || $stab->return_db_err($dbh);

	$dbh->commit;
	$stab->msg_return( "Auto Generation Configuration Changed", undef, 1 );
	undef $stab;
}

sub process_domain_soa_changes {
	my ( $stab, $domid ) = @_;
	my $dbh = $stab->dbh || die "Could not create dbh";

	my $serial  = $stab->cgi_parse_param( 'SOA_SERIAL',  $domid );
	my $refresh = $stab->cgi_parse_param( 'SOA_REFRESH', $domid );
	my $retry   = $stab->cgi_parse_param( 'SOA_RETRY',   $domid );
	my $expire  = $stab->cgi_parse_param( 'SOA_EXPIRE',  $domid );
	my $minimum = $stab->cgi_parse_param( 'SOA_MINIMUM', $domid );
	my $rname   = $stab->cgi_parse_param( 'SOA_RNAME',   $domid );
	my $mname   = $stab->cgi_parse_param( 'SOA_MNAME',   $domid );

	my $orig      = $stab->get_dns_domain_from_id($domid);
	my %newdomain = (
		DNS_DOMAIN_ID => $domid,
		SOA_SERIAL    => $serial,
		SOA_REFRESH   => $refresh,
		SOA_RETRY     => $retry,
		SOA_EXPIRE    => $expire,
		SOA_MINIMUM   => $minimum,
		SOA_RNAME     => $rname,
		SOA_MNAMEUM   => $mname,
	);
	my $diffs = $stab->hash_table_diff( $orig, _dbx( \%newdomain ) );
	my $tally = keys %$diffs;

	if ( !$tally ) {
		$stab->msg_return( "Nothing to Update", undef, 1 );
	} elsif (
		!$stab->DBUpdate(
			table  => "DNS_DOMAIN",
			dbkey  => "DNS_DOMAIN_ID",
			keyval => $domid,
			hash   => $diffs
		)
	  )
	{
		$dbh->rollback;

		#$stab->error_return("Unknown Error with Update");
		$stab->return_db_err($dbh);
	} else {
		$dbh->commit;
		$stab->msg_return( "Successful update!", undef, 1 );
	}
}
