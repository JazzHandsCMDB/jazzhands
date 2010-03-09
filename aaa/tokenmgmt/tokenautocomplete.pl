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
use CGI::Cookie;
use JazzHands::AuthToken;

# This needs to not be here

my $AUTHDOMAIN = 'example.com';

sub loggit {
	syslog(LOG_ERR, $@);
#	printf STDERR $@;
}

sub gettokenlist {
	openlog("tokenautocomplete", "pid", LOG_LOCAL6);

	my $string  = param("serial");
	my $types  = param("types");
	loggit("Types: %s", $types);
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

	if (!$string) {
		print '<body><ul></ul></body>';
		goto BAIL;
	}

	my $jhdbh;
	if (!($jhdbh = JazzHands::Management->new(application => 'jh_websvcs_ro'))) {
		loggit("unable to open connection to jhdbh");
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
	# First determine whether user can set all tokens
	#

	my $perm;
	my $sth;

	my $q = q {
		SELECT
			Property_Value
		FROM
			V_User_Prop_Expanded
		WHERE
			System_User_ID = :sysuid AND
			UClass_Property_Type = 'TokenMgmt' AND
			UClass_Property_Name = 'GlobalAdmin'
	};

	if (!($sth = $dbh->prepare($q))) {
		loggit("Unable to prepare database query: " . $dbh->errstr);
		print "<body><ul><li id='token-dberror'>Database error</li></ul></body>";
		goto BAIL;
	}
	$sth->bind_param(':sysuid', $user->Id);
	if (!($sth->execute)) {
		loggit("Unable to execute database query: " . $sth->errstr);
		print "<body><ul><li id='token-dberror'>Database error</li></ul></body>";
		goto BAIL;
	}
	my $tokenlist;
	$perm = ($sth->fetchrow_array)[0];
	$sth->finish;
	if ($perm && $perm eq 'Y') {
#		if (!defined($tokenlist = $jhdbh->GetTokens(
#				serial => $string,
#				fuzzy => 1
#				))) {
#			loggit("unable to get token list: " . $jhdbh->Error);
#			print "<body><ul><li id='token-dberror'>Database error</li></ul></body>";
#			goto BAIL;
#		}
#		print "<body><ul>\n";
#		foreach my $token (@$tokenlist) {
#			printf q{	<li id="token%d">%s</li>}."\n",
#				$token->{token_id},
#				$token->{serial};
#		}
#		print "</ul></body>\n";

		$q = sprintf q {
			SELECT UNIQUE
				Token_ID,
				Token_Serial,
				Token_Collection_Name
			FROM	
				V_Token LEFT JOIN
				Token_Collection_Member USING (Token_ID) LEFT JOIN
				Token_Collection USING (Token_Collection_Id)
			WHERE   
				REGEXP_LIKE(Token_Serial, :serial || '$', 'i')
		};
		if (!($sth = $dbh->prepare($q))) {
			loggit("Unable to prepare database query: " . $dbh->errstr);
			print "<body><ul><li id='token-dberror'>Database error</li></ul></body>";
			goto BAIL;
		}
		$sth->bind_param(':serial', $string);
	} else {
		$q = sprintf q {
			SELECT UNIQUE
				Token_ID,
				Token_Serial,
				Token_Collection_Name
			FROM	
				V_User_Prop_Expanded UPE JOIN
				Token_Collection TC ON
					(Property_Value_Token_Col_ID = Token_Collection_ID) JOIN
				Token_Collection_Member USING (Token_Collection_ID) JOIN
				V_Token USING (Token_ID)
			WHERE   
				UPE.System_User_ID = :sysuid AND
				UClass_Property_Type = 'TokenMgmt' AND
				UClass_Property_Name = 'ManageTokenCollection' AND
				REGEXP_LIKE(Token_Serial, :serial || '$', 'i') AND
				Token_Status <> 'DESTROYED'
		};
		if (!($sth = $dbh->prepare($q))) {
			loggit("Unable to prepare database query: " . $dbh->errstr);
			print "<body><ul><li id='token-dberror'>Database error</li></ul></body>";
			goto BAIL;
		}
		$sth->bind_param(':sysuid', $user->Id);
		$sth->bind_param(':serial', $string);
	}
	if (!($sth->execute)) {
		loggit("Unable to execute database query: " . $sth->errstr);
		print "<body><ul><li id='token-dberror'>Database error</li></ul></body>";
		goto BAIL;
	}
	my $rowsfound = 0;
	my %token;
	while (my ($id, $serial, $collection) =
			$sth->fetchrow_array) {
		$rowsfound++;
		if ($token{$id}) {
			push @{$token{$id}->{collection}}, $collection;
		} else {
			$token{$id} = {
				serial => $serial,
			};
			if (defined($collection)) {
				$token{$id}->{collection} = [ $collection ];
			}
		}
	}
	print "<body><ul>\n";
	if (!$rowsfound) {
		print qq{<li id="tokennotfound">No matching tokens found</li>\n};
	} else {
		foreach my $id (sort 
				{$token{$a}->{serial} cmp $token{$b}->{serial}} keys %token) {
			my $serial = $token{$id}->{serial};
			if ($token{$id}->{collection}) {
				$serial .= sprintf '<span class="informal"> (%s)</span>',
					(join ",", sort @{$token{$id}->{collection}});
			}
			printf q{    <li id="token%d">%s</li>}."\n",
				$id,
				$serial;
		}
	}
	print "</ul></body>\n";

	BAIL:
	closelog;
	undef $jhdbh;
}

&gettokenlist;
