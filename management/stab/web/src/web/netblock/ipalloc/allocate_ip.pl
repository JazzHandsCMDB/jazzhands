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
use Data::Dumper;
use Carp;
use Net::IP;

process_netblock_reservations();

#############################################################################
#
# subroutines below here (they actually do all the work)
#
#############################################################################
sub process_netblock_reservations {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi;
	my $dbh  = $stab->dbh;

	my $numchanges = 0;

	my $nblkid = $stab->cgi_parse_param('NETBLOCK_ID');

	cleanup_unchanged_netblocks( $stab, $nblkid );
	cleanup_unchanged_routes( $stab, $nblkid );

       # print $cgi->header, $cgi->start_html, $cgi->Dump, $cgi->end_html; exit;

	$numchanges += parse_netblock_routes( $stab, $nblkid );

	#
	# we actually only get here if something changed..
	#
	for my $uniqid ( $stab->cgi_get_ids('desc') ) {
		my $inid   = $stab->cgi_parse_param( 'rowblk',           $uniqid );
		my $indesc = $stab->cgi_parse_param( 'desc',             $uniqid );
		my $tixsys = $stab->cgi_parse_param( 'APPROVAL_TYPE',    $uniqid );
		my $intix  = $stab->cgi_parse_param( 'APPROVAL_REF_NUM', $uniqid );
		my $inip  = $stab->cgi_parse_param( 'ip', $uniqid );

		my $ip;
		if($uniqid !~ /^new_\d+/) {
			$ip = $uniqid;
		} else {
			$ip = $inip;
		}


		# already exists, so assume so.
		if ($inid) {
			my $netblock = $stab->get_netblock_from_id($inid);
			if ( !defined($netblock) ) {
				$stab->error_return(
					"Unable to find IP in DB.  Seek Help");
			}
			my $status = $netblock->{'NETBLOCK_STATUS'};

			# no description means remove entry
			if ( !defined($indesc) ) {
				if (       $status eq 'Reserved'
					|| $status eq 'Legacy' )
				{
					remove_dns_record( $stab, $inid );
				}

				my $q = qq{
					delete from netblock where netblock_id = :1
				};
				my $sth = $stab->prepare($q)
				  || $stab->return_db_err($dbh);
				$sth->execute($inid);

			       # I used to allow err 2292 thru.  don't know why.
			}

	       # assume something changed because of the 'clear', so this is ok.
			if ( $status eq 'Legacy' ) {
				$status = 'Reserved';
			}

		   #
		   # its not possible to change this, so we force it to stay the
		   # same if it wasn't passed through.
			if ( defined( $netblock->{'APPROVAL_REF_NUM'} ) ) {
				$intix  = $netblock->{'APPROVAL_REF_NUM'};
				$tixsys = $netblock->{'APPROVAL_TYPE'};
			}

			my %newnb = (
				NETBLOCK_ID      => $inid,
				DESCRIPTION      => $indesc,
				APPROVAL_TYPE    => $tixsys,
				APPROVAL_REF_NUM => $intix,
				NETBLOCK_STATUS  => $status,
			);
			my $diffs =
			  $stab->hash_table_diff( $netblock, \%newnb );
			my $tally   += keys %$diffs;
			$numchanges += $tally;
			if (
				$tally
				&& !$stab->build_update_sth_from_hash(
					"NETBLOCK", "NETBLOCK_ID",
					$inid,      $diffs
				)
			  )
			{
				$stab->rollback;
				$stab->error_return(
					"Unknown Error with Update");
			}

		} else {

			# [XXX] need to reconfigure
			$inid = ipalloc_get_or_create_netblock_id(
				$stab,   $ip,    $nblkid,
				$indesc, $intix, $tixsys
			);
		}
		$numchanges++;
	}

	if ( !$numchanges ) {
		$stab->rollback;
		$stab->msg_return("No work to do");
	}

	$stab->commit;
	my $url = "../?nblkid=$nblkid";
	$stab->msg_return( "Update successful", $url, 1 );
}

