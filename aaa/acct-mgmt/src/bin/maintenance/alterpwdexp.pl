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
# generate passwd files, group files, whatever else may be necessary...
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
		unshift( @INC, "$dir/../../../fakeroot.lib/$incentry" );
	}
	unshift( @INC, "$dir/../../lib/lib" );
}

use strict;
use DBI;
use Getopt::Std;
use JazzHands::Management;
use Time::Local;
use POSIX;

my %opt;
getopts( 'n', \%opt );

my $jh;
if ( !( $jh = JazzHands::Management->new( application => 'acctmgt' ) ) ) {
	print STDERR "Unable to open connection to JazzHands\n";
	exit -1;
}

my $dbh = $jh->DBHandle;
$dbh->{PrintError} = 1;

my $q = qq{
	SELECT
		System_User_Id
	FROM
		System_User JOIN System_Password USING (System_User_Id)
	WHERE
		System_User_Status = 'enabled' AND
		Change_Time = TO_DATE('2007-10-11 21:19:18', 'YYYY-MM-DD HH24:MI:SS')
	ORDER BY
		System_User_ID
};
my $sth = $dbh->prepare($q) || dbdie($q);
$sth->execute || dbdie($q);

my @sysuids;
while ( my $sysuid = ( $sth->fetchrow_array )[0] ) {
	push @sysuids, $sysuid;
}
$sth->finish;

$q = qq {
	UPDATE
		System_Password
	SET
		Change_Time = TO_DATE(:changetime, 'YYYY-MM-DD HH24:MI:SS')
	WHERE
		System_User_ID = :sysuid
};
$sth = $dbh->prepare($q) || dbdie($q);

# Start from Jan 3
my $changetime = timegm( 0, 0, 0, 3, 0, 108 );

# Go back 90 days
$changetime -= 86400 * 90;
my $interval = 2592000 / $#sysuids;

#print scalar(localtime($starttime)), "\n";
#print $interval, "\n";
#print scalar(localtime($starttime + $interval)), "\n";
#print strftime("%Y-%m-%d %H:%M:%S", gmtime($changetime));
foreach my $sysuid (@sysuids) {
	$sth->bind_param( ":sysuid", $sysuid );
	$sth->bind_param( ":changetime",
		strftime( "%Y-%m-%d %H:%M:%S", gmtime($changetime) ) );
	$sth->execute() || dbdie($q);
	$changetime += $interval;
}
$dbh->commit;
$dbh->disconnect;
