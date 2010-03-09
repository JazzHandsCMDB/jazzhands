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
use Sys::Syslog qw(:standard :macros);

use CGI::Cookie;
use JazzHands::AuthToken;
use JSON::XS;
use JazzHands::PWVerify;

my $AUTHDOMAIN = 'example.com';
my $MAILCMD = '/usr/sbin/sendmail -t';

# Array containing list of things to send back hard errors to AD on.  Any
# error types that are in here will send back a success and silently ignore
# it.  Valid values are:
#	pseudouser		- password for a pseudouser is being changed
#	adminprohibit	- account is administratively prohibited from changing
#					  from AD
#	system			- system errors

my $ADMIN_PRINC = 'adminsetpw@EXAMPLE.COM';
my $KEYTAB = "/etc/krb5.keytab-adminsetpw";

openlog("changepw", "pid", LOG_LOCAL6);

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

sub is_numeric {
	no warnings;
	use warnings FATAL => 'numeric';
	return defined eval { $_[ 0] == 0 };
}

sub do_changepassword {
	my $query = new CGI;
	my $header = {
		-type => 'application/json'
	};
	my $response = {};

	my %cookie = fetch CGI::Cookie;

	my $updateAD = 1;
	my $updateLocal = 1;
	my $updateKrb5 = 1;

	my $errorstr = undef;

	my $pass = $query->param("password");
	if ($pass) {
		$pass = CGI::unescape($pass);
	}
	
	my $auth;
	if (!($auth = new JazzHands::AuthToken)) {
		loggit("Unable to initialize AuthToken object");
		$response = {
			errorcode => 'fatal',
			usererror => 'Fatal error performing authentication'
		};
		goto BAIL;
	}

	my $authtoken = '';
	if (defined($cookie{'authtoken-changepassword'})) {
		$authtoken = eval {$cookie{'authtoken-changepassword'}->value};
	}

	if (!$authtoken) {
		loggit("No authtoken present");
		$response = {
			errorcode => 'unauthorized',
			usererror => 'Not authorized or session timeout'
		};
		goto BAIL;
	}

	my $userinfo;
	if (!($userinfo = $auth->Decode($authtoken))) {
		loggit("Unable to decode authentication token '%s': %s", $authtoken,
			$auth->Error);
		$response = {
			errorcode => 'unauthorized',
			usererror => 'Not authorized or session timeout'
		};
		goto BAIL;
	}
	my $login = $userinfo->{login};
	$authtoken = $auth->Timestamp($userinfo);
	if (!$authtoken) {
		loggit("Unable to timestamp auth token: %s", $auth->Error);
	} else {
		my $authcookie = new CGI::Cookie(-name=>'authtoken-changepassword',
			-value=>$authtoken,
			-path=>'/',-domain=>$AUTHDOMAIN);
		$header->{'-cookie'} = $authcookie;
	} 

	if (!$pass) {
		$response->{errorcode} = 'nopassword';
		$response->{usererror} = 'No password to set';
		goto BAIL;
	}

	my $jhdbh;
	if (!($jhdbh = JazzHands::Management->new(application => 'user-cpw',
			dberrors => 1, appuser => $login))) {
		loggit('Unable to open connection to JazzHands DB');
		$response->{errorcode} = 'fatal';
		$response->{usererror} =
			'Unable to connect to backend database.  Please try again later';
		goto BAIL;
	}

	my $adh;

	$adh = JazzHands::ActiveDirectory->new();
	if (!ref($adh)) {
		loggit('Unable to open connection to ActiveDirectory: %s', 
			$adh || 'unknown');
		$response->{errorcode} = 'fatal';
		$response->{usererror} = 
			'Unable to open connection to Active Directory.  Please try again later';
		goto BAIL;
	}

	my $user;

	#
	# Determine whether the authenticated user is allowed to set
	# this password
	#
	if (!defined($user = $jhdbh->GetUser(login => $login))) {
		loggit('User not found in JazzHands.  This should not happen.');
		$response->{errorcode} = 'nouser';
		$response->{usererror} = 'Not authorized or session timeout';
		goto BAIL;
	}

	#
	# Password can not be changed for pseudousers
	#
	if ($user->Type eq "pseudouser") {
		loggit('attempt to change password for pseudouser %s', $login);
		$response->{errorcode} = 'changedenied';
		$response->{usererror} =
			'Passwords may not be changed for pseudousers';
		goto BAIL;
	}

	#
	# Password can not be changed for disabled users
	#
	if (!$user->IsEnabled) {
		loggit('attempt to change password for disabled user %s', $login);
		$response->{errorcode} = 'changedenied';
		$response->{usererror} =
			'Passwords may not be changed for disabled users';
		goto BAIL;
	}

	my $changeallowed;

#	my $changeallowed = $jhdbh->GetUserUclassPropertyValue(user => $user, 
#		name => "AllowUserChange", type => "password");

	#
	# If we couldn't find a property, then allow the change
	#
	if (!defined($changeallowed)) {
		if ($jhdbh->Error) {
			loggit('Error retrieving uclass property: %s', $jhdbh->Error);
			$response->{errorcode} = 'fatal';
			$response->{usererror} =
				'Fatal database error.  Please try again later';
			goto BAIL;
		} else {
			$changeallowed = 1;
		}
	}

	if (!$changeallowed) {
		loggit('password change denied for %s', $login);
		$response->{errorcode} = 'changedenied';
		$response->{usererror} =
			'Passwords may not be changed for this user';
		goto BAIL;
	}

#	if ($randomize) {
#		$pass = makeuprandompasswd();
#	}

	if (my $rv = JazzHands::PWVerify::VerifyPassword(
			user => $user,
			password => $pass)) {
		loggit('VerifyPassword returned error setting password for %s: %s',
			$login, $rv);
		$response->{errorcode} = 'passwordstrength';
		$response->{usererror} = $rv;
		goto BAIL;
	}

	if ($userinfo->{secondaryauthinfo} eq 'recover') {
		
		#
		# Must notify or change fails
		#
		if (!open (I, "|$MAILCMD")) {
#		if (!open (I, ">/tmp/crap")) {
			loggit('Unable to mail out change notification for password recovery of %s: %s',
				$login, $!);
			$response->{errorcode} = 'notifyfailed';
			$response->{usererror} = 'Could not mail notification of password reset; password recovery is denied';
			goto BAIL;
		}
		printf I 
q{From: ITSM <nobody@example.com>
To: %s <%s@example.com>
Subject: Your password has been reset

Dear %s,

Your passwords have been reset from IP address %s at
%s.  If you did not request or perform this password reset, please contact
nobody@example.com immediately.

},
			$user->FullName, $login, $user->FullName,
			$ENV{'REMOTE_ADDR'}, scalar(localtime());
		close I;

		my $dbh = $jhdbh->DBHandle;
		my $sth;

		if (!($sth = $dbh->prepare(q {
				UPDATE Token SET Token_PIN = NULL WHERE Token_ID IN (
					SELECT 
						Token_ID
					FROM
						V_Token JOIN
						System_User USING (System_User_ID)
					WHERE
						Login = ?
				)
				}))) {
			loggit("Unable to prepare database query resetting token PIC: %s",
				$dbh->errstr);
			$response = {
				errorcode => 'dberror',
				usererror => 'Fatal database error'
			};  
			goto BAIL;
		}
		if (!($sth->execute($login))) {
			loggit("Unable to execute database query resetting token PIC: %s",
				$sth->errstr);
			$response = {
				errorcode => 'dberror',
				usererror => 'Fatal database error'
			};  
			goto BAIL;
		}
		$sth->finish;
		$dbh->commit;
	}

	my $kadm = JazzHands::Krb5::Tools->new(user => $ADMIN_PRINC,
		keytab => $KEYTAB);

	if (!ref($kadm)) {
		loggit(
			"Unable to get admin principal to change Kerberos password: %s",
			$kadm);
		$response->{errorcode} = 'fatal';
		$response->{usererror} =
			'Error getting kadmin principal to set Kerberos password.';
		goto BAIL;
	}

	if (!$kadm->SetPassword(user => $user->Login, password => $pass)) {
		loggit("Unable to set Kerberos password for %s: %s",
			$login, $kadm->Error);
		$response->{errorcode} = 'pwchangefailed';
		$response->{usererror} = 'Error setting Kerberos password';
		goto BAIL;
	}

	#
	# Try to get an AD account.  If there isn't one, don't worry about it
	#

	my $dn;
	if (!($dn = $adh->GetUserByUID($user->Id))) {
		loggit('No AD account for %s, skipping', $login);
	} elsif (!($adh->setLDAPPassword(dn => $dn, password => $pass))) {
		loggit("Unable to set ActiveDirectory password for %s: %s",
			$login, $adh->Error);
		$response->{errorcode} = 'pwchangefailed';
		$response->{usererror} = 'Error setting ActiveDirectory password';
		goto BAIL;
	}

	if (!$user->SetPassword(password => $pass)) {
		loggit('JazzHands password change failed for %s: %s',
			$login, $user->Error);
		$response->{errorcode} = 'pwchangefailed';
		$response->{usererror} = 'Error setting JazzHands password';
		goto BAIL;
	}

	$jhdbh->commit;

	loggit('password successfully changed for %s', $login);
	$response->{status} = 'success';

	BAIL:
	if ($jhdbh) {
		$jhdbh->rollback;
		$jhdbh->disconnect;
	}
	undef $jhdbh;
	closelog;

	print header($header);
	print encode_json $response;
}

&do_changepassword();
