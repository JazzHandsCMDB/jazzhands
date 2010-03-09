#!/usr/local/bin/perl
# Copyright (c) 2005-2010, Vonage Holdings Corp.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#
# $Id$
#
# This shares code with mitkrblog-insert.pl.  I should totally code share, but
# that's totally work..  and time.

#
# NOTE:  This uses sleep(3) and SIGALRM, which may have issues in some
# operating systems.  Maybe even this one.
#

=head1 NAME

  mitkrb-autoexpire - Temporary account expiration based on kerberos logs

=cut

use warnings;
use strict;
use Authen::Krb5;
use Authen::Krb5::Admin qw(:constants);
use FileHandle;
use POSIX;
use Data::Dumper;
use Sys::Syslog qw(:DEFAULT);
use Getopt::Long;
use Pod::Usage;
use Fcntl;
use DB_File;

use constant EXPIRE_LIFE  => ( 30 * 60 );
use constant PERMITD_FAIL => 6;

#
# Start Kerberos Admin magic
#
Authen::Krb5::init_context();
$ENV{'KRB5_CCNAME'} = "/var/run/k5cc_autoexpire.$$";

my $dbh;

#
# configuration, globals
#
my $pidfn       = "/var/run/mitkrb-autoexpire.pid";
my $dumpfn      = "/prod/mitkrb-autoexpire/run/mitkrb-autoexpire.dump";
my $keytab      = "/etc/krb5.keytab.autotempexpire";
my $admin_princ = "autotempexpire";

# globals related to disk caching.  These are global so signal processing
# and the like can be dealt with.  Kind of lame.
my $diskdbfn = "/prod/mitkrb-autoexpire/db/autoexpire.db";
my %diskhash;
my $diskref;

# global to tweak stuff that gets printed
my $verbose = 0;
my $debug   = 0;

# set to hostname at start, and that's it.
my $instname;

# keeps track of if there is an alarm set
my $alarmg;

# global instance for hitting the kdc
my $nochangekdc;

#
# for decoding dates in logs.
#
my (%months) = (
	'Jan' => 0,
	'Feb' => 1,
	'Mar' => 2,
	'Apr' => 3,
	'May' => 4,
	'Jun' => 5,
	'Jul' => 6,
	'Aug' => 7,
	'Sep' => 8,
	'Oct' => 9,
	'Nov' => 10,
	'Dec' => 11,
);

#
# this is a global so that dealing with unexpires on an alarm work.  There is
# much awesomeness involved here.
#
my $usermap = {};

#
# controls if a HUP was sent, in which case files are closed are reopened.
# the HIP signal sets this and verious loops will abort if its set to
# gracefully reopen files.
#
my $restart_processing = 0;

#
# This is used to discern the current year of the log entry if its not
# in the log entry.  This is kind of icky.
#
my ( $thismon, $thisyear ) = ( localtime(time) )[ 4, 5 ];

# start of code

exit main();

# there is no non-sub code after this.

#############################################################################

=head1 

=head1 OPTIONS

 mitkrb-autoexpire
	[ --debug | --verbose | --nofork ]
	[ --noskip ]
	[ --file /path/to/kdc/log ]
	[ --notail ]
	[ --nopid ]
	[ --nochangekdc ]
	[ --summary ]

=head1 SUMMARY

mitkrb-autoexpire is used to temporary expire kerberos principals when
a password is entered uncorrectly too many times in a row.

It is hardcoded to expire after six consecutive password failures over
thirty minutes (though this could be longer as each failure starts the
thirty minute period over).  If there are no failures for thirty minutes,
the clock starts over.  If a password is expired by this process, after
thirty minutes it will be unexpired.

=head1 DESCRIPTION

The --debug option implies the --verbose, --nopid and --nofork options.
The --verbose option implies --nofork.

The --debug will print extra debugging about various operations of the
code to be printed, including when signals are received and some
strategically placed dumps of internal databases.

The --verbose option causes each principal be printed as it is processed.

The default file that is processed is /prod/krb5/log/kdc.log.  This can
be changed with the --file option.

Normally, mitkrb-autoexpire will continue reading the log after it gets
to the end, similar to how tail -f may work.  The --notail option causes it
to exit when the end of the log si reached.

