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
use JazzHands::Common qw(_dbx);
use Net::IP;

do_dns_toplevel();

sub do_dns_toplevel {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";

	my $dnsdomid  = $stab->cgi_parse_param('dnsdomainid');
	my $dnsrecid  = $stab->cgi_parse_param('DNS_RECORD_ID');
	my $dnssearch = $stab->cgi_parse_param('dnssearch');

	my $paging_dns_page  = $stab->cgi_parse_param('paging-dns-page')  || '1';
	my $paging_dns_limit = $stab->cgi_parse_param('paging-dns-limit') || '200';

	my $addonly = $stab->cgi_parse_param('addonly');

	# Do we have to search for a record?
	if ($dnssearch) {
		my $dnsrec = $stab->get_dns_record_from_id($dnssearch);
		if ($dnsrec) {
			$dnsdomid = $dnsrec->{ _dbx('DNS_DOMAIN_ID') };
			$dnsrecid = $dnsrec->{ _dbx('DNS_RECORD_ID') };
		}
	}

	if ($dnsrecid) {
		dump_zone( $stab, $dnsdomid, $dnsrecid, $addonly, $paging_dns_page,
			$paging_dns_limit );
	} elsif ( !defined($dnsdomid) ) {
		dump_all_zones_dropdown($stab);
	} else {
		dump_zone( $stab, $dnsdomid, undef, $addonly, $paging_dns_page,
			$paging_dns_limit );
	}
	undef $stab;
}

sub dump_dns_record_search_section {
	my ($stab) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

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

	print $cgi->hr;
}

sub dump_all_zones_dropdown {
	my ($stab) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	print $cgi->header( { -type => 'text/html' } ), "\n";
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
		select 	dns_domain_id,
			soa_name,
			soa_class,
			soa_ttl,
			soa_serial,
			soa_refresh,
			soa_retry,
			soa_expire,
			soa_minimum,
			soa_mname,
			soa_rname,
			should_generate,
			last_generated
		  from	v_dns_domain_nouniverse
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

		if ( !defined( $hr->{ _dbx('LAST_GENERATED') } ) ) {
			$hr->{ _dbx('LAST_GENERATED') } =
			  $cgi->escapeHTML('<never>');
		}

		my $xbox =
		  $stab->build_checkbox( $hr, "ShouldGen", "SHOULD_GENERATE",
			'DNS_DOMAIN_ID' );

		my $opts = {};
		$opts->{-class} = 'tracked';
		$opts->{-original} =
		  defined( $hr->{ _dbx('SOA_SERIAL') } )
		  ? $hr->{ _dbx('SOA_SERIAL') }
		  : '';
		my $serial =
		  $stab->b_textfield( $opts, $hr, 'SOA_SERIAL', 'DNS_DOMAIN_ID' );
		$opts->{-original} =
		  defined( $hr->{ _dbx('SOA_REFRESH') } )
		  ? $hr->{ _dbx('SOA_REFRESH') }
		  : '';
		my $refresh =
		  $stab->b_textfield( $opts, $hr, 'SOA_REFRESH', 'DNS_DOMAIN_ID' );
		$opts->{-original} =
		  defined( $hr->{ _dbx('SOA_RETRY') } )
		  ? $hr->{ _dbx('SOA_RETRY') }
		  : '';
		my $retry =
		  $stab->b_textfield( $opts, $hr, 'SOA_RETRY', 'DNS_DOMAIN_ID' );
		$opts->{-original} =
		  defined( $hr->{ _dbx('SOA_EXPIRE') } )
		  ? $hr->{ _dbx('SOA_EXPIRE') }
		  : '';
		my $expire =
		  $stab->b_textfield( $opts, $hr, 'SOA_EXPIRE', 'DNS_DOMAIN_ID' );
		$opts->{-original} =
		  defined( $hr->{ _dbx('SOA_MINIMUM') } )
		  ? $hr->{ _dbx('SOA_MINIMUM') }
		  : '';
		my $minimum =
		  $stab->b_textfield( $opts, $hr, 'SOA_MINIMUM', 'DNS_DOMAIN_ID' );

		my $link =
		  build_dns_link( $stab, $hr->{ _dbx('DNS_DOMAIN_ID') } );
		my $zone =
		  $cgi->a( { -href => $link }, $hr->{ _dbx('SOA_NAME') } );

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
			$cgi->Tr( $cgi->td( "LastGen:", $hr->{ _dbx('LAST_GENERATED') } ) ),
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
	my ( $stab, $dnsdomainid, $dnsrecid, $paging_dns_page, $paging_dns_limit )
	  = @_;

	my $cgi = $stab->cgi || die "Could not create cgi";

	my @where_condition;
	push( @where_condition, "dns_domain_id = :dns_domain_id" );

	# If we have a target dns record id, we want to display the page (offset/limit) that contains it
	my $query;
	if ($dnsrecid) {
		$query = qq {
			WITH dr as (
				SELECT row_number() over() r, d.*, device_id
				FROM v_dns_sorted d
				LEFT JOIN network_interface_netblock USING (netblock_id)
				WHERE dns_domain_id = :dns_domain_id
			)
			SELECT * from dr
			OFFSET (SELECT floor((r-1)/:limit)*:limit FROM dr WHERE dns_record_id=:dns_record_id)
			LIMIT :limit
		};
	} else {
		$query = qq {
			SELECT row_number() over() r, d.*, device_id
			FROM	v_dns_sorted d
					LEFT JOIN network_interface_netblock USING (netblock_id)
			WHERE
		} . join( "\nAND ", @where_condition ) . ' LIMIT :limit OFFSET :offset';
	}

	my $sth = $stab->prepare($query) || return $stab->return_db_err;

	$sth->bind_param( ':dns_domain_id', $dnsdomainid );
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

	my $count  = 0;
	my $offset = -1;
	while ( my $hr = $sth->fetchrow_hashref ) {

		# Get the offset of the first returned record
		if ( $offset == -1 ) {
			$offset = $hr->{ _dbx('R') };
		}
		print build_dns_rec_Tr( $stab, $hr, ( $count++ % 2 ) ? 'even' : 'odd' );
	}
	$sth->finish;

	# Return the offset of the first record in the set
	return $offset;
}

