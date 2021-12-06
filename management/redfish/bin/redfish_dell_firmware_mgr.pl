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
my $firmware_file;
my $output_format = 'text';
my $output_file;

GetOptions(
	'username=s'	=> \$user,
	'password=s'	=> \$password,
	'authapp=s'		=> \$authapp,
	'file=s'		=> \$firmware_file,
	'debug+'		=> sub { $debug += 1; $verbose = 10; },
	'verbose+'		=> \$verbose,
	'format=s'		=> \$output_format,
	'output=s'		=> \$output_file,
);

if ($output_format ne 'text' and $output_format ne 'json') {
	print STDERR "Argument to --format must be either 'text' or 'json'\n";
	exit 1;
}

my $redfish = JazzHands::Redfish->new();
my $credentials;

my $status = {};

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
	my $errors = [];
	$status->{$host} = {
		firmware => [],
		errors => []
	};
	my $stat_data = $status->{$host};

	my $conninfo = {
		hostname => $host
	};

	if ($verbose) {
		printf STDERR "Querying %s: ", $host;
	}

	my $result;
	#
	# Get the current firmware information
	#
	$result = $redfish->SendCommand(
		device => $conninfo,
		credentials => $credentials,
		url => '/redfish/v1/UpdateService/FirmwareInventory',
		errors => $errors,
		debug => $debug
	);

	if (!$result) {
		push
			@{$stat_data->{errors}},
			{ 
				url => '/redfish/v1/UpdateService/FirmwareInventory',
				errors => $errors
			};

		if (!$verbose) {
			printf STDERR "Error querying %s: ", $host;
		}

		printf STDERR "%s\n", join("\n", @$errors);
		next DEVLOOP;
	} else {
		if ($verbose) {
			printf "Ok\n";
		}
	}

	if ($debug) {
		local $Data::Dumper::Terse = 1;
		printf STDERR "Result:\n%s\n", Dumper($result);
	}

	next if (!exists($result->{Members}));
	foreach my $member (@{$result->{Members}}) {
		if ($member->{'@odata.id'} =~ m!/Installed!) {
			$errors = [];
			my $fwdata = $redfish->SendCommand(
				device => $conninfo,
				credentials => $credentials,
				url => $member->{'@odata.id'},
				errors => $errors,
				debug => $debug
			);

			if (!$fwdata) {
				push
					@{$stat_data->{errors}},
					{ 
						url => $member->{'@odata.id'},
						errors => $errors
					};

				if ($debug) {
					printf STDERR "Error fetching %s from %s: %s\n",
						$member->{'@odata.id'},
						$host,
						join ("\n", @$errors);
				}

				next;
			}
			push @{$stat_data->{firmware}},
				{
					component_name => $fwdata->{Name},
					version => $fwdata->{Version},
					updateable => $fwdata->{Updateable}
				};
		}
	}
	print Dumper $stat_data->{firmware};
}

