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

sub error {
	syslog( LOG_ERR, $_[0] );
}

sub getuserlist {
	openlog( "usernameautocomplete", "pid", LOG_LOCAL6 );

	my $string  = lc( param("username") );
	my $appuser = $ENV{'REMOTE_USER'};

	print header;

	if ( !$string ) {
		goto BAIL;
	}

	my $jh;
	if (
		!(
			$jh =
			JazzHands::Management->new( application => 'user-cpw' )
		)
	  )
	{
		error("unable to open connection to JazzHands");
		goto BAIL;
	}

	my $dbh = $jh->DBHandle;

	my $user;

	#
	# First determine whether our authenticated user is allowed to set
	# passwords
	#
	if ( !defined( $user = $jh->GetUser( login => $appuser ) ) ) {
		error( "unable to get user information for authenticated user "
			  . $appuser . ": "
			  . $jh->Error );
		goto BAIL;
	}
	if ( !ref($user) ) {
		error( "unable to get user information for authenticated user "
			  . $user );
	}

	my $perm;
	if (
		!(
			$perm = $jh->GetUserUclassPropertyValue(
				user => $user,
				name => "PasswordAdmin",
				type => "password"
			)
		)
	  )
	{
		if ( $jh->Error ) {
			error(
"unable to get user property information for authenticated user"
				  . $appuser . ": "
				  . $jh->Error );
		} else {
			error("user $appuser is not allowed to set passwords");
		}
		goto BAIL;
	}

      #
      # ... now determine whether the user that we're trying to set the password
      # for is allowed to have its password changed
      #

	my $userlist;

	if (
		!defined(
			$userlist = $jh->GetUsers(
				login        => $string,
				first        => $string,
				last         => $string,
				enabled_only => 1,
				fuzzy        => 1
			)
		)
	  )
	{
		error( "unable to get user list" . ": " . $jh->Error );
		goto BAIL;
	}

	if (@$userlist) {
		print "<ul>\n";
		foreach $user (@$userlist) {
			printf
q{    <li id="%d">%s<span class="informal"> - %s %s</span></li>}
			  . "\n",
			  $user->Id,
			  $user->Login,
			  ( $user->PreferredFirstName || $user->FirstName ),
			  ( $user->PreferredLastName  || $user->LastName );
		}
		print "</ul>\n";
	}
      BAIL:
	closelog;
	undef $jh;
}

&getuserlist;
