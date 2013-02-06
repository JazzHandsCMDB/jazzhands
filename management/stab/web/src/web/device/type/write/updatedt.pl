#!/usr/bin/env perl
#
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
use URI;

do_device_type_update();

############################################################################
sub process_power_interface_updates($$) {
	my($stab, $devtypid) = @_;

	my $cgi = $stab->cgi || die "Could not create cgi";
	my $dbh = $stab->dbh || die "Could not create dbh";

	my $field = "POWER_INTERFACE_PORT_".$devtypid;

	my $changes = 0;

	foreach my $port ($stab->cgi_get_ids($field)) {
		my $addage = $devtypid."_".$port;

		my $rmme = $stab->cgi_parse_param("power_port_rm_pwr", $addage);
		my $name = $stab->cgi_parse_param($field. "_" . $port);
		my $plug = $stab->cgi_parse_param("PLUG_STYLE", $addage);
		my $volt = $stab->cgi_parse_param("VOLTAGE", $addage);
		my $amp =  $stab->cgi_parse_param("MAX_AMPERAGE", $addage);

		if($volt && $volt !~ /^\d+$/) {
			$stab->error_return("Voltage must be an integer.");
		}

		if($amp && ($amp !~ /^\d+$/ || $amp <0) ) {
			$stab->error_return("Max Amperage must be a positive integer.");
		}

		if($rmme) {
			my $q = qq{
				delete from device_type_power_port_templt
				where	device_type_id = :1
				  and	power_interface_port = :2
			};
			my $sth = $stab->prepare($q) || return $stab->return_db_error($dbh);
			$sth->execute($devtypid, $port) || return $stab->return_db_error($sth);;
			$changes++;
		} else {
			my $q = qq{
				select	DEVICE_TYPE_ID, POWER_INTERFACE_PORT,
						PLUG_STYLE, VOLTAGE, MAX_AMPERAGE
				  from	device_type_power_port_templt
				 where	DEVICE_TYPE_ID = :1
				   and	POWER_INTERFACE_PORT = :2
			};
			my $sth = $stab->prepare($q) || return $stab->return_db_error($dbh);
			$sth->execute($devtypid, $port) || return $stab->return_db_error($sth);;
			my $old = $sth->fetchrow_hashref || return $stab->return_db_error($sth);
			my %newtemplate = (
				DEVICE_TYPE_ID		=>	$devtypid,
				POWER_INTERFACE_PORT=>	$name,
				PLUG_STYLE			=>	$plug,
				VOLTAGE				=>	$volt,
				MAX_AMPERAGE		=>	$amp,
			);

			my $diffs = $stab->hash_table_diff($old, \%newtemplate);

			my $tally += keys %$diffs;
			$changes += $tally;

			my $table = "device_type_power_port_templt";
			my @keys = ('DEVICE_TYPE_ID', 'POWER_INTERFACE_PORT');
			my @keyvals = ($devtypid, $port);

			if($tally && !$stab->build_update_sth_from_hash($table, \@keys, \@keyvals, $diffs)) {
				$dbh->rollback;
				my $url = "../";
				$stab->error_return("Unknown Error with Power Update", $url);
			}
		}
	}
	$changes;
}

sub process_physical_port_updates($$$) {
	my($stab, $devtypid, $type) = @_;

	my $cgi = $stab->cgi || die "Could not create cgi";
	my $dbh = $stab->dbh || die "Could not create dbh";

	my $changes = 0;

	my $field = join("_", "PORT_NAME", $devtypid, $type);
	foreach my $port ($stab->cgi_get_ids($field)) {
		my $rmme = $stab->cgi_parse_param("rm_${field}_$port");
		my $name = $stab->cgi_parse_param( "${field}_$port" );

		if($rmme) {
			my $q = qq{
				delete from DEVICE_TYPE_PHYS_PORT_TEMPLT
				where	device_type_id = :1
				  and	port_name = :2
				  and	port_type = :3
			};
			my $sth = $stab->prepare($q) || return $stab->return_db_error($dbh);
			$changes += $sth->execute($devtypid, $port, $type) || return $stab->return_db_error($sth);;
		} else {
			my $q = qq{
				select	DEVICE_TYPE_ID, PORT_NAME, PORT_TYPE
				  from	DEVICE_TYPE_PHYS_PORT_TEMPLT
				 where	DEVICE_TYPE_ID = :1
				   and	PORT_NAME = :2
				   and	port_type = :3
			};
			my $sth = $stab->prepare($q) || return $stab->return_db_error($dbh);
			$changes += $sth->execute($devtypid, $port, $type) || return $stab->return_db_error($sth);;
			my $old = $sth->fetchrow_hashref || return $stab->return_db_error($sth);
			my %newtemplate = (
				DEVICE_TYPE_ID		=>	$devtypid,
				PORT_NAME			=>	$name,
				PORT_TYPE			=> $type,
			);

			my $diffs = $stab->hash_table_diff($old, \%newtemplate);

			my $tally += keys %$diffs;
			$changes += $tally;

			my $table = "DEVICE_TYPE_PHYS_PORT_TEMPLT";
			my @keys = ('DEVICE_TYPE_ID', 'PORT_NAME', 'PORT_TYPE');
			my @keyvals = ($devtypid, $port, $type);

			if($tally && !$stab->build_update_sth_from_hash($table, \@keys, \@keyvals, $diffs)) {
				$dbh->rollback;
				my $url = "../";
				$stab->error_return("Unknown Error with $type Port Update", $url);
			}
		}
	}
	$changes;
}


