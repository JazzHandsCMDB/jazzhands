#!/usr/bin/env perl
#
# Copyright (c) 2016-2017 Todd Kover
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

#
# this script validates input for an addition, and in the event of problem,
# will send an error message and present the user with an opportunity to
# fix.
#

use strict;
use warnings;
use JazzHands::STAB;
use JazzHands::Common qw(_dbx);
use URI;
use vars qw($stab);
use vars qw($cgi);
use vars qw($dbh);

do_device_add();

sub check_for_device {
	my ( $dbh, $name ) = @_;

	my $q = qq{
		select	count(*)
		  from	device
		 where	device_name = ?
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute($name) || $stab->return_db_err($sth);
	( $sth->fetchrow_array )[0];
}

sub do_device_add {
	$stab = new JazzHands::STAB || die "Could not create STAB";
	$cgi  = $stab->cgi          || die "Could not create cgi";
	$dbh  = $stab->dbh          || die "Could not create dbh";

	# print $cgi->header, $cgi->start_html, $cgi->Dump, $cgi->end_html; exit;

	my $device_name = $stab->cgi_parse_param('DEVICE_NAME');
	my $devtypeid   = $stab->cgi_parse_param('DEVICE_TYPE_ID');
	my $serialno    = $stab->cgi_parse_param('SERIAL_NUMBER');
	my $partno      = $stab->cgi_parse_param('PART_NUMBER');
	my $status      = $stab->cgi_parse_param('STATUS');
	my $owner       = $stab->cgi_parse_param('OWNERSHIP_STATUS');
	my $sitecode    = $stab->cgi_parse_param('SITE_CODE');
	my $svcenv      = $stab->cgi_parse_param('SERVICE_ENVIRONMENT_ID');
	my $osid        = $stab->cgi_parse_param('OPERATING_SYSTEM_ID');
	my $commstr     = $stab->cgi_parse_param('SNMP_COMMSTR');
	my $ismonitored = $stab->cgi_parse_param('chk_IS_MONITORED');
	my $localmgd    = $stab->cgi_parse_param('chk_IS_LOCALLY_MANAGED');
	my $cfgfetch    = $stab->cgi_parse_param('chk_SHOULD_FETCH_CONFIG');
	my $virtdev     = $stab->cgi_parse_param('chk_IS_VIRTUAL_DEVICE');
	my $mgmtprot    = $stab->cgi_parse_param('AUTO_MGMT_PROTOCOL');
	my $comptypid   = $stab->cgi_parse_param('COMPONENT_TYPE_ID');

	if ($device_name) {
		$device_name =~ s/^\s+//;
		$device_name =~ s/\s+$//;
		$device_name =~ tr/A-Z/a-z/;

		my $existingdev = $stab->get_dev_from_name($device_name);
		if ($existingdev) {
			$stab->error_return("A device by that name already exists.");
		}
	}

	if ($serialno) {
		$serialno =~ s/^\s+//;
		$serialno =~ s/\s+$//;

		my $otherdev = $stab->get_dev_from_serial($serialno);
		if ($otherdev) {
			undef $otherdev;
			$stab->error_return("That serial number is in use.");
		}
	}

	#
	# gather up all the device functions
	#
	my (@devfuncs);
	foreach my $p ( $cgi->param ) {
		if ( $p =~ /^chk_DEV_FUNC_(.+)$/ ) {
			my $func = $1;
			$func =~ tr/A-Z/a-z/;
			push( @devfuncs, $func );
		}
	}

	#
	# gather up all the appgroups.  This actually overrides the above.
	#
	my (@appgroups);
	foreach my $p ( $stab->cgi_parse_param('appgroup') ) {
		push( @appgroups, $p );
	}

	if ( !defined($device_name) ) {
		$stab->error_return("You must enter a device name.");
	} elsif ( check_for_device( $dbh, $device_name ) != 0 ) {
		$stab->error_return("Device $device_name already exists.");
	}

	if ( !defined($devtypeid) ) {
		$stab->error_return("You must set a device type.");
	}

	#if(!defined($status)) {
	#	$stab->error_return("You must set a status.");
	#}
	$status = 'unknown';

	#if(!defined($osid)) {
	#	$stab->error_return("You must set an operating system.");
	#}
	$osid = 0;

	if ( !defined($owner) ) {
		$stab->error_return("You must describe the ownership arrangement.");
	}

	if ( !defined($svcenv) ) {
		$stab->error_return("You must describe the production state.");
	}

	$ismonitored = $stab->mk_chk_yn($ismonitored);
	$localmgd    = $stab->mk_chk_yn($localmgd);
	$cfgfetch    = $stab->mk_chk_yn($cfgfetch);
	$virtdev     = $stab->mk_chk_yn($virtdev);

	my $numchanges = 0;
	my (@errs);

	my $compid;
	if ($comptypid) {
		my $newcomp = { COMPONENT_TYPE_ID => $comptypid, };

		if (
			!(
				$numchanges += $stab->DBInsert(
					table  => 'component',
					hash   => $newcomp,
					errors => \@errs
				)
			)
		  )
		{
			$stab->error_return( join( " ", @errs ) );
		}

		$compid = $newcomp->{ _dbx('COMPONENT_ID') };

		my $newasset = {
			COMPONENT_ID     => $compid,
			PART_NUMBER      => $partno,
			SERIAL_NUMBER    => $serialno,
			OWNERSHIP_STATUS => $owner,
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

	my $newdev = {
		DEVICE_TYPE_ID         => $devtypeid,
		COMPONENT_ID           => $compid,
		DEVICE_NAME            => $device_name,
		DEVICE_STATUS          => $status,
		SERVICE_ENVIRONMENT_ID => $svcenv,
		OPERATING_SYSTEM_ID    => $osid,
		SITE_CODE              => $sitecode,
		IS_MONITORED           => $ismonitored,
		IS_LOCALLY_MANAGED     => $localmgd,
		SHOULD_FETCH_CONFIG    => $cfgfetch,
		IS_VIRTUAL_DEVICE      => $virtdev,
		AUTO_MGMT_PROTOCOL     => $mgmtprot,
	};

	$numchanges = 0;
	if (
		!(
			$numchanges += $stab->DBInsert(
				table  => 'device',
				hash   => $newdev,
				errors => \@errs
			)
		)
	  )
	{
		$stab->error_return( join( " ", @errs ) );
	}

	my $devid = $newdev->{ _dbx('DEVICE_ID') };

	if ( defined($commstr) ) {
		my $q = qq{
			insert into snmp_commstr
			(
				device_id, snmp_commstr_type, rd_string, purpose
			) values (
				?, 'legacy', ?, 'historical community string'
			)
		};
		my $sth = $stab->prepare($q) || die $stab->return_db_err($dbh);
		$sth->execute( $devid, $commstr )
		  || die $stab->return_db_err($sth);
		$sth->finish;
	}

	#	if ( $#appgroups > -1 ) {
	#	     # note that appgroup_util.add_role validates the device collection
	#	     # id to ensure that its of the right type, so that does not need to
	#	     # happen here.
	#		my $sth = $stab->prepare(
	#			qq{
	#			begin
	#				appgroup_util.add_role(:1, :2);
	#			end;
	#		}
	#		) || die $stab->return_db_err;
	#
	#		foreach my $dcid (@appgroups) {
	#			$sth->execute( $devid, $dcid )
	#			  || die $stab->return_db_err;
	#		}
	#	}

	$dbh->commit;

	my $url = "../device.pl?devid=$devid";
	$stab->msg_return( "Device Added Successfully.", $url );
	undef $stab;
}
