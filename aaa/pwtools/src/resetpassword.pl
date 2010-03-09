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
use CGI::Cookie ();
use Apache2::RequestRec ();
use APR::Table ();
use Apache2::Const -compile => qw(REDIRECT);
use JazzHands::Management qw(:DEFAULT);
use JazzHands::AuthToken qw(:DEFAULT);
use Sys::Syslog qw(:standard :macros);
use Time::HiRes qw(tv_interval gettimeofday);
use DBD::Oracle ':ora_types';

#
# These need to be set elsewhere
#
my $LOGINPAGE = "/login";
my $AUTHDOMAIN = "example.com";
my $CONTACT = '<a href="mailto:nobody@example.com">ITSM</a>';

sub loggit {
	syslog(LOG_ERR, @_);
#	printf STDERR @_;
}

my $r = shift;
closelog;
openlog("resetpassword", "pid", LOG_LOCAL6);

my %cookie = fetch CGI::Cookie;

my $auth;
my $redirecttologin = 0;
if (!($auth = new JazzHands::AuthToken)) {
	loggit("Unable to initialize AuthToken object");
	$redirecttologin = 1;
}

my $authtoken = eval {$cookie{'authtoken-level1'}->value};

my $userinfo;
if (!($userinfo = $auth->Decode($authtoken))) {
	loggit("Unable to decode authentication token '%s': %s", $authtoken,
		$auth->Error);
	$redirecttologin = 1;
}

if ($redirecttologin) {
	my $url = url();
	loggit ("Redirecting to login page from: %s", $url);
	$url =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
	$r->headers_out->set(Location => $LOGINPAGE . '?referrer=' . $url);
	$r->status(Apache2::Const::REDIRECT);

	return Apache2::Const::REDIRECT;
}

my $appuser = $userinfo->{login};

my $jhdbh;
my $authorized = undef;
my $master = undef;
my $usererror = 'fatal';

if (!($jhdbh = JazzHands::Management->new(
		application => 'jh_websvcs_ro',
		dberrors => 1
		))) {
	loggit("unable to open connection to JazzHands DB");
	$usererror = 'Fatal database error';
	goto BAIL;
}

my $dbh = $jhdbh->DBHandle;

my $user;

if (!defined($user = $jhdbh->GetUser(login => $appuser))) {
	loggit("unable to get user information for authenticated user '%s': %s",
		$appuser, $jhdbh->Error);
	goto BAIL;
}
if (!ref($user)) {
	loggit("unable to get user information for authenticated user " .
		$user);
}

#
# determine whether user can manage passwords
#

my $sth;

my $q = q {
	SELECT
		Property_Name, Property_Value, Property_Value_UClass_ID
	FROM
		V_User_Prop_Expanded
	WHERE
		System_User_ID = :sysuid AND
		Property_Type = 'UserMgmt' AND
		Property_Name IN ('GlobalPasswordAdmin', 'MasterPasswordAdmin',
			'PasswordAdminForUclass')
};

if (!($sth = $dbh->prepare($q))) {
	loggit("Unable to prepare database query: " . $dbh->errstr);
	goto BAIL;
}
$sth->bind_param(':sysuid', $user->Id, ORA_NUMBER);
if (!($sth->execute)) {
	loggit("Unable to execute database query: " . $sth->errstr);
	goto BAIL;
}
my $tokenlist;
while (my ($propname, $perm, $uclass) = $sth->fetchrow_array) {
	#
	# To allow the overrides to work, we need to find only the first instance
	# of the property
	#
	if (!defined($authorized)) {
		if (($perm && $perm eq 'Y') || ($uclass)) {
			$authorized = 1;
		} else {
			$authorized = 0;
		}
	}
	if ($propname eq 'MasterPasswordAdmin' && !defined($master)) {
		if ($perm && $perm eq 'Y') {
			$master = 1;
		} else {
			$master = 0;
		}
	}
}
$sth->finish;
$usererror = 'unauthorized';

