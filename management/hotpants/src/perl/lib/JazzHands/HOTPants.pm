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
# Copyright (c) 2015-2016, Todd M. Kover
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
package JazzHands::HOTPants;

use 5.010;
use strict;
use warnings;
use Crypt::Eksblowfish::Bcrypt qw(bcrypt en_base64);
use Math::BigInt;
use Digest::SHA qw(sha1 sha1_base64);
use Digest::HMAC qw(hmac);
use MIME::Base64;
use Data::Dumper;
use JazzHands::Common qw(:all);    # not clear that we want all
use JazzHands::DBI;
use Crypt::CBC;
use Digest::SHA qw(sha256);
use DateTime::Format::Strptime;    # could also put epochs in views
use POSIX;
use JSON::PP;
use FileHandle;

use parent 'JazzHands::Common';

our $errstr;

#
# These need to be configurable as properties for overrrides.
#
my %__HOTPANTS_CONFIG_PARAMS = (
	TimeSequenceSkew      => 2,      # sequence skew allowed for time-based
	                                 # tokens
	SequenceSkew          => 7,      # Normal amount of sequence skew allowed
	ResyncSequenceSkew    => 100,    # Amount of sequence skew allowed for
	                                 # unassisted resync (i.e. two successive
	                                 # auths)
	BadAuthsBeforeLockout => 6,      # Lock out user/token after attempts
	BadAuthLockoutTime    => 1800,   # Lock out time after bad attempts, in
	                                 # seconds (0 means must be administratively
	                                 # unlocked)
	DefaultAuthMech       => undef,  # Default to denying authentication if an
	                                 # authentication mechanism is not defined
	PasswordExpiration    => 365     # Number of days for password expiration
);

our ( $VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS );
our ( %TokenType, %TokenStatus, %UserStatus );

