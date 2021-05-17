
# Copyright (c) 2011-2019 Todd M. Kover, Matthew Ragan
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

JazzHands::DBI - database authentication abstraction for Perl

=head1 SYNOPSIS

use JazzHands::DBI;
my $dbh = JazzHands::DBI->connect($app, [ $instance, ] [ $flags ], [$user]);

Instance and flags are optional, but if you want to set user, you need to pass
an undef for instance.

Alternatively:

use JazzHands::DBI;
my $jhdbi = JazzHands::DBI->new;
my $dbh = $jhdbi->connect(
	application => $app,
	instance => $instance,
	dbiflags => {},
	appuser => $appuser,
	errors => \@errors
);

When calling using the OO interface, only application is required.

DBI::set_session_user($dbh, $user)
$jhdbi->set_session_user($user)

Sets the session user based on what is appropriate for the underlying database

=head1 DESCRIPTION

In the non-OO case, it is meant to be a drop in replacement for the perl
DBI module.

This is the perl implementation of the Application Authorization Layer for
talking to databases.   Given application details, the library figures out
connection details, connects and returns a DBI handle for talking to said
database.  This allows connection information to be completely outside the
code, stored in a standardized fashion.

There is support for various login methods, including using Hashicorp Vault
to store the actual crednetials, which is handled by the JazzHands::Vault
module.  Note that the it is still necessary for the calling application
to ensure the correct DBD module is installed, and in the case of vault
support, that JazzHands::Vault is supported.

DBI/databse configuration happens under the top level "database" stanza.
Ultimately the DBType must be set, and based on that typically also
Username, Password, DBName, DBHost and DBPort although if the underlying
library has defaults, they can be left out.  The Method argument can be
password, which just does basic username and password auth or Vault, which
uses Hashicorp Vault to determine credentials and synthesize a dbauth entry
that gets parsed by this library.  JazzHands::Vault contains the information
on how this works. 

=head1 APPAUTHAL FILE

An example of a minimal configuration for a database is this:

  {
	"database": {
		"DBType": "postgresql",
		"Method": "password",
		"DBHost": "jazzhands-db.example.com",
		"DBName": "jazzhands",
		"Username": "app_stab",
		"Password": "thisisabadpassword"
	}
  }

Values are case sensitive.  It is possible to set the value to a an array of
entries, in which case they are tried serially until one works.

=head1 CONFIGURATION FILE

The global configuration file (defaults to /etc/jazzhands/appauth.json) can
be used to define system wide defaults.  It is optional.

The file format for dbauth files themselves is documented in
JazzHands::AppAuthAL, and the Hashicorp vault specifics can be found in
JazzHands::Vault.

=head1 FILES

/etc/jazzhands/appauth.json - configuration file
/var/lib/jazzhands/appauth-info - Default Location for Auth Files

=head1 ENVIRONMENT

The APPAUTHAL_CONFIG config can be set to a pathname to a json configuration
file that will be used instead of the optional global config file.  If this
variable is set, the config file becomes required.


=head1 AUTHORS

Todd Kover (kovert@omniscient.com)
Matthew Ragan (mdr@sucksless.net)

=cut

package JazzHands::DBI;

use strict;
use warnings;
use Exporter;
use JazzHands::AppAuthAL qw(:parse :cache);
use JazzHands::Common qw(:all);
use DBI;
use FileHandle;
use Data::Dumper;

use parent 'JazzHands::Common';

use vars qw(@EXPORT_OK @ISA $VERSION);

$VERSION = '0.55';

@ISA       = qw(DBI Exporter);
@EXPORT_OK = qw(set_session_user set_transaction_type errstr);

my $appauth_config = $JazzHands::AppAuthAL::appauth_config;

# our implemenation of DBI::connect.
#
# We provide no defaults, but the underlying DBD module may provide something.
#

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self  = {};
	my $opt   = _options(@_);

	return bless $self, $class;
}

sub errstr {
	return $errstr;
}

sub optional_set_session_user {
	my ( $dbh, $options, $dude ) = @_;

	return $dbh if ( !$dbh );

	my $doit = 0;
	if ( $options && $options->{'use_session_variables'} ) {
		if ( $options->{'use_session_variables'} =~ /^y(es)?$/i ) {
			$doit = 1;
		}
	}
	if ( !$doit ) {
		if ( !defined( $appauth_config->{'use_session_variables'} ) ) {
			return $dbh;
		}

		if ( $appauth_config->{'use_session_variables'} =~ /^n(o)?$/i ) {
			return $dbh;
		}
		$doit = 1;
	}

	return $dbh if ( !$doit );

	# If here is reached, then it means session variables are on.  The
	# default is to not use them.

	if ( !defined($dude) ) {
		$dude = ( getpwuid($<) )[0] || 'unknown';
	}
	return set_session_user( $dbh, $dude );
}