The --nopid option will cause a pid file to not be written.

The --nochangekdc option will cause principals to not be changed (ie,
expired/unexpired).  The log entries will look like that has happened,
and the kdc will still be consulted to see if principals are expired
when they should be.

The --summary option is used to print an entry as the log file is parsed
every 1000 entries so the invoker can know if it is still working. 

An on disk db file keeps track of all the principals that are supposed to
be expired so that principals will get unexpired correctly across reboots.
Without this, if a restart happened in conjunction with a log rotation,
accounts would stay expired.

=head1 SIGNALS

The HUP option will cause files to be closed and reopened, including the
log and an on disk database.

The USR1 signal causes a dump of the internal tracking database to be
dumped.

=head1 FILES

/var/run/mitkrb-autoexpire.pid - pid file

/prod/mitkrb-autoexpire/run/mitkrb-autoexpire.dump - USR1 dumps the internal
db here.

/prod/mitkrb-autoexpire/db/autoexpire.db - on disk databse of principals
are expired and when they were expired.

/etc/krb5.keytab.autotempexpire  - The keytab file where the autotempexpire
principal is stored.

=cut

sub main {
	my $kdclog = "/prod/krb5/log/kdc.log";

	#
	# Syslog problems
	#
	openlog( "mitkrblog-autoexpire", "pid", 'auth' );

	#
	# options
	#
	my ( $notail, $nofork, $noskip, $nopid, $summary );
	GetOptions(
		'debug'       => \$debug,
		'verbose'     => \$verbose,
		'nofork'      => \$nofork,
		'noskip'      => \$noskip,
		'file=s'      => \$kdclog,
		'notail'      => \$notail,
		'nopid'       => \$nopid,
		'nochangekdc' => \$nochangekdc,
		'summary'     => \$summary,
	) || die pod2usage(1);

	if ($debug) {
		$nopid = $verbose = $nofork = 1;
	} elsif ($verbose) {
		$nopid = $nofork = 1;
	}

	if ( !$nofork ) {
		my $pid = fork();
		if ( $pid < 0 ) {
			die "fork()";
		} elsif ( $pid > 0 ) {
			record_pid($pid) if ( !$nopid );
			exit(0);
		} else {
			setpgrp( 0, 0 );
			setsid;
		}
	} else {
		record_pid($$) if ( !$nopid );
	}

	#
	# logged to indicate which host things came from.
	#
	$instname = `hostname`;
	chomp($instname);
	$instname =~ s/.example.com\s*$//;

	$SIG{'TERM'} = 'signaldeath';
	$SIG{'USR1'} = 'dumpmap';
	$SIG{'HUP'}  = 'processhup';
	$SIG{'ALRM'} = 'dounexpire';

	autoexpire_accounts( $kdclog, $noskip, $notail, $summary );
}

#
# called as an alarm, iterates through looking for people who were set as
# expired for thirty minutes, and unexpires them, then sets an alarm for
# when the next guy is due to be expired.
#
# note that there is the possibility of a tiny window where an entry lingers
# in diskhash because it is untied when the alarm goes off.  This /should/ get
# cleaned up the next time the process is restarted, so I'm not trying to deal
# with it.
#
#
sub dounexpire {
	my ( $oldest, $olddude );
	my $now = time;

	$alarmg = undef;
	foreach my $dude ( keys(%$usermap) ) {
		next if ( !defined( $usermap->{$dude}->{lastattempt} ) );
		next
		  if ( !exists( $usermap->{$dude}->{expired} )
			|| $usermap->{$dude}->{expired} ne 'yes' );
		if ( $usermap->{$dude}->{lastattempt} + EXPIRE_LIFE <= $now ) {
			kdc_action( $usermap, $dude, 'unexpire' );
		} elsif ( !$oldest
			|| $usermap->{$dude}->{lastattempt} < $oldest )
		{
			$oldest  = $usermap->{$dude}->{lastattempt};
			$olddude = $dude;
		}
	}

	# loathe SysV;
	$SIG{'ALRM'} = \&dounexpire;

	if ($oldest) {
		my $alarmit = ( $oldest + EXPIRE_LIFE ) - $now;
		syslog( "debug", "checking in %d seconds for %s (%d)",
			$alarmit, $olddude, $oldest );
		set_alarm($alarmit);
	} else {
		syslog( "debug", "not setting alarm" );
		warn "not setting alarm for unexpires" if ($debug);
	}
}

