#
# Copyright (c) 2019-2022 Todd M. Kover

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
# $Id$
#

=head1 NAME

JazzHands::Vault - Connecting to Hashicorp Vault by JazzHands tools

=head1 SYNOPSIS

Method 1:

	$v = new JazzHands::Vault ( appauthal => jsonblob ) || die JazzHands::Vault::errstr;
	$newauth = $v->fetch_and_merge_dbauth($auth);

Method 2:

	$v = new JazzHands::Vault (
		VaultServer => 'https://vault.example.org:8200/',
		CAPath  => '/path/to/file/or/directory'
		VaultTokenPath => '/path/to/token'
		VaultSecretId    => 'secret-id', # _OR_
		VaultSecretIdPath => '/path/to/file/with/secret-id'
		VaultRoleId      => 'role-id', # _OR_
		VaultRoleIdPath => '/path/to/file/with/role-id',
	) || die JazzHands::Vault::errstr;

	my $hash = $v->read("kv/data/thing/secret", $metadata);
	my $hash = $v->write("kv/data/thing/secret", $hashofkvs);
	my $array = $v->list("kv/data/thing");
	$v->delete("kv/data/thing/secret");
	$v->delete_metadata("kv/data/thing");


This has two methods of use.   The first method get included if it's available
to JazzHands::AppAuthAL and is meant primarily for internal use by that module.
It is required to be installed in order to enable C<Method: Vault> in
AppAuthAL.

The second method is as an interface to generically interact with HashiCorp
Vault.   The arguments to new are the same as the keys in a hash passed to
the appauthal creation method.

The second method returns something on success in all operations, usually some
data from vault about the request.  The read operation can be passed an
extra parameter, if true, will return the metadata of the secret, instead of
just the secret data.

If any of the second methods fail, then the $v->errstr method can be used to
get a human readable message and $v->err will get the numeric http code
tied to the failure.  The code is not set on success.

=head1 DESCRIPTION

In both cases, the VaultServer must be set.  if it's not set, and the
environment variable VAULT_ADDR is set, that will get used.  Explicitly
setting the variable as an input wins over the environment variable.

There are two methods to authenticate to vault.  The first is using
approle, which requires a secret id and a role id.

Only one of VaultRoleId or VaultRoleIdPath can be set.  Both set will
cause new to fail.

Only one of VaultSecretId or VaultSecretIdPath can be set.  Both set will
cause new to fail.  It is generally ill advised to use VaultSecretId since
it is expected to change regularly

If VaultTokenPath is _also_ set and writable, the contents of that file
will be consulted (if it exists) to determine if the token is valid, and
not near expiration. if it's invalid or near expiration a new token will
be obtained, and if the file is writable, will be saved to that file.
If it is not writable (or not set) the token used by the approle login
will be revoked and discarded.

The second method involves setting just VaultTokenPath without setting
any of the role or secret id options.  In this case, that file must
contain a vault token that is passed in to vault. it will be left
unchanged and the expiration time not considered.  The code will fail if
the token is invalid.

The approle method was the original version of this library and exists
as a mechanism to extend dbauth/appauthal support to support HashiCorp
Vault. (vaultproject.io).  There is nothing to absolutely require this,
but it is written and designed with that in mind.

To that end, it generally works by taking an appauth entry pulled from
libraries with C<Method: Vault> and uses that to construct an entry that
does not have any vault.

The library can also be used to invoke the caching methodology documented
in JazzHands::AppAuthAL

The L<Vault: Method> requires the VaultServer, VaultPath, one of
VaultRoleId or VaultRoleIdPath, and one of VaultSecretIdPath or
VaultSecretId to be set.  VautlTokenIdPath may be set with or in lieu of the
role+secrets.  It is HIGHLY recommended that VaultSecretIdPath
be used and include a process of regular rotation of the secret id.

If both VaultSecretId and VaultSecretIdPath are set, it will fail.

