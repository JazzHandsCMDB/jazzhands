#!/usr/bin/env perl
#
# Copyright (c) 2015, Todd M. Kover
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#	   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;
use Data::Dumper;
use JSON::PP;
use JazzHands::DBI;
use Net::SSLeay;
use Pod::Usage;
use Getopt::Long;
use JazzHands::AppAuthAL;
use Email::Date::Format qw(email_date);
use DateTime::Format::Strptime;
use FileHandle;
use POSIX;

my $service = "approval-build";

=head1 NAME

build-approvals - 
=head1 SYNOPSIS

build-approvals [ --debug ][ --dry-run | -n ]  [ --random-sleep=# ] 

=head1 DESCRIPTION

Calls the database funcions required to setup any outstanding approvals.

--debug makes it more noisy.

--dry-run is currently useless.

--random-sleep tells the script to wait a random number of seconds after
starting before doing any work.  This may be used when the invocation happens
on multiple machines but can not run at the exact same time due to locking
or lack thereof. 

=head1 AUTHORS

Todd M. Kover <kovert@omniscient.com>

=cut 

exit do_work();

#############################################################################

my $dbh;

sub do_work {
	$dbh = JazzHands::DBI->connect( $service, { AutoCommit => 0 } )
	  || die $JazzHands::DBI::errstr;

	my ( $stabroot, $debug, $dryrun, $updatedb, $mailfrom, $signer, $login );
	my ( $sleep, $argnow, $remindergap );

	my ($faqurl);

	my $escalationgap = 0;
	my $escalationlevel;

	GetOptions(
		"debug"              => \$debug,
		"dry-run|n"          => \$dryrun,
		"random-sleep=i"     => \$sleep,
	) || die pod2usage();

	if ($sleep) {
		my $delay = int( rand($sleep) );
		warn "Sleeping $delay seconds\n" if ($debug);
		sleep($delay);
	}

	warn "Building Database connection()...\n" if($debug);
	my $sth = $dbh->prepare_cached(q{
		SELECT approval_utils.build_attest()
	}) || die $dbh->errstr;

	warn "Calling build_attest()...\n" if($debug);
	$sth->execute() || die $sth->errstr;
	while(my ($tally) = $sth->fetchrow_array) {
		if($tally) {
			warn "Updated $tally rows\n" if($debug);
		}
	}
	$sth->finish;
	warn "Done calling build_attest()" if($debug);
	$dbh->commit;
}

END {
	if ($dbh) {
		$dbh->rollback;
		$dbh->disconnect;
		$dbh = undef;
	}
}
