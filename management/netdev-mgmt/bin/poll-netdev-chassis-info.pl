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

use strict;
use warnings;

umask 022;

my $help = 0;
my $debug = 0;

my $filename;
my $commit = 1;
#my $user = $ENV{'USER'};
my $user;
my $password;
my $connect_name = undef;
my $hostname = [];
my $conf_mgmt_type = undef;
my $authapp = 'net_dev_probe';

sub loggit {
	printf STDERR join "\n", @_;
	print "\n";
}

GetOptions(
	'username=s', \$user,
	'commit!', \$commit,
	'connect-name=s', \$connect_name,
	'hostname=s', $hostname,
	'management-type=s', \$conf_mgmt_type,
	'debug+', \$debug
);

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
				PrintError => 0,
			}
		))) {
	printf STDERR "WTF?: %s\n", $JazzHands::DBI::errstr;
	exit 1;
}

my $mgmt = new JazzHands::NetDev::Mgmt;

##
## Prepare all of the database queries we're going to need
##

my $q;

$q = q {
	SELECT
		d.device_id,
		d.device_name,
		d.component_id,
		dt.device_type_id,
		dt.device_type_name,
		d.physical_label,
		dt.config_fetch_type
	FROM
		jazzhands.device d JOIN
		jazzhands.device_type dt USING (device_type_id)
	WHERE
		device_name = ? OR
		physical_label = ?
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
		jazzhands.device d
	SET
		device_name = parms.device_name,
		physical_label = parms.device_name,
		device_type_id = dt.device_type_id
	FROM
		jazzhands.device_type dt,
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
			?::text AS device_type_name
	) INSERT INTO jazzhands.device (
		device_type_id,
		device_name,
		physical_label,
		device_status,
		service_environment_id,
		is_locally_managed,
		is_monitored,
		is_virtual_device,
		should_fetch_config
	) SELECT
		device_type_id,
		parms.device_name,
		parms.device_name,
		'up',
		service_environment_id,
		'Y',
		'Y',
		'N',
		'Y'
	FROM
		jazzhands.service_environment se,
		jazzhands.device_type dt,
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
			?::text AS network_interface_name,
			?::text AS ip_addr
	), upd_nb AS (
		UPDATE
			jazzhands.netblock n
		SET
			netblock_type = 'default',
			parent_netblock_id = netblock_utils.find_best_parent_id(
				in_ipaddress := parms.ip_addr::inet
			)
		FROM
			parms
		WHERE
			host(n.ip_address) = parms.ip_addr AND
			is_single_address = 'Y' AND
			netblock_type = 'dns'
	)
	INSERT INTO jazzhands.network_interface (
		device_id,
		network_interface_name,
		netblock_id,
		network_interface_type,
		should_monitor
	) SELECT
		parms.device_id,
		parms.network_interface_name,
		n.netblock_id,
		'broadcast',
		'Y'
	FROM
		parms,
		jazzhands.netblock n
	WHERE
		host(n.ip_address) = parms.ip_addr AND
		is_single_address = 'Y'
};

my $ins_ni_sth;

if (!($ins_ni_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}

$q = q {
	UPDATE
		jazzhands.netblock n
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
		jazzhands.network_interface
	SET
		network_interface_name = ?
	WHERE
		network_interface_id = ?
};

my $upd_ni_sth;

if (!($upd_ni_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}


$q = q {
	UPDATE
		jazzhands.component c
	SET
		component_type_id = ct.component_type_id
	FROM
		jazzhands.component_type ct,
		jazzhands.component_type oct
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
		jazzhands.asset a
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
	INSERT INTO jazzhands.asset (
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
					jazzhands.component_type ct JOIN
					jazzhands.company c USING (company_id),
					parms
				WHERE
					c.company_name = parms.company_name AND
					ct.model = parms.model
			),
			serial_number := (SELECT parms.serial FROM parms)
		)
	) UPDATE
		jazzhands.component c
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
					jazzhands.component_type ct JOIN
					jazzhands.company c USING (company_id),
					parms
				WHERE
					c.company_name = parms.company_name AND
					ct.model = parms.model
			),
			serial_number := (SELECT parms.serial FROM parms)
		)
	) UPDATE
		jazzhands.device d
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
	jazzhands.device d LEFT JOIN
	jazzhands.component p USING (component_id) LEFT JOIN
	jazzhands.slot s USING (component_id) LEFT JOIN
	jazzhands.component c ON (s.slot_id = c.parent_slot_id) LEFT JOIN
	jazzhands.component_type ct ON
		(c.component_type_id = ct.component_type_id) LEFT JOIN
	jazzhands.asset a ON (a.component_id = c.component_id)
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
	jazzhands.device d LEFT JOIN
	jazzhands.component c USING (component_id) LEFT JOIN
	jazzhands.component_type ct ON
		(c.component_type_id = ct.component_type_id) LEFT JOIN
	jazzhands.asset a ON (a.component_id = c.component_id)
WHERE
	device_id = ?
};

my $dev_asset_sth;

if (!($dev_asset_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}

foreach my $host (@$hostname) {
	my $connect_host;
	if ($host =~ /:/) {
		($host, $connect_host) = $host =~ /(^[^:]+):(.*)/;
	} else {
		$connect_host = $host;
	}
	printf "Probing host %s\n", $host;
	my $device;
	my $packed_ip = gethostbyname($host);
	my $ip_address;
	if (defined $packed_ip) {
		$ip_address = inet_ntoa($packed_ip);
	}
	if (!$ip_address) {
		printf "Name '%s' does not resolve\n", $host;
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
		print STDERR "Multiple devices returned with this device_name or IP address:\n";
		map {
			printf "    %6d %-30s %-30s\n", @{$_}[0,1,2];
		}
		next;
	}
	my $db_dev = $d->[0];

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
			errors => \@errors))) {
		printf "Error connecting to device: %s\n", (join "\n", @errors);
		next;
	}

	if ($debug) {
		print "Fetching IP address information...\n";
	}
