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
# Copyright (c) 2013 Matthew Ragan
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
use Net::Netmask;
use FileHandle;
use JazzHands::STAB;
use JazzHands::Common::Util qw(_dbx);

do_netblock_addition();

#############################################################################
#
# real work happens here
#
#############################################################################

sub do_netblock_addition {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";

	my $par_nblkid = $cgi->param('parentnblkid') || undef;
	my $ip         = $stab->cgi_parse_param('ip');
	my $bits       = $stab->cgi_parse_param('bits');
	my $desc       = $stab->cgi_parse_param('description');

	if (!defined($ip)) {
		$stab->error_return("Insufficient Values Specified.");
	}

	if($ip =~ s,/(\d+)$,,) {
		my $embedbits = $1;
		if(defined($embedbits) && defined($bits)) {
			if($embedbits != $bits) {
				$stab->error_return("Bits do not match");
			}
		} elsif(defined($embedbits) && !defined($bits)) {
			$bits = $embedbits;
		}
	}

	if(!defined($bits)) {
		$stab->error_return("Insufficient Bits Specified");
	}


	if ( $bits == 0 ) {
		$stab->error_return(
			qq{
			I can't fathom why you'd want to add a /0,
			so I won't let you.
		}
		);
	}

	my $childaddr = NetAddr::IP->new($ip, $bits);

	my @errors;
	if (defined($par_nblkid)) {
		my $netblock = $stab->GetNetblock( netblock_id => $par_nblkid, 
			errors => \@errors);

		if ( !defined($netblock) ) {
			if (@errors) {
				$stab->error_return(join ",", @errors);
			} else {
				$stab->error_return("Invalid Parent Netblock");
			}
			exit 0;
		}

		my $par_ip   = $netblock->IPAddress;

		#
		# Validate that this netblock is a child of the parent.  This probably
		# isn't *strictly* necessary, since a) the database will take care of
		# homing the netblock correctly and b) it only checks that it's a child
		# of this block and not necessarily a child of a child of this block,
		# but it will at least catch some instances of fat-fingering.
		#
		if (!($par_ip->contains($childaddr))) {
			$cgi->delete('orig_referer');
			$stab->error_return( qq{
					$childaddr is not a child netblock of $par_ip
				}
			);
			exit 0;
		}
	}
	#
	# Create a new netblock object
	#

	my $me = new JazzHands::Mgmt::Netblock (
		jhhandle => $stab,
		is_single_address => 'N',
		can_subnet => 'Y',
		netblock_status => 'Allocated',
		description => $desc,
		netblock_type => 'default',
		ip_address => $childaddr,
		errors => \@errors
	);

	if ( !defined($me) ) {
		if (@errors) {
			$stab->error_return(join ",", @errors);
		} else {
			$stab->error_return("Unknown error inserting netblock");
		}
		exit 0;
	}

	#
	# Now write it out
	#

	if (!($me->write(errors => \@errors))) {
		if (@errors) {
			$stab->error_return(join ",", @errors);
		} else {
			$stab->error_return("Invalid Parent Netblock");
		}
		exit 0;
	}


	$me->commit;
	$stab->disconnect;

	my $refurl = "../";
	if ($me->hash->{_dbx('parent_netblock_id')}) {
		$refurl .= "?nblkid=" . $me->hash->{_dbx('parent_netblock_id')};
	}
	undef $me;
	$stab->msg_return( "Child Netblock Added", $refurl, 1 );
	undef $stab;
	1;
}
