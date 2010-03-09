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
use JazzHands::AuthToken;
use JSON::XS;
use Sys::Syslog qw(:standard :macros);

openlog("verifyauthquestion", "pid", LOG_LOCAL6);

sub _options {
    my %ret = @_;
    for my $v (grep { /^-/ } keys %ret) {
        $ret{substr($v,1)} = $ret{$v};
    }
    \%ret;
}

sub loggit {
	syslog(LOG_ERR, @_);
}

sub verifyauthquestion {
	my $query = new CGI;
	my $AUTHDOMAIN = 'example.com';
	my $response = {
	};

	my $header = {
		-type => 'application/json'
	};
	my $auth;
	if (!($auth = new JazzHands::AuthToken)) {
		loggit("Unable to initialize AuthToken object");
		$response->{usererror} = 'Not authorized';
		$response->{errorcode} = 'unauthorized';
		goto BAIL;
	}

	my $authtoken = $query->param("authtoken");
	if (!$authtoken) {
		loggit ("No auth token passed");
		$response->{usererror} = 'Invalid authorization';
		$response->{errorcode} = 'unauthorized';
		goto BAIL;
	}

	my $userinfo;
	if (!($userinfo = $auth->Decode($authtoken))) {
		loggit("Unable to decode authentication token: " . $auth->Error);
		$response->{usererror} = 'Invalid authorization';
		$response->{errorcode} = 'unauthorized';
		goto BAIL;
	}

	my $login = $userinfo->{login};
	if ($userinfo->{authtype} ne 'recoverpassword') {
		loggit("Invalid authorization type '%s' for password recovery for %s",
			$userinfo->{authtype}, $login);
		$response->{usererror} = 'Invalid authorization';  
		$response->{errorcode} = 'unauthorized';
		goto BAIL; 
	}

	my $questionid;
	if (!(($questionid = $userinfo->{secondaryauthinfo}) > 0)) {
		loggit("Authorization token for %s does not contain question id",
			$login);
		$response->{usererror} = 'Invalid authorization';
		$response->{errorcode} = 'unauthorized';
		goto BAIL;
	}
	
	my $jhdbh;
    if (!($jhdbh = JazzHands::Management->new(application => 'jh_websvcs_ro',
			dberrors => 1))) {
		loggit("unable to open connection to JazzHands DB");
		$response->{usererror} = 'Database access error';
		$response->{errorcode} = 'fatal';  
		goto BAIL; 
	}	

	my $dbh = $jhdbh->DBHandle;
	my $user;
	if (!defined($user = $jhdbh->GetUser(login => $login))) {
		loggit("Unable to fetch user %s: %s", $login,
			$jhdbh->Error);
		$response->{usererror} = 'Invalid authorization';
		$response->{errorcode} = 'unauthorized';  
		goto BAIL; 
	}

	#
	# Verify that we're able to enroll this user.  The user has to be
	# enabled, not a pseudouser, and not have the AllowEnroll password
	# property set to false
	#
	if ($user->Type eq "pseudouser") {
		error ("Attempting to recover password for pseudouser %s",
			$login);
		$response->{usererror} = 'Invalid authorization';
		$response->{errorcode} = 'unauthorized';  
		goto BAIL;
	}

	if (!$user->IsEnabled) {
		error ("Attempting to recover password for %s, which is not enabled", 
			$login);
		$response->{usererror} = 'Invalid authorization';
		$response->{errorcode} = 'unauthorized';  
		goto BAIL;
	}

	#
	# Make sure the user is allowed to recover passwords
	#

	my ($q, $sth);

	$q = q {
		SELECT
			Property_Value
		FROM
			V_User_Prop_Expanded
		WHERE
			System_User_ID = :sysuid AND
			Property_Type = 'UserAttributes' AND
			Property_Name = 'RecoverPassword'
	};

	if (!($sth = $dbh->prepare($q))) {
		loggit("Unable to prepare database query: " . $dbh->errstr);
		goto BAIL;
	}
	$sth->bind_param(':sysuid', $user->Id);
	if (!($sth->execute)) {
		loggit("Unable to execute database query: " . $sth->errstr);
		goto BAIL;
	}
	my $tokenlist;
	my $changeallowed = ($sth->fetchrow_array)[0];
	$sth->finish;

	if (defined($changeallowed) && !$changeallowed) {
		loggit("Attempting to recover password for %s who has RecoverPassword attribute set to false",
			$login);
#		$response->{usererror} = 'Recovery has been disabled for this user';
#		$response->{errorcode} = 'disallowed';  
		$response->{usererror} = 'Invalid authorization';
		$response->{errorcode} = 'unauthorized';  
		goto BAIL;
	}

	my $answer = $query->param('answer');
	if (!$answer) {
		loggit("Attempting to recover password for %s, but no answer was passed",
			$login);
		$response->{usererror} =
			'Answer not passed';
		$response->{errorcode} = 'needanswer';
		goto BAIL;
	}
	#
	# Verify that the user has the questions enrolled that was passed
	#

	$q = q{
		SELECT 
			User_Answer
		FROM
			System_User_Auth_Question
		WHERE
			System_User_ID = :sysuid AND
			Auth_Question_ID = :questionid
	};
	if (!($sth = $dbh->prepare($q))) {
		loggit("Unable to fetch question information: " . $dbh->errstr);
		$response->{usererror} = 'Database error';
		$response->{errorcode} = 'fatal';  
		goto BAIL;
	}
	$sth->bind_param(':sysuid', $user->Id);
	$sth->bind_param(':questionid', $questionid);
	if (!($sth->execute)) {
		loggit("Unable to fetch question information: " . $sth->errstr);
		$response->{usererror} = 'Database error';
		$response->{errorcode} = 'fatal';  
		goto BAIL;
	}
	my $authanswer = ($sth->fetchrow_array)[0];
	$sth->finish;

	if (!$authanswer || lc($authanswer) ne lc($answer)) {
		$response->{usererror} = 'Invalid authorization';
		$response->{errorcode} = 'unauthorized';  
		goto BAIL;
	}

	#
	# If we get here, everything went okay
	#
	if (!($authtoken = $auth->Create(
			login => $login,
			authtype => 'changepassword',
			lifetime => 300,
			secondaryauthinfo => 'recover'
			))) {
		loggit("Unable to set password recover auth token for %s",
			$login);
		goto BAIL;
	}

	my $authcookie = new CGI::Cookie (-name=>'authtoken-changepassword',
		-value => $authtoken,
		-path => '/',
		-domain => $AUTHDOMAIN);
	$header->{'-cookie'} = $authcookie;

	$response->{status} = 'authorized';
	BAIL:
	undef $jhdbh;
	closelog;

	print header($header);
	print encode_json $response;
}

&verifyauthquestion();
