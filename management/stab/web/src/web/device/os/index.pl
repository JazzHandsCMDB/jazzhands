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

do_operating_system();

sub do_operating_system {
	my $stab = new JazzHands::STAB || die "Could not create STAB";

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $osid = $stab->cgi_parse_param('OPERATING_SYSTEM_ID');

	if ( defined($osid) ) {
		manip_operating_system( $stab, $osid );
		return;
	}

	print $cgi->header('text/html');
	print $stab->start_html( { -title => "Operating System" } ), "\n";

	print $cgi->start_form( { -method => 'POST', -action => 'search.pl' } );
	print $cgi->div(
		{ -align => 'center' },
		$cgi->h3( { -align => 'center' }, 'Pick an Operating System:' ),
		$stab->b_dropdown( undef, 'OPERATING_SYSTEM_ID', undef, 1 ),
		$cgi->submit
	);
	print $cgi->end_form;

	print $cgi->end_html;
}

sub manip_operating_system {
	my ( $stab, $osid ) = @_;

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $os = $stab->get_operating_system_from_id($osid);

	my $table = $cgi->table(
		{ -align => 'center' },
		$stab->build_tr(
			$os,      "b_dropdown",
			"Vendor", 'COMPANY_ID',
			'OPERATING_SYSTEM_ID'
		),
		$stab->build_tr(
			$os,    "b_textfield",
			"Name", 'NAME',
			'OPERATING_SYSTEM_ID'
		),
		$stab->build_tr(
			$os,       "b_textfield",
			"Version", 'VERSION',
			'OPERATING_SYSTEM_ID'
		),
		$stab->build_tr(
			$os,    "b_dropdown",
			"Arch", 'PROCESSOR_ARCHITECTURE',
			'OPERATING_SYSTEM_ID'
		),
		$cgi->Tr(
			$cgi->td(
				{ -align => 'center', -colspan => 2 },
				$cgi->hidden( 'OPERATING_SYSTEM_ID', $osid ),
				$cgi->submit
			)
		),
	);

	my $name    = $os->{NAME};
	my $version = $os->{VERSION};

	print $cgi->header('text/html');
	print $stab->start_html(
		{ -title => "Operating System $name $version" } ), "\n";
	print $cgi->start_form(
		{ -method => 'POST', -action => 'write/updateos.pl' } );
	print $table;
	print $cgi->end_form;
	print $cgi->end_html;
}
