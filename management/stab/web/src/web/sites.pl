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

use strict;
use warnings;
use POSIX;
use JazzHands::STAB;
use vars qw($stab);
use vars qw($cgi);
use vars qw($dbh);

$stab = new JazzHands::STAB || die "Could not create STAB";
$cgi  = $stab->cgi          || die "Could not create cgi";
$dbh  = $stab->dbh          || die "Could not create dbh";

print $cgi->header( { -type => 'text/html' } ), "\n";

print $stab->start_html( { -title => 'Site Code List' } ), "\n";

my $q = qq{
	select 	s.site_code,
	 	c.company_name,
		-- p.address, XXX
		s.npanxx,
		s.site_status,
		s.description
	  from	site s
		left join company c
			on c.company_id = s.colo_company_id
	order by s.site_code
};

my $sth = $stab->prepare($q) || die;
$sth->execute || die;

print $cgi->start_table( { -border => 1 } );

print $cgi->Tr(
	$cgi->th('Site Code'), $cgi->th('Colo Provider'),
	$cgi->th('Address'),   $cgi->th('NPANXX'),
	$cgi->th('Status'),    $cgi->th('Description'),
);

while ( my ( $sitecode, $name, $addr, $npanxx, $status, $desc ) =
	$sth->fetchrow_array )
{
	print $cgi->Tr(
		$cgi->td($sitecode), $cgi->td($name),
		$cgi->td($addr),     $cgi->td($npanxx),
		$cgi->td($status),   $cgi->td($desc)
	  ),
	  "\n";
}
print $cgi->end_table;
print $cgi->end_html, "\n";

$dbh->rollback;
$dbh->disconnect;

undef $stab;
