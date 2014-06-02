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
		my $p2devid =
		  $stab->cgi_parse_param( 'P2_DEVICE_ID', $pportid );
		my $p2portid =
		  $stab->cgi_parse_param( 'P2_PHYSICAL_PORT_ID', $pportid );
		my $baud     = $stab->cgi_parse_param( 'BAUD',      $pportid );
		my $stopbits = $stab->cgi_parse_param( 'STOP_BITS', $pportid );
		my $databits = $stab->cgi_parse_param( 'DATA_BITS', $pportid );
		my $parity   = $stab->cgi_parse_param( 'PARITY',    $pportid );
		my $serparam =
		  $stab->cgi_parse_param( 'SERIAL_PARAMS', $pportid );
		my $flow = $stab->cgi_parse_param( 'FLOW_CONTROL', $pportid );

		if ($serparam) {
			( $databits, $parity, $stopbits ) =
			  serial_abbr_to_field($serparam);
			next if ( !$databits || !$parity || !$stopbits );
		}

		my $l1c = $stab->get_layer1_connection_from_port($pportid);

		next if ( !$l1c && $p2portid );

		if ($l1c) {
			if (       defined( $l1c->{ _dbx('BAUD') } )
				&& defined($baud) )
			{
				next if ( $l1c->{ _dbx('BAUD') } ne $baud );
			} elsif (  !defined( $l1c->{ _dbx('BAUD') } )
				&& !defined($baud) )
			{
				;
			} else {
				next;
			}
			if (       defined( $l1c->{ _dbx('STOP_BITS') } )
				&& defined($stopbits) )
			{
				next
				  if ( $l1c->{ _dbx('STOP_BITS') } ne
					$stopbits );
			} elsif (  !defined( $l1c->{ _dbx('STOP_BITS') } )
				&& !defined($stopbits) )
			{
				;
			} else {
				next;
			}
			if (       defined( $l1c->{ _dbx('DATA_BITS') } )
				&& defined($databits) )
			{
				next
				  if ( $l1c->{ _dbx('DATA_BITS') } ne
					$databits );
			} elsif (  !defined( $l1c->{ _dbx('DATA_BITS') } )
				&& !defined($databits) )
			{
				;
			} else {
				next;
			}
			if (       defined( $l1c->{ _dbx('PARITY') } )
				&& defined($parity) )
			{
				next if ( $l1c->{ _dbx('PARITY') } ne $parity );
			} elsif (  !defined( $l1c->{ _dbx('PARITY') } )
				&& !defined($parity) )
			{
				;
			} else {
				next;
			}
			if (       defined( $l1c->{ _dbx('FLOW_CONTROL') } )
				&& defined($flow) )
			{
				next
				  if ( $l1c->{ _dbx('FLOW_CONTROL') } ne
					$flow );
			} elsif (  !defined( $l1c->{ _dbx('FLOW_CONTROL') } )
				&& !defined($flow) )
			{
				;
			} else {
				next;
			}

			if ( $l1c->{ _dbx('PHYSICAL_PORT1_ID') } == $pportid ) {
				next
				  if (
					!$p2portid && defined(
						$l1c->{ _dbx('PHYSICAL_PORT2_ID'
						) }
					)
					|| $l1c->{ _dbx('PHYSICAL_PORT2_ID') }
					!= $p2portid
				  );
			}
			if ( $l1c->{ _dbx('PHYSICAL_PORT2_ID') } == $pportid ) {
				next
				  if (
					!$p2portid && defined(
						$l1c->{ _dxb('PHYSICAL_PORT1_ID'
						) }
					)
					|| $l1c->{ _dbx('PHYSICAL_PORT1_ID') }
					!= $p2portid
				  );
			}
		}

		$cgi->delete( "P1_PHYSICAL_PORT_ID__" . $pportid );  # umm, wtf?
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
	my $site      = $stab->cgi_parse_param( 'SITE_CODE', $devid );
	my $status    = $stab->cgi_parse_param( 'DEVICE_STATUS', $devid );
	my $owner     = $stab->cgi_parse_param( 'OWNERSHIP_STATUS', $devid );
	my $svcenv    = $stab->cgi_parse_param( 'SERVICE_ENVIRONMENT', $devid );
	my $assettag  = $stab->cgi_parse_param( 'ASSET_TAG', $devid );
	my $osid      = $stab->cgi_parse_param( 'OPERATING_SYSTEM_ID', $devid );
	my $voeid     = $stab->cgi_parse_param( 'VOE_ID', $devid );
	my $ismonitored = $stab->cgi_parse_param( 'chk_IS_MONITORED', $devid );
	my $baselined   = $stab->cgi_parse_param( 'chk_IS_BASELINED', $devid );
	my $parentid    = $stab->cgi_parse_param( 'PARENT_DEVICE_ID', $devid );
	my $localmgd =
	  $stab->cgi_parse_param( 'chk_IS_LOCALLY_MANAGED', $devid );
	my $cfgfetch =
	  $stab->cgi_parse_param( 'chk_SHOULD_FETCH_CONFIG', $devid );
	my $virtdev = $stab->cgi_parse_param( 'chk_IS_VIRTUAL_DEVICE', $devid );
	my $mgmtprot = $stab->cgi_parse_param( 'AUTO_MGMT_PROTOCOL', $devid );
	my $voetrax = $stab->cgi_parse_param( 'VOE_SYMBOLIC_TRACK_ID', $devid );
	my $appgtab = $stab->cgi_parse_param( 'has_appgroup_tab',      $devid );
	my @appgroup = $stab->cgi_parse_param( 'appgroup', $devid );

       #-print $cgi->header, $cgi->start_html, $cgi->Dump, $cgi->end_html; exit;
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

	my $resyncpower = $stab->cgi_parse_param( 'power_port_resync', $devid );
	my $resyncserial =
	  $stab->cgi_parse_param( 'serial_port_resync', $devid );
	my $resyncswitch =
	  $stab->cgi_parse_param( 'switch_port_resync', $devid );

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
		$stab->error_return(
			"You must actually specify a device to update.");
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
		if (       $existingdev
			&& $existingdev->{ _dbx('DEVICE_ID') } != $devid )
		{
			$stab->error_return(
				"A device by that name already exists.");
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
	$numchanges += add_device_note( $stab, $devid );

	if ( $serial_reset && $retire_device ) {
		$stab->error_return(
"You may not both reset serial ports and retire the box."
		);
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

	my $newdevice = {
		DEVICE_ID      => $devid,
		DEVICE_NAME    => $devname,
		DEVICE_TYPE_ID => $devtypeid,
		SERIAL_NUMBER  => $serialno,
		PART_NUMBER    => $partno,
		PHYSICAL_LABEL => $physlabel,

		#- DEVICE_STATUS		=> $status,
		OWNERSHIP_STATUS    => $owner,
		SERVICE_ENVIRONMENT => $svcenv,
		ASSET_TAG           => $assettag,

		#- OPERATING_SYSTEM_ID	=> $osid,
		#- VOE_ID			=> $voeid,
		IS_MONITORED        => $ismonitored,
		IS_LOCALLY_MANAGED  => $localmgd,
		SHOULD_FETCH_CONFIG => $cfgfetch,
		IS_VIRTUAL_DEVICE   => $virtdev,
		AUTO_MGMT_PROTOCOL  => $mgmtprot,

		#- VOE_SYMBOLIC_TRACK_ID	=> $voetrax,
		SITE_CODE => $site,
	};

	#
	# This can not be set on pages where there are virtual devices
	# and thus would clear the field if it was blindly passed in.
	if ( $dbdevice->{ _dbx('IS_VIRTUAL_DEVICE') } eq 'N' ) {
		$newdevice->{'PARENT_DEVICE_ID'} = $parentid;
	}

	my $diffs = $stab->hash_table_diff( $dbdevice, _dbx($newdevice) );

	if (       $serialno
		&& $dbdevice->{ _dbx('SERIAL_NUMBER') }
		&& $dbdevice->{ _dbx('SERIAL_NUMBER') } ne $serialno )
	{
		my $sernodev = $stab->get_dev_from_serial($serialno);
		if (       $sernodev
			&& $serialno ne 'Not-Applicable'
			&& $serialno !~ m,^n/a$,i )
		{
			undef $sernodev;
			$stab->error_return("That serial number is in use.");
		}
		undef $sernodev;
	}

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
		$stab->msg_return("Nothing changed.  No updates submitted.");
		exit;
	}
	if (
		$tally
		&& !$stab->run_update_from_hash(
			"DEVICE", "DEVICE_ID", $devid, $diffs
		)
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
		$numchanges +=
		  $sth->execute( $devid, $dcid ) || $stab->return_db_err($sth);
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
		$numchanges +=
		  $sth->execute( $devid, $dcid ) || $stab->return_db_err($sth);
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

	my $locid = $stab->cgi_get_ids('LOCATION_ID');

	my $numchanges = 0;
	my $rackid = $stab->cgi_parse_param( 'LOCATION_RACK_ID', $locid );
	if ( !$rackid ) {
		return $numchanges;
	}

	my $ru   = $stab->cgi_parse_param( 'LOCATION_RU_OFFSET', $locid );
	my $side = $stab->cgi_parse_param( 'LOCATION_RACK_SIDE', $locid );
	my $interoff =
	  $stab->cgi_parse_param( 'LOCATION_INTER_DEV_OFFSET', $locid );

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
			$stab->error_return(
				'Location does not match Value set on Device');
		}
		$curloc = undef;
	}

	$interoff = 0 if ( !$interoff );

	if ( !defined($ru) || $ru !~ /^-?\d+$/ ) {
		$stab->error_return('U Offset must be a number.');
	}
	if ( $interoff !~ /^\d+$/ ) {
		$stab->error_return('inter device offset must be a number.');
	}

	my %newloc = (
		LOCATION_ID                 => $locid,
		RACK_ID                     => $rackid,
		RACK_U_OFFSET_OF_DEVICE_TOP => $ru,
		RACK_SIDE                   => $side,
		INTER_DEVICE_OFFSET         => $interoff,
	);
	my $newloc = \%newloc;

	#
	# no location previously existed, lets set a new one!
	#
	if ( !$curloc || !defined( $curloc->{ _dbx('LOCATION_ID') } ) ) {
		return $stab->add_location_to_dev( $devid, $newloc );
	}

	my $diffs = $stab->hash_table_diff( $curloc, _dbx($newloc) );
	my $tally   += keys %$diffs;
	$numchanges += $tally;

	if (
		$tally
		&& !$stab->run_update_from_hash(
			"LOCATION", "LOCATION_ID", $locid, $diffs
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
	my ( $stab, $oldblock ) = @_;

	return undef unless ( defined($oldblock) );

	my $q = qq{
		delete	from netblock
		 where	netblock_id = ?
	};
	my $sth = $stab->prepare($q) || die $stab->return_db_err;
	$sth->execute( $oldblock->{ _dbx('NETBLOCK_ID') } )
	  || die $stab->return_db_err($sth);

}

sub configure_nb_if_ok {
	my ( $stab, $oldblock, $ip ) = @_;

	my $newblock = $stab->get_netblock_from_ip(
		ip_address        => $ip,
		is_single_address => 'Y',
		netblock_type     => 'default',
	);

	#
	# if netblocks aren't changing, then its ok.
	#
	if ( defined($oldblock) && defined($newblock) ) {
		if ( $oldblock->{ _dbx('NETBLOCK_ID') } ==
			$newblock->{ _dbx('NETBLOCK_ID') } )
		{
			return $oldblock;
		} else {
			return $stab->error_return("$ip is in use.");
		}
	}

	$newblock = $stab->configure_allocated_netblock( $ip, $newblock );
	$newblock;
}

sub get_dns_record_from_netblock_id {
	my ( $stab, $id ) = @_;

	return undef unless ( defined($id) );

	my $q = qq{
		select *
		 from	dns_record
		where	netblock_id = ?
 	     and	should_generate_ptr = 'Y'
	};
	my $sth = $stab->prepare($q) || die $stab->return_db_err;
	$sth->execute($id) || die $stab->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
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

sub get_network_interface {
	my ( $stab, $id ) = @_;

	my $q = qq{
		select *
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

sub delete_interface {
	my ( $stab, $netintid, $ipdisposition ) = @_;

	if ( my $tally = number_interface_kids( $stab, $netintid ) ) {
		$stab->error_return(
"You can not remove parent interfaces when they still have child interfaces. ($netintid, # $tally)"
		);
	}

	my $nbq = qq{
		select	ni.netblock_id,
			ni.physical_port_id,
			ni.device_id,
			nb.description,
			dns.dns_record_id,
			dns.dns_name,
			dom.soa_name
		  from	network_interface ni
			inner join netblock nb on
				ni.netblock_id = nb.netblock_id
			left join dns_record dns on
				dns.netblock_id = ni.netblock_id
			left join dns_domain dom on
				dom.dns_domain_id = dns.dns_domain_id
		 where	ni.network_interface_id = ?
	};
	my $nbsth = $stab->prepare($nbq) || $stab->return_db_err;
	$nbsth->execute($netintid) || $stab->return_db_err($nbsth);
	my (
		$nblkid, $ppid,  $ispri,  $ismgt, $devid,
		$nbdesc, $dnsid, $dnsnam, $domain
	) = $nbsth->fetchrow_array;
	$nbsth->finish;

	if ($netintid) {
		my $q = qq{
			delete	from network_interface
			  where	network_interface_id = ?
		};
		my $sth = $stab->prepare($q) || $stab->return_db_err;
		$sth->execute($netintid)
		  || $stab->return_db_err( $sth, "netintid: $netintid" );
	}

	if ( !$nblkid ) {
		$stab->commit || $stab->error_return;
		return 1;
	}

	local_delete_netblock( $stab, $nblkid, $nbdesc, $ipdisposition );

	$stab->commit || $stab->error_return;
	1;
}

sub local_delete_netblock {
	my ( $stab, $nblkid, $nbdesc, $ipdisposition ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $dnsinfo = get_dnsids( $stab, $nblkid );

	my $oldname;
	while ( my $dnsid = shift(@$dnsinfo) ) {
		last if ( !defined($dnsid) );
		my $name = shift(@$dnsinfo);
		my $q    = qq{
			delete	from dns_record
		 	 where	dns_record_id = ?
		};
		my $sth = $stab->prepare($q) || $stab->return_db_err;
		$sth->execute($dnsid) || $stab->return_db_err( $sth, $dnsid );

		$oldname = $name if ( !defined($oldname) );
	}
	$oldname = "not in dns" if ( !defined($oldname) );
	if ( !defined($ipdisposition) || $ipdisposition eq 'reserve' ) {
		my $setclause = "";
		if ( !defined($nbdesc) ) {
			$setclause = ", description = :descr";
			$nbdesc    = "was $oldname";
		}
		my $q = qq{
			update netblock
				set netblock_status = 'Reserved'
				$setclause
			  where	netblock_id = :nblkid
		};
		my $sth = $stab->prepare($q) || $stab->return_db_err;
		$sth->bind_param( ':nblkid', $nblkid )
		  || $stab->return_db_err($sth);
		if ( length($setclause) ) {
			$sth->bind_param( ':descr', $nbdesc )
			  || $stab->return_db_err($sth);
		}
		$sth->execute || $stab->return_db_err($sth);
	} elsif ( $ipdisposition eq 'free' ) {
		my $q = qq{
			delete	from netblock
			  where	netblock_id = ?
		};
		my $sth = $stab->prepare($q) || $stab->return_db_err;
		$sth->execute($nblkid) || $stab->return_db_err($sth);
	} else {
		$stab->rollback;
		$stab->error_return(
			"Delete Failed.  Unknown IP Address Disposition");
	}
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

sub process_ip {
	my ( $stab, $oldblock, $ip, $dns, $dnsdomid ) = @_;

	my $oldnbid;

	if ( defined($oldblock) ) {
		$oldnbid = $oldblock->{ _dbx('NETBLOCK_ID') };
	}

	my $numchanges = 0;

	#
	# go make the netblock exist if  it is not already in use (and changed)
	#
	my $nblk = configure_nb_if_ok( $stab, $oldblock, $ip );

	if ( !$nblk ) {
		$stab->error_return("Internal Error Processing IP address.");
	}

	if (
		( !defined($oldblock) && defined($nblk) )
		|| ( $oldblock->{ _dbx('NETBLOCK_ID') } !=
			$nblk->{ _dbx('NETBLOCK_ID') } )
	  )
	{
		$numchanges++;
	}

	if ( !defined($nblk) ) {
		$stab->error_return( "Could not configure IP address "
			  . ( defined($ip) ? $ip : "--unset--" )
			  . "Seek help." );
	}

	my $dnsrec;
	if ( defined($oldnbid) ) {
		$dnsrec = get_dns_record_from_netblock_id( $stab, $oldnbid );
	}

       #
       # This happens when there is no dns domain passed in from the form, such
       # as when it was not edited.  In that case, we just use the existing one.
	if ( !$dnsdomid && ref $dnsrec ) {
		$dnsdomid = $dnsrec->{ _dbx('DNS_DOMAIN_ID') };
		$dns      = $dnsrec->{ _dbx('DNS_NAME') };
	}

	if ( defined($dnsrec) && $dnsdomid ) {
		my $type = 'A';
		$type = 'AAAA' if ( $stab->validate_ip($ip) == 6 );
		my $new_dns = {
			DNS_NAME      => $dns,
			DNS_DOMAIN_ID => $dnsdomid,
			DNS_TYPE      => $type,
			NETBLOCK_ID   => $nblk->{ _dbx('NETBLOCK_ID') }
		};
		my $diff = $stab->hash_table_diff( $dnsrec, _dbx($new_dns) );
		if ( defined($diff) ) {
			$numchanges += keys %$diff;
			$stab->run_update_from_hash( 'dns_record',
				'dns_record_id',
				$dnsrec->{ _dbx('DNS_RECORD_ID') }, $diff );
		}
	} elsif ( defined($dns) && defined($dnsdomid) ) {
		$numchanges++;
		my $type = 'A';
		$type = 'AAAA' if ( $stab->validate_ip($ip) == 6 );
		$stab->add_dns_record(
			{
				dns_name      => $dns,
				dns_domain_id => $dnsdomid,
				dns_type      => $type,
				dns_class     => 'IN',
				netblock_id   => $nblk->{ _dbx('NETBLOCK_ID') },
			}
		);
	}

	if ( $numchanges == 0 ) {
		return undef;
	}
	$nblk;
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
	my $sth = $stab->prepare($q) || $stab->return_db_err($stab);

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
		$numchanges +=
		  update_physical_port( $stab, $pportid, $serial_reset );
	}
	$numchanges;
}

sub update_physical_port {
	my ( $stab, $pportid, $serial_reset ) = @_;

	my $p2devid = $stab->cgi_parse_param( 'P2_DEVICE_ID', $pportid );
	my $p2portid =
	  $stab->cgi_parse_param( 'P2_PHYSICAL_PORT_ID', $pportid );

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
		( $databits, $parity, $stopbits ) =
		  serial_abbr_to_field($serparam);
		if (       !defined($databits)
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
			purge_physical_connection_by_physical_port_id( $stab,
				$path );
		}
		return 1;
	}

	if ( !$p2portid ) {
		my $cgi = $stab->cgi;
		$stab->error_return(
"You must specify the port on the other end's serial device."
		);
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
	$sth->bind_param( ':baud', $baud ) || $stab->return_db_err($sth);
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
		  attempt_path_cleanup( $stab, $l1c, $path, $pportid,
			$p2portid );
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
		if ( $path->[ $#{@$path} ]
			->{ _dbx('PC_P2_PHYSICAL_PORT_ID') } != $p2portid )
		{
			my $q = qq{
				update	physical_connection
				   set	physical_port2_id = ?
				 where	physical_connection_id = ?
			};
			my $stab =
			  $stab->prepare($q) || $stab->return_db_err($stab);
			$stab->execute(
				$p2portid,
				$path->[ $#{@$path} ]
				  ->{ _dbx('PHYSICAL_CONNECTION_ID') },
			);
		}
	} elsif ( $path->[0]->{ _dbx('PC_P1_PHYSICAL_PORT_ID') } == $p2portid )
	{
		if ( $path->[ $#{@$path} ]
			->{ _dbx('PC_P2_PHYSICAL_PORT_ID') } != $pportid )
		{
			my $q = qq{
				update	physical_connection
				   set	physical_port2_id = ?
				 where	physical_connection_id = ?
			};
			my $stab =
			  $stab->prepare($q) || $stab->return_db_err($stab);
			$stab->execute( $pportid,
				$path->[ $#{@$path} ]
				  ->{ _dbx('PHYSICAL_CONNECTION_ID') } );
		}
	} elsif ( $path->[ $#{@$path} ]->{ _dbx('PC_P2_PHYSICAL_PORT_ID') } ==
		$pportid )
	{
		if ( $path->[0]->{ _dbx('PC_P1_PHYSICAL_PORT_ID') } !=
			$p2portid )
		{
			my $q = qq{
				update	physical_connection
				   set	physical_port1_id = ?
				 where	physical_connection_id = ?
			};
			my $stab =
			  $stab->prepare($q) || $stab->return_db_err($stab);
			$stab->execute( $p2portid,
				$path->[0]->{ _dbx('PHYSICAL_CONNECTION_ID') }
			);
		}
	} elsif ( $path->[ $#{@$path} ]->{ _dbx('PC_P2_PHYSICAL_PORT_ID') } ==
		$p2portid )
	{
		if ( $path->[0]->{ _dbx('PC_P1_PHYSICAL_PORT_ID') } !=
			$pportid )
		{
			my $q = qq{
				update	physical_connection
				   set	physical_port1_id = ?
				 where	physical_connection_id = ?
			};
			my $stab =
			  $stab->prepare($q) || $stab->return_db_err($stab);
			$stab->execute( $pportid,
				$path->[0]->{ _dbx('PHYSICAL_CONNECTION_ID') }
			);
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
		my $devid =
		  $stab->cgi_parse_param( "PC_P${side}_DEVICE_ID", $magic );
		my $devnm =
		  $stab->cgi_parse_param( "PC_P${side}_DEVICE_NAME", $magic );
		my $oport =
		  $stab->cgi_parse_param( "PC_P${side}_PHYSICAL_PORT_ID",
			$magic );
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
"Must specify a cable type on Patch Panel Connections"
			);
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

			if ( $path->[$i]->{ _dbx('PC_P2_PHYSICAL_PORT_ID') }
				!= $rhspp )
			{
				$needtofix++;
			}

			if ( $newpath[$i]->{'cable'} ne
				$path->[$i]->{ _dbx('CABLE_TYPE') } )
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
		my $pid = $newpath[$i]->{'port'};
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
		  purge_physical_connection_by_physical_port_id( $stab,
			$tpath );
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

sub update_all_interfaces {
	my ( $stab, $devid ) = @_;

	my $numchanges = 0;

	# These need to be processed in the correct order  (children first,
	# then parents) so as not to order out.

	# XXX HOWEVER -- right now, there are no parent/child relationships.
	# So, yay.
	my $sth = $stab->prepare(
		qq{
		select	network_interface_id
		 from	network_interface
		where	device_id = ?
		order by network_interface_id
	}
	) || $stab->return_db_err;

	#
	# process updates, then deletions.  That way child interfaces can be
	# moved to non-virtual interfaces, then parent interfaces moved in the
	# same transaction.
	#

	my (@rmids);
	$sth->execute($devid) || $stab->return_db_err($sth);
	while ( my ($netintid) = $sth->fetchrow_array ) {
		my $p =
		  $stab->cgi_parse_param( 'NETWORK_INTERFACE_ID', $netintid );

		if ($p) {    # also look at chk_RM_NET_INT_PRESERVEIPS
			my $rmint =
			  $stab->cgi_parse_param( 'chk_RM_NETWORK_INTERFACE',
				$netintid );
			if ( !defined($rmint) ) {
				$numchanges +=
				  update_interface( $stab, $devid, $netintid );
			} else {
				push( @rmids, $netintid );
			}
		}
	}

	# also look at chk_RM_NET_INT_PRESERVEIPS
	# process all the deletions
	foreach my $netintid (@rmids) {
		my $delit =
		  $stab->cgi_parse_param( 'chk_RM_NETWORK_INTERFACE',
			$netintid );
		my $preserveip =
		  $stab->cgi_parse_param( 'chk_RM_NET_INT_PRESERVEIPS',
			$netintid );

		if ($delit) {
			if ( defined($preserveip) ) {
				delete_interface( $stab, $netintid, 'reserve' );
			} else {
				delete_interface( $stab, $netintid, 'free' );
			}
			$numchanges++;
		}
	}

	$numchanges;
}

sub update_interface {
	my ( $stab, $devid, $netintid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $intname =
	  $stab->cgi_parse_param( 'NETWORK_INTERFACE_NAME', $netintid );
	my $macaddr  = $stab->cgi_parse_param( 'MAC_ADDR',      $netintid );
	my $dns      = $stab->cgi_parse_param( 'DNS_NAME',      $netintid );
	my $dnsdomid = $stab->cgi_parse_param( 'DNS_DOMAIN_ID', $netintid );
	my $desc     = $stab->cgi_parse_param( 'DESCRIPTION',   $netintid );
	my $ip       = $stab->cgi_parse_param( 'IP',            $netintid );
	my $nitype =
	  $stab->cgi_parse_param( 'NETWORK_INTERFACE_TYPE', $netintid );
	my $isintup =
	  $stab->cgi_parse_param( 'chk_IS_INTERFACE_UP', $netintid );
	my $isnatint = $stab->cgi_parse_param( 'chk_PROVIDES_NAT',  $netintid );
	my $shldmng  = $stab->cgi_parse_param( 'chk_SHOULD_MANAGE', $netintid );
	my $shldmon = $stab->cgi_parse_param( 'chk_SHOULD_MONITOR', $netintid );
	my $dhcp    = $stab->cgi_parse_param( 'chk_PROVIDES_DHCP',  $netintid );

	$isintup  = $stab->mk_chk_yn($isintup);
	$shldmng  = $stab->mk_chk_yn($shldmng);
	$shldmon  = $stab->mk_chk_yn($shldmon);
	$isnatint = $stab->mk_chk_yn($isnatint);
	$dhcp     = $stab->mk_chk_yn($dhcp);

	if ($intname) {
		$intname =~ s/^\s+//;
		$intname =~ s/\s+$//;
	}
	if ($dns) {
		$dns =~ s/^\s+//;
		$dns =~ s/\s+$//;

		# remove trailing dots since they would just result in
		# double dots in final zone generation
		$dns =~ s/\.+$//;
	}

	if ( $ip && !$stab->validate_ip($ip) ) {
		$stab->error_return("$ip is an invalid IP address");
	}

	if ( $dns && !$dnsdomid ) {
		$stab->error_return(
			"You must specify a domain when adding a dns entry.");
	}

	my $numchanges = 0;

	#
	# sanity check the mac address (convert to an integer).
	#
	my $procdmac = undef;
	if ( defined($macaddr) ) {

		# $procdmac = $stab->int_mac_from_text($macaddr);
		$procdmac = $macaddr;
		if ( !defined($procdmac) ) {
			$stab->error_return( "Unable to parse mac address "
				  . ( ( defined($macaddr) ) ? $macaddr : "" ) );
		}
	}

	#
	# ok, at this point, it's time to update
	#
	my $old_int = get_network_interface( $stab, $netintid );

	#
	# first deal with the netblock, including grabbing old dns info
	#
	my $oldblock =
	  $stab->get_netblock_from_id( $old_int->{ _dbx('NETBLOCK_ID') } );

	#
	# properly deal with keeping IP address around
	#
	my ( $nblk, $nblkid );
	if ($ip) {
		$nblk = process_ip( $stab, $oldblock, $ip, $dns, $dnsdomid );

		if ( defined($nblk) ) {
			$numchanges++;
		} else {
			$nblk = $oldblock;
		}
		$nblkid = $nblk->{ _dbx('NETBLOCK_ID') };
	} else {
		#
		# in this case, the IP was removed, which means it should
		# be disassociated with the interface and removed.  At
		#
		if ($oldblock) {
			$numchanges++;
			my $q = qq{
				update netblock
					set netblock_status = 'Reserved'
				  where	netblock_id = ?
			};
			my $sth = $stab->prepare($q) || $stab->return_db_err;
			$sth->execute( $oldblock->{ _dbx('NETBLOCK_ID') } );
		}
		$nblkid = undef;
	}

	#
	# doing this earlier in case the physical port exists already
	#
	my $newppid = $old_int->{ _dbx('PHYSICAL_PORT_ID') };
	if ( $old_int->{ _dbx('NETWORK_INTERFACE_NAME') } ne $intname ) {
		$newppid =
		  rename_physical_port( $stab,
			$old_int->{ _dbx('PHYSICAL_PORT_ID') },
			$intname, $devid );
		$numchanges++;
	}

	#
	# if there was a parent interface, and its switching from virtual to
	# something else, then delete the parent/child relationship
	#
	my $newparent = $old_int->{ _dbx('PARENT_NETWORK_INTERFACE_ID') };
	if (       $old_int->{ _dbx('NETWORK_INTERFACE_TYPE') } ne $nitype
		&& $nitype ne 'virtual' )
	{
		if ($newparent) {
			$newparent = undef;
		}
	}

	#
	# now go and update the netblock itself.
	#
	my $new_int = {
		NETWORK_INTERFACE_ID =>
		  $old_int->{ _dbx('NETWORK_INTERFACE_ID') },
		NETWORK_INTERFACE_NAME => $intname,
		NETWORK_INTERFACE_TYPE => $nitype,
		IS_INTERFACE_UP        => $isintup,
		MAC_ADDR               => $procdmac,
		SHOULD_MONITOR         => $shldmon,
		PROVIDES_NAT           => $isnatint,
		NETBLOCK_ID            => $nblkid,
		SHOULD_MANAGE          => $shldmng,
		PROVIDES_DHCP          => $dhcp,
		DESCRIPTION            => $desc,

		#- PHYSICAL_PORT_ID => $newppid,
		#- PARENT_NETWORK_INTERFACE_ID => $newparent,
	};

	my (@notes);

	my $diff = $stab->hash_table_diff( $old_int, _dbx($new_int) );
	$numchanges += keys %$diff;
	$stab->run_update_from_hash( 'network_interface',
		'network_interface_id',
		$old_int->{ _dbx('NETWORK_INTERFACE_ID') }, $diff );

	#
	# now delete the old netblock if required.
	#
	if ( defined($oldblock) && defined($nblk) ) {
		if ( $oldblock->{ _dbx('NETBLOCK_ID') } !=
			$nblk->{ _dbx('NETBLOCK_ID') } )
		{
			delete_old_netblock( $stab, $oldblock );
			$numchanges++;
		}
	}

	$numchanges;
}

sub rename_physical_port {
	my ( $stab, $id, $newname, $devid ) = @_;

	my $newpp =
	  $stab->get_physical_port_byport( $devid, $newname, 'network' );
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
			$stab->error_return(
				"Invalid attempt to remove a non-license");
		}
		$numchanges +=
		  $stab->remove_from_device_collection( $devid, $dcid,
			'applicense' );
	}

	for my $offset ( $stab->cgi_get_ids("add_license_$devid") ) {
		my $dcid =
		  $stab->cgi_parse_param( "add_license_$devid", $offset );
		if ( $dcid !~ /^\d+$/ || grep( $dcid == $_, @existingdc ) ) {

# $stab->error_return("Device Collection ($dcid) is already assigned to this node.");
			next;
		}
		my $dc = $stab->get_device_collection($dcid);
		if ( $dc->{ _dbx('DEVICE_COLLECTION_TYPE') } ne 'applicense' ) {
			$stab->error_return(
				"Invalid attempt to remove a non-license");
		}
		$numchanges += $stab->add_to_device_collection( $devid, $dcid );
	}

	$numchanges;
}

sub process_interfaces {
	my ( $stab, $devid ) = @_;

	my $cgi        = $stab->cgi;
	my $numchanges = 0;

	#print $cgi->header, $cgi->start_html, $cgi->Dump, $cgi->end_html; exit;

	my $x = "";

	# see if we should delete any
	my (@gone);
	for my $srtid ( $stab->cgi_get_ids('chk_RM_STATIC_ROUTE_ID') ) {
		push( @gone, $srtid );
		$numchanges += $stab->rm_static_route_from_device($srtid);
	}

	for my $srtid ( $stab->cgi_get_ids('chk_ADD_STATIC_ROUTE_TEMPLATE_ID') )
	{
		$numchanges +=
		  $stab->add_static_route_from_template( $devid, $srtid );
	}

	#
	# process updates
	#
	foreach my $id ( $stab->cgi_get_ids('STATIC_ROUTE_ID') ) {
		next if ( grep( $_ eq $id, @gone ) );
		my $srcip = $stab->cgi_parse_param( 'ROUTE_SRC_IP', $id );
		my $srcbits =
		  $stab->cgi_parse_param( 'ROUTE_SRC_MASKLEN', $id );
		my $destip = $stab->cgi_parse_param( 'ROUTE_DEST_IP', $id );

		if ( $srcip && $srcip =~ /^default$/i ) {
			$srcip = '0.0.0.0';
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
			if (
				!$stab->check_ip_on_local_nets( $devid,
					$destip )
			  )
			{
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
			STATIC_ROUTE_ID => $id,
			DEVICE_SRC_ID   => $devid,
			NETWORK_INTERFACE_DST_ID =>
			  $ni->{ _dbx('NETWORK_INTERFACE_ID') },
			NETBLOCK_ID => $nb->{ _dbx('NETBLOCK_ID') },
		};

		my $diffs = $stab->hash_table_diff( $dbsr, _dbx($newsr) );

		my $tally   += keys %$diffs;
		$numchanges += $tally;

		if (
			$tally
			&& !$stab->run_update_from_hash(
				'STATIC_ROUTE', 'STATIC_ROUTE_ID',
				$id,            $diffs
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
		$srcip = '0.0.0.0';
		$srcbits = 0 if ( !$srcbits );
	}

	# exits with an error if it does not validate
	my ( $ni, $nb ) =
	  $stab->validate_route_entry( $srcip, $srcbits, $destip );

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
"Static Route $srcip/$srcbits->$destip is already on device"
			);
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
	my $macaddr  = $stab->cgi_parse_param('MAC_ADDR');
	my $dns      = $stab->cgi_parse_param('DNS_NAME');
	my $dnsdomid = $stab->cgi_parse_param('DNS_DOMAIN_ID');
	my $ip       = $stab->cgi_parse_param('IP');
	my $nitype   = $stab->cgi_parse_param('NETWORK_INTERFACE_TYPE');
	my $isintup  = $stab->cgi_parse_param('chk_IS_INTERFACE_UP');
	my $ismgmtip = $stab->cgi_parse_param('chk_IS_MANAGEMENT_INTERFACE');
	my $ispriint = $stab->cgi_parse_param('chk_IS_PRIMARY');
	my $isnatint = $stab->cgi_parse_param('chk_PROVIDES_NAT');
	my $dhcp     = $stab->cgi_parse_param('chk_PROVIDES_DHCP');
	my $shldmng  = $stab->cgi_parse_param('chk_SHOULD_MANAGE');
	my $shldmon  = $stab->cgi_parse_param('chk_SHOULD_MONITOR');

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

	$isintup  = $stab->mk_chk_yn($isintup);
	$ismgmtip = $stab->mk_chk_yn($ismgmtip);
	$ispriint = $stab->mk_chk_yn($ispriint);
	$isnatint = $stab->mk_chk_yn($isnatint);
	$shldmng  = $stab->mk_chk_yn($shldmng);
	$shldmon  = $stab->mk_chk_yn($shldmon);
	$dhcp     = $stab->mk_chk_yn($dhcp);

	return 0 if ( !defined($intname) );

	my $device = $stab->get_dev_from_devid($devid);

	if ( !defined($device) ) {
		$stab->error_return("You have specified an invalid device.");
	}

	if ( !defined($nitype) || $nitype eq 'unknown' ) {
		$stab->error_return("You must set an interface type");
	}

	if ( !defined($ip) ) {
		$stab->error_return("You must set an IP address");
	}

	if ( defined($dns) && !defined($dnsdomid) ) {
		#
		# not sure if this is a good idea or not.
		#
		$dnsdomid = $stab->guess_dns_domain_from_devid($device);
		if ( !defined($dnsdomid) ) {
			$stab->error_return(
				"You must set a DNS domain with a DNS name");
		}
	}

	my $nblk = $stab->get_netblock_from_ip(
		ip_address        => $ip,
		is_single_address => 'Y',
		netblock_type     => 'default'
	);
	my $xblk = $stab->configure_allocated_netblock( $ip, $nblk );
	$nblk = $xblk;

	#
	# figure out if other interfaces share these properties, and turn them
	# off if so.  (need to notify users).
	#
	my $oldpris  = 0;
	my $oldmgmts = 0;
	if ( $ispriint eq 'Y' ) {
		$oldpris =
		  switch_all_ni_prop_to_n( $stab, $devid, 'IS_PRIMARY' );
	}
	if ( $ismgmtip eq 'Y' ) {
		$oldmgmts = switch_all_ni_prop_to_n( $stab, $devid,
			'IS_MANAGEMENT_INTERFACE' );
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

	#
	# sanity check the mac address (convert to an integer).
	# required for oracle
	#
	#	my $procdmac = undef;
	#	if(defined($macaddr)) {
	#		$procdmac = $stab->int_mac_from_text($macaddr);
	#		if(!defined($procdmac)) {
	#			$stab->error_return("Unable to parse mac address ".
	#				((defined($macaddr))?$macaddr:"") );
	#		}
	#	}

	my $new = {
		device_id              => $devid,
		network_interface_name => $intname,
		network_interface_type => $nitype,
		IS_INTERFACE_UP        => $isintup,
		MAC_ADDR               => $macaddr,
		physical_port_id       => $ppid,
		provides_nat           => $isnatint,
		provides_dhcp          => $dhcp,
		netblock_id            => $nblk->{ _dbx('NETBLOCK_ID') },
		should_manage          => $shldmng,
		should_monitor         => $shldmon,
	};

	my $q = qq{
		insert into network_interface (
			device_id, name, NETWORK_INTERFACE_TYPE,
			IS_INTERFACE_UP, MAC_ADDR,
			NETWORK_INTERFACE_PURPOSE, IS_PRIMARY, SHOULD_MONITOR,
			physical_port_id, provides_nat, provides_dhcp,
			NETBLOCK_ID, SHOULD_MANAGE, IS_MANAGEMENT_INTERFACE
		) values (
			:devid, :name, :nitype,
			:isup, :mac,
			:nipurpose, :isprimary, :shldmon,
			:phsportid, :doesnat, 'N',
			:nblkid, :shldmng, :ismgmtip
		) returning network_interface_Id into :rv
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

	if ( defined($dns) && defined($dnsdomid) ) {
		my $type = 'A';
		$type = 'AAAA' if ( $stab->validate_ip($ip) == 6 );
		$stab->add_dns_record(
			{
				dns_name      => $dns,
				dns_domain_id => $dnsdomid,
				dns_type      => $type,
				dns_class     => 'IN',
				netblock_id   => $nblk->{ _dbx('NETBLOCK_ID') },
			}
		);
	}

	#
	# [XXX] - adjust DNS to match rules if primary/mgmt were set to y,
	# including adjusting non-primaries approppriately.
	#
	$numchanges;
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
	$stab->setup_device_physical_ports($devid);
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
				purge_physical_connection_by_physical_port_id(
					$stab, $path );
			}
		}
		$sth1->execute( $portid, $portid )
		  || $stab->return_db_err($sth1);
	}

	$sth1->finish;
	1;
}

sub delete_device_collection_membership {
	my ( $stab, $devid ) = @_;

	my $q = qq{
		delete from device_collection_device where device_id = ?
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err;

	my $numchanges = $sth->execute($devid) || $stab->return_db_err($sth);

	$sth->finish;
	$numchanges;
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

sub delete_device_interfaces {
	my ( $stab, $devid ) = @_;

	my (@netblocks);
	my $nbq = qq{
		select	netblock_id from network_interface
					where device_id = ?
	};
	my $Nsth = $stab->prepare($nbq) || $stab->return_db_err;
	$Nsth->execute($devid) || $stab->return_db_err($Nsth);
	while ( my ($nbid) = $Nsth->fetchrow_array ) {
		push( @netblocks, $nbid );
	}
	$Nsth->finish;

	my @qs = (
		qq{delete from dns_record
			where netblock_id in
					(select netblock_id from network_interface
						where device_id = ?
					)
		},
		qq{delete from network_interface_purpose
					where device_id = ?
		},
		qq{delete from network_interface
					where device_id = ?
		},
	);

	foreach my $q (@qs) {
		my $sth = $stab->prepare($q) || $stab->return_db_err;
		$sth->execute($devid) || $stab->return_db_err($sth);
	}

	foreach my $nbid (@netblocks) {
		$stab->delete_netblock($nbid);
	}
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

	my $dbdevice = $stab->get_dev_from_devid($devid);
	if ( !$dbdevice ) {
		$stab->error_return("Device no longer exists.");
	}
	my $numnotes = $stab->get_num_dev_notes($devid);

	# connections/phys_ports can probably be rolled into each other
	# once there's no physical port manipulation in the network
	# interface triggers.
	delete_device_connections( $stab, $devid );
	delete_device_interfaces( $stab, $devid );
	delete_device_phys_ports( $stab, $devid );
	delete_device_power( $stab, $devid );

	delete_device_collection_membership( $stab, $devid );

	my (@removeqs) = ( "SELECT device_utils.retire_device_ancillary(?);", );

	my $devtoo = 0;
	if (
		(
			  !$dbdevice->{ _dbx('SERIAL_NUMBER') }
			|| $dbdevice->{ _dbx('SERIAL_NUMBER') } =~ m,^n/a$,i
			|| $dbdevice->{ _dbx('SERIAL_NUMBER') } =~
			m,^Not-Applicable,i
		)
		&& !$numnotes
	  )
	{
		push( @removeqs, "delete from device where device_id = ?" );
		$devtoo = 1;
	} else {
		push( @removeqs,
"update device set device_name = NULL, service_environment = 'unallocated', device_status = 'removed', voe_symbolic_track_id = NULL where device_id = ?"
		);
	}

	foreach my $q (@removeqs) {
		my $sth = $stab->prepare($q) || $stab->return_db_err;
		$sth->execute($devid) || $stab->return_db_err($sth);
	}

	my ( $url, $msg );
	if ($devtoo) {
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
