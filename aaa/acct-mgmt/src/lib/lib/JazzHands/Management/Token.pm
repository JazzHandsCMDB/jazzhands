#
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

# $Id$
#

package JazzHands::Management::Token;

use DBI;

use strict;
use Digest::SHA qw(sha1);
use Digest::HMAC qw(hmac);
use Math::BigInt;
use MIME::Base64;
use Crypt::Eksblowfish::Bcrypt qw(bcrypt en_base64);
use POSIX;

use vars qw($VERSION @EXPORT @ISA);

$VERSION = '1.0';    # $Date$

require Exporter;
our @ISA = ("Exporter");
@EXPORT = qw(
  AssignToken
  ClearTokenPIN
  GetAllTokenAssignments
  GetAllTokens
  GetToken
  GetTokenAssignments
  GetTokenList
  GetTokens
  ResetTokenPIN
  SetTokenLockStatus
  SetTokenPIN
  SetTokenSequence
  SetTokenStatus
  UnassignToken
  UnlockToken
);

my %TokenStatus = (
	DISABLED  => 0,
	0         => 'DISABLED',
	ENABLED   => 1,
	1         => 'ENABLED',
	LOST      => 2,
	2         => 'LOST',
	STOLEN    => 3,
	3         => 'STOLEN',
	DESTROYED => 4,
	4         => 'DESTROYED',
);

my %TokenType = (
	0 => {
		value       => 0,
		dbname      => 'UNDEF',
		displayname => 'Undefined Token Type',
		digits      => 0,
	},

	1 => {
		value       => 1,
		dbname      => 'SOFT_SEQ',
		displayname => 'Sequence-based soft token',
		digits      => 8,
	},

	2 => {
		value       => 2,
		dbname      => 'SOFT_TIME',
		displayname => 'Time-based soft token',
		digits      => 8,
	},

	3 => {
		value       => 3,
		dbname      => 'ETOKEN_OTP32',
		displayname => 'Aladdin EToken NG-OTP 32K',
		digits      => 6,
	},

	4 => {
		value       => 4,
		dbname      => 'ETOKEN_OTP64',
		displayname => 'Aladdin EToken NG-OTP 64K',
		digits      => 6,
	},

	5 => {
		value       => 5,
		dbname      => 'DIGIPASS_GO3',
		displayname => 'Vasco Digipass Go3',
		digits      => 6,
	},

	5 => {
		value       => 5,
		dbname      => 'INCARD',
		displayname => 'InCard ICT Token',
		digits      => 6,
	},
	7 => {
		value       => 7,
		dbname      => 'TOK_MAX',
		displayname => 'Dummy token',
		digits      => 0,
	},
);

#
# Make TokenType have keys for both the enumerated value in the HOTPants
# BDB and the key value in the RDBMS
#
foreach my $value ( values %TokenType ) {
	$TokenType{ $value->{dbname} } = $value;
}

sub UserStatus {
	my $val = shift;
	return 0 if ( $val eq 'DISABLED' );
	return 1 if ( $val eq 'ENABLED' );
	return 2 if ( $val eq 'DELETED' );

	#
	# If we don't know, the account is disabled
	#
	return 0;
}

sub _options {
	my %ret = @_;
	for my $v ( grep { /^-/ } keys %ret ) {
		$ret{ substr( $v, 1 ) } = $ret{$v};
	}
	\%ret;
}

sub GetTokenList {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $opt = &_options(@_);

	my $q;
	if ( $opt->{serial} ) {
		$q = "SELECT UNIQUE Token_Serial FROM V_Token";
	} else {
		$q = "SELECT UNIQUE Token_ID FROM V_Token";
	}
	my $sth;
	if ( !( $sth = $dbh->prepare($q) ) ) {
		$JazzHands::Management::Errmsg =
		  "Error preparing database statement in GetTokenList";
		return undef;
	}
	if ( !( $sth->execute ) ) {
		$JazzHands::Management::Errmsg =
		  "Error executing database statement in GetTokenList";
		return undef;
	}
	my @tokens;
	my $token;
	while ( defined( $token = $sth->fetchrow_arrayref ) ) {
		push @tokens, $token->[0];
	}
	$sth->finish;
	return \@tokens;
}

