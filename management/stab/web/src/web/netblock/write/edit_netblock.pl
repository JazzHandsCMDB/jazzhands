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

edit_netblock();

#############################################################################
#
# only subroutines below here.
#
#############################################################################

sub edit_netblock {
	my $stab = new JazzHands::STAB;
	my $cgi  = $stab->cgi;
	my $dbh  = $stab->dbh;

	my $numchanges = 0;

#	$numchanges += process_routes

	foreach my $id ( $stab->cgi_get_ids('NETBLOCK_DESCRIPTION') ) {
		my $v    = $cgi->param("NETBLOCK_DESCRIPTION_$id");
		my $ov = $cgi->param("orig_NETBLOCK_DESCRIPTION_$id");
		if ( $v ne $ov ) {
			$numchanges += process_netblock_update( $stab, $id, $v );
		}
	}

	if ( $numchanges > 0 ) {
		$dbh->commit;
		$dbh->disconnect;
		$stab->msg_return( "$numchanges changes commited", undef, 1 );
	}

	$dbh->rollback;
	$dbh->disconnect;
	$stab->msg_return( "There were no changes.", undef, 1 );
}

sub process_netblock_update {
	my ( $stab, $nblkid, $newval ) = @_;

	my $dbh = $stab->dbh;
	my $q   = qq{
		update	netblock
		  set	description = ?
		where	netblock_id = ?
	};

	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute( $newval, $nblkid ) || $stab->return_db_err($sth);
	1;
}
