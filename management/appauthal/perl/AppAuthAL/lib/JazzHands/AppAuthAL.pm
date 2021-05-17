#
# Copyright (c) 2011-2019, Todd M. Kover
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

JazzHands::AppAuthAL - generic auth abstraction layer routines used by:

=head1 SYNOPSIS

You probably don't want to run this.

=head1 DESCRIPTION

This module is not meant to be directly used by mortals; it is meant to
provide support functions for other libraries that depend on it.

Files are looked for based on F</var/lib/jazzhands/appauth-info> or the
APPAUTHAL_CONFIG environment variable's config file.  Under that directory,
the library looks for app.json, and if there is an instance involved looks
under app/instance.json and may fall backt to app.json based on
sloppy_instance_match.

The library also implements caching via a generic sign in module, and
will cache credentials under F</run/user/uid> or in a directory under
F</tmp>.  If the running user does not own that directory and it's not
other readable, it will not be used.

This caching is done by the do_cached_login call.  It is possible to
completely disable Caching but setting Caching to false in the general options
of agiven appauthaal file.    The default amount of time to cache a
record is set to 86400 seconds, but can be changed via DefaultCacheExpiration
in the options field.  If the underlying engine (such as vault) includes
a lifetime for a credential, it is cached, by default, for half that time.
The DefaultCacheDivisor option can be used to change that divisor.  There
is no way to override that value, just manipulate it.

=head1 APPAUTH files

The file has a hash of many top level stanzas, interpreted by various
AppAuthLayer consumers.  options is generic across all libraries although
may have some module-specific options.  database is used for DBI.

AN example of one:

  {
	"options": {
		"Caching": true,
		"use_session_variables": "yes"
	},
	"database": {
		"DBType": "postgresql",
		"Method": "password",
		"DBHost": "jazzhands-db.example.com",
		"DBName": "jazzhands",
		"Username": "app_stab",
		"Password": "thisisabadpassword"
	}
  }


=head1 CONFIGURATION FILE

The global configuration file (defaults to /etc/jazzhands/appauth.json) can
be used to define system wide defaults.  It is optional.

The config file format is JSON.  Here is an example:

   {
	"onload": {
		"environment": [
			{
				"ORACLE_HOME": "/usr/local/oracle/libs"
			}
		]
	},
	"search_dirs": [
		".",
		"/var/lib/appauthal"
	],
	"sloppy_instance_match": "yes",
	"use_session_variables": "yes"
   }

The "onload" describes things that happen during the importing of the
AppAuthAL library and are used to setup things that other libraries may
require.  In this case, environment variables required by Oracle.

The search_dirs parameter is used to search for auth files, and defaults to
/var/lib/jazzhands/appauth-info .  It will iterate through listed directories
until it finds a match.  Note that "." means the directory the config file
appears in rather than a literal ".".  This is typically used to stash all
the development connection information in one directory with the config file.

sloppy_instance_match tells the library to use the non-instance version of
files if there is no instance match.

use_session_variables tells the library to try to use session variables
in underlying libraries to set usernames, if this is available.  This is
generally a JazzHands-specific thing for databases, but may work in other
instances.

=head1 FILES

F</etc/jazzhands/appauth.json> - configuration file
F</var/lib/jazzhands/appauth-info> - Default Location for Auth Files

=head1 ENVIRONMENT

The APPAUTHAL_CONFIG config can be set to a pathname to a json configuration
file that will be used instead of the optional global config file.  Setting
this variable, the config file becomes required.


=head1 AUTHORS

Todd Kover (kovert@omniscient.com)

=cut

package JazzHands::AppAuthAL;

# optional
# use JazzHands::Vault;
eval "require JazzHands::Vault";


use strict;
use warnings;

use FileHandle;
use File::Temp qw(tempfile);
use JSON::PP;
use JazzHands::Common qw(:internal);
use Data::Dumper;
use Fcntl "S_IRWXO";
use Storable qw(dclone);

use parent 'JazzHands::Common';

use Exporter 'import';

our $VERSION = '0.86';

our @ISA = qw(Exporter );

# throughout all the JazzHands::Common family.
our @EXPORT_OK =
  qw(parse_json_auth find_and_parse_auth get_cached_auth save_cached do_cached_login);

