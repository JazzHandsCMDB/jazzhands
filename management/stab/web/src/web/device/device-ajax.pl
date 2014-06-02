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
use FileHandle;
use CGI;
use JazzHands::Common::Util qw(_dbx);
use JazzHands::STAB;
use Data::Dumper;
use JSON::PP;

do_show_serial();

sub do_show_serial {
	my $stab = new JazzHands::STAB( ajax => 'yes' )
	  || die "Could not create STAB";
	my $cgi = $stab->cgi || die "Could not create cgi";
	my $devid    = $stab->cgi_parse_param('DEVICE_ID')            || undef;
	my $devnam   = $stab->cgi_parse_param('DEVICE_NAME')          || undef;
	my $pportid  = $stab->cgi_parse_param('PHYSICAL_PORT_ID')     || undef;
	my $piport   = $stab->cgi_parse_param('POWER_INTERFACE_PORT') || undef;
	my $niid     = $stab->cgi_parse_param('NETWORK_INTERFACE_ID') || undef;
	my $what     = $stab->cgi_parse_param('what')                 || undef;
	my $type     = $stab->cgi_parse_param('type')                 || undef;
	my $row      = $stab->cgi_parse_param('row')                  || undef;
	my $side     = $stab->cgi_parse_param('side')                 || undef;
	my $passedin = $stab->cgi_parse_param('passedin')             || undef;
	my $xml      = $stab->cgi_parse_param('xml')                  || 'no';
	my $json     = $stab->cgi_parse_param('json')                 || 'no';
	my $parent   = $stab->cgi_parse_param('parent')               || undef;
	my $osid     = $stab->cgi_parse_param('OPERATING_SYSTEM_ID')  || undef;
	my $site     = $stab->cgi_parse_param('SITE_CODE')            || undef;
	my $locid    = $stab->cgi_parse_param('LOCATION_ID')          || undef;
	my $dropid   = $stab->cgi_parse_param('dropid')               || undef;
	my $uniqid   = $stab->cgi_parse_param('uniqid');

	if ( $what eq 'serial' ) {
		$what = 'Serial';
	} elsif ( $what eq 'network' ) {
		$what = 'Switchport';
	}

	if ( $devnam && !$devid ) {
		my $dev = $stab->get_dev_from_name($devnam);
		if ($dev) {
			$devid = $dev->{'DEVICE_ID'};
		}
	}

	#
	# passedin contains all the arguments that were passed to the original
	# calling page.  This is sort of gross but basically is used to ensure
	# that fields that were filled in get properly filled in on error
	# conditions that send things back.
	if ($passedin) {
		$passedin =~ s/^.*\?//;
		foreach my $pair ( split( /[;&]/, $passedin ) ) {
			my ( $var, $val ) = split( /=/, $pair, 2 );
			next if ( $var eq 'devid' );
			next if ( $var eq '__notemsg__' );
			next if ( $var eq '__errmsg__' );
			$val = $cgi->unescape($val);
			$cgi->param( $var, $val );
		}
	}

	if ( $xml eq 'yes' ) {
		print $cgi->header("text/xml");
		print "<response>\n";
	} elsif ( $json eq 'yes' ) {
		print $cgi->header("text/json");
	} elsif ( $xml eq 'no' ) {
		print $cgi->header("text/html");
	}

	$what = "" if ( !defined($what) );

	if ( $what eq 'Serial' ) {

		# returns the serial port tab
		print $stab->device_serial_ports($devid);
	} elsif ( $what eq 'Power' ) {

		# returns the power supply tab
		print $stab->device_power_ports($devid);
	} elsif ( $what eq 'Ports' ) {
		my %values;

		#XXX $type = 'serial' if(!defined($type)); # legacy
		my $args = {};
		if ( $devid && $devid =~ /^\d+/ ) {
			$args->{-deviceid} = $devid;
		}
		if ($type) {
			$args->{-portLimit} = $type;
		}
		if ( defined($side) ) {

	       # [XXX] <- this is such a hack.  need to overhaul all port stuff.
			$args->{-name} =
			  "PC_P${side}_PHYSICAL_PORT_ID_$pportid";
			if ($pportid) {
				$values{"P${side}_PHYSICAL_PORT_ID"} = $pportid;
			}
		} else {
			$side = 2;
			if ($pportid) {
				$values{"PHYSICAL_PORT_ID"}    = $pportid;
				$values{"P1_PHYSICAL_PORT_ID"} = $pportid;
			}
		}
		print $stab->b_dropdown( $args, _dbx( \%values ),
			"P${side}_PHYSICAL_PORT_ID", 'P1_PHYSICAL_PORT_ID' );
	} elsif ( $what eq 'PowerPorts' ) {
		my %values;
		$values{'P1_DEVICE_ID'}            = $devid;
		$values{'P1_POWER_INTERFACE_PORT'} = $piport;
		if ( $devid && $devid =~ /^\d+/ ) {
			print $stab->b_dropdown(
				{ -deviceid => $devid },
				_dbx( \%values ),
				'P2_POWER_INTERFACE_PORT',
				'P1_POWER_INTERFACE_PORT'
			);
		} else {
			print $stab->b_dropdown( undef, _dbx( \%values ),
				'P2_POWER_INTERFACE_PORT',
				'P1_POWER_INTERFACE_PORT' );
		}
	} elsif ( $what eq 'VOESymTrax' ) {
		my $args = {};

		# $args->{-xml} = $xml if($xml);

		my $values = {};
		$values->{'DEVICE_ID'}           = $devid;
		$values->{'OPERATING_SYSTEM_ID'} = $osid;
		print $stab->b_dropdown( $args, $values,
			'VOE_SYMBOLIC_TRACK_ID', 'DEVICE_ID' );
	} elsif ( $what eq 'Circuit' ) {
		print $stab->device_circuit_tab( $devid, $parent );
	} elsif ( $what eq 'AppGroup' ) {
		print $stab->device_appgroup_tab($devid);
	} elsif ( $what eq 'Advanced' ) {
		print $stab->dump_advanced_tab($devid);
	} elsif ( $what eq 'IP' ) {

		# returns network interfaces tab
		print $stab->dump_interfaces($devid);
	} elsif ( $what eq 'IPRoute' ) {

		# returns ip routing interfaces tab
		print $stab->dump_device_route($devid);
	} elsif ( $what eq 'Location' ) {
		print $stab->device_location_print($devid);
	} elsif ( $what eq 'Notes' ) {
		print $stab->device_notes_print($devid);
	} elsif ( $what eq 'Switchport' ) {
		print $stab->device_switch_port($devid);
	} elsif ( $what eq 'SwitchportKids' ) {
		print $stab->device_switch_port( $devid, $parent );
	} elsif ( $what eq 'PatchPanel' ) {
		print $stab->device_patch_ports($devid);
	} elsif ( $what eq 'Licenses' ) {
		print $stab->device_license_tab($devid);
	} elsif ( $what eq 'PhysicalConnection' ) {
		if ($row) {
			print $stab->device_physical_connection( $devid,
				$pportid, $row, $side );
		} else {
			print $stab->device_physical_connection( $devid,
				$pportid );
		}
	} elsif ( $what eq 'IpRow' ) {

		# params, blk, hr, ip, reservation
		print $stab->build_netblock_ip_row( { -uniqid => $uniqid }, );
	} elsif ( $what eq 'LicenseDrop' ) {
		my $values = undef;
		my $args   = {};
		$args->{-deviceCollectionType} = 'applicense';
		$args->{-id}                   = $dropid;
		$args->{-name}                 = $dropid;
		print $stab->b_dropdown( $args, $values,
			'DEVICE_COLLECTION_ID', 'DEVICE_ID' );
	} elsif ( $what eq 'SiteRacks' ) {
		my $p;
		if ( $locid || $site ) {
			$p = {};
			$p->{LOCATION_ID}        = $locid if ($locid);
			$p->{LOCATION_SITE_CODE} = $site  if ($site);
		}
		if ( $type && $type eq 'dev' ) {
			print $stab->b_dropdown(
				{ -site => $site, -dolinkUpdate => 'rack' },
				$p, 'LOCATION_RACK_ID', 'LOCATION_ID', 1 );
		} else {
			print $stab->b_dropdown( { -site => $site },
				$p, 'RACK_ID', 'LOCATION_ID', 1 );
		}
	} elsif ( $what eq 'interfacedns' ) {
		my $sth = $stab->prepare(
			qq{
			select	dns.dns_record_id,
					dns.dns_domain_id,
					dom.soa_name,
					dns.dns_name,
					ni.network_interface_id
			  from	network_interface ni
					left join dns_record dns using (netblock_id)
			  		left join dns_domain dom using (dns_domain_id)
			 where	ni.network_interface_id= ?
			 order by dns.should_generate_ptr desc, dns.dns_record_id
			 limit 1
		}
		) || $stab->return_db_err();
		$sth->execute($niid) || die $sth->errstr;
		my $row = $sth->fetchrow_hashref;
		$sth->finish;
		my $doms = "";
		if ($row) {
			$doms =
			  $stab->build_dns_drop(
				$row->{ _dbx('DNS_DOMAIN_ID') }, $type );
		}
		my $j = JSON::PP->new->utf8;
		my $r = {
			'NETWORK_INTERFACE_ID' => $niid,
			'domains'              => $doms,
			'DNS_NAME'             => {
				'name' => "DNS_NAME_$niid",
				'id'   => "DNS_NAME_$niid",
				'type' => 'text',
			},
			'DNS_DOMAIN' => {
				'name' => "DNS_DOMAIN_ID_$niid",
				'id'   => "DNS_DOMAIN_ID_$niid",
				'type' => 'input',
			}
		};
		if ($row) {
			if ( exists( $row->{ _dbx('DNS_NAME') } ) ) {
				$r->{"DNS_NAME"}->{'value'} =
				  $row->{ _dbx('DNS_NAME') };
			}
		}
		print $j->encode($r);
	} else {

		# catch-all error condition
		print $cgi->div(
			{ -style => 'text-align: center; padding: 50px', },
			$cgi->em("not implemented yet.") );
	}

	if ( $xml eq 'yes' ) {
		print "</response>\n";
	}

	my $dbh = $stab->dbh;
	if ( $dbh && $dbh->{'Active'} ) {
		$dbh->commit;
	}
	undef $stab;
}
