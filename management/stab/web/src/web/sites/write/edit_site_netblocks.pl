#!/usr/bin/env perl
# Copyright (c) 2023 Todd M. Kover

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
# $Id$
#

use strict;
use warnings;
use FileHandle;
use JazzHands::STAB;
use JazzHands::Common qw(:all);
use Data::Dumper;

process_site_netblocks();

#############################################################################
#
# only subroutines below here.
#
#############################################################################

sub process_site_netblocks {
	my $stab = new JazzHands::STAB;

	my $cgi = $stab->cgi;

	#print $cgi->header, $cgi->start_html, $cgi->Dump, $cgi->end_html; exit;
	#print $cgi->header, $cgi->start_html;

	#print $cgi->end_html; exit;

	my $numchanges = 0;

	# Get the site code
	my $site_code = $cgi->param('sitecode');

	# Process deletion requests
	foreach my $netblock_id ( $stab->cgi_get_ids('SITE_NETBLOCK_DELETE') ) {
		if ( $stab->cgi_parse_param("SITE_NETBLOCK_DELETE_$netblock_id") eq
			'delete' )
		{
			$numchanges +=
			  delete_site_netblock( $stab, $site_code, $netblock_id );
		}
	}

	# Process update requests
	# Note: there is nothing to edit for now
	my $sn_ip;

	#my $sn_desc;

	#foreach my $id ( $cgi->param( 'CHANGED_ELEMENTS' ) ) {
	#	#$sn_ip      = $stab->cgi_parse_param("SITE_NETBLOCK_START_IP_$id");
	#	$sn_desc          = $stab->cgi_parse_param("SITE_NETBLOCK_DESCRIPTION_$id");
	#	$numchanges += update_site_netblock(
	#		$stab,
	#		$id,
	#		#$sn_ip,
	#		$sn_desc
	#	);
	#}

	# Process addition request
	$sn_ip = $stab->cgi_parse_param("SITE_NETBLOCK_IP_NEW");

	#$sn_desc = $stab->cgi_parse_param("SITE_NETBLOCK_DESCRIPTION_NEW");

	if ($sn_ip) {
		$numchanges += create_site_netblock( $stab, $site_code, $sn_ip );
	}

	#print $cgi->end_html;

	if ( $numchanges > 0 ) {

		#my $url = "../?sitecode=$site_code";
		$cgi->delete_all;
		$stab->commit || die $stab->return_db_err;
		$stab->msg_return( "$numchanges changes commited", undef, 1 );
	}

	$stab->rollback;
	$stab->msg_return( "There were no changes.", undef, 1 );
	undef $stab;
}

sub delete_site_netblock {
	my ( $stab, $site_code, $sn_netblock_id ) = @_;

	# Delete the specified site netblock association
	my $q = qq{
		delete from site_netblock where site_code = ? and netblock_id = ?
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($stab);
	$sth->execute( $site_code, $sn_netblock_id )
	  || $stab->return_db_err($sth);
	1;
}

# Currently unused
sub update_site_netblock {
	my ( $stab, $sn_id, $sn_desc ) = @_;

	#my $orig = $stab->get_site_netblock_from_id( $sn_ip );

	print $sn_id, $sn_desc, "<br/>\n";

	# Get the netblock from the ip
	#my $netblock_id = $stab->get_netblock_from_ip( ip_address => $sn_ip );
	#print Dumper($netblock_id), "<br/>\n";

	# Update the site netblock
	my $q = qq{
		update site_netblock
		set description = ?
		where site_netblock_id = ?
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($stab);
	$sth->execute( $sn_desc, $sn_id )
	  || $stab->return_db_err($sth);

	#my $new = {
	#	SITE_NETBLOCK_ID   => $sn_id,
	#	START_NETBLOCK_ID  => $start_netblock_id,
	#	STOP_NETBLOCK_ID   => $stop_netblock_id,
	#	LEASE_TIME         => $sn_lease_time,
	#	DNS_PREFIX         => $sn_dns_prefix,
	#	DNS_DOMAIN_ID      => $sn_dns_domain_id,
	#	SITE_NETBLOCK_TYPE => $sn_type,
	#	DESCRIPTION        => $sn_desc
	#};
	#my $diffs = $stab->hash_table_diff( $orig, _dbx($new) );
	#my $tally = keys %$diffs;
	#if ($tally) {
	#	$stab->run_update_from_hash( 'SITE_NETBLOCK', 'SITE_NETBLOCK__ID',
	#		$sn_id, $diffs )
	#	  || die $stab->return_db_err();
	#}
	#$tally;
	1;
}

sub create_site_netblock {
	my ( $stab, $site_code, $sn_ip ) = @_;

	# Get the netblock for the specified ip
	my $nb = $stab->get_netblock_from_ip( ip_address => $sn_ip );

	# If no matching netblock was found, abort here
	if ( !$nb ) {
		$stab->error_return(
			"ERROR: the ip $sn_ip doesn't correpond to an existing netblock");
	}
	my $netblock_id = $nb->{ _dbx('NETBLOCK_ID') };

	my $q = qq{
		insert into site_netblock
			(site_code, netblock_id)
		values
			(?, ?);
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($stab);
	$sth->execute( $site_code, $netblock_id )
	  || $stab->return_db_err($sth);

	1;
}

