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
	my ( $rtroot, $rtuser, $rtpass, $priority, $issuetype );
	my ( $queue, $forceassign, $daemonize, $onetime );

	my $command = basename($0);

	#
	# hidden-type can be used to override this, but probably not smart.
	#
	my $type = 'rt-hr';

	$daemonize = 1;

	GetOptions(
		"dry-run|n"      => \$dryrun,
		"daemonize!"     => \$daemonize,
		"webroot=s"      => \$rtroot,
		"user=s"         => \$rtuser,
		"password=s"     => \$rtpass,
		"queue=s"        => \$queue,
		"force-assign=s" => \$forceassign,
		"priority=s"     => \$priority,
		"issue-type=s"   => \$issuetype,
		"hidden-type=s"  => \$type,
		"verbose"        => \$verbose,
		"once"           => \$onetime,
		"debug"          => \$debug,
	) || die pod2usage();

	my $rt = new JazzHands::Tickets::RT(
		service => $service,
		queue   => $queue,
	) || die $JazzHands::Tickets::RT::Errstr;

	$rt->set( 'webroot',     $rtroot )      if ($rtroot);
	$rt->set( 'username',    $rtuser )      if ($rtuser);
	$rt->set( 'password',    $rtpass )      if ($rtpass);
	$rt->set( 'priority',    $priority )    if ($priority);
	$rt->set( 'issuetype',   $issuetype )   if ($issuetype);
	$rt->set( 'forceassign', $forceassign ) if ($forceassign);

	$rt->set( 'verbose', $verbose ) if ($verbose);
	$rt->dryrun($dryrun);

	my $app = new JazzHands::Approvals(
		daemonize => $daemonize,
		service   => $service,
		type      => $type,
		verbose   => $verbose,
		debug     => $debug,
		myname	  => $command,
	) || die $JazzHands::Approvals::Errstr;

	$app->dryrun($dryrun);

	if ($onetime) {
		$app->onetime($rt) || die $app->errstr;
	} else {
		$app->mainloop($rt) || die $app->errstr;
	}

	0;
}
