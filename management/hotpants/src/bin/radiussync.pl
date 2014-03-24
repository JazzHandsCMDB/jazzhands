#!/usr/bin/env perl -w
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
	unshift( @INC, "$dir/../../../acct-mgmt/src/lib/lib/" );
}

use strict;
use HOTPants;
use Getopt::Long;
use JazzHands::Management;
use Data::Dumper;
use POSIX;

my $dbpath           = "/prod/hotpants/db";
my $verbose          = 0;
my $synctokens       = 1;
my $syncusers        = 1;
my $syncclients      = 1;
my $syncdevcollprops = 1;
my $syncattrs        = 1;
my $syncpasswds      = 1;

GetOptions(
	'dbpath=s'           => \$dbpath,
	'v|verbose+'         => \$verbose,
	'sync-tokens!'       => \$synctokens,
	'sync-users!'        => \$syncusers,
	'sync-clients!'      => \$syncclients,
	'sync-devcollprops!' => \$syncdevcollprops,
	'sync-passwds!'      => \$syncpasswds,
	'sync-attrs!'        => \$syncattrs,
);

my $err;
my $hostname = ( POSIX::uname() )[1];

my $hp = new HOTPants( path => $dbpath );
if ( !$hp ) {
	printf STDERR "Unable to get HOTPants handle\n";
	exit 1;
}

if ( $err = $hp->opendb ) {
	print STDERR $err . "\n";
	exit 1;
}

my $dbh = OpenJHDBConnection("tokensync") || die $DBI::errstr;
$dbh->{AutoCommit} = 0;

#
# First, sync all token data
#

