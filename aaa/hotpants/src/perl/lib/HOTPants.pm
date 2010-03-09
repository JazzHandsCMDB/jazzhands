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
package HOTPants;

use 5.006;
use strict;
use warnings;
use BerkeleyDB;
use Crypt::Eksblowfish::Bcrypt qw(bcrypt en_base64);
use Math::BigInt;
use Digest::SHA qw(sha1 sha1_base64);
use Digest::HMAC qw(hmac);
use MIME::Base64;
use Data::Dumper;

my %__HOTPANTS_DB_NAME = (
	UserDB        => "user.db",
	TokenDB       => "token.db",
	AttrDB        => "attributes.db",
	ClientDB      => "client.db",
	DevCollPropDB => "devcoll_prop.db",
	PasswdDB      => "passwd.db",
);

my %__HOTPANTS_SERIALIZE_VERSION = (
	TOKEN       => 1,
	USER        => 2,
	ATTRIBUTES  => 1,
	CLIENT      => 1,
	DEVCOLLPROP => 1,
	PASSWD      => 1,
);

my %__HOTPANTS_CONFIG_PARAMS = (
	SequenceSkew          => 7,     # Normal amount of sequence skew allowed
	ResyncSequenceSkew    => 100,   # Amount of sequence skew allowed for
	                                # unassisted resync (i.e. two successive
	                                # auths)
	BadAuthsBeforeLockout => 6,     # Lock out user/token after attempts
	BadAuthLockoutTime    => 1800,  # Lock out time after bad attempts, in
	     # seconds (0 means must be administratively
	     # unlocked)
	DefaultAuthMech    => undef,   # Default to denying authentication if an
	                               # authentication mechanism is not defined
	PasswordExpiration => 90       # Number of days for password expiration
);

our ( $VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS );
our ( %TokenType, %TokenStatus, %UserStatus );

BEGIN {
	use Exporter ();
	our ( $VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS );

	$VERSION = '1.0';
	@ISA     = qw(Exporter);
	@EXPORT  = qw(
	  TT_UNDEF
	  TT_SOFT_SEQ
	  TT_SOFT_TIME
	  TT_ETOKEN_OTP32
	  TT_ETOKEN_OTP64
	  TT_ETOKEN_PASS
	  TT_DIGIPASS_GO3
	  TT_TOKMAX
	  TS_DISABLED
	  TS_ENABLED
	  TS_LOST
	  TS_STOLEN
	  TS_DESTROYED
	  US_DISABLED
	  US_ENABLED
	  US_DELETED
	);
	%EXPORT_TAGS = ();
	@EXPORT_OK   = ();

	our ( %TokenType, %TokenStatus, %UserStatus );

	#
	# Token type definitions
	#

	eval 'sub TT_UNDEF () {0x0;}' unless defined(&TT_UNDEF);
	$TokenType{&TT_UNDEF} = {
		displayname => "Undefined Token Type",
		digits      => 0
	};

	eval 'sub TT_SOFT_SEQ () {0x1;}' unless defined(&TT_SOFT_SEQ);
	$TokenType{&TT_SOFT_SEQ} = {
		displayname => "Sequence-based soft token",
		digits      => 8
	};

	eval 'sub TT_SOFT_TIME () {0x2;}' unless defined(&TT_SOFT_TIME);
	$TokenType{&TT_SOFT_TIME} = {
		displayname => "Time-based soft token",
		digits      => 8
	};

	eval 'sub TT_ETOKEN_OTP32 () {0x3;}' unless defined(&TT_ETOKEN_OTP32);
	$TokenType{&TT_ETOKEN_OTP32} = {
		displayname => "Aladdin eToken OTP32",
		digits      => 6
	};

	eval 'sub TT_ETOKEN_OTP64 () {0x4;}' unless defined(&TT_ETOKEN_OTP64);
	$TokenType{&TT_ETOKEN_OTP64} = {
		displayname => "Aladdin eToken OTP64",
		digits      => 6
	};

	eval 'sub TT_DIGIPASS_GO3 () {0x5;}' unless defined(&TT_DIGIPASS_GO3);
	$TokenType{&TT_DIGIPASS_GO3} = {
		displayname => "VASCO DigiPass Go3",
		digits      => 6
	};

	eval 'sub TT_ETOKEN_PASS () {0x6;}' unless defined(&TT_ETOKEN_PASS);
	$TokenType{&TT_ETOKEN_PASS} = {
		displayname => "Aladdin eToken PASS",
		digits      => 6
	};

	eval 'sub TT_TOKMAX () {0x7;}' unless defined(&TT_TOKMAX);
	$TokenType{&TT_TOKMAX} = {
		displayname => "Bad Value",
		digits      => 0
	};

	#
	# Token status definitions
	#
	eval 'sub TS_DISABLED () {0x0;}' unless defined(&TS_DISABLED);
	$TokenStatus{&TS_DISABLED} = "Disabled";

	eval 'sub TS_ENABLED () {0x1;}' unless defined(&TS_ENABLED);
	$TokenStatus{&TS_ENABLED} = "Enabled";

	eval 'sub TS_LOST () {0x2;}' unless defined(&TS_LOST);
	$TokenStatus{&TS_LOST} = "Lost";

	eval 'sub TS_STOLEN () {0x3;}' unless defined(&TS_STOLEN);
	$TokenStatus{&TS_STOLEN} = "Stolen";

	eval 'sub TS_DESTROYED () {0x4;}' unless defined(&TS_DESTROYED);
	$TokenStatus{&TS_DESTROYED} = "Destroyed";

	#
	# User status definitions
	#
	eval 'sub US_DISABLED () {0x0;}' unless defined(&US_DISABLED);
	$UserStatus{&US_DISABLED} = "Disabled";

	eval 'sub US_ENABLED () {0x1;}' unless defined(&US_ENABLED);
	$UserStatus{&US_ENABLED} = "Enabled";

	eval 'sub US_DELETED () {0x2;}' unless defined(&US_DELETED);
	$UserStatus{&US_DELETED} = "Deleted";

}

sub _options {
	my %ret = @_;
	for my $v ( grep { /^-/ } keys %ret ) {
		$ret{ substr( $v, 1 ) } = $ret{$v};
	}
	\%ret;
}

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $opt   = &_options;

	return undef if ( !$opt->{path} );

	my $self = {};
	$self->{dbpath} = $opt->{path};
	$self->{_debug} = defined( $opt->{debug} ) ? $opt->{debug} : 0;
	bless( $self, $class );
}

sub SetDebug {
	my $self = shift;
	if (@_) { $self->{_debug} = shift; }
	return $self->{_debug};
}

sub _Debug {
	my $self  = shift;
	my $level = shift;

	if ( $self->{_debug} >= $level ) {
		if (@_) { printf STDERR @_; print STDERR "\n"; }
	}
}

sub Error {
	my $self = shift;

	if (@_) { $self->{_error} = shift; }
	return $self->{_error};
}

sub Status {
	my $self = shift;

	if (@_) { $self->{_status} = shift; }
	return $self->{_status};
}

#
# Sets the error to display to a remote user
#
sub UserError {
	my $self = shift;

	if (@_) { $self->{_usererror} = shift; }
	return $self->{_usererror};
}

sub Config {
	my $self = shift;

	# return a copy of the config data

	my %ret = %__HOTPANTS_CONFIG_PARAMS;

	return \%ret;
}

sub opendb {
	my $self = shift;
	my $opt  = &_options;

	if ( $self->{Env} ) {
		$self->closedb();
	}

	my $env;
	if (
		!(
			$env = new BerkeleyDB::Env
			-Home    => $self->{dbpath},
			-ErrFile => $self->{dbpath} . "/db_error.log",
			-Flags   => DB_CREATE | DB_INIT_MPOOL | DB_INIT_LOCK |
			DB_INIT_LOG | DB_INIT_TXN | DB_REGISTER | DB_RECOVER
		)
	  )
	{
		undef $env;
		return "Unable to create environment";
	}

	$env->set_verbose(
		DB_VERB_REGISTER | DB_VERB_DEADLOCK | DB_VERB_RECOVERY |
		  DB_VERB_REPLICATION | DB_VERB_WAITSFOR,
		1
	);

	$env->set_flags( DB_LOG_AUTOREMOVE, 1 );

	#
	# Open all of the databases into the environment
	#
	my $txn = $env->txn_begin();

	foreach my $db ( keys %__HOTPANTS_DB_NAME ) {
		my $dbhandle;
		if (
			!(
				$dbhandle = new BerkeleyDB::Hash
				-Env      => $env,
				-Filename => $__HOTPANTS_DB_NAME{$db},
				-Flags    => DB_CREATE,
				-Txn      => $txn
			)
		  )
		{

		 #
		 # If the open failed, close any databases we did manage to open
		 #
			foreach my $dbclose ( keys %__HOTPANTS_DB_NAME ) {
				if ( defined( $self->{$dbclose} ) ) {
					$self->{$dbclose}->db_close;
					delete $self->{$dbclose};
				}
			}
			$txn->txn_abort();
			$env->close;
			undef $env;
			$self->Error(
				"Unable to open $db: $!" . $BerkeleyDB::Error );
			return "Unable to open $db: $!" . $BerkeleyDB::Error;
		}
		$self->{$db} = $dbhandle;
	}
	$txn->txn_commit();
	$self->{Env} = $env;

	return 0;
}

