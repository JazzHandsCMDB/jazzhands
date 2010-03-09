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

my $logoutcookie = sprintf('authtoken-level1=;path=/;domain=%s;expires=Thu, 01-Jan-70 00:00:01 GMT;', $AUTHDOMAIN);

my $authorized = 0;
my $usererror = 'fatal';

my $auth;
if (!($auth = new JazzHands::AuthToken)) {
	loggit("Unable to initialize AuthToken object");
	goto BAIL;
}

my $userinfo = $auth->Verify(
	request => $r,
	required_properties => [
		'TokenMgmt' => 'GlobalAdmin',
		'TokenMgmt' => 'ManageTokenCollection'
	]);

if (!$userinfo) {
	if ($auth->ErrorCode eq 'REDIRECT') {
		return Apache2::Const::REDIRECT;
	}
	$usererror = 'unauthorized';
} else {
	$authorized = 1;
}

my $appuser = $userinfo->{login};

my $jhdbh;

if (!($jhdbh = JazzHands::Management->new(
		application => 'jh_websvcs_ro',
		dberrors => 1
		))) {
	loggit("unable to open connection to JazzHands DB");
	$usererror = 'Fatal database error';
	goto BAIL;
}

my $dbh = $jhdbh->DBHandle;

my $q = q {
	SELECT
		Token_Status,
		Description
	FROM
		VAL_Token_Status
};

my $sth;
if (!($sth = $dbh->prepare($q))) {
	loggit("Unable to prepare database query: " . $dbh->errstr);
}

BAIL:

closelog;

print header(-cookie=>[$auth->{cookie}]);
print <<'EOF';
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" 
	"http://www.w3.org/TR/html4/loose.dtd">
<head>
  <title>Token Management</title>
  <meta http-equiv="content-type" content="text/html; charset=utf-8" />
  <link href="/common/css/acct.css" media="screen" rel="Stylesheet" type="text/css" />
  <script src="/common/javascript/prototype.js" type="text/javascript"></script>
  <script src="/common/javascript/effects.js" type="text/javascript"></script>
  <script src="/common/javascript/controls.mdr.js" type="text/javascript"></script>
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


<div id="showlogout" class="content" style="display:none">
You have been logged out.
</div>

<div id="content" class="content">

<div id="logoutdiv" class="logout">
<p onclick="doLogout();">Logout</p>
</div>

<h1>Token Management</h1>
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
		printf <<'EOF';
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
<div id="frontpage">

<p>
Please select a user or a token to manage.  Enter at least three characters
of a user's login, first, or last name in the box on the left and select the
user from the drop-down menu or enter the last two to four digits of the token
in the box on the right and select the token from the drop-down menu.
</p>

<style type="text/css" media="screen">
	div.userinputdiv {
		float: left;
		margin-left: 5%;
		width: 38%;
	}

	div.tokeninputdiv {
		float: right;
		width: 38%;
		margin-right: 5%;
	}

	div.tokeninputdiv p, div.userinputdiv p {
		margin-top: 2px;
		margin-bottom: 2px;
	}

	div.tokeninputdiv p:first-child, div.userinputdiv p:first-child {
		text-align: center;
		font-weight: bold;
	}
}
</style>

<div class="userinputdiv">
<p style="text-align: center; font-weight: bold;">
Enter User
</p>
<p>
<input id="login" style="width: 95%;" type="text"/>
</p>
<p>
<input align="left" id="allowdisabled" type="checkbox" value="allowdisabled"
	onchange="toggleDisabledUserSearch(this);">
Also search for disabled users
</p>
</div>

<div class="tokeninputdiv">
<p style="text-align: center; font-weight: bold;">
Enter Token
</p>
<p>
<input id="token" style="width: 95%;" type="text"/>
</p>
</div>

</div>
  
