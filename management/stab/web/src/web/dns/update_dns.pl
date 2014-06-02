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
# Copyright (c) 2013 Todd Kover
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
# $Id$
#

#
# this script validates input for an addition, and in the event of problem,
# will send an error message and present the user with an opportunity to
# fix.
#

use strict;
use warnings;
use JazzHands::STAB;
use JazzHands::Common qw(:all);
use FileHandle;
use Data::Dumper;
use URI;
use CGI;
use POSIX;
use Net::IP;

do_dns_update();

#
# I probably need to find a better way to do this.  This allows error
# responses to be much less sucky, but it's going to be way slow.
#
sub clear_same_dns_params {
	my ( $stab, $domid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $q = qq{
		select	d.dns_record_id,
				d.dns_name, d.dns_class, d.dns_type, 
				d.dns_value, d.dns_ttl, d.is_enabled,
				d.dns_srv_service, d.dns_srv_protocol, 
				d.dns_srv_weight, d.dns_srv_port,
				d.dns_priority, d.should_generate_ptr,
				net_manip.inet_dbtop(nb.ip_address) as ip
		  from	dns_record d
				left join netblock nb
					on nb.netblock_id = d.netblock_id
		 where	dns_domain_id = ?
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err;
	$sth->execute($domid) || $stab->return_db_err;

	my $all = $sth->fetchall_hashref( _dbx('DNS_RECORD_ID') )
	  || $stab->error_return(
		"Unable to obtain existing DNS records from database.");

	my ($purge) = {};

	#
	# iterate over TTL because that's a record that exists for everything,
	# even the uneditable "device" recors.
	#
	# a "next" in this loop causes it to not be removed and is left for
	# consideration later in the script.
	#
	# ttlonly no longer means ttlonly as it now includes is_enabled...
	#
      DNS: for my $dnsid ( $stab->cgi_get_ids('DNS_RECORD_ID') ) {
		next if ( $dnsid !~ /^\d+$/ );

		my $in_name    = $stab->cgi_parse_param( 'DNS_NAME',  $dnsid );
		my $in_class   = $stab->cgi_parse_param( 'DNS_CLASS', $dnsid );
		my $in_type    = $stab->cgi_parse_param( 'DNS_TYPE',  $dnsid );
		my $in_ttl     = $cgi->param( 'DNS_TTL_' . $dnsid );
		my $in_value   = $stab->cgi_parse_param( 'DNS_VALUE', $dnsid );
		my $in_ttlonly = $stab->cgi_parse_param( 'ttlonly',   $dnsid );
		my $in_enabled =
		  $stab->cgi_parse_param( 'chk_IS_ENABLED', $dnsid );

		my $in_ptr =
		  $stab->cgi_parse_param( 'chk_SHOULD_GENERATE_PTR', $dnsid );

		my $in_srv_svc =
		  $stab->cgi_parse_param( 'DNS_SRV_SERVICE', $dnsid );
		my $in_srv_proto =
		  $stab->cgi_parse_param( 'DNS_SRV_PROTOCOL', $dnsid );
		my $in_srv_weight =
		  $stab->cgi_parse_param( 'DNS_SRV_WEIGHT', $dnsid );
		my $in_srv_port =
		  $stab->cgi_parse_param( 'DNS_SRV_PORT', $dnsid );
		my $in_priority =
		  $stab->cgi_parse_param( 'DNS_PRIORITY', $dnsid );

		$in_enabled = $stab->mk_chk_yn($in_enabled);
		$in_ptr     = $stab->mk_chk_yn($in_ptr);

		if ( !exists( $all->{$dnsid} ) ) {
			next;
		}

		if ( !defined($in_ttl) ) {
			$in_ttl = $all->{$dnsid}->{ _dbx('DNS_TTL') };
		}

	     #
	     # TTL only records are setup on the device and changes need to be
	     # made there.  It is not clear if SHOULD_GENERATE_PTR should be
	     # manipulatable or not but its here for now.  It probably should if
	     # enabled and TTL are around.
	     #
		if ($in_ttlonly) {
			if ( $all->{$dnsid}->{ _dbx('DNS_TTL') } && $in_ttl ) {
				if ( $all->{$dnsid}->{ _dbx('DNS_TTL') } !=
					$in_ttl )
				{
					next;
				}
			} elsif (  !$all->{$dnsid}->{ _dbx('DNS_TTL') }
				&& !$in_ttl )
			{
				;
			} else {
				next;
			}

			if ( $all->{$dnsid}->{ _dbx('IS_ENABLED') } ne
				$in_enabled )
			{
				next;
			}

			if ( $all->{$dnsid}->{ _dbx('SHOULD_GENERATE_PTR') }
				ne $in_ptr )
			{
				next;
			}

		} else {
			if ( $all->{$dnsid}->{ _dbx('DNS_TYPE') } =~
				/^A(AAA)?/ )
			{
				$all->{$dnsid}->{ _dbx('DNS_VALUE') } =
				  $all->{$dnsid}->{ _dbx('IP') };
			}

			my $map = {
				DNS_NAME            => $in_name,
				DNS_CLASS           => $in_class,
				DNS_TYPE            => $in_type,
				DNS_VALUE           => $in_value,
				DNS_TTL             => $in_ttl,
				IS_ENABLED          => $in_enabled,
				DNS_SRV_SERVICE     => $in_srv_svc,
				DNS_SRV_PROTOCOL    => $in_srv_proto,
				DNS_SRV_WEIGHT      => $in_srv_weight,
				DNS_SRV_PORT        => $in_srv_port,
				DNS_PRIORITY        => $in_priority,
				SHOULD_GENERATE_PTR => $in_ptr,
			};

	    # if it correponds to an actual row, compare, otherwise only keep if
	    # something is set.
			if (       defined($dnsid)
				&& exists( $all->{$dnsid} )
				&& defined( $all->{$dnsid} ) )
			{
				my $x = $all->{$dnsid};
				foreach my $key ( sort keys(%$map) ) {
					if (       defined( $x->{ _dbx($key) } )
						&& defined( $map->{$key} ) )
					{
						if ( $x->{ _dbx($key) } ne
							$map->{$key} )
						{
							next DNS;
						}
					} elsif ( !defined( $x->{ _dbx($key) } )
						&& !defined( $map->{$key} ) )
					{
						;
					} else {
						next DNS;
					}
				}
			}
		}

		$purge->{ 'DNS_RECORD_ID_' . $dnsid }           = 1;
		$purge->{ 'DNS_NAME_' . $dnsid }                = 1;
		$purge->{ 'DNS_TTL_' . $dnsid }                 = 1;
		$purge->{ 'DNS_TYPE_' . $dnsid }                = 1;
		$purge->{ 'DNS_CLASS_' . $dnsid }               = 1;
		$purge->{ 'DNS_VALUE_' . $dnsid }               = 1;
		$purge->{ 'DNS_SRV_SERVICE_' . $dnsid }         = 1;
		$purge->{ 'DNS_SRV_PROTOCOL_' . $dnsid }        = 1;
		$purge->{ 'DNS_SRV_WEIGHT_' . $dnsid }          = 1;
		$purge->{ 'DNS_SRV_PORT_' . $dnsid }            = 1;
		$purge->{ 'DNS_PRIORITY_' . $dnsid }            = 1;
		$purge->{ 'ttlonly_' . $dnsid }                 = 1;
		$purge->{ 'chk_IS_ENABLED_' . $dnsid }          = 1;
		$purge->{ 'chk_SHOULD_GENERATE_PTR_' . $dnsid } = 1;
	}

	undef $all;

	my $n = new CGI($cgi);
	$cgi->delete_all;
	my $v = $n->Vars;
	foreach my $p ( keys %$v ) {
		next if ( $p eq 'Records' );
		next if ( defined( $purge->{$p} ) );
		$cgi->param( $p, $v->{$p} );
	}

	undef $v;
	undef $n;
	undef $purge;
}

sub process_dns_update {
	my ( $stab, $domid, $updateid ) = @_;

	my $cgi = $stab->cgi || die "Could not create cgi";

	my $numchanges = 0;

	my $name  = $stab->cgi_parse_param( 'DNS_NAME', $updateid );
	my $ttl   = $cgi->param( 'DNS_TTL_' . $updateid );
	my $class = $stab->cgi_parse_param( 'DNS_CLASS', $updateid );
	my $type  = $stab->cgi_parse_param( 'DNS_TYPE', $updateid );
	my $value = $stab->cgi_parse_param( 'DNS_VALUE', $updateid );
	my $genptr =
	  $stab->cgi_parse_param( 'chk_SHOULD_GENERATE_PTR', $updateid );
	my $enabled = $stab->cgi_parse_param( 'chk_IS_ENABLED', $updateid );
	my $ttlonly = $stab->cgi_parse_param( 'ttlonly',        $updateid );

	my $in_srv_svc = $stab->cgi_parse_param( "DNS_SRV_SERVICE", $updateid );
	my $in_srv_proto =
	  $stab->cgi_parse_param( "DNS_SRV_PROTOCOL", $updateid );
	my $in_srv_weight =
	  $stab->cgi_parse_param( "DNS_SRV_WEIGHT", $updateid );
	my $in_srv_port = $stab->cgi_parse_param( "DNS_SRV_PORT", $updateid );
	my $in_priority = $stab->cgi_parse_param( "DNS_PRIORITY", $updateid );

	$enabled = $stab->mk_chk_yn($enabled);
	$genptr  = $stab->mk_chk_yn($genptr);

	if ( $type eq 'MX' ) {
		$in_srv_svc = $in_srv_proto = $in_srv_weight =
		  $in_srv_port = undef;
	} elsif ( $type ne 'SRV' ) {
		$in_srv_svc    = $in_srv_proto = $in_srv_weight =
		  $in_srv_port = $in_priority  = undef;
	}

	if ( defined($in_srv_port) && $in_srv_port !~ /^\d+/ ) {
		$stab->error_return("SRV Port must be a number");
	}

	if ( defined($in_srv_weight) && $in_srv_weight !~ /^\d+/ ) {
		$stab->error_return("SRV weight must be a number");
	}

	if ( defined($in_priority) && $in_priority !~ /^\d+/ ) {
		$stab->error_return("SRV/MX Priority must be a number");
	}

	if ( !defined($name) && !$ttl && !$class && !$type && !$value ) {
		return $numchanges;
	}

	if ( !$ttlonly ) {

		# this are just informational records.
		next if ( !$name && !$class && !$type && !$value );
		if ($name) {
			$name =~ s/^\s+//;
			$name =~ s/\s+$//;
		}
		if ( !$value ) {
			my $hint = $name || "";
			$hint = "($hint id#$updateid)";
			$stab->error_return(
				"Records may not have empty values ($hint)");
		}
		$value =~ s/^\s+//;
		$value =~ s/\s+$//;
	}

	if ( $ttl && $ttl !~ /^\d+/ ) {
		$stab->error_return("TTLs must be numbers");
	}

	# [XXX] need to check value and deal with it appropriately (or figure
	# out where quotes should go in the extraction.
	if ( $name && $name =~ /\s/ ) {
		$stab->error_return("DNS Records may not contain spaces");
	}

	my $new = {
		dns_name            => $name,
		dns_record_id       => $updateid,
		dns_domain_id       => $domid,
		dns_ttl             => $ttl,
		dns_class           => $class,
		dns_type            => $type,
		dns_value           => $value,
		dns_priority        => $in_priority,
		dns_srv_service     => $in_srv_svc,
		dns_srv_protocol    => $in_srv_proto,
		dns_srv_weight      => $in_srv_weight,
		dns_srv_port        => $in_srv_port,
		is_enabled          => $enabled,
		should_generate_ptr => $genptr,
	};

	$numchanges += process_and_update_dns_record( $stab, $new, $ttlonly );

}

sub process_dns_add {
	my ( $stab, $domid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $numchanges = 0;

	foreach my $newid ( $stab->cgi_get_ids("new_DNS_NAME") ) {
		my $name  = $stab->cgi_parse_param("new_DNS_NAME_$newid");
		my $ttl   = $stab->cgi_parse_param("new_DNS_TTL_$newid");
		my $class = $stab->cgi_parse_param("new_DNS_CLASS_$newid");
		my $type  = $stab->cgi_parse_param("new_DNS_TYPE_$newid");
		my $value = $stab->cgi_parse_param("new_DNS_VALUE_$newid");
		my $enabled =
		  $stab->cgi_parse_param( 'new_chk_IS_ENABLED', $newid );
		my $genptr =
		  $stab->cgi_parse_param( "new_chk_SHOULD_GENERATE_PTR",
			$newid );

		$enabled = $stab->mk_chk_yn($enabled);

		# Need to capture if this is checked or not.
		if ($genptr) {
			$genptr = $stab->mk_chk_yn($genptr);
		}

		if ( !$name && !$class && !$type && !$value ) {
			return 0;
		}

		my $in_srv_svc =
		  $stab->cgi_parse_param("new_DNS_SRV_SERVICE_$newid");
		my $in_srv_proto =
		  $stab->cgi_parse_param("new_DNS_SRV_PROTOCOL_$newid");
		my $in_srv_weight =
		  $stab->cgi_parse_param("new_DNS_SRV_WEIGHT_$newid");
		my $in_srv_port =
		  $stab->cgi_parse_param("new_DNS_SRV_PORT_$newid");
		my $in_priority =
		  $stab->cgi_parse_param("new_DNS_PRIORITY_$newid");

		if ( defined($name) ) {
			$name =~ s/^\s+//;
			$name =~ s/\s+$//;
		}
		if ( defined($value) ) {
			$value =~ s/^\s+//;
			$value =~ s/\s+$//;
		}

		$class = 'IN' if ( !defined($class) );
		if ( !defined($type) || !length($type) ) {
			$stab->error_return("Must set a record type");
		}
		if ( !defined($value) || !length($value) ) {
			$stab->error_return("Must set a value");
		}
		if ( defined($ttl) && $ttl !~ /^\d+$/ ) {
			$stab->error_return("TTL, if set, must be a number");
		}

		if ( $type eq 'MX' ) {
			$in_srv_svc = $in_srv_proto = $in_srv_weight =
			  $in_srv_port = undef;
		} elsif ( $type ne 'SRV' ) {
			$in_srv_svc    = $in_srv_proto = $in_srv_weight =
			  $in_srv_port = $in_priority  = undef;
		}

		if ( defined($in_srv_port) && $in_srv_port !~ /^\d+/ ) {
			$stab->error_return("SRV Port must be a number");
		}

		if ( defined($in_srv_weight) && $in_srv_weight !~ /^\d+/ ) {
			$stab->error_return("SRV weight must be a number");
		}

		if ( defined($in_priority) && $in_priority !~ /^\d+/ ) {
			$stab->error_return("SRV/MX Priority must be a number");
		}

		if ( !defined($name) && !$ttl && !$class && !$type && !$value )
		{
			return $numchanges;
		}

		my $cur = $stab->get_dns_record_from_name( $name, $domid );
		if ($cur) {
			if (       $type eq 'CNAME'
				&& $cur->{ _dbx('DNS_TYPE') } ne 'CNAME' )
			{
				$stab->error_return(
"You may not add a CNAME, when records of other types exist."
				);
			}
			if (       $type ne 'CNAME'
				&& $cur->{ _dbx('DNS_TYPE') } eq 'CNAME' )
			{
				$stab->error_return(
"You may not add non-CNAMEs when CNAMEs already exist"
				);
			}
		}

		if ( ( !defined($name) || !length($name) ) && $type eq 'CNAME' )
		{
			$stab->error_return(
"CNAMEs are illegal when combined with an SOA record."
			);
		}

		my $new = {
			dns_name            => $name,
			dns_domain_id       => $domid,
			dns_ttl             => $ttl,
			dns_class           => $class,
			dns_type            => $type,
			dns_value           => $value,
			dns_priority        => $in_priority,
			dns_srv_service     => $in_srv_svc,
			dns_srv_protocol    => $in_srv_proto,
			dns_srv_weight      => $in_srv_weight,
			dns_srv_port        => $in_srv_port,
			is_enabled          => 'Y',
			should_generate_ptr => $genptr,
		};

		$numchanges += $stab->process_and_insert_dns_record($new);
	}

	$numchanges;
}

sub do_dns_update {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";

	my $numchanges;

	my $domid = $stab->cgi_parse_param('DNS_DOMAIN_ID');

	if ( !dns_domain_authcheck( $stab, $domid ) ) {
		$stab->error_return(
			"You are not authorized to change this zone.");
	}

	clear_same_dns_params( $stab, $domid );

      #- print $cgi->header, $cgi->start_html, $cgi->Dump, $cgi->end_html; exit;

	my $genflip = $stab->cgi_parse_param('AutoGen');

    # process deletions
    # Done first so that updates that need to make decisions about defaults will
    # have a resonable state
	my $delsth;
	foreach my $delid ( $stab->cgi_get_ids('Del') ) {
		my $dns = $stab->get_dns_record_from_id($delid);
		if ( !defined($delsth) ) {
			my $q = qq{
				delete from dns_record
				 where	dns_record_id = ?
			};
			$delsth = $stab->prepare($q)
			  || $stab->return_db_err;
		}
		$delsth->execute($delid) || $stab->return_db_err($delsth);
		$cgi->delete("Del_$delid");
		$cgi->delete("DNS_RECORD_ID_$delid");
		$numchanges++;

		if ( $dns && $dns->{ _dbx('DNS_TYPE') } =~ /^A(AAA)?$/ ) {
			$numchanges +=
			  $stab->delete_netblock( $dns->{ _dbx('NETBLOCK_ID') },
				1 );
		}
	}

	# process updates
	my $updsth;
	foreach my $updateid ( $stab->cgi_get_ids('DNS_RECORD_ID') ) {
		next if ( !$updateid );
		$numchanges += process_dns_update( $stab, $domid, $updateid );
	}

  # These are saved for the end so that PTR record sets are handled properly, as
  # updates may have it set to 'Y' because they used to have it so an add would
  # get overwritten.
	$numchanges += process_dns_add( $stab, $domid );

	if ($numchanges) {
		$stab->commit || $stab->return_db_err();
		my $url = "./?dnsdomainid=" . $domid;
		$stab->msg_return( "Zone Updated", $url, 1 );
	}

	$stab->rollback;
	$stab->msg_return("Nothing to do");
	undef $stab;
}

sub process_and_update_dns_record {
	my ( $stab, $opts, $ttlonly ) = @_;

	$opts = _dbx( $opts, 'lower' );

	$opts->{'is_enabled'} = 'Y' if ( !defined( $opts->{'is_enabled'} ) );

	my $orig = $stab->get_dns_record_from_id( $opts->{'dns_record_id'} );

	if ( !exists( $opts->{'dns_ttl'} ) ) {
		$opts->{'dns_ttl'} = $orig->{ _dbx('DNS_TTL') };
	} elsif ( !length( $opts->{'dns_ttl'} ) ) {
		$opts->{'dns_ttl'} = undef;
	}

	my $newrecord;

	# ttlonly applies only to A/AAAA records anchored to hosts
	if ($ttlonly) {
		$newrecord = {
			DNS_RECORD_ID       => $opts->{'dns_record_id'},
			DNS_TTL             => $opts->{'dns_ttl'},
			IS_ENABLED          => $opts->{'is_enabled'},
			SHOULD_GENERATE_PTR => $opts->{'should_generate_ptr'},
		};
	} else {
		$newrecord = {
			DNS_RECORD_ID       => $opts->{'dns_record_id'},
			DNS_TTL             => $opts->{'dns_ttl'},
			DNS_NAME            => $opts->{'dns_name'},
			DNS_VALUE           => $opts->{'dns_value'},
			DNS_TYPE            => $opts->{'dns_type'},
			IS_ENABLED          => $opts->{'is_enabled'},
			SHOULD_GENERATE_PTR => $opts->{'should_generate_ptr'},
			DNS_PRIORITY        => $opts->{'dns_priority'},
			DNS_SRV_SERVICE     => $opts->{'dns_srv_service'},
			DNS_SRV_PROTOCOl    => $opts->{'dns_srv_protocol'},
			DNS_SRV_WEIGHT      => $opts->{'dns_srv_weight'},
			DNS_SRV_PORT        => $opts->{'dns_srv_port'},
		};
	}
	if ( defined( $opts->{class} ) ) {
		$newrecord->{'DNS_CLASS'} = $opts->{dns_class};
	}

	$newrecord = _dbx( $newrecord, 'lower' );

	# On update:
	#	Only pay attention to if the new type is A or AAAA.
	#	If it is set to 'Y', then set it to 'Y' and change all other
	#		records to the same netblock to 'N'.
	#	If it a type change, and set to 'N', then check to see if there
	#		is already a record with PTR.  If there is already, then set
	#		to 'N'.
	#	If it is not a type change, then just obey what it was set to.
	#
	if (       $opts->{should_generate_ptr}
		&& $opts->{'dns_type'} =~ /^A(AAA)?$/ )
	{
		if ( $opts->{should_generate_ptr} eq 'Y' ) {
			$newrecord->{'should_generate_ptr'} =
			  $opts->{should_generate_ptr};
		} elsif ( $orig->{'dns_type'} ne $opts->{'dns_type'} ) {
			if (
				!$stab->get_dns_a_record_for_ptr(
					$opts->{'dns_value'}
				)
			  )
			{
				$newrecord->{'should_generate_ptr'} = 'Y';
			} else {
				$newrecord->{'should_generate_ptr'} =
				  $opts->{should_generate_ptr};
			}
		} else {
			$newrecord->{'should_generate_ptr'} =
			  $opts->{should_generate_ptr};
		}

		if ( $opts->{should_generate_ptr} eq 'Y' ) {

		      # set all other dns_records but this one to have ptr = 'N'
			if (
				my $recid = $stab->get_dns_a_record_for_ptr(
					$opts->{'dns_value'}
				)
			  )
			{
				$stab->run_update_from_hash( "DNS_RECORD",
					"DNS_RECORD_ID", $recid,
					{ should_generate_ptr => 'N' } );
			}
		}
	}

	my $nblkid;

	# if the new type is A/AAAA then find the netblock and create if it
	# does not exist.
	# Creation should only happen on a change.
	if ( $opts->{'dns_type'} =~ /^A(AAA)?/ ) {
		my $i = new Net::IP( $opts->{'dns_value'} )
		  || $stab->error_return(
			"$opts->{'dns_value'} is not a valid IP address");
		if ( $opts->{'dns_type'} eq 'A' && $i->version() != 4 ) {
			$stab->error_return(
"$opts->{'dns_value'} is not a valid IPv4 address"
			);
		}
		if ( $opts->{'dns_type'} eq 'AAAA' && $i->version() != 6 ) {
			$stab->error_return(
"$opts->{'dns_value'} is not a valid IPv6 address"
			);
		}

		my $block = $stab->get_netblock_from_ip(
			ip_address => $opts->{'dns_value'} );
		if ( !$block ) {
			$block = $stab->get_netblock_from_ip(
				ip_address    => $opts->{'dns_value'},
				netblock_type => 'dns'
			);
		}
		if ( !defined($block) ) {
			my $h = {
				ip_address        => $opts->{'dns_value'},
				is_single_address => 'Y'
			};
			if (
				!(
					my $par =
					$stab->guess_parent_netblock_id(
						$opts->{'dns_value'}
					)
				)
			  )
			{
				# XXX This is outside our IP universe,
				# which we should probably print a warning
				# on, but lacking that, it gets created as a
				# type dns
				$h->{netblock_type} = 'dns';
			}
			$nblkid = $stab->add_netblock($h)
			  || die $stab->return_db_err();
		} else {
			$nblkid = $block->{ _dbx('NETBLOCK_ID') };
		}
	}

# if changing from A/AAAA or back then just swap out the netblock id and don't set the
# value
	if (       $orig->{ _dbx('DNS_TYPE') } =~ /^A(AAA)?/
		&& $opts->{dns_type} =~ /^A(AAA)?/ )
	{
		$newrecord->{ _dbx('DNS_VALUE') }   = undef;
		$newrecord->{ _dbx('NETBLOCK_ID') } = $nblkid;
	} elsif (  $orig->{ _dbx('DNS_TYPE') } =~ /^A(AAA)?/
		&& $opts->{dns_type} !~ /^A(AAA)?/ )
	{
		$newrecord->{ _dbx('DNS_VALUE') }   = $opts->{dns_value};
		$newrecord->{ _dbx('NETBLOCK_ID') } = undef;
	} elsif (  $orig->{ _dbx('DNS_TYPE') } !~ /^A(AAA)?/
		&& $opts->{dns_type} =~ /^A(AAA)?/ )
	{
		$newrecord->{ _dbx('DNS_VALUE') }   = undef;
		$newrecord->{ _dbx('NETBLOCK_ID') } = $nblkid;
	}

	my $diffs = $stab->hash_table_diff( $orig, _dbx($newrecord) );
	my $tally = keys %$diffs;
	if ( !$tally ) {
		return 0;
	} elsif (
		!$stab->run_update_from_hash(
			"DNS_RECORD",           "DNS_RECORD_ID",
			$orig->{dns_record_id}, $diffs
		)
	  )
	{
		$stab->rollback;
		$stab->return_db_err();
	}
	#
	# XXX -- NEED TO TRY TO REMOVE OLD NETBLOCK BUT NOT FAIL IF IT FAILS!
	#
	#
	return $tally;
}

#
# returns 1 if someone is authorized to change a given domain id,
# returns 0 if not.
#
sub dns_domain_authcheck {
	my ( $stab, $domid ) = @_;

	# XXXXXXXXXXXXXXXXXXXXXX
	# XXX -- NEED TO FIX XXX
	# XXXXXXXXXXXXXXXXXXXXXX
	return 1;

	my $cgi = $stab->cgi;

	#
	# if there's no htaccess file, return ok.
	#
	my $htaccess = $cgi->path_translated();
	if ( !$htaccess && $cgi->{'.r'} ) {

		# I'm sure this is illegal.
		$htaccess = $cgi->{'.r'}->filename;
	}
	return 0 if ( !$htaccess );
	$htaccess =~ s,/[^/]+$,/,;
	$htaccess .= "write/.htaccess";
	my $fh = new FileHandle($htaccess);
	return 0 if ( !$fh );
	my $wwwgroup = undef;
	while ( my $line = $fh->getline ) {

		if ( $line =~ /^\s*Require\s+group\s+(\S+)\s*$/ ) {
			$wwwgroup = $1;
			last;
		}
	}
	$fh->close;

	#
	# if there's no require group, then give access
	#
	return 0 if ( !$wwwgroup );

	#
	# if there is a domain, look for ${wwwgroup} or ${wwwgroup}--domain
	#
	my $altwwwgroup = $wwwgroup;
	my $hr          = $stab->get_dns_domain_from_id($domid);
	if ($hr) {
		$altwwwgroup = $wwwgroup . "--" . $hr->{ _dbx('SOA_NAME') };
	}

	#
	# look through the www group.  This must match the apache config.  Yes,
	# this is a gross hack.
	#
	# if there's no auth directory, then its not on, and return.
	# (this needs to move to db based auth)
	return 1 if ( !-d "/prod/www/auth" );
	my $fn   = "/prod/www/auth/groups";
	my $auth = new FileHandle($fn);

	#
	# fail if the file isn't there.
	#
	return 0 if ( !$auth );

	my $userlist;
	while ( my $line = $auth->getline ) {
		chomp($line);
		my ( $g, $u ) = split( /:/, $line, 2 );
		next if ( !$g || !$u );
		if ( $g eq $altwwwgroup ) {
			$userlist = $u;
			last;
		} elsif ( $g eq $wwwgroup ) {
			$userlist = $u;
		}
	}
	$auth->close;

	my $dude = $cgi->remote_user;
	return 0 if ( !$dude );
	return 0 if ( !$userlist );

	return 1 if ( $userlist =~ /\b$dude\b/ );
	return 0;
}