sub GetToken {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $opt = &_options(@_);

	return undef if ( !$opt->{token_id} && !$opt->{serial} );
	my $q;

	#
	# If we pass the --withkey option, then we need to query against the
	# base tables to get key.  This also assumes that we have permission
	# in the database to do so.
	#
	if ( $opt->{withkey} ) {
		$q = qq {
			SELECT
				Token_ID,
				Token_Type,
				Token_Status,
				Token_Serial,
				Token_Sequence,
				Zero_Time,
				Time_Modulo,
				Time_Skew,
				Is_User_Token_Locked,
				Time_Util.Epoch(Token_Unlock_Time) AS Token_Unlock_Time,
				Bad_Logins,
				Time_Util.Epoch(Token.Last_Updated) AS Token_Last_Updated,
				Time_Util.Epoch(Token_Sequence.Last_Updated) AS
					Token_Sequence_Last_Updated,
				Time_Util.Epoch(System_User_Token.Last_Updated) AS
					Lock_Status_Last_Updated,
				System_User_Id,
				Login,
				System_User_Type,
				Time_Util.Epoch(Issued_Date),
				Token_PIN,
				Token_Key
			FROM
				Token LEFT OUTER JOIN Token_Sequence USING (Token_ID)
				LEFT OUTER JOIN System_User_Token USING (Token_ID)
				LEFT OUTER JOIN System_User USING (System_User_ID)
			WHERE
		};
	} else {
		$q = qq {
			SELECT
				Token_ID,
				Token_Type,
				Token_Status,
				Token_Serial,
				Token_Sequence,
				Zero_Time,
				Time_Modulo,
				Time_Skew,
				Is_User_Token_Locked,
				Time_Util.Epoch(Token_Unlock_Time) AS Token_Unlock_Time,
				Bad_Logins,
				Time_Util.Epoch(Token_Last_Updated),
				Time_Util.Epoch(Token_Sequence_Last_Updated),
				Time_Util.Epoch(Lock_Status_Last_Updated),
				System_User_Id,
				Login,
				System_User_Type,
				Time_Util.Epoch(Issued_Date),
				Token_PIN
			FROM
				V_Token LEFT OUTER JOIN System_User USING (System_User_ID)
			WHERE
		};
	}
	my $id;
	if ( $opt->{token_id} ) {
		$q .= "\t\tToken_ID = :id\n";
		$id = $opt->{token_id};
	} else {
		$q .= "\t\tToken_Serial = :id\n";
		$id = $opt->{serial};
	}

	my $sth;
	if ( !( $sth = $dbh->prepare($q) ) ) {
		$JazzHands::Management::Errmsg =
		  "Error preparing database statement in GetToken"
		  . $dbh->errstr;
		return undef;
	}
	$sth->bind_param( ':id', $id );
	if ( !( $sth->execute ) ) {
		$JazzHands::Management::Errmsg =
		  "Error executing database statement in GetToken";
		return undef;
	}
	my $token = undef;
	while ( my $row = $sth->fetchrow_arrayref ) {
		if ( !$token ) {
			$token = {
				token_id    => $row->[0],
				type        => $TokenType{ $row->[1] }->{value},
				status      => $TokenStatus{ $row->[2] },
				serial      => $row->[3],
				sequence    => $row->[4],
				zero_time   => $row->[5] || 0,
				time_modulo => $row->[6] || 0,
				time_skew   => $row->[7] || 0,
				token_locked =>
				  ( $row->[8] && $row->[8] eq 'Y' ) ? 1 : 0,
				unlock_time         => $row->[9],
				bad_logins          => $row->[10] || 0,
				token_changed       => $row->[11],
				sequence_changed    => $row->[12],
				lock_status_changed => $row->[13],
				user_id             => $row->[14],
				issued_date         => $row->[17],
				pin                 => $row->[18],
				altlogins           => [],
			};
		}

		#
		# Figure out the primary user (hint: it's the one that isn't a
		# pseudouser)
		#
		if ( $row->[16] && $row->[16] eq 'pseudouser' ) {
			push @{ $token->{altlogins} }, $row->[15];
		} else {
			$token->{login} = $row->[15];
		}
		if ( $opt->{withkey} ) {
			$token->{key} = $row->[19];
		}
	}
	$sth->finish;
	if ( !defined($token) ) {
		return undef;
	}
	bless $token;
}

# GetAllTokens is really GetTokens with types unspecified and returning a
# hash ref, but Vv

sub GetAllTokens {
	GetTokens( @_, hashref => 1 );
}

