#!/usr/bin/env perl
#
# Copyright (c) 2019 Todd Kover
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

#
# this script validates input for an addition, and in the event of problem,
# will send an error message and present the user with an opportunity to
# fix.
#

use strict;
use warnings;
use JazzHands::STAB;
use DBI::Const::GetInfoType;
use URI;

do_domain_update();

sub do_domain_update {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $dbh  = $stab->dbh          || die "Could not create dbh";

	my $domid          = $stab->cgi_parse_param('DNS_DOMAIN_ID');
	my $ip_universe_id = $stab->cgi_parse_param('IP_UNIVERSE_ID');
	my $genflip        = $stab->cgi_parse_param('AutoGen');
	my $resetns        = $stab->cgi_parse_param('Nameservers');

	if ( !defined($domid) ) {
		$stab->error_return("Unknown Domain");
	}

	# Default to universe 0 if not specified
	if ( !defined($ip_universe_id) ) {
		$ip_universe_id = 0;
	}

	if ( defined($genflip) ) {
		if ( $genflip =~ /Off/ ) {
			toggle_domain_autogen( $stab, $domid, $ip_universe_id, 'N' );
		} elsif ( $genflip =~ /On/ ) {
			toggle_domain_autogen( $stab, $domid, $ip_universe_id, 'Y' );
		} else {
			$stab->error_return("Unknown Command.");
		}
	}

	if ( defined($resetns) && $domid ) {
		my $sth = $dbh->prepare_cached(
			qq{
			SELECT dns_manip.add_ns_records(?, true)
		}
		) || $stab->return_db_err($dbh);

		$sth->execute($domid) || $stab->return_db_err($dbh);
		$sth->finish;
		$stab->commit;
		$stab->msg_return( "Successful update!", undef, 1 );
	}

	process_domain_soa_changes( $stab, $domid, $ip_universe_id );
}

sub toggle_domain_autogen {
	my ( $stab, $domid, $ip_universe_id, $direction ) = @_;
	my $dbh = $stab->dbh || die "Could not create dbh";

	my $sth = $stab->prepare_cached(
		qq{
		update dns_domain_ip_universe
		   set	should_generate = :direction
		 where	dns_domain_id = :dom
		   and  ip_universe_id = :ip_universe_id
	}
	) || $stab->return_db_err($dbh);
	$sth->bind_param( ':dom',            $domid ) || $stab->return_db_err($dbh);
	$sth->bind_param( ':ip_universe_id', $ip_universe_id )
	  || $stab->return_db_err($dbh);
	$sth->bind_param( ':direction', $direction ) || $stab->return_db_err($dbh);
	$sth->execute                                || $stab->return_db_err($dbh);

	$dbh->commit;
	$stab->msg_return( "Auto Generation Configuration Changed", undef, 1 );
	undef $stab;
}

sub process_domain_soa_changes {
	my ( $stab, $domid, $ip_universe_id ) = @_;
	my $dbh = $stab->dbh || die "Could not create dbh";

	my $serial  = $stab->cgi_parse_param( 'SOA_SERIAL',  $domid );
	my $refresh = $stab->cgi_parse_param( 'SOA_REFRESH', $domid );
	my $retry   = $stab->cgi_parse_param( 'SOA_RETRY',   $domid );
	my $expire  = $stab->cgi_parse_param( 'SOA_EXPIRE',  $domid );
	my $minimum = $stab->cgi_parse_param( 'SOA_MINIMUM', $domid );
	my $rname   = $stab->cgi_parse_param( 'SOA_RNAME',   $domid );
	my $mname   = $stab->cgi_parse_param( 'SOA_MNAME',   $domid );

	my $orig = $stab->get_dns_domain_from_id( $domid, $ip_universe_id );

	# Convert orig keys to lowercase to match DBUpdate expectations
	my %orig_lower = map { lc($_) => $orig->{$_} } keys %$orig;

	my %newdomain = (
		dns_domain_id  => $domid,
		ip_universe_id => $ip_universe_id,
		soa_serial     => $serial,
		soa_refresh    => $refresh,
		soa_retry      => $retry,
		soa_expire     => $expire,
		soa_minimum    => $minimum,
		soa_rname      => $rname,
		soa_mname      => $mname,
	);
	my $diffs = $stab->hash_table_diff( \%orig_lower, \%newdomain );
	my $tally = keys %$diffs;

	if ( !$tally ) {
		$stab->msg_return( "Nothing to Update", undef, 1 );
	} elsif ( !$stab->DBUpdate(
		table  => "dns_domain_ip_universe",
		dbkey  => [ "dns_domain_id", "ip_universe_id" ],
		keyval => [ $domid,          $ip_universe_id ],
		hash   => $diffs
	) )
	{
		$dbh->rollback;

		#$stab->error_return("Unknown Error with Update");
		$stab->return_db_err($dbh);
	} else {
		$dbh->commit;
		$stab->msg_return( "Successful update!", undef, 1 );
	}
}
