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
	if($dir =~ m,/,) {
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
		unshift(@INC, "$dir/../../fakeroot.lib/$incentry");
	}
	unshift(@INC, "$dir/../lib/lib");
}

use strict;
use CGI qw(:standard);
use JazzHands::Management qw(:DEFAULT);
use Sys::Syslog qw(:standard :macros);
use Time::HiRes qw(tv_interval gettimeofday);
use DBD::Oracle ':ora_types';
use Data::Dumper;
use JazzHands::AuthToken;
use JSON::XS;
use CGI::Cookie;

sub loggit {
	syslog(LOG_ERR, @_);
#	printf STDERR @_;
}

my $AUTHDOMAIN = "example.com";

openlog("getuserauthquestion", "pid", LOG_LOCAL6);

sub getuserauthquestion {
	my $response = {};

	my $login = param('login') || 'davidoff';
	my $header = {
		-type => 'application/json'
	};

	if (!$login) {
		loggit("login parameter not passed");
		$response->{errorcode} = 'fatal';
		$response->{usererror} = 'Login parameter not given';
		goto BAIL;
	}

	my $jhdbh;
	if (!($jhdbh = JazzHands::Management->new(application => 'jh_websvcs_ro'))) {
		loggit("unable to open connection to JazzHands DB");
		$response->{errorcode} = 'fatal';
		$response->{usererror} = 'fatal';
		goto BAIL;
	}

	my $auth;
	if (!($auth = new JazzHands::AuthToken)) {
		loggit("Unable to initialize AuthToken object");
		$response = {
			errorcode => 'fatal',
			usererror => 'Fatal authentication error'
		};
		goto BAIL;
	}

	my $dbh = $jhdbh->DBHandle;

	my $q = q {
		SELECT
			Auth_Question_ID,
			Question_Text
		FROM
			VAL_Auth_Question JOIN
			System_User_Auth_Question USING (Auth_Question_ID) JOIN
			System_User USING (System_User_ID)
		WHERE
			Login = :login
	};

	my $sth;
	if (!($sth = $dbh->prepare($q))) {
		loggit("Unable to prepare query for questions: %s", $dbh->errstr);
		$response->{errorcode} = 'fatal';
		$response->{usererror} = 'Database error';
		goto BAIL;
	}
	$sth->bind_param(':login', $login);
	if (!($sth->execute)) {
		loggit("Unable to execute query for questions: %s", $sth->errstr);
		$response->{errorcode} = 'fatal';
		$response->{usererror} = 'Database error';
		goto BAIL;
	}

	my %question;
	my @questionlist;
	while (my ($id, $question) = $sth->fetchrow_array) {
		$question =~ s/"/\\"/g;
		$question{$id} = $question;
		push @questionlist, $id;
	}
	$sth->finish;

	my $idx;
	if (!@questionlist) {
		#
		# If the user does not exist or does not have any questions selected
		# pick some questions, but make it appear to return the same two
		# questions for that user, as if it were actually enrolled with two
		# questions.
		#
		$q = q {
			SELECT
				Auth_Question_ID,
				Question_Text
			FROM
				VAL_Auth_Question
			ORDER BY
				Auth_Question_ID
		};

		if (!($sth = $dbh->prepare($q))) {
			loggit("Unable to prepare query for questions: %s", $dbh->errstr);
			$response->{errorcode} = 'fatal';
			$response->{usererror} = 'Database error';
			goto BAIL;
		}
		if (!($sth->execute)) {
			loggit("Unable to execute query for questions: %s", $sth->errstr);
			$response->{errorcode} = 'fatal';
			$response->{usererror} = 'Database error';
			goto BAIL;
		}

		while (my ($id, $question) = $sth->fetchrow_array) {
			$question =~ s/"/\\"/g;
			$question{$id} = $question;
			push @questionlist, $id;
		}
		$sth->finish;

		my @ary = unpack ('c' . (length($login) + 1), $login);

		foreach my $i (@ary) {
			$idx += $i;
		}
		$idx = ($idx + int(rand(2))) % $#questionlist;
	} else {
		$idx = int(rand($#questionlist + 1));
	}
	$response->{question} = $question{$questionlist[$idx]};

	$jhdbh->disconnect;
	my $authtoken;
	if (!($authtoken = $auth->Create(
			login => $login,
			authtype => 'recoverpassword',
			lifetime => 300,
			secondaryauthinfo => $questionlist[$idx]))) {
		loggit ('Unable to set authentication token for %s', $login);
		$response->{errocode} = 'fatal';
		$response->{usererror} = 'Authentication error';
		goto BAIL;
	}
#	my $authcookie = new CGI::Cookie(-name=>'authtoken-resetpassword',
#		-value=>$authtoken,
#		-path=>'/',-domain=>$AUTHDOMAIN);
	$response->{authtoken} = $authtoken;

	BAIL:
	print header($header);
	print encode_json $response;

	undef $jhdbh;
	closelog;
}

&getuserauthquestion;

