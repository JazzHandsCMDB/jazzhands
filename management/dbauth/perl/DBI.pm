#
# Copyright (c) 2011, Todd M. Kover
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
# $Id$
#


=head1 NAME

JazzHands::DBI - database authentication abstraction for Perl

=head1 SYNOPSIS

use JazzHands::DBI;
my $dbh = JazzHands::DBI->connect($app, [ $instance, ] [ $flags ]);

=head1 DESCRIPTION

I totally need to write this.

=head1 CONFIGURATION FILE

The gloabl configuration file (defaults to /etc/

=head1 FILES

/etc/jazzhands/dbauth.json - configuration file
/var/lib/jazzhands/dbauth-info - Default Location for Auth Files

=head1 ENVIRONMENT

The APPAUTHAL_CONFIG config can be set to a pathname to a json configuration
file that will be used instead of the optional global config file.  Setting
this variable, the config file becomes required.


=head1 AUTHORS

Todd Kover (kovert@omniscient.com)

=cut

package JazzHands::DBI;

use strict;
use warnings;
use Exporter;
use DBI;
use FileHandle;
use JSON::PP;
use Data::Dumper;
use vars qw(@EXPORT_OK @ISA $VERSION $db_config);

$VERSION = '$Revision$';

@ISA       = qw(DBI Exporter);
@EXPORT_OK = qw(do_database_connect);


#
# places where the auth files may live
#
our (@searchdirs);

# Parsed JSON config
our $dbi_config;

our $errstr;

#
# If the environment variable is set, require it, otherwise use an optional
# config file
#
BEGIN {
	my $fn;
	if(defined($ENV{'APPAUTHAl_CONFIG'})) {
		$fn = $ENV{'APPAUTHAL_CONFIG'};
	}
	if(defined($fn)) { 
		if(! -r $fn) {
			die "$fn is unreadable or nonexistance.\n";
		}
	} else {
		$fn = "/etc/jazzhands/dbauth.json";
	}
	if(-r $fn) {
		my $fh = new FileHandle($fn) || die "$fn: $!\n";
		my $json = join("", $fh->getlines);
		$fh->close;
		$dbi_config = decode_json($json) || die "Unable to parse config file";
		if(exists($dbi_config->{'onload'})) {
			if(defined($dbi_config->{'onload'}->{'environment'})) {
				foreach my $e (@{$dbi_config->{'onload'}->{'environment'}}) {
					foreach my $k (keys %$e) {
						$ENV{'$k'} = $e->{$k};
					}
				}
			}
		}
		my $dirname = $fn;
		$dirname =~ s,/[^/]+$,,;
		if(exists($dbi_config->{'search_dirs'})) {
			foreach my $d (@{$dbi_config->{'search_dirs'}}) {
				#
				# Translate . by itself to the directory that the file is
				# in.  If someone actually wants the current directory, use ./
				if($d eq '.') {
					push(@searchdirs, $dirname);
				} else {
					push(@searchdirs, $d);
				}
			}
		}
	}

	if($#searchdirs < 0) {
		push(@searchdirs, "/var/lib/jazzhands/dbauth-info");
	}
}

#
# Parse a JSON file and return the variable/value pairs to be used by other
# operations
#
sub parse_json_auth {
	my $fn = shift;

	my $fh = new FileHandle($fn) || die "$fn: $!\n";
	my $json = join("", $fh->getlines);
	$fh->close;
	my $thing = decode_json($json) || die "Unable to parse config file";
	if($thing->{'database'}) {
		return $thing->{'database'};
	}
	undef;
}

#
# Find an authfile on the search paths and return the procssed version
#
sub find_and_parse_auth {
	my $app = shift @_;
	my $instance = shift @_;

	#
	# This implementation only supports json, but others may want something
	# in XML, plantext or something else.
	#
	#
	# If instance is set, then look for $d/$app/$instance.json.  if that is
	# not there, check to see if sloppy_instance_match is set to no, in which
	# case don't check for a non-instance version.
	#
	if($instance) {
		foreach my $d (@searchdirs) {
			if(-f "$d/$app/$instance.json") {
				return(parse_json_auth("$d/$app.$instance/json"));
			}
		}

		if(defined($dbi_config->{'sloppy_instance_match'}) &&
			$dbi_config->{'sloppy_instance_match'} =~ /^n(o)?$/i) {
				return undef;
		}
	}

	foreach my $d (@searchdirs) {
		if(-f "$d/$app.json") {
			return(parse_json_auth("$d/$app.json"));
		} elsif(-f "$d/$app") {
			return(parse_json_auth("$d/$app"));
		}
	}

	undef;
}

#
# our implemenation of DBI::connect.
#
# We provide no defaults, but the underlying DBD module may provide something.
#
sub do_database_connect {
	my $app = shift;
	my $instance = shift;
	my $dbiflags = shift;

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

	my $autharray = find_and_parse_auth($app, $instance);

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
				my $v = $auth->{$k};
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
			return $dbh;
		}
	}
	return undef;
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

	if(ref($instance)) {
		return do_database_connect($app, undef, $instance);
	} else {
		return do_database_connect($app, $instance, $flags);
	}
}

1;
