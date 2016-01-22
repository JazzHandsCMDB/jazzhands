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
use JazzHands::Management;

my $err;

my $dbh = OpenJHDBConnection("tokenmgmt") || die $DBI::errstr;
$dbh->{AutoCommit} = 0;

my $token;
my $ret;

my $tokenlist = JazzHands::Management::Token::GetTokenList($dbh);
if ( !defined($tokenlist) ) {
	print STDERR $JazzHands::Management::Errmsg . "\n";
	exit 1;
}

foreach my $tok (@$tokenlist) {
	if (
		!defined(
			$token = JazzHands::Management::Token::GetToken(
				$dbh, token_id => $tok,
			)
		)
	  )
	{
		print STDERR $JazzHands::Management::Errmsg . "\n";
		exit 1;
	}
	printf
	  "TokenID: %s\n\tType: %s\n\tStatus: %s\n\tSerial: %s\n\tSequence: %s\n\tPIN: %s\n\n",
	  $token->{token_id}, $token->{type}, $token->{status},
	  $token->{serial}, $token->{sequence}, $token->{pin} || '';
}

#if (JazzHands::Management::Token::RevokeTokenFromUser($dbh,
#		user_id => 21,
#		token_id => 1)) {
#	printf "Error unassigning token: %s\n", $JazzHands::Management::Errmsg;
#}
#
#if (JazzHands::Management::Token::AssignTokenToUser($dbh,
#		user_id => 21,
#		token_id => 1)) {
#	printf "Error assigning token: %s\n", $JazzHands::Management::Errmsg;
#}

END {
	$dbh->disconnect if $dbh;
}