If both VaultRoleId and VaultRoleIdPath are set, it will fail.

VaultSecretIdPath is the path to a file containing just the secret id to
be used.

The secret id and role ids are typically guid-type values that are
understood by vault.  The VaultPath should not have a leading slash or
include a vault restful api version number.

The end user is assumed to know how to use data in paths correctly.

CAPath can be specified optionally, which is the path to a file or
directory of OpenSSL-friendly CAs to validate the connection to vault
against.

The library will understand both kv and dynamic database credentials from
Vault (they are returned differently by the restful api).  In anticipation
of switching from kv to dynamic credentials, it's wise to name the username
and password keys, "username" and "password" (lower case) and map them
appropriately.

=head1 APPAUTHAL CONFIGURATION FILE

Vault friendly appauthal files are slightly different than others because
they end up being the union of values from vault and from the entry.

A minimal example is:

   {
	"options": {
		"vault": {
			"CAPath": "/usr/pkg/etc/openssl/certs",
			"VaultServer": "https://vault.example.com:8200",
			"VaultRoleId": "e3a17f50-6aea-15df-93f3-cc1651dcb4d9",
			"VaultSecretIdPath": "/var/lib/vault/stab/secret-id"
		}
	},
	"database": {
		"Method": "vault",
		"VaultPath": "kv/data/myfirstapp/db",
		"import": {
			"DBType": "postgresql",
			"Method": "password",
			"DBHost": "jazzhands-db.example.com",
			"DBName": "jazzhands"
		},
		"map": {
			"Username": "username",
			"Password": "password"
		}
	}
  }

The vault options can also be placed directly in the database
L<Method:Vault> entry and do not need to be pulled out into options, it
is just setup there to make setting up multiple credentials easier to
read.

The CAPath is used to override the system one that perl uses.

In this case, the library will retrieve L<kv/data/myfirstapp/db> after
logging in with the specified RoleId and a secret id pulled from
the first line of F</var/lib/vault/stab/secret-id> .  It then takes all
the keys in the import stanza and imports them into a synthesized appauth
entry, and then takes the values returned from the vault server and imports
them into the synthesized appauth entry mapping the value to the given
key.  Again, it is ideal to use username and password in kv pairs to make
future dynamic credentials easier.

Also note that there may be caching happening, as described in the
JazzHands::AppAuthAL documentation.

=head1 SEE ALSO

JazzHands::AppAuthAL, JazzHands::DBI

=head1 AUTHORS

Todd Kover (kovert@omniscient.com)

=cut

package JazzHands::Vault;

use strict;
use warnings;
use Exporter;
use LWP::Protocol::https;
use LWP::UserAgent;
use IO::Socket::SSL;
use FileHandle;
use JSON::PP;
use JazzHands::Common qw(:internal);
use Data::Dumper;
use File::Basename;
use Digest::SHA qw(sha1_hex);

use parent 'JazzHands::Common';

use vars qw(@EXPORT_OK @ISA $VERSION);

$VERSION = '0.86';

@ISA       = qw(JazzHands::Common Exporter);
@EXPORT_OK = qw();

our $ttl_refresh_seconds = 3600 / 2;

