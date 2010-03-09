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

use strict;
use warnings;
use JazzHands::STAB;

do_voe_compare();

sub do_voe_compare {
	my $stab = new JazzHands::STAB || die "Could not create STAB";

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $voe1id = $stab->cgi_parse_param('voe1');
	my $voe2id = $stab->cgi_parse_param('voe2');

	if ( defined($voe1id) && defined($voe2id) ) {
		compare_voees( $stab, $voe1id, $voe2id );
		return;
	}

	print $cgi->header('text/html');
	print $stab->start_html(
		{ -title => "JazzHands Operating Environment Comparisions" }
	  ),
	  "\n";

	print $stab->voe_compare_form;

	print $cgi->end_html;
}

sub compare_voees {
	my ( $stab, $voe1id, $voe2id ) = @_;

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $voe1 = $stab->get_voe_from_id($voe1id);
	my $voe2 = $stab->get_voe_from_id($voe2id);

	if ( !$voe1 || !$voe2 ) {
		$stab->error_return("Must specify two valid VOEs");
	}

	my $pkgs1 = $stab->get_packages_for_voe($voe1id);
	my $pkgs2 = $stab->get_packages_for_voe($voe2id);

	my %pkglist;
	foreach my $p ( keys(%$pkgs1) ) {
		$pkglist{$p}++;
	}
	foreach my $p ( keys(%$pkgs2) ) {
		$pkglist{$p}++;
	}

	my $voe1link =
	  $cgi->a( { -href => ".?VOE_ID=$voe1id" }, $voe1->{'VOE_NAME'} );
	my $voe2link =
	  $cgi->a( { -href => ".?VOE_ID=$voe2id" }, $voe2->{'VOE_NAME'} );

	my $oldstyle  = "";
	my $bothstyle = "";
	my $newstyle  = "background: salmon;";
	my $nodiff    = 'color: grey';
	my $onestyle  = "background: orange";

	my $tt = $cgi->th( [ $voe1link, 'Package', $voe2link ] );
	foreach my $p ( sort keys %pkglist ) {
		my $v1 = ( defined( $pkgs1->{$p} ) ) ? $pkgs1->{$p} : "";
		my $v2 = ( defined( $pkgs2->{$p} ) ) ? $pkgs2->{$p} : "";
		my $newer = $stab->cmpPkgVer( $v1, $v2 );

		my ( $s1, $s2, $pstyle );
		if ( $v1 eq "" || $v2 eq "" ) {
			$s1 = $s2 = $oldstyle;
			$pstyle = $onestyle;
		} elsif ( $v1 eq $v2 ) {
			$s1 = $s2 = $pstyle = $nodiff;
		} elsif ( $v1 eq $newer ) {
			$s1     = $newstyle;
			$s2     = $oldstyle;
			$pstyle = $bothstyle;
		} elsif ( $v2 eq $newer ) {
			$s1     = $oldstyle;
			$s2     = $newstyle;
			$pstyle = $bothstyle;
		}

		$tt .= $cgi->Tr(
			$cgi->td( { -style => $s1 },     $v1 ),
			$cgi->td( { -style => $pstyle }, $p ),
			$cgi->td( { -style => $s2 },     $v2 ),
		);
	}

	print $cgi->header('text/html');
	print $stab->start_html( { -title => "VOE Compare" } ), "\n";

	print $cgi->table( { -align => 'center', -border => 1 }, $tt );

	print $cgi->end_html;
}
