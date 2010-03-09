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

=head1 NAME

  adloginlog - Script to capture AD logins for otherwise idle accounts

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
use JazzHands::ActiveDirectory;

my $instname = `hostname`;
chomp($instname);
$instname =~ s/.example.com\s*$//;

#
# options? verbosity? [XXX]
#

exit main();

# there is no non-sub code after this.

#############################################################################

=head1 

=head1 OPTIONS

	adloginlog [ --verbose ] [ --debug ] [ login ... ]

=head1 DESCRIPTION

--verbose can be used to print users as they are processed. 

--debug can be used to print information about users as they are procssed.

This command looks for accounts that haven't been touched in 10 days and
checks for logins to the ActiveDirectory domain.  If it finds any that are
newer than the last login recorded in the database, it will insert a record
for that user.  This allows records that look for idle accounts to be aware of
idle logins.

Logins can be specified on the command line to limit the results to those
logins.  This is primarily meant for debugging.

=cut

sub main {
	my ( $verbose, $debug );

	GetOptions(
		'verbose' => \$verbose,
		'debug'   => \$debug,
	) || die pod2usage();

	$verbose = 1 if ( $debug && !$verbose );

	#
	# Open Conection to JazzHands
	#
	my $dbh =
	  Jazzhands::DBI->connect( 'jazzhands_capturelogins',
		{ AutoCommit => 0 } )
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

	my $ldap = JazzHands::ActiveDirectory->new()
	  || die "could not connect to AD server";

	#
	# look for accounts that either have no login time, or haven't logged
	# in in 10 days to check.  Active accounts that have logged in more
	# recently already have logins recorded.
	#
	my $sth = $dbh->prepare(
		qq{
		select	su.system_user_id,
			su.login,
			time_util.epoch(al.system_user_auth_ts)
				AS system_user_auth_ts
		 from	system_user su
			left join mv_system_user_last_auth al
				on al.system_user_id = su.system_user_id
		where	(al.system_user_auth_ts is null or
			al.system_user_auth_ts <=  (sysdate - :1))
		order by su.login
	}
	) || die $dbh->errstr;

	$sth->execute(10) || die $sth->errstr;
	while ( my ( $id, $login, $whence ) = $sth->fetchrow_array ) {
		last if ( !$id );
		next if ( $#ARGV >= 0 && !grep( $_ eq $login, @ARGV ) );

		# JazzHands::ActiveDirectory probably should do something
		# else for the base.  May not need to specify? [XXX]
		my $msg = $ldap->search(
			base   => "dc=example,dc=com",
			filter => "(SAMAccountName=$login)",
			attr   => ['lastLogin'],
		);
		if ( $msg->code ) {
			die "$login: ", $msg->error;
			next;
		}
		print "considering $login\n" if ($verbose);

		# didn't look like I could just extract lastLogon;
		if ( my $e = $msg->entry(0) ) {
			foreach my $a ( $e->attributes ) {
				if ( $a eq 'lastLogon' ) {
					my $v = $e->get_value($a);

			  # only set a last login if someone actually logged in.
					if ($v) {

		       # this is the the whack microsoft  date format.  awesome.
						my $since_epoch = int(
							(
								int(
									$v -
									  116444736000000000
								)
							) / 10000000
						);

			   # only set if its newer than the last record we have.
						if ( 1 || $debug ) {
							if ($whence) {
								print
"\tDB Last Date: $whence (",
								  pretty_date(
									$whence
								  ), ")\n";
							} else {
								print
"\tdb is not set\n";
							}
							print
"\tAD Last Date: $since_epoch (",
							  pretty_date(
								$since_epoch),
							  ") (MS: $v)\n";
						}

						if (      !$whence
							|| $since_epoch >
							$whence )
						{

				# [XXX]  check to see if this matches the most
				# recent record, if so, do not insert it. [XXX]
				# I think this wants to go into the set_ad_login
				# script, which can be generic and pass an
				# instance and type.
							set_ad_login( $dbh, $id,
								$since_epoch );
						}
					}
					last;
				}
			}
		}
	}

	$ldap->unbind;
	$dbh->commit;
	$dbh->disconnect;
}

sub set_ad_login {
	my ( $dbh, $id, $whence ) = @_;

	my $sth = $dbh->prepare(
		qq{
		insert into system_user_auth_log (
			system_user_id,
			SYSTEM_USER_AUTH_TS,
			WAS_AUTH_SUCCESS,
			AUTH_RESOURCE,
			AUTH_RESOURCE_INSTANCE,
			AUTH_ORIGIN
		) values (
			:1,
			:2,
			'Y',
			'ad',
			:3,
			'contrived'
		)
	}
	);

	my $ts = pretty_date($whence);
	$sth->execute( $id, $ts, $instname ) || die $sth->errstr;
}

sub pretty_date {
	my ($whence) = @_;

	my @w = gmtime($whence);
	strftime( "%F %T", @w );
}

sub find_most_recent {
	my ( $dbh, $resource, $inst ) = @_;

	my $sth = $dbh->prepare_cached(
		qq{
		select  time_util.epoch(max(SYSTEM_USER_AUTH_TS))
		  from  system_user_auth_log
		  where auth_resource = :1
		   and  auth_resource_instance = :2
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

=head1 AUTHOR

