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
# prompt a user for password changes.
#

use strict;
use CGI qw/:standard :html4/;

$contact = "nobody\@EXAMPLE.COM";

CGI::default_dtd(
	[
		'-//W3C//DTr HTML 4.01 tdansitional//EN',
		'http://www.w3.org/TR/html4/loose.dtr'
	]
);

print header;
print start_html(
	-title => "Set Your Network Device Password!",
	-style =>
	  { -code => "\tbody {background: lightyellow; color:black;}\n" }
);
print "\n";

my $user = $ENV{'REMOTE_USER'};

# Remove kerberos realm from the user, should it be there.
$user =~ s/\@.*$//g;

print startform(
	'POST',
	'/cgi-bin/accounts/safe-commit-cnpw',
	'application/x-www-form-urlencoded'
  ),
  "\n";

print table(
	{ -border => 0, -width => '70%' },
	Tr( td("JazzHands"), "\n" ),
	td( { -align => 'center' }, h1("Set Your Network Device Password") )
);

printf qq {
This web page allows you to change or set the password you use to log into
network devices that use TACACS+ or RADIUS for authentication.  This password
should not, and in fact may not, be the same as your Kerberos/system login
password. Your password must be at least 8 characters, and will also be
checked to ensure that it is a strong password.
<p>
Please see the <a href="choosing-good-passwords.html">Choosing Good
Passwords</a> document for information on choosing a strong password.
<p>
After changing your password, it may take up to 15 minutes for this to
be propagated to all authentication servers.  
<p>
Please direct any questions or problems to 
<a href="mailto:$contact">$contact</a>
<p>
Changing password for <b>%s</b>.
<p>
Please enter your <b>current Kerberos password</b> to authenticate yourself.
<p>
}, $user;
print br( "Current Kerberos Password:",
	  password_field(
		  -name => "k5password",
		  -size => 16,
		  "\n"
	  ) );
print br( "New Network Device Password:",
	  password_field(
		  -name => "newpassword",
		  -size => 16,
		  "\n"
	  ) );
print br( "New Network Device Password (again):",
	  password_field(
		  -onchange => "submit()",
		  -name     => "newpasswordagain",
		  -size     => 16,
		  "\n"
	  ) );

print br( submit("Change ${user}'s password") );

print endform, "\n";

print end_html, "\n";