<div id="userdisplay" class="displaybox" style="display: none">
	<image src="/common/images/closebutton.png" class="closebutton"
		height="15" width="15" onclick="closeMain();">
	<div id="tokenassignbox" class="tokendetailbox" style="display: none">
	<image src="/common/images/closebutton.png" class="closebutton"
		height="15" width="15"
		onClick="$('newtoken').value=''; newTokenID = null; $('statbox').style.display = 'none'; $('tokenassignbox').style.display='none';">
	<p>
		Enter the last two to four characters of the serial number printed
		on the back of the token, then select the token from the drop-down
		list.
	</p>
	<input id="newtoken" name="newtoken" type="text" />
	<div class="tokenbuttons">
		<input id="confirmassignbutton" type="button" value="Assign" 
			onClick="assignToken();">
	</div>
	<div id="new_token_auto_complete" class="auto_complete"></div>

	</div>
	<div id="tokendetailbox" class="tokendetailbox" >
	<image src="/common/images/closebutton.png" class="closebutton"
		height="15" width="15"
		onclick="closeTokenDetail();">
	<div class="tokendetailbox2">
	<p class="infobox">Token ID: <strong><span id="tokenidfield"></span>
		</strong></p>
	<p id="tokentypefield" class="infobox"></p>
	<p class="infobox">Token Serial: <strong><span id="tokenserialfield">
		</span></strong></p>
	<p id="tokenstatusfield" class="infobox">Token Status is 
		<select id="tokenstatus" name="tokenstatus" 
				onChange="checkTokenStatus(this);">
			<option selected value="DISABLED">Disabled</option>
			<option value="ENABLED">Enabled</option>
			<option value="LOST">Lost</option>
			<option value="STOLEN">Stolen</option>
			<option value="DESTROYED">Destroyed</option>
		</select>
	</p>
	<p id="tokenpicfield" class="infobox">PIC is <strong>
		<span id="picset"></span></strong>
		<input id="resetpic" type="button" value = "Reset PIC"
			onClick="resetPIC();">
	</p>
	</div>
	<div class="tokenbuttons">
		<input id="applybutton" type="button" value="Apply"
			onclick="setStatus();">
		<input id="tokenhistorybutton" type="button" value="View History" 
			onclick="getHistory(currentToken.tokenid, 'tokenid');">
	</div>
	</div>
	<p id="displaylogin" class="infobox"></p>
	<p id="displaytitle" class="infobox"></p>
	<p id="displaystatus" class="infobox">User status is <span id="userstatus"></span></p>
	<div id="currenttokenbox" class="currenttokenbox">
	<p>Tokens assigned</p>
	<table id="tokentable">
	</table>
	<span>
		<input id="assignbutton" type = "button" value="Assign New Token"
			onClick="doAssignButton();">
		<input id="viewhistory" type = "button" value="View User History"
			onClick="getHistory(currentUser.userid, 'userid');">
	</span>
	</div>
</div>

<div class="displaybox" id="historydisplay" 
		style="display:none">
	<image src="/common/images/closebutton.png" class="closebutton"
		height="15" width="15"
		onclick="$('historydisplay').style.display = 'none';">
	<div id="historytablediv" class="tableContainer">
	<table id="historytable">
	</table>
	</div>
</div>
<div class="statbox" id="statbox" style="display:none"></div>

<div id="login_auto_complete" class="auto_complete"><ul><li></li></ul></div>
<div id="token_auto_complete" class="auto_complete"><li></li></div>

<script>
//<![CDATA[
var authCookie;
var currentUser;
var currentToken;
var tokenList;
var newTokenID;
var busy = 0;
EOF
printf "var logoutCookie = '%s'\n", $logoutcookie;
print <<'EOF';

var new_token_autocompleter = new Ajax.Autocompleter(
	'newtoken',
	'new_token_auto_complete',
	'/websvcs/tokenautocomplete.pl',
	{
		paramName: 'serial',
		minChars: 2,
		afterUpdateElement : setNewTokenSelection
	});

