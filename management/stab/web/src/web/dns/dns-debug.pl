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

use strict;
use warnings;
use POSIX;
use JazzHands::STAB;
use JazzHands::Common qw(:all);
use CGI::Pretty;
use Net::DNS;
use Data::Dumper;

exit( do_zone_debug() || 0 );

#
# pretty up the most typical answers for minimal results
#
sub process_answer {
	my ( $stab, $stripdmns, $dns ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $ttl = $cgi->b( $dns->ttl ) || "";

	my $txt;

	if ( $dns->type eq 'NS' ) {
		$txt = $dns->nsdname;
	} elsif ( $dns->type eq 'A' || $dns->type eq 'AAAA' ) {
		$txt = $dns->address;
	} elsif ( $dns->type eq 'PTR' ) {
		$txt = $dns->ptrdname;
	} elsif ( $dns->type eq 'TXT' ) {
		$txt = $dns->txtdata;
	} else {

		# this was here; not clearwhy.
		# $ttl = '';
		$txt = $dns->string;
	}

	# pluck from db...
	$txt =~ s,.example.com$,<b>...</b>, if ($stripdmns);

	"$ttl $txt";
}

sub show_nsbox {
	my ( $stab, $check, $extrans ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $l = "";
	foreach my $x (@$extrans) {
		$l .= $cgi->textfield( { -name => 'extra_ns' } ) . $cgi->br;
	}

	$cgi->div(
		$cgi->a(
			{ -href => '#', -onClick => 'dns_debug_addns(this);' },
			'Add a Nameserver'
		),
		$cgi->br,
		$l
	);
}

sub dump_appls {
	my $stab  = shift @_;
	my $check = shift @_;
	my $cgi   = $stab->cgi || die "Could not create cgi";

	my $sth = $stab->prepare(
		qq{
		select	role_level, role_id, role_path, role_is_leaf
		  from	v_application_role
		 where	role_path like '/server/dns%'
		 -- and	role_is_leaf in ('Y', 'N')
		 order by role_path
	}
	) || $stab->return_db_err;

	$sth->execute;

	my $max = 0;
	my ( @default, @values, %labels, %attrib );
	while ( my ( $level, $id, $role, $leaf ) = $sth->fetchrow_array ) {
		push( @values, $id );
		$labels{$id} = "$role";
		if ( $leaf eq 'Y' ) {
			$attrib{$id} = { 'class' => 'dns_leaf' };

			# thoughtfully passed through escapeHTML
			# $labels{$id} = $cgi->b($labels{$id});
		}
		$attrib{$id}->{'style'} =
		  'text-indent: ' . ( $level * 2 ) . "em;";
		if ( exists( $check->{$role} ) ) {
			push( @default, $id );
		}
		$max = length($role) if ( length($role) > $max );
	}

	#
	# This needs to be revisited to deal with labelattribute per-checkbox
	#
	$cgi->div(
		{
			-class => 'approles',
			-style => "width: ${max}ex"
		},
		$cgi->a(
			{
				-href    => '#',
				-onClick => 'dns_show_approles(this)'
			},
			"Show AppRoles"
		),
		$cgi->div(
			{
				class  => 'approles_group',
				-id    => 'approle_div',
				-style => "display: none",
			},
			$cgi->checkbox_group(
				-name       => 'approles',
				-values     => \@values,
				-labels     => \%labels,
				-default    => \@default,
				-linebreak  => 'true',
				-attributes => \%attrib,

				# -labelattributes => {class => 'foo'},
			)
		)
	);
}

sub do_zone_debug {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";

	my $dnsrec    = $stab->cgi_parse_param('DNS_RECORD');
	my $dnstype   = $stab->cgi_parse_param('DNS_TYPE');
	my $stripdmns = $stab->cgi_parse_param('strip_dmns');

	my @applist = $stab->cgi_parse_param('approles');
	my @extrans = $stab->cgi_parse_param('extra_ns');

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html(
		{ -title => "DNS Debugging", -javascript => 'dns' } ), "\n";

	print $cgi->div(
		{ -class => 'introblurb' }, qq{
		This page is used to look at a record on various nameservers
		at JazzHands and throughout.  You can pick types of nameservers from
		the AppRoles table, but it defaults to a reasonable set.  You may
		also add additional nameservers to the list, though these need to be
		accessible from the host that STAB is hosted on.
	}
	  ),
	  $cgi->hr;

	my $chks =
	  { '/server/dns/dns autogeneration/dns autogeneration all zones' => 1,
	  };

	print $cgi->start_form( -class => 'center_form', -method => 'GET' );
	print q{ Enter a record and a record type to look for: }, $cgi->br;
	print $cgi->textfield(
		{
			-name  => 'DNS_RECORD',
			-value => $dnsrec,
		}
	);
	print $stab->b_dropdown( { -showHidden => 'yes' }, undef, 'DNS_TYPE' );
	print $cgi->br,
	  $cgi->checkbox(
		{
			-name  => 'strip_dmns',
			-label => "Strip example.com"
		}
	  );    # pluck from db

	print dump_appls( $stab, $chks );
	print show_nsbox( $stab, $chks, \@extrans );
	print $cgi->submit;
	print $cgi->end_form;

	return if ( !$dnsrec );
	$stab->error_return("No Appliction Roles Checked")
	  if ( $#applist == -1 );

	foreach my $x (@applist) {
		if ( defined($x) && $x !~ /^\d+$/ ) {
			return $stab->error_return(
				"Invalid application entry.");
		}
	}

	# limit the query to just the approles of interest, then filter further
	# in perl.  This allows us to get away form hardcoding a list in the
	# query, which means more lots of sanity checking and ickiness.
	my $sth = $stab->prepare(
		qq{
		select	d.device_id, d.device_name, am.role_id
		  from	device d
				inner join v_application_role_member am
					on am.device_id = d.device_id
				inner join v_application_role ar
					on ar.role_id = am.role_id
		where
				role_path like '/server/dns%'
	}
	) || return $stab->return_db_err;

	$sth->execute || $stab->return_db_err;

	my $tt = "";
	while ( my $hr = $sth->fetchrow_hashref ) {
		next if ( !grep( $_ == $hr->{ _dbx('ROLE_ID') }, @applist ) );
		$tt .=
		  query_fmt_ns( $stab, $hr, $dnsrec, $dnstype, $stripdmns );
	}

	if ( $#extrans >= 0 ) {
		foreach my $ns (@extrans) {
			$tt .= query_fmt_ns( $stab, $ns, $dnsrec, $dnstype,
				$stripdmns );
		}
	}

	print $cgi->table(
		{
			-caption => 'foo',
			-border  => 1,
			-class   => 'center_table',
			-id      => 'dns_debug',
		},
		$cgi->th( [ "DNS Server", "Record Results ..." ] ),
		$tt
	);

	$tt = undef;

	print $cgi->end_html;
	undef $stab;
	0;
}

sub query_fmt_ns {
	my ( $stab, $hr, $dnsrec, $dnstype, $stripdmns ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my ( $name, $link );
	if ( ref $hr eq 'HASH' ) {
		my $devid = $hr->{ _dbx('DEVICE_ID') };
		$name = $hr->{ _dbx('DEVICE_NAME') };
		my $pname = $hr->{ _dbx('DEVICE_NAME') };

		# pluck from db
		$pname =~ s,.example.com$,<b>...</b>, if ($stripdmns);
		$link = $cgi->a(
			{
				-href => '../device/device.pl?devid=$devid'
			},
			$pname
		);
	} else {
		$name = $link = $hr;
	}

	my $res = new Net::DNS::Resolver;
	$res->nameservers($name);
	my $q = $res->query( $dnsrec, $dnstype );

	my $tt = "";
	if ( !$q ) {
		$tt .= $cgi->Tr( $cgi->td( [ $link, "NXDOMAIN" ] ) );
	} else {
		$tt .= $cgi->Tr(
			$cgi->td(
				[
					$link,
					sort map {
						process_answer( $stab,
							$stripdmns, $_ );
					} $q->answer
				]
			)
		);
	}
	$tt;
}