if ($synctokens) {
	my $tokens =
	  JazzHands::Management::Token::GetAllTokens( $dbh, withkey => 1 );
	if ( !defined($tokens) ) {
		print STDERR $JazzHands::Management::Errmsg . "\n";
		exit 1;
	}

	printf STDERR "Updating %d tokens.\n", scalar( keys %$tokens )
	  if $verbose;
	foreach my $token ( values %$tokens ) {
		my $hptoken;
		if (
			!(
				$hptoken = $hp->fetch_token(
					token_id => $token->{token_id}
				)
			)
		  )
		{
			my $err = $hp->Error;
			if ($err) {
				printf STDERR
				  "Error fetching token from HP database: %s\n",
				  $hp->Error;
				next;
			}

		   #
		   # If there was not an error and we didn't fetch a token, then
		   # it must be a new token.  Write it.
		   #
			if ( $verbose > 1 ) {
				printf STDERR
				  "Writing new token %08x to local DB.\n",
				  $token->{token_id};
			}
			if ( !( $hp->put_token( token => $token ) ) ) {
				printf STDERR
"Error writing token %08x to HP database: %s\n",
				  $token->{token_id}, $hp->Error;
			}
			next;
		}
		my $token_changed   = 0;
		my $hptoken_changed = 0;

	  #
	  # The sequence_changed timestamp (probably really should be
	  # sequence_reset_timestamp) is only updated when it is changed
	  # administratively, usually when the token is reloaded and it is reset
	  # to zero, although it can also happen if the sequence gets out of
	  # whack and needs to jump way ahead.  Otherwise, believe whatever the
	  # largest sequence number is.
	  #

		if (
			( $token->{sequence} > $hptoken->{sequence} )
			|| ( $token->{sequence_changed} >
				$hptoken->{sequence_changed} )
		  )
		{
			if ( $verbose > 1 ) {
				printf STDERR
"Updating token %08x from sequence %d to %d\n",
				  $hptoken->{token_id}, $hptoken->{sequence},
				  $token->{sequence};
			}

			# Make sure the key is the same
			$hptoken->{key}      = $token->{key};
			$hptoken->{sequence} = $token->{sequence};
			$hptoken->{sequence_changed} =
			  $token->{sequence_changed};
			$hptoken_changed++;
		} elsif ( $token->{sequence} < $hptoken->{sequence} ) {
			if ( $verbose > 1 ) {
				printf STDERR
"Updating token %08x from sequence %d to %d in database\n",
				  $token->{token_id}, $token->{sequence},
				  $hptoken->{sequence};
			}
			$token_changed++;
			if (
				JazzHands::Management::Token::SetTokenSequence(
					$dbh,
					token_id => $token->{token_id},
					sequence => $hptoken->{sequence}
				)
			  )
			{
				printf STDERR
				  "Error setting token serial: %s\n",
				  $JazzHands::Management::Errmsg;
			}
		}

		#
		# Check the various lock parameters
		#

	       #
	       # If the token is no longer assigned, then reset the local status
	       #
		if ( !$token->{user_id} && $hptoken->{lock_status_changed} ) {
			$hptoken->{token_locked}        = 0;
			$hptoken->{bad_logins}          = 0;
			$hptoken->{unlock_time}         = 0;
			$hptoken->{lock_status_changed} = 0;
			$hptoken_changed++;
			if ( $verbose > 1 ) {
				printf STDERR
"Resetting lock parameters for unassigned token %08x in local db.\n",
				  $token->{token_id};
			}
		} elsif ( $token->{lock_status_changed} <
			$hptoken->{lock_status_changed} )
		{
			if ( $verbose > 1 ) {
				printf STDERR
"Updating lock parameters for token %08x in JazzHands: locked %s -> %d, bad logins: %d -> %d, unlock_time: %d -> %d\n",
				  $token->{token_id},
				  $token->{token_locked},
				  $hptoken->{token_locked},
				  $token->{bad_logins}, $hptoken->{bad_logins},
				  $token->{unlock_time},
				  $hptoken->{unlock_time};
			}
			if (
				JazzHands::Management::Token::SetTokenLockStatus(
					$dbh,
					token_id    => $hptoken->{token_id},
					locked      => $hptoken->{token_locked},
					bad_logins  => $hptoken->{bad_logins},
					unlock_time => $hptoken->{unlock_time},
					lock_status_changed =>
					  $hptoken->{lock_status_changed}
				)
			  )
			{
				printf STDERR
				  "Error setting token lock parameters: %s\n",
				  $JazzHands::Management::Errmsg;
			}
		} elsif ( $token->{lock_status_changed} >
			$hptoken->{lock_status_changed} )
		{
			$hptoken->{token_locked} = $token->{token_locked};
			$hptoken->{bad_logins}   = $token->{bad_logins};
			$hptoken->{unlock_time}  = $token->{unlock_time};
			$hptoken->{lock_status_changed} =
			  $token->{lock_status_changed};
			$hptoken_changed++;
			if ( $verbose > 1 ) {
				printf STDERR
"Updating lock parameters for token %08x in local db: locked %d -> %s, bad logins: %d -> %d, unlock_time: %s -> %s\n",
				  $token->{token_id},
				  $hptoken->{token_locked},
				  $token->{token_locked},
				  $hptoken->{bad_logins}, $token->{bad_logins},
				  $hptoken->{unlock_time}
				  ? scalar( localtime( $token->{unlock_time} ) )
				  : "Never",
				  $token->{unlock_time}
				  ? scalar(
					localtime( $hptoken->{unlock_time} ) )
				  : "Never";
			}
		}

	 #
	 # All of the other token parameters are only pulled from the database,
	 # and are essentially read-only.
	 #
	 # Time skew is not handled properly right now.  There needs to be a
	 # 'skew_last_updated' parameter added at some point.  Turns out,
	 # that isn't now, since we really don't handle time-based tokens, well,
	 # at all.
	 #

		if ( $token->{token_changed} > $hptoken->{token_changed} ) {
			if ( $hptoken->{type} != $token->{type} ) {
				if ( $verbose > 1 ) {
					printf STDERR
"Updating token %08x from type %d to %d\n",
					  $hptoken->{token_id},
					  $hptoken->{type}, $token->{type};
				}
				$hptoken->{type} = $token->{type};
			}
			if ( $token->{pin} && $hptoken->{pin} ne $token->{pin} )
			{
				if ( $verbose > 1 ) {
					printf STDERR
"Updating token %08x from PIN %s to %s\n",
					  $hptoken->{token_id}, $hptoken->{pin},
					  $token->{pin};
				}
				$hptoken->{pin} = $token->{pin};
			}
			if ( $token->{key} && $hptoken->{key} ne $token->{key} )
			{
				if ( $verbose > 1 ) {
					printf STDERR
"Updating token %08x key <omitted> to <omitted>\n",
					  $hptoken->{token_id};
				}
				$hptoken->{pin} = $token->{pin};
			}
			if ( $hptoken->{status} != $token->{status} ) {
				if ( $verbose > 1 ) {
					printf STDERR
"Updating token %08x from status %d to %d\n",
					  $hptoken->{token_id},
					  $hptoken->{status},
					  $token->{status};
				}
				$hptoken->{status} = $token->{status};
			}
			if ( $hptoken->{serial} ne $token->{serial} ) {
				if ( $verbose > 1 ) {
					printf STDERR
"Updating token %08x from serial %s to %s\n",
					  $hptoken->{token_id},
					  $hptoken->{serial},
					  $token->{serial};
				}
				$hptoken->{serial} = $token->{serial};
			}
			if ( $hptoken->{zero_time} != $token->{zero_time} ) {
				if ( $verbose > 1 ) {
					printf STDERR
"Updating token %08x from zero_time %d to %d\n",
					  $hptoken->{token_id},
					  $hptoken->{zero_time},
					  $token->{zero_time};
				}
				$hptoken->{zero_time} = $token->{zero_time};
			}
			if ( $hptoken->{time_modulo} != $token->{time_modulo} )
			{
				if ( $verbose > 1 ) {
					printf STDERR
"Updating token %08x from time_modulo %d to %d\n",
					  $hptoken->{token_id},
					  $hptoken->{time_modulo},
					  $token->{time_modulo};
				}
				$hptoken->{time_modulo} = $token->{time_modulo};
			}
			if ( $hptoken->{skew_sequence} != $token->{time_skew} )
			{
				if ( $verbose > 1 ) {
					printf STDERR
"Updating token %08x from skew_sequence %d to %d\n",
					  $hptoken->{token_id},
					  $hptoken->{skew_sequence},
					  $token->{time_skew};
				}
				$hptoken->{skew_sequence} = $token->{time_skew};
			}
			$hptoken->{token_changed} = $token->{token_changed};
			$hptoken_changed++;
		}

		if ($token_changed) {
			if ( $verbose > 1 ) {
				printf STDERR
"Committing changes to token %08x to JazzHands\n",
				  $token->{token_id};
			}
			$dbh->commit;
		}
		if ($hptoken_changed) {
			if ( $verbose > 1 ) {
				printf STDERR
"Committing changes to token %08x to local database\n",
				  $hptoken->{token_id};
			}
			if ( !( $hp->put_token( token => $token ) ) ) {
				printf STDERR
"Error writing token %08x to HP database: %s\n",
				  $token->{token_id}, $hp->Error;
			}
		}
	}

      #
      # At this point, we've pushed all changes from JazzHands down, but now we
      # need to determine if any tokens need to be deleted.  We don't worry
      # at this point if the token is assigned to a user, since that will get
      # cleaned up below.  If the user does try to authenticate with a token
      # between here and below, things will fail correctly, as the token doesn't
      # actually exist.
      #

	my $hptokens;
	if ( !defined( $hptokens = $hp->fetch_all_tokens ) ) {
		printf STDERR "Error fetching tokens from local database\n";
		exit 1;
	}

	foreach my $tokenid ( keys %$hptokens ) {
		if ( !$tokens->{$tokenid} ) {
			printf STDERR
			  "Deleting token %08x from local database\n", $tokenid
			  if $verbose > 1;
			$hp->delete_token( tokenid => $tokenid );
		}
	}
}

