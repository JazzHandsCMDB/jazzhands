
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

#
# Copyright (c) 2015, Todd M. Kover
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


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
use JazzHands::DBI;

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
	TimeSequenceSkew      => 2,     # sequence skew allowed for time-based
	                                # tokens
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
	PasswordExpiration => 365       # Number of days for password expiration
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

	# return undef if ( !$opt->{path} );

	my $self = {};
	$self->{_debug} = defined( $opt->{debug} ) ? $opt->{debug} : 0;
	bless( $self, $class );
	$self->opendb();
	
	$self;
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


	if (@_) { 
		my $fmt = shift;
		if (@_) {
			$self->{_error} = sprintf($fmt, @_);
		} else {
			$self->{_error} = $fmt;
		}
	}
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

	if ( $self->{dbh} ) {
		$self->closedb();
	}

	my $dbh;
	if (
		!(
			$dbh = JazzHands::DBI->connect(
				'hotpants', { AutoCommit => 0 }
			)
		)
	  )
	{
		undef $dbh;
		return "Unable to create environment";
	}

	$self->{dbh} = $dbh;
	return 0;
}

sub closedb {
	my $self = shift;
	return if !$self;
	return if !$self->{dbh};

	$self->{dbh}->rollback();
	$self->{dbh}->disconnect();
	delete $self->{dbh};
	return 0;
}

sub fetch_token {
	my $self = shift;
	my $opt  = &_options;

	my $tokenid = $opt->{token_id};
	my $token;
	my ( $ret, $tokendata );

	#
	# bail if there is no db connection
	#
	if ( !$self->{dbh} ) {
		$self->Error("fetch_token: no connection to database");
		return undef;
	}

	# clear errors
	$self->Error(undef);

	if ( !$tokenid ) {
		$self->Error("fetch_token: user id not passed");
		return undef;
	}

	# views in the db not here: time_skew, last_updated expire_time
	# things in the bdb file that are not in the db:
	# last_login token_locked unlock_time bad_logins
	# sequence_changed token_changed lock_status_changed
	# skew_sequence,
	# XXX - does not gracefully handle when an account is assigned to multiple
	# users!
	my $dbh = $self->{dbh};
	my $sth = $dbh->prepare_cached(
		qq{
			SELECT
					token_id,
					token_type,
					token_status,
					token_serial,
					token_key,
					zero_time,
					time_modulo,
					token_pin,
					is_user_token_locked,
					token_unlock_time as lock_status_changed,
					bad_logins,
					token_sequence,
					ts.last_updated as sequence_changed
			FROM	token t
					INNER JOIN account_token at USING (token_id)
					INNER JOIN token_sequence ts USING (token_id)
			WHERE	token_id = ?

	});

	# XXX - syncradius.pl also does stuff with radius_app.

	if ( !$sth ) {
		$self->Error(
			"fetch_token: unable to prepare sth: " . $dbh->errstr );
		return undef;
	}

	if ( !( $sth->execute($tokenid) ) ) {
		$self->Error( "fetch_token: execute failed: " . $dbh->errstr );
		return undef;
	}

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;

	if ( !$hr ) {
		return undef;
	}

	# XXX - other attributes listed above are not included.  some grew
	# token_ prefixes.
	return $hr;
}