sub closedb {
	my $self = shift;
	return if !$self;
	return if !$self->{Env};
	foreach my $dbclose ( keys %__HOTPANTS_DB_NAME ) {
		if ( defined( $self->{$dbclose} ) ) {
			$self->{$dbclose}->db_close;
			delete $self->{$dbclose};
		}
	}
	$self->{Env}->close;
	delete $self->{Env};
	return 0;
}

sub fetch_token {
	my $self = shift;
	my $opt  = &_options;

	my $tokenid = $opt->{token_id};
	my $token;
	my ( $ret, $tokendata );

	# clear errors
	$self->Error(undef);

	if ( !$tokenid ) {
		$self->Error("fetch_token: Token id not passed");
		return undef;
	}

	#
	# bail if the database environment or token database are not defined
	#
	$self->Error(undef);
	if ( !$self->{Env} || !$self->{TokenDB} ) {
		$self->Error(
			"fetch_token: database environment is not defined");
		return undef;
	}

	if ( $ret =
		$self->{TokenDB}->db_get( pack( 'N', $tokenid ), $tokendata ) )
	{
		if ( $ret !~ /^DB_NOTFOUND/ ) {
			$self->Error( sprintf "Error retrieving token %d: %s",
				$token, $BerkeleyDB::Error );
		}
		return undef;
	}
	if ( !( $token = deserialize_token($tokendata) ) ) {
		$self->Error("Error deserializing token");
		return undef;
	}

	return $token;
}

sub fetch_all_tokens {
	my $self = shift;
	my ( $ret, $cursor, $tokenid, $tokendata );

	if ( !$self->{Env} || !$self->{TokenDB} ) {
		$self->Error(
			"fetch_all_tokens: database environment is not defined"
		);
		return undef;
	}

	# clear errors
	$self->Error(undef);

	my $tokens = {};
	$tokenid   = "";
	$tokendata = "";
	$cursor    = $self->{TokenDB}->db_cursor();
	while ( $cursor->c_get( $tokenid, $tokendata, DB_NEXT ) == 0 ) {
		$tokenid = unpack( 'N', $tokenid );
		$tokens->{$tokenid} = deserialize_token($tokendata);
	}
	$cursor->c_close;
	return $tokens;
}

sub fetch_user {
	my $self = shift;
	my $opt  = &_options;

	my $login = $opt->{login};
	my ( $ret, $userdata );
	my $userptr;

	if ( !$login ) {
		$self->Error("fetch_user: login not provided");
		return undef;
	}

	#
	# bail if the database environment or user database are not defined
	#
	if ( !$self->{Env} || !$self->{UserDB} ) {
		$self->Error("fetch_user: database environment is not defined");
		return undef;
	}

	# clear errors
	$self->Error(undef);

	if ( $ret = $self->{UserDB}->db_get( $login, $userdata ) ) {
		if ( $ret !~ /^DB_NOTFOUND/ ) {
			$self->Error( sprintf "Error retrieving user %s: %s",
				$login, $BerkeleyDB::Error );
		}
		return undef;
	}
	if ( !( $userptr = deserialize_user($userdata) ) ) {
		return undef;
	}

	return $userptr;
}

sub fetch_all_users {
	my $self = shift;
	my ( $ret, $cursor, $userid, $userdata );

	if ( !$self->{Env} || !$self->{UserDB} ) {
		$self->Error(
			"fetch_all_users: database environment is not defined");
		return undef;
	}

	# clear errors
	$self->Error(undef);

	my $users = {};
	$userid   = "";
	$userdata = "";
	$cursor   = $self->{UserDB}->db_cursor();
	while ( $cursor->c_get( $userid, $userdata, DB_NEXT ) == 0 ) {
		$userid = unpack( 'Z*', $userid );
		$users->{$userid} = deserialize_user($userdata);
	}
	$cursor->c_close;
	return $users;
}

sub fetch_client {
	my $self = shift;
	my $opt  = &_options;

	my $clientid = $opt->{client_id};
	my ( $ret, $clientdata );
	my $client;

	#
	# bail if the database environment or client database are not defined
	#
	if ( !$self->{Env} || !$self->{ClientDB} ) {
		$self->Error(
			"fetch_client: database environment is not defined");
		return undef;
	}

	# clear errors
	$self->Error(undef);

	if ( !$clientid ) {
		$self->Error("fetch_client: client id not passed");
		return undef;
	}

	if ( $ret = $self->{ClientDB}->db_get( $clientid, $clientdata ) ) {
		if ( $ret !~ /^DB_NOTFOUND/ ) {
			$self->Error(
				sprintf
				  "Error retrieving client data for %s: %s",
				$client, $BerkeleyDB::Error
			);
		}
		return undef;
	}
	if ( !( $client = deserialize_client($clientdata) ) ) {
		return undef;
	}
	$client->{client_id} = $clientid;

	return $client;
}

sub fetch_all_clients {
	my $self = shift;
	my ( $ret, $cursor, $clientid, $clientdata );

	if ( !$self->{Env} || !$self->{ClientDB} ) {
		$self->Error(
			"fetch_all_clients: database environment is not defined"
		);
		return undef;
	}

	# clear errors
	$self->Error(undef);

	my $clients = {};
	$clientid   = "";
	$clientdata = "";
	$cursor     = $self->{ClientDB}->db_cursor();
	while ( $cursor->c_get( $clientid, $clientdata, DB_NEXT ) == 0 ) {
		$clientid = unpack( 'Z*', $clientid );
		$clients->{$clientid} = deserialize_client($clientdata);
		$clients->{$clientid}->{client_id} = $clientid;
	}
	$cursor->c_close;
	return $clients;
}

sub fetch_devcollprop {
	my $self = shift;
	my $opt  = &_options;

	my $devcollid = $opt->{devcoll_id};
	my ( $ret, $devcollpropdata );
	my $devcollprop;

      #
      # bail if the database environment or devcollprop database are not defined
      #
	if ( !$self->{Env} || !$self->{DevCollPropDB} ) {
		$self->Error(
			"fetch_devcollprop: database environment is not defined"
		);
		return undef;
	}

	if ( !$devcollid ) {
		$self->Error("fetch_devcollprop: devcollid not passed");
		return undef;
	}

	# clear errors
	$self->Error(undef);

	if ( $ret =
		$self->{DevCollPropDB}->db_get( $devcollid, $devcollpropdata ) )
	{
		if ( $ret !~ /^DB_NOTFOUND/ ) {
			$self->Error(
				sprintf
"Error retrieving property data for devcoll %s: %s",
				$devcollid, $BerkeleyDB::Error
			);
		}
		return undef;
	}
	if ( !( $devcollprop = deserialize_devcollprop($devcollpropdata) ) ) {
		return undef;
	}

	return $devcollprop;
}

sub fetch_all_devcollprops {
	my $self = shift;
	my ( $ret, $cursor, $devcollpropid, $devcollpropdata );

	if ( !$self->{Env} || !$self->{DevCollPropDB} ) {
		$self->Error(
"fetch_all_devcollprops: database environment is not defined"
		);
		return undef;
	}

	# clear errors
	$self->Error(undef);

	my $devcollprops = {};
	$devcollpropid   = "";
	$devcollpropdata = "";
	$cursor          = $self->{DevCollPropDB}->db_cursor();
	while ( $cursor->c_get( $devcollpropid, $devcollpropdata, DB_NEXT ) ==
		0 )
	{
		$devcollpropid = unpack( 'Z*', $devcollpropid );
		$devcollprops->{$devcollpropid} =
		  deserialize_devcollprop($devcollpropdata);
	}
	$cursor->c_close;
	return $devcollprops;
}

sub fetch_passwd {
	my $self = shift;
	my $opt  = &_options;

	my $login = $opt->{login};
	my ( $ret, $passwddata );
	my $passwd;

	#
	# bail if the database environment or passwd database are not defined
	#
	if ( !$self->{Env} || !$self->{PasswdDB} ) {
		$self->Error(
			"fetch_passwd: database environment is not defined");
		return undef;
	}
	if ( !$login ) {
		$self->Error("fetch_passwd: login not passwd");
		return undef;
	}

	# clear errors
	$self->Error(undef);

	if ( $ret = $self->{PasswdDB}->db_get( $login, $passwddata ) ) {
		if ( $ret !~ /^DB_NOTFOUND/ ) {
			$self->Error(
				sprintf
				  "Error retrieving passwd data for %s: %s",
				$login, $BerkeleyDB::Error
			);
		}
		return undef;
	}
	if ( !( $passwd = deserialize_passwd($passwddata) ) ) {
		return undef;
	}

	return $passwd;
}