#
# returns named parameters.  If the first one is a hash reference, assume
# they're all contained in there.
#
sub _options {
	if ( ref $_[0] eq 'HASH' ) {
		return $_[0];
	} else {
		my %ret = @_;
		for my $v ( grep { /^-/ } keys %ret ) {
			$ret{ substr( $v, 1 ) } = $ret{$v};
		}
		\%ret;
	}
}

sub wait_for_more {
	my ( $opt, $offset ) = @_;

	# this means we got a hup.
	return if ($restart_processing);
	my $fh = $opt->{filehandle};

	return undef if ( $opt->{notail} );

	if ( !$offset && $opt->{catchup_proc} ) {
		&{ $opt->{catchup_proc} }( $opt->{map} );
	}

	if ( !defined($offset) ) {
		$offset = ( stat($fh) )[7];
	}
	my $new;
	do {
		sleep(2);
		$new = ( stat($fh) )[7];
	} while ( !$restart_processing && $new == $offset );
	$new;
}

sub cleanup_thirty {
	my ($map) = @_;

	my $oldest;

	my $age = time - EXPIRE_LIFE;
	foreach my $dude ( keys(%$map) ) {

		# if the last attempt was before 30 minutes ago...
		if ( $map->{$dude}->{lastattempt} < $age ) {
			if ( $map->{$dude}->{tally} < PERMITD_FAIL ) {    #[XXX]
				kdc_action( $map, $dude, 'unexpire-silent' );
			} else {

			   # do this because they may not be expired in the kdc,
			   # due to how the script ran.
				kdc_action( $map, $dude, 'unexpire-silent' );
			}
		} else {
			if ( $map->{$dude}->{tally} >= PERMITD_FAIL ) {
				kdc_action( $map, $dude, 'expire' );
				if (      !$oldest
					|| $map->{$dude}->{lastattempt} <
					$oldest )
				{
					$oldest = $map->{$dude}->{lastattempt};
				}
				syslog(
					"info",
"%s should still be expired from last run",
					$dude
				);
			}
		}
	}

	warn "cleanup_thirty dump: ", Dumper($map) if ($debug);

	#
	# set an alarm to unexpire accounts
	#
	if ($oldest) {
		$oldest += EXPIRE_LIFE;
		my $now = time;
		if ( $oldest < $now ) {
			set_alarm(300);
		} else {
			set_alarm( $oldest - $now + 10 );
		}
	}
	syslog( "info", "caught up to history" );
}

#
# removes the pid file when terminated
#
sub signaldeath {
	syslog( "info", "exiting due to signal %s", @_ );
	unlink($pidfn);

	# kill my process group, which should get all of my children.
	$SIG{'TERM'} = 'IGNORE';
	kill( 'TERM', 0 - $$ );
	exit(0);
}

#
# dumps the map out to see what the state of the state is.
#
sub dumpmap {
	syslog( "info", "signal recceived, dumping expire map", @_ );

	if ( my $f = new FileHandle(">$dumpfn") ) {
		$f->print( Dumper($usermap) );
		$f->close;
	} else {
		syslog( "err", "unable to open $dumpfn: %s", $! );
	}

	# loathe sysV
	$SIG{'USR1'} = \&dumpmap;
}

#
# close and reopen file and restart processing
#
sub processhup {
	syslog( "info", "received HUP, rereading logfile", @_ );

	# causes everything to close and reopen.
	$restart_processing = 1;

	# loathe sysV
	$SIG{'HUP'} = \&processhup;
}

#
# saves the pid file when terminated.  Takes the pid as an argument (so it
# can be called from the parent; this may not be wise).
#
sub record_pid {
	my $pid = shift @_;
	my $f = new FileHandle(">$pidfn") || die "could not save pid in $pidfn";
	$f->print("$pid\n");
	$f->close;
}

