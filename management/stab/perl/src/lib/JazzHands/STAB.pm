#
# Copyright (c) 2013-2017 Todd M. Kover, Matthew Ragan
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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

# $Id$
#

package JazzHands::STAB;

use 5.008007;
use strict;
use warnings;

use Storable qw(dclone);
use CGI;    #qw(-no_xhtml);

# use CGI::Pretty;
use URI;
use Carp qw(cluck);
use Data::Dumper;
use NetAddr::IP qw(:lower);

# Try to keep these later.
use JazzHands::STAB::DBAccess;
use JazzHands::STAB::Device;
use JazzHands::STAB::Rack;
use JazzHands::DBI;
use JazzHands::Common qw(:all);

our @ISA = qw(
  JazzHands::Mgmt
  JazzHands::Common
  JazzHands::STAB::DBAccess
  JazzHands::STAB::Device
  JazzHands::STAB::Rack
);

our $VERSION = '1.0.0';

# Preloaded methods go here.

#
# This is called when thigns fail to initialize and it prints a human
# readable error message using raw html (in case modules don't work).
#
sub stab_panic {
	my $error = shift @_;

	print qq{
		Header: text/html;

		<html>
		<body>
		<head>
			<title> Panic:  STAB failed to initialize! </title>
			<style>
				div {
					text-align: center;
				}
				div.error {
					color: red;
				}
				div.big {
					border: 2px double-solid;
					border-color: black;
					width: 70%;
					display: inline;
				}
				div.panic {
					font-size: +50;
					text-align: center
				}
			</style>
		</head>
		<body>
		<div class="big">
			<div class="panic">
				PANIC!<br>STAB failed to initialize with error:
			</div>
			<div class="error">
					$error
			</div>
			<div class="panic"> Seek help. </div>
			</div>
		</div>
		</body>
		</html>

	};

	warn "stab_panic: ", $error;
	exit 1;
}

#
# functions that should be considered private.  May want to go through a
# little more effort to make them inaccessable.  Or not.
#

sub new {
	my $class = shift;
	my $opt   = &_options(@_);

	#
	# Accept either dbh (deprecated) or dbhandle
	#
	if ( $opt->{dbh} ) {
		cluck
		  "WARNING: dbh parameter to JazzHands::STAB::new() is deprecated\n";
		push( @_, 'dbhandle', $opt->{dbh} );
	}
	if ( !$opt->{application} ) {
		push( @_, 'application', 'stab' );
	}
	my $cgi;
	if ( !$opt->{cgi} ) {
		$cgi = new CGI || return undef;
		push( @_, 'appuser', $cgi->remote_user || $ENV{'REMOTE_USER'} );
	}

	my $self = $class->SUPER::new(@_);
	$self->{cgi} = $cgi;

	$self->{_username} = $cgi->remote_user;
	$self->{_username} =~ tr/A-Z/a-z/;

	foreach my $something ( 'ajax', 'debug' ) {
		$self->{$something} = $opt->{$something};
	}

	#	while ( my $thing = shift(@params) ) {
	#		if ( $thing eq 'dbh' ) {
	#			$self->{dbh} = shift(@params);
	#		} elsif ( $thing eq 'cgi' ) {
	#			$self->{cgi} = shift(@params);
	#		} elsif ( $thing eq 'dbuser' ) {
	#			$self->{_dbuser} = shift(@params);
	#		} elsif ( $thing eq 'ajax' ) {
	#			$self->{_ajax} = shift(@params);
	#		} elsif ( $thing eq 'debug' ) {
	#			$self->{_debug} = shift(@params);
	#		}
	#	}

	#	$self->_initdb() if ( !defined( $self->{dbh} ) );

	bless $self, $class;
	$self->textfield_sizing(1);

	#
	# This is kind of an icky way to find the error but the generic error
	# stuff needs to be revisted as part of decoupling this from
	# the now deprecated JazzHands::Mgmt...
	#
	if ( !$self->dbh ) {
		stab_panic(
			"Unable to initialize database: " . $JazzHands::DBI::errstr );
	}

	#
	# These are used for permissions.
	#
	$self->{_permmap} = {
		'AccountCol' => '/account/collection',
		'Approval'   => '/approve',
		'Device'     => '/device',
		'DNS'        => '/dns/',
		'Netblock'   => '/netblock/',
		'Network'    => '/network/',
		'Sites',     => '/sites/rack/',
		'X509',      => '/x509/',
		'StabAccess' => '/',
	};

	$self->{_urlpermmap} =
	  { map { $self->{_permmap}->{$_} => $_ } keys %{ $self->{_permmap} } };

	if ( !exists( $opt->{nocheck_perms} ) ) {
		my $stabroot = $self->guess_stab_root();
		my $thisurl  = $cgi->url( { -full => 1 } );
		foreach my $u (
			sort { length($a) <=> length($b) }
			keys %{ $self->{_urlpermmap} }
		  )
		{
			if ( $thisurl =~ /^$stabroot$u/ ) {
				if ( !$self->check_permissions( $self->{_urlpermmap}->{$u} ) ) {
					$self->return_permission_denied();
				}
			}
		}
	}

	$self;
}

sub return_permission_denied {
	my $self = shift @_;

	my $cgi      = $self->cgi;
	my $refurl   = $cgi->referer;
	my $stabroot = $self->guess_stab_root();

	if ( $refurl && $refurl =~ m,^$stabroot, ) {
		$self->error_return("Permission Denied");
	}

	print $cgi->header( -status => 403 );
	$self->rollback;
	$self->disconnect;
	exit 0;
}

sub cgi {
	my $self = shift;

	if (@_) { $self->{cgi} = shift }
	return $self->{cgi};
}

#
# fetch support email
#
sub support_email {
	my $self  = shift @_;
	my $email = $self->fetch_property( 'Defaults', '_supportemail' );
	$email || '-- email support address not set --';
}