sub set_session_user {
	my ( $dbh, $dude ) = @_;

	if ( !defined($dbh) ) {
		return undef;
	}

	if ( !exists( $dbh->{Driver} ) && exists( $dbh->{_DBHandle} ) ) {
		$dbh = $dbh->{_DBHandle};
	}

	# XXX oracle untested
	if ( $dbh->{Driver}->{Name} eq 'oracle' ) {
		$dbh->do(
			qq{
			begin
				dbms_session.set_identifier ('$dude');
			end;
		}
		);    # XXX not fatal?
	} elsif ( $dbh->{Driver}->{Name} eq 'Pg' ) {
		$dbh->do(
			qq{
				set jazzhands.appuser to '$dude';
		}
		);    # XXX not fatal?
	} else {

		# unable to do it for this type, so silently let through.
	}
	$dbh;
}

sub set_transaction_type {
	my ( $dbh, $type ) = @_;

	if ( !defined($dbh) ) {
		return undef;
	}

	if ( !exists( $dbh->{Driver} ) && exists( $dbh->{_DBHandle} ) ) {
		$dbh = $dbh->{_DBHandle};
	}

	if ( $dbh->{Driver}->{Name} eq 'Pg' ) {
		$dbh->do(
			qq{
                                set transaction ISOLATION LEVEL $type;
                }
		);    # XXX not fatal?
	} else {

		# unable to do it for this type, so silently let through.
	}
	$dbh;
}

#
# Our implementation of connect.  In order to accomodate the instance being an
# optionalish thing, this will accept flags instead of an instance and DTRT.
#
sub connect {
	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		$dbh = do_database_connect(@_);
	} else {
		my $app      = shift;
		my $instance = shift;
		my $flags    = shift;
		my $user     = shift;
		my $override = shift;

		if ( ref($instance) ) {
			$dbh = do_database_connect(
				application => $app,
				dbiflags    => $instance,
				appuser     => $flags
			);
		} elsif ( $flags && !ref($flags) ) {
			$dbh = do_database_connect(
				application => $app,
				instance    => $instance,
				appuser     => $flags
			);
		} else {
			$dbh = do_database_connect(
				application => $app,
				instance    => $instance,
				dbiflags    => $flags,
				appuser     => $user,
				override    => $override
			);
		}
	}
	if ( ref($self) ) {
		$self->{_DBHandle} = $dbh;
	}
	$dbh;
}

sub connect_cached {
	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		$dbh = do_database_connect( @_, cached => 1 );
	} else {
		my $app      = shift;
		my $instance = shift;
		my $flags    = shift;
		my $user     = shift;
		my $override = shift;

		if ( ref($instance) ) {
			$dbh = do_database_connect(
				application => $app,
				dbiflags    => $instance,
				appuser     => $flags,
				cached      => 1
			);
		} elsif ( $flags && !ref($flags) ) {
			$dbh = do_database_connect(
				application => $app,
				instance    => $instance,
				appuser     => $flags,
				cached      => 1
			);
		} else {
			$dbh = do_database_connect(
				application => $app,
				instance    => $instance,
				dbiflags    => $flags,
				appuser     => $user,
				override    => $override,
				cached      => 1
			);
		}
	}
	if ( ref($self) ) {
		$self->{_DBHandle} = $dbh;
	}
	$dbh;
}

#
# override almost certainly needs to go away.
#
sub build_and_connect($$) {
	my ( $opt, $auth ) = @_;

	my $errors   = $opt->{dbiflags};
	my $dbiflags = $opt->{dbiflags};
	my $override = $opt->{override};
	my $app      = $opt->{application};
	my $dbdmap   = $opt->{_dbdmap};

	my ( $user, $pass );

	my $dbtype = $auth->{'DBType'};
	if ( !$dbtype ) {
		$errstr = "dbtype not defined";
		return undef;
	}
	$dbtype =~ tr/A-Z/a-z/;

	# XXX - revisit how to make sure this is ok.
	if ( !defined( $auth->{'DBType'} ) ) {
		$errstr = "No DBType specified for app $app";
		SetError( $errors, $errstr );
		return undef;
	}

	my $dbd = $dbdmap->{$dbtype}->{_DBD};

	if ( !defined($dbd) ) {
		$errstr = "Unable to map $dbtype to a DBD Module.  Sorry";
		SetError( $errors, $errstr );
		return undef;
	}

	my @vals;
	foreach my $k ( keys( %{$auth} ) ) {
		if ( $k eq 'Username' ) {
			$user = $auth->{'Username'};
		} elsif ( $k eq 'Password' ) {
			$pass = $auth->{'Password'};
		} else {
			next if ( !exists( $dbdmap->{$dbtype}->{$k} ) );
			my $pk = $dbdmap->{$dbtype}->{$k};
			my $v;
			if ( ref $override and $override->{$k} ) {
				$v = $override->{$k};
			} else {
				$v = $auth->{$k};
			}
			push( @vals, "$pk=$v" );
		}
	}
	my $dbstr = "dbi:${dbd}:" . join( ";", sort @vals );
	my $dbh;

	my $print_error = $dbiflags && exists($dbiflags->{PrintError}) && $dbiflags->{PrintError};

	$dbiflags ||= {};
	$dbiflags->{PrintError} = 0;

	if ( $opt->{cached} ) {
		$dbh = DBI->connect_cached( $dbstr, $user, $pass, $dbiflags );
	} else {
		$dbh = DBI->connect( $dbstr, $user, $pass, $dbiflags );
	}

	$dbh->{PrintError} = $print_error if $dbh;

	return $dbh;
}

