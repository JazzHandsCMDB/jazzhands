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
use Net::Netmask;
use JazzHands::STAB;

do_dump_dhcp_range();

############################################################################3
#
# everything else is a subroutine
#
############################################################################3

sub do_dump_dhcp_range {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi;
	my $dbh  = $stab->dbh;

	print $cgi->header, $stab->start_html("All DHCP Ranges");

	my $q = qq{
		select	
			dhcp.dhcp_range_id,
			ni.network_interface_id,
			ni.name as network_interface_name,
			ni.device_id,
			d.device_name,
			ip_manip.v4_octet_from_int(nb.ip_address) as ip,
			nb.netmask_bits,
			ip_manip.v4_octet_from_int(lhs.ip_address) as start_ip,
			ip_manip.v4_octet_from_int(rhs.ip_address) as stop_ip,
			dhcp.start_netblock_id,
			dhcp.stop_netblock_id,
			dhcp.lease_time
		  from	dhcp_range dhcp
				inner join network_interface ni
					on dhcp.network_interface_id = ni.network_interface_id
				inner join netblock nb
					on nb.netblock_id = ni.v4_netblock_id
				inner join device d
					on d.device_id = ni.device_id
				inner join netblock lhs
					on lhs.netblock_id = dhcp.start_netblock_id
				inner join netblock rhs
					on rhs.netblock_id = dhcp.stop_netblock_id
		order by nb.ip_address
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($stab);
	$sth->execute || $stab->return_db_err($stab);

	print $cgi->start_table( { -border => 1, -align => 'center' } );

	print $cgi->th(
		[
			'Router',  'Interface', 'Netblock', 'Start IP',
			'Stop IP', 'Lease Time'
		]
	);

	while ( my $hr = $sth->fetchrow_hashref ) {
		my $nb =
		  new Net::Netmask( $hr->{'IP'} . "/" . $hr->{'NETMASK_BITS'} );

		my $link = "../device/device.pl?devid=" . $hr->{'DEVICE_ID'};
		print $cgi->Tr(
			$cgi->hidden( 'DHCP_RANGE_ID', $hr->{'DHCP_RANGE_ID'} ),
			$cgi->td(
				[
					$cgi->a(
						{ -href => $link },
						$hr->{'DEVICE_NAME'}
					),
					$hr->{'NETWORK_INTERFACE_NAME'},
					$nb->base() . "/" . $nb->bits(),
					$hr->{'START_IP'},
					$hr->{'STOP_IP'},
					$hr->{'LEASE_TIME'}
				]
			)
		);
	}

	print $cgi->end_table;
	print $cgi->end_html;
}
