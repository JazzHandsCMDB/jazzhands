#!/usr/bin/env perl

use FindBin qw($RealBin);

use lib "$RealBin/../../perllib";

use JazzHands::Common;
use JazzHands::NetDev::Mgmt;
use JazzHands::DBI;
use JazzHands::AppAuthAL;
use NetAddr::IP;
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
my $defuser = $ENV{'USER'};
my $user;
my $merge = 0;
my $pull = 0;
my $push = 1;
my $pushopt;
my $pullopt;
my $notreally = 0;
my $verbose = 0;
my $prefixlist = [];
my $default_dev_function = ['core_switch', 'border_router'];
my $dev_function = [];
my $site = [];
my $authapp = 'sync-prefix-lists';

sub loggit {
	printf STDERR join "\n", @_;
	print "\n";
}

GetOptions(
	'prefix-list=s', $prefixlist,
	'authapp=s', $authapp,
	'username=s', \$user,
	'merge!', \$merge,
	'pull!', \$pullopt,
	'push!', \$pushopt,
	'commit!', \$commit,
	'verbose+', \$verbose,
	'notreally!', \$notreally,
	'type|function=s', $dev_function,
	'site=s', $site
);

my @errors;
my $jh;
if (!($jh = JazzHands::DBI->new->connect(
		application => $authapp,
		cached => 1,
		dbiflags => { AutoCommit => 0, PrintError => 0 },
		))) {
	printf STDERR "Unable to connect to database: %s\n",
		$JazzHands::DBI::errstr;
	exit 1;
}

if (defined($pullopt)) {
	$pull = $pullopt;
	$push = 0;
}
if (defined($pushopt)) {
	$push = $pushopt;
}

my $password;

if (!$user) {
	my $record = JazzHands::AppAuthAL::find_and_parse_auth($authapp);

	if (!$record || !$record->{network_device}) {
		$user = $defuser;
		if (!$user) {
			printf "No network_device appauth entry found, and no username provided for local authentication\n";
			exit 1;
		}
	} else {
		$user = $record->{network_device}->{username};
		$password = $record->{network_device}->{password};
	}
} 

if (!$password) {
	$password = AskPass();
	if (!$password) {
		print STDERR "Password required\n";
		exit 1;
	}
}

my $mgmt = new JazzHands::NetDev::Mgmt;

my @hosts;


if (@ARGV) {
	@hosts = @ARGV;
} else {
	my $args = [ @$dev_function ? $dev_function : $default_dev_function ];

	##
	## We only handle Juniper devices right now, but that will change
	## shortly after we separate ACL vs. routing prefix-lists and
	## being able to assign prefix-lists to device_collections
	##
	my $q = q {
		SELECT
			device_name
		FROM
			device d JOIN
			device_type dt USING (device_type_id) JOIN
			device_collection_device dcd USING (device_id) JOIN
			device_collection dc USING (device_collection_id) JOIN
			site s USING (site_code)
		WHERE
			device_status = 'up' AND
			device_collection_type = 'device-function' AND
			device_collection_name = ANY (?) AND
			config_fetch_type = 'juniper'
	};
	if (@$site) {
		$q .= "			AND site_code = ANY(?)";
		push @$args, $site;
	} else {
		$q .= "			AND site_status = 'ACTIVE'";
	}
	my $sth;
	if (!($sth = $jh->prepare_cached($q))) {
		print STDERR "Unable to device query\n";
		exit 1;
	}
#	print "$q\n";
#	print Dumper $args;
	if (!($sth->execute(@$args))) {
		loggit "Unable to execute device query\n";
		exit 1;
	}
	while (my $row = $sth->fetchrow_arrayref) {
		push @hosts, $row->[0];
	}
}


my $q = qq {
	SELECT
		netblock_collection_id,
		netblock_collection_name,
		netblock_id,
		netblock_type,
		ip_address,
		CASE 
			WHEN is_single_address = 'Y' THEN true
			ELSE false
		END AS is_single_address
	FROM
		netblock_collection nc LEFT JOIN
		netblock_collection_netblock ncn USING (netblock_collection_id)
			LEFT JOIN
		netblock n USING (netblock_id)
	WHERE
		netblock_collection_type = 'prefix-list'
};

my $all_nc_sth;
if (!($all_nc_sth = $jh->prepare_cached($q))) {
	print STDERR "Unable to prepare netblock collection list query\n";
	exit 1;
}