sub _process_arguments($$) {
	my $self    = shift;
	my $appauth = shift;

	# if it's defined in the input file that wins, otherwise allow the
	# VAULT_ADDR variable to override.  If it's in neither, it's fatal.
	if ( $ENV{VAULT_ADDR} ) {
		if ( !exists( $appauth->{VaultServer} ) ) {
			$appauth->{VaultServer} = $ENV{VAULT_ADDR};
		}
	} else {
		foreach my $thing (qw(VaultServer )) {
			if ( ( !exists( $appauth->{$thing} ) )
				|| !defined( $appauth->{$thing} ) )
			{
				$errstr = "Mandatory Vault Parameter $thing not specified";
				return undef;
			}
		}
	}

	# remove trailing slash if it's there.
	if ( exists( $appauth->{VaultServer} ) ) {
		$appauth->{VaultServer} =~ s,/$,,;
	} elsif ( defined( $ENV{VAULT_ADDR} ) ) {
		$self->{_uri} = $ENV{VAULT_ADDR};
		$appauth->{VaultServer} =~ s,/$,,;
	} else {
		$errstr =
		  "Mandatory Vault Parameter VaultServer or environment varilable VAULT_ADDR is not specified";
		return undef;
	}

	#
	# if VaultTokenPath is set, then the Role/Secrets are optional and it
	# is assumed that something external maintains this file.
	#
	# If it's not set, the minimum required to enable approle login is
	# required.
	#

	my $hasrole;
	my $hassecret;
	my $hastoken;

	if ( $appauth->{VaultTokenPath} ) {
		$self->{VaultTokenPath} = $appauth->{VaultTokenPath};
		$hastoken = 1;
	}

	if (   exists( $appauth->{VaultSecretId} )
		|| exists( $appauth->{VaultSecretIdPath} ) )
	{
		$hassecret = 1;
	}

	if (   exists( $appauth->{VaultRoleId} )
		|| exists( $appauth->{VaultRoleIdPath} ) )
	{
		$hasrole = 1;
	}

	if ($hastoken) {
		if ( ( $hassecret && !$hasrole ) || ( $hasrole && !$hassecret ) ) {
			$errstr =
			  "Either both Secret and Role information or neither must be passed when using tokens";
			return undef;
		}
	} elsif ( !$hassecret && !$hasrole ) {
		$errstr = "Token file must exist when secret/role data is not provided";
		return undef;
	}

	#
	# Either VaultSecretIdPath or VaultSecretId must be set.  Both may
	# not be set.  In the path case, the file is assumed to contain just
	# the role id similar to VaultSecretIdPath
	#
	if (   exists( $appauth->{VaultSecretId} )
		&& exists( $appauth->{VaultSecretIdPath} ) )
	{
		$errstr = "Both VaultSecretIdPath and VaultSecretId are set.";
		return undef;
	} elsif ( exists( $appauth->{VaultSecretIdPath} ) ) {
		if ( ( my $fh = new FileHandle( $appauth->{VaultSecretIdPath} ) ) ) {
			while ( my $l = $fh->getline() ) {
				chomp($l);
				$l =~ s/#.*$//;
				next if ( $l =~ /^\s*$/ );
				$self->{VaultSecretId} = $l;
				last;
			}
			$fh->close;
		} else {
			$errstr = sprintf "Unable to read Vault Secret Id from %s: %s",
			  $appauth->{VaultSecretIdPath},
			  $!;
			return undef;
		}
	} elsif ( exists( $appauth->{VaultSecretId} ) ) {
		$self->{VaultSecretId} = $appauth->{VaultSecretId};
	} elsif ( !$hastoken ) {
		$errstr = "Neither VaultSecretIdPath nor VaultSecetId are set.";
		return undef;
	}
	#
	# Either VaultRoleIdPath or VaultRoleId need to be set.  Both can not be
	# set.  In the path case, the file is assumed to contain just the role
	# id similar to VaultSecretIdPath
	#
	if (   exists( $appauth->{VaultRoleId} )
		&& exists( $appauth->{VaultRoleIdPath} ) )
	{
		$errstr = "Both VaultRoleIdPath and VaultRoleId are set.";
		return undef;
	} elsif ( exists( $appauth->{VaultRoleIdPath} ) ) {
		if ( ( my $fh = new FileHandle( $appauth->{VaultRoleIdPath} ) ) ) {
			while ( my $l = $fh->getline() ) {
				chomp($l);
				$l =~ s/#.*$//;
				next if ( $l =~ /^\s*$/ );
				$self->{VaultRoleId} = $l;
				last;
			}
			$fh->close;
		} else {
			$errstr = sprintf "Unable to read Vault Role Id from %s: %s",
			  $appauth->{VaultRoleIdPath},
			  $!;
			return undef;
		}
	} elsif ( exists( $appauth->{VaultRoleId} ) ) {
		$self->{VaultRoleId} = $appauth->{VaultRoleId};
	} elsif ( !$hastoken ) {
		$errstr = "Neither VaultRoleIdPath nor VaultRoleId are set.";
		return undef;
	}

	# extra check in case the above failed.
	if ( !$hastoken && !( defined( $self->{VaultSecretId} ) ) ) {
		$errstr = "VaultSecretId could not be determined.";
		return undef;
	}

	# extra check in case the above failed.
	if ( !$hastoken && !( defined( $self->{VaultRoleId} ) ) ) {
		$errstr = "VaultRoleId could not be determined.";
		return undef;
	}

	if (   $hastoken
		&& !( defined( $self->{VaultRoleId} ) )
		&& !( defined( $self->{VaultSecretId} ) ) )
	{
		if ( !-r $self->{VaultTokenPath} ) {
			$errstr = sprintf "Token file required but does not exist: %s",
			  $self->{VaultTokenPath};
			return undef;
		}
	}

	my $capath = $ENV{'VAULT_CAPATH'} || $appauth->{CAPath};
	if ( $capath) {
		if ( -f $capath ) {
			$self->{sslargs}->{SSL_ca_file} = $capath;
		} elsif ( -d $capath ) {
			$self->{sslargs}->{SSL_ca_path} = $capath;
		} else {
			$errstr = sprintf "Invalid CAPath %s", $capath;
			return undef;
		}
	}

	$self->{_appauthal} = $appauth;
}
#
# takes $appauthal argument that's a hash of all the things required to
# talk to vault.
#
sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self  = $class->SUPER::new(@_);

	my $opt = &_options(@_);
	if ( my $appauth = $opt->{appauthal} ) {
		_process_arguments( $self, $appauth ) || return undef;

		#
		# This is required for appauthal mode but not useful in non-appauthal
		# form.
		#
		foreach my $thing (qw(VaultPath )) {
			if ( ( !exists( $appauth->{$thing} ) )
				|| !defined( $appauth->{$thing} ) )
			{
				$errstr = "Mandatory Vault Parameter $thing not specified";
				return undef;
			}
		}
	} else {
		_process_arguments( $self, $opt ) || return undef;

		#
		# Not valid for non-appauthal form
		#
		foreach my $thing (qw(VaultPath )) {
			if ( ( exists( $appauth->{$thing} ) )
				|| defined( $appauth->{$thing} ) )
			{
				$errstr = "$thing is not permitted in non-appauthal form";
				return undef;
			}
		}

		# now go make sure we are ready to do vault ops
		$self->approle_login() || return undef;
	}

	return bless $self, $class;
}

