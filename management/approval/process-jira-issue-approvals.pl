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
use JazzHands::Approvals;
use JazzHands::Tickets::JIRA;
use File::Basename;

my $service = 'jira-attestation';

$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;
$ENV{'HTTPS_DEBUG'}                  = 0;

=head1 NAME

process-jira-issue-approvals

=head1 SYNOPSIS

process-jira-ticket-approvals [ --dry-run | -n ]  [ --verbose ] [ --daemonize ] [ --debug ] [ --random-sleep=# ] [ --webroot=URL ] [ --user=username ] [ --password=password ] [ --force-assign=login ] [ --issue-type=type ] [ --once ] [ --resolution-delay=# ] --project projectname

=head1 DESCRIPTION

This script looks through open Jira Issues associated with approval steps and
closes the approval steps if applicable.  It also looks for open approval
steps associated with the jira-hr type (or the --type argument) and opens a new
issue in the project specified by the --project argument.  In all liklihood, most
environments will have the --project argument, and possibly the --type and
--random-sleep arguments and nothing else.

The --type option specifies which approval instance step type to look for, and
defaults to jira-hr.

The --random-sleep argument tells the script to sleep a random amount of time
when starting.   This is probably not necessary.

The -n (or --dry-run) argumenets causes no issues created or approval steps to
be managed, it just says what would happen if the -n option was not there.

The --verbose and --debug optiosn produce varying degrees of verbosity.  These
do not influence each other and likely debug means that verbose should also be
specified.

--webroot, --user and --password all describe how to talk to RT.  These are
typically pulled from the AppAuth Layer application jira-attestation.

The --force-assign indicates that new issues should have login setup as the
requestor.  The default behavior is to have the user on whose behalf it is being
opened as the target.  This is primarily for debugging.

--resolution-delay specifies how long to treat an issue resolved in Jira before
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
	my ( $dryrun,   $verbose,     $debug );
	my ( $jiraroot, $jirauser,    $jirapass, $priority, $issuetype );
	my ( $project,  $forceassign, $daemonize, $onetime, $delay );
	my ($sleep);

	my $command = basename($0);

	#
	# hidden-type can be used to override this, but probably not smart.
	#
	my $type = 'jira-hr';

	$daemonize = 1;

	GetOptions(
		"dry-run|n"          => \$dryrun,
		"daemonize!"         => \$daemonize,
		"webroot=s"          => \$jiraroot,
		"user=s"             => \$jirauser,
		"password=s"         => \$jirapass,
		"project=s"          => \$project,
		"force-assign=s"     => \$forceassign,
		"priority=s"         => \$priority,
		"issue-type=s"       => \$issuetype,
		"resolution-delay=i" => \$delay,
		"hidden-type=s"      => \$type,
		"verbose"            => \$verbose,
		"once"               => \$onetime,
		"debug"              => \$debug,
		"random-sleep=i"     => \$sleep,
	) || die pod2usage();

	my $jira = new JazzHands::Tickets::JIRA(
		service => $service,
		project => $project,
	) || die $JazzHands::Tickets::JIRA::Errstr;

	$jira->set( 'webroot',     $jiraroot )    if ($jiraroot);
	$jira->set( 'username',    $jirauser )    if ($jirauser);
	$jira->set( 'password',    $jirapass )    if ($jirapass);
	$jira->set( 'priority',    $priority )    if ($priority);
	$jira->set( 'issuetype',   $issuetype )   if ($issuetype);
	$jira->set( 'forceassign', $forceassign ) if ($forceassign);
	$jira->set( 'delay',       $delay )       if ($delay);

	$jira->set( 'verbose', $verbose ) if ($verbose);
	$jira->dryrun($dryrun);

	if ($sleep) {
		my $delay = int( rand($sleep) );
		warn "Sleeping $delay seconds\n" if ($verbose);
		sleep($delay);
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
		$app->onetime($jira) || die $app->errstr;
	} else {
		$app->mainloop($jira) || die $app->errstr;
	}

	0;
}
