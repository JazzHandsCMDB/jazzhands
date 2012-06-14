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
# $Id$
#


=head1 NAME

JazzHands::AppAuthAL - generic auth abstraction layer routines used by:

=head1 SYNOPSIS

use JazzHands::DBI;
my $dbh = JazzHands::DBI->connect($app, [ $instance, ] [ $flags ]);

=head1 DESCRIPTION

I totally need to write this.

=head1 CONFIGURATION FILE

The global configuration file (defaults to /etc/

=head1 FILES

/etc/jazzhands/appauth.json - configuration file
/var/lib/jazzhands/appauth-info - Default Location for Auth Files

=head1 ENVIRONMENT

The APPAUTHAL_CONFIG config can be set to a pathname to a json configuration
file that will be used instead of the optional global config file.  Setting
this variable, the config file becomes required.


=head1 AUTHORS

Todd Kover (kovert@omniscient.com)

=cut

package JazzHands::AppAuthAL;

use strict;
use warnings;

use FileHandle;
use JSON::PP;
use Data::Dumper;

our $VERSION = '0.10';

#
# places where the auth files may live
#
our (@searchdirs);

# Parsed JSON config
our $appauth_config;

our $errstr = "";

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
		$fn = "/etc/jazzhands/appauth-config.json";
	}
	if(-r $fn) {
		my $fh = new FileHandle($fn) || die "$fn: $!\n";
		my $json = join("", $fh->getlines);
		$fh->close;
		$appauth_config = decode_json($json) || die "Unable to parse config file";
		if(exists($appauth_config->{'onload'})) {
			if(defined($appauth_config->{'onload'}->{'environment'})) {
				foreach my $e (@{$appauth_config->{'onload'}->{'environment'}}) {
					foreach my $k (keys %$e) {
						$ENV{'$k'} = $e->{$k};
					}
				}
			}
		}
		my $dirname = $fn;
		$dirname =~ s,/[^/]+$,,;
		if(exists($appauth_config->{'search_dirs'})) {
			foreach my $d (@{$appauth_config->{'search_dirs'}}) {
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
		push(@searchdirs, "/var/lib/jazzhands/appauth-info");
	}
}

#
# Parse a JSON file and return the variable/value pairs to be used by other
# operations
#
sub parse_json_auth {
	my $fn = shift;
	my $section = shift;

	my $fh = new FileHandle($fn) || die "$fn: $!\n";
	my $json = join("", $fh->getlines);
	$fh->close;
	my $thing = decode_json($json) || die "Unable to parse config file";
	if($section and $thing->{$section}) {
		return $thing->{$section};
	} else { return $thing } 
	undef;
}

#
# Find an authfile on the search paths and return the procssed version
#
sub find_and_parse_auth {
	my $app = shift @_;
	my $instance = shift @_;
	my $section = shift @_;

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
				return(parse_json_auth("$d/$app.$instance/json", $section));
			}
		}

		if(defined($appauth_config->{'sloppy_instance_match'}) &&
			$appauth_config->{'sloppy_instance_match'} =~ /^n(o)?$/i) {
				return undef;
		}
	}

	foreach my $d (@searchdirs) {
		if(-f "$d/$app.json") {
			return(parse_json_auth("$d/$app.json", $section));
		} elsif(-f "$d/$app") {
			return(parse_json_auth("$d/$app", $section));
		}
	}

	undef;
}

1;
