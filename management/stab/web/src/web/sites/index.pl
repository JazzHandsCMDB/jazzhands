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

do_site_page();

sub do_site_page {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";
	my $dbh  = $stab->dbh          || die "Could not create dbh";

	my $sitecode = $stab->cgi_parse_param('SITE_CODE');

	if ( !defined($sitecode) ) {
		dump_all_sites($stab);
	} else {
		dump_site( $stab, $sitecode );
	}

	$dbh->rollback;
	$dbh->disconnect;
	$dbh = undef;
}

sub make_url {
	my ( $stab, $sitecode ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $n = new CGI($cgi);
	$n->param( 'sitecode', $sitecode );

	$cgi->a( { -href => $n->self_url }, $sitecode );
}

sub dump_all_sites {
	my ($stab) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";
	my $dbh = $stab->dbh || die "Could not create dbh";

	print $cgi->header( { -type => 'text/html' } );
	print $stab->start_html( { -title => 'Site Code List' } );

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
			$cgi->td( make_url( $stab, $sitecode ) ),
			$cgi->td($name),
			$cgi->td($addr),
			$cgi->td($npanxx),
			$cgi->td($status),
			$cgi->td($desc)
		);
	}
	print $cgi->end_table;
	print $cgi->end_html;
}

sub dump_site {
	my ( $stab, $sitecode ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";
	my $dbh = $stab->dbh || die "Could not create dbh";

	print $cgi->header( { -type => 'text/html' } );
	print $stab->start_html(
		{ -title => "Site Code Breakdown for $sitecode" } );

	my $netblocks = build_site_netblocks( $stab, $sitecode );
	my $racks = "";    # build_site_racks($stab, $sitecode);

	print $cgi->table(
		{ -border => 1 },
		$cgi->Tr( $cgi->th( ["Netblocks"] ) ),
		$cgi->Tr( $cgi->td( [$netblocks] ) )
	);

	print $cgi->end_html;
}

sub build_site_racks {
	my ( $stab, $sitecode ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";
	my $dbh = $stab->dbh || die "Could not create dbh";

	my $roomlist = get_room_list( $stab, $sitecode );

	my $q = qq{
		select	rack_row, rack
		  from	location
		 where	site_code = ?
		   AND	room = ?
		   AND	sub_room = ?
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($stab);

	my $t = "";
	foreach my $space (@$roomlist) {
		my $room    = $space->{'ROOM'}     || "";
		my $subroom = $space->{'SUB_ROOM'} || "";
		$sth->execute( $sitecode, $room, $subroom )
		  || $stab->return_db_err($stab);
		my $tt = "";
		while ( my ( $row, $rack ) = $sth->fetchrow_array ) {
			my $ps = ($subroom) ? "($subroom)" : "";
			my $link = $cgi->a(
				{
					-href =>
"sites/racks?SITE=$sitecode;ROOM=$room;SUB_ROOM=$subroom;ROW=$row;RACK=$rack"
				},
				"$room$ps: $row-$rack"
			);
			$tt .= $cgi->Tr( $cgi->td($link) );
		}
		$sth->finish;
		$t .= $cgi->table($tt) if ( length($tt) );
	}
	$cgi->table($t);
}

sub get_room_list {
	my ( $stab, $sitecode ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";
	my $dbh = $stab->dbh || die "Could not create dbh";

	my $q = qq{
		select	room, sub_room
		  from	location
		 where	site_code = ?
		 order by room, sub_room
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($stab);
	$sth->execute($sitecode) || $stab->return_db_err($stab);
	my (@rv);
	while ( my $h = $sth->fetchrow_hashref ) {
		push( @rv, $h );
	}
	$sth->finish;
	\@rv;
}

sub build_site_netblocks {
	my ( $stab, $sitecode ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";
	my $dbh = $stab->dbh || die "Could not create dbh";

	my $q = qq{
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
	my $sth = $stab->prepare($q) || die $dbh->errstr;
	$sth->execute($sitecode) || die $sth->errstr;

	my $x = $cgi->start_table( { -border => 1 } );
	$x .= $cgi->th([ "Block", "Description" ]);
	while ( my ( $id, $ip, $bits, $desc ) = $sth->fetchrow_array ) {
		my $link = "../netblock/?nblkid=$id";
		$link .= "&expand=yes" if ( $bits >= 24 );
		$x .= $cgi->Tr(
			$cgi->td( $cgi->a( { -href => $link }, "$ip/$bits" ) ),
			$cgi->td( ( ( defined($desc) ) ? $desc : "" ) ),
		);
	}
	$x .= $cgi->end_table;
	$x;
}