#
# Ok, tokens are done.  Now we sync the users
#

if ($syncusers) {
	my $usertokens =
	  JazzHands::Management::Token::GetAllTokenAssignments($dbh);
	if ( !defined($usertokens) ) {
		print STDERR $JazzHands::Management::Errmsg . "\n";
		exit 1;
	}

	my $sth;
	if (
		!(
			$sth = $dbh->prepare(
				qq {
			SELECT
				System_User_ID,
				Login,
				System_User_Status
			FROM
				System_User
			}
			)
		)
	  )
	{
		printf STDERR "Error preparing database query: %s\n",
		  $dbh->errstr;
		exit -1;
	}
	if ( !( $sth->execute ) ) {
		printf STDERR "Error executing user query: %s\n",
		  $dbh->errstr;
		exit -1;
	}

	my $jhuser = {};
	$jhuser->{byuid}   = {};
	$jhuser->{bylogin} = {};

	while ( my @row = $sth->fetchrow_array ) {
		my $userhash = {};
		$jhuser->{byuid}->{ $row[0] }   = $userhash;
		$jhuser->{bylogin}->{ $row[1] } = $userhash;
		$userhash->{userid}             = $row[0];
		$userhash->{login}              = $row[1];
		$userhash->{status}             = $row[2];
	}
	$sth->finish;

	if (
		!(
			$sth = $dbh->prepare(
				qq {
			SELECT
				System_User_ID,
				Time_Util.Epoch(MAX(System_User_Auth_TS)) AS Last_Login
			FROM
				System_User_Auth_Log
			WHERE
				Auth_Resource = 'radius'
			GROUP BY
				System_User_ID
			}
			)
		)
	  )
	{
		printf STDERR "Error preparing system user database query: %s\n",
		  $dbh->errstr;
		exit -1;
	}
	if ( !( $sth->execute ) ) {
		printf STDERR "Error executing database query: %s\n",
		  $dbh->errstr;
		exit -1;
	}

	while ( my @row = $sth->fetchrow_array ) {
		$jhuser->{byuid}->{ $row[0] }->{last_login} = $row[1];
	}
	$sth->finish;

	if (
		!(
			$sth = $dbh->prepare(
				qq {
			INSERT INTO System_User_Auth_Log (
				System_User_ID,
				System_User_Auth_TS,
				Was_Auth_Success,
				Auth_Resource,
				Auth_Resource_Instance,
				Auth_Origin
			) VALUES (
				:userid,
				TO_DATE(:lastlog, 'YYYY-MM-DD HH24:MI:SS'),
				'Y',
				'radius',
				:hostname,
				'127.0.0.1'
			)
			}
			)
		)
	  )
	{
		printf STDERR "Error preparing database query: %s\n",
		  $dbh->errstr;
		exit -1;
	}

	printf STDERR "Updating %d users.\n",
	  scalar( keys %{ $jhuser->{byuid} } )
	  if $verbose;
	foreach my $userid ( keys %{ $jhuser->{byuid} } ) {

		#
		# First, see if the user is in the local database
		#

		my $user = $jhuser->{byuid}->{$userid};

		my $status;
		if ( IsUserEnabled( $user->{status} ) ) {
			$status = US_ENABLED;
		} else {
			$status = US_DISABLED;
		}

		my $hpuser;
		if ( !( $hpuser = $hp->fetch_user( login => $user->{login} ) ) )
		{
			my $err = $hp->Error;
			if ($err) {
				printf STDERR
				  "Error fetching user %s from database: %s\n",
				  $user->{login}, $err;
				exit 1;
			}
		}

		if ( !$hpuser ) {

			#
			# User does not exist in local database
			#
			my $hpuser = {
				login        => $user->{login},
				status       => $status,
				last_login   => 0,
				user_changed => scalar( time() ),
				tokens       => []
			};
			foreach my $token ( @{ $usertokens->{$userid} } ) {
				push @{ $hpuser->{tokens} }, $token->{token_id};
			}
			printf STDERR
"Inserting user %s into local database, tokenids: %s\n",
			  $hpuser->{login}, ( join ",", @{ $hpuser->{tokens} } )
			  if $verbose > 1;
			if ( !( $hp->put_user($hpuser) ) ) {
				printf STDERR
				  "Error writing user %s to local database: %s",
				  $hpuser->{login},
				  $hp->Error;
			}
		} else {

		#
		# Update user parameters, if needed.  All user parameters except
		# last login are only updated downstream.
		#
			my $hpuser_updated = 0;
			if ( $hpuser->{status} != $status ) {
				if ( $verbose > 1 ) {
					printf STDERR
"Updating user %s from status %d to %d\n",
					  $hpuser->{login}, $hpuser->{status},
					  $status;
				}
				$hpuser->{status} = $status;
				$hpuser_updated++;
			}

			if (
				(
					  !$user->{last_login}
					&& $hpuser->{last_login}
				)
				|| (       $hpuser->{last_login}
					&& $hpuser->{last_login} >
					$user->{last_login} )
			  )
			{
				my ( $sec, $min, $hour, $mday, $mon, $year ) =
				  gmtime( $hpuser->{last_login} );
				my $lastlog = sprintf(
					"%04d-%02d-%02d %02d:%02d:%02d",
					$year + 1900,
					$mon + 1, $mday, $hour, $min, $sec
				);
				if ( $verbose > 1 ) {
					printf STDERR
"Updating user last login for %s to %s\n",
					  $hpuser->{login}, $lastlog;
				}
				$sth->bind_param( ':userid',   $userid );
				$sth->bind_param( ':hostname', $hostname );
				$sth->bind_param( ':lastlog',  $lastlog );
				if ( !( $sth->execute ) ) {
					printf STDERR
"Error executing database query: %s\n",
					  $dbh->errstr;
					exit -1;
				}

			}

			#
			# Check to see if any tokens have changed
			#
			my $changed = 0;
			my @tokenlist;
			if ( $usertokens->{$userid} ) {
				@tokenlist =
				  map { $_->{token_id} }
				  @{ $usertokens->{$userid} };
			}

	    #
	    # If we don't have the same number of tokens, they obviously differ.
	    #
			if ( @tokenlist == @{ $hpuser->{tokens} } ) {
				my @tokarray1 = sort @tokenlist;
				my @tokarray2 = sort @{ $hpuser->{tokens} };
				while ( my $t1 = shift @tokarray1 ) {
					my $t2 = shift @tokarray2;
					if ( $t1 != $t2 ) {
						$changed++;
						last;
					}
				}
			} else {
				$changed++;
			}

			if ($changed) {
				if ( $verbose > 1 ) {
					printf STDERR
"Tokens for user %s changed from (%s) to (%s)\n",
					  $hpuser->{login},
					  join( ",", @{ $hpuser->{tokens} } ),
					  join( ",", @tokenlist );
				}

		 #
		 # Note, this just changes the reference.  You really don't want
		 # to modify $user->{tokens} after this.  Just sayin'.
		 #
				$hpuser->{tokens} = \@tokenlist;
				$hpuser_updated++;
			}

			if ($hpuser_updated) {
				printf STDERR
"Updating user %s into local database, tokenids: %s\n",
				  $user->{login}, ( join ",", @tokenlist )
				  if $verbose > 1;
				if ( !( $hp->put_user($hpuser) ) ) {
					printf STDERR
"Error writing user %s to local database: %s",
					  $user->{login}, $hp->Error;
				}
			}
		}
	}

    # At this point, every user who is in JazzHands has been synchronized, but
    # we need to make a pass through to ensure that we don't have any users in
    # the database who aren't in JazzHands because they were purged or whatever.

	my $hpusers;
	if ( !defined( $hpusers = $hp->fetch_all_users() ) ) {
		printf STDERR "Unable to get users from local database: %s\n",
		  $hp->Error;
		exit 1;
	}

	foreach my $login ( keys %$hpusers ) {
		if ( !$jhuser->{bylogin}->{$login} ) {
			printf STDERR "Deleting user %s from local database.\n",
			  $login
			  if $verbose > 1;
			$hp->delete_user($login);
		}
	}
}

