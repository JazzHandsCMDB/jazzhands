#
# Copyright (c) 2011, Todd M. Kover
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
# $Id: DBI.pm 99 2012-03-09 01:35:38Z kovert $
#


=head1 NAME

JazzHands::DBI - database authentication abstraction for Perl

=head1 SYNOPSIS

use JazzHands::DBI;
my $dbh = JazzHands::DBI->connect($app, [ $instance, ] [ $flags ], [$user]);

Instance and flags are optional, but if you want to set user, you need to pass
an undef for instance.

DBI::set_session_user($dbh, $user)

Sets the session user based on what is appropriate for the underlying database

=head1 DESCRIPTION

I totally need to write this.

=head1 CONFIGURATION FILE

The global configuration file (defaults to /etc/jazzhands/appauth.json) can
be used to define system wide defaults.  It is optional.

=head1 FILES

/etc/jazzhands/appauth.json - configuration file
/var/lib/jazzhands/appauth-info - Default Location for Auth Files

=head1 ENVIRONMENT

The APPAUTHAL_CONFIG config can be set to a pathname to a json configuration
file that will be used instead of the optional global config file.  If this
variable is set, the config file becomes required.


=head1 AUTHORS

Todd Kover (kovert@omniscient.com)

=cut

package JazzHands::DBI;

use strict;
use warnings;
use Exporter;
use DBI;
use FileHandle;
use Data::Dumper;
use JazzHands::AppAuthAL;

use vars qw(@EXPORT_OK @ISA $VERSION);

$VERSION = '0.51';

@ISA       = qw(DBI Exporter);
@EXPORT_OK = qw(do_database_connect set_session_user);

my $appauth_config = $JazzHands::AppAuthAL::appauth_config;

our $errstr = "";

#
# our implemenation of DBI::connect.
#
# We provide no defaults, but the underlying DBD module may provide something.
#
sub do_database_connect {
	my $app = shift;
	my $instance = shift;
	my $dbiflags = shift;
	my $dude = shift;
	my $override = shift;

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
					'_DBD' => 'Pg',
					'DBName' => 'dbname',
					'DBHost' => 'host',
					'DBPort' => 'port',
					'Options' => 'options',
					'Service' => 'service',
					'SSLMode' => 'sslmode',
			},
		'mysql' => {
					'_DBD' => 'mysql',
					'DBName' => 'database',
					'DBHost' => 'host',
					'DBPort' => 'port',
					'Compress' => 'mysql_compression',
					'ConnectTimeout' => 'mysql_connect_timeout',
					'SSLMode' => 'mysql_ssl',
			},
		'tds' => {
					'_DBD' => 'Sybase'
		},
		'sqlite' => {
					'_DBD' => 'SQLite',
					'DBName' => 'dbname',
					'_fileonly' => 'yes',
		},
	};


	my $record = JazzHands::AppAuthAL::find_and_parse_auth($app, $instance);
	if(!$record) {
		$errstr = "Unable to find entry";
		return undef;
	}
	my $autharray = $record->{database};
	#
	# Return the first one that works.
	#
	# [XXX] Probably want a global config that indiciates if it should 
	# indicate what entries it should skip (incomplete?  fail to connect?
	# other failure modes?)
	#
	foreach my $auth (@{$autharray}) {
		if(!defined($auth))  {
			$errstr = "Unable to find app $app".
				(($instance)?" $instance":"");
			next;
		}
		if(!defined($auth->{'DBType'})) {
			$errstr = "No DBType specified for app $app";
			next;
		}

		#
		# only support Password at the moment
		#
		my($user,$pass);
	
		my $dbtype = $auth->{'DBType'};
		$dbtype =~ tr/A-Z/a-z/;
	
		my $dbd = $dbdmap->{$dbtype}->{_DBD};
	
		if(!defined($dbd)) {
			$errstr = "Unable to map $dbtype to a DBD Module.  Sorry";
			next;
		}
	
		my $fileonly;
		if(defined($dbdmap->{$dbtype}->{_fileonly}) &&
			$dbdmap->{$dbtype}->{_fileonly} eq 'yes') {
			delete $dbdmap->{$dbtype}->{_fileonly};
			$fileonly = 'yes';
		} else {
			if(!defined($auth->{'Method'})) {
				$errstr = "No method defined for app $app";
				next;
			}
		}
	
		my @vals;
		foreach my $k (keys(% {$auth} )) {
			if($k eq 'Username') {
				$user = $auth->{'Username'};
			} elsif($k eq 'Password') {
				$pass = $auth->{'Password'};
			} else {
				next if(!exists($dbdmap->{$dbtype}->{$k}));
				my $pk = $dbdmap->{$dbtype}->{$k};
				my $v;
				if(ref $override and $override->{$k}){
					$v = $override->{ $k }
				} else {
					$v = $auth->{ $k } 
				}
				push(@vals, "$pk=$v");
			}
		}
	
		if(!$fileonly && lc($auth->{'Method'}) ne 'password') {
			$errstr = "Only password method supported for app $app";
			next;
		}
	
		my $dbstr = "dbi:${dbd}:". join(";", @vals);
		my $dbh = DBI->connect($dbstr, $user, $pass, $dbiflags);
		$errstr = $DBI::errstr;
		if($dbh) {
			return optional_set_session_user($dbh, $record->{'options'}, $dude);
		}
	}
	return undef;
}

sub optional_set_session_user {
	my($dbh, $options, $dude) = @_;

	return $dbh if(!$dbh);

	my $doit = 0;
	if($options && $options->{'use_session_variables'}) {
		if($options->{'use_session_variables'} =~ /^y(es)?$/i) {
			$doit = 1;
		}
	}
	if(!$doit) {
		if(!defined($appauth_config->{'use_session_variables'})) {
			return $dbh;
		}

		if($appauth_config->{'use_session_variables'} =~ /^n(o)?$/i) {
			return $dbh;
		}
		$doit = 1;
	}

	return $dbh if(!$doit);

	# If here is reached, then it means session variables are on.  The
	# default is to not use them.

	if(! defined($dude)) {
		$dude = ( getpwuid($<) )[0] || 'unknown';
	}
	return set_session_user($dbh, $dude);
}

sub set_session_user {
	my($dbh, $dude) = @_;

	# XXX oracle untested
	if($dbh->{Driver}->{Name} eq 'oracle') {
		$dbh->do(qq{
			begin
				dbms_session.set_identifier ('$dude');
			end;
		});	# XXX not fatal?
	} elsif($dbh->{Driver}->{Name} eq 'Pg') {
		$dbh->do(qq{
				set jazzhands.appuser to '$dude';
		}); # XXX not fatal?
	} else {
		# unable to do it for this type, so silently let through.
	}
	$dbh;
}

#
# Our implementation of connect.  In order to accomadate the instance being an
# optionalish thing, this will accept flags instead of an instance and DTRT.
#
sub connect {
	my $class = shift;
	my $app = shift;
	my $instance = shift;
	my $flags = shift;
	my $user = shift;
	my $override = shift;

	my $dbh;
	if(ref($instance)) {
		$dbh = do_database_connect($app, undef, $instance, $flags);
	} elsif($flags && !ref($flags)) {
		$dbh = do_database_connect($app, $instance, undef, $flags);
	} else {
		$dbh = do_database_connect($app, $instance, $flags, $user, $override);
	}
	$dbh;
}

1;