BAIL:

closelog;
undef $jhdbh;

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
print <<'EOF';
<eDOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
  <title>Password Reset Tool</title>
  <meta http-equiv="content-type" content="text/html; charset=utf-8" />
  <link href="/common/css/acct.css" media="screen" rel="Stylesheet" type="text/css" />
  <script src="/common/javascript/prototype.js" type="text/javascript"></script>
  <script src="/common/javascript/effects.js" type="text/javascript"></script>
  <script src="/common/javascript/controls.js" type="text/javascript"></script>
<style type="text/css">
#footer {
  /* Netscape 4, IE 4.x-5.0/Win and other lesser browsers will use this */
  position: absolute; right: 20px; bottom: 10px;
}
body > div#footer {
  /* used by Opera 5+, Netscape6+/Mozilla, Konqueror, Safari, OmniWeb 4.5+, iCab, ICEbrowser */
  position: fixed;
}
</style>
<!--[if gte IE 5.5]>
<![if lt IE 7]>
<style type="text/css">
div#footer {
  /* IE5.5+/Win - this is more specific than the IE 5.0 version */
  right: auto; bottom: auto;
  left: expression( ( 0 - footer.offsetWidth + ( document.documentElement.clientWidth ? document.documentElement.clientWidth : document.body.clientWidth ) + ( ignoreMe2 = document.documentElement.scrollLeft ? document.documentElement.scrollLeft : document.body.scrollLeft ) ) + 'px' );
  top: expression( ( 0 - footer.offsetHeight + ( document.documentElement.clientHeight ? document.documentElement.clientHeight : document.body.clientHeight ) + ( ignoreMe = document.documentElement.scrollTop ? document.documentElement.scrollTop : document.body.scrollTop ) ) + 'px' );
}
</style>
<![endif]>
<![endif]-->
</head>
<body>

  <div id="headbox">
	  User Management Tools
  </div>
  <div id="content" class="content">
    <h1>Password Reset Tool</h1>
EOF

if (!$authorized) {
	if ($usererror eq 'unauthorized') {
		print <<'EOF';
<div id='unauthorized'>
<h2>Unauthorized</h2>
<p>
You do not have permission to access this tool.
</p>
</div>
EOF
	} else {
		printf <<'EOF', $CONTACT;
<div id="errorstuffs">
<p>
Fatal error authorizing user.  Contact %s if this error persists.
</p>
</div>
EOF
	}
	print <<'EOF';
<div id="footer">
    <p>
	JazzHands Management
    </p>
</div>
EOF
	return;
}

print <<'EOF';
<p>
This page allows an administrator to reset the password of a user to a
random password.  This will reset ActiveDirectory, UNIX login accounts, and
Kerberos passwords.
</p>
<p> 
Enter a user's first name, last name, or login (or a portion thereof) and
select the desired user from the drop-down list, then press the Go button:
</p>

<input id="login" type="text" />
	<div class="auto_complete" id="login_auto_complete"></div>
<img src="/common/images/go.png" onclick=validateAndConfirmSubmit()></a>

<div id="questiondiv" class="answer" style="display:none">
<p>
Challenge question: <span id="question"></span>
<dl>
<dt>
<label for="answer">Answer: </label>
</dt>
<dd>
<input 
	id="answer"
	type="text"
	size="50"
	autocomplete="off"
	onkeypress="if (this.value == '\r') { verifyAuthQuestion(); }"
	onchange="validateAndConfirmSubmit();"
	/>
</dd>
</dl>
</p> 
</div>
<div id='overridediv' class="answer" style="display:none">
<input id="forcereset" type="checkbox">
	I have verified this user's identity using other means:
<select id="resetverify">
	<option selected value="UNSET">Please choose one...</option>
	<option value="BADGE">Employer-issued badge with photo</option>
	<option value="GOVTID">Government-issued photo ID</option>
</select>
</div>