#
# build the row for a (possibly) editable dns record.
#
# Some things end up not being editable but just become links to other
# records.
#
sub build_dns_rec_Tr {
	my ( $stab, $hr, $basecssclass ) = @_;

	my $cssclass = 'dnsupdate';

	my $cgi = $stab->cgi || die "Could not create cgi";

	my $opts = {};

	if ( !defined($hr) ) {
		$opts->{-prefix} = "new_";
		$opts->{-suffix} = "_0";
	}

	$opts->{-class} = 'dnsttl tracked';
	$opts->{-original} =
	  defined( $hr->{ _dbx('DNS_TTL') } ) ? $hr->{ _dbx('DNS_TTL') } : '';
	my $ttl =
	  $stab->b_offalwaystextfield( $opts, $hr, 'DNS_TTL', 'DNS_RECORD_ID' );
	delete $opts->{-class};

	my $value = "";
	my $name  = "";
	my $class = "";
	my $type  = "";

	my $dnsrecid;

	if ( defined($hr) && defined( $hr->{ _dbx('DNS_NAME') } ) ) {
		$name = $hr->{ _dbx('DNS_NAME') };
	}

	if ( defined($hr) && $hr->{ _dbx('DNS_TYPE') } =~ /^A(AAA)?$/ ) {
		$dnsrecid = $hr->{ _dbx('DNS_RECORD_ID') };
	}

	my $showexcess = 1;
	my $ttlonly    = 0;

	my $canedit = 1;

	if ( !$hr->{ _dbx('DNS_RECORD_ID') } ) {
		$name     = $hr->{ _dbx('DNS_NAME') };
		$class    = $hr->{ _dbx('DNS_CLASS') };
		$type     = $hr->{ _dbx('DNS_TYPE') };
		$value    = $hr->{ _dbx('DNS_VALUE') } || $hr->{ _dbx('IP') };
		$ttl      = "";
		$canedit  = 0;
		$cssclass = 'dnsinfo';
	} else {
		if ( $hr->{ _dbx('REF_RECORD_ID') } ) {
			$name = $hr->{ _dbx('DNS_NAME') };
		} else {
			$opts->{-class} = 'dnsname tracked';
			$opts->{-original} =
			  defined( $hr->{ _dbx('DNS_NAME') } )
			  ? $hr->{ _dbx('DNS_NAME') }
			  : '';
			$name =
			  $stab->b_textfield( $opts, $hr, 'DNS_NAME', 'DNS_RECORD_ID' );
			delete $opts->{-class};
		}
		$opts->{-class} = 'tracked';
		$opts->{-original} =
		  defined( $hr->{ _dbx('DNS_CLASS') } )
		  ? $hr->{ _dbx('DNS_CLASS') }
		  : '';
		$class =
		  $stab->b_dropdown( $opts, $hr, 'DNS_CLASS', 'DNS_RECORD_ID', 1 );

		$opts->{-class} = 'dnstype tracked';
		$opts->{-original} =
		  defined( $hr->{ _dbx('DNS_TYPE') } ) ? $hr->{ _dbx('DNS_TYPE') } : '';
		$type = $stab->b_dropdown( $opts, $hr, 'DNS_TYPE', 'DNS_RECORD_ID', 1 );
		delete( $opts->{-class} );

		if ( defined($hr) && $hr->{ _dbx('DNS_TYPE') } =~ /^A(AAA)?$/ ) {

			# [XXX] hack hack hack, needs to be fixed right so it doesn't
			# show up as a value, but the network.  I think.
			$hr->{ _dbx('DNS_VALUE') } = $hr->{ _dbx('IP') };
		}
	}

	if ( $hr->{ _dbx('DNS_VALUE_RECORD_ID') } ) {
		if ( !$hr->{ _dbx('NETBLOCK_ID') } ) {
			my $link =
			  "./?DNS_RECORD_ID=" . $hr->{ _dbx('DNS_VALUE_RECORD_ID') };
			$value = $cgi->a( { -class => 'dnsrefoutlink', -href => $link },
				$hr->{ _dbx('DNS_VALUE') } );
		} else {
			my $link =
			  "./?DNS_RECORD_ID=" . $hr->{ _dbx('DNS_VALUE_RECORD_ID') };
			$value = $cgi->a( { -class => 'dnsrefoutlink', -href => $link },
				$hr->{ _dbx('IP') } );
		}
		$value .= $cgi->a(
			{ -class => 'dnsrefouteditbutton', onclick => 'return(false);' },
			'' );
	} elsif ( $hr->{ _dbx('DNS_RECORD_ID') } ) {
		$opts->{-class} = 'dnsvalue tracked';
		$opts->{-original} =
		  defined( $hr->{ _dbx('DNS_VALUE') } )
		  ? $hr->{ _dbx('DNS_VALUE') }
		  : '';
		if ( $hr->{ _dbx('DNS_TYPE') } eq 'CNAME' ) {
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

	if ( $hr->{ _dbx('DEVICE_ID') } ) {
		if ( $hr->{ _dbx('DNS_TYPE') } eq 'PTR' ) {
			my $link =
			  "../device/device.pl?devid=" . $hr->{ _dbx('DEVICE_ID') };
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
			-name  => "DNS_VALUE_RECORD_ID_" . $hr->{ _dbx('DNS_RECORD_ID') },
			-label => '',
			-class => 'valdnsrecid',
		);
		if ( $hr->{ _dbx('DNS_VALUE_RECORD_ID') } ) {
			$args{-value} = $hr->{ _dbx('DNS_VALUE_RECORD_ID') },;
		}
		$value .= $cgi->hidden(%args);
	}

	if ($canedit) {
		$opts->{-default} = 'Y';
		if ($showexcess) {
			if ( defined($hr) && $hr->{ _dbx('DNS_RECORD_ID') } ) {
				$excess .= $cgi->checkbox( {
					-class => 'irrelevant rmrow',
					-name  => "Del_" . $hr->{ _dbx('DNS_RECORD_ID') },
					-label => '',
				} );
			} else {
				$cssclass = "dnsadd";
			}
		}
		if ( $ttlonly && defined($hr) ) {
			$excess .= $cgi->hidden( {
				-name  => "ttlonly_" . $hr->{ _dbx('DNS_RECORD_ID') },
				-value => 'ttlonly'
			} );
		}

		if ( $hr && $hr->{ _dbx('DNS_RECORD_ID') } ) {
			$hidden = $cgi->hidden( {
				-name  => "DNS_RECORD_ID_" . $hr->{ _dbx('DNS_RECORD_ID') },
				-value => $hr->{ _dbx('DNS_RECORD_ID') }
			} );
		}

		$opts->{-nodiv} = 1;
		$opts->{'-class'} = 'tracked';
		$opts->{'-original'} =
		  ( $hr->{ _dbx('IS_ENABLED') } eq 'Y' ) ? 'checked' : '';
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
			&& !$hr->{ _dbx('DNS_VALUE_RECORD_ID') }
			&& $hr->{ _dbx('DNS_TYPE') } =~ /^A(AAA)?$/ )
		{
			$opts->{-class} = "ptrbox tracked";
			$opts->{-original} =
			  ( $hr->{ _dbx('SHOULD_GENERATE_PTR') } eq 'Y' ) ? 'checked' : '';
			$ptrbox =
			  $stab->build_checkbox( $opts,
				$hr, "", "SHOULD_GENERATE_PTR", 'DNS_RECORD_ID' );
			delete( $opts->{-class} );
		}

		# for SRV records, it is necessary to prepend the
		# protocol and service name to the name
		if ( $hr && $hr->{ _dbx('DNS_TYPE') } eq 'SRV' ) {

			# Build the SRV service field
			$opts->{-class} = 'srvname tracked';
			$opts->{-original} =
			  $hr->{ _dbx('DNS_SRV_SERVICE') } || '__unknown__';
			$opts->{-placeholder} = 'service';
			my $srvname = $stab->b_dropdown( $opts, $hr, 'DNS_SRV_SERVICE',
				'DNS_RECORD_ID', 1 );

			# Build the SRV protocol field
			$opts->{-class} = 'srvproto tracked';
			$opts->{-original} =
			  $hr->{ _dbx('DNS_SRV_PROTOCOL') } || '__unknown__';
			$opts->{-placeholder} = 'protocol';
			my $srvproto =
			  $stab->b_nondbdropdown( $opts, $hr, 'DNS_SRV_PROTOCOL',
				'DNS_RECORD_ID' );

			$name = $srvname . $srvproto . $name;

			# Build the SRV priority field
			$opts->{-class} = 'srvnum tracked';

			# If $hr->{ _dbx('DNS_PRIORITY')}) is defined, use it, otherwise use ''
			# It can be zero, so we have to use defined() instead of just $hr->{ _dbx('DNS_PRIORITY')} || ''
			$opts->{-original} =
			  defined( $hr->{ _dbx('DNS_PRIORITY') } )
			  ? $hr->{ _dbx('DNS_PRIORITY') }
			  : '';
			$opts->{-placeholder} = 'priority';
			my $srvpriority =
			  $stab->b_textfield( $opts, $hr, 'DNS_PRIORITY', 'DNS_RECORD_ID' );

			# Build the SRV weight field
			$opts->{-class} = 'srvnum tracked';
			$opts->{-original} =
			  defined( $hr->{ _dbx('DNS_SRV_WEIGHT') } )
			  ? $hr->{ _dbx('DNS_SRV_WEIGHT') }
			  : '';
			$opts->{-placeholder} = 'weight';
			my $srvweight = $stab->b_textfield( $opts, $hr, 'DNS_SRV_WEIGHT',
				'DNS_RECORD_ID' );

			# Build the SRV port field
			$opts->{-class} = 'srvnum tracked';
			$opts->{-original} =
			  defined( $hr->{ _dbx('DNS_SRV_PORT') } )
			  ? $hr->{ _dbx('DNS_SRV_PORT') }
			  : '';
			$opts->{-placeholder} = 'port';
			my $srvport =
			  $stab->b_textfield( $opts, $hr, 'DNS_SRV_PORT', 'DNS_RECORD_ID' );

			$value = $srvpriority . $srvweight . $srvport . $value;

			delete( $opts->{-class} );

			# MX record
		} elsif ( $hr && $hr->{ _dbx('DNS_TYPE') } eq 'MX' ) {
			$opts->{-class} = 'srvnum tracked';
			$opts->{-original} =
			  defined( $hr->{ _dbx('DNS_PRIORITY') } )
			  ? $hr->{ _dbx('DNS_PRIORITY') }
			  : '';
			$opts->{-placeholder} = 'priority';
			$value =
			  $stab->b_textfield( $opts, $hr, 'DNS_PRIORITY', 'DNS_RECORD_ID' )
			  . $value;
			delete( $opts->{-class} );
		}

		if ($hr) {
			$args->{'-id'} = $hr->{ _dbx('DNS_RECORD_ID') };
		} else {
			$args->{'-id'} = "0";
		}
	} else {    # uneditable.
		$ttl = "";
	}
	return $cgi->Tr(
		$args,            $cgi->td( $hidden, $enablebox ),
		$cgi->td($name),  $cgi->td($ttl),
		$cgi->td($class), $cgi->td($type),
		$cgi->td($value), $cgi->td( { -class => 'ptrtd' }, $ptrbox ),
	);
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
		$dnsname     = $dns->{ _dbx('DNS_NAME') };
		$dnsdomainid = $dns->{ _dbx('DNS_DOMAIN_ID') };
	}

	return ( $dnsname, $dnsdomainid );
}

