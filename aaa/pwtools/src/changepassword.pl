#!/usr/local/bin/perl

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

sub loggit {
	syslog(LOG_ERR, @_);
#	printf STDERR @_;
}

my $r = shift;
openlog("tokenmgmt", "pid", LOG_LOCAL6);

my %cookie = fetch CGI::Cookie;

my $auth;
my $redirecttologin = 0;
if (!($auth = new JazzHands::AuthToken)) {
	loggit("Unable to initialize AuthToken object");
	$redirecttologin = 1;
}

my $authtoken = eval {$cookie{'authtoken-changepassword'}->value};

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
	$r->headers_out->set(Location => $LOGINPAGE . '?referrer=' . $url .
		'&authtype=changepassword');
	$r->status(Apache2::Const::REDIRECT);

	return Apache2::Const::REDIRECT;
}

my $pwexpired = param('pwexpired');
my $recovery = 'false';
if ($userinfo->{secondaryauthinfo} eq 'recover') {
	$recovery = 'true';
}

print header;
print <<'EOF';
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
  <title>Change Password</title>
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
    <h1>Change Password</h1>

EOF

if ($pwexpired) {
	print q{
		<p><strong>
			Your password has expired and you will need to change it.
		</strong></p>
	};
}

print <<'EOF';
<p>
Changing your password here will synchronize your password across all
centrally-managed systems and stuff.  YMMV.
</p>
<div id ="recover" style="display:none">
<p>
Because you are using password recovery, resetting your password here will
also reset the PIC for any token that you have enrolled.  After setting your
password, you will be need to use the <a href="/enroll">token enrollment
page</a> to re-enroll your token.
</p>
</div>
<p>
Your password must:
<ul>
<li>be between 7 and 20 characters in length
<li>contain at least three different types of characters (upper case,
lower case, numbers, and punctuation)
<li>not contain any spaces, your username, or your first or last name
<li>not be based on a dictionary word or a <q>l33t-spelled</q> word, such as 
<q>p4$$w0rd</q>
</ul>
</p>
<p>
For more help, see the document on <a onclick="window.open('https://account.example.com/choosing-good-passwords.html');">Choosing a Good Password</a>
</p>
<p>
As with any password, do not write it down.
</p>
<script type="text/javascript">
//<![CDATA[
EOF

printf q{
var AUTHDOMAIN = '%s';
var recovery = %s;
}, $AUTHDOMAIN, $recovery;

print <<'EOF';

function validateAndSubmit() {
	var pass1Field = $("newpass1");
	var pass2Field = $("newpass2");
	var statBox = $("statbox");

	if (pass1Field.value.length == 0) {
		statBox.className = "errorbox";
		statBox.innerHTML = "You must provide a new password.";
		statBox.style.display = "";
		pass1Field.focus();
		return false;
	}

	if (pass2Field.value.length == 0) {
		statBox.className = "errorbox";
		statBox.innerHTML = "You must provide a new password.";
		statBox.style.display = "";
		pass2Field.focus();
		return false;
	}

	if (pass1Field.value != pass2Field.value) {
		statBox.className = "errorbox";
		statBox.innerHTML = "Your new passwords do not match";
		statBox.style.display = "";
		pass1Field.focus();
		return false;
	}

	statBox.style.display = "";
	statBox.className = "statbox";
	statBox.innerHTML = "Changing password...";
	var ajaxRequest = new Ajax.Request("/websvcs/changepw.pl",
		{
			method: 'post',
			parameters: {
				password: pass2Field.value
			},
			onSuccess: function(req) {
				var response = req.responseJSON;
				var statBox = $("statbox");
				var passwordForm = $("passwordform");
				statBox.style.display = "";
				if (response.status != "success") {
					statBox.className = "errorbox";
					statBox.innerHTML = "Error changing password: " 
						+ response.usererror;
					return false;
				} else {
					statBox.className = "statbox";
					passwordForm.style.display = "none";
					var expire_date = new Date();
					document.cookie = 'authtoken-changepassword=;expires=' +
						expire_date.toGMTString() + ';path=/;domain=' +
						AUTHDOMAIN + ';';
					if (!recovery) {
						statBox.innerHTML = "Your password was changed.";
					} else {
						statBox.update('Your password was changed and your token PIC has been reset.  Please visit the <a href="/enroll">token enrollment page</a> to enroll your token PIC');
					}
					return true;
				}
			},
			onFailure: function(response) {
				transportFailure(response);
			}
		}
	);
}

function transportFailure(req) {
	var statBox = document.getElementById("statbox");
	statBox.className = "errorbox";
	statBox.innerHTML = "Error making password reset request: " +
		req.statusText;
	statBox.style.display = "";
}


function visiblizeFields(req) {
	var pass1Field = $("newpass1");
	var pass2Field = $("newpass2");
	var pass1Div = $("newpass1div");
	var pass2Div = $("newpass2div");

	if (pass1Field.value.length != 0) {
		pass2Div.style.display = "";
		pass2Field.focus();
	}

}

if (recovery) {
	$('recover').style.display = "";
}

//]]>
</script>
<div id="passwordform">
<dl>
	<div id="newpass1div">
	<dt>
		<label for="newpass1"> Enter your new password: </label>
	</dt>
	<dd>
		<input
			id="newpass1"
			name="newpass1"
			size="30"
			type="password"
			onchange=visiblizeFields()
		/>
	</dd>
	</div>
	<div id="newpass2div" style="display:none">
	<dt>
		<label for="newpass2"> Enter your new password again: </label>
	</dt>
	<dd>
		<input
			id="newpass2"
			name="newpass2"
			size="30"
			type="password"
			onchange=validateAndSubmit()
		/>
	</dd>
	</div>
</dl>
</div>

	<div class="statbox" id="statbox" style="display:none"></div>
  </div>
  
  <div id="footer">
    JazzHands Management
  </div>

</body>
</html>

EOF
