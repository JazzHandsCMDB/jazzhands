#!/usr/bin/env perl

# Copyright (c) 2017, Matthew Ragan
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use FindBin qw($RealBin);

use JazzHands::NetDev::Mgmt;
use Term::ReadKey;

use Data::Dumper;
use Pod::Usage;
use Getopt::Long;
use Socket;
use JazzHands::DBI;
use JSON::XS;

use strict;
use warnings;

umask 022;

my $help = 0;
my $debug = 0;
my $verbose = 0;
my $parallel = 0;
my $probe_addresses = 0;
my $probe_interfaces = 0;

my $filename;
my $commit = 1;
#my $user = $ENV{'USER'};
my $user;
my $password;
my $site_code;
my $timeout;
my $connect_name = undef;
my $hostname = [];
my $conf_mgmt_type = undef;
my $authapp = 'net_dev_probe';

sub loggit {
	printf STDERR join "\n", @_;
	print "\n";
}

if (!(GetOptions(
	'username=s', \$user,
	'commit!', \$commit,
	'connect-name=s', \$connect_name,
	'hostname=s', $hostname,
	'management-type=s', \$conf_mgmt_type,
	'timeout=i', \$timeout,
	'site-code=s', \$site_code,
	'probe-addresses!', \$probe_addresses,
	'probe-interfaces!', \$probe_interfaces,
	'debug+', \$debug,
	'verbose+', \$verbose,
	'parallel!', \$parallel,
	'file=s', \$filename
))) {
	exit 1;
};

#
# Add the rest of the arguments as additional hosts
#
push @$hostname, @ARGV;

my $credentials;
if (!@$hostname) {
	print STDERR "Must provide --hostname\n";
	exit 1;
}

if ($user) {
	print STDERR 'Password: ';
	ReadMode('noecho');
	chomp($password = <STDIN>);
	ReadMode(0);
	print STDERR "\n";

	if (!$password) {
		print STDERR "Password required\n";
		exit 1;
	}
	$credentials->{username} = $user;
	$credentials->{password} = $password;
} else {
	my $record = JazzHands::AppAuthAL::find_and_parse_auth($authapp);
	if (!$record || !$record->{network_device}) {
		loggit(sprintf("Unable to find network_device auth entry for %s.",
			 $authapp));
		exit 1;
	}
	$credentials = $record->{network_device};
}

my $dbh;
my @errors;

if (!($dbh = JazzHands::DBI->new->connect(
			application => $authapp,
			cached => 1,
			dbiflags => {
				AutoCommit => 0,
				PrintError => 1,
			}
		))) {
	printf STDERR "WTF?: %s\n", $JazzHands::DBI::errstr;
	exit 1;
}

$dbh->do('SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ');
my $mgmt = new JazzHands::NetDev::Mgmt;

##
## Prepare all of the database queries we're going to need
##

my $q;

$q = q {
	SELECT
		d.device_id,
		d.device_name,
		d.host_id,
		d.component_id,
		dt.device_type_id,
		dt.device_type_name,
		d.physical_label,
		dt.config_fetch_type
	FROM
		device d JOIN
		device_type dt USING (device_type_id)
	WHERE
		(lower(device_name) = lower(?) OR
		lower(physical_label) = lower(?)) AND
		device_status != 'removed'
};

my $dev_by_ip_sth;