#
# This is the meat of the process.  It opens a db connection, processes
# the eisting log, then processes
#
sub autoexpire_accounts {
	my ( $kdclog, $noskip, $notail, $summary, $filemap ) = @_;

	# cache accounts expired from last time
	tie( %diskhash, 'DB_File', $diskdbfn, O_RDWR | O_CREAT, 0600 )
	  || die "$diskdbfn: $!";
	read_disk_hash( \%diskhash, $usermap );
	untie(%diskhash);

	#
	# parse the existing file
	#
	my $args = {
		start_whence => undef,
		file         => $kdclog,
		notail       => $notail,
		summary      => $summary,
		map          => $usermap,
		catchup_proc => \&cleanup_thirty,
	};
	do {
		$restart_processing = 0;
		$diskref =
		  tie( %diskhash, 'DB_File', $diskdbfn, O_RDWR | O_CREAT, 0600 )
		  || die "$diskdbfn: $!";
		my ( $lastts, $map ) = process_file($args);
		undef $diskref;
		untie(%diskhash);
	} while ( !$notail );
}

sub process_file {
	my $opt = &_options(@_);
	my ( $inwhence, $file, $notail, $summary ) = (
		$opt->{start_whence}, $opt->{file},
		$opt->{notail},       $opt->{summary}
	);

	my $lastwhence;
	my $map = $opt->{'map'} || die;

	my $first = 0;
	my $skip  = 0;

	if ($inwhence) {
		my @w = gmtime($inwhence);
		my $ts = strftime( "%F %T", @w );
		syslog( "info", "Processing %s from %s", $file, $ts );
	} else {
		syslog( "info", "Processing %s from start", $file );
	}

	my $fh = new FileHandle($file) || die "$file: $!";
	my $tally = 0;
	my $lastline;
	my $off;    # offset into the file we last processed

	my $waitopt = {
		filehandle   => $fh,
		catchup_proc => $opt->{catchup_proc},
		notail       => $notail,
		map          => $map,
	};

	while (    ( my $line = $fh->getline )
		|| ( $off = wait_for_more( $waitopt, $off ) ) )
	{

		# this means we got a HUP.
		last if ($restart_processing);

	       # these essentially mean that we hit the end of the file and were
	       # now into the tailing zone.
		last if ( !$line && $notail );
		last if ( $off   && $notail );

		# catch all so that tail -fs work without warnings
		next if ( !$line );

		#
		# we only care about tgts being issued or preauth failing.
		#
		my ( $time, $dude, $host, $what );
		if ( $line =~
/^((\S+\s){2}\S+)\s.*\s+(\S+):\s+ISSUE.*,\s+([^@]+)@\S+ for krbtgt/
		  )
		{
			( $time, $host, $dude ) = ( $1, $3, $4 );
			$what = "issue";
		} elsif ( $line =~
/^((\S+\s){3}).*\s+(\S+):\s+PREAUTH_FAILED:\s+([^@]+)@\S+/
		  )
		{
			( $time, $host, $dude ) = ( $1, $3, $4 );
			$what = "fail";
		} elsif ( $line =~
/^((\S+\s){3}).*\s+(\S+):\s+CLIENT\s+EXPIRED:\s+([^@]+)@\S+/
		  )
		{
			( $time, $host, $dude ) = ( $1, $3, $4 );
			syslog(
				"info",
'%s@%s attempted to get tickets, despite being expired.',
				$dude,
				$host
			);
			next;
		} else {
			next;
		}

		#
		# some things that its just not worth issuing.  We can probably
		# remove the non-host entries later if they get handled smartly.
		#
		next if ( $dude =~ m,^host/, );
		next if ( $dude =~ m,/.*example.com$, );

		# get a time_t out of the date log.  assume this year.
		# Need to handle the year boundry... [XXX]
		my (@time) = split( /[\s:]/, $time );
		my $logmon = $months{ shift @time };
		push( @time, $logmon );
		@time = (@time)[ 3, 2, 1, 0, 4 ];

		#
		# deal with log entries on a year boundary.
		#
		if ( $logmon == 11 && $thismon == 1 ) {
			push( @time, $thisyear - 1 );
		} elsif ( $logmon == 0 && $thismon == 11 ) {
			push( @time, $thisyear + 1 );
		} else {
			push( @time, $thisyear );
		}
		my $whence = mktime(@time);

		# now we have a time_t...
		$lastwhence = $whence;

		#
		# if we've got a starting timestamp (such as multiple files),
		# skip ahead until we have an entry that matches that.
		#
		#XXX		if(defined($inwhence) && $lastwhence < $inwhence) {
		#XXX			$skip++;
		#XXX			next;
		#XXX		}

	#
	# log how many lines we skipped.
	#
	#XXX		if(!$first) {
	#XXX			$first++;
	#XXX			syslog("info", "skipped %d lines (previously processed)", $skip);
	#XXX		}

		$lastline = $line;
		warn "process $dude on $host\n" if ($verbose);
		$tally++;
		warn "processed $tally entries"
		  if ( $summary && !( $tally % 1000 ) );
		my $args = {
			map      => $map,
			origin   => $host,
			event    => $what,
			username => $dude,
			whence   => $whence
		};

		# $off is set when we are tailing the file, and at that point
		# things are happening in real time.
		$args->{skippurge} = 'yes' if ( !$off );
		process_login($args);

	}
	$fh->close;
	( $lastwhence, $map );
}

