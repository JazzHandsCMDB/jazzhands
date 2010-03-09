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
# This is a quick hack and really needs to be rewritten.

=head1 NAME

  jazzhands_expire - Automatically expire apparently idle accounts

=cut

use warnings;
use strict;
use Data::Dumper;
use Jazzhands::DBI;
use FileHandle;
use Getopt::Long;
use Pod::Usage;

#
# globals;  these should probably come out of the DB...
#
my $mailfrom = 'JazzHands-Reports@example.com';
my $mailto   = 'JazzHands-Idle-Terms@example.com';

# globals that shouldn't.
my $dbauth_user = "jazzhands_autoexpire";

my $debug;

exit main();

################################### subs only ###############################

sub process_accounts_for_expiration($) {
	my ($dbh) = @_;

	my $sth = $dbh->prepare_cached(
		qq{
			select  su.system_user_id,
				su.login,
				su.first_name,
				su.last_name,
				xref.hris_id,
				trunc(su.hire_date, 'DDD') as hire_date,
				d.name as dept_name,
				c.company_name,
				su.system_user_type,
				cast(al.system_user_auth_ts as date) as system_user_auth_ts,
				time_util.epoch(al.system_user_auth_ts) as last_auth_epoch
			 from   system_user su
				inner join val_system_user_type typ
					on typ.system_user_type = su.system_user_type
				left join system_user_xref xref
					on xref.system_user_id = su.system_user_id
				left join mv_system_user_last_auth al
					on al.system_user_id = su.system_user_id
				left join dept_member dm
					on dm.system_user_id = su.system_user_id
				left join dept d
					on d.dept_id = dm.dept_id
						and dm.reporting_type = 'direct'
				left join company c
					on su.company_id = c.company_id
				where su.system_user_status = 'enabled'
				and su.hire_date <= sysdate - 90
				and su.system_user_type != 'badge'
				and (
						al.system_user_auth_ts <= (sysdate - 90)
					or
						al.system_user_auth_ts is null
					)
				and     typ.is_person = 'Y'
				order by decode(al.system_user_auth_ts, null, 1, 0),
					su.system_user_type, su.login
	}
	) || die $dbh->errstr;

	# and		al.system_user_auth_ts is not null

	$sth->execute || die $sth->errstr;

	my ($actions) = {};
	$actions->{never} = {};
	$actions->{used}  = {};

	while ( my $hr = $sth->fetchrow_hashref ) {
		my $usage;
		if ( !$hr->{SYSTEM_USER_AUTH_TS} ) {
			$usage = 'never';
		} else {
			$usage = 'used';
		}

		if ( $hr->{HRIS_ID} ) {

			# need to forcedisabled
			push( @{ $actions->{$usage}->{forcedisabled} }, $hr );
		} else {

			# need to disabled
			push( @{ $actions->{$usage}->{disabled} }, $hr );
		}
	}
	$actions;
}

sub process_users($$$$) {
	my ( $dbh, $dontdoit, $records, $action ) = @_;

	my $sth = $dbh->prepare_cached(
		qq{
		update	system_user
		  set	system_user_status = :2
		 where	system_user_id = :1
	}
	);

	my $rv = "";
	foreach my $hr ( @{$records} ) {
		if ( !$dontdoit ) {
			$sth->execute( $hr->{SYSTEM_USER_ID}, $action )
			  || die $sth->errstr;
		}

		my ( $company, $dept, $lastlogin ) = ( "", "", "" );
		$company = " from " . $hr->{COMPANY_NAME}
		  if ( $hr->{COMPANY_NAME} );
		$dept = " in dept " . $hr->{DEPT_NAME} if ( $hr->{DEPT_NAME} );
		$lastlogin = " with last login " . $hr->{SYSTEM_USER_AUTH_TS}
		  if ( $hr->{SYSTEM_USER_AUTH_TS} );

		$rv .= join( "",
			$hr->{LOGIN},            " (",
			$hr->{FIRST_NAME},       " ",
			$hr->{LAST_NAME},        ") - ",
			$hr->{SYSTEM_USER_TYPE}, $company,
			$dept,                   $lastlogin,
			"\n" );
	}
	$rv;
}

=head1

=head1 OPTIONS

  jazzhands_expire [ --dry-run | -n ] [ --no-unused ] [ --dbauth appname ]
	[ --mailto mailto ]

=head1 SUMMARY

jazzhands_expire expires accounts that have not been used in 90 days and
email a report of which accounts were disabled.

=head1 DESCRIPTION

jazzhands_expire looks at all non-badge-only users in JazzHands and examines
their last login as stored in JazzHands.  If the account has not been used
in 90 days, or the account has been around for 90 days and never used,
the account will be disabled.