sub process_new_physical_ports($$$) {
	my($stab, $devtypid, $type) = @_;

	my $numchanges = 0;

	my $captype = $type;
	$captype =~ tr/a-z/A-Z/;

	#
	# Check to see if physical port fields are specified without a count
	#
	my $prefix   = $stab->cgi_parse_param("${captype}_PORT_PREFIX");
	my $start    = $stab->cgi_parse_param("${captype}_INTERFACE_PORT_START");
	my $count = $stab->cgi_parse_param("${captype}_INTERFACE_PORT_COUNT");

	if(!$count && ($prefix || $start) ) {
		return $stab->error_return("You must specify a $type count to setup $type ports.");
	}

	if((defined($count) && $count) || defined($prefix)) {
		$numchanges += $stab->add_physical_ports($devtypid, $type);
	}
	$numchanges;
}

sub do_device_type_update {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi = $stab->cgi || die "Could not create cgi";
	my $dbh = $stab->dbh || die "Could not create dbh";

	my $devtypid = $stab->cgi_parse_param('DEVICE_TYPE_ID');

	# print $cgi->header, $cgi->start_html, $cgi->Dump, $cgi->end_html;
	# exit;

	if(!defined($devtypid)) {
		$stab->error_return("Unspecified Device Type.  Try again.");
	}

	my $pwrcount = $stab->cgi_parse_param('POWER_INTERFACE_PORT_COUNT');

	my $numchanges = 0;

	if(defined($pwrcount) && $pwrcount) {
		$stab->add_power_ports($devtypid);
		$numchanges++;
	}

	# may return an error message...
	$numchanges += process_new_physical_ports($stab, $devtypid, 'serial');
	$numchanges += process_new_physical_ports($stab, $devtypid, 'network');

	$numchanges+= process_power_interface_updates($stab, $devtypid);
	$numchanges+= process_physical_port_updates($stab, $devtypid, 'serial');
	$numchanges+= process_physical_port_updates($stab, $devtypid, 'network');

	my $partid = $stab->cgi_parse_param('COMPANY_ID', $devtypid);
	my $arch = $stab->cgi_parse_param('PROCESSOR_ARCHITECTURE', $devtypid);
	my $model = $stab->cgi_parse_param('MODEL', $devtypid);
	my $cfgfetch = $stab->cgi_parse_param('CONFIG_FETCH_TYPE', $devtypid);
	my $descr = $stab->cgi_parse_param('DESCRIPTION', $devtypid);
	my $racku = $stab->cgi_parse_param('RACK_UNITS', $devtypid);
	my $cansnmp = $stab->cgi_parse_param('chk_SNMP_CAPABLE', $devtypid);
	my $has8023 = $stab->cgi_parse_param('chk_HAS_802_3_INTERFACE', $devtypid);
	my $has80211 = $stab->cgi_parse_param('chk_HAS_802_11_INTERFACE', $devtypid);

	$cansnmp = $stab->mk_chk_yn($cansnmp);
	$has8023 = $stab->mk_chk_yn($has8023);
	$has80211 = $stab->mk_chk_yn($has80211);

	#
	# Check to see if a start, voltage, amp are specified without a
	# count.
	#
	my $pwrstart    = $stab->cgi_parse_param('POWER_INTERFACE_PORT_START');
	my $pwrpstyl    = $stab->cgi_parse_param('PLUG_STYLE');
	my $pwrvolt     = $stab->cgi_parse_param('VOLTAGE');
	my $pwrmaxamp   = $stab->cgi_parse_param('MAX_AMPERAGE');

	if(!$pwrcount && ($pwrstart || $pwrpstyl || $pwrvolt || $pwrmaxamp)) {
		return $stab->error_return("You must specify a power count to setup power ports");
	}

	if(!defined($racku)) {
		return $stab->error_return("You must specify rack units");
	} elsif($racku !~ /^[\d\-]+$/ || ($racku != -99 && $racku <0) ) {
		return $stab->error_return("Rack Units must be numeric");
	}

	if($model && length($model) > 1000) {
		return $stab->error_return("Model length exceeds 1000 characters");	     
	}

	if($cfgfetch && length($cfgfetch) > 200) { 
		return $stab->error_return("Config Fetch type exceeds 200 characters"); 
	} 

	if($descr && length($descr) > 16000) {
		return $stab->error_return("Description Exceeds 16000 characters");     
	}


	my %newdevice = (
		DEVICE_TYPE_ID		=> $devtypid,
		COMPANY_ID			=> $partid,
		MODEL				=> $model,
		CONFIG_FETCH_TYPE	=> $cfgfetch,
		PROCESSOR_ARCHITECTURE	=> $arch,
		RACK_UNITS			=> $racku,
		DESCRIPTION			=> $descr,
		HAS_802_3_INTERFACE => $has8023,
		HAS_802_11_INTERFACE=> $has80211,
		SNMP_CAPABLE		=> $cansnmp
	);

	my $dbdevice = $stab->get_device_type_from_id($devtypid);
	my $diffs = $stab->hash_table_diff($dbdevice, \%newdevice);
	my $tally += keys %$diffs;
	$numchanges += $tally;

	if($tally && !$stab->build_update_sth_from_hash("DEVICE_TYPE", "DEVICE_TYPE_ID", $devtypid, $diffs)) {
		$dbh->rollback;
		my $url = "../devicetype.pl";
		$stab->error_return("Unknown Error with Update", $url);
	}

	if($numchanges) {
		$dbh->commit;
		my $refurl = "../?DEVICE_TYPE_ID=$devtypid";
		$stab->msg_return("Device Updated", $refurl, 1);
	} else {
		$stab->msg_return("Nothing to do", undef, 1);
		$dbh->rollback;
	}

	$dbh->rollback;
}

1;