sub fetch_user {
	my $self = shift;
	my $opt  = &_options;

	my $login = $opt->{login};
	my ( $ret, $userdata );
	my $userptr;

	#
	# bail if there is no db connection
	#
	if ( !$self->{dbh} ) {
		$self->Error("fetch_user: no connection to database");
		return undef;
	}

	# clear errors
	$self->Error(undef);

	if ( !$login ) {
		$self->Error("fetch_user: user id not passed");
		return undef;
	}

	my $dbh = $self->{dbh};
	my $sth = $dbh->prepare_cached(
		qq{
		SELECT	LOGIN, account_status, 
				array_agg(token_id ORDER BY token_id)  as tokens
		FROM	v_corp_family_account
				LEFT JOIN account_token USING (account_id)
		WHERE	is_enabled = 'Y'
		AND		login = ?
		GROUP BY LOGIN, account_status

	}
	);

	# XXX - syncradius.pl also does stuff with radius_app.

	if ( !$sth ) {
		$self->Error(
			"fetch_user: unable to prepare sth: " . $dbh->errstr );
		return undef;
	}

	if ( !( $sth->execute($login) ) ) {
		$self->Error( "fetch_user: execute failed: " . $dbh->errstr );
		return undef;
	}

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;

	if ( !$hr ) {
		return undef;
	}

	# XXX - numerous other attributes, including token ids here
	return {
		login  => $hr->{login},
		status => $hr->{account_status},
		tokens => $hr->{tokens},
	};
}

sub fetch_client {
	my $self = shift;
	my $opt  = &_options;

	my $clientid = $opt->{client_id};
	my ( $ret, $clientdata );
	my $client;

	#
	# bail if there is no db connection
	#
	if ( !$self->{dbh} ) {
		$self->Error("fetch_client: no connection to database");
		return undef;
	}

	# clear errors
	$self->Error(undef);

	if ( !$clientid ) {
		$self->Error("fetch_client: client id not passed");
		return undef;
	}

	my $dbh = $self->{dbh};
	my $sth = $dbh->prepare_cached(
		qq{
				SELECT DISTINCT
	                Device_Id,
	                Device_Name,
	                Device_Collection_Id,
	                Device_Collection_Name,
	                Device_Collection_Type,
	                host(IP_Address) as IP_address
	        FROM	Device_Collection
	                INNER JOIN device_collection_device
	                        USING (Device_Collection_ID) 
	                INNER JOIN Device USING (Device_Id) 
	                INNER JOIN Network_Interface NI USING (Device_ID) 
	                INNER JOIN Netblock NB USING (Netblock_id)
	        WHERE
	                Device_Collection_Type = 'mclass'
	        AND     Device_Name IS NOT NULL
	        AND     Device_Name IS NOT NULL
				AND		host(ip_address) = ?
	}
	);

	# XXX - syncradius.pl also does stuff with radius_app.

	if ( !$sth ) {
		$self->Error( "fetch_client: unable to prepare sth: "
			  . $dbh->errstr );
		return undef;
	}

	if ( !( $sth->execute($clientid) ) ) {
		$self->Error( "fetch_client: execute failed: " . $dbh->errstr );
		return undef;
	}

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;

	if ( !$hr ) {
		return undef;
	}

	return {
		client_id    => $clientid,
		name         => $hr->{device_name},
		devcoll_id   => $hr->{device_collection_id},
		devcoll_name => $hr->{device_collection_name},
		devcoll_type => $hr->{device_collection_type},
	};
}

sub fetch_devcollprop {
	my $self = shift;
	my $opt  = &_options;

	my $devcollid = $opt->{devcoll_id};
	my ( $ret, $devcollpropdata );
	my $devcollprop;

	#
	# bail if there is no db connection
	#
	if ( !$self->{dbh} ) {
		$self->Error("fetch_devcollprop: no connection to database");
		return undef;
	}

	# clear errors
	$self->Error(undef);

	if ( !$devcollid ) {
		$self->Error("fetch_devcollprop: devcollid not passed");
		return undef;
	}

	my $dbh = $self->{dbh};
	my $sth = $dbh->prepare_cached(
		qq{
		SELECT	device_collection_id, Property_Value_Password_Type
		FROM	property
		WHERE	Property_Name = 'UnixPwType'
		AND		Property_Type = 'MclassUnixProp'
		AND		device_collection_id = ?
	}
	);

	# XXX - syncradius.pl also does stuff with radius_app.

	if ( !$sth ) {
		$self->Error(
			"fetch_devcollprop: unable to prepare sth: " . $dbh->errstr );
		return undef;
	}

	if ( !( $sth->execute($devcollid) ) ) {
		$self->Error( "fetch_devcollprop: execute failed: " . $dbh->errstr );
		return undef;
	}

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;

	if ( !$hr ) {
		return undef;
	}

	my $r= {
		devcoll_id => $hr->{device_collection_id},
		pwtype => $hr->{password_type}
	};
	$r;
}

