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
use JazzHands::Krb5::Tools;
use JazzHands::ActiveDirectory;
use Crypt::Cracklib qw/check/;
use Sys::Syslog qw(:standard :macros);

use CGI::Cookie;
use JSON::XS;
use JazzHands::AuthToken;

my $AUTHDOMAIN = 'examples.com';
my $r = shift;

# Array containing list of things to send back hard errors to AD on.  Any
# error types that are in here will send back a success and silently ignore
# it.  Valid values are:
#	pseudouser		- password for a pseudouser is being changed
#	adminprohibit	- account is administratively prohibited from changing
#					  from AD
#	system			- system errors

my @ERRORSON = ("pseudouser", "krb5", "internal", "disallowed");
my $ADMIN_PRINC = 'adminsetpw@EXAMPLE.COM';
my $KEYTAB = "/etc/krb5.keytab-adminsetpw";
my $WORDLIST = "/usr/dict/words";
my $BANNEDWORDLIST = "/../private/bannedwords";
my $CHRLIST = "0123456789!$%^*.";
my @CHRLIST = split '', $CHRLIST;
my @WORDLIST;
my @BANNEDLIST;

closelog();
openlog("adminsetpw", "pid", LOG_LOCAL6);

if (!@WORDLIST) {
	if (!open(W, "<$WORDLIST")) {
		loggit("Unable to open $WORDLIST: $!\n");
	} else {
		@WORDLIST = grep {/^[a-z]{3,6}$/} <W>;
		chomp @WORDLIST;
		close W;
	}
}

if (!@BANNEDLIST) {
	if (!open(W, "<$BANNEDWORDLIST")) {
		loggit("Unable to open $BANNEDWORDLIST: $!\n");
	} else {
		@BANNEDLIST = <W>;
		chomp @BANNEDLIST;
		close W;
	}
}

sub _options {
    my %ret = @_;
    for my $v (grep { /^-/ } keys %ret) {
        $ret{substr($v,1)} = $ret{$v};
    }
    \%ret;
}

sub loggit {
	syslog(LOG_ERR, @_);
#	printf STDERR @_;
}


sub is_numeric {
	no warnings;
	use warnings FATAL => 'numeric';
	return defined eval { $_[ 0] == 0 };
}

