#!/usr/bin/env perl
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

#
# XXX - this probably belongs somewhere else.
#

package JazzHands::TokenDB;

use strict;
use warnings;

BEGIN {
	eval {
		# use MIME::Base32 qw(RFC);
		use MIME::Base32;
		local $SIG{__WARN__} = sub { };
		MIME::Base32->import(qw(RFC));
	};
	if ($@) {

		# >= 1.3
		use MIME::Base32;
	}

}
use MIME::Base64;
use Digest::SHA qw(sha256);
use Crypt::CBC qw(random_bytes);
use Crypt::Eksblowfish::Bcrypt qw(bcrypt en_base64);
use JazzHands::Common qw(:all);
use Data::Dumper;
use JSON::PP;
use URI::Escape qw(uri_escape);

use parent 'JazzHands::Common';

our $errstr;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $opt   = &_options;

	my $self = $class->SUPER::new(@_);

	my $svc = $opt->{service};

	$self->Connect( service => $opt->{'service'} ) || return undef;

	if ( $opt->{keymap} ) {
		if ( ref $opt->{keymap} eq 'HASH' ) {
			$self->{_keymap} = $opt->{keymap};
		} elsif ( ref $opt->{keymap} eq '' ) {
			my $fh = new FileHandle( $opt->{keymap} );
			if ( !$fh ) {
				$errstr = "keymap(" . $opt->{keymap} . "): $!";
				return undef;
			}
			my $x = join( "\n", $fh->getlines() );
			$fh->close;
			my $km = decode_json($x);
			if ( !$km || !exists( $km->{keymap} ) ) {
				$errstr = "keymap(" . $opt->{keymap} . "): No keymap";
				return undef;
			}
			$self->{_keymap} = $km->{keymap};
		}
	}

	$self->{_ekpurpose} = $opt->{encryption_key_purpose} || 'tokenkey';
	$self->{_ekversion} = $opt->{encryption_key_purpose};
	if ( ( !$self->{_ekversion} ) && $self->{_ekpurpose} && $self->{_keymap} ) {
		#
		# go through the list, find the highest number we have and pick that
		# as a default, if one is not set.
		#
		if ( my $dbh = $self->DBHandle() ) {
			if (
				my $sth = $dbh->prepare_cached(
					qq{
						SELECT	encryption_key_purpose_version
						FROM	val_encryption_key_purpose
						WHERE	encryption_key_purpose = ?
						ORDER BY encryption_key_purpose_version DESC;
					}
				)
			  )
			{
				if ( $sth->execute( $self->{_ekpurpose} ) ) {
					my $km = $self->{_keymap};
					while ( my ($v) = $sth->fetchrow_array ) {
						if ( defined( $km->{$v} ) ) {
							$self->{_ekversion} = $v;
							last;
						}
					}
					$sth->finish;
				}
			}
		}
	}

	$self;
}

sub ekpurpose($;$) {
	my $self = shift @_;
	if (@_) { $self->{_ekpurpose} = shift; }
	return $self->{_ekpurpose};
}

sub ekversion($;$) {
	my $self = shift @_;
	if (@_) { $self->{_ekversion} = shift; }
	return $self->{_ekversion};
}

sub soft_time($;$) {
	my $self = shift @_;
	if (@_) { $self->{_soft_time} = shift; }
	return $self->{_soft_time} || 30;
}

sub issuer($;$) {
	my $self = shift @_;
	if (@_) { $self->{_issuer} = shift; }
	return $self->{_issuer} || 'JazzHands';
}

sub label($;$) {
	my $self = shift @_;
	if (@_) {
		$self->{_label} = shift;
	}
	my $t = $self->{_type} || '';
	$t =~ s/^soft_//;
	return $self->{_label} || "JazzHands-$t";
}

sub key32($) {
	my $self = shift;
	$self->{key32};
}

sub encrypt {
	my $self = shift;
	my ( $text, $pw ) = @_;

	my $key = sha256($pw);

	my $iv = Crypt::CBC->random_bytes(16);

	my $data = $text;

	my $cipher = Crypt::CBC->new(
		-key         => $key,
		-cipher      => 'Rijndael',
		-iv          => $iv,
		-header      => 'none',
		-literal_key => 1,
	);
	my $cry = $iv . $cipher->encrypt($data);
	encode_base64( $cry, '' );
}

sub decrypt {
	my $self = shift;
	my ( $text, $pw ) = @_;
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
	my $plaintext = $cipher->decrypt($c_text);
	$plaintext;

}

