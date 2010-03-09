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
use CGI qw(:standard);
use JazzHands::Management qw(:DEFAULT);
use Sys::Syslog qw(:standard :macros);
use Time::HiRes qw(tv_interval gettimeofday);
use DBD::Oracle ':ora_types';
use Data::Dumper;
use JazzHands::AuthToken;

sub error {
	syslog( LOG_ERR, $_[0] );

	#	print STDERR $_[0];
}

openlog( "questionlist", "pid", LOG_LOCAL6 );

sub questionlist {

	my $usererror = "User unauthorized";
	my $errorcode = 'unspecified';
	my $authtoken;
	if ( !( $authtoken = param('authtoken') ) ) {
		error('authtoken parameter must be set');
		$errorcode = 'unauthorized';
		goto BAIL;
	}
	my $auth;
	if ( !( $auth = new JazzHands::AuthToken ) ) {
		error("Unable to initialize AuthToken object");
		$errorcode = 'unauthorized';
		goto BAIL;
	}
	my $userinfo;
	if ( !( $userinfo = $auth->Decode($authtoken) ) ) {
		error( "Unable to decode authentication token: "
			  . $auth->Error );
		$errorcode = 'unauthorized';
		goto BAIL;
	}
	print header( -type => 'application/json' );

	my $jh;
	if (
		!(
			$jh = JazzHands::Management->new(
				application => 'jh_websvcs_ro'
			)
		)
	  )
	{
		error("unable to open connection to JazzHands");
		$errorcode = 'fatal';
		goto BAIL;
	}

	my $dbh = $jh->DBHandle;

	my $q = q {
		SELECT
			Auth_Question_ID,
			Question_Text
		FROM
			VAL_Auth_Question
		ORDER BY
			Auth_Question_ID
	};

	my $sth;
	if ( !( $sth = $dbh->prepare($q) ) ) {
		error( "Unable to prepare query for questions: "
			  . $dbh->errstr );
		$errorcode = 'fatal';
		goto BAIL;
	}
	if ( !( $sth->execute ) ) {
		error( "Unable to execute query for questions: "
			  . $sth->errstr );
		$errorcode = 'fatal';
	}

	my %questionlist;
	while ( my ( $id, $question ) = $sth->fetchrow_array ) {
		$question =~ s/"/\\"/g;
		$questionlist{$id} = $question;
	}
	$sth->finish;

	printf "{\n    questions: { \n        %s\n    }\n}\n",
	  join ",\n        ",
	  map { sprintf( '%d : "%s"', $_, $questionlist{$_} ); }
	  sort { $a <=> $b } keys %questionlist;
	$errorcode = undef;
      BAIL:
	if ($errorcode) {
		printf '{ errorcode: "%s" }', $errorcode;
	}
	undef $jh;
}

&questionlist;

