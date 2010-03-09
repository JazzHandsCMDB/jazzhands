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
# This shares code with autoexpire.pl.  I should totally code share, but
# that's totally work.

=head1 NAME

  mitkrblog-insert - Insert interesting KDC events into JazzHands

=cut

use warnings;
use strict;
use Jazzhands::DBI;
use FileHandle;
use POSIX;
use Data::Dumper;
use Carp;
use Sys::Syslog qw(:DEFAULT);
use Getopt::Long;
use Pod::Usage;

#
# configuration, globals
#
my $pidfn   = "/var/run/mitkrblog-insert.pid";
my $verbose = 0;

# for signal and other purposes, otherwise it should not be manipulated as
# a global
my $dbh;

# set to hostname at start, and that's it.
my $instname;

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
# This is used to discern the current year of the log entry if its not
# in the log entry.  This is kind of icky.
#
my ( $thismon, $thisyear ) = ( localtime(time) )[ 4, 5 ];

exit main();

# there is no non-sub code after this.

#############################################################################

=head1 

=head1 OPTIONS

 mitkrblog-insert [ --nopid ] [ --verbose ] [ --nofork ] [ --noskip ] 
	[ --notail ] [ --summary ] [ --file=name ] 

=head1 SUMMARY

This utility will read the log file from an MIT kerberos kdc's logs and
insert preauth failures and the issue of krbtgt tickets into the
system_user_auth_log table in JazzHands.

=head1 DESCRIPTION

The utility normally looks at the most recent entry in the database for
this host, and will skip entries that are earlier than that entry.  The
--noskip option will prevent that from happening.

It should normally be restarted when
a kdc is restarted to get the proper file.  It will default to a filename
of /prod/krb5/log/kdc.log, though this can be overwridden with the --file
option.

The --nofork option will cause the utility to not fork in the background, but
stay in the foreground.  The --verbose option will print entries procsesed
to stderr, and implies --nofork.

The --nopid option tells the software to not capture a pid in /var/run.

The --summary option will print an indication of progress every 1000
inserts.

Normally, mitkrblog-insert will read from the file until it is killed
(similar to tail -f), but when the --notail option is specified, it
will stop reading when an end of file is reached.  This is normally used
to process back data and the like.

=cut

sub main {
	my $kdclog = "/prod/krb5/log/kdc.log";
	my ( $notail, $nofork, $noskip, $nopid, $summary );
	GetOptions(
		'verbose' => \$verbose,
		'nofork'  => \$nofork,
		'noskip'  => \$noskip,
		'file=s'  => \$kdclog,
		'notail'  => \$notail,
		'nopid'   => \$nopid,
		'summary' => \$summary,
	) || die pod2usage(1);

	$nofork = 1 if ($verbose);

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
	insert_history( $kdclog, $noskip, $notail, $summary );
}

DESTROY {
	if ($dbh) {
		$dbh->rollback;
		$dbh->disconnect;
		$dbh = undef;
	}
}

