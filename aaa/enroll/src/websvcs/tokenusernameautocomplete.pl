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
	if ( $dir =~ m,/, ) {
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
		unshift( @INC, "$dir/../../fakeroot.lib/$incentry" );
	}
	unshift( @INC, "$dir/../lib/lib" );
}

use strict;
use CGI qw(:standard);
use JazzHands::Management qw(:DEFAULT);
use Sys::Syslog qw(:standard :macros);
use Time::HiRes qw(tv_interval gettimeofday);
use DBD::Oracle ':ora_types';

sub error {
	syslog( LOG_ERR, $_[0] );

	#	print STDERR $_[0];
}

sub getuserlist {
	openlog( "tokenusernameautocomplete", "pid", LOG_LOCAL6 );

	my $string  = lc( param("login") );
	my $appuser = $ENV{'REMOTE_USER'};
	if ( !$string ) {
		$string = "mdr";
	}
	if ( !$appuser ) {
		$appuser = "mdr";
	}

	my $t0 = [gettimeofday];
	print header;

	if ( !$string ) {
		goto BAIL;
	}

	my $jh;
	if (
		!(
			$jh = JazzHands::Management->new(
				application => 'jh_websvcs_ro'
			)
		)
	  )
	{
		error("unable to open connection to JazzHands");
		goto BAIL;
	}

	my $dbh = $jh->DBHandle;

	my $user;

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

	#
	# First determine whether user can set all tokens
	#

	my $perm;
	my $sth;

	my $q = q {
		SELECT
			Property_Value
		FROM
			V_User_Prop_Expanded
		WHERE
			System_User_ID = :1 AND
			Property_Type = 'UserMgmt' AND
			Property_Name = 'GlobalTokenAdmin'
	};

	if ( !( $sth = $dbh->prepare($q) ) ) {
		error( "Unable to prepare database query: " . $dbh->errstr );
		goto BAIL;
	}
	if ( !( $sth->execute( $user->Id ) ) ) {
		error( "Unable to execute database query: " . $sth->errstr );
		goto BAIL;
	}
	my $userlist;
	$perm = ( $sth->fetchrow_array )[0];
	$sth->finish;
	if ( $perm && $perm eq 'Y' ) {
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
			error( "unable to get user list: " . $jh->Error );
			goto BAIL;
		}

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
	} else {
		$q = sprintf q {
			SELECT UNIQUE
				System_User_ID,
				Login,	 
				First_Name,
				Preferred_First_Name,
				Last_Name,
				Preferred_Last_Name
			FROM	
				V_User_Prop_Expanded UPE JOIN
				MV_Uclass_User_Expanded UUE ON
					(Property_Value_Uclass_ID = UUE.Uclass_Id) JOIN
				System_User SU ON (UUE.System_User_ID = SU.System_User_ID)
			WHERE   
				UPE.System_User_ID = :sysuid AND
				Property_Type = 'UserMgmt' AND
				Property_Name = 'TokenAdminForUclass'
		}, $user->Id;
		if ( !( $sth = $dbh->prepare($q) ) ) {
			error( "Unable to prepare database query: "
				  . $dbh->errstr );
			goto BAIL;
		}
		$sth->bind_param( ':sysuid', $user->Id, ORA_NUMBER );
		my $t = [gettimeofday];
		if ( !( $sth->execute ) ) {
			error( "Unable to execute database query: "
				  . $sth->errstr );
			goto BAIL;
		}
		print "<ul>\n";
		while ( my ( $uid, $login, $first, $pfirst, $last, $plast ) =
			$sth->fetchrow_array )
		{
			my $found = 0;
			foreach my $i ( $login, $first, $pfirst, $last, $plast )
			{
				next if !$i;
				next if ( ( index lc($i), $string ) < 0 );
				$found = 1;
			}
			next if !$found;
			printf
q{    <li id="%d">%s<span class="informal"> - %s %s</span></li>}
			  . "\n",
			  $uid,
			  $login,
			  $pfirst || $first,
			  $plast  || $last;
		}
		print "</ul>\n";
	}

      BAIL:
	closelog;
	undef $jh;
}

&getuserlist;