If an account is tied to HRIS, it will be 'forcedisabled', which means that
it will not be reenabled by the HRIS feed.

The --dry-run (or -n) option will prevent any changes from being made
to the user and add a message to the email report indicatingas much.

The --no-unused option will cause the script to exclude accounts that
have never been used.  This is primarily to be used before major
applications have their login history added to the db (such as CCA and RT).

The --dbauth option overrides the database application user used to login,
which defaults to jazzhands_autoexpire.

The --mailto option is used to change the default destination of the report,
which defaults to JazzHands-Idle-Terms@example.com.

=head1 RISKS

As this was written, applications were frantically being changed to
pass login information back to JazzHands.  It is not anticipated that the
most important applications will be logging to the database by mid-November
2009.

If a user is not marked as a "badge only" account, but they really are,
then they will be disabled, including their physical security badges.
This could be considered a bad thing.

=cut

sub main {
	my $dryrun;
	my $nounused;

	GetOptions(
		'debug'     => \$debug,
		'dbauth=s'  => \$dbauth_user,
		'dry-run|n' => \$dryrun,
		'mailto=s'  => \$mailto,
		'no-unused' => \$nounused,
	) || die pod2usage(1);

	my $dontdoit = !$dryrun;

	my $dbh = Jazzhands::DBI->connect( $dbauth_user, { AutoCommit => 0 } )
	  || die;
	{
		my $dude = ( getpwuid($<) )[0] || 'unknown';
		$dbh->do(
			qq{
			begin
				dbms_session.set_identifier ('$dude');
			end;
		}
		) || die $dbh->errstr;
	}

	my $actions = process_accounts_for_expiration($dbh);

	my $msg = "";
	if ($dontdoit) {
		$msg .=
"The actions described in this email are not actually happening.  ";
		$msg .=
"This email is advisory and describes what would happen when the";
		$msg .= "expiration system runs.\n\n";
	}

	my $tally = 0;

	$msg .=
"This email describes actions taken to disable users in JazzHands.  Users have this action when the appear idle more than 90 days.  This could mean that the accounts are no longer in use or could also mean that the way that they are used is not captured in JazzHands.  CCA and RT accounts would not be included in this list before November 11, 2009.\n\n";

	my $dismsg =
	  process_users( $dbh, $dontdoit, $actions->{used}->{forcedisabled},
		'forcedisable' );
	$tally++ if ( $dismsg && length($dismsg) );
	if ($msg) {
		$msg .=
"The following users are tied to the HRIS system, thus are being ";
		$msg .=
"forcedisabled in JazzHands.  HRIS should be cleaned up to properly terminate them:\n\n";
		$msg .= $dismsg;
		$msg .= "\n\n";
	}

	$dismsg =
	  process_users( $dbh, $dontdoit, $actions->{used}->{disabled},
		'disabled' );
	$tally++ if ( $dismsg && length($dismsg) );
	if ($msg) {
		$msg .=
"The following users are not tied to the HRIS system, thus are being ";
		$msg .= "disabled in JazzHands:\n\n";
		$msg .= $dismsg;
		$msg .= "\n\n";
	}

	if ( !$nounused ) {
		$dismsg =
		  process_users( $dbh, $dontdoit,
			$actions->{never}->{forcedisabled},
			'forcedisable' );
		$tally++ if ( $dismsg && length($dismsg) );
		if ($msg) {
			$msg .=
"The following apparently unused accounts are tied to the HRIS system, ";
			$msg .=
"forcedisabled in JazzHands.  HRIS should be cleaned up to properly terminate them:\n\n";
			$msg .= $dismsg;
			$msg .= "\n\n";
		}

		$dismsg =
		  process_users( $dbh, $dontdoit, $actions->{never}->{disabled},
			'disabled' );
		$tally++ if ( $dismsg && length($dismsg) );
		if ($msg) {
			$msg .=
"The following apparently unused accounts are not tied to the HRIS system, ";
			$msg .= "thus are being disabled in JazzHands:\n\n";
			$msg .= $dismsg;
			$msg .= "\n\n";
		}
	}

	if ($tally) {
		warn "sending email to $mailto" if ($debug);
		my $fh =
		  new FileHandle("| /usr/sbin/sendmail -f$mailfrom $mailto ")
		  || die "sendmail: $!";
		$fh->print("To: $mailto\n");
		$fh->print("From: $mailfrom\n");
		$fh->print("Subject: Disabled Idle Accounts\n");
		$fh->print("\n");
		$fh->print($msg);
		$fh->close;
	} else {
		warn "no email to send" if ($debug);
	}

	$dbh->commit;
	$dbh->disconnect;

}

=head1 AUTHOR