sub add_encryption_id($;$$$) {
	my $self      = shift;
	my $dbkey     = shift;
	my $ekpurpose = shift || $self->ekpurpose;
	my $ekversion = shift || $self->ekversion;

	my $dbh = $self->dbh;

	if ( !$dbkey ) {
		$dbkey = substr( encode_base64( Crypt::CBC->random_bytes(20) ), 0, 20 );
	}

	my $sth = $dbh->prepare_cached(
		qq{
		WITH ins AS (
			INSERT INTO encryption_key (
				encryption_key_db_value,
				encryption_key_purpose,
				encryption_key_purpose_version,
				encryption_method
			) VALUES (
				?,
				?,
				?,
				?
			) RETURNING *
		) select * from ins LIMIT 1
	}
	) || die $dbh->errstr;

	$sth->execute( $dbkey, $ekpurpose, $ekversion,
		'aes256-cbc-hmac-sha256-base64' )
	  || die $sth->errstr;

	my $encid;
	if ( my $hr = $sth->fetchrow_hashref ) {
		$encid = $hr->{encryption_key_id};
	} else {
		die "Unable to add encryption key";
	}
	$sth->finish;
	return {
		encryption_key_id              => $encid,
		encryption_key_purpose         => $ekpurpose,
		encryption_key_purpose_version => $ekversion,
		dbkey                          => $dbkey,
	};
}

sub get_encryption_id($$) {
	my $self = shift;
	my $id   = shift;

	my $dbh = $self->dbh;
	my $sth = $dbh->prepare_cached(
		qq{
		SELECT	*
		FROM	encryption_key
		WHERE	encryption_key_id = ?
	}
	) || die $dbh->errstr;

	$sth->execute($id) || die $sth->errstr;

	my $hr = $sth->fetchrow_hashref;
	return undef if ( !$hr );
	$sth->finish;

	return {
		encryption_key_id              => $hr->{encryption_key_id},
		encryption_key_purpose         => $hr->{encryption_key_purpose},
		encryption_key_purpose_version => $hr->{encryption_key_purpose_version},
		dbkey                          => $hr->{encryption_key_db_value},
		encryption_key                 => $hr->{encryption_method},

	};
}

sub update_status($$) {
	my $self    = shift;
	my $tokenid = shift;
	my $login   = shift;
	my $status  = shift;

	my $dbh = $self->dbh;
	my $sth = $dbh->prepare_cached(
		qq{
		UPDATE token t
		SET token_status = ?
		FROM account_token at
		WHERE at.token_id = t.token_id
		AND account_id IN (select account_id
			FROM v_corp_family_account
			WHERE login = ?
		)
		AND t.token_id = ?
	}
	) || return undef;

	my $nr;
	if ( !( $nr = $sth->execute( $status, $login, $tokenid ) ) ) {
		$errstr = $sth->errstr;
		return undef;
	}
	$nr;
}

sub rm_token($$) {
	my $self    = shift;
	my $tokenid = shift;
	my $login   = shift;

	my $dbh = $self->dbh;
	my $sth = $dbh->prepare_cached(
		qq{
		DELETE FROM account_token
		WHERE token_id = ?
		AND account_id IN (select account_id
			FROM v_corp_family_account
			WHERE login = ?
		)
	}
	) || return undef;

	my $nr;
	if ( !( $nr = $sth->execute( $tokenid, $login ) ) ) {
		$errstr = $sth->errstr;
		return undef;
	}
	$nr;
}

sub fetch_token($$$) {
	my $self    = shift;
	my $tokenid = shift;

	my $dbh = $self->dbh;
	my $sth = $dbh->prepare_cached(
		qq{ SELECT
				token_type, token_status, time_modulo, token_key,
				encryption_key_id, token_password, is_token_locked,
				last_updated
			FROM token
			WHERE token_id = ?
	}
	) || die $dbh->errstr;

	$sth->execute($tokenid) || die $sth->errstr;
	my $hr = $sth->fetchrow_hashref();
	$sth->finish;

	return undef if ( !$hr );
	my $enc = $self->get_encryption_id( $hr->{encryption_key_id} );

	# get the part that's not in the db
	my $nondbkey =
	  $self->{_keymap}->{ $enc->{encryption_key_purpose_version} };

	# assemble the full key based on what's in the db
	my $fullkey = "$nondbkey" . $enc->{dbkey};

	my $tokenkey = $self->decrypt( $hr->{token_key}, $fullkey );

	my $key32 = MIME::Base32::encode($tokenkey);
	my $key64 = encode_base64($tokenkey);

	$self->{_type} = $hr->{token_type};
	$self->{key32} = $key32;
	$self->{key64} = $key64;
	$tokenid;
}