sub dump_soa_section {
	my ( $stab, $dnsdomainid, $dnsrecid, $dnsname, $addonly ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my @where_condition;
	push( @where_condition, "dns_domain_id = :dns_domain_id" );

	my $q = qq{
		select 	dns_domain_id,
			soa_name,
			soa_class,
			soa_ttl,
			soa_serial,
			soa_refresh,
			soa_retry,
			soa_expire,
			soa_minimum,
			soa_mname,
			soa_rname,
			should_generate,
			parent_dns_domain_id,
			parent_soa_name,
			last_generated
		  from v_dns_domain_nouniverse d1
			left join (
				select dns_domain_id as parent_dns_domain_id,soa_name as parent_soa_name
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

	$sth->execute || return $stab->return_db_err($sth);

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;

	if ( !defined($hr) ) {
		$stab->error_return("Unknown Domain");
	}

	my $title = $hr->{ _dbx('SOA_NAME') };
	if ($dnsname) {
		$title = "$dnsname.$title";
	}

	if ( $hr->{ _dbx('SHOULD_GENERATE') } eq 'Y' ) {
		$title .= " (Auto Generated) ";
	}

	if ($addonly) {
		$title = "Add record to " . $title;
	}

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html( { -title => $title, -javascript => 'dns' } ), "\n";

	# Stop here if we are in addonly mode
	if ($addonly) {
		return;
	}

	my $lastgen = 'never';
	if ( defined( $hr->{ _dbx('LAST_GENERATED') } ) ) {
		$lastgen = $hr->{ _dbx('LAST_GENERATED') };
	}

	my $soatable = "";
	my $parlink;
	my $zonelink = "";

	$parlink = $cgi->span( $cgi->b("Parent: ") . $parlink ) if ($parlink);
	my $nblink = build_reverse_association_section( $stab, $dnsdomainid );

	print $cgi->start_form( { -action => "write/update_domain.pl" } );
	print $cgi->hidden(
		-name    => 'DNS_DOMAIN_ID',
		-default => $hr->{ _dbx('DNS_DOMAIN_ID') }
	);
	print $cgi->hr;
	my $t =
	  $cgi->Tr( $cgi->td( { -colspan => 2 }, "Last Generated: $lastgen" ) );
	my $autogen = "";

	if ( $hr->{ _dbx('SHOULD_GENERATE') } eq 'Y' ) {
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

	print $cgi->table( { -class => 'dnsgentable' }, $t );

	$parlink = "--none--";
	if ( $hr->{ _dbx('PARENT_DNS_DOMAIN_ID') } ) {
		my $url =
		  build_dns_link( $stab, $hr->{ _dbx('PARENT_DNS_DOMAIN_ID') } );
		my $parent =
		  ( $hr->{ _dbx('PARENT_SOA_NAME') } )
		  ? $hr->{ _dbx('PARENT_SOA_NAME') }
		  : "unnamed zone";
		$parlink = $cgi->a( { -href => $url }, $parent );
	}
	$parlink = "Parent: $parlink";

	if ( $nblink && length($nblink) ) {
		$nblink = $cgi->br($nblink);
	}

	print $cgi->hr;

	print $cgi->div( { -class => 'centered' }, $parlink, $nblink, $zonelink );

	print $stab->zone_header( $hr, 'update' );

	# Add a cancel (reset) button
	print $cgi->div(
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
	print $cgi->end_form;

	print $cgi->hr;

}

sub dump_records_section {
	my ( $stab, $dnsdomainid, $dnsrecid, $addonly, $paging_dns_page,
		$paging_dns_limit )
	  = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	#
	# second form, second table
	#
	print $cgi->start_form(  { -action => "update_dns.pl" } );
	print $cgi->start_table( { -class  => 'dnstable' } );
	print $cgi->hidden(
		-name    => 'DNS_DOMAIN_ID',
		-default => $dnsdomainid
	);

	# Dump the paging header, but only if we're not just adding a record without displaying the rest of the zone
	if ( !$addonly ) {

		# Get the total number of records in the zone
		my $count = get_dns_records_count( $stab, $dnsdomainid );

		# The function returns the validated page, if it's out of range
		$paging_dns_page =
		  validate_page( $stab, $dnsdomainid, $count, $paging_dns_page,
			$paging_dns_limit );

		# We just add a paging container div to the top of the tabl
		# It will be automatically populated by a paging.js function
		# The required parameters are the count, limit, and offset
		print $cgi->Tr( $cgi->td(
			{ -colspan => '7' },
			$cgi->div( {
					-id           => 'paging-dns',
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
	print $cgi->Tr( $cgi->th(
		[ 'Enable', 'Record', 'TTL', 'Class', 'Type', 'Value', 'PTR' ]
	) );

	print $cgi->Tr( $cgi->td(
		{ -colspan => '7', -align => 'left' },
		$cgi->a( {
				-onclick     => 'return false;',
				-class       => 'adddnsrec plusbutton',
				-placeholder => 'Create new DNS record'
			},
		)
	) );

	my $offset = -1;
	if ( !$addonly ) {
		$offset =
		  build_dns_zone( $stab, $dnsdomainid, $dnsrecid, $paging_dns_page,
			$paging_dns_limit );
	}

	print $cgi->end_table;

	# Print a javascript global variable that contains the value of the offset
	if ( $offset != -1 ) {
		print $cgi->script( { -type => 'text/javascript' },
			"var pagingOffset = $offset;" );
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
		$paging_dns_limit )
	  = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	# Validate the domain from the record if needed, and get the dnsname
	my ( $dnsname, $dnsdomainid ) =
	  get_domain_from_record( $stab, $dnsdomid, $dnsrecid );

	# Dump the soa section
	dump_soa_section( $stab, $dnsdomainid, $dnsrecid, $dnsname, $addonly );

	# Search for a record section
	if ( !$addonly ) {
		dump_dns_record_search_section($stab);
	}

	# Dump the records section
	dump_records_section( $stab, $dnsdomainid, $dnsrecid, $addonly,
		$paging_dns_page, $paging_dns_limit );

	# Add a javascript snippet that contains the value of dnsrecid as a global variable
	# It will be used in dns-utils.js / scrollToTargetDNSRecord() to scroll to the record when the page is loaded
	if ($dnsrecid) {
		print $cgi->script( { -type => 'text/javascript' },
			"var dnsrecid = $dnsrecid;" );
	}
}

# Function to get the total number of records in the zone
sub get_dns_records_count {
	my ( $stab, $dnsdomainid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my @where_condition;
	push( @where_condition, "dns_domain_id = :dns_domain_id" );

	# Get the total number of records in the zone
	my $sth = $stab->prepare(
		qq{
		SELECT count(*)
		FROM v_dns_sorted d
		LEFT JOIN network_interface_netblock USING (netblock_id)
		} . "WHERE " . join( "\nAND ", @where_condition )
	) || return $stab->return_db_err;

	$sth->bind_param( ':dns_domain_id', $dnsdomainid );
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