sub fetch_all_passwds {
	my $self = shift;
	my ( $ret, $cursor, $passwd, $passwddata );

	if ( !$self->{Env} || !$self->{PasswdDB} ) {
		$self->Error(
			"fetch_all_passwds: database environment is not defined"
		);
		return undef;
	}

	# clear errors
	$self->Error(undef);

	my $passwds = {};
	$passwd     = "";
	$passwddata = "";
	$cursor     = $self->{PasswdDB}->db_cursor();
	while ( $cursor->c_get( $passwd, $passwddata, DB_NEXT ) == 0 ) {
		$passwd = unpack( 'Z*', $passwd );
		$passwds->{$passwd} = deserialize_passwd($passwddata);
	}
	$cursor->c_close;
	return $passwds;
}

sub fetch_attributes {
	my $self = shift;
	my $opt  = &_options;

	my ( $ret, $attributedata );
	my $attribute;

	#
	# bail if the database environment or attribute database are not defined
	#
	if ( !$self->{Env} || !$self->{AttrDB} ) {
		$self->Error(
			"fetch_attributes: database environment is not defined"
		);
		return undef;
	}
	if ( !$opt->{key} && !( $opt->{login} && $opt->{devcoll_id} ) ) {
		$self->Error(
"fetch_attributes: key or login and devcollid must be passed"
		);
		return undef;
	}
	my $attributeid = $opt->{key}
	  || pack( "Z*N", $opt->{login}, $opt->{devcoll_id} );

	# clear errors
	$self->Error(undef);

	if ( $ret = $self->{AttrDB}->db_get( $attributeid, $attributedata ) ) {
		if ( $ret !~ /^DB_NOTFOUND/ ) {
			$self->Error(
				sprintf
"Error retrieving attribute data for login %s, devcoll %d: %s",
				unpack( "Z*N", $attributeid ),
				$BerkeleyDB::Error
			);
		}
		return undef;
	}
	if ( !( $attribute = deserialize_attributes($attributedata) ) ) {
		return undef;
	}

	return $attribute;
}

sub fetch_all_attributes {
	my $self = shift;
	my ( $ret, $cursor, $attributeid, $attributedata );

	if ( !$self->{Env} || !$self->{AttrDB} ) {
		$self->Error(
"fetch_all_attributes: database environment is not defined"
		);
		return undef;
	}

	# clear errors
	$self->Error(undef);

	my $attributes = {};
	$attributeid   = "";
	$attributedata = "";
	$cursor        = $self->{AttrDB}->db_cursor();
	while ( $cursor->c_get( $attributeid, $attributedata, DB_NEXT ) == 0 ) {
		$attributes->{$attributeid} =
		  deserialize_attributes($attributedata);
	}
	$cursor->c_close;
	return $attributes;
}

sub put_token {
	my $self  = shift;
	my $opt   = &_options;
	my $token = $opt->{token};
	my ( $ret, $tokendata );

	#
	# bail if the database environment or token database are not defined
	#
	if ( !$self->{Env} || !$self->{AttrDB} ) {
		$self->Error("put_token: database environment is not defined");
		return undef;
	}

	if ( !$token || !$token->{token_id} ) {
		$self->Error("put_token: token invalid or not passed");
		return undef;
	}

	# clear errors
	$self->Error(undef);

	if ( !( $tokendata = serialize_token($token) ) ) {
		return undef;
	}

	my $txn;
	$txn = $self->{Env}->txn_begin();
	if ( !$txn ) {
		return undef;
	}
	$self->{TokenDB}->Txn($txn);
	if ( $ret =
		$self->{TokenDB}
		->db_put( pack( 'N', $token->{token_id} ), $tokendata ) )
	{
		$txn->txn_abort;
		$self->{TokenDB}->Txn(undef);
		undef $txn;
		$self->Error($ret);
		return undef;
	}
	$txn->txn_commit;
	$self->{TokenDB}->Txn(undef);
	undef $txn;

	return 1;
}

sub delete_token {
	my $self = shift;
	my $opt  = &_options(@_);
	my $ret;
	my $token_id = $opt->{token_id} || $opt->{token}->{token_id};

	#
	# bail if the database environment or token database are not defined
	#
	if ( !$self->{Env} || !$self->{TokenDB} ) {
		$self->Error(
			"delete_token: database environment is not defined");
		return undef;
	}
	if ( !$token_id ) {
		$self->Error("delete_token: token_id not passed");
		return undef;
	}

	# clear errors
	$self->Error(undef);

	my $txn;
	$txn = $self->{Env}->txn_begin();
	if ( !$txn ) {
		return undef;
	}
	$self->{TokenDB}->Txn($txn);
	if ( $ret = $self->{TokenDB}->db_del( pack( 'N', $token_id ) ) ) {
		$txn->txn_abort;
		$self->{TokenDB}->Txn(undef);
		$self->Error($ret);
		return undef;
	}
	$txn->txn_commit;
	$self->{TokenDB}->Txn(undef);
	undef $txn;

	return 1;
}

sub put_user {
	my $self = shift;
	my $user = shift;
	my ( $ret, $userdata );

	#
	# bail if the database environment or user database are not defined
	#
	if ( !$self->{Env} || !$self->{UserDB} ) {
		$self->Error("put_user: database environment is not defined");
		return undef;
	}
	if ( !$user || !$user->{login} ) {
		$self->Error("put_user: user invalid or not passed");
		return undef;
	}

	# clear errors
	$self->Error(undef);

	if ( !( $userdata = serialize_user($user) ) ) {
		return undef;
	}

	my $txn;
	$txn = $self->{Env}->txn_begin();
	if ( !$txn ) {
		$self->Error("Could not begin transaction");
		return undef;
	}
	$self->{UserDB}->Txn($txn);
	if ( $ret = $self->{UserDB}->db_put( $user->{login}, $userdata ) ) {
		$txn->txn_abort;
		$self->{UserDB}->Txn(undef);
		$self->Error($ret);
		return undef;
	}
	$txn->txn_commit;
	$self->{UserDB}->Txn(undef);
	return 1;
}

sub delete_user {
	my $self  = shift;
	my $login = shift;
	my $ret;

	#
	# bail if the database environment or user database are not defined
	#
	if ( !$self->{Env} || !$self->{UserDB} ) {
		$self->Error(
			"delete_user: database environment is not defined");
		return undef;
	}
	if ( !$login ) {
		$self->Error("delete_user: login not passed");
		return undef;
	}

	my $txn;
	$txn = $self->{Env}->txn_begin();
	if ( !$txn ) {
		return undef;
	}
	$self->{UserDB}->Txn($txn);
	if ( $ret = $self->{UserDB}->db_del($login) ) {
		$txn->txn_abort;
		$self->{UserDB}->Txn(undef);
		$self->Error($ret);
		return undef;
	}
	$txn->txn_commit;
	$self->{UserDB}->Txn(undef);
	undef $txn;

	return 1;
}

sub put_client {
	my $self   = shift;
	my $client = shift;
	my ( $ret, $clientdata );

	#
	# bail if the database environment or client database are not defined
	#
	if ( !$self->{Env} || !$self->{ClientDB} ) {
		$self->Error("put_client: database environment is not defined");
		return undef;
	}
	if ( !$client || !$client->{client_id} ) {
		$self->Error("put_client: client invalid or not passed");
		return undef;
	}

	# clear errors
	$self->Error(undef);

	if ( !( $clientdata = serialize_client($client) ) ) {
		return undef;
	}

	my $txn;
	$txn = $self->{Env}->txn_begin();
	if ( !$txn ) {
		$self->Error("Could not begin transaction");
		return undef;
	}
	$self->{ClientDB}->Txn($txn);
	if ( $ret =
		$self->{ClientDB}->db_put( $client->{client_id}, $clientdata ) )
	{
		$txn->txn_abort;
		$self->{ClientDB}->Txn(undef);
		$self->Error($ret);
		return undef;
	}
	$txn->txn_commit;
	$self->{ClientDB}->Txn(undef);
	return 1;
}

sub delete_client {
	my $self      = shift;
	my $client_id = shift;
	my $ret;

	#
	# bail if the database environment or client database are not defined
	#
	if ( !$self->{Env} || !$self->{ClientDB} ) {
		$self->Error(
			"delete_client: database environment is not defined");
		return undef;
	}
	if ( !$client_id ) {
		$self->Error("delete_client: client_id not passed");
		return undef;
	}
	return undef if !$client_id;

	my $txn;
	$txn = $self->{Env}->txn_begin();
	if ( !$txn ) {
		return -1;
	}
	$self->{ClientDB}->Txn($txn);
	if ( $ret = $self->{ClientDB}->db_del($client_id) ) {
		$txn->txn_abort;
		$self->{ClientDB}->Txn(undef);
		$self->Error($ret);
		return undef;
	}
	$txn->txn_commit;
	$self->{ClientDB}->Txn(undef);
	undef $txn;

	return 1;
}