BEGIN {
	use Exporter ();
	our ( $VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS );

	$VERSION = '1.0';

	# redundant with use parent, and all this can likely go away.  maybe.
	@ISA = qw(JazzHands::Common Exporter);

	# TT,TS,US_ can all go away; no longer used.  There's other bdb droppings
	# around that need to be purged.
	@EXPORT = qw(
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
		digits      => 6
	};

	eval 'sub TT_SOFT_TIME () {0x2;}' unless defined(&TT_SOFT_TIME);
	$TokenType{&TT_SOFT_TIME} = {
		displayname => "Time-based soft token",
		digits      => 6
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

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $opt   = &_options;

	my $self = $class->SUPER::new(@_);

	$self->{_dbuser} = $opt->{dbuser} || 'hotpants';

	$self->{_debug} = defined( $opt->{debug} ) ? $opt->{debug} : 0;
	$self->opendb();

	if ( $opt->{encryptionmap} ) {
		if ( ref $opt->{encryptionmap} eq 'HASH' ) {
			$self->{_encryptionmap} = $opt->{encryptionmap};
		} elsif ( ref $opt->{encryptionmap} eq '' ) {
			my $fh = new FileHandle( $opt->{encryptionmap} );
			if ( !$fh ) {
				$errstr = "encryptionmap(" . $opt->{encryptionmap} . "): $!";
				return undef;
			}
			my $x = join( "\n", $fh->getlines() );
			$fh->close;
			my $km = decode_json($x);
			if ( !$km || !exists( $km->{keymap} ) ) {
				$errstr =
				    "encryptionmap("
				  . $opt->{encryptionmap}
				  . "): No encryptionmap in file";
				return undef;
			}
			$self->{_encryptionmap} = $km->{keymap};
		}
	}

	$self;
}

#
# return the acccounts's mechanism and next one if that should they be tiered.
#
sub get_authmechs($$$$$$) {
	my $self = shift @_;
	my ( $attrs, $login, $client, $devcollprop, $rank ) = @_;

	my ( $authmech, $nexttype );
	if ( defined( $attrs->{HOTPants}->{PWType} ) ) {
		if ($rank) {
			if ( ref( $attrs->{HOTPants}->{PWType}->{value} ) ne 'ARRAY' ) {
				$self->ErrorF(
					"Challenge sent (%s) for an unchallenging account", $rank );
				return undef;
			}
			my @a = @{ $attrs->{HOTPants}->{PWType}->{value} };
			if ( $rank > $#a ) {
				$self->ErrorF( "Challenge sent (%s) is to high for account",
					$rank );
				return undef;
			} elsif ( $rank < $#a ) {
				$nexttype =
				  $attrs->{HOTPants}->{PWType}->{value}->[ $rank + 1 ];
			}
			$authmech = $attrs->{HOTPants}->{PWType}->{value}->[$rank];
		} else {
			if ( ref( $attrs->{HOTPants}->{PWType}->{value} ) eq 'ARRAY' ) {
				warn "+++ setting up next";
				$nexttype =
				  $attrs->{HOTPants}->{PWType}->{value}->[1];
				$authmech =
				  $attrs->{HOTPants}->{PWType}->{value}->[0];
			} else {
				$authmech = $attrs->{HOTPants}->{PWType}->{value};
			}
		}
		$self->_Debug(
			2, "Setting password type for user %s on client %s to (%s)",
			$login,
			$client->{devcoll_name},
			$authmech || "undefined"
		);
	} else {
		#
		# If there is no default password method for the account, figure out
		# the default for the collection.
		# This is a similar dance to the previous case, where there can be
		# tiers and the array needs to be plucked out.
		#
		if ($rank) {
			if ( ref( $devcollprop->{pwtype} ) ne 'ARRAY' ) {
				$self->ErrorF(
					"Challenge sent (%s) for an unchallenging account", $rank );
				return undef;
			}
			my @a = @{ $devcollprop->{pwtype} };
			if ( $rank > $#a ) {
				$self->ErrorF( "Challenge sent (%s) is to high for account",
					$rank );
				return undef;
			} elsif ( $rank < $#a ) {
				$nexttype = $devcollprop->{pwtype}->[ $rank + 1 ];
			}
			$authmech = $devcollprop->{pwtype}->[$rank];
		} else {
			if ( ref( $devcollprop->{pwtype} ) eq 'ARRAY' ) {
				$authmech = $devcollprop->{pwtype}->[0];
				$nexttype = $devcollprop->{pwtype}->[1];
			} else {
				$authmech = $devcollprop->{pwtype};
			}
		}

		if ( defined($authmech) ) {
			$self->_Debug(
				2,
				"Setting password type for client %s to %s%s",
				$client->{devcoll_name},
				$authmech, ($nexttype) ? " [$nexttype]" : ""
			);
		} else {
			$authmech = $__HOTPANTS_CONFIG_PARAMS{DefaultAuthMech};
			$self->_Debug(
				2,
				"Setting password type for client %s to default (%s)",
				$client->{devcoll_name},
				$authmech || "undefined"
			);
		}
	}

	return {
		authmech => $authmech,
		nexttype => $nexttype
	};
}

sub Status {
	my $self = shift;

	if (@_) { $self->{_status} = shift; }
	return $self->{_status};
}

#
# gets the shared secret for a device with a given IP
#
sub GetSharedSecret {
	my $self = shift;
	my $ip   = shift;

	#
	# bail if there is no db connection
	#
	if ( !$self->{dbh} ) {
		$self->Error("fetch_token: no connection to database");
		return undef;
	}

	my $dbh = $self->{dbh};

	# clear errors
	$self->Error(undef);

	my $sth = $dbh->prepare_cached(
		qq{
			SELECT	*
			FROM	v_hotpants_client
			WHERE	host(ip_address) = ?
	}
	);

	if ( !$sth ) {
		$self->Error(
			"GetSharedSecret: unable to prepare sth: " . $dbh->errstr );
		return undef;
	}

	if ( !( $sth->execute($ip) ) ) {
		$self->Error( "fetch_token: execute failed: " . $dbh->errstr );
		return undef;
	}

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	if ($hr) {
		return {
			secret   => $hr->{radius_secret},
			hostname => $hr->{device_name},
		};
	}
	$dbh->rollback;
	return undef;
}

#
# Sets the error to display to a remote user
#
sub UserError {
	my $self = shift;

	if (@_) { $self->{_usererror} = shift; }
	return $self->{_usererror};
}

#
# takes a key encrypted from the db and a base64 encrypted key, and returns a
# base64 encrypted version of the unencrypted string.
#
# This probably wants to be in a common library
#
sub _decryptkey {
	my ( $self, $text, $pw ) = @_;
	my $key = sha256($pw);

	my $ciphertext = decode_base64($text);
	my $iv         = substr( $ciphertext, 0, 16 );
	my $c_text     = substr( $ciphertext, 16 );

	my $cipher = Crypt::CBC->new(
		-key         => $key,
		-cipher      => 'Rijndael',
		-iv          => $iv,
		-header      => 'none',
		-literal_key => 1,
	);
	my $unenc = $cipher->decrypt($c_text) || die $_;
	if ($unenc) {
		return encode_base64($unenc);
	} else {
		$self->_Debug( 1, "Unable to decrypt" );
	}
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
			$dbh =
			JazzHands::DBI->connect( $self->{_dbuser}, { AutoCommit => 0 } )
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

	$self->{dbh}->commit();
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
			SELECT	*
			FROM	v_hotpants_token
			WHERE	token_id = ?
	}
	);

	# XXX - syncradius.pl also does stuff with radius_app.

	if ( !$sth ) {
		$self->Error( "fetch_token: unable to prepare sth: " . $dbh->errstr );
		return undef;
	}

	if ( !( $sth->execute($tokenid) ) ) {
		$self->Error( "fetch_token: execute failed: " . $dbh->errstr );
		return undef;
	}

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;

	if ( !$hr ) {
		$self->_Debug( 1,
			"fetch_token: No token in database: " . $dbh->errstr );
		return undef;
	}

	# XXX - other attributes listed above are not included.  some grew
	# token_ prefixes.

	if ( !exists( $self->{_encryptionmap} ) && $hr->{encryption_key_db_value} )
	{
		$self->_Debug( 1, "fetch_token: Token can not be decrypted" );
		return undef;
	} elsif ( $hr->{encryption_key_purpose} ) {
		$self->_Debug( 10, "fetch_token: decrypting token" );
		#
		# XXX should probably make sure about encryption purpose and method
		#
		my $emap = $self->{_encryptionmap};

		if ( !exists( $emap->{ $hr->{encryption_key_purpose_version} } ) ) {
			$self->_Debug( 1,
				"fetch_token: Token not be decrypted due to encryption version"
			);
			return undef;
		}

		my $fullkey =
		    $emap->{ $hr->{encryption_key_purpose_version} }
		  . $hr->{encryption_key_db_value};

		$hr->{token_key} = $self->_decryptkey( $hr->{token_key}, $fullkey );
	}

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
		SELECT	LOGIN, account_status,  token_id
		FROM	v_corp_family_account
				LEFT JOIN account_token USING (account_id)
		WHERE	is_enabled = 'Y'
		AND		login = ?
		ORDER BY LOGIN, account_status, token_id

	}
	);

	# XXX - syncradius.pl also does stuff with radius_app.

	if ( !$sth ) {
		$self->Error( "fetch_user: unable to prepare sth: " . $dbh->errstr );
		return undef;
	}

	if ( !( $sth->execute($login) ) ) {
		$self->Error( "fetch_user: execute failed: " . $dbh->errstr );
		return undef;
	}

	my $rv;
	while ( my $hr = $sth->fetchrow_hashref ) {
		if ( !$rv ) {
			$rv = {
				login  => $hr->{login},
				status => $hr->{account_status},
				tokens => [ $hr->{token_id} ],
			};
		} else {
			push( @{ $rv->{tokens} }, $hr->{token_id} );
		}
	}
	return $rv;
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
	my $sth;
	if ( $clientid =~ /^[\.:0-9a-f]+$/ ) {
		$sth = $dbh->prepare_cached(
			qq{
				SELECT *
	        	FROM	v_hotpants_device_collection
	        	WHERE	ip_address = ?
				AND		device_collection_type IN ('HOTPants')
		}
		);
	} else {
		$sth = $dbh->prepare_cached(
			qq{
				SELECT *
	        	FROM	v_hotpants_device_collection
	        	WHERE	device_collection_name = ?
				AND		device_collection_type = 'HOTPants-app'
		}
		);
	}

	if ( !$sth ) {
		$self->Error( "fetch_client: unable to prepare sth: " . $dbh->errstr );
		return undef;
	}

	if ( !( $sth->execute($clientid) ) ) {
		$self->Error( "fetch_client: execute failed: " . $dbh->errstr );
		return undef;
	}

	my $hr = $sth->fetchrow_hashref;
	$hr->{name} = $hr->{device_collection_name};    # XXX
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
		SELECT	device_collection_id, property_value
		FROM	v_hotpants_dc_attribute
		WHERE	Property_Name = 'PWType'
		AND		Property_Type = 'HOTPants'
		AND		device_collection_id = ?
		ORDER BY property_type, property_name, property_rank
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

	my $r;
	while ( my $hr = $sth->fetchrow_hashref ) {
		if ( !$r ) {
			$r = {
				devcoll_id => $hr->{device_collection_id},
				pwtype     => $hr->{property_value}
			};
		} else {
			if ( ref( $r->{pwtype} ) eq 'ARRAY' ) {
				push( @{ $r->{pwtype} }, $hr->{property_value} );
			} else {
				my @a;
				push( @a, $r->{pwtype} );
				push( @a, $hr->{property_value} );
				$r->{pwtype} = \@a;
			}
		}
	}

	$sth->finish;

	if ( !$r ) {
		return undef;
	}

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
		$self->Error( "fetch_passwd: unable to prepare sth: " . $dbh->errstr );
		return undef;
	}

	if ( !( $sth->execute($login) ) ) {
		$self->Error( "fetch_passwd: execute failed: " . $dbh->errstr );
		return undef;
	}

	my $rv = {};
	while ( my $hr = $sth->fetchrow_hashref() ) {
		$rv->{ $hr->{password_type} } = {
			passwd      => $hr->{password},
			change_time => $hr->{change_time},
			expire_time => $hr->{expire_time},
		};
	}

	if ( !keys %{$rv} ) {
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
	my $dcid  = $opt->{devcoll_id};

	if ( !$login || !$dcid ) {
		$self->Error(
			"fetch_attributes: must specify both a account and device collection"
		);
		return undef;
	}

	# XXX - V_Dev_Col_User_Prop_Expanded needs to have mutlivalue fixed and
	#	have the multivalue logic pulled from the syncer
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
	        FROM	v_hotpants_account_attribute
	        WHERE	login = ?
			AND		device_collection_id = ?
			ORDER BY property_type, property_name, property_rank
	}
	);

	if ( !$sth ) {
		$self->Error(
			"fetch_attributes: unable to prepare sth: " . $dbh->errstr );
		return undef;
	}

	if ( !( $sth->execute( $login, $dcid ) ) ) {
		$self->Error( "fetch_attributes: execute failed: " . $dbh->errstr );
		return undef;
	}
	my $count = 0;
	my $attr  = {};

	# XXX need to properly support multivalue
	while ( my $hr = $sth->fetchrow_hashref ) {
		if (
			exists( $attr->{ $hr->{property_type} }->{ $hr->{property_name} } )
		  )
		{
			my $x = $attr->{ $hr->{property_type} }->{ $hr->{property_name} };
			if ( ref( $x->{value} ) eq 'ARRAY' ) {
				push( @{ $x->{value} }, $hr->{property_value} );
			} else {
				my @arr;
				push( @arr, $x->{value} );
				push( @arr, $hr->{property_value} );
				$x->{value}      = \@arr;
				$x->{multivalue} = 'Y';
			}
		} else {
			$attr->{ $hr->{property_type} }->{ $hr->{property_name} } = {
				name       => $hr->{property_name},
				value      => $hr->{property_value},
				multivalue => 'N',
			};
		}
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

	#
	# bail if there is no db connection
	#
	if ( !$self->{dbh} ) {
		$self->Error("put_token: no connection to database");
		return undef;
	}
	my $dbh = $self->{dbh};

	if ( !$token || !$token->{token_id} ) {
		$self->Error("put_token: token invalid or not passed");
		return undef;
	}

	# clear errors
	$self->Error(undef);

	my $now = strftime( "%F %T", gmtime() );

	if ( $token->{time_skew} ) {
		my $sth = $dbh->prepare - cached(
			qq{
			UPDATE token set	time_skew = :skew
			WHERE	token_id = :tokenid
			AND		time_skew != :skew
		}
		);

		if ( !$sth ) {
			$self->Error( "put_token: unable to prepare sth: " . $dbh->errstr );
			return undef;
		}

		if ( !$sth->bind_param( ':tokenid', $token->{token_id} ) ) {
			$self->Error( "put_token: unable to bind tokenid" . $sth->errstr );
			return undef;
		}

		if ( !$sth->bind_param( ':skew', $token->{time_skew} ) ) {
			$self->Error(
				"put_token: unable to bind time_skew" . $sth->errstr );
			return undef;
		}

		if ( !$sth->execute ) {
			$self->Error(
				"put_token: unable to execute token update" . $sth->errstr );
			return undef;
		}
	}

	if ( $token->{token_sequence} ) {
		my $sth = $dbh->prepare_cached(
			qq{
			UPDATE v_hotpants_token 
					set token_sequence = :seq, last_updated = :now
			WHERE	token_id = :tokenid
			AND		token_sequence < :seq
		}
		);

		if ( !$sth ) {
			$self->Error( "put_token: unable to prepare sth: " . $dbh->errstr );
			return undef;
		}

		if ( !$sth->bind_param( ':tokenid', $token->{token_id} ) ) {
			$self->Error( "put_token: unable to bind tokenid" . $sth->errstr );
			return undef;
		}

		if ( !$sth->bind_param( ':seq', $token->{token_sequence} ) ) {
			$self->Error(
				"put_token: unable to bind time_skew" . $sth->errstr );
			return undef;
		}

		if ( !$sth->bind_param( ':now', $now ) ) {
			$self->Error( "put_user: unable to bind now" . $sth->errstr );
			return undef;
		}

		if ( !( $sth->execute() ) ) {
			if ( !$sth->execute ) {
				$self->Error(
					"put_token: unable to execute token_seq update"
					  . $sth->errstr );
				return undef;
			}
		}
	}

	# XXX - need to deal with token disable locally
	# XXX deal with me locking the token more recently than the db says it was
	# locked..
	if ( $token->{is_token_locked} ) {
		my $dbtok = $self->fetch_token( token_id => $token->{token_id} );
		if ( !$dbtok ) {
			$self->Error(
				"put_token: token can not be fetched from db " . $dbh->errstr );
			return undef;
		}

		my $islocked =
		  $token->{is_token_locked} && $token->{is_token_locked} ne 'N';
		my $unlocktime;
		if ($islocked) {
			$islocked = 'Y';
			$unlocktime =
			  strftime( "%F %T", gmtime( $token->{token_unlock_time} ) );
		} else {
			$islocked = 'N';
		}
		my $lastupdate = strftime( "%F %T", gmtime() );

		my $new = {
			token_id          => $token->{token_id},
			token_unlock_time => $unlocktime,
			bad_logins        => $token->{bad_logins},
			last_updated      => $lastupdate,
			is_token_locked   => $islocked
		};
		my $diff = $self->hash_table_diff( $dbtok, $new );

		if ( scalar $diff ) {
			my $set = join( ", ", map { "$_ = :$_" } keys %{$diff} );
			my $sth = $dbh->prepare_cached(
				qq{
				UPDATE	v_hotpants_token SET $set
				WHERE	token_id = :token_id
				AND		last_updated <= :last_updated
			}
			);

			if ( !$sth ) {
				$self->Error(
					"put_token: unable to prepare sth: " . $dbh->errstr );
				return undef;
			}

			$diff->{token_id} = $new->{token_id};
			foreach my $key ( keys %{$diff} ) {
				if ( !$sth->bind_param( ":$key", $diff->{$key} ) ) {
					$self->Error(
						"put_token: unable to bind $key" . $sth->errstr );
					return undef;
				}
			}

			if ( !( $sth->execute() ) ) {
				$self->Error(
					"put_token: unable to execute token_seq update"
					  . $sth->errstr );
				return undef;
			}
		}
	}

	return 1;
}

