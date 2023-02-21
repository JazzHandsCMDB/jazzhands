#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use Socket;
use IO::Socket::SSL;
use JazzHands::Common::Util qw(_options );
use JazzHands::Common::Error qw(:all);
use JazzHands::AppAuthAL;
use JazzHands::Redfish;
use JSON::XS;
use NetAddr::IP qw(:lower);
use LWP::UserAgent;
use Getopt::Long;
use Term::ReadKey;

sub loggit {
	printf STDERR join "\n", @_;
	print "\n";
}

my $user;
my $password;
my $debug = 0;
my $verbose = 0;
my $probe_nvme = 0;
my $timeout = undef;
my $authapp = 'dev_redfish';
my ($readfile, $writefile);

GetOptions(
	'username=s'	=> \$user,
	'password=s'	=> \$password,
	'authapp=s'		=> \$authapp,
	'write=s'		=> \$writefile,
	'read=s'		=> \$readfile,
	'debug+'		=> \$debug,
	'timeout=i'		=> \$timeout,
	'nvme!'			=> \$probe_nvme,
	'verbose+'		=> \$verbose,
);

if ($readfile && $writefile) {
	print STDERR "Only one of --read or --write may be specified\n";
	exit 1;
}

my $credentials;
my $redfish = JazzHands::Redfish->new();

if ($user) {
	if (!$password) {
		print STDERR 'Password: ';
		ReadMode('noecho');
		chomp($password = <STDIN>);
		ReadMode(0);
		print STDERR "\n";

		if (!$password) {
			print STDERR "Password required\n";
			exit 1;
		}
	}
	$credentials->{username} = $user;
	$credentials->{password} = $password;
} elsif (!$user) {
	my $record = JazzHands::AppAuthAL::find_and_parse_auth($authapp);
	if (!$record || !$record->{network_device}) {
		loggit(sprintf("Unable to find network_device auth entry for %s.",
			 $authapp));
		exit 1;
	}
	$credentials = $record->{network_device};
}

my $host;
my $device_hash = {};

DEVLOOP: while ($host = shift) {
	my @errors;

	my $conninfo = {
		hostname => $host
	};

	if ($debug) {
		printf "%s...\n", $host;
	}

	my $result;
	#
	# Pull base chassis/sled information
	#
	$result = $redfish->SendCommand(
		device => $conninfo,
		credentials => $credentials,
		url => '/redfish/v1',
		errors => \@errors,
		timeout => $timeout,
		debug => $debug
	);

	if (!$result) {
		if ($verbose) {
			printf "%s: %s\n", $host, join("\n", @errors);
		}
		next DEVLOOP;
	}

	my $device_serial = $result->{Oem}->{Dell}->{ServiceTag};

	if (!$device_serial) {
		next;
	}

	if (!exists($device_hash->{$device_serial})) {
		$device_hash->{$device_serial} = {
			host	=> $host,
			serial	=> $device_serial
		};
	}
	my $device = $device_hash->{$device_serial};
	
#	$device->{device_serial} = $device_serial;

	$result = $redfish->SendCommand(
		device => $conninfo,
		credentials => $credentials,
		url => '/redfish/v1/Systems/System.Embedded.1',
		errors => \@errors,
		timeout => $timeout,
		debug => $debug
	);

	if (!$result) {
		printf "%s: %s\n", $host, join("\n", @errors);
		next DEVLOOP;
	}
	$device->{model} = $result->{Model};
	$device->{part_number} = $result->{PartNumber};

	if ($debug) {
		printf "Found %s with serial %s\n",
			$device->{model},
			$device->{serial};
	}

	#
	# Look for backplane
	#

	my $nexturl;
	if ($result->{SimpleStorage}) {
		$nexturl = $result->{SimpleStorage}->{'@odata.id'};
	} else {
		printf "%s: %s\n", $host, join("\n", @errors);
		next DEVLOOP;
	}

#	if (grep { $_->{'@odata.id'} =~ m%/CPU\.\d+$% } @{$result->{Members}} ) {
#		$device->{NVMe} = 1;
#	} else {
#		$device->{NVMe} = 0;
#	}
#
#	printf "%s: %s\n",
#		$device_serial,
#		$device->{NVMe} ?
#			"NVMe backplane present" :
#			"NVMe backplane NOT present";

	if ($probe_nvme) {
		#
		# Pull controllers
		#
		$result = $redfish->SendCommand(
			device => $conninfo,
			credentials => $credentials,
			url => $nexturl,
			errors => \@errors,
			debug => $debug
		);

		if (!$result) {
			printf "%s: %s\n", $host, join("\n", @errors);
			next DEVLOOP;
		}

		my @controllers;
		if (@controllers = grep { $_->{'@odata.id'} =~ m%/CPU\.\d+$% } @{$result->{Members}} ) {
			$device->{NVMe} = [];
		} else {
			$device->{NVMe} = undef;
			goto PRINTIT;
		}

		foreach my $controller (@controllers) {
			$result = $redfish->SendCommand(
				device => $conninfo,
				credentials => $credentials,
				url => $controller->{'@odata.id'},
				errors => \@errors,
				debug => $debug
			);

			if (!$result) {
				printf "%s: %s\n", $host, join("\n", @errors);
				next DEVLOOP;
			}

			next if (!$result->{Devices});
			foreach my $nvme (@{$result->{Devices}}) {
				next if !$nvme->{CapacityBytes};
				$nvme->{Manufacturer} =~ s/ +$//;
				$nvme->{Model} =~ s/ +$//;
				push @{$device->{NVMe}}, $nvme;
			}
		}
	}
	
	PRINTIT:

	printf "%s: %s: %s", $device->{host}, $device_serial, $device->{model};
	if ($probe_nvme) {
		if (defined($device->{NVMe})) {
			print " - NVMe backplane present: ";
			if (!@{$device->{NVMe}}) {
				print "No NVMe devices found\n";
			} else {
				if ($verbose < 2) {
					printf "%d NVME devices found\n", $#{$device->{NVMe}};
				} else {
					printf "\n    " . join ("\n    ",
						map {
							sprintf q{Size: %s, Manufacturer: %s, Model: "%s"},
								$_->{CapacityBytes},
								$_->{Manufacturer},
								$_->{Model}
						} @{$device->{NVMe}}
					);
				}
			}
		} else {
			printf " - NVMe backplane not present",
		}
	}
	print "\n";
}

