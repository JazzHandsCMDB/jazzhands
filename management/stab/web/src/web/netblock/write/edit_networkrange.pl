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
use Data::Dumper;

process_network_ranges();

#############################################################################
#
# only subroutines below here.
#
#############################################################################

sub process_network_ranges {
	my $stab = new JazzHands::STAB;

	my $cgi = $stab->cgi;

	#print $cgi->header, $cgi->start_html, $cgi->Dump, $cgi->end_html; exit;
	#print $cgi->header, $cgi->start_html, $cgi->Dump;

	my $numchanges = 0;

	# We now need to get all the cgi data to be processed
	# because we want to empty it to avoid urls being too long

	# Get items to delete
	my @todelete;
	foreach my $id ( $stab->cgi_get_ids('NETWORK_RANGE_DELETE') ) {
		my $bDelete = $stab->cgi_parse_param( 'NETWORK_RANGE_DELETE_' . $id );
		if ( !defined($bDelete) || $bDelete ne 'delete' ) { next; }
		push( @todelete, $id );
	}

	# Get ids of changed items, both updated and new
	my @ids = split( ',', $cgi->param('CHANGED_ELEMENTS_IDS') );
	my %changed;
	foreach my $id (@ids) {
		$changed{$id} = {
			'NETWORKRANGE_START_IP' =>
			  $stab->cgi_parse_param("NETWORKRANGE_START_IP_$id"),
			'NETWORKRANGE_STOP_IP' =>
			  $stab->cgi_parse_param("NETWORKRANGE_STOP_IP_$id"),
			'NETWORKRANGE_LEASE_TIME' =>
			  $stab->cgi_parse_param("NETWORKRANGE_LEASE_TIME_$id"),
			'NETWORKRANGE_DNS_PREFIX' =>
			  $stab->cgi_parse_param("NETWORKRANGE_DNS_PREFIX_$id"),
			'NETWORKRANGE_DNS_DOMAIN' =>
			  $stab->cgi_parse_param("NETWORKRANGE_DNS_DOMAIN_$id"),
			'NETWORKRANGE_TYPE' =>
			  $stab->cgi_parse_param("NETWORKRANGE_TYPE_$id"),
			'NETWORKRANGE_DESCRIPTION' =>
			  $stab->cgi_parse_param("NETWORKRANGE_DESCRIPTION_$id")
		};
	}

	# Remove all cgi parameters to avoid urls too long to be valid
	# This means we need to re-add the (changed) parameters that we want to track
	$cgi->delete_all;

	# Process deletion requests
	foreach my $id (@todelete) {
		$numchanges += delete_network_range( $stab, $id );
	}

	# Process update and creation requests, starting with updates
	foreach my $id ( sort( keys(%changed) ) ) {

		my $nr_start_ip      = $changed{$id}{'NETWORKRANGE_START_IP'};
		my $nr_stop_ip       = $changed{$id}{'NETWORKRANGE_STOP_IP'};
		my $nr_lease_time    = $changed{$id}{'NETWORKRANGE_LEASE_TIME'};
		my $nr_dns_prefix    = $changed{$id}{'NETWORKRANGE_DNS_PREFIX'};
		my $nr_dns_domain_id = $changed{$id}{'NETWORKRANGE_DNS_DOMAIN'};
		my $nr_type          = $changed{$id}{'NETWORKRANGE_TYPE'};
		my $nr_desc          = $changed{$id}{'NETWORKRANGE_DESCRIPTION'};

		# We want to keep those changed parameters in case of db failure
		# They will be added to the stab url in that case
		$cgi->param( "NETWORKRANGE_START_IP_$id",    $nr_start_ip );
		$cgi->param( "NETWORKRANGE_STOP_IP_$id",     $nr_stop_ip );
		$cgi->param( "NETWORKRANGE_LEASE_TIME_$id",  $nr_lease_time );
		$cgi->param( "NETWORKRANGE_DNS_PREFIX_$id",  $nr_dns_prefix );
		$cgi->param( "NETWORKRANGE_DNS_DOMAIN_$id",  $nr_dns_domain_id );
		$cgi->param( "NETWORKRANGE_TYPE_$id",        $nr_type );
		$cgi->param( "NETWORKRANGE_DESCRIPTION_$id", $nr_desc );

		if ( $id !~ /^NEW/ ) {
			$numchanges += update_network_range(
				$stab,             $id,            $nr_start_ip,
				$nr_stop_ip,       $nr_lease_time, $nr_dns_prefix,
				$nr_dns_domain_id, $nr_type,       $nr_desc
			);
		} else {

			# Make sure we have a network range type
			if ( !defined($nr_type) || $nr_type eq '' ) {
				$stab->error_return(
					'ERROR: a network range type must be selected ');
			}
			$numchanges +=
			  create_network_range( $stab, $nr_start_ip, $nr_stop_ip,
				$nr_lease_time, $nr_dns_prefix, $nr_dns_domain_id, $nr_type,
				$nr_desc );
		}
	}

	#print $cgi->end_html;

	# TODO - Remove temporary rollback
	#$stab->rollback; undef $stab; exit;

	if ( $numchanges > 0 ) {

		# We don't need to remember any cgi parameter since the updates are all successful
		$cgi->delete_all;
		$stab->commit || die $stab->return_db_err;
		$stab->msg_return( "$numchanges changes commited", undef, 1 );
	}

	$stab->rollback;
	$stab->msg_return( "There were no changes.", undef, 1 );
	undef $stab;
}

