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
use POSIX;
use Data::Dumper;
use Carp;
use JazzHands::STAB;
use Net::IP;

do_dns_toplevel();

sub do_dns_toplevel {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";

	my $dnsdomid       = $stab->cgi_parse_param('dnsdomainid');
	my $dnsrecid       = $stab->cgi_parse_param('DNS_RECORD_ID');
	my $dnssearch      = $stab->cgi_parse_param('dnssearch');
	my $ip_universe_id = $stab->cgi_parse_param('ip_universe_id');

	my $paging_dns_page  = $stab->cgi_parse_param('paging-dns-page')  || '1';
	my $paging_dns_limit = $stab->cgi_parse_param('paging-dns-limit') || '200';

	my $addonly = $stab->cgi_parse_param('addonly');

	# Do we have to search for a record?
	if ($dnssearch) {
		my $dnsrec = $stab->get_dns_record_from_id($dnssearch);
		if ($dnsrec) {
			$dnsdomid = $dnsrec->{'DNS_DOMAIN_ID'};
			$dnsrecid = $dnsrec->{'DNS_RECORD_ID'};
		}
	}

	if ($dnsrecid) {
		dump_zone( $stab, $dnsdomid, $dnsrecid, $addonly, $paging_dns_page,
			$paging_dns_limit, $ip_universe_id );
	} elsif ( !defined($dnsdomid) ) {
		dump_all_zones_dropdown($stab);
	} else {
		dump_zone( $stab, $dnsdomid, undef, $addonly, $paging_dns_page,
			$paging_dns_limit, $ip_universe_id );
	}
	undef $stab;
}