sub do_changepassword {
	my $query = new CGI;
	my $header = {};
	my $response = {};

	my %cookie = fetch CGI::Cookie;
	my $userid = $query->param("userid");
	my $updateAD = 1;
	my $questionid = $query->param("qid");
	my $questionresponse = $query->param("response");
	my $force = $query->param("force");
	my $updateLocal = 1;
	my $updateKrb5 = 1;

	my $errorstr = undef;

	my $login = $query->param("login");
	if ($login) {
		$login = CGI::unescape(lc($login));
	}
	my $pass = $query->param("password");
	if ($pass) {
		$pass = CGI::unescape(lc($pass));
	}
	my $source = $query->param("source");
	if ($source) {
		$source = CGI::unescape($source);
	}

	$header->{'-type'} = 'application/json';

	#
	# Either these two are set, or the authtoken is set
	#
	my $appuser;

	my $auth;
	if (!($auth = new JazzHands::AuthToken)) {
		loggit("Unable to initialize AuthToken object");
		$response->{errorcode} = 'unauthorized';
		$response->{usererror} = "Not authorized or session timeout";
		goto BAIL;
	}

	#
	# Ignore authtoken if username and password were passed
	#
	my $authenticated = 0;

	my $authtoken = '';
	my $userinfo;
	if (defined($cookie{'authtoken-level1'})) {
		$authtoken = eval {$cookie{'authtoken-level1'}->value};
	}

	if (!($userinfo = $auth->Decode($authtoken))) {
		loggit("Unable to decode authentication token '%s': %s", $authtoken,
			$auth->Error);
		$response->{errorcode} = 'unauthorized';
		$response->{usererror} = "Not authorized or session timeout";
		goto BAIL;
	} else {
		$authenticated = 1;
		$appuser = $userinfo->{login};
		$authtoken = $auth->Timestamp($userinfo);
		if (!$authtoken) {
			loggit("Unable to timestamp auth token: %s", $auth->Error);
		} else {
			my $authcookie = new CGI::Cookie(-name=>'authtoken-level1',
				-value=>$authtoken,
				-path=>'/',-domain=>$AUTHDOMAIN);
			$header->{'-cookie'} = [ $authcookie ];
		}
	} 

	#
	# If the source is from ActiveDirectory, don't update it
	#
	if ($source && $source eq 'ActiveDirectory') {
		$updateAD = 0;
	}
	
	if ($userid && !is_numeric($userid)) {
		loggit ('invalid userid: %s', $userid);
		$response->{errorcode} = 'fatal';
		$response->{usererror} = "Invalid userid";
		goto BAIL;
	}

	my $jhdbh;
	if (!($jhdbh = JazzHands::Management->new(application => 'user-cpw',
			dberrors => 1, appuser => $appuser))) {
		loggit ('Unable to connect to JazzHands DB');
		$response->{errorcode} = 'fatal';
		$response->{usererror} = "Database error";
		goto BAIL;
	}

	$jhdbh->rollback;

	my $adh;

	if ($updateAD) {
		$adh = JazzHands::ActiveDirectory->new();
		if (!ref($adh)) {
			loggit ('Unable to connect to AD');
			$response->{errorcode} = 'fatal';
			$response->{usererror} = "Unable to connect to AD";
			goto BAIL;
		}
	}

	my $authuser;

	#
	# Determine whether the authenticated user is allowed to set
	# this password
	#
	if (!defined($authuser = $jhdbh->GetUser(login => $appuser))) {
		loggit ("Internal error: unable to get user information for authenticated user '%s': %s",
			$appuser, $jhdbh->Error);
		$response->{errorcode} = 'fatal';
		$response->{usererror} = "Database error";
		goto BAIL;
	}

	my $sysuid = undef;
	my $authorized = 0;
	my $perm;
	my $dbh = $jhdbh->DBHandle;
	my $sth;
	my $q;

	my $user;

	# Try to fetch the user, but don't error yet until we figure out whether
	# the user should get a real error

	if ($userid) {
		if (!defined($user = $jhdbh->GetUser(id => int($userid)))) {
			loggit("Unable to get user information for userid %d", $userid);
		}
	} else {
		if (!defined($user = $jhdbh->GetUser(login => $login))) {
			loggit("Unable to get user information for user %s", $login);
		}
	}

	if (defined($user)) {
		$login = $user->Login;
		$sysuid = $user->Id;
	}
	#
	# Determine whether the admin is permitted to do things to this user
	#

	#
	# ... first see if this is a global admin
	#
	$q = q {
		SELECT
			Property_Value
		FROM
			V_User_Prop_Expanded
		WHERE
			System_User_ID = :1 AND
			Property_Type = 'UserMgmt' AND
			Property_Name = 'GlobalPasswordAdmin'
	};

	if (!($sth = $dbh->prepare($q))) {
		loggit("Unable to prepare database query: " . $dbh->errstr);
		$response = {
			errorcode => 'dberror',
			usererror => 'Fatal database error'
		};
		goto BAIL;
	}
	if (!($sth->execute($authuser->Id))) {
		loggit("Unable to execute database query: " . $sth->errstr);
		$response = {
			errorcode => 'dberror',
			usererror => 'Fatal database error'
		};
		goto BAIL;
	}
	my $userlist;
	$perm = ($sth->fetchrow_array)[0];
	$sth->finish;
	if ($perm && $perm eq 'Y') {
		$authorized = 1;
	} elsif ($sysuid) {
		#
		# ... it wasn't, so see if they are authorized for this particular
		# user
		#
		$q = q {
			SELECT UNIQUE
				SU.System_User_ID
			FROM
				V_User_Prop_Expanded UPE JOIN
				MV_Uclass_User_Expanded UUE ON
					(Property_Value_Uclass_ID = UUE.Uclass_Id) JOIN
				System_User SU ON (UUE.System_User_ID = SU.System_User_ID)
			WHERE   
				UPE.System_User_ID = :adminsysuid AND
				SU.System_User_ID = :usersysuid AND
				Property_Type = 'UserMgmt' AND
				Property_Name = 'PasswordAdminForUclass'
		};
		if (!($sth = $dbh->prepare($q))) {
			loggit("Unable to prepare database query: " . $dbh->errstr);
			$response = {
				errorcode => 'dberror',
				usererror => 'Fatal database error'
			};
			goto BAIL;
		}
		$sth->bind_param(':adminsysuid', $authuser->Id);
		$sth->bind_param(':usersysuid', $sysuid);
		if (!($sth->execute)) {
			loggit("Unable to execute database query: " . $sth->errstr);
			$response = {
				errorcode => 'dberror',
				usererror => 'Fatal database error'
			};
			goto BAIL;
		}
		if ($perm = ($sth->fetchrow_array)[0]) {
			$authorized = 1;
		} else {
			loggit("User %s is not allowed to set passwords for user %s",
				$appuser, $login);
		}
		$sth->finish;
	}

	# If they are not a global password admin, give this error

	if (!$authorized) {
		$response = {
			errorcode => 'unauthorized-user',
			usererror =>
				'You do not have permission to set passwords for this user',
		};
		goto BAIL;
	}

	# If they are a global password admin, give this error if the user doesn't
	# exist

	if (!defined($user)) {
		$response = {
			errorcode => 'baduser',
			usererror => 'User does not exist'
		};
		goto BAIL;
	}

	#
	# ... now determine whether the user that we're trying to set the password
	# for is allowed to have its password changed
	#

	#
	# Password can not be changed for pseudousers
	#
	if ($user->Type eq "pseudouser") {
		my $msg = 'passwords may not be changed for pseudousers';
		loggit("%s changing password for %s", $msg, $login);
		$response->{errorcode} = 'fatal';
		$response->{usererror} = $msg;
		goto BAIL;
	}

	#
	# Password can not be changed for disabled users
	#
	if (!$user->IsEnabled) {
		my $msg = 'passwords may not be changed for disabled users';
		loggit("%s changing password for %s", $msg, $login);
		$response->{errorcode} = 'fatal';
		$response->{usererror} = $msg;
		goto BAIL;
	}

	my $changeallowed = 1;

	#
	# If we couldn't find a property, then allow the change
	#
	if (!defined($changeallowed)) {
		if ($jhdbh->Error) {
			loggit ('Database error');
			$response->{errorcode} = 'fatal';
			$response->{usererror} = "Database error";
			goto BAIL;
		} else {
			$changeallowed = 1;
		}
	}

	if (!$changeallowed) {
		my $msg = 'password may not be changed for user %s';
		loggit($msg, $login);
		$response->{errorcode} = 'fatal';
		$response->{usererror} = sprintf($msg, $login);
		goto BAIL;
	}

	#
	# See if we have a challenge/response we need to deal with
	#
	$q = q {
		SELECT
			Auth_Question_ID,
			User_Answer
		FROM
			System_User_Auth_Question
		WHERE
			System_User_ID = :1
	};

	if (!($sth = $dbh->prepare($q))) {
		loggit("Unable to prepare database query: " . $dbh->errstr);
		$response->{errorcode} = 'fatal';
		$response->{usererror} = "Database error";
		goto BAIL;
	}
	if (!($sth->execute($user->Id))) {
		loggit("Unable to execute database query: " . $sth->errstr);
		$response->{errorcode} = 'fatal';
		$response->{usererror} = "Database error";
		goto BAIL;
	}
	my %answer;
	while (my ($qid, $qanswer) = $sth->fetchrow_array)  {
		$answer{$qid} = $qanswer;
	}

	if (%answer) {
		#
		# If there are questions and answers enrolled...
		#
		if ($force) {
			#
			# Check if admin can force
			#
			$q = q {
				SELECT
					Property_Value
				FROM
					V_User_Prop_Expanded
				WHERE
					System_User_ID = :1 AND
					Property_Type = 'UserMgmt' AND
					Property_Name = 'MasterPasswordAdmin'
			};

			if (!($sth = $dbh->prepare($q))) {
				loggit("Unable to prepare database query: " . $dbh->errstr);
				$response->{errorcode} = 'fatal';
				$response->{usererror} = "Database error";
				goto BAIL;
			}
			if (!($sth->execute($authuser->Id))) {
				loggit("Unable to execute database query: " . $sth->errstr);
				$response->{errorcode} = 'fatal';
				$response->{usererror} = "Database error";
				goto BAIL;
			}
			$perm = ($sth->fetchrow_array)[0];
			$sth->finish;
			if (!$perm || $perm ne 'Y') {
				loggit("Admin %s is not allowed to override challenge for %s",
					$appuser, $login);
				$response->{errorcode} = 'unauthorized';
				$response->{usererror} = 
					"You do not have permission to override challenges";
				goto BAIL;
			} else {
				loggit("Challenge for %s overridden by admin %s",
					$login, $appuser);
			}
		} else {
			if ((!$questionid) || (!$questionresponse) ||
					!$answer{$questionid}) {
				$response->{errorcode} = 'needresponse';
				my @qids = keys %answer;
				my $qid = $qids[rand($#qids + 1)];
				loggit('Sending challenge question id %d for %s',
					$qid, $login);
				$response->{question} = $qid;
				goto BAIL;
			}
			if (lc($questionresponse) ne lc($answer{$questionid})) {
				loggit('Response did not match verifying user %s', $login);
				$response->{errorcode} = 'badresponse';
				$response->{usererror} = 'Challenge response did not match';
				goto BAIL;
			}   
		}
	} else {
		loggit ('No challenge questions set for user %s', $login);
		if (!$force) {
			$response->{errorcode} = 'requireoverride';
			$response->{usererror} = 
				'Override is required without challenge questions';
			goto BAIL;
		}
	}

	#
	# If we got here, the question and response were not set or were matched,
	# or the admin overrode.
	#

	$pass = makeuprandompasswd();

	if ($updateLocal) {
		if (!$user->SetPassword(password => $pass)) {
			loggit('JazzHands password change failed for %s', $login);
			$response->{usererror} = 'fatal';
			$response->{errorcode} = 'JazzHands password change failed';
			goto BAIL;
		}
	}

	if ($updateKrb5) {
		my $kadm = JazzHands::Krb5::Tools->new(user => $ADMIN_PRINC,
			keytab => $KEYTAB);

		if (!ref($kadm)) {
			my $msg = sprintf(
				'Unable to get admin principal to change Kerberos password for %s: %s',
				$login, $kadm);
			loggit($msg);
			$response->{usererror} = 'fatal';
			$response->{errorcode} = $msg;
			goto BAIL;
		}

		if (!$kadm->SetPassword(user => $user->Login, password => $pass)) {
			my $msg = sprintf(
				'Unable to set Kerberos password for %s: %s',
				$login, $kadm->Error);
			loggit($msg);
			$response->{usererror} = 'fatal';
			$response->{errorcode} = $msg;
			goto BAIL;
		}
	}

	if ($updateAD) {
		#
		# Try to get an AD account.  If there isn't one, don't worry about it
		#

		my $dn;
		if (!($dn = $adh->GetUserByUID($user->Id))) {
			syslog(LOG_INFO, "No AD account for %s (id %d) - skipping",
				$user->Login, $user->Id);
		} elsif (!($adh->setLDAPPassword( 
				dn => $dn, password => $pass, adminset => 1))) {
			my $msg = sprintf(
				'Unable to set AD password for %s: %s',
				$login, $adh->Error);
			loggit($msg);
			$response->{usererror} = 'fatal';
			$response->{errorcode} = $msg;
			goto BAIL;
		}
	}

	$jhdbh->commit;

	loggit('Password reset for %s by %s', $login, $appuser);
	$response->{status} = 'success';
	$response->{password} = $pass;

	BAIL:
	print header($header);
	print encode_json $response;

	if ($jhdbh) {
		$jhdbh->rollback;
		$jhdbh->disconnect;
	}
	undef $jhdbh;
	closelog;
}

sub makeuprandompasswd {
	my $Password;
	if (@WORDLIST) {
		my $word1;
		my $word2;
		do {
			$word1 = $WORDLIST[int(rand($#WORDLIST + 1))];
		} while (grep {/^$word1$/} @BANNEDLIST);
		do {
			$word2 = $WORDLIST[int(rand($#WORDLIST + 1))];
		} while (grep {/^$word2$/} @BANNEDLIST);

		$Password = $word1 .
			$CHRLIST[int(rand($#CHRLIST + 1))] .
			$CHRLIST[int(rand($#CHRLIST + 1))] .
			$word2;

		# Uppercase a random number of characters

		my $numrand = int(rand(4));
		while ($numrand--) {
			substr($Password,int(rand(length($Password)+1)),1) =~ tr/a-z/A-Z/;
		}
	} else {
		for(my $i = 0; $i < 7; $i++) {
			$Password .= ('A'..'Z', '%', '$', '.', '!', '-', 0..9,'a'..'z')[rand 64];
		}
	}
	$Password;
}

&do_changepassword();