#
# Processes an event.  if it's a successful login, make sure no info about
# the user is tracked.
#
# if its a failure and the user is already expired, just note it.
#
# If its the first failure in > thirty minutes, then start the clock again.
#
# At six, mark the account as expired.
#
sub process_login {
	my $opt = &_options(@_);

	my ( $map, $dude, $host, $whence, $what ) = (
		$opt->{map},    $opt->{username}, $opt->{origin},
		$opt->{whence}, $opt->{event}
	);

	#
	# this means that we have some outstanding action and we're
	# reprocessing a file, so nothing should happen.
	#
	if ( exists( $map->{$dude} )
		&& ( $whence < $map->{$dude}->{lastattempt} ) )
	{
		return $map;
	}

	if ( $what eq 'issue' ) {
		if ( exists( $map->{$dude} )
			&& ( $whence > $map->{$dude}->{lastattempt} ) )
		{

		     # maybe do this?  leaving out since expired accounts should
		     # never get tickets.
			my $kdcexp;
			if ( exists( $map->{$dude} ) ) {
				if ( exists( $map->{$dude}->{expired} )
					&& $map->{$dude}->{expired} eq 'yes' )
				{

					$kdcexp =
					  get_expire_time( undef, $dude );
					if ($kdcexp) {
						syslog(
							"err",
"%s should be expired, expired in kdc (%d), but got tickets anyway",
							$dude,
							$kdcexp
						);
					} else {
						syslog(
							"err",
"%s should be expired, but not in kdc and got tickets anyway",
							$dude
						);
					}
				}
			}

		# only stop tracking the person if the account was actually
		# unexprired in the kdc.  If no check took place, assume that
		# it is unexpired in the kdc.  (essentially that means he wasn't
		# in the list, so this is redundant.
			if ( !$kdcexp ) {
				$map->{$dude} = undef;
				delete $map->{$dude};
			}
		}
	} elsif ( $what eq 'fail' ) {

		# cleanup entries older than 30 minutes ago.  It'll get
		# get recreated fresh below.
		if (       exists( $map->{$dude} )
			&& exists( $map->{$dude}->{lastattempt} ) )
		{
			if (
				(
					time -
					$map->{$dude}->{lastattempt} +
					EXPIRE_LIFE
				) < 0
			  )
			{
				if ( $map->{$dude}->{expired} ne 'yes' ) {
					$map->{$dude} = undef;
					delete $map->{$dude};
				}
			}
		}

		$map->{$dude}->{lastattempt} = $whence;
		$map->{$dude}->{tally}++;
		if ( $map->{$dude}->{tally} >= PERMITD_FAIL ) {
			if ( !exists( $opt->{skippurge} )
				|| $opt->{skippurge} ne 'yes' )
			{
				kdc_action( $map, $dude, 'expire' );
			}
		}
	}
	$map;
}

