#!/usr/bin/env perl

use strict;
use warnings qw(all);
use FindBin qw($RealBin);

use DBI;
#use Data::Dumper;
use Getopt::Long;
use Socket;
use NetAddr::IP;
use JazzHands::DBI;
use JazzHands::AppAuthAL;
use JazzHands::Common::Error qw(:all);
use JazzHands::Common::Util qw(_options);
use JazzHands::NetDev::Mgmt;
use JSON;

my $verbose = 0;
my $debug = 0;
my $prompt = 1;
my $errstr;
my $ignoreme;
my $notreally;
my $subnet_priority;
my $domain;
my $tag;
my $upload = 0;
my $force = 0;

my $authapp = 'network-manip';

if (!GetOptions(
	'n|notreally!', \$notreally,
	'prompt!', \$prompt,
	'verbose+', \$verbose,
	'debug!', \$debug,
	'encapsulation-tag|tag|vlan=i', \$tag,
	'encapsulation-domain|domain|site=s', \$domain,
	'upload!', \$upload,
	'super-secret-forcd!', \$ignoreme,
	'super-secret-force!', \$force,
)) {
	exit 1;
}

if (!$tag || !$domain) {
	print STDERR "Error: must give --encapsulation-domain and --encapsulation-tag\n";
	exit 1;
}

my @errors;
my $jh;
if (!($jh = JazzHands::DBI->new->connect(
        application => $authapp,
        cached => 1,
        dbiflags => { AutoCommit => 0, PrintError => 0 },
		errors => \@errors
        ))) {
    printf STDERR "Unable to connect to database: %s\n",
        join ("\n", @errors);
    exit 1;
}

my $netconf = new  JazzHands::NetDev::Mgmt;
my $record = JazzHands::AppAuthAL::find_and_parse_auth($authapp);
if (!$record || !$record->{network_device}) {
	printf STDERR "Unable to find network_device auth entry for %s\n",
		 $authapp;
	exit 1;
}
my $netdev_creds = $record->{network_device};

my ($q, $sth, $ret);

#
# Validate that the VLAN exists
#
$q = q {
	SELECT
		lxe.layer3_network_id,
		lxe.layer2_network_id,
		lxe.ip_address
	FROM
		v_layerx_network_expanded lxe
	WHERE
		lxe.encapsulation_domain = ? AND
		lxe.encapsulation_tag = ?
};

if (!($sth = $jh->prepare($q))) {
	print STDERR "Error preparing layer2_network query\n";
	exit 1;
}

if (!$sth->execute($domain, $tag)) {
	$errstr = $sth->errstr;
	$errstr =~ s/ERROR:\s+([^\n]*)\n.*$/$1/s;
	printf STDERR "Error fetching layer2_network: %s\n", $errstr;
	exit 1;
}

my $l3 = [];
while (my $row = $sth->fetchrow_hashref) {
	push @$l3, $row;
}
$sth->finish;

if (!@$l3) {
	printf STDERR "Layer 2 network not found with encapsulation domain '%s' and tag '%s'\n",
		$domain, $tag;
	exit 1;
}
my $l2id = $l3->[0]->{layer2_network_id};

if ($debug) {
	printf STDERR "Found layer2_network %d\n", $l2id;
}

#
# Validate that we can remove this network.  Error if there
# are any addresses still assigned that have not been removed
# and are not assigned to routing devices we're going to
# clean up
#
$q = q{
	SELECT
		d.device_id,
		COALESCE(d.device_name, d.physical_label) AS
			device_name,
		ni.layer3_interface_name,
		host(n.ip_address) AS ip_address
	FROM
		device d
		JOIN layer3_interface ni using (device_id)
		JOIN layer3_interface_netblock nin USING
			(layer3_interface_id)
		JOIN netblock n USING (netblock_id)
		JOIN v_layerx_network_expanded lxe ON
			(n.parent_netblock_id = lxe.netblock_id)
		LEFT JOIN device_encapsulation_domain ded ON
			(d.device_id = ded.device_id)
	WHERE
		lxe.encapsulation_domain = ?
		AND lxe.encapsulation_tag = ?
		AND ded.encapsulation_domain IS DISTINCT FROM
			lxe.encapsulation_domain
	ORDER BY
		n.ip_address
};

if (!($sth = $jh->prepare($q))) {
	print STDERR "Error preparing VLAN inventory query\n";
	exit 1;
}