sub add_token($$$) {
	my $self   = shift;
	my $type   = shift;
	my $passwd = shift;
	my $status = shift;

	my $dbh = $self->dbh;

	$self->{_type} = $type;

	$status = 'enabled' if ( !$status );

	my $modulo;
	if ( $type eq 'soft_time' ) {
		$modulo = $self->soft_time || 30;
	}

	my ( $tokid, $tokenkey, $key32, $enckey );

	my $enc = $self->add_encryption_id();

	my $nondbkey = '';
	if ( $enc && $self->{_keymap} ) {
		$nondbkey =
		  $self->{_keymap}->{ $enc->{encryption_key_purpose_version} };
	}

	$tokenkey = Crypt::CBC->random_bytes(20);
	if ( !$self->{unencrypted} ) {
		my $fullkey = "$nondbkey" . $enc->{dbkey};
		$enckey = $self->encrypt( $tokenkey, $fullkey );
		my $dekey = encode_base64( $self->decrypt( $enckey, $fullkey ) );
		$key32    = MIME::Base32::encode($tokenkey);
		$tokenkey = encode_base64($tokenkey);
	} else {
		$enckey = encode_base64($tokenkey);
		$key32  = MIME::Base32::encode($tokenkey);
	}

	$self->{key32} = $key32;
	$self->{key64} = $tokenkey;

	if ($passwd) {
		$passwd = bcrypt(
			$passwd,
			'$2a$07$'
			  . en_base64(
				pack( "LLLL",
					rand(0xffffffff), rand(0xffffffff),
					rand(0xffffffff), rand(0xffffffff) )
			  )
		);
	}

	my $sth = $dbh->prepare_cached(
		qq{
		WITH ins AS (
			INSERT INTO token (
				token_type,
				token_status,
				time_modulo,
				token_key,
				encryption_key_id,
				token_password,
				is_token_locked,
				last_updated
			) VALUES (
				?,
				?,
				?,
				?,
				?,
				?,
				'N',
				now()
			) RETURNING *
		) select * from ins LIMIT 1
	}
	) || die $dbh->errstr;

	$sth->execute( $type, $status, $modulo, $enckey, $enc->{encryption_key_id},
		$passwd )
	  || die $sth->errstr;
	if ( my $hr = $sth->fetchrow_hashref ) {
		$tokid = $hr->{token_id};
	} else {
		die "Unable to add token";
	}
	$sth->finish;

	$self->{token_id} = $tokid;

	#
	# this should probably be smarter.
	#
	my $seq;
	if ( $type eq 'soft_time' ) {
		$seq = int( time() / $modulo ) - 1;
	} elsif ( $type eq 'soft_seq' ) {
		$seq = int rand(50);
	}

	if ( defined($seq) ) {
		$self->set_sequence($seq);
	}

	$tokid;
}

sub assign_token($$;$$) {
	my $self  = shift @_;
	my $login = shift @_;
	my $desc  = shift @_;
	my $tokid = shift @_ || $self->{token_id};

	my $dbh = $self->dbh;
	my $sth = $dbh->prepare_cached(
		qq{
		INSERT INTO account_token (
			account_id, token_id, issued_date, description
		) SELECT account_id, ?, now(), ?
			FROM v_corp_family_account
			WHERE login = ?
			ORDER BY account_id
			LIMIT 1
		RETURNING *
	}
	) || die $dbh->errstr;

	$sth->execute( $tokid, $desc, $login ) || die $sth->errstr;
	$sth->finish;

}

sub set_sequence($;$$) {
	my $self  = shift @_;
	my $seq   = shift @_ || 5;
	my $tokid = shift @_ || $self->{token_id};

	my $dbh = $self->dbh;
	my $sth = $dbh->prepare_cached(
		qq{
		WITH ins AS (
			INSERT INTO token_sequence (
				token_id,
				token_sequence,
				last_updated
			) VALUES (
				?,
				?,
				now()
			) RETURNING *
		) select * from ins LIMIT 1
	}
	) || die $dbh->errstr;

	$sth->execute( $tokid, $seq ) || die $sth->errstr;
	$sth->finish;

	$self->{_sequence} = $seq;
}

sub url($) {
	my $self = shift;

	my $label = $self->label;

	my $svc = 'hotp';
	if ( $self->{_type} eq 'soft_time' ) {
		$svc = 'totp';
	}

	my $key32  = $self->{key32};
	my $issuer = $self->issuer;

	$issuer = uri_escape($issuer);
	$label  = uri_escape($label);

	my $rv = "otpauth://$svc/$issuer%3A$label?secret=${key32}&issuer=$issuer";

	if ( $svc eq 'hotp' ) {
		my $counter = $self->{_sequence} + 1;
		$rv .= "&counter=" . $counter;
	}

	return $rv;
}

DESTROY {
	my $self = shift @_;

	if ($self) {
		$self->rollback;
		$self->disconnect;
	}
}

1;
