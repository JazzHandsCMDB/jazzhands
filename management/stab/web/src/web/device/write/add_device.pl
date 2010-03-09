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

#
# this script validates input for an addition, and in the event of problem,
# will send an error message and present the user with an opportunity to
# fix.
#

use strict;
use warnings;
use JazzHands::STAB;
use URI;
use vars qw($stab);
use vars qw($cgi);
use vars qw($dbh);

$stab = new JazzHands::STAB || die "Could not create STAB";
$cgi  = $stab->cgi          || die "Could not create cgi";
$dbh  = $stab->dbh          || die "Could not create dbh";

sub check_for_device {
	my ( $dbh, $name ) = @_;

	my $q = qq{
		select	count(*)
		  from	device
		 where	device_name = :1
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute($name) || $stab->return_db_err($sth);
	( $sth->fetchrow_array )[0];
}

my $device_name = $stab->cgi_parse_param('DEVICE_NAME');
my $devtypeid   = $stab->cgi_parse_param('DEVICE_TYPE_ID');
my $serialno    = $stab->cgi_parse_param('SERIAL_NUMBER');
my $partno      = $stab->cgi_parse_param('PART_NUMBER');
my $status      = $stab->cgi_parse_param('STATUS');
my $owner       = $stab->cgi_parse_param('OWNERSHIP_STATUS');
my $prodstate   = $stab->cgi_parse_param('PRODUCTION_STATE');
my $osid        = $stab->cgi_parse_param('OPERATING_SYSTEM_ID');
my $voeid       = $stab->cgi_parse_param('VOE_ID');
my $commstr     = $stab->cgi_parse_param('SNMP_COMMSTR');
my $ismonitored = $stab->cgi_parse_param('chk_IS_MONITORED');
my $localmgd    = $stab->cgi_parse_param('chk_IS_LOCALLY_MANAGED');
my $cfgfetch    = $stab->cgi_parse_param('chk_SHOULD_FETCH_CONFIG');
my $virtdev     = $stab->cgi_parse_param('chk_IS_VIRTUAL_DEVICE');
my $mgmtprot    = $stab->cgi_parse_param('AUTO_MGMT_PROTOCOL');
my $voetrax     = $stab->cgi_parse_param('VOE_SYMBOLIC_TRACK_ID');

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

		# probably want to check device type [XXX]
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

if ( !defined($device_name) ) {
	$stab->error_return("You must enter a device name.");
} elsif ( check_for_device( $dbh, $device_name ) != 0 ) {
	$stab->error_return("Device $device_name already exists.");
}

if ( !defined($devtypeid) ) {
	$stab->error_return("You must set a device type.");
}

if ( !defined($status) ) {
	$stab->error_return("You must set a status.");
}

if ( !defined($osid) ) {
	$stab->error_return("You must set an operating system.");
}

if ( !defined($owner) ) {
	$stab->error_return("You must describe the ownership arrangement.");
}

if ( !defined($prodstate) ) {
	$stab->error_return("You must describe the production state.");
}

$ismonitored = $stab->mk_chk_yn($ismonitored);
$localmgd    = $stab->mk_chk_yn($localmgd);
$cfgfetch    = $stab->mk_chk_yn($cfgfetch);
$virtdev     = $stab->mk_chk_yn($virtdev);

my $q = qq{
	insert into device (
		DEVICE_TYPE_ID, DEVICE_NAME, SERIAL_NUMBER, 
		PART_NUMBER, STATUS,
 		PRODUCTION_STATE, OPERATING_SYSTEM_ID, VOE_ID,
 		OWNERSHIP_STATUS, IS_MONITORED, IS_LOCALLY_MANAGED,
		SHOULD_FETCH_CONFIG, IS_VIRTUAL_DEVICE, AUTO_MGMT_PROTOCOL,
		VOE_SYMBOLIC_TRACK_ID
	 ) values (
		:device_type_id, :device_name, :serial_number, 
		:part_number, :status,
		:prodstate, :osid, :voeid,
		:ownstat, :ismon, :islclmgd,
		:cfgfetch, :isvirt, :mgmtprot, 
		:voetrax
	) returning device_id into :device_id
};

my $devid;

my $sth = $stab->prepare($q) || die $stab->return_db_err($dbh);
$sth->bind_param( ':device_type_id', $devtypeid ) || $stab->return_db_err($sth);
$sth->bind_param( ':device_name', $device_name ) || $stab->return_db_err($sth);
$sth->bind_param( ':part_number', $partno )      || $stab->return_db_err($sth);
$sth->bind_param( ':serial_number', $serialno )  || $stab->return_db_err($sth);
$sth->bind_param( ':status',        $status )    || $stab->return_db_err($sth);
$sth->bind_param( ':prodstate',     $prodstate ) || $stab->return_db_err($sth);
$sth->bind_param( ':osid',          $osid )      || $stab->return_db_err($sth);
$sth->bind_param( ':voeid',         $voeid )     || $stab->return_db_err($sth);
$sth->bind_param( ':ownstat',       $owner )     || $stab->return_db_err($sth);
$sth->bind_param( ':ismon',    $ismonitored ) || $stab->return_db_err($sth);
$sth->bind_param( ':islclmgd', $localmgd )    || $stab->return_db_err($sth);

$sth->bind_param( ':cfgfetch', $cfgfetch ) || $stab->return_db_err($sth);
$sth->bind_param( ':isvirt',   $virtdev )  || $stab->return_db_err($sth);
$sth->bind_param( ':mgmtprot', $mgmtprot ) || $stab->return_db_err($sth);
$sth->bind_param( ':voetrax',  $voetrax )  || $stab->return_db_err($sth);

$sth->bind_param_inout( ':device_id', \$devid, 500 )
  || $stab->return_db_err($sth);

$sth->execute || $stab->return_db_err($sth);

$sth->finish;

if ( defined($commstr) ) {
	$q = qq{
		insert into snmp_commstr
		(
			device_id, snmp_commstr_type, rd_string, purpose
		) values (
			:1, 'legacy', :2, 'historical community string'
		)
	};
	$sth = $stab->prepare($q) || die $stab->return_db_err($dbh);
	$sth->execute( $devid, $commstr ) || die $stab->return_db_err($sth);
	$sth->finish;
}

if ( $#devfuncs > -1 ) {
	$q = qq{
		insert into device_function (
			device_id, device_function_type
		) values (
			:1, :2
		)
	};
	$sth = $stab->prepare($q) || die $stab->return_db_err($sth);

	foreach my $func (@devfuncs) {
		$sth->execute( $devid, $func )
		  || die $stab->return_db_err($sth);
	}
	$sth->finish;
}

$stab->setup_device_power($devid);
$stab->setup_device_serial($devid);

$dbh->commit;

my $url = "../device.pl?devid=$devid";
$stab->msg_return( "Device Added Successfully.", $url );