sub remove_dns_record {
	my ( $stab, $id ) = @_;

	my $dbh = $stab->dbh;

	my $q = qq{
		delete from dns_Record where netblock_id = :1
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute($id) || $stab->return_db_err($sth);
}

#
# NOTE:  THIS IS NOT THE SAME VERSION AS ELSEWHERE
# needs to be merged in as appropriate!
#
sub ipalloc_get_or_create_netblock_id {
	my ( $stab, $insert_ip, $par_nbid, $desc, $tix, $tixsys ) = @_;
	my $cgi = $stab->cgi;

	return undef if ( !defined($par_nbid) );

	my $netblock = $stab->get_netblock_from_id( $par_nbid, 1, 1 );
	if ( !defined($netblock) ) {
		$stab->error_return(
"Unable to find/configure parent IP in DB.  Please seek help"
		);
	}
	my $bits = $netblock->{'NETMASK_BITS'};

	if ( !defined($bits) ) {
		return undef;
	}

	my $pip = new Net::IP($netblock->{IP}."/".$netblock->{NETMASK_BITS}) ||
		$stab->error_return("Netblock IP is not valid") ;

	my $nip = new Net::IP($insert_ip) ||
		$stab->error_return("IP: $insert_ip is not valid") ;

	#
	# check to see if IP is in the parent netblock.  This is more meaningful
	# in Ipv6 (or large block) additions
	#
	if($pip->overlaps($nip) != $IP_B_IN_A_OVERLAP) {
		$stab->error_return("$insert_ip is not in ".
			$netblock->{IP}."/".$netblock->{NETMASK_BITS});
	}

	my $nbid;
	my $q = qq {
		insert into netblock (
			ip_address, netmask_bits, is_ipv4_address,
			is_single_address, netblock_status,
			netblock_type,
			PARENT_NETBLOCK_ID, DESCRIPTION, 
			APPROVAL_TYPE, APPROVAL_REF_NUM
		) values (
			:ip, :bits, :ipv4,
			'Y', 'Reserved',
			'default',
			:parent_nblkid, :description, 
			:tixsys, :tix
		) returning netblock_id into :rv
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err;
	$sth->bind_param_inout( ":rv", \$nbid, 500 )
	  || $stab->return_db_err($sth);
	$sth->bind_param( ":ip",   $nip->intip() ) || $stab->return_db_err($sth);
	$sth->bind_param( ":bits", $bits )      || $stab->return_db_err($sth);
	$sth->bind_param( ":parent_nblkid", $par_nbid )
	  || $stab->return_db_err($sth);
	$sth->bind_param( ":description", $desc ) || $stab->return_db_err($sth);
	$sth->bind_param( ":tixsys", $tixsys ) || $stab->return_db_err($sth);
	$sth->bind_param( ":tix",    $tix )    || $stab->return_db_err($sth);
	$sth->bind_param(":ipv4", ($bits>32)?'N':'Y') || $stab->return_db_err($sth);

	$sth->execute || $stab->return_db_err($sth);
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
			ip_manip.v4_octet_from_int(snb.ip_address) as SOURCE_BLOCK_IP,
			snb.netmask_bits as SOURCE_NETMASK_BITS,
			ip_manip.v4_octet_from_int(dnb.ip_address) as ROUTE_DESTINATION_IP
		 from   static_route_template srt
			inner join netblock snb
			    on srt.netblock_src_id = snb.netblock_id
			inner join network_interface ni
			    on srt.network_interface_dst_id = ni.network_interface_id
			inner join netblock dnb
			    on dnb.netblock_id = ni.v4_netblock_id
			inner join device d
			    on d.device_id = ni.device_id
		where   srt.netblock_id = :1
	}
	);
	$sth->execute($nblkid) || $stab->return_db_err($sth);
	my $all = $sth->fetchall_hashref('STATIC_ROUTE_TEMPLATE_ID');

      ROUTE:
	for my $srtid ( $stab->cgi_get_ids('STATIC_ROUTE_TEMPLATE_ID') ) {
		my $srcip = $stab->cgi_parse_param( 'SOURCE_BLOCK_IP', $srtid );
		my $srcbits =
		  $stab->cgi_parse_param( 'SOURCE_NETMASK_BITS', $srtid );
		my $dstip =
		  $stab->cgi_parse_param( 'ROUTE_DESTINATION_IP', $srtid );
		my $desc =
		  $stab->cgi_parse_param( 'ROUTE_DESCRIPTION', $srtid );

		my $map = {
			SOURCE_BLOCK_IP      => $srcip,
			SOURCE_NETMASK_BITS  => $srcbits,
			ROUTE_DESTINATION_IP => $dstip,
			ROUTE_DESCRIPTION    => $desc,
		};

	    # if it correponds to an actual row, compare, otherwise only keep if
	    # something is set.
		if (       defined($srtid)
			&& exists( $all->{$srtid} )
			&& defined( $all->{$srtid} ) )
		{
			my $x = $all->{$srtid};
			foreach my $key ( sort keys(%$map) ) {
				if ( $x->{$key} && defined( $map->{$key} ) ) {
					next ROUTE
					  if ( $x->{$key} ne $map->{$key} );
				} elsif (  !defined( $x->{$key} )
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
		$cgi->delete("SOURCE_NETMASK_BITS_$srtid");
		$cgi->delete("ROUTE_DESTINATION_IP_$srtid");
		$cgi->delete("ROUTE_DESCRIPTION_$srtid");
	}

	undef $all;

	# check adds..
	my $add = 0;
	foreach my $key (
		qw(
		SOURCE_BLOCK_IP
		SOURCE_NETMASK_BITS
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
			SOURCE_NETMASK_BITS
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
				approval_type, approval_ref_num,
				ip_manip.v4_octet_from_int(ip_address) as ip
		  from 	netblock
		 where	parent_netblock_id = :1
	}
	);
	$sth->execute($nblkid) || $stab->return_db_err($sth);
	my $all = $sth->fetchall_hashref('NETBLOCK_ID');

	for my $uniqid ( $stab->cgi_get_ids('desc') ) {
		my $inid   = $stab->cgi_parse_param( 'rowblk',           $uniqid );
		my $indesc = $stab->cgi_parse_param( 'desc',             $uniqid );
		my $intix  = $stab->cgi_parse_param( 'APPROVAL_REF_NUM', $uniqid );
		my $intixsys = $stab->cgi_parse_param( 'APPROVAL_TYPE', $uniqid );

		#
		# new IP addresses, need to add them.
		next if($uniqid =~ /^new_\d+/);

		my $ip = $uniqid;


	    # if it correponds to an actual row, compare, otherwise only keep if
	    # something is set.
		if (       defined($inid)
			&& exists( $all->{$inid} )
			&& defined( $all->{$inid} ) )
		{
			my $x = $all->{$inid};
			if ( $x->{'DESCRIPTION'} && defined($indesc) ) {
				next if ( $x->{'DESCRIPTION'} ne $indesc );
			} elsif (  !defined( $x->{'DESCRIPTION'} )
				&& !defined($indesc) )
			{
				;
			} else {
				next;
			}

			# ticket number can be added but not changed.
			if ( !defined( $x->{'APPROVAL_REF_NUM'} ) && $intix ) {
				next;
			}

			# ignoring ticket system changes.  rethink?
		} else {
			if (       defined($inid)
				|| defined($indesc)
				|| defined($intix) )
			{
				next;
			}
		}

		$cgi->delete("rowblk_$ip");
		$cgi->delete("desc_$ip");
		$cgi->delete("APPROVAL_TYPE_$ip");
		$cgi->delete("APPROVAL_REF_NUM_$ip");
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
	my $srcbits = $stab->cgi_parse_param('SOURCE_NETMASK_BITS');
	my $destip  = $stab->cgi_parse_param('ROUTE_DESTINATION_IP');
	my $desc    = $stab->cgi_parse_param('ROUTE_DESCRIPTION');

	if ( $srcip && $srcip =~ /^default$/i ) {
		$srcip = '0.0.0.0';
		$srcbits = 0 if ( !$srcbits );
	}

	# exits with an error if it does not validate.
	my ( $ni, $nb ) =
	  $stab->validate_route_entry( $srcip, $srcbits, $destip );

	return 0 if ( !$ni && !$nb );

	my $sth = $stab->prepare(
		qq{
		insert into static_route_template (
			NETBLOCK_SRC_ID, NETWORK_INTERFACE_DST_ID, NETBLOCK_ID,
			DESCRIPTION
		) values (
			:1, :2, :3,
			:4
		)
	}
	);
	$numchanges +=
	  $sth->execute( $nb->{'NETBLOCK_ID'}, $ni->{'NETWORK_INTERFACE_ID'},
		$nblkid, $desc )
	  || $stab->return_db_err($sth);
	$numchanges;
}

sub update_netblock_routes {
	my ( $stab, $nblkid ) = @_;

	my $dbh = $stab->dbh;

	my $numchanges = 0;

	foreach my $id ( $stab->cgi_get_ids('chk_RM_STATIC_ROUTE_TEMPLATE_ID') )
	{
		$numchanges += $stab->rm_static_route_from_netblock($id);
	}

	foreach my $id ( $stab->cgi_get_ids('STATIC_ROUTE_TEMPLATE_ID') ) {
		my $srcip = $stab->cgi_parse_param( 'SOURCE_BLOCK_IP', $id );
		my $srcbits =
		  $stab->cgi_parse_param( 'SOURCE_NETMASK_BITS', $id );
		my $destip =
		  $stab->cgi_parse_param( 'ROUTE_DESTINATION_IP', $id );
		my $desc = $stab->cgi_parse_param( 'ROUTE_DESCRIPTION', $id );

		if ( $srcip && $srcip =~ /^default$/i ) {
			$srcip = '0.0.0.0';
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
				'STATIC_ROUTE_TEMPLATE',
				'STATIC_ROUTE_TEMPLATE_ID', $id, $diffs
			)
		  )
		{
			$dbh->rollback;
			$stab->error_return("Unknown Error with Update");
		}
	}
	$numchanges;
}
