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
use Term::ReadKey;

use Data::Dumper;
use Pod::Usage;
use Getopt::Long;
use Socket;
use JazzHands::DBI;
use JazzHands::NetDev::Mgmt;
use NetAddr::IP;
use JSON;

use strict;
use warnings;

umask 022;

my $help = 0;
my $debug = 0;
my $verbose = 0;
my $force = 0;

my $filename;
my $commit = 1;
#my $user = $ENV{'USER'};
my $user;
my $probe_lldp = 0;
my $address_errors = 'error';
my $probe_ip = 1;
my $notreally = 0;
my $purge_int = 1;
my $password;
my $bgpstate = 'up';
my $hostname = [];
my $timeout = undef;
my $authapp = 'net_dev_probe';

sub loggit {
	printf STDERR join "\n", @_;
	print "\n";
}

GetOptions(
	'username=s', \$user,
	'timeout=i', \$timeout,
	'commit!', \$commit,
	'hostname=s', $hostname,
	'verbose+', \$verbose,
	'force!', \$force,
	'ignore-errors', sub {
		$address_errors = 'warn'
	},
	'debug+', \$debug,
	'probe-lldp!', \$probe_lldp,
	'probe-ip!', \$probe_ip,
	'purge-empty-interfaces!', \$purge_int,
	'notreally!', \$notreally,
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
		dt.config_fetch_type
	FROM
		device d JOIN
		device_type dt USING (device_type_id)
	WHERE
		lower(device_name) = lower(?)
};

my $dev_search_sth;

