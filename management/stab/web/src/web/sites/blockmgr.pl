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
print $stab->start_html( { -title => "Netblock and IP Allocation" } ), "\n";

my $persiteq = qq{
	select	nb.netblock_id,
		net_manip.inet_dbtop(nb.ip_address) as ip,
		nb.netmask_bits,
		nb.description
	  from	netblock nb
		inner join site_netblock snb
			on snb.netblock_id = nb.netblock_id
	 where	snb.site_code = ?
	 order by ip_address
};
my $persitesth = $stab->prepare($persiteq) || die $dbh->errstr;

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
my $sth = $stab->prepare($q) || die $dbh->errstr;
$sth->execute || die $sth->errstr;

my $maxperrow = 4;

print $cgi->start_table( { -border => 1 } ), "\n";

print $cgi->h2( { -align => 'center' }, "IP Network Allocation" ), "\n";

my $curperrow = -1;
my $rowtxt    = "";
while ( my ( $sitecode, $name, $addr, $npanxx, $status, $desc ) =
	$sth->fetchrow_array )
{
	if ( ++$curperrow == $maxperrow ) {
		$curperrow = 0;
		print $cgi->Tr($rowtxt), "\n";
		$rowtxt = "";
	}

	$persitesth->execute($sitecode) || die $sth->errstr;

	my $netblocks = "";
	while ( my ( $id, $ip, $bits, $desc ) = $persitesth->fetchrow_array ) {
		my $link = "../netblock/?nblkid=$id";
		$link .= "&expand=yes" if ( $bits >= 24 );
		$netblocks .= $cgi->Tr(
			$cgi->td( $cgi->a( { -href => $link }, "$ip/$bits" ) ),

			# $cgi->td( ((defined($desc))?$desc:"") ),
		) . "\n";
	}

	my $sitelink = $cgi->a({-href=>"./?SITE_CODE=$sitecode"}, $sitecode);
	my $entry =
	  #$cgi->table({-border => 1, -width=>'100%', -align=>'top'},
	  $cgi->table(
		{ -width => '100%', -align => 'top' },
		$cgi->Tr(
			$cgi->td(
				{
					-align => 'center',
					-style => 'background: yellow'
				},
				$cgi->b($sitelink)
			)
		),
		$cgi->b($sitecode),
		$cgi->Tr(
			$cgi->td(
				{
					-align => 'center',
					-style => 'background: yellow'
				},
				$cgi->b($desc)
			)
		),
		$cgi->Tr(
			$cgi->td(
				{ -align => 'center' },
				$cgi->table( $cgi->hr, $netblocks )
			)
		)
	  ) . "\n";

	$rowtxt .= $cgi->td( { -valign => 'top' }, $entry );
}
print $cgi->Tr($rowtxt), "\n";
print $cgi->end_table;
print $cgi->end_html, "\n";

$dbh->rollback;
$dbh->disconnect;
$dbh = undef;

END {
	if ( defined($dbh) ) {
		$dbh->rollback;
		$dbh->disconnect;
	}
}
