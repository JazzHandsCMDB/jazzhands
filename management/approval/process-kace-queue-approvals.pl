#!/usr/bin/env perl
# Copyright (c) 2016, Ryan D Williams
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

use strict;
use warnings;
use JazzHands::DBI;
use Pod::Usage;
use Getopt::Long;
use IO::Select;
use JazzHands::Approvals;
use JazzHands::Tickets::KACE;
use File::Basename;

my $approval_service = 'kace-attestation';
my $kace_service 	 = 'kace-tix';

=head1 NAME

process-kace-issue-approvals

=head1 SYNOPSIS

process-kace-ticket-approvals [ --dry-run | -n ]  [ --verbose ] [ --daemonize ] [ --debug ] [ --random-sleep=# ] [ --force-assign=login ] [ --once ] [ --resolution-delay=# ] --queue queue_name

=head1 DESCRIPTION

This script looks through open KACE Issues associated with approval steps and
closes the approval steps if applicable.  It also looks for open approval
steps associated with the kace-hr type (or the --type argument) and opens a new
issue in the project specified by the --queue argument.  In all liklihood, most
environments will have the --queue argument, and possibly the --type and
--random-sleep arguments and nothing else.

The --type option specifies which approval instance step type to look for, and
defaults to kace-hr.

The --random-sleep argument tells the script to sleep a random amount of time
when starting.   This is probably not necessary.

The -n (or --dry-run) argumenets causes no issues created or approval steps to
be managed, it just says what would happen if the -n option was not there.

The --verbose and --debug optiosn produce varying degrees of verbosity.  These
do not influence each other and likely debug means that verbose should also be
specified.

The --force-assign indicates that new issues should have login setup as the
requestor.  The default behavior is to have the user on whose behalf it is being
opened as the target.  This is primarily for debugging.

--resolution-delay specifies how long to treat an issue resolved in KACE before
the step is marked as resolved.  This is to allow time for feeds to run.  It
defaults to an hour.

--no-daemonize can be used to tell it not to fork as a daemon.  --daemonize
is redundant.

=head1 AUTHORS

Ryan D Williams <xrxdxwx@gmail.com>

=cut 

exit do_work();

#############################################################################

sub do_work {
	my ( $dryrun,    $verbose,   $debug );
	my ( $priority,  $issuetype, $queue, $forceassign );
	my ( $daemonize, $onetime,   $delay, $sleep, $commit_on_open );

	my $command = basename($0);

	#
	# hidden-type can be used to override this, but probably not smart.
	#
	my $type = 'kace-hr';

	$daemonize 		= 1;
	$commit_on_open = 1;

	GetOptions(
		"dry-run|n"          => \$dryrun,
		"daemonize!"         => \$daemonize,
		"queue=s"          	 => \$queue,
		"force-assign=s"     => \$forceassign,
		"issue-type=s"       => \$issuetype,
		"resolution-delay=i" => \$delay,
		"commit-on-open!" 	 => \$commit_on_open,
		"hidden-type=s"      => \$type,
		"verbose"            => \$verbose,
		"once"               => \$onetime,
		"debug"              => \$debug,
		"random-sleep=i"     => \$sleep,
	) || die pod2usage();

	my $kace = new JazzHands::Tickets::KACE(
		service => $kace_service,
		queue 	=> $queue,
	) || die $JazzHands::Tickets::KACE::Errstr;

	$kace->set( 'forceassign', $forceassign ) if ($forceassign);
	$kace->set( 'delay',       $delay )       if ($delay);

	$kace->set( 'verbose', $verbose ) if ($verbose);
	$kace->dryrun($dryrun);

	if ($sleep) {
		my $delay = int( rand($sleep) );
		warn "Sleeping $delay seconds\n" if ($verbose);
		sleep($delay);
	}

	my $app = new JazzHands::Approvals(
		daemonize 		=> $daemonize,
		service   		=> $approval_service,
		type      		=> $type,
		verbose   		=> $verbose,
		debug     		=> $debug,
		commit_on_open  => $commit_on_open,
		delay    		=> $delay,
		myname    		=> $command,
	) || die $JazzHands::Approvals::Errstr;

	$app->dryrun($dryrun);

	if ($onetime) {
		$app->onetime($kace) || die $app->errstr;
	} else {
		$app->mainloop($kace) || die $app->errstr;
	}

	0;
}
