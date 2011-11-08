#!/usr/local/bin/perl
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

do_device_type_add();

############################################################################

sub do_device_type_add {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $numchanges = 0;

	my $devtypid;

	my $pwrcount = $stab->cgi_parse_param('POWER_INTERFACE_PORT_COUNT');
	# physical portage is handled later

	my $compid = $stab->cgi_parse_param('COMPANY_ID', $devtypid);
	my $arch = $stab->cgi_parse_param('PROCESSOR_ARCHITECTURE', $devtypid);
	my $model = $stab->cgi_parse_param('MODEL', $devtypid);
	my $descr = $stab->cgi_parse_param('DESCRIPTION', $devtypid);
	my $cfgfetch = $stab->cgi_parse_param('CONFIG_FETCH_TYPE', $devtypid);
	my $racku = $stab->cgi_parse_param('RACK_UNITS', $devtypid);
	my $cansnmp = $stab->cgi_parse_param('chk_SNMP_CAPABLE', $devtypid);
	my $has8023 = $stab->cgi_parse_param('chk_HAS_802_3_INTERFACE', $devtypid);
	my $has80211 = $stab->cgi_parse_param('chk_HAS_802_11_INTERFACE', $devtypid);

	$cansnmp = $stab->mk_chk_yn($cansnmp);
	$has8023 = $stab->mk_chk_yn($has8023);
	$has80211 = $stab->mk_chk_yn($has8023);

	if(!defined($compid)) {
		return $stab->error_return("You must specify a vendor");
	}

	if(!defined($model)) {
		return $stab->error_return("You must specify a model");
	}

	my $curdt = $stab->get_device_type_from_name($compid, $model);
	if($curdt) {
		undef $curdt;
		$stab->error_return("That device already exists.");
	}

	if(!defined($racku)) {
		return $stab->error_return("You must specify rack units");
	} elsif($racku !~ /^[\d\-]+$/ || ($racku != -99 && $racku <0) ) {
		return $stab->error_return("Rack Units must be a positive number");
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

	#
	# Check to see if a start, voltage, amp are specified without a
	# count.
	#
	my $pwrstart    = $stab->cgi_parse_param('POWER_INTERFACE_PORT_START');
	my $pwrpstyl    = $stab->cgi_parse_param('PLUG_STYLE');
	my $pwrvolt	= $stab->cgi_parse_param('VOLTAGE');
	my $pwrmaxamp   = $stab->cgi_parse_param('MAX_AMPERAGE');

	if(!$pwrcount && ($pwrstart || $pwrpstyl || $pwrvolt || $pwrmaxamp)) {
		return $stab->error_return("You must specify a power count to setup power ports");
	}

	#################
	### Now go and add the device type
	# [XXX] - need to properly handle provides_power Y/N.  Now it just
	# defaults to N.
	my $q = qq{
		insert into device_type (
			COMPANY_ID, MODEL, CONFIG_FETCH_TYPE, RACK_UNITS,
			HAS_802_3_INTERFACE, HAS_802_11_INTERFACE, SNMP_CAPABLE,
			PROCESSOR_ARCHITECTURE, DESCRIPTION
		) values (
			:company, :model, :cfgfetch, :ru,
			:has8023, :has80211, :cansnmp,
			:procarch, :descr
		) returning DEVICE_TYPE_ID into :devtypid
	};
	my $sth = $stab->prepare($q) || $stab->return_db_error;
	$sth->bind_param(':company', $compid) || $stab->return_db_error($sth);
	$sth->bind_param(':model', $model) || $stab->return_db_error($sth);
	$sth->bind_param(':cfgfetch', $cfgfetch) || $stab->return_db_error($sth);
	$sth->bind_param(':descr', $descr) || $stab->return_db_error($sth);
	$sth->bind_param(':ru', $racku) || $stab->return_db_error($sth);
	$sth->bind_param(':has8023', $has8023) || $stab->return_db_error($sth);
	$sth->bind_param(':has80211', $has80211) || $stab->return_db_error($sth);
	$sth->bind_param(':cansnmp', $cansnmp) || $stab->return_db_error($sth);
	$sth->bind_param(':procarch', $arch) || $stab->return_db_error($sth);

	$sth->bind_param_inout(':devtypid', \$devtypid, 50) || $stab->return_db_error($sth);

	$numchanges += $sth->execute || $stab->return_db_error($sth);

	### Add power ports

	my $didstuff = 0;
	if(defined($pwrcount) && $pwrcount) {
		if($pwrcount > 50) {
			$stab->error_return("You can't be serious?");
		}
		$numchanges += $stab->add_power_ports($devtypid);
	}

	### Add physical ports
	$numchanges += process_physical_portage($stab, $devtypid, 'serial');
	$numchanges += process_physical_portage($stab, $devtypid, 'network');

	if($numchanges) {
		my $url = "../?DEVICE_TYPE_ID=$devtypid";
		$stab->commit;
		$stab->msg_return("Addition Suceeded", $url, 1);
	}
	$stab->rollback;
	$stab->msg_return("Nothing to do", undef, 1);
}

sub process_physical_portage {
	my ($stab, $devtypid, $type) = @_;

	my $captype = $type;
	$captype =~ tr/a-z/A-Z/;

	#
	# Check to see if physical port fields are specified without a count
	#
	my $count = $stab->cgi_parse_param("${captype}_INTERFACE_PORT_COUNT");
	my $prefix	= $stab->cgi_parse_param("${captype}_PORT_PREFIX");
	my $start	= $stab->cgi_parse_param("${captype}_INTERFACE_PORT_START");

	if(!$count && ($prefix || $start) ) {
		return $stab->error_return("You must specify a $type count to setup $type ports.");
	}

	my $numchanges = 0;
	if((defined($count) && $count) || defined($prefix)) {
		if($count > 250) {
			$stab->error_return("($type) You can't be serious?");
		}
		$numchanges += $stab->add_physical_ports($devtypid, $type);
	}
	$numchanges;
}
