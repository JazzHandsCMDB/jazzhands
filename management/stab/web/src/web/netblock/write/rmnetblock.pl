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
use Net::Netmask;
use FileHandle;
use JazzHands::STAB;
use JazzHands::GenericDB qw(_dbx);
use vars qw($stab);
use vars qw($cgi);
use vars qw($dbh);

do_remove_netblock();

###########################################################################
#
# the work goes here
#
###########################################################################

sub do_remove_netblock {
	$stab = new JazzHands::STAB || die "Could not create STAB";
	$cgi  = $stab->cgi          || die "Could not create cgi";
	$dbh  = $stab->dbh          || die "Could not create dbh";

	my $nblkid = $cgi->param('id') || undef;

	if ( !defined($nblkid) ) {
		$stab->error_return("You must specify a valid netblock.");
	}

	my @errors;
#	my $netblock = $stab->get_netblock_from_id( $nblkid, 1 );
	my $netblock = $stab->GetNetblock( netblock_id => $nblkid, 
		errors => \@errors);
	if ( !defined($netblock) ) {
		if (@errors) {
			$stab->error_return(join ';', @errors);
		} else {
			$stab->error_return("You must specify a valid netblock.");
		}
	}

	my $ip    = $netblock->IPAddress;
	my $parid = $netblock->hash->{_dbx('parent_netblock_id')};

	my $ref = "../";
	if ( defined($parid) ) {
		$ref .= "?nblkid=$parid";
	}

	$cgi->param( 'orig_referer', $ref );
	$stab->check_if_sure("remove $ip");

	if (!($netblock->delete(errors => \@errors))) {
		$stab->error_return(join ";", @errors);
	}
#	my $q = qq{
#		delete from netblock where netblock_id = :1
#	};
#	my $sth = $stab->prepare($q) || die "$q" . $dbh->errstr;
#
#	if ( !( $sth->execute($nblkid) ) ) {
#		if ( $sth->err == 2292 ) {
#			$stab->error_return(
#				qq{
#				This netblock has children that must 
#				be dealt with before it can be removed. 
#				 Sorry.
#			}
#			);
#		} else {
#			$stab->return_db_err($sth);
#		}
#	}

	$dbh->commit;
	$dbh->disconnect;
	$stab->msg_return( "Successfully removed $ip.", $ref, 1 );
}