#	my $ipinfo = $device->GetIPAddressInformation;
#
#	if (!$ipinfo) {
#		print STDERR "Unable to get IP address information from device\n";
#		exit 1;
#	}
#	my $iface_name =
#		(grep {
#			grep {
#				NetAddr::IP->new($_)->addr eq $ip_address
#			} @{$ipinfo->{$_}->{ipv4}}
#		} keys %$ipinfo)[0];
#
#	if ($debug) {
#		print "IP Addresses:\n";
#		print map {
#			sprintf "\t%s: %s\n", $_, (join ',', @{$ipinfo->{$_}->{ipv4}})
#		} keys %$ipinfo;
#		print "Fetching chassis information...\n";
#	}

	my $chassisinfo;
	if (!($chassisinfo = $device->GetChassisInfo (
			errors => \@errors,
			))) {
		print "Error retrieving chassis info: " . join("\n", @errors) . "\n";
	}

	if ($debug) {
		print Data::Dumper->Dump([$chassisinfo], [qw($chassisinfo)]);
	}

	if (!$device->disconnect) {
		printf "Error doing device disconnect: %s\n", join "\n", @errors;
	}

	if (!$db_dev->{device_id}) {
		printf "Inserting device entry for %s\n", $host;

		if (!($ins_dev_sth->execute(
			$host,
			$chassisinfo->{model}
		))) {
			printf STDERR "Unable to insert device: %s\n",
				$ins_dev_sth->errstr;
			exit 1;
		}
		$db_dev = $ins_dev_sth->fetchrow_hashref;
		if ($debug) {
			print Data::Dumper->Dump([$db_dev], ['$db_dev']);
		}
	} else {
		my $do_update = 0;
		if ((!$db_dev->{device_name}) || $db_dev->{device_name} ne $host) {
			printf "Changing device name from '%s' to '%s'\n",
				$db_dev->{device_name} || $db_dev->{physical_label} || '',
				$host;
			$do_update = 1;
		}
		if ($db_dev->{device_type_name} ne $chassisinfo->{model}) {
			printf "Changing device type from '%s' to '%s'\n",
				$db_dev->{device_type_name},
				$chassisinfo->{model};
			$do_update = 1;
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

#	if (!$db_dev->{network_interface_id}) {
#		printf "Inserting network interface %s\n", $iface_name;
#
#		if (!($upd_nb_sth->execute(
#			$ip_address
#		))) {
#			printf STDERR "Unable to execute netblock update: %s\n",
#				$upd_nb_sth->errstr;
#			exit 1;
#		}
#		if (!($ins_ni_sth->execute(
#			$db_dev->{device_id},
#			$iface_name,
#			$ip_address
#		))) {
#			printf STDERR "Unable to insert network interface: %s\n",
#				$ins_ni_sth->errstr;
#			exit 1;
#		}
#	} elsif ($db_dev->{network_interface_name} ne $iface_name) {
#		printf "Changing network interface name from '%s' to '%s'\n",
#			$db_dev->{network_interface_name},
#			$iface_name;
#
#		if (!($upd_ni_sth->execute(
#			$iface_name,
#			$db_dev->{network_interface_id}
#		))) {
#			printf STDERR "Unable to update network interface: %s\n",
#				$upd_ni_sth->errstr;
#			exit 1;
#		}
#	}

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
					printf STDERR "Serial number of component in %s do not match.  This needs to be fixed manually because of things\n",
						$slotname;
					next;
				}
				if ($components->{$slotname}->{model} ne
						$chassisinfo->{modules}->{$slot}->{model}) {
					printf "Changing component type of slot %s from %s to %s\n",
						$slotname,
						$components->{$slotname}->{model},
						$chassisinfo->{modules}->{$slot}->{model};

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
					printf "Setting serial number of %s in slot %s (component id %d) to %s\n",
						$chassisinfo->{modules}->{$slot}->{model},
						$slotname,
						$components->{$slotname}->{component_id},
						$chassisinfo->{modules}->{$slot}->{serial};

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
				printf "Inserting %s component type into slot %s with serial %s\n",
					$chassisinfo->{modules}->{$slot}->{model},
					$slotname,
					$chassisinfo->{modules}->{$slot}->{serial};

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
			printf STDERR "Serial number of asset does not match.  This needs to be fixed manually because of things\n";
			next;
		}
		if (!$asset->{component_id}) {
			printf "Inserting %s component type for device %s with serial %s\n",
				$chassisinfo->{model},
				$db_dev->{device_id},
				$chassisinfo->{serial};

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
				printf "Changing component type of device from %s to %s\n",
					$asset->{model},
					$chassisinfo->{model};

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
				printf "Setting serial number of device (component id %d) to %s\n",
					$asset->{component_id},
					$chassisinfo->{serial};

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
}

$dev_by_ip_sth->finish;
$upd_dev_sth->finish;
$dev_components_sth->finish;
$dev_asset_sth->finish;
$ins_dev_sth->finish;
$ins_ni_sth->finish;
$upd_ni_sth->finish;
$upd_nb_sth->finish;
$upd_ct_sth->finish;
$ins_asset_sth->finish;
$ins_component_sth->finish;
$dev_component_sth->finish;

if ($commit) {
	if (!$dbh->commit) {
		print STDERR $dbh->errstr;
	};
} else {
	$dbh->rollback;
}
$dbh->disconnect;