var login_autocompleter = new Ajax.Autocompleter(
	'login',
	'login_auto_complete',
	'/websvcs/tokenusernameautocomplete.pl',
	{
		paramName: 'login',
		parameters: { includeDisabled : false },
		minChars: 3,
		afterUpdateElement : loadUserFromUserSelection
	});

var token_autocompleter = new Ajax.Autocompleter(
	'token',
	'token_auto_complete',
	'/websvcs/tokenautocomplete.pl',
	{
		paramName: 'serial',
		minChars: 2,
		afterUpdateElement : loadHistoryFromTokenSelection
	});

function toggleDisabledUserSearch ( box ) {
	if (typeof login_autocompleter.options.defaultParams == 'object') {
		login_autocompleter.options.defaultParams.includeDisabled = 
			box.checked;
	} else {
		login_autocompleter.options.defaultParams = {
			includeDisabled : box.checked
		};
	}
}

function loadUserFromUserSelection (text, li) {
	var userid = li.id.toString();
	var login = text.value;
	if (userid == 'usernotfound') {
		return false;
		text.value = '';
	}
	userid = userid.replace(/^userid/, '');

	loadUser(userid, 'userid');
	closeHistory();
}

function loadUserFromTokenSelection (text, li) {
	var token = li.id.toString();
	var serial = text.value;

	if (token == 'tokennotfound') {
		text.value = '';
		return false;
	}
	token = token.replace(/^token/, '');
	loadUser(token, 'tokenid');
	closeHistory();
}

function loadHistoryFromTokenSelection (text, li) {
	var token = li.id.toString();
	var serial = text.value;

	if (token == 'tokennotfound') {
		text.value = '';
		return false;
	}
	token = token.replace(/^token/, '');
	getHistory(token, 'tokenid');
	// If we're loading something new, clear out the other box
	closeMain();
}

function setNewTokenSelection (text, li) {
	var tokid = li.id.toString();
	if (tokid == 'tokennotfound') {
		text.value = '';
		return false;
	}
	newTokenID = tokid.replace(/^token/, '');
}

function closeMain() {
	$('userdisplay').style.display = "none";
}

function closeTokenDetail() {
	$('tokendetailbox').style.display = "none";
	var histtype = getHistoryType();
	if (getHistoryType() == 'token') {
		closeHistory();
	}
}

function closeHistory() {
	$('historydisplay').style.display = "none";
}

function loadUser(id, idtype) {
	var params = {
		command : 'getuser'
	};

	// If we're already doing something, wait for us to finish.
	if (busy) return false;
	busy = 1;

	if (!id) return false;
	if (!idtype || (idtype != 'userid' && idtype != 'tokenid')) return false; 
	if (idtype == 'userid') {
		params['userid'] = id;
	} else {
		params['tokenid'] = id;
	}
	var statBox = $("statbox");
	statBox.style.display = "";
	statBox.className = "statbox";
	statBox.innerHTML = "Please wait...";
	var ajaxRequest = new Ajax.Request("/websvcs/tokencmd.pl",
		{
			method: 'post',
			parameters: params,
			onSuccess: function(resp) {
				// We're not busy any more
				busy = 0;
				var response = resp.responseJSON;
				var statBox = $('statbox');
				statBox.style.display = 'none'; 
				if (response.errorcode) {
					statBox.className = "errorbox";
					if (response.usererror) {
						statBox.innerHTML = response.usererror;
					} else {
						statBox.innerHTML = "Unknown error";
					}
					statBox.style.display = '';
					return false;
				}
				if (!response.user) {
					return false;
				}
				currentUser = response.user;
				$('displaylogin').update(currentUser.login + ' - ' + 
					currentUser.first_name + ' ' + currentUser.last_name);
				$('userstatus').update(currentUser.status);
				$('displaytitle').update(currentUser.title);
				$('userdisplay').style.display = '';
				$('tokenassignbox').style.display = 'none';
				$('tokendetailbox').style.display = 'none';
				if (!currentUser.tokens) {
					tokenList = [];
				} else {
					tokenList = currentUser.tokens;
				}
				displayTokenList(tokenList);
			},
			onFailure: function(resp) {
				fatalError(resp);
			}
		}
	);
}