sub GetTokens {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $opt = &_options(@_);

	my %types;
	if ( $opt->{types} ) {

	       # if 'types' is a scalar, then we're only going to have one thing
		if ( !ref( $opt->{types} ) ) {
			$types{ $opt->{types} } = 1;
		} elsif ( ref( $opt->{types} ) eq "ARRAY" ) {
			foreach my $type ( @{ $opt->{types} } ) {
				$types{$type} = 1;
			}
		}
	}

	#
	# If we pass the --withkey option, then we need to query against the
	# base tables to get key.  This also assumes that we have permission
	# in the database to do so.
	#

       # The following is the base query that we care about.  If we are limiting
       # ourselves to specific types of tokens, then we need to add WHERE
       # clauses later.

	my $q;
	if ( $opt->{withkey} ) {
		$q = qq {
			SELECT
				Token_ID,
				Token_Type,
				Token_Status,
				Token_Serial,
				Token_Sequence,
				Zero_Time,
				Time_Modulo,
				Time_Skew,
				Is_User_Token_Locked,
				Time_Util.Epoch(Token_Unlock_Time) AS Token_Unlock_Time,
				Bad_Logins,
				Time_Util.Epoch(Token.Last_Updated) AS Token_Last_Updated,
				Time_Util.Epoch(Token_Sequence.Last_Updated) AS
					Token_Sequence_Last_Updated,
				Time_Util.Epoch(System_User_Token.Last_Updated) AS
					Lock_Status_Last_Updated,
				System_User_Id,
				Login,
				Time_Util.Epoch(Issued_Date) AS Issued_Date,
				Token_PIN,
				Token_Key
			FROM
				Token LEFT OUTER JOIN Token_Sequence USING (Token_ID)
				LEFT OUTER JOIN System_User_Token USING (Token_ID)
				LEFT OUTER JOIN System_User USING (System_User_ID)
		};
	} else {
		$q = qq 
{			SELECT
				Token_ID,
				Token_Type,
				Token_Status,
				Token_Serial,
				Token_Sequence,
				Zero_Time,
				Time_Modulo,
				Time_Skew,
				Is_User_Token_Locked,
				Time_Util.Epoch(Token_Unlock_Time) AS Token_Unlock_Time,
				Bad_Logins,
				Time_Util.Epoch(Token_Last_Updated),
				Time_Util.Epoch(Token_Sequence_Last_Updated),
				Time_Util.Epoch(Lock_Status_Last_Updated),
				System_User_Id,
				Login,
				Time_Util.Epoch(Issued_Date),
				Token_PIN
			FROM
				V_Token LEFT OUTER JOIN System_User USING (System_User_ID)
};
	}
	my @whereclause;
	if (%types) {

		#
		# Check which statuses we're interested in
		#
		my @status;
		foreach
		  my $i ( "enabled", "disabled", "lost", "stolen", "destroyed" )
		{
			if ( $types{$i} ) {
				push( @status, uc($i) );
			}
		}
		if (@status) {
			push @whereclause,
			  sprintf( "Token_Status IN ('%s')",
				join( "', '", @status ) );
		}

		#
		# Check for what assignment types
		#
		my @assigned;
		if ( $types{assigned} ) {
			push @assigned, "System_User_Id IS NOT NULL";
		}
		if ( $types{unassigned} ) {
			push @assigned, "System_User_Id IS NULL";
		}
		if (@assigned) {
			push @whereclause,
			  "(" . join( " OR ", @assigned ) . ")\n";
		}
		my @pinset;
		my $pinsetquery;

		if ( $types{pinset} ) {
			push @pinset, "Token_PIN IS NOT NULL";
		}
		if ( $types{pinunset} ) {
			push @pinset, "Token_PIN IS NULL";
		}

		if (@pinset) {
			push @whereclause,
			  "(" . join( " OR ", @pinset ) . ")\n";
		}

		my @locked;
		my $lockedquery;

		if ( $types{locked} ) {
			push @locked, "Is_User_Token_Locked = 'Y'";
		}
		if ( $types{unlocked} ) {
			push @locked, "Is_User_Token_Locked = 'N'";
		}

		if (@locked) {
			push @whereclause,
			  "(" . join( " OR ", @locked ) . ")\n";
		}
	}

	if ( $opt->{login} ) {
		push @whereclause, "Login = :login\n";
	}

	if ( $opt->{serial} ) {
		if ( $opt->{fuzzy} ) {
			push @whereclause, "Token_Serial LIKE :serial",
			  $opt->{serial} = '%' . $opt->{serial};
		} else {
			push @whereclause, "Token_Serial = :serial",;
		}
	}

	if (@whereclause) {
		$q .= "\t\t\tWHERE\n\t\t\t\t"
		  . join( " AND\n\t\t\t\t", @whereclause );
	}

	my $sth;
	if ( !( $sth = $dbh->prepare($q) ) ) {
		$JazzHands::Management::Errmsg =
		  "Error preparing database statement in GetTokens";
		return undef;
	}
	if ( $opt->{login} ) {
		$sth->bind_param( ':login', $opt->{login} );
	}
	if ( $opt->{serial} ) {
		$sth->bind_param( ':serial', $opt->{serial} );
	}
	if ( !( $sth->execute ) ) {
		$JazzHands::Management::Errmsg =
		  "Error executing database statement in GetTokens";
		return undef;
	}
	my $tokens;
	if ( $opt->{hashref} ) {
		$tokens = {};
	} else {
		$tokens = [];
	}
	while ( my $row = $sth->fetchrow_arrayref ) {
		my $token = {
			token_id     => $row->[0],
			type         => $TokenType{ $row->[1] }->{value},
			status       => $TokenStatus{ $row->[2] },
			serial       => $row->[3],
			sequence     => $row->[4],
			zero_time    => $row->[5] || 0,
			time_modulo  => $row->[6] || 0,
			time_skew    => $row->[7] || 0,
			token_locked => ( $row->[8] && $row->[8] eq 'N' )
			? 0
			: 1,
			unlock_time         => $row->[9]  || 0,
			bad_logins          => $row->[10] || 0,
			token_changed       => $row->[11] || 0,
			sequence_changed    => $row->[12] || 0,
			lock_status_changed => $row->[13] || 0,
			user_id             => $row->[14] || 0,
			login               => $row->[15],
			issued_date         => $row->[16],
			pin                 => $row->[17]
		};
		if ( $opt->{withkey} ) {
			$token->{key} = $row->[18];
		}
		if ( $opt->{hashref} ) {
			$tokens->{ $row->[0] } = $token;
		} else {
			push @$tokens, $token;
		}
		bless $token;
	}
	$sth->finish;
	return $tokens;
}

sub GetTokenAssignments {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $opt = &_options(@_);

	return undef
	  if ( !$opt->{user_id} && !$opt->{token_id} && !$opt->{login} );

	my $sth;
	my $q = qq {
			SELECT
				System_User_Id,
				Login,
				Token_ID,
				Token_Serial,
				Token_PIN,
				Time_Util.Epoch(Issued_Date),
				Is_User_Token_Locked,
				Time_Util.Epoch(Token_Unlock_Time),
				Bad_Logins,
				Time_Util.Epoch(Last_Updated)
			FROM
				V_Token JOIN
				System_User USING (System_User_ID)
	};

	if ( $opt->{user_id} ) {
		$q .= "WHERE System_User_ID = :userid";
	} elsif ( $opt->{login} ) {
		$q .= "WHERE Login = :login";
	} else {
		$q .= "WHERE Token_ID = :tokenid";
	}

	if ( !( $sth = $dbh->prepare($q) ) ) {
		$JazzHands::Management::Errmsg =
		  "Error preparing database statement in GetTokenAssignments:"
		  . $dbh->errstr;
		return undef;
	}

	if ( $opt->{user_id} ) {
		$sth->bind_param( ':userid', $opt->{user_id} );
	} elsif ( $opt->{login} ) {
		$sth->bind_param( ':login', $opt->{login} );
	} else {
		$sth->bind_param( ':tokenid', $opt->{token_id} );
	}

	if ( !( $sth->execute ) ) {
		$JazzHands::Management::Errmsg =
		  "Error executing database statement in GetTokenAssignments";
		return undef;
	}
	my $tokens = [];
	while ( my $row = $sth->fetchrow_arrayref ) {
		my $token = {
			user_id             => $row->[0],
			login               => $row->[1],
			token_id            => $row->[2],
			token_serial        => $row->[3],
			token_pin           => $row->[4],
			issued_date         => $row->[5],
			is_locked           => $row->[6],
			unlock_time         => $row->[7],
			bad_logins          => $row->[8],
			lock_status_changed => $row->[9]
		};
		push @$tokens, $token;
	}
	$sth->finish;
	return $tokens;
}