sub delete_network_range {
	my ( $stab, $nr_id ) = @_;

	# Delete the specified network range
	my $q = qq{
		select (netblock_manip.remove_network_range(
			network_range_id := ?
		))
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($stab);
	$sth->execute($nr_id)
	  || $stab->return_db_err($sth);

	1;
}

sub update_network_range {
	my (
		$stab,             $nr_id,         $nr_start_ip,
		$nr_stop_ip,       $nr_lease_time, $nr_dns_prefix,
		$nr_dns_domain_id, $nr_type,       $nr_desc
	) = @_;

	#my $orig = $stab->get_network_range_from_id( $nr_id );

	#print $nr_id, $nr_start_ip, $nr_stop_ip, $nr_lease_time, $nr_dns_prefix, $nr_dns_domain_id, $nr_type, $nr_desc,"<br/>\n";

	# Get the netblock for the start and end ip
	# Check if they belong to the same netblock
	# and make sure it's layer3
	#my $start_netblock_id = $stab->parse_netblock_search( $nr_start_ip );
	#my $stop_netblock_id = $stab->parse_netblock_search( $nr_stop_ip );
	#print Dumper($start_netblock_id), Dumper($stop_netblock_id), "<br/>\n";

	# Update the network range
	# TODO - Remove start ip address, stop ip address and parent netblock if the stored procedure doesn't support those parameters
	my $q = qq{
		select netblock_manip.update_network_range(
			network_range_id := ?,
			start_ip_address := network(?),
			stop_ip_address := broadcast(?),
			lease_time := ?,
			dns_prefix := ?,
			dns_domain_id := ?,
			description := ?,
			parent_netblock_id := null
		)
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($stab);

	#$sth->execute( $nr_id, $nr_start_ip, $nr_stop_ip, $nr_lease_time, $nr_dns_prefix, $nr_dns_domain_id, $nr_type, $nr_desc, $nr_start_ip )
	$sth->execute( $nr_id, $nr_start_ip, $nr_stop_ip, $nr_lease_time,
		$nr_dns_prefix, $nr_dns_domain_id, $nr_desc )
	  || $stab->return_db_err($sth);

	1;
}

sub create_network_range {
	my ( $stab, $nr_start_ip, $nr_stop_ip, $nr_lease_time, $nr_dns_prefix,
		$nr_dns_domain_id, $nr_type, $nr_desc )
	  = @_;

	#print $nr_start_ip, $nr_stop_ip, $nr_lease_time, $nr_dns_prefix, $nr_dns_domain_id, $nr_type, $nr_desc,"<br/>\n";

	# Create the network range
	my $q = qq{
		select netblock_manip.create_network_range(
			start_ip_address := ?::inet,
			stop_ip_address := ?::inet,
			parent_netblock_id := null,
			lease_time := ?,
			dns_prefix := ?,
			dns_domain_id := ?,
			network_range_type := ?,
			description := ?
		)
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($stab);
	$sth->execute( $nr_start_ip, $nr_stop_ip, $nr_lease_time, $nr_dns_prefix,
		$nr_dns_domain_id, $nr_type, $nr_desc )
	  || $stab->return_db_err($sth);
	1;
}

