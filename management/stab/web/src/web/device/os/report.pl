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

do_operating_system_report();

sub do_operating_system_report {
	my $stab = new JazzHands::STAB || die "Could not create STAB";

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	print $cgi->header('text/html');
	print $stab->start_html( { -title => "Operating System Breakdown" } ),
	  "\n";

	my $q = qq{
		select	os.name,
			os.version,
			os.processor_architecture,
			count(*) as tally
		  from	device d
			inner join operating_system os
				on os.operating_system_id = d.operating_system_id
			left join device_function df on
				d.device_id = df.device_id
			where (
					os.processor_architecture <> 'noarch' or
					os.name = 'unknown'
				  )
			  and	(df.device_function_type is NULL or
					 df.device_function_type in ('server', 'desktop')
					)
		group by os.name, os.version, os.processor_architecture
		order by lower(os.name), os.processor_architecture, os.version
	};

	my $sth = $stab->prepare($q) || return $stab->return_db_error($dbh);
	$sth->execute || return $stab->return_db_error($sth);

	print $cgi->start_table( { -border => 1, align => 'center' } );
	print $cgi->th(
		[ 'Name', 'Version', 'Architecture', 'Number of Systems' ] );
	while ( my ( $name, $version, $arch, $tally ) = $sth->fetchrow_array ) {
		print $cgi->Tr(
			$cgi->td($name),    $cgi->td($arch),
			$cgi->td($version), $cgi->td($tally),
		);
	}
	print $cgi->end_table;
	$sth->finish;

	print $cgi->end_html;
}
