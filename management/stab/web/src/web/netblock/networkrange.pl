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
use JazzHands::Common qw(_dbx);

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

	print $cgi->header, $stab->start_html("All Network Ranges");

	my $q = qq{
		select	
			nr.network_range_id,
			net_manip.inet_dbtop(lhs.ip_address) as start_ip,
			net_manip.inet_dbtop(rhs.ip_address) as stop_ip,
			nr.start_netblock_id,
			nr.stop_netblock_id,
			nr.lease_time,
			nr.dns_prefix,
			dom.soa_name
		  from	network_range nr
				left join dns_domain dom using (dns_domain_id)
				inner join netblock lhs
					on lhs.netblock_id = nr.start_netblock_id
				inner join netblock rhs
					on rhs.netblock_id = nr.stop_netblock_id
		order by lhs.ip_address
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($stab);
	$sth->execute || $stab->return_db_err($stab);

	print $cgi->start_table( { -border => 1, -align => 'center' } );

	print $cgi->th(
		[
			'Start IP',
			'End IP',
			'Lease Time',
			'DNS Prefix',
			'DNS Domain'
		]
	);

	while ( my $hr = $sth->fetchrow_hashref ) {
		print $cgi->Tr(
			$cgi->hidden(
				'NETWORK_RANGE_ID',
				$hr->{ _dbx('network_RANGE_ID') }
			),
			$cgi->td(
				[
					$hr->{ _dbx('START_IP') },
					$hr->{ _dbx('STOP_IP') },
					$hr->{ _dbx('LEASE_TIME') || '' },
					$hr->{ _dbx('DNS_PREFIX') || '' },
					$hr->{ _dbx('SOA_NAME') || '' },
				]
			)
		);
	}

	print $cgi->end_table;
	print $cgi->end_html;
	undef $stab;
}
