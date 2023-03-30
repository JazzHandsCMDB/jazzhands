#!/usr/bin/env perl
#
# Copyright (c) 2010-2017 Todd M. Kover
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

#
# this script validates input for an addition, and in the event of problem,
# will send an error message and present the user with an opportunity to
# fix.
#

#
# [XXX]
# - need to properly process deletion of interfaces (checkbox) <= test
# - also need checkbox to not be dumb (checking unchecks the other) <= test
# - deal with serial, power, location, switchport updates
# - consider breaking do_update_device into just a caller of subroutines
# - merge add device/interface
# - add interface should also appear on update interface
#	- javascript/ajax adding of multiple interfaces?
#

use strict;
use warnings;
use JazzHands::STAB;
use JazzHands::Common qw(:all);
use Data::Dumper;
use URI;
use Carp qw(cluck);

return do_update_device();

###########################################################################

#
# this is also done in the dns section.  This clears out parameters that
# aren't different so error returns work properly when there are a metric
# ton of switch ports (so the get line on errors is managable).
#
# needs to be tweaked to suck down all the possible parameters, and check
# rather than running a bunch of little queries.  XXX
#
sub clear_same_physical_port_params {
	my ($stab) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	for my $pportid ( $stab->cgi_get_ids('P1_PHYSICAL_PORT_ID') ) {
		my $p2devid = $stab->cgi_parse_param( 'P2_DEVICE_ID', $pportid );
		my $p2portid =
		  $stab->cgi_parse_param( 'P2_PHYSICAL_PORT_ID', $pportid );
		my $baud     = $stab->cgi_parse_param( 'BAUD',          $pportid );
		my $stopbits = $stab->cgi_parse_param( 'STOP_BITS',     $pportid );
		my $databits = $stab->cgi_parse_param( 'DATA_BITS',     $pportid );
		my $parity   = $stab->cgi_parse_param( 'PARITY',        $pportid );
		my $serparam = $stab->cgi_parse_param( 'SERIAL_PARAMS', $pportid );
		my $flow     = $stab->cgi_parse_param( 'FLOW_CONTROL',  $pportid );

		if ($serparam) {
			( $databits, $parity, $stopbits ) = serial_abbr_to_field($serparam);
			next if ( !$databits || !$parity || !$stopbits );
		}

		my $l1c = $stab->get_layer1_connection_from_port($pportid);

		next if ( !$l1c && $p2portid );

		if ($l1c) {
			if (   defined( $l1c->{ _dbx('BAUD') } )
				&& defined($baud) )
			{
				next if ( $l1c->{ _dbx('BAUD') } ne $baud );
			} elsif ( !defined( $l1c->{ _dbx('BAUD') } )
				&& !defined($baud) )
			{
				;
			} else {
				next;
			}
			if (   defined( $l1c->{ _dbx('STOP_BITS') } )
				&& defined($stopbits) )
			{
				next
				  if ( $l1c->{ _dbx('STOP_BITS') } ne $stopbits );
			} elsif ( !defined( $l1c->{ _dbx('STOP_BITS') } )
				&& !defined($stopbits) )
			{
				;
			} else {
				next;
			}
			if (   defined( $l1c->{ _dbx('DATA_BITS') } )
				&& defined($databits) )
			{
				next
				  if ( $l1c->{ _dbx('DATA_BITS') } ne $databits );
			} elsif ( !defined( $l1c->{ _dbx('DATA_BITS') } )
				&& !defined($databits) )
			{
				;
			} else {
				next;
			}
			if (   defined( $l1c->{ _dbx('PARITY') } )
				&& defined($parity) )
			{
				next if ( $l1c->{ _dbx('PARITY') } ne $parity );
			} elsif ( !defined( $l1c->{ _dbx('PARITY') } )
				&& !defined($parity) )
			{
				;
			} else {
				next;
			}
			if (   defined( $l1c->{ _dbx('FLOW_CONTROL') } )
				&& defined($flow) )
			{
				next
				  if ( $l1c->{ _dbx('FLOW_CONTROL') } ne $flow );
			} elsif ( !defined( $l1c->{ _dbx('FLOW_CONTROL') } )
				&& !defined($flow) )
			{
				;
			} else {
				next;
			}

			if ( $l1c->{ _dbx('PHYSICAL_PORT1_ID') } == $pportid ) {
				next
				  if ( !$p2portid
					&& defined( $l1c->{ _dbx('PHYSICAL_PORT2_ID') } )
					|| $l1c->{ _dbx('PHYSICAL_PORT2_ID') } != $p2portid );
			}
			if ( $l1c->{ _dbx('PHYSICAL_PORT2_ID') } == $pportid ) {
				next
				  if ( !$p2portid
					&& defined( $l1c->{ _dxb('PHYSICAL_PORT1_ID') } )
					|| $l1c->{ _dbx('PHYSICAL_PORT1_ID') } != $p2portid );
			}
		}

		$cgi->delete( "P1_PHYSICAL_PORT_ID__" . $pportid );    # umm, wtf?
		$cgi->delete( "P1_PHYSICAL_PORT_ID_" . $pportid );
		$cgi->delete( "P2_PHYSICAL_PORT_ID_" . $pportid );
		$cgi->delete( "P2_DEVICE_ID_" . $pportid );
		$cgi->delete( "P2_DEVICE_NAME_" . $pportid );
		$cgi->delete( "BAUD_" . $pportid );
		$cgi->delete( "SERIAL_PARAMS_" . $pportid );
		$cgi->delete( "STOP_BITS_" . $pportid );
		$cgi->delete( "DATA_BITS_" . $pportid );
		$cgi->delete( "PARITY_" . $pportid );
		$cgi->delete( "FLOW_CONTROL_" . $pportid );
	}

}

sub do_update_device {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";

	my $devid     = $stab->cgi_get_ids('DEVICE_ID');
	my $devtypeid = $stab->cgi_parse_param( 'DEVICE_TYPE_ID', $devid );
	my $serialno  = $stab->cgi_parse_param( 'SERIAL_NUMBER', $devid );
	my $partno    = $stab->cgi_parse_param( 'PART_NUMBER', $devid );
	my $leasexp   = $stab->cgi_parse_param( 'LEASE_EXPIRATION_DATE', $devid );
	my $site      = $stab->cgi_parse_param( 'SITE_CODE', $devid );
	my $status    = $stab->cgi_parse_param( 'DEVICE_STATUS', $devid );
	my $owner     = $stab->cgi_parse_param( 'OWNERSHIP_STATUS', $devid );
	my $svcenv    = $stab->cgi_parse_param( 'SERVICE_ENVIRONMENT_ID', $devid );
	my $assettag  = $stab->cgi_parse_param( 'ASSET_TAG', $devid );
	my $osid      = $stab->cgi_parse_param( 'OPERATING_SYSTEM_ID', $devid );
	my $ismonitored = $stab->cgi_parse_param( 'chk_IS_MONITORED', $devid );
	my $baselined   = $stab->cgi_parse_param( 'chk_IS_BASELINED', $devid );
	my $parentid    = $stab->cgi_parse_param( 'PARENT_DEVICE_ID', $devid );
	my $localmgd = $stab->cgi_parse_param( 'chk_IS_LOCALLY_MANAGED', $devid );
	my $cfgfetch = $stab->cgi_parse_param( 'chk_SHOULD_FETCH_CONFIG', $devid );
	my $virtdev  = $stab->cgi_parse_param( 'chk_IS_VIRTUAL_DEVICE', $devid );
	my $mgmtprot = $stab->cgi_parse_param( 'AUTO_MGMT_PROTOCOL', $devid );
	my $appgtab  = $stab->cgi_parse_param( 'has_appgroup_tab', $devid );
	my @appgroup = $stab->cgi_parse_param( 'appgroup', $devid );

	#-print $cgi->header, $cgi->html($cgi->Dump()); exit;
	# print $cgi->header, $cgi->start_html,
	# my @x = $cgi->param('appgroup_'.$devid);
	# print $cgi->p("appgroup is ", $cgi->ul(@appgroup), "totally");
	# print $cgi->pre($cgi->b($cgi->ul(@x)));
	# print $cgi->b($cgi->self_url);
	# print $cgi->Dump, $cgi->end_html; exit;

	#
	# name is special
	#
	my $devname   = $cgi->param( 'DEVICE_NAME_' . $devid );
	my $physlabel = $cgi->param( 'PHYSICAL_LABEL_' . $devid );

	my $serial_reset  = $stab->cgi_parse_param('chk_dev_port_reset');
	my $retire_device = $stab->cgi_parse_param('chk_dev_retire');

	my $resyncpower  = $stab->cgi_parse_param( 'power_port_resync',  $devid );
	my $resyncserial = $stab->cgi_parse_param( 'serial_port_resync', $devid );
	my $resyncswitch = $stab->cgi_parse_param( 'switch_port_resync', $devid );

	if ($devname) {
		$devname =~ s/^\s+//;
		$devname =~ s/\s+$//;
		$devname =~ tr/A-Z/a-z/;
	}
	if ($serialno) {
		$serialno =~ s/^\s+//;
		$serialno =~ s/\s+$//;
	}

	if ( defined($devname) && !length($devname) ) {
		$stab->error_return(
			"To remove a device (blank the name) you must retire on the Advanced Tab"
		);
	}

	$ismonitored = $stab->mk_chk_yn($ismonitored);
	$localmgd    = $stab->mk_chk_yn($localmgd);
	$virtdev     = $stab->mk_chk_yn($virtdev);
	$cfgfetch    = $stab->mk_chk_yn($cfgfetch);
	$baselined   = $stab->mk_chk_yn($baselined);

	if ( !defined($devid) ) {
		$stab->error_return("You must actually specify a device to update.");
	}

	#
	# get the current data and submit the difference if there are changes.
	#
	my $dbdevice = $stab->get_dev_from_devid($devid);
	if ( !$dbdevice ) {
		$stab->error_return("Unknown Device");
	}

	clear_same_physical_port_params($stab);

	# [XXX] need to clear same power ports, too!

	#
	# check to see if the device name already exists
	#
	if ( defined($devname) ) {
		my $existingdev = $stab->get_dev_from_name($devname);
		if (   $existingdev
			&& $existingdev->{ _dbx('DEVICE_ID') } != $devid )
		{
			$stab->error_return("A device by that name already exists.");
		}
	} else {

		# this is so the box can be grey'd out.
		$devname = $dbdevice->{ _dbx('DEVICE_NAME') };
	}

	if ( !defined($physlabel) ) {
		$physlabel = $dbdevice->{ _dbx('PHYSICAL_LABEL') };
	}

	my $numchanges = 0;

	#
	# to catch the case of everything being unchecked, the tab sets
	# something to indicate that the tab was loaded.
	#
	#if($stab->cgi_parse_param('dev_func_tab_loaded', $devid)) {
	#	#
	#	# gather up all the device functions
	#	#
	#	my(@devfuncs);
	#	foreach my $p ($cgi->param) {
	#		if($p =~ /^chk_dev_func_([^_]+)(_(\d+))?$/i) {
	#			my ($func, $fdevid) = ($1, $3);
	#			next if($fdevid != $devid);
	#			$func =~ tr/A-Z/a-z/;
	#			push(@devfuncs, $func);
	#		}
	#	}
	#	$numchanges += reconcile_dev_functions($stab, $devid, \@devfuncs);
	#}

	if ($appgtab) {
		$numchanges += reconcile_appgroup( $stab, $devid, \@appgroup );
	}

	# everything about the device is pulled in, so now go and update the
	# actual device.

	$numchanges += update_location( $stab, $devid );
	$numchanges += update_all_interfaces( $stab, $devid );
	$numchanges += update_all_dns_value_references( $stab, $devid );
	$numchanges += add_device_note( $stab, $devid );

	if ( $serial_reset && $retire_device ) {
		$stab->error_return(
			"You may not both reset serial ports and retire the box.");
	}

	if ($retire_device) {
		return retire_device( $stab, $devid );

		# this does not return.
	}

	if ($serial_reset) {
		$numchanges += reset_serial_to_default( $stab, $devid );
	}

	$numchanges += update_physical_ports( $stab, $devid, $serial_reset );
	$numchanges += update_power_ports( $stab, $devid );
	$numchanges += add_interfaces( $stab, $devid );

	# Not there today..
	#- $numchanges += process_licenses($stab, $devid);
	$numchanges += process_interfaces( $stab, $devid );
	$numchanges += update_functions( $stab, $devid );

	my $assetid = $dbdevice->{ _dbx('ASSET_ID') };

	# Does the asset exist?
	if ($assetid) {
		my $dbasset =
		  $stab->get_asset_from_component_id(
			$dbdevice->{ _dbx('COMPONENT_ID') } );
		if ( !$dbasset ) {
			return $stab->error_return(
				"Unable to obtain asset info.  Seek help");
		}

		if (   $serialno
			&& $dbasset->{ _dbx('SERIAL_NUMBER') }
			&& $dbasset->{ _dbx('SERIAL_NUMBER') } ne $serialno )
		{
			my $sernodev = $stab->get_dev_from_serial($serialno);
			if (   $sernodev
				&& $serialno ne 'Not-Applicable'
				&& $serialno !~ m,^n/a$,i )
			{
				$stab->error_return("That serial number is in use.");
			}
		}

		my $newasset = {
			ASSET_ID              => $dbasset->{ _dbx('ASSET_ID') },
			SERIAL_NUMBER         => $serialno,
			PART_NUMBER           => $partno,
			ASSET_TAG             => $assettag,
			OWNERSHIP_STATUS      => $owner,
			LEASE_EXPIRATION_DATE => $leasexp,
		};

		my $diffs = $stab->hash_table_diff( $dbasset, _dbx($newasset) );
		my $tally   += keys %$diffs;
		$numchanges += $tally;

		if (
			$tally
			&& !$stab->run_update_from_hash(
				"ASSET", "ASSET_ID", $assetid, $diffs
			)
		  )
		{
			$stab->rollback;
			my $url = "../device.pl";
			return $stab->return_db_err;
		}

		# If the asset doesn't exist and if we have a component_id for the device, let's create the missing asset
	} elsif ( defined( $dbdevice->{ _dbx('COMPONENT_ID') } ) ) {
		my @errs;
		my $newasset = {
			COMPONENT_ID          => $dbdevice->{ _dbx('COMPONENT_ID') },
			SERIAL_NUMBER         => $serialno,
			PART_NUMBER           => $partno,
			ASSET_TAG             => $assettag,
			OWNERSHIP_STATUS      => $owner || 'unknown',
			LEASE_EXPIRATION_DATE => $leasexp,
		};

		if (
			!(
				$numchanges += $stab->DBInsert(
					table  => 'asset',
					hash   => $newasset,
					errors => \@errs
				)
			)
		  )
		{
			$stab->error_return( join( " ", @errs ) );
		}
		my $assetid = $newasset->{ _dbx('ASSET_ID') };
	}

	my $newdevice = {
		DEVICE_ID      => $devid,
		DEVICE_NAME    => $devname,
		DEVICE_TYPE_ID => $devtypeid,

		#- SERIAL_NUMBER  => $serialno,
		PART_NUMBER    => $partno,
		PHYSICAL_LABEL => $physlabel,

		#- DEVICE_STATUS		=> $status,

		#- OPERATING_SYSTEM_ID	=> $osid,
		IS_MONITORED        => $ismonitored,
		IS_LOCALLY_MANAGED  => $localmgd,
		SHOULD_FETCH_CONFIG => $cfgfetch,
		IS_VIRTUAL_DEVICE   => $virtdev,
		AUTO_MGMT_PROTOCOL  => $mgmtprot,

		SITE_CODE              => $site,
		SERVICE_ENVIRONMENT_ID => $svcenv,
	};

	#
	# This can not be set on pages where there are virtual devices
	# and thus would clear the field if it was blindly passed in.
	if ( $dbdevice->{ _dbx('IS_VIRTUAL_DEVICE') } eq 'N' ) {
		$newdevice->{'PARENT_DEVICE_ID'} = $parentid;
	}

	my $diffs = $stab->hash_table_diff( $dbdevice, _dbx($newdevice) );

	my $tally   += keys %$diffs;
	$numchanges += $tally;

	if ($resyncpower) {
		$numchanges += $stab->resync_device_power( _dbx($newdevice) );
	}

	if ($resyncserial) {
		$numchanges +=
		  $stab->resync_physical_ports( _dbx($newdevice), 'serial' );
	}

	if ($resyncswitch) {
		$numchanges +=
		  $stab->resync_physical_ports( _dbx($newdevice), 'network' );
	}

	if ( $numchanges == 0 ) {
		$stab->msg_return("Nothing changed. No updates submitted.");
		exit;
	}
	if ( $tally
		&& !$stab->run_update_from_hash( "DEVICE", "DEVICE_ID", $devid, $diffs )
	  )
	{
		$stab->rollback;
		my $url = "../device.pl";
		$stab->error_return( "Unknown Error with Update", $url );
	}

	$stab->commit || $stab->error_return;
	my $url = "../device.pl?devid=$devid";

	my $rettab = $stab->cgi_parse_param('__default_tab__');
	if ($rettab) {
		$url .= ";__default_tab__=$rettab";
	}
	$stab->msg_return( "Update successful.", $url, 1 );
	undef $stab;

	1;
}

