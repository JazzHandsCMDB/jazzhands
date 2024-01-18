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
my $authapp = 'dev_redfish';
my ($readfile, $writefile);

GetOptions(
	'username=s'	=> \$user,
	'password=s'	=> \$password,
	'authapp=s'		=> \$authapp,
	'write=s'		=> \$writefile,
	'read=s'		=> \$readfile,
	'debug+'		=> \$debug,
	'verbose+'		=> \$verbose
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
		printf "Sending reset to %s: ", $host;
	}

	my $result;
	#
	# Reset the controller
	#
	$result = $redfish->SendCommand(
		device => $conninfo,
		credentials => $credentials,
		url => '/redfish/v1/Managers/iDRAC.Embedded.1/Actions/Manager.Reset/',
		arguments =>  {
			ResetType => 'GracefulRestart'
		},
		errors => \@errors,
		debug => $debug
	);

	if (!$result) {
		if (!$verbose) {
			printf "Error resetting %s: ", $host;
		}

		printf "%s: %s\n", $host, join("\n", @errors);
		next DEVLOOP;
	} else {
		if ($verbose) {
			printf "Ok\n";
		}
	}
}

