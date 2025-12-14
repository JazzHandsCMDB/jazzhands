#!/usr/bin/env perl

#
# Copyright (c) 2017 Todd Kover
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

use strict;
use warnings;
use POSIX;
use Data::Dumper;
use Carp;
use JazzHands::STAB;

do_layer2_network_toplevel();

sub do_layer2_network_toplevel {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";

	my $l2net = $stab->cgi_parse_param('LAYER2_NETWORK_ID');

	if ($l2net) {
		dump_l2_network( $stab, $l2net );
	} else {
		print $cgi->header('text/html'), $stab->start_html, "Not implemented",
		  $cgi->end_html;
	}
	undef $stab;
}

sub get_layer3_table($$) {
	my ( $stab, $l2netid ) = @_;

	my $cgi = $stab->cgi;

	my $sth = $stab->prepare(
		qq{
		SELECT	*
		FROM	layer3_network
				JOIN netblock USING (netblock_id)
		WHERE	layer2_network_id = ?
	}
	) || return $stab->return_db_err();

	$sth->execute($l2netid) || return $stab->return_db_err();

	my $t = '';
	while ( my $hr = $sth->fetchrow_hashref ) {
		my $a = $cgi->a( {
				-href => "../l3/?LAYER3_NETWORK_ID="
				  . $hr->{'LAYER3_NETWORK_ID'}
			},
			$hr->{'IP_ADDRESS'}
		);
		$t .= $cgi->li($a);
	}
	return $cgi->ul($t);

}

sub dump_l2_network {
	my $stab    = shift @_;
	my $l2netid = shift @_;

	my $cgi = $stab->cgi || die "Could not create cgi";
	my $sth = $stab->prepare(
		qq{
		SELECT *
		FROM	layer2_network
		WHERE	layer2_network_id = ?
	}
	) || die $stab->return_db_err();
	$sth->execute($l2netid);

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;

	my $l3table = get_layer3_table( $stab, $l2netid );

	my $t = $cgi->table(
		{ -class => 'reporting' },
		$cgi->Tr( $cgi->td( [ "Description", $hr->{'DESCRIPTION'} || '' ] ) ),
		$cgi->Tr( $cgi->td(
			[ "Encapsulation Name", $hr->{'ENCAPSULATION_NAME'} ] ) ),
		$cgi->Tr( $cgi->td( [
			"Encapsulation Domain", $hr->{'ENCAPSULATION_DOMAIN'}
		] ) ),
		$cgi->Tr( $cgi->td(
			[ "Encapsulation Type", $hr->{'ENCAPSULATION_TYPE'} ] ) ),
		$cgi->Tr( $cgi->td(
			[ "Encapsulation Tag", $hr->{'ENCAPSULATION_TAG'} ] ) ),
		$cgi->Tr( $cgi->td( [ "Layer 3 Networks", $l3table ] ) ),
	);

	print $cgi->header('text/html');
	print $stab->start_html( -title => 'Layer2 Network' );
	print $cgi->p($t);
	print $cgi->end_html;

}