sub get_dev_funcs {
	my ( $stab, $devid ) = @_;

	my (@oldfuncs);
	my $q = qq{
		select	device_function_type
		  from	device_function
		 where	device_id = ?
	};
	my $sth = $stab->prepare($q) || die $stab->return_db_err;
	$sth->execute($devid) || die $stab->return_db_err($sth);

	while ( my ($func) = $sth->fetchrow_array ) {
		push( @oldfuncs, $func );
	}

	return (@oldfuncs);
}

sub reconcile_appgroup {

	# $appgroup is array ref
	my ( $stab, $devid, $appgroup ) = @_;

	return 0 if ( !$appgroup );

	my $numchanges = 0;

	# get a list of the currently assigned leaf nodes for manipulation
	# purposes;
	my @curlist =
	  $stab->get_device_collections_for_device( $devid, 'appgroup' );

	# 1. go through all the leaf appgroups in the db and see if any need
	# to be unset
	my $sth = $stab->prepare(
		qq{
		begin
			appgroup_util.remove_role(?, ?);
		end;
	}
	) || die $stab->return_db_err;

	foreach my $dcid (@curlist) {
		next if ( grep( $_ eq $dcid, @$appgroup ) );
		$numchanges += $sth->execute( $devid, $dcid )
		  || $stab->return_db_err($sth);
	}

	# 2. go through all the appgroups in the argument list and see if any
	# need to be set (using the pl/sql function for setting such things
	$sth = $stab->prepare(
		qq{
		begin
			appgroup_util.add_role(?, ?);
		end;
	}
	) || die $stab->return_db_err;

	foreach my $dcid (@$appgroup) {
		next if ( grep( $_ eq $dcid, @curlist ) );
		$numchanges += $sth->execute( $devid, $dcid )
		  || $stab->return_db_err($sth);
	}

	$numchanges;
}

#
# this will be retired and is now driven off of appgroups (see above function)
#
sub reconcile_dev_functions {
	my ( $stab, $devid, $newfunc ) = @_;

	my $numchanges = 0;

	my @oldfunc = get_dev_funcs( $stab, $devid );

	#
	# remove what was there if it's not checked any more.
	#
	if ( $#oldfunc >= 0 ) {
		my $q = qq{
			delete from device_function
			 where	device_id = ? and device_function_type = ?
		};
		my $sth = $stab->prepare($q) || die $stab->return_db_err;

		foreach my $func (@oldfunc) {
			if ( !grep( $_ eq $func, @$newfunc ) ) {
				$sth->execute( $devid, $func )
				  || $stab->return_db_err($sth);
				$numchanges++;
			}
		}
	}

	#
	# Now, add the new.
	#

	my $q = qq{
		insert into device_function (device_id, device_function_type)
			values (?, ?)
	};
	my $sth = $stab->prepare($q) || die $stab->return_db_err;
	foreach my $func (@$newfunc) {
		if ( !grep( $_ eq $func, @oldfunc ) ) {
			$sth->execute( $devid, $func )
			  || die $stab->return_db_err($sth);
			$numchanges++;
		}
	}

	$numchanges++;

}

sub update_location {
	my ( $stab, $devid ) = @_;

	my $locid = $stab->cgi_get_ids('RACK_LOCATION_ID');

	my $numchanges = 0;

	# Attempt to read the location from the original rack dropdown, which as the location id in its name
	my $rackid = $stab->cgi_parse_param( 'LOCATION_RACK_ID', $locid );

	# If we don't have that value, it could be because the datacenter was changed
	# In that case, the rack dropdown doesn't have the location id in its name anymore
	# That's the response from device-ajax.pl?what=SiteRacks;type=dev;SITE_CODE=FRA1;RACK_LOCATION_ID=16411
	if ( !$rackid ) {
		$rackid = $stab->cgi_parse_param('LOCATION_RACK_ID');
	}
	if ( !$rackid ) {
		return $numchanges;
	}

	my $ru   = $stab->cgi_parse_param( 'LOCATION_RU_OFFSET', $locid );
	my $side = $stab->cgi_parse_param( 'LOCATION_RACK_SIDE', $locid );

	my $curloc = $stab->get_location_from_devid( $devid, 1 );

	if ( defined($locid) && $locid < 0 ) {

		# this means the record needs to be deleted from the db, location
		# set to null for the device, $curloc set to null, and the new
		# location added as though it was never there.
		#
		# NOTE that this never gets called if rack id is not set, so its
		# not possible to change just the site code.  This probably needs
		# to be revisited, but so does the entire location code.
		if ( !$stab->cleanup_bogus_location( $devid, $locid ) ) {
			$stab->error_return('Location does not match Value set on Device');
		}
		$curloc = undef;
	}

	# No location previously existed and no new value provided, the user is not trying to update the location
	return
	  if ( !defined($curloc)
		&& $rackid eq ''
		&& $locid eq ''
		&& $ru eq ''
		&& $side eq '' );

	if ( !defined($rackid) || !defined($side) || !defined($ru) ) {
		$stab->error_return(
			'Rack, U Offset and Rack Side are mandatory parameters.');
	}

	if ( !defined($ru) || $ru !~ /^-?\d+$/ ) {
		$stab->error_return('U Offset must be a number.');
	}

	my %newloc = (
		RACK_LOCATION_ID            => $locid,
		RACK_ID                     => $rackid,
		RACK_U_OFFSET_OF_DEVICE_TOP => $ru,
		RACK_SIDE                   => $side,
	);
	my $newloc = \%newloc;

	#
	# no location previously existed, lets set a new one!
	#
	if ( !$curloc || !defined( $curloc->{ _dbx('RACK_LOCATION_ID') } ) ) {
		return $stab->add_location_to_dev( $devid, $newloc );
	}

	my $diffs = $stab->hash_table_diff( $curloc, _dbx($newloc) );
	my $tally   += keys %$diffs;
	$numchanges += $tally;

	if (
		$tally
		&& !$stab->run_update_from_hash(
			"RACK_LOCATION", "RACK_LOCATION_ID", $locid, $diffs
		)
	  )
	{
		$stab->rollback;
		my $url = "../device.pl";
		$stab->error_return( "Unknown Error with Update", $url );
	}

	$numchanges;
}

############################################################################
#
# interface components
#
############################################################################

sub delete_old_netblock {
	my ( $stab, $netblock_id ) = @_;

	return undef unless ( defined($netblock_id) );

	my @qs = (
		qq{delete from network_interface_netblock
			where netblock_id = ?
		},
		qq{delete from netblock
			where netblock_id = ?
		},
	);
	foreach my $q (@qs) {
		my $sth = $stab->prepare($q) || $stab->return_db_err;
		$sth->execute($netblock_id)
		  || $stab->return_db_err($sth);
	}
}

sub configure_nb_if_ok {
	my ( $stab, $netblock_id, $ip_ui ) = @_;

	my $newblock = $stab->get_netblock_from_ip(
		ip_address        => $ip_ui,
		is_single_address => 'Y',
		netblock_type     => 'default',
	);

	# If netblocks aren't changing, then its ok.
	if ( defined($netblock_id) && defined($newblock) ) {
		if ( $netblock_id == $newblock->{ _dbx('NETBLOCK_ID') } ) {

			# Just return the existing netblock
			return $netblock_id;
		} else {

			# If the netblock is on a device, consider that bad.  Otherwise
			# jut absorb the IP.  This allows devices to be added to DNS but
			# later attached to devices.  Less than ideal, but at least its
			# cleanup.
			my $nbid = $newblock->{ _dbx('NETBLOCK_ID') };
			if ( $stab->get_interface_from_netblock_id($nbid) ) {
				return $stab->error_return("$ip_ui is in use on a device");
			}
		}
	}

	$newblock = $stab->configure_allocated_netblock( $ip_ui, $newblock );

	# Check if the netblock could be allocated
	if ( !defined($newblock) ) {
		$stab->error_return( "Could not configure IP address "
			  . ( defined($ip_ui) ? $ip_ui : "--unset--" )
			  . "Seek help." );
	}

	$newblock->{ _dbx('NETBLOCK_ID') };
}