sub GetAllTokenAssignments {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $opt = &_options(@_);

	my $sth;
	my $q = qq {
			SELECT
				System_User_Id,
				Login,
				Token_ID,
				Token_Serial,
				Token_PIN,
				Time_Util.Epoch(Issued_Date),
				Is_User_Token_Locked,
				Time_Util.Epoch(Token_Unlock_Time),
				Bad_Logins,
				Time_Util.Epoch(System_user_Token.Last_Updated)
			FROM
				System_User_Token JOIN System_User USING (System_User_ID)
				JOIN Token USING (Token_ID)
	};

	if ( !( $sth = $dbh->prepare($q) ) ) {
		$JazzHands::Management::Errmsg =
"Error preparing database statement in GetAllTokenAssignments";
		return undef;
	}

	if ( !( $sth->execute ) ) {
		$JazzHands::Management::Errmsg =
"Error executing database statement in GetAllTokenAssignments";
		return undef;
	}
	my $tokens = {};
	while ( my $row = $sth->fetchrow_arrayref ) {
		my $token = {
			user_id             => $row->[0],
			login               => $row->[1],
			token_id            => $row->[2],
			token_serial        => $row->[3],
			token_pin           => $row->[4],
			issued_date         => $row->[5],
			is_locked           => $row->[6],
			unlock_time         => $row->[7],
			bad_logins          => $row->[8],
			lock_status_changed => $row->[9]
		};
		if ( !$tokens->{ $row->[0] } ) {
			$tokens->{ $row->[0] } = [];
		}
		push @{ $tokens->{ $row->[0] } }, $token;
	}
	$sth->finish;
	return $tokens;
}

sub SetTokenSequence {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $opt = &_options(@_);

	return -1 if !$opt->{token_id};
	return -1 if !$opt->{sequence};

	my $sth;

	if (
		!(
			$sth = $dbh->prepare(
				qq{
			BEGIN
				token_util.set_sequence(
					:tokenid,
					:sequence,
					:updatetime
				);
			END;
			}
			)
		)
	  )
	{
		$JazzHands::Management::Errmsg =
		  "Error preparing database statement in SetTokenSequence";
		return undef;
	}
	$sth->bind_param( ':tokenid',  $opt->{token_id} );
	$sth->bind_param( ':sequence', $opt->{sequence} );
	if ( $opt->{update_time} ) {
		my ( $sec, $min, $hour, $mday, $mon, $year ) = gmtime( time() );
		my $modtime = sprintf(
			"%04d-%02d-%02d %02d:%02d:%02d",
			$year + 1900,
			$mon + 1, $mday, $hour, $min, $sec
		);
		$sth->bind_param( ':updatetime', $modtime );
	} else {
		$sth->bind_param( ':updatetime', undef );
	}
	if ( !( $sth->execute ) ) {
		$JazzHands::Management::Errmsg =
		  "Error executing database statement in SetTokenSequence";
		return -1;
	}
	$dbh->commit;
	return 0;
}

sub SetTokenStatus {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $opt = &_options(@_);

	return -1 if !$opt->{token_id};
	return -1 if !$opt->{status};

	my $sth;

	if (
		!(
			$sth = $dbh->prepare(
				qq{
			BEGIN
				token_util.set_status(
					:tokenid,
					:status
				);
			END;
			}
			)
		)
	  )
	{
		$JazzHands::Management::Errmsg =
		  "Error preparing database statement in SetTokenStatus";
		return undef;
	}
	$sth->bind_param( ':tokenid', $opt->{token_id} );
	$sth->bind_param( ':status',  $opt->{status} );
	if ( !( $sth->execute ) ) {
		$JazzHands::Management::Errmsg =
		  "Error executing database statement in SetTokenStatus";
		return -1;
	}
	if ( !$opt->{nocommit} ) {
		$dbh->commit;
	}
	return 0;
}

sub SetTokenPIN {
	my $jh  = undef;
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$jh  = $dbh;
		$dbh = $jh->DBHandle;
	}
	return undef if !$dbh;

	my $opt = &_options(@_);

	return -1 if !$opt->{token_id};
	return -1 if !$opt->{pin};

	my $sth;
	my $pin = bcrypt(
		$opt->{pin},
		'$2a$07$'
		  . en_base64(
			pack( "LLLL",
				rand(0xffffffff), rand(0xffffffff),
				rand(0xffffffff), rand(0xffffffff) )
		  )
	);

	if (
		!(
			$sth = $dbh->prepare(
				qq{
			BEGIN
				token_util.set_pin(
					:tokenid,
					:pin
				);
			END;
			}
			)
		)
	  )
	{
		if ($jh) {
			$jh->Error(
"Error preparing database statement in SetTokenPIN"
				  . $jh->DBErrors ? ": " . $dbh->errstr : "" );
		}
		return -1;
	}
	$sth->bind_param( ':tokenid', $opt->{token_id} );
	$sth->bind_param( ':pin',     $pin );
	if ( !( $sth->execute ) ) {
		if ($jh) {
			$jh->Error(
"Error executing database statement in SetTokenPIN"
				  . $jh->DBErrors ? ": " . $sth->errstr : "" );
		}
		return -1;
	}
	$sth->finish;
	if ( !$opt->{nocommit} ) {
		$dbh->commit;
	}
	return 0;
}

