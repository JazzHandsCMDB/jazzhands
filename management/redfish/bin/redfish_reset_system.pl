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

my $action = 'status';
my $user;
my $password;
my $debug = 0;
my $verbose = 0;
my $json = 0;
my $authapp = 'dev_redfish';
my ($readfile, $writefile);

GetOptions(
	'username=s'	=> \$user,
	'password=s'	=> \$password,
	'authapp=s'		=> \$authapp,
	'write=s'		=> \$writefile,
	'read=s'		=> \$readfile,
	'json!'			=> \$json,
	'debug+'		=> \$debug,
	'verbose+'		=> \$verbose,
	'reset'			=> sub { $action = 'ForceRestart' },
	'cycle'			=> sub { $action = 'PowerCycle' },
	'poweroff'		=> sub { $action = 'ForceOff' },
	'poweron'		=> sub { $action = 'On' },
	'off'			=> sub { $action = 'ForceOff' },
	'on'			=> sub { $action = 'On' },
	'action=s'		=> \$action,
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

	if ($verbose) {
		printf "%s...\n", $host;
	}

	my $result;
	#
	# Send system reset
	#
	$result = $redfish->SendCommand(
		device => $conninfo,
		credentials => $credentials,
		url => '/redfish/v1',
		errors => \@errors,
		debug => $debug
	);

	if (!$result) {
		if ($verbose) {
			printf "%s: %s\n", $host, join("\n", @errors);
		}
		next DEVLOOP;
	}
	my $device_serial = $result->{Oem}->{Dell}->{ServiceTag};
	my $device = {
		host			=> $host,
		serial			=> $device_serial,
	};
	$device_hash->{$host} = $device;

	# Retrieving power cycle values

	$result = $redfish->SendCommand(
		device => $conninfo,
		credentials => $credentials,
		url => '/redfish/v1/Systems/System.Embedded.1',
		errors => \@errors,
		debug => $debug
	);

	if (!$result) {
		$device->{errors} = $@errors;
		printf "%s: %s\n", $host, join("\n", @errors);
		next DEVLOOP;
	}

	$device->{power_state} = $result->{PowerState};

	my $power_options = $result->{Actions}->{'#ComputerSystem.Reset'}->
		{'ResetType@Redfish.AllowableValues'};
	my $power_url = $result->{Actions}->{'#ComputerSystem.Reset'}->{target};

	if ($action eq 'status') {
		if (!$json) {
			printf "%s: %s: %s\n",
				$device->{host},
				$device->{serial} || '',
				$device->{power_state}
			;
		}
	#	else {
	#		print JSON::XS->new->pretty(1)->encode($device);
	#	}
		next;
	}

	if ($debug) {
		printf STDERR "Power action is: %s\n", $action;
	}

	if (! grep { $_ eq $action } @$power_options) {
		printf STDERR "%s is not a valid power status.  Use one of: %s\n",
			$action,
			(join ', ', @$power_options);
		next;
	}

	$device->{reset_type} = $action;

	$result = $redfish->SendCommand(
		device => $conninfo,
		credentials => $credentials,
		url => $power_url,
		arguments => {
				ResetType => $action
			},
		errors => \@errors,
		debug => $debug
	);

	if (!$result) {
		printf "%s: %s\n", $host, join("\n", @errors);
		$device->{errors} = $@errors;
		next DEVLOOP;
	}
	if ($verbose) {
		printf "%s: %s: Power state: %s, changed to %s\n",
			$device->{host},
			$device->{serial} || '',
			$device->{power_state},
			$action
		;
	}
}

if ($json) {
	print JSON::XS->new->pretty(1)->encode($device_hash);
}