sub build_cache_key($$) {
	my ( $self, $auth ) = @_;

	# This happens when the role id is pulled from a file.
	my $roleid =
		 $auth->{VaultRoleId}
	  || $self->{VaultRoleId}
	  || (
		( exists( $self->{_token} ) ) ? sha1_hex( $self->{_token} ) : undef );
	my $server = $auth->{VaultServer}
	  || (
		( exists( $self->{_appauthal} ) )
		? $self->{_appauthal}->{VaultServer}
		: undef
	  );
	my $path = (
		exists( $self->{_appauthal} )
		? $self->{_appauthal}->{VaultPath}
		: $auth->{VaultPath} );

	return undef if ( !$roleid || !$server || !$path );

	my $key = sprintf "%s@%s/%s", $server, $roleid, $path;
	$key =~ s,[/:],_,g;
	return $key;
}

#
# this is deprecated.  Do not use it.  If direct chatter with vault is
# requried not provided by a method, a method should be created.
#
sub fetchurl {
	return _fetchurl(@_);
}

sub _fetchurl {
	my $self = shift @_;

	my $opt = &_options(@_);

	undef $errcode;
	undef $errstr;

	my $url    = $opt->{url};
	my $method = $opt->{method} || 'GET';
	my $data   = $opt->{data};

	if ( !defined($url) ) {
		$errstr = "URL not passed to _fetchurl";
		return undef;
	}

	my $ua = LWP::UserAgent->new( ssl_opts => $self->{sslargs} );
	$ua->agent("JazzHands::Vault/$VERSION");

	my $req = HTTP::Request->new( $method => $url );

	# favor the token passed in as an option, failing that use the one in
	# $self, unless no_token is passed as an argument.
	if ( $opt->{token} ) {
		$req->header( 'X-Vault-Token', $opt->{token} );
	} elsif ( $self->{_token} && !$opt->{no_token} ) {
		$req->header( 'X-Vault-Token', $self->{_token} );
	}

	my $json = JSON::PP->new();
	if ($data) {
		my $body = $json->encode($data);
		$req->content_type('application/json');
		$req->content($body);
	}

	my $res = $ua->request($req);

	if ( !$res->is_success ) {
		$errcode = $res->code;
		$errstr  = sprintf "%s: %s", $url, $res->status_line;
		if ( $res->content ) {
			my $vaulterr;
			eval {
				$vaulterr = $json->decode( $res->content );
				if ( exists( $vaulterr->{errors} ) ) {
					$errstr = sprintf "%s: (%s): %s",
					  $url, $res->code, join( ",", @{ $vaulterr->{errors} } );
				}
			};

		}

		return undef;
	}

	if ( $res->content ) {
		return $json->decode( $res->content );
	} else {

		# some methods (like DELETE) allow for an empty payload.
		return {};
	}
	return undef;
}