if ($syncclients) {
	my ( $q, $sth );

	#
	# Get IP-to-device collection information
	#
	$q = qq {
		SELECT UNIQUE
			Device_Id,
			Device_Name,
			Device_Collection_Id,
			Device_Collection.Name,
			Device_Collection_Type,
			IP_Address
		FROM	
			Device_Collection JOIN device_collection_device
				USING (Device_Collection_ID) JOIN
			Device USING (Device_Id) LEFT JOIN
			Device_Function USING (Device_ID) LEFT JOIN
			Network_Interface NI USING (Device_ID) LEFT JOIN
			Netblock NB ON
				(NI.Netblock_Id = NB.Netblock_ID)
		WHERE
			Device_Collection_Type = 'mclass' AND
			Device_Name IS NOT NULL AND
			Status = 'up'
	};

	if ( !( $sth = $dbh->prepare($q) ) ) {
		printf STDERR "Error preparing IP-to-devcoll query: %s\n",
		  $dbh->errstr;
		exit 1;
	}

	if ( !( $sth->execute ) ) {
		printf STDERR "Error executing IP-to-devcoll query: %s\n",
		  $sth->errstr;
		exit 1;
	}

	my $clients = {};
	while (
		my (
			$devid,       $devname,     $devcollid,
			$devcollname, $devcolltype, $ip
		)
		= $sth->fetchrow_array
	  )
	{

		#
		# If this interface doesn't have an IP address, skip it
		#
		next if ( !$ip );
		my $client_id = join '.',
		  $ip >> 24 & 0xff,
		  $ip >> 16 & 0xff,
		  $ip >> 8 & 0xff,
		  $ip & 0xff;
		$clients->{$client_id} = {
			client_id    => $client_id,
			name         => $devname,
			devcoll_id   => $devcollid,
			devcoll_name => $devcollname,
			devcoll_type => $devcolltype
		};
	}

	$sth->finish;

	#
	# Get application-to-device collection information
	#
	$q = qq {
		SELECT UNIQUE
			Device_Collection_Id,
			Device_Collection.Name,
			Device_Collection.Description,
			Device_Collection_Type
		FROM	
			Device_Collection
		WHERE
			Device_Collection_Type = 'radius_app'
	};

	if ( !( $sth = $dbh->prepare($q) ) ) {
		printf STDERR "Error preparing app-to-devcoll query: %s\n",
		  $dbh->errstr;
		exit 1;
	}

	if ( !( $sth->execute ) ) {
		printf STDERR "Error executing app-to-devcoll query: %s\n",
		  $sth->errstr;
		exit 1;
	}

	while ( my ( $devcollid, $devcollname, $devcolldesc, $devcolltype ) =
		$sth->fetchrow_array )
	{

		my $client_id = $devcollname;
		$clients->{$client_id} = {
			client_id    => $client_id,
			name         => $devcolldesc || $devcollname,
			devcoll_id   => $devcollid,
			devcoll_name => $devcollname,
			devcoll_type => $devcolltype
		};
	}
	$sth->finish;

	printf STDERR "Updating %d clients.\n", scalar( keys %{$clients} )
	  if $verbose;

	foreach my $client ( values %{$clients} ) {
		my $client_id = $client->{client_id};
		if ( $verbose > 2 ) {
			printf "%s: %s (%d - %s - %s)\n",
			  $client->{client_id},
			  $client->{name},
			  $client->{devcoll_id},
			  $client->{devcoll_name},
			  $client->{devcoll_type};
		}

		my $hpclient;
		if (
			!(
				$hpclient =
				$hp->fetch_client( client_id => $client_id )
			)
		  )
		{
			my $err = $hp->Error;
			if ($err) {
				printf STDERR
"Error fetching client %s from database: %s\n",
				  $client_id, $err;
				exit 1;
			}
		}

		if ( !$hpclient ) {
			printf STDERR
			  "Inserting client %s into local database: %s\n",
			  $client_id, $client->{name}
			  if $verbose > 1;
			if ( !( $hp->put_client($client) ) ) {
				printf STDERR
"Error writing client %s (%s) to local database: %s\n",
				  $client_id,
				  $client->{name},
				  $hp->Error;
			}
			next;
		}

		my $changed = 0;

		foreach my $field ( "name", "devcoll_id", "devcoll_name",
			"devcoll_type" )
		{
			if ( $hpclient->{$field} ne $client->{$field} ) {
				printf STDERR
				  "Client %s changed %s from %s to %s\n",
				  $client_id,
				  $field, $hpclient->{$field}, $client->{$field}
				  if $verbose > 1;
				$changed++;
			}
		}

		if ($changed) {
			printf STDERR "Updating client %s: %s\n",
			  $client_id, $client->{name}
			  if $verbose > 1;
			if ( !( $hp->put_client($client) ) ) {
				printf STDERR
"Error writing client %s (%s) to local database: %s\n",
				  $client_id,
				  $client->{name},
				  $hp->Error;
			}
		}
	}

	# Delete clients that have been deactivated/purged/vv

	my $hpclients;
	if ( !defined( $hpclients = $hp->fetch_all_clients() ) ) {
		printf STDERR "Unable to get clients from local database: %s\n",
		  $hp->Error;
		exit 1;
	}

	foreach my $client_id ( keys %$hpclients ) {
		if ( !$clients->{$client_id} ) {
			printf STDERR
			  "Deleting client %s (%s) from local database.\n",
			  $client_id, ( $hpclients->{name} || "" )
			  if $verbose > 1;
			$hp->delete_client($client_id);
		}
	}
}

