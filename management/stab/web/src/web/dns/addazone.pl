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

do_add_a_zone();

sub do_add_a_zone {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";
	my $dbh  = $stab->dbh          || die "Could not create dbh";

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html(
		{ -title => "Add A Zone", -javascript => 'dns' } ), "\n";

	print $cgi->start_form( { -action => "write/add_domain.pl" } );

	print $cgi->start_table( { -align => 'center' } );
	print $cgi->Tr(
		$cgi->td(
			"Domain Name",
			$stab->b_textfield(
				undef, 'SOA_NAME', 'DNS_DOMAIN_ID'
			)
		)
	);
	print $cgi->Tr( $cgi->td( $stab->zone_header ) );
	print $cgi->Tr(
		{ -align => 'center' },
		$cgi->td(
			$cgi->a(
				{
					-id   => 'soa_switch',
					-href => 'javascript:void(null)',
					-onClick =>
'show_soa("soa_switch", "soa_table");',
				},
				"Change SOA Defaults"
			)
		)
	);

	print $cgi->Tr(
		{ -align => 'center' },
		$cgi->td(
			$cgi->b("Domain Type: ")
			  . $stab->b_dropdown(
				undef, undef,
				'DNS_DOMAIN_TYPE', 'DNS_DOMAIN_TYPE', 1
			  ),
		),
	  ),
	  $cgi->Tr(
		{ -align => 'center' },
		$cgi->td(
			$stab->build_checkbox(
				undef,             "Should Generate",
				"SHOULD_GENERATE", 'DNS_DOMAIN_ID',
				1
			)
		)
	  ),
	  $cgi->Tr(
		{ -align => 'center' },
		$cgi->td(
			$stab->build_checkbox(
				undef, "Add Default NS Records",
				"DEFAULT_NS_RECORDS", 'DNS_DOMAIN_ID', 1
			)
		)
	  );
	print $cgi->Tr(
		{ -align => "center" },
		$cgi->td(
			$cgi->submit(
				-name  => "New",
				-value => "Add Domain"
			)
		)
	);
	print $cgi->end_table;

	print $cgi->end_form;
	undef $stab;
}
