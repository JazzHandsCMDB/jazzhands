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
use JazzHands::ActiveDirectory;
use Sys::Syslog qw(:standard :macros);
use Time::HiRes qw(tv_interval gettimeofday);
use DBD::Oracle ':ora_types';
use Data::Dumper;
use JazzHands::AuthToken;
use JSON::XS;

use Digest::MD5 qw(md5 md5_hex md5_base64);
use Digest::SHA qw(sha1_base64);
use Crypt::Eksblowfish::Bcrypt qw(bcrypt en_base64);

# Specify lifetimes for various auth methods

my %lifetime = (
	'enroll' => 300,			# 5 minutes
	'level1' => 36000,			# 10 hours
	'level2' => 900,			# 15 minutes
	'changepassword' => 300		# 5 minutes
);

my $ADREALM = 'example.com';

my $HPDBPATH = '/prod/hotpants/db';

sub loggit {
	syslog(LOG_ERR, @_);
#	printf STDERR @_;
}

sub _options {
	my %ret = @_;
	for my $v (grep { /^-/ } keys %ret) {
		$ret{substr($v,1)} = $ret{$v};
	}
	\%ret;
}	   

sub authuser {
	closelog;
	openlog("authchangepass", "pid", LOG_LOCAL6);

	my $usererror = "Authentication failed";
	my $errorcode = 'unspecified';
	my $fatalerror = 0;
	my $response = {};
	my $login = lc(param('login'));
	if (!$login) {
		loggit('login parameter must be set');
		$errorcode = 'fatal';
		goto BAIL;
	}
	my $password = param('password');
	my $status = undef;
	my $authenticated = 0;
	if (!$password) {
		loggit('password parameter must be set');
		$errorcode = 'fatal';
		goto BAIL;
	}

	my $t0 = [gettimeofday];
	print header(-type => 'application/json'); 

	my $jhdbh;
	if (!($jhdbh = JazzHands::Management->new(application => 'jh_user_auth'))) {
		loggit("unable to open connection to JazzHands DB");
		$errorcode = 'fatal';
		goto BAIL;
	}

	my $dbh = $jhdbh->DBHandle;

	my $auth;
	if (!ref($auth = new JazzHands::AuthToken)) {
		loggit("Unable to initialize AuthToken object: ". $auth);
		$errorcode = 'fatal';
		goto BAIL;
	}
	my $user;

	if (!defined($user = $jhdbh->GetUser(login => $login))) {
		loggit("unable to get user information for authenticating user " .
			$login . ": " . $jhdbh->Error);
		goto BAIL;
	}
	if (!ref($user)) {
		loggit("unable to get user information for authenticated user " .
			$user);
		goto BAIL;
	}

	if (!$user->IsEnabled) {
		loggit("User %s is disabled", $user);
		goto BAIL;
	}

	my $authtoken;

	#
	# For password change, check AD, blowfish, interact
	# This totally needs to be configuration-driven, and not hard-coded
	#

	my $passhash = $user->GetPasswords;
	if ($passhash->{blowfish}->{hash} && $passhash->{blowfish}->{hash} eq
			bcrypt($password, $passhash->{blowfish}->{hash})) {
		$authenticated = 1;
		loggit("User %s successfully authenticated using blowfish password", $login);
		goto DONE;
	}
	if ($passhash->{interact}->{hash} && 
			($passhash->{interact}->{hash} eq
				(($passhash->{interact}->{hash} =~ /^\$2a?\$/) ?
				bcrypt($password, $passhash->{interact}->{hash}) :
				md5_hex($password)))
				) {
		$authenticated = 1;
		loggit("User %s successfully authenticated using interact password", $login);
		goto DONE;
	}
	my $aduser = $login . '@' . $ADREALM;
	my $adh = JazzHands::ActiveDirectory->new(
		nodbauth => 1,
		username => $aduser,
		password => $password,
		domain => $ADREALM
		);
	if (ref($adh)) {
		$authenticated = 1;
		loggit("User %s successfully authenticated using AD password", $login);
		goto DONE;
	}
	loggit("User %s failed authentication", $login);

	DONE:
	if ($authenticated) {
		if (!($authtoken = $auth->Create(
				login => $login,
				authtype => 'changepassword',
				lifetime => 500,
				))) {
			loggit("Unable to set authentication token");
			$errorcode = 'fatal';
			goto BAIL;
		}
		$response->{authtoken} = $authtoken;
	}

	BAIL:
	if (!$response->{authtoken}) {
		$response = {
			error => $usererror,
			errorcode => $errorcode
		};
	}

	print encode_json $response;
	closelog;
	undef $jhdbh;
}

&authuser;

