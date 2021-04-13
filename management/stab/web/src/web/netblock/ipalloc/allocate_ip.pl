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
# Copyright (c) 2019 Todd Kover, Matthew Ragan
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
# $Id$
#

#
# NOTE:  The netblock page originally handled multiple blocks per page,
# but has been converted to just handle one, so there's probably stuff in the
# main page that is no longer here that needs to be ripped out..
#
# It shouldn't be hard to put it all back in, tho...
#

use strict;
use warnings;
use JazzHands::STAB;
use JazzHands::Common qw(:all);
use Data::Dumper;
use Carp;
use Net::IP;

process_netblock_reservations();

#############################################################################
#
# subroutines below here (they actually do all the work)
#
#############################################################################
#
# This type of routine is splattered out everywhere.   It clears out
# parameters that are not different frmo the db so error returns do not
# overflow headers, but fill forms look right.
#
sub clear_same_netblock_breakdown_params {
	my $stab = shift @_;

	my $cgi = $stab->cgi || die "could not create cgi";

	my $rootblkid = $stab->cgi_parse_param('NETBLOCK_ID');

	my $sth = $stab->prepare(
		qq{
		select	*
		  from	netblock
		 where	host(ip_address) = host(?)
		   and	parent_netblock_id = ?
		 LIMIT 1
	}
	);

	foreach my $rowblk ( $stab->cgi_get_ids("rowblk") ) {
		#
		# if $rowblk is not an ip address, then ignore it since it was
		# added from the web form.
		if ( $rowblk !~ m#^((\d+\.){3}(\d+)|([:A-Za-z0-9]+))$# ) {
			next;
		}
		#
		my $nbid = $stab->cgi_parse_param( "rowblk", $rowblk );
		my $desc = $stab->cgi_parse_param( "desc",   $rowblk );

		$sth->execute( $rowblk, $rootblkid )
		  || $stab->return_db_error($sth);
		my $hr = $sth->fetchrow_hashref;
		$sth->finish;
		next if ( !$hr );

		# if the netblock id changed, preserve, tho this is weird.
		next if ( $hr->{ _dbx('NETBLOCK_ID') } ne $nbid );

		if ( $hr->{ _dbx('DESCRIPTION') } ne $desc ) {
			next;
		}

		$cgi->delete("rowblk_$rowblk");
		$cgi->delete("desc_$rowblk");
	}
}

