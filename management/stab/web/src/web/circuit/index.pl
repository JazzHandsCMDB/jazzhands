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

do_circuit_toplevel();

sub do_circuit_toplevel {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";
	my $dbh  = $stab->dbh          || die "Could not create dbh";

	my $circid = $stab->cgi_parse_param('CIRCUIT_ID');

	if ( !defined($circid) ) {
		circuit_search($stab);
	} else {
		dump_circuit( $stab, $circid );
	}
	undef $stab;
}

sub circuit_search {
	my ($stab) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";
	my $dbh = $stab->dbh || die "Could not create dbh";

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html( { -title => "Circuit Search" } ), "\n";

	print "totally not implemented";

	print $cgi->end_html, "\n";

}

sub dump_circuit {
	my ( $stab, $circid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $c = $stab->get_circuit($circid);
	my $tg;

	if ( $c->{'TRUNK_GROUP_ID'} ) {
		$tg = $stab->get_trunk_group( $c->{'TRUNK_GROUP_ID'} );
	}

	#
	# [XXX] need to limit options to voice circuits.
	#
	my $ctab = $cgi->table(
		{ -align => 'center' },
		$stab->build_tr(
			undef,               $c,
			'b_dropdown',        "Carrier",
			'VENDOR_COMPANY_ID', 'CIRCUIT_ID'
		),
		$stab->build_tr(
			undef,                   $c,
			'b_textfield',           "Circuit ID",
			"VENDOR_CIRCUIT_ID_STR", 'CIRCUIT_ID'
		),
		$stab->build_tr(
			undef,            $c,
			'b_textfield',    "JazzHands PO(N)",
			"PURCHASE_ORDER", 'CIRCUIT_ID'
		),
		$stab->build_tr(
			undef,                    $c,
			'b_dropdown',             "Interface Type",
			"NETWORK_INTERFACE_TYPE", 'CIRCUIT_ID'
		),
		$stab->build_tr(
			undef,               $c,
			'b_dropdown',        "Signaling",
			"CIRCUIT_SIGNALING", 'CIRCUIT_ID'
		),

		#
		# [XXX] TCIC  should only be printed on voice oc3s!
		#
		$stab->build_tr(
			undef,              $c,
			'b_textfield',      "TCIC Start",
			"TRUNK_TCIC_START", 'CIRCUIT_ID'
		),
		$stab->build_tr(
			undef,            $c,
			'b_textfield',    "TCIC End",
			"TRUNK_TCIC_END", 'CIRCUIT_ID'
		),
	);

	#
	# deal with aloc/zloc
	#
	my $atab = build_circuit_aloc( $stab, $c, 'A' );
	my $ztab = build_circuit_aloc( $stab, $c, 'Z' );

	my $l1table = dump_circuit_l1table( $stab, $circid );

	## [XXX] need to incoprorate physical connections

	my $cstr =
	  ($c) ? "Circuit " . $c->{'VENDOR_CIRCUIT_ID_STR'} : "Circuit";

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html( { -title => $cstr } ), "\n";
	print $cgi->table(
		{ -align => 'center', -border => 1 },
		$cgi->Tr( $cgi->td( { -colspan => 2 }, $ctab ) ),
		$cgi->Tr( $cgi->td($atab), $cgi->td($ztab) ),
		$cgi->Tr( $cgi->td( { -colspan => 2 }, $l1table ) ),
	);
	print $cgi->end_html, "\n";

}

sub build_circuit_aloc {
	my ( $stab, $c, $side ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	#
	# [XXX] link to circuit if it's something we manage, otherwise it should
	# be editable.  For our stuff you should have to actually go to the
	# circuit (but need to figure out how to CHANGE it).
	#

	my $label = "$side Location";
	if ( $side eq 'A' ) {
		$label .= " (Market)";
	} elsif ( $side eq 'Z' ) {
		$label .= " (Site)";
	}

       #
       # maybe have the site/market options available via drop down?
       # site option gets pulled from the device where it ultimately terminates.
       # A location should have a market pull down
       # Z location should have a site code pull down
       #

	$cgi->table(
		$cgi->Tr(
			$cgi->td(
				{ -colspan => 2, -align => 'center', },
				$cgi->b($label)
			)
		),
		$stab->build_tr(
			undef,                       $c,
			'b_dropdown',                "Carrier",
			"${side}LOC_LEC_COMPANY_ID", 'CIRCUIT_ID'
		),
		$stab->build_tr(
			undef,                           $c,
			'b_textfield',                   "Circuit ID",
			"${side}LOC_LEC_CIRCUIT_ID_STR", 'CIRCUIT_ID'
		),
		$stab->build_tr(
			undef,       $c, 'b_dropdown', "Site Code",
			"SITE_CODE", 'SITE_CODE'
		),
	);
}

sub dump_circuit_l1table {
	my ( $stab, $cid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $sth = $stab->prepare(
		qq{
		select  ni.network_interface_id,
			ni.name as network_interface_name,
			d.device_id,
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
				company.company_id = c.VENDOR_COMPANY_ID
			left join trunk_group tg
				on tg.trunk_group_id = c.trunk_group_id
		 where  c.circuit_id = :1
		  and	d.is_locally_managed = 'Y'
		order by d.device_id, NETWORK_STRINGS.NUMERIC_INTERFACE(ni.name)
	}
	);

	$sth->execute($cid) || $stab->return_db_err($sth);

	#
	# [XXX} automatically open the correct tab
	#
	my $tt = $cgi->Tr( { -align => 'center' },
		$cgi->td( $cgi->b("Logical Termination") ) );
	while ( my $hr = $sth->fetchrow_hashref ) {
		my $link = $cgi->a(
			{
				-href => "../device/device.pl?devid="
				  . $hr->{'DEVICE_ID'}
			},
			$hr->{'DEVICE_NAME'} . ":"
			  . $hr->{'NETWORK_INTERFACE_NAME'}
		);
		$tt .= $cgi->Tr( { -align => 'center' }, $cgi->td($link), );

	}

	$cgi->table( { -align => 'center' }, $tt );
}