<div class="statbox" id="statbox" style="display:none"></div>
 </div>
 
 <div id="footer">
   <p>JazzHands Management</p>
 </div>

<script type="text/javascript">
//<![CDATA[
var userid;
var qid;
var login;
var requireforce = 0;
var force = 0;
var authBusy = 0;
EOF
printf "var master = %d\n", $master;
print <<'EOF';

function validateAndConfirmSubmit() {
	if (!userid) return false;
	if (authBusy) return false;
	var answer = $('answer').value;
	// Only prompt the first time
	if (!answer) {
		if(!confirm('Do you want to reset the password for ' + 
			login + '?')) return false;
	}
	authBusy = true;
	var statBox = $("statbox");
	statBox.style.display = "";
	statBox.className = "statbox";
	statBox.innerHTML = "Resetting password for " + login;
	var params = {
		'userid' : userid
	};
	if (qid && answer) {
		params.qid = qid;
		params.response = answer;
	}
	if (master || requireforce) {
		force = $('forcereset').checked;
	}
	if (force) {
		params.force = 1;
		var forceverify = $('resetverify').value;
		if (forceverify == 'UNSET') {
			statBox.className = "errorbox";
			statBox.innerHTML = "You must select how you verified the identity of the user";
			statBox.style.display = '';
			return false;
		}
		params.forceverify = $('resetverify').value;
	}
	var ajaxRequest = new Ajax.Request("/websvcs/adminsetpw.pl",
		{
			method: 'post',
			parameters: params,
			onSuccess: function(resp) {
				authBusy = false;
				var response = resp.responseJSON;
				var statBox = $('statbox');
				var qDiv = $('questiondiv');
				statBox.style.display = 'none';
				if (response.status == 'success') {
					statBox.className = "statbox";
					statBox.style.display = '';
					statBox.innerHTML = "Password for " + login +
						" set to '" + response.password + "'";
					set_to_default();
					return true;
				}
				if (response.errorcode == 'needresponse') {
					loadQuestions(response.question);
					return true;
				}
				if (response.errorcode == 'requireoverride') {
					$('overridediv').style.display = '';
					requireforce = 1;
					return true;
				}
				statBox.className = "errorbox";
				statBox.innerHTML = "Error setting password for " +
					login + ": " + response.usererror;
				statBox.style.display = '';
				return false;
			},
			onFailure: function(response) {
				transportFailure(response);
			}
		}
	);
}

function transportFailure(req) {
	var statBox = $('statbox');
	statBox.className = 'errorbox';
	statBox.innerHTML = 'Error making password reset request: ' +
		req.statusText;
	statBox.style.display = '';
}

function loadQuestions(questionid) {
	var ajaxRequest = new Ajax.Request("/websvcs/getquestions.pl",
		{
			method: 'post',
			parameters: {
			},
			onSuccess: function(resp) {
				var response = resp.responseJSON;
				if (response.errorcode) {
					// If we get errors retrieving the questions and
					// answers, then remove the questions and answers
					// page.
					return false;
				} else {
					if (response.questions[questionid]) {
						$('question').update(response.questions[questionid]);
						qid = questionid;
						$('questiondiv').style.display = '';
						if (master) {
							$('overridediv').style.display = '';
						}
						return true;
					}
				}
			},
			onFailure: function(response) {
				return false;
			}
		}
	);
}

function set_to_default() {
	qid = undefined;
	$('questiondiv').style.display = 'none';
	$('overridediv').style.display = 'none';
	requireforce = 0;
	$('forcereset').checked = false;
}

function setSelectionId(text, li) {
	userid = li.id;
	login = text.value;

	// Reset all of the various values back to defaults
	set_to_default();
}

var login_autocompleter = new Ajax.Autocompleter(
	'login',
	'login_auto_complete',
	'/websvcs/passwordusernameautocomplete.pl',
	{
		paramName : 'login',
		afterUpdateElement : setSelectionId,
		minChars : 3
	});

//]]>
</script>
</body>
</html>

EOF