#
# any sort of expire/kdc actions take place here.
#
sub kdc_action {
	my ( $map, $dude, $action ) = @_;

	if ( $action eq 'expire' ) {
		if ( !exists( $map->{$dude}->{expired} )
			|| $map->{$dude}->{expired} ne 'yes' )
		{
			syslog( "info", "expiring %s", $dude );
			$map->{$dude}->{expired} = 'yes';
			$diskhash{$dude} = $map->{$dude}->{lastattempt};
			if ( !$alarmg ) {
				my $wait =
				  time -
				  $map->{$dude}->{lastattempt} +
				  EXPIRE_LIFE;
				syslog( "debug", "kdc_action alarming in %d",
					$wait );
				set_alarm($wait);
			} else {
				syslog( "debug", "already waiting, no alarm" );
			}
			if ( !$nochangekdc ) {
				expire_princ( undef, $dude,
					$map->{$dude}->{lastattempt} );
			}
		}
	} elsif ( $action =~ /unexpire/ ) {
		delete $diskhash{$dude};

		my $nokdc;
		if ( !exists( $map->{$dude}->{expired} )
			|| $map->{$dude}->{expired} ne 'yes' )
		{

		      #
		      # just wipe the dude, we shouldn't need to act on the kdc.
		      #
			$nokdc = 1;
			if ( $action ne 'unexpire-silent' ) {
				warn "$dude is not marked as expired"
				  if ($debug);
			}
		} else {
			syslog( "info", "Unexpiring %s", $dude )
			  if ( $action eq 'unexpire' );
		}

		$map->{$dude} = undef;
		delete $map->{$dude};
		my $exp = get_expire_time( undef, $dude );
		if ($exp) {
			if ($nokdc) {
				syslog(
					"err",
"%s was really expired (%d) but were only asked to clear.",
					$dude,
					$exp
				);
			} elsif ( !$nochangekdc ) {
				expire_princ( undef, $dude, 0 );
			}
		}
	} else {
		syslog( "err", "unknown action $action" );
	}

	$diskref->sync;
}

#
# wrapper around setting the alarm so the global gets set.  Also allows
# for more easy debugging.
#
sub set_alarm {
	my ($whence) = @_;

	$alarmg = $whence;
	warn "setting alarm to $whence" if ($debug);
	alarm($whence);
}

#
# read the disk hash of expired principals into the incore representation
#
sub read_disk_hash {
	my ( $diskhash, $map ) = @_;

	while ( my ( $dude, $lasta ) = each(%$diskhash) ) {

		# larger than the # at issue
		$map->{$dude}->{tally}       = PERMITD_FAIL + 1;
		$map->{$dude}->{lastattempt} = $lasta;
		$map->{$dude}->{expired}     = 'yes';
	}
}

sub admin_connect {
	my $krbadminh =
	  Authen::Krb5::Admin->init_with_skey( $admin_princ, $keytab );
	if ( !$krbadminh ) {
		syslog(
			"err",
"Error establishing Kerberos Admin connection(%s,%s): %s",
			$admin_princ,
			$keytab,
			$Authen::Krb5::Admin::error
		);
		exit(1);
	}
	$krbadminh;
}

sub get_expire_time {
	my ( $krb5, $dude ) = @_;

	$krb5 = admin_connect() unless ($krb5);

	# Authen::Krb5::Admin::Policy
	my $name = Authen::Krb5::parse_name($dude);
	if ( !$name ) {
		syslog( "err", "failed to parse_name($dude)", $krb5->error );
		return;
	}
	my $princ = $krb5->get_principal( $name, KADM5_PRINCIPAL_NORMAL_MASK );
	if ( !$princ ) {
		syslog( "err", "%s: get: Failed to get principal: %s",
			$dude, $krb5->error );
		return;
	}
	$princ->princ_expire_time;
}

sub expire_princ {
	my ( $krb5, $dude, $whence ) = @_;

	$krb5 = admin_connect() unless ($krb5);

	# Authen::Krb5::Admin::Policy
	my $name = Authen::Krb5::parse_name($dude);
	if ( !$name ) {
		syslog( "err", "failed to parse_name($dude)", $krb5->error );
		return;
	}
	my $princ = $krb5->get_principal( $name, KADM5_PRINCIPAL_NORMAL_MASK )
	  || die $krb5->error;
	if ( !$princ ) {
		syslog( "err", "$dude: expire: failed to get principal: %s",
			$dude, krb5->error );
	}

	$princ->princ_expire_time($whence);
	$krb5->modify_principal($princ);
}

DESTROY {
	undef $diskref;
	untie(%diskhash);
}

=head1 AUTHOR