our %EXPORT_TAGS = (
	'parse' => [qw(parse_json_auth find_and_parse_auth)],
	'cache' => [qw(do_cached_login get_cached_auth save_cached)],
);

#
# places where the auth files may live
#
our (@searchdirs);

# Parsed JSON config
our $appauth_config;

#
# If the environment variable is set, require it, otherwise use an optional
# config file
#
BEGIN {
	my $fn;
	if ( defined( $ENV{'APPAUTHAL_CONFIG'} ) ) {
		$fn = $ENV{'APPAUTHAL_CONFIG'};
	}
	if ( defined($fn) ) {
		if ( !-r $fn ) {
			die "$fn is unreadable or nonexistance.\n";
		}
	} else {
		$fn = "/etc/jazzhands/appauth-config.json";
	}
	if ( -r $fn ) {
		my $fh   = new FileHandle($fn) || die "$fn: $!\n";
		my $json = join( "", $fh->getlines );
		$fh->close;
		$appauth_config = decode_json($json)
                    || die "Unable to parse config file";
		if ( exists( $appauth_config->{'onload'} ) ) {
			if ( defined( $appauth_config->{'onload'}->{'environment'} ) ) {
				my $e = $appauth_config->{'onload'}->{'environment'};
				foreach my $k ( %$e ) {
					$ENV{$k} = $e->{$k};
				}
			}
		}
		my $dirname = $fn;
		$dirname =~ s,/[^/]+$,,;
		if ( exists( $appauth_config->{'search_dirs'} ) ) {
			foreach my $d ( @{ $appauth_config->{'search_dirs'} } ) {
				#
				# Translate . by itself to the directory that the file is
				# in.  If someone actually wants the current directory, use ./
				if ( $d eq '.' ) {
					push( @searchdirs, $dirname );
				} else {
					push( @searchdirs, $d );
				}
			}
		}
	}

	if ( $#searchdirs < 0 ) {
		push( @searchdirs, "/var/lib/jazzhands/appauth-info" );
	}
}

#
# Parse a JSON file and return the variable/value pairs to be used by other
# operations
#
sub parse_json_auth {
	my $fn      = shift;
	my $section = shift;

	my $fh = new FileHandle($fn);
	if ( !$fh ) {
		$errstr = "$fn: $!";
		return undef;
	}
	my $json = join( "", $fh->getlines );
	$fh->close;
	my $thing = decode_json($json);
	if ( !$thing ) {
		$errstr = "Unable to parse $fn; likely invalid json";
		return undef;
	}
	if ( $section and $thing->{$section} ) {
		return $thing->{$section};
	} else {
		return $thing;
	}
	{};
}

#
# Find an authfile on the search paths and return the procssed version
#
sub find_and_parse_auth {
	my $app      = shift @_;
	my $instance = shift @_;
	my $section  = shift @_;

	#
	# This implementation only supports json, but others may want something
	# in XML, plantext or something else.
	#
	#
	# If instance is set, then look for $d/$app/$instance.json.  if that is
	# not there, check to see if sloppy_instance_match is set to no, in which
	# case don't check for a non-instance version.
	#
	if ($instance) {
		foreach my $d (@searchdirs) {
			if ( -f "$d/$app/$instance.json" ) {
				return (
					parse_json_auth( "$d/$app.$instance/json", $section ) );
			}
		}

		if ( defined( $appauth_config->{'sloppy_instance_match'} )
			&& $appauth_config->{'sloppy_instance_match'} =~ /^n(o)?$/i )
		{
			return {};
		}
	}

	foreach my $d (@searchdirs) {
		if ( -f "$d/$app.json" ) {
			return ( parse_json_auth( "$d/$app.json", $section ) );
		} elsif ( -f "$d/$app" ) {
			return ( parse_json_auth( "$d/$app", $section ) );
		}
	}

	undef;
}

sub build_key($) {
	my ($auth) = @_;

	my $key;
	if (   exists( $auth->{VaultRoleId} )
		&& exists( $auth->{VaultServer} )
		&& exists( $auth->{VaultPath} ) )
	{
		$key = sprintf "%s@%s/%s", $auth->{VaultServer}, $auth->{VaultRoleId},
		  $auth->{VaultPath};
		$key =~ s,[/:],_,g;
	}

	return $key;
}