sub fetch_passwd {
	my $self = shift;
	my $opt  = &_options;

	my $login = $opt->{login};

	#
	# bail if there is no db connection
	#
	if ( !$self->{dbh} ) {
		$self->Error("fetch_passwd: no connection to database");
		return undef;
	}

	# clear errors
	$self->Error(undef);

	# clear errors
	$self->Error(undef);

	if ( !$login ) {
		$self->Error("fetch_passwd: login not passed");
		return undef;
	}

	my $dbh = $self->{dbh};
	my $sth = $dbh->prepare_cached(
		qq{
		SELECT	ap.account_id,
				ap.account_realm_id,
				ap.password_type,
				ap.password,
				extract(epoch from ap.change_time)::integer as change_time,
				extract(epoch from ap.expire_time)::integer as expire_time,
				extract(epoch from ap.unlock_time)::integer as unlock_time
		FROM	account_password ap
				inner join v_corp_family_account a
					USING (account_id)
		WHERE	login = ?
	}
	);

	# XXX - syncradius.pl also does stuff with radius_app.

	if ( !$sth ) {
		$self->Error(
			"fetch_passwd: unable to prepare sth: " . $dbh->errstr );
		return undef;
	}

	if ( !( $sth->execute($login) ) ) {
		$self->Error( "fetch_passwd: execute failed: " . $dbh->errstr );
		return undef;
	}

	my $rv = {};
	while( my $hr = $sth->fetchrow_hashref() ) {
		$rv->{ $hr->{password_type} } = {
			passwd => $hr->{password},
			change_time => $hr->{change_time},
			expire_time => $hr->{expire_time},
		};
	}


	if ( ! keys %{$rv} ) {
		return undef;
	}

	return $rv;
}