sub put_user {
	my $self = shift;
	my $acct = shift;
	my ($ret);

	#
	# bail if there is no db connection
	#
	if ( !$self->{dbh} ) {
		$self->Error("put_user: no connection to database");
		return undef;
	}
	my $dbh = $self->{dbh};

	if ( !$acct || !$acct->{login} ) {
		$self->Error("put_user: account invalid or not passed");
		return undef;
	}

	# clear errors
	$self->Error(undef);

	# XXX - need to deal with token disable locally
	# XXX deal with me locking the token more recently than the db says it was
	# locked..
	# XXX - need to deal with account realms!!
	if ( $acct->{user_locked} ) {
		#
		# likely want to only update badlogins if its < our badlogins
		#
		my $sth = $dbh->prepare_cached(
			qq{
			UPDATE	account_token
			SET		token_unlock_time = :unlock,
					bad_logins = :badlogins,
					last_updated = :now,
					is_token_locked = :islocked
			WHERE	is_token_locked != :islocked
			AND		last_updated <= :lastupdate
			AND		account_id IN (
						SELECT account_id from account where login = :login
					)
		}
		);

		my $islocked = $acct->{user_locked};
		my $unlocktime;
		if ( $islocked eq 'Y' ) {
			$unlocktime = strftime( "%F %T", gmtime( $acct->{unlock_time} ) );
		}
		my $lastupdate = strftime( "%F %T", gmtime() );
		my $now = $lastupdate;

		if ( !$sth ) {
			$self->Error(
				"fetch_user: unable to prepare sth: " . $dbh->errstr );
			return undef;
		}

		if ( !$sth->bind_param( ':now', $now ) ) {
			$self->Error( "put_user: unable to bind now" . $sth->errstr );
			return undef;
		}

		if ( !$sth->bind_param( ':unlock', $unlocktime ) ) {
			$self->Error(
				"put_user: unable to bind unlocktime" . $sth->errstr );
			return undef;
		}

		if ( !$sth->bind_param( ':badlogins', $acct->{bad_logins} ) ) {
			$self->Error(
				"put_user: unable to bind unlocktime" . $sth->errstr );
			return undef;
		}

		if ( !$sth->bind_param( ':islocked', $islocked ) ) {
			$self->Error( "put_user: unable to bind islocked" . $sth->errstr );
			return undef;
		}

		if ( !$sth->bind_param( ':lastupdate', $lastupdate ) ) {
			$self->Error(
				"put_user: unable to bind lastupdate" . $sth->errstr );
			return undef;
		}

		if ( !$sth->bind_param( ':login', $acct->{login} ) ) {
			$self->Error( "put_user: unable to bind login" . $sth->errstr );
			return undef;
		}

		if ( !( $sth->execute() ) ) {
			if ( !$sth->execute ) {
				$self->Error(
					"put_user: unable to execute put_user.account_token update"
					  . $sth->errstr );
				return undef;
			}
		}
	}

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
		$self->Error("delete_token: database environment is not defined");
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
	  $token->{time_modulo}       || 0,
	  $token->{skew_sequence}     || 0,
	  $token->{is_token_locked}   || 0,
	  $token->{token_unlock_time} || 0,
	  $token->{bad_logins}        || 0,
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
		$self->Error("HOTPAuthenticate: no connection to database");
		return undef;
	}

	# Generic user error
	$self->UserError("Login incorrect");

	# clear errors
	$self->Error(undef);

	my $login  = $opt->{login};
	my $user   = $opt->{user};
	my $method = $opt->{method};

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

	# keep track of any tokens that need to be marked as out of sync to
	# force a resync
	my (@badotp);

	my (@badtokens);

	my $sequence;
	foreach $tokenid ( @{ $user->{tokens} } ) {
		$self->_Debug( 1, "Trying token %d for user %s", $tokenid, $login );
		if ( !( $token = $self->fetch_token( token_id => $tokenid ) ) ) {
			$self->_Debug( 2, "Token %d assigned to %s not actually there",
				$tokenid, $login );
			next;
		}

		if ( !$method || $method ne 'oath-only' ) {
			if ( !$token->{token_password} ) {
				$self->_Debug( 2, "PIN not set for token %d.  Skipping.",
					$tokenid );
				next;
			}
		}

		#
		# Token is valid
		#
		$validtoken = 1;

		#
		# Figure out what is the PIN and what is the OTP
		#

		# XXX - need to check to see if its a valid/understood type
		if ( !$token->{token_type} ) {
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
			$self->_Debug( 1, "Invalid OTP digits defined for token %d",
				$tokenid );
			next;
		}

		if ( length($otp) < $otplen ) {
			$self->_Debug( 2,
				"OTP given less than minimal possible length for token %d",
				$tokenid );
			next;
		}

		$pin = substr( $otp, 0, length($otp) - $otplen );
		$prn = substr( $otp, length($otp) - $otplen );

		#
		# Check the PIN
		#
		if ( !$method || $method ne 'oath-only' ) {
			my $crypt = bcrypt( $pin, $token->{token_password} );
			if ( $token->{token_password} eq
				bcrypt( $pin, $token->{token_password} ) )
			{

				$pinfound = 1;
				$self->_Debug( 2, "PIN is correct for token %d", $tokenid );
			} else {
				$self->_Debug( 2,
					"PIN is incorrect for token %d, expected %s, got %s",
					$tokenid, $token->{token_password}, $crypt );
				next;
			}
		}

		# before having passwordless token, the for loop ended here and the
		# loop ended with $token pointing to a valdi toke

		if ( !$validtoken ) {
			next;
		}
		if ( !$method || $method ne 'oath-only' ) {
			if ( !$pinfound ) {
				next;
			}
		}

		#
		# Verify that the token is enabled - XXX
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
		if ( !$token->{is_token_locked} || $token->{is_token_locked} eq 'Y' ) {
			my $unlockwhence;
			eval {
				my $Strp = DateTime::Format::Strptime->new(
					pattern   => '%F %T',
					locale    => 'en_US.UTF8',
					time_zone => 'UTC',
				);
				my $dt = $Strp->parse_datetime( $token->{token_unlock_time} )
				  || die;
				$unlockwhence = $dt->epoch;
			};
			if ($@) {
				$self->ErrorF(
					"Unable to convert %s to epoch",
					$token->{token_unlock_time}
				);
				return undef;
			}

			if ( $unlockwhence && $unlockwhence <= time() ) {
				$token->{is_token_locked}   = 'N';
				$token->{token_unlock_time} = undef;
				$token->{bad_logins}        = 0;
				$token->{last_updated}      = time();
				$self->_Debug( 2, "Unlocking token %d", $token->{token_id} );
				if ( !( $self->put_token( token => $token ) ) ) {
					$self->ErrorF( "Error unlocking token %d: %s",
						$token->{token_id}, $self->Error );
					return undef;
				}
			} else {
				$errstr = sprintf( "token %d is locked.", $token->{token_id} );
				if ( $token->{token_unlock_time} ) {
					$errstr .= sprintf( "  Token will unlock at %s",
						$token->{token_unlock_time} );
				} else {
					$errstr .= "  Token must be administratively unlocked";
				}
				$self->Error($errstr);

				# not returning here in case another unlocked token is valid.
				next;
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
		$sequence = undef;
		if ( $token->{time_skew} ) {
			$sequence = $token->{time_skew} + 1;
			$self->_Debug( 2, "Expecting next token sequence %d for token %d",
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
						"Unknown error generating OTP for token %d (seq %d)",
						$token->{token_id}, $sequence
					)
				);
				return undef;
			}
			if ( $prn eq $checkprn ) {
				$authok = 1;
				last;
				$self->_Debug( 2, "Received token sequence %d for token %d",
					$sequence, $token->{token_id} );
				last;
			}
			$self->_Debug( 2, "Did not receive token sequence %d for token %d",
				$sequence, $token->{token_id} );
		}

		my $initialseq;
		my $maxskew;
		if ( $token->{time_modulo} ) {
			$initialseq =
			  int(
				time() / $token->{time_modulo} -
				  $__HOTPANTS_CONFIG_PARAMS{TimeSequenceSkew} );
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
			$sequence <=
			$initialseq + $__HOTPANTS_CONFIG_PARAMS{ResyncSequenceSkew} ;
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
						"Unknown error generating OTP for token %d - seq %d",
						$token->{token_id}, $sequence
					)
				);
				return undef;
			}
			$self->_Debug( 50, "Given PRN is %s.  PRN for sequence %d is %s",
				$prn, $sequence, $checkprn );
			if ( $prn eq $checkprn ) {
				$self->_Debug( 2, "Found a match, PRN: %s ", $checkprn );
				last;
			}
		}

		#
		# If we don't get to it in ResyncSequenceSkew sequences, bail
		#
		if ( $sequence >
			$initialseq + $__HOTPANTS_CONFIG_PARAMS{ResyncSequenceSkew} )
		{
			push( @badtokens, $token );
			next;
		}

		#
		# If we find the sequence, but it's between SequenceSkew and
		# ResyncSequenceSkew, put the token into next OTP mode
		#
		#
		if ( $sequence > ( $initialseq + $maxskew ) ) {
			push( @badotp, $token );
			$token->{maxskew}   = $maxskew;
			$token->{time_skew} = $sequence;
			next;
		}

		#
		# If we got here, it worked
		#
		$authok = 1;
	}

	if ( !$validtoken ) {
		$errstr = "no valid tokens found for user";
		goto HOTPAuthDone;
	}
	if ( !$method || $method ne 'oath-only' ) {
		if ( !$pinfound ) {
			$errstr = "PIN incorrect for all assigned tokens";
			goto HOTPAuthDone;
		}
	}

  HOTPAuthDone:
	if ($authok) {
		#
		# clear errors in case something was set above
		#
		$self->Error(undef);

		$token->{time_skew}           = 0;
		$token->{bad_logins}          = 0;
		$token->{token_sequence}      = $sequence;
		$token->{lock_status_changed} = time;
		$self->Status(
			sprintf(
				"user %s successfully authenticated with token %d",
				$login, $token->{token_id}
			)
		);
		$errstr = undef;
		$self->Error(undef);
		#
		# Write token back to database
		#
		if ( !( $self->put_token( token => $token ) ) ) {
			$self->ErrorF( "Error updating token %d: %s",
				$token->{token_id}, $self->Error );
			return undef;
		}
	} else {
		$errstr =
		  sprintf( "OTP given does not match a permitted sequence for token %s",
			join( ",", map { $_->{token_id} } @badtokens ) );
		if ( $#badotp >= 0 ) {
			foreach my $tok (@badotp) {
				#
				# for a user with multiple tokens, this may generate a false
				# negative, so likely need to flag this as a "come back to XXX
				#
				$errstr = sprintf(
					"OTP sequence %d for token %d (%s) outside of normal skew (expected less than %d).  Setting NEXT_OTP mode.",
					$sequence, $tok->{token_id}, $login, $tok->{maxskew} );
				$self->UserError(
					"One-time password out of range.  Log in again with the next numbers displayed to resynchronize your token"
				);
			}
		}
		#
		# go through all the tokens marked as bad and update their bad logins
		# and possibly lock them.
		#
		foreach my $tok (@badtokens) {
			$tok->{bad_logins} += 1;
			$self->_Debug( 2, "Bad logins for token %d now %d",
				$tok->{token_id}, $tok->{bad_logins} );
			$tok->{last_updated} = time;
			if ( $tok->{bad_logins} >=
				$__HOTPANTS_CONFIG_PARAMS{BadAuthsBeforeLockout} )
			{
				$self->_Debug( 2, "Locking token %d", $tok->{token_id} );
				$tok->{is_token_locked} = 1;
				if ( $__HOTPANTS_CONFIG_PARAMS{BadAuthLockoutTime} ) {
					$tok->{token_unlock_time} =
					  time + $__HOTPANTS_CONFIG_PARAMS{BadAuthLockoutTime};
				} else {
					$tok->{token_unlock_time} = undef;
				}
			}
			#
			# these only happen if the user failed to login, so if it fails
			# this does not prevent a user from logging in.
			#
			if ( !( $self->put_token( token => $tok ) ) ) {
				$self->ErrorF( "Error updating token %d: %s",
					$tok->{token_id}, $self->Error );
				return undef;
			}
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
	if (   !defined( $opt->{key} )
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

	return undef if length $opt->{key} < 16;                   # 128-bit minimum
	return undef if ref $opt->{sequence} ne "Math::BigInt";
	return undef if $opt->{digits} < 6 and $opt->{digits} > 10;

	# zero pad, remove the 0x.
	( my $hex = $opt->{sequence}->as_hex ) =~
	  s/^0x(.*)/"0"x(16 - length $1).$1/e;
	my $bin = join '', map chr hex, $hex =~ /(..)/g;    # pack 64-bit big endian
	my $hash = hmac $bin, $opt->{key}, \&sha1;
	my $offset = hex substr unpack( "H*" => $hash ), -1;
	my $dt = unpack "N" => substr $hash, $offset, 4;
	$dt &= 0x7fffffff;                                  # 31-bit
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
	my $authsucceeded = undef;

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
	my $rank  = $opt->{rank};

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
			$self->Error( sprintf( "unknown client: %s", $source ) );
		}
		return undef;
	}

	if ( !$client->{devcoll_id} ) {
		$self->ErrorF( "Authenticate: No collection for %s", $source );
		return undef;
	}

	#
	# Fetch client parameters for the device class.
	#
	my $devcollprop;

	if (
		!(
			$devcollprop =
			$self->fetch_devcollprop( devcoll_id => $client->{devcoll_id} )
		)
	  )
	{
		if ( $self->Error ) {
			return undef;
		}
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

	my ( $authmech, $nexttype );
	if ( my $am =
		$self->get_authmechs( $attrs, $login, $client, $devcollprop, $rank ) )
	{
		$authmech = $am->{authmech};
		$nexttype = $am->{nexttype};
	} else {
		return undef;
	}

	#
	# See if the user has access to log in here
	#
	if ( !( $attrs->{HOTPants}->{GrantAccess} ) ) {
		$self->Error(
			sprintf(
				"user %s does not have permission to log in to %s (%s)",
				$login, $source, $client->{devcoll_name}
			)
		);
		return undef;
	}

	if ( !defined($authmech) || $authmech eq 'star' ) {
		$self->Error(
			sprintf(
				"no password mechanisms defined to auth user %s on client '%s' (%s)",
				$login                  || '',
				$client->{devcoll_name} || '',
				$source                 || ''
			)
		);
		return undef;
	}

	if (   $authmech eq 'oath-only'
		|| $authmech eq 'oath+passwd'
		|| $authmech eq 'token'
		|| $authmech eq 'oath' )
	{
		$self->_Debug( 2, "Authenticating user %s on client %s with HOTP",
			$login, $client->{devcoll_name} );

		if (
			$self->HOTPAuthenticate(
				user   => $user,
				otp    => $password,
				method => $authmech,
			)
		  )
		{
			$authsucceeded = { result => 'accept' };
		}
		$err = $self->Error;
		return undef if ( $err && $err =~ /^No tokens assigned/ );
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
				$authmech, $login, scalar( $p->{expire_time} )
			)
		);
		$self->UserError("Your password is expired");
		return undef;
	} elsif ( $p->{change_time}
		&& $p->{change_time} +
		( 86400 * $__HOTPANTS_CONFIG_PARAMS{PasswordExpiration} ) < time )
	{
		$self->Error(
			sprintf(
				"%s password for %s expired %s",
				$authmech,
				$login,
				scalar(
					$p->{change_time} +
					  86400 * $__HOTPANTS_CONFIG_PARAMS{PasswordExpiration}
				)
			)
		);
		$self->UserError("Your password is expired");
		return undef;
	}

	my $checkpass = undef;
	if ( $authmech eq 'blowfish' ) {
		$checkpass = bcrypt( $password, $p->{passwd} );
	} elsif ( ( $authmech eq 'des' )
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
				$authmech, $login, $client->{devcoll_name}
			)
		);
		return undef;
	}

	$self->_Debug( 2, "Authenticating user %s on client %s with %s",
		$login, $client->{devcoll_name}, $authmech );
	if (   $p->{passwd} eq $checkpass
		|| $p->{passwd} eq ( $checkpass . "=" ) )
	{
		$authsucceeded = { result => 'accept' };
	} else {
		$self->_Debug(
			2,
			"User %s failed authentication on client %s with %s: expected %s, got %s",
			$login,
			$client->{devcoll_name},
			$authmech,
			$p->{passwd},
			$checkpass,
		);
	}

  UserAuthDone:
	if ($authsucceeded) {
		my $extralogmsg = "";
		if ($nexttype) {
			my $challengeresponse = $rank + 1;
			$extralogmsg = sprintf( "[challenging to %d]", $challengeresponse );
			my $msg = "Please enter the code for the next stage";
			if ($nexttype) {
				if ( $nexttype eq 'oath-only' ) {
					$msg = "Please enter your OATH Token sequence";
				} elsif ( $nexttype eq 'oath+passwd'
					|| $nexttype eq 'token'
					|| $nexttype eq 'oath' )
				{
					$msg = "Please enter your PIC and OATH Token sequence";
				} elsif ( $nexttype eq 'blowfish' ) {
					$msg = "Please enter your password";
				}
			}
			$authsucceeded = {
				result  => 'challenge',
				next    => $challengeresponse,
				message => $msg
			};

		}
		if ( !$self->Status ) {
			$self->Status(
				sprintf(
					"user %s successfully authenticated using %s for client %s (%s)",
					$login,                  $authmech,
					$client->{devcoll_name}, $extralogmsg
				)
			);
		}

		if ( !$self->Status ) {
			$self->Status(
				sprintf(
					"user %s successfully authenticated using %s for client %s",
					$login, $authmech, $client->{devcoll_name}
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
					$login, $authmech, $client->{devcoll_name}
				)
			);
			$self->_Debug( 2, $self->Error );
		}

		# XXX likely need to make this go away because its token only.
		$user->{bad_logins} += 1;
		$user->{lock_status_changed} = time;
		if ( $user->{bad_logins} >=
			$__HOTPANTS_CONFIG_PARAMS{BadAuthsBeforeLockout} )
		{
			$self->_Debug( 2, "Locking user %s", $login );
			$self->Error( $self->Error . " - locking user" );
			$user->{user_locked} = 1;
			if ( $__HOTPANTS_CONFIG_PARAMS{BadAuthLockoutTime} ) {
				$user->{token_unlock_time} =
				  time + $__HOTPANTS_CONFIG_PARAMS{BadAuthLockoutTime};
			} else {
				$user->{token_unlock_time} = undef;
			}
		}
	}

	$err = $self->Error;
	if ( !( $self->put_user($user) ) ) {
		$self->ErrorF( "Error updating user %s: %s", $login, $self->Error );
		$self->Status(undef);
		return undef;
	}
	if ($err) {
		$self->Error($err);
	}
	return $authsucceeded;
}

