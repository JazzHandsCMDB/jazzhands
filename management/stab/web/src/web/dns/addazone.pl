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

	print $cgi->header( { -type => 'text/html', -charset => 'utf-8' } ), "\n";
	print $stab->start_html( { -title => "Add A Zone", -javascript => 'dns' } ),
	  "\n";

	print $cgi->h3( { -align => 'center' }, "Add a DNS Zone" );

	print $cgi->start_form( { -action => "write/add_domain.pl" } );

	print $cgi->div( {
		-style => 'max-width: 1000px; margin: 20px auto; border: 2px solid var(--border); padding: 20px; background-color: var(--table-column-background-even);'
	} );

	print $cgi->start_table( {
		-align       => 'center',
		-border      => 0,
		-cellpadding => 8,
		-cellspacing => 0,
		-style       => 'width: 100%;'
	} );

	# Check if there are multiple IP universes
	my $universe_count = $stab->get_ip_universe_count();

	if ( $universe_count > 1 ) {

		# Domain selection section - visually grouped
		print $cgi->Tr( $cgi->td( {
				-colspan => 2,
				-style   => 'padding: 15px; border: 2px solid var(--border); background-color: var(--background-color-box); border-radius: 5px;'
			},
			$cgi->div( { -style => 'margin-bottom: 5px; display: flex;' },
				$cgi->span( { -style => 'font-weight: bold; display: inline-block; width: 230px; flex-shrink: 0;' }, "Create New Domain:"),
				$cgi->textfield(
					-name  => 'SOA_NAME',
					-style => 'flex-grow: 1;'
				)
			),
			$cgi->div( { -style => 'margin-bottom: 10px; display: flex;' },
				$cgi->span( { -style => 'font-weight: bold; display: inline-block; width: 230px; flex-shrink: 0;' }, "Type:"),
				$cgi->div( { -style => 'flex-grow: 1;' },
					$stab->b_dropdown(
						undef, undef, 'DNS_DOMAIN_TYPE', 'DNS_DOMAIN_TYPE', 1
					)
				)
			),
			$cgi->div( {
				-align => 'center',
				-style => 'margin: 10px 0; position: relative;'
			},
				$cgi->hr( { -style => 'border: var(--border); margin: 0;' } ),
				$cgi->span( {
					-style => 'position: absolute; top: -10px; left: 50%; transform: translateX(-50%); background-color: var(--background-color-box); padding: 0 10px; font-weight: bold;'
				}, "OR" ),
			),
			$cgi->div( { -style => 'display: flex;' },
				$cgi->span( { -style => 'font-weight: bold; display: inline-block; width: 230px; flex-shrink: 0;' }, "Add Universe to Domain:"),
				$cgi->div( { -style => 'flex-grow: 1;' },
					$stab->b_dropdown(
						undef, undef, 'DNS_DOMAIN_ID', 'DNS_DOMAIN_ID', 0
					)
				)
			)
		) );

		# IP Universe - separate section
		print $cgi->Tr( $cgi->td( {
				-colspan => 2,
				-style   => 'padding: 15px; margin-top: 15px; border-top: 2px solid var(--border); text-align: center;'
			},
			$cgi->span( { -style => 'font-weight: bold; white-space: nowrap;' }, "IP Universe:"),
			$cgi->span( { -style => 'color: var(--color-error); font-size: 0.9em;' }, " *" ),
			" ",
			$stab->b_dropdown(
				undef, undef, 'IP_UNIVERSE_ID', 'IP_UNIVERSE_ID', 0
			)
		) );
	} else {

		# Single universe - show textfield and domain type on separate lines
		print $cgi->Tr( $cgi->td( { -colspan => 2 },
			$cgi->div( { -style => 'margin-bottom: 5px; display: flex;' },
				$cgi->span( { -style => 'font-weight: bold; display: inline-block; width: 230px; flex-shrink: 0;' }, "Create New Domain:"),
				$cgi->textfield(
					-name  => 'SOA_NAME',
					-style => 'flex-grow: 1;'
				)
			),
			$cgi->div( { -style => 'display: flex;' },
				$cgi->span( { -style => 'font-weight: bold; display: inline-block; width: 230px; flex-shrink: 0;' }, "Type:"),
				$cgi->div( { -style => 'flex-grow: 1;' },
					$stab->b_dropdown(
						undef, undef, 'DNS_DOMAIN_TYPE', 'DNS_DOMAIN_TYPE', 1
					)
				)
			)
		) );
		# Use hidden field with ip_universe_id = 0
		print $cgi->hidden(
			-name    => 'IP_UNIVERSE_ID',
			-default => 0
		);
	}

	# Advanced options section
	print $cgi->Tr( $cgi->td( {
			-colspan => 2,
			-style   => 'padding-top: 15px; border-top: 1px solid #ddd;'
	} ) );

	print $cgi->Tr( $cgi->td( { -colspan => 2 }, $stab->zone_header ) );
	print $cgi->Tr(
		{ -align => 'center' },
		$cgi->td( { -colspan => 2 }, $cgi->a( {
				-id      => 'soa_switch',
				-href    => 'javascript:void(null)',
				-onClick => 'show_soa("soa_switch", "soa_table");',
				-style   => 'font-size: 0.9em;'
			},
			"▼ Change SOA Defaults"
		) )
	);

	print $cgi->Tr(
		$cgi->td( { -colspan => 2, -style => 'text-align: center;' },
			$stab->build_checkbox(
				undef, "Should Generate",
				"SHOULD_GENERATE", 'DNS_DOMAIN_ID', 1
			)
		)
	);
	print $cgi->Tr(
		$cgi->td( { -colspan => 2, -style => 'text-align: center;' },
			$stab->build_checkbox(
				undef,                "Add Default NS Records",
				"DEFAULT_NS_RECORDS", 'DNS_DOMAIN_ID',
				1
			)
		)
	);

	# Submit button
	print $cgi->Tr( $cgi->td( {
			-colspan => 2,
			-align   => 'center',
			-style   => 'padding-top: 20px;'
		},
		$cgi->submit( {
			-name  => "New",
			-value => "Add Domain",
			-style => 'padding: 8px 24px; font-size: 1em;'
		} )
	) );
	print $cgi->end_table;

	print $cgi->end_div;

	print $cgi->end_form;
	undef $stab;
}
