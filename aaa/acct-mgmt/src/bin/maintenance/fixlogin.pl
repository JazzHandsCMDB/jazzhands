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
	my $incentry;
	unshift( @INC, "$dir/../lib/lib" );
	foreach $incentry (@SAVEINC) {
		unshift( @INC, "$dir/../../fakeroot.lib/$incentry" );
	}
}

use strict;
use JazzHands::Management qw(:DEFAULT);
use Getopt::Std;

my (%opt);
getopts( 'v', \%opt );

my $verbose = 0;
$verbose = 1 if ( $opt{v} );

#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
#
# die because of a problem with the DBI module.  Print the error message
# from the oracle module.
#
my $dbh = OpenJHDBConnection || die $DBI::errstr;
$dbh->{AutoCommit} = 0;
my ( $q, $sth );

sub dbdie {
	$dbh->rollback;
	if (DBI::errstr) {
		die "DB Problem: "
		  . join( " ", @_ ) . ": "
		  . DBI::errstr . "\n";
	} else {
		die join( " ", @_ ) . "\n";
	}
}

$q = qq{
	UPDATE
		User_Unix_Info
	SET
		Default_Home = ?
	WHERE 
		System_User_ID = ?
};
$sth = $dbh->prepare($q) || dbdie DBI::errstr;

while (<>) {

	# Delete preceding and trailing spaces
	s/^ *//g;
	s/\t */\t/g;
	s/ *\t/\t/g;
	s/ $//g;
	my (
		$login,            $last_name,         $first_name,
		$dn,               $middle_name,       $title,
		$suffix,           $nickname,          $hire_date,
		$job_title,        $company,           $company_code,
		$office_address,   $office_city,       $office_state,
		$office_country,   $postal_code,       $email,
		$office_telephone, $mobile,            $fax,
		$department_name,  $department_number, $supervisor,
		$move_status,      $pod,               $floor,
		$area,             $seat,              $location,
		$ha,               $badge_type,        $badge_number,
		$badge_picture
	) = split(/\t/);

	$login = lc($login);
	if ( !$login ) {
		print "No login for '$first_name $last_name'.  Skipping\n";
		next;
	}

	my $userid = findUserIdFromlogin( $dbh, $login );

	if ($userid) {
		$sth->execute( "/home/$login", $userid ) || dbdie DBI::errstr;
	}
}
$dbh->commit;