function getHistory(id, idtype) {
	var params = {
		command : 'gethistory'
	};
	var histtype;

	// If we're already doing something, wait for us to finish.
	if (busy) return false;
	busy = 1;

	if (!id) return false;
	if (!idtype || (idtype != 'userid' && idtype != 'tokenid')) return false; 
	if (idtype == 'userid') {
		params['userid'] = id;
		histtype = 'user';
	} else {
		params['tokenid'] = id;
		histtype = 'token';
	}
	var statBox = $("statbox");
	statBox.style.display = "";
	statBox.className = "statbox";
	statBox.innerHTML = "Please wait...";
	var ajaxRequest = new Ajax.Request("/websvcs/tokencmd.pl",
		{
			method: 'post',
			parameters: params,
			onSuccess: function(resp) {
				// We're not busy any more
				busy = 0;
				var response = resp.responseJSON;
				var statBox = $('statbox');
				statBox.style.display = 'none'; 
				if (response.errorcode) {
					statBox.className = "errorbox";
					if (response.usererror) {
						statBox.innerHTML = response.usererror;
					} else {
						statBox.innerHTML = "Unknown error";
					}
					statBox.style.display = '';
					return false;
				}
				if (!response.events) {
					return false;
				}
				displayHistory(response.events);
				setHistoryType(histtype);
			},
			onFailure: function(resp) {
				fatalError(resp);
			}
		}
	);
}

function fatalError (resp) {
	var statBox = $('statbox');
	statBox.className = "errorbox";
	statBox.innerHTML = 'Fatal error contacting server';
	statBox.style.display = '';
	return false;
}

function doAssignButton () {
	$('newtoken').value='';
	newTokenID = null;
	$('tokenassignbox').style.display = '';
	closeTokenDetail();
	$('statbox').style.display = 'none';
	$('newtoken').focus();
}

function showTokenDetail (index) {
	if (!tokenList[index]) return false;
	currentToken = tokenList[index];
	tokenIndex = index;

	$('tokenidfield').innerHTML = currentToken.tokenid.toString();
	$('tokentypefield').innerHTML = currentToken.type;
	$('tokenserialfield').innerHTML = currentToken.serial;
	$('tokenassignbox').style.display = 'none';
	$('tokendetailbox').style.display = '';
	$('statbox').style.display = 'none';
	var statusselect = $('tokenstatus');
	statusselect.value = currentToken.status;
	statusselect.oldvalue = currentToken.status;
	if (currentToken.pin) {
		$('picset').innerHTML = 'SET';
		$('resetpic').style.display = '';
	} else {
		$('picset').innerHTML = 'NOT SET';
		$('resetpic').style.display = 'none';
	}

	var histtype = getHistoryType();
	if (histtype == 'token') {
		closeHistory();
	}
	return true;
}

function checkTokenStatus(e) {
	if (e.value == 'DESTROYED') {
		if (!confirm("Setting the status to destroyed will unassign the " +
				"token and remove it from the inventory.")) {
			e.value = e.oldvalue;
			return false;
		}
	}
	e.oldvalue = e.value;
	return true;
}