sub put_devcollprop {
	my $self        = shift;
	my $devcollprop = shift;
	my ( $ret, $devcollpropdata );

      #
      # bail if the database environment or devcollprop database are not defined
      #
	if ( !$self->{Env} || !$self->{DevCollPropDB} ) {
		$self->Error(
			"put_devcollprop: database environment is not defined");
		return undef;
	}
	if ( !$devcollprop || !$devcollprop->{devcoll_id} ) {
		$self->Error(
			"put_devcollprop: devcollprop is invalid or not passed"
		);
		return undef;
	}

	# clear errors
	$self->Error(undef);

	if ( !( $devcollpropdata = serialize_devcollprop($devcollprop) ) ) {
		return undef;
	}

	my $txn;
	$txn = $self->{Env}->txn_begin();
	if ( !$txn ) {
		$self->Error("Could not begin transaction");
		return undef;
	}
	$self->{DevCollPropDB}->Txn($txn);
	if ( $ret =
		$self->{DevCollPropDB}
		->db_put( $devcollprop->{devcoll_id}, $devcollpropdata ) )
	{
		$txn->txn_abort;
		$self->{DevCollPropDB}->Txn(undef);
		$self->Error($ret);
		return undef;
	}
	$txn->txn_commit;
	$self->{DevCollPropDB}->Txn(undef);
	return 1;
}

sub delete_devcollprop {
	my $self       = shift;
	my $devcoll_id = shift;
	my $ret;

      #
      # bail if the database environment or devcollprop database are not defined
      #
	if ( !$self->{Env} || !$self->{DevCollPropDB} ) {
		$self->Error(
"delete_devcollprop: database environment is not defined"
		);
		return undef;
	}
	if ( !$devcoll_id ) {
		$self->Error("delete_devcollprop: devcoll_id not passed");
		return undef;
	}

	my $txn;
	$txn = $self->{Env}->txn_begin();
	if ( !$txn ) {
		return -1;
	}
	$self->{DevCollPropDB}->Txn($txn);
	if ( $ret = $self->{DevCollPropDB}->db_del($devcoll_id) ) {
		$txn->txn_abort;
		$self->{DevCollPropDB}->Txn(undef);
		$self->Error($ret);
		return undef;
	}
	$txn->txn_commit;
	$self->{DevCollPropDB}->Txn(undef);
	undef $txn;

	return 1;
}

sub put_passwd {
	my $self   = shift;
	my $login  = shift;
	my $passwd = shift;
	my ( $ret, $passwddata );

	#
	# bail if the database environment or passwd database are not defined
	#
	if ( !$self->{Env} || !$self->{PasswdDB} ) {
		$self->Error("put_passwd: database environment is not defined");
		return undef;
	}
	if ( !$login ) {
		$self->Error("put_passwd: login not passed");
		return undef;
	}
	if ( !$passwd ) {
		$self->Error("put_passwd: passwd hash not passed");
		return undef;
	}

	# clear errors
	$self->Error(undef);

	if ( !( $passwddata = serialize_passwd($passwd) ) ) {
		return undef;
	}

	my $txn;
	$txn = $self->{Env}->txn_begin();
	if ( !$txn ) {
		$self->Error("Could not begin transaction");
		return undef;
	}
	$self->{PasswdDB}->Txn($txn);
	if ( $ret = $self->{PasswdDB}->db_put( $login, $passwddata ) ) {
		$txn->txn_abort;
		$self->{PasswdDB}->Txn(undef);
		$self->Error($ret);
		return undef;
	}
	$txn->txn_commit;
	$self->{PasswdDB}->Txn(undef);
	return 1;
}

sub delete_passwd {
	my $self  = shift;
	my $login = shift;
	my $ret;

	#
	# bail if the database environment or passwd database are not defined
	#
	if ( !$self->{Env} || !$self->{PasswdDB} ) {
		$self->Error(
			"delete_passwd: database environment is not defined");
		return undef;
	}
	if ( !$login ) {
		$self->Error("delete_passwd: login not passed");
		return undef;
	}

	my $txn;
	$txn = $self->{Env}->txn_begin();
	if ( !$txn ) {
		return -1;
	}
	$self->{PasswdDB}->Txn($txn);
	if ( $ret = $self->{PasswdDB}->db_del($login) ) {
		$txn->txn_abort;
		$self->{PasswdDB}->Txn(undef);
		$self->Error($ret);
		return undef;
	}
	$txn->txn_commit;
	$self->{PasswdDB}->Txn(undef);
	undef $txn;

	return 1;
}

sub put_attributes {
	my $self = shift;
	my $opt  = &_options(@_);

	my $attributes = $opt->{attrs};
	my ( $ret, $attributesdata );

       #
       # bail if the database environment or attributes database are not defined
       #
	if ( !$self->{Env} || !$self->{AttrDB} ) {
		$self->Error(
			"put_attributes: database environment is not defined");
		return undef;
	}
	if ( !$opt->{key} && !( $opt->{login} && $opt->{devcoll_id} ) ) {
		$self->Error(
"put_attributes: key or login and devcollid must be passed"
		);
		return undef;
	}
	my $attributeid = $opt->{key}
	  || pack( "Z*N", $opt->{login}, $opt->{devcoll_id} );

	if ( !$attributes ) {
		$self->Error("put_attributes: attribute hash not passed");
		return undef;
	}

	# clear errors
	$self->Error(undef);

	if ( !( $attributesdata = serialize_attributes($attributes) ) ) {
		return undef;
	}

	my $txn;
	$txn = $self->{Env}->txn_begin();
	if ( !$txn ) {
		$self->Error("Could not begin transaction");
		return undef;
	}
	$self->{AttrDB}->Txn($txn);
	if ( $ret = $self->{AttrDB}->db_put( $attributeid, $attributesdata ) ) {
		$txn->txn_abort;
		$self->{AttrDB}->Txn(undef);
		$self->Error($ret);
		return undef;
	}
	$txn->txn_commit;
	$self->{AttrDB}->Txn(undef);
	return 1;
}

sub delete_attributes {
	my $self = shift;
	my $ret;
	my $opt = &_options(@_);

       #
       # bail if the database environment or attributes database are not defined
       #
	if ( !$self->{Env} || !$self->{AttrDB} ) {
		$self->Error(
			"delete_attributes: database environment is not defined"
		);
		return undef;
	}

	if ( !$opt->{key} && !( $opt->{login} && $opt->{devcoll_id} ) ) {
		$self->Error(
"put_attributes: key or login and devcollid must be passed"
		);
		return undef;
	}
	my $attributeid = $opt->{key}
	  || pack( "Z*N", $opt->{login}, $opt->{devcoll_id} );

	my $txn;
	$txn = $self->{Env}->txn_begin();
	if ( !$txn ) {
		return -1;
	}
	$self->{AttrDB}->Txn($txn);
	if ( $ret = $self->{AttrDB}->db_del($attributeid) ) {
		$txn->txn_abort;
		$self->{AttrDB}->Txn(undef);
		$self->Error($ret);
		return undef;
	}
	$txn->txn_commit;
	$self->{AttrDB}->Txn(undef);
	undef $txn;

	return 1;
}

sub deserialize_token {
	my $tokendata = shift;
	my $token;
	my ($version) = unpack( 'N', $tokendata );

	my (
		$tokenid,       $type,         $status,
		$serial,        $key,          $sequence,
		$zero_time,     $time_modulo,  $skew_sequence,
		$pin,           $token_locked, $unlock_time,
		$last_login,    $bad_logins,   $sequence_changed,
		$token_changed, $lock_status_changed
	);

	if ( $version == 1 ) {
		(
			$tokenid,          $type,
			$status,           $serial,
			$key,              $sequence,
			$zero_time,        $time_modulo,
			$skew_sequence,    $pin,
			$last_login,       $token_locked,
			$unlock_time,      $bad_logins,
			$sequence_changed, $token_changed,
			$lock_status_changed
		) = unpack( 'x[N]N3Z*Z*N4Z*N7', $tokendata );

		$token = {
			token_id            => $tokenid,
			type                => $type,
			status              => $status,
			serial              => $serial,
			key                 => $key,
			sequence            => $sequence,
			zero_time           => $zero_time,
			time_modulo         => $time_modulo,
			skew_sequence       => $skew_sequence,
			pin                 => $pin,
			last_login          => $last_login,
			token_locked        => $token_locked,
			unlock_time         => $unlock_time,
			bad_logins          => $bad_logins,
			sequence_changed    => $sequence_changed,
			token_changed       => $token_changed,
			lock_status_changed => $lock_status_changed
		};
	} else {
		return undef;
	}
	return $token;
}

