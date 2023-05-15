#!/usr/bin/env perl

#
# Copyright (c) 2016 Matthew Ragan
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

use FindBin qw($RealBin);
use lib "$RealBin/../../jazzhands/perllib";
use lib "$RealBin/modules";

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long;
use Log::Log4perl;
use FileHandle;
use Socket;

use JazzHands::Common qw(:all);
use JazzHands::DBI;
use JazzHands::AppAuthAL;

use Net::STOMP::Client;
use NetAddr::IP qw(:lower);

use POSIX qw(setsid uname);
use File::Path;
use Pod::Usage;

eval {
	if (-f "$RealBin/modules/_LocalHooks.pm") {
		require _LocalHooks;
	}
};

if ($@) {
	print STDERR $@;
	exit 1;
}

umask 022;

my $help;
my $daemonize = 1;
my $onetime = 0;
my $local_options = {};

my $authapp = 'dhcpgen';

my $conf = {
	rootdir 		=> '/etc/dhcpd',
	workdir 		=> '/etc/dhcpd',
	restart_dhcpd	=> 1,
	logfile 		=> '/var/log/dhcpgen',
	default_lease	=> 3600,
	debug			=> 0,
};

GetOptions(
	'help'				=> \$help,
	'hostname=s'		=> \$conf->{hostname},
	'd|daemonize!'		=> \$daemonize,
	'debug+'			=> \$conf->{debug},
	'l|logfile=s'		=> \$conf->{logfile},
	'o|onetime'			=> sub { $daemonize = 0; $onetime=1 },
	'restart-dhcpd!'	=> \$conf->{restart_dhcpd},
	'w|workdir=s'		=> \$conf->{workdir},
	'rootdir=s'			=> \$conf->{rootdir},
    defined(&_LocalHooks::local_getopts) ?
        _LocalHooks::local_getopts(
            $local_options
        )
    : ()
) or pod2usage(2);

#
# Map JazzHands DHCP properties to dhcpd config options
#
my $option_map = {
	DomainNameServers => {
		option => 'option domain-name-servers',
		type => 'ip_address_list'
	},
	NTPServers => {
		option => 'option ntp-servers',
		type => 'ip_address_list'
	},
	MaxLeaseTime => {
		option => 'max-lease-time',
		type => 'integer'
	},
	MinLeaseTime => {
		option => 'min-lease-time',
		type => 'integer'
	},
	DefaultLeaseTime => {
		option => 'default-lease-time',
		type => 'integer'
	},
	NextServer => {
		option => 'next-server',
		type => 'ip_address'
	},
	DomainName => {
		option => 'option domain-name',
		type => 'quoted_string'

	},
	DomainSearch => {
		option => 'option domain-search',
		type => 'quoted_string_list'
	},
	BootFile =>  {
		option => q !
if substring(option vendor-class-identifier, 0, 9) = "PXEClient" and option PXEArch = 00:00 {
    option bootfile-name "%s";
}
!,
		type => 'string_replacement'
	},
	UEFIBootFile =>  {
		option => q !
if substring(option vendor-class-identifier, 0, 9) = "PXEClient" and option PXEArch = 00:07 {
    option bootfile-name "%s";
}
!,
		type => 'string_replacement'
	},
	ConfigStanza => {
		option => "%s",
		type => 'string_replacement'
	}
};
pod2usage(2) if ($help);

if (!$conf->{hostname}) {
	( undef, $conf->{hostname} ) = uname();
}

#
# Yes, this defeats a lot of the purpose of Log4Perl.  Sue me.
#
my $log;
if ($daemonize) {
	Log::Log4perl::init( 
		{
			"log4perl.rootLogger" => "DEBUG, dhcpgen",
			"log4perl.additivity.dhcpgen" => 0,
			"log4perl.appender.dhcpgen" => "Log::Log4perl::Appender::File",
			"log4perl.appender.dhcpgen.filename" => $conf->{logfile},
			"log4perl.appender.dhcpgen.mode" => "append",
			"log4perl.appender.dhcpgen.layout" => "PatternLayout",
			"log4perl.appender.dhcpgen.layout.ConversionPattern" => "[%d] %m%n",
		}
	);
	$log = Log::Log4perl::get_logger('dhcpgen');

#	daemonize( 'log' => $log );
} else {
	Log::Log4perl->init( {
		"log4perl.rootLogger", "DEBUG, Screen",
		"log4perl.appender.Screen", "Log::Log4perl::Appender::Screen",
		"log4perl.appender.Screen.stderr", 1,
		"log4perl.appender.Screen.layout", "Log::Log4perl::Layout::PatternLayout",
		"log4perl.appender.Screen.layout.ConversionPattern", "[%d] %p: %m%n",
	});
	$log = Log::Log4perl::get_logger('dhcpgen');
}

