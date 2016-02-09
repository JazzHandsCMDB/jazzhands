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

BEGIN {
	my $dir = $0;
	if ( $dir =~ m,/, ) {
		$dir =~ s!^(.+)/[^/]+$!$1!;
	} else {
		$dir = ".";
	}

	#
	# Copy all of the entries in @INC, and prepend the fakeroot install
	# directory.
	#
	my @SAVEINC = @INC;
	foreach my $incentry (@SAVEINC) {
		unshift( @INC, "$dir/../../fakeroot.lib/$incentry" );
	}
	unshift( @INC, "$dir/../perl/lib" );
}

use strict;
use JazzHands::HOTPants;

use vars qw(%RAD_REQUEST %RAD_REPLY %RAD_CHECK);
use Data::Dumper;

use constant RLM_MODULE_REJECT   => 0;    # immediately reject the request
use constant RLM_MODULE_FAIL     => 1;    # module failed, don't reply
use constant RLM_MODULE_OK       => 2;    # the module is OK, continue
use constant RLM_MODULE_HANDLED  => 3;    # the module handled the request,
                                          #	so stop.
use constant RLM_MODULE_INVALID  => 4;    # the module considers the request
                                          #	invalid.
use constant RLM_MODULE_USERLOCK => 5;    # reject the request (user is
                                          #	locked out)
use constant RLM_MODULE_NOTFOUND => 6;    # user not found
use constant RLM_MODULE_NOOP     => 7;    # module succeeded without doing
                                          #	 anything
use constant RLM_MODULE_UPDATED  => 8;    # OK (pairs modified)
use constant RLM_MODULE_NUMCODES => 9;    # How many return codes there are

my $err;

#
# called throughout; meant to work around encryption map and what not
#
sub connect_hp {
	my $hp = new JazzHands::HOTPants(
		dbuser        => 'hotpants',
		encryptionmap => '/etc/tokenmap.json',
		debug         => 2
	);
	return $hp;
}

#
# figures out the source, and its an app, returns the appname as well
#
sub get_source {
	my @validsrc = qw(JH-Application-Name NAS-IP-Address);
	my $source;
	foreach my $s (@validsrc) {
		if ( $RAD_REQUEST{$s} ) {
			my $v = $RAD_REQUEST{$s};

			# This was just gross, but leaving here in case
			# it becomes necessary to resurrect
			#if ($s eq 'NAS-Identifier') {
			#	if ($v !~ s/^jazzhands-hotpants://) {
			#		next;
			#	}
			#}
			$source = $v;
			last;
		}
	}

	if ( ref($source) eq 'ARRAY' ) {
		my $newsource = $source->[0];
		radiusd::radlog(
			2,
			sprintf(
				"NAS-IP-Address is an array, picking out first (%s) of %s",
				$newsource, join( ",", @{$source} )
			)
		);
		$source = $newsource;
	}

	# may not be set
	my $appname = $RAD_REQUEST{'JH-Application-Name'}
	  || $RAD_REQUEST{'NAS-Identifier'};

	#radiusd::radlog( 2,
	#	sprintf("get_source(): returning %s %s", $source, $appname));

	return ( $source, $appname );
}

sub find_client {
	my $client =
	  $RAD_REQUEST{"Packet-Src-IP-Address"} || $RAD_REQUEST{'Tmp-IP-Address-0'};
	if ( !$client ) {
		radiusd::radlog( 4, "Unable to find callers IP" );
		return RLM_MODULE_FAIL;
	}

	# XXX - need to make this be a DB lookup
	my $hp = connect_hp();

	if ( !$hp ) {
		radiusd::radlog( 4,
			"Unable to connect" . $JazzHands::HOTPants::errstr );
		return RLM_MODULE_FAIL;
	}

	if ( $client && ( my $rec = $hp->GetSharedSecret($client) ) ) {
		my $short = $rec->{hostname};
		$short =~ s/\./_/g;
		$RAD_REPLY{'FreeRADIUS-Client-IP-Address'} = $client;
		$RAD_REPLY{'FreeRADIUS-Client-Shortname'}  = $short;
		$RAD_REPLY{'FreeRADIUS-Client-Secret'}     = $rec->{'secret'};

		# $RAD_REPLY{'FreeRADIUS-Client-NAS-Type'} = 'other';
		$RAD_REPLY{'FreeRADIUS-Client-Virtual-Server'} = 'HOTPants';
		return RLM_MODULE_OK;
	}
	$RAD_REPLY{"Reply-Message"} = "Unknown Client";
	return RLM_MODULE_REJECT;

}