function unassignToken(index) {
	var statBox = $('statbox');
	if (!tokenList[index]) {
		statBox.className = 'errorbox';
		statBox.innerHTML = 'Internal error unassigning token.  Please report this error.';
		statBox.style.display = '';
		return false;
	}

	// If we're already doing something, wait for us to finish.
	if (busy) return false;
	busy = 1;

	var token = tokenList[index];

	if (!confirm('Unassign token ' + token.serial + '?')) {
		return false;
	}
	var params = {
		command : 'unassign',
		tokenid : token.tokenid,
		userid : currentUser.userid
	};

	statBox.style.display = "";
	statBox.className = "statbox";
	statBox.innerHTML = "Please wait...";
	var ajaxRequest = new Ajax.Request("/websvcs/tokencmd.pl",
		{
			method: 'post',
			parameters: params,
			onSuccess: function(resp) {
				var response = resp.responseJSON;
				var statBox = $('statbox');
				var tokIndex = index;
				busy = 0;
				statBox.style.display = 'none'; 
				if (response.errorcode) {
					statBox.className = "errorbox";
					if (response.usererror) {
						statBox.innerHTML = response.usererror;
					} else {
						statBox.innerHTML = "Unknown error unassigning token";
					}
					statBox.style.display = '';
					return false;
				}
				if (response.success)  {
					// Delete token from list
					if (currentToken === tokenList[tokIndex]) {
						$('tokendetailbox').style.display = 'none';
					}
					tokenList.splice(tokIndex, 1);
					statBox.className = 'statbox';
					statBox.innerHTML = 'Token ' + token.serial +
						' was unassigned';
					statBox.style.display = '';
					displayTokenList(tokenList);
				}
			},
			onFailure: function(resp) {
				fatalError(resp);
			}
		}
	);
}

function assignToken() {
	var statBox = $('statbox');
	if (!newTokenID) {
		statBox.className = 'errorbox';
		statBox.innerHTML = 'You must select a token to assign.';
		statBox.style.display = '';
		return false;
	}

	// If we're already doing something, wait for us to finish.
	if (busy) return false;
	busy = 1;

	var params = {
		command : 'assign',
		tokenid : newTokenID,
		userid : currentUser.userid
	};

	statBox.style.display = "";
	statBox.className = "statbox";
	statBox.innerHTML = "Please wait...";
	var ajaxRequest = new Ajax.Request("/websvcs/tokencmd.pl",
		{
			method: 'post',
			parameters: params,
			onSuccess: function(resp) {
				var response = resp.responseJSON;
				var statBox = $('statbox');
				busy = 0;
				statBox.style.display = 'none'; 
				if (response.errorcode) {
					statBox.className = "errorbox";
					if (response.usererror) {
						statBox.innerHTML = response.usererror;
					} else {
						statBox.innerHTML = "Unknown error assigning token";
					}
					statBox.style.display = '';
					return false;
				}
				if (response.success)  {
					// Reload user
					loadUser(currentUser.userid, 'userid');
					return true;
				}
			},
			onFailure: function(resp) {
				fatalError(resp);
			}
		}
	);
}

function resetPIC() {
	var statBox = $('statbox');
	if (!currentToken) {
		statBox.className = 'errorbox';
		statBox.innerHTML = 'Internal Error.  Please report this.';
		statBox.style.display = '';
		return false;
	}

	var token = currentToken;
	// If we're already doing something, wait for us to finish.
	if (busy) return false;
	busy = 1;

	var params = {
		command : 'resetpic',
		tokenid : token.tokenid.toString()
	};

	statBox.style.display = "";
	statBox.className = "statbox";
	statBox.innerHTML = "Please wait...";
	var ajaxRequest = new Ajax.Request("/websvcs/tokencmd.pl",
		{
			method: 'post',
			parameters: params,
			onSuccess: function(resp) {
				var response = resp.responseJSON;
				var statBox = $('statbox');
				busy = 0;
				statBox.style.display = 'none'; 
				if (response.errorcode) {
					statBox.className = "errorbox";
					if (response.usererror) {
						statBox.innerHTML = response.usererror;
					} else {
						statBox.innerHTML = "Unknown error resetting PIC";
					}
					statBox.style.display = '';
					return false;
				}
				if (response.success)  {
					token.pin = 0;
					$('picset').innerHTML = 'NOT SET';
					$('resetpic').style.display = 'none';
				}
			},
			onFailure: function(resp) {
				fatalError(resp);
			}
		}
	);
}

