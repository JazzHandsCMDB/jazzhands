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
use JazzHands::STAB;
use Net::Netmask;

do_device_search();

sub find_devices {
	my ( $stab, $name, $ipblock, $type, $os, $mac, $serial ) = @_;

	my $cgi = $stab->cgi || die "Could not create cgi";
	my $dbh = $stab->dbh || die "Could not create dbh";

	my ( $ip, $bits );
	if ( defined($ipblock) ) {
		my $nb = new2 Net::Netmask($ipblock);
		if ( defined($nb) ) {
			( $ip, $bits ) = ( $nb->base, $nb->bits );
		} else {
			$stab->error_return("That is an invalid IP address");
		}
	}

	my $criteria =
	  "(d.device_name IS NULL OR d.device_name not like '%--otherside%')";

	if ( defined($name) ) {
		$criteria .= " and " if ( length($criteria) );
		$criteria .=
			" (lower(d.device_name) like lower(:name) or lower(dns.dns_name) like lower(:name) or lower(d.physical_label) like lower(:name))";

	}

	if ( defined($serial) ) {
		$criteria .= " and " if ( length($criteria) );
		$criteria .= " (lower(d.serial_number) like lower(:serial)";
		$criteria .= "  OR lower(d.host_id) like lower(:serial))";
	}

	if ( defined($mac) ) {
		$criteria .= " and " if ( length($criteria) );
		$criteria .= " ni.mac_addr = :mac";
	}

	if ( defined($type) ) {
		$criteria .= " and " if ( length($criteria) );
		$criteria .= " d.device_type_id = :type ";
	}

	if ( defined($os) ) {
		$criteria .= " and " if ( length($criteria) );
		$criteria .= " d.operating_system_id = :os ";
	}

	# switch /32 lookups to be simple ip_address = X

	if ( defined($ip) ) {
		$criteria .= " and " if ( length($criteria) );
		if ( $bits < 32 ) {
			$criteria .=
" (ip_manip.v4_base(nb.ip_address, :bits) = ip_manip.v4_base(ip_manip.v4_int_from_octet(:ip, 1), :bits)";
			$criteria .=
" or ip_manip.v4_base(snbnb.ip_address, :bits) = ip_manip.v4_base(ip_manip.v4_int_from_octet(:ip, 1), :bits)";
			$criteria .= " )";
		} else {
			$criteria .=
" (nb.ip_address = ip_manip.v4_int_from_octet(:ip) or snbnb.ip_address = ip_manip.v4_int_from_octet(:ip))";
		}
	}

	if ( !defined($criteria) || !length($criteria) ) {
		$stab->msg_return("No criteria specified");
	}

	my $q = qq{
		select	distinct d.device_id, d.device_name
		  from	device d
			left join network_interface ni
				on ni.device_id = d.device_id
			left join netblock nb
				on nb.netblock_id = ni.v4_netblock_id
			left join dns_record dns
				on dns.netblock_id = nb.netblock_id
			left join secondary_netblock snb
				on snb.network_interface_id =
					ni.network_interface_id
			left join netblock snbnb
				on snbnb.netblock_id = snb.netblock_id
		 where	
			$criteria
		 order by d.device_name
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);

	if ( defined($name) ) {
		$sth->bind_param( ":name", "%$name%" )
		  || $stab->return_db_err($sth);
	}
	if ( defined($type) ) {
		$sth->bind_param( ":type", $type )
		  || $stab->return_db_err($sth);
	}
	if ( defined($os) ) {
		$sth->bind_param( ":os", $os ) || $stab->return_db_err($sth);
	}
	if ( defined($ip) ) {
		$sth->bind_param( ":ip", $ip ) || $stab->return_db_err($sth);
		if ( $bits < 32 ) {
			$sth->bind_param( ":bits", $bits )
			  || $stab->return_db_err($sth);
		}
	}
	if ( defined($serial) ) {
		$sth->bind_param( ":serial", "%$serial%" )
		  || $stab->return_db_err($sth);
	}
	if ( defined($mac) ) {
		my $intmac = $stab->int_mac_from_text($mac);
		$sth->bind_param( ":mac", $intmac )
		  || $stab->return_db_err($sth);
	}
	$sth->execute || $stab->return_db_err($sth);

	my (@rv);
	while ( my ($devid) = $sth->fetchrow_array ) {
		push( @rv, $devid );
	}
	$sth->finish;
	@rv;
}

sub do_device_search {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";
	my $dbh  = $stab->dbh          || die "Could not create dbh";

	my $byip     = $stab->cgi_parse_param('byip');
	my $byname   = $stab->cgi_parse_param('byname');
	my $bymac    = $stab->cgi_parse_param('bymac');
	my $byserial = $stab->cgi_parse_param('byserial');
	my $bytype   = $stab->cgi_parse_param('DEVICE_TYPE_ID');
	my $byos     = $stab->cgi_parse_param('OPERATING_SYSTEM_ID');
	my $Search   = $stab->cgi_parse_param('Search');

	$cgi->delete('devlist');

	#
	# if no search terms, then redirect to where they can be entered.
	#
	if (       !$cgi->referer
		&& !defined($byip)
		&& !defined($byname)
		&& !defined($bymac)
		&& !defined($byserial)
		&& !defined($bytype)
		&& !defined($byos) )
	{
		print $cgi->redirect(".");
		return;
	}

	my @searchresults =
	  find_devices( $stab, $byname, $byip, $bytype, $byos, $bymac,
		$byserial );

	#
	# exactly one search result, so redirect to that result.  If Search is
	# set, it means this was the calling page, in which case, we don't want
	# to redirect..
	#
	if ( $#searchresults == 0 ) {
		my $url = "device.pl?devid=" . $searchresults[0];
		$cgi->redirect($url);
		exit 0;
	} elsif ( $#searchresults > 0 ) {
		if ( $#searchresults > 500 ) {
			$stab->error_return(
				"Too many matches ($#searchresults).  Please limit your query");
		}
		my $devlist = join( ",", @searchresults );
		my $url = $stab->build_passback_url( devlist => $devlist );
		$cgi->redirect($url);
		exit 0;
	}

	$stab->msg_return("No devices found matching that criteria");

	exit 0;
}