$log->info ("dhcpgen starting");

if ($onetime) {
	do_rebuild(
		'log' => $log,
		conf => $conf
	);
} else {
	my $record = JazzHands::AppAuthAL::find_and_parse_auth($authapp);
	if (!$record || !$record->{stomp}) {
		printf STDERR "Unable to find STOMP auth entry for %s\n",
			 $authapp;
		exit 1;
	}
	$conf->{stomp} = $record->{stomp};	
	if ($daemonize) {
		daemonize('log' => $log);
	}
	
	handle_stomp_frames(
		conf => $conf,
		'log' => $log
		);
}

sub get_stomp_client {
	my $stompconf = shift;
	my ( undef, $myhostname ) = uname();

	if (!$stompconf->{port} ) {
		$stompconf->{port} = 61613;
	}

	$log->debug( sprintf( "Connecting to STOMP server %s:%s", 
		$stompconf->{host}, $stompconf->{port} ) );

	my $stomp;
	eval {
		$stomp = Net::STOMP::Client->new(
			host => $stompconf->{host},
			port => $stompconf->{port}
		);

		$stomp->connect(
			login	=> $stompconf->{username},
			passcode => $stompconf->{password}
		);

		$stomp->message_callback( sub { return 1; } );
	};

	if ($@) {
		$log->error(
			sprintf(
				"Error connecting to STOMP server %s:%s: %s",
				$stompconf->{host}, $stompconf->{port}, $@
			)
		);
		return undef;
	}

	for my $destination (@{$stompconf->{destinations}}) {
		$log->debug( sprintf( "Subscribing to destination %s", $destination ) );

		eval { 
			$stomp->subscribe( 
				id => $myhostname,
				destination => $destination 
			);
		};

		if ($@) {
			$log->error(
				sprintf( "Error subscribing to destination %s: %s",
					$destination, $@ 
				)
			);
			return undef;
		}
	}

	return $stomp;
}

sub daemonize {
	my $opt = &_options(@_);
	my $log = $opt->{'log'};
	open STDOUT, '>', '/dev/null'
	  or $log->logdie("Unable to redirect STDOUT: $!");
	open STDIN, '<', '/dev/null'
	  or $log->logdie("Unable to redirect STDIN: $!");
	defined( my $pid = fork ) or $log->logdie("Can not fork: $!");
	exit if $pid;
	setsid() or $log->logdie("Unable to initiate new session: $!");
	open STDERR, '>&STDOUT'
	  or $log->logdie("Unable to redirect STDERR: $!");
}

sub handle_stomp_frames {
	my $opt = &_options(@_);

	my $stompconf = $opt->{conf}->{stomp};
	my $log = $opt->{log};
	my $stomp  = get_stomp_client($stompconf);

	if ( !$stomp ) {
		$log->logdie("Cannot create STOMP client");
	}

	while (1) {
		my $rebuild_needed = 0;
		my $stomp_error = 0;
		my @errors;

		$log->info("Waiting for STOMP frames");

		my $frame;
		eval { $frame = $stomp->wait_for_frames; };

		if ($@) {
			$stomp_error = 1;
			$log->error( sprintf( "Error waiting for STOMP frame: %s", $@ ) );
			while (1) {
				$log->debug("Attempting to reconnect to STOMP broker");
				$stomp = get_stomp_client($stompconf);

				if ( !$stomp ) {
					$log->error( "Error reconnecting to STOMP broker, "
						  . "waiting for retry" );
					sleep 60;
				}
				else {
					last;
				}
			}
		}

		if ($stomp_error) {
			next;
		}

		#
		# Skip anything that isn't a MESSAGE frame
		#
		next if $frame->command ne "MESSAGE";

		while ($frame) {
			if ($conf->{debug}) {
				$log->debug(Data::Dumper->Dump([$frame], ['frame']));
			}
			my $body = $frame->body;
			my $headers = $frame->headers;
			if ($body eq 'update') {
				$log->info("Received rebuild frame");

				$rebuild_needed = 1;
			} else {
				$log->warn( "Received unparsable message: " . $body );
			}
			#
			# If there's anything else pending, go do it.
			#
			$frame = $stomp->wait_for_frames(timeout => .1);
		}
		if ($rebuild_needed) {
			do_rebuild(
				'log' => $log,
				conf => $conf
			);
		}
	}
	$stomp->disconnect;
}

