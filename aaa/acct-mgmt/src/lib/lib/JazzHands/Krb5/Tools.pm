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

package JazzHands::Krb5::Tools;

use 5.006;
use strict;
use warnings;
use Authen::Krb5;
use Authen::Krb5::Admin qw(:constants);

BEGIN {
	use Exporter ();
	our ( $VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS );

	$VERSION     = 1.00;
	@ISA         = qw(Exporter);
	@EXPORT      = qw();
	%EXPORT_TAGS = ();
	@EXPORT_OK   = ();

}
our @EXPORT_OK;

my $DefaultRealm  = "EXAMPLE.COM";
my $AdminPrinc    = "acct-mgmt";
my $DefaultExpire = 90 * 86400;      # 90 days

# eval this, since if it's already initialized, it will error

eval { Authen::Krb5::init_context(); };

sub _options {
	my %ret = @_;
	for my $v ( grep { /^-/ } keys %ret ) {
		$ret{ substr( $v, 1 ) } = $ret{$v};
	}
	\%ret;
}

sub Error {
	my $self = shift;

	if (@_) { $self->{_error} = shift }
	return $self->{_error};
}

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $opt   = &_options;

	my $realm = $opt->{realm} || $DefaultRealm;
	my $cc = "MEMORY:admin";

	if ( !$opt->{user} ) {
		return "Must give a user to bind with";
	}
	my $kadm;
	my $kconfig;
	$kconfig = new Authen::Krb5::Admin::Config();
	if ( !$kconfig ) {
		return "Unable to create Authen::Krb5::Admin::Config object";
	}
	$kconfig->realm($realm);
	if ( $opt->{keytab} ) {
		$kadm =
		  Authen::Krb5::Admin->init_with_skey( $opt->{user},
			$opt->{keytab}, KADM5_ADMIN_SERVICE, $kconfig ) ;
	} elsif ( $opt->{password} ) {
		  $kadm =
		    Authen::Krb5::Admin->init_with_password( $opt->{user},
			  $opt->{password}, KADM5_ADMIN_SERVICE, $kconfig ) ;
	} else {
		  return "Must provide either a password or a keytab";
	}
	if ( !$kadm ) {
		  return sprintf( "Unable to get kadmin handle: %s",
			  Authen::Krb5::Admin::error );
	}

	my $self = {};
	$self->{kadm} = $kadm;

	bless $self, $proto;
}

sub GetTicket {
	  my $self    = shift;
	  my $opt     = &_options(@_);
	  my $success = undef;
	  my $cc      = "MEMORY:";
	  my $realm   = $opt->{realm} || $DefaultRealm;

	  if ( !$opt->{user} ) {
		  return ("User must be specified");
		  goto BAIL;
	  }
	  if ( !$opt->{password} ) {
		  return ("Password must be specified");
		  goto BAIL;
	  }
	  if ( $opt->{realm} ) {
		  $opt->{user} .= '@' . $opt->{realm};
	  }
	  if ( !$opt->{ccname} ) {
		  $opt->{ccname} = "default";
	  }
	  $cc .= $opt->{ccname};

	  my $ccache = Authen::Krb5::cc_resolve($cc);
	  if ( !defined($ccache) ) {
		  return (
"Unable to establish Kerberos credentials cache to check password"
		  );
	  }

	  my $client = Authen::Krb5::parse_name( $opt->{user} . '@' . $realm );

	  if ( !$client ) {
		  return ( "Unable to construct client principal for "
			    . $opt->{user} );
	  }

	  my $service =
	    Authen::Krb5::parse_name( "krbtgt/" . $realm . '@' . $realm );

	  if ( !$service ) {
		  return (
"Unable to construct service principal for password verification"
		  );
	  }

	  my $code = Authen::Krb5::get_in_tkt_with_password( $client,
		  $service, $opt->{password}, $ccache );

	  if ( !defined($code) ) {
		  my $msg = Authen::Krb5::error();
		  if ( $msg eq 'Decrypt integrity check failed' ) {
			  return ("Password is incorrect");
		  }
		  if ( $msg eq 'Client not found in Kerberos database' ) {
			  return ("You do not have a Kerberos principal.");
		  }
		  return ($msg);
	  }

	  return 0;
}

sub SetPassword {
	  my $self    = shift;
	  my $opt     = &_options(@_);
	  my $success = undef;

	  if ( !$opt->{user} ) {
		  $self->Error("User must be specified");
		  goto BAIL;
	  }
	  if ( !$opt->{password} ) {
		  $self->Error("Password must be specified");
		  goto BAIL;
	  }
	  my $expire;
	  if ( $opt->{expiretime} ) {
		  $expire = $opt->{expiretime};
	  } else {
		  $expire = time() + $DefaultExpire;
	  }

	  #
	  # So what we're doing here is that if the principal doesn't exist
	  # that we're changing the password for, we create the principal,
	  # since there should be a principal for every account that would
	  # be passed in this way without any exceptions.
	  #
	  my $kadm;
	  if ( !( $kadm = $self->{kadm} ) ) {
		  $self->Error("Invalid kadm handle");
		  goto BAIL;
	  }

	  #
	  # Does principal exist?
	  #
	  my $pname = Authen::Krb5::parse_name( $opt->{user} );
	  my $princ = $kadm->get_principal( $pname,
		  KADM5_PRINCIPAL_NORMAL_MASK | KADM5_KEY_DATA );
	  if ( !$princ ) {

		  #
		  # principal doesn't exist, create one
		  #
		  if ( !( $princ = Authen::Krb5::Admin::Principal->new ) ) {
			  $self->Error( "Unable to create a new principal for "
				    . $opt->{user} . ": "
				    . Authen::Krb5::Admin::error );
			  goto BAIL;
		  }
		  $princ->principal($pname);
		  $princ->kvno(2);
		  if ( !$kadm->create_principal( $princ, $opt->{password} ) ) {
			  $self->Error( "Unable to create a new principal for "
				    . $opt->{user} . ": "
				    . Authen::Krb5::Admin::error );
			  goto BAIL;
		  }
	  } else {

		  #
		  # principal does exist, change the password
		  #
		  if ( !$kadm->chpass_principal( $pname, $opt->{password} ) ) {
			  $self->Error( "Unable to change password for "
				    . $opt->{user} . ": "
				    . Authen::Krb5::Admin::error );
			  goto BAIL;
		  }
	  }
	  $princ->pw_expiration($expire);
	  if ( !$kadm->modify_principal($princ) ) {
		  $self->Error( "Unable to set password expiration for "
			    . $opt->{user} . ": "
			    . Authen::Krb5::Admin::error );
		  goto BAIL;
	  }
	  $success = 1;
	BAIL:
	  return $success;
}
