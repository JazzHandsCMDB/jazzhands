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
use vars qw($stab);
use vars qw($cgi);
use vars qw($dbh);

do_netblock_addition();

#############################################################################
#
# real work happens here
#
#############################################################################

sub do_netblock_addition {
	$stab = new JazzHands::STAB || die "Could not create STAB";
	$cgi  = $stab->cgi          || die "Could not create cgi";
	$dbh  = $stab->dbh          || die "Could not create dbh";

	my $par_nblkid = $cgi->param('parentnblkid') || undef;
	my $ip         = $stab->cgi_parse_param('ip');
	my $bits       = $stab->cgi_parse_param('bits');
	my $desc       = $stab->cgi_parse_param('description');

	if ( !defined($par_nblkid) || !defined($ip) || !defined($bits) ) {
		$stab->error_return("Insufficient Values Specified.");
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

	my $parnb = new Net::Netmask("$par_ip/$par_bits");

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

	my $q = qq{
		insert into netblock
		(
			ip_address, netmask_bits, is_ipv4_address,
		 	is_single_address, parent_netblock_id, netblock_status,
		 	description, is_organizational
		) values (
			ip_manip.v4_int_from_octet(:1,1), :2, 'Y', 
		 	'N', :3, 'Allocated',
			:4, 'N'
		)
	};

	my $sth = $stab->prepare($q) || die "$q" . $dbh->errstr;

	if ( !( $sth->execute( $ip, $bits, $par_nblkid, $desc ) ) ) {
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
