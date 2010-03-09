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
}

use strict;
use CGI qw(:standard);
use JazzHands::Management qw(:DEFAULT);
use Sys::Syslog qw(:standard :macros);
use Time::HiRes qw(tv_interval gettimeofday);
use DBD::Oracle ':ora_types';
use Data::Dumper;
use JazzHands::AuthToken;

sub error {
	syslog( LOG_ERR, @_ );

	#	printf STDERR @_;
}

sub _options {
	my %ret = @_;
	for my $v ( grep { /^-/ } keys %ret ) {
		$ret{ substr( $v, 1 ) } = $ret{$v};
	}
	\%ret;
}

sub authuser {
	openlog( "userenroll", "pid", LOG_LOCAL6 );

	my $usererror  = "Authentication failed";
	my $errorcode  = 'unspecified';
	my $fatalerror = 0;
	my ( $login, $authtype );
	if ( !( $login = lc( param('login') ) ) ) {
		error('login parameter must be set');
		$errorcode = 'fatal';
		goto BAIL;
	}
	$authtype = lc( param("authtype") ) || 'password';

	#
	# Authtype 'enroll' is special
	#
	my $otp1;
	my $otp2;
	my $password;
	my $status        = undef;
	my $authenticated = 0;
	if ( $authtype eq 'enroll' ) {
		if ( !defined( $otp1 = lc( param('otp1') ) ) ) {
			error('otp1 parameter must be set with authtype enroll'
			);
			$errorcode = 'fatal';
			goto BAIL;
		}
		if ( !defined( $otp2 = lc( param('otp2') ) ) ) {
			error('otp2 parameter must be set with authtype enroll'
			);
			$errorcode = 'fatal';
			goto BAIL;
		}
	} else {
		if ( !defined( $password = lc( param('password') ) ) ) {
			error( 'password parameter must be set with authtype '
				  . $authtype );
			$errorcode = 'fatal';
			goto BAIL;
		}
	}

	my $t0 = [gettimeofday];
	print header( -type => 'application/json' );

	my $jh;
	if (
		!(
			$jh = JazzHands::Management->new(
				application => 'jh_user_auth'
			)
		)
	  )
	{
		error("unable to open connection to JazzHands");
		$errorcode = 'fatal';
		goto BAIL;
	}

	my $dbh = $jh->DBHandle;

	my $user;

	if ( !defined( $user = $jh->GetUser( login => $login ) ) ) {
		error( "unable to get user information for authenticating user "
			  . $login . ": "
			  . $jh->Error );
		goto BAIL;
	}
	if ( !ref($user) ) {
		error( "unable to get user information for authenticated user "
			  . $user );
		goto BAIL;
	}

	if ( !$user->IsEnabled ) {
		error( "User %s is disabled", $user );
		goto BAIL;
	}

	my $authtoken;
	my $token;
	my $secondaryauthinfo;
	if ( $authtype eq 'enroll' ) {

		#
		# Determine if user is using a valid token
		#

		my $tokens =
		  JazzHands::Management::Token::GetTokenAssignments( $dbh,
			login => $login );

		if ( !@$tokens ) {
			error(
				sprintf(
"User %s attempted to enroll but has no tokens assigned",
					$login )
			);
		}

	    #		error(sprintf("tokens: %s", join(', ', map { $_->{token_serial} }
	    #			@$tokens)));
		foreach my $tok (@$tokens) {
			my $seq = JazzHands::Management::Token::FindHOTP(
				$dbh,
				token_id => $tok->{token_id},
				otp      => $otp1,
				noupdate => 1
			);

			#			if ($seq) {
			#				error(sprintf("Found sequence %d for %s",
			#					$seq,
			#					$tok->{token_serial}));
			#			} else {
			#				error(sprintf("Sequence not found for %s",
			#					$tok->{token_serial}));
			#			}

		    # First OTP didn't match this token, so this isn't the droid
		    # we're looking for

			next if ( !$seq );

		#
		# Check the second sequence number by specifically requesting
		# a check against the next sequence from the one returned above.
		# If this matches, the token is verified, and we want to have
		# the sequence in the database updated to match.
		#
			$seq = JazzHands::Management::Token::FindHOTP(
				$dbh,
				token_id => $tok->{token_id},
				otp      => $otp2,
				sequence => $seq + 1
			);

			# Second OTP didn't match this token

			next if ( !$seq );

			# Token sequences match

			if ( $tok->{token_pin} ) {
				$usererror = "User Already Enrolled";
				$errorcode = 'alreadyenrolled';
				goto BAIL;
			}

			$authenticated     = 1;
			$token             = $tok;
			$secondaryauthinfo = $token->{token_id};
			last;
		}
		if ( !$authenticated ) {
			goto BAIL;
		}
		my $auth;
		if ( !ref( $auth = new JazzHands::AuthToken ) ) {
			error( "Unable to initialize AuthToken object: "
				  . $auth );
			$errorcode = 'fatal';
			goto BAIL;
		}
		if (
			!(
				$authtoken = $auth->Create(
					login             => $login,
					authtype          => 'enroll',
					timeout           => 300,
					secondaryauthinfo => $secondaryauthinfo
				)
			)
		  )
		{
			error("Unable to set authentication token");
			$errorcode = 'fatal';
		}
		my ( $q, $sth );
		$q = q{
			SELECT 
				COUNT(*)
			FROM
				System_Password
			WHERE
				System_User_ID = :sysuid AND
				Password_Type IN ('blowfish', 'cca', 'des', 'md5',
					'sha1-nosalt')
		};
		if ( !( $sth = $dbh->prepare($q) ) ) {
			error( "Unable to fetch password information"
				  . $dbh->errstr );
			goto BAIL;
		}
		$sth->bind_param( ':sysuid', $user->Id );
		if ( !( $sth->execute ) ) {
			error( "Unable to fetch password information"
				  . $sth->errstr );
			goto BAIL;
		}
		my $pwcount = ( $sth->fetchrow_array )[0];
		$sth->finish;
		my $passwordsenrolled;
		if ( !$pwcount ) {
			$passwordsenrolled = 'none';
		} elsif ( $pwcount > 0 && $pwcount < 6 ) {
			$passwordsenrolled = 'partial';
		} else {
			$passwordsenrolled = 'full';
		}

		# See if the user has any questions enrolled
		$q = q{
			SELECT 
				COUNT(*)
			FROM
				System_User_Auth_Question
			WHERE
				System_User_ID = :sysuid
		};
		if ( !( $sth = $dbh->prepare($q) ) ) {
			error( "Unable to fetch question information: "
				  . $dbh->errstr );
			goto BAIL;
		}
		$sth->bind_param( ':sysuid', $user->Id );
		if ( !( $sth->execute ) ) {
			error( "Unable to fetch question information: "
				  . $sth->errstr );
			goto BAIL;
		}
		my $questcount = ( $sth->fetchrow_array )[0];
		$sth->finish;

		if ($authtoken) {
			printf '{
				authtoken: "%s",
				passwordsenrolled: "%s",
				questionsenrolled: %s
			}', $authtoken, $passwordsenrolled, $questcount ? "true" : "false";
			return;
		}
	}

      BAIL:
	if ($authtoken) {
		printf '{ authtoken: "%s" }', $authtoken;
		return;
	}
	if ($usererror) {
		printf q '{
			error: "%s",
			errorcode: "%s"
}', $usererror, $errorcode;
	}
	closelog;
	undef $jh;
}

&authuser;

