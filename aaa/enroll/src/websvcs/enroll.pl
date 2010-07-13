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
use JazzHands::Krb5::Tools;
use Authen::Krb5::Admin qw/:constants/;
use JazzHands::ActiveDirectory;
use JazzHands::AuthToken;
use JazzHands::PWVerify;
use JSON::XS;
use Sys::Syslog qw(:standard :macros);

#
# We should get these values from somewhere else.
#
my $ADMIN_PRINC = 'user_enroll@EXAMPLE.COM';
my $KEYTAB      = '/etc/krb5.keytab-user_enroll';
my $REALM       = 'EXAMPLE.COM';

openlog( "enroll", "pid", LOG_LOCAL6 );

sub _options {
	my %ret = @_;
	for my $v ( grep { /^-/ } keys %ret ) {
		$ret{ substr( $v, 1 ) } = $ret{$v};
	}
	\%ret;
}

sub loggit {
	syslog( LOG_ERR, @_ );
}

sub enroll {
	my $query    = new CGI;
	my $response = {
		errorcode       => 'unknown',
		usererror       => 'Unknown error',
		tokenpic        => 0,
		questions       => 0,
		passwordsSet    => [],
		passwordsNotSet => []
	};

	print header ( -type => 'application/json' );
	my $auth;
	if ( !( $auth = new JazzHands::AuthToken ) ) {
		loggit("Unable to initialize AuthToken object");
		$response->{usererror} = 'Not authorized';
		$response->{errorcode} = 'unauthorized';
		goto BAIL;
	}

	my $authtoken = $query->param("authtoken");

	my $userinfo;
	if ( !( $userinfo = $auth->Decode($authtoken) ) ) {
		loggit( "Unable to decode authentication token: "
			  . $auth->Error );
		$response->{usererror} = 'Invalid authorization';
		$response->{errorcode} = 'unauthorized';
		goto BAIL;
	}

	loggit( 'Enrolling user %s', $userinfo->{login} );

	if ( !( $userinfo->{secondaryauthinfo} > 0 ) ) {
		loggit( "authentication token for %s does not contain token id",
			$userinfo->{login} );
		$response->{usererror} = 'Invalid authorization';
		$response->{errorcode} = 'unauthorized';
		goto BAIL;
	}

	my $jh;
	if (
		!(
			$jh = JazzHands::Management->new(
				application => 'jh_user_enroll',
				dberrors    => 1
			)
		)
	  )
	{
		loggit("unable to open connection to JazzHands");
		$response->{usererror} = 'Database access error';
		$response->{errorcode} = 'fatal';
		goto BAIL;
	}

	my $dbh = $jh->DBHandle;
	my $user;
	if ( !defined( $user = $jh->GetUser( login => $userinfo->{login} ) ) ) {
		loggit( "Unable to fetch user %s: %s",
			$userinfo->{login}, $jh->Error );
		$response->{usererror} = 'Database access error';
		$response->{errorcode} = 'fatal';
		goto BAIL;
	}

	#
	# Verify that we're able to enroll this user.  The user has to be
	# enabled, not a pseudouser, and not have the AllowEnroll password
	# property set to false
	#
	if ( $user->Type eq "pseudouser" ) {
		error( "Attempting to enroll pseudouser %s",
			$userinfo->{login} );
		$response->{usererror} = 'You may not enroll a pseudouser';
		$response->{errorcode} = 'disallowed';
		goto BAIL;
	}

	if ( !$user->IsEnabled ) {
		error( "Attempting to enroll user %s, which is not enabled",
			$userinfo->{login} );
		$response->{usererror} = 'This user is not enabled';
		$response->{errorcode} = 'disallowed';
		goto BAIL;
	}

	#
	# Make sure the user is allowed to enroll
	#

	my ( $q, $sth );

	$q = q {
		SELECT
			Property_Value
		FROM
			V_User_Prop_Expanded
		WHERE
			System_User_ID = :sysuid AND
			Property_Type = 'TokenMgmt' AND
			Property_Name = 'GlobalAdmin'
	};

	if ( !( $sth = $dbh->prepare($q) ) ) {
		loggit( "Unable to prepare database query: " . $dbh->errstr );
		goto BAIL;
	}
	$sth->bind_param( ':sysuid', $user->Id );
	if ( !( $sth->execute ) ) {
		loggit( "Unable to execute database query: " . $sth->errstr );
		goto BAIL;
	}
	my $tokenlist;
	my $changeallowed = ( $sth->fetchrow_array )[0];
	$sth->finish;

	if ( defined($changeallowed) && !$changeallowed ) {
		loggit(
"Attempting to enroll user %s who has AllowEnroll set to false",
			$userinfo->{login}
		);
		$response->{usererror} =
		  'Enrollment has been disabled for this user';
		$response->{errorcode} = 'disallowed';
		goto BAIL;
	}

	#
	# Should probably re-check here whether this token is already enrolled
	#

	#
	# So now that we've verified that the user is able to enroll, verify
	# that the user has not enrolled before, and that we have all of the
	# information that we need to enroll
	#

	my $tokenpic = $query->param('tokenpic');
	if ( !$tokenpic ) {
		$response->{usererror} =
		  'Token PIC required for enrollment but not found';
		$response->{errorcode} = 'needpic';
		loggit( $response->{usererror} );
		goto BAIL;
	}

	#
	# Verify that the user has questions enrolled or that they are specified
	# in the enrollment form.
	#

	$q = q{
		SELECT 
			COUNT(*)
		FROM
			System_User_Auth_Question
		WHERE
			System_User_ID = :sysuid
	};
	if ( !( $sth = $dbh->prepare($q) ) ) {
		loggit( "Unable to fetch question information: "
			  . $dbh->errstr );
		goto BAIL;
	}
	$sth->bind_param( ':sysuid', $user->Id );
	if ( !( $sth->execute ) ) {
		loggit( "Unable to fetch question information: "
			  . $sth->errstr );
		goto BAIL;
	}
	my $questcount = ( $sth->fetchrow_array )[0];
	$sth->finish;

	# This really needs to be passed as an array.  Just sayin.

	my ( $q1id, $q1answer, $q2id, $q2answer );
	if ( !$questcount ) {
		$q1id     = $query->param("question1id");
		$q1answer = $query->param("question1answer");
		$q2id     = $query->param("question2id");
		$q2answer = $query->param("question2answer");

		if ( !$q1id || !$q2id || !$q1answer || !$q2answer ) {
			$response->{usererror} =
'Challenge questions needed for enrollment but not found';
			$response->{errorcode} = 'needquestions';
			loggit( $response->{usererror} );
			goto BAIL;
		}
	}

	my $password = $query->param('password');

	my @passwordstoset = qw(blowfish cca des md5 sha1-nosalt);

	$q = sprintf q{
		SELECT 
			COUNT(*)
		FROM
			System_Password
		WHERE
			System_User_ID = :sysuid AND
			Password_Type IN ('%s')
	}, join q{','}, @passwordstoset;

	if ( !( $sth = $dbh->prepare($q) ) ) {
		loggit( "Unable to fetch password information" . $dbh->errstr );
		goto BAIL;
	}
	$sth->bind_param( ':sysuid', $user->Id );
	if ( !( $sth->execute ) ) {
		loggit( "Unable to fetch password information" . $sth->errstr );
		goto BAIL;
	}
	my $pwcount = ( $sth->fetchrow_array )[0];
	$sth->finish;

	#
	# Only require a password if there are none set
	#
	if ( ( $pwcount == 0 ) && !$password ) {
		$response->{usererror} =
		  'Password required for enrollment but not found';
		$response->{errorcode} = 'needpassword';
		loggit( $response->{usererror} );
		goto BAIL;
	}

	# Check password strength, if the password is given
	if ($password) {
		if (
			my $rv = JazzHands::PWVerify::VerifyPassword(
				password => $password
			)
		  )
		{
			loggit(
'VerifyPassword returned error setting password for %s: %s',
				$userinfo->{login}, $rv
			);
			$response->{usererror} = $rv;
			$response->{errorcode} = 'passwordstrength';
			goto BAIL;
		}
	}

	# If we get here, all of the parameters we need to set are okay

	#
	# Set the token PIC/PIN
	#
	if (
		$jh->SetTokenPIN(
			token_id => $userinfo->{secondaryauthinfo},
			pin      => $tokenpic
		)
	  )
	{
		loggit(
			'Unable to set PIC for token %d for user %s: %s',
			$userinfo->{secondaryauthinfo},
			$userinfo->{login},
			$JazzHands::Management::Errmsg
		);
		$response->{errorcode} = 'fatal';
		$response->{usererror} = 'Error assigning token PIC';
		goto BAIL;
	} else {
		$response->{tokenpic} = 1;
	}

	if ( !$questcount ) {
		if (
			!$user->SetUserAuthQuestions(
				questions => {
					$q1id => $q1answer,
					$q2id => $q2answer
				}
			)
		  )
		{
			loggit(
'Unable to set auth question/answer pairs for %s: %s',
				$userinfo->{login}, $user->Error
			);
			$response->{errorcode} = 'fatal';
			$response->{usererror} =
			  'Error assigning questions to user account';
			goto BAIL;
		} else {
			$response->{questions} = 1;
		}
	}

	$response->{errorcode} = 'success';
	$response->{usererror} = '';

	#
	# From here on out, we're not returning hard errors to the calling
	# application.  We will just return whether each password was
	# successfully set or not
	#

	if ( !$password ) {
		goto BAIL;
	}
	my $adh;

	#
	# Set ActiveDirectory passwords, if it exists.  Account would have
	# already been created via external sync mechanisms
	#
	$adh = JazzHands::ActiveDirectory->new();
	if ( !ref($adh) ) {
		loggit( 'Unable to get AD handle: %s', $adh );
		push @{ $response->{passwordsNotSet} },
		  'Active Directory/Windows';
	} else {

	   #
	   # Try to get an AD account.  If there isn't one, don't worry about it
	   #

		my $dn;
		if ( !( $dn = $adh->GetUserByUID( $user->Id ) ) ) {

		      # Log, but don't tell user that his AD password wasn't set
			loggit( "No AD account for %s (id %d) - skipping",
				$user->Login, $user->Id );
		} elsif (
			!(
				$adh->setLDAPPassword(
					dn       => $dn,
					password => $password
				)
			)
		  )
		{
			loggit( "Error setting AD password for %s: %s",
				$userinfo->{login}, $adh->Error );
			push @{ $response->{passwordsNotSet} },
			  'Active Directory/Windows';
		} else {
			push @{ $response->{passwordsSet} },
			  'Active Directory/Windows';
		}
	}

	#
	# Set internal database password hashes
	#
	if ( !$user->SetPassword( password => $password ) ) {
		loggit( "Error setting JazzHands passwords for %s: %s",
			$user->Login, $user->Error );
		push @{ $response->{passwordsNotSet} }, 'JazzHands';
	} else {
		push @{ $response->{passwordsSet} }, 'JazzHands';
	}
	$jh->commit;

	#
	# Set up Kerberos principals
	#
	my $kadm = JazzHands::Krb5::Tools->new(
		user   => $ADMIN_PRINC,
		realm  => $REALM,
		keytab => $KEYTAB
	);

	if ( !ref($kadm) ) {
		loggit(
"Error getting Kerberos admin handle while enrolling %s: %s",
			$user->Login, $kadm
		);
		push @{ $response->{passwordsNotSet} }, 'Kerberos';
		goto KRBDONE;
	}

	if (
		!$kadm->SetPassword(
			user     => $user->Login,
			password => $password,
			realm    => $REALM
		)
	  )
	{
		loggit( "Error changing Kerberos password for %s: %s",
			$user->Login, $kadm->Error );
		push @{ $response->{passwordsNotSet} }, 'Kerberos';
	} else {
		push @{ $response->{passwordsSet} }, 'Kerberos';
	}

      KRBDONE:
	;
      BAIL:

	if ( $response->{errorcode} eq 'success' ) {
		loggit( 'User %s has successfully enrolled',
			$userinfo->{login} );
		$jh->commit;
	} elsif ($jh) {
		loggit( 'User %s was not enrolled', $userinfo->{login} );
		$jh->rollback;
	}
	undef $jh;

	print encode_json $response;
}

&enroll();