sub process_netblock_reservations {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi;
	my $dbh  = $stab->dbh;

	clear_same_netblock_breakdown_params($stab);
	my $numchanges = 0;

	my $nblkid = $stab->cgi_parse_param('NETBLOCK_ID');

	cleanup_unchanged_netblocks( $stab, $nblkid );

	# Temporarily remove the routing stuff
	#- cleanup_unchanged_routes( $stab, $nblkid );

	#- print $cgi->header, $cgi->start_html, $cgi->Dump, $cgi->end_html; exit;

	$numchanges += process_dns_additions( $stab, $nblkid );

	$numchanges += parse_netblock_routes( $stab, $nblkid );

	#
	# we actually only get here if something changed..
	#
	for my $uniqid ( $stab->cgi_get_ids('desc') ) {
		my $inid   = $stab->cgi_parse_param( 'rowblk', $uniqid );
		my $indesc = $stab->cgi_parse_param( 'desc',   $uniqid );
		my $inip   = $stab->cgi_parse_param( 'ip',     $uniqid );

		my $ip;
		if ( $uniqid !~ /^new_\d+/ ) {
			$ip = $uniqid;
		} else {
			$ip = $inip;
		}

		next if ( !$ip || $ip =~ /^\s*$/ );

		# already exists, so assume so.
		if ( defined($inid) ) {
			my $netblock = $stab->get_netblock_from_id($inid);
			if ( !defined($netblock) ) {
				$stab->error_return(
					"Unable to find IP ($ip) in DB for $inid.  Seek Help");
			}
			my $status = $netblock->{ _dbx('NETBLOCK_STATUS') };

			# do not attempt to deleted allocated ips
			next
			  if ( $status ne 'Reserved' && $status ne 'Legacy' );

			# no description means remove entry
			if ( !defined($indesc) ) {
				if (   $status eq 'Reserved'
					|| $status eq 'Legacy' )
				{
					remove_dns_record( $stab, $inid );
				}

				my $q = qq{
					delete from netblock where netblock_id = ?
				};
				my $sth = $stab->prepare($q)
				  || $stab->return_db_err($dbh);
				$numchanges += $sth->execute($inid)
				  || die $stab->return_db_err($sth);
				$sth->finish;

				# I used to allow err 2292 thru.  don't know why.
				next;
			}

			# assume something changed because of the 'clear', so this is ok.
			if ( defined($status) && $status eq 'Legacy' ) {
				$status = 'Reserved';
			}

			#
			# its not possible to change this, so we force it to stay the
			# same if it wasn't passed through.
			my %newnb = (
				NETBLOCK_ID     => $inid,
				DESCRIPTION     => $indesc,
				NETBLOCK_STATUS => $status,
			);
			my $diffs =
			  $stab->hash_table_diff( _dbx($netblock), _dbx( \%newnb ) );

			#- warn " ++ ", Dumper(\%newnb, $diffs, $netblock);
			my $tally   += keys %$diffs;
			$numchanges += $tally;
			if (
				$tally
				&& !$stab->run_update_from_hash(
					"NETBLOCK", "NETBLOCK_ID", $inid, $diffs
				)
			  )
			{
				$stab->rollback;
				$stab->error_return("Unknown Error with Update");
			}

		} else {

			# [XXX] need to reconfigure
			# Netblock can come into existance if it was populated by
			# a DNS insert previously.
			if (
				!(
					my $xx = $stab->get_netblock_from_ip(
						ip_address        => $ip,
						is_single_address => 'Y'
					)
				)
			  )
			{
				$inid = ipalloc_get_or_create_netblock_id( $stab, $ip, $nblkid,
					$indesc, );
				$numchanges++ if ($inid);
			}
		}
	}

	if ( !$numchanges ) {
		$stab->rollback;
		$stab->msg_return("No work to do");
	}

	$stab->commit;
	my $url = "../?nblkid=$nblkid";
	$stab->msg_return( "Update successful", $url, 1 );
	undef $stab;
}

