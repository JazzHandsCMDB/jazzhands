#!/usr/bin/env perl -w
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
	unshift( @INC, "$dir/../perl/blib/lib" );
}

use strict;
use HOTPants;
use Getopt::Std;

my $dbpath = "/prod/hotpants/db";

my (%opt);
getopts( 'vnhd:u:t:', \%opt );

if ( $opt{h} ) {
	usage();
}

if ( $opt{d} ) {
	$dbpath = $opt{d};
}

my $login;
my $tokenid;

if ( $opt{t} ) {
	$tokenid = $opt{t};
}

if ( $opt{u} ) {
	if ($tokenid) {
		usage();
	}
	$login = $opt{u};
}

if ( !$login && !$tokenid ) {
	usage();
}

my $err;
my $hp = new HOTPants( path => $dbpath );
if ( !$hp ) {
	printf STDERR "Unable to get HOTPants handle\n";
	exit 1;
}

if ( $err = $hp->opendb ) {
	printf STDERR $err . "\n";
	exit 1;
}

if ($tokenid) {
	my ( $ret, $token );
	$ret = $hp->fetch_token( $tokenid, \$token );
	if ( $ret && $ret !~ /^DB_NOTFOUND/ ) {
		print STDERR "Error fetching token from HP database: $ret\n";
		exit 1;
	}
	HOTPants::dump_token( token => $token );
}

if ($login) {
	my ( $ret, $user );
	$ret = $hp->fetch_user( $login, \$user );
	if ( $ret && $ret !~ /^DB_NOTFOUND/ ) {
		print STDERR "Error fetching user from HP database: $ret\n";
		exit 1;
	}
	HOTPants::dump_user( user => $user );
}

END {
	$hp->closedb if $hp;
}

sub usage {
	getopts( 'vnhd:u:t:', \%opt );
	print STDERR "Usage:\n";
	print STDERR "    $0 -h\n";
	print STDERR "    $0 [-d <directory>] -u user\n";
	print STDERR "    $0 [-d <directory>] -t tokenid\n";
	exit 0;
}