sub ClearTokenPIN {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $opt = &_options(@_);

	return -1 if !$opt->{token_id};

	my $sth;

	if (
		!(
			$sth = $dbh->prepare(
				qq{
			BEGIN
				token_util.set_pin(
					:tokenid,
					NULL
				);
			END;
			}
			)
		)
	  )
	{
		$JazzHands::Management::Errmsg =
		  "Error preparing database statement in ClearTokenPIN";
		return undef;
	}
	$sth->bind_param( ':tokenid', $opt->{token_id} );
	if ( !( $sth->execute ) ) {
		$JazzHands::Management::Errmsg =
		  "Error executing database statement in ClearTokenPIN";
		return -1;
	}
	$sth->finish;
	if ( !$opt->{nocommit} ) {
		$dbh->commit;
	}
	return 0;
}

sub AssignToken {
	my $obj = shift;

	my $dbh;
	if ( ref($obj) eq "JazzHands::Management" ) {
		$dbh = $obj->DBHandle;
	} else {
		$dbh = $obj;
	}
	return "Bad arguments" if !$dbh;

	my $opt = &_options(@_);

	#
	# We have a bunch of checks to do before we can assign the token.
	# First, make sure we were passed in sufficient parameters
	#

	return "No login passed" if ( !$opt->{login} );
	return "No token passed" if ( !$opt->{token_id} && !$opt->{serial} );

	# Check to see whether the token is valid

	my $token;
	if ( $opt->{token_id} ) {
		$token = $obj->GetToken( token_id => $opt->{token_id} );
		if ( !defined($token) ) {
			return "Token not found with id " . $opt->{token_id};
		}
	} else {
		$token = $obj->GetToken( serial => $opt->{serial} );
		if ( !defined($token) ) {
			return "Token not found with serial " . $opt->{serial};
		}
	}

	# Make sure the user exists

	my $user = $obj->GetUserData( $opt->{login} );

	if ( !$user ) {
		return "User " . $opt->{login} . " does not exist";
	}

	# Check to see if the token is already assigned.  If the user is
	# a pseudouser, then it has to have previously been assigned to
	# someone.  Otherwise, it must not have previously been assigned.

	my $assignments =
	  $obj->GetTokenAssignments( token_id => $token->{token_id} );
	if ( $assignments && @$assignments ) {
		if ( $user->{SYSTEM_USER_TYPE} ne "pseudouser" ) {
			return "Token is already assigned";
		}
	} else {
		if ( $user->{SYSTEM_USER_TYPE} eq "pseudouser" ) {
			return
			    "User "
			  . $opt->{login}
			  . "is a pseudouser and token has "
			  . "not been assigned";
		}
	}

	# At this point, things should be okay to assign the token unless we're
	# doing a replacement

	if ( $opt->{replace} || $opt->{replace_id} ) {

		# pseudousers can't have tokens replaced

		if ( $user->{SYSTEM_USER_TYPE} eq "pseudouser" ) {
			return
			    "User "
			  . $opt->{login}
			  . "is a pseudouser and may not "
			  . "be replaced.";
			return "User  is already assigned";
		}
		my $replace;

		if ( $opt->{replace_id} ) {
			$replace =
			  $obj->GetToken( token_id => $opt->{replace_id} );
			if ( !defined($replace) ) {
				return "Token not found with id "
				  . $opt->{replace_id};
			}
		} else {
			$replace = $obj->GetToken( serial => $opt->{replace} );
			if ( !defined($replace) ) {
				return "Token not found with serial "
				  . $opt->{replace};
			}
		}

		# Token must be assigned to the user we're replacing

		my $check =
		  $obj->GetTokenAssignments( token_id => $replace->{token_id} );

		if ( $check && @$check ) {
			if (
				!(
					grep {
						$_->{user_id} ==
						  $user->{SYSTEM_USER_ID}
					} @$check
				)
			  )
			{
				return
"Token to be replaced is not assigned to user "
				  . $opt->{login};
			}
		} else {
			return "Token to be replaced is not assigned";
		}

		# Verify the status is okay. If we aren't passed a status, just
		# set it to 'DISABLED'

		if ( !$opt->{replace_status} ) {
			$opt->{replace_status} = 'DISABLED';
		} else {
			if ( !$TokenStatus{ uc( $opt->{replace_status} ) } ) {
				return
				    "Status "
				  . $opt->{replace_status}
				  . " is not valid";
			}
		}

		# Everything's cool.  Do it.
		my $sth;

		# First, migrate everything to the new token

		if (
			!(
				$sth = $dbh->prepare(
					qq{
				BEGIN
					Token_Util.Replace_Token(
						:oldtoken,
						:newtoken
					);
				END;
				}
				)
			)
		  )
		{
			$JazzHands::Management::Errmsg =
			  "Error preparing database statement in AssignToken";
			return "Database error";
		}
		$sth->bind_param( ':oldtoken', $replace->{token_id} );
		$sth->bind_param( ':newtoken', $token->{token_id} );
		if ( !( $sth->execute ) ) {
			$JazzHands::Management::Errmsg =
			  "Error executing database statement in AssignToken";
			$dbh->rollback;
			return "Database error reassigning token";
		}
		$sth->finish;

		# Copy the PIN from the old token to the new one

		if (
			!(
				$sth = $dbh->prepare(
					qq{
				BEGIN
					Token_Util.Copy_PIN(
						:oldtoken,
						:newtoken
					);
				END;
				}
				)
			)
		  )
		{
			$JazzHands::Management::Errmsg =
			  "Error preparing database statement in AssignToken";
			return "Database error";
		}
		$sth->bind_param( ':oldtoken', $replace->{token_id} );
		$sth->bind_param( ':newtoken', $token->{token_id} );
		if ( !( $sth->execute ) ) {
			$JazzHands::Management::Errmsg =
			  "Error executing database statement in AssignToken";
			$dbh->rollback;
			return "Database error migrating PIN";
		}
		$sth->finish;

		# Clear the PIN from the old token

		if (
			!(
				$sth = $dbh->prepare(
					qq{
				BEGIN
					Token_Util.Set_PIN(
						:oldtoken,
						NULL
					);
				END;
				}
				)
			)
		  )
		{
			$JazzHands::Management::Errmsg =
			  "Error preparing database statement in AssignToken";
			return "Database error";
		}
		$sth->bind_param( ':oldtoken', $replace->{token_id} );
		if ( !( $sth->execute ) ) {
			$JazzHands::Management::Errmsg =
			  "Error executing database statement in AssignToken";
			$dbh->rollback;
			return "Database error clearing old token data";
		}
		$sth->finish;

		# Now set the token status for the old and new tokens.

		if (
			$obj->SetTokenStatus(
				token_id => $token->{token_id},
				status   => 'ENABLED',
				nocommit => 1
			)
		  )
		{
			$dbh->rollback;
			return "Database error setting status of new token";
		}

		if (
			$obj->SetTokenStatus(
				token_id => $replace->{token_id},
				status   => uc( $opt->{replace_status} ),
				nocommit => 1
			)
		  )
		{
			$dbh->rollback;
			return "Database error setting status of new token";
		}

		# We're done, I guess
		$dbh->commit;
		return 0;
	}

	# If we get here, it's a brand new assignment, and everything's happy.

	my $sth;
	if (
		!(
			$sth = $dbh->prepare(
				qq{
			BEGIN
				Token_Util.Assign_Token(
					:tokenid,
					:userid
				);
			END;
			}
			)
		)
	  )
	{
		$JazzHands::Management::Errmsg =
		  "Error preparing database statement in AssignToken";
		$dbh->rollback;
		return "Database error assigning new token";
	}
	$sth->bind_param( ':tokenid', $token->{token_id} );
	$sth->bind_param( ':userid',  $user->{SYSTEM_USER_ID} );
	if ( !( $sth->execute ) ) {
		$JazzHands::Management::Errmsg =
		  "Error executing database statement in AssignToken: "
		  . $DBI::errstr;
		$dbh->rollback;
		return "Database error assigning new token";
	}

	# If this is an additional assignment (i.e. to a pseudouser), we're done

	if ( $user->{SYSTEM_USER_TYPE} eq "pseudouser" ) {
		$dbh->commit;
		return 0;
	}

	if (
		$obj->ClearTokenPIN(
			token_id => $token->{token_id},
			nocommit => 1
		)
	  )
	{
		$dbh->rollback;
		return "Database error clearing new token PIN";
	}

	if (
		$obj->SetTokenStatus(
			token_id => $token->{token_id},
			status   => 'ENABLED',
			nocommit => 1
		)
	  )
	{
		$dbh->rollback;
		return "Database error setting status of new token";
	}

	# Everything worked.  Party.

	$dbh->commit;
	return 0;
}

