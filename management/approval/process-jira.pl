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

my $service = 'rt-attestation';

$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;
$ENV{'HTTPS_DEBUG'}                  = 0;

=head1 NAME

process-ticekts - 
=head1 SYNOPSIS

process-rt [ --dry-run | -n ] 

=head1 DESCRIPTION

=head1 AUTHORS

Todd M. Kover <kovert@omniscient.com>

=cut 

exit do_work();

#############################################################################

sub do_work {
	my ( $dryrun, $verbose, $debug );
	my ( $jiraroot, $jirauser, $jirapass, $priority, $issuetype );
	my ( $project, $forceassign, $daemonize, $onetime );

	#
	# hidden-type can be used to override this, but probably not smart.
	#
	my $type = 'jira-hr';

	$daemonize = 1;

	GetOptions(
		"dry-run|n"      => \$dryrun,
		"daemonize!"     => \$daemonize,
		"webroot=s"      => \$jiraroot,
		"user=s"         => \$jirauser,
		"password=s"     => \$jirapass,
		"project=s"        => \$project,
		"force-assign=s" => \$forceassign,
		"priority=s"     => \$priority,
		"issue-type=s"   => \$issuetype,
		"hidden-type=s"  => \$type,
		"verbose"        => \$verbose,
		"once"           => \$onetime,
		"debug"          => \$debug,
	) || die pod2usage();

	my $jira = new JazzHands::Tickets::JIRA(
		service => $service,
		project   => $project,
	) || die $JazzHands::Tickets::JIRA::Errstr;

	$jira->set( 'webroot',     $jiraroot )    if ($jiraroot);
	$jira->set( 'username',    $jirauser )    if ($jirauser);
	$jira->set( 'password',    $jirapass )    if ($jirapass);
	$jira->set( 'priority',    $priority )    if ($priority);
	$jira->set( 'issuetype',   $issuetype )   if ($issuetype);
	$jira->set( 'forceassign', $forceassign ) if ($forceassign);

	$jira->set( 'verbose', $verbose ) if ($verbose);
	$jira->dryrun($dryrun);

	my $app = new JazzHands::Approvals(
		daemonize => $daemonize,
		service   => $service,
		type      => $type,
		verbose   => $verbose,
		debug     => $debug,
	) || die $JazzHands::Approvals::Errstr;

	$app->dryrun($dryrun);

	if ($onetime) {
		$app->onetime($jira) || die $app->errstr;
	} else {
		$app->mainloop($jira) || die $app->errstr;
	}

	0;
}