sub _readtoken($) {
	my $self = shift @_;

	return undef if ( !exists( $self->{_appauthal}->{VaultTokenPath} ) );
	return undef if ( !defined( $self->{_appauthal}->{VaultTokenPath} ) );
	return undef if ( !-r $self->{_appauthal}->{VaultTokenPath} );

	my $fn = $self->{_appauthal}->{VaultTokenPath};

	#
	# what to do if $token is already set?
	#
	my $token;
	if ( ( my $fh = new FileHandle($fn) ) ) {
		$token = $fh->getline();
		$fh->close;
		chomp($token);
	}

	$token;

}

#
# return 0 if the approle dance needs to happen
# return 1 if we have a valid token already.
#
sub _check_and_test_token_cache($) {
	my $self = shift @_;

	if ( !$self->{_token} ) {
		my $token = $self->_readtoken();

		delete( $self->{_token} );
		delete( $self->{token_lease_duration} );

		if ($token) {
			my $url = sprintf "%s/v1/auth/token/lookup-self",
			  $self->{_appauthal}->{VaultServer};

			my $resp = $self->_fetchurl(
				method => 'GET',
				url    => $url,
				token  => $token,
			);

			if ( $resp && $resp->{data} ) {
				$self->{_token}               = $token;
				$self->{token_lease_duration} = $resp->{data}->{ttl};
			}
		}
	} else {
		return (0);
	}

	if ( !defined( $self->{token_lease_duration} ) ) {
		return 0;
	}

	# does not expire.
	if ( $self->{token_lease_duration} == 0 ) {
		return 1;
	}

	# ttl from lookup-self seems to be number of second remaining.
	if ( $self->{token_lease_duration} > $ttl_refresh_seconds ) {
		return 1;
	}

	return 0;
}