#
# removes the pid file when terminated
#
sub signaldeath {
	syslog( "info", "exiting due to signal %s", @_ );
	unlink($pidfn);
	if ($dbh) {
		$dbh->rollback;
		$dbh->disconnect;
		$dbh = undef;
	}

	# kill my process group, which should get all of my children.
	$SIG{'TERM'} = 'IGNORE';
	kill( 'TERM', 0 - $$ );
	exit(0);
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
sub insert_history {
	my ( $kdclog, $noskip, $notail, $summary ) = @_;

	#
	# Open Conection to JazzHands
	#
	$dbh = Jazzhands::DBI->connect( 'setkrbhistory', { AutoCommit => 0 } )
	  || confess;

	{
		my $dude = ( getpwuid($<) )[0] || 'unknown';
		my $q = qq{ 
			begin
				dbms_session.set_identifier ('$dude');
			end;
		};
		if ( my $sth = $dbh->prepare($q) ) {
			$sth->execute;
		}
	}
	$dbh->do(
"alter session set NLS_TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS.FF'"
	) || die $dbh->errstr;

	#
	# Syslog problems
	#
	openlog( "mitkrblog-insert", "pid", 'auth' );

	#
	# figure out our most recent entry.  This is kind of gross.
	#
	my $lastts;

	#
	# noskip means to not to skip over any.
	#
	if ( !$noskip ) {
		$lastts = find_most_recent( $dbh, 'kerberos', $instname );
	}
	if ( defined($lastts) ) {
		my @w = gmtime($lastts);
		my $ts = strftime( "%F %T", @w );
		syslog( "info", "Starting from last entry %s", $ts );
	} else {
		syslog( "info", "No previous syslog entries" );
	}

	#
	# There is a potential for dups here because of the way the timestamp
	# is used, but it beats missing data in case there are two in the
	# same second.  Its also unclear if 3000 is a good number.  It just
	# needs to be far enough to pick up items between the first and the
	# second.
	#
	$lastts = process_file( $dbh, $lastts, $kdclog, $notail, $summary );
}

sub process_file {
	my ( $dbh, $inwhence, $file, $notail, $summary ) = @_;
	my $lastwhence;
	my $uidmap = {};

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
	my $off;
	while (    ( my $line = $fh->getline )
		|| ( $off = wait_for_more( $fh, $off, $notail ) ) )
	{

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
		if ( defined($inwhence) && $lastwhence < $inwhence ) {
			$skip++;
			next;
		}

		#
		# log how many lines we skipped.
		#
		if ( !$first ) {
			$first++;
			syslog( "info",
				"skipped %d lines (previously processed)",
				$skip );
		}

		$lastline = $line;
		warn "process $dude on $host\n" if ($verbose);
		$tally++;
		warn "processed ", $tally, " entries"
		  if ( $summary && !$tally % 1000 );
		process_login( $dbh, $uidmap, $dude, $host, $whence, $what );
		$dbh->commit;

	}
	$lastwhence;
}

sub process_login {
	my ( $dbh, $uidmap, $dude, $host, $whence, $what ) = @_;

	if ( !exists( $uidmap->{$dude} ) ) {
		$uidmap->{$dude} = find_uid( $dbh, $dude );
	}

	if ( !defined( $uidmap->{$dude} ) ) {
		syslog( "err", "skipping unknown principal %s", $dude );
		return;
	}

	my $sth = $dbh->prepare_cached(
		qq{
		insert into system_user_auth_log (
			system_user_id,
			system_user_auth_ts,
			was_auth_success,
			auth_resource,
			auth_resource_instance,
			auth_origin
		) values (
			:1,
			:2,
			:3,
			:4,
			:5,
			:6
		)
	}
	) || die $dbh->errstr;

	my @w = gmtime($whence);
	my $ts = strftime( "%F %T", @w );

	$sth->execute( $uidmap->{$dude}, $ts, ( $what eq 'issue' ) ? 'Y' : 'N',
		'kerberos', $instname, $host )
	  || die $sth->errstr;
}

sub find_uid {
	my ( $dbh, $dude ) = @_;

	my $sth = $dbh->prepare_cached(
		qq{
		select	system_user_id
		  from	system_user
		 where	login = :1
	}
	) || die $dbh->errstr;
	$sth->execute($dude) || die $sth->errstr;
	my ($id) = $sth->fetchrow_array;
	$sth->finish;
	$id;
}

sub find_most_recent {
	my ( $dbh, $resource, $inst ) = @_;

	my $sth = $dbh->prepare_cached(
		qq{
		select	time_util.epoch(max(SYSTEM_USER_AUTH_TS))
		  from	system_user_auth_log 
		  where	auth_resource = :1 
		   and 	auth_resource_instance = :2
	}
	) || die $dbh->errstr;

	#
	# this is kind of gross.
	#
	$sth->execute( $resource, $inst ) || die $sth->errstr;
	my ($whence) = $sth->fetchrow_array;
	$sth->finish;
	$whence;
}

sub wait_for_more {
	my ( $fh, $offset, $notail ) = @_;

	return undef if ($notail);

	if ( !defined($offset) ) {
		$offset = ( stat($fh) )[7];
	}
	my $new;
	do {
		sleep(2);
		$new = ( stat($fh) )[7];
	} while ( $new == $offset );
	$new;
}

=head1 AUTHOR
