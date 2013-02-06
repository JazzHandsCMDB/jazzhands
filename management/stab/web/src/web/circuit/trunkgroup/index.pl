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
use POSIX;
use JazzHands::STAB;

do_trunk_group_toplevel();

sub do_trunk_group_toplevel {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";
	my $dbh  = $stab->dbh          || die "Could not create dbh";

	my $tgid = $stab->cgi_parse_param('TRUNK_GROUP_ID');

	if ( !defined($tgid) ) {
		tg_search($stab);
	} else {
		dump_tg( $stab, $tgid );
	}
}

sub tg_search {
	my ($stab) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";
	my $dbh = $stab->dbh || die "Could not create dbh";

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html( { -title => "Trunk Group Search" } ), "\n";

	print "totally not implemented";

	print $cgi->end_html, "\n";

}

sub dump_tg {
	my ( $stab, $tgid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";
	my $dbh = $stab->dbh || die "Could not create dbh";

	{
		my $sth = $stab->prepare(
			qq{
		select	c.company_name,
			c.company_id,
			tg.trunk_group_name,
			tg.src_point_code,
			tg.dst_point_code
		  from	trunk_group tg
				inner join company c
					on c.company_id = tg.company_id
		 where	tg.trunk_group_id = :1
	}
		);
		$sth->execute($tgid) || $stab->return_db_err($sth);

		my $hr = $sth->fetchrow_hashref;
		$sth->finish;

		if ( !$hr ) {
			$stab->msg_return("Unknown Trunk Group");
		}

		print $cgi->header( { -type => 'text/html' } ), "\n";
		print $stab->start_html( { -title => "Trunk Group" } ), "\n";

		my $opc = sprintf( "%09d", $hr->{'SRC_POINT_CODE'} );
		my $dpc = sprintf( "%09d", $hr->{'DST_POINT_CODE'} );

		$opc =~ s/(\d{3})(\d{3})(\d{3})/$1-$2-$3/;
		$dpc =~ s/(\d{3})(\d{3})(\d{3})/$1-$2-$3/;

		print $cgi->table(
			{ -align => 'center', -border => 1 },
			$cgi->Tr(
				$cgi->td(
					[
						$cgi->b('Vendor'),
						$hr->{'COMPANY_ID'}
					]
				)
			),
			$cgi->Tr(
				$cgi->td(
					[
						$cgi->b('Trunk'),
						$hr->{'TRUNK_GROUP_NAME'}
					]
				)
			),
			$cgi->Tr( $cgi->td( [ $cgi->b('OPC'), $opc ] ) ),
			$cgi->Tr( $cgi->td( [ $cgi->b('DPC'), $dpc ] ) ),
		);
	}

	my $sth = $stab->prepare(
		qq{
		select  ni.network_interface_id,
			ni.name as network_interface_name,
			d.device_name,
			p.physical_port_id,
			p.port_name,
			p.port_type,
			comp.company_name,
			c.circuit_id,
			c.vendor_circuit_id_str,
			ni.network_interface_type,
			tg.trunk_group_id,
			tg.trunk_group_name,
			c.trunk_tcic_start,
			c.trunk_tcic_end
		  from  physical_port p
			inner join network_interface ni on
				ni.physical_port_id = p.physical_port_id
			inner join device d on
				d.device_id = ni.device_id
			inner join layer1_connection l1c on
				(p.physical_port_id = l1c.physical_port1_id OR
				 p.physical_port_id = l1c.physical_port2_id)
			inner join circuit c on
				c.circuit_id = l1c.circuit_id
			inner join company comp on
				comp.company_id = c.VENDOR_COMPANY_ID
			inner join trunk_group tg
				on tg.trunk_group_id = c.trunk_group_id
		 where  tg.trunk_group_id = :1
		  and	d.is_locally_managed = 'Y'
		order by c.trunk_tcic_start
	}
	);
	$sth->execute($tgid) || $stab->return_db_err;

	my $count = 0;
	my $tt    = "";
	while ( my $hr = $sth->fetchrow_hashref ) {
		$count++;
		$tt .= $cgi->Tr(
			$cgi->td(
				[
					$hr->{'DEVICE_NAME'},
					$hr->{'NETWORK_INTERFACE_NAME'},
					$hr->{'VENDOR_CIRCUIT_ID_STR'},
					$hr->{'NETWORK_INTERFACE_TYPE'},
					$hr->{'TRUNK_TCIC_START'},
					$hr->{'TRUNK_TCIC_END'},
				]
			)
		);
	}

	print $cgi->table( { -border => 1, -align => 'center' }, $tt );

	print $cgi->end_html, "\n";

}