sub remove_dns_record {
	my ( $stab, $id ) = @_;

	my $dbh = $stab->dbh;

	my $q = qq{
		delete from dns_Record where netblock_id = ?
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute($id) || $stab->return_db_err($sth);
}

#
# NOTE:  THIS IS NOT THE SAME VERSION AS ELSEWHERE
# needs to be merged in as appropriate!
#
sub ipalloc_get_or_create_netblock_id {
	my ( $stab, $insert_ip, $par_nbid, $desc ) = @_;
	my $cgi = $stab->cgi;

	return undef if ( !defined($par_nbid) );

	my $netblock = $stab->get_netblock_from_id($par_nbid);
	if ( !defined($netblock) ) {
		$stab->error_return(
			"Unable to find/configure parent IP in DB.  Please seek help");
	}

	my $pip = new Net::IP( $netblock->{ _dbx('IP_ADDRESS') } )
	  || $stab->error_return("Netblock IP is not valid");

	my $nip = new Net::IP($insert_ip)
	  || $stab->error_return("IP: $insert_ip is not valid");

	#
	# check to see if IP is in the parent netblock.  This is more meaningful
	# in Ipv6 (or large block) additions
	#
	if ( $pip->ip() ne $nip->ip() ) {
		if ( $pip->overlaps($nip) != $IP_B_IN_A_OVERLAP ) {
			$stab->error_return(
				"$insert_ip is not in " . $netblock->{ _dbx('IP_ADDRESS') } );
		}
	}

	my $q = qq {
		WITH ins AS (
			insert into netblock (
				ip_address,
				is_single_address, netblock_status,
				can_subnet,
				netblock_type, ip_universe_id,
				PARENT_NETBLOCK_ID, DESCRIPTION
			) values (
				:ip,
				'Y', 'Reserved',
				'N',
				'default', 0,
				:parent_nblkid, :description
			) RETURNING *
		) SELECT netblock_id from ins
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err;
	$sth->bind_param( ":ip", $nip->ip() ) || $stab->return_db_err($sth);
	$sth->bind_param( ":parent_nblkid", $par_nbid )
	  || $stab->return_db_err($sth);
	$sth->bind_param( ":description", $desc ) || $stab->return_db_err($sth);

	$sth->execute || $stab->return_db_err($sth);
	my ($nbid) = ( $sth->fetchrow_array )[0];
	$nbid;
}

##############################################################################3
#
# returning errors doesn't work well if there are too many.  This pairs
# things down at the expense of some cpu/memory.
#
sub cleanup_unchanged_routes {
	my ( $stab, $nblkid ) = @_;
	my $cgi = $stab->cgi;

	my $sth = $stab->prepare(
		qq{
		select  srt.STATIC_ROUTE_TEMPLATE_ID,
			srt.description as ROUTE_DESCRIPTION,
			net_manip.inet_dbtop(snb.ip_address) as SOURCE_BLOCK_IP,
			masklen(snb.ip_address) as SOURCE_MASKLEN,
			net_manip.inet_dbtop(dnb.ip_address) as ROUTE_DESTINATION_IP
		 from   static_route_template srt
			inner join netblock snb
			    on srt.netblock_src_id = snb.netblock_id
			inner join network_interface_netblock ni
			    on srt.network_interface_dst_id = ni.network_interface_id
			inner join netblock dnb
			    on dnb.netblock_id = ni.netblock_id
			inner join device d
			    on d.device_id = ni.device_id
		where   srt.netblock_id = ?
	}
	);
	$sth->execute($nblkid) || $stab->return_db_err($sth);
	my $all = $sth->fetchall_hashref('STATIC_ROUTE_TEMPLATE_ID');

  ROUTE:
	for my $srtid ( $stab->cgi_get_ids('STATIC_ROUTE_TEMPLATE_ID') ) {
		my $srcip   = $stab->cgi_parse_param( 'SOURCE_BLOCK_IP',      $srtid );
		my $srcbits = $stab->cgi_parse_param( 'SOURCE_MASKLEN',       $srtid );
		my $dstip   = $stab->cgi_parse_param( 'ROUTE_DESTINATION_IP', $srtid );
		my $desc    = $stab->cgi_parse_param( 'ROUTE_DESCRIPTION',    $srtid );

		my $map = {
			SOURCE_BLOCK_IP      => $srcip,
			SOURCE_MASKLEN       => $srcbits,
			ROUTE_DESTINATION_IP => $dstip,
			ROUTE_DESCRIPTION    => $desc,
		};

		# if it correponds to an actual row, compare, otherwise only keep if
		# something is set.
		if (   defined($srtid)
			&& exists( $all->{$srtid} )
			&& defined( $all->{$srtid} ) )
		{
			my $x = $all->{$srtid};
			foreach my $key ( sort keys(%$map) ) {
				if ( $x->{$key} && defined( $map->{$key} ) ) {
					next ROUTE
					  if ( $x->{$key} ne $map->{$key} );
				} elsif ( !defined( $x->{$key} )
					&& !defined( $map->{$key} ) )
				{
					;
				} else {
					next ROUTE;
				}
			}
		}

		$cgi->delete("STATIC_ROUTE_TEMPLATE_ID_$srtid");
		$cgi->delete("SOURCE_BLOCK_IP_$srtid");
		$cgi->delete("SOURCE_MASKLEN_$srtid");
		$cgi->delete("ROUTE_DESTINATION_IP_$srtid");
		$cgi->delete("ROUTE_DESCRIPTION_$srtid");
	}

	undef $all;

	# check adds..
	my $add = 0;
	foreach my $key (
		qw(
		SOURCE_BLOCK_IP
		SOURCE_MASKLEN
		ROUTE_DESTINATION_IP
		ROUTE_DESCRIPTION
		)
	  )
	{
		my $x = $stab->cgi_parse_param($key);
		$add++ if ( defined($x) );
		undef $x;
	}

	if ( !$add ) {
		foreach my $key (
			qw(
			SOURCE_BLOCK_IP
			SOURCE_MASKLEN
			ROUTE_DESTINATION_IP
			ROUTE_DESCRIPTION
			)
		  )
		{
			$cgi->delete($key);
		}
	}
}

sub cleanup_unchanged_netblocks {
	my ( $stab, $nblkid ) = @_;
	my $cgi = $stab->cgi;

	my $sth = $stab->prepare(
		qq{
		select	netblock_id,netblock_status,description,
				net_manip.inet_dbtop(ip_address) as ip
		  from 	netblock
		 where	parent_netblock_id = ?
	}
	);
	$sth->execute($nblkid) || $stab->return_db_err($sth);
	my $all = $sth->fetchall_hashref( _dbx('NETBLOCK_ID') );

	for my $uniqid ( $stab->cgi_get_ids('desc') ) {
		my $inid   = $stab->cgi_parse_param( 'rowblk', $uniqid );
		my $indesc = $stab->cgi_parse_param( 'desc',   $uniqid );

		#
		# new IP addresses, need to add them.
		next if ( $uniqid =~ /^new_\d+/ );

		my $ip = $uniqid;

		# if it correponds to an actual row, compare, otherwise only keep if
		# something is set.
		if (   defined($inid)
			&& exists( $all->{$inid} )
			&& defined( $all->{$inid} ) )
		{
			my $x = $all->{$inid};
			if ( $x->{ _dbx('DESCRIPTION') } && defined($indesc) ) {
				next
				  if ( $x->{ _dbx('DESCRIPTION') } ne $indesc );
			} elsif ( !defined( $x->{ _dbx('DESCRIPTION') } )
				&& !defined($indesc) )
			{
				;
			} else {
				next;
			}

			# ignoring ticket system changes.  rethink?
		} else {
			if (   defined($inid)
				|| defined($indesc) )
			{
				next;
			}
		}

		$cgi->delete("rowblk_$ip");
		$cgi->delete("desc_$ip");
	}

	undef $all;
}

#
# end cleanup
#
##############################################################################3

sub parse_netblock_routes {
	my ( $stab, $nblkid ) = @_;

	my $numchanges = 0;
	$numchanges += add_netblock_routes( $stab, $nblkid );
	$numchanges += update_netblock_routes( $stab, $nblkid );
	$numchanges;
}

sub add_netblock_routes {
	my ( $stab, $nblkid ) = @_;

	my $numchanges = 0;

	my $srcip   = $stab->cgi_parse_param('SOURCE_BLOCK_IP');
	my $srcbits = $stab->cgi_parse_param('SOURCE_MASKLEN');
	my $destip  = $stab->cgi_parse_param('ROUTE_DESTINATION_IP');
	my $desc    = $stab->cgi_parse_param('ROUTE_DESCRIPTION');

	if ( $srcip && $srcip =~ /^default$/i ) {
		$srcip   = '0.0.0.0';
		$srcbits = 0 if ( !$srcbits );
	}

	# exits with an error if it does not validate.
	my ( $ni, $nb ) = $stab->validate_route_entry( $srcip, $srcbits, $destip );

	return 0 if ( !$ni && !$nb );

	my $sth = $stab->prepare(
		qq{
		insert into static_route_template (
			NETBLOCK_SRC_ID, NETWORK_INTERFACE_DST_ID, NETBLOCK_ID,
			DESCRIPTION
		) values (
			?, ?, ?
			?
		)
	}
	);
	$numchanges += $sth->execute(
		$nb->{ _dbx('NETBLOCK_ID') },
		$ni->{ _dbx('NETWORK_INTERFACE_ID') },
		$nblkid, $desc
	) || $stab->return_db_err($sth);
	$numchanges;
}

sub update_netblock_routes {
	my ( $stab, $nblkid ) = @_;

	my $dbh = $stab->dbh;

	my $numchanges = 0;

	foreach my $id ( $stab->cgi_get_ids('chk_RM_STATIC_ROUTE_TEMPLATE_ID') ) {
		$numchanges += $stab->rm_static_route_from_netblock($id);
	}

	foreach my $id ( $stab->cgi_get_ids('STATIC_ROUTE_TEMPLATE_ID') ) {
		my $srcip   = $stab->cgi_parse_param( 'SOURCE_BLOCK_IP',      $id );
		my $srcbits = $stab->cgi_parse_param( 'SOURCE_MASKLEN',       $id );
		my $destip  = $stab->cgi_parse_param( 'ROUTE_DESTINATION_IP', $id );
		my $desc    = $stab->cgi_parse_param( 'ROUTE_DESCRIPTION',    $id );

		if ( $srcip && $srcip =~ /^default$/i ) {
			$srcip   = '0.0.0.0';
			$srcbits = 0 if ( !$srcbits );
		}

		# exits with an error if it does not validate.
		my ( $ni, $nb ) =
		  $stab->validate_route_entry( $srcip, $srcbits, $destip );

		my $gSth = $stab->prepare(
			qq{
			select * from static_route_template where static_route_template_id = :1
		}
		);
		$gSth->execute($id) || $stab->return_db_err($gSth);
		my $dbsrt = $gSth->fetchrow_hashref;
		$gSth->finish;

		$stab->error_return("Unknown Existing Route") if ( !$dbsrt );

		my %newsrt = (
			STATIC_ROUTE_TEMPLATE_ID => $id,
			NETBLOCK_SRC_ID          => $nb->{NETBLOCK_ID},
			NETWORK_INTERFACE_DST_ID => $ni->{NETWORK_INTERFACE_ID},
			NETBLOCK_ID              => $nblkid,
			DESCRIPTION              => $desc
		);

		my $diffs = $stab->hash_table_diff( $dbsrt, \%newsrt );

		my $tally   += keys %$diffs;
		$numchanges += $tally;

		if (
			$tally
			&& !$stab->build_update_sth_from_hash(
				'STATIC_ROUTE_TEMPLATE', 'STATIC_ROUTE_TEMPLATE_ID',
				$id,                     $diffs
			)
		  )
		{
			$dbh->rollback;
			$stab->error_return("Unknown Error with Update");
		}
	}
	$numchanges;
}

sub process_dns_additions( $$ ) {
	my $stab   = shift @_;
	my $nblkid = shift @_;    # probably not used

	my $numchanges = 0;

	for my $uniqid ( $stab->cgi_get_ids('DNS_RECORD_ID') ) {
		my $ip = $uniqid;
		if ( $uniqid =~ /newiptr_(\d+)$/ ) {
			$ip = $stab->cgi_parse_param( 'ip_new', $1 );
			if ( !$ip ) {
				$stab->error_return(
					"Unable to find IP for uniq id $uniqid.  Seek help");
			}
		}
		my $type = 'A';
		if ( $ip =~ /:/ ) {
			$type = 'AAAA';
		}
		my $new = {
			DNS_NAME      => $stab->cgi_parse_param( 'DNS_RECORD_ID', $uniqid ),
			DNS_DOMAIN_ID => $stab->cgi_parse_param( 'DNS_DOMAIN_ID', $uniqid ),
			DNS_CLASS     => 'IN',
			DNS_TYPE      => $type,
			DNS_VALUE     => $ip,
			IS_ENABLED    => 'Y',
		};
		$numchanges += $stab->process_and_insert_dns_record($new);
	}
	$numchanges;
}