$q = qq {
	SELECT
		netblock_collection_id,
		netblock_collection_name,
		netblock_id,
		netblock_type,
		ip_address,
		CASE 
			WHEN is_single_address = 'Y' THEN true
			ELSE false
		END AS is_single_address
	FROM
		netblock_collection nc LEFT JOIN
		netblock_collection_netblock ncn USING (netblock_collection_id)
			LEFT JOIN
		netblock n USING (netblock_id)
	WHERE
		netblock_collection_type = 'prefix-list' AND
		netblock_collection_name = ANY(?)
};

my $nc_list_sth;
if (!($nc_list_sth = $jh->prepare_cached($q))) {
	print STDERR "Unable to prepare netblock collection list query\n";
	exit 1;
}

$q = qq {
	SELECT
		netblock_collection_id,
		netblock_id,
		netblock_type,
		ip_address,
		CASE 
			WHEN is_single_address = 'Y' THEN true
			ELSE false
		END AS is_single_address
	FROM
		netblock_collection nc LEFT JOIN
		netblock_collection_netblock ncn USING (netblock_collection_id)
			LEFT JOIN
		netblock n USING (netblock_id)
	WHERE
		netblock_collection_type = 'prefix-list' AND
		netblock_collection_name = ?
};

my $nc_sth;
if (!($nc_sth = $jh->prepare_cached($q))) {
	print STDERR "Unable to prepare netblock collection query\n";
	exit 1;
}

$q = qq {
	DELETE FROM
		netblock_collection_netblock
	WHERE
		netblock_collection_id = ? AND
		netblock_id = ANY(?)
};

my $member_del_sth;
if (!($member_del_sth = $jh->prepare_cached($q))) {
	print STDERR "Unable to prepare netblock collection member delete query\n";
	exit 1;
}

$q = qq {
	INSERT INTO netblock_collection_netblock (
		netblock_collection_id,
		netblock_id
	) VALUES (
		?, ?
	)
};

my $member_ins_sth;
if (!($member_ins_sth = $jh->prepare_cached($q))) {
	print STDERR "Unable to prepare netblock collection member insert query\n";
	exit 1;
}

$q = qq {
	INSERT INTO netblock_collection (
		netblock_collection_name,
		netblock_collection_type
	) VALUES (
		?, 'prefix-list'
	)
	RETURNING *
};

my $nc_ins_sth;
if (!($nc_ins_sth = $jh->prepare_cached($q))) {
	loggit sprintf("Unable to prepare netblock collection insert query: %s",
		$jh->errstr);
	exit 1;
}

$q = qq {
	SELECT 
		netblock_collection_id
	FROM
		netblock_collection 
	WHERE
		netblock_collection_type = 'prefix-list' AND
		netblock_collection_name = ?
};

my $nc_exist_sth;
if (!($nc_exist_sth = $jh->prepare_cached($q))) {
	loggit sprintf("Unable to prepare netblock collection existence query: %s",
		$jh->errstr);
	exit 1;
}

#
# Find an appropriate netblock to use for the prefix-list.
# This query prefers a default netblock_type first, followed by
# a 'prefix-list' netblock_type.  For single addresses, it will match
# either a netblock with an identical netmask or a /32 or /128.  Finally,
# for blocks with potential multiple matches (e.g. loopback addresses),
# prefer the single-address block over the non-single-address block.
#
$q = qq {
	SELECT 
		netblock_id,
		ip_address,
		netblock_type,
		CASE
			WHEN is_single_address = 'Y' THEN 0
			ELSE 1
		END AS single,
		CASE
			WHEN netblock_type = 'default' THEN 0
			ELSE 1
		END AS ordering

	FROM
		netblock
	WHERE
		netblock_type IN ('default', 'prefix-list') AND
		ip_address = ? OR
		(host(ip_address)::inet = ? and is_single_address = 'Y')
	ORDER BY ordering, single
	LIMIT 1
};

my $nb_sth;
if (!($nb_sth = $jh->prepare_cached($q))) {
	loggit sprintf("Unable to prepare netblock select query: %s",
		$jh->errstr);
	exit 1;
}

$q = qq {
	INSERT INTO netblock (
		ip_address,
		netblock_type,
		is_single_address,
		can_subnet,
		netblock_status
	) VALUES (
		?,
		'prefix-list',
		'N',
		'N',
		'Allocated'
	)
	RETURNING *
};

my $nb_ins_sth;
if (!($nb_ins_sth = $jh->prepare_cached($q))) {
	loggit sprintf("Unable to prepare netblock insert query: %s",
		$jh->errstr);
	exit 1;
}

