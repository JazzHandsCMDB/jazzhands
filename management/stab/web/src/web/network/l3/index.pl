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
use JazzHands::Common qw(_dbx);

do_layer3_network_toplevel();

sub do_layer3_network_toplevel {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";

	my $l3net = $stab->cgi_parse_param('LAYER3_NETWORK_ID');

	if ($l3net) {
		dump_l3_network( $stab, $l3net );
	} else {
		print $cgi->header('text/html'), $stab->start_html, "Not implemented",
		  $cgi->end_html;
	}
	undef $stab;
}

sub dump_l3_network {
	my $stab    = shift @_;
	my $l3netid = shift @_;

	my $cgi = $stab->cgi || die "Could not create cgi";
	my $sth = $stab->prepare( qq{
		SELECT l3.*,
				concat(encapsulation_type, ' ',
					encapsulation_domain, ':', encapsulation_name) AS
					layer2_network_name
		FROM	layer3_network l3
				LEFT JOIN layer2_network l2 USING (layer2_network_id)
		WHERE	layer3_network_id = ?
	}
	) || die $stab->return_db_err();
	$sth->execute($l3netid) || die $stab->return_db_err();

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;

	my $l2tr =
	  ( $hr->{ _dbx('LAYER2_NETWORK_ID') } )
	  ? $cgi->Tr( $cgi->td( [
		'Layer2 Network',
		$cgi->a( {
				-href => '../l2/?LAYER2_NETWORK_ID='
				  . $hr->{ _dbx('LAYER2_NETWORK_ID') }
			},
			$hr->{ _dbx('LAYER2_NETWORK_NAME') }
		)
	  ] ) )
	  : "";

	my ( $nbt, $dgwt ) = ( "", "" );

	if ( my $nb = $stab->get_netblock_from_id( $hr->{ _dbx('NETBLOCK_ID') } ) )
	{
		$nbt = $cgi->Tr( $cgi->td( [
			'Network',
			$cgi->a( {
					-href => "../../netblock/?nblkid="
					  . $nb->{ _dbx('NETBLOCK_ID') }
				},
				$nb->{ _dbx('IP_ADDRESS') }
			),
		] ) );
	}

	if (
		my $nb = $stab->get_netblock_from_id(
			$hr->{ _dbx('DEFAULT_GATEWAY_NETBLOCK_ID') }
		)
	  )
	{
		$dgwt =
		  $cgi->Tr( $cgi->td( [ 'Default Gateway', $nb->{ _dbx('IP') } ] ) );
	}

	my $t = $cgi->table(
		{ -class => 'reporting' },
		$cgi->Tr(
			$cgi->td( [ "Description", $hr->{ _dbx('DESCRIPTION') } || '' ] )
		),
		$l2tr, $nbt,
		$dgwt,

	);

	print $cgi->header('text/html');
	print $stab->start_html( -title => 'Layer3 Network' );
	print $cgi->p($t);
	print $cgi->end_html;

}