sub get_cachedir() {
        my $cachedir;
        if ( -d "/run/user/$<" ) {
                $cachedir = "/run/user/$</jazzhands-dbi-cache";
                mkdir( $cachedir, 0700 );
        } else {
                my $c = "/tmp/__jazzhands-appauthal-cache__-$<";
                if ( !-d $c ) {
                        mkdir( $c, 0700 );
                }
                if ( -d $c ) {
                        $cachedir = $c;
                }
        }

	my ($uid,$mode) = (lstat($cachedir))[4,2];
	return undef if(-l _);
	return undef if($uid != $<);

	return if($mode & S_IRWXO);
	$cachedir;
}

sub _assemble_cache($$) {
	my ($options, $tocache) = @_;

	my $defexpire = 86400;
	if (   $options
		&& exists( $options->{'DefaultCacheExpiration'} )
		&& defined( $options->{'DefaultCacheExpiration'} ) )
	{
		$defexpire = $options->{'DefaultCacheExpiration'};
	}

	my $expire = time() + $defexpire;
	if ( exists( $tocache->{'__Expiration'} ) ) {
		my $defdivisor = 2;
		if (   $options
			&& exists( $options->{'DefaultCacheDivisor'} )
			&& defined( $options->{'DefaultCacheDivisor'} ) )
		{
			$defdivisor = $options->{'DefaultCacheDivisor'};
		}
		$expire = time() + $tocache->{'__Expiration'} / $defdivisor;
		delete( $tocache->{'__Expiration'} );
	}

	my $cache = {
		expired_whence => $expire,
		auth           => $tocache
	};

	return $cache;
}

sub save_cached($$$) {
	my ( $options, $auth, $tocache ) = @_;

	my $key	      = build_key($auth) || return undef;
	my $cachedir  = get_cachedir()	 || return undef;
	my $cachepath = "$cachedir/$key";

	my ( $fh, $tmpfname );

	eval {
		( $fh, $tmpfname ) = tempfile('tmpXXXXXX', DIR => $cachedir );
	};

	if ($@) {
		$errstr = "WriteCache: " . $@;
		return undef;
	}

	my $cache = _assemble_cache($options, $tocache);
	my $json  = new JSON::PP;
	my $o	  = $json->encode($cache);

	$fh->print( $o, "\n" );
	$fh->close;

	unless ( rename($tmpfname, $cachepath) ) {
		$errstr = "WriteCache: " . $!;
		return undef;
	}

	chmod( 0500, $cachepath );

	return $auth;
}

sub get_cached_auth($) {
	my ( $auth ) = @_;

	my $key = build_key($auth);
	return undef if ( !$key );

	my $cachedir = get_cachedir() || return undef;
	my $cachedauth;
	my $fn = "$cachedir/$key";
	if ( my $fh = new FileHandle($fn) ) {
		my $f     = join( "\n", $fh->getlines() );
		my $json  = new JSON::PP;
		my $cache = $json->decode($f);
		$fh->close();

		return undef
		  if (!$cache->{expired_whence}
			|| $cache->{expired_whence} !~ /^\d+$/ );

		return undef if ( !$cache->{auth} );
		#
		# indicate expiration if everything is not in order
		#
		if ( $cache->{expired_whence} > time() ) {
			$cache->{auth}->{expired} = undef;
		} else {
			$cache->{auth}->{expired} = 1;
		}
		$cachedauth = $cache->{auth};
	}

	$cachedauth;
}

sub _is_caching_enabled($) {
	my $options = shift;

	if ( exists $options->{Caching} ) {
		my $c = $options->{Caching};

		return 0 if ( grep { lc($c) eq $_ } qw(no n 0) );
		return 1 if ( grep { lc($c) eq $_ } qw(yes y 1) );
	}

	return 1;
}

sub _diff_cache($$) {
	my ( $old, $new_cache ) = @_;

	return 1 unless ($old);

	my $old_cache = dclone($old);
	
	return 1 if ( delete $old_cache->{expired} );
	return 1 if ( keys(%$old_cache) != keys(%$new_cache) );

	my %cmp = map { $_ => 1 } keys %$old_cache;

	for my $key (keys %$new_cache) {
		last unless exists $cmp{$key};
		last unless $old_cache->{$key} eq $new_cache->{$key};
		delete $cmp{$key};
	}

	return 1 if (%cmp);

	return 0;
}