function setStatus() {
	var statBox = $('statbox');
	if (!currentToken) {
		statBox.className = 'errorbox';
		statBox.innerHTML = 'Internal Error.  Please report this.';
		statBox.style.display = '';
		return false;
	}

	// Don't want this to change out from under us

	var token = currentToken;

	// If the status hasn't changed, then we don't need to change it

	var statusselect = $('tokenstatus');
	if (token.status == statusselect.value) {
		return true;
	}

	var newvalue = statusselect.value;

	// If we're already doing something, wait for us to finish.
	if (busy) return false;
	busy = 1;

	var params = {
		command : 'setstatus',
		value : newvalue,
		tokenid : token.tokenid.toString()
	};

	statBox.style.display = "";
	statBox.className = "statbox";
	statBox.innerHTML = "Please wait...";
	var ajaxRequest = new Ajax.Request("/websvcs/tokencmd.pl",
		{
			method: 'post',
			parameters: params,
			onSuccess: function(resp) {
				var response = resp.responseJSON;
				var statBox = $('statbox');
				busy = 0;
				statBox.style.display = 'none'; 
				if (response.errorcode) {
					statBox.className = "errorbox";
					if (response.usererror) {
						statBox.innerHTML = response.usererror;
					} else {
						statBox.innerHTML = "Unknown error modifying token";
					}
					statBox.style.display = '';
					return false;
				}
				if (response.success)  {
					token.status = newvalue;
					// If the token is successfully marked as destroyed,
					// unassign it
					if (newvalue == 'DESTROYED') {
						for (var i = 0; i < tokenList.length; i++) {
							if (tokenList[i] === token) {
								tokenList.splice(i, 1);
							}
						}
						displayTokenList(tokenList);
					}
					$('tokendetailbox').style.display = 'none';
				}
			},
			onFailure: function(resp) {
				fatalError(resp);
			}
		}
	);
}

function doTokenDetailEvent(event) {
	var tokenIndex = event.element().id;
	tokenIndex = tokenIndex.replace(/^tokenrow/, '');
	showTokenDetail(tokenIndex);
}

function doHistoryUserDetailEvent(event) {
	var userid = event.element()._userid;
	loadUser(userid, 'userid');
	closeHistory();
}

function doHistoryTokenDetailEvent(event) {
	var tokenid = event.element()._tokenid;
	getHistory(tokenid, 'tokenid');
}

function doTokenUnassignEvent(event) {
	var tokenIndex = event.element().id;
	tokenIndex = tokenIndex.replace(/^unassignbutton/, '');
	unassignToken(tokenIndex);
}

function displayTokenList (list) {
	var tt = $('tokentable');
	var rows = tt.childElements();
	for (var i = 0; i < rows.length; i++) {
		if (rows[i]) rows[i].remove();
	}
	var tbody = document.createElement('tbody');
	tt.appendChild(tbody);
	for (var i = 0; i < list.length; i++) {
		if (!list[i]) continue;
		var tr = document.createElement('tr');
		tbody.appendChild(tr);
		var td = document.createElement('td');
		tr.appendChild(td);
		var a = new Element('a',
			{
				'id' : 'tokenrow' + i,
				'href' : 'javascript:void(0);'
			}).update(list[i].serial);
		td.appendChild(a);
		// I fucking hate IE
		a.observe('click', doTokenDetailEvent);
		td = document.createElement('td');
		tr.appendChild(td);
		var button = new Element('input',
			{
				'id' : 'unassignbutton' + i,
				'type' : 'button',
				'value' : 'Unassign'
			});
		td.appendChild(button);
		button.observe('click', doTokenUnassignEvent);
	}
}

function setHistoryType(histtype) {
	if (histtype) {
		$('historytablediv')._historytype = histtype;
	}
}

function getHistoryType() {
	var histtype;
	try {
		histtype = $('historytablediv')._historytype;
	} catch (e) {
		histtype = 'unknown';
	}
	return histtype;
}

