#
# Copyright (c) 2019-2021 Todd M. Kover
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

	$v = new JazzHands::Vault ( appauthal => jsonblob )
	$newauth = $v->fetch_and_merge_dbauth($auth);


This is generally not used by mortals but gets included if it's available
to JazzHands::AppAuthAL.  It is required to be installed in order to
enable C<Method: Vault> in AppAuthAL.

It is possible that this will grow to something to become a generic interface
to HashiCorp Vault.

=head1 DESCRIPTION

This library primarily exists as a mechanism to extend dbauth support to
support HashiCorp Vault.  (vaultproject.io).  There is nothing to
absolutely require this, but it is written and designed with that in mind.

It only implements approle style auth where it uses that to get a
limited life token, but will likely be extended to also allow for
token-based login assuming something external to it manages the token
retrieval.

To that end, it generally works by taking an appauth entry pulled from
libraries with C<Method: Vault> and uses that to construct an entry that
does not have any vault.

The library can also be used to invoke the caching library documented
in JazzHands::AppAuthAL

The L<Vault: Method> requires the VaultServer, VaultPath, one of
VaultRoleId or VaultRoleIdPath, and one of VaultSecretIdPath or
VaultSecretId to be set.  It is HIGHLY recommended that VaultSecretIdPath
be used and include a process of regular rotation of the secret id.
VaultSecretId is mostly implemented to deal with unusual/emergency
type situations where one might need to use it.  If both VaultSecretIdPath
and VaultSecretId are specified, VaultSecretIdPath wins.  If both
VaultRoleId and VaultRoleIdPath are set, it will fail.

VaultSecretIdPath is the path to a file containing just the secret id to
be used.

The secret id and role ids are guid-type values that are understood by vault.
The VaultPath should not have a leading slash or include a vault restful
api version number.

The retrieved token is revoked after it is used so it will not be valid
outside the lifetime of the object created by new.

CAPath can be specified optionally, which is the path to a file or
directory of OpenSSL-friendly CAs to validate the connection to vault
against.

The library will understand both kv and dynamic database credentials from
Vault (they are returned differently by the restful api).  In anticipation
of switching from kv to dynamic credentials, it's wise to name the username
and password keys, "username" and "password" (lower case) and map them
appropriately.

=head1 CONFIGURATION FILE

The vault configuration files are slightly different than others because
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
			"DBHost": "jazzhands-db.eample.com",
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
use JazzHands::Common qw(_options SetError $errstr );
use Data::Dumper;

use parent 'JazzHands::Common';

use vars qw(@EXPORT_OK @ISA $VERSION);

$VERSION = '0.86';

@ISA       = qw(JazzHands::Common Exporter);
@EXPORT_OK = qw();

#
# takes $appauthal argument that's a hash of all the things required to
# talk to vault.
#
sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self  = $class->SUPER::new(@_);

	my $opt     = &_options(@_);
	my $appauth = $opt->{appauthal};

	# VaultRoleName - can be path in /var/lib/vault/stab ?  maybe?
	# VaultSecretIdPath - path to file containing secret
	foreach my $thing (qw(VaultServer VaultPath )) {
		if ( ( !exists( $appauth->{$thing} ) )
			|| !defined( $appauth->{$thing} ) )
		{
			$errstr = "Mandatory Vault Parameter $thing not specified";
			return undef;
		}
	}

	# remove trailing slash if it's there.
	if ( exists( $appauth->{VaultServer} ) ) {
		$appauth->{VaultServer} =~ s,/$,,;
	}

	if (   !exists( $appauth->{VaultSecretId} )
		&& !exists( $appauth->{VaultSecretIdPath} )
		&& !$appauth->{VaultSecretId}
		&& !$appauth->{VaultSecretIdPath} )
	{
		$errstr = "Mandatory Vault Parameter VaultSecretIdPath not specified";
		return undef;
	}

	if (   !exists( $appauth->{VaultRoleId} )
		&& !exists( $appauth->{VaultRoleIdPath} )
		&& !$appauth->{VaultRoleId}
		&& !$appauth->{VaultRoleIdPath} )
	{
		$errstr = "Mandatory Vault Parameter VaultRoleIdPath not specified";
		return undef;
	}

	#
	# VaultSecretIdPath is the right way to do this, but one can also include
	# both the VaultSecretId rather than pulling it from a file.  Generally
	# speaking, the RoleId is not something to be protected bu the SecretId
	# is, thus having both is basically like having credentials.  That said,
	# sometimes this is something that needs to happen with debugging, so it's
	# in there. If both are defined, the path wins.
	#
	# The Secret Id is also expected to rotate often.
	#
	if ( exists( $appauth->{VaultSecretIdPath} ) ) {
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
	} else {
		$errstr = "Neither VaultSecretIdPath nor VaultSecretId are set.";
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
	} else {
		$errstr = "Neither VaultRoleIdPath nor VaultRoleId are set.";
		return undef;
	}

	# extra check in case the above failed.
	if ( !( defined( $self->{VaultSecretId} ) ) ) {
		$errstr = "VaultSecretId could not be determined.";
		return undef;
	}

	# extra check in case the above failed.
	if ( !( defined( $self->{VaultRoleId} ) ) ) {
		$errstr = "VaultRoleId could not be determined.";
		return undef;
	}

	$self->{sslargs} = {};
	if ( $appauth->{CAPath} ) {
		my $ca = $appauth->{CAPath};
		if ( -f $ca ) {
			$self->{sslargs}->{SSL_ca_file} = $ca;
		} elsif ( -d $ca ) {
			$self->{sslargs}->{SSL_ca_path} = $ca;
		} else {
			$errstr = sprintf "Invalid CAPath %s", $ca;
			return undef;
		}
	}

	$self->{_appauthal} = $appauth;
	return bless $self, $class;
}

