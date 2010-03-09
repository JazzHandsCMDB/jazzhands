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

my $dbh = OpenJHDBConnection || die $DBI::errstr;
$dbh->{AutoCommit} = 0;
my ( $q, $sth );

while (<>) {

	# Delete preceding and trailing spaces
	s/^ *//g;
	s/\t */\t/g;
	s/ *\t/\t/g;
	s/ $//g;
	my ($login) = $_;
	chomp($login);

	$login = lc($login);
	next if ( !$login );

	my $userid = findUserIdFromlogin( $dbh, $login );

	if ($userid) {
		if ( BalefireUser( $dbh, $userid ) ) {
			print "User '$login' eradicated\n";
		} else {
			print "Unable to delete user '$login'\n";
		}
	} else {
		print "User '$login' does not exist.\n";
	}
}
$dbh->commit;