sub check_permissions {
	my $self = shift;
	my $role = shift;

	if ( !exists( $self->{_sectionaccess} ) ) {
		my $q = qq{
			select	property_value
			  from	v_property p
					inner join v_acct_coll_acct_expanded ae
							using (account_collection_id)
					inner join v_corp_family_account a
							on ae.account_id = a.account_id
			where	a.login = ?
			 and	p.property_type = 'StabRole'
			 and	p.property_name = 'PermitStabSection'
		} || die $self->return_db_err();

		my $sth = $self->prepare($q) || $self->return_db_err;

		$sth->execute( $self->{_username} ) || die $self->return_db_err;
		while ( my ($r) = $sth->fetchrow_array() ) {
			push( @{ $self->{_sectionaccess} }, $r );
		}
		$sth->finish;
	}

	my @r = grep( $_ eq $role, @{ $self->{_sectionaccess} } );
	( $#r >= 0 ) ? 1 : 0;
}

sub check_role {
	my $self = shift;
	my $role = shift;

	if ( !exists( $self->{_roles} ) ) {
		my $q = qq{
			select	property_name
			  from	v_property p
					inner join v_acct_coll_acct_expanded ae
							using (account_collection_id)
					inner join v_corp_family_account a
							on ae.account_id = a.account_id
			where	a.login = ?
			 and	p.property_type = 'StabRole'
			 and	p.property_name != 'PermitStabSection'
		} || die $self->return_db_err();

		my $sth = $self->prepare($q) || $self->return_db_err;

		$sth->execute( $self->{_username} ) || die $self->return_db_err;
		while ( my ($r) = $sth->fetchrow_array() ) {
			push( @{ $self->{_roles} }, $r );
		}
		$sth->finish;
	}

	my @r = grep( $_ eq $role, @{ $self->{_roles} } );
	( $#r >= 0 ) ? 1 : 0;
}

sub check_approval_god_mode {
	my $self = shift @_ || die "Could not get STAB";

	my $myacctid = $self->get_account_id()
	  || die $self->error_return(
		"I was not able to determine who you are. This should not happen.");

	my $sth = $self->prepare(
		qq{
		SELECT count(*)
		FROM	v_acct_coll_acct_expanded
				JOIN account a USING (account_id)
				JOIN property USING (account_collection_id)
		WHERE	property_type = 'Defaults'
		AND		property_name = '_can_approve_all'
		AND		a. account_id = ?
	}
	) || return $self->return_db_err;

	$sth->execute($myacctid)
	  || return $self->error_return("Error determining delegation");

	my ($tally) = $sth->fetchrow_array();
	$sth->finish;
	$tally;
}

sub check_approval_delegation {
	my $self   = shift @_ || die "Could not get STAB";
	my $acctid = shift @_ || die "Could not find account id";

	#
	my $sth = $self->prepare(
		qq{
		SELECT	count(*)
		FROM	property
			INNER JOIN ( SELECT DISTINCT
					account_collection_id,
					unnest(ARRAY[h.account_id, h.manager_account_id])
						AS account_Id
				FROM v_account_manager_hier h
					INNER JOIN v_acct_coll_acct_expanded e
						ON h.manager_account_id = e.account_id
			) lhse USING (account_collection_id)
			INNER JOIN (
				SELECT account_collection_id
						AS property_value_account_coll_id,
					account_id
				FROM v_acct_coll_acct_expanded
			) rhse USING (property_value_account_coll_id)
		WHERE
			property_type = 'attestation'
			AND property_name IN ('Delegate', 'AlternateApprovers')
			AND lhse.account_id = ?
			AND rhse.account_id = ?

	}
	) || return $self->return_db_err;

	my $myacctid = $self->get_account_id()
	  || die $self->error_return(
		"I was not able to determine who you are. This should not happen.");

	$sth->execute( $acctid, $myacctid )
	  || $self->error_return("Error determining delegation");

	my ($tally) = $sth->fetchrow_array;
	$sth->finish;

	$tally;
}

#
# returns 1 if a user is an admin
#
sub check_admin() {
	my $self = shift;

	$self->check_permissions('FullAdmin');
}

sub username {
	my $self = shift;

	$self->{_username};
}

sub get_account_id {
	my $self = shift;

	my $who = shift || $self->{_username};

	my $sth = $self->prepare(
		qq{
		select	account_id
		from	v_corp_family_account
		where	login = ?
	}
	) || die $self->return_db_err;

	$sth->execute($who) || die $self->return_db_err;

	my ($id) = $sth->fetchrow_array;
	$sth->finish;
	if ( !$id ) {
		$self->error_return(
			"Unable to find '$who' in the database.  This should not happen.");
	}
	$id;
}

#
# handles dealing with java script, standard favorite icon, other things
# that are consistant across all apps.
#
sub start_html {
	my $self = shift;

	my $opts = {};
	if ( $#_ == 0 && ref( $_[0] ) ne 'HASH' ) {
		$opts->{'title'} = shift;
	} elsif ( $#_ == 0 && ref( $_[0] ) eq 'HASH' ) {
		$opts = shift;
		for my $v ( grep { /^-/ } keys %$opts ) {
			$opts->{ substr( $v, 1 ) } = $opts->{$v};
		}
	} else {
		$opts = &_options(@_);
	}

	my $cgi = $self->cgi;

	my $stabroot = $self->guess_stab_root;
	my $root     = $stabroot;
	$root =~ s,/stab$,,;

	my (%args);
	$args{'-script'} = $opts->{script} || [];

	if ( $opts->{javascript} ) {
		if ( $opts->{javascript} eq 'device' ) {
			push(
				@{ $args{'-script'} },
				{
					-language => 'javascript',
					-src => "$root/javascript-common/external/jQuery/jquery.js",
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/ajaxsearch.js"
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/table-manip.js"
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/stab-common.js"
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/dns-common.js"
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/device-utils.js"
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/form-tracking.js"
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/racks.js"
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/ajax-utils.js"
				},
			);
		}
		if ( $opts->{javascript} eq 'netblock_collection' ) {
			push(
				@{ $args{-script} },
				{
					-language => 'javascript',
					-src => "$root/javascript-common/external/jQuery/jquery.js",
				},
				{
					-language => 'javascript',
					-src      => "$root/javascript-common/common.js",
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/netblock-collection.js"
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/ajax-utils.js"
				}
			);
		}
		if ( $opts->{javascript} eq 'netblock' ) {
			push(
				@{ $args{-script} },
				{
					-language => 'javascript',
					-src => "$root/javascript-common/external/jQuery/jquery.js",
				},
				{
					-language => 'javascript',
					-src      => "$root/javascript-common/common.js",
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/tickets.js"
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/stab-common.js"
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/netblock.js"
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/ajax-utils.js"
				}
			);
		}
		if ( $opts->{javascript} eq 'network_range' || $opts->{javascript} eq 'site_netblock' ) {
			push(
				@{ $args{-script} },
				{
					-language => 'javascript',
					-src => "$root/javascript-common/external/jQuery/jquery.js",
				},
				{
					-language => 'javascript',
					-src      => "$root/javascript-common/common.js",
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/tickets.js"
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/stab-common.js"
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/form-tracking.js"
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/ajax-utils.js"
				}
			);
		}
		if ( $opts->{javascript} eq 'dns' ) {
			push(
				@{ $args{-script} },
				{
					-language => 'javascript',
					-src => "$root/javascript-common/external/jQuery/jquery.js",
				},
				{
					-language => 'javascript',
					-src =>
					  "$root/javascript-common/external/jquery-Autocomplete/jquery.autocomplete.js",
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/stab-common.js"
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/dns-common.js"
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/dns-utils.js"
				},
			);
		}
		if ( $opts->{javascript} eq 'ac' ) {
			push(
				@{ $args{-script} },
				{
					-language => 'javascript',
					-src => "$root/javascript-common/external/jQuery/jquery.js",
				},
				{
					-language => 'javascript',
					-src =>
					  "$root/javascript-common/external/jquery-Autocomplete/jquery.autocomplete.js",
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/stab-common.js"
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/account-collection.js"
				},
			);
		}
		if ( $opts->{javascript} eq 'attest' ) {
			push(
				@{ $args{-script} },
				{
					-language => 'javascript',
					-src => "$root/javascript-common/external/jQuery/jquery.js",
				},
				{
					-language => 'javascript',
					-src =>
					  "$root/javascript-common/external/chosen/chosen.jquery.js",
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/stab-common.js"
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/attest.js"
				},
			);
		}
		if ( $opts->{javascript} eq 'reporting' ) {
			push(
				@{ $args{-script} },
				{
					-language => 'javascript',
					-src => "$root/javascript-common/external/jQuery/jquery.js",
				},
				{
					-language => 'javascript',
					-src =>
					  "$root/javascript-common/external/datatables-1.10.9/jquery.dataTables.min.js",
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/stab-common.js"
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/reporting.js"
				},
			);
		}
		if ( $opts->{javascript} eq 'x509' ) {
			push(
				@{ $args{-script} },
				{
					-language => 'javascript',
					-src => "$root/javascript-common/external/jQuery/jquery.js",
				},
				{
					-language => 'javascript',
					-src =>
					  "$root/javascript-common/external/datatables-1.10.9/jquery.dataTables.min.js",
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/stab-common.js"
				},
			);
		}

		if ( $opts->{javascript} eq 'devicetype' ) {
			push(
				@{ $args{-script} },
				{
					-language => 'javascript',
					-src => "$root/javascript-common/external/jQuery/jquery.js",
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/devicetype.js"
				}
			);
		}
		if ( $opts->{javascript} eq 'rack' ) {
			push(
				@{ $args{-script} },
				{
					-language => 'javascript',
					-src => "$root/javascript-common/external/jQuery/jquery.js",
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/racks.js"
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/ajax-utils.js"
				}
			);
		}
		if ( $opts->{javascript} eq 'apps' ) {
			push(
				@{ $args{-script} },
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/stab-common.js"
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/app-utils.js"
				},
				{
					-language => 'javascript',
					-src      => "$stabroot/javascript/ajax-utils.js"
				}
			);
		}

	}

	$args{'-head'} = $cgi->Link(
		{
			-rel  => 'icon',
			-href => "$stabroot/stabcons/stab.png",
			-type => 'image/png'
		}
	  )
	  . $cgi->Link(
		{
			-rel  => 'shortcut icon',
			-href => "$stabroot/stabcons/stab.png",
			-type => 'image/png'
		}
	  );

	if ( $opts->{'onLoad'} ) {
		$args{'-onLoad'} = $opts->{'onLoad'};
	}

	$args{'-meta'} = {
		'id'        => '$Id$',
		'Generator' => "STAB!  STAB!  STAB!"
	};

	#
	# This might get around tabindex issues
	#
	$args{'-dtd'} = '-//W3C//DTD HTML 3.2//EN';

	# need to move to this...
	#$args{'-dtd'} = '-//W3C//DTD HTML 4.01 Transitional//EN';

	if ( defined( $opts->{'title'} ) && length( $opts->{'title'} ) ) {
		$args{'-title'} = "STAB: " . $opts->{'title'};

		# $args{'-title'} = $opts->{'title'};
	} else {
		$args{'-title'} = "STAB";
	}

	# development.  XXX Probably need to put in a is_dev_instance
	# function that can be used to discern this throughout the code,
	# although this is only used in the css for the background and here.
	if ( $stabroot !~ m,://stab.[^/]+/?$, && $stabroot !~ /dev[^e]/ ) {
		$args{'-title'} =~ s/STAB:/STAB(D):/;
	}

	#
	# should seriously consider  making case insensitive like CGI
	#
	if ( defined( $opts->{'style'} ) ) {
		$args{'-style'} = $opts->{'style'};
		if ( exists( $opts->{'style'}->{'SRC'} ) ) {
			$args{'-style'}->{'SRC'} =
			  [ "$stabroot/style.pl", $opts->{'style'}->{'SRC'} ];
		} else {
			$args{'-style'}->{'SRC'} = "$stabroot/style.pl";
		}
	} else {
		$args{'-style'} = {
			'SRC' => [

				#"$root/javascript-common/external/chosen/docsupport/style.css",
				#"$root/javascript-common/external/chosen/docsupport/prism.css",
				"$root/javascript-common/external/chosen/chosen.css",
				"$root/javascript-common/external/datatables-1.10.9/jquery.dataTables.min.css",
				"$stabroot/style.pl",
			]
		};
	}

	# XXX need to handle multiple styles, and figure out how to do chosen only
	# on attestation

	my $inline_title = "";
	if ( ( !defined( $opts->{'noinlinetitle'} ) ) ) {
		$inline_title = $opts->{'title'} || "";
		$inline_title =~ s/^\s+STAB:\s+//;
	}
	if ( defined($inline_title) ) {
		$inline_title =
		  $cgi->p( $cgi->h2( { -align => 'center' }, $inline_title ) );
	}

	if ( ( !defined( $opts->{'noinlinenavbar'} ) ) ) {
		my $map = {
			'Device'   => 'Device',
			'DNS'      => 'DNS',
			'Netblock' => 'Netblock',
			'Racks'    => 'Sites',
			'STAB'     => 'StabAccess',
		};

		my $navbar = "";
		foreach my $p ( sort keys %{$map} ) {
			if ( $self->check_permissions( $map->{$p} ) ) {
				if ( length($navbar) ) {
					$navbar .= " - ";
				}
				$navbar .= $cgi->a(
					{
						-href => "$stabroot/"
						  . $self->{_permmap}->{ $map->{$p} },
					},
					$p
				);
			}
		}

		if ( length($navbar) ) {
			$inline_title .=
			  $cgi->div( { -class => 'navbar' }, "[ $navbar ] " ) . "\n";
		}
	}

	if ( ( !defined( $opts->{'noinlinemsgs'} ) ) ) {
		my $errmsg  = $cgi->param('__errmsg__')  || undef;
		my $notemsg = $cgi->param('__notemsg__') || undef;
		$cgi->param( '__errmsg__',  undef );
		$cgi->param( '__notemsg__', undef );
		$inline_title .= $cgi->div( { -class => 'errmsg' }, $errmsg )
		  if ( defined($errmsg) );
		$inline_title .= $cgi->div( { -class => 'notemsg' }, $notemsg )
		  if ( defined($notemsg) );
	}

	$cgi->delete('orig_referer');

	$cgi->start_html( \%args ) . "\n" . $inline_title . "\n\n";
}

#
# passes all the arguments passed in back to the referer, which is either
# infered from self's cgi object or passed in.  This will allow
# the form to be re-presented to process errors, but allows all the error
# checking and commiting to happen here.
#
sub build_passback_url {
	my $self = shift @_;
	my $opts = &_options(@_);

	my $errmsg         = $opts->{'errmsg'};
	my $notemsg        = $opts->{'notemsg'};
	my $refurl         = $opts->{'refurl'};
	my $devlist        = $opts->{'devlist'};
	my $nopreserveargs = $opts->{'nopreserveargs'};

	my $cgi     = $self->cgi;
	my $origurl = $cgi->self_url;
	if ( !defined($refurl) ) {
		my $or = $cgi->param('orig_referer');
		if ( defined($or) && length($or) ) {
			$refurl = $or;
		} else {
			$refurl = $cgi->referer;
		}
		$cgi->delete('orig_referer');
	}

	if ( !$refurl ) {

		# used to return an error page, but this isn't really an
		# error, just a user configuration that causes issues.
		$refurl = $self->guess_stab_root;
	}

	my $uri = new URI($refurl);
	my $theq = $uri->query    || "";

	# Loop on parameters that are in the reference url
	# and eliminate those missing from the $cgi-param array
	# because those are unchecked checkboxes
	foreach my $keypair ( split( ';', $theq ) ) {
		my $key = (split( '=', $keypair ))[0];
		# If the parameter doesn't start with 'chk_', it's not a checkbox, skip it
		if ( $key !~ /^chk/ ) { next; }
		# Does the checkbox parameter exist in the cgi parameters?
		if ( !defined( $cgi->param($key) ) ) {
			# No, let's remove it from the referer url
			$theq =~ s/(^|;)$key=[^;]*(;|$)/;/;
			# Just make sure we didn't add an extra semicolon
			$theq =~ s/^;//;
			$theq =~ s/;$//;
		}
	}

	my $ref  = new CGI($theq) || "";

	if ( !defined($nopreserveargs) ) {
		foreach my $p ( $cgi->param ) {
			my $v = $cgi->param($p);
			$ref->param( $p, $v ) if ( defined($v) );
		}
	}

	#
	# This is really just to catch when someone is ultimately redirected
	# to the same site (sometimes the referer url wasn't canonicalized
	# but was basically the same.
	#
	my $attempts = 0;
	while ( $attempts++ < 2 ) {

		#
		# don't want to double-pass messages, so remove the ones that aren't
		# set, and set the ones that are.
		#
		if ( !defined($errmsg) ) {
			$ref->delete("__errmsg__");
		} else {
			$ref->param( "__errmsg__", $errmsg );
		}
		if ( !defined($notemsg) ) {
			$ref->delete("__notemsg__");
		} else {
			$ref->param( "__notemsg__", $notemsg );
		}
		if ( defined($devlist) ) {
			$ref->param( 'devlist', $devlist );
		} else {
			$ref->delete('devlist');
		}
		my $qs = $ref->query_string || "";
		$uri->query($qs);

		#
		# This should never happen, but seems to in development
		# sometimes.  This will cause a return to the same page
		# to redirect to an error page.
		#
		my $origuri = new URI($origurl);
		$origurl = $origuri->canonical;
		if ( $uri->canonical eq $origurl ) {
			my $stabroot = $self->guess_stab_root;
			$uri = new URI("$stabroot/error.pl");
			$uri->query($qs) if ( defined($qs) && length($qs) );
			$ref            = new CGI("");
			$nopreserveargs = 1;
			last;
		} else {
			last;
		}
	}
	return ( $uri->canonical );
}

sub return_db_err {
	my ( $self, $dbobj, $opttxt ) = @_;

	my $cgi = $self->cgi;

	if ( $dbobj = $self ) {
		$dbobj = $self->dbh;
	}

	my $genmsg = "DATABASE ERROR.  SEEK HELP: ";
	my $errmsg = "";
	my $rawmsg = "";
	if ( defined($dbobj) ) {
		if ( defined( $dbobj->err ) ) {

			# Most of these are no longer valid, but leaving here
			# for reference.
			if ( $dbobj->err == 20600 ) {
				$errmsg = "There is a conflicting package.";
			} elsif ( $dbobj->err == 20601 ) {
				$errmsg = "Package Repository is not open";
			} elsif ( $dbobj->err == 20602 ) {
				$errmsg =
				  "Device OS and VOE have different Software Package Repositories";
			} elsif ( $dbobj->err == 20603 ) {
				$errmsg =
				  "Device and VOE Track have different Software Package Repositories";
			}
			$genmsg = "" if ( length($errmsg) );
		}

		if ( !length($errmsg) && defined( $dbobj->errstr ) ) {
			$genmsg = "DATABASE ERROR.  SEEK HELP";
			$rawmsg = $errmsg;
			$errmsg = $cgi->escapeHTML( $dbobj->errstr )
			  || "unknown";
		}
	}

	if ( !length($errmsg) ) {
		$rawmsg = $errmsg = "Unknown database error";
	}

	if ( defined($opttxt) ) {
		$errmsg = "[$opttxt]: $errmsg";
	}
	cluck("returning db error $rawmsg");
	$self->error_return( ${genmsg} . "$errmsg\n" );
}

#
# return an error to the refering URL (or a specified one).  This will
# show up in red at the top of the URL.
#
sub error_return {
	my ( $self, $errmsg, $url, $success ) = @_;

	my $cgi = $self->cgi;
	$url = $self->build_passback_url(
		errmsg         => $errmsg,
		refurl         => $url,
		nopreserveargs => $success
	);

	if ( $self->{_ajax} ) {
		print $cgi->div( { -style => 'color: red' }, $errmsg );
	} else {
		print $cgi->redirect($url);
	}

	my $dbh = $self->dbh;
	if ($dbh) {
		$dbh->rollback;
		$dbh->ping;
		$dbh->disconnect;
	}
	exit;
}

#
# return an error to the refering URL (or a specified one).  This will
# show up in green at the top of the URL.
#
sub msg_return {
	my ( $self, $note, $url, $success ) = @_;

	my $cgi = $self->cgi;
	$url = $self->build_passback_url(
		notemsg        => $note,
		refurl         => $url,
		nopreserveargs => $success
	);
	print $cgi->redirect($url);

	my $dbh = $self->dbh;
	if ($dbh) {
		$dbh->rollback;
		$dbh->ping;
		$dbh->disconnect;
	}
	exit;
}

#
# most of the code only processes one thing at a time, despite the fact
# that it's possible to process multiple ones.  This is written to later
# be easily extended to processing multiple ones, though code will
# almost certainly need to be smarter about checking to see if updates
# really need to happen and executing updates accordingly...
#
sub cgi_get_ids {
	my ( $self, $field ) = @_;

	my $cgi = $self->cgi;
	my (@rv);

	foreach my $p ( $cgi->param ) {
		if ( $p =~ /^${field}_+(.+)$/s ) {
			my $digits = $1;
			my $v      = $cgi->param($p);

			#
			# this used to require that the value actually match
			# the field name, but this doesn't work for buttons,
			# though in the button case, only one can be pushed
			# at a time...
			#
			if ( defined($v) ) {
				push( @rv, $digits );
			}
		}
	}

	if ( $#rv == -1 ) {
		my $alone = $cgi->param($field);
		if ( defined($alone) ) {
			push( @rv, $alone );
		}
	}

	if ( wantarray() ) {
		return (@rv);
	} elsif ( defined wantarray() ) {
		return $rv[0];
	}
}

sub cgi_parse_param {
	my ( $self, $param, $key, $newkey ) = @_;

	my $cgi = $self->cgi;

	#
	# [XXX]
	# need to rethink in oder to get of the || $cgi->param($param);
	#

	my $v;
	if ( defined($key) ) {
		$v = $cgi->param("${param}_$key");
	} elsif ( defined($newkey) ) {
		$v = $cgi->param( $param . "_" );
	} else {
		$v = $cgi->param($param);
	}

	if ( defined($v) && ( $v eq '__unknown__' || !length($v) ) ) {
		$v = undef;
	}

	if ( defined($v) ) {
		$v =~ s/^\s*(.+)\s*$/$1/s;

		# Trim leading and trailing spaces.
		$v =~ s/^\s+|\s+$//g;
	}
	undef $cgi;
	$v;
}

sub mk_chk_yn {
	my ( $self, $value, $allowundef ) = @_;

	if ($allowundef) {
		if ( !defined($value) ) {
			return undef;
		}
		if (   $value =~ /^y/i
			|| $value =~ /on/i
			|| $value =~ /checked/i )
		{
			return 'Y';
		} else {
			return 'N';
		}
	} else {
		if ( defined($value) ) {
			return 'Y';
		} else {
			return 'N';
		}
	}
	return 'N';
}

sub remove_other_flagged {
	my ( $self, $oldblk, $newblk, $table, $pkey, $reckey, $field, $human ) = @_;

	my $dbh = $self->dbh;

	return undef if ( !defined($oldblk) || !defined($newblk) );

	return undef
	  if ( defined( $oldblk->{$field} )
		&& !defined( $newblk->{$field} ) );

	#
	# Check to see if there are other records for this thing that
	# have the key set
	#
	if ($reckey) {
		my $q = qq{
			select	count(*)
			  from	$table
			 where	$pkey = :pkey
			  and	$reckey != :mykey
			  and	$field = 'Y'
		};
		my $sth = $self->prepare($q) || $self->return_db_err($dbh);
		$sth->bind_param( ":pkey",  $oldblk->{$pkey} );
		$sth->bind_param( ":mykey", $oldblk->{$reckey} );
		$sth->execute || $self->return_db_err($sth);

		my $tally = ( $sth->fetchrow_array )[0];
		$sth->finish;
		return undef if ( $tally == 0 );
	}

	my $q = qq{
		update	$table
		  set	$field = 'N'
		where	$pkey = :pkey
		  and	$reckey != :mykey
		  and	$field = 'Y'
	};
	my $sth = $self->prepare($q) || $self->return_db_err($dbh);
	$sth->bind_param( ":pkey",  $oldblk->{$pkey} );
	$sth->bind_param( ":mykey", $oldblk->{$reckey} );
	$sth->execute || $self->return_db_err($sth);

	( ( defined($human) ) ? $human : $field ) . " updated";
}

#
# yes, words can not begin to describe the lameness of this, but our build
# of perl doesn't support 64-bit ints and macs are otherwise too big.
#
# Other suggestions welcome.
#
sub int_mac_from_text {
	my ( $self, $vc_mac ) = @_;

	return (undef) if ( !defined($vc_mac) );

	$vc_mac =~ tr/a-z/A-Z/;
	if ( $vc_mac =~ /^([\dA-F]{4}\.){2}[\dA-F]{4}$/ ) {
		$vc_mac =~ s/\.//g;
	} elsif ( $vc_mac =~ /^([\dA-F]{1,2}:){5}[\dA-F]{1,2}$/ ) {
		my $newmac = "";
		foreach my $o ( split( /:/, $vc_mac ) ) {
			$newmac .= sprintf( "%02X", hex($o) );
		}
		$vc_mac = $newmac;
	} elsif ( $vc_mac =~ /^[\dA-F]{12}$/ ) {

		#
	} else {
		return undef;
	}

	my $dbh = $self->dbh;

	my $q = qq{
		select TO_NUMBER(:1,'XXXXXXXXXXXX') from dual
	};
	my $sth = $self->prepare($q) || $self->return_db_err($dbh);
	$sth->execute($vc_mac) || $self->return_db_err($sth);
	( $sth->fetchrow_array )[0];
}

sub b_nondbdropdown {
	my $self = shift(@_);

	my $params;

	#
	# note the argument weirdnes check since the first arg is always
	# a hash...
	#
	if ( $#_ == 0 || ( !defined( $_[1] ) || ref $_[1] eq 'HASH' ) ) {
		$params = shift(@_);
	}
	my ( $values, $field, $pkeyfield, $noguessunknown ) = @_;

	# XXX probably should do this elsewhere, but...
	$field     = _dbx($field)     if ( defined($field) );
	$pkeyfield = _dbx($pkeyfield) if ( defined($pkeyfield) );

	my $dbh      = $self->dbh;
	my $cgi      = $self->cgi;
	my $onchange = $params->{'-onChange'};
	my $id       = $params->{'-id'};
	my $class    = $params->{'-class'};
	my $prefix   = $params->{'-prefix'} || "";
	my $preidfix = $params->{'-preidfix'} || "";
	my $suffix   = $params->{'-suffix'} || "";
	my $original = $params->{'-original'};

	my $xml = $params->{'-xml'};

	my $pkn = "";
	if ( defined($pkeyfield) && defined($values) ) {
		if ( ref $pkeyfield eq 'ARRAY' ) {
			foreach my $k (@$pkeyfield) {
				$pkn .= "_"
				  . (
					( defined( $values->{$k} ) )
					? $values->{$k}
					: ""
				  );
			}
		} else {
			if ( defined( $values->{$pkeyfield} ) ) {
				$pkn = "_" . $values->{$pkeyfield};
			}
		}
	}

	my $pickone = "Please Select";

	#
	# set these if they need to be bound.
	#
	my $devidmap;
	my $devfuncmap;

	my $withlevel = 0;

	# oracle/pgsqlism
	my $selectfield = $field;
	$selectfield =~ tr/a-z/A-Z/;

	my @list;
	my %list;
	my $default;
	if ( $selectfield eq 'BAUD' ) {
		@list = ( 300, 1200, 2400, 4800, 9600, 115200 );
	} elsif ( $selectfield eq 'SERIAL_PARAMS' ) {
		@list = (
			'8-N-1', '7-N-1', '8-N-2', '7-N-2', '8-N-1.5', '7-N-1.5',
			'8-E-1', '7-E-1', '8-E-2', '7-E-2', '8-E-1.5', '7-E-1.5',
			'8-O-1', '7-O-1', '8-O-2', '7-O-2', '8-O-1.5', '7-O-1.5',
			'8-S-1', '7-S-1', '8-S-2', '7-S-2', '8-S-1.5', '7-S-1.5',
			'8-M-1', '7-M-1', '8-M-2', '7-M-2', '8-M-1.5', '7-M-1.5'
		);
		foreach my $l (@list) { $list{$l} = $l }
		my $df = '__unknown__';
		$pickone = '--Unset--';
		unshift( @list, $df );
		$list{$df} = $pickone;
	} elsif ( $selectfield eq 'TIX_SYSTEM' ) {
		@list = ( "NSI-RT", "PPM" );
		foreach my $l (@list) { $list{$l} = $l }
		$default        = "__unknown__";
		$pickone        = "Pick System";
		$list{$default} = $pickone;
		unshift( @list, $default );
	} elsif ( $selectfield =~ /APPROVAL_TYPE$/ ) {

		# this probably needs to be handled better, perhaps with
		# a Y/N column in the db indicating that is a user
		# selectable value or some such.
		%list = (
			'rt'          => 'RT',
			'ppm'         => 'PPM',
			'servicedesk' => 'ServiceDesk',
			'jira'        => 'Jira',
		);
		foreach my $l ( sort keys %list ) { push( @list, $l ); }
		$default        = "__unknown__";
		$pickone        = "Pick System";
		$list{$default} = $pickone;
		unshift( @list, $default );
	} elsif ( $selectfield eq 'DNS_SRV_PROTOCOL' ) {
		%list = (
			'tcp' => '_tcp',
			'udp' => '_udp',
		);
		foreach my $l ( sort keys %list ) { push( @list, $l ); }
		$default        = "__unknown__";
		$pickone        = "Pick";
		$list{$default} = $pickone;
		unshift( @list, $default );
	} elsif ( $selectfield eq 'LOCATION_RACK_SIDE' ) {
		@list = ( 'FRONT', 'BACK' );
		my $df = 'FRONT';
	} elsif ( $selectfield =~ '(PC_)?P[12]_PHYSICAL_PORT_ID'
		|| $selectfield eq 'P2_POWER_INTERFACE_PORT' )
	{
		$default = '__unknown__';
		$pickone = 'Pick Device';

		@list = ($default);
		$list{$default} = $pickone;
	} elsif ( $selectfield eq 'RACK_STYLE' ) {
		@list = ( 'CABINET', 'RELAY' );
		my $df = 'CABINET';
	} elsif ( $selectfield eq 'DNS_TYPE' ) {
		@list = ( 'CNAME', 'A', 'AAAA' );
		my $df = 'CNAME';
	}

	if ( defined($values) ) {
		$default =
		  ( defined( $values->{$field} ) ) ? $values->{$field} : undef;
	}

	#
	# here we take the hackish method of looking for a field with
	# unknown in it, and if it's not found and there's no default, then
	# saying "please pick one from list."  There's probably a better way
	# to do this.
	#
	if ( !defined($values) ) {
		my @value =
		  grep( /unknown/ || ( defined( $list{$_} ) && $list{$_} =~ /unknown/ ),
			@list );
		if ( !defined($noguessunknown) && $#value >= 0 ) {
			$default = $value[0];
		} else {
			$default = "__unknown__";
			unshift( @list, $default );
			$list{$default} = $pickone;
		}
	} elsif ( !defined($default) ) {
		$default = "__unknown__";
		# Don't add duplicated options
		if( !exists( $list{$default} ) ) {
			unshift( @list, $default );
			$list{$default} = "--Unset--";
		}
	}

	$field =~ tr/a-z/A-Z/;

	my $name = "$prefix$field$preidfix$pkn$suffix";
	if ( defined($params) && exists( $params->{-name} ) ) {
		$name = $params->{-name};
	}

	if ( !defined($id) ) {
		$id = $name;
	}

	my $popup_args = {};
	$popup_args->{'-class'}    = $class if ($class);
	$popup_args->{'-name'}     = $name;
	$popup_args->{'-values'}   = \@list if ( $#list >= 0 );
	$popup_args->{'-labels'}   = \%list if ( $#list >= 0 );
	$popup_args->{'-default'}  = $default;
	$popup_args->{'-onChange'} = $onchange if ($onchange);
	$popup_args->{'-id'}       = $id if ($id);
	$popup_args->{'-original'} = $original if ( defined($original) );

	my $x = $cgi->popup_menu($popup_args);

	if ( $params->{-divWrap} ) {
		$x = $cgi->div( { -id => $params->{-divWrap} }, $x );
	}
	$x;
}

#
# [XXX] this needs to be tweaked to handle bind variables smarter.
# Have a hash that stores all the variables to bind and what to bind them
# to rather than deal with variables.  work, and stuff.
#
sub b_dropdown {
	my $self = shift(@_);

	my $params;

	#
	# note the argument weirdnes check since the first arg is always
	# a hash...
	#
	if ( $#_ == 0 || ( !defined( $_[1] ) || ref $_[1] eq 'HASH' ) ) {
		$params = shift(@_);
	}
	my ( $values, $field, $pkeyfield, $noguessunknown ) = @_;

	# XXX probably should do this elsewhere, but...
	$field     = _dbx($field)     if ( defined($field) );
	$pkeyfield = _dbx($pkeyfield) if ( defined($pkeyfield) );

	my $dbh      = $self->dbh;
	my $cgi      = $self->cgi;
	my $onchange = $params->{'-onChange'};
	my $class    = $params->{'-class'};
	my $prefix   = $params->{'-prefix'} || "";
	my $preidfix = $params->{'-preidfix'} || "";
	my $suffix   = $params->{'-suffix'} || "";
	my $callback = $params->{'-callback'};
	my $original = $params->{'-original'};

	# [XXX] need to consider making id/name always the same?
	my $id = $params->{'-id'};

	my $showhidden = $params->{'-showHidden'};

	my $pkn = "";
	if ( defined($pkeyfield) && defined($values) ) {
		if ( ref $pkeyfield eq 'ARRAY' ) {
			foreach my $k (@$pkeyfield) {
				$pkn .= "_"
				  . (
					( defined( $values->{$k} ) )
					? $values->{$k}
					: ""
				  );
			}
		} else {
			if ( defined( $values->{$pkeyfield} ) ) {
				$pkn = "_" . $values->{$pkeyfield};
			}
		}
	}

	my $site = $params->{-site} || undef;

	my $pickone = "Please Select";

	#
	# set these if they need to be bound.
	#
	my $devidmap;
	my $devfuncmap;
	my ($bindos);

	my $withlevel = 0;
	my $default;
	my $portrestrict;
	my $devcoltype;
	my $dnsdomaintype;

	my $argone_grey;

	# oracle/pgsqlism
	my $selectfield = $field;
	$selectfield =~ tr/a-z/A-Z/;

	my $q;
	if ( $selectfield eq 'DEVICE_TYPE_ID' ) {

		# kookiness is to strip out 'Not Applicable' companies.
		$q = qq{
			select * from
			(select	dt.device_type_id,
					CASE WHEN c.company_name = 'Not Applicable' THEN ' '
						ELSE c.company_name END as name,
					dt.model
			  from	device_type dt
					inner join company c
						on c.company_id = dt.company_id
			) xx
			order by
				CASE WHEN name = ' ' THEN lower(model) ELSE lower(name) END,
				lower(model)
		};
	} elsif ( $selectfield eq 'COMPONENT_TYPE_ID' ) {
		$q = qq{
			SELECT * FROM (
			SELECT	component_type_id,
					CASE WHEN company_name = 'unknown' THEN ' '
						ELSE company_name
					END AS company_name,
					model
			FROM component_type ct
				JOIN company cy USING (company_id)
			WHERE model IS NOT NULL
			) xx
			ORDER BY company_name, lower(model)
		};
	} elsif ( $selectfield eq 'DEVICE_STATUS' ) {
		$q = qq{
			select	device_status, description
			  from	val_device_status
			order by description, device_status
		};
	} elsif ( $selectfield eq 'AUTO_MGMT_PROTOCOL' ) {
		$q = qq{
			select	AUTO_MGMT_PROTOCOL, description
			  from	val_device_auto_mgmt_protocol
			order by description, AUTO_MGMT_PROTOCOL
		};
	} elsif ( $selectfield eq 'OWNERSHIP_STATUS' ) {
		$q = qq{
			select	ownership_status, description
			  from	val_ownership_status
			order by description, ownership_status
		};
	} elsif ( $selectfield eq 'OPERATING_SYSTEM_ID' ) {
		$q = qq{
			select	os.operating_system_id,
				os.operating_system_name, os.version
			  from	operating_system os
			order by os.operating_system_name, os.version
		};
	} elsif ( $selectfield eq 'DNS_DOMAIN_ID' ) {
		my $limitverbiage = "";
		if ( defined( $params->{'-only_nonauto'} ) ) {
			$limitverbiage = "where SHOULD_GENERATE = 'N'";
		}
		if ( defined( $params->{'-dnsdomaintype'} ) ) {
			if ( length($limitverbiage) ) {
				$limitverbiage .= " AND ";
			} else {
				$limitverbiage .= " WHERE ";
			}
			$limitverbiage .= "dns_domain_type = :dnsdomaintype";
			$dnsdomaintype = $params->{'-dnsdomaintype'};
		}
		$q = qq{
			select	dns_domain_id, soa_name
			  from	v_dns_domain_nouniverse $limitverbiage
			order by CASE WHEN dns_domain_type = 'reverse' THEN 1 ELSE 0 END,
				soa_name
		};
		$pickone = "Please Select Domain";
	} elsif ( $selectfield eq 'PRODUCTION_STATE' ) {
		$q = qq{
			select	production_state, description
			  from	val_production_state
			order by description, production_state
		};
	} elsif ( $selectfield eq 'SERVICE_ENVIRONMENT_ID' ) {
		$q = qq{
			select	service_environment_id,
				coalesce(description,
					concat(service_environment_name,
						' (', production_state, ')'))
						as description
			  from	service_environment
			order by description, service_environment_name
		};
	} elsif ( $selectfield eq 'NETWORK_INTERFACE_TYPE' ) {
		$q = qq{
			select	network_interface_type, description
			  from	val_network_interface_type
			order by description, network_interface_type
		};
	} elsif ( $selectfield eq 'NETWORK_INTERFACE_PURPOSE' ) {
		$q = qq{
			select	network_interface_purpose, description
			  from	val_network_interface_purpose
			order by description, network_interface_purpose
		};
	} elsif ( $selectfield eq 'DNS_TYPE' ) {
		my $list = q{  ('ID', 'NON-ID') };
		if ($showhidden) {

			# XXX when db constraint on val_dns_type.id_type is updated to
			# include HIDDEN, the or clause can go away.  This should happen
			# with 3.1.
			$list = q{  ('ID', 'NON-ID', 'HIDDEN') or dns_type = 'SOA' };
		}
		$q = qq{
			select	dns_type, description
			  from	val_dns_type
			 where	id_type in $list
			order by description, dns_type
		};
		$pickone = "Choose";
	} elsif ( $selectfield eq 'DNS_CLASS' ) {
		$q = qq{
			select	dns_class, description
			  from	val_dns_class
			order by description, dns_class
		};
		$pickone = "Choose";
	} elsif ( $selectfield eq 'COMPANY_ID'
		|| $selectfield =~ /_COMPANY_ID$/ )
	{
		my $ct = ( $params->{'-company_type'} )
		  ? q{
			inner join company_type using (company_id)
			where company_type = :company_type
			}
		  : "";
		$q = qq{
			select	company_id, company_name
			  from	company
				$ct
			order by lower(company_name)
		};
		$pickone = "Choose";
	} elsif ( $selectfield eq 'POWER_PLUG_STYLE' ) {
		$q = qq{
			select	power_plug_style, description
			  from	val_POWER_PLUG_STYLE
			order by POWER_PLUG_STYLE
		};
	} elsif ( $selectfield eq 'P2_DEVICE_ID' ) {
		## commented out because I think its not used with
		## device_function going away out left here inc ase I'm
		## wrong and need to figure out wtf.
		##
		## This is used to make a drop down of devices that meet
		## certain requirements.  It must be restricted to a certain
		## type, and that type should probably not be server.  It's
		## primarily used in device/device.pl .
		##
		#if ( !defined( $params->{'-devfuncrestrict'} ) ) {
		#	return ("");
		#}
		#$devfuncmap = $params->{'-devfuncrestrict'};
		#my $ordev = "";
		#if ( defined($values) && defined( $values->{$field} ) ) {
		#	$ordev    = 'or d.device_id = :devid';
		#	$devidmap = $values->{$field};
		#}
		#$q = qq{
		#	select  d.device_id,
		#		d.device_name
		#	  from  device d
		#		inner join device_function df
		#			on df.device_id = d.device_id
		#	where   df.device_function_type = :dev_func
		#	 $ordev
		#	 order by lower(d.device_name)
		#};
	} elsif ( $selectfield =~ '(PC_)?P[12]_PHYSICAL_PORT_ID' ) {
		$devidmap = $params->{'-deviceid'};
		if ( !$devidmap ) {
			return (
				$self->b_nondbdropdown( $params, $values, $field, $pkeyfield )
			);
		}
		$argone_grey = 1;

		if ( exists( $params->{'-portLimit'} ) ) {
			$portrestrict = "and p.port_type = :portrestrict";
		} else {
			$portrestrict = "";
		}

		# ORACLE/PGSQL -- the E\\\1 vs \\1
		# was distinct, maybe needs to be?
		# probably want to sort by network_strings...
		$q = qq{
			select
				CASE
     			     WHEN l1.layer1_connection_id is not NULL THEN 1     
			  	 WHEN pc.physical_connection_id is not NULL THEN 1
			  	 ELSE NULL
				END as connection_id,
					p.PHYSICAL_PORT_ID, p.port_name
			  from	PHYSICAL_PORT p
					left join layer1_connection l1 on
						(l1.PHYSICAL_PORT1_ID = p.physical_port_id or
						 l1.PHYSICAL_PORT2_ID = p.physical_port_id
						)
					left join physical_connection pc on
						(pc.PHYSICAL_PORT1_ID = p.physical_port_id or
						 pc.PHYSICAL_PORT2_ID = p.physical_port_id
						)
			 where	p.device_id = :devid
			   $portrestrict
			 order by
			 	regexp_replace(p.port_name,
					'^[^0-9]*([0-9]*)[^0-9]*\$',E'\\\\1'),
				p.port_name
		};
	} elsif ( $selectfield eq 'P2_POWER_DEVICE_ID' ) {
		$q = qq{
			select	d.device_id,
				d.device_name
			  from	device d
				inner join device_function df
					on df.device_id = d.device_id
			 where	df.device_function_type = 'rpc'
		};
	} elsif ( $selectfield eq 'PORT_SPEED' ) {
		$q = qq{
			select	port_speed,
				description
			  from	val_port_speed
		};
	} elsif ( $selectfield eq 'PORT_PURPOSE' ) {
		$q = qq{
			select	port_purpose,
				description
			  from	val_port_purpose
		};
	} elsif ( $selectfield eq 'PORT_PROTOCOL' ) {
		$q = qq{
			select	port_protocol,
				description
			  from	val_port_protocol
		};
	} elsif ( $selectfield eq 'PORT_PLUG_STYLE' ) {
		$q = qq{
			select	port_plug_style,
				description
			  from	val_port_plug_style
		};
	} elsif ( $selectfield eq 'PORT_MEDIUM' ) {
		$q = qq{
			select	distinct port_medium,
				description
			  from	val_port_medium
		};
	} elsif ( $selectfield eq 'CABLE_TYPE' ) {
		$q = qq{
			select	cable_type,
				description
			  from	val_cable_type
		};
	} elsif ( $selectfield eq 'P2_POWER_INTERFACE_PORT' ) {
		$devidmap = $params->{'-deviceid'};
		if ( !$devidmap ) {
			return (
				$self->b_nondbdropdown( $params, $values, $field, $pkeyfield )
			);
		}
		$argone_grey = 1;

		$q = qq{
			select	c.device_power_connection_id, p.power_interface_port
			  from	device_power_interface p
					left join device_power_connection c on
						(c.power_interface_port = p.power_interface_port AND
						 c.device_id = p.device_id) OR
						(c.rpc_power_interface_port = p.power_interface_port AND
						 c.rpc_device_id = p.device_id)
			 where	p.device_id = :devid
		};

	} elsif ( $selectfield eq 'SNMP_COMMSTR_TYPE' ) {
		$q = qq{
			select	snmp_commstr_type
			  from	val_snmp_commstr_type
			order by snmp_commstr_type
		};
		$pickone = "Choose";
	} elsif ( $selectfield eq 'PROCESSOR_ARCHITECTURE' ) {
		$q = qq{
			select  processor_architecture, description
			  from  val_processor_architecture
			order by description, processor_architecture
		};
	} elsif ( $selectfield eq 'SITE_CODE'
		|| $selectfield eq 'RACK_SITE_CODE' )
	{

		# [XXX] - consider making planned/active doober smarter
		# for places where someone may want to look at all sites.
		$q = qq{
			select  site_code
			  from  site
			order by site_code
		};
		$default = 'none' if ( !defined($default) );
	} elsif ( $selectfield eq 'RACK_ID'
		|| $selectfield eq 'LOCATION_RACK_ID' )
	{
		my $siteclause = "";
		if ($site) {
			$siteclause = 'and site_code = :site';
		}
		$q = qq{
			select  rack_id,
					CASE WHEN SITE_CODE = 'n/a' THEN '' ELSE SITE_CODE || '-' END	as SITE_CODE,
					CASE WHEN ROOM = 'n/a' THEN '' ELSE ROOM || '-' END	as ROOM,
					CASE WHEN SUB_ROOM = 'n/a' THEN '' ELSE SUB_ROOM || '-' END	as SUN_ROOM,
					CASE WHEN RACK_ROW = 'n/a' THEN '' ELSE RACK_ROW || '-' END	as RACK_ROW,
					CASE WHEN RACK_NAME = 'n/a' THEN '' ELSE RACK_NAME || '-' END	as RACK_NAME
			  from  rack
			where	rack_id > 0
			$siteclause
			order by site_code, room, sub_room, rack_row, rack_name
		};
		$default = 'none' if ( !defined($default) );
	} elsif ( $selectfield eq 'X509_CERT_ID' ) {
		$q = qq{
			select	x509_cert_Id, subject
			  from	x509_certificate
		};
	} elsif ( $selectfield eq 'X509_KEY_USG' ) {
		$q = qq{
			select	X509_KEY_USG, DESCRIPTION
			  from	VAL_X509_KEY_USAGE
		};
	} elsif ( $selectfield eq 'X509_FILE_FORMAT' ) {
		$q = qq{
			select	X509_FILE_FORMAT, DESCRIPTION
			  from	VAL_X509_CERTIFICATE_FILE_FMT
		};
	} elsif ( $selectfield eq 'DNS_DOMAIN_TYPE' ) {
		$q = qq{
			select	DNS_DOMAIN_TYPE, DESCRIPTION
			  from	VAL_DNS_DOMAIN_TYPE
		};
		$default = 'service' if ( !defined($default) );
	} elsif ( $selectfield eq 'DEVICE_COLLECTION_ID' ) {
		$q = qq{
			select	DEVICE_COLLECTION_ID,
				DEVICE_COLLECTION_NAME
			  from	DEVICE_COLLECTION
		};
		if ( exists( $params->{'-deviceCollectionType'} ) ) {
			$q .= "where device_collection_type = :devcoltype";
			$devcoltype = $params->{'-deviceCollectionType'};
		}
		$pickone = "Please Select License";
	} elsif ( $selectfield eq 'DNS_SRV_SERVICE' ) {
		$q = qq{
			select	dns_srv_service, description
			  from	val_dns_srv_service;
		};
	} elsif ( $selectfield eq 'RACK_TYPE' ) {
		$q = qq{
			select	rack_type, description
			  from	val_racK_type;
		};
	} elsif ( $selectfield eq 'NETBLOCK_COLLECTION_TYPE' ) {
		my $d = 'netblock_collection_type';
		if ( defined( $params->{-desc} ) && $params->{-desc} eq 'expand' ) {
			$d = q{
					netblock_collection_type || ' (' || description || ')' as
						description
			};
		}
		$q = qq{
			select	netblock_collection_type,  $d
			  from	val_netblock_collection_type
			order by netblock_collection_type
		};
	} elsif ( $selectfield eq 'ACCOUNT_COLLECTION_TYPE' ) {
		my $d = 'account_collection_type';
		if ( defined( $params->{-desc} ) && $params->{-desc} eq 'expand' ) {
			$d = q{
					account_collection_type || ' (' || description || ')' as
						description
			};
		}
		$q = qq{
			select	account_collection_type,  $d
			  from	val_account_collection_type
			order by account_collection_type
		};

	} elsif ( $selectfield eq 'APPROVAL_INSTANCE_ID' ) {
		$q = qq{
			select approval_instance_id, approval_instance_name
			from approval_instance
			order by approval_start desc
		};
	} elsif ( $selectfield eq 'NETWORK_RANGE_TYPE' ) {
		$q = qq{
			select
				network_range_type
			from
				val_network_range_type;
		};
		$default = 'none' if ( !defined($default) );
	} else {
		return "-XX-";
	}

	my $sth = $self->prepare($q) || $self->return_db_err($dbh);

	if ( defined($portrestrict) && length($portrestrict) ) {
		$sth->bind_param( ':portrestrict', $params->{'-portLimit'} );
	}

	if ( defined($site) && length($site) ) {
		$sth->bind_param( ':site', $site );
	}

	if ( defined($devidmap) ) {
		$sth->bind_param( ':devid', $devidmap );
	}

	if ( defined($devfuncmap) ) {
		$sth->bind_param( ':dev_func', $devfuncmap );
	}

	if ( defined($devcoltype) ) {
		$sth->bind_param( ':devcoltype', $devcoltype );
	}

	if ( defined($dnsdomaintype) ) {
		$sth->bind_param( ':dnsdomaintype', $dnsdomaintype );
	}

	if ( defined( $params->{'-company_type'} ) ) {
		$sth->bind_param( ':company_type', $params->{'-company_type'} );
	}

	$sth->execute || $self->return_db_err($sth);

	my (%attr);

	my (%list);
	my (@list);

	# override default if the value is actually set in the db.
	if ( defined($values) ) {
		$default =
		  ( defined( $values->{$field} ) ) ? $values->{$field} : undef;
	}
	while ( my (@stuff) = $sth->fetchrow_array ) {
		my $grey;
		#
		# allow caller to limit what's shown via a callback.
		#
		if ($callback) {
			next if ( !$callback->( $stuff[0] ) );
		}
		$grey = shift(@stuff) if ($argone_grey);
		my $header = "";
		if ($withlevel) {
			my $level = shift(@stuff);
			for ( my $i = 0 ; $i < $level ; $i++ ) {
				$header .= "--";
			}
		}

		# [XXX] $lid (perhaps) should be $id(?)  maybe bug, maybe not
		my $lid   = shift(@stuff);
		my $stuff = $header;
		if ( (@stuff) && $#stuff > -1 && defined( $stuff[0] ) ) {
			foreach my $x (@stuff) {
				$stuff .= join( " ", $x ) . " " if ($x);
			}
			$stuff = 'Unknown' if ( $stuff =~ /unknownunknown/ );
			$stuff =~ s/^\s+//;
			$stuff =~ s/\s+$//;
			$list{$lid} = $stuff;
		} else {
			$list{$lid} = $lid;
		}
		push( @list, $lid );
		if ( $argone_grey && $grey ) {
			$attr{$lid} = { -style => 'color: grey;' };
		}
	}

	$sth->finish;

	#
	# here we take the hackish method of looking for a field with
	# unknown in it, and if it's not found and there's no default, then
	# saying "please pick one from list."  There's probably a better way
	# to do this.
	#
	if ( !defined($values) ) {
		my @value =
		  grep( /unknown/ || ( defined( $list{$_} ) && $list{$_} =~ /unknown/ ),
			@list );
		if ( !defined($noguessunknown) && $#value >= 0 ) {
			$default = $value[0];
		} else {
			$default = "__unknown__";
			unshift( @list, $default );
			$list{$default} = $pickone;
		}
	} elsif ( !defined($default) ) {
		$default = "__unknown__";
		unshift( @list, $default );
		$list{$default} = "--Unset--";
	}

	my $nfield = $field;
	$nfield =~ tr/a-z/A-Z/;

	my $name = "$nfield$preidfix$pkn";
	if ( defined($params) && exists( $params->{-name} ) ) {
		$name = $params->{-name};
	}

	$name = "$prefix$preidfix$name$suffix";

	if ( !defined($id) ) {
		$id = $name;
	}

	my $redir = "";
	if ( !$onchange && $params->{-dolinkUpdate} ) {
		if ( $params->{'-dolinkUpdate'} eq 'device_type' ) {
			my $redirid = "ptr_" . $id;
			$onchange = "setDevLinkRedir($id, $redirid)";
			my $devlink = "javascript:void(null);";
			if ($default) {
				$devlink = "./type/?DEVICE_TYPE_ID=$default";
			}
			$redir = $cgi->a(
				{
					-style  => 'font-size: 30%;',
					-target => 'TOP',
					-id     => $redirid,
					-href   => $devlink
				},
				">>"
			);
		}
		if ( $params->{'-dolinkUpdate'} eq 'rack' ) {
			my $root    = $self->guess_stab_root() . "/sites/rack/";
			my $redirid = "rack_link" . $id;
			$onchange = "setRackLinkRedir(\"$id\", \"$redirid\", \"$root\")";
			my $devlink = "javascript:void(null);";
			if ( $default && $default ne '__unknown__' ) {
				$devlink = "$root?RACK_ID=$default";
			}
			$redir = $cgi->a(
				{
					-style  => 'font-size: 30%;',
					-target => 'TOP',
					-id     => $redirid,
					-href   => $devlink
				},
				">>"
			);
		}

	}

	my $popupargs = {};
	$popupargs->{-valign}     = 'TOP';
	$popupargs->{-name}       = $name;
	$popupargs->{-values}     = \@list if ( $#list >= 0 );
	$popupargs->{-labels}     = \%list if ( $#list >= 0 );
	$popupargs->{-default}    = $default;
	$popupargs->{-original}   = $original if ( defined($original) );
	$popupargs->{-onChange}   = $onchange if ( defined($onchange) );
	$popupargs->{-class}      = $class if ( defined($class) );
	$popupargs->{-attributes} = \%attr;
	$popupargs->{-id}         = $id if ( defined($id) );

	my $x = $cgi->popup_menu(
		$popupargs

	) . $redir;

	if ( $params->{-divWrap} ) {
		$x = $cgi->div( { -id => $params->{-divWrap} }, $x );
	}

	$x;
}

sub textfield_sizing {
	my $self = shift;

	if (@_) { $self->{_textfield_sizing} = shift }
	return $self->{_textfield_sizing};
}

sub newstyle_addition_ids {
	my $self = shift;

	if (@_) { $self->{_newstyle_addition_ids} = shift }
	return $self->{_newstyle_addition_ids};
}

sub b_offtextfield {
	my $self = shift(@_);
	my $params;

	#
	# note the argument weirdnes check since the first arg is always
	# a hash...
	#
	if ( $#_ == 0 || ( !defined( $_[1] ) || ref $_[1] eq 'HASH' ) ) {
		$params = shift(@_);
	}
	my ( $values, $field, $pkeyfield ) = @_;

	$params = {} if ( !$params );
	$params->{-noEdit} = 'yes';
	$self->b_textfield( $params, $values, $field, $pkeyfield );
}

sub b_offalwaystextfield {
	my $self = shift(@_);
	my $params;

	#
	# note the argument weirdnes check since the first arg is always
	# a hash...
	#
	if ( $#_ == 0 || ( !defined( $_[1] ) || ref $_[1] eq 'HASH' ) ) {
		$params = shift(@_);
	}
	my ( $values, $field, $pkeyfield ) = @_;

	# arguably, args should always be copied here or old value preserved.
	$params = {} if ( !$params );
	$params->{-noEdit} = 'always';
	my $x = $self->b_textfield( $params, $values, $field, $pkeyfield );
	delete( $params->{-noEdit} );
	$x;
}

sub b_textfield {
	my $self = shift(@_);
	my $params;

	#
	# note the argument weirdnes check since the first arg is always
	# a hash...
	#
	if ( $#_ == 0 || ( !defined( $_[1] ) || ref $_[1] eq 'HASH' ) ) {
		$params = shift(@_);
	}
	my ( $values, $field, $pkeyfield ) = @_;

	# XXX probably should do this elsewhere, but...
	$field     = _dbx($field)     if ( defined($field) );
	$pkeyfield = _dbx($pkeyfield) if ( defined($pkeyfield) );

	my $default      = $params->{'-default'};
	my $ip0          = $params->{'-allow_ip0'};
	my $class        = $params->{'-class'};
	my $alt          = $params->{'-alt'};
	my $onchange     = $params->{'-onChange'};
	my $onkeyup      = $params->{'-onKeyUp'};
	my $placeholder  = $params->{'-placeholder'};
	my $pattern      = $params->{'-pattern'};
	my $defaultValue = $params->{'-defaultValue'};
	my $original     = $params->{'-original'};
	my $editoff      = $params->{'-noEdit'} || 'never';
	my $prefix       = $params->{'-prefix'} || "";
	my $preidfix     = $params->{'-preidfix'} || "";
	my $suffix       = $params->{'-suffix'} || "";

	my $cgi = $self->cgi;

	my $pkn = "";
	if ( defined($pkeyfield) && defined($values) ) {
		if ( ref $pkeyfield eq 'ARRAY' ) {
			foreach my $k (@$pkeyfield) {
				$pkn .= "_"
				  . (
					( defined( $values->{$k} ) )
					? $values->{$k}
					: ""
				  );
			}
		} else {
			if ( defined( $values->{$pkeyfield} ) ) {
				$pkn = "_" . $values->{$pkeyfield};
			}
		}
	}

	# XXX this was setting both $f and $field to uppercase under oracle
	# need to reconsider
	my $f = $field;
	$f =~ tr/a-z/A-Z/;

	my $name    = $pkn;
	my $webname = "$prefix$f$preidfix$pkn$suffix";
	if ( $params && $params->{'-name'} ) {
		$name = $webname = $params->{'-name'};
	}
	my $allf =
	  defined( $values && defined( ( $values->{$field} ) ) )
	  ? $values->{$field}
	  : $default;

	#
	# Not a valid IP.
	#
	if ( !$ip0 && ( defined($allf) && $allf eq '0.0.0.0' ) ) {
		$allf = "";
	}

	# oracle/pgsqlism
	my $selectfield = $field;
	$field =~ tr/a-z/A-Z/;

	my $size = $params->{-textfield_width};
	if ( !defined($size) && $self->textfield_sizing ) {
		$size =
		  ( defined($allf) && length($allf) > 60 ) ? length($allf) : 60;
		$size = 30 if ( $field eq 'LEASE_EXPIRATION_DATE' );

		$size = 7  if ( $field =~ /APPROVAL_REF_NUM\b/ );
		$size = 20 if ( $field eq 'SNMP_COMMSTR' );
		$size = 16 if ( $field =~ /_?IP$/ );
		$size = 13 if ( $field eq 'MAC_ADDR' );
		$size = 10 if ( $field eq 'RACK_UNITS' );
		$size = 20 if ( $field eq 'INTERFACE_NAME' );
		$size = 10 if ( $field eq 'POWER_INTERFACE_PORT' );
		$size = 10 if ( $field eq 'VOLTAGE' );
		$size = 10 if ( $field eq 'MAX_AMPERAGE' );
		$size = 10 if ( $field eq 'P1_PORT_NAME' );
		$size = 10 if ( $field eq 'P2_PORT_NAME' );
		$size = 15 if ( $field eq 'RD_STRING' );
		$size = 15 if ( $field eq 'WR_STRING' );
		$size = 15 if ( $field eq 'LOCAL_PO' );
		$size = 30 if ( $field =~ /CIRCUIT_ID_STR$/ );
		$size = 10 if ( $field =~ /^TRUNK_TCIC/ );

		$size = 15 if ( $field eq 'LOCATION_ROOM' );
		$size = 15 if ( $field eq 'LOCATION_SUB_ROOM' );
		$size = 15 if ( $field eq 'LOCATION_RACK_ROW' );
		$size = 15 if ( $field eq 'LOCATION_RACK' );
		$size = 15 if ( $field eq 'LOCATION_RU_OFFSET' );
		$size = 15 if ( $field eq 'LOCATION_RACK_SIDE' );
		$size = 15 if ( $field eq 'LOCATION_INTER_DEV_OFFSET' );
	}

	my ( $button, $disabled ) = ( "", undef );
	if (   $values
		&& defined($field)
		&& $editoff =~ /^(yes|always)$/i )
	{
		my $id =
		  ( $values->{$pkeyfield} )
		  ? $field . "_" . $values->{$pkeyfield}
		  : undef;

		if ($id) {
			my $buttonid = "editbut_$id";
			$button = $cgi->a(
				{
					-id    => $buttonid,
					-class => 'stabeditbutton',
					-href  => '#',
					-onclick => 'event.preventDefault();',
				},
				$cgi->img(
					{
						-src   => "../stabcons/e.png",
						-alt   => "Edit",
						-title => 'Edit',

						# -class => 'stabeditbutton',
					}
				)
			);
		}
		$disabled = 'true';

	} elsif ( $editoff eq 'always' ) {
		my $id = $field;

		if ( defined($id) ) {
			my $buttonid = "editbut_$id";
			$button = $cgi->a(
				{
					-id    => $buttonid,
					-class => 'stabeditbutton',
					-href  => '#',
				},
				$cgi->img(
					{
						-src   => "../stabcons/e.png",
						-alt   => "Edit",
						-title => 'Edit',
						-class => 'stabeditbutton',
					}
				)
			);
		}
		$disabled = 'true';
	}

	$disabled = 1 if ( $params->{-disabled} );

	my $args = {};
	$args->{'-name'}         = $webname;
	$args->{'-id'}           = $webname;
	$args->{'-class'}        = $class if ( defined($class) );
	$args->{'-alt'}          = $alt if ( defined($alt) );
	$args->{'-onChange'}     = $onchange if ($onchange);
	$args->{'-onKeyUp'}      = $onkeyup if ($onkeyup);
	$args->{'-placeholder'}  = $placeholder if ( defined($placeholder) );
	$args->{'-pattern'}      = $pattern if ( defined($pattern) );
	$args->{'-defaultValue'} = $$defaultValue if ( defined($defaultValue) );
	$args->{'-default'}      = $allf if ( defined($allf) );
	$args->{'-original'}     = $original if ( defined($original) );
	$args->{'-size'}         = $size if ($size);
	$args->{'-maxlength'} = 2048;    ## [XXX] probably need to rethink!

	if ($disabled) {
		if ( $args->{-class} ) {
			$args->{'-class'} .= " off";
		} else {
			$args->{'-class'} = "off";
		}
	}

	my $optional = "";
	if ( $params->{-mark} ) {
		$optional = $cgi->em( { -style => 'font-size: 70%;' },
			"(" . $params->{-mark} . ")" );
	}

	$cgi->textfield($args) . $button . $optional;
}

sub build_tr {
	my $self = shift(@_);

	my $params;

	#
	# note the argument weirdnes check since the first arg is always
	# a hash...
	#
	if ( $#_ == 0 || ( !defined( $_[1] ) || ref $_[1] eq 'HASH' ) ) {
		$params = shift(@_);
	}

	my ( $values, $callback, $header, $field, $pkeyfield ) = @_;

	# XXX probably should do this elsewhere, but...
	$pkeyfield = _dbx($pkeyfield) if ( defined($pkeyfield) );

	my $cgi = $self->cgi;

	my $f = "";
	if ( defined($callback) ) {
		$f = $self->$callback( $params, $values, $field, $pkeyfield );
	} else {
		$f = $values->{$field} || "";
	}

	my $args = {};
	if ( exists( $params->{-noaligntr} ) ) {
		1;
	} elsif ( exists( $params->{-align} ) ) {
		$args->{-align} = $params->{-align};
	} else {
		$args = { -align => 'right', -valign => 'bottom' };
	}

	my $postpend = $params->{'-postpend_html'} || "";
	$f .= $postpend;

	my $rv =
	  $cgi->Tr( $cgi->td( $args, $cgi->b($header) ), $cgi->td($f) ) . "\n";

	$rv;
}

sub build_checkbox {
	my ($self) = shift @_;

	my $params;

	#
	# note the argument weirdnes check since the first arg is always
	# a hash...
	#
	if ( $#_ == 0 || ( !defined( $_[1] ) || ref $_[1] eq 'HASH' ) ) {
		$params = shift(@_);
	}
	my ( $values, $label, $field, $pkeyfield, $checked ) = @_;

	# This gets around $label not being set in the other build_* b_
	# commands that may be passed to build_tr
	if ( $params && exists( $params->{-label} ) ) {
		$pkeyfield = $field;
		$field     = $label;
		$label     = $params->{-label};
	}

	# XXX probably should do this elsewhere, but...
	$field     = _dbx($field)     if ( defined($field) );
	$pkeyfield = _dbx($pkeyfield) if ( defined($pkeyfield) );

	my $cgi = $self->cgi;

	my $pkn = "";
	if ( defined($pkeyfield) && defined($values) ) {
		if ( ref $pkeyfield eq 'ARRAY' ) {
			foreach my $k (@$pkeyfield) {
				$pkn .= "_"
				  . (
					( defined( $values->{$k} ) )
					? $values->{$k}
					: ""
				  );
			}
		} else {
			if ( defined( $values->{$pkeyfield} ) ) {
				$pkn = "_" . $values->{$pkeyfield};
			}
		}
	}

	if ( defined($values) ) {
		if ( !defined($checked) && defined( $values->{$field} ) ) {
			$checked = ( $values->{$field} eq 'Y' ) ? 1 : undef;
		}
	} elsif ( exists( $params->{'-default'} ) ) {
		$checked = $params->{'-default'};
	}

	if ( defined($checked) && ( $checked ne 0 && $checked ne 'off' ) ) {
		$checked = 'on';
	} else {
		$checked = undef;
	}

	$field =~ tr/a-z/A-Z/;
	my $name = "chk_${field}$pkn";

	if ( defined( $params->{-prefix} ) ) {
		$name = $params->{-prefix} . $name;
	}

	if ( defined( $params->{-suffix} ) ) {
		$name = $name . $params->{-suffix};
	}
	my $args = {
		-name  => $name || '',
		-value => 'on',
		-label => $label || '',
	};

	if ( defined($checked) ) {
		$args->{-checked} = $checked;
	}

	if ( defined( $params->{-class} ) ) {
		$args->{-class} = $params->{-class};
	}

	if ( defined( $params->{-original} ) ) {
		$args->{-original} = $params->{-original};
	}

	my $cb = $cgi->checkbox( $args, );

	if ( !$params->{-nodiv} ) {
		return ( $cgi->div($cb) );
	} else {
		return $cb;
	}
}

sub build_table_from_query {
	my $self = shift @_;

	my $opt = &_options(@_);

	my $cgi = $self->cgi;
	my $sth = $self->prepare( $opt->{query} ) || return $self->return_db_err();

	if ( !$opt->{bind} ) {
		$sth->execute || return $self->return_db_err($sth);
	} elsif ( ref( $opt->{bind} ) eq 'ARRAY' ) {
		$sth->execute( @{ $opt->{bind} } ) || return $self->return_db_err($sth);
	} elsif ( ref $opt->{bind} eq 'HASH' ) {
		return $self->error_return("HASH binding not implemented");
	} else {
		return $self->error_return("Unable to handle this type of args");
	}

	my $showcols = $sth->{NAME};
	if ( defined( $opt->{hidden} ) ) {
		my %c = map { $_ => 1 } @{ $opt->{hidden} };
		my @x = grep( defined($_) && $_,
			map { ( !defined( $c{$_} ) ) ? $_ : undef } @{$showcols} );
		$showcols = \@x;

	}
	my $thead = $cgi->thead( $cgi->th( [ @{$showcols} ] ) );

	my $t = "";
	while ( my $hr = $sth->fetchrow_hashref ) {
		my @foo;
		foreach my $k ( @{$showcols} ) {

			#
			# if there is an entry in urlmap for this column, transform
			# it into a url and do replacements for all the columns in the
			# query
			#
			if ( $opt->{urlmap} && exists( $opt->{urlmap}->{$k} ) ) {
				my $url = $opt->{urlmap}->{$k};
				foreach my $qcol ( @{ $sth->{NAME} } ) {
					my $v = $hr->{$qcol} || '';
					$url =~ s,\%\{$qcol\},$v,;
				}
				push( @foo, $cgi->a( { -href => $url }, $hr->{$k} ) );
			} else {
				push( @foo, $hr->{$k} );
			}
		}
		for ( my $i = 0 ; $i <= $#foo ; $i++ ) {
			$foo[$i] = '' if ( !defined( $foo[$i] ) );
		}
		$t .= $cgi->Tr( $cgi->td( [@foo] ) );
	}

	my $args;
	$args->{class} = $opt->{class} if ( exists( $opt->{class} ) );

	$args = "" if ( !$args );

	my $caption = "";
	if ( exists( $opt->{caption} ) ) {
		$caption = $cgi->caption( $opt->{caption} );
	}

	my $divargs   = dclone($args);
	my $tableargs = dclone($args);

	if ( $opt->{tableid} ) {
		$tableargs->{id} = $opt->{tableid};
	}

	$cgi->div( $divargs, $cgi->table( $tableargs, $caption, $thead, $t ) );
}

sub check_if_sure {
	my ( $self, $msg ) = @_;

	my $cgi          = $self->cgi;
	my $areyousure   = $cgi->param('areyousure') || undef;
	my $orig_referer = $cgi->param('orig_referer') || undef;

	$msg = "do this" if ( !defined($msg) );

	if ( !defined($areyousure) ) {
		my $n = new CGI($cgi);
		$n->param( 'areyousure', 'y' );
		my $ref = $orig_referer || $cgi->referer;
		$n->param( 'orig_referer', $ref );

		print $cgi->header(      { -type  => 'text/html' } ),    "\n";
		print $self->start_html( { -title => 'Verification' } ), "\n";
		print $cgi->h2(
			$cgi->a(
				{ -href => $n->self_url },
				"Click if you are you sure you want to ${msg}."
			)
		);
		print $cgi->end_html;
		exit;
	} else {
		$cgi->delete('areyousure');
	}
}

#
# this used to call guess_parent_netblock_id but was switched around to
# hit up the db directly since guess_parent_netblock_id probaly just needs
# to die since that's all handled in the db.
#
sub parse_netblock_search {
	my ( $self, $bycidr ) = @_;

	my $cgi = $self->cgi || die "Could not create cgi";
	my $dbh = $self->dbh || die "Could not create dbh";

	my $nb = new NetAddr::IP($bycidr);

	if ( !defined($nb) ) {
		return $self->error_return("You specified an invalid address");
	}

	my $parent = $self->guess_parent_netblock_id( $bycidr, undef, 'Y' );

	my $sth = $self->prepare(
		qq{
		SELECT *
		FROM netblock
		WHERE netblock_id IN ( SELECT
			netblock_utils.find_best_parent_id(
				in_IpAddress := ?,
				in_ip_universe_id := 0,
				in_netblock_type := 'default'
		))
		ORDER BY netblock_id
		LIMIT 1
	}
	) || return $self->return_db_err();

	$sth->execute($bycidr) || return $self->return_db_err($sth);

	my $blk = $sth->fetchrow_hashref;
	$sth->finish;

	if ( !$blk ) {
		return $self->error_return("Network $bycidr not found");
	}
	$blk;
}

sub parse_netblock_description_search {
	my ( $self, $bydesc ) = @_;

	my $dbh = $self->dbh || die "Could not create dbh";

	my $q = qq{
		select	nb.netblock_id as netblock_id,
			net_manip.inet_dbtop(nb.ip_address) as ip,
			nb.ip_address,
			nb.is_single_address,
			nb.parent_netblock_id,
			nb.netblock_status,
			nb.description
		  from	netblock nb
		 where	lower(nb.description) like lower(?)
	};

	$bydesc = "%$bydesc%";
	my $sth = $self->prepare($q) || $self->return_db_err($dbh);
	$sth->execute($bydesc) || $self->return_db_err($sth);

	my $hr = $sth->fetchall_hashref( _dbx('NETBLOCK_ID') );
	$hr;
}

sub guess_stab_root {
	my ( $self, $abs ) = @_;

	my $cgi = $self->cgi;

	my $root = $cgi->url( { -full => 1 } );
	if ( $root =~ /~.*stab/ || $root =~ m,/stab/, ) {
		$root =~ s,(stab).*$,$1,;
	} else {
		$root = $cgi->url( { -base => 1 } );
	}
	$root || "/";
}

#
# hr - hash ref for passing to expansion functions
# id - the id value that's used for this field
# pkey - pkey (generally suffixed to things)
# prefix - optional prefix tp prepend before the approval fields.  This
# 	should probably be an argument passed to the b_* functions.
#
sub build_ticket_row {
	my ( $self, $hr, $id, $pkey, $prefix ) = @_;

	my $cgi = $self->cgi;

	if ( defined($prefix) && length($prefix) ) {
		$prefix .= "_";
	} else {
		$prefix = "";
	}

	my $idstr = ( defined($id) ) ? "_$id" : "";

	# [XXX] probably want to rethink this.
	my $dropid = $prefix . "APPROVAL_TYPE$idstr";
	my $txtid  = $prefix . "APPROVAL_REF_NUM$idstr";
	my $tix    = $self->b_nondbdropdown(
		{
			-name     => $dropid,
			-onChange => "tix_sys_toggle(\"$dropid\", \"$txtid\")",
		},
		$hr,
		$prefix . 'APPROVAL_TYPE',
		$pkey
	  )
	  . $self->b_textfield(
		{ -disabled => 'yes', -name => $txtid }, undef,
		$prefix . 'APPROVAL_REF_NUM', $pkey
	  );
	$tix;
}

sub build_trouble_ticket_link {
	my ( $self, $tix, $system ) = @_;

	return "" if ( !$tix || !$system );
	if ( !defined($system) ) {
		if ( $tix =~ s/^ppm:// ) {
			$system = 'ppm';
		} elsif ( $tix =~ s/^rt:// ) {
			$system = 'rt';
		}
	}

	if ( $system eq 'ppm' ) {
		"https://othertool.example.com/ticket?REQUEST_ID=$tix";
	} elsif ( $system eq 'rt' ) {
		"https://tickets.example.com/Ticket/Display.html?id=$tix";
	} else {

		# undef causes the caller to have to not show a link.
		return undef;
	}
}

sub cmpPkgVer {
	my ( $self, $ver1, $ver2 ) = @_;
	my ( $ver1Maj, $ver1Min, $ver2Maj, $ver2Min );
	my ( @ver1, @ver2 );

	return ($ver1) if ( defined($ver1)  && !defined($ver2) );
	return ($ver2) if ( !defined($ver1) && defined($ver2) );

	unless ( $ver1 =~ /^[\d\.]+-[\d\.]$/ && $ver2 =~ /^[\d\.]+-[\d\.]$/ ) {
		return $ver1 if ( $ver1 gt $ver2 );
		return $ver2 if ( $ver2 gt $ver1 );
	}

	return undef if ( $ver1 eq $ver2 );

	( $ver1Maj, $ver1Min ) = split( /-/, $ver1 );
	( $ver2Maj, $ver2Min ) = split( /-/, $ver2 );

	@ver1 = split( /\./, $ver1Maj );
	@ver2 = split( /\./, $ver2Maj );

	my $mi =
	  ( scalar(@ver1) > scalar(@ver2) ) ? scalar(@ver1) : scalar(@ver2);

	for ( my $i = 0 ; $i < $mi ; $i++ ) {
		if ( defined( $ver1[$i] ) && !defined( $ver2[$i] ) ) {
			return $ver1;
		} elsif ( !defined( $ver1[$i] ) && defined( $ver2[$i] ) ) {
			return $ver2;
		} elsif ( $ver1[$i] !~ /^\d+/ || $ver2[$i] !~ /^\d+/ ) {
			return $ver1 if ( $ver1[$i] gt $ver2[$i] );
			return $ver2 if ( $ver2[$i] gt $ver1[$i] );
		} else {
			return $ver1 if ( $ver1[$i] > $ver2[$i] );
			return $ver2 if ( $ver2[$i] > $ver1[$i] );
		}
	}

	@ver1 = split( /\./, $ver1Min );
	@ver2 = split( /\./, $ver2Min );

	$mi = ( scalar(@ver1) > scalar(@ver2) ) ? scalar(@ver1) : scalar(@ver2);

	for ( my $i = 0 ; $i < $mi ; $i++ ) {
		return $ver1 if ( $ver1[$i] > $ver2[$i] );
		return $ver2 if ( $ver2[$i] > $ver1[$i] );
	}

	return 0;
}

sub zone_header {
	my ( $self, $hr, $change_type ) = @_;

	$change_type = 'add' if ( !$change_type );

	my $cgi = $self->cgi || die "Could not create cgi";
	my $dbh = $self->dbh || die "Could not create dbh";

	$self->textfield_sizing(0);
	my $serial = $self->b_textfield( $hr, 'SOA_SERIAL', 'DNS_DOMAIN_ID', 0 );
	my $refresh =
	  $self->b_textfield( $hr, 'SOA_REFRESH', 'DNS_DOMAIN_ID', 21600 );
	my $retry = $self->b_textfield( $hr, 'SOA_RETRY', 'DNS_DOMAIN_ID', 7200 );
	my $expire =
	  $self->b_textfield( $hr, 'SOA_EXPIRE', 'DNS_DOMAIN_ID', 2419200 );
	my $minimum =
	  $self->b_textfield( $hr, 'SOA_MINIMUM', 'DNS_DOMAIN_ID', 3600 );
	my $mname = $self->b_textfield( $hr, 'SOA_MNAME', 'DNS_DOMAIN_ID' );
	my $rname = $self->b_textfield( $hr, 'SOA_RNAME', 'DNS_DOMAIN_ID' );
	$self->textfield_sizing(1);

	my $class = 'IN';
	my $type  = 'SOA';
	my $ttl   = 3600;

	if ( defined($hr) ) {
		$type = $hr->{ _dbx('SOA_TYPE') } || 'SOA';
		$ttl  = $hr->{ _dbx('TTL') }      || "";
	}

	my $style = '';
	if ( !$change_type || $change_type ne 'update' ) {
		$style = 'visibility: hidden; display: none';
	}

	my $t = $cgi->table(
		{ -id => 'soa_table', -style => $style, -class => 'soatable' },
		( $change_type ne 'update' )
		? $cgi->caption(
			"These fields will be filled in automatically, you need not enter them.",
			$cgi->hr
		  )
		: "",
		$cgi->Tr(
			$cgi->td( "@\t", $ttl, " ", $class, " ", $type ),
			$cgi->td($mname),
			$cgi->td( $rname, "(" ),
		),
		$cgi->Tr( $cgi->td(""),  $cgi->td($serial),  $cgi->td("; serial") ),
		$cgi->Tr( $cgi->td(""),  $cgi->td($refresh), $cgi->td("; refresh") ),
		$cgi->Tr( $cgi->td(""),  $cgi->td($retry),   $cgi->td("; retry") ),
		$cgi->Tr( $cgi->td(""),  $cgi->td($expire),  $cgi->td("; expire") ),
		$cgi->Tr( $cgi->td(""),  $cgi->td($minimum), $cgi->td("; minimum") ),
		$cgi->Tr( $cgi->td(")"), $cgi->td(""),       $cgi->td("") )
	);

	$t;
}

sub add_power_ports {
	my ( $self, $devtypid ) = @_;

	my $cgi = $self->cgi || die "Could not create cgi";
	my $dbh = $self->dbh || die "Could not create dbh";

	my $prefix = $self->cgi_parse_param('POWER_INTERFACE_PORT_PREFIX');
	my $start  = $self->cgi_parse_param('POWER_INTERFACE_PORT_START');
	my $count  = $self->cgi_parse_param('POWER_INTERFACE_PORT_COUNT');
	my $pstyl  = $self->cgi_parse_param('POWER_PLUG_STYLE');
	my $volt   = $self->cgi_parse_param('VOLTAGE');
	my $maxamp = $self->cgi_parse_param('MAX_AMPERAGE');
	my $dopwr  = $self->cgi_parse_param('chk_PROVIDES_POWER');
	my $isopt  = $self->cgi_parse_param('chk_IS_OPTIONAL');

	$dopwr = $self->mk_chk_yn($dopwr);
	$isopt = $self->mk_chk_yn($isopt);

	if ( !defined($start) ) {
		$self->error_return("You must specify the first port");
	} elsif ( $start !~ /^\d/ ) {
		$self->error_return("Power port start must be a positive number.");
	}

	if ( !defined($count) ) {
		$self->error_return("You must specify the number of ports");
	} elsif ( $count !~ /^\d/ || $count <= 0 ) {
		$self->error_return("Power port count must be a positive number.");
	}
	if ( !defined($pstyl) ) {
		$self->error_return("You must specify the power plug style");
	}
	if ( !defined($volt) ) {
		$self->error_return("You must specify the voltage");
	} elsif ( $volt !~ /^\d/ || $volt <= 0 ) {
		$self->error_return("Voltage must be a positive number.");
	}
	if ( !defined($maxamp) ) {
		$self->error_return("You must specify the max amperage");
	} elsif ( $maxamp !~ /^\d/ || $maxamp <= 0 ) {
		$self->error_return("Max Amperage must be a positive number.");
	}

	if ( $start !~ /^\d+$/ ) {
		$self->error_return("Start port must be a number");
	}
	if ( $start !~ /^\d+$/ || $count <= 0 ) {
		$self->error_return("End port must be a positive number");
	}

	if ( $prefix && length($prefix) > 60 ) {
		$self->error_return("Serial prefix must be no more than 60 characters");

	}

	#
	# [XXX] - need to properly handle provides_power.  This will happen well
	# after 2-2 is released, I'm thinking.
	my $q = qq{
		insert into     device_type_power_port_templt (
			device_type_id, power_interface_port,
			power_plug_style, voltage, max_amperage,
			provides_power, is_optional
		) values (
			?, ?,
			?, ?, ?,
			?, ?
		)
	};
	my $sth = $dbh->prepare($q) || $self->return_db_err($dbh);

	my $total = 0;
	for ( my $i = $start ; $i < $start + $count ; $i++ ) {
		my $portname = $i;
		if ( defined($prefix) ) {
			$portname = "$prefix$i";
		}
		$sth->execute( $devtypid, $portname, $pstyl, $volt, $maxamp,
			$dopwr, $isopt )
		  || $self->return_db_err($dbh);
		$total++;
	}
	++$total;
}

sub add_physical_ports {
	my ( $self, $devtypid, $type ) = @_;

	my $captype = $type;
	$captype =~ tr/a-z/A-Z/;

	my $cgi = $self->cgi || die "Could not create cgi";
	my $dbh = $self->dbh || die "Could not create dbh";

	my $prefix   = $self->cgi_parse_param("${captype}_PORT_PREFIX");
	my $start    = $self->cgi_parse_param("${captype}_INTERFACE_PORT_START");
	my $count    = $self->cgi_parse_param("${captype}_INTERFACE_PORT_COUNT");
	my $tcp      = $self->cgi_parse_param("${captype}_TCP_PORT_START");
	my $purpose  = $self->cgi_parse_param("${captype}_PORT_PURPOSE");
	my $speed    = $self->cgi_parse_param("${captype}_PORT_SPEED");
	my $protocol = $self->cgi_parse_param("${captype}_PORT_PROTOCOL");
	my $medium   = $self->cgi_parse_param("${captype}_PORT_MEDIUM");
	my $plug     = $self->cgi_parse_param("${captype}_PORT_PLUG_STYLE");

	if ( !defined($count) ) {
		$self->error_return("You must specify the number of $type ports");
	}

	if ( !defined($start) && $count ne 1 ) {
		$self->error_return(
			"You must specify one $type port or a starting number");
	}

	if ( defined($start) && ( $start !~ /^\d+$/ || $start < 0 ) ) {
		$self->error_return("Starting $type port must be a positive number");
	}
	if ( $count !~ /^\d+$/ || $count <= 0 ) {
		$self->error_return("$type Port count must be a positive number");
	}

	if ( $prefix && length($prefix) > 50 ) {
		$self->error_return("$type prefix must be no more than 180 characters");
	}

	if ( $purpose && length($purpose) > 50 ) {
		$self->error_return("$type prefix must be no more than 180 characters");
	}

	my $q = qq{
		insert into     device_type_phys_port_templt (
			device_type_id, port_name, port_type,
			port_plug_style, port_medium, port_protocol, port_speed,
			port_purpose, tcp_port
		) values (
			:typeid, :name, :porttype,
			:plug, :medium, :protocol, :speed,
			:purpose, :tcpport
		)
	};
	my $sth = $dbh->prepare($q) || $self->return_db_err($dbh);

	my $total = 0;
	if ( defined($start) ) {
		for ( my $i = $start ; $i < $start + $count ; $i++ ) {
			my $portname = $i;
			if ( defined($prefix) ) {
				$portname = "$prefix$i";
			}
			$sth->bind_param( ':typeid', $devtypid )
			  || $self->return_db_err($dbh);
			$sth->bind_param( ':name', $portname )
			  || $self->return_db_err($dbh);
			$sth->bind_param( ':porttype', $type )
			  || $self->return_db_err($dbh);
			$sth->bind_param( ':plug', $plug )
			  || $self->return_db_err($dbh);
			$sth->bind_param( ':medium', $medium )
			  || $self->return_db_err($dbh);
			$sth->bind_param( ':protocol', $protocol )
			  || $self->return_db_err($dbh);
			$sth->bind_param( ':speed', $speed )
			  || $self->return_db_err($dbh);
			$sth->bind_param( ':purpose', $purpose )
			  || $self->return_db_err($dbh);

			if ($tcp) {
				$sth->bind_param( ':tcpport', $tcp + ( $i - $start ) )
				  || $self->return_db_err($dbh);
			} else {
				$sth->bind_param( ':tcpport', undef )
				  || $self->return_db_err($dbh);
			}
			$sth->execute || $self->return_db_err($dbh);
			$total++;
		}
	} else {
		my $portname = $prefix;
		$sth->bind_param( ':typeid', $devtypid )
		  || $self->return_db_err($dbh);
		$sth->bind_param( ':name', $portname )
		  || $self->return_db_err($dbh);
		$sth->bind_param( ':porttype', $type )
		  || $self->return_db_err($dbh);
		$sth->bind_param( ':plug', $plug )
		  || $self->return_db_err($dbh);
		$sth->bind_param( ':medium', $medium )
		  || $self->return_db_err($dbh);
		$sth->bind_param( ':protocol', $protocol )
		  || $self->return_db_err($dbh);
		$sth->bind_param( ':speed', $speed )
		  || $self->return_db_err($dbh);
		$sth->bind_param( ':purpose', $purpose )
		  || $self->return_db_err($dbh);

		if ($tcp) {
			$sth->bind_param( ':tcpport', $tcp )
			  || $self->return_db_err($dbh);
		} else {
			$sth->bind_param( ':tcpport', undef )
			  || $self->return_db_err($dbh);
		}
		$sth->execute || $self->return_db_err($dbh);
		$total++;
	}
	$total;
}

sub validate_ip {
	my ( $self, $ip ) = @_;

	my $i = new NetAddr::IP($ip) || return 0;
	return $i->version();
}

#
# given a jazzhands company name, return a link to the logo for said company
#
sub vendor_logo {
	my ( $self, $vendor ) = @_;
	my $cgi = $self->cgi || die "Could not create cgi";

	my %ICOMAP = (
		'Dot Hill',         'dothill.ico', 'Cisco',            'cisco.ico',
		'Foundry',          'foundry.ico', 'Dell',             'dell.ico',
		'Force10 Networks', 'force10.ico', 'IBM',              'ibm.ico',
		'HP',               'hp.ico',      'Sun Microsystems', 'sun.ico',
		'Juniper',          'juniper.ico',
	);

	my $root = $self->guess_stab_root;

	my $rv = "";
	if ( $vendor && exists( $ICOMAP{$vendor} ) && $ICOMAP{$vendor} ) {
		$rv = $cgi->img(
			{
				-alt   => $vendor,
				-align => 'left',
				-src   => $root . '/images/vendors/' . $ICOMAP{$vendor}
			}
		);
	}
	$rv;
}

#
# process new references to this record.
#
sub process_dns_ref_add($$$$) {
	my ( $self, $recupdid, $refid ) = @_;

	my $cgi        = $self->cgi || die "Could not create cgi";
	my $numchanges = 0;

	my $p        = 'dnsref_';
	my $s        = "_dnsref_${recupdid}";
	my $name     = $self->cgi_parse_param( "${p}DNS_NAME${s}", $refid );
	my $type     = $self->cgi_parse_param( "${p}DNS_TYPE${s}", $refid );
	my $refdomid = $self->cgi_parse_param( "${p}DNS_DOMAIN_ID${s}", $refid );

	my $new = {
		dns_name            => $name,
		dns_domain_id       => $refdomid,
		dns_type            => $type,
		dns_value_record_id => $recupdid,
		should_generate_ptr => 'N',
	};

	$numchanges += $self->process_and_insert_dns_record($new);
}

# Process recordds that refer to this one.
sub process_dns_ref_updates($$$$) {
	my ( $self, $recupdid, $refid ) = @_;

	my $cgi        = $self->cgi || die "Could not create cgi";
	my $numchanges = 0;

	my $p        = 'dnsref_';
	my $s        = "_dnsref_${recupdid}";
	my $name     = $self->cgi_parse_param( "${p}DNS_NAME${s}", $refid );
	my $type     = $self->cgi_parse_param( "${p}DNS_TYPE${s}", $refid );
	my $refdomid = $self->cgi_parse_param( "${p}DNS_DOMAIN_ID${s}", $refid );

	my $new = {
		dns_record_id       => $refid,
		dns_name            => $name,
		dns_type            => $type,
		dns_domain_id       => $refdomid,
		dns_value_record_id => $recupdid,
		should_generate_ptr => 'N',
	};

	$numchanges += $self->process_and_update_dns_record($new);
}

sub process_and_update_dns_record {
	my ( $self, $opts, $ttlonly ) = @_;

	$opts = _dbx( $opts, 'lower' );

	$opts->{'is_enabled'} = 'Y' if ( !defined( $opts->{'is_enabled'} ) );

	my $orig = $self->get_dns_record_from_id( $opts->{'dns_record_id'} );

	if ( !exists( $opts->{'dns_ttl'} ) ) {
		$opts->{'dns_ttl'} = $orig->{ _dbx('DNS_TTL') };
	} elsif ( !length( $opts->{'dns_ttl'} ) ) {
		$opts->{'dns_ttl'} = undef;
	}

	my $newrecord;

	# ttlonly applies only to A/AAAA records anchored to hosts
	if ($ttlonly) {
		$newrecord = {
			DNS_RECORD_ID       => $opts->{'dns_record_id'},
			DNS_TTL             => $opts->{'dns_ttl'},
			IS_ENABLED          => $opts->{'is_enabled'},
			SHOULD_GENERATE_PTR => $opts->{'should_generate_ptr'},
		};
	} else {
		$newrecord = {
			DNS_RECORD_ID       => $opts->{'dns_record_id'},
			DNS_TTL             => $opts->{'dns_ttl'},
			DNS_NAME            => $opts->{'dns_name'},
			DNS_VALUE           => $opts->{'dns_value'},
			DNS_TYPE            => $opts->{'dns_type'},
			IS_ENABLED          => $opts->{'is_enabled'},
			SHOULD_GENERATE_PTR => $opts->{'should_generate_ptr'},
			DNS_PRIORITY        => $opts->{'dns_priority'},
			DNS_SRV_SERVICE     => $opts->{'dns_srv_service'},
			DNS_SRV_PROTOCOl    => $opts->{'dns_srv_protocol'},
			DNS_SRV_WEIGHT      => $opts->{'dns_srv_weight'},
			DNS_SRV_PORT        => $opts->{'dns_srv_port'},
			DNS_VALUE_RECORD_ID => $opts->{'dns_value_record_id'},
		};
	}
	if ( defined( $opts->{class} ) ) {
		$newrecord->{'DNS_CLASS'} = $opts->{dns_class};
	}

	# This is used for dns references
	if ( defined( $opts->{dns_domain_id} ) ) {
		$newrecord->{'DNS_DOMAIN_ID'} = $opts->{dns_domain_id};
	}

	$newrecord = _dbx( $newrecord, 'lower' );

	# On update:
	#	Only pay attention to if the new type is A or AAAA.
	#	If it is set to 'Y', then set it to 'Y' and change all other
	#		records to the same netblock to 'N'.
	#	If it a type change, and set to 'N', then check to see if there
	#		is already a record with PTR.  If there is already, then set
	#		to 'N'.
	#	If it is not a type change, then just obey what it was set to.
	#
	if (   $opts->{should_generate_ptr}
		&& $opts->{'dns_type'} =~ /^A(AAA)?$/ )
	{
		if ( $opts->{should_generate_ptr} eq 'Y' ) {
			$newrecord->{'should_generate_ptr'} = $opts->{should_generate_ptr};
		} elsif ( $orig->{'dns_type'} ne $opts->{'dns_type'} ) {
			if (   !$opts->{dns_value_record_id}
				&& !$self->get_dns_a_record_for_ptr( $opts->{'dns_value'} ) )
			{
				$newrecord->{'should_generate_ptr'} = 'Y';
			} else {
				$newrecord->{'should_generate_ptr'} =
				  $opts->{should_generate_ptr};
			}
		} else {
			$newrecord->{'should_generate_ptr'} = $opts->{should_generate_ptr};
		}

		if ( $opts->{should_generate_ptr} eq 'Y' ) {

			# Get the dns record having the ptr
			my $recid = $self->get_dns_a_record_for_ptr( $opts->{'dns_value'} );

			# If there is one, and if it's different than the current record, set ptr = 'N'
			if ( $recid && $recid != $orig->{'dns_record_id'} ) {
				$self->run_update_from_hash( "DNS_RECORD",
					"DNS_RECORD_ID", $recid, { should_generate_ptr => 'N' } );
			}
		}
	}

	# Wildcard dns records must not have the PTR set
	if( $opts->{dns_name} =~ /\*/ ) {
		$newrecord->{'should_generate_ptr'} = 'N';
	}

	my $nblkid;
	if (   defined( $opts->{dns_value} )
		&& defined( $opts->{dns_value_record_id} ) )
	{
		$self->error_return("Must not specify a reference and Value");
	}

	# if the new type is A/AAAA then find the netblock and create if it
	# does not exist.
	# Creation should only happen on a change.
	if ( $opts->{'dns_type'} =~ /^A(AAA)?/ && !$opts->{dns_value_record_id} ) {
		if (   $opts->{'dns_value'} !~ /^(\d+\.){3}\d+/
			&& $opts->{'dns_type'} eq 'A' )
		{
			$self->error_return(
				"$opts->{'dns_value'} is not a valid IPv4 address");
		} elsif ( $opts->{'dns_value'} !~ /^[A-Z0-9:]+$/i
			&& $opts->{'dns_type'} eq 'AAAA' )
		{
			$self->error_return(
				"$opts->{'dns_value'} is not a valid IPv6 address");
		}

		my $block =
		  $self->get_netblock_from_ip( ip_address => $opts->{'dns_value'} );
		if ( !$block ) {
			$block = $self->get_netblock_from_ip(
				ip_address    => $opts->{'dns_value'},
				netblock_type => 'dns'
			);
		}
		if ( !defined($block) ) {
			my $h = {
				ip_address        => $opts->{'dns_value'},
				is_single_address => 'Y'
			};
			if (
				!(
					my $par =
					$self->guess_parent_netblock_id( $opts->{'dns_value'} )
				)
			  )
			{
				# XXX This is outside our IP universe,
				# which we should probably print a warning
				# on, but lacking that, it gets created as a
				# type dns
				$h->{netblock_type} = 'dns';
			}
			$nblkid = $self->add_netblock($h)
			  || die $self->return_db_err();
		} else {
			$nblkid = $block->{ _dbx('NETBLOCK_ID') };
		}
	}

	# if changing from A/AAAA or back then just swap out the netblock id and don't set the
	# value
	if (   $orig->{ _dbx('DNS_TYPE') } =~ /^A(AAA)?/
		&& $opts->{dns_type} =~ /^A(AAA)?/ )
	{
		$newrecord->{ _dbx('DNS_VALUE') }   = undef;
		$newrecord->{ _dbx('NETBLOCK_ID') } = $nblkid;
	} elsif ( $orig->{ _dbx('DNS_TYPE') } =~ /^A(AAA)?/
		&& $opts->{dns_type} !~ /^A(AAA)?/ )
	{
		$newrecord->{ _dbx('DNS_VALUE') }   = $opts->{dns_value};
		$newrecord->{ _dbx('NETBLOCK_ID') } = undef;
	} elsif ( $orig->{ _dbx('DNS_TYPE') } !~ /^A(AAA)?/
		&& $opts->{dns_type} =~ /^A(AAA)?/ )
	{
		$newrecord->{ _dbx('DNS_VALUE') }   = undef;
		$newrecord->{ _dbx('NETBLOCK_ID') } = $nblkid;
	}

	my $diffs = $self->hash_table_diff( $orig, _dbx($newrecord) );
	my $tally = keys %$diffs;
	if ( !$tally ) {
		return 0;
	} elsif (
		!$self->run_update_from_hash(
			"DNS_RECORD", "DNS_RECORD_ID", $orig->{dns_record_id}, $diffs
		)
	  )
	{
		$self->rollback;
		$self->return_db_err();
	}
	#
	# XXX -- NEED TO TRY TO REMOVE OLD NETBLOCK BUT NOT FAIL IF IT FAILS!
	#
	#
	return $tally;
}

sub DESTROY {
	my $self = shift;
	my $dbh  = $self->dbh;

	if ( $self->{_JazzHandsSth} ) {
		foreach my $q ( keys( %{ $self->{_JazzHandsSth} } ) ) {
			if ( defined( $self->{_JazzHandsSth}->{$q} ) ) {
				$self->{_JazzHandsSth}->{$q}->finish;
			}
			delete( $self->{_JazzHandsSth}->{$q} );
		}
		delete( $self->{_JazzHandsSth} );
	}

	if (0) {    # XXX
		if ( defined($dbh) && $dbh->ping ) {
			my $x = join( "\n", $dbh->func('dbms_output_get') );
			print STDERR $x, "\n"
			  if ( $self->{_debug} && $x && length($x) );
		}
	}
	if ( defined($dbh) ) {
		$dbh->rollback;
		$dbh->ping;
		$dbh->disconnect;
		$self->{dbh} = undef;
	}
}

1;
__END__

=head1 NAME

JazzHands::STAB - Perl extension for common code in JazzHands STAB

=head1 SYNOPSIS

  use JazzHands::STAB;

  my $stab = new JazzHands::STAB(dbh=> $dbh, cgi => $cgi, dbuser => $dbauthapp);

  $stab->start_html;

  $stab->build_passback_url(errmsg => $errmsg, notemsg=> $notemsg,
	refurl => $refurl, devlist = $devlist, nopreserveargs => no);

  $stab->cgi($cgi);

  $stab->dbh($dbh);

  $stab->return_db_err($dbobj, $optionaltext);

  $stab->error_return($msg, $url, $success);

  $stab->msg_return($msg, $url, $success);

  $stab->cgi_get_ids($key);

  $stab->cgi_parse_param($param, $key);

  $stab->chk_yn($value, $allowundef);

  $stab->hash_table_diff($hash1ref, $hash2ref);

  $stab->build_update_sth_from_hash($table, $dbkey, $keyval, $hashref);

  $stab->int_mac_from_text($mac);

  $stab->b_dropdown($valueref, $field, $pkeyfield, $noguessunknown);

  $stab->textfield_sizing($should);

  $stab->b_textfield($valueref, $field, $pkeyfield

  $stab->build_tr($values, $callback, $header, $field, $pkeyfield);

  $stab->check_if_sure($msg);

  $stab->remove_other_flagged($oldh, $newh, $table, $pkey, $reckey, $field, $human);

  $stab->guess_stab_root;

  $stab->parse_netblock_search($bycidr);

=head1 DESCRIPTION

This documentation is incomplete.

Code sharing point for the STAB system for management of devices and
device related info.  Generally speaking, only stab uses this, but it's
always good to document.

new returns a new object tat can be used to call all the other functions.
The only way to access any of the container functions is to call new and
run with it.  If called with no options, an attempt will be made to
use JazzHands::DBI to obtain a connection to the database for user 'stab'.

start_html prints out header information, including favorite icons, and
including some standard java script.  It also prints the top level title
and a navigation bar.  There is a mechanism to pass notes and errors
(notes appear in green and errors in red, under the nav bar).  This is the
typical way STAB application returns errors to the user.

start_html either takes a title as a single option.  If multiple
options, or a hash are passed in, then it's assumed to be standard style
arguments as follows: title sets the title. noinlinetitle will cause a
title to not be printed on the top of the page that matches the title
bar.  noinlinenavbar says to not print a navigation bar, and nolinlinemsgs
causes no error messages/notes to be printed.

build_passback_url is primarily an internal function used by other routines,
but takes errmsg and notemsg and constructs a url that passes those strings
as parameters to another stab page.  This is normally the referer page,
but that can be overridden by the refurl argument.  devlist is used to
set the devlist flag (this is primarily used to pass the values of a search
back to a search; it should probably be genericified).  nopreservearg
causes none of the arguments of the current page to be preserved.  Normally,
all the args are passed back so forms are properly filled in.  This is
normally used in the case of 'success', when the calling page is a form.

cgi and dbh are used to get and set the CGI and DBI::dbh values stored
inside the STAB structure.

return_db_err returns the error associated with a db object (dbh or sth)
by printing a cgi redirect.

error_return sends an error message back to an optional url (defaults to
the cgi referer).  I takes 'success' as an optional target, which if set
will cause the return to not pass any arguments.  (see build_passback_url).
Error messages are generally messages printed in red.

msg_return operates like error_return, except passes back messages that
will appear in Green (like "success!").

cgi_get_ids when called in a scalar context will return the first
parameter ("first" is not defined) that matches a given pararmeter
with a numeric id.  For example, if given DEVICE_ID, and there's a cgi
parameter DEVICE_ID_123 set to 123, it will return 123.  In an array
context, it will return all devices that have a numeric suffix with a
value set to this suffix.  This allows for more complicated web forms, and
is not presently in use.

cgi_parse_param finds the parameter associated with a given key.  If key is
not set, then it will just look for the paremeter.  If the parmeter is not
set to anything, set to an empty string, or set to __unknown__, then it will
be set to undef.

mk_chk_yn takes a check box value and returns "Y" or "N", as appropriate

hash_table_diff takes two hashes and returns a hash that contains values
that are different in the second hash.  If it's not set in the second
hash, it's not considered, so you can't set things to NULL that were
previously set to something.  This should probably change using 'exists'
instead of 'defined.'

build_update_sth_from_hash tags a table name (table), the field that has
a key (dbkey), the value for that key in a table (keyval) and a hash
reference (similar to what $sth->fetchrow_hashref might return) that
contains all the fields and constructs a query that will update only
those values that are in the hash reference.  This is used in conjunction
with hash_table_diff.

int_mac_from_text, given a mac in either colon seperated, or period
seperate (cisco style) will return the numeric value of that mac.  It
does this through oracle since the host OS might not support 64 bit
integers.  If an invalid mac is passed in, the function returns undef.

b_dropdown returns a dropdown menu based on a given field.  It will
use the pkeyfield value to build the name value for the drop down by
extracting it from values. it will also set the default value based on
the hash values.  If noguessunknown is not set, it will try to find a
value with "unknown" in it and make that the default if it's not set. If
that value is set, or no "unknown" value can be found, it will print
"Please Select."

b_textfield returns a textfield  with a name based on the pkeyfield
in hash reference $values.  $field is used as the default if it's set.
It will make a reasonable guess at sizings, though the textfield_sizing

textfield_sizing takes an argument (undef or something) and that defines
whether or not b_textfield will attempt to make a guess at sizing

build_tr builds a table (CGI Tr) and returns it using callback.
Callback is b_dropdown or b_textfield. it prints a label next to the
callback.

check_if_sure is used to throw up an "are you sure" page maipulating cgi
parameters

remove_other_flagged is used to remove all the other flags associated with
an element, if they're set, unless the flag is already set on the element.
$oldh is a hash of columns with their values, and if column $field is
set for all other rows of column $pkey, except for column $reckey,
they will all be set to 'N'.  If nothing is changed undef is returned.
If something is changed, "$human updated" is returned, unless $human is not
defined, in which case "$field updated" is returned.

guess_stab_root looks at the called URL and makes a best guess at where the
root of the stab tree is.  This is primarily used for icons and other
things in the stab tree, and also largely for development purposes.

parse_netblock_search takes an ip address, checks it and returns the
netblock, or an error condition (to the calling page).  This is used in the
search-for-a-netblock page.

=head1 SEE ALSO

JazzHands::DBI, JazzHands::STAB::DBAccess

=head1 AUTHOR

Todd Kover

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Todd Kover

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.


=cut
