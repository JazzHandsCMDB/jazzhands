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
use CGI::Cookie;
use JazzHands::AuthToken;

# This needs to not be here
                
my $AUTHDOMAIN = 'example.com';

sub loggit {
#	syslog(LOG_ERR, $@);
	printf STDERR $@;
}

sub getuserlist {
	openlog("tokenusernameautocomplete", "pid", LOG_LOCAL6);

	my $string  = lc(param("login"));
	my $enabled_only  = lc(param("includeDisabled"));
	$enabled_only = 
		(defined $enabled_only && $enabled_only eq 'true') ?  0 : 1;

	my %cookie = fetch CGI::Cookie;

	my $auth;
	if (!($auth = new JazzHands::AuthToken)) {
		loggit("Unable to initialize AuthToken object");
		print header, "<body><ul><li id='token-noauth'>Not authorized or session timeout</li></ul></body>";
		goto BAIL;
	}

	my $authtoken = '';
	if (defined($cookie{'authtoken-level1'})) {
		$authtoken = eval {$cookie{'authtoken-level1'}->value};
	}

	my $userinfo;
	if (!($userinfo = $auth->Decode($authtoken))) {
		loggit("Unable to decode authentication token '%s': %s", $authtoken,
			$auth->Error);
		print header, "<body><ul><li id='token-noauth'>Not authorized or session timeout</li></ul></body>";
		goto BAIL;
	}
	my $appuser = $userinfo->{login};
	$authtoken = $auth->Timestamp($userinfo);
	if (!$authtoken) {
		loggit("Unable to timestamp auth token: %s", $auth->Error);
		print header;
	} else {
		my $authcookie = new CGI::Cookie(-name=>'authtoken-level1',
			-value=>$authtoken,
			-path=>'/',-domain=>$AUTHDOMAIN);
		print header(-cookie=>[$authcookie]);
	} 

	my $t0 = [gettimeofday];

	my $jhdbh;
	if (!($jhdbh = JazzHands::Management->new(application => 'jh_websvcs_ro'))) {
		loggit("unable to open connection to JazzHands DB");
		print "<body><ul><li id='token-dberror'>Database error</li></ul></body>";
		goto BAIL;
	}

	my $dbh = $jhdbh->DBHandle;

	my $user;

	if (!defined($user = $jhdbh->GetUser(login => $appuser))) {
		loggit("unable to get user information for authenticated user " .
			$appuser . ": " . $jhdbh->Error);
		print "<body><ul><li id='token-noauth'>Not authorized or session timeout</li></ul></body>";
		goto BAIL;
	}
	if (!ref($user)) {
		loggit("unable to get user information for authenticated user " .
			$user);
		print "<body><ul><li id='token-noauth'>Not authorized or session timeout</li></ul></body>";
		goto BAIL;
	}

	#
	# First determine whether admin can set tokens for all users
	#

	my $perm;
	my $sth;

	my $q = q {
		SELECT
			Property_Value
		FROM
			V_User_Prop_Expanded
		WHERE
			System_User_ID = :1 AND
			UClass_Property_Type = 'UserMgmt' AND
			UClass_Property_Name = 'GlobalTokenAdmin'
	};

	if (!($sth = $dbh->prepare($q))) {
		loggit("Unable to prepare database query: " . $dbh->errstr);
		print "<body><ul><li id='token-dberror'>Database error</li></ul></body>";
		goto BAIL;
	}
	if (!($sth->execute($user->Id))) {
		loggit("Unable to execute database query: " . $sth->errstr);
		print "<body><ul><li id='token-dberror'>Database error</li></ul></body>";
		goto BAIL;
	}
	my $userlist;
	$perm = ($sth->fetchrow_array)[0];
	$sth->finish;
	if ($perm && $perm eq 'Y') {
		if (!defined($userlist = $jhdbh->GetUsers(
				login => $string,
				first => $string,
				last => $string,
				enabled_only => $enabled_only,
				fuzzy => 1
				))) {
			loggit("unable to get user list: " . $jhdbh->Error);
			print "<body><ul><li id='token-dberror'>Database error</li></ul></body>";
			goto BAIL;
		}

		print "<body><ul>\n";
		foreach $user (@$userlist) {
			printf q{    <li id="%d">%s<span class="informal"> - %s %s</span></li>}."\n",
				$user->Id, 
				$user->Login,
				($user->PreferredFirstName || $user->FirstName),
				($user->PreferredLastName || $user->LastName);
		}
		print "</ul></body>\n";
	} else {
		$q = sprintf q {
			SELECT UNIQUE
				System_User_ID,
				Login,	 
				First_Name,
				Preferred_First_Name,
				Last_Name,
				Preferred_Last_Name
			FROM	
				V_User_Prop_Expanded UPE JOIN
				MV_Uclass_User_Expanded UUE ON
					(Property_Value_Uclass_ID = UUE.Uclass_Id) JOIN
				System_User SU ON (UUE.System_User_ID = SU.System_User_ID)
			WHERE   
				UPE.System_User_ID = :sysuid AND
				UClass_Property_Type = 'UserMgmt' AND
				UClass_Property_Name = 'TokenAdminForUclass'
		}, $user->Id;
		if (!($sth = $dbh->prepare($q))) {
			loggit("Unable to prepare database query: " . $dbh->errstr);
			print "<body><ul><li id='token-dberror'>Database error</li></ul></body>";
			goto BAIL;
		}
		$sth->bind_param(':sysuid', $user->Id, ORA_NUMBER);
		my $t = [gettimeofday];
		if (!($sth->execute)) {
			loggit("Unable to execute database query: " . $sth->errstr);
			print "<body><ul><li id='token-dberror'>Database error</li></ul></body>";
			goto BAIL;
		}
		print "<body><ul>\n";
#		printf q{<li id="0">Elapsed: %.3f sec</li>} . "\n", tv_interval($t);
#		printf "Total Elapsed: %.3f sec\n", tv_interval($t0);
		my $rowsfound = 0;
		while (my ($uid, $login, $first, $pfirst, $last, $plast) =
				$sth->fetchrow_array) {
			my $found = 0;
			foreach my $i ($login, $first, $pfirst, $last, $plast) {
				next if !$i;
				next if ((index lc($i), $string) < 0);
				$found = 1;
			}
			next if !$found;
			$rowsfound++;
			printf q{    <li id="%d">%s<span class="informal"> - %s %s</span></li>}."\n",
				$uid,
				$login,
				$pfirst || $first,
				$plast || $last;
		}
		if (!$rowsfound) {
			print qq{	<li id="usernotfound">No matching users found</li>\n};
		}
		print "</ul></body>\n";
	}

	BAIL:
	closelog;
	undef $jhdbh;
}

&getuserlist;