sub deserialize_user {
	my $userdata = shift;
	my $user;
	my ($version) = unpack( 'N', $userdata );

	if ( $version == 1 ) {
		my ( $login, $status, $last_login, $user_changed, @tokens );
		( $login, $status, $last_login, $user_changed, @tokens ) =
		  unpack( 'x[N]Z*N3N/N', $userdata );

		$user = {
			login        => $login,
			status       => $status,
			last_login   => $last_login,
			user_changed => $user_changed,
			bad_logins   => 0,
			user_locked  => 0,
			unlock_time  => 0,
			tokens       => \@tokens
		};
	} elsif ( $version == 2 ) {
		my (
			$login,       $status,
			$last_login,  $user_changed,
			@tokens,      $bad_logins,
			$user_locked, $unlock_time,
			$lock_status_changed
		);
		(
			$login,        $status,
			$last_login,   $bad_logins,
			$user_locked,  $unlock_time,
			$user_changed, $lock_status_changed,
			@tokens
		) = unpack( 'x[N]Z*N7N/N', $userdata );

		$user = {
			login               => $login,
			status              => $status,
			last_login          => $last_login,
			bad_logins          => $bad_logins,
			user_locked         => $user_locked,
			unlock_time         => $unlock_time,
			user_changed        => $user_changed,
			lock_status_changed => $lock_status_changed,
			tokens              => \@tokens
		};
	} else {
		return undef;
	}
	return $user;
}

sub deserialize_client {
	my $clientdata = shift;
	my $client;
	my ($version) = unpack( 'N', $clientdata );

	if ( $version == 1 ) {
		my ( $clientid, $name, $devcollid, $devcollname, $devcolltype )
		  = unpack( 'x[N]Z*Z*NZ*Z*', $clientdata );

		$client = {
			client_id    => $clientid,
			name         => $name,
			devcoll_id   => $devcollid,
			devcoll_name => $devcollname,
			devcoll_type => $devcolltype,
		};
	} else {
		return undef;
	}
	return $client;
}

sub deserialize_devcollprop {
	my $devcollpropdata = shift;
	my $devcollprop;
	my ($version) = unpack( 'N', $devcollpropdata );

	if ( $version == 1 ) {
		my ( $devcoll_id, $pwtype ) =
		  unpack( 'x[N]NZ*', $devcollpropdata );

		$devcollprop = {
			devcoll_id => $devcoll_id,
			pwtype     => $pwtype,
		};
	} else {
		return undef;
	}
	return $devcollprop;
}

sub deserialize_passwd {
	my $passwddata = shift;
	my %passwd;
	my ($version) = unpack( 'N', $passwddata );

	if ( $version == 1 ) {
		my (@pwtype) = unpack( 'x[N]N/(Z*Z*NN)', $passwddata );

		while (@pwtype) {
			my $type = shift @pwtype;
			$passwd{$type} = {
				passwd      => shift @pwtype,
				change_time => shift @pwtype,
				expire_time => shift @pwtype
			};
		}
	} else {
		return undef;
	}
	return \%passwd;
}

sub deserialize_attributes {
	my $attrdata = shift;
	my $attr     = {};
	my ($version) = unpack( 'N', $attrdata );

	if ( $version == 1 ) {
		my (@attrs) = unpack( 'x[N]N/(Z*Z*NZ*)', $attrdata );

		while (@attrs) {
			my $name       = shift @attrs;
			my $type       = shift @attrs;
			my $multivalue = shift @attrs;
			my $value      = shift @attrs;
			$attr->{$type} = {} if !$attr->{$type};
			if ( !$attr->{$type}->{$name} ) {
				$attr->{$type}->{$name} =
				  { multivalue => $multivalue };
				if ($multivalue) {
					$attr->{$type}->{$name}->{value} =
					  [$value];
				} else {
					$attr->{$type}->{$name}->{value} =
					  $value;
				}
			} else {
				if ($multivalue) {
					push
					  @{ $attr->{$type}->{$name}->{value} },
					  $value;
				}
			}
		}
	} else {
		return undef;
	}
	return $attr;
}

sub serialize_token {
	my $token = shift;
	my $tokendata;

	return undef if !$token || !$token->{token_id};

	$tokendata = pack( 'N4Z*Z*N4Z*N7',
		$__HOTPANTS_SERIALIZE_VERSION{TOKEN},
		$token->{token_id},
		$token->{type}                || TT_UNDEF,
		$token->{status}              || TS_DISABLED,
		$token->{serial}              || '',
		$token->{key}                 || '',
		$token->{sequence}            || 0,
		$token->{zero_time}           || 0,
		$token->{time_modulo}         || 0,
		$token->{skew_sequence}       || 0,
		$token->{pin}                 || '',
		$token->{last_login}          || 0,
		$token->{token_locked}        || 0,
		$token->{unlock_time}         || 0,
		$token->{bad_logins}          || 0,
		$token->{sequence_changed}    || 0,
		$token->{token_changed}       || 0,
		$token->{lock_status_changed} || 0 );
	return $tokendata;
}

sub serialize_user {
	my $user = shift;
	my $userdata;

	return undef if !$user || !$user->{login};
	my $numtokens = 0;
	if ( @{ $user->{tokens} } ) {
		$numtokens = $#{ $user->{tokens} } + 1;
	}

	$userdata = pack( "NZ*N8",
		$__HOTPANTS_SERIALIZE_VERSION{USER},
		$user->{login},
		$user->{status}              || US_DISABLED,
		$user->{last_login}          || 0,
		$user->{bad_logins}          || 0,
		$user->{user_locked}         || 0,
		$user->{unlock_time}         || 0,
		$user->{user_changed}        || 0,
		$user->{lock_status_changed} || 0,
		$numtokens );

	if ($numtokens) {
		$userdata .= pack( "N[$numtokens]", @{ $user->{tokens} } );
	}
	return $userdata;
}

sub serialize_client {
	my $client = shift;
	my $clientdata;

	return undef if !$client;
	$clientdata = pack( 'NZ*Z*NZ*Z*',
		$__HOTPANTS_SERIALIZE_VERSION{CLIENT},
		$client->{client_id},
		$client->{name},
		$client->{devcoll_id},
		$client->{devcoll_name},
		$client->{devcoll_type} );

	return $clientdata;
}

sub serialize_devcollprop {
	my $devcollprop = shift;
	my $devcollpropdata;

	return undef if !$devcollprop;
	my $numprops = 0;
	$devcollpropdata = pack( 'N2Z*',
		$__HOTPANTS_SERIALIZE_VERSION{DEVCOLLPROP},
		$devcollprop->{devcoll_id},
		$devcollprop->{pwtype} );

	return $devcollpropdata;
}

sub serialize_passwd {
	my $password = shift;
	my $passwddata;

	return undef if !$password;

	my $numpass = keys %$password;

	$passwddata =
	  pack( 'N2', $__HOTPANTS_SERIALIZE_VERSION{PASSWD}, $numpass );

	foreach my $key ( keys %$password ) {
		$passwddata .= pack( 'Z*Z*NN',
			$key,
			$password->{$key}->{passwd},
			$password->{$key}->{change_time},
			$password->{$key}->{expire_time},
		);
	}

	return $passwddata;
}

sub serialize_attributes {
	my $attrs    = shift;
	my $attrdata = undef;

	return undef if !$attrs;

	my $numattrs = 0;

	foreach my $type ( keys %$attrs ) {
		foreach my $name ( keys %{ $attrs->{$type} } ) {
			if ( $attrs->{$type}->{$name}->{multivalue} ) {
				foreach my $val (
					@{ $attrs->{$type}->{$name}->{value} } )
				{
					$attrdata .= pack( 'Z*Z*NZ*',
						$name, $type, 1, $val );
					$numattrs += 1;
				}
			} else {
				$attrdata .= pack( 'Z*Z*NZ*',
					$name, $type, 0,
					$attrs->{$type}->{$name}->{value} );
				$numattrs += 1;
			}
		}
	}

	$attrdata =
	  pack( 'N2', $__HOTPANTS_SERIALIZE_VERSION{ATTRIBUTES}, $numattrs )
	  . $attrdata;

	#	print STDERR unpack ('H*', $attrdata);
	#	print "\n";
	return $attrdata;
}