if ($syncdevcollprops) {
	my ( $q, $sth );

	#
	# Get device collection properties (currently only password type)
	#
	$q = qq {
		SELECT
			Device_Collection_Id,
			Property_Value_Password_Type
		FROM	
			Property
		WHERE
			Property_Name = 'UnixPwType'
		AND
			Property_Type = 'MclassUnixProp'
	};

	if ( !( $sth = $dbh->prepare($q) ) ) {
		printf STDERR "Error preparing devcoll prop query: %s\n",
		  $dbh->errstr;
		exit 1;
	}

	if ( !( $sth->execute ) ) {
		printf STDERR "Error executing devcoll prop query: %s\n",
		  $sth->errstr;
		exit 1;
	}

	my $props = {};
	while ( my ( $devcollid, $pwtype ) = $sth->fetchrow_array ) {
		my $prop = {};
		$props->{$devcollid}               = $prop;
		$props->{$devcollid}->{devcoll_id} = $devcollid;
		$props->{$devcollid}->{pwtype}     = $pwtype;
	}

	printf STDERR "Updating %d device collection properties.\n",
	  scalar( keys %$props )
	  if $verbose;

	foreach my $devcollid ( keys %$props ) {
		my $prop = $props->{$devcollid};
		my $hpprop;
		if (
			!(
				$hpprop = $hp->fetch_devcollprop(
					devcoll_id => $devcollid
				)
			)
		  )
		{
			my $err = $hp->Error;
			if ($err) {
				printf STDERR
"Error fetching devcollprop for %d from database: %s\n",
				  $devcollid, $err;
				exit 1;
			}

			printf STDERR
			  "Inserting devcollprop for %d into local database\n",
			  $devcollid
			  if $verbose > 1;
			if ( !( $hp->put_devcollprop( $props->{$devcollid} ) ) )
			{
				printf STDERR
"Error writing devcollprop for %d to local database: %s\n",
				  $devcollid,
				  $hp->Error;
			}
			next;
		}

		my $changed = 0;

		foreach my $field ("pwtype") {
			if ( $hpprop->{$field} ne $prop->{$field} ) {
				printf STDERR
				  "%d: property changed %s from %s to %s\n",
				  $devcollid,
				  $field, $hpprop->{$field}, $prop->{$field}
				  if $verbose > 1;
				$changed++;
			}
		}

		if ($changed) {
			printf STDERR "Updating properties for devcoll %d\n",
			  $devcollid
			  if $verbose > 1;
			if ( !( $hp->put_devcollprop($prop) ) ) {
				printf STDERR
"Error writing devcollprop for %d to local database: %s\n",
				  $devcollid,
				  $hp->Error;
			}
		}
	}
	$sth->finish;

	# Delete devcolls that have been deactivated/purged/vv

	my $hpprops;
	if ( !defined( $hpprops = $hp->fetch_all_devcollprops() ) ) {
		printf STDERR
		  "Unable to get properties from local database: %s\n",
		  $hp->Error;
		exit 1;
	}

	foreach my $devcollid ( keys %$hpprops ) {
		if ( !$props->{$devcollid} ) {
			printf STDERR
			  "Deleting devcoll %d from local database.\n",
			  $devcollid
			  if $verbose > 1;
			$hp->delete_devcollprop($devcollid);
		}
	}
}