#
# This is currently a noop, but could be used for checking to see if a user is
# globally locked or some such .   There are no provisions in all this for
# globally locking someone
#
sub VerifyUser {
	my $self = shift;
	my $opt  = &_options;

	$self->Error(undef);
	return 1;

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

	# Additional checks on a user, such as if the user has been locked or
	# disabled could be done here, otherwise, this is largely a noop.
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
	my $rank  = $opt->{rank};

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
			$self->ErrorF( sprintf( "Client %s not found", $source ) );
		}
		return undef;
	}

	#
	# Fetch client parameters for the device class.
	#
	my $devcollprop;

	if ( !$client->{devcoll_id} ) {
		$self->ErrorF( "Authorize: No collection for %s", $source );
		return undef;
	}

	if (
		!(
			$devcollprop =
			$self->fetch_devcollprop( devcoll_id => $client->{devcoll_id} )
		)
	  )
	{
		if ( $self->Error ) {
			return undef;
		}
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

	my ( $authmech, $nexttype );
	if ( my $am =
		$self->get_authmechs( $attrs, $login, $client, $devcollprop, $rank ) )
	{
		$authmech = $am->{authmech};
		$nexttype = $am->{nexttype};
	} else {
		return undef;
	}

	#
	# See if the user has access to log in here
	#
	if ( !( $attrs->{HOTPants}->{GrantAccess} ) ) {
		$self->Error(
			sprintf(
				"User %s does not have access to log in to %s (%s)",
				$login, $source, $client->{devcoll_name}
			)
		);
		return undef;
	}

	if ( !defined($authmech) || $authmech eq 'star' ) {
		$self->Error(
			sprintf(
				"No password mechanisms defined to auth user %s on client %s (%s)",
				$login, $client->{devcoll_name}, $source
			)
		);
		return undef;
	}

	if (   $authmech eq 'oath+passwd'
		|| $authmech eq 'oath-only'
		|| $authmech eq 'token'
		|| $authmech eq 'oath' )
	{
		$self->_Debug( 2, "Authenticating user %s on client %s with HOTP",
			$login, $client->{devcoll_name} );

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

sub DESTROY {
	my $self = shift @_;

	$self->closedb();
}

1;
