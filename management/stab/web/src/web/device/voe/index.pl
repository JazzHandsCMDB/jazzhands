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
use FileHandle;
use JazzHands::STAB;

do_operating_system();

sub do_operating_system {
	my $stab = new JazzHands::STAB || die "Could not create STAB";

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $voeid = $stab->cgi_parse_param('VOE_ID');

	if ( defined($voeid) ) {
		manip_voe( $stab, $voeid );
		return;
	}

	print $cgi->header('text/html');
	print $stab->start_html(
		{ -title => "Versioned Operating Environment (VOE)" } ), "\n";

	print $cgi->start_form( { -method => 'POST', -action => 'search.pl' } );
	print $cgi->div(
		{ -align => 'center' },
		$cgi->h3( { -align => 'center' }, 'Examine a VOE:' ),
		$stab->b_dropdown( undef, 'VOE_ID', undef, 1 ),
		$cgi->submit
	);
	print $cgi->end_form;

	print $cgi->hr;

	print $stab->voe_compare_form;

	print $cgi->hr;

	print $cgi->div(
		{ -align => 'center' },
		$cgi->a(
			{ -href => 'voesymtrax.pl', -align => 'center' },
			"VOE Symbolic Tracks"
		),
		" - These are the repositories that apt/vprac use"
	);

	print $cgi->hr;
	print $cgi->end_html;
}

sub manip_voe {
	my ( $stab, $voeid ) = @_;

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $voe = $stab->get_voe_from_id($voeid);

	my $version = $voe->{VOE_NAME};
	my $state   = $voe->{VOE_STATE};

	my $swrep = "--None--";
	if ( defined( $voe->{SW_PACKAGE_REPOSITORY_ID} ) ) {
		$swrep =
		    $voe->{SW_PACKAGE_REPOSITORY_NAME} . "("
		  . $voe->{APT_REPOSITORY} . ")";
	}

	my $table = $cgi->table(
		{ -align => 'center' },
		$cgi->Tr( $cgi->td( "Version:", $version ) ),
		$cgi->Tr( $cgi->td( "SWRepo:",  $swrep ) ),
		$cgi->Tr( $cgi->td( "State:",   $state ) ),
	);

	my $pkgtable = build_voe_package_table( $stab, $voeid ) || "";
	my $devtable = build_voe_device_table( $stab, $voeid ) || "";
	my $upgradetable = build_voe_upgrade_table( $stab, $voeid ) || "";

	my $lhs = $cgi->td($pkgtable);
	my $rhs = $cgi->td(
		{ -valign => 'top' },
		$cgi->table(
			{ -border => 1 },
			$cgi->Tr( $cgi->td($upgradetable) ),
			$cgi->Tr( $cgi->td($devtable) )
		)
	);

	print $cgi->header('text/html');
	print $stab->start_html( { -title => "VOE $version" } ), "\n";

      #print $cgi->start_form({-method=>'POST', -action=>'write/updatevoe.pl'});
	print $cgi->table(
		{ -border => 1 },
		$cgi->Tr(
			$cgi->td(
				{ -align => 'center', -colspan => 2 }, $table
			)
		),
		$cgi->Tr( $lhs, $rhs ),
	);

	#print $cgi->end_form;
	print $cgi->end_html;
}

sub build_voe_package_table {
	my ( $stab, $voeid ) = @_;

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $q = qq{
		select  pkgr.sw_package_release_id,
			pkg.sw_package_name, pkgr.sw_package_version, 
			pkg.description
		  from  sw_package pkg
			inner join sw_package_release pkgr
				on pkgr.sw_package_id = pkg.sw_package_id
			inner join voe_sw_package voeswp
				on voeswp.sw_package_release_id =
					pkgr.sw_package_release_id
		 where  voeswp.voe_id = :1
		order by pkg.sw_package_name


	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute($voeid) || $stab->return_db_err($sth);

	my $tt = "";
	while ( my ( $pkgrid, $n, $v, $desc ) = $sth->fetchrow_array ) {
		my $pkglink =
		  $cgi->a( { -href => "pkg.pl?pkgrid=$pkgrid" }, "$n-$v" );
		$tt .=
		  $cgi->Tr( $cgi->td($pkglink),
			$cgi->td( ( ($desc) ? $desc : "" ) ) );
	}
	$sth->finish;
	$cgi->table( { -border => 1 },
		$cgi->caption( $cgi->b("Packages") ), $tt );
}

sub build_voe_upgrade_table {
	my ( $stab, $voeid ) = @_;

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $q = qq{
	    select  vr.related_voe_id, vu.upgrade_severity
	     from       val_upgrade_severity vu 
			left join 
			(select * from voe_relation where voe_id = :1
					and is_active = 'Y') vr
				on vu.upgrade_severity = vr.upgrade_severity
	    order by vu.severity_factor desc
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute($voeid) || $stab->return_db_err($sth);

	my $tt = "";
	while ( my ( $id, $severity ) = $sth->fetchrow_array ) {
		my $voelink;
		if ($id) {
			$voelink = build_voe_link( $stab, $id, $voeid );
		} else {
			$voelink = "--none--";
		}

		$tt .= $cgi->Tr( $cgi->td($voelink), $cgi->td($severity) );
	}
	$sth->finish;
	$cgi->table( { -border => 1 },
		$cgi->caption( $cgi->b("Upgrade Path") ), $tt );
}

sub build_voe_device_table {
	my ( $stab, $voeid ) = @_;

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $q = qq{
			select  device_id, device_name
			  from  device
			 where  voe_id = :1
			  order	by device_name
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute($voeid) || $stab->return_db_err($sth);

	my $tt = "";
	while ( my ( $id, $name ) = $sth->fetchrow_array ) {
		$tt .= $cgi->Tr(
			$cgi->td(
				$cgi->a(
					{ -href => "../device.pl?devid=$id" },
					$name
				)
			)
		);
	}
	$sth->finish;
	$cgi->table( $cgi->caption( $cgi->b("Devices") ), $tt );
}

sub build_voe_link {
	my ( $stab, $id, $fromvoeid ) = @_;

	my $cgi = $stab->cgi;

	my $rv;
	if ( !$id ) {
		return ("--none--");
	} else {
		my $voe = $stab->get_voe_from_id($id);
		$rv =
		  $cgi->a( { -href => "./?VOE_ID=" . $id },
			$voe->{'VOE_NAME'} );
	}

	if ($fromvoeid) {
		$rv .= $cgi->a(
			{ -href => "voecompare.pl?voe1=$fromvoeid;voe2=$id" },
			"[diff]" );
	}

	$rv;

}
