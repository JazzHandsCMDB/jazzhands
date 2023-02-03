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

use strict;
use warnings;
use JazzHands::STAB;
use vars qw($stab);
use vars qw($cgi);
use vars qw($dbh);

$stab = new JazzHands::STAB || die "Could not create STAB";
$cgi  = $stab->cgi          || die "Could not create cgi";
$dbh  = $stab->dbh          || die "Could not create dbh";

my $devlist = $stab->cgi_parse_param('devlist');
$cgi->delete($devlist) if ($devlist);

print $cgi->header('text/html');
print $stab->start_html( { -title => "Device Management" } ), "\n";

if ( defined($devlist) && $devlist =~ /^[\d,]+$/ ) {
	my @devlist = split( /,/, $devlist );
	my $tally = $#devlist + 1;
	print $cgi->p(
		$cgi->b(
			"The following $tally devices match the selected criteria.  Please choose or submit a new search:"
		)
	);
	my $q = qq{
		select	distinct device_id, device_name
		  from	device
		  where	device_id in ($devlist)
		order by device_name
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute || $stab->return_db_err($sth);

	my $all = "";
	while ( my ( $id, $name ) = $sth->fetchrow_array ) {
		$name = "(unnamed, retired device)" if ( !defined($name) );
		$all .=
		  $cgi->li( $cgi->a( { -href => "device.pl?devid=$id" }, $name ) )
		  . "\n";
	}
	if ( length($all) ) {
		print $cgi->ul($all), "\n";
	} else {
		print $cgi->p( { -align => 'center', -style => 'color: green' },
			"Unable to find any matches." );
	}

}

print $cgi->hr, "\n";
print $cgi->h3( { -align => 'center' }, 'Search for a device' ), "\n";

print $cgi->p(
	{ -align => 'center' }, qq{
	Please enter the criteria to search for.  Search will be for hosts
	that match all fields that are filled in.  CIDR blocks are of the
	form ip/bits.
	
}
);

print $cgi->start_form( -method => 'POST', -action => 'search.pl' ), "\n";

print $cgi->start_table( { align => 'center' } );
print $cgi->Tr(
	$cgi->td("Host/Label/DNS Shortname: "),
	$cgi->td( $cgi->textfield( -name => "byname" ) )
  ),
  "\n";
print $cgi->Tr(
	$cgi->td("IP or CIDR: "),
	$cgi->td( $cgi->textfield( -name => "byip" ) )
  ),
  "\n";
print $cgi->Tr(
	$cgi->td("Serial Number/HostId: "),
	$cgi->td( $cgi->textfield( -name => "byserial" ) )
  ),
  "\n";
print $cgi->Tr(
	$cgi->td("Mac Addr: "),
	$cgi->td( $cgi->textfield( -name => "bymac" ) )
  ),
  "\n";
print $cgi->Tr( $cgi->td("Type: "),
	$cgi->td( $stab->b_dropdown( undef, 'DEVICE_TYPE_ID', undef, 1 ) ) ),
  "\n";
print $cgi->Tr( $cgi->td("OS: "),
	$cgi->td( $stab->b_dropdown( undef, 'OPERATING_SYSTEM_ID', undef, 1 ) ) ),
  "\n";
print $cgi->Tr(
	$cgi->td(
		{ -colspan => 2, align => 'center' },
		$stab->build_checkbox(
			undef, "Include removed devices",
			'INCLUDE_REMOVED', undef, 0
		),
	),
  ),
  "\n";
print $cgi->Tr(
	$cgi->td( { -colspan => 2, align => 'center' }, $cgi->submit("Search") ) );

print $cgi->end_table;
print $cgi->end_form, "\n";

print $cgi->hr, "\n";
print $cgi->p( { -align => 'center' },
	$cgi->a( { -href => "device.pl" }, "Add a device" ) );
print $cgi->hr, "\n";

print $cgi->end_html, "\n";

undef $stab;

exit 0;