if (!$sth->execute($domain, $tag)) {
	$errstr = $sth->errstr;
	$errstr =~ s/ERROR:\s+([^\n]*)\n.*$/$1/s;
	printf STDERR "Error fetching VLAN inventory: %s\n",
		$errstr;
	exit 1;
}

$ret = $sth->fetchall_arrayref;
$sth->finish;

if (@$ret) {
	printf "%sThe following hosts are still active on this network:\n",
		$force ? "WARNING: " : "";
	foreach my $row (@$ret) {
		printf "%-25s %s (%d)",
			$row->[3],
			$row->[1],
			$row->[0];
		if ($row->[2]) {
			printf " (%s)",
				$row->[2];
		}
		print "\n\n";
	}
	if (!$force) {
		exit 1;
	}
}

$q = q{
	SELECT DISTINCT
		d.device_id,
		COALESCE(d.device_name, d.physical_label)
			AS device_name,
		ni.layer3_interface_name,
		dt.config_fetch_type
	FROM
		device d
		JOIN device_type dt USING (device_type_id)
		JOIN layer3_interface ni using (device_id)
		JOIN layer3_interface_netblock nin USING
			(layer3_interface_id)
		JOIN netblock n USING (netblock_id)
		JOIN v_layerx_network_expanded lxe ON
			(n.parent_netblock_id = lxe.netblock_id)
		LEFT JOIN device_encapsulation_domain ded ON
			(d.device_id = ded.device_id)
	WHERE
		lxe.encapsulation_domain = ?
		AND lxe.encapsulation_tag = ?
		AND ded.encapsulation_domain IS NOT DISTINCT FROM
			lxe.encapsulation_domain
	ORDER BY
		device_name
};

if (!($sth = $jh->prepare($q))) {
	print STDERR "Error preparing device list query\n";
	exit 1;
}

if (!$sth->execute($domain, $tag)) {
	$errstr = $sth->errstr;
	$errstr =~ s/ERROR:\s+([^\n]*)\n.*$/$1/s;
	printf STDERR "Error fetching device list: %s\n",
		$errstr;
	exit 1;
}

my $devices = [];
while (my $row = $sth->fetchrow_hashref) {
	push @$devices, $row;
}
$sth->finish;

if (!@$devices) {
	print "No devices found hosting this network.  Only removing from database.\n";
} else {
	printf "Removing the following interfaces:\n";

	printf "%s\n\n", join ("\n", 
		map {
			sprintf("    %s: %s",
				$_->{device_name},
				$_->{layer3_interface_name}
			)
		} @${devices}
	);
}

if ($prompt) {
    print STDERR "OK? ";
    my $crap = <STDIN>;
    chomp $crap;
    if ($crap !~ /^[yY]/) {
        exit 0;
    }
}

foreach my $devrec (@$devices) {
	my $mgmt = JazzHands::NetDev::Mgmt->new;
	my $device;
	undef @errors;
	printf "%s: ", $devrec->{device_name};
	if (!($device = $mgmt->connect(
			device => {
				hostname => $devrec->{device_name},
				management_type => $devrec->{config_fetch_type}
			},
			credentials => $netdev_creds,
			errors => \@errors))) {
		printf "Error connecting to device: %s\n", (join "\n", @errors);
		next;
	}

	if (!($device->RemoveVLAN(
			encapsulation_tag => $tag,
			errors => \@errors,
			debug => $debug
			))) {
		printf "%s: %s\n", $devrec->{device_name}, (join("\n", @errors));
		$device->rollback;
		$device->disconnect;
		next;
	}
	if ($notreally) {
		printf "Rolling back change to %s\n", $devrec->{device_name};
		$device->rollback;
	} else {
		$device->commit;
	}
	$device->disconnect;
	print "done\n";
}

printf "Deleting layer2_network with layer2_network_id %d... ", $l2id;

$q = q{
	SELECT * FROM layerx_network_manip.delete_layer2_network(
		layer2_network_id := ?,
		purge_network_interfaces := true
	)
};
if (!($sth = $jh->prepare($q))) {
	print STDERR "Error preparing delete_layer2_network query\n";
	exit 1;
}

if (!$sth->execute($l2id)) {
	$errstr = $sth->errstr;
	$errstr =~ s/ERROR:\s+([^\n]*)\n.*$/$1/s;
	printf STDERR "Error deleting layer2_network: %s\n",
		$errstr;
	exit 1;
}

if ($notreally) {
	printf "Rolling back database change\n";
	$jh->rollback;
} else {
	$jh->commit;
}

print "done\n";
