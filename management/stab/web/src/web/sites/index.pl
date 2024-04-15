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

	my $sitecode = $stab->cgi_parse_param('sitecode');

	# If the site code is not specificed, display a summary page
	# Otherwise display the site page with netblocks
	if ( !defined($sitecode) ) {
		dump_all_sites($stab);
	} else {
		dump_site_netblocks( $stab, $sitecode );
	}

	$dbh->rollback;
	$dbh->disconnect;
	$dbh = undef;
	undef $stab;
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
	my $cgi    = $stab->cgi || die "Could not create cgi";
	my $dbh    = $stab->dbh || die "Could not create dbh";

	print $cgi->header(      { -type  => 'text/html' } );
	print $stab->start_html( { -title => 'Site Code List' } );

	my $q = qq{
		select 	s.site_code,
		 	c.company_name,
			physical_address_utils.localized_physical_address(p.physical_address_id),
			s.site_status,
			s.description
		  from	site s
			left join company c
				on c.company_id = s.colo_company_id
			left join physical_address p
				USING (physical_address_id)
		order by s.site_code
	};

	my $sth = $stab->prepare($q) || die;
	$sth->execute                || die;

	print $cgi->start_table( { -border => 1, -align => 'center' } );

	print $cgi->Tr(
		$cgi->th('Site Code'), $cgi->th('Colo Provider'),
		$cgi->th('Address'),   $cgi->th('Status'),
		$cgi->th('Description'),
	);

	while ( my ( $sitecode, $name, $addr, $status, $desc ) =
		$sth->fetchrow_array )
	{
		print $cgi->Tr( $cgi->td( make_url( $stab, $sitecode ) ),
			$cgi->td($name), $cgi->td($addr), $cgi->td($status),
			$cgi->td($desc) );
	}
	print $cgi->end_table;
	print $cgi->end_html;
}

sub dump_site_netblocks {
	my ( $stab, $sitecode ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";
	my $dbh = $stab->dbh || die "Could not create dbh";

	print $cgi->header( { -type => 'text/html' } );
	print $stab->start_html( {
		-title      => "Site Netblocks for $sitecode",
		-javascript => 'site_netblock'
	} );

	#my $netblocks = build_site_netblocks( $stab, $sitecode );
	#my $racks = "";    # build_site_racks($stab, $sitecode);
	#print $netblocks;

	my $q = qq{
		select	nb.netblock_id,
			net_manip.inet_dbtop(nb.ip_address) as ip,
			masklen(nb.ip_address) as masklen,
			nb.description
		  from	netblock nb
			inner join site_netblock snb
				on snb.netblock_id = nb.netblock_id
		 where	snb.site_code = ?
		 order by ip_address
	};
	my $sth = $stab->prepare($q) || die $dbh->errstr;
	$sth->execute($sitecode)     || die $sth->errstr;

	print $cgi->start_form(
		-method => 'POST',
		-action => 'write/edit_site_netblocks.pl'
	);
	print $cgi->hidden( 'sitecode', $sitecode );
	print '<br/>'
	  . $cgi->start_table(
		{ -class => 'networkrange', -border => 1, -align => 'center' } );
	print $cgi->th( { -class => 'networkrange' },
		[ 'RM', 'Netblock', 'Description' ] );
	print $cgi->Tr( $cgi->td( {
			-class   => 'networkrange',
			-colspan => '3'
		},
		$cgi->a( {
				-href    => '#',
				-class   => 'adddnsrec plusbutton',
				-onclick =>
				  "this.style.display = 'none'; document.getElementById('SITE_NETBLOCK_NEW').style.display = '';",
				-title => 'Add a new Netblock to this Site',
			},
		)
	) );
	print $cgi->Tr( {
			-id    => 'SITE_NETBLOCK_NEW',
			-style => 'display: none;',
		},
		$cgi->td(
			{ -class => 'networkrange' },
			[
				$cgi->hidden( 'SITE_NETBLOCK_ID', 'NEW' ),
				$cgi->textfield( {
					-size     => 10,
					-name     => 'SITE_NETBLOCK_IP_NEW',
					-value    => '',
					-class    => 'tracked',
					-original => '',
				} ),

				#$cgi->textfield({
				#	-size => 50,
				#	-name => 'SITE_NETBLOCK_DESCRIPTION_NEW',
				#	-value => '',
				#	-class => 'tracked',
				#	-original => '',
				#})
			]
		)
	);

	# Loop on netblocks for this site
	while ( my ( $id, $ip, $bits, $desc ) = $sth->fetchrow_array ) {
		my $link = "../netblock/?nblkid=$id";
		$link .= "&expand=yes" if ( $bits >= 24 );
		print $cgi->Tr( {
				-class => ( (
						$stab->cgi_parse_param( 'SITE_NETBLOCK_DELETE_' . $id )
						  eq 'delete'
					) ? 'rowrm' : ''
				)
			},
			$cgi->td(
				{ -class => 'networkrange' },
				$cgi->hidden( {
					-value =>
					  $stab->cgi_parse_param( 'SITE_NETBLOCK_DELETE_' . $id ),
					-id       => 'SITE_NETBLOCK_DELETE_' . $id,
					-name     => 'SITE_NETBLOCK_DELETE_' . $id,
					-class    => 'tracked',
					-original => '',
				} )
				  . $cgi->a( {
						-class   => 'rmrow',
						-alt     => "Disassociate this Netblock from the Site",
						-title   => 'Disassociate this Netblock from the Site',
						-onclick =>
						  "let trcl=this.parentElement.parentElement.classList; trcl.toggle('rowrm'); document.getElementById('SITE_NETBLOCK_DELETE_$id').value = trcl.contains('rowrm') ? 'delete' : '';"
					},
					''
				  )
			),
			$cgi->td(
				{ -class => 'networkrange' },
				$cgi->a( { -href => $link }, "$ip/$bits" )
			),
			$cgi->td(
				{ -class => 'networkrange' },
				( ( defined($desc) ) ? $desc : "" )

				  #$cgi->textfield({
				  #	-size => 50,
				  #	-name => 'SITE_NETBLOCK_DESCRIPTION_'.$id,
				  #	-value => defined($desc) ? $desc : "",
				  #	-class => 'tracked',
				  #	-original => defined($desc) ? $desc : "",
				  #}),
			),
		);
	}
	print $cgi->end_table;
	print $cgi->div(
		{ -class => 'centered' },
		$cgi->submit( {
			-class => '',
			-name  => "NetblockSites",
			-value => "Submit Site Netblock Changes",
		} )
	);
	print $cgi->end_form, "\n";

	print $cgi->end_html;
}