# This function returns all dns records associated to a netblock
sub get_dns_records_from_netblock_id {
	my ( $stab, $id ) = @_;

	return undef unless ( defined($id) );

	my $q = qq{
		select *
		from	dns_record
		where	netblock_id = ?
		order by should_generate_ptr desc, dns_name
	};

	#  	    	and		should_generate_ptr = 'Y'

	my $sth = $stab->prepare($q) || die $stab->return_db_err;
	$sth->execute($id) || die $stab->return_db_err($sth);

	# Get all records as a single hash with dns record ids being the keys
	my $hr = $sth->fetchall_arrayref( {} );
	$sth->finish;
	$hr;
}

sub get_dns_record {
	my ( $stab, $id ) = @_;

	my $q = qq{
		select *
		 from	dns_record
		where	dns_record_id = ?
	};
	my $sth = $stab->prepare($q) || die $stab->return_db_err;
	$sth->execute($id) || die $stab->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

# This function returns all network_interface columns for the specified id
sub get_network_interface {
	my ( $stab, $id ) = @_;

	#my $q = qq{
	#	select network_interface.*,network_interface_netblock.netblock_id
	#	from	network_interface
	#	left join network_interface_netblock
	#	using   (network_interface_id)
	#	where	network_interface_id = ?
	#};
	my $q = qq{
		select network_interface.*
		from	network_interface
		where	network_interface_id = ?
	};
	my $sth = $stab->prepare($q) || die $stab->return_db_err;
	$sth->execute($id) || die $stab->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_total_ifs {
	my ( $stab, $id ) = @_;

	my $q = qq{
		select	count(*)
		  from	network_interface
		 where	device_id = ?
	};
	my $sth = $stab->prepare($q) || die $stab->return_db_err;
	$sth->execute($id) || die $stab->return_db_err($sth);
	my ($rv) = $sth->fetchrow_array;
	$sth->finish;
	$rv;
}

#
# return number of children for a given network_interface
#
sub number_interface_kids {
	my ( $stab, $netintid ) = @_;

	my $sth = $stab->prepare(
		qq{
		select	count(*)
		 from	network_interface
		where	parent_network_interface_id = ?
	}
	) || $stab->return_db_err;

	$sth->execute($netintid) || $stab->return_db_err($sth);
	my ($tally) = $sth->fetchrow_array;
	$sth->finish;
	$tally;
}

# This function deletes an interface and its purposes, if any
sub delete_interface {
	my ( $stab, $netintid ) = @_;

	if ( !defined($netintid) ) { return 0; }

	if ( my $tally = number_interface_kids( $stab, $netintid ) ) {
		$stab->error_return(
			"You can not remove parent interfaces when they still have child interfaces. ($netintid, # $tally)"
		);
	}

	# Need to delete network interface purposes first
	my $query_delete_purposes = qq(
		delete from network_interface_purpose
			where network_interface_id = ?
	);
	my $sth = $stab->prepare($query_delete_purposes) || $stab->return_db_err;
	$sth->execute($netintid)
	  || $stab->return_db_err( $sth,
		"Can't delete network interface $netintid purposes.\n" );

	# Delete the interface
	# Note: the netblocks should be gone by now, the first query shouldn't be needed
	my @qs = (
		qq{delete from network_interface_netblock
			where network_interface_id = ?
		},
		qq{delete from network_interface
			where network_interface_id = ?
		},
	);
	foreach my $q (@qs) {
		my $sth = $stab->prepare($q) || $stab->return_db_err;
		$sth->execute($netintid)
		  || $stab->return_db_err( $sth, "netintid: $netintid" );
	}

	$stab->commit || $stab->error_return;
	1;
}

sub get_dnsids {
	my ( $stab, $netblockid ) = @_;

	my (@dnsid);

	my $q = qq{
		select	dns.dns_record_id, dns.dns_name, dom.soa_name
		  from	dns_record dns
			inner join dns_domain dom on
				dns.dns_domain_id = dom.dns_domain_id
		 where	dns.netblock_id = ?
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err;
	$sth->execute($netblockid) || $stab->return_db_err($sth);
	while ( my ( $id, $dns, $dom ) = $sth->fetchrow_array ) {
		my $fqhn = "$dns" if ( defined($dns) );
		$fqhn .= ".$dom" if ( defined($dom) );
		push( @dnsid, $id, $fqhn );
	}
	$sth->finish;
	\@dnsid;
}

sub process_netblock_and_dns {
	my ( $stab, $network_interface_id, $netblock_id, $ip_ui, $refnumlockeddns,
		$refnumchanges )
	  = @_;

	# Get the existing DNS records for the netblock
	# In case of IP change, this will only consider records that have been transferred to the new IP - see above
	# This also means that updates to a DNS records that is left assigned to the old netblock won't be applied
	my $dns_records;
	$dns_records = get_dns_records_from_netblock_id( $stab, $netblock_id );

	# Configure the netblock, but only if the requested ip address is not in use by another netbblock
	# If the netblock allocation fails, this function fails with an error and the processing stops here
	my $configured_netblock_id =
	  configure_nb_if_ok( $stab, $netblock_id, $ip_ui );

	# Loop on the DNS records associated to the initial netblock
	foreach my $dns_record (@$dns_records) {

		my $dns_record_id = $dns_record->{'dns_record_id'};
		my $dns_ui        = $stab->cgi_parse_param( 'DNS_NAME',
			$network_interface_id . '_' . $netblock_id . '_' . $dns_record_id );
		my $dnsdom_ui = $stab->cgi_parse_param( 'DNS_DOMAIN_ID',
			$network_interface_id . '_' . $netblock_id . '_' . $dns_record_id );
		my $dnsptr_ui = $stab->cgi_parse_param( 'DNS_PTR',
			$network_interface_id . '_' . $netblock_id );
		my $dnstoggle_ui = $stab->cgi_parse_param( 'DNS_TOGGLE',
			$network_interface_id . '_' . $netblock_id . '_' . $dns_record_id );

		# The value of the DNS_PTR radio group is the id of the selected group member
		# There is on radio group per netblock and each group has N+1 member
		# where N is the number of DNS records. The extra member is the new dns record.
		if (  $dnsptr_ui eq 'DNS_PTR_'
			. $network_interface_id . '_'
			. $netblock_id . '_'
			. $dns_record_id )
		{
			$dnsptr_ui = 'Y';
		} else {
			$dnsptr_ui = 'N';
		}

		# Remove leading and trailing spaces from dns name
		# Also remove trailing dots since they would just result in
		# double dots in final zone generation
		if ($dns_ui) {
			$dns_ui =~ s/^\s+//;
			$dns_ui =~ s/\s+$//;
			$dns_ui =~ s/\.+$//;
		}

		# The DNS record is marked for deletion
		if ( $dnstoggle_ui eq 'delete' ) {
			my @qs = (
				qq{
					delete from	dns_record
					where		dns_value_record_id = ?
				},
				qq{
					delete from	dns_record
					where		dns_record_id = ?
				},
			);
			foreach my $q (@qs) {
				my $sth = $stab->prepare($q) || $stab->return_db_err;
				$sth->execute($dns_record_id) || $stab->return_db_err($sth);
				$sth->finish;
			}

			$$refnumchanges++;

			# Nothing else to process for this dns record, move to next one
			next;
		}

		# At this point we know the dns record will be kept
		# It can be updated, and may or may not be locked to the original ip address

		# If the dns name or the dns domain are set to empty values, error out
		if (   ( !defined($dns_ui) or $dns_ui eq '' )
			or ( !defined($dnsdom_ui) or $dnsdom_ui eq '-1' ) )
		{
			$stab->error_return(
				"DNS name or domain can't be empty. Use the delete button to remove a DNS record."
			);
		}

		# Validate the combination of ip, dns name and dns domain
		# Emtpy values are ok in there (although we don't actually want that for existing records - see above)
		validate_ip_dns_combo( $stab, $ip_ui, $dns_ui, $dnsdom_ui );

		# Has the netblock changed (ip update) and isn't the dns record locked to the original IP?
		my $new_netblock_id;
		if (   defined($netblock_id)
			&& $netblock_id != $configured_netblock_id
			&& $dnstoggle_ui ne 'lock' )
		{
			$new_netblock_id = $configured_netblock_id;

			# Need to reassign just the primary DNS record to new netblock
			my $q = qq{
				update	dns_record
				set		netblock_id = ?
				where	dns_record_id = ?
			};
			my $sth = $stab->prepare($q) || $stab->return_db_err;
			$sth->execute( $configured_netblock_id, $dns_record_id )
			  || $stab->return_db_err( $sth, $configured_netblock_id );
			$sth->finish;

			# The old netblock is not defined (new ip)
		} elsif ( !defined($netblock_id) ) {
			$new_netblock_id = $configured_netblock_id;

			# Other casess:
			# - the netblocks are not different (no ip change)
			# - the dns record is locked to the original ip
		} else {

			# Is the dns record locked? If yes, count it.
			if ( $dnstoggle_ui eq 'lock' ) { $$refnumlockeddns++; }
			$new_netblock_id = $netblock_id;
		}

		# Is this DNS locked to the original ip?

		# Does the DNS record need an update?
		# This applies to the toggle values 'update' and 'lock', so in fact anything that is not 'delete'
		my $type = 'A';
		$type = 'AAAA' if ( $stab->validate_ip($ip_ui) == 6 );

		my $new_dns = {
			DNS_RECORD_ID       => $dns_record_id,
			DNS_NAME            => $dns_ui,
			DNS_DOMAIN_ID       => $dnsdom_ui,
			DNS_TYPE            => $type,
			NETBLOCK_ID         => $new_netblock_id,
			SHOULD_GENERATE_PTR => $dnsptr_ui
		};

		my $diff = $stab->hash_table_diff( $dns_record, _dbx($new_dns) );
		if ( defined($diff) ) {
			$$refnumchanges += keys %$diff;
			$stab->run_update_from_hash( 'dns_record', 'dns_record_id',
				$dns_record_id, $diff );
		}

		# The IP has changed and DNS record is not locked to original IP
		# The IP has changed and DNS record is locked to original IP

	}    # Enf of loop on DNS records for the netblock

	# Check if we have to add a new DNS entry
	my $dns_new_ui;
	my $dnsdom_new_ui;
	my $dnsptr_new_ui;

	# Is it for an existing netblock?
	if ( defined($netblock_id) ) {
		$dns_new_ui = $stab->cgi_parse_param( 'DNS_NAME',
			$network_interface_id . '_' . $netblock_id . '_new' );
		$dnsdom_new_ui = $stab->cgi_parse_param( 'DNS_DOMAIN_ID',
			$network_interface_id . '_' . $netblock_id . '_new' );
		$dnsptr_new_ui = $stab->cgi_parse_param( 'DNS_PTR',
			$network_interface_id . '_' . $netblock_id );

		# The value of the DNS_PTR radio group is the id of the selected group member
		# There is on radio group per netblock and each group has N+1 member
		# where N is the number of DNS records. The extra member is the new dns record.
		if (  $dnsptr_new_ui eq 'DNS_PTR_'
			. $network_interface_id . '_'
			. $netblock_id
			. '_new' )
		{
			$dnsptr_new_ui = 'Y';
		} else {
			$dnsptr_new_ui = 'N';
		}

		# Or for a brand new netblock?
	} else {
		$dns_new_ui = $stab->cgi_parse_param( 'DNS_NAME',
			$network_interface_id . '_new_new' );
		$dnsdom_new_ui = $stab->cgi_parse_param( 'DNS_DOMAIN_ID',
			$network_interface_id . '_new_new' );
		$dnsptr_new_ui =
		  $stab->cgi_parse_param( 'DNS_PTR', $network_interface_id . '_new' );

		# For new netblocks, the ptr field is just a checkbox, not a radio
		$dnsptr_new_ui = $stab->mk_chk_yn($dnsptr_new_ui);
	}

	# Validate the combination of ip, dns name and dns domain
	validate_ip_dns_combo( $stab, $ip_ui, $dns_new_ui, $dnsdom_new_ui );

	if ($dns_new_ui) {
		$$refnumchanges++;
		my $type = 'A';
		$type = 'AAAA' if ( $stab->validate_ip($ip_ui) == 6 );
		$stab->add_dns_record(
			{
				dns_name            => $dns_new_ui,
				dns_domain_id       => $dnsdom_new_ui,
				dns_type            => $type,
				dns_class           => 'IN',
				netblock_id         => $configured_netblock_id,
				SHOULD_GENERATE_PTR => $dnsptr_new_ui,
			}
		);
	}

	$configured_netblock_id;
}

sub serial_abbr_to_field {
	my ($serparam) = @_;

	my ( $databits, $parity, $stopbits ) = split( '-', $serparam );
	$parity =~ tr/a-z/A-Z/;
	my %parmap = (
		'N' => 'none',
		'E' => 'even',
		'O' => 'odd',
		'M' => 'mark',
		'S' => 'space',
	);
	$parity = $parmap{$parity};
	( $databits, $parity, $stopbits );

}

sub update_power_ports {
	my ( $stab, $devid ) = @_;

	my $changes = 0;

	foreach my $piport ( $stab->cgi_get_ids('P1_POWER_INTERFACE_PORT') ) {
		$changes += update_power_port( $stab, $devid, $piport );
	}

	$changes;
}

sub update_power_port {
	my ( $stab, $devid, $piport ) = @_;

	my $numchanges = 0;

	my $otherdev = $stab->cgi_parse_param( 'P2_POWER_DEVICE_ID', $piport );
	my $otherport =
	  $stab->cgi_parse_param( 'P2_POWER_INTERFACE_PORT', $piport );

	#
	# if nothing specified, nothing to process...
	#
	if ( !$otherdev || !$otherport ) {
		my $q = qq{
			select  device_power_connection_id
			  from	device_power_connection
			 where	(device_id = ? and power_interface_port = ?)
			   OR	(rpc_device_id = ? and rpc_power_interface_port = ?)
		};
		my $sth = $stab->prepare($q) || die $stab->return_db_err($stab);

		my $q2 = qq{
			delete from device_power_connection
			 where	device_power_connection_id = ?
		};
		my $sth2 = $stab->prepare($q2) || $stab->return_db_err($stab);

		$sth->execute( $devid, $piport, $devid, $piport )
		  || $stab->return_db_err($sth);
		while ( my ($pc) = $sth->fetchrow_array ) {
			$sth2->execute($pc) || $stab->return_db_err($sth2);
			$numchanges++;
			$sth2->finish;
		}
		$sth->finish;
		return ($numchanges);
	}

	# my $cgi = $stab->cgi;
	# print $cgi->header, $cgi->start_html;
	# print "$devid $piport $otherdev $otherport\n";
	# print $cgi->Dump;
	# print $cgi->end_html;
	# exit;

	my $q = qq{
		SELECT port_utils.configure_power_connect(
			in_dev1_id := :dev1,
			in_port1_id := :port1,
			in_dev2_id := :dev2,
			in_port2_id := :port2
		);
	};

	my $tally = 0;
	my $sth   = $stab->prepare($q) || $stab->return_db_err($stab);

	$sth->bind_param( ':dev1',  $devid )     || $stab->return_db_err($stab);
	$sth->bind_param( ':port1', $piport )    || $stab->return_db_err($stab);
	$sth->bind_param( ':dev2',  $otherdev )  || $stab->return_db_err($stab);
	$sth->bind_param( ':port2', $otherport ) || $stab->return_db_err($stab);

	#- $numchanges += ( $sth->fetchrow_array) [ 0 ];
	# this function does not return anything.   it should.  XXX
	$numchanges += 1;

	$sth->execute || $stab->return_db_err($stab);
	$numchanges;
}

sub update_physical_ports {
	my ( $stab, $devid, $serial_reset ) = @_;

	my $numchanges = 0;

	#
	# this does not happen as part of update_physical_port because the port
	# generally changes when the layer1 connection data has been scrubbed.
	#
	my %pcports;
	foreach my $port ( $stab->cgi_get_ids('PhysPath') ) {
		$port =~ s/_row\d+$//;
		$pcports{$port}++;
	}
	foreach my $pportid ( keys %pcports ) {
		$numchanges += update_physical_connection( $stab, $pportid );
	}

	for my $pportid ( $stab->cgi_get_ids('P1_PHYSICAL_PORT_ID') ) {
		$numchanges += update_physical_port( $stab, $pportid, $serial_reset );
	}
	$numchanges;
}

sub update_physical_port {
	my ( $stab, $pportid, $serial_reset ) = @_;

	my $p2devid  = $stab->cgi_parse_param( 'P2_DEVICE_ID',        $pportid );
	my $p2portid = $stab->cgi_parse_param( 'P2_PHYSICAL_PORT_ID', $pportid );

	#
	# these are all set only on serial ports.
	#
	my $baud     = $stab->cgi_parse_param( 'BAUD',          $pportid );
	my $stopbits = $stab->cgi_parse_param( 'STOP_BITS',     $pportid );
	my $databits = $stab->cgi_parse_param( 'DATA_BITS',     $pportid );
	my $parity   = $stab->cgi_parse_param( 'PARITY',        $pportid );
	my $serparam = $stab->cgi_parse_param( 'SERIAL_PARAMS', $pportid );
	my $flow     = $stab->cgi_parse_param( 'FLOW_CONTROL',  $pportid );

	if ($serparam) {
		( $databits, $parity, $stopbits ) = serial_abbr_to_field($serparam);
		if (   !defined($databits)
			|| !defined($parity)
			|| !defined($stopbits) )
		{
			$stab->error_return("Invalid serial parameters");
		}
	}

	my $numchanges = 0;

	if ( !$p2devid ) {
		my $l1c = $stab->get_layer1_connection_from_port($pportid);
		return 0 if ( !$l1c );

		#
		# save the path before the layer 1 connection is destroyed
		my $path =
		  $stab->get_physical_path_from_l1conn(
			$l1c->{ _dbx('LAYER1_CONNECTION_ID') } );

		my $q = qq{
			delete from layer1_connection
			 where	layer1_connection_id = ?
		};
		my $sth = $stab->prepare($q) || $stab->return_db_err;
		$sth->execute( $l1c->{ _dbx('LAYER1_CONNECTION_ID') } )
		  || $stab->return_db_err($sth);
		$sth->finish;

		#
		# if there is a path, it should be destroyed.
		#
		if ($path) {
			purge_physical_connection_by_physical_port_id( $stab, $path );
		}
		return 1;
	}

	if ( !$p2portid ) {
		my $cgi = $stab->cgi;
		$stab->error_return(
			"You must specify the port on the other end's serial device.");
	}

	#
	# [XXX] get this for later cleanup
	#
	my $l1c = $stab->get_layer1_connection_from_port($pportid);
	my $path =
	  $stab->get_physical_path_from_l1conn(
		$l1c->{ _dbx('LAYER1_CONNECTION_ID') } );

	# XXX oracle/pgsqlism
	my $q = qq{
		SELECT port_utils.configure_layer1_connect(
			physportid1 := :physportid1,
			physportid2 := :physportid2,
			baud := :baud,
			data_bits := :data_bits,
			stop_bits := :stop_bits,
			parity := :parity,
			flw_cntrl := :flw_cntrl
		);
	};

	my $sth = $stab->prepare($q) || $stab->return_db_err;

	my $tally = 0;
	$sth->bind_param( ':physportid1', $pportid )
	  || $stab->return_db_err($sth);
	$sth->bind_param( ':physportid2', $p2portid )
	  || $stab->return_db_err($sth);
	$sth->bind_param( ':baud',      $baud ) || $stab->return_db_err($sth);
	$sth->bind_param( ':data_bits', $databits )
	  || $stab->return_db_err($sth);
	$sth->bind_param( ':stop_bits', $stopbits )
	  || $stab->return_db_err($sth);
	$sth->bind_param( ':parity',    $parity ) || $stab->return_db_err($sth);
	$sth->bind_param( ':flw_cntrl', $flow )   || $stab->return_db_err($sth);

	$sth->execute || $stab->return_db_err($sth);
	$numchanges += ( $sth->fetchrow_array )[0];
	$numchanges += $tally;

	#
	# check to see if the far end of the physical connection exists and
	# if so, check if the far other end's physical port matches, and if
	# not, update it.  This should probably purge in some circumstances.
	#
	if ($l1c) {
		$numchanges +=
		  attempt_path_cleanup( $stab, $l1c, $path, $pportid, $p2portid );
	}
	$numchanges;
}

#
# this looks at a layer 1 connection and attempts to make sure the two
# end points match.  This is kind of hackish and should possibly be in
# the db in the layer1_connection updating code.  [XXX]
#
sub attempt_path_cleanup {
	my ( $stab, $l1c, $path, $pportid, $p2portid ) = @_;

	my $numchanges = 0;

	return $numchanges if ( !$path );

	if ( $path->[0]->{ _dbx('PC_P1_PHYSICAL_PORT_ID') } == $pportid ) {
		if ( $path->[ $#{@$path} ]->{ _dbx('PC_P2_PHYSICAL_PORT_ID') } !=
			$p2portid )
		{
			my $q = qq{
				update	physical_connection
				   set	physical_port2_id = ?
				 where	physical_connection_id = ?
			};
			my $stab = $stab->prepare($q)
			  || $stab->return_db_err($stab);
			$stab->execute( $p2portid,
				$path->[ $#{@$path} ]->{ _dbx('PHYSICAL_CONNECTION_ID') },
			);
		}
	} elsif ( $path->[0]->{ _dbx('PC_P1_PHYSICAL_PORT_ID') } == $p2portid ) {
		if ( $path->[ $#{@$path} ]->{ _dbx('PC_P2_PHYSICAL_PORT_ID') } !=
			$pportid )
		{
			my $q = qq{
				update	physical_connection
				   set	physical_port2_id = ?
				 where	physical_connection_id = ?
			};
			my $stab = $stab->prepare($q)
			  || $stab->return_db_err($stab);
			$stab->execute( $pportid,
				$path->[ $#{@$path} ]->{ _dbx('PHYSICAL_CONNECTION_ID') } );
		}
	} elsif (
		$path->[ $#{@$path} ]->{ _dbx('PC_P2_PHYSICAL_PORT_ID') } == $pportid )
	{
		if ( $path->[0]->{ _dbx('PC_P1_PHYSICAL_PORT_ID') } != $p2portid ) {
			my $q = qq{
				update	physical_connection
				   set	physical_port1_id = ?
				 where	physical_connection_id = ?
			};
			my $stab = $stab->prepare($q)
			  || $stab->return_db_err($stab);
			$stab->execute( $p2portid,
				$path->[0]->{ _dbx('PHYSICAL_CONNECTION_ID') } );
		}
	} elsif (
		$path->[ $#{@$path} ]->{ _dbx('PC_P2_PHYSICAL_PORT_ID') } == $p2portid )
	{
		if ( $path->[0]->{ _dbx('PC_P1_PHYSICAL_PORT_ID') } != $pportid ) {
			my $q = qq{
				update	physical_connection
				   set	physical_port1_id = ?
				 where	physical_connection_id = ?
			};
			my $stab = $stab->prepare($q)
			  || $stab->return_db_err($stab);
			$stab->execute( $pportid,
				$path->[0]->{ _dbx('PHYSICAL_CONNECTION_ID') } );
		}
	} else {
		$numchanges +=
		  purge_physical_connection_by_physical_port_id( $stab, $path );
	}

	$numchanges;
}

sub update_physical_connection {
	my ( $stab, $pportid ) = @_;

	my $cgi = $stab->cgi;    # [XXX] comment out when debugging is done

	my $numchanges = 0;

	# elsewhere (later) a check is made to see if the other end of the
	# layer1 connection was removed, and if it was, then the path gets
	# removed there.  may also try to do it here, too?  probably makes
	# sense to do it here... [XXX]

	# figure out which end is ours, and if its backwards
	# walk the chain to figure out what needs to change, and update...

	#
	# if there is no layer1 connection id for this port yet, then there's no
	# reason to do port manipulations.  If the port is being removed, then
	# the physical connection should be completely removed.
	#
	my $l1c = $stab->get_layer1_connection_from_port($pportid);

	if ( !$l1c ) {
		return 0;
	}

	#
	# figure out the path to a given host.
	#
	my $path =
	  $stab->get_physical_path_from_l1conn(
		$l1c->{ _dbx('LAYER1_CONNECTION_ID') } );

	my (@newpath);
	my $backwards = 0;
	if ( $l1c->{ _dbx('PHYSICAL_PORT1_ID') } != $pportid ) {
		$backwards = 1;
	}

	#
	# obtain all the row data
	#
	my $short = "PhysPath_${pportid}";
	my @list  = sort {
		my ( $aa, $bb ) = ( $a, $b );
		$aa =~ s/^row//;
		$bb =~ s/^row//;
		$aa <=> $bb;
	} $stab->cgi_get_ids($short);

	for ( my $i = 0 ; $i <= $#list ; $i++ ) {
		my $rowname = $list[$i];
		my $magic   = $stab->cgi_parse_param("${short}_$rowname");
		my $side    = ($backwards) ? 1 : 2;
		my $devid   = $stab->cgi_parse_param( "PC_P${side}_DEVICE_ID", $magic );
		my $devnm = $stab->cgi_parse_param( "PC_P${side}_DEVICE_NAME", $magic );
		my $oport =
		  $stab->cgi_parse_param( "PC_P${side}_PHYSICAL_PORT_ID", $magic );
		my $rm    = $stab->cgi_parse_param( "rm_PC",      $magic );
		my $cable = $stab->cgi_parse_param( "CABLE_TYPE", $magic );

		# excluding these because it makes reordering them  in the backwards
		# case much easier
		my %stuff = (

			#reference => $rowname,
			#magic => $magic,
			#device_id => $devid,
			#device_name => $devnm,
			port  => $oport,
			cable => $cable,
			rm    => $rm
		);
		push( @newpath, \%stuff );

		if ( !$cable ) {
			$stab->error_return(
				"Must specify a cable type on Patch Panel Connections");
		}

		# the last one does not have a port end, just a cable...
		if ( !$oport && $i != $#list ) {
			$stab->error_return(
				"Must specify the other end of an undeleted leg in a Patch Panel Connection"
			);
		}

	}

	if ($backwards) {
		@newpath = reverse(@newpath);

		#
		# In this case, the ports get pulled back one
		# so the cable types line up.
		#
		for ( my $i = 0 ; $i < $#newpath ; $i++ ) {
			$newpath[$i]->{'port'} = $newpath[ $i + 1 ]->{'port'};
			$newpath[$i]->{'rm'}   = $newpath[ $i + 1 ]->{'rm'};
		}
		$newpath[$#newpath]->{'port'} = undef;
		$newpath[$#newpath]->{'rm'}   = undef;
	}

	#
	# at this point, newpath should contain:
	# physport2... from first in chain through the second to last.
	# the cable type for each item in the chain
	# and rm is set if the thing with physport2 set to port goes away.
	#
	# The last item just contains the cable type for connecting to the
	# final item (layer1 connection's pport2)
	#
	# the first item's pport1 is going to be layer1 connection's pport1
	#

	#
	# put in a check here to see if the path has not changed, if it
	# has not, then nothing furthur is done.  This allows people to view
	# the physical port connections without dropping them.   This closely
	# matches the code for adding a path, which has some screwiness because
	# of the border conditions.
	#
	if ($path) {
		my $needtofix = 0;
		my $lhspp     = $l1c->{ _dbx('PHYSICAL_PORT1_ID') };
		my $cabletype;
		for ( my $i = 0 ; $i <= $#newpath ; $i++ ) {
			my $rhspp = $newpath[$i]->{'port'};
			if ( $i == $#newpath ) {
				$rhspp = $l1c->{ _dbx('PHYSICAL_PORT2_ID') };
			}

			if ( $newpath[$i]->{'rm'} ) {
				$needtofix++;
			}

			if ( !exists( $path->[$i] ) ) {
				$needtofix++;
				next;
			}

			if ( $path->[$i]->{ _dbx('PC_P2_PHYSICAL_PORT_ID') } != $rhspp ) {
				$needtofix++;
			}

			if (
				$newpath[$i]->{'cable'} ne $path->[$i]->{ _dbx('CABLE_TYPE') } )
			{
				$needtofix++;
			}

		}
		if ( $needtofix == 0 ) {
			return 0;
		}
	}

	#
	# There is probably enough information in the above section to do a
	# smarter update and not to brute force (it may even be possible to do
	# it inline above).  Requires a little more thought and some sleep.
	#

	#
	# This is /completely/ brute force and really should be a matter of
	# manipulating existing physical_connection_ids, but it at least gets
	# this out the door.  If there's time, I'll get it break it out like
	# that, or I'll get it after the first revision goes out...
	#
	if ($path) {
		$numchanges +=
		  purge_physical_connection_by_physical_port_id( $stab, $path );
		$path = undef;
	}

	#
	# when the above is reconsidered, probably need to rethink this. [XXX]
	#
	# This goes through any components of the new physical path in the
	# db and removes it.  When this happens, it means that the new path
	# had something different than the old path.  (a patch panel was
	# reused).
	#
	for ( my $i = 0 ; $i <= $#newpath ; $i++ ) {
		my $pid      = $newpath[$i]->{'port'};
		my $endpoint = find_phys_con_endpoint_from_port( $stab, $pid );

		# lookup physical connections that include said things,
		# and remove the entire chain.  Note that the above purges
		# existing physical paths, so its possible that there won't
		# be anything.
		next if ( !$endpoint );
		my $tl1c = $stab->get_layer1_connection_from_port($endpoint);
		next if ( !$tl1c );
		my $tpath =
		  $stab->get_physical_path_from_l1conn(
			$tl1c->{ _dbx('LAYER1_CONNECTION_ID') } );
		next if ( !$tpath );
		$numchanges +=
		  purge_physical_connection_by_physical_port_id( $stab, $tpath );
	}

	#
	# there is no physical path, so just add it as is.  This is completely
	# screwy because of the border conditions.
	#
	if ( !$path ) {
		my $q = qq{
			insert into physical_connection
				(physical_port1_id, physical_port2_id, cable_type)
			values
				(?, ?, ?)
		};
		my $sth = $stab->prepare($q) || $stab->return_db_err($stab);

		my $lhspp = $l1c->{ _dbx('PHYSICAL_PORT1_ID') };
		my $cabletype;
		for ( my $i = 0 ; $i <= $#newpath ; $i++ ) {
			next if ( $newpath[$i]->{'rm'} );    # was deleted.
			$cabletype = $newpath[$i]->{'cable'};
			my $rhspp = $newpath[$i]->{'port'};
			if ( $i == $#newpath ) {
				$rhspp = $l1c->{ _dbx('PHYSICAL_PORT2_ID') };
			}

			# print $cgi->h3("
			$sth->execute( $lhspp, $rhspp, $cabletype )
			  || $stab->return_db_err($sth);

			# ");
			$numchanges++;

			$lhspp = $rhspp;
		}
	}

	# print $cgi->header, $cgi->start_html;
	# print "l1c is $l1c, backwards is $backwards\n";
	# print "old path: ", $cgi->pre(Dumper($path));
	# print "new path: ", $cgi->pre(Dumper(@newpath));
	# my $xpath = $stab->get_physical_path_from_l1conn($l1c->{_dbx('LAYER1_CONNECTION_ID')});
	# print "new SET path: ", $cgi->pre(Dumper($xpath));
	# print "layer 1 conn: ", $cgi->pre(Dumper($l1c));
	# print $cgi->Dump;
	# print $cgi->end_html;
	# $stab->rollback;
	# exit 0;

	#
	# NOTE:  need to check to see if port on the other end of the layer1
	# connection changed, in which case that will also need to be moved in
	# the physical connection.

	#
	# note that we don't have to do the above now because we just delete
	# and recreate the physical connection record.
	$numchanges;
}

sub purge_physical_connection_by_physical_port_id {
	my ( $stab, $path ) = @_;
	my $cgi = $stab->cgi;

	cluck "removing physical ports";

	my $numchanges = 0;

	my $q = qq{
		delete from physical_connection
		  where	physical_connection_id = ?
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($stab);

	foreach my $row (@$path) {
		$numchanges +=
		  $sth->execute( $row->{ _dbx('PHYSICAL_CONNECTION_ID') } );
	}

	$numchanges;
}

# This functions takes care of the referring dns records changes
sub update_all_dns_value_references {
	my ( $stab, $devid ) = @_;

	my $cgi = $stab->cgi;

	my $numchanges = 0;

	# This is actually copied from dns/update_dns.pl and should probably be
	# merged in somehow.  Just not doing it yet.

	# now process dns references.  Note that this used to be in the update loop
	# but because "same" dns records get cleared, records were not showing up,
	# so the assumption here is that the records are valid.
	foreach my $refname ( $stab->cgi_get_ids('dnsref_DNS_NAME_dnsref') ) {
		$refname =~ /^(\d+)_(.+$)/;
		my ( $recupdid, $refid ) = ( $1, $2 );

		if ( $refid =~ /^new/ ) {
			$numchanges += $stab->process_dns_ref_add( $recupdid, $refid );
		} else {
			$numchanges += $stab->process_dns_ref_updates( $recupdid, $refid );
		}
	}

	# copied from dns/update_dns.pl
	my $delsth;
	foreach my $delid ( $stab->cgi_get_ids('Del') ) {
		my $dns = $stab->get_dns_record_from_id($delid);
		if ( !defined($delsth) ) {
			my $q = qq{
                delete from dns_record
                 where  dns_record_id = ?
            };
			$delsth = $stab->prepare($q)
			  || $stab->return_db_err;
		}
		$delsth->execute($delid) || $stab->return_db_err($delsth);
		$cgi->delete("Del_$delid");
		$cgi->delete("DNS_RECORD_ID_$delid");
		$numchanges++;

		if (   $dns
			&& $dns->{ _dbx('DNS_TYPE') } =~ /^A(AAA)?$/
			&& $dns->{ _dbx('NETBLOCK_ID') } )
		{
			$numchanges += $stab->delete_netblock( $dns->{'netblock_id'}, 1 );
		}
	}
	return $numchanges;
}

# This function loops on all interfaces of a device to process them
sub update_all_interfaces {
	my ( $stab, $devid ) = @_;

	my $numchanges = 0;

	# Get the network interfaces from the database
	my $sth = $stab->prepare(
		qq{
		select	network_interface_id
		 from	network_interface
		where	device_id = ?
		order by network_interface_id
	}
	) || $stab->return_db_err;

	$sth->execute($devid) || $stab->return_db_err($sth);

	# Loop on network interfaces found in the database for the current device

	# TODO - if an ip is deleted / unlinked from an interface, this interface should be processed first
	# in order to be able - in the same transaction - to add it to another interface
	# The only way to do that is to first loop on all interfaces and netblocks and check the toggles status

	while ( my ($network_interface_id) = $sth->fetchrow_array ) {

		# Get the interface values from the UI
		my $p = $stab->cgi_parse_param( 'NETWORK_INTERFACE_ID',
			$network_interface_id );
		my $network_interface_toggle_ui =
		  $stab->cgi_parse_param( 'NETWORK_INTERFACE_TOGGLE',
			$network_interface_id );

		# Ignore the interface if it's only in the DB but not in the UI
		# This can happen if the submit button was pressed without the IP/Network tab loaded
		if ( !defined($p) ) { next; }

		# The interface will now be processed. That includes its netblocks and their dns records.
		# This is necessary even if the interface will be deleted
		$numchanges += update_interface( $stab, $devid, $network_interface_id );

		# Is the interface marked for deletion?
		if ( $network_interface_toggle_ui eq 'delete' ) {
			delete_interface( $stab, $network_interface_id );
			$numchanges++;
		}
	}

	$numchanges;
}

# This functions makes sure that the requested ip/dns/dns domain config is valid
sub validate_ip_dns_combo {
	my ( $stab, $ip, $dnsname, $dnsdomain ) = @_;

	# Make sure a dns value is not specified without ip
	if ( !defined($ip) && defined($dnsname) ) {
		$stab->error_return(
			"You must set an IP address with the DNS name $dnsname.");
	}

	# Don't allow a dns name without a domain
	if ( $dnsname && ( !$dnsdomain || $dnsdomain eq '-1' ) ) {
		$stab->error_return(
			"You must specify a domain for the DNS entry $dnsname.");
	}

	# And check if a dns domain is given without dns name
	if ( !defined($dnsname) && defined($dnsdomain) && $dnsdomain ne '-1' ) {
		$stab->error_return(
			"You must set a DNS name for each specified DNS domain.");
	}

	# Finally, we need to check if the dnsname doesn't contain an existing child domain
	# Like abc.ams1 with domain appnexus.net while ams1.appnexus.net exists

	# If the dns name has no dot, there is nothig to check
	if ( $dnsname !~ /\./ ) { return; }

	# Get a list of existing domains
	my $sth = $stab->prepare(
		qq{
			select		dns_domain_id, soa_name
			from		dns_domain
			order by	soa_name
		}
	);
	$sth->execute() || die $sth->errstr;
	my $domains_by_id = $sth->fetchall_hashref('dns_domain_id');
	my %domains_by_soa;
	foreach my $dns_domain_id ( keys %{$domains_by_id} ) {
		$domains_by_soa{ $domains_by_id->{$dns_domain_id}{'soa_name'} } =
		  $domains_by_id->{$dns_domain_id}{'dns_domain_id'};
	}

	# Get the dns name part after the last dot
	my @parts    = split /\./, $dnsname;
	my $lastpart = $parts[-1];

	# Get the dns domain corresponding to the id
	my $dnsdomainname = $domains_by_id->{$dnsdomain}{'soa_name'};
	if ( exists( $domains_by_soa{ $lastpart . '.' . $dnsdomainname } ) ) {
		$stab->error_return(
			"You can't use .$lastpart in the DNS name, you must use $lastpart.$dnsdomainname as the domain."
		);
	}
}

# This function makes sure that the specified mac address has a valid format
# TODO - It doesn't check its uniqueness in the database thouggh - do we want to do that?
sub validate_mac_address {
	my ( $stab, $macaddress ) = @_;
	if ( $macaddress eq '' ) { return; }
	if ( $macaddress !~ /^([0-9a-fA-F]{2}:){5}([0-9a-fA-F]){2}$/ ) {
		$stab->error_return(
			"The specified mac address '$macaddress' is not valid.");
	}
}

# This function processes an interface
sub update_interface {
	my ( $stab, $devid, $netintid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $numchanges = 0;

	# Read the network interface values from the UI
	# Note: most values will be empty if the toggle state is 'delete'
	# because the html input fields are disabled in this case
	my $intname = $stab->cgi_parse_param( 'NETWORK_INTERFACE_NAME', $netintid );
	my $nitype  = $stab->cgi_parse_param( 'NETWORK_INTERFACE_TYPE', $netintid );
	my $macaddr = $stab->cgi_parse_param( 'MAC_ADDR',               $netintid );
	my $desc =
	  $stab->cgi_parse_param( 'NETWORK_INTERFACE_DESCRIPTION', $netintid );
	my $network_interface_toggle_ui =
	  $stab->cgi_parse_param( 'NETWORK_INTERFACE_TOGGLE', $netintid );

	# Make sure checkboxes are reported as Y or N only
	my $isintup = $stab->mk_chk_yn(
		$stab->cgi_parse_param( 'chk_IS_INTERFACE_UP', $netintid ) );
	my $shldmng = $stab->mk_chk_yn(
		$stab->cgi_parse_param( 'chk_SHOULD_MANAGE', $netintid ) );
	my $shldmon = $stab->mk_chk_yn(
		$stab->cgi_parse_param( 'chk_SHOULD_MONITOR', $netintid ) );

	# Remove leading and trailing spaces from the interface name
	if ($intname) {
		$intname =~ s/^\s+//;
		$intname =~ s/\s+$//;
	}

	# Make sure the mac address has a correct format
	validate_mac_address( $stab, $macaddr );

	# Get the network interface details from the database
	my $network_interface_db = get_network_interface( $stab, $netintid );

	# Update the physical port name
	my $newppid = $network_interface_db->{ _dbx('PHYSICAL_PORT_ID') };
	if ( $network_interface_db->{ _dbx('NETWORK_INTERFACE_NAME') } ne $intname )
	{
		$newppid =
		  rename_physical_port( $stab,
			$network_interface_db->{ _dbx('PHYSICAL_PORT_ID') },
			$intname, $devid );
		$numchanges++;
	}

	# Let's get the associated netblocks from the database
	my $sth = $stab->prepare(
		qq{
		select		netblock.netblock_id
		from		network_interface
		left join	network_interface_netblock using( network_interface_id )
		left join	netblock using (netblock_id)
		where		network_interface.device_id = ?
		and			network_interface.network_interface_id = ?
		order by	netblock.netblock_id
	}
	) || $stab->return_db_err;

	$sth->execute( $devid, $netintid ) || $stab->return_db_err($sth);

	# Loop on existing netblocks in the database
	while ( my ($netblock_id) = $sth->fetchrow_array ) {

		# The query above has left joins, so ignore null netblock ids, if any
		if ( !$netblock_id ) { next; }

		# Read the current netblock values from the UI
		my $netblock_toggle_ui = $stab->cgi_parse_param( 'NETBLOCK_TOGGLE',
			$netintid . '_' . $netblock_id );
		my $ip_ui =
		  $stab->cgi_parse_param( 'IP', $netintid . '_' . $netblock_id );

		# Validate the ip address
		if ( !defined($ip_ui) && $netblock_toggle_ui ne 'delete' ) {
			$stab->error_return(
				"Empty IP address fields are not supported. To delete an IP address, use the red cross button in front ot it."
			);
		}
		if ( defined($ip_ui) && !$stab->validate_ip($ip_ui) ) {
			$stab->error_return("$ip_ui is an invalid IP address");
		}

		# If the netblock is not marked for deletion (so, update or unlink), process it
		if ( $netblock_toggle_ui ne 'delete' ) {
			$numchanges += process_interface_netblock( $stab, $devid, $netintid,
				$netblock_id, $ip_ui );
		}

		# Is the netblock marked to be disassociated from the network interface?
		if ( $netblock_toggle_ui eq 'unlink' ) {

			my @qs = (
				qq{
					update	netblock
					set		netblock_status = 'Reserved'
					where	netblock_id = ?
				},
				qq{
					delete from	network_interface_netblock
					where		netblock_id = ?
				},
			);

			foreach my $q (@qs) {
				my $sth = $stab->prepare($q) || $stab->return_db_err;
				$sth->execute($netblock_id)
				  || $stab->return_db_err($sth);
			}

			$numchanges++;

			# The netblock is flagged for removal and the ip address will be deleted, not disassociated
		} elsif ( $netblock_toggle_ui eq 'delete' ) {

			# First delete the DNS records starting with their referring records
			my @qs = (
				qq{
 					delete from	dns_record
					where		dns_value_record_id in (
						select	dns_record_id
						from	dns_record
						where	netblock_id = ?
					)
				},
				qq{
					delete from	dns_record
					where		netblock_id = ?
				},
			);
			foreach my $q (@qs) {
				my $sth = $stab->prepare($q) || $stab->return_db_err;
				$sth->execute($netblock_id);
			}

			# Then delete the netblock itself
			delete_old_netblock( $stab, $netblock_id );

			$numchanges++;
		}
	}    # End of loop on netblocks

	# Check if we need to add a new netblock to the interface
	my $new_ip  = $stab->cgi_parse_param( 'IP',       $netintid . '_new' );
	my $new_dns = $stab->cgi_parse_param( 'DNS_NAME', $netintid . '_new_new' );
	my $new_dnsdom =
	  $stab->cgi_parse_param( 'DNS_DOMAIN_ID', $netintid . '_new_new' );

	# If no new ip is provided, but the dns name or domain is set, error out
	if (
		!defined($new_ip)
		and ( defined($new_dns)
			or ( defined($new_dnsdom) and $new_dnsdom ne '-1' ) )
	  )
	{
		$stab->error_return(
			"DNS information can't be supplied without a valid IP address.");
	}

	# Validate the combination of ip, dns name and dns domain
	# Emtpy values are ok
	validate_ip_dns_combo( $stab, $new_ip, $new_dns, $new_dnsdom );

	# Process the netblock if the new ip address is defined
	if ( defined($new_ip) ) {

		# Validate the ip address
		if ( !$stab->validate_ip($new_ip) ) {
			$stab->error_return("$new_ip is an invalid IP address");
		}
		$numchanges +=
		  process_interface_netblock( $stab, $devid, $netintid, undef,
			$new_ip );
	}

	# If the network interface is marked for deletion, we're done
	if ( $network_interface_toggle_ui eq 'delete' ) {
		return $numchanges;
	}

	# Update the network interface
	my $new_int = {
		NETWORK_INTERFACE_ID =>
		  $network_interface_db->{ _dbx('NETWORK_INTERFACE_ID') },
		NETWORK_INTERFACE_NAME => $intname,
		NETWORK_INTERFACE_TYPE => $nitype,
		IS_INTERFACE_UP        => $isintup,
		MAC_ADDR               => $macaddr,
		SHOULD_MONITOR         => $shldmon,
		SHOULD_MANAGE          => $shldmng,
		DESCRIPTION            => $desc,
	};

	my $diff = $stab->hash_table_diff( $network_interface_db, _dbx($new_int) );
	$numchanges += keys %$diff;
	$stab->run_update_from_hash( 'network_interface', 'network_interface_id',
		$network_interface_db->{ _dbx('NETWORK_INTERFACE_ID') }, $diff );

	$numchanges +=
	  manipulate_network_interface_purpose( $stab, $netintid, $devid );

	$numchanges;
}

# Process the update of one netblock of a network interface, including its dns records
sub process_interface_netblock {

	my ( $stab, $devid, $network_interface_id, $netblock_id, $ip_ui ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $numchanges   = 0;
	my $numlockeddns = 0;

	# properly deal with keeping IP address around
	my $configured_netblock_id;
	$configured_netblock_id =
	  process_netblock_and_dns( $stab, $network_interface_id, $netblock_id,
		$ip_ui, \$numlockeddns, \$numchanges );

	# The ip address is changing
	if ( defined($netblock_id) && $netblock_id != $configured_netblock_id ) {

		my $old_nb = {
			NETWORK_INTERFACE_ID => $network_interface_id,
			NETBLOCK_ID          => $netblock_id,
		};

		my $new_nb = {
			NETWORK_INTERFACE_ID => $network_interface_id,
			NETBLOCK_ID          => $configured_netblock_id,
		};

		my $diffnb = $stab->hash_table_diff( $old_nb, $new_nb );
		$numchanges += keys %$diffnb;
		$stab->run_update_from_hash( 'network_interface_netblock',
			'netblock_id', $netblock_id, $diffnb );
		$numchanges++;

		# Delete the old netblock, but only if no DNS is locked to the original IP
		if ( $numlockeddns == 0 ) {
			delete_old_netblock( $stab, $netblock_id );
			$numchanges++;
		}

		# A new ip address is being added?
	} elsif ( !defined($netblock_id) ) {

		# We need to get a free interface rank first
		my $iFreeRank =
		  find_free_network_interface_rank( $stab, $network_interface_id );

		my $new = {
			NETWORK_INTERFACE_ID   => $network_interface_id,
			NETBLOCK_ID            => $configured_netblock_id,
			NETWORK_INTERFACE_RANK => $iFreeRank,
		};

		my @errs;

		if (
			!(
				$numchanges += $stab->DBInsert(
					table  => 'network_interface_netblock',
					hash   => $new,
					errors => \@errs
				)
			)
		  )
		{
			$stab->error_return( join( " ", @errs ) );
		}

		$numchanges++;
	}

	$numchanges;
}

sub find_free_network_interface_rank {

	my ( $stab, $network_interface_id ) = @_;

	my $query_get_rank = qq{
		select		network_interface_rank
		from		network_interface_netblock
		where		network_interface_id = ?
		order by	network_interface_rank
	};
	my $sth_get_rank = $stab->prepare($query_get_rank)
	  || die $stab->return_db_err;
	$sth_get_rank->execute($network_interface_id)
	  || die $stab->return_db_err($sth_get_rank);
	my $ranks = $sth_get_rank->fetchall_arrayref( [0] );
	$sth_get_rank->finish;

	# Map the ranks array to a hash for easier processing
	my %hRanks;
	foreach my $row ( @{$ranks} ) {
		$hRanks{ @{$row}[0] } = 1;
	}

	my $iFreeRank = -1;
	my $iTestRank = 0;
	while ( $iTestRank < 1000 ) {
		if ( exists( $hRanks{$iTestRank} ) ) {
			$iTestRank++;
			next;
		}
		$iFreeRank = $iTestRank;
		last;
	}

	# Safety check: if we couldn't find a free rank before reaching 1000, there is a problem
	if ( $iTestRank == 1000 ) {
		$stab->error_return(
			"Couldn't find a free network interface rank for interface $network_interface_id"
		);
	}

	$iFreeRank;
}

# This function seems to delete all purposes and recreate them.
# TODO - Is that really necessary??
sub manipulate_network_interface_purpose {
	my ( $stab, $netintid, $devid, $new ) = @_;

	my $cgi = $stab->cgi || die "Could not create cgi";

	my $ui_field_id = ( defined($new) ) ? $new : $netintid;
	my @newpurp =
	  $cgi->multi_param( 'NETWORK_INTERFACE_PURPOSE_' . $ui_field_id );

	my $oldpurp = $stab->get_network_int_purpose($netintid);

	my $rmsth = $stab->prepare(
		qq{
		delete from network_interface_purpose
		where	network_interface_id = ?
		and		network_interface_purpose = ?
	}
	) || return $stab->return_db_err;

	my $addsth = $stab->prepare(
		qq{
		INSERT INTO network_interface_purpose (
			device_id, network_interface_id, network_interface_purpose
		) VALUES (
			?, ?, ?
		);
	}
	) || return $stab->return_db_err;

	my $numchanges = 0;
	foreach my $purp ( @{$oldpurp} ) {
		if ( !grep( $_ eq $purp, @newpurp ) ) {
			$numchanges += $rmsth->execute( $netintid, $purp )
			  || return $stab->return_db_err();
		}
	}

	foreach my $purp (@newpurp) {
		if ( !grep( $_ eq $purp, @${oldpurp} ) ) {
			my $result = $addsth->execute( $devid, $netintid, $purp );
			if( ! $result ) {
				if( $addsth->errstr =~ /violates unique constraint.*pk_network_int_purpose/ ) {
					$stab->error_return( "ERROR: The purpose '$purp' can't be added to multiple interfaces." );
				} else {
					return $stab->return_db_err();
				}
			}
			$numchanges += $result;
		}
	}
	$numchanges;
}

sub rename_physical_port {
	my ( $stab, $id, $newname, $devid ) = @_;

	my $newpp = $stab->get_physical_port_byport( $devid, $newname, 'network' );
	if ($newpp) {
		return $newpp->{ _dbx('PHYSICAL_PORT_ID') };
	}

	my $q = qq{
		update	physical_port
 		   set	port_name = ?
		 where	physical_port_id = ?
	};

	my $sth = $stab->prepare($q) || $stab->return_db_err;
	$sth->execute( $newname, $id ) || $stab->return_db_err($sth);
	$sth->finish;
}

sub add_device_note {
	my ( $stab, $devid ) = @_;

	my $cgi = $stab->cgi;

	my $text = $stab->cgi_parse_param("DEVICE_NOTE_TEXT_$devid");

	my $user = $cgi->remote_user || "--unknown--";

	return 0 if ( !$text );

	my $q = qq{
		insert into device_note (
			device_id, note_text, note_date, note_user
		) values (
			?, ?, now(), upper(?)
		)
	};

	my $sth = $stab->prepare($q) || $stab->return_db_err;
	$sth->execute( $devid, $text, $user ) || $stab->return_db_err($sth);
	1;
}

########################################################################
sub process_licenses {
	my ( $stab, $devid ) = @_;

	my $cgi        = $stab->cgi;
	my $numchanges = 0;

	my @existingdc =
	  $stab->get_device_collections_for_device( $devid, 'applicense' );

	for my $dcid ( $stab->cgi_get_ids('rm_Lic_DEVICE_COLLECTION') ) {

		# my $checked	= $stab->cgi_parse_param("rm_Lic_DEVICE_COLLECTION", $dcid);
		if ( $dcid !~ /^\d+$/ || !grep( $dcid == $_, @existingdc ) ) {

			# $stab->error_return("Device Collection ($dcid) is not assigned to this node.");
			next;
		}
		my $dc = $stab->get_device_collection($dcid);
		if ( $dc->{ _dbx('DEVICE_COLLECTION_TYPE') } ne 'applicense' ) {
			$stab->error_return("Invalid attempt to remove a non-license");
		}
		$numchanges +=
		  $stab->remove_from_device_collection( $devid, $dcid, 'applicense' );
	}

	for my $offset ( $stab->cgi_get_ids("add_license_$devid") ) {
		my $dcid = $stab->cgi_parse_param( "add_license_$devid", $offset );
		if ( $dcid !~ /^\d+$/ || grep( $dcid == $_, @existingdc ) ) {

			# $stab->error_return("Device Collection ($dcid) is already assigned to this node.");
			next;
		}
		my $dc = $stab->get_device_collection($dcid);
		if ( $dc->{ _dbx('DEVICE_COLLECTION_TYPE') } ne 'applicense' ) {
			$stab->error_return("Invalid attempt to remove a non-license");
		}
		$numchanges += $stab->add_to_device_collection( $devid, $dcid );
	}

	$numchanges;
}

sub process_interfaces {
	my ( $stab, $devid ) = @_;

	my $cgi        = $stab->cgi;
	my $numchanges = 0;

	#- print $cgi->header, $cgi->html($cgi->Dump()); exit;

	my $x = "";

	# see if we should delete any
	my (@gone);
	for my $srtid ( $stab->cgi_get_ids('chk_RM_STATIC_ROUTE_ID') ) {
		push( @gone, $srtid );
		$numchanges += $stab->rm_static_route_from_device($srtid);
	}

	for my $srtid ( $stab->cgi_get_ids('chk_ADD_STATIC_ROUTE_TEMPLATE_ID') ) {
		$numchanges += $stab->add_static_route_from_template( $devid, $srtid );
	}

	#
	# process updates
	#
	foreach my $id ( $stab->cgi_get_ids('STATIC_ROUTE_ID') ) {
		next if ( grep( $_ eq $id, @gone ) );
		my $srcip   = $stab->cgi_parse_param( 'ROUTE_SRC_IP',      $id );
		my $srcbits = $stab->cgi_parse_param( 'ROUTE_SRC_MASKLEN', $id );
		my $destip  = $stab->cgi_parse_param( 'ROUTE_DEST_IP',     $id );

		if ( $srcip && $srcip =~ /^default$/i ) {
			$srcip   = '0.0.0.0';
			$srcbits = 0 if ( !$srcbits );
		}

		# exits with an error if it does not validate
		my ( $ni, $nb ) =
		  $stab->validate_route_entry( $srcip, $srcbits, $destip );

		if ( !$nb && !$ni ) {
			$stab->error_return(
				"Unable to look up existing entry for $srcip->$srcbits $destip update"
			);
		}

		my $gSth = $stab->prepare(
			qq{
			select * from static_route where static_route_id = ?
		}
		);
		$gSth->execute($id) || $stab->return_db_err($gSth);
		my $dbsr = $gSth->fetchrow_hashref;
		$gSth->finish;

		$stab->error_return("Unable to find $id") if ( !$dbsr );

		if ( $ni->{ _dbx('NETWORK_INTERFACE_ID') } !=
			$dbsr->{ _dbx('NETWORK_INTERFACE_DST_ID') } )
		{
			if ( !$stab->check_ip_on_local_nets( $devid, $destip ) ) {
				$stab->error_return(
					"$destip for static route is not reachable from an interface on this device."
				);
			}
			if (
				$stab->is_static_route_on_device(
					$devid,
					$ni->{ _dbx('NETWORK_INTERFACE_ID') },
					$nb->{ _dbx('NETBLOCK_ID') }
				)
			  )
			{
				$stab->error_return(
					"Static Route $srcip/$srcbits->$destip is already on device"
				);
			}
		}

		my $newsr = {
			STATIC_ROUTE_ID          => $id,
			DEVICE_SRC_ID            => $devid,
			NETWORK_INTERFACE_DST_ID => $ni->{ _dbx('NETWORK_INTERFACE_ID') },
			NETBLOCK_ID              => $nb->{ _dbx('NETBLOCK_ID') },
		};

		my $diffs = $stab->hash_table_diff( $dbsr, _dbx($newsr) );

		my $tally   += keys %$diffs;
		$numchanges += $tally;

		if (
			$tally
			&& !$stab->run_update_from_hash(
				'STATIC_ROUTE', 'STATIC_ROUTE_ID', $id, $diffs
			)
		  )
		{
			$stab->rollback;
			$stab->error_return("Unknown Error With Update");
		}
	}

	#
	# Add new
	#
	my $srcip   = $stab->cgi_parse_param('ROUTE_SRC_IP');
	my $srcbits = $stab->cgi_parse_param('ROUTE_SRC_MASKLEN');
	my $destip  = $stab->cgi_parse_param('ROUTE_DEST_IP');

	if ( $srcip && $srcip =~ /^default$/i ) {
		$srcip   = '0.0.0.0';
		$srcbits = 0 if ( !$srcbits );
	}

	# exits with an error if it does not validate
	my ( $ni, $nb ) = $stab->validate_route_entry( $srcip, $srcbits, $destip );

	if ( $nb && $ni ) {
		if ( !$stab->check_ip_on_local_nets( $devid, $destip ) ) {
			$stab->error_return(
				"$destip for static route is not reachable from an interface on this device."
			);
		}

		if (
			$stab->is_static_route_on_device(
				$devid,
				$ni->{ _dbx('NETWORK_INTERFACE_ID') },
				$nb->{ _dbx('NETBLOCK_ID') }
			)
		  )
		{
			$stab->error_return(
				"Static Route $srcip/$srcbits->$destip is already on device");
		}

		my $sth = $stab->prepare(
			qq{
			insert into static_route
				(DEVICE_SRC_ID, NETWORK_INTERFACE_DST_ID, NETBLOCK_ID)
			values
				(?, ?, ?)
		}
		);

		$numchanges += $sth->execute(
			$devid,
			$ni->{ _dbx('NETWORK_INTERFACE_ID') },
			$nb->{ _dbx('NETBLOCK_ID') }
		) || $stab->return_db_err($sth);
	}

	$numchanges;
}

########################################################################

sub add_interfaces {
	my ( $stab, $devid ) = @_;

	my $cgi = $stab->cgi;

	my $netintid = $stab->cgi_parse_param('NETWORK_INTERFACE_ID');
	my $intname  = $stab->cgi_parse_param('NETWORK_INTERFACE_NAME');
	my $nitype   = $stab->cgi_parse_param('NETWORK_INTERFACE_TYPE');
	my $macaddr  = $stab->cgi_parse_param('MAC_ADDR');

	my $ip        = $stab->cgi_parse_param('IP_new_new');
	my $dns       = $stab->cgi_parse_param('DNS_NAME_new_new_new');
	my $dnsdom_ui = $stab->cgi_parse_param('DNS_DOMAIN_ID_new_new_new');
	my $dnsptr_ui = $stab->cgi_parse_param('DNS_PTR_new_new');

	my $isintup  = $stab->cgi_parse_param('chk_IS_INTERFACE_UP');
	my $ismgmtip = $stab->cgi_parse_param('chk_IS_MANAGEMENT_INTERFACE');
	my $ispriint = $stab->cgi_parse_param('chk_IS_PRIMARY');
	my $shldmng  = $stab->cgi_parse_param('chk_SHOULD_MANAGE');
	my $shldmon  = $stab->cgi_parse_param('chk_SHOULD_MONITOR');

	my $desc = $stab->cgi_parse_param('NETWORK_INTERFACE_DESCRIPTION_new');

	if ($intname) {
		$intname =~ s/^\s+//;
		$intname =~ s/\s+$//;
	}
	if ($dns) {
		$dns =~ s/^\s+//;
		$dns =~ s/\s+$//;
	}
	if ($ip) {
		$ip =~ s/^\s+//;
		$ip =~ s/\s+$//;
		if ( !$stab->validate_ip($ip) ) {
			$stab->error_return("$ip is an invalid IP address");
		}
	}

	$isintup   = $stab->mk_chk_yn($isintup);
	$ismgmtip  = $stab->mk_chk_yn($ismgmtip);
	$ispriint  = $stab->mk_chk_yn($ispriint);
	$shldmng   = $stab->mk_chk_yn($shldmng);
	$shldmon   = $stab->mk_chk_yn($shldmon);
	$dnsptr_ui = $stab->mk_chk_yn($dnsptr_ui);

	# Check if some parameter was supplied without an acutal interface name
	if ( !defined($intname) ) {
		if ( defined($nitype) ) {
			$stab->error_return(
				"An interface type can't be speicified without an interface name."
			);
		}
		if ( defined($macaddr) ) {
			$stab->error_return(
				"A MAC address can't be speicified without an interface name.");
		}
		if ( defined($ip) ) {
			$stab->error_return(
				"An IP address can't be speicified without an interface name.");
		}
		if ( defined($dns) or ( defined($dnsdom_ui) and $dnsdom_ui ne '-1' ) ) {
			$stab->error_return(
				"DNS information can't be speicified without an interface name."
			);
		}

		# Without a new interface name, there is nothing to do
		return 0;
	}

	my $device = $stab->get_dev_from_devid($devid);

	if ( !defined($device) ) {
		$stab->error_return("You have specified an invalid device.");
	}

	if ( !defined($nitype) || $nitype eq 'unknown' ) {
		$stab->error_return("You must set an interface type");
	}

	if ( !defined($ip)
		and ( defined($dns) or ( defined($dnsdom_ui) and $dnsdom_ui ne '-1' ) )
	  )
	{
		$stab->error_return(
			"DNS information can't be specified without an IP address.");
	}

	# Check if a dns name is given but no dns domain
	if ( defined($dns) and ( !defined($dnsdom_ui) or $dnsdom_ui eq '-1' ) ) {
		$stab->error_return("You must set a DNS domain with a DNS name");
	}

	# Check if a dns domain is given but no dns name
	if ( !defined($dns) and defined($dnsdom_ui) and $dnsdom_ui ne '-1' ) {
		$stab->error_return("You must set a DNS name with a DNS domain");
	}

	my $nblk;
	if ( defined($ip) ) {
		$nblk = $stab->get_netblock_from_ip(
			ip_address        => $ip,
			is_single_address => 'Y',
			netblock_type     => 'default'
		);
		my $xblk = $stab->configure_allocated_netblock( $ip, $nblk );
		$nblk = $xblk;
	}

	#
	# figure out if other interfaces share these properties, and turn them
	# off if so.  (need to notify users).
	#
	my $oldpris  = 0;
	my $oldmgmts = 0;
	if ( $ispriint eq 'Y' ) {
		$oldpris = switch_all_ni_prop_to_n( $stab, $devid, 'IS_PRIMARY' );
	}
	if ( $ismgmtip eq 'Y' ) {
		$oldmgmts =
		  switch_all_ni_prop_to_n( $stab, $devid, 'IS_MANAGEMENT_INTERFACE' );
	}

	#
	# Do not create physical ports.  If there is not a matching one, then
	# assume its virtual
	#
	my $ppid;
	my $pp = $stab->get_physical_port_byport( $devid, $intname, 'network' );
	if ($pp) {
		$ppid = $pp->{ _dbx('PHYSICAL_PORT_ID') };
	}

	# Make sure the mac address has a correct format
	validate_mac_address( $stab, $macaddr );

	my $new = {
		device_id              => $devid,
		network_interface_name => $intname,
		network_interface_type => $nitype,
		IS_INTERFACE_UP        => $isintup,
		MAC_ADDR               => $macaddr,
		physical_port_id       => $ppid,
		should_manage          => $shldmng,
		should_monitor         => $shldmon,
		DESCRIPTION            => $desc,
	};

	my $numchanges = 0;
	my @errs;

	if (
		!(
			$numchanges += $stab->DBInsert(
				table  => 'network_interface',
				hash   => $new,
				errors => \@errs
			)
		)
	  )
	{
		$stab->error_return( join( " ", @errs ) );
	}

	$netintid = $new->{ _dbx('NETWORK_INTERFACE_ID') };

	if ( defined($ip) ) {
		my $new2 = {
			network_interface_id => $netintid,
			netblock_id          => $nblk->{ _dbx('NETBLOCK_ID') },
			device_id            => $devid
		};

		if (
			!(
				$numchanges += $stab->DBInsert(
					table  => 'network_interface_netblock',
					hash   => $new2,
					errors => \@errs
				)
			)
		  )
		{
			$stab->error_return( join( " ", @errs ) );
		}
	}

	if ( defined($dns) && defined($dnsdom_ui) ) {
		my $type = 'A';
		$type = 'AAAA' if ( $stab->validate_ip($ip) == 6 );
		$stab->add_dns_record(
			{
				dns_name            => $dns,
				dns_domain_id       => $dnsdom_ui,
				dns_type            => $type,
				dns_class           => 'IN',
				netblock_id         => $nblk->{ _dbx('NETBLOCK_ID') },
				SHOULD_GENERATE_PTR => $dnsptr_ui,
			}
		);
		$numchanges++;
	}

	# Update purposes
	$numchanges +=
	  manipulate_network_interface_purpose( $stab, $netintid, $devid, 'new' );

	#
	# [XXX] - adjust DNS to match rules if primary/mgmt were set to y,
	# including adjusting non-primaries approppriately.
	#
	$numchanges;
}

sub update_functions {
	my ( $stab, $devid ) = @_;

	my $cgi        = $stab->cgi;
	my $numchanges = 0;

	# Get selected device functions from the UI
	my @new_device_functions = $cgi->multi_param( 'DEVICE_FUNCTIONS' );
	# Return 0 change if the Functions tab wasn't loaded
	if( ! @new_device_functions ) { return( 0 ) };

	# Get device functions from the database
	my %functions = %{$stab->get_device_functions( $devid )};
	my @old_device_functions;
	push( @old_device_functions, $functions{$_}{'device_collection_id'} ) for grep { $functions{$_}{'selected'} == 1 } keys %functions;

	# Get a list of function ids to remove
	my @to_delete;
	foreach ( @old_device_functions ) {
		push( @to_delete, $_ ) unless exists( $new_device_functions[$_] );
	}

	# Get a list of function ids to add
	my @to_add;
	foreach ( @new_device_functions ) {
		push( @to_add, $_ ) unless exists( $old_device_functions[$_] );
	}

	#print $cgi->header;
	#print $cgi->html($cgi->Dump());
	#print "old: ".Dumper( @old_device_functions );
	#print "new: ".Dumper( @new_device_functions );
	#print "del: ".Dumper( @to_delete );
	#print "add: ".Dumper( @to_add );

	# Build the values list for the delete statement below
	my $values_to_delete = join(',',@to_delete);

	# Build the values list for the insert statement below
	my $valuepairs_to_add;
	$valuepairs_to_add .= "($devid,$_)," for @to_add;
	chop( $valuepairs_to_add );
	#print "pairs: ".Dumper( $valuepairs_to_add );
	# exit;

	# Delete functions

	my $q = qq {
		delete from
			device_collection_device
		where
			device_id = ? and
			device_collection_id in ($values_to_delete)
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($stab);
	$sth->execute($devid) || $stab->return_db_err($stab);
	$sth->finish;

	# Add functions

	$q = qq {
		insert into
			device_collection_device
			( device_id, device_collection_id )
		values
			$valuepairs_to_add
	};
	$sth = $stab->prepare($q) || $stab->return_db_err($stab);
	$sth->execute || $stab->return_db_err($stab);
	$sth->finish;

	# Return the number of changes
	@to_add + @to_delete;
}

sub switch_all_ni_prop_to_n {
	my ( $stab, $devid, $field ) = @_;

	my $old_count = 0;
	if ($field) {
		my $q = qq{
			select	count(*)
			  from	network_interface
			 where	device_id = ?
			  and	$field = 'Y'
		};
		my $sth = $stab->prepare($q) || $stab->return_db_err;
		$sth->execute($devid) || $stab->return_db_err($sth);
		($old_count) = $sth->fetchrow_array;
	}

	if ($old_count) {
		my $q = qq{
			update network_interface
			  set  $field = 'N'
			where  device_id = ?
		};
		my $sth = $stab->prepare($q) || $stab->return_db_err;
		$sth->execute($devid) || $stab->return_db_err($sth);
	}
	$old_count;
}

sub reset_serial_to_default {
	my ( $stab, $devid ) = @_;

	delete_device_connections( $stab, $devid, 'serial' );
	delete_device_phys_ports( $stab, $devid, 'serial' );
}

sub find_phys_con_endpoint_from_port {
	my ( $stab, $pportid ) = @_;

	my $sth = $stab->prepare(
		qq{
		select * from v_physical_connection
		where layer1_physical_port1_id = ?
	}
	) || $stab->return_db_err($stab);

	my $endpoint;
	$sth->execute($pportid) || $stab->return_db_err($stab);

	while ( my $hr = $sth->fetchrow_hashref ) {
		if ( $hr->{ _dbx('PHYSICAL_PORT1_ID') } != $pportid ) {
			$endpoint = $hr->{ _dbx('PHYSICAL_PORT1_ID') };
		}
		if ( $hr->{ _dbx('PHYSICAL_PORT2_ID') } != $pportid ) {
			$endpoint = $hr->{ _dbx('PHYSICAL_PORT2_ID') };
		}
	}
	$sth->finish;
	$endpoint;
}

sub delete_device_connections {
	my ( $stab, $devid, $limit ) = @_;

	my $ports = $stab->get_physical_ports_for_dev( $devid, $limit );

	my $q1 = qq{
		delete from layer1_connection where physical_port1_id = ?
			or physical_port2_id = ?
	};
	my $sth1 = $stab->prepare($q1) || $stab->return_db_err;

	foreach my $portid (@$ports) {
		my $l1c = $stab->get_layer1_connection_from_port($portid);
		if ($l1c) {
			my $path =
			  $stab->get_physical_path_from_l1conn(
				$l1c->{ _dbx('LAYER1_CONNECTION_ID') } );
			if ($path) {
				purge_physical_connection_by_physical_port_id( $stab, $path );
			}
		}
		$sth1->execute( $portid, $portid )
		  || $stab->return_db_err($sth1);
	}

	$sth1->finish;
	1;
}

sub delete_device_phys_ports {
	my ( $stab, $devid, $limit ) = @_;

	my $ports = $stab->get_physical_ports_for_dev( $devid, $limit );

	my $q2 = qq{
		delete from physical_port where physical_port_id = ?
	};
	my $sth2 = $stab->prepare($q2) || $stab->return_db_err;

	foreach my $portid (@$ports) {
		$sth2->execute($portid) || $stab->return_db_err($sth2);
	}

	$sth2->finish;
	1;
}

sub delete_device_power {
	my ( $stab, $devid ) = @_;

	{
		my $q = qq {
			delete	from device_power_connection
			 where	( device_id = :devid and
						power_interface_port in
						(select power_interface_port
						   from	device_power_interface
						  where	device_id = :devid
						)
					)
			 OR		( rpc_device_id = :devid and
					rpc_power_interface_port in
						(select power_interface_port
						   from	device_power_interface
						  where	device_id = :devid
						)
					)
		};
		my $sth = $stab->prepare($q) || $stab->return_db_err($stab);
		$sth->bind_param( ":devid", $devid )
		  || $stab->return_db_err($stab);
		$sth->execute || $stab->return_db_err($stab);
		$sth->finish;
	}

	{
		my $q = qq {
			delete	from device_power_interface
			 where	device_id = ?
		};
		my $sth = $stab->prepare($q) || $stab->return_db_err($stab);
		$sth->execute($devid) || $stab->return_db_err($stab);
		$sth->finish;
	}
}

sub retire_device {
	my ( $stab, $devid ) = @_;

	my $sth = $stab->prepare(
		qq{
		SELECT	device_utils.retire_device(
				in_device_id := ?
			);
	}
	) || die $stab->return_db_err($stab);

	$sth->execute($devid) || $stab->return_db_err($sth);
	my ($stillhere) = ( $sth->fetchrow_array );
	$sth->finish;

	my ( $url, $msg );
	if ( !$stillhere ) {
		$url = "../";
		$msg = "Device Removed";
	} else {
		$url = "../device.pl?devid=$devid";
		$msg = "Device Retired";
	}

	$stab->commit || $stab->error_return;
	$stab->msg_return( $msg, $url, 1 );
}

########################### end 'o deletion ##################################
