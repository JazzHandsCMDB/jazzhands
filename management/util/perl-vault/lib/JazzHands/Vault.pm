#
# Copyright (c) 2019 Todd M. Kover
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
support HashiCorp vault.  There's nothing to absolutely require this, but
it is written and designed with that in mind.

It only implements approle style auth where it uses that to get a
limited life token, but will likely be extended to also allow for
token-based login assuming something external to it manages the token
retrival.

To that end, it generally works by taking an appauth entry pulled from
libraries with C<Method: Vault> and uses that to construct an entry that
does not have any vault.

The library can also be used to invoke the caching library documented
in JazzHands::AppAuthAL

The L<Vault: Method> requires the VaultServer, VaultPath, VaultRoleId and
one of VaultSecretIdPath or VaultSecretId to be set.  It is HIGHLY
recommended that VaultSecretIdPath be used and include a process of regular
rotation of the secret id.  VaultSecretId is mostly implemented to deal with
unusual/emergency type situations where one might need to use it.  If both
VaultSecretIdPath and VaultSecretId are specified, VaultSecretIdPath wins.

VaultSecretIdPath is the path to a file containing just the secret id to
be used.

The secret id and role ids are guid-type values that are understood by vault.
The VaultPath should not have a leading slash or include a vault restful
api version number.

CAPath can be specified optionally, which is the path to a file or
directory of OpenSSL-friendly CAs to validate the connection to vault
against.

The library will understand both kv and dynamic database credentials from
Vault (they are returned differently by the restful api).  In anticipation
of switching from kv to dynamic credentials, it's wise to name the username
and password keys, "username" and "password" (lower case) and map them
appropriately.

=head1 CONFIGURATION FILE

The vault configuration files are slightly differnet than others because
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

THe CAPath is used to override the system one that perl uses.

In this case, the library will retrive L<kv/data/myfirstapp/db> after
loging in with the specified RoleId and a secret id pulled from
the first line of F</var/lib/vault/stab/secret-id> .  It then takes all
the keys in the import stanza and imports them into a synthesized appauth
entry, and then takes the values returned from the vault server and imports
them into the synthesized appauth entry mapping the value to the given
key.  Again, it is ideal to use usename and password in kv pairs to make
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
	foreach my $thing (qw(VaultServer VaultPath VaultRoleId)) {
		if ( ( !exists( $appauth->{$thing} ) )
			|| !defined( $appauth->{$thing} ) )
		{
			$errstr = "Mandatory Vault Parameter $thing not specified";
			return undef;
		}
	}

	if (   !exists( $appauth->{VaultSecretId} )
		&& !exists( $appauth->{VaultSecretIdPath} )
		&& !$appauth->{VaultSecretId}
		&& !$appauth->{VaultSecretIdPath} )
	{
		$errstr = "Mandatory Vault Parameter VaultSecretIdPath not specified";
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
			$errstr = sprintf "Unable to read secretid from %s: %s",
			  $appauth->{VaultSecretId},
			  $!;
			return undef;
		}
	} else {
		$self->{VaultSecretId} = $appauth->{VaultSecretId};
	}

	# extra check in case the above failed.
	if ( !( defined( $self->{VaultSecretId} ) ) ) {
		$errstr = "VaultSecretId could not be determined.";
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
		return undef;
	}

	$json->decode( $res->content ) || die $!;
}

sub approle_login {
	my $self = shift @_;

	my $url = sprintf "%s/v1/auth/approle/login",
	  $self->{_appauthal}->{VaultServer};

	my $resp = $self->fetchurl(
		method => 'POST',
		url    => $url,
		data   => {
			'role_id'   => $self->{_appauthal}->{VaultRoleId},
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

	$self->approle_login || return undef;
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

1;