sub get_dns_domain_ip_universes {
	my ( $stab, $dnsdomainid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $q = qq{
		select ip_universe_id, ip_universe_name
		  from ip_universe
			   join dns_domain_ip_universe using (ip_universe_id)
		 where dns_domain_id = :dns_domain_id
		order by ip_universe_id
	};
	my $sth = $stab->prepare($q) || return $stab->return_db_err;
	$sth->bind_param( ':dns_domain_id', $dnsdomainid );
	$sth->execute || return $stab->return_db_err($sth);

	my @universes;
	while ( my $hr = $sth->fetchrow_hashref ) {
		push(
			@universes,
			{
				ip_universe_id   => $hr->{'IP_UNIVERSE_ID'},
				ip_universe_name => $hr->{'IP_UNIVERSE_NAME'}
			}
		);
	}
	$sth->finish;
	return \@universes;
}

sub dump_dns_record_search_section {
	my ($stab) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	# Wrap the entire search section in a bordered container
	print $cgi->start_div( {
		-style =>
		  'border: 1px solid var(--border-color-stabtab, #bbb); border-radius: 8px; padding: 15px; margin: 10px auto; max-width: fit-content;'
	} );

	# Search for a record section
	print $cgi->start_form( { -class => 'dnspage', -action => "search.pl" } );

	# If the dnsdomainid is set, add a small title, otherwise a h4 title
	if ( $stab->cgi_parse_param('dnsdomainid') ) {
		print $cgi->div( { -align => 'center' }, "Find a DNS Record" );
	} else {
		print $cgi->h4( { -align => 'center' }, "Find a DNS Record" );
	}

	# This needs to be in a table because of the javascript code for autocomplete using things like closest()
	print $cgi->table(
		{ -align => 'center' },
		$cgi->Tr( $cgi->td(

			# Add a select dropdown for the record type
			$stab->b_dropdown(
				{ -class => 'dnstypefilter' },
				undef, 'DNS_TYPE', undef, 0
			),

			# And a textfield for the record search value
			$stab->b_textfield( {
					-class           => 'dnsautocomplete dnssearch',
					-textfield_width => '80',
					-placeholder => 'Enter a keyword to search for a record...'
				},
				undef,
				'DNS_SEARCH_VALUE',
				undef
			),

			# Add a hidden field for the record id
			$cgi->hidden(
				{ -class => 'valdnsrecid', -name => 'DNS_SEARCH_RECORD_ID' }
			),

			# And finally a Search button to open the zone and go to the record page
			$cgi->submit( {
				-id    => 'gotorecord',
				-name  => "Record",
				-value => "Go to Record",

				# Disable it by default, it will be enabled when a record is selected in the dropdown
				-class       => 'off',
				-placeholder =>
				  'A record must be selected from the dropdown list on the left before clicking this button'
			} ),
			$cgi->div(
				{ -class => 'hint' },
				'(a record must be selected from the dropdown list before clicking the button above)'
			)
		) )
	);
	print $cgi->end_form;

	print $cgi->end_div;    # Close bordered container
}

sub dump_all_zones_dropdown {
	my ($stab) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	print $cgi->header(      { -type  => 'text/html' } );
	print $stab->start_html( { -title => "DNS Zones", -javascript => 'dns' } ),
	  "\n";

	# Search for a zone section
	print $cgi->start_form( { -class => 'dnspage', -action => "search.pl" } );
	print $cgi->h4( { -align => 'center' }, "Find a Zone" );
	print $cgi->table(
		$stab->build_tr( undef, undef, "b_dropdown", "Zone", 'DNS_DOMAIN_ID' ),
		$cgi->Tr( $cgi->td(
			{ -colspan => 2 },
			$cgi->checkbox( {
				-name  => 'addonly',
				-label => 'Add record (do not view zone)',
			} ),
			$cgi->div( $cgi->submit(
				-name  => "Zone",
				-value => "Go to Zone"
			) )
		) )
	);
	print $cgi->end_form;

	print $cgi->hr;

	# Search for a record section
	dump_dns_record_search_section($stab);

	print $cgi->h4( { -align => 'center' },
		$cgi->a( { -href => "addazone.pl" }, "Add A Zone" ) );

	print $cgi->hr;

	print $cgi->h4( { -align => 'center' },
		"Reconcile non-autogenerated zones" );
	print $cgi->start_form(
		{ -action => "dns-reconcile.pl", -method => 'GET' } );
	print $cgi->start_table( { -align => 'center' } );
	print $stab->build_tr( { -only_nonauto => 'yes' },
		undef, "b_dropdown", "Zone", 'DNS_DOMAIN_ID' );
	print $cgi->Tr(
		{ -align => 'center' },
		$cgi->td(
			{ -colspan => 2 },
			$cgi->submit(
				-name  => "Zone",
				-value => "Go to Zone"
			)
		)
	);
	print $cgi->end_table;
	print $cgi->end_form;

	print $cgi->end_html, "\n";
}

sub dump_all_zones {
	my ( $stab, $cgi ) = @_;

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html( { -title => "DNS Zones", -javascript => 'dns' } ),
	  "\n";

	my $q = qq{
		select 	d.dns_domain_id,
			d.dns_domain_name AS soa_name,
			du.soa_class,
			du.soa_ttl,
			du.soa_serial,
			du.soa_refresh,
			du.soa_retry,
			du.soa_expire,
			du.soa_minimum,
			du.soa_mname,
			du.soa_rname,
			du.should_generate,
			du.last_generated
		  from	dns_domain d
			join dns_domain_ip_universe du using (dns_domain_id)
		 where du.ip_universe_id = 0
		order by soa_name
	};
	my $sth = $stab->prepare($q) || return $stab->return_db_err;
	$sth->execute                || return $stab->return_db_err($sth);

	my $maxperrow = 4;
	print $cgi->start_table( { -border => 1, -align => 'center' } ), "\n";

	my $curperrow = -1;
	my $rowtxt    = "";
	while ( my $hr = $sth->fetchrow_hashref ) {
		if ( ++$curperrow == $maxperrow ) {
			$curperrow = 0;
			print $cgi->Tr($rowtxt), "\n";
			$rowtxt = "";
		}

		if ( !defined( $hr->{'LAST_GENERATED'} ) ) {
			$hr->{'LAST_GENERATED'} = $cgi->escapeHTML('<never>');
		}

		my $xbox =
		  $stab->build_checkbox( $hr, "ShouldGen", "SHOULD_GENERATE",
			'DNS_DOMAIN_ID' );

		my $opts = {};
		$opts->{-class} = 'tracked';
		$opts->{-original} =
		  defined( $hr->{'SOA_SERIAL'} )
		  ? $hr->{'SOA_SERIAL'}
		  : '';
		my $serial =
		  $stab->b_textfield( $opts, $hr, 'SOA_SERIAL', 'DNS_DOMAIN_ID' );
		$opts->{-original} =
		  defined( $hr->{'SOA_REFRESH'} )
		  ? $hr->{'SOA_REFRESH'}
		  : '';
		my $refresh =
		  $stab->b_textfield( $opts, $hr, 'SOA_REFRESH', 'DNS_DOMAIN_ID' );
		$opts->{-original} =
		  defined( $hr->{'SOA_RETRY'} )
		  ? $hr->{'SOA_RETRY'}
		  : '';
		my $retry =
		  $stab->b_textfield( $opts, $hr, 'SOA_RETRY', 'DNS_DOMAIN_ID' );
		$opts->{-original} =
		  defined( $hr->{'SOA_EXPIRE'} )
		  ? $hr->{'SOA_EXPIRE'}
		  : '';
		my $expire =
		  $stab->b_textfield( $opts, $hr, 'SOA_EXPIRE', 'DNS_DOMAIN_ID' );
		$opts->{-original} =
		  defined( $hr->{'SOA_MINIMUM'} )
		  ? $hr->{'SOA_MINIMUM'}
		  : '';
		my $minimum =
		  $stab->b_textfield( $opts, $hr, 'SOA_MINIMUM', 'DNS_DOMAIN_ID' );

		my $link = build_dns_link( $stab, $hr->{'DNS_DOMAIN_ID'} );
		my $zone =
		  $cgi->a( { -href => $link }, $hr->{'SOA_NAME'} );

		my $entry = $cgi->table(
			{ -width => '100%', -align => 'top' },
			$cgi->Tr( $cgi->td( {
					-align => 'center',
					-style => 'background: green'
				},
				$cgi->b($zone)
			) ),

			#$cgi->Tr($cgi->td("Serial: ", $serial )),
			#$cgi->Tr($cgi->td("Refresh: ", $refresh )),
			#$cgi->Tr($cgi->td("Retry: ", $retry )),
			#$cgi->Tr($cgi->td("Expire: ", $expire )),
			#$cgi->Tr($cgi->td("Minimum: ", $minimum )),
			$cgi->Tr( $cgi->td( "LastGen:", $hr->{'LAST_GENERATED'} ) ),
			$cgi->Tr( $cgi->td($xbox) )
		) . "\n";

		$rowtxt .= $cgi->td( { -valign => 'top' }, $entry );
	}
	print $cgi->Tr($rowtxt), "\n";
	print $cgi->end_table;
	print $cgi->end_html, "\n";

	$sth->finish;
}

sub build_dns_zone {
	my ( $stab, $dnsdomainid, $dnsrecid, $paging_dns_page, $paging_dns_limit,
		$ip_universe_id, $show_origin_universe )
	  = @_;

	my $cgi = $stab->cgi || die "Could not create cgi";

	# Default to showing origin universe column if not specified
	$show_origin_universe = 1 unless defined($show_origin_universe);

	my @where_condition;
	push( @where_condition, "d.dns_domain_id = :dns_domain_id" );
	if ( defined($ip_universe_id) ) {
		push( @where_condition, "d.ip_universe_id = :ip_universe_id" );
	}

	# If we have a target dns record id, we want to display the page (offset/limit) that contains it
	my $query;
	if ($dnsrecid) {
		$query = qq {
			WITH dr as (
				SELECT row_number() over() r, d.*, device_id,
					iu.ip_universe_name,
					iu_origin.ip_universe_name as origin_ip_universe_name
				FROM v_dns_sorted d
				LEFT JOIN network_interface_netblock USING (netblock_id)
				LEFT JOIN ip_universe iu ON iu.ip_universe_id = d.ip_universe_id
				LEFT JOIN ip_universe iu_origin ON iu_origin.ip_universe_id = d.origin_ip_universe_id
				WHERE } . join( "\n\t\t\t\t  AND ", @where_condition ) . qq{
			)
			SELECT * from dr
			OFFSET (SELECT floor((r-1)/:limit)*:limit FROM dr WHERE dns_record_id=:dns_record_id)
			LIMIT :limit
		};
	} else {
		$query = qq {
			SELECT row_number() over() r, d.*, device_id,
				iu.ip_universe_name,
				iu_origin.ip_universe_name as origin_ip_universe_name
			FROM	v_dns_sorted d
					LEFT JOIN network_interface_netblock USING (netblock_id)
					LEFT JOIN ip_universe iu ON iu.ip_universe_id = d.ip_universe_id
					LEFT JOIN ip_universe iu_origin ON iu_origin.ip_universe_id = d.origin_ip_universe_id
			WHERE
		} . join( "\nAND ", @where_condition ) . ' LIMIT :limit OFFSET :offset';
	}
	my $sth = $stab->prepare($query) || return $stab->return_db_err;

	$sth->bind_param( ':dns_domain_id', $dnsdomainid );
	if ( defined($ip_universe_id) ) {
		$sth->bind_param( ':ip_universe_id', $ip_universe_id );
	}
	if ($dnsrecid) {
		$sth->bind_param( ':dns_record_id', $dnsrecid );
	}

	# Bind the limit parameter
	$sth->bind_param( ':limit', $paging_dns_limit );

	# Don't use an offset if we have a target dns record id to go to
	# as it will be automatically calculated in the query above
	if ( !$dnsrecid ) {

		# Calculate the offset from the page and limit
		my $offset = ( $paging_dns_page - 1 ) * $paging_dns_limit;
		$sth->bind_param( ':offset', $offset );
	}

	$sth->execute() || return $stab->return_db_err($sth);

	my $count              = 0;
	my $offset             = -1;
	my $has_cross_universe = 0;
	while ( my $hr = $sth->fetchrow_hashref ) {

		# Get the offset of the first returned record
		if ( $offset == -1 ) {
			$offset = $hr->{'R'};
		}

		# Check if this record is from a different universe than the one it's in
		# (i.e., it was copied from another universe)
		if (   defined( $hr->{'IP_UNIVERSE_ID'} )
			&& defined( $hr->{'ORIGIN_IP_UNIVERSE_ID'} )
			&& $hr->{'ORIGIN_IP_UNIVERSE_ID'} != $hr->{'IP_UNIVERSE_ID'} )
		{
			$has_cross_universe = 1;
		}
		print build_dns_rec_Tr( $stab, $hr, ( $count++ % 2 ) ? 'even' : 'odd',
			$ip_universe_id, $show_origin_universe );
	}
	$sth->finish;

	# Return the offset of the first record in the set and whether cross-universe records were found
	return ( $offset, $has_cross_universe );
}

#
# build the row for a (possibly) editable dns record.
#
# Some things end up not being editable but just become links to other
# records.
#
sub build_dns_rec_Tr {
	my ( $stab, $hr, $basecssclass, $current_ip_universe_id,
		$show_origin_universe )
	  = @_;

	my $cssclass = 'dnsupdate';

	my $cgi = $stab->cgi || die "Could not create cgi";

	# Default to showing origin universe column if not specified
	$show_origin_universe = 1 unless defined($show_origin_universe);

	# Check if this record's origin universe matches the universe it's in
	# Records from other universes get the universe-mismatch class
	# so they can be toggled with the "Hide Others" button
	my $universe_mismatch = 0;
	if ( defined($hr) ) {
		my $ip_univ = $hr->{'IP_UNIVERSE_ID'};
		my $origin  = $hr->{'ORIGIN_IP_UNIVERSE_ID'};
		if ( defined($ip_univ) && defined($origin) && $origin != $ip_univ ) {
			$universe_mismatch = 1;
			$cssclass .= ' universe-mismatch';
		}
	}

	my $opts = {};

	if ( !defined($hr) ) {
		$opts->{-prefix} = "new_";
		$opts->{-suffix} = "_0";
	}

	$opts->{-class} = 'dnsttl tracked';
	$opts->{-original} =
	  defined( $hr->{'DNS_TTL'} ) ? $hr->{'DNS_TTL'} : '';
	my $ttl =
	  $stab->b_offalwaystextfield( $opts, $hr, 'DNS_TTL', 'DNS_RECORD_ID' );
	delete $opts->{-class};

	my $value = "";
	my $name  = "";
	my $class = "";
	my $type  = "";

	my $dnsrecid;

	if ( defined($hr) && defined( $hr->{'DNS_NAME'} ) ) {
		$name = $hr->{'DNS_NAME'};
	}

	if ( defined($hr) && $hr->{'DNS_TYPE'} =~ /^A(AAA)?$/ ) {
		$dnsrecid = $hr->{'DNS_RECORD_ID'};
	}

	my $showexcess = 1;
	my $ttlonly    = 0;

	my $canedit = 1;

	if ( !$hr->{'DNS_RECORD_ID'} ) {
		$name     = $hr->{'DNS_NAME'};
		$class    = $hr->{'DNS_CLASS'};
		$type     = $hr->{'DNS_TYPE'};
		$value    = $hr->{'DNS_VALUE'} || $hr->{'IP'};
		$ttl      = "";
		$canedit  = 0;
		$cssclass = 'dnsinfo';
	} else {
		if ( $hr->{'REF_RECORD_ID'} ) {
			$name = $hr->{'DNS_NAME'};
		} else {
			$opts->{-class} = 'dnsname tracked';
			$opts->{-original} =
			  defined( $hr->{'DNS_NAME'} )
			  ? $hr->{'DNS_NAME'}
			  : '';
			$name =
			  $stab->b_textfield( $opts, $hr, 'DNS_NAME', 'DNS_RECORD_ID' );
			delete $opts->{-class};
		}
		$opts->{-class} = 'tracked';
		$opts->{-original} =
		  defined( $hr->{'DNS_CLASS'} )
		  ? $hr->{'DNS_CLASS'}
		  : '';
		$class =
		  $stab->b_dropdown( $opts, $hr, 'DNS_CLASS', 'DNS_RECORD_ID', 1 );

		$opts->{-class} = 'dnstype tracked';
		$opts->{-original} =
		  defined( $hr->{'DNS_TYPE'} ) ? $hr->{'DNS_TYPE'} : '';
		$type = $stab->b_dropdown( $opts, $hr, 'DNS_TYPE', 'DNS_RECORD_ID', 1 );
		delete( $opts->{-class} );

		if ( defined($hr) && $hr->{'DNS_TYPE'} =~ /^A(AAA)?$/ ) {

			# [XXX] hack hack hack, needs to be fixed right so it doesn't
			# show up as a value, but the network.  I think.
			$hr->{'DNS_VALUE'} = $hr->{'IP'};
		}
	}

	if ( $hr->{'DNS_VALUE_RECORD_ID'} ) {
		if ( !$hr->{'NETBLOCK_ID'} ) {
			my $link = "./?DNS_RECORD_ID=" . $hr->{'DNS_VALUE_RECORD_ID'};
			$value = $cgi->a( { -class => 'dnsrefoutlink', -href => $link },
				$hr->{'DNS_VALUE'} );
		} else {
			my $link = "./?DNS_RECORD_ID=" . $hr->{'DNS_VALUE_RECORD_ID'};
			$value = $cgi->a( { -class => 'dnsrefoutlink', -href => $link },
				$hr->{'IP'} );
		}
		$value .= $cgi->a(
			{ -class => 'dnsrefouteditbutton', onclick => 'return(false);' },
			'' );
	} elsif ( $hr->{'DNS_RECORD_ID'} ) {
		$opts->{-class} = 'dnsvalue tracked';
		$opts->{-original} =
		  defined( $hr->{'DNS_VALUE'} )
		  ? $hr->{'DNS_VALUE'}
		  : '';
		if ( $hr->{'DNS_TYPE'} eq 'CNAME' ) {
			$opts->{-class} .= ' dnsautocomplete';
		}
		$value = $stab->b_textfield( $opts, $hr, 'DNS_VALUE', 'DNS_RECORD_ID' );
		if ($dnsrecid) {
			$value .= $cgi->a( {
					-class => 'dnsref',
					-href  => 'javascript:void(null)',
					-title => 'DNS Records Referencing This Name',
					-alt   => 'DNS Records Referencing This Name',
				},
				$cgi->hidden( {
					-class    => 'dnsrecordid',
					-name     => '',
					-value    => $dnsrecid,
					-disabled => 1
				} ),
			);
		}
		delete( $opts->{-class} );
	}

	if ( $hr->{'DEVICE_ID'} ) {
		if ( $hr->{'DNS_TYPE'} eq 'PTR' ) {
			my $link = "../device/device.pl?devid=" . $hr->{'DEVICE_ID'};
			$value = $cgi->a( { -href => $link }, $value );
		}
	}

	my $args      = { '-class' => "dnsrecord $basecssclass $cssclass" };
	my $enablebox = "";
	my $ptrbox    = "";
	my $hidden    = "";
	my $excess    = "";

	{
		my %args = (
			-name  => "DNS_VALUE_RECORD_ID_" . $hr->{'DNS_RECORD_ID'},
			-label => '',
			-class => 'valdnsrecid',
		);
		if ( $hr->{'DNS_VALUE_RECORD_ID'} ) {
			$args{-value} = $hr->{'DNS_VALUE_RECORD_ID'},;
		}
		$value .= $cgi->hidden(%args);
	}

	if ($canedit) {
		$opts->{-default} = 'Y';
		if ($showexcess) {
			if ( defined($hr) && $hr->{'DNS_RECORD_ID'} ) {
				$excess .= $cgi->checkbox( {
					-class => 'irrelevant rmrow',
					-name  => "Del_" . $hr->{'DNS_RECORD_ID'},
					-label => '',
				} );
			} else {
				$cssclass = "dnsadd";
			}
		}
		if ( $ttlonly && defined($hr) ) {
			$excess .= $cgi->hidden( {
				-name  => "ttlonly_" . $hr->{'DNS_RECORD_ID'},
				-value => 'ttlonly'
			} );
		}

		if ( $hr && $hr->{'DNS_RECORD_ID'} ) {
			$hidden = $cgi->hidden( {
				-name  => "DNS_RECORD_ID_" . $hr->{'DNS_RECORD_ID'},
				-value => $hr->{'DNS_RECORD_ID'}
			} );
		}

		$opts->{-nodiv} = 1;
		$opts->{'-class'} = 'tracked';
		$opts->{'-original'} =
		  ( $hr->{'IS_ENABLED'} eq 'Y' ) ? 'checked' : '';
		$enablebox = $excess
		  . $cgi->a( {
				-class => 'rmrow',
				-title => 'Delete this record'
			},
			''
		  )
		  . $stab->build_checkbox( $opts, $hr, "", "IS_ENABLED",
			'DNS_RECORD_ID' );
		delete( $opts->{-default} );
		delete( $opts->{-nodiv} );

		$ptrbox = "";
		if (   $hr
			&& !$hr->{'DNS_VALUE_RECORD_ID'}
			&& $hr->{'DNS_TYPE'} =~ /^A(AAA)?$/ )
		{
			$opts->{-class} = "ptrbox tracked";
			$opts->{-original} =
			  ( $hr->{'SHOULD_GENERATE_PTR'} eq 'Y' ) ? 'checked' : '';
			$ptrbox =
			  $stab->build_checkbox( $opts,
				$hr, "", "SHOULD_GENERATE_PTR", 'DNS_RECORD_ID' );
			delete( $opts->{-class} );
		}

		# for SRV records, it is necessary to prepend the
		# protocol and service name to the name
		if ( $hr && $hr->{'DNS_TYPE'} eq 'SRV' ) {

			# Build the SRV service field
			$opts->{-class}       = 'srvname tracked';
			$opts->{-original}    = $hr->{'DNS_SRV_SERVICE'} || '__unknown__';
			$opts->{-placeholder} = 'service';
			my $srvname = $stab->b_dropdown( $opts, $hr, 'DNS_SRV_SERVICE',
				'DNS_RECORD_ID', 1 );

			# Build the SRV protocol field
			$opts->{-class}       = 'srvproto tracked';
			$opts->{-original}    = $hr->{'DNS_SRV_PROTOCOL'} || '__unknown__';
			$opts->{-placeholder} = 'protocol';
			my $srvproto =
			  $stab->b_nondbdropdown( $opts, $hr, 'DNS_SRV_PROTOCOL',
				'DNS_RECORD_ID' );

			$name = $srvname . $srvproto . $name;

			# Build the SRV priority field
			$opts->{-class} = 'srvnum tracked';

			# If $hr->{'DNS_PRIORITY'}) is defined, use it, otherwise use ''
			# It can be zero, so we have to use defined() instead of just $hr->{'DNS_PRIORITY'} || ''
			$opts->{-original} =
			  defined( $hr->{'DNS_PRIORITY'} )
			  ? $hr->{'DNS_PRIORITY'}
			  : '';
			$opts->{-placeholder} = 'priority';
			my $srvpriority =
			  $stab->b_textfield( $opts, $hr, 'DNS_PRIORITY', 'DNS_RECORD_ID' );

			# Build the SRV weight field
			$opts->{-class} = 'srvnum tracked';
			$opts->{-original} =
			  defined( $hr->{'DNS_SRV_WEIGHT'} )
			  ? $hr->{'DNS_SRV_WEIGHT'}
			  : '';
			$opts->{-placeholder} = 'weight';
			my $srvweight = $stab->b_textfield( $opts, $hr, 'DNS_SRV_WEIGHT',
				'DNS_RECORD_ID' );

			# Build the SRV port field
			$opts->{-class} = 'srvnum tracked';
			$opts->{-original} =
			  defined( $hr->{'DNS_SRV_PORT'} )
			  ? $hr->{'DNS_SRV_PORT'}
			  : '';
			$opts->{-placeholder} = 'port';
			my $srvport =
			  $stab->b_textfield( $opts, $hr, 'DNS_SRV_PORT', 'DNS_RECORD_ID' );

			$value = $srvpriority . $srvweight . $srvport . $value;

			delete( $opts->{-class} );

			# MX record
		} elsif ( $hr && $hr->{'DNS_TYPE'} eq 'MX' ) {
			$opts->{-class} = 'srvnum tracked';
			$opts->{-original} =
			  defined( $hr->{'DNS_PRIORITY'} )
			  ? $hr->{'DNS_PRIORITY'}
			  : '';
			$opts->{-placeholder} = 'priority';
			$value =
			  $stab->b_textfield( $opts, $hr, 'DNS_PRIORITY', 'DNS_RECORD_ID' )
			  . $value;
			delete( $opts->{-class} );
		}

		if ($hr) {
			$args->{'-id'} = $hr->{'DNS_RECORD_ID'};
		} else {
			$args->{'-id'} = "0";
		}
	} else {    # uneditable.
		$ttl = "";
	}

	# Add ip_universe_id column
	my $universe_col = '';
	if ( defined($hr) && defined( $hr->{'ORIGIN_IP_UNIVERSE_NAME'} ) ) {
		$universe_col = $hr->{'ORIGIN_IP_UNIVERSE_NAME'};
	}

	my @cells = (
		$cgi->td( $hidden, $enablebox ), $cgi->td($name),
		$cgi->td($ttl),                  $cgi->td($class),
		$cgi->td($type),                 $cgi->td($value),
		$cgi->td( { -class => 'ptrtd' }, $ptrbox ),
	);
	if ($show_origin_universe) {
		push @cells, $cgi->td( { -class => 'universeid' }, $universe_col );
	}

	return $cgi->Tr( $args, @cells );
}

sub get_domain_from_record {
	my ( $stab, $dnsdomainid, $dnsrecid ) = @_;

	my $dnsname;

	# Don't we have a dns domain id?
	if ( !$dnsdomainid ) {

		# Don't we have a dns record id?
		if ( !$dnsrecid ) {
			return $stab->error_return("Must specify a domain to examine");
		}

		# We have no domain id but a dns record id
		my $dns = $stab->get_dns_record_from_id($dnsrecid);
		if ( !$dns ) {
			return $stab->error_return(
				"Must specify a valid record to examine");
		}
		$dnsname     = $dns->{'DNS_NAME'};
		$dnsdomainid = $dns->{'DNS_DOMAIN_ID'};
	}

	return ( $dnsname, $dnsdomainid );
}

sub dump_secondary_domain_section {
	my ( $stab, $dnsdomainid, $hr ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	# Query the property table to find the Secondary property
	# property_type = 'DNSZonegen', property_name = 'Secondary'
	# Join through dns_domain_collection_dns_dom to find matching domain
	my $q = qq{
		select p.property_id,
			p.property_value_nblk_coll_id,
			nc.netblock_collection_name,
			nc.netblock_collection_type
		  from property p
			join dns_domain_collection_dns_dom ddcd
				on ddcd.dns_domain_collection_id = p.dns_domain_collection_id
			left join netblock_collection nc
				on nc.netblock_collection_id = p.property_value_nblk_coll_id
		 where p.property_type = 'DNSZonegen'
		   and p.property_name = 'Secondary'
		   and ddcd.dns_domain_id = :dns_domain_id
	};

	my $sth = $stab->prepare($q) || return $stab->return_db_err;
	$sth->bind_param( ':dns_domain_id', $dnsdomainid );
	$sth->execute || return $stab->return_db_err($sth);

	my @secondaries;
	while ( my $row = $sth->fetchrow_hashref ) {
		push(
			@secondaries,
			{
				property_id                 => $row->{'PROPERTY_ID'},
				property_value_nblk_coll_id =>
				  $row->{'PROPERTY_VALUE_NBLK_COLL_ID'},
				netblock_collection_name => $row->{'NETBLOCK_COLLECTION_NAME'},
				netblock_collection_type => $row->{'NETBLOCK_COLLECTION_TYPE'}
			}
		);
	}
	$sth->finish;

	# Build the secondary domain information HTML
	my $html = '';
	$html .= $cgi->hr;
	$html .= $cgi->h3( { -align => 'center' }, "Secondary DNS Zone" );
	$html .= $cgi->div( { -class => 'centered', -style => 'margin: 20px 0;' },
		$cgi->p("This is a secondary DNS zone.") );

	if (@secondaries) {
		$html .= $cgi->div( { -class => 'centered', -style => 'margin: 20px 0;' },
			$cgi->h4("Secondaries From:") );

		$html .= $cgi->start_table(
			{ -class => 'secondary-info', -align => 'center', -border => 1 } );
		$html .= $cgi->Tr( $cgi->th( [ 'Netblock Collection', 'Type' ] ) );

		foreach my $sec (@secondaries) {
			my $nc_id   = $sec->{property_value_nblk_coll_id};
			my $nc_name = $sec->{netblock_collection_name} || 'Unknown';
			my $nc_type = $sec->{netblock_collection_type} || 'Unknown';

			my $link_text = "$nc_name:$nc_type";
			my $link_url =
			  "../netblock/collection/?NETBLOCK_COLLECTION_ID=$nc_id";

			$html .= $cgi->Tr(
				$cgi->td( $cgi->a( { -href => $link_url }, $link_text ) ),
				$cgi->td($nc_type) );
		}

		$html .= $cgi->end_table;
	} else {
		$html .= $cgi->div(
			{ -class => 'centered', -style => 'margin: 20px 0;' },
			$cgi->p(
				{ -style => 'color: orange;' },
				"Warning: No secondary configuration found for this zone."
			)
		);
	}

	return $html;
}

sub dump_soa_section {
	my ( $stab, $dnsdomainid, $dnsrecid, $dnsname, $addonly, $ip_universe_id,
		$print_header )
	  = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	# Default to printing header unless explicitly disabled
	if ( !defined($print_header) ) {
		$print_header = 1;
	}

	my @where_condition;
	push( @where_condition, "d.dns_domain_id = :dns_domain_id" );
	push( @where_condition, "du.ip_universe_id = :ip_universe_id" );

	my $q = qq{
		select 	d.dns_domain_id,
			d.dns_domain_name AS soa_name,
			d.dns_domain_type,
			du.soa_class,
			du.soa_ttl,
			du.soa_serial,
			du.soa_refresh,
			du.soa_retry,
			du.soa_expire,
			du.soa_minimum,
			du.soa_mname,
			du.soa_rname,
			du.should_generate,
			du.ip_universe_id,
			d.parent_dns_domain_id,
			parent_soa_name,
			du.last_generated,
			vdt.can_generate
		  from dns_domain d
			join dns_domain_ip_universe du using (dns_domain_id)
			left join val_dns_domain_type vdt on vdt.dns_domain_type = d.dns_domain_type
			left join (
				select dns_domain_id as parent_dns_domain_id,dns_domain_name as parent_soa_name
				from dns_domain
			) d2 USING(parent_dns_domain_id)
	};
	if ( scalar @where_condition ) {
		$q .= "WHERE " . join( "\nAND ", @where_condition );
	}
	my $sth = $stab->prepare($q) || return $stab->return_db_err;

	if ($dnsdomainid) {
		$sth->bind_param( ':dns_domain_id', $dnsdomainid )
		  || return $stab->return_db_err();
	}
	if ( defined($ip_universe_id) ) {
		$sth->bind_param( ':ip_universe_id', $ip_universe_id )
		  || return $stab->return_db_err();
	}

	$sth->execute || return $stab->return_db_err($sth);

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;

	if ( !defined($hr) ) {
		$stab->error_return("Unknown Domain");
	}

	my $title = $hr->{'SOA_NAME'};
	if ($dnsname) {
		$title = "$dnsname.$title";
	}

	if ( $hr->{'SHOULD_GENERATE'} eq 'Y' ) {
		$title .= " (Auto Generated) ";
	}

	if ($addonly) {
		$title = "Add record to " . $title;
	}

	# Stop here if we are in addonly mode
	if ($addonly) {
		if ($print_header) {
			print $cgi->header( { -type => 'text/html' } ),
			  $stab->start_html( { -title => $title, -javascript => 'dns' } ), "\n";
		}
		return 0;
	}

	# Handle secondary domains differently
	my $secondary_html;
	if ( $hr->{'DNS_DOMAIN_TYPE'} && $hr->{'DNS_DOMAIN_TYPE'} eq 'secondary' ) {
		$secondary_html = dump_secondary_domain_section( $stab, $dnsdomainid, $hr );
		if ( !defined($secondary_html) ) {
			return undef;
		}
		if ($print_header) {
			print $cgi->header( { -type => 'text/html' } ),
			  $stab->start_html( { -title => $title, -javascript => 'dns' } ), "\n";
		}
		print $secondary_html;
		return 1;
	}

	if ($print_header) {
		print $cgi->header( { -type => 'text/html' } ),
		  $stab->start_html( { -title => $title, -javascript => 'dns' } ), "\n";
	}

	my $lastgen = 'never';
	if ( defined( $hr->{'LAST_GENERATED'} ) ) {
		$lastgen = $hr->{'LAST_GENERATED'};
	}

	my $soatable = "";
	my $parlink;
	my $zonelink = "";

	$parlink = $cgi->span( $cgi->b("Parent: ") . $parlink ) if ($parlink);
	my $nblink = build_reverse_association_section( $stab, $dnsdomainid );

	print $cgi->start_form(
		{ -action => "write/update_domain.pl", -method => 'POST' } );
	print $cgi->hidden(
		-name    => 'DNS_DOMAIN_ID',
		-default => $hr->{'DNS_DOMAIN_ID'}
	);
	print $cgi->hidden(
		-name    => 'IP_UNIVERSE_ID',
		-default => $hr->{'IP_UNIVERSE_ID'}
	);
	print $cgi->hr;

	# Build the generation table HTML if this domain type can be generated
	my $gentable = "";
	if ( $hr->{'CAN_GENERATE'} && $hr->{'CAN_GENERATE'} eq 'Y' ) {
		my $t =
		  $cgi->Tr( $cgi->td( { -colspan => 2 }, "Last Generated: $lastgen" ) );
		my $autogen = "";

		if ( $hr->{'SHOULD_GENERATE'} eq 'Y' ) {
			$autogen = "Turn Off Autogen";
		} else {
			$autogen = "Turn On Autogen";
		}
		$t .= $cgi->Tr(
			{ -align => 'center' },
			$cgi->td( $cgi->submit( {
				-align => 'center',
				-name  => "AutoGen",
				-value => $autogen
			} ) ),
			$cgi->td( $cgi->submit( {
				-align => 'center',
				-name  => "Nameservers",
				-value => "Reset to Default Nameservers",
			} ) )
		);

		$gentable = $cgi->table( { -class => 'dnsgentable' }, $t );
	}

	$parlink = "--none--";
	if ( $hr->{'PARENT_DNS_DOMAIN_ID'} ) {
		my $url = build_dns_link( $stab, $hr->{'PARENT_DNS_DOMAIN_ID'} );
		my $parent =
		  ( $hr->{'PARENT_SOA_NAME'} )
		  ? $hr->{'PARENT_SOA_NAME'}
		  : "unnamed zone";
		$parlink = $cgi->a( { -href => $url }, $parent );
	}
	$parlink = "Parent: $parlink";

	if ( $nblink && length($nblink) ) {
		$nblink = $cgi->br($nblink);
	}

	# Add toggle button for domain information section
	print $cgi->div(
		{ -class => 'centered', -style => 'margin: 10px 0;' },
		$cgi->button( {
			-type    => 'button',
			-id      => 'toggle-domain-info',
			-onclick => 'toggleDomainInfo()',
			-value   => 'Show Domain Information'
		} )
	);

	# Create a container div to hold generation table and SOA section side by side
	my $parlink_div =
	  $cgi->div( { -class => 'centered' }, $parlink, $nblink, $zonelink );
	my $soa_header  = $stab->zone_header( $hr, 'update' );
	my $soa_buttons = $cgi->div(
		{ -class => 'centered' },
		$cgi->reset( {
			-class   => '',
			-onclick =>
			  "resetForm( this.form, 'All pending SOA changes will be cancelled. Are you sure?' ); return false;",
			-name  => "cancel",
			-value => "Cancel All SOA Changes"
		} )
		  . $cgi->submit( {
			-class => '',
			-name  => "SOA",
			-value => "Submit SOA Changes"
		  } )
	);

	# Wrap domain information in a collapsible div (hidden by default) with double border
	print $cgi->start_div( {
		-id    => 'domain-info-section',
		-style =>
		  'display: none; border: 3px double var(--border-color-stabtab, #bbb); border-radius: 8px; padding: 20px; margin: 10px 0;'
	} );

	if ($gentable) {
		print $cgi->div( {
				-style =>
				  'display: flex; gap: 20px; align-items: center; justify-content: space-around;'
			},
			$cgi->div( { -style => 'flex: 0 0 auto;' }, $gentable ),
			$cgi->div(
				{ -style => 'flex: 0 1 auto;' },
				$parlink_div, $soa_header, $soa_buttons
			)
		);
	} else {
		print $parlink_div;
		print $soa_header;
		print $soa_buttons;
	}

	print $cgi->end_div;    # Close domain-info-section

	print $cgi->end_form;

	# Add JavaScript for toggle functionality
	print $cgi->script(
		{ -type => 'text/javascript' }, qq{
		function toggleDomainInfo() {
			var section = document.getElementById('domain-info-section');
			var button = document.getElementById('toggle-domain-info');
			if (section.style.display === 'none') {
				section.style.display = 'block';
				button.value = 'Hide Domain Information';
			} else {
				section.style.display = 'none';
				button.value = 'Show Domain Information';
			}
		}
	}
	);

	return 0;
}

sub dump_records_section {
	my (
		$stab,           $dnsdomainid,          $dnsrecid,
		$addonly,        $paging_dns_page,      $paging_dns_limit,
		$ip_universe_id, $show_origin_universe, $use_tabs
	) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	# Default to showing origin universe column if not specified
	$show_origin_universe = 1 unless defined($show_origin_universe);

	#
	# second form, second table
	#
	print $cgi->start_form( { -action => "update_dns.pl", -method => 'POST' } );
	print $cgi->start_table( { -class => 'dnstable' } );
	print $cgi->hidden(
		-name    => 'DNS_DOMAIN_ID',
		-default => $dnsdomainid
	);
	print $cgi->hidden(
		-name    => 'IP_UNIVERSE_ID',
		-default => $ip_universe_id
	);

	# Dump the paging header, but only if we're not just adding a record without displaying the rest of the zone
	if ( !$addonly ) {

		# Get the total number of records in the zone
		my $count =
		  get_dns_records_count( $stab, $dnsdomainid, $ip_universe_id );

		# The function returns the validated page, if it's out of range
		$paging_dns_page =
		  validate_page( $stab, $dnsdomainid, $count, $paging_dns_page,
			$paging_dns_limit );

		# We just add a paging container div to the top of the tabl
		# It will be automatically populated by a paging.js function
		# The required parameters are the count, limit, and offset
		# Add ip_universe_id to make the ID unique per tab (only when there are multiple universes)
		# When there's only one universe, use 'paging-dns' to match parameter names
		my $paging_id =
		  $use_tabs && defined($ip_universe_id)
		  ? "paging-dns-$ip_universe_id"
		  : 'paging-dns';
		my $paging_colspan = $show_origin_universe ? '8' : '7';
		print $cgi->Tr( $cgi->td(
			{ -colspan => $paging_colspan },
			$cgi->div( {
					-id           => $paging_id,
					-class        => 'paging-container',
					'-data-count' => $count,
					'-data-page'  => $paging_dns_page,
					'-data-limit' => $paging_dns_limit,
				},
				''
			)
		) );
	}

	# Print the table header
	my @headers =
	  ( 'Enable', 'Record', 'TTL', 'Class', 'Type', 'Value', 'PTR' );
	if ($show_origin_universe) {
		push @headers, 'Origin Universe';
	}
	print $cgi->Tr( $cgi->th( \@headers ) );

	my $colspan = $show_origin_universe ? '8' : '7';
	print $cgi->Tr( $cgi->td(
		{ -colspan => $colspan, -align => 'left' },
		$cgi->a( {
				-onclick     => 'return false;',
				-class       => 'adddnsrec plusbutton',
				-placeholder => 'Create new DNS record'
			},
		)
	) );

	my $offset             = -1;
	my $has_cross_universe = 0;
	if ( !$addonly ) {
		( $offset, $has_cross_universe ) =
		  build_dns_zone( $stab, $dnsdomainid, $dnsrecid, $paging_dns_page,
			$paging_dns_limit, $ip_universe_id, $show_origin_universe );
	}

	print $cgi->end_table;

	# Print a javascript global variable that contains the value of the offset
	# Make it tab-specific to avoid conflicts when multiple tabs exist
	if ( $offset != -1 ) {
		my $paging_id =
		  $use_tabs && defined($ip_universe_id)
		  ? "paging-dns-$ip_universe_id"
		  : 'paging-dns';
		print $cgi->script( { -type => 'text/javascript' },
			"window['pagingOffset_" . $paging_id . "'] = $offset;" );
	}

	# Add a data attribute to indicate if cross-universe records exist
	# This will be used by JavaScript to show/hide the toggle button
	if ($has_cross_universe) {
		my $paging_id =
		  $use_tabs && defined($ip_universe_id)
		  ? "paging-dns-$ip_universe_id"
		  : 'paging-dns';
		print $cgi->script( { -type => 'text/javascript' },
			"window['hasCrossUniverse_" . $paging_id . "'] = true;" );
	}

	# Add a cancel (reset) button
	print $cgi->div(
		{ -class => 'centered' },
		$cgi->reset( {
			-class   => '',
			-onclick =>
			  "resetForm( this.form, 'All pending DNS record changes will be cancelled. Are you sure?' ); return false;",
			-name  => "cancel",
			-value => "Cancel All DNS Record Changes"
		} )
		  . $cgi->submit( {
			-class => '',
			-name  => "Records",
			-value => "Submit DNS Record Changes"
		  } )
	);
	print $cgi->end_form;
}

sub dump_zone {
	my ( $stab, $dnsdomid, $dnsrecid, $addonly, $paging_dns_page,
		$paging_dns_limit, $requested_ip_universe_id )
	  = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	# Validate the domain from the record if needed, and get the dnsname
	my ( $dnsname, $dnsdomainid ) =
	  get_domain_from_record( $stab, $dnsdomid, $dnsrecid );

	# Get IP universes for this domain
	my $universes = get_dns_domain_ip_universes( $stab, $dnsdomainid );

	# If there's only one universe or no universes, don't show tabs
	if ( !$universes || scalar(@$universes) <= 1 ) {
		my $ip_universe_id =
			$universes && scalar(@$universes) == 1
		  ? $universes->[0]->{ip_universe_id}
		  : 0;

		# Check if there are cross-universe records to determine if we should show the origin universe column
		my $show_origin_universe =
		  check_has_cross_universe_records( $stab, $dnsdomainid,
			$ip_universe_id );

		# Dump the soa section (includes header)
		my $is_secondary =
		  dump_soa_section( $stab, $dnsdomainid, $dnsrecid, $dnsname, $addonly,
			$ip_universe_id, 1 );

		# Don't show records section for secondary domains
		if ($is_secondary) {
			if ($dnsrecid) {
				print $cgi->script(
					{ -type => 'text/javascript' },
					"var dnsrecid = $dnsrecid;"
				);
			}
			return;
		}

		# Search for a record section
		if ( !$addonly ) {
			dump_dns_record_search_section($stab);
		}

		# Dump the records section (not using tabs in single-universe mode)
		dump_records_section(
			$stab,           $dnsdomainid,          $dnsrecid,
			$addonly,        $paging_dns_page,      $paging_dns_limit,
			$ip_universe_id, $show_origin_universe, 0
		);

		# Add a javascript snippet that contains the value of dnsrecid as a global variable
		# It will be used in dns-utils.js / scrollToTargetDNSRecord() to scroll to the record when the page is loaded
		if ($dnsrecid) {
			print $cgi->script( { -type => 'text/javascript' },
				"var dnsrecid = $dnsrecid;" );
		}
		return;
	}

	# Multiple universes - need to print header first, then build tabs
	# Get the first universe to extract domain info for the title
	my $first_universe_id = $universes->[0]->{ip_universe_id};

	# Fetch domain info for title
	my $q = qq{
		select d.dns_domain_name AS soa_name, du.should_generate
		  from dns_domain d
			join dns_domain_ip_universe du using (dns_domain_id)
		 where d.dns_domain_id = ?
		   and du.ip_universe_id = ?
		limit 1
	};
	my $sth = $stab->prepare($q) || return $stab->return_db_err;
	$sth->execute( $dnsdomainid, $first_universe_id )
	  || return $stab->return_db_err($sth);
	my $domain_info = $sth->fetchrow_hashref;
	$sth->finish;

	my $title = $domain_info->{'SOA_NAME'} || "DNS Zone";
	if ($dnsname) {
		$title = "$dnsname.$title";
	}
	if (   $domain_info->{'SHOULD_GENERATE'}
		&& $domain_info->{'SHOULD_GENERATE'} eq 'Y' )
	{
		$title .= " (Auto Generated)";
	}
	if ($addonly) {
		$title = "Add record to " . $title;
	}

	# Print header once
	print $cgi->header(      { -type  => 'text/html' } ),                  "\n";
	print $stab->start_html( { -title => $title, -javascript => 'dns' } ), "\n";

	# Multiple universes - create tabs
	my @tabs;
	my $count = 0;

	# Validate the requested universe and determine which tab should be active
	my $active_tab_index = 0;
	if ( defined($requested_ip_universe_id) ) {
		for ( my $i = 0 ; $i < scalar(@$universes) ; $i++ ) {
			if ( $universes->[$i]->{ip_universe_id} ==
				$requested_ip_universe_id )
			{
				$active_tab_index = $i;
				last;
			}
		}
	}

	foreach my $universe (@$universes) {
		my $ip_universe_id   = $universe->{ip_universe_id};
		my $ip_universe_name = $universe->{ip_universe_name};

		# Extract paging parameters specific to this universe
		my $universe_page_param  = "paging-dns-${ip_universe_id}-page";
		my $universe_limit_param = "paging-dns-${ip_universe_id}-limit";
		my $universe_paging_page =
		  $stab->cgi_parse_param($universe_page_param) || '1';
		my $universe_paging_limit =
		  $stab->cgi_parse_param($universe_limit_param) || '200';

		# Capture output for this tab
		my $tab_content = '';
		{
			local *STDOUT;
			open( STDOUT, '>', \$tab_content )
			  or die "Cannot redirect STDOUT: $!";

			# Dump the soa section (without header since we already printed it)
			my $is_secondary =
			  dump_soa_section( $stab, $dnsdomainid, $dnsrecid, $dnsname,
				$addonly, $ip_universe_id, 0 );

			# Don't show records section for secondary domains
			if ( !$is_secondary ) {

				# Search for a record section
				if ( !$addonly ) {
					dump_dns_record_search_section($stab);
				}

				# Dump the records section (using tabs in multi-universe mode)
				dump_records_section( $stab, $dnsdomainid, $dnsrecid, $addonly,
					$universe_paging_page, $universe_paging_limit,
					$ip_universe_id, 1, 1 );
			}

			close(STDOUT);
		}

		# Create tab ID
		my $tab_id = "universe_${ip_universe_id}";

		push(
			@tabs,
			{
				id      => $tab_id,
				name    => $ip_universe_name,
				content => $tab_content
			}
		);
	}

	# Build the tab bar
	my $tabbar = '';
	$count = 0;
	for my $h (@tabs) {
		my $class = 'stabtab';
		if ( $count++ == $active_tab_index ) {
			$class .= ' stabtab_on';
		} else {
			$class .= ' stabtab_off';
		}
		my $id = $h->{id};
		$tabbar .= $cgi->a( {
				-class => $class,
				-id    => "tab$id",
			},
			$h->{name}
		);
	}

	# Build the tab content
	$count = 0;
	my $tabcontent = '';
	for my $h (@tabs) {
		my $id    = $h->{id};
		my $class = 'stabtab';
		if ( $count++ == $active_tab_index ) {
			$class .= ' stabtab_on';
		}
		$tabcontent .=
		  $cgi->div( { -class => $class, id => "tab$id" }, $h->{content} );
	}

	print $cgi->div(
		{ -class => 'stabtabset' },
		$cgi->div( { -class => 'stabtabbar' },     $tabbar ),
		$cgi->div( { -class => 'stabtabcontent' }, $tabcontent ),
	);

	# Add a javascript snippet that contains the value of dnsrecid as a global variable
	# It will be used in dns-utils.js / scrollToTargetDNSRecord() to scroll to the record when the page is loaded
	if ($dnsrecid) {
		print $cgi->script( { -type => 'text/javascript' },
			"var dnsrecid = $dnsrecid;" );
	}

	print $cgi->end_html, "\n";
}

# Function to get the total number of records in the zone
sub check_has_cross_universe_records {
	my ( $stab, $dnsdomainid, $ip_universe_id ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my @where_condition;
	push( @where_condition, "d.dns_domain_id = :dns_domain_id" );
	if ( defined($ip_universe_id) ) {
		push( @where_condition, "d.ip_universe_id = :ip_universe_id" );
	}
	push( @where_condition, "d.origin_ip_universe_id IS NOT NULL" );
	push( @where_condition, "d.origin_ip_universe_id != d.ip_universe_id" );

	# Check if there are any cross-universe records
	my $sth = $stab->prepare(
		qq{
		SELECT count(*)
		FROM v_dns_sorted d
		} . "WHERE " . join( "\nAND ", @where_condition )
	) || return $stab->return_db_err;

	$sth->bind_param( ':dns_domain_id', $dnsdomainid );
	if ( defined($ip_universe_id) ) {
		$sth->bind_param( ':ip_universe_id', $ip_universe_id );
	}
	$sth->execute() || return $stab->return_db_err($sth);
	my ($count) = $sth->fetchrow_array;
	$sth->finish;

	return $count > 0 ? 1 : 0;
}

sub get_dns_records_count {
	my ( $stab, $dnsdomainid, $ip_universe_id ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my @where_condition;
	push( @where_condition, "d.dns_domain_id = :dns_domain_id" );
	if ( defined($ip_universe_id) ) {
		push( @where_condition, "d.ip_universe_id = :ip_universe_id" );
	}

	# Get the total number of records in the zone
	my $sth = $stab->prepare(
		qq{
		SELECT count(*)
		FROM v_dns_sorted d
		LEFT JOIN network_interface_netblock USING (netblock_id)
		} . "WHERE " . join( "\nAND ", @where_condition )
	) || return $stab->return_db_err;

	$sth->bind_param( ':dns_domain_id', $dnsdomainid );
	if ( defined($ip_universe_id) ) {
		$sth->bind_param( ':ip_universe_id', $ip_universe_id );
	}
	$sth->execute() || return $stab->return_db_err($sth);
	my ($count) = $sth->fetchrow_array;
	$sth->finish;

	$count;
}

# Function used to validate the paging offset parameter
sub validate_page {
	my ( $stab, $dnsdomainid, $count, $paging_dns_page, $paging_dns_limit ) =
	  @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	# Calculate the number of pages
	my $pages = ceil( $count / $paging_dns_limit );

	# Make sure the page is within the range of pages
	$paging_dns_page = $pages if $paging_dns_page > $pages;
	$paging_dns_page = 1      if $paging_dns_page < 1;

	$paging_dns_page;
}

sub build_reverse_association_section {
	my ( $stab, $domid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $q = qq{
		select  nbr.netblock_id,
			net_manip.inet_dbtop(nb.ip_address),
			masklen(nb.ip_address)
		  from  dns_record d
			inner join netblock nb
				on nb.netblock_id = d.netblock_id
			left join netblock nbr
				on nbr.ip_address = nb.ip_address
				and masklen(nbr.ip_address)
					= masklen(nb.ip_address)
				and nbr.netblock_type = 'default'
		 where  d.dns_type = 'REVERSE_ZONE_BLOCK_PTR'
		   and  d.dns_domain_id = ?

	};
	my $sth = $stab->prepare($q) || return $stab->return_db_err();
	$sth->execute($domid)        || return $stab->return_db_err($sth);

	#
	# Print a useful /24 if it exists, otherwise, just show
	# what it is.
	#
	my $linkage = "";
	while ( my ( $nbid, $ip, $bits ) = $sth->fetchrow_array ) {
		if ($nbid) {
			$linkage =
			  $cgi->a( { -href => "../netblock/?nblkid=$nbid" }, "$ip/$bits" );
		} else {
			$linkage = "$ip/$bits";
		}
	}
	$linkage = $cgi->b("Reverse Linked Netblock:") . $linkage if ($linkage);
	$sth->finish;
	$linkage;
}

sub build_dns_link {
	my ( $stab, $dnsdomainid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $n = new CGI($cgi);
	$n->param( 'dnsdomainid', $dnsdomainid );

	# Remove the paging parameters paging-dns-page and paging-dns-limit
	$n->delete('paging-dns-page');
	$n->delete('paging-dns-limit');
	$n->self_url;
}
