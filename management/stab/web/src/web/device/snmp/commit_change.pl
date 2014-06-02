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
use JazzHands::STAB;

do_snmp_update();

sub do_snmp_update {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";
	my $dbh  = $stab->dbh          || die "Could not create dbh";

	my $devid      = $stab->cgi_parse_param('DEVICE_ID');
	my $numchanges = 0;

	foreach my $snmpid ( $stab->cgi_get_ids("SNMP_COMMSTR_ID") ) {
		$numchanges += process_snmp_commstr_updates( $stab, $snmpid );

	}

	$numchanges += process_snmp_commstr_adds($stab);

	my $refurl;
	if ( defined($devid) ) {
		$refurl = "../device.pl?devid=$devid";
	}

	if ($numchanges) {
		$dbh->commit;
		$dbh->disconnect;
		$stab->msg_return( "Processed $numchanges changes", $refurl,
			1 );
	} else {
		$dbh->rollback;
		$dbh->disconnect;
		$stab->msg_return( "No changes", $refurl, 1 );
	}
	undef $stab;
}

sub process_snmp_commstr_updates {
	my ( $stab, $snmpid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";
	my $dbh = $stab->dbh || die "Could not create dbh";

	my $numchanges = 0;

	my $type  = $stab->cgi_parse_param("SNMP_COMMSTR_TYPE_$snmpid");
	my $rdstr = $stab->cgi_parse_param("RD_STRING_$snmpid");
	my $wrstr = $stab->cgi_parse_param("WR_STRING_$snmpid");
	my $purp  = $stab->cgi_parse_param("PURPOSE_$snmpid");

	my $oldrec = $stab->get_snmpcommstr_from_id($snmpid);

	if ( !defined($oldrec) ) {
		$stab->error_return("Unknown Community String Id $snmpid");
	}

	my %newrec = (
		SNMP_COMMSTR_ID   => $snmpid,
		SNMP_COMMSTR_TYPE => $type,
		RD_STRING         => $rdstr,
		WR_STRING         => $wrstr,
		PURPOSE           => $purp,
	);

	my $diff = $stab->hash_table_diff( $oldrec, \%newrec );
	if ( defined($diff) ) {
		$numchanges += keys %$diff;
		$stab->build_update_sth_from_hash( 'SNMP_COMMSTR',
			'SNMP_COMMSTR_ID', $snmpid, $diff );
	}

	$numchanges;
}

sub process_snmp_commstr_adds {
	my ( $stab, $snmpid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";
	my $dbh = $stab->dbh || die "Could not create dbh";

	my $numchanges = 0;

	my $type  = $stab->cgi_parse_param("SNMP_COMMSTR_TYPE");
	my $devid = $stab->cgi_parse_param("DEVICE_ID");
	my $rdstr = $stab->cgi_parse_param("RD_STRING");
	my $wrstr = $stab->cgi_parse_param("WR_STRING");
	my $purp  = $stab->cgi_parse_param("PURPOSE");

	if ( !defined($rdstr) && !defined($wrstr) && !defined($purp) ) {
		return 0;
	}

	if ( !defined($rdstr) && !defined($wrstr) ) {
		$stab->error_return(
			"A read or write string must be specified.");
	}
	if ( !defined($purp) ) {
		$stab->error_return("You must specify a purpose");
	}
	if ( !defined($type) ) {
		$stab->error_return("You must specify a type.");
	}

	my $q = qq{
		insert into snmp_commstr
			( device_id, snmp_commstr_type,
				rd_string, wr_string, purpose
			) values (
				:1, :2, :3, :4, :5
			)
	};

	my $sth = $stab->prepare($q) || die $stab->return_db_err($dbh);
	$sth->execute( $devid, $type, $rdstr, $wrstr, $purp )
	  || die $stab->return_db_err($sth);
	$numchanges += 1;
}