sub fetch_attributes {
	my $self = shift;
	my $opt  = &_options;

	my ( $ret, $attributedata );
	my $attribute;

	#
	# bail if there is no db connection
	#
	if ( !$self->{dbh} ) {
		$self->Error("fetch_attributes: no connection to database");
		return undef;
	}

	# clear errors
	$self->Error(undef);

	my $login = $opt->{login};
	my $dcid = $opt->{devcoll_id};

	if ( !$login || !$dcid) {
		$self->Error("fetch_attributes: must specify both a account and device collection");
		return undef;
	}

	# XXX - V_Dev_Col_User_Prop_Expanded needs to have mutlivalue fixed and
	#	have the multivalue logic pulled from teh syncer
	# view also needs account.is_enabled and  possibly v_corp_family_account

	my $dbh = $self->{dbh};
	my $sth = $dbh->prepare_cached(
		qq{
	       SELECT
	                Login,
	                Property_Name,
	                Property_Type,
					property_value,
	                Is_Boolean,
	                Device_Collection_ID
	        FROM
	                V_Dev_Col_User_Prop_Expanded JOIN
	                Device_Collection USING (Device_Collection_ID)
	        WHERE
					is_enabled = 'Y'
	        AND     (Device_Collection_Type = 'radius_app' OR
	                	Property_Type = 'RADIUS')
			AND		login = ?
			AND		device_collection_id = ?
	}
	);

	if ( !$sth ) {
		$self->Error(
			"fetch_attributes: unable to prepare sth: " . $dbh->errstr );
		return undef;
	}

	if ( !( $sth->execute($login, $dcid) ) ) {
		$self->Error( "fetch_attributes: execute failed: " . $dbh->errstr );
		return undef;
	}
	my $count = 0;
	my $attr = {};
	# XXX need to properly support multivalue
	while(my $hr = $sth->fetchrow_hashref) {
		$attr-> { $hr->{property_type} }->{ $hr->{property_name} }=
			{
				name => $hr->{property_name},
				value => $hr->{property_value},
				multivalue => 'N',
			};
		$count++;
	}
	$sth->finish;

	if ( !$count ) {
		return undef;
	}

	return $attr;
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

	# XXX
	return 1;

	#
	# bail if the database environment or token database are not defined
	#
	if ( !$self->{Env} || !$self->{TokenDB} ) {
		$self->Error(
			"delete_token: database environment is not defined");
		return undef;
	}
	if ( !$user || !$user->{login} ) {
		$self->Error("put_user: user invalid or not passed");
		return undef;
	}

	# clear errors
	$self->Error(undef);

	# XXX - should be tweaked to use the generic only update changed columns
	# code
	my $dbh = $self->{dbh};
	my $sth = $dbh->prepare_cached(
		qq{
			UPDATE account
			SET	status = :status,
				last_login = :last_login,
				bad_logins = :last_login,
	       SELECT
	                Login,
	                Property_Name,
	                Property_Type,
					property_value,
	                Is_Boolean,
	                Device_Collection_ID
	        FROM
	                V_Dev_Col_User_Prop_Expanded JOIN
	                Device_Collection USING (Device_Collection_ID)
	        WHERE
					is_enabled = 'Y'
	        AND     (Device_Collection_Type = 'radius_app' OR
	                	Property_Type = 'RADIUS')
			AND		login = ?
			AND		device_collection_id = ?
	}
	);

	if ( !$sth ) {
		$self->Error(
			"fetch_attributes: unable to prepare sth: " . $dbh->errstr );
		return undef;
	}


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
	# bail if there is no db connection 
	#
	if ( !$self->{dbh} ) {
		$self->Error("fetch_token: no connection to database");
		return undef;
	}

	# Generic user error
	$self->UserError("Login incorrect");

	# clear errors
	$self->Error(undef);

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

		if ( !$token->{token_pin} ) {
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

		if ( !$token->{token_type} || $token->{token_type} >= TT_TOKMAX ) {
			$self->_Debug( 1, "Invalid token type for token %d: %d",
				$tokenid, $token->{token_type} );
			next;
		}

		# $otplen = $TokenType{ $token->{token_type} }->{digits};
		# XXX
		$otplen = 6;
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
		my $crypt = bcrypt( $pin, $token->{token_pin} );
		if ( $token->{token_pin} eq bcrypt( $pin, $token->{token_pin} ) ) {

			$pinfound = 1;
			$self->_Debug( 2, "PIN is correct for token %d",
				$tokenid );
			last;
		} else {
			$self->_Debug(
				2,
				"PIN is incorrect for token %d, expected %s, got %s",
				$tokenid,
				$token->{token_pin},
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
#	if ( $token->{token_status} != TS_ENABLED ) {
#		$self->Error(
#			sprintf( "token %d is marked as %s", $tokenid,
#				$TokenStatus{ $token->{token_status} } )
#		);
#		return undef;
#	}

	#
	# Check if the token is locked
	#
	if ( !$token->{is_user_token_locked} || $token->{is_user_token_locked} eq 'Y') {
		if ( $token->{unlock_time} && $token->{unlock_time} <= time() )
		{
			$token->{is_user_token_locked}        = 'N';
			$token->{token_unlock_time}         = 0;
			$token->{token_bad_logins}          = 0;
			$token->{last_updated} = time();
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
			if ( $token->{token_unlock_time} ) {
				$errstr .= sprintf(
					"  Token will unlock at %s",
					scalar(
						localtime(
							$token->{token_unlock_time}
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
	if ( $token->{time_skew} ) {
		$sequence = $token->{time_skew} + 1;
		$self->_Debug( 2,
			"Expecting next token sequence %d for token %d",
			$sequence, $token->{token_id} );
		my $checkprn = GenerateHOTP(
			key      => $token->{token_key},
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

	my $initialseq;
	my $maxskew;
	if ( $token->{time_modulo} ) {
		$initialseq = time() % $token->{time_modulo} -
		  $__HOTPANTS_CONFIG_PARAMS{TimeSequenceSkew};
		#
		# If we already have an auth from this sequence, don't
		# allow replays
		#
		if ( $token->{token_sequence} >= $initialseq ) {
			$initialseq = $token->{token_sequence} + 1;
		}
		$maxskew = $__HOTPANTS_CONFIG_PARAMS{TimeSequenceSkew};
	} else {
		$initialseq = $token->{token_sequence} + 1;
		$maxskew    = $__HOTPANTS_CONFIG_PARAMS{SequenceSkew};
	}

	#
	# Either the token is not skewed, or the skew reset failed.  Perform
	# normal authentication
	#
	for (
		$sequence = $initialseq ;
		$sequence <= $token->{token_sequence} +
		$__HOTPANTS_CONFIG_PARAMS{ResyncSequenceSkew} ;
		$sequence++
	  )
	{

		my $checkprn = GenerateHOTP(
			key      => $token->{token_key},
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
	if ( $sequence > $token->{token_sequence} +
		$__HOTPANTS_CONFIG_PARAMS{ResyncSequenceSkew} )
	{
		$errstr = sprintf(
			"OTP given does not match a valid sequence for token %d",
			$token->{token_id} );
		goto HOTPAuthDone;
	}

	#
	# If we find the sequence, but it's between SequenceSkew and
	# ResyncSequenceSkew, put the token into next OTP mode
	#
	# XXX - need to reinvestigate how all this works
	#
	if ( $sequence > ($initialseq + $maxskew) ) {
		$errstr = sprintf(
			"OTP sequence %d for token %d (%s) outside of normal skew (expected less than %d).  Setting NEXT_OTP mode.",
			$sequence, $token->{token_id}, $login, $maxskew );
		warn $errstr;
		$self->UserError(
			"One-time password out of range.  Log in again with the next numbers displayed to resynchronize your token"
		);
		$token->{time_skew} = $sequence;
		goto HOTPAuthDone;
	}

	#
	# If we got here, it worked
	#
	$authok = 1;

      HOTPAuthDone:
	if ($authok) {
		$token->{time_skew}       = 0;
		$token->{bad_logins}          = 0;
		$token->{token_sequence}            = $sequence;
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
			$token->{last_updated} = time;
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
					  $__HOTPANTS_CONFIG_PARAMS{BadAuthLockoutTime}
					  ;
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
	# bail if there is no db connection
	#
	if ( !$self->{dbh} ) {
		$self->Error("fetch_user: no connection to database");
		return undef;
	}

	# clear errors
	$self->Error(undef);

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

	if ( defined( $attrs->{RADIUS}->{PWType} ) ) {
		$authmech = $attrs->{RADIUS}->{PWType}->{value};
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
	if ( !( $attrs->{RADIUS}->{GrantAccess} ) ) {
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
	} elsif ( $authmech eq 'sha1_nosalt' ) {
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
	if (       $p->{passwd} eq $checkpass
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
					$login, $authmech, $client->{name}
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
					$login, $authmech, $client->{name}
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
	# bail if there is no db connection
	#
	if ( !$self->{dbh} ) {
		$self->Error("fetch_user: no connection to database");
		return undef;
	}

	# clear errors
	$self->Error(undef);

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
				return undef;
			}
		}
	}
	$login = $user->{login};

	return 1;

	# XXX

	#
	# Check if the user is locked
	#
	if ( $user->{user_locked} ) {
		if ( $user->{unlock_time} && $user->{unlock_time} <= time() ) {
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
	# bail if there is no db connection
	#
	if ( !$self->{dbh} ) {
		$self->Error("fetch_user: no connection to database");
		return undef;
	}

	# clear errors
	$self->Error(undef);

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

	if ( defined( $attrs->{RADIUS}->{PWType} ) ) {
		$authmech = $attrs->{RADIUS}->{PWType}->{value};
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
	if ( !( $attrs->{RADIUS}->{GrantAccess} ) ) {
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
