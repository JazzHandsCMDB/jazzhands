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
use Data::Dumper;
use Sys::Syslog qw(:standard :macros);

my $r = shift;
my $headers = $r->headers_out;
my $inheaders = $r->headers_in;
$headers->{'Pragma'} = $headers->{'Cache-control'} = 'no-cache';
$r->no_cache(1);

my $authdomain = 'example.com';
my $changepasswordurl = '/changepassword';

print header(-charset => 'utf-8');
print <<'EOF';
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
  <title>Login</title>
  <meta http-equiv="content-type" content="text/html; charset=utf-8" />
  <link href="/common/css/acct.css" media="screen" rel="Stylesheet" type="text/css" />
  <script src="/common/javascript/prototype.js" type="text/javascript"></script>
<!--
  <script src="/common/javascript/effects.js" type="text/javascript"></script>
  <script src="/common/javascript/controls.js" type="text/javascript"></script>
-->
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
	  Password Recovery
  </div>
<div id="content" class="content">

<div id="blurb">
<h1>Password Recovery</h1>

<p>
If you have forgotten your password, you can use this page to reset it
if you have enrolled with the self-service password recovery service.
Enter your username and answer the question with the response that you
gave when you enrolled.
</p>
<dl>
<dt>
<label for="login">Username: </label>
</dt>
<dd>
<input 
	id="login"
	type="text"
	size="30"
	autocomplete="off"
	onkeypress="if (this.value == '\r') { getAuthQuestion(); }"
	onchange="getAuthQuestion();"
	/>
</dd>
</dl>
<div id="questiondiv" class="answer" style="display:none">
<p>
Your question: <span id="question"></span>
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
	onchange="verifyAuthQuestion();"
	/>
</dd>
</dl>
</p>
</div>
</div>
</div>
<div class="statbox" id="statbox" style="display:none"></div>

</div>
  
<div id="footer">
    <p>
	JazzHange Management
    </p>
</div>

<script>
//<![CDATA[
var authCookie;
var authBusy = false;
EOF
printf q{
var AUTHDOMAIN = '%s';
var CHANGEPASSWORD = '%s';
}, $authdomain, $changepasswordurl;
print <<'EOF';

function fatalError(text) {
//	$('fatalerror').style.display = '';
	var statBox = $('statbox');
	statBox.className = 'errorbox';
	statBox.innerHTML = 'Fatal error authenticating user: ' +
		text +
		'<br>Please try again later.';
	statBox.style.display = '';
	return false;
}

function getAuthQuestion () {
	if (authBusy) {
		return false;
	}

	var statBox = $('statbox');
	var loginobj = $('login');
	if (!loginobj || !(loginobj.value)) {
		statBox.className = "errorbox";
		statBox.innerHTML = "You must provide a username";
		statBox.style.display = "";
		loginobj.focus();
		return false;
	}
	var login = loginobj.value;

	// Authenticate user.  This will return either a success or failure.
	// On success it will also received a short-lived authentication
	// cookie.

	statBox.className = 'statbox';
	statBox.innerHTML = "Fetching question...";
	statBox.style.display = '';
	authBusy = true;
	
	var ajaxRequest = new Ajax.Request("/websvcs/getuserauthquestion.pl",
		{
			method: 'post',
			parameters: {
				'login': login
			},
			onSuccess: function(resp) {
				var response = resp.responseJSON;
				var statBox = $('statbox');
				statBox.style.display = 'none';
				// If we get an auth token back, then the user
				// has authenticated successfully, otherwise spew
				// the errors.
				authBusy = false;
				if (!response.question) {
					authBusy = false;
					statBox.className = "errorbox";
					if (response.usererror) {
						statBox.innerHTML = response.usererror;
					} else {
						statBox.innerHTML = "Unknown error";
					}
					statBox.style.display = '';
					loginobj.focus();
					return false;
				} else {
					$('question').innerHTML = response.question;
					$('questiondiv').style.display = '';
					$('answer').focus();
					authCookie = response.authtoken;
				}
			},
			onFailure: function(response) {
				authBusy = false;
				fatalError(response.statusText);
			}
		}
	);
}

function verifyAuthQuestion () {
	if (authBusy) {
		return false;
	}

	var statBox = $("statbox");
	var answerobj = $('answer');
	if (!answerobj || !(answerobj.value)) {
		statBox.className = "errorbox";
		statBox.innerHTML = "You must answer the question";
		statBox.style.display = "";
		answerobj.focus();
		return false;
	}
	var answer = answerobj.value;

	// Authenticate user.  This will return either a success or failure.
	// On success it will also received a short-lived authentication
	// cookie.

	statBox.className = 'statbox';
	statBox.innerHTML = "Validating answer...";
	statBox.style.display = '';
	authBusy = true;
	
	var ajaxRequest = new Ajax.Request("/websvcs/verifyauthquestion.pl",
		{
			method: 'post',
			parameters: {
				'authtoken' : authCookie,
				'answer': answer
			},
			onSuccess: function(resp) {
				var response = resp.responseJSON;
				var statBox = $('statbox');
				statBox.style.display = 'none';
				// If we get an auth token back, then the user
				// has authenticated successfully, otherwise spew
				// the errors.
				if (!response.status) {
					authBusy = false;
					statBox.className = "errorbox";
					if (response.errorcode == 'unauthorized') {
						statBox.innerHTML = 'Your answer to this question did not match the one you originally provided.  Capitalization does not matter, however punctuation does';
					} else if (response.usererror) {
						statBox.innerHTML = response.usererror;
					} else {
						statBox.innerHTML = "Unknown error";
					}
					statBox.style.display = '';
					answerobj.focus();
					return false;
				} else {
					document.location = CHANGEPASSWORD;
				}
			},
			onFailure: function(response) {
				fatalError(response.statusText);
			}
		}
	);
}

//]]>
</script>

</body>
</html>
EOF