# Function to handle authorize
sub authorize {

	# This call is used to authorize the host.  Basically return the
	# correct shared secret
	if (   $RAD_REQUEST{"Packet-Src-IP-Address"}
		|| $RAD_REQUEST{'Tmp-IP-Address-0'} )
	{
		return find_client();
	}

	my $rv = validate_credentials();

	if ( ref($rv) ne 'HASH' ) {
		return $rv;
	}

	my $appname    = $rv->{appname};
	my $authreqstr = $rv->{authreqstr};
	my $client     = $rv->{client};
	my $hp         = $rv->{hp};
	my $login      = $rv->{login};
	my $source     = $rv->{source};
	my $user       = $rv->{user};
	my $rank       = $rv->{rank};

	my $success =
	  $hp->AuthorizeUser( login => $login, source => $source, rank => $rank );
	if ( !$success ) {
		my $err = $hp->Error;
		radiusd::radlog( 2, sprintf( "%s: %s", $authreqstr, $err ) );
		$err = $hp->UserError;
		if ($err) {
			$RAD_REPLY{"Reply-Message"} = $err;
		}
		$hp->closedb;
		return RLM_MODULE_REJECT;
	}
	$RAD_REQUEST{"Auth-Type"} = "HOTPants";
	return RLM_MODULE_OK;
}

sub validate_credentials {
	my ( $source, $appname ) = get_source();

	#
	# The PWType rank is used for chaining, if set, then this is just passed
	# up to figure out where things are
	#
	my $rank;
	if ( ( my $state = $RAD_REQUEST{'State'} ) ) {
		if ( $state =~ s/^0x// ) {
			$state = map { chr("0x$_") } substr( $state, 2 );
			$state =~ s/^jazzhands-hotpants-//;
		}
		$rank = int($state);
	}

	my $callingid = "";
	if ( $RAD_REQUEST{'Calling-Station-Id'} ) {
		$callingid = $RAD_REQUEST{"Calling-Station-Id"};
	}
	if ( !$source ) {
		my $msg = join(
			", ",
			map {
				"$_ => "
				  . ( ( $_ !~ /Password/i ) ? $RAD_REQUEST{$_} : "BLANKED" )
			  }
			  keys %RAD_REQUEST
		);
		radiusd::radlog(
			4,
			sprintf(
				"authenticate: Unable to discern source from %s: %s",
				$callingid, $msg
			)
		);
		return RLM_MODULE_FAIL;
	}

	#if ( $RAD_REQUEST{"NAS-IP-Address"} eq "127.0.0.1" ) {
	#	fake localhost...
	#	$RAD_REQUEST{"NAS-IP-Address"} = "fake ip address";
	#}

	my $login;
	if ( !( $login = $RAD_REQUEST{"User-Name"} ) ) {
		radiusd::radlog( 4, "No User-Name in the request" );
		return RLM_MODULE_REJECT;
	}

	# convert to lower case for lookup
	my $origlogin = $login;
	$login =~ tr/A-Z/a-z/;

	my $authreqstr = sprintf( "Authentication request for %s (%s) from %s",
		$login, $origlogin, $source );
	if ($appname) {
		$authreqstr .= ' (' . $RAD_REQUEST{'NAS-IP-Address'} . ')';
	}
	if ( $RAD_REQUEST{'Calling-Station-Id'} ) {
		$authreqstr .= " connecting from " . $RAD_REQUEST{"Calling-Station-Id"};
	}

	my $hp = connect_hp();
	if ( $err = $hp->opendb ) {
		print STDERR $err . "\n";
		exit RLM_MODULE_FAIL;
	}

	#
	# Make sure this is a valid source.  AuthenticateUser does this as well,
	# but we're going to need to get the attributes for the user, so we need
	# to know this anyway.
	#

	my $client;
	if ( !( $client = $hp->fetch_client( client_id => $source ) ) ) {
		if ( $hp->Error ) {
			radiusd::radlog( 4, $hp->Error );
			$hp->closedb;
			return RLM_MODULE_FAIL;
		} else {
			radiusd::radlog( 2, sprintf( "%s: unknown client", $authreqstr ) );
			$hp->closedb;
			return RLM_MODULE_REJECT;
		}
	}

	my $user;
	if ( !( $user = $hp->fetch_user( login => $login ) ) ) {
		if ( !$hp->Error ) {
			radiusd::radlog( 2, sprintf( "unknown user", $authreqstr ) );
			$hp->closedb;
			return RLM_MODULE_REJECT;
		} else {
			radiusd::radlog( 4, "fetch_user: " . $hp->Error );
			$hp->closedb;
			return RLM_MODULE_FAIL;
		}
	}

	return {
		appname    => $appname,
		authreqstr => $authreqstr,
		client     => $client,
		hp         => $hp,
		login      => $login,
		source     => $source,
		user       => $user,
		rank       => $rank,
	};
}