#
# save the token if it's possible to save it.
#
# returns undef on fail, the token on success
#
sub _save_token($$) {
	my $self = shift @_;
	my $auth = shift @_;

	my $token = $auth->{client_token};

	return undef if ( !exists( $self->{_appauthal}->{VaultTokenPath} ) );
	return undef if ( !defined( $self->{_appauthal}->{VaultTokenPath} ) );
	my $tokenpath = $self->{_appauthal}->{VaultTokenPath};

	my $d     = dirname($tokenpath);
	my $tmpfn = $tokenpath . "_tmp.$$";

	if ( !-w $tokenpath ) {
		return undef if ( !-w $d );
	}

	my $curtok = $self->_readtoken( $self->{_appauthal}->{VaultTokenPath} );
	return $token if ( $curtok && $curtok eq $token );

	if ( !-w $d ) {

		# gross but Vv
		$tmpfn = $tokenpath;
	}

	if ( my $fh = new FileHandle( ">" . $tmpfn ) ) {
		$fh->printf( "%s\n", $token );
		$fh->close;

		if ( $tmpfn ne $tokenpath ) {
			my $oldfn = $tokenpath . "_old";
			unlink($oldfn);
			rename( $tokenpath, $oldfn );
			if ( !rename( $tmpfn, $tokenpath ) ) {
				rename( $oldfn, $tokenpath );
			} else {
				unlink($oldfn);
			}
		}
	}

	$token;
}

#
# login using an approle, but use a token if the tokenpath is set and it
# exists.  stash the token in said file if it's a different one.
#
sub approle_login {
	my $self = shift @_;

	return $self->{_token} if $self->_check_and_test_token_cache();

	my $url = sprintf "%s/v1/auth/approle/login",
	  $self->{_appauthal}->{VaultServer};

	my $resp = $self->_fetchurl(
		no_token => 1,
		method   => 'POST',
		url      => $url,
		data     => {
			'role_id'   => $self->{VaultRoleId},
			'secret_id' => $self->{VaultSecretId},
		},
	);

	if ( !$resp ) {
		return undef;
	}

	if ( !$resp->{auth} && !$resp->{auth}->{client_token} ) {
		$errstr = "did not receive client token from vault server";
		return undef;
	}

	#
	# does this need to be converted to a time_t (two places)
	#
	if ( $resp->{auth}->{lease_duration} ) {
		$self->{token_lease_duration} = $resp->{auth}->{lease_duration};
	} else {
		$self->{token_lease_duration} = 86400;    # XXX
	}

	$self->_save_token( $resp->{auth} );
	$self->{_token} = $resp->{auth}->{client_token};
}

#
# arguably needs to take the path asn an argument and become "read" or "get"
#
sub _get_vault_path($$) {
	my $self = shift @_;
	my $path = shift @_;

	my $opt = &_options(@_);

	my $url = sprintf "%s/v1/%s", $self->{_appauthal}->{VaultServer}, $path;

	my $resp = $self->_fetchurl( url => $url, );

	if ( !$resp ) {
		$errstr = "did not receive credentials from vault server";
		return undef;

	}

	if ( !$resp->{data} ) {
		$errstr = "No dbauth data returned in vault request to $url";
		return undef;
	}
	#
	# dynamic credentials are different.  It's possible the smarts here
	# should be moved to the caller.

	#
	my $dbauth;
	if ( $resp->{data}->{data} ) {
		$dbauth = $resp->{data}->{data};
	} else {
		$dbauth = $resp->{data};
	}

	if ( $resp->{lease_duration} ) {
		$dbauth->{'lease_duration'} = $resp->{lease_duration};
	}
	$dbauth;
}

#
# this does the login and fetches the key.
#
sub fetch_and_merge_dbauth {
	my $self = shift @_;
	my $auth = shift @_;

	my $vaultpath = $self->{_appauthal}->{VaultPath};
	if ( !$vaultpath ) {
		$errstr = "Class was not instantiated for appauthal usage";
		return undef;
	}

	$self->approle_login                           || return undef;
	my $vault = $self->_get_vault_path($vaultpath) || return undef;

	my $rv = {};
	if ( exists( $auth->{import} ) ) {
		foreach my $key ( keys %{ $auth->{import} } ) {
			$rv->{$key} = $auth->{import}->{$key};
		}
	}
	if ( exists( $auth->{map} ) ) {
		foreach my $key ( keys %{ $auth->{map} } ) {
			my $vkey = $auth->{map}->{$key};
			$rv->{$key} = $vault->{$vkey};
		}
	}

	if ( exists( $vault->{'lease_duration'} ) ) {
		$rv->{'__Expiration'} = $vault->{'lease_duration'};
	}

	$rv;
}