sub UnassignToken {
	my $obj = shift;

	my $dbh;
	if ( ref($obj) eq "JazzHands::Management" ) {
		$dbh = $obj->DBHandle;
	} else {
		$dbh = $obj;
	}
	return "Bad arguments" if !$dbh;

	my $opt = &_options(@_);

	return "No token passed" if ( !$opt->{token_id} && !$opt->{serial} );

	# Check to see whether the token is valid

	my $token;
	if ( $opt->{token_id} ) {
		$token = $obj->GetToken( token_id => $opt->{token_id} );
		if ( !defined($token) ) {
			return "Token not found with id " . $opt->{token_id};
		}
	} else {
		$token = $obj->GetToken( serial => $opt->{serial} );
		if ( !defined($token) ) {
			return "Token not found with serial " . $opt->{serial};
		}
	}

	# Make sure the user exists if it's passed

	my $userid;
	if ( $opt->{login} ) {
		my $user = $obj->GetUserData( $opt->{login} );

		if ( !$user ) {
			return "User " . $opt->{login} . " does not exist";
		}

		# Token must be assigned to the user

		my $check =
		  $obj->GetTokenAssignments( token_id => $token->{token_id} );

		if ( $check && @$check ) {
			if (
				!(
					grep {
						$_->{user_id} ==
						  $user->{SYSTEM_USER_ID}
					} @$check
				)
			  )
			{
				return "Token is not assigned to user "
				  . $opt->{login};
			}
		} else {
			return "Token is not assigned";
		}

	       # if the user isn't a pseudouser, then we're removing it from the
	       # primary user, so we need to remove it from everything.

		if ( $user->{SYSTEM_USER_TYPE} eq "pseudouser" ) {
			$userid = $user->{SYSTEM_USER_ID};
		}
	}

	my $sth;
	if (
		!(
			$sth = $dbh->prepare(
				qq{
			BEGIN
				Token_Util.Unassign_Token(
					:tokenid,
					:userid
				);
			END;
			}
			)
		)
	  )
	{
		$JazzHands::Management::Errmsg =
		  "Error preparing database statement in UnassignToken";
		$dbh->rollback;
		return "Database error unassigning token";
	}
	$sth->bind_param( ':tokenid', $token->{token_id} );
	$sth->bind_param( ':userid',  $userid );
	if ( !( $sth->execute ) ) {
		$JazzHands::Management::Errmsg =
		  "Error executing database statement in UnassignToken: "
		  . $DBI::errstr;
		$dbh->rollback;
		return "Database error unassigning token";
	}

	# If we removed the token from everything, clear the PIN and disabled it

	if ( !$userid ) {
		if (
			$obj->ClearTokenPIN(
				token_id => $token->{token_id},
				nocommit => 1
			)
		  )
		{
			$dbh->rollback;
			return "Database error clearing token PIN";
		}

	    # Disable the token iff it hasn't been set to another status already

		if (       ( $token->{status} ne 'ENABLED' )
			&& ( $token->{status} != 2 ) )
		{
			if (
				$obj->SetTokenStatus(
					token_id => $token->{token_id},
					status   => 'DISABLED',
					nocommit => 1
				)
			  )
			{
				$dbh->rollback;
				return "Database error setting status of token";
			}
		}
	}

	# Everything worked.  Party.

	$dbh->commit;
	return 0;
}