sub build_cache_key($$) {
	my ( $self, $auth ) = @_;

	# This happens when the role id is pulled from a file.
	my $roleid = $auth->{VaultRoleId} || $self->{VaultRoleId};
	my $server = $auth->{VaultServer};
	my $path   = $auth->{VaultPath};

	return undef if ( !$roleid || !$server || !$path );

	my $key = sprintf "%s@%s/%s", $server, $roleid, $path;
	$key =~ s,[/:],_,g;
	return $key;
}

sub fetchurl {
	my $self = shift @_;

	my $opt = &_options(@_);

	my $url    = $opt->{url};
	my $method = $opt->{method} || 'GET';
	my $data   = $opt->{data};

	if ( !defined($url) ) {
		$errstr = "URL not passed to fetchurl";
		return undef;
	}

	my $ua = LWP::UserAgent->new( ssl_opts => $self->{sslargs} );
	$ua->agent("JazzHands::Vault/$VERSION");

	my $req = HTTP::Request->new( $method => $url );

	if ( $opt->{token} ) {
		$req->header( 'X-Vault-Token', $opt->{token} );
	}

	my $json = JSON::PP->new();
	if ($data) {
		my $body = $json->encode($data);
		$req->content_type('application/json');
		$req->content($body);
	}

	my $res = $ua->request($req);

	if ( !$res->is_success ) {
		$errstr = sprintf "%s: %s", $url, $res->status_line;
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
		$json->decode( $res->content );
	} else {
		return {};
	}
}

sub approle_login {
	my $self = shift @_;

	my $url = sprintf "%s/v1/auth/approle/login",
	  $self->{_appauthal}->{VaultServer};

	my $resp = $self->fetchurl(
		method => 'POST',
		url    => $url,
		data   => {
			'role_id'   => $self->{VaultRoleId},
			'secret_id' => $self->{VaultSecretId},
		},
	);

	if ( !$resp ) {

		# $errstr set in fetchurl.
		return undef;
	}

	if ( !$resp->{auth} && !$resp->{auth}->{client_token} ) {
		$errstr = "did not receive client token from vault server";
		return undef;
	}

	if ( $resp->{auth}->{lease_duration} ) {
		$self->{token_lease_duration} = $resp->{auth}->{lease_duration};
	}

	$self->{token} = $resp->{auth}->{client_token};
}

sub get_vault_path {
	my $self = shift @_;

	my $token = $self->{token};

	my $opt = &_options(@_);

	my $url = sprintf "%s/v1/%s",
	  $self->{_appauthal}->{VaultServer},
	  $self->{_appauthal}->{VaultPath};

	my $resp = $self->fetchurl(
		url   => $url,
		token => $token,
	);

	if ( !$resp ) {

		# $errstr = "did not receive credentials from vault server";
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

	$self->approle_login                || return undef;
	my $vault = $self->get_vault_path() || return undef;

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

sub DESTROY {
	my $self = shift @_ || return;

	if ( $self->{token} ) {
		my $url = sprintf "%s/v1/auth/token/revoke-self",
		  $self->{_appauthal}->{VaultServer};

		my $resp = $self->fetchurl(
			method => 'POST',
			url    => $url,
			token  => $self->{token},
		);
		delete( $self->{token} );
	}

}

1;
