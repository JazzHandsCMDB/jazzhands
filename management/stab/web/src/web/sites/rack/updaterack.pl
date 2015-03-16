#!/usr/bin/env perl
#
# Copyright (c) 2013, Todd M. Kover
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# $Id$
#

#
# This retires a rack
#

use strict;
use warnings;
use Data::Dumper;
use JazzHands::STAB;
use JazzHands::Common qw(_dbx);
use URI;

exit do_update_racks();

sub retire_rack($$) {
	my ( $stab, $rackid ) = @_;

	my $sth = $stab->prepare(qq{
	        SELECT  device_utils.retire_Rack(
	                        _in_rack_id := ?
	                );
	}) || die $stab->return_db_err($stab);

	$sth->execute($rackid) || $stab->return_db_err($sth);
	my ($stillhere) = ($sth->fetchrow_array);
	$sth->finish;

	my ( $url, $msg );
	if (! $stillhere) {
	        $url = "./";
	        $msg = "Rack Removed";
	} else {
	        $url = "./?RACK_ID=$rackid";
	        $msg = "Rack Retired";
	}

	$stab->commit || $stab->error_return;
	$stab->msg_return( $msg, $url, 1 );
}

sub demonitor_rack($$) {
	my ( $stab, $rackid ) = @_;

	my $sth = $stab->prepare(qq{
	        SELECT  device_utils.monitoring_off_in_rack(
	                        _in_rack_id := ?
	                );
	}) || die $stab->return_db_err($stab);

	my $nr = $sth->execute($rackid) || $stab->return_db_err($sth);
	$sth->finish;

	my $url = "./?RACK_ID=$rackid";
	my $msg = "Monitoring disabled for devices in rack";
	$stab->commit || $stab->error_return;
	$stab->msg_return( $msg, $url, 1 );
}


sub update_rack($$) {
	my ( $stab, $rackid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $numchanges = 0;

	my $site   = $stab->cgi_parse_param( 'SITE_CODE',	$rackid );
	my $room   = $stab->cgi_parse_param( 'ROOM',	     $rackid );
	my $subr   = $stab->cgi_parse_param( 'SUB_ROOM',	 $rackid );
	my $row    = $stab->cgi_parse_param( 'RACK_ROW',	 $rackid );
	my $rackn  = $stab->cgi_parse_param( 'RACK_NAME',	$rackid );
	my $desc   = $stab->cgi_parse_param( 'DESCRIPTION',      $rackid );
	my $type   = $stab->cgi_parse_param( 'RACK_TYPE',	$rackid );
	my $style  = $stab->cgi_parse_param( 'RACK_STYLE',       $rackid );
	my $height = $stab->cgi_parse_param( 'RACK_HEIGHT_IN_U', $rackid );

	my $rmrack = $stab->cgi_parse_param( 'REMOVE_RACK', $rackid );
	my $demonr  = $stab->cgi_parse_param( 'DEMONITOR_RACK', $rackid );
	$rmrack = $stab->mk_chk_yn($rmrack);
	$demonr = $stab->mk_chk_yn($demonr);

	my @errs;
	my $hr = $stab->DBFetch(
		table	   => 'rack',
		match	   => { rack_id => $rackid },
		errors	  => \@errs,
		result_set_size => 'exactlyone',
	);

	if ( !$hr ) {
		$stab->error_return("Invalid Rack Id $rackid (!)");
	}

	my $new = {
		SITE_CODE	=> $site,
		ROOM	     => $room,
		SUB_ROOM	 => $subr,
		RACK_ROW	 => $row,
		RACK_NAME	=> $rackn,
		DESCRIPTION      => $desc,
		RACK_TYPE	=> $type,
		RACK_STYLE       => $style,
		RACK_HEIGHT_IN_U => $height,
	};

	my $diffs = $stab->hash_table_diff( $hr, _dbx($new) );
	my $tally += keys %$diffs;

	#if($tally && $rmrack eq 'Y') {
	#	return $stab->error_return("Unable to Remove rack and upate rack parameters in the same transaction");
	#}

	# This is an else because demonitoring is a subset of removing.
	if ($rmrack eq 'Y') {
		return retire_rack($stab, $rackid);
	} elsif ($demonr eq 'Y') {
		return demonitor_rack($stab, $rackid);
	}

	return 0 if ( !$tally );

	if (
		$tally
		&& !$stab->run_update_from_hash(
			"RACK", "RACK_ID", $rackid, $diffs
		)
	  )
	{
		$stab->return_db_err();
	}
	$numchanges += $tally;

	$numchanges;
}

sub do_update_racks {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi	  || die "Could not create cgi";

      #- print $cgi->header, $cgi->start_html, $cgi->Dump, $cgi->end_html; exit;

	my $numchanges = 0;
	foreach my $rackid ( $stab->cgi_get_ids('RACK_ID') ) {
		if ($rackid) {
			$numchanges += update_rack( $stab, $rackid );
		}
	}
	if ($numchanges) {
		$stab->commit;
		$stab->msg_return( "Rack Updated", undef, 1 );
	} else {
		$stab->rollback;
		$stab->msg_return("Nothing to change");
	}
	0;
}