# Note: ResetTokenPIN is essentially a verification wrapper for ClearTokenPIN

sub ResetTokenPIN {
	my $obj = shift;

	my $dbh;
	if ( ref($obj) eq "JazzHands::Management" ) {
		$dbh = $obj->DBHandle;
	} else {
		$dbh = $obj;
	}
	return "Bad arguments" if !$dbh;

	my $opt = &_options(@_);

	return "No token passed" if ( !$opt->{token_id} && !$opt->{serial} );

	# Check to see whether the token is valid

	my $token;
	if ( $opt->{token_id} ) {
		$token = $obj->GetToken( token_id => $opt->{token_id} );
		if ( !defined($token) ) {
			return "Token not found with id " . $opt->{token_id};
		}
	} else {
		$token = $obj->GetToken( serial => $opt->{serial} );
		if ( !defined($token) ) {
			return "Token not found with serial " . $opt->{serial};
		}
	}

	if ( $obj->ClearTokenPIN( token_id => $token->{token_id} ) ) {
		return "Database error clearing token PIN";
	}
	return 0;
}

sub UnlockToken {
	my $obj = shift;

	my $dbh;
	if ( ref($obj) eq "JazzHands::Management" ) {
		$dbh = $obj->DBHandle;
	} else {
		$dbh = $obj;
	}
	return "Bad arguments" if !$dbh;

	my $opt = &_options(@_);

	return "No token passed" if ( !$opt->{token_id} && !$opt->{serial} );

	# Check to see whether the token is valid

	my $token;
	if ( $opt->{token_id} ) {
		$token = $obj->GetToken( token_id => $opt->{token_id} );
		if ( !defined($token) ) {
			return "Token not found with id " . $opt->{token_id};
		}
	} else {
		$token = $obj->GetToken( serial => $opt->{serial} );
		if ( !defined($token) ) {
			return "Token not found with serial " . $opt->{serial};
		}
	}

	if (
		$obj->SetTokenLockStatus(
			token_id => $token->{token_id},
			locked   => 0,
		)
	  )
	{
		return "Database error unlocking token: "
		  . $JazzHands::Management::Errmsg;
	}
	return 0;
}

sub SetTokenLockStatus {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $opt = &_options(@_);

	return -1 if ( !defined( $opt->{token_id} ) );
	return -1 if ( !defined( $opt->{locked} ) );

	if ( $opt->{locked} ) {
		$opt->{token_locked} = 'Y';
	} else {
		$opt->{token_locked} = 'N';
	}
	my $unlock_time;
	my ( $sec, $min, $hour, $mday, $mon, $year );
	if ( !$opt->{unlock_time} ) {
		$unlock_time = "";
	} else {
		( $sec, $min, $hour, $mday, $mon, $year ) =
		  gmtime( $opt->{unlock_time} );
		$unlock_time = sprintf(
			"%04d-%02d-%02d %02d:%02d:%02d",
			$year + 1900,
			$mon + 1, $mday, $hour, $min, $sec
		);
	}
	if ( !$opt->{bad_logins} ) {
		$opt->{bad_logins} = 0;
	}
	if ( !$opt->{lock_status_changed} ) {
		$opt->{lock_status_changed} = scalar( time() );
	}
	( $sec, $min, $hour, $mday, $mon, $year ) =
	  gmtime( $opt->{lock_status_changed} );
	my $modtime = sprintf(
		"%04d-%02d-%02d %02d:%02d:%02d",
		$year + 1900,
		$mon + 1, $mday, $hour, $min, $sec
	);
	my $q = qq {
		BEGIN
			token_util.set_lock_status(
				:tokenid,
				:locked,
				TO_DATE(:unlock, 'YYYY-MM-DD HH24:MI:SS'),
				:badlogins,
				TO_DATE(:lastupdated, 'YYYY-MM-DD HH24:MI:SS')
			);
		END;
	};
	my $sth;
	if ( !( $sth = $dbh->prepare($q) ) ) {
		$JazzHands::Management::Errmsg =
		  "Error preparing database statement in SetTokenLockStatus";
		return undef;
	}
	$sth->bind_param( ':locked',      $opt->{token_locked} );
	$sth->bind_param( ':unlock',      $unlock_time );
	$sth->bind_param( ':badlogins',   $opt->{bad_logins} );
	$sth->bind_param( ':lastupdated', $modtime );
	$sth->bind_param( ':tokenid',     $opt->{token_id} );

	if ( !( $sth->execute ) ) {
		$JazzHands::Management::Errmsg =
		  "Error executing database statement in SetTokenLockStatus: "
		  . $DBI::errstr;
		return -1;
	}
	$dbh->commit;
	return 0;
}

# function derived from Authen::HOTP module by Iain Wade (iwade@optusnet.com.au)
# Perl sucks balls trying to do real bit manipulation

sub GenerateHOTP {
	my $opt = &_options(@_);
	if (       !defined( $opt->{key} )
		|| !defined( $opt->{sequence} )
		|| !$opt->{digits} )
	{
		return undef;
	}

	$opt->{sequence} = new Math::BigInt( $opt->{sequence} )
	  unless ref $opt->{sequence} eq "Math::BigInt";

	$opt->{digits} ||= 6;

	if ( $opt->{keytype} eq 'base64' ) {
		$opt->{key} = decode_base64( $opt->{key} );
	}

	return undef if length $opt->{key} < 16;               # 128-bit minimum
	return undef if ref $opt->{sequence} ne "Math::BigInt";
	return undef if $opt->{digits} < 6 and $opt->{digits} > 10;

	( my $hex = $opt->{sequence}->as_hex ) =~
	  s/^0x(.*)/"0"x(16 - length $1).$1/e;
	my $bin = join '', map chr hex,
	  $hex =~ /(..)/g;    # pack 64-bit big endian
	my $hash = hmac $bin, $opt->{key}, \&sha1;
	my $offset = hex substr unpack( "H*" => $hash ), -1;
	my $dt = unpack "N" => substr $hash, $offset, 4;
	$dt &= 0x7fffffff;    # 31-bit
	my $otp = substr( sprintf( "%010d", $dt ), 0 - $opt->{digits} );

	return $otp;
}

