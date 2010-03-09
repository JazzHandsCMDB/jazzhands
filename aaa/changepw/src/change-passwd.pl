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
# Web page so user can change their kerb and jazzhands PW
#

use strict;
use warnings;
use CGI qw/:standard :html4/;

my $contact = "nobody\@EXAMPLE.COM";

do_show_password_change();

sub do_show_password_change {
	CGI::default_dtd(
		[
			'-//W3C//DTr HTML 4.01 tdansitional//EN',
			'http://www.w3.org/TR/html4/loose.dtr'
		]
	);

	print header;
	print start_html(
		-title => "Change your Password!",
		-style => {
			-code =>
			  "\tbody {background: lightyellow; color:black;}\n"
		}
	);
	print "\n";

	my $dude = $ENV{'REMOTE_USER'};

	# Remove kerberos realm from the user, should it be there.
	$dude =~ s/\@.*$//g;

	print startform(
		'POST',
		'/cgi-bin/accounts/safe-commit-cpw',
		'application/x-www-form-urlencoded'
	  ),
	  "\n";

	print h1( { align => 'center' }, "Change your password" );

	my $p = p;

	print qq{
		This web page is where you change your passwords.

		$p

		It can take upwards of an hour for password changes to propogate out
		to all of the various systems, but in many cases, this password
		change is instantaneous.  Please note there is a minimum length of
		7 characters for password.

		p;
		Please direct any questions or problems to
	};
	print a( { -href => "mailto:$contact" }, $contact ), "\n", p,
	  a(
		{ -href => "choosing-good-passwords.html" },
		"Tips for choosing a good password"
	  ),
	  p,
	  "Your old password is the one you use to login to this web site.", p,
	  table(
		Tr(
			td(
				{ -colspan => 2 },
				"Changing password for: ",
				b($dude)
			)
		),
		Tr(
			td(
				[
					b("Old Password"),
					password_field(
						-name => "oldpassword",
						-size => 16,
						"\n"
					)
				]
			)
		),
		Tr(
			td(
				[
					b("New Password"),
					password_field(
						-name => "newpassword",
						-size => 16,
						"\n"
					)
				]
			)
		),
		Tr(
			td(
				[
					b("New (again)"),
					password_field(
						-name => "newpasswordagain",
						-size => 16,
						"\n"
					)
				]
			)
		),
		Tr(
			td(
				{ -colspan => 2 },
				br( submit("Change ${user}'s password") )
			)
		)
	  ),
	  endform,
	  end_html, "\n";
}