sub do_database_connect {
	my $opt    = &_options(@_);
	my $errors = $opt->{errors};
	my ( $app, $instance, $dude, );
	if ( !( $app = $opt->{application} ) ) {
		$errstr = "Application not given";
		SetError( $errors, $errstr );
		return undef;
	}
	$instance = $opt->{instance};
	$dude     = $opt->{appuser};

	# Mapping from what the db is called to how to set parameters
	# parameter names preceeded by an r: are required, everything else is
	# optional.  NOTE:  Have not implemented anything required yet.
	#
	# Most of these have not yet been tested.
	#
	# Note: SSL mode, Compress, etc needs to be normalized.
	#
	my $dbdmap = {
		'oracle' => {
			'_DBD' => 'Oracle'
		},
		'postgresql' => {
			'_DBD'    => 'Pg',
			'DBName'  => 'dbname',
			'DBHost'  => 'host',
			'DBPort'  => 'port',
			'Options' => 'options',
			'Service' => 'service',
			'SSLMode' => 'sslmode',
		},
		'mysql' => {
			'_DBD'           => 'mysql',
			'DBName'         => 'database',
			'DBHost'         => 'host',
			'DBPort'         => 'port',
			'Compress'       => 'mysql_compression',
			'ConnectTimeout' => 'mysql_connect_timeout',
			'SSLMode'        => 'mysql_ssl',
		},
		'odbc' => {
                        '_DBD'     => 'ODBC',
                        'DSN'      => 'dsn',
			'DBName'   => 'database',
			'DBDriver' => 'driver',
			'DBHost'   => 'server',
			'DBPort'   => 'port',
			'SSLMode'  => 'sslmode',
		},
		'tds' => {
			'_DBD' => 'Sybase'
		},
		'sqlite' => {
			'_DBD'      => 'SQLite',
			'DBName'    => 'dbname',
			'_fileonly' => 'yes',
		},
	};

	my $record = JazzHands::AppAuthAL::find_and_parse_auth( $app, $instance );
	if ( !$record ) {
		$errstr = "Unable to find auth entry for " . $app;
		SetError( $errors, $errstr );
		return undef;
	}
	my $autharray = $record->{database};
	if ( ref($autharray) ne 'ARRAY' ) {
		$autharray = [$autharray];
	}

	#
	# Return the first one that works.
	#
	# [XXX] Probably want a global config that indiciates if it should
	# indicate what entries it should skip (incomplete?  fail to connect?
	# other failure modes?)
	#
	my $dbh;
	foreach my $auth ( @{$autharray} ) {
		#
		# This is kind of convoluted.  For some types, such as sqlite,
		# there is not a username/password, thus there is no auth type.
		# in That case, just skip the whole figuring out the username/
		# password thing and it's ok if it's not there.
		#
		# DBType is only set if we're not redirecting off to another
		# auth engine, such as vault.
		#
		my $fileonly;
		if ( exists( $auth->{DBType} ) ) {
			my $dbtype = $auth->{DBType};

			if ( defined( $record->{$dbtype}->{_fileonly} )
				&& $dbdmap->{$dbtype}->{_fileonly} eq 'yes' )
			{
				delete $dbdmap->{$dbtype}->{_fileonly};
				$fileonly = 'yes';
			}

		}

		#
		# used by the callback to figure out how to sign in.
		$opt->{_dbdmap} = $dbdmap;

		#
		# simple case of just connecting without a username/pasword, so
		# ignore all the more advanced connection mechanisms
		#
		if ($fileonly) {
			$dbh = build_and_connect( $opt, $auth );
			last if ($dbh);
			next;
		}

		my $cached_args = {
			options  => $record->{options},
			errors   => $errors,
			errors   => $errors,
		};

		$dbh =
		  do_cached_login( $cached_args, $auth, \&build_and_connect, $opt );
		last if ($dbh);

	}

	if ($dbh) {
		optional_set_session_user( $dbh, $record->{'options'}, $dude );
		return $dbh;
	}

	$errstr = $DBI::errstr if ( !$errstr );
	SetError( $errors, $errstr );
	return undef;
}

1;
