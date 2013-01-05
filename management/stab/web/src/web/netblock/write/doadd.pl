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

do_netblock_addition();

#############################################################################
#
# real work happens here
#
#############################################################################

sub do_netblock_addition {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";
	my $dbh  = $stab->dbh          || die "Could not create dbh";

	my $par_nblkid = $cgi->param('parentnblkid') || undef;
	my $ip         = $stab->cgi_parse_param('ip');
	my $bits       = $stab->cgi_parse_param('bits');
	my $desc       = $stab->cgi_parse_param('description');

	if ( !defined($par_nblkid) || !defined($ip)) {
		$stab->error_return("Insufficient Values Specified.");
	}

	if($ip =~ s,/(\d+)$,,) {
		my $embedbits = $1;
		warn "compare $bits and $embedbits\n";
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

	my $netblock = $stab->get_netblock_from_id( $par_nblkid, 1 );

	if ( !defined($netblock) ) {
		$stab->error_return("Invalid Parent Netblock");
		exit 0;
	}

	my $par_ip   = $netblock->{'IP'};
	my $par_bits = $netblock->{'NETMASK_BITS'};

	#
	# Check to ensure that parent/child relationship is ok.  This can
	# actually all be done with Net::IP, and does not need to be done
	# with Net::Netmask.  Part of the ripping apart of all of this...
	# [XXX]
	#
	if($netblock->{'IS_IPV4_ADDRESS'} eq 'Y') {
        	my $par_ip = $netblock->{'IP'};
        	my $par_bits = $netblock->{'NETMASK_BITS'};
  
		my $parnb = new Net::Netmask("$par_ip/$par_bits") || $stab->error_return("Invalid IPv4 address: ", Net::IP::Error());


		if ( !$parnb->contains("$ip/$bits") ) {
			$cgi->delete('orig_referer');
			$stab->error_return(
				qq{
				$ip/$bits is not a child netblock of 
				$par_ip/$par_bits
			}
			);
			exit 0;
		}
	 } else { # IPv6
		my $par_ip = $netblock->{'IP'};
		my $par_bits = $netblock->{'NETMASK_BITS'};

		my $parn = new Net::IP("$par_ip/$par_bits") ||
			$stab->error_return(
				"Invalid IPv6 parent address: ", Net::IP::Error()
			);

		my $me = new Net::IP($ip) ||
			$stab->error_return(
				"Invalid IPv6 address: ", Net::IP::Error()
			);


		if($me->intip() < $parn->intip() ||
		   $me->intip() > ($parn->intip() + $parn->size())) {
			$stab->error_return(qq{
				$ip/$bits is not a child netblock of
				$par_ip/$par_bits
			});
		}
	}

	my $me = new Net::IP($ip) || $stab->error_return("Invalid IPv6 address: ", Net::IP::Error());

	my $q = qq{
		insert into netblock
		(
			ip_address, netmask_bits, is_ipv4_address,
		 	is_single_address, parent_netblock_id, netblock_status,
		 	description, netblock_type
		) values (
			:1, :2, :3,
		 	'N', :4, 'Allocated',
			:5, 'default'
		)
	};

	my $sth = $stab->prepare($q) || die "$q" . $stab->errstr;

	# XXX $me->ip_is_ipv4() is not reasonable, so I just do a stupid
	# check against bits.  ugh.
	if ( !( $sth->execute( $me->intip(), $bits, 
			($bits > 32)?'N':'Y',
			$par_nblkid, $desc ) ) ) {
		print $cgi->delete('orig_referer');
		if ( $sth->err == 29532 ) {
			print $stab->error_return("Invalid IP");
		} elsif ( $sth->err == 1722 ) {
			$stab->error_return("Invalid BITS");
		} else {
			$stab->return_db_err($sth);
		}
	}

	$dbh->commit;
	$dbh->disconnect;
	$dbh = undef;
	my $refurl = "../?nblkid=$par_nblkid";
	$stab->msg_return( "Child Netblock Added", $refurl, 1 );
}
