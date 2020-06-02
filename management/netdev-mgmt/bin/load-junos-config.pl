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
use XML::DOM;

use strict;
use warnings;

umask 022;

my $help = 0;

my $filename;
my $commit = 1;
my $user = $ENV{'USER'};
my $password;
my $parallel = 0;
my $format = 'text';
my $authapp;

sub loggit {
	printf STDERR join "\n", @_;
	print "\n";
}

GetOptions(
	'filename=s', \$filename,
	'username=s', \$user,
	'password=s', \$password,
	'parallel!', \$parallel,
	'format=s', \$format,
	'commit!', \$commit,
	'authapp=s', \$authapp
);


my $credentials;

if ($authapp) {
	my $record = JazzHands::AppAuthAL::find_and_parse_auth($authapp);
	if (!$record || !$record->{network_device}) {
		loggit(sprintf("Unable to find network_device auth entry for %s.",
			 $authapp));
		exit 1;
	}
	$credentials = $record->{network_device};
} elsif ($user) {
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
} else {
	print STDERR "Must give either --user or --authapp\n";
	exit 1;
}

my @errors;
if (!defined($filename)) {
	if (!(open(FH, '<-'))) {
		print STDERR "Unable to open stdin\n";
		exit 1;
	}
} elsif (!(open(FH, '<', $filename))) {
	print STDERR "Unable to open config file %s: %s\n", $filename, $!;
	exit 1;
}

my $config = join ('', <FH>);
close FH;

if ($format eq 'xml') {
	my $parser = new XML::DOM::Parser;
	my $doc = $parser->parsestring($config);
	$config = $doc;
}

while (my $devname = shift) {
	my $mgmt = JazzHands::NetDev::Mgmt->new;
	my $device;
	if (!($device = $mgmt->connect(
			device => {
				hostname => $devname,
				management_type => 'juniper'
			},
			credentials => $credentials,
			errors => \@errors))) {
		printf "Error connecting to device: %s\n", (join "\n", @errors);
		next;
	}

	if (!$parallel) {
		printf "%s: ", $devname;
	}

	if (!($device->UploadConfigText(
			config => $config,
			format => $format,
			errors => \@errors,
			commit => $commit
			))) {
		printf "%s: %s\n", $devname, (join("\n", @errors));
	} else {
		if ($parallel) {
			printf "%s: done\n", $devname;
		} else {
			print "done\n";
		}
	}
	$device->disconnect;
}