sub dump_token {
	my $opt = &_options;

	if ( !$opt->{token} ) {
		return undef;
	}
	my $token = $opt->{token};

	printf qq{
Token ID:             %08x (%d)
Type:                 %d (%s)
Status:               %d (%s)
Serial:               %s
Key:                  %s
PIN:                  %s
Current Sequence:     %d
Zero Time:            %s
Time Modulo:          %d
Skew Sequence:        %d
Token Locked:         %s
Unlock Time:          %s
Bad Logins:           %d
Last Login:           %s
Sequence Changed:     %s
Token Changed:        %s
Lock Status Changed:  %s
},
	  $token->{token_id},
	  $token->{token_id},
	  $token->{type},
	  $TokenType{ $token->{type} || TT_UNDEF },
	  $token->{status},
	  $TokenStatus{ $token->{status} || TS_DISABLED },
	  $token->{serial} || '',
	  $token->{key}
	  ? ( $opt->{verbose} ? $token->{key} : "Present" )
	  : "Not Set",
	  $token->{pin} ? ( $opt->{verbose} ? $token->{pin} : "Present" )
	  : "Not Set",
	  $token->{sequence} || 0,
	  scalar( gmtime( $token->{zero_time} || 0 ) ),
	  $token->{time_modulo}   || 0,
	  $token->{skew_sequence} || 0,
	  $token->{token_locked}  || 0,
	  $token->{unlock_time}   || 0,
	  $token->{bad_logins}    || 0,
	  scalar( gmtime( $token->{last_login}          || 0 ) ),
	  scalar( gmtime( $token->{sequence_changed}    || 0 ) ),
	  scalar( gmtime( $token->{token_changed}       || 0 ) ),
	  scalar( gmtime( $token->{lock_status_changed} || 0 ) );
}

sub dump_user {
	my $opt = &_options;

	if ( !$opt->{user} ) {
		return undef;
	}
	my $user = $opt->{user};

	printf qq{
Login:          %s
Status:         %d (%s)
Last Login:     %s
Last Changed:   %s
Tokens:         %s
},
	  $user->{login},
	  $user->{status},
	  $UserStatus{ $user->{status} || US_DISABLED },
	  $user->{last_login} ? scalar( gmtime( $user->{last_login} ) )
	  : "Never",
	  $user->{user_changed} ? scalar( gmtime( $user->{user_changed} ) )
	  : "Never", join(
		',',
		sort {
			$a <=> $b
		  } @{ $user->{tokens} }
	  );
}

sub HOTPAuthenticate {
	my $self = shift;
	my $opt  = &_options;
	my ($ret);

	#
	# bail if the database environment or token database are not defined
	#

	# Generic user error
	$self->UserError("Login incorrect");

	if ( !$self->{Env} || !$self->{TokenDB} ) {
		$self->Error("database environment not initialized");
		return undef;
	}

	my $login = $opt->{login};
	my $user  = $opt->{user};

	if ( !$login && !$user ) {
		$self->Error("login or user options required but not provided");
		return undef;
	}

	if ( !$user ) {
		if ( !( $user = $self->fetch_user( login => $login ) ) ) {
			if ( !$self->Error ) {
				$self->Error("unknown user");
				$self->UserError("Login incorrect");
				return undef;
			}
		}
	}
	$login = $user->{login};
	my $otp;
	if ( !( $otp = $opt->{otp} ) ) {
		$self->Error("otp option required but not provided");
		return undef;
	}

	$self->_Debug( 1, "Beginning HOTP authentication for %s", $login );

	my $authok = 0;
	my $errstr;

	my $validtoken = 0;
	my $pinfound   = 0;
	my ( $token, $tokenid );
	my ( $pin, $prn, $otplen );

	foreach $tokenid ( @{ $user->{tokens} } ) {
		$self->_Debug( 1, "Trying token %d for user %s",
			$tokenid, $login );
		if ( !( $token = $self->fetch_token( token_id => $tokenid ) ) )
		{
			$self->_Debug( 2,
				"Token %d assigned to %s not actually there",
				$tokenid, $login );
			next;
		}

		if ( !$token->{pin} ) {
			$self->_Debug( 2,
				"PIN not set for token %d.  Skipping.",
				$tokenid );
			next;
		}

		#
		# Token is valid
		#
		$validtoken = 1;

		#
		# Figure out what is the PIN and what is the OTP
		#

		if ( !$token->{type} || $token->{type} >= TT_TOKMAX ) {
			$self->_Debug( 1, "Invalid token type for token %d: %d",
				$tokenid, $token->{type} );
			next;
		}

		$otplen = $TokenType{ $token->{type} }->{digits};
		$self->_Debug( 2, "Number of OTP digits for token %d is %d",
			$tokenid, $otplen );
		if ( !$otplen ) {
			$self->_Debug( 1,
				"Invalid OTP digits defined for token %d",
				$tokenid );
			next;
		}

		if ( length($otp) < $otplen ) {
			$self->_Debug(
				2,
"OTP given less than minimal possible length for token %d",
				$tokenid
			);
			next;
		}

		$pin = substr( $otp, 0, length($otp) - $otplen );
		$prn = substr( $otp, length($otp) - $otplen );

		#
		# Check the PIN
		#
		my $crypt = bcrypt( $pin, $token->{pin} );
		if ( $token->{pin} eq bcrypt( $pin, $token->{pin} ) ) {

			$pinfound = 1;
			$self->_Debug( 2, "PIN is correct for token %d",
				$tokenid );
			last;
		} else {
			$self->_Debug(
				2,
"PIN is incorrect for token %d, expected %s, got %s",
				$tokenid,
				$token->{pin},
				$crypt
			);
			next;
		}
	}
	if ( !$validtoken ) {
		$errstr = "no valid tokens found for user";
		goto HOTPAuthDone;
	}
	if ( !$pinfound ) {
		$errstr = "PIN incorrect for all assigned tokens";
		goto HOTPAuthDone;
	}

	#
	# Verify that the token is enabled
	#
	if ( $token->{status} != TS_ENABLED ) {
		$self->Error(
			sprintf( "token %d is marked as %s",
				$TokenStatus{ $token->{status} } )
		);
		return undef;
	}

	#
	# Check if the token is locked
	#
	if ( $token->{token_locked} ) {
		if ( $token->{unlock_time} && $token->{unlock_time} <= time() )
		{
			$token->{token_locked}        = 0;
			$token->{unlock_time}         = 0;
			$token->{bad_logins}          = 0;
			$token->{lock_status_changed} = time();
			$self->_Debug( 2, "Unlocking token %d",
				$token->{token_id} );
			if ( !( $self->put_token( token => $token ) ) ) {
				$self->Error( "Error unlocking token %d: %s",
					$token->{token_id}, $self->Error );
				return undef;
			}
		} else {
			$errstr =
			  sprintf( "token %d is locked.", $token->{token_id} );
			if ( $token->{unlock_time} ) {
				$errstr .= sprintf(
					"  Token will unlock at %s",
					scalar(
						localtime(
							$token->{unlock_time}
						)
					)
				);
			} else {
				$errstr .=
				  "  Token must be administratively unlocked";
			}
			$self->Error($errstr);
			return undef;
		}
	}

	#
	# At this point, the user and the token are both fine and can be
	# authenticated
	#

	#
	# Check to see if we're looking for a specific sequence first to
	# resynchronize the token
	#
	my $sequence;
	if ( $token->{skew_sequence} ) {
		$sequence = $token->{skew_sequence} + 1;
		$self->_Debug( 2,
			"Expecting next token sequence %d for token %d",
			$sequence, $token->{token_id} );
		my $checkprn = GenerateHOTP(
			key      => $token->{key},
			sequence => $sequence,
			digits   => $otplen,
			keytype  => 'base64'
		);
		if ( !defined($checkprn) ) {
			$self->Error(
				sprintf(
"Unknown error generating OTP for token %d",
					$token->{token_id} )
			);
			return undef;
		}
		if ( $prn eq $checkprn ) {
			$authok = 1;
			goto HOTPAuthDone;
			$self->_Debug( 2,
				"Received token sequence %d for token %d",
				$sequence, $token->{token_id} );
			goto HOTPAuthDone;
		}
		$self->_Debug( 2,
			"Did not receive token sequence %d for token %d",
			$sequence, $token->{token_id} );
	}

	#
	# Either the token is not skewed, or the skew reset failed.  Perform
	# normal authentication
	#
	for (
		$sequence = $token->{sequence} +
		1 ;
		$sequence <= $token->{sequence} +
		$__HOTPANTS_CONFIG_PARAMS{ResyncSequenceSkew} ;
		$sequence++
	  )
	{

		my $checkprn = GenerateHOTP(
			key      => $token->{key},
			sequence => $sequence,
			digits   => $otplen,
			keytype  => 'base64'
		);
		if ( !defined($checkprn) ) {
			$self->Error(
				sprintf(
"Unknown error generating OTP for token %d",
					$token->{token_id} )
			);
			return undef;
		}
		$self->_Debug( 2, "Given PRN is %s.  PRN for sequence %d is %s",
			$prn, $sequence, $checkprn );
		last if ( $prn eq $checkprn );
	}

	#
	# If we don't get to it in ResyncSequenceSkew sequences, bail
	#
	if ( $sequence > $token->{sequence} +
		$__HOTPANTS_CONFIG_PARAMS{ResyncSequenceSkew} )
	{
		$errstr = sprintf(
"OTP given does not match a valid sequence for token %d",
			$token->{token_id} );
		goto HOTPAuthDone;
	}

	#
	# If we find the sequence, but it's between SequenceSkew and
	# ResyncSequenceSkew, but the token into next OTP mode
	#
	if ( $sequence >
		$token->{sequence} + $__HOTPANTS_CONFIG_PARAMS{SequenceSkew} )
	{
		$errstr = sprintf(
"OTP sequence %d for token %d outside of normal skew (expected less than %d).  Setting NEXT_OTP mode.",
			$sequence,
			$token->{token_id},
			$login,
			$token->{sequence} +
			  $__HOTPANTS_CONFIG_PARAMS{SequenceSkew}
		);
		$self->UserError(
"One-time password out of range.  Log in again with the next numbers displayed to resynchronize your token"
		);
		$token->{skew_sequence} = $sequence;
		goto HOTPAuthDone;
	}

	#
	# If we got here, it worked
	#
	$authok = 1;

      HOTPAuthDone:
	if ($authok) {
		$token->{skew_sequence}       = 0;
		$token->{bad_logins}          = 0;
		$token->{sequence}            = $sequence;
		$token->{lock_status_changed} = time;
		$self->Status(
			sprintf(
"user %s successfully authenticated with token %d",
				$login, $token->{token_id}
			)
		);
		$self->Error(undef);
	} else {
		if ($pinfound) {
			$token->{bad_logins} += 1;
			$self->_Debug( 2, "Bad logins for token %d now %d",
				$token->{token_id}, $token->{bad_logins} );
			$token->{lock_status_changed} = time;
			if ( $token->{bad_logins} >=
				$__HOTPANTS_CONFIG_PARAMS{BadAuthsBeforeLockout}
			  )
			{
				$self->_Debug( 2, "Locking token %d",
					$token->{token_id} );
				$token->{token_locked} = 1;
				if (
					$__HOTPANTS_CONFIG_PARAMS{BadAuthLockoutTime}
				  )
				{
					$token->{unlock_time} = time +
					  $__HOTPANTS_CONFIG_PARAMS{BadAuthLockoutTime};
				} else {
					$token->{unlock_time} = 0;
				}
			}
		}

	}

	#
	# Write token back to database
	#
	if ($pinfound) {
		if ( !( $self->put_token( token => $token ) ) ) {
			$self->Error( "Error updating token %d: %s",
				$token->{token_id}, $self->Error );
			return undef;
		}
	}
	$self->Error($errstr);
	if ($authok) {
		return 1;
	} else {
		return 0;
	}
}

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

