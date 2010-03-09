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
# commit a password change.
#

use strict;
use warnings;
use CGI qw/:standard :html4/;
use Krb5::Changepw;
use Crypt::Cracklib qw/check/;
use JazzHands::Management;

our $contact = 'jazzhands@EXAMPLE.COM';

do_change_pw();

sub describe_failure {
	my ( $msg, $tmpfail ) = @_;

	print h1("Password Change Failed!\n");
	print br;
	print "\n";
	print $msg, "\n";
	print br,
"Please contact <a href=\"$contact\">$contact</a> for assistance if this problem continues.\n"
	  if ($tmpfail);
	print end_html;
}

sub sanity_check {
	my ( $oldpw, $newpw, $newpw2 ) = @_;

	if ( !defined($oldpw) || !defined($newpw) ) {
		describe_failure(
			"You must specify both an old and a new password.\n");
		exit 0;
	}

	if ( !defined($newpw2) || $newpw ne $newpw2 ) {
		describe_failure(
			"Both values for the new password did not match.\n");
		exit 0;
	}

	if ( length($newpw) < 7 ) {
		describe_failure(
"Your new password must be at least seven characters long.\n"
		);
		exit 0;
	}

	if ( !check( $newpw, "/usr/local/lib/cracklib/pw_dict" ) ) {
		describe_failure("Your new password is too easy to guess.");
		exit 0;
	}
}

sub do_change_pw {

	my $oldpw  = param("oldpassword");
	my $newpw  = param("newpassword");
	my $newpw2 = param("newpasswordagain");

	sanity_check( $oldpw, $newpw, $newpw2 );

	my $user = $ENV{'REMOTE_USER'};

	# Remove kerberos realm from the user, if mod_auth_kerb set it.
	$user =~ s/\@.+$//g;

	print header;
	print start_html(
		-title => "Password Change Results",
		-style => {
			-code =>
			  "\tbody {background: lightyellow; color:black;}\n"
		}
	);
	my $rv = Krb5::Changepw::change_pw( $user, $oldpw, $newpw );

	if ( $rv == 0 ) {
		describe_failure("Your old password is incorrect.");
		print end_html;
		exit 0;
	} elsif ( $rv == -1 ) {
		print describe_failure(
"An unknown system error occured.  Please try again later."
		);
		exit 0;
	}

	my $jhpwchange = 0;
	my $dbh;

	my $userid;

	if (       ( $dbh = OpenJHDBConnection("web-cpw") )
		&& ( $userid = findUserIdFromlogin( $dbh, $user ) )
		&& ChangeUserPassword( $dbh, $userid, $newpw ) )
	{
		$jhpwchange = 1;
	} else {
		warn $JazzHands::Management::Errmsg;
	}

	my @whatfail;
	if ( !$jhpwchange ) {
		if (
			(
				Krb5::Changepw::change_pw( $user, $newpw,
					$oldpw )
			) <= 0
		  )
		{
			push( @whatfail, "Kerberos" );
		}
		if ( !( ChangeUserPassword( $dbh, $userid, $oldpw ) ) ) {
			push( @whatfail, "Kerberos" );
		}

		my $msg =
"There was an internal error changing your password, please try again later.";

		if ( $#whatfail >= 0 ) {
			$msg .= hw("WARNING!!!");
			$msg .=
"The following passwords were changed and could not be rolled back: "
			  . join( ", ", @whatfail );
		}
		describe_failure( $msg, 1 );
		print end_html;
		exit 0;
	}

	print h1("Password Change Succeeded!");

	print qq{
		Your password has been changed, but it may take upwards of a few
		hours for that to propogate to all systems.  If your old password
		continues to work after three hours, please contact $contact, and
		describe which password continues to work.
	};
	print end_html, "\n";
	exit 0;
}
