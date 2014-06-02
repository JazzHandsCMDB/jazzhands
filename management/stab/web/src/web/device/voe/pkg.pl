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
use FileHandle;
use JazzHands::STAB;

do_sw_package();

sub do_sw_package {
	my $stab = new JazzHands::STAB || die "Could not create STAB";

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $pkgid = $stab->cgi_parse_param('pkgrid');

	if ( defined($pkgid) ) {
		dump_package_release( $stab, $pkgid );
		return;
	}

	$stab->msg_return("Nothing to do yet");
	undef $stab;
}

sub dump_package_release {
	my ( $stab, $pkgid ) = @_;

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $pkg = $stab->get_package_release($pkgid);

	if ( !defined($pkg) ) {
		$stab->error_return("Unknown package ($pkgid)");
	}

	my $pkgtable = build_packagedesc_table( $stab, $pkg );
	my $deptable = build_package_assoc_table( $stab, $pkg );

	print $cgi->header;
	print $stab->start_html("Package Information");

	print $cgi->table( { -border => 1, -align => 'center' },
		$cgi->Tr( $cgi->td($pkgtable), $cgi->td($deptable) ) );
}

sub build_packagedesc_table {
	my ( $stab, $pkg ) = @_;

	my $cgi = $stab->cgi || die "Could not create cgi";

	my $tt = "";
	$tt .= $stab->build_tr( undef, $pkg, undef, "Package Name",
		"SW_PACKAGE_NAME", 'SW_PACKAGE_RELEASE_ID' );
	$tt .=
	  $stab->build_tr( undef, $pkg, undef, "Version", "SW_PACKAGE_VERSION",
		'SW_PACKAGE_RELEASE_ID' );
	$tt .=
	  $stab->build_tr( undef, $pkg, undef, "Added", "INSTANTIATION_DATE",
		'SW_PACKAGE_RELEASE_ID' );
	$tt .=
	  $stab->build_tr( undef, $pkg, undef, "Format", "SW_PACKAGE_FORMAT",
		'SW_PACKAGE_RELEASE_ID' );
	$tt .= $stab->build_tr( undef, $pkg, undef, "Uploaded By",
		"UPLOADING_PRINCIPAL", 'SW_PACKAGE_RELEASE_ID' );
	$tt .=
	  $stab->build_tr( undef, $pkg, undef, "Package Size", "PACKAGE_SIZE",
		'SW_PACKAGE_RELEASE_ID' );
	$tt .= $stab->build_tr( undef, $pkg, undef, "Pathname", "PATHNAME",
		'SW_PACKAGE_RELEASE_ID' );
	$tt .= $stab->build_tr( undef, $pkg, undef, "md5sum", "MD5SUM",
		'SW_PACKAGE_RELEASE_ID' );
	$tt .= $stab->build_tr( undef, $pkg, undef, "Architecture",
		"PROCESSOR_ARCHITECTURE", 'SW_PACKAGE_RELEASE_ID' );

	$cgi->table( { -align => 'center' }, $tt );
}

sub build_package_assoc_table {
	my ( $stab, $pkg ) = @_;

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $q = qq{
		select  p.sw_package_name,
			spr.PACKAGE_RELATION_TYPE,
			spr.RELATION_RESTRICTION
		  from  sw_package_relation spr
			inner join sw_package p
				on spr.RELATED_SW_PACKAGE_ID
					= p.sw_package_id
		 where  spr.sw_package_release_id = :1 
		order by spr.package_relation_type, p.sw_package_name
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute( $pkg->{SW_PACKAGE_RELEASE_ID} )
	  || $stab->return_db_err($sth);

	my $tt = "";
	while ( my ( $n, $ass, $r ) = $sth->fetchrow_array ) {
		$tt .=
		  $cgi->Tr( $cgi->td($ass), $cgi->td($n),
			$cgi->td( ( ($r) ? $r : "" ) ) );
	}
	$cgi->table( { -align => 'center' }, $tt );
}