sub AuthenticateUser {
	my $self = shift;
	my $opt  = &_options;
	my ($ret);
	my $err;

	#
	# Keep track of success or failure for locking the user
	#
	my $authsucceeded = 0;

	# Generic user error, clear status
	$self->UserError("Login incorrect");
	$self->Status(undef);

	#
	# bail if the database environment or token database are not defined
	#

	if ( !$self->{Env} || !$self->{TokenDB} ) {
		$self->Error("database environment not initialized");
		return undef;
	}

	my $login = $opt->{login};
	my $user  = $opt->{user};

	if ( !$login && !$user ) {
		$self->Error("login or user options required but not provided");
		return undef;
	}

	if ( !$user ) {
		if ( !( $user = $self->fetch_user( login => $login ) ) ) {
			if ( !$self->Error ) {
				$self->Error("unknown user");
				$self->UserError("Login incorrect");
				return undef;
			}
		}
	}
	$login = $user->{login};

	my $password;
	if ( !( $password = $opt->{passwd} ) ) {
		$self->Error("passwd option required but not provided");
		return undef;
	}

	my $source;
	if ( !( $source = $opt->{source} ) ) {
		$self->Error("source option required but not provided");
		return undef;
	}

	if ( !$self->VerifyUser( user => $user ) ) {
		return undef;
	}

	#
	# Fetch the client for the source (IP address or application name)
	# Return undef if the client does not exist.
	#
	my $client;
	if ( !( $client = $self->fetch_client( client_id => $source ) ) ) {
		if ( !$self->Error ) {
			$self->Error( sprintf( "unknown client", $source ) );
		}
		return undef;
	}

	#
	# Fetch client parameters for the device class.
	#
	my $devcollprop;

	if (
		!(
			$devcollprop = $self->fetch_devcollprop(
				devcoll_id => $client->{devcoll_id}
			)
		)
	  )
	{
		if ( $self->Error ) {
			return undef;
		}
	}

	#
	# If we don't have a device password method, use our default
	#
	my $authmech = $devcollprop->{pwtype};

	if ( defined($authmech) ) {
		$self->_Debug( 2, "Setting password type for client %s to %s",
			$client->{name}, $authmech );
	} else {
		$authmech = $__HOTPANTS_CONFIG_PARAMS{DefaultAuthMech};
		$self->_Debug( 2,
			"Setting password type for client %s to default (%s)",
			$client->{name}, $authmech || "undefined" );
	}

	#
	# See if the user has a password type override
	#

	my $attrs;
	if (
		!(
			$attrs = $self->fetch_attributes(
				login      => $login,
				devcoll_id => $client->{devcoll_id}
			)
		)
	  )
	{
		if ( $self->Error ) {
			return undef;
		}
	}

	if ( defined( $attrs->{__HOTPANTS_INTERNAL}->{PWType} ) ) {
		$authmech = $attrs->{__HOTPANTS_INTERNAL}->{PWType}->{value};
		$self->_Debug(
			2,
"Setting password type for user %s on client %s to (%s)",
			$login,
			$client->{name},
			$authmech || "undefined"
		);
	}

	#
	# See if the user has access to log in here
	#
	if ( !( $attrs->{__HOTPANTS_INTERNAL}->{GrantAccess} ) ) {
		$self->Error(
			sprintf(
"user %s does not have permission to log in to %s (%s)",
				$login, $source, $client->{name}
			)
		);
		return undef;
	}

	if ( !defined($authmech) || $authmech eq 'star' ) {
		$self->Error(
			sprintf(
"no password mechanisms defined to auth user %s on client %s (%s)",
				$login, $client->{name}, $source
			)
		);
		return undef;
	}

	if ( $authmech eq 'token' || $authmech eq 'oath' ) {
		$self->_Debug( 2,
			"Authenticating user %s on client %s with HOTP",
			$login, $client->{name} );

		if (
			$self->HOTPAuthenticate(
				user => $user,
				otp  => $password
			)
		  )
		{
			$authsucceeded = 1;
		}
		$err = $self->Error;
		return undef if ( $err =~ /^No tokens assigned/ );
		goto UserAuthDone;
	}

	my $passwd;
	if ( !( $passwd = $self->fetch_passwd( login => $login ) ) ) {
		if ( !$self->Error ) {
			$self->Error(
				sprintf(
"user must use %s to authenticate, but has no set passwords",
					$authmech )
			);
		}
		return undef;
	}

	if ( !defined( $passwd->{$authmech} ) ) {
		$self->Error(
			sprintf(
"user must use %s to authenticate, but does not have a password of that type",
				$authmech )
		);
		return undef;
	}

	my $p = $passwd->{$authmech};
	if ( $p->{expire_time} && $p->{expire_time} < time ) {
		$self->Error(
			sprintf(
				"%s password for %s expired %s",
				$authmech, $login,
				scalar( $p->{expire_time} )
			)
		);
		$self->UserError("Your password is expired");
		return undef;
	} elsif (  $p->{change_time}
		&& $p->{change_time} +
		( 86400 * $__HOTPANTS_CONFIG_PARAMS{PasswordExpiration} ) <
		time )
	{
		$self->Error(
			sprintf(
				"%s password for %s expired %s",
				$authmech,
				$login,
				scalar(
					$p->{change_time} + 86400 *
					  $__HOTPANTS_CONFIG_PARAMS{PasswordExpiration}
				)
			)
		);
		$self->UserError("Your password is expired");
		return undef;
	}

	my $checkpass = undef;
	if ( $authmech eq 'blowfish' ) {
		$checkpass = bcrypt( $password, $p->{passwd} );
	} elsif (  ( $authmech eq 'des' )
		|| ( $authmech eq 'md5' )
		|| ( $authmech eq 'networkdevice' ) )
	{
		$checkpass = crypt( $password, $p->{passwd} );
	}
	( $authmech eq 'sha1_nosalt' )  {
		  $checkpass = sha1_base64($password);
	  } else {
		  $self->Error(
			  sprintf(
"unsupported authentication mechanism %s authenticating user %s for client %s",
				  $authmech, $login, $client->{name}
			  )
		  );
		  return undef;
	}

	$self->_Debug( 2, "Authenticating user %s on client %s with %s",
		  $login, $client->{name}, $authmech );
	if (         $p->{passwd} eq $checkpass
		  || $p->{passwd} eq ( $checkpass . "=" ) )
	  {
		  $authsucceeded = 1;
	} else {
		  $self->_Debug(
			  2,
"User %s failed authentication on client %s with %s: expected %s, got %s",
			  $login,
			  $client->{name},
			  $authmech,
			  $checkpass,
			  $p->{passwd}
		  );
	}

      UserAuthDone:
	if ($authsucceeded) {
		  if ( !$self->Status ) {
			  $self->Status(
				  sprintf(
"user %s successfully authenticated using %s for client %s",
					  $login, $authmech,
					  $client->{name}
				  )
			  );
		  }
		  $user->{bad_logins}          = 0;
		  $user->{lock_status_changed} = time;
		  $user->{last_login}          = time;
	} else {
		  if ( !$self->Error ) {
			  $self->Error(
				  sprintf(
"user %s unsuccessfully authenticated using %s for client %s",
					  $login, $authmech,
					  $client->{name}
				  )
			  );
			  $self->_Debug( 2, $self->Error );
		  }
		  $user->{bad_logins} += 1;
		  $user->{lock_status_changed} = time;
		  if ( $user->{bad_logins} >=
			  $__HOTPANTS_CONFIG_PARAMS{BadAuthsBeforeLockout} )
		  {
			  $self->_Debug( 2, "Locking user %s", $login );
			  $self->Error( $self->Error . " - locking user" );
			  $user->{user_locked} = 1;
			  if ( $__HOTPANTS_CONFIG_PARAMS{BadAuthLockoutTime} ) {
				  $user->{unlock_time} = time +
				    $__HOTPANTS_CONFIG_PARAMS{BadAuthLockoutTime};
			  } else {
				  $user->{unlock_time} = 0;
			  }
		  }
	}

	$err = $self->Error;
	if ( !( $self->put_user($user) ) ) {
		  $self->Error( "Error updating user %s: %s",
			  $login, $self->Error );
		  $self->Status(undef);
		  return undef;
	}
	if ($err) {
		  $self->Error($err);
	}
	return $authsucceeded;
}

