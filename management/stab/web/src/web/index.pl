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
# Copyright (c) 2015-2016 Todd Kover
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

use strict;
use warnings;
use JazzHands::STAB;
use vars qw($cgi);
use vars qw($stab);

my $stab = new JazzHands::STAB || die "no stab!";
my $cgi  = $stab->cgi          || die "no cgi!";

print $cgi->header( { -type => 'text/html' } ), "\n";
print $stab->start_html('STAB: System Tools for Administrative Baselining');

my $email = $stab->support_email();

my $mailto = $cgi->a( { -href => $email }, $email );

print $cgi->div(
	{ -class => 'description' }, qq{
	STAB is a web front-end to JazzHands.
	STAB is used to manage network elements, and related information,
	ranging from device properties, to network topology to DNS
	information.  If you have
	any issues with STAB, please contact  $mailto.
}
);

print $cgi->h2( { -align => 'center' }, "STAB Network Element Management" );

my @things;

if ( $stab->check_permissions('AccountCol') ) {
	push(
		@things,
		join(
			"",

			#$cgi->li( $cgi->a( { -href => "account/" }, "Account" ) ) . "\n",
			$cgi->li('Account'),
			$cgi->ul(
				$cgi->li(
					$cgi->a(
						{ -href => "account/collection" },
						"Account Collections",
					)
				)
			)
		)
	);
}

if ( $stab->check_permissions('DNS') ) {
	push(
		@things,
		join(
			"",
			$cgi->li( $cgi->a( { -href => "dns/" }, "DNS" ) ) . "\n",
			$cgi->ul(
				$cgi->li(
					$cgi->a(
						{ -href => "dns/soacheck.pl" },
						"NIC vs JazzHands"
					)
				),

				#		$cgi->li(
				#			$cgi->a(
				#				{ -href => "dns/dns-debug.pl" },
				#				"DNS Namespace Debugging"
				#			)
				#		),
			),
		)
	);
}

if ( $stab->check_permissions('Device') ) {
	push(
		@things,
		join(
			"",
			$cgi->li( $cgi->a( { -href => "device/" }, "Device Management" ) )
			  . "\n",
			$cgi->li(
				[
					$cgi->a(
						{ -href => "device/type/" },
						"Device Type Management"
					),

					#		$cgi->a(
					#			{ -href => "device/apps/" }, "Application Management"
					#		),
				]
			  )
			  . "\n",
		)
	);
}

if ( $stab->check_permissions('Netblock') ) {
	push(
		@things,
		join(
			"",
			$cgi->li(
				$cgi->a( { -href => "netblock/" }, "Netblock Management" )
			  )
			  . "\n",
			$cgi->ul(
				$cgi->li(
					[
						$cgi->a(
							{ href => "netblock/networkrange.pl" },
							"Network Ranges (VPN/DHCP/etc)"
						),
						$cgi->a(
							{ href => "netblock/collection/" },
							"Netblock Collections"
						),
					]
				)
			),
		)
	);
}

if ( $stab->check_permissions('Sites') ) {
	push(
		@things,
		join(
			"",
			$cgi->li( $cgi->a( { -href => "sites/" }, "Sites" ) ) . "\n",
			$cgi->ul(
				$cgi->li(
					$cgi->a(
						{ -href => "sites/blockmgr.pl" },
						"IP Space Management by Site"
					)
				),
				$cgi->li(
					$cgi->a( { -href => "sites/rack/" }, "Racks by Site" )
				)
			),
		)
	);
}

if ( $stab->check_permissions('X509') ) {
	push(
		@things,
		join(
			"",
			$cgi->li( $cgi->a( { -href => "x509/" }, "X509 Certificates" ) )
			  . "\n",
			$cgi->ul(
				$cgi->li(
					$cgi->a(
						{ -href => "x509/expiry.pl" },
						"Pending Expiration"
					)
				  )
				  . "\n",
			)
		  )

	);
}

#	$cgi->li( $cgi->a( { -href => "stats/" }, "STAB Statistics" ) ) .

print $cgi->ul(@things);
print $cgi->end_html, "\n";

undef $stab;
exit;