sub FindHOTP {

	#
	# Takes a token object and an OTP and tries to find a matching sequence
	# starting at the current sequence and going up to some sequence value.
	# Defaults to 50, but can be changed by passing a 'maxseq' option.
	#
	# Note that this does not do anything about checking whether the token
	# or user are enabled.
	#
	# The 'noupdate' parameter can be set to a non-zero value to specify
	# that the sequence number should not be updated, as this function is
	# used to resequence a token if it gets way off where there may need to
	# be multiple sequential auths to actually update the sequence
	#
	# The 'sequence' parameter may also be passed to check a single,
	# specific sequence.  This is also used in the above case to verify
	# the exact next sequence number in a series.
	#
	# This function returns the sequence number that matched, or undef if
	# no match was found.  Alternatively, if the 'differential' parameter is
	# set, the difference between the sequence located and the base sequence
	# will be returned.
	#
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $opt = &_options(@_);

	if ( !defined( $opt->{token_id} ) || !defined( $opt->{otp} ) ) {
		return undef;
	}

	my $maxseq = 50;
	if ( $opt->{maxseq} && int( $opt->{maxseq} ) ) {
		$maxseq = $opt->{maxseq};
	}

	my $token = GetToken(
		$dbh,
		token_id => $opt->{token_id},
		withkey  => 1
	);
	if ( !defined($token) ) {
		print STDERR $JazzHands::Management::Errmsg;
		return undef;
	}
	my $digits = $TokenType{ $token->{type} }->{digits};

	my $sequence;
	if ( $opt->{sequence} ) {
		$sequence = $opt->{sequence};
		$maxseq   = 1;
	} else {
		$sequence = $token->{sequence} + 1;
	}

	for ( my $seq = $sequence ; $seq < $sequence + $maxseq ; $seq++ ) {
		my $otp = GenerateHOTP(
			key      => $token->{key},
			keytype  => 'base64',
			sequence => $seq,
			digits   => $TokenType{ $token->{type} }->{digits}
		);
		print STDERR "Generated OTP for sequence $seq is $otp\n";
		if ( $opt->{otp} eq $otp ) {
			if ( !$opt->{noupdate} ) {
				SetTokenSequence(
					$dbh,
					token_id => $token->{token_id},
					sequence => $seq
				);
			}
			if ( $opt->{differential} ) {
				return ( $seq - $sequence );
			} else {
				return ($seq);
			}
		}
	}
	return undef;
}

sub dump {
	my $token = shift;
	my $opt   = &_options(@_);

	my $issuestr = "";
	if ( $token->{issued_date} ) {
		$issuestr =
		  strftime( "%Y-%m-%d", gmtime( $token->{issued_date} ) );
	}
	if ( $opt->{brief} ) {
		my $status = $TokenStatus{ $token->{status} };
		$status = "X" if $status eq "DESTROYED";
		$status = substr( $status, 0, 1 );

		printf STDERR "%-6d (0x%08x)  %-12s %2d  %1s%1s%1s  %10s  %s\n",
		  $token->{token_id}, $token->{token_id}, $token->{serial},
		  $token->{type}, $status, ( $token->{pin} ? "+" : " " ),
		  ( ( $token->{token_locked} ) ? "@" : " " ), $issuestr,
		  ( $token->{login} || "" );
	} else {
		printf STDERR qq
{TokenId:           %d (0x%08x)
Serial Number:     %s
Type:              %s
Status:            %s
Issued:            %s
}, $token->{token_id}, $token->{token_id}, $token->{serial},
		  $TokenType{ $token->{type} }->{displayname},
		  $TokenStatus{ $token->{status} }, $issuestr;
		if ( $token->{type} == 1 ) {
			printf STDERR qq
{Zero Time:         %s
Time Modulo:       %d seconds
Current Time Skew: %d seconds
}, $token->{zero_time}, $token->{time_modulo}, $token->{time_skew};
		} else {
			printf STDERR "Current Sequence:  %d\n",
			  $token->{sequence};
		}
		if ( $opt->{keys} ) {
			if ( $token->{pin} ) {
				printf STDERR "PIN:               %s\n",
				  $token->{pin};
			}
			if ( $token->{key} ) {
				printf STDERR "Key:               %s\n",
				  $token->{key};
			}
		} else {
			if ( $token->{pin} ) {
				printf STDERR "PIN:               %s\n",
				  $token->{pin} ? "set" : "unset";
			}
		}
		if ( $token->{login} ) {
			printf STDERR "Assigned to:       %s\n",
			  $token->{login};

		    #			printf STDERR "Last Used:         %s\n",
		    #				($token->{sequence_changed} ?
		    #					scalar(gmtime($token->{sequence_changed})) : "Never");
		}
		if ( defined( $token->{altlogins} )
			&& @{ $token->{altlogins} } )
		{
			printf STDERR "Alternate logins:  %s\n", join ", ",
			  @{ $token->{altlogins} };
		}

		if ( $token->{token_locked} ) {
			print STDERR "TOKEN IS LOCKED.  ";
			if ( $token->{unlock_time} ) {
				strftime(
"Token will unlock at %Y-%m-%d %H:%M:%S %Z",
					gmtime( $token->{issued_date} )
				);
			} else {
				print STDERR
				  "Token must be manually unlocked.\n";
			}
		}
	}
}

1;