if ($syncpasswds) {
	my ( $q, $sth );

	#
	# Get all passwords for users
	#
	$q = qq {
		SELECT
			Login,
			Password_Type,
			User_Password,
			Time_Util.Epoch(Change_Time),
			Time_Util.Epoch(Expire_Time)
		FROM	
			System_User JOIN
			System_Password USING (System_User_ID)
	};

	if ( !( $sth = $dbh->prepare($q) ) ) {
		printf STDERR "Error preparing passwd query: %s\n",
		  $dbh->errstr;
		exit 1;
	}

	if ( !( $sth->execute ) ) {
		print STDERR "Error executing passwd query: %s",
		  $sth->errstr;
		exit 1;
	}

	my $passwds = {};
	while ( my ( $login, $pwtype, $pass, $change, $expire ) =
		$sth->fetchrow_array )
	{
		if ( !$passwds->{$login} ) {
			$passwds->{$login} = {};
		}
		$passwds->{$login}->{$pwtype} = {
			passwd      => $pass,
			change_time => $change || 0,
			expire_time => $expire || 0
		};
	}
	$sth->finish;

	printf STDERR "Updating passwords for %d users.\n",
	  scalar( keys %$passwds )
	  if $verbose;

	foreach my $login ( keys %{$passwds} ) {
		my $hppasswd;
		my $passwd = $passwds->{$login};
		printf STDERR "Syncing passwords for %s\n", $login
		  if $verbose > 2;
		if ( !( $hppasswd = $hp->fetch_passwd( login => $login ) ) ) {
			my $err = $hp->Error;
			if ($err) {
				printf STDERR
"Error fetching passwd for %s from database: %s\n",
				  $login, $err;
				exit 1;
			}

			printf STDERR
			  "Inserting passwd for %s into local database\n",
			  $login
			  if $verbose > 1;
			if ( !( $hp->put_passwd( $login, $passwd ) ) ) {
				printf STDERR
"Error writing passwd for %s to local database: %s\n",
				  $login,
				  $hp->Error;
			}
			next;
		}

		my $changed = 0;

		if ( $verbose > 2 ) {
			print STDERR "JazzHands: ", Dumper($passwd);
			print STDERR "HOTPants : ", Dumper($hppasswd);
		}

		if ( keys %$hppasswd == keys %$passwd ) {
			foreach my $type ( keys %$passwd ) {
				if ( $hppasswd->{$type} ) {
					foreach
					  my $field ( "passwd", "change_time",
						"expire_time" )
					{
						if ( $hppasswd->{$type}
							->{$field} ne
							$passwd->{$type}
							->{$field} )
						{
							printf STDERR
"passwd type %s for user %s changed %s from %s to %s\n",
							  $type,
							  $login,
							  $field,
							  $hppasswd->{$type}
							  ->{$field},
							  $passwd->{$type}
							  ->{$field}
							  if $verbose > 1;
							$changed++;
						}
					}
				} else {
					printf STDERR
					  "New password type %s for %s.\n",
					  $type, $login
					  if $verbose > 1;
					$changed++;
				}
			}
		} else {
			printf STDERR
			  "Different number of password types for %s.\n", $login
			  if $verbose > 1;
			$changed++;
		}

		if ($changed) {
			printf STDERR "Updating passwd for %s\n", $login
			  if $verbose > 1;
			if ( !( $hp->put_passwd( $login, $passwd ) ) ) {
				printf STDERR
"Error writing passwd for %s to local database: %s\n",
				  $login,
				  $hp->Error;
			}
		}
	}

	# Delete logins that have been deactivated/purged/vv

	my $hppasswds;
	if ( !defined( $hppasswds = $hp->fetch_all_passwds() ) ) {
		printf STDERR "Unable to get passwds from local database: %s\n",
		  $hp->Error;
		exit 1;
	}

	foreach my $login ( keys %$hppasswds ) {
		if ( !defined( $passwds->{$login} ) ) {
			printf STDERR
			  "Deleting passwd for %s from local database.\n",
			  $login
			  if $verbose > 1;
			$hp->delete_passwd($login);
		}
	}
}