foreach my $hostname (@hosts) {
	printf "Host: %s\n", $hostname if $verbose;
	my $dev;
	if (!($dev = $mgmt->connect(
			device => {
				hostname => $hostname,
				network_device_type => 'juniperswitch',
				management_type => 'juniper'
			},
			credentials => {
				username => $user,
				password => $password
			},
			errors => \@errors))) {
		printf "Error connecting to device: %s\n", (join "\n", @errors);
		next;
	}

	my $device_pls;

	if (!defined($device_pls = $dev->GetPrefixLists(
		(@$prefixlist ? ( "prefix-lists" => $prefixlist ) : () ),
		errors => \@errors))) {
		printf "Error getting prefix list from %s: %s\n", $hostname,
			(join "\n", @errors);
		next;
	}
	if ($pull) {
		print "    Syncing prefix-lists FROM device..." if $verbose > 1;
		foreach my $pl (sort keys %$device_pls) {
			printf "    Prefix-List: %s...", $pl if $verbose > 1;

			if (!($nc_exist_sth->execute($pl))) {
				loggit "Unable to execute netblock collection existence query\n";
				exit 1;
			}
			my $nc;
			if (!($nc = $nc_exist_sth->fetchrow_hashref)) {
				print " not found\n" if $verbose > 1;
				print "       creating new prefix list..." if $verbose > 1;
				if (!($nc_ins_sth->execute($pl))) {
					loggit sprintf("Unable to create netblock: %s", 
						$nc_ins_sth->errstr);
					exit 1;
				}
				$nc = $nc_ins_sth->fetchrow_hashref;
				$nc_ins_sth->finish;
			}
			$nc_exist_sth->finish;
			if (!($nc_sth->execute($pl))) {
				loggit "Unable to execute netblock collection query\n";
				exit 1;
			}
			my $prefixlist = [];
			my $val;
			while ($val = $nc_sth->fetchrow_hashref) {
				if ($val->{ip_address}) {
					$val->{ip_address} = NetAddr::IP->new($val->{ip_address});
					push @$prefixlist, $val;
				}
			}
			$nc_sth->finish;
			printf " id %d\n", $nc->{netblock_collection_id} if $verbose > 1;

			foreach my $nb (@{$device_pls->{$pl}}) {
				print "        Looking for netblock $nb in netblock collection... " if $verbose > 2;
				#
				# There may be some weird edge cases here
				#
				my $target_nb = [ grep { 
						$_->{is_single_address} ?
							($nb->addr eq $_->{ip_address}->addr) :
							($nb eq $_->{ip_address})
					} @$prefixlist ];
				if (@$target_nb) {
					print "found\n" if $verbose > 2;
					$target_nb->[0]->{found} = 1;
					next;
				} else {
					print "not found\n" if $verbose > 2;
					printf "            Looking for netblock %s... ", $nb
						if $verbose > 2;
					if (!($nb_sth->execute($nb, $nb))) {
						loggit(sprintf(
							"Unable to execute netblock existence query: %s",
							$nb_sth->errstr
						));
						exit 1;
					}
					my $db_nb = $nb_sth->fetchrow_hashref;
					$nb_sth->finish;
					if ($db_nb) {
						printf "found %s netblock %s (%d)\n",
							$db_nb->{netblock_type},
							$db_nb->{ip_address},
							$db_nb->{netblock_id}
						if $verbose > 2;
					} else {
						print "not found\n" if $verbose > 2;
						printf "            Inserting netblock %s... ", $nb
							if $verbose > 2;
						if (!($nb_ins_sth->execute($nb))) {
							loggit(sprintf(
								"Unable to execute netblock insert query: %s",
								$nb_ins_sth->errstr
							));
							exit 1;
						}
						$db_nb = $nb_ins_sth->fetchrow_hashref;
						$nb_ins_sth->finish;
						printf "inserted  %s netblock %s (%d)\n",
							$db_nb->{netblock_type},
							$db_nb->{ip_address},
							$db_nb->{netblock_id}
						if $verbose > 2;
					}
					if (!($member_ins_sth->execute(
						$nc->{netblock_collection_id},
						$db_nb->{netblock_id}
					))) {
						loggit(sprintf(
							"Unable to execute netblock insert query: %s",
							$nb_ins_sth->errstr
						));
						exit 1;
					}
				}

			}
			if (!$merge) {
				#
				# If we're not merging, then delete anything that didn't match
				# above
				#
				my $nbs = [ grep { !($_->{found}) } @$prefixlist ];
				if (!@$nbs) {
					print "        No netblocks to delete from collection...\n"
						if $verbose > 2;
				} else {
					printf "        Removing %s from netblock collection\n",
						(join ",", (map { $_->{ip_address} } @$nbs)) 
						if $verbose > 2;	
					if (!($member_del_sth->execute(
						$nc->{netblock_collection_id},
						[ map { $_->{netblock_id} } @$nbs ]
					))) {
						loggit(sprintf(
							"Unable to execute netblock collection member delete query: %s",
							$member_del_sth->errstr
						));
						exit 1;
					}
				}
			}
		}
	}
	if ($push) {
		print "    Syncing prefix-lists TO device...\n" if $verbose > 1;
		my $sth;
		if (@$prefixlist) {
			$sth = $nc_list_sth;
			if (!($nc_list_sth->execute(
				$prefixlist
			))) {
				loggit(sprintf(
					"Unable to execute netblock collection list query: %s",
					$nc_list_sth->errstr
				));
				exit 1;
			}
		} else {
			$sth = $all_nc_sth;
			if (!($all_nc_sth->execute)) {
				loggit(sprintf(
					"Unable to execute all netblock collection list query: %s",
					$all_nc_sth->errstr
				));
				exit 1;
			}
		}
		my $prefixlists = {};
		my $val;
		while ($val = $sth->fetchrow_hashref) {
			if (!$prefixlists->{$val->{netblock_collection_name}}) {
				$prefixlists->{$val->{netblock_collection_name}} = [];
			}
			$val->{ip_address} = NetAddr::IP->new($val->{ip_address});
			if ($val->{is_single_address}) {
				$val->{ip_address} = NetAddr::IP->new($val->{ip_address}->addr,
					$val->{ip_address}->version eq 4 ? 32 : 128);
			}
			push @{$prefixlists->{$val->{netblock_collection_name}}}, $val;
		}
		$sth->finish;
		my $changes = 0;
		foreach my $pl (sort keys %$prefixlists) {
			printf "    Prefix-List: %s... ", $pl if $verbose > 1;
			#
			# Figure out if the prefix-lists are different
			#

			#
			# If the prefix-list doesn't exist on the device, or if they
			# are different lengths, then they're different
			#
			my $changed = 0;
			if (!exists($device_pls->{$pl})) {
				print "does not exist on device..." if $verbose > 2;
				$changed = 1;
			} else {
				my $devpl = $device_pls->{$pl};
				my $dbpl = $prefixlists->{$pl};
				foreach my $entry (sort 
						{ $a->{ip_address} cmp $b->{ip_address} } @$dbpl
					) {
					if (!grep { $entry->{ip_address} eq $_ } @$devpl) {
						printf "\n        + %s",
							$entry->{ip_address}
							if $verbose > 2;
					
						$changed = 1;
					}
				}
				foreach my $entry (sort 
						{ $a cmp $b } @$devpl
					) {
					if (!grep { $_->{ip_address} eq $entry } @$dbpl) {
						printf "\n        - %s",
							$entry
							if $verbose > 2;
					
						$changed = 1;
					}
				}
			}
			if ($changed) {
				if (!$notreally) {
					print "  Pushing new prefix-list" if $verbose > 2;
					$changes = 1;
					
					if (!$dev->SetPrefixLists(
						'prefix-lists' => {
							$pl => [ 
								map { $_->{ip_address} } @{$prefixlists->{$pl}} 
							]
						},
						errors => \@errors)
					) {
						printf "Error setting prefix list for %s: %s", $pl,
							(join "\n", @errors);
						exit 1;
					}
				}
				print "\n";
			}
			print "\n" if $verbose > 1;
		}

		if ($changes) {
			if (!($dev->commit(errors => \@errors))) {
				loggit(
					sprintf(
						"Error committing configurations to %s: %s",
						$hostname,
						(join "\n", @errors)
					)
				);
			}
		}
	}
}

if ($commit && !$notreally) {
	$jh->commit;
} else {
	$jh->rollback;
}

use vars qw($tios $c_lflag);
sub AskPass {
	my $fh;
	my $passwd;
	if (open ($fh, '<', "/dev/tty")) {
		print STDERR "Password: ";
		ReadMode 'noecho';
		chomp($passwd = ReadLine 0, $fh);
		print STDERR "\n";
		close $fh;
		ReadMode 'restore';
	}
	return $passwd;

	END {
		ReadMode 'normal';
	}
}

