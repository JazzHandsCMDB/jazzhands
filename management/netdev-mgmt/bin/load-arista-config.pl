#!/usr/bin/env perl

use FindBin qw($RealBin);

use JazzHands::Common;
use JazzHands::NetDev::Mgmt;
use JazzHands::DBI;

use Term::ReadKey;
use Data::Dumper;
use Pod::Usage;
use Getopt::Long;
use Socket;

use strict;
use warnings;

umask 022;

my $help = 0;

my $filename;
my $commit = 1;
my $user;
my $password;
my $parallel = 0;
my $authapp = 'net_dev_probe';

sub loggit {
	printf STDERR join "\n", @_;
	print "\n";
}

GetOptions(
	'filename=s', \$filename,
	'username=s', \$user,
	'password=s', \$password,
	'write|commit!', \$commit,
	'parallel!', \$parallel,
	'authapp=s', \$authapp
);

my $credentials;

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

my @errors;
if (!defined($filename)) {
	if (!(open(FH, '<-'))) {
		print STDERR "Unable to open stdin\n";
		exit 1;
	}
} elsif (!(open(FH, '<', $filename))) {
	printf STDERR "Unable to open config file %s: %s\n", $filename, $!;
	exit 1;
}

my @config;
chomp(@config = <FH>);
close FH;
unshift @config, "configure";
unshift @config, "enable";
#if ($commit) {
#	push @config, "write memory";
#}

my $netconf = new JazzHands::NetDev::Mgmt;
while (my $device = shift) {
	if (!$parallel) {
		printf STDERR "%s: ", $device;
	}
	my $dev = $netconf->connect(
		credentials => $credentials,
		device => {
			hostname => $device,
			management_type => 'arista'
		},
		errors => \@errors
	);

	if (!defined($dev)) {
		printf "%s: %s\n", $device, (join "\n", @errors);
		next;
	}

	my $result = $dev->SendCommand(
		commands => [
			@config
		],
		timeout => 300,
		errors => \@errors
	);

	if (!defined($result)) {
		printf "%s: %s\n", $device, (join "\n", @errors);
		next;
	}
	if ($parallel) {
		printf "%s: done\n", $device;
	} else {
		print "done\n";
	}
	$dev->commit;
}
