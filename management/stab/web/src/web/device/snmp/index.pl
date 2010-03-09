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

use strict;
use warnings;
use Net::Netmask;
use FileHandle;
use JazzHands::STAB;

do_device_snmp_page();

############################################################################

sub do_device_snmp_page {
	my $stab = new JazzHands::STAB || die "Could not create STAB";

	my $cgi   = $stab->cgi               || die "Could not create cgi";
	my $dbh   = $stab->dbh               || die "Could not create dbh";
	my $devid = $cgi->param('DEVICE_ID') || undef;

	if ( !defined($devid) ) {
		$stab->error_return("Must specify a device.");
	}
	my $device = $stab->get_dev_from_devid($devid);
	if ( !defined($device) ) {
		$stab->error_return("Unknown Device");
	}

	my $title =
	  "SNMP Community String information for " . $device->{'DEVICE_NAME'};

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html( { -title => $title } ), "\n";

	my $q = qq{
		select	snmp_commstr_id,
			device_id,
			snmp_commstr_type,
			rd_string,
			wr_string,
			purpose
		  from	snmp_commstr
		 where	device_id = :1
	};

	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute($devid);

	my $t = "";

	while ( my $hr = $sth->fetchrow_hashref ) {
		$t .= build_snmp_row( $stab, $hr );
	}

	# add a new
	$t .= $cgi->Tr(
		$cgi->td(
			{
				-colspan => 4,
				-align   => 'center',
				-class   => 'header'
			},
			$cgi->b('Add New')
		)
	);
	$t .= build_snmp_row($stab);

	$t .= $cgi->Tr(
		$cgi->td(
			{ -colspan => 4, -align => 'center' },
			$cgi->submit('Submit Changes')
		)
	);

	print $cgi->start_form( -action => 'commit_change.pl' );
	print $cgi->hidden( 'DEVICE_ID', $devid );
	print $cgi->table(
		{ -align => 'center', -border => 1 },
		$cgi->th(
			[ 'Type', 'Read String', 'Write String', 'Purpose' ]
		),
		$t
	);

	print $cgi->end_form, "\n";
	print $cgi->end_html, "\n";

	$dbh->rollback;
	$dbh->disconnect;
}

sub build_snmp_row {
	my ( $stab, $hr ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $hidden = "";
	if ( defined($hr) && exists( $hr->{'SNMP_COMMSTR_ID'} ) ) {
		$hidden =
		  $cgi->hidden( 'SNMP_COMMSTR_ID_' . $hr->{'SNMP_COMMSTR_ID'},
			$hr->{'SNMP_COMMSTR_ID'} ),
		  ;
	}

	$cgi->Tr(
		$hidden,
		$cgi->td(
			$stab->b_dropdown(
				undef,               $hr,
				'SNMP_COMMSTR_TYPE', 'SNMP_COMMSTR_ID'
			)
		),
		$cgi->td(
			$stab->b_textfield(
				undef, $hr, 'RD_STRING', 'SNMP_COMMSTR_ID'
			)
		),
		$cgi->td(
			$stab->b_textfield(
				undef, $hr, 'WR_STRING', 'SNMP_COMMSTR_ID'
			)
		),
		$cgi->td(
			$stab->b_textfield(
				undef, $hr, 'PURPOSE', 'SNMP_COMMSTR_ID'
			)
		),
	);
}
