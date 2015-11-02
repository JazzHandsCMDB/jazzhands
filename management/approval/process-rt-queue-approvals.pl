#!/usr/bin/env perl
# Copyright (c) 2015, Todd M. Kover
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
use LWP::Protocol::https;
use LWP::UserAgent;
use HTTP::Cookies;
use LWP::Debug qw(+);
use Data::Dumper;
use JSON::PP;
use JazzHands::DBI;
use Net::SSLeay;
use Pod::Usage;
use Getopt::Long;
use JazzHands::AppAuthAL;
use IO::Select;
use File::Basename;
use JazzHands::Approvals;
use JazzHands::Tickets::RT;

my $service = 'rt-attestation';

$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;
$ENV{'HTTPS_DEBUG'}                  = 0;

=head1 NAME

process-rt-queue-approvals

=head1 SYNOPSIS

process-rt-queue-approvals [ --dry-run | -n ] [ --[no-]daemonize ] [ --verbose ] [ --debug ] [ --random-sleep=# ] [ --webroot=URL ] [ --user=username ] [ --password=password ] [ --force-assign=login ] [ --once ] --queue queuename

=head1 DESCRIPTION

This script looks through open RT tickets associated with approval steps and
closes the approval steps if applicable.  It also looks for open approval
steps associated with the rt-hr type (or the --type argument) and opens a new
ticket in the queue specified by the --queue argument.  In all liklihood, most
environments will have the --queue argument, and possibly the --type and
--random-sleep arguments and nothing else.

The --type option specifies which approval instance step type to look for, and
defaults to rt-hr.

The --random-sleep argument tells the script to sleep a random amount of time
when starting.   This is probably not necessary.

The -n (or --dry-run) argumenets causes no tickets created or approval steps to
be managed, it just says what would happen if the -n option was not there.

The --verbose and --debug optiosn produce varying degrees of verbosity.  These
do not influence each other and likely debug means that verbose should also be
specified.

--webroot, --user and --password all describe how to talk to RT.  These are
typically pulled from the AppAuth Layer application rt-attestation.

The --force-assign indicates that new tickets should have login setup as the
requestor.  The default behavior is to have the user on whose behalf it is being
opened as the target.  This is primarily for debugging.

--resolution-delay specifies how long to treat an issue resolved in RT before
the step is marked as resolved.  This is to allow time for feeds to run.  It
defaults to an hour.

--no-daemonize can be used to tell it not to fork as a daemon.  --daemonize
is redundant.

=head1 AUTHORS

Todd M. Kover <kovert@omniscient.com>

=cut 

exit do_work();

#############################################################################

sub do_work {
	my ( $dryrun, $verbose,     $debug );
	my ( $rtroot, $rtuser,      $rtpass );
	my ( $queue,  $forceassign, $daemonize, $onetime, $sleep );
	my ($delay);

	my $command = basename($0);

	#
	# hidden-type can be used to override this, but probably not smart.
	#
	my $type = 'rt-hr';

	$daemonize = 1;

	GetOptions(
		"daemonize!"         => \$daemonize,
		"debug"              => \$debug,
		"dry-run|n"          => \$dryrun,
		"force-assign=s"     => \$forceassign,
		"hidden-type=s"      => \$type,
		"once"               => \$onetime,
		"password=s"         => \$rtpass,
		"queue=s"            => \$queue,
		"random-sleep=s"     => \$sleep,
		"resolution-delay=i" => \$delay,
		"user=s"             => \$rtuser,
		"verbose"            => \$verbose,
		"webroot=s"          => \$rtroot,
	) || die pod2usage();

	my $rt = new JazzHands::Tickets::RT(
		service => $service,
		queue   => $queue,
	) || die $JazzHands::Tickets::RT::Errstr;

	$rt->set( 'webroot',     $rtroot )      if ($rtroot);
	$rt->set( 'username',    $rtuser )      if ($rtuser);
	$rt->set( 'password',    $rtpass )      if ($rtpass);
	$rt->set( 'forceassign', $forceassign ) if ($forceassign);

	$rt->set( 'verbose', $verbose ) if ($verbose);
	$rt->set( 'delay',   $delay )   if ($delay);
	$rt->dryrun($dryrun);

	if ($sleep) {
		my $length = int( rand($sleep) );
		warn "Sleeping $length seconds\n" if ($verbose);
		sleep($length);
	}

	my $app = new JazzHands::Approvals(
		daemonize => $daemonize,
		service   => $service,
		type      => $type,
		verbose   => $verbose,
		debug     => $debug,
		myname    => $command,
	) || die $JazzHands::Approvals::Errstr;

	$app->dryrun($dryrun);

	if ($onetime) {
		$app->onetime($rt) || die $app->errstr;
	} else {
		$app->mainloop($rt) || die $app->errstr;
	}

	0;
}