if ($syncattrs) {
	my ( $q, $sth );

	#
	# The really fun one.  Sync attributes
	#
	$q = qq {
		SELECT
			Login,
			Property_Name,
			Property_Type,
			Property_Value,
			Is_Multivalue,
			Is_Boolean,
			Device_Collection_ID
		FROM
			V_Dev_Col_User_Prop_Expanded JOIN
			Device_Collection USING (Device_Collection_ID)
		WHERE
			System_User_Status IN ('enabled') AND
			(Device_Collection_Type = 'radius_app' OR
			Property_Type = 'RADIUS')
	};

       #
       # The way the attribute view works is this:
       #
       # Rows are ordered so that the first attribute in a user/uclass/name/type
       # tuple takes precendence.  If the attribute is single-valued, then
       # the first attribute is the daddy.  If it is multi-valued, then all
       # values for the tuple are put into an array, elmininating duplicates.
       #
       # Since the view expands all uclass, department, and device_collection
       # hierarchies, there can be a *lot* of values.  We are reducing this
       # somewhat by only caring about attributes given to 'radius_app' type
       # device collections, or specific RADIUS attributes.
       #
	if ( !( $sth = $dbh->prepare($q) ) ) {
		printf STDERR "Error preparing attribute query: %s\n",
		  $dbh->errstr;
		exit 1;
	}

	if ( !( $sth->execute ) ) {
		printf STDERR "Error executing attribute query: %s\n",
		  $sth->errstr;
		exit 1;
	}

	my $attributes = {};
	while (
		my (
			$login,      $propname, $proptype, $propval,
			$multivalue, $boolean,  $devcollid
		)
		= $sth->fetchrow_array
	  )
	{

		#
		# Intercept specific attributes that we want to rewrite to
		# internal attributes
		#
		if ( $proptype eq 'RADIUS' && $propname eq 'GrantAccess' ) {
			$proptype = '__HOTPANTS_INTERNAL';
		}
		if ( $proptype eq 'RADIUS' && $propname eq 'PWType' ) {
			$proptype = '__HOTPANTS_INTERNAL';
		}

	      # process things that are completely stupid, like the
	      # cisco-avpair-shell attribute, which is itself an attribute-value
	      # pair

		if ( $proptype eq 'RADIUS'
			&& ( ( my $i = index( $propname, '=' ) ) >= 0 ) )
		{
			$propval = substr( $propname, $i + 1 ) . '=' . $propval;
			$propname = substr( $propname, 0, $i );
		}

		my $key = pack( "Z*N", $login, $devcollid );
		if ( !$attributes->{$key} ) {
			$attributes->{$key} = {};
		}
		if ( !$attributes->{$key}->{$proptype} ) {
			$attributes->{$key}->{$proptype} = {};
		}
		if ( !$attributes->{$key}->{$proptype}->{$propname} ) {
			$attributes->{$key}->{$proptype}->{$propname} =
			  { multivalue => $multivalue };
		}
		my $attribute = $attributes->{$key}->{$proptype}->{$propname};

		if ($boolean) {
			if ( $propval eq 'Y' ) {
				$propval = 1;
			} else {
				$propval = 0;
			}
		}

	     # Skip this if we already have an attribute and it's not multivalue

		if ( defined( $attribute->{value} ) ) {
			if ( !$multivalue ) {
				printf STDERR
"Skipping attr %s, type %s for devcoll %d for user %s because it is already assigned and not multivalue",
				  $propname, $proptype, $devcollid, $login
				  if $verbose > 2;
				next;
			} else {
				if ( !grep { $_ eq $propval }
					@{ $attribute->{value} } )
				{
					push @{ $attribute->{value} }, $propval;
				}
				next;
			}
		} else {
			if ($multivalue) {
				$attribute->{value} = [$propval];
			} else {
				$attribute->{value} = $propval;
			}
		}
	}
	$sth->finish;

	printf STDERR
	  "Updating user attributes for %d user/device collection pairs.\n",
	  scalar( keys %$attributes )
	  if $verbose;

	foreach my $key ( keys %{$attributes} ) {
		my $hpattr;
		my ( $login, $devcollid ) = unpack( "Z*N", $key );
		my $attr = $attributes->{$key};
		printf STDERR "Syncing attributes for %s, devcoll %d\n",
		  $login, $devcollid
		  if $verbose > 2;
		if ( !( $hpattr = $hp->fetch_attributes( key => $key ) ) ) {
			my $err = $hp->Error;
			if ($err) {
				printf STDERR
"Error fetching attributes for %s, devcoll %d from database: %s\n",
				  $login, $devcollid, $err;
				exit 1;
			}

			printf STDERR
"Inserting attributes for %s, devcoll %d into local database\n",
			  $login, $devcollid
			  if $verbose > 1;
			if (
				!(
					$hp->put_attributes(
						key   => $key,
						attrs => $attr
					)
				)
			  )
			{
				printf STDERR
"Error writing attrbutes for %s, devcoll %d to local database: %s\n",
				  $login,
				  $devcollid,
				  $hp->Error;
			}
			next;
		}

		my $changed = 0;

		if ( $verbose > 2 ) {
			print STDERR "JazzHands: ", Dumper($attr);
			print STDERR "HOTPants: ",  Dumper($hpattr);
		}

		if ( keys %$hpattr == keys %$attr ) {
			foreach my $type ( keys %$attr ) {
				if ( $hpattr->{$type} ) {
					if (
						keys %{ $hpattr->{$type} } !=
						keys %{ $attr->{$type} } )
					{
						printf STDERR
"Different number of attributes of type %s for %s, devcoll %d\n",
						  $type,
						  $login,
						  $devcollid;
						$changed++;
						last;
					}
					foreach my $attrname (
						keys %{ $attr->{$type} } )
					{
						if (
							!defined(
								$hpattr->{$type}
								  ->{$attrname}
							)
						  )
						{
							printf STDERR
"New attribute %s for %s, devcoll %d.\n",
							  $attrname,
							  $login, $devcollid
							  if $verbose > 1;
							$changed++;
							last;
						}
						if ( $attr->{$type}->{$attrname}
							->{multivalue} )
						{
							if ( !$hpattr->{$type}
								->{$attrname}
								->{multivalue} )
							{
								$changed++;
								last;
							}
							my $vals =
							  $attr->{$type}
							  ->{$attrname}
							  ->{value};
							my $hpvals =
							  $hpattr->{$type}
							  ->{$attrname}
							  ->{value};
							if ( @{$vals} !=
								@{$hpvals} )
							{
								$changed++;
								last;
							}
							foreach
							  my $val ( @{$vals} )
							{
								if (
									!(
										grep
										$val,
										@{
											$hpvals
										}
									)
								  )
								{
									$changed++;
									last;
								}
							}
							last if $changed;
						} else {
							if ( $hpattr->{$type}
								->{$attrname}
								->{value} ne
								$attr->{$type}
								->{$attrname}
								->{value} )
							{
								printf STDERR
"%s: attr %s of type %s changed from %s to %s\n",
								  $login,
								  $attrname,
								  $type,
								  $hpattr
								  ->{$type}
								  ->{$attrname}
								  ->{value},
								  $attr->{$type}
								  ->{$attrname}
								  ->{value}
								  if $verbose >
									  1;
								$changed++;
								last;
							}
						}
					}
				} else {
					printf STDERR
					  "New attribute type %s for %s.\n",
					  $type, $login
					  if $verbose > 1;
					$changed++;
					last;
				}
			}
		} else {
			printf STDERR
			  "Different number of attribute types for %s.\n",
			  $login
			  if $verbose > 1;
			$changed++;
		}

		if ($changed) {
			printf STDERR "Updating attributes for %s\n", $login
			  if $verbose > 1;
			if (
				!(
					$hp->put_attributes(
						key   => $key,
						attrs => $attr
					)
				)
			  )
			{
				printf STDERR
"Error writing attrbute for %s devcoll %d to local database: %s\n",
				  $login,
				  $devcollid,
				  $hp->Error;
			}
		}
	}

	# Delete attrs that have been deactivated/purged/vv

	my $hpattrs;
	if ( !defined( $hpattrs = $hp->fetch_all_attributes() ) ) {
		printf STDERR
		  "Unable to get attributes from local database: %s\n",
		  $hp->Error;
		exit 1;
	}

	foreach my $key ( keys %$hpattrs ) {
		if ( !$attributes->{$key} ) {
			printf STDERR
"Deleting attribute for %s devcoll %d from local database.\n",
			  unpack( "Z*N", $key )
			  if $verbose > 1;
			$hp->delete_attributes( key => $key );
		}
	}
}

END {
	if ($hp) {
		$hp->{Env}->txn_checkpoint( 0, 0, 0 );
		$hp->closedb;
	}
	$dbh->disconnect if $dbh;
}