if (!($dev_search_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}

#$q = q {
#	WITH parms AS (
#		SELECT ?::integer AS device_id
#	) SELECT
#		ni.network_interface_id,
#		ni.network_interface_name
#	FROM
#		network_interface ni JOIN
#		network_interface_netblock USING (network_interface_id),
#		parms
#	WHERE
#		ni.device_id = parms.device_id
#	UNION SELECT
#		ni.network_interface_id,
#		ni.network_interface_name
#	FROM
#		network_interface ni JOIN
#		shared_netblock_network_int snni USING (network_interface_id),
#		parms
#	WHERE
#		ni.device_id = parms.device_id
#};

$q = q {
	SELECT
		ni.network_interface_id,
		ni.network_interface_name
	FROM
		network_interface ni
	WHERE
		ni.device_id = ?
};
my $ni_list_sth;

if (!($ni_list_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}

$q = q {
	SELECT * FROM device_utils.remove_network_interfaces(
		network_interface_id_list := ?
	);
};

my $ni_del_sth;

if (!($ni_del_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}

$q = q {
	SELECT * FROM netblock_manip.set_interface_addresses(
		device_id := ?,
		network_interface_name := ?,
		ip_address_hash := ?,
		create_layer3_networks := true,
		move_addresses := ?,
		address_errors := ?
	)
};

my $set_interface_sth;

if (!($set_interface_sth = $dbh->prepare_cached($q))) {
	print STDERR $dbh->errstr;
	exit 1;
}

HOSTLOOP:
foreach my $host (@$hostname) {
	my @errors;
	my $device;
	my $connect_host;

    if ($host =~ /:/) {
        ($host, $connect_host) = $host =~ /(^[^:]+):(.*)/;
    } else {
        $connect_host = $host;
    }

	if ($verbose) {
		printf "%s:\n", $host;
	}

#	my $packed_ip = gethostbyname($host);
#	my $ip_address;
#
#	if (defined $packed_ip) {
#		$ip_address = inet_ntoa($packed_ip);
#	}
#	if (!$ip_address) {
#		printf "Name '%s' does not resolve\n", $host;
#		next;
#	}

	#
	# Pull information about this device from the database.  If there are
	# multiple devices returned, then bail
	#

	if (!$dev_search_sth->execute($host)) {
		printf STDERR "Error fetching device from database: %s\n",
			$dev_search_sth->errstr;
		exit 1;
	}

	my $d = [];
	my $rec;
	while ($rec = $dev_search_sth->fetchrow_hashref) {
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

	if ($debug) {
		print Data::Dumper->Dump([$db_dev], [qw($db_dev)]);
	}

	if (!($device = $mgmt->connect(
			device => {
				hostname => $connect_host,
				management_type => $db_dev->{config_fetch_type}
			},
			credentials => $credentials,
			errors => \@errors))) {
		printf "Error connecting to device: %s\n", (join "\n", @errors);
		next;
	}

	my $info;
	if ($probe_ip) {
		if (!$ni_list_sth->execute($db_dev->{device_id})) {
			printf STDERR "Error fetching network_interfaces from database: %s\n",
				$ni_list_sth->errstr;
			exit 1;
		}

		my $dev_int = {};
		my $unnamed_int = [];
		my $rec;
		while ($rec = $ni_list_sth->fetchrow_hashref) {
			if (defined($rec->{network_interface_name})) {
				$dev_int->{$rec->{network_interface_name}} =
					$rec->{network_interface_id};
			} else {
				push @$unnamed_int, $rec->{network_interface_id};
			}
		}

		if (!($info = $device->GetIPAddressInformation(
			debug			=> $debug,
			errors 			=> \@errors,
			timeout			=> $timeout,
		))) {
			printf STDERR "Error getting address information on switch %s: %s\n",
				$host,
				@errors;
			next;
		}
		foreach my $iname (keys %$info) {
			my $interface = $info->{$iname};
			#
			# If we found the interface, then we don't need to process it later
			#
			delete $dev_int->{$iname};
			#
			# Don't process anything for lo0, because
			#
			#next if $iname =~ '^lo0';

			if ($verbose) {
				printf "    %s:\n", $iname;
				if (exists($interface->{ipv4})) {
					printf "        IPv4: %s\n", (join ',', @{$interface->{ipv4}});
				}
				if (exists($interface->{ipv6})) {
					printf "        IPv6: %s\n", (join ',', @{$interface->{ipv6}});
				}
				if (exists($interface->{vrrp}) && @{$interface->{vrrp}}) {
					printf "        VRRP: %s\n", (join ',',
						map { $_->{group} . ':' . $_->{address} } 
							sort { $a->{group} <=> $b->{group} }
								@{$interface->{vrrp}});
				}
				if (exists($interface->{virtual_router}) &&
					@{$interface->{virtual_router}})
				{
					printf "        VARP: %s\n", (join ',',
						@{$interface->{virtual_router}});
				}
			}

			my $json = JSON->new->utf8->encode({
					ip_addresses =>
						[
							defined( $interface->{ipv4} ) ?
								(map {
										$_->addr . '/' . $_->masklen
									} @{$interface->{ipv4}}
								) : (),
							defined( $interface->{ipv6} ) ?
								(map {
										$_->addr . '/' . $_->masklen
									} @{$interface->{ipv6}}
								) : ()
						],
					shared_ip_addresses =>
						[
							defined( $interface->{vrrp}) ?
								(map {
									{
										ip_address => $_->{address}->addr,
										protocol => 'VRRP'
									}
								} @{$interface->{vrrp}})
							: (),
							defined($interface->{virtual_router}) ?
								(map {
									{
										ip_address => $_->addr,
										protocol => 'VARP'
									}
								} @{$interface->{virtual_router}})
							: ()
						]
				});
			{
				my @warn;
				local $SIG{__WARN__} = sub {
					my $x = $_[0];
					chomp($x);
					push(@warn, $x);
				};
				if (!$notreally) {
					if (!$set_interface_sth->execute(
						$db_dev->{device_id},
						$iname,
						$json,
						$force ? 'always' : 'if_same_device',
						$address_errors
					)) {
						printf STDERR "Error setting device interface information for interface %s: %s\n",
							$iname,
							$set_interface_sth->errstr;
						$dbh->rollback;
						next HOSTLOOP;
					} elsif ($verbose && @warn ) {
						printf "        %s\n", 
							(join "        ", @warn);
					}
				}
			}
		}
		if (%$dev_int || @$unnamed_int) {
			if ($purge_int) {
				if ($verbose) {
					printf "    Removing network interfaces: %s\n",
						(join ", ", keys %$dev_int);
				}
				if (!$notreally) {
					if (!$ni_del_sth->execute( [ values %$dev_int, @$unnamed_int ] )) {
						printf STDERR "Error deleting network_interfaces from database: %s\n",
							$ni_del_sth->errstr;
						exit 1;
					}
				}
			}
		}
	}

	if ($probe_lldp) {
		if (!($info = $device->GetLLDPInformation(
			debug			=> $debug,
			errors 			=> \@errors,
			timeout			=> $timeout,
		))) {
			printf STDERR "Error getting LLDP information on switch %s: %s\n",
				$host,
				@errors;
			next;
		}

		print Dumper($info);
	}

	#
	# Commit after each device
	#

	if ($commit) {
		if (!($dbh->commit)) {
			printf STDERR "Error committing transaction: %s\n", $dbh->errstr;
		}
	} else {
		$dbh->rollback;
	}
}

$dev_search_sth->finish;
$set_interface_sth->finish;
$ni_list_sth->finish;
$ni_del_sth->finish;
$dbh->disconnect;