#
# Returns a handle to whatever, intellegently tries cached logins, including
# properly handle expiration.  Tries super hard to get signed in and cache
# credentials if appropriate..
#
# Takes four arguments:
#
# $opt		- parameters to this function (pulled out in beginning)
# $auth		- dbauth input entry
# $callback - function taht does the auth and returns a handle
#				callback is passed two functions, an appauthal entry
#				derived from $auth as needed and the next argument
# $args - args that are passed to the function
#

sub do_cached_login($$$$) {
	my $opt      = shift @_;
	my $auth     = shift @_;
	my $callback = shift @_;
	my $args     = shift @_;

	#
	# routines to pass.  Note that the vault options probably want to be
	# passed in via the options->{vault} section
	#
	my $errors   = $opt->{errors};      # JazzHands::Common::Errors
	my $options  = $opt->{options};     # appauthal file options section

	# conn to return
	my $conn;

	if ( !defined($auth) ) {
		$errstr = "Unable to find auth entry";
		SetError( $errors, $errstr );
		return undef;
	}

	if ( $auth->{'Method'} eq 'password' ) {
		$conn = &$callback( $args, $auth );
		return $conn;
	} elsif ( $auth->{'Method'} eq 'odbc' ) {
		$conn = &$callback( $args, $auth );
		return $conn;
	} elsif ( $auth->{'Method'} ne 'vault' ) {
		$errstr = "Only password and vault methods supported";
		SetError( $errors, $errstr );
		return undef;
	}

	if ( !defined($JazzHands::Vault::VERSION) ) {
		$errstr = "Vault module not loaded.";
		SetError( $errors, $errstr );
		return undef;
	}

	#
	# fill in all the bits that may be missing from the array of entries
	# to try.
	#
	if ( defined($options) && exists($options->{vault} ) ) {
		my $vaultbase = $options->{vault};

		foreach my $key ( keys %{$vaultbase} ) {
			if ( !exists( $auth->{$key} ) ) {
				$auth->{$key} = $vaultbase->{$key};
			}
		}
	}

	#
	# At this point, $auth contains everything needed to talk to vault,
	# or cache, and get the bits.  When it returns depends on stuf.
	#

	# 1 fetch catched creds
	# 2 if success unexpired, try those
	# 3 if sucesssful conn, return
	# 4 get new credentials from Vault
	# 5 if new ones, try them
	# 6 if cached ones success, and caches diff, save in cache, return
	# 7 if new ones fail and cached exist, try
	# 8 if cached ones suceeded, return
	# 9 if cached ones failed, return failure
	#
	#

	#
	# get cached creds.  If they are expired, attempt to get
	# new ones.  We'll figure out which to use later.
	#
	# step 1
	my $cached;

	if ( _is_caching_enabled($options) ) {
		$cached = get_cached_auth( $auth );

		# step 2, 3
		if ( $cached && !$cached->{expired} ) {
			if ( $conn = &$callback( $args, $cached ) ) {
				return $conn;
			}
		}
	}

	# step 4
	my $newauth;
	my $v = new JazzHands::Vault( appauthal => $auth );
	if ( !$v ) {
		SetError( $errors, $JazzHands::Vault::errstr );
		return undef;
	}
	$newauth = $v->fetch_and_merge_dbauth($auth);

	# 5 if new ones, try them
	# 6 if cached ones success, and caches diff, save in cache, return
	if ($newauth) {
		if ( $conn = &$callback( $args, $newauth ) ) {
			my $new_cache = _assemble_cache( $options, $newauth );
			
			if ( _diff_cache( $cached, $new_cache->{'auth'} ) ) {
				save_cached( $options, $auth, $newauth );
			}
			return $conn;
		}
	}

	# 7 if new ones fail and cached exist, try
	# 8 if cached ones suceeded, return
	if ($cached) {
		if ( $conn = &$callback( $args, $cached ) ) {
			return $conn;
		}
	}

	# 9 if cached ones failed, return failure
}

1;
