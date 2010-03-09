#!/usr/local/bin/perl -w
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
# Notifies people of imminent password expiration
#

BEGIN {
	my $dir = $0;
	if ( $dir =~ m,/, ) {
		$dir =~ s!^(.+)/[^/]+$!$1!;
	} else {
		$dir = ".";
	}

	#
	# Copy all of the entries in @INC, and prepend the fakeroot install
	# directory.
	#
	my @SAVEINC = @INC;
	foreach my $incentry (@SAVEINC) {
		unshift( @INC, "$dir/../../fakeroot.lib/$incentry" );
	}
	unshift( @INC, "$dir/../lib/lib" );
}

use strict;
use DBI;
use Getopt::Std;
use JazzHands::Management;
use POSIX;

# Lengths are in days

# Length of time until password expires
my $expirelength = 90;
my $mail         = "/usr/sbin/sendmail -t";
my $log          = "/var/log/pwnotify";
my $domain       = "EXAMPLE.COM";
my $contact      = "nobody\@$domain";
my $weblocation  = "https://WWW.EXAMPLE.COM/change-passwd.pl";

# Number of days to send e-mail warnings before the expire date
my $warnlength = 7;

my %opt;
getopts( 'nw:f:d', \%opt );

if ( $opt{f} ) {
	$log = $opt{f};
}

if ( $opt{d} ) {
	$log = "-";
}

if ( $opt{w} ) {
	if ( $opt{w} <= 0 ) {
		print "Argument to -w must be a postive number.\n";
		exit 1;
	}
	$warnlength = $opt{w};
}

sub dbdie {
	if (DBI::errstr) {
		print LOG "DB Problem: "
		  . join( " ", @_ ) . ": "
		  . DBI::errstr . "\n";
		exit 1;
	} else {
		print LOG join( " ", @_ ) . "\n";
		exit 1;
	}
}

if ( !open LOG, ">$log" ) {
	print STDERR "Error opening log $log: $!\n";
	exit 1;
}

print LOG "Password expiration notification notification starting "
  . scalar(localtime) . "\n";

my $dbh = OpenJHDBConnection() || die $DBI::errstr;
$dbh->{PrintError} = 1;

my $q = qq{
   SELECT
		Login, Time_Util.Epoch(Change_Time), Time_Util.Epoch(Expire_Time),
		Change_Time + $expirelength - SYSDATE, SYSDATE - Change_Time
   FROM
		System_User JOIN System_Password USING (System_User_ID)
   WHERE
		System_User_Status = 'enabled' AND
		System_User_Type IN ('employee', 'contractor') AND
		((Crypt IS NOT NULL AND Crypt <> '*') OR
		 (MD5Hash IS NOT NULL AND MD5Hash <> '*') OR
		 (SHA1 IS NOT NULL AND SHA1 <> '*')) AND
		((Expire_Time > SYSDATE AND Expire_Time < SYSDATE + $warnlength) OR
		(Change_Time + $expirelength > SYSDATE AND 
		 Change_Time + $expirelength < SYSDATE + $warnlength AND
		 Expire_Time IS NULL))
};

my $sth = $dbh->prepare($q) || dbdie($q);
$sth->execute || dbdie($q);

while ( my ( $login, $changetime, $expiretime, $timeleft, $lastchanged ) =
	$sth->fetchrow_array )
{

	# round to the nearest day

	my $expirestr = strftime(
		"%A, %B %e at %H:%M UTC",
		gmtime(
			$expiretime
			  || ( $changetime + ( $expirelength * 86400 ) )
		)
	);
	my $changestr;
	if ($changetime) {
		$changestr = strftime(
"Your password was last changed on %A, %B %e at %H:%M UTC.",
			localtime($changetime)
		);
	} else {
		$changestr = "Your password has never been changed.";
	}

	if ( !$opt{n} ) {
		open( I, "|$mail" );
		printf I <<EOF, $login, $timeleft, $expirestr, $changestr;
From: Password Expiration Notification <donotreply\@$domain>
To: %s\@$domain
Subject: Your Kerberos/UNIX password will expire in less than %.f days

Your Kerberos and UNIX login password must be changed, as it will expire
on %s and your account will be locked.

You will need to access the web page at:

$weblocation

to change your password.  You will need to know your current Kerberos/UNIX
password in order to change it.

%s

If you have any questions or need help, please contact $contact.

EOF
		close I;
	}

	printf LOG "%s was notified of %.f days remaining\n", $login, $timeleft;
}

close LOG;
