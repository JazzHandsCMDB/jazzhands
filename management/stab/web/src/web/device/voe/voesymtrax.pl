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

	my $voesymtraxid = $stab->cgi_parse_param('VOE_SYMBOLIC_TRACK_ID');

	if ( defined($voesymtraxid) ) {
		manip_voe_trax( $stab, $voesymtraxid );
		return;
	}

	print $cgi->header('text/html');
	print $stab->start_html( { -title => "VOE Symbolic Track" } ), "\n";

	print $cgi->start_form(
		{ -method => 'GET', -action => 'voesymtrax.pl' } );
	print $cgi->div(
		{ -align => 'center' },
		$cgi->h4(
			{ -align => 'center' },
			'Examine a VOE Symbolic Track:'
		),
		$cgi->p("(These correspond to apt repositories)"),
		$stab->b_dropdown( undef, 'VOE_SYMBOLIC_TRACK_ID', undef, 1 ),
		$cgi->submit
	);
	print $cgi->end_form;

	print $cgi->end_html;
}

sub manip_voe_trax {
	my ( $stab, $voesymtraxid ) = @_;

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $hr   = get_voe_sym_trax_id( $stab, $voesymtraxid );
	my $name = $hr->{SYMBOLIC_TRACK_NAME};
	my $repo = $hr->{APT_REPOSITORY};

	my $alink = $cgi->a( { -href => "./?VOE_ID=" . $hr->{ACTIVE_VOE_ID} },
		$hr->{'ACTIVE_VOE_NAME'} );
	my $plink = "";
	if ( $hr->{'PENDING_VOE_ID'} ) {
		$plink =
		  $cgi->a( { -href => "./?VOE_ID=" . $hr->{PENDING_VOE_ID} },
			$hr->{'PENDING_VOE_NAME'} );
	}

	my $table = $cgi->table(
		{ -align => 'center', -border => 1 },
		$cgi->Tr( $cgi->td( $cgi->b("Name:") ),      $cgi->td($name) ),
		$cgi->Tr( $cgi->td( $cgi->b("ActiveVOE:") ), $cgi->td($alink) ),
		$cgi->Tr(
			$cgi->td( $cgi->b("PendingVOE:") ), $cgi->td($plink)
		),
		$cgi->Tr( $cgi->td( $cgi->b("Repo:") ), $cgi->td($repo) ),
	);

	print $cgi->header('text/html');
	print $stab->start_html( { -title => "VOE Symbolic Track $name" } ),
	  "\n";
	print $table;
	print $cgi->end_html;
}

sub get_voe_sym_trax_id {
	my ( $stab, $id ) = @_;

	my $dbh = $stab->dbh || die "Could not create dbh";

	my $q = qq{
		select	vt.VOE_SYMBOLIC_TRACK_ID,
			vt.SYMBOLIC_TRACK_NAME,
			vt.ACTIVE_VOE_ID,
			avoe.VOE_NAME as ACTIVE_VOE_NAME,
			vt.PENDING_VOE_ID,
			pvoe.VOE_NAME as PENDING_VOE_NAME,
			vt.SW_PACKAGE_REPOSITORY_ID,
			spr.apt_repository
		  from	voe_symbolic_track vt
			left join VOE avoe
				on avoe.VOE_ID = vt.ACTIVE_VOE_ID
			left join VOE pvoe
				on pvoe.VOE_ID = vt.PENDING_VOE_ID
			left join SW_PACKAGE_REPOSITORY spr
				on spr.sw_package_repository_id =
					vt.sw_package_repository_id
		where	vt.voe_symbolic_track_id = :1
	};
	my $sth = $stab->prepare($q) || $stab->return_db_error($dbh);
	$sth->execute($id) || $stab->return_db_error($sth);

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}