# Function to handle authenticate
sub authenticate {
	my $rv = validate_credentials();

	if ( ref($rv) ne 'HASH' ) {
		return $rv;
	}

	my $appname    = $rv->{appname};
	my $authreqstr = $rv->{authreqstr};
	my $client     = $rv->{client};
	my $hp         = $rv->{hp};
	my $login      = $rv->{login};
	my $source     = $rv->{source};
	my $user       = $rv->{user};
	my $rank       = $rv->{rank};

	if ( !$hp->VerifyUser( user => $user ) ) {
		if ( $hp->Error ) {
			radiusd::radlog( 2, sprintf( "%s: %s", $authreqstr, $hp->Error ) );
		}
		$hp->closedb;
		return RLM_MODULE_REJECT;
	}

	my $passwd;
	if ( !defined( $passwd = $RAD_REQUEST{"User-Password"} ) ) {
		radiusd::radlog( 4, "No User-Password in the request" );
		$hp->closedb;
		return RLM_MODULE_REJECT;
	}
	my $success;

	if ( defined($passwd) ) {
		$hp->SetDebug(2);
		$success = $hp->AuthenticateUser(
			login  => $login,
			passwd => $passwd,
			source => $source,
			rank   => $rank
		);
		if ( !$success ) {
			my $err = $hp->Error;
			if ($err) {
				radiusd::radlog( 2, sprintf( "%s: %s", $authreqstr, $err ) );
			}
			$err = $hp->UserError;
			if ($err) {
				$RAD_REPLY{"Reply-Message"} = $err;
			}
			$hp->closedb;
			return RLM_MODULE_REJECT;
		}
		my $status = $hp->Status;
		if ($status) {
			radiusd::radlog( 2, sprintf( "%s: %s", $authreqstr, $status ) );
		}
	}

	if ( $success->{result} eq 'accept' ) {
		#
		# If we get here, the user is okay.  Fetch any attributes and put them
		# in the RAD_REPLY hash.  If any of the dictionary items are not known,
		# they won't get sent back and an error will get logged by rlm_perl
		#

		my $attrs;
		if (
			!(
				$attrs = $hp->fetch_attributes(
					login      => $login,
					devcoll_id => $client->{devcoll_id}
				)
			)
		  )
		{
			if ( $hp->Error ) {
				radiusd::radlog( 4, $hp->Error );
				$hp->closedb;
				return RLM_MODULE_FAIL;
			}
		}

		#
		# Copy all of the attribute/value pairs.  Where $source is radius,
		# JH-Application-ACL is handled differently below.  This probably
		# needs to be rethought.
		#
		map { $RAD_REPLY{$_} = $attrs->{RADIUS}->{$_}->{value} }
		  sort keys %{ $attrs->{RADIUS} };

		#
		# If we have JH-Application-Name set, return all of the attributes
		# for that application type.  If JH-Application-ACL was set, then
		# see if any of the ACLs match
		#

		if ($appname) {
			my @attr = sort keys %{ $attrs->{$source} };
			if (@attr) {
				$RAD_REPLY{$appname} = \@attr;
			}
			if ( $RAD_REQUEST{$appname} ) {

				# Clear the success flag unless we match an ACL
				$success = 0;
				foreach my $a (
					ref( $RAD_REQUEST{$appname} )
					? @{ $RAD_REQUEST{$appname} }
					: $RAD_REQUEST{$appname}
				  )
				{
					if ( grep { lc($_) eq lc($a) } @attr ) {
						$success = 1;
						last;
					}
				}
			}
		}
	} elsif ( $success->{result} eq 'challenge' ) {
		$RAD_REPLY{'State'}         = "jazzhands-hotpants-" . $success->{next};
		$RAD_REPLY{'Reply-Message'} = $success->{message};
		$RAD_CHECK{'Response-Packet-Type'} = 'Access-Challenge';
	}

	$hp->closedb;
	if ( $success->{result} eq 'accept' ) {
		return RLM_MODULE_OK;
	} elsif ( $success->{result} eq 'challenge' ) {
		return RLM_MODULE_HANDLED;
	} else {
		return RLM_MODULE_REJECT;
	}

	return RLM_MODULE_OK;
}

sub preacct {
	return RLM_MODULE_OK;
}

sub accounting {
	return RLM_MODULE_OK;
}

sub checksimul {
	return RLM_MODULE_OK;
}

sub pre_proxy {
	return RLM_MODULE_OK;
}

sub post_proxy {
	return RLM_MODULE_OK;
}

sub post_auth {
	return RLM_MODULE_OK;
}

# Function to handle xlat
sub xlat {
}

# Function to handle detach
sub detach {
	return RLM_MODULE_OK;
}

1;