sub revoke_my_token {
	my $self = shift @_ || return;

	if ( $self->{_token} ) {
		my $url = sprintf "%s/v1/auth/token/revoke-self",
		  $self->{_appauthal}->{VaultServer};

		my $resp = $self->_fetchurl(
			method => 'POST',
			url    => $url,
		);
		delete( $self->{_token} );
		$resp;
	}
}

sub write {
	my $self = shift @_;
	my $path = shift @_;
	my $data = shift @_;

	my $url = sprintf "%s/v1/%s", $self->{_appauthal}->{VaultServer}, $path;

	my $resp = $self->_fetchurl(
		method => 'POST',
		url    => $url,
		data   => $data
	);

	if ( !$resp ) {
		# pass back $errstr from _fetchurl
		return undef;
	}
	return 1;
}

sub read {
	my $self     = shift @_;
	my $path     = shift @_;
	my $metadata = shift @_;

	my $url = sprintf "%s/v1/%s", $self->{_appauthal}->{VaultServer}, $path;

	my $resp = $self->_fetchurl(
		method => 'GET',
		url    => $url,
	);

	if ( !$resp ) {

		# pass back $errstr
		return undef;
	}
	if ($metadata) {
		return $resp->{data};
	}
	return $resp->{data}->{data};
}

##############################################################################
# Delete metadata from Vault
# Ex.: you have 'kv/data/myfirstapp/foo name=foo pass=bar'
#
# --> use 'delete' method on 'kv/myfirstapp/foo'
#     in order to delete the secrets (name and pass in this example)
# --> Use 'delete_metadata' method on 'kv/myfirstapp/foo'
#     in order to delete the 'foo' path.
##############################################################################
sub delete {
	my $self = shift @_;
	my $path = shift @_;
	my $data = shift @_;

	my $url = sprintf "%s/v1/%s", $self->{_appauthal}->{VaultServer}, $path;

	my $resp = $self->_fetchurl(
		method => 'DELETE',
		url    => $url,
	);

	if ( !$resp ) {

		# pass back $errstr
		return undef;
	} elsif ( $resp->{data} ) {
		return $resp->{data};
	} else {
		return {};
	}
}

# deletes the path, not just the secret (see comment for delete).
sub delete_metadata {
	my $self = shift @_;
	my $path = shift @_;
	( my $real_path = $path ) =~ s/\/data\//\/metadata\//;

	my $url = sprintf "%s/v1/%s", $self->{_appauthal}->{VaultServer},
	  $real_path;

	my $resp = $self->_fetchurl(
		method => 'DELETE',
		url    => $url,
	);

	if ( !$resp ) {

		# pass back $errstr
		return undef;
	} elsif ( $resp->{data} ) {
		return $resp->{data};
	} else {
		return {};
	}
}

sub list {
	my $self = shift @_;
	my $path = shift @_;
	my $data = shift @_;

	( my $real_path = $path ) =~ s/\/data\//\/metadata\//;

	my $url = sprintf "%s/v1/%s", $self->{_appauthal}->{VaultServer},
	  $real_path;

	my $resp = $self->_fetchurl(
		method => 'LIST',
		url    => $url,
	);

	if ( !$resp ) {

		# pass back $errstr
		return undef;
	}
	return $resp->{data}->{keys};
}

sub DESTROY {
	my $self = shift @_ || return;

	if (   $self->{VaultRoleId}
		&& $self->{VaultSecretId}
		&& !$self->{VaultTokenPath} )
	{
		$self->revoke_my_token();
	}
}
1;
