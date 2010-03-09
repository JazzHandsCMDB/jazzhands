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
use Net::Netmask;
use FileHandle;
use JazzHands::STAB;

do_rack();

############################################################################3
#
# everything else is a subroutine
#
############################################################################3

sub do_rack {
	my $stab = new JazzHands::STAB || die "Could not create STAB";

	my $cgi = $stab->cgi || die "Could not create cgi";

	my $rackid = $stab->cgi_parse_param('RACK_ID');

	if ( defined($rackid) && $rackid ) {
		do_one_rack( $stab, $rackid );
		return;
	}

	do_rack_chooser($stab);
}

sub do_rack_chooser {
	my ($stab) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $rackdivid = "pickrack";

	print $cgi->header('text/html');
	print $stab->start_html(
		{
			-title      => "Rack Search",
			-javascript => 'rack',
		}
	);
	print $cgi->start_form( { -method => 'GET', -action => './' } );
	print $cgi->h3( { -align => 'center' }, 'Pick a site:' );
	print $cgi->div(
		{ -align => 'center' },
		$stab->b_dropdown(
			{
				-onChange =>
				  "site_to_rack(\"SITE_CODE\", \"$rackdivid\");"
			},
			undef,
			'SITE_CODE',
			undef, 1
		),
	);

	print $cgi->h3( { -align => 'center' }, 'Pick a rack:' );
	print $cgi->div(
		{ -align => 'center', -id => $rackdivid },
		$stab->b_dropdown( undef, 'RACK_ID', undef, 1 ),
	);

	print $cgi->h3( { -align => 'center' }, $cgi->submit );

	print $cgi->end_form;
	print $cgi->end_html;
}

sub do_one_rack {
	my ( $stab, $rackid ) = @_;

	my $cgi = $stab->cgi || die "Could not create cgi";

	my $hr = $stab->get_rack_from_rackid($rackid);

	my $box = join(
		"",
		$stab->build_tr(
			$hr, "b_dropdown", "Site", "SITE_CODE", "RACK_ID"
		),
		$stab->build_tr(
			$hr, "b_textfield", "Room", "ROOM", "RACK_ID"
		),
		$stab->build_tr(
			$hr, "b_textfield", "Sub-Room", "SUB_ROOM",
			"RACK_ID"
		),
		$stab->build_tr(
			$hr, "b_textfield", "Row", "RACK_ROW", "RACK_ID"
		),
		$stab->build_tr(
			$hr, "b_textfield", "Rack", "RACK_NAME", "RACK_ID"
		),

		#$stab->build_tr($hr, "b_textfield",
		#	"Height in U", "RACK_HEIGHT_IN_U", "RACK_ID"),
		# [XXX]Display from Bottom
	);

	my $rack = $stab->build_rack($rackid);

	print $cgi->header('text/html');
	print $stab->start_html(
		{
			-title      => "Rack",
			-javascript => 'rack',
		}
	);

	print $cgi->start_form(
		{ -method => 'GET', -action => 'write/updaterack.pl' } );
	print $cgi->table( { -class => 'rack_summary', -align => 'center' },
		$box );

	# print $cgi->div({-align=>'center'}, $cgi->submit("Submit Changes"));
	print $cgi->end_form;
	print $cgi->div( { -align => 'center' }, $rack );

	print $cgi->end_html;

}