sub do_rebuild {
	my $opt = &_options(@_);

	my $conf = $opt->{conf};
	my @errors;
	my $log = $opt->{'log'};

	my $jh;
	my $ret;

	$ret = generate_dhcp_configs(
		conf => $conf,
		errors => \@errors
	);

	if ($ret) {
		$log->info ("Rebuild completed successfully");
		if ($conf->{restart_dhcpd}) {
			if (-x "/etc/init.d/dhcpd") {
				system("/etc/init.d/dhcpd restart");
			} if (-x "/etc/init.d/isc-dhcp-server") {
				system("/etc/init.d/isc-dhcp-server restart");
			}
		}
	} else {
		$log->error(sprintf("FAIL: %s", join ("\n", @errors)));
	}
}


sub generate_dhcp_configs {
	my $opt = &_options(@_);

	my $conf = $opt->{conf};
	my $err = $opt->{errors};

	if (!$conf->{hostname}) {
		( undef, $conf->{hostname} ) = uname();
	}

	my $jh;
	if (!($jh = JazzHands::DBI->new->connect(
			application => $authapp,
			cached => 1,
			))) {
		SetError($err,
			"Unable to connect to database: " . $JazzHands::DBI::errstr);
		return undef;
	} else {
		$log->info ("Beginning DHCP rebuild");
	}

	my ($q, $sth);
	
	#
	# Pull DHCP property information
	#
	$q = q {
		SELECT
			layer2_network_collection_id,
			property_name,
			is_multivalue,
			property_rank,
			COALESCE(property_value, device_name) AS
				property_value,
			ip_address
		FROM (
			SELECT
				layer2_network_collection_id,
				property_name,
				property_type,
				property_value,
				property_value_nblk_coll_id,
				property_value_device_coll_id,
				property_rank,
				level,
				MIN(level) OVER 
					(PARTITION BY layer2_network_collection_id, property_name)
					AS minlevel
				FROM (
					SELECT
						root_l2_network_coll_id as layer2_network_collection_id,
						property_name,
						property_type,
						property_value,
						property_value_nblk_coll_id,
						property_value_device_coll_id,
						property_rank,
						level
					FROM
						v_l2_network_coll_expanded l2ce JOIN
						layer2_network_collection l2c USING
							(layer2_network_collection_id) JOIN
						property p USING (layer2_network_collection_id)
					WHERE
						property_type = 'DHCP' AND
						layer2_network_collection_type = 'DHCP'
					UNION SELECT
						l2n.layer2_network_collection_id,
						property_name,
						property_type,
						property_value,
						property_value_nblk_coll_id,
						property_value_device_coll_id,
						property_rank,
						131072
					FROM
						layer2_network_collection l2n,
						property p
					WHERE
						p.property_type = 'DHCP' AND
						p.layer2_network_collection_id IS NULL AND
						p.network_range_id IS NULL AND
						p.device_collection_id IS NULL
				) x
			) y LEFT JOIN 
			device_collection dc ON (y.property_value_device_coll_id = 
				dc.device_collection_id) LEFT JOIN
			device_collection_device dcd USING (device_collection_id) LEFT JOIN
			device d USING (device_id) LEFT JOIN
			netblock_collection nc ON (y.property_value_nblk_coll_id = 
				nc.netblock_collection_id) LEFT JOIN
			netblock_collection_netblock ncn USING (netblock_collection_id)
				LEFT JOIN
			netblock n ON (ncn.netblock_id = n.netblock_id AND 
				family(ip_address) = 4) JOIN
			val_property pt USING (property_name, property_type)
		WHERE
			level = minlevel
		ORDER BY layer2_network_collection_id, property_name, property_rank
	};

	if (!($sth = $jh->prepare_cached($q))) {
		SetError($err, 
			sprintf("Unable to prepare DHCP property query: %s",
			$jh->errstr));
		return undef;
	}

	if (!($sth->execute)) {
		SetError($err,
			sprintf("Unable to execute DHCP layer2_network property query: %s",
			$sth->errstr));
		return undef;
	}


	my $l2_props = {};

	while (my $row = $sth->fetchrow_hashref) {
		if ($row->{ip_address}) {
			$row->{property_value} = NetAddr::IP->new($row->{ip_address});
		}
		if ($row->{is_multivalue} eq 'N') {
			#
			# Things may be single-value, but actually return multiple
			# rows if it's an expanded IP address
			#
			if (exists($l2_props->{$row->{layer2_network_collection_id}}->
					{$row->{property_name}})) {

				if (ref($l2_props->{$row->{layer2_network_collection_id}}->
						{$row->{property_name}}) eq 'ARRAY') {
					push @{$l2_props->{$row->{layer2_network_collection_id}}->
								{$row->{property_name}}}, 
							$row->{property_value};
				} else {
					$l2_props->{$row->{layer2_network_collection_id}}->
							{$row->{property_name}} = [ 
						$l2_props->{$row->{layer2_network_collection_id}}->
							{$row->{property_name}},
						$row->{property_value} 
					];
				}
			} else {
				$l2_props->{$row->{layer2_network_collection_id}}->
					{$row->{property_name}} = $row->{property_value};
			}
		} else {
			if (!exists($l2_props->{$row->{layer2_network_collection_id}}->
					{$row->{property_name}})) {
				$l2_props->{$row->{layer2_network_collection_id}}->
					{$row->{property_name}} = [ $row->{property_value} ];
			} else {
				push @{$l2_props->{$row->{layer2_network_collection_id}}->
					{$row->{property_name}}}, $row->{property_value};
			}
		}
	}
	$sth->finish;

	$q = q {
		SELECT
			network_range_id,
			property_name,
			is_multivalue,
			property_rank,
			COALESCE(property_value, device_name) AS
				property_value,
			ip_address
		FROM
			network_range nr JOIN
			property p USING (network_range_id) LEFT JOIN
			device_collection dc ON (p.property_value_device_coll_id = 
				dc.device_collection_id) LEFT JOIN
			device_collection_device dcd ON (dcd.device_collection_id = 
				dc.device_collection_id) LEFT JOIN
			device d USING (device_id) LEFT JOIN
			netblock_collection nc ON (p.property_value_nblk_coll_id = 
				nc.netblock_collection_id) LEFT JOIN
			netblock_collection_netblock ncn ON (ncn.netblock_collection_id =
				nc.netblock_collection_id) LEFT JOIN
			netblock n ON (ncn.netblock_id = n.netblock_id AND 
				family(ip_address) = 4) JOIN
			val_property pt USING (property_name, property_type)
		WHERE
			p.property_type = 'DHCP' AND
			nr.network_range_type = 'dhcp_lease_pool'
		ORDER BY network_range_id, property_name, property_rank
	};

	if (!($sth = $jh->prepare_cached($q))) {
		SetError($err, 
			sprintf("Unable to prepare DHCP property query: %s",
			$jh->errstr));
		return undef;
	}

	if (!($sth->execute)) {
		SetError($err,
			sprintf("Unable to execute DHCP network_range property query: %s",
			$sth->errstr));
		return undef;
	}


	my $netrange_props = {};

	while (my $row = $sth->fetchrow_hashref) {
		if ($row->{ip_address}) {
			$row->{property_value} = NetAddr::IP->new($row->{ip_address});
		}
		if ($row->{is_multivalue} eq 'N') {
			#
			# Things may be single-value, but actually return multiple
			# rows if it's an expanded IP address
			#
			if (exists($netrange_props->{$row->{network_range_id}}->
					{$row->{property_name}})) {
				if (ref($netrange_props->{$row->{network_range_id}}->
						{$row->{property_name}}) eq 'ARRAY') {
					push @{$netrange_props->{$row->{network_range_id}}->
							{$row->{property_name}}},
						$row->{property_value};
				} else {
					$netrange_props->{$row->{network_range_id}}->
						{$row->{property_name}} = [
							$netrange_props->{$row->{network_range_id}}->
								{$row->{property_name}},
							$row->{property_value}
						];
				}
			} else {
				$netrange_props->{$row->{network_range_id}}->
					{$row->{property_name}} = $row->{property_value};
			}
		} else {
			if (!exists($netrange_props->{$row->{network_range_id}}->
					{$row->{property_name}})) {
				$netrange_props->{$row->{network_range_id}}->
					{$row->{property_name}} = [ $row->{property_value} ];
			} else {
				push @{$netrange_props->{$row->{network_range_id}}->
					{$row->{property_name}}}, $row->{property_value};
			}
		}
	}
	$sth->finish;


	$q = q {
		SELECT 
			device_id,
			property_name,
			is_multivalue,
			property_rank,
			property_value,
			ip_address
		FROM (
			SELECT
				d.device_id,
				property_id,
				property_name,
				is_multivalue,
				device_collection_level,
				MIN(device_collection_level) OVER (PARTITION BY property_name, d.device_id) AS min_dev_coll_level,
				property_rank,
				COALESCE(property_value, td.device_name) AS
					property_value,
				ip_address
			FROM
				device d JOIN
				device_collection_device dcd USING (device_id) JOIN
				v_device_coll_hier_detail dchd USING (device_collection_id) JOIN
				device_collection dc USING (device_collection_id) JOIN
				property p ON (dchd.parent_device_collection_id = p.device_collection_id)
					LEFT JOIN
				device_collection tdc ON (p.property_value_device_coll_id =
					tdc.device_collection_id) LEFT JOIN
				device_collection_device tdcd ON (tdcd.device_collection_id =
					tdc.device_collection_id) LEFT JOIN
				device td ON (tdcd.device_id = td.device_id) LEFT JOIN
				netblock_collection nc ON (p.property_value_nblk_coll_id =
					nc.netblock_collection_id) LEFT JOIN
				netblock_collection_netblock ncn ON (ncn.netblock_collection_id =
					nc.netblock_collection_id) LEFT JOIN
				netblock n ON (ncn.netblock_id = n.netblock_id AND
					family(ip_address) = 4) JOIN
				val_property pt USING (property_name, property_type)
			WHERE
				property_type = 'DHCP' 
		) x
		WHERE
			device_collection_level = min_dev_coll_level
        ORDER BY device_id, property_name, device_collection_level, property_rank, property_id
	};

	if (!($sth = $jh->prepare_cached($q))) {
		SetError($err, 
			sprintf("Unable to prepare DHCP property query: %s",
			$jh->errstr));
		return undef;
	}

	if (!($sth->execute)) {
		SetError($err,
			sprintf("Unable to execute DHCP device property query: %s",
			$sth->errstr));
		return undef;
	}


	my $device_props = {};

	while (my $row = $sth->fetchrow_hashref) {
		if ($row->{ip_address}) {
			$row->{property_value} = NetAddr::IP->new($row->{ip_address});
		}
		if ($row->{is_multivalue} eq 'N') {
			#
			# Things may be single-value, but actually return multiple
			# rows if it's an expanded IP address
			#
			if (exists($device_props->{$row->{device_id}}->
					{$row->{property_name}})) {
				if (ref($device_props->{$row->{device_id}}->
						{$row->{property_name}}) eq 'ARRAY') {
					push @{$device_props->{$row->{device_id}}->
							{$row->{property_name}}},
						$row->{property_value};
				} else {
					$device_props->{$row->{device_id}}->
						{$row->{property_name}} = [
							$device_props->{$row->{device_id}}->
								{$row->{property_name}},
							$row->{property_value}
						];
				}
			} else {
				$device_props->{$row->{device_id}}->
					{$row->{property_name}} = $row->{property_value};
			}
		} else {
			if (!exists($device_props->{$row->{device_id}}->
					{$row->{property_name}})) {
				$device_props->{$row->{device_id}}->
					{$row->{property_name}} = [ $row->{property_value} ];
			} else {
				push @{$device_props->{$row->{device_id}}->
					{$row->{property_name}}}, $row->{property_value};
			}
		}
	}
	$sth->finish;

	#
	# Pull out all layer2/layer3 information for IPv4 networks
	#
	$q = q {
		SELECT
			layer3_network_id,
			layer2_network_collection_id,
			layer2_network_id,
			l2.encapsulation_name,
			l2.encapsulation_type,
			l2.encapsulation_domain,
			l2.encapsulation_tag,
			l2.description as layer2_description,
			concat_ws('-',
				l2.encapsulation_domain,
				l2.encapsulation_tag,
				l2.layer2_network_id
			) as layer2_unique_label,
			n.netblock_id,
			n.ip_address as netblock_address,
			dg.ip_address as gateway_address
		FROM
			layer2_network_collection l2nc JOIN
			l2_network_coll_l2_network USING (layer2_network_collection_id)
				JOIN
			layer2_network l2 USING (layer2_network_id) JOIN
			layer3_network l3 USING (layer2_network_id) JOIN
			netblock n USING (netblock_id) JOIN
			netblock dg ON (l3.default_gateway_netblock_id = dg.netblock_id)
		WHERE
			layer2_network_collection_type = 'DHCP' AND
			family(n.ip_address) = 4;
	};

	if (!($sth = $jh->prepare_cached($q))) {
		SetError($err, 
			sprintf("Unable to prepare DHCP network query: %s",
			$jh->errstr));
		return undef;
	}

	if (!($sth->execute)) {
		SetError($err,
			sprintf("Unable to execute DHCP network query: %s",
			$sth->errstr));
		return undef;
	}

	my $layer2_networks;
	while (my $row = $sth->fetchrow_hashref) {
		if (!exists $layer2_networks->{$row->{layer2_network_id}}) {
			$layer2_networks->{$row->{layer2_network_id}} = {
				map { $_, $row->{$_} } ( qw (
					layer2_network_id
					layer2_network_collection_id
					layer2_unique_label
					encapsulation_type
					encapsulation_domain
					encapsulation_tag
					layer2_description
				) )
			};
			$layer2_networks->{$row->{layer2_network_id}}->{layer3_networks} = [];
		}
		if ($row->{netblock_address}) {
			$row->{netblock_address} = 
				NetAddr::IP->new($row->{netblock_address});
		}
		if ($row->{gateway_address}) {
			$row->{gateway_address} = 
				NetAddr::IP->new($row->{gateway_address});
		}
		push @{$layer2_networks->{$row->{layer2_network_id}}->{layer3_networks}},
			{ map { $_, $row->{$_} } ( qw (
					layer3_network_id
					netblock_id
					netblock_address
					gateway_address
				) )
			};
	}
	$sth->finish;

	$q = q {
		SELECT
			network_range_id,
			l3.layer2_network_id,
			n.netblock_id,
			sn.ip_address AS start_address,
			en.ip_address AS stop_address
		FROM
			network_range r JOIN
			netblock n ON (r.parent_netblock_id = n.netblock_id) JOIN
			netblock sn ON (sn.netblock_id = r.start_netblock_id) JOIN
			netblock en ON (en.netblock_id = r.stop_netblock_id) JOIN
			layer3_network l3 ON (r.parent_netblock_id = l3.netblock_id)
		WHERE
			network_range_type = 'dhcp_lease_pool' AND
			family(n.ip_address) = 4
	};


	if (!($sth = $jh->prepare_cached($q))) {
		SetError($err, 
			sprintf("Unable to prepare DHCP network_range query: %s",
			$jh->errstr));
		return undef;
	}

	if (!($sth->execute)) {
		SetError($err,
			sprintf("Unable to execute DHCP network_range query: %s",
			$sth->errstr));
		return undef;
	}

	# Pull out all of the network ranges by layer2_network_id

	my $netranges = {};
	while (my $row = $sth->fetchrow_hashref) {
		$row->{start_address} = NetAddr::IP->new($row->{start_address});
		$row->{stop_address} = NetAddr::IP->new($row->{stop_address});
		if (exists($netranges->{$row->{layer2_network_id}})) {
			push @{$netranges->{$row->{layer2_network_id}}}, $row;
		} else {
			$netranges->{$row->{layer2_network_id}} = [ $row ];
		}
	}
	$sth->finish;

	# Pull out information for all of the devices/network_interfaces with
	# direct MAC->IP address mappings.  The second part of this union
	# needs to be overhauled after we do some rearrangement of how bonded
	# devices are represented for Linux

	$q = q {
		SELECT
			dhcp.device_id,
			dhcp.device_name,
			dhcp.physical_label,
			dhcp.network_interface_id,
			dhcp.network_interface_name,
			dhcp.mac_addr,
			dhcp.other_network_interface_id,
			dhcp.other_network_interface_name,
			dhcp.netblock_id,
			n.ip_address,
			l3.layer3_network_id,
			l3.layer2_network_id
		FROM
			(SELECT
				d.device_id,
				d.device_name,
				d.physical_label,
				ni.network_interface_id,
				ni.network_interface_name,
				ni.mac_addr,
				NULL AS other_network_interface_id,
				NULL AS other_network_interface_name,
				nin.netblock_id
			FROM
				device d JOIN
				network_interface ni USING (device_id) JOIN
				network_interface_netblock nin USING (network_interface_id)
			WHERE
				ni.mac_addr IS NOT NULL
			UNION
			SELECT
				d.device_id,
				d.device_name,
				d.physical_label,
				ni1.network_interface_id,
				ni1.network_interface_name,
				ni1.mac_addr,
				ni2.network_interface_id,
				ni2.network_interface_name,
				ni2.netblock_id
			FROM
				device d JOIN
				(
					SELECT
						ni.device_id,
						ni.network_interface_id,
						ni.network_interface_name,
						ni.mac_addr
					FROM
						network_interface ni LEFT JOIN
						network_interface_netblock nin
							USING (network_interface_id)
					WHERE
						mac_addr IS NOT NULL AND
						netblock_id IS NULL
				) ni1 ON (d.device_id = ni1.device_id) JOIN
				(
					SELECT
						ni.device_id,
						ni.network_interface_id,
						ni.network_interface_name,
						nin.netblock_id,
						rank() OVER
							(PARTITION BY ni.device_id ORDER BY network_interface_name) AS
							ni_rank
					FROM
						network_interface ni JOIN
						network_interface_netblock nin
							USING (network_interface_id)
					WHERE
						mac_addr IS NULL
				) ni2 ON (d.device_id = ni2.device_id AND ni2.ni_rank = 1)
			) dhcp JOIN
			netblock n ON (
				dhcp.netblock_id = n.netblock_id AND
				family(n.ip_address) = 4
			) JOIN
			layer3_network l3 ON (n.parent_netblock_id = l3.netblock_id)
	};

	if (!($sth = $jh->prepare_cached($q))) {
		SetError($err, 
			sprintf("Unable to prepare DHCP assignment query: %s",
			$jh->errstr));
		return undef;
	}

	if (!($sth->execute)) {
		SetError($err,
			sprintf("Unable to execute DHCP assignment query: %s",
			$sth->errstr));
		return undef;
	}

	my $devices = {};
	while (my $row = $sth->fetchrow_hashref) {
		next if (
			!defined($row->{layer2_network_id}) ||
			!exists($layer2_networks->{$row->{layer2_network_id}})
		);

		if (exists($layer2_networks->{$row->{layer2_network_id}}->
				{dhcp_assignments})) {
			push @{$layer2_networks->{$row->{layer2_network_id}}->
				{dhcp_assignments}}, $row;
		} else {
			$layer2_networks->{$row->{layer2_network_id}}->
				{dhcp_assignments} = [ $row ];
		}
		if ($row->{ip_address}) {
			$row->{ip_address} = NetAddr::IP->new($row->{ip_address});
		} 
		if (!($devices->{$row->{device_id}})) {
			$devices->{$row->{device_id}} = [];
		}
		push @{$devices->{$row->{device_id}}}, $row;
	}
	$sth->finish;

	#
	# At this point, we've pulled everything out of the database that we
	# should need, so start pulling things together and writing files for
	# this host
	#

	my $rootdir = $conf->{rootdir} || '.';
	my $workdir = $conf->{workdir} || '.';
	my $autodir = $workdir . "/automatic";
	if (! -e $autodir && !(mkdir $autodir)) {
		SetError($err, sprintf("Unable to create working directory '%s': %s",
			$autodir, $!));
		return undef;
	}

	my $masterfh = new FileHandle $autodir . '/master.conf',
		O_WRONLY|O_CREAT|O_TRUNC;
		
	print $masterfh <<EOM;
#
# Autogenerated DHCP configuration file
# DO NOT MAKE MANUAL CHANGES TO THIS FILE.  THEY WILL BE OVERWRITTEN.
#
option PXEArch code 93 = unsigned integer 16;
EOM

	foreach my $l2_net (
		sort { 
			$a->{encapsulation_domain} cmp $b->{encapsulation_domain} ||
			$a->{encapsulation_tag} <=> $b->{encapsulation_tag}

		} values %$layer2_networks
	) {
		my $fn = sprintf("%s/%s.conf", $autodir, $l2_net->{layer2_unique_label});
		printf $masterfh qq {include "%s/automatic/%s.conf";\n},
			$rootdir, $l2_net->{layer2_unique_label};

		if ($conf->{debug}) {
			printf "Processing %s\n", $fn;
		}
		my $l2fh = new FileHandle $fn, O_WRONLY|O_CREAT|O_TRUNC;

		print $l2fh <<EOM;
#
# Autogenerated DHCP configuration file
# DO NOT MAKE MANUAL CHANGES TO THIS FILE.  THEY WILL BE OVERWRITTEN.
#
EOM
		my $indent = "\t";
		my $shared_network = 0;
		if (scalar(@{$l2_net->{layer3_networks}}) > 1) {
			printf $l2fh "shared-network %s {\n", $l2_net->{layer2_unique_label};
			$indent = "\t\t";
			$shared_network = 1;
		}
	
		my $l3_count = 0;
		foreach my $l3_net (@{$l2_net->{layer3_networks}}) {
			next if ($l3_net->{netblock_address}->masklen <= 19 || 
				$l3_net->{netblock_address}->masklen > 30);
			printf $l2fh <<EOF
%ssubnet %s netmask %s {
%s	option routers %s;
EOF
,
				$shared_network ? "\t" : "",
				$l3_net->{netblock_address}->addr,
				$l3_net->{netblock_address}->mask,
				$shared_network ? "\t" : "",
				$l3_net->{gateway_address}->addr;
			my $props = $l2_props->{$l2_net->{layer2_network_collection_id}};
			foreach my $option (sort keys %$option_map) {
				my $val;
				if (defined($val = $props->{$option})) {
				printf $l2fh qq {%s%s\n},
					$indent,
					FormatOption(
						$option_map->{$option},
						$val,
						$indent);
				}
			}

			printf $l2fh "%s}\n", ${indent} if $shared_network;
			$l3_count += 1;
		}

		#
		# Spit out any DHCP lease pools associated with this layer2_network
		# if we're supposed to be a DHCP server of record for it
		#
		# For now, we are not supporting DHCP failover setups, but that
		# should hopefully change in the near future, so any pools will
		# only be installed on the primary DHCP server for a given range
		#

		foreach my $nr (@{$netranges->{$l2_net->{layer2_network_id}}}) {
			my $props = $netrange_props->{$nr->{network_range_id}};
			my $primary = $props->{PrimaryDHCPServer} || 
				$l2_props->{$l2_net->{layer2_network_collection_id}}->
					{PrimaryDHCPServer};
			if ($primary && $conf->{hostname} && $primary eq $conf->{hostname}) {
				printf $l2fh "\tpool {\n\t\trange %s %s;\n",
					$nr->{start_address}->addr,
					$nr->{stop_address}->addr;

				foreach my $option (sort keys %$option_map) {
					my $val;
					if (defined($val = $props->{$option})) {
						printf $l2fh qq {\t\t%s\n},
							FormatOption(
								$option_map->{$option},
								$val,
								$indent); }
				}

				print $l2fh "\t}\n";
			}
		}
		print $l2fh "}\n" if $l3_count;
		#
		# Spit out host assignments that are associated with this
		# layer2 network, even though they are global declarations
		#
		if (exists($l2_net->{dhcp_assignments})) {
			print $l2fh <<EOF;
##
## NOTE: The following host declarations are global.  They are located here
## as an attempt to group them with the layer2 networks that the IP address
## is associate with
##
EOF

			foreach my $host (sort { $a->{ip_address} <=> $b->{ip_address} } 
					@{$l2_net->{dhcp_assignments}}) {
				printf $l2fh 
					qq!
# %s (%s) device_id %d, network_interface %d, netblock %d
host %s-%d-%d-%d {
	hardware ethernet %s;
	fixed-address %s;
	option host-name = "%s";
!,
					($host->{device_name} || 'unnamed device'),
					($host->{physical_label} || 'unlabeled device'),
					$host->{device_id},
					$host->{network_interface_id},
					$host->{netblock_id},
					$host->{device_name} || $host->{physical_label} || 
						'device',
					$host->{device_id},
					$host->{network_interface_id},
					$host->{netblock_id},
					$host->{mac_addr},
					$host->{ip_address}->addr,
					$host->{physical_label} || $host->{device_name} ||
						('device' . $host->{device_id});

				if (my $props = $device_props->{$host->{device_id}}) {
					foreach my $option (sort keys %$option_map) {
						my $val;
						if (defined($val = $props->{$option})) {
							printf $l2fh qq {\t%s\n},
								FormatOption(
									$option_map->{$option},
									$val,
									$indent);
						}
					}
				}
				print $l2fh "}\n";
			}
		}

		close $l2fh;
	}
	close $masterfh;

	if (defined(&_LocalHooks::postrun)) {
		_LocalHooks::postrun(
			dbh => $jh,
			conf => $conf,
			local_options => $local_options,
			log => $log,
			errors => $err,
			devices => $devices,
			layer2_networks => $layer2_networks,
			network_ranges => $netranges,
			layer2_properties => $l2_props,
			network_range_properties => $netrange_props,
			device_properties => $device_props
		);
	}	
	return 1;
}

sub FormatOption {
	my $type = shift;
	my $val = shift;
	my $indent = shift;
	my $ret;
			
	if ($type->{type} eq 'integer') {
		if ($val =~ /^\d+/) {
			$ret = sprintf(qq {%s %d;},
				$type->{option},
				$val);
		}
	} elsif ($type->{type} eq 'quoted_string') {
		$ret = sprintf(qq{%s "%s";},
			$type->{option},
			$val);
	} elsif ($type->{type} eq 'string_replacement') {
		if (ref($val) eq 'ARRAY') {
			$ret = join ("\n", map { 
				sprintf($type->{option}, $_)
			} @$val);
		}  else {
			$ret = sprintf($type->{option}, $val);
		}
	} elsif ($type->{type} eq 'quoted_string_list') {
		$ret = sprintf(qq{%s %s;},
			$type->{option},
			join (', ', (map { qq{"$_"} }
				ref($val) eq 'ARRAY' ?  @$val : ( $val ))));
	} elsif ($type->{type} eq 'ip_address') {
		$ret = sprintf(qq{%s %s;},
			$type->{option},
			$val->addr);
	} elsif ($type->{type} eq 'ip_address_list') {
		$ret = sprintf(qq{%s %s;},
			$type->{option},
			join (', ', (map { $_->addr } 
				ref($val) eq 'ARRAY' ?  @$val : ( $val ))));
	}
	if ($indent) {
		$ret =~ s/\n/\n${indent}/g;
	}
	return $ret;
}
