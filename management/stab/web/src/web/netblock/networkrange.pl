#!/usr/bin/env perl

#
# Copyright (c) 2014 Todd M. Kover
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
use JazzHands::STAB;
use Data::Dumper;

do_dump_network_ranges();

############################################################################3
#
# everything else is a subroutine
#
############################################################################3

sub do_dump_network_ranges {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi;
	my $dbh  = $stab->dbh;

	print $cgi->header;

	#print $stab->start_html("All Network Ranges");
	print $stab->start_html(
		-title      => 'STAB: All Network Ranges',
		-javascript => 'network_range',
	);

	#my $hr_nt = get_networkrange_types( $stab );
	#print Dumper($hr_nt);

	my $q = qq{
		select	
			nr.network_range_id,
			nr.parent_netblock_id,
			pnb.ip_address as parent_netblock_ip_address,
			net_manip.inet_dbtop(lhs.ip_address) as start_ip,
			net_manip.inet_dbtop(rhs.ip_address) as stop_ip,
			nr.start_netblock_id,
			nr.stop_netblock_id,
			nr.lease_time,
			nr.dns_prefix,
			dom.dns_domain_id,
			dom.soa_name,
			nr.network_range_type,
			nr.description
		  from	network_range nr
				left join dns_domain dom using (dns_domain_id)
				inner join netblock pnb
					on pnb.netblock_id = nr.parent_netblock_id
				inner join netblock lhs
					on lhs.netblock_id = nr.start_netblock_id
				inner join netblock rhs
					on rhs.netblock_id = nr.stop_netblock_id
		order by lhs.ip_address
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($stab);
	$sth->execute                || $stab->return_db_err($stab);

	print $cgi->start_form(
		-method => 'POST',
		-action => 'write/edit_networkrange.pl'
	);
	print '<br/>'
	  . $cgi->start_table(
		{ -class => 'networkrange', -border => 1, -align => 'center' } );

	print $cgi->Tr(
		{ -class => 'networkrange' },
		$cgi->th(
			{ -class => 'networkrange' },
			[
				'RM',
				'Parent Netblock',
				'Start IP',
				'End IP',
				'Lease Time',
				'DNS Prefix',
				'DNS Domain',
				'Type',
				'Description'
			]
		)
	);

	print $cgi->Tr( $cgi->td(
		{ -colspan => '9' },
		$cgi->a( {
				-href    => '#',
				-class   => 'adddnsrec plusbutton',
				-onclick =>
				  "this.style.display = 'none'; document.getElementById('NETWORK_RANGE_NEW').style.display = '';",
				-title => 'Add',
			},
		)
	) );
	print $cgi->Tr( {
			-id    => 'NETWORK_RANGE_NEW',
			-style => 'display: none;',
		},
		$cgi->td(
			{ -class => 'networkrange' },
			[
				$cgi->hidden( 'NETWORK_RANGE_ID', 'NEW' ),
				'<i>(Automatic)</i>',
				$cgi->textfield( {
					-size     => 10,
					-name     => 'NETWORKRANGE_START_IP_NEW',
					-value    => '',
					-class    => 'tracked',
					-original => '',
				} ),
				$cgi->textfield( {
					-size     => 10,
					-name     => 'NETWORKRANGE_STOP_IP_NEW',
					-value    => '',
					-class    => 'tracked',
					-original => '',
				} ),
				$cgi->textfield( {
					-size     => 10,
					-name     => 'NETWORKRANGE_LEASE_TIME_NEW',
					-value    => '',
					-class    => 'tracked',
					-original => '',
				} ),
				$cgi->textfield( {
					-size     => 10,
					-name     => 'NETWORKRANGE_DNS_PREFIX_NEW',
					-value    => '',
					-class    => 'tracked',
					-original => '',
				} ),
				$stab->b_dropdown( {
						-dnsdomaintype => 'service',
						-name          => 'NETWORKRANGE_DNS_DOMAIN_NEW',
						-class         => 'tracked',
						-original      => '__unknown__',
					},
					undef,
					'DNS_DOMAIN_ID',
					undef, 1
				),
				$stab->b_dropdown( {
						-name     => 'NETWORKRANGE_TYPE_NEW',
						-class    => 'tracked',
						-original => '__unknown__',
					},
					undef,
					'NETWORK_RANGE_TYPE',
					undef, 1
				),
				$cgi->textfield( {
					-size     => 32,
					-name     => 'NETWORKRANGE_DESCRIPTION_NEW',
					-value    => '',
					-class    => 'tracked',
					-original => '',
				} ),

			],
		),
	);

	# Loop on existing network ranges and display them
	while ( my $hr = $sth->fetchrow_hashref ) {
		my $nrid = $hr->{'NETWORK_RANGE_ID'};
		print $cgi->Tr( {
				-class => 'networkrange'
				  . ( (
						$stab->cgi_parse_param(
							'NETWORK_RANGE_DELETE_' . $nrid
						) eq 'delete'
					) ? ' rowrm' : ''
				  )
			},
			$cgi->hidden( 'NETWORK_RANGE_ID', $nrid ),
			$cgi->td(
				{ -class => 'networkrange' },
				[
					$cgi->hidden( {
						-value    => '',
						-id       => 'NETWORK_RANGE_DELETE_' . $nrid,
						-name     => 'NETWORK_RANGE_DELETE_' . $nrid,
						-class    => 'tracked',
						-original => '',
					} )
					  . $cgi->a( {
							-class   => 'rmrow',
							-alt     => "Delete this Network Range",
							-title   => 'Delete This Network Range',
							-onclick =>
							  "let trcl=this.parentElement.parentElement.classList; trcl.toggle('rowrm'); document.getElementById('NETWORK_RANGE_DELETE_$nrid').value = trcl.contains('rowrm') ? 'delete' : '';"
						},
						''
					  ),
					"<a href='/netblock/?nblkid="
					  . $hr->{'PARENT_NETBLOCK_ID'} . "'>"
					  . $hr->{'PARENT_NETBLOCK_IP_ADDRESS'} . "</a>",

					# Note: we don't support editing those start/end netblock fields at the moment
					$cgi->span( {}, $hr->{'START_IP'} || '' )
					,    #$cgi->textfield({
						 #	-size => 10,
						 #	-name => 'NETWORKRANGE_START_IP_'.$nrid,
						 #	-value => $hr->{ 'START_IP' || '' },
						 #	-class => 'tracked',
						 #	-original => $hr->{ 'START_IP' || '' },
						 #}),
					$cgi->span( {}, $hr->{'STOP_IP'} || '' ), #$cgi->textfield({
															  #	-size => 10,
						#	-name => 'NETWORKRANGE_STOP_IP_'.$nrid,
						#	-value => $hr->{ 'STOP_IP' || '' },
						#	-class => 'tracked',
						#	-original => $hr->{ 'STOP_IP' || '' },
						#}),
					$cgi->textfield( {
						-size     => 10,
						-name     => 'NETWORKRANGE_LEASE_TIME_' . $nrid,
						-value    => $hr->{'LEASE_TIME'} || '',
						-class    => 'tracked',
						-original => $hr->{'LEASE_TIME'} || '',
					} ),
					$cgi->textfield( {
						-size     => 10,
						-name     => 'NETWORKRANGE_DNS_PREFIX_' . $nrid,
						-value    => $hr->{'DNS_PREFIX'} || '',
						-class    => 'tracked',
						-original => $hr->{'DNS_PREFIX'} || '',
					} ),
					$stab->b_dropdown( {
							-dnsdomaintype => 'service',
							-name     => 'NETWORKRANGE_DNS_DOMAIN_' . $nrid,
							-class    => 'tracked',
							-original => $hr->{'DNS_DOMAIN_ID'} || '',
						},
						$hr,
						'DNS_DOMAIN_ID',
						undef, 1
					),

					# Note the stored procedure used to modify network ranges doesn't
					# support changing the network type currently
					$cgi->span(
						{},
						$hr->{'NETWORK_RANGE_TYPE'} || '',
						$cgi->hidden(
							'NETWORK_RANGE_TYPE',
							$hr->{'NETWORK_RANGE_TYPE'} || ''
						)
					),    #$stab->b_dropdown(
						  #	{
						  #		-name => 'NETWORKRANGE_TYPE_'.$nrid,
						  #		-class => 'tracked',
						  #		-original => $hr->{ 'NETWORK_RANGE_TYPE' || '' },
						  #	},
						  #	$hr,
						  #	'NETWORK_RANGE_TYPE',
						  #	undef,
						  #	1
						  #),
					$cgi->textfield( {
						-size     => 32,
						-name     => 'NETWORKRANGE_DESCRIPTION_' . $nrid,
						-value    => $hr->{'description'} || '',
						-class    => 'tracked',
						-original => $hr->{'description'} || '',
					} ),
				]
			)
		);
	}

	print $cgi->end_table;
	print $cgi->div(
		{ -class => 'centered' },
		$cgi->submit( {
			-class => '',
			-name  => "Ranges",
			-value => "Submit Network Ranges Changes",
		} )
	);
	print $cgi->end_form, "\n";
	print $cgi->end_html;
	undef $stab;
}

sub get_networkrange_types {
	my ($stab) = @_;

	my $q = qq{
		select
			network_range_type,
			description,
			dns_domain_required,
			default_dns_prefix,
			netblock_type,
			can_overlap,
			require_cidr_boundary
		from
			val_network_range_type;
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($stab);
	$sth->execute                || $stab->return_db_err($stab);

	my $hr = $sth->fetchall_hashref('NETWORK_RANGE_TYPE');
	$hr;
}

