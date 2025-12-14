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

# This scripts gets a list of devices matching the specified pattern
# It is used by the Other End fields of the STAb Device page, Switch Port tab
# It returns a json array of [device_id,device_name] pairs

use warnings;
use FileHandle;
use JSON;
use JazzHands::STAB;

do_search_devices();

sub do_search_devices {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";
	my $dbh  = $stab->dbh          || die "Could not create dbh";

	my $pattern = $cgi->param('pattern') || undef;

	print $cgi->header("application/json");

	my $q = qq{
		select	device_id, device_name
		from	device
		where	device_name like ?
		and	device_name not like '%--otherside%'
		order by device_name
	};
	my $sth = $stab->prepare($q) || $stab->return_db_error($dbh);
	$pattern = "%" . $pattern . "%";
	$sth->execute($pattern) || $stab->return_db_error($sth);

	my $result = $sth->fetchall_arrayref( [] );

	# Just get the first 10 results
	splice @$result, 10;
	print to_json($result);
	$sth->finish;
	undef $stab;
}