sub VerifyUser {
	  my $self = shift;
	  my $opt  = &_options;

	  $self->Error(undef);

	  #
	  # bail if the database environment or token database are not defined
	  #

	  if ( !$self->{Env} || !$self->{TokenDB} ) {
		  $self->Error("database environment not initialized");
		  return undef;
	  }

	  my $login = $opt->{login};
	  my $user  = $opt->{user};

	  if ( !$login && !$user ) {
		  $self->Error(
			  "login or user options required but not provided");
		  return undef;
	  }

	  if ( !$user ) {
		  if ( !( $user = $self->fetch_user( login => $login ) ) ) {
			  if ( !$self->Error ) {
				  $self->Error("unknown user");
				  return undef;
			  }
		  }
	  }
	  $login = $user->{login};

	  #
	  # Check if the user is locked
	  #
	  if ( $user->{user_locked} ) {
		  if ( $user->{unlock_time} && $user->{unlock_time} <= time() )
		  {
			  $user->{user_locked}         = 0;
			  $user->{unlock_time}         = 0;
			  $user->{lock_status_changed} = time();
			  $self->_Debug( 2, "Unlocking user %s", $login );
			  if ( !( $self->put_user($user) ) ) {
				  $self->Error( "Error unlocking user %s: %s",
					  $login, $self->Error );
				  return undef;
			  }
		  } else {
			  my $errstr = sprintf( "user %s is locked.", $login );
			  if ( $user->{unlock_time} ) {
				  $errstr .= sprintf(
					  "  User will unlock at %s",
					  scalar(
						  localtime(
							  $user->{unlock_time}
						  )
					  )
				  );
			  } else {
				  $errstr .=
				    "  User must be administratively unlocked.";
			  }
			  $self->Error($errstr);
			  return undef;
		  }
	  }
	  $self->_Debug( 2, "user %s is valid", $login );
	  return 1;
}

sub AuthorizeUser {
	  my $self = shift;
	  my $opt  = &_options;
	  my ($ret);

	  # Generic user error, clear status
	  $self->UserError("Login incorrect");
	  $self->Status(undef);

	  #
	  # bail if the database environment or token database are not defined
	  #

	  if ( !$self->{Env} || !$self->{TokenDB} ) {
		  $self->Error("database environment not initialized");
		  return undef;
	  }

	  my $login = $opt->{login};
	  my $user  = $opt->{user};

	  if ( !$login && !$user ) {
		  $self->Error(
			  "login or user options required but not provided");
		  return undef;
	  }

	  if ( !$user ) {
		  if ( !( $user = $self->fetch_user( login => $login ) ) ) {
			  if ( !$self->Error ) {
				  $self->Error("unknown user");
				  $self->UserError("Login incorrect");
				  return undef;
			  }
		  }
	  }
	  $login = $user->{login};

	  my $source;
	  if ( !( $source = $opt->{source} ) ) {
		  $self->Error("source option required but not provided");
		  return undef;
	  }

	  if ( !$self->VerifyUser( user => $user ) ) {
		  return undef;
	  }

	  #
	  # Fetch the client for the source (IP address or application name)
	  # Return undef if the client does not exist.
	  #
	  my $client;
	  if ( !( $client = $self->fetch_client( client_id => $source ) ) ) {
		  if ( !$self->Error ) {
			  $self->Error(
				  sprintf( "Client %s not found", $source ) );
		  }
		  return undef;
	  }

	  #
	  # Fetch client parameters for the device class.
	  #
	  my $devcollprop;

	  if (
		  !(
			  $devcollprop = $self->fetch_devcollprop(
				  devcoll_id => $client->{devcoll_id}
			  )
		  )
	    )
	  {
		  if ( $self->Error ) {
			  return undef;
		  }
	  }

	  #
	  # If we don't have a device password method, use our default
	  #
	  my $authmech = $devcollprop->{pwtype};

	  if ( defined($authmech) ) {
		  $self->_Debug( 2, "Setting password type for client %s to %s",
			  $client->{name}, $authmech );
	  } else {
		  $authmech = $__HOTPANTS_CONFIG_PARAMS{DefaultAuthMech};
		  $self->_Debug(
			  2,
			  "Setting password type for client %s to default (%s)",
			  $client->{name},
			  $authmech || "undefined"
		  );
	  }

	  #
	  # See if the user has a password type override
	  #

	  my $attrs;
	  if (
		  !(
			  $attrs = $self->fetch_attributes(
				  login      => $login,
				  devcoll_id => $client->{devcoll_id}
			  )
		  )
	    )
	  {
		  if ( $self->Error ) {
			  return undef;
		  }
	  }

	  if ( defined( $attrs->{__HOTPANTS_INTERNAL}->{PWType} ) ) {
		  $authmech = $attrs->{__HOTPANTS_INTERNAL}->{PWType}->{value};
		  $self->_Debug(
			  2,
"Setting password type for user %s on client %s to (%s)",
			  $login,
			  $client->{name},
			  $authmech || "undefined"
		  );
	  }

	  #
	  # See if the user has access to log in here
	  #
	  if ( !( $attrs->{__HOTPANTS_INTERNAL}->{GrantAccess} ) ) {
		  $self->Error(
			  sprintf(
"User %s does not have access to log in to %s (%s)",
				  $login, $source, $client->{name}
			  )
		  );
		  return undef;
	  }

	  if ( !defined($authmech) || $authmech eq 'star' ) {
		  $self->Error(
			  sprintf(
"No password mechanisms defined to auth user %s on client %s (%s)",
				  $login, $client->{name}, $source
			  )
		  );
		  return undef;
	  }

	  if ( $authmech eq 'token' || $authmech eq 'oath' ) {
		  $self->_Debug( 2,
			  "Authenticating user %s on client %s with HOTP",
			  $login, $client->{name} );

		  if ( !@{ $user->{tokens} } ) {
			  $self->Error( "No tokens assigned to " . $login );
			  return undef;
		  }
		  return 1;
	  }

	  my $passwd;
	  if ( !( $passwd = $self->fetch_passwd( login => $login ) ) ) {
		  if ( !$self->Error ) {
			  $self->Error(
				  sprintf(
"User must use %s to authenticate, but has no set passwords",
					  $authmech )
			  );
		  }
		  return undef;
	  }

	  if ( !defined( $passwd->{$authmech} ) ) {
		  $self->Error(
			  sprintf(
"User must use %s to authenticate, but does not have a password of that type",
				  $authmech )
		  );
		  return undef;
	  }

	  return 1;
}

1;