function displayHistory (list) {
	var tablediv = $('historytablediv');
	var rows = tablediv.childElements();
	for (var i = 0; i < rows.length; i++) {
		if (rows[i]) rows[i].remove();
	}
	if (!list) {
		document.createTextNode("No Events.");
		return;
	}
	var tt = document.createElement('table');
	tt.id = 'historytable';
	tt.className = 'scrollable';
	tablediv.appendChild(tt);
	var thead = document.createElement('thead');
	thead.className = 'scrollable';
	var tbody = document.createElement('tbody');
	tt.appendChild(thead);

	var tr;
	var td;
	var th;

	tr = document.createElement('tr');

	th = document.createElement('th');
	th.appendChild(document.createTextNode("Timestamp"));
	tr.appendChild(th);

	th = document.createElement('th');
	th.appendChild(document.createTextNode("Serial"));
	tr.appendChild(th);

	th = document.createElement('th');
	th.appendChild(document.createTextNode("Performer"));
	tr.appendChild(th);

	th = document.createElement('th');
	th.appendChild(document.createTextNode("Event"));
	tr.appendChild(th);

	thead.appendChild(tr);

	tt.appendChild(tbody);
	for (var i = 0; i < list.length; i++) {
		if (!list[i]) continue;

		tr = document.createElement('tr');
		if ( i % 2 ) {
			tr.className = 'alternateRow';
		}

		td = document.createElement('td');
		var timestamp = new Date(list[i].timestamp * 1000);
		td.appendChild(document.createTextNode(formatDate(timestamp)));
		tr.appendChild(td);

		td = document.createElement('td');

		var a = new Element('a',
			{
				'href' : 'javascript:void(0);'
			}).update(list[i].serial);
		a._tokenid = list[i].token_id;
		td.appendChild(a);
		// hate IE
		a.observe('click', doHistoryTokenDetailEvent);
		tr.appendChild(td);

		td = document.createElement('td');
		td.appendChild(document.createTextNode(list[i].actor));
		tr.appendChild(td);

		td = document.createElement('td');
		var eventStr = list[i].event;
		if (eventStr == 'Token Assigned') {
			eventStr += ' to ';
		}
		if (eventStr == 'Token Unassigned') {
			eventStr += ' from ';
		}
		if (eventStr == 'Status Changed') {
			eventStr += ' from ' + list[i].previous + ' to ' + list[i].current;
		}
		td.appendChild(document.createTextNode(eventStr));
		if (eventStr == 'Token Assigned to ' || 
				eventStr == 'Token Unassigned from ') {
			a = new Element('a',
				{
					'href' : 'javascript:void(0);'
				}).update(list[i].login);
			a._userid = list[i].system_user_id;
			td.appendChild(a);
			// hate IE
			a.observe('click', doHistoryUserDetailEvent);
		}

		tr.appendChild(td);

		tbody.appendChild(tr);
	}
	$('historydisplay').style.display = '';
}

function doLogout() {
	$('content').style.display = 'none';
	$('showlogout').style.display = '';
	document.cookie = logoutCookie;
}

function formatDate(timestamp) {
	var timeString = timestamp.getUTCFullYear() + '-';
	timeString += (timestamp.getUTCMonth() < 9 ? '0' : '') + 
		(timestamp.getUTCMonth() + 1) + '-';
	timeString += (timestamp.getUTCDate() < 10 ? '0' : '') +
		(timestamp.getUTCDate()) + ' ';
	timeString += (timestamp.getUTCHours() < 10 ? '0' : '') +
		(timestamp.getUTCHours()) + ':';
	timeString += (timestamp.getUTCMinutes() < 10 ? '0' : '') +
		(timestamp.getUTCMinutes()) + ':';
	timeString += (timestamp.getUTCSeconds() < 10 ? '0' : '') +
		(timestamp.getUTCSeconds());
	return timeString;
}	

$('login').focus();

//]]>
</script>
</body>
</html>

EOF