if (!($dev_by_ip_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}

$q = q {
	WITH parms AS (
		SELECT
			?::integer AS device_id,
			?::text AS device_name,
			?::text AS device_type_name
	) UPDATE
		device d
	SET
		device_name = parms.device_name,
		physical_label = parms.device_name,
		device_type_id = dt.device_type_id
	FROM
		device_type dt,
		parms
	WHERE
		d.device_id = parms.device_id AND
		dt.device_type_name = parms.device_type_name
	RETURNING *
};

my $upd_dev_sth;

if (!($upd_dev_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}

$q = q {
	WITH parms AS (
		SELECT
			?::text AS device_name,
			?::text AS device_type_name,
			?::text AS site_code
	) INSERT INTO device (
		device_type_id,
		device_name,
		physical_label,
		site_code,
		device_status,
		service_environment_id,
		is_virtual_device
	) SELECT
		device_type_id,
		parms.device_name,
		parms.device_name,
		parms.site_code,
		'up',
		service_environment_id,
		false
	FROM
		service_environment se,
		device_type dt,
		parms
	WHERE
		service_environment_name = 'production' AND
		dt.device_type_name = parms.device_type_name
	RETURNING
		*
};

my $ins_dev_sth;

if (!($ins_dev_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}


$q = q {
	WITH parms AS (
		SELECT
			?::integer AS device_id,
			?::text AS layer3_interface_name,
			?::text AS ip_addr
	), upd_nb AS (
		UPDATE
			netblock n
		SET
			netblock_type = 'default',
			parent_netblock_id = netblock_utils.find_best_parent_id(
				in_ipaddress := parms.ip_addr::inet
			)
		FROM
			parms
		WHERE
			host(n.ip_address) = parms.ip_addr AND
			is_single_address = true AND
			netblock_type = 'dns'
	), l3i AS (
		INSERT INTO layer3_interface (
			device_id,
			layer3_interface_name,
			layer3_interface_type,
			should_monitor
		) SELECT
			parms.device_id,
			parms.layer3_interface_name,
			'broadcast',
			true
		FROM
			parms
		RETURNING *
	)
	INSERT INTO layer3_interface_netblock (
		netblock_id,
		layer3_interface_id
	) SELECT
		n.netblock_id,
		l3i.layer3_interface_id
	FROM
		l3i,
		parms,
		netblock n
	WHERE
		host(n.ip_address) = parms.ip_addr AND
		is_single_address = true
};

my $ins_l3i_sth;

if (!($ins_l3i_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}

$q = q {
	UPDATE
		netblock n
	SET
		netblock_type = 'default'
	WHERE
		host(n.ip_address) = ? AND
		is_single_address = 'Y' AND
		netblock_type = 'dns'
};

my $upd_nb_sth;

if (!($upd_nb_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}

$q = q {
	UPDATE
		layer3_interface
	SET
		layer3_interface_name = ?
	WHERE
		layer3_interface_id = ?
};

my $upd_l3i_sth;

if (!($upd_l3i_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}

$q = q {
	UPDATE
		device
	SET
		host_id = ?
	WHERE
		device_id = ?
};

my $set_hi_sth;

if (!($set_hi_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}

$q = q {
	UPDATE
		component c
	SET
		component_type_id = ct.component_type_id
	FROM
		component_type ct,
		component_type oct
	WHERE
		c.component_id = ? AND
		c.component_type_id = oct.component_type_id AND
		ct.company_id = oct.company_id AND
		ct.model = ?
};

my $upd_ct_sth;

if (!($upd_ct_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}

$q = q {
	UPDATE
		asset a
	SET
		serial_number = ?
	WHERE
		a.asset_id = ?
};

my $set_sn_sth;

if (!($set_sn_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}

$q = q {
	INSERT INTO asset (
		component_id,
		serial_number,
		ownership_status
	) VALUES (
		?,
		?,
		'leased'
	)
};

my $ins_asset_sth;

if (!($ins_asset_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}

$q = q {
	WITH parms AS (
		SELECT
			?::integer	AS slot_id,
			?::text		AS company_name,
			?::text		AS model,
			?::text		AS serial
	), comp_fetch AS (
		SELECT * FROM component_utils.fetch_component(
			component_type_id := (
				SELECT
					ct.component_type_id
				FROM
					component_type ct JOIN
					company c USING (company_id),
					parms
				WHERE
					c.company_name = parms.company_name AND
					ct.model = parms.model
			),
			serial_number := (SELECT parms.serial FROM parms)
		)
	) UPDATE
		component c
	SET
		parent_slot_id = parms.slot_id
	FROM
		parms,
		comp_fetch
	WHERE
		c.component_id = comp_fetch.component_id
};

my $ins_component_sth;

if (!($ins_component_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}

$q = q {
	WITH parms AS (
		SELECT
			?::integer	AS device_id,
			?::text		AS company_name,
			?::text		AS model,
			?::text		AS serial
	), comp_fetch AS (
		SELECT * FROM component_utils.fetch_component(
			component_type_id := (
				SELECT
					ct.component_type_id
				FROM
					component_type ct JOIN
					company c USING (company_id),
					parms
				WHERE
					c.company_name = parms.company_name AND
					ct.model = parms.model
			),
			serial_number := (SELECT parms.serial FROM parms)
		)
	) UPDATE
		device d
	SET
		component_id = comp_fetch.component_id
	FROM
		parms,
		comp_fetch
	WHERE
		d.device_id = parms.device_id
};

my $dev_component_sth;

if (!($dev_component_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}


$q = q {
SELECT
	s.slot_id,
	s.slot_name,
	c.component_id,
	ct.component_type_id,
	ct.model,
	a.asset_id,
	a.serial_number
FROM
	device d LEFT JOIN
	component p USING (component_id) LEFT JOIN
	slot s USING (component_id) LEFT JOIN
	component c ON (s.slot_id = c.parent_slot_id) LEFT JOIN
	component_type ct ON
		(c.component_type_id = ct.component_type_id) LEFT JOIN
	asset a ON (a.component_id = c.component_id)
WHERE
	device_id = ?
};

my $dev_components_sth;

if (!($dev_components_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}

$q = q {
SELECT
	c.component_id,
	ct.component_type_id,
	ct.model,
	a.asset_id,
	a.serial_number
FROM
	device d LEFT JOIN
	component c USING (component_id) LEFT JOIN
	component_type ct ON
		(c.component_type_id = ct.component_type_id) LEFT JOIN
	asset a ON (a.component_id = c.component_id)
WHERE
	device_id = ?
};

my $dev_asset_sth;

if (!($dev_asset_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}

$q = q {
SELECT
	operating_system_name,
	major_version,
	version
FROM
	device d JOIN
	operating_system os USING (operating_system_id)
WHERE
	device_id = ?
};

my $pull_os_version_sth;

if (!($pull_os_version_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}

$q = q {
SELECT * FROM device_manip.set_operating_system(
	device_id := ?,
	operating_system_name := ?,
	operating_system_family := ?,
	operating_system_version := ?,
	operating_system_major_version := ?,
	operating_system_company_name := ?
)
};

my $set_os_version_sth;

if (!($set_os_version_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}

foreach my $host (@$hostname) {
	undef @errors;
	my $chassisinfo;
	my $db_dev;

	if ($filename) {
		my $fh;
        if (!(open ($fh, '<', $filename))) {
            printf STDERR "Unable to open %s: %s\n", $filename, $!;
            exit 1;
        }
        local $/ = undef;
        my $stuff = <$fh>;
        close $fh;
        eval { $chassisinfo = decode_json($stuff) };
        if (!defined($chassisinfo)) {
            printf STDERR "Could not read valid JSON from %s\n",
                $filename;
            exit 1;
        }	

		if (!$dev_by_ip_sth->execute($host, $host)) {
			printf STDERR "Error fetching device from database: %s\n",
				$dev_by_ip_sth->errstr;
			exit 1;
		}

		my $d = [];
		my $rec;
		while ($rec = $dev_by_ip_sth->fetchrow_hashref) {
			push @$d, $rec;
		}

		if ($#$d > 0) {
			print STDERR "Multiple devices returned with device_name %s:\n",
				$host,
				map {
					printf "    %6d %-30s %-30s\n", @{$_}[0,1,2];
				}
			next;
		}
		$db_dev = $d->[0];
	} else {
		my $connect_host;
		if ($host =~ /:/) {
			($host, $connect_host) = $host =~ /(^[^:]+):(.*)/;
		} else {
			$connect_host = $host;
		}
		if ($verbose && !$parallel) {
			printf "Probing host %s\n", $host;
		}
		my $device;
		my $packed_ip = gethostbyname($host);
		my $ip_address;
		if (defined $packed_ip) {
			$ip_address = inet_ntoa($packed_ip);
		}
		if (!$ip_address) {
			printf STDERR "Name '%s' does not resolve\n", $host;
			next;
		}
		#
		# Pull information about this device from the database.  If there are
		# multiple devices returned, then bail
		#

		if ($debug) {
			printf "Getting device from database (IP address: %s, host: %s)\n",
				$ip_address, $host;
		}
		if (!$dev_by_ip_sth->execute($host, $host)) {
			printf STDERR "Error fetching device from database: %s\n",
				$dev_by_ip_sth->errstr;
			exit 1;
		}
		if ($debug) {
			print "Done\n";
		}

		my $d = [];
		my $rec;
		while ($rec = $dev_by_ip_sth->fetchrow_hashref) {
			push @$d, $rec;
		}

		if ($#$d > 0) {
			print STDERR "Multiple devices returned with device_name %s:\n",
				$host,
				map {
					printf "    %6d %-30s %-30s\n", @{$_}[0,1,2];
				}
			next;
		}
		$db_dev = $d->[0];

		my $mgmt_type = $conf_mgmt_type || $db_dev->{config_fetch_type};

		if ($debug) {
			print Data::Dumper->Dump([$db_dev], [qw($db_dev)]);
		}

		if (!($device = $mgmt->connect(
				device => {
					hostname => $connect_host || $host,
					management_type => $mgmt_type
				},
				credentials => $credentials,
				defined($timeout) ? (timeout => $timeout) : (),
				errors => \@errors))) {
			printf STDERR "Error connecting to device %s: %s\n",
				$host,
				(join "\n", @errors);
			next;
		}
		if (!($chassisinfo = $device->GetChassisInfo (
				errors => \@errors,
				))) {
			printf STDERR "Error retrieving chassis info for %s: %s\n",
				$host,
				(join("\n", @errors));
			next;
		}

		if ($debug) {
#			print Data::Dumper->Dump([$chassisinfo], [qw($chassisinfo)]);
			print JSON::XS->new->pretty(1)->encode ($chassisinfo);
		}

		#
		# Don't really care if this fails
		#
		$device->disconnect;
	}

	if (!$db_dev->{device_id}) {
		if ($verbose) {
			printf "Inserting device entry for %s, model %s\n",
				$host,
				$chassisinfo->{model};
		}

		if (!($ins_dev_sth->execute(
			$host,
			$chassisinfo->{model},
			$site_code
		))) {
			printf STDERR "Unable to insert device: %s\n",
				$ins_dev_sth->errstr;
			exit 1;
		}
		$db_dev = $ins_dev_sth->fetchrow_hashref;
		if (!$db_dev) {
			print STDERR "Unable to insert device\n";
			exit 1;
		}
		if ($debug) {
			print Data::Dumper->Dump([$db_dev], ['$db_dev']);
		}
	} else {
		my $do_update = 0;
		if ((!$db_dev->{device_name}) || $db_dev->{device_name} ne $host) {
			if ($verbose) {
				printf "Changing device name from '%s' to '%s'\n",
					$db_dev->{device_name} || $db_dev->{physical_label} || '',
					$host;
			}
			$do_update = 1;
		}
		if ($db_dev->{device_type_name} ne $chassisinfo->{model}) {
			if ($verbose) {
				printf "Changing device type from '%s' to '%s'\n",
					$db_dev->{device_type_name},
					$chassisinfo->{model};
				$do_update = 1;
			}
		}
		if ($do_update) {
			if (!($upd_dev_sth->execute(
					$db_dev->{device_id},
					$host,
					$chassisinfo->{model}
			))) {
				printf STDERR "Unable to update device: %s\n",
					$upd_dev_sth->errstr;
				exit 1;
			}
		}
	}

	if (defined($chassisinfo->{lldp_chassis_id}) &&
		(!defined($db_dev->{host_id}) || 
		$db_dev->{host_id} ne $chassisinfo->{lldp_chassis_id})
	) {
		if ($verbose) {
			printf "Setting host_id of %s to %s\n",
				$host,
				$chassisinfo->{lldp_chassis_id};
		}
		if (!($set_hi_sth->execute(
			$chassisinfo->{lldp_chassis_id},
			$db_dev->{device_id}
		))) {
			printf STDERR "Unable to set host_id of %s: %s\n",
				$host,
				$set_hi_sth->errstr;
			exit 1;
		}
	}


	if ($chassisinfo->{model} eq 'Juniper EX4xxx virtual chassis') {
		#
		# Pull component information
		#

		if (!($dev_components_sth->execute($db_dev->{device_id}))) {
			printf STDERR "Unable to fetch device component information: %s\n",
				$dev_components_sth->errstr;
			exit 1;
		}
		my $components = $dev_components_sth->fetchall_hashref('slot_name');

		if ($debug) {
			print Data::Dumper->Dump([$components], [qw($components)]);
		}

		foreach my $slot (sort { $a <=> $b } keys %{$chassisinfo->{modules}}) {
			my $slotname = 'VC' . $slot;
			if ($components->{$slotname}->{component_id}) {
				if ($components->{$slotname}->{serial_number} &&
					$components->{$slotname}->{serial_number} ne
						$chassisinfo->{modules}->{$slot}->{serial})
				{
					printf STDERR "Serial number of component %s in slot %s (%s) of device %s (%s) do not match.  This needs to be fixed manually because of things\n",
						$components->{$slotname}->{component_id},
						$slotname,
						;
					next;
				}
				if ($components->{$slotname}->{model} ne
						$chassisinfo->{modules}->{$slot}->{model}) {
					if ($verbose) {
						printf "Changing component type of slot %s of %s from %s to %s\n",
							$slotname,
							$host,
							$components->{$slotname}->{model},
							$chassisinfo->{modules}->{$slot}->{model};
					}

					if (!($upd_ct_sth->execute(
						$components->{$slotname}->{component_id},
						$chassisinfo->{modules}->{$slot}->{model}
					))) {
						printf STDERR "Unable to update component_type: %s\n",
							$upd_ct_sth->errstr;
						exit 1;
					}
				}
				if (!$components->{$slotname}->{serial_number}) {
					if ($verbose) {
						printf "Setting serial number of %s in slot %s (component id %d) of %s to %s\n",
							$chassisinfo->{modules}->{$slot}->{model},
							$slotname,
							$components->{$slotname}->{component_id},
							$host,
							$chassisinfo->{modules}->{$slot}->{serial};
					}

					if ($components->{$slotname}->{asset_id}) {
						if (!($set_sn_sth->execute(
							$chassisinfo->{modules}->{$slot}->{serial},
							$components->{$slotname}->{asset_id},
						))) {
							printf STDERR "Unable to update serial number: %s\n",
								$set_sn_sth->errstr;
							exit 1;
						}
					} else {
						if (!($ins_asset_sth->execute(
							$components->{$slotname}->{component_id},
							$chassisinfo->{modules}->{$slot}->{serial}
						))) {
							printf STDERR "Unable to update serial number: %s\n",
								$ins_asset_sth->errstr;
							exit 1;
						}
					}
				}
			} else {
				if ($verbose) {
					printf "Inserting %s component type into slot %s of %s with serial %s\n",
						$chassisinfo->{modules}->{$slot}->{model},
						$slotname,
						$host,
						$chassisinfo->{modules}->{$slot}->{serial};
				}
				if (!($ins_component_sth->execute(
					$components->{$slotname}->{slot_id},
					$chassisinfo->{manufacturer},
					$chassisinfo->{modules}->{$slot}->{model},
					$chassisinfo->{modules}->{$slot}->{serial}
				))) {
					printf STDERR "Unable to insert component: %s\n",
						$ins_component_sth->errstr;
					exit 1;
				}
			}
		}
	} else {
		#
		# Pull device asset information
		#

		if (!($dev_asset_sth->execute($db_dev->{device_id}))) {
			printf STDERR "Unable to fetch device asset information: %s\n",
				$dev_asset_sth->errstr;
			exit 1;
		}
		my $asset = $dev_asset_sth->fetchrow_hashref;

		if ($debug) {
			print Data::Dumper->Dump([$asset], [qw($asset)]);
		}
		if ($asset->{serial_number} &&
			$asset->{serial_number} ne $chassisinfo->{serial})
		{
			printf STDERR "Serial number of asset does not match (asset %d: %s vs %s).  This needs to be fixed manually because of things\n",
				$asset->{asset_id},
				$asset->{serial_number},
				$chassisinfo->{serial};
			next;
		}
		if (!$asset->{component_id}) {
			if ($verbose) {
				printf "Inserting %s component type for device %s (%s) with serial %s\n",
					$chassisinfo->{model},
					$db_dev->{device_id},
					$host,
					$chassisinfo->{serial};
			}

			if (!($dev_component_sth->execute(
				$db_dev->{device_id},
				$chassisinfo->{manufacturer},
				$chassisinfo->{model},
				$chassisinfo->{serial}
			))) {
				printf STDERR "Unable to insert component: %s\n",
					$dev_component_sth->errstr;
				exit 1;
			}
		} else {
			if ($asset->{model} ne $chassisinfo->{model}) {
				#
				# This shouldn't be able to happen, but just in case
				#
				if ($verbose) {
					printf "Changing component type of %s from %s to %s\n",
						$host,
						$asset->{model},
						$chassisinfo->{model};
				}
				if (!($upd_ct_sth->execute(
					$asset->{component_id},
					$chassisinfo->{model}
				))) {
					printf STDERR "Unable to update component_type: %s\n",
						$upd_ct_sth->errstr;
					exit 1;
				}
			}
			if (!$asset->{serial_number}) {
				if ($verbose) {
					printf "Setting serial number of %s (component id %d) to %s\n",
						$host,
						$asset->{component_id},
						$chassisinfo->{serial};
				}
				if ($asset->{asset_id}) {
					if (!($set_sn_sth->execute(
						$chassisinfo->{serial},
						$asset->{asset_id},
					))) {
						printf STDERR "Unable to update serial number: %s\n",
							$set_sn_sth->errstr;
						exit 1;
					}
				} else {
					if (!($ins_asset_sth->execute(
						$asset->{component_id},
						$chassisinfo->{serial}
					))) {
						printf STDERR "Unable to update serial number: %s\n",
							$ins_asset_sth->errstr;
						exit 1;
					}
				}
			}
		}
	}
	
	if ($probe_addresses) {
		if ($debug) {
			print "Fetching IP address information...\n";
		}
#		my $ipinfo = $device->GetIPAddressInformation;
#
#		if (!$ipinfo) {
#			print STDERR "Unable to get IP address information from device\n";
#			exit 1;
#		}
#		my $iface_name =
#			(grep {
#				grep {
#					NetAddr::IP->new($_)->addr eq $ip_address
#				} @{$ipinfo->{$_}->{ipv4}}
#			} keys %$ipinfo)[0];
#
#		if ($debug) {
#			print "IP Addresses:\n";
#			print map {
#				sprintf "\t%s: %s\n", $_, (join ',', @{$ipinfo->{$_}->{ipv4}})
#			} keys %$ipinfo;
#			print "Fetching chassis information...\n";
#		}
#
#		if (!$db_dev->{layer3_interface_id}) {
#			printf "Inserting network interface %s\n", $iface_name;
#
#			if (!($upd_nb_sth->execute(
#				$ip_address
#			))) {
#				printf STDERR "Unable to execute netblock update: %s\n",
#					$upd_nb_sth->errstr;
#				exit 1;
#			}
#			if (!($ins_l3i_sth->execute(
#				$db_dev->{device_id},
#				$iface_name,
#				$ip_address
#			))) {
#				printf STDERR "Unable to insert network interface: %s\n",
#					$ins_l3i_sth->errstr;
#				exit 1;
#			}
#		} elsif ($db_dev->{layer3_interface_name} ne $iface_name) {
#			printf "Changing network interface name from '%s' to '%s'\n",
#				$db_dev->{layer3_interface_name},
#				$iface_name;
#
#			if (!($upd_l3i_sth->execute(
#				$iface_name,
#				$db_dev->{layer3_interface_id}
#			))) {
#				printf STDERR "Unable to update network interface: %s\n",
#					$upd_l3i_sth->errstr;
#				exit 1;
#			}
#		}
	}

	if ($commit) {
		if (!$dbh->commit) {
			print STDERR $dbh->errstr;
		};
	}

	if (!($pull_os_version_sth->execute(
		$db_dev->{device_id}
	))) {
		printf STDERR "Unable to fetch device operating_system version: %s\n",
			$pull_os_version_sth->errstr;
	} else {

		my $osrec = $pull_os_version_sth->fetchrow_hashref;
		if (
			!$osrec ||
			!$osrec->{operating_system_name} ||
			!$osrec->{major_version} ||
			!$osrec->{version} ||
			$osrec->{operating_system_name} ne 
				$chassisinfo->{software}->{os_name} ||
			$osrec->{major_version} ne 
				$chassisinfo->{software}->{major_version} ||
			$osrec->{version} ne 
				$chassisinfo->{software}->{version}
		) {
			if ($verbose) {
				printf "Setting OS of %s to %s %s\n",
					$host,
					$chassisinfo->{software}->{os_name},
					$chassisinfo->{software}->{version};
			}

			if (!($set_os_version_sth->execute(
				$db_dev->{device_id},
				$chassisinfo->{software}->{os_name},
				$chassisinfo->{software}->{os_name},
				$chassisinfo->{software}->{version},
				$chassisinfo->{software}->{major_version},
				$chassisinfo->{manufacturer}
			))) {
				printf STDERR "Unable to set device operating_system version: %s\n",
					$set_os_version_sth->errstr;
			}
		}
	}
	
	if ($commit) {
		if (!$dbh->commit) {
			print STDERR $dbh->errstr;
		};
	}
}

$dev_by_ip_sth->finish;
$upd_dev_sth->finish;
$dev_components_sth->finish;
$dev_asset_sth->finish;
$ins_dev_sth->finish;
$ins_l3i_sth->finish;
$upd_l3i_sth->finish;
$upd_nb_sth->finish;
$upd_ct_sth->finish;
$ins_asset_sth->finish;
$ins_component_sth->finish;
$dev_component_sth->finish;
$pull_os_version_sth->finish;
$set_os_version_sth->finish;

if ($commit) {
	if (!$dbh->commit) {
		print STDERR $dbh->errstr;
	};
} else {
	$dbh->rollback;
}
$dbh->disconnect;
