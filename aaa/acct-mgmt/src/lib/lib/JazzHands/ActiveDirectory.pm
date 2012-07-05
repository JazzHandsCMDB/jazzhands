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

package JazzHands::ActiveDirectory;

use strict;
use warnings;
use base 'Net::LDAP';
use Net::LDAP::Entry;
use Net::DNS;
use JazzHands::AppAuthAL;
use IO::Socket;
use Authen::Krb5;

my $DefaultDomain  = "ad.example.com";
my $ksetpw_command = "/usr/local/sbin/ksetpw";
my @msdatefields   = ( "pwdlastset", "lastlogon" );
my @mstimestamps   = ( "whencreated", "whenchanged" );
my $companyparms   = {
	"" => {
		mdb     => "EXCHANGE1/SG1/MS1-SG1 (EXCHANGE1)",
		homedir => '\\\\fileserver.ad.example.com\\homedir$\\',
	},
};

foreach my $company ( values %$companyparms ) {
	next if !$company->{mdb};
	my ( $mailsrvname, $mailsg, $maildb ) = split '/', $company->{mdb};
	$company->{homemta} =
"CN=Microsoft MTA,CN=${mailsrvname},CN=Servers,CN=First Administrative Group,CN=Administrative Groups,CN=My Company,CN=Microsoft Exchange,CN=Services,CN=Configuration,DC=ad,DC=example,DC=net";
	$company->{homemdb} =
"CN=${maildb},CN=${mailsg},CN=InformationStore,CN=${mailsrvname},CN=Servers,CN=First Administrative Group,CN=Administrative Groups,CN=My Company,CN=Microsoft Exchange,CN=Services,CN=Configuration,DC=ad,DC=example,DC=com";
	$company->{homesrvname} =
"/o=My Company/ou=First Administrative Group/cn=Configuration/cn=Servers/cn=${mailsrvname}";
}

sub _options {
	my %ret = @_;
	for my $v ( grep { /^-/ } keys %ret ) {
		$ret{ substr( $v, 1 ) } = $ret{$v};
	}
	\%ret;
}

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $opt   = &_options;

      #
      # First, we need to find out where the LDAP server is for the domain we're
      # interested in
      #
	my @servers;
	my $self;
	my (
		$username, $password, $server,  $domain,
		$krbuser,  $krbrealm, $company, $tmprealm
	);

	#
	# user specified the authfile
	#
	my $authfile = $opt->{authfile} || "ActiveDirectory";

	my $dbauthal_conf = JazzHands::AppAuthAL::find_and_parse_auth($authfile,'', 'AD');
	my %dbauthal = %$dbauthal_conf;

	#
	# Use defaults if available
	#
	$username = $dbauthal{Username} if $dbauthal{Username};
	$password = $dbauthal{Password} if $dbauthal{Password};
	$domain = $dbauthal{Domain} || $DefaultDomain;
	$server = $dbauthal{ServerName} if $dbauthal{ServerName};
	my $tls = $dbauthal{tls} or warn "No tls option for the connection to AD\n";
	$krbrealm =
	  $dbauthal{KrbRealm} ? uc( $dbauthal{KrbRealm} ) : uc($domain);

	$domain   = $opt->{domain}         if $opt->{domain};
	$username = $opt->{username}       if $opt->{username};
	$password = $opt->{password}       if $opt->{password};
	$company  = $opt->{company}        if $opt->{company};
	$server   = $opt->{server}         if $opt->{server};
	$krbrealm = uc( $opt->{krbrealm} ) if $opt->{krbrealm};

	return "No username available" if !$username;

	( $krbuser, $tmprealm ) = $username =~ /(.*)\@(.*)/;
	if ($tmprealm) {
		$krbrealm = uc($tmprealm);
	} else {
		$krbuser = $username;
	}

	if ( !$server ) {
		my $res         = Net::DNS::Resolver->new;
		my $querystring = "_ldap._tcp." . $domain;
		my $packet      = $res->query( $querystring, "SRV" );
		my $answer;

		if ( !$packet ) {
			warn $res->errorstring;
			return
"Unable to find LDAP server while querying '$querystring'\n";
		}

		foreach $answer ( $packet->answer ) {
			next if ( $answer->type ne "SRV" );

			#
			# This is a hack.
			# XXX need to have a way to ignore certain
			# servers due do network stupidity (such as if
			# some DC is in a far off site).
			#
			#next
			#  if (     ( $answer->target !~ /^va-dc/ )
			#	|| ( $answer->target =~ /va-dc4\./ ) );
			push @servers, $answer->target;
		}
		if ( !@servers ) {
			return "No servers found for '$querystring'\n";
		}
	} else {
		push( @servers, split( /,/, $server ) );
	}


	if ( !defined( $self = $class->SUPER::new( \@servers, timeout => 10) ) ) {
		return
		  "Unable to open connection to LDAP hosts: "
		  . join( ', ', @servers ) . "\n";
	}
	my $mesg = $self->start_tls( %$tls ); 
	if($mesg->code){ die "Cannot issue STARTTLS command $!\n" . $mesg->error }

	$self->{domain}   = $domain;
	$self->{krbrealm} = uc($domain);

	$self->{searchbase} = "dc=" . join( ",dc=", split( /\./, $domain ) );

	$mesg = $self->bind( $username, password => $password );
	if ( $mesg->is_error ) {
		return $mesg->error_text;
	}

       #
       # This is what we call 'really fucking lame'.  In order to actually
       # activate the account, we have to connect to a domain controller with
       # LDAP and create the account, then we have to connect to the *SAME DC*
       # and set the password using Kerberos.  Since the Kerberos API has no
       # mechanism to specify exactly which server we want to change the
       # password on, we have to create a fake krb5.conf and set the KRB5_CONFIG
       # environment variable to point to it.  I can pretty much guarantee
       # that this will spew chunks under mod_perl.
       #
	my $ipaddr = inet_ntoa( ( sockaddr_in( $self->socket->peername ) )[1] );

	my $counter    = 0;
	my $k5confbase = "/tmp/krb5.conf.ad.$$.";
	while ( -f $k5confbase . $counter ) {
		$counter++;
	}
	my $k5conf = $k5confbase . $counter;

	if ( !open( KRB5CONF, ">$k5conf" ) ) {
		goto krb5done;
	}
	printf KRB5CONF qq/
[libdefaults]
	default_tkt_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 des3-cbc-sha1 arcfour-hmac-md5 des-cbc-crc des-cbc-md5 des-cbc-md4
	default_tgs_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 des3-cbc-sha1 arcfour-hmac-md5 des-cbc-crc des-cbc-md5 des-cbc-md4

[realms]
	%s = {
		kpasswd_server = %s
		admin_server = %s
	}
/, $self->{krbrealm}, $ipaddr, $ipaddr;
	close KRB5CONF;

	$ENV{KRB5_CONFIG} = $k5conf;
	$self->{krb5conf} = $k5conf;

	#
	# only call init_context when not called already
	#
	if ( !defined( Authen::Krb5::get_default_realm() ) ) {
		Authen::Krb5::init_context();
	}

	#
	# i suspect that i would be better off using MEMORY: as the
	# the cache target to avoid leaving junk files lying around.
	#
	# also, setting a ENV variable is kinda rude.  there may be
	# unintended side affects later on.
	#
	# i am not brave enough to make either of these changes.
	#
	my $krb = {};
	$self->{_krb} = $krb;
	$counter = 0;
	my $ccbase = "/tmp/krb5.ccache.ad.$$.";
	while ( -f $ccbase . $counter ) {
		$counter++;
	}
	my $ccname = "FILE:" . $ccbase . $counter;
	$ENV{KRB5CCNAME} = $ccname;
	my $cc = Authen::Krb5::cc_resolve($ccname);
	my $princ =
	  Authen::Krb5::parse_name( $krbuser . '@' . $self->{krbrealm} );

	# Ubuntu 8.04.4 did not like this at all.  Caused it to fail.  Need
	# to discern if we want to do this at all (such as when tls is not
	# going on) or just require tls/ldaps
	if(0) {
		# $cc->initialize($princ) || die;

		if (
			!Authen::Krb5::get_in_tkt_with_password(
				$princ,
				Authen::Krb5::parse_name(
				    	"krbtgt/"
				  	. $self->{krbrealm} . '@'
				  	. uc( $self->{domain} )
				),
				$password,
				$cc
			)
	  	)
		{
			$cc->destroy;
		} else {
			$krb->{cc} = $cc;
		}
	}
      krb5done:

	bless( $self, $class );
}

sub GetUserByUsername {
	my $self = shift;
	my $user = shift;

	return undef if !$user;
	my $mesg = $self->search(
		base   => $self->{searchbase},
		filter => "(sAMAccountName=$user)",
		attrs  => ['1.1']
	);

	if ( $mesg->is_error ) {
		return undef;
	}

	if ( !( $mesg->count ) ) {
		return undef;
	}

	if ( !( my $entry = $mesg->pop_entry() ) ) {
		return undef;
	} else {
		return $entry->dn();
	}
}

sub GetHashByMatch {
	my $self   = shift;
	my $string = shift;
	my $attrs  = shift;
	my %attrs;

	if ($attrs) {
		$attrs{attrs} = $attrs;
	}

	return undef if !$string;
	my $mesg = $self->search(
		base => $self->{searchbase},
		filter =>
"(|(sAMAccountName=$string)(givenname=*$string*)(sn=*$string*))",
		%attrs
	);

	if ( $mesg->is_error ) {
		return undef;
	}

	if ( !( $mesg->count ) ) {
		return undef;
	}

	my $struct = $mesg->as_struct();
	if ( !$struct ) {
		return undef;
	}

	courtesy_conversions( $struct, $attrs );

	return $struct;
}

sub GetUserByUID {
	my $self = shift;
	my $uid  = shift;

	return undef if !$uid;
	my $mesg = $self->search(
		base   => $self->{searchbase},
		filter => "(jazzHandsSystemUserID=$uid)",
		attrs  => ['1.1']
	);

	if ( $mesg->is_error ) {
		return undef;
	}

	if ( !( $mesg->count ) ) {
		return undef;
	}

	if ( !( my $entry = $mesg->pop_entry() ) ) {
		return undef;
	} else {
		return $entry->dn();
	}
}

sub DecodeUserAccountControl {
	my $self = shift;
	my $uac  = shift;

	return _decode_user_account_control($uac);
}

sub _decode_user_account_control($) {
	my $uac = shift;
	return (  ( $uac & 0x02 ? 'DISABLED' : 'ENABLED' )
		. ( $uac & 0x20 ? '+PWDCHG' : '' ) );
}

sub GetHashByUID {
	my $self  = shift;
	my $uid   = shift;
	my $attrs = shift;
	my %attrs;

	if ($attrs) {
		$attrs{attrs} = $attrs;
	}

	return undef if !$uid;
	my $mesg = $self->search(
		base   => $self->{searchbase},
		filter => "(jazzHandsSystemUserID=$uid)",
		%attrs
	);

	if ( $mesg->is_error ) {
		return undef;
	}

	if ( !( $mesg->count ) ) {
		return undef;
	}

	my $struct = $mesg->as_struct();
	if ( !$struct ) {
		return undef;
	}

	courtesy_conversions( $struct, $attrs );

	return $struct;
}

sub ConvertFromMSDate {
	my $whack_ass_msoft_date = shift;
	return ( $whack_ass_msoft_date - 116444736000000000 ) / 10000000;
}

sub ConvertToMSDate {
	my $sane_date = shift;
	return ( $sane_date * 10000000 ) + 116444736000000000;
}

sub CreateUser {
	my $self = shift;
	my $opt  = &_options;

	#
	# Check for valid parameters.  All of thse first ones *MUST* be passed
	#
	if ( !$opt->{login} ) {
		return "Must specify username";
	}
	if ( !$opt->{ou} ) {
		return "Must specify OU";
	}
	if ( !$opt->{givenname} ) {
		return "Must specify GivenName";
	}
	if ( !$opt->{sn} ) {
		return "Must specify Surname (SN)";
	}
	if ( !$opt->{uid} ) {
		return "Must specify uid";
	}
	if ( !$opt->{password} ) {
		return "Must specify password";
	}
	if ( !$opt->{cn} ) {
		$opt->{cn} = $opt->{givenname} . " " . $opt->{sn};
	}
	if ( !defined( $opt->{company} ) ) {
		$opt->{company} = "";
	}

       #
       # Start building the entry.  All of these attributes are definitely going
       # to be present.
       #
	my $entry = Net::LDAP::Entry->new;

	my $dn = sprintf( "CN=%s,%s", $opt->{cn}, $opt->{ou} );
	$entry->dn($dn);

	$entry->add(
		objectClass       => [qw(top person organizationalPerson user)],
		sAMAccountName    => $opt->{login},
		cn                => $opt->{cn},
		userPrincipalName => $opt->{login} . "\@AD.EXAMPLE.COM",
		name              => $opt->{displayname}
		  || $opt->{cn},
		displayName => $opt->{displayname}
		  || $opt->{cn},
		sn                    => $opt->{sn},
		givenName             => $opt->{givenname},
		mail                  => $opt->{login} . "\@AD.EXAMPLE.COM",
		proxyAddresses =>
		  [ "SMTP:" . $opt->{login} . "\@ad.example.com", ],
		altSecurityIdentities => "Kerberos:"
		  . $opt->{login}
		  . "\@AD.EXAMPLE.COM",
		jazzHandsSystemUserID => $opt->{uid},
		homeDrive             => "Y:",
		homedirectory         => (
			     $companyparms->{ $opt->{company} }->{homedir}
			  || $companyparms->{""}->{homedir}
		  )
		  . $opt->{login},
		scriptPath => "logon.cmd",
#		mailNickname          => $opt->{login},
#		msExchALObjectVersion => 139,
#		msExchPoliciesIncluded =>
#"{8B508B43-0100-49F2-B4AD-7682AD9C6BC5},{26491CFC-9E50-4857-861B-0CB8DF22B5D7}",
#		homeMTA => (
#			     $companyparms->{ $opt->{company} }->{homemta}
#			  || $companyparms->{""}->{homemta}
#		),
#
#		homeMDB => (
#			     $companyparms->{ $opt->{company} }->{homemdb}
#			  || $companyparms->{""}->{homemdb}
#		),
#		msExchHomeServerName => (
#			     $companyparms->{ $opt->{company} }->{homesrvname}
#			  || $companyparms->{""}->{homesrvname}
#		),
#		showInAddressBook => [
#"CN=Default Global Address List,CN=All Global Address Lists,CN=Address Lists Container,CN=My Company,CN=Microsoft Exchange,CN=Services,CN=Configuration,DC=ad,DC=example,DC=com",
#"CN=All Users,CN=All Address Lists,CN=Address Lists Container,CN=My Company,CN=Microsoft Exchange,CN=Services,CN=Configuration,DC=ad,DC=example,DC=com"
#		],
#		legacyExchangeDN =>
#"/o=My Company/ou=First Administrative Group/cn=Recipients/cn="
#		  . $opt->{login},
#		textEncodedORAddress => sprintf(
#			"c=US;a= ;p=My Company;o=Exchange;s=%s;g=%s;",
#			$opt->{sn}, $opt->{givenname}
#		)
	);

	
	# If these optional parameters are passed, then shove them in as
	# well
	#
	if ( $opt->{title} ) {
		$entry->add( title => $opt->{title} );
	}
	if ( $opt->{department} ) {
		$entry->add( department => $opt->{department} );
	}
	if ( $opt->{company} ) {
		$entry->add( company => $opt->{company} );
	}
	if ( $opt->{location} ) {
		$entry->add( roomNumber => $opt->{location} );
	}
	if ( $opt->{city} ) {
		$entry->add( l => $opt->{city} );
	}
	if ( $opt->{state} ) {
		$entry->add( st => $opt->{state} );
	}
	if ( $opt->{country} ) {
		$entry->add( c => $opt->{country} );
	}
	if ( $opt->{address} ) {
		$entry->add( streetAddress => $opt->{address} );
	}
	if ( $opt->{postal_code} ) {
		$entry->add( postalCode => $opt->{postal_code} );
	}
	if ( $opt->{fax} ) {
		$entry->add( facsimileTelephoneNumber => $opt->{fax} );
	}
	if ( $opt->{mobile} ) {
		$entry->add( mobile => $opt->{mobile} );
	}
	if ( $opt->{phone} ) {
		$entry->add( telephonenumber => $opt->{phone} );
	}

	#
	# If we're debugging, spew stuff out on stdout
	#

	if ( $self->{verbose} ) {
		$entry->dump;
	}

	#
	# Just return if we're just going through the motions
	#

	if ( $self->{letsjustpretend} ) {
		return 0;
	}

	#
	# Adding the user is a three-step process.  First, we add the account
	# to the directory using LDAP, which AD forces to be locked.
	#

	my $mesg = $entry->update($self);
	if ( $mesg->is_error ) {
		return
		  sprintf( "Unable to create account for %s, DN %s:\n\t%s\n",
			$opt->{login}, $dn, $mesg->error_text );
	}

	#
	# Now we set a password using Kerberos
	#
	printf STDERR "Setting password for %s\n", $opt->{login}
	  if $self->{verbose};
	if (
		!$self->setLDAPPassword(
			dn       => $dn,
			password => $opt->{password}
		)
	  )
	{
		return sprintf( "Error setting password for %s: %s\n",
			$opt->{login}, $self->{errstr} );
	}

	#
	# Finally, we unlock the account using LDAP
	#

	if ( !$opt->{nopasswdchg} ) {
		$mesg = $self->modify( $dn, replace => { "pwdLastSet" => 0 } );

		if ( $mesg->is_error ) {
			return
			  sprintf(
"Unable to clear password change time for %s, DN %s:\n\t%s\n",
				$opt->{login}, $dn, $mesg->error_text );
		}
	}
	$mesg =
	  $self->modify( $dn, replace => { "userAccountControl" => 512 } );

	if ( $mesg->is_error ) {
		return
		  sprintf( "Unable to activate account for %s, DN %s:\n\t%s\n",
			$opt->{login}, $dn, $mesg->error_text );
	}
	0;
}

sub setRoamingProfile {
	my $self = shift;
	my $opt  = &_options;

	delete $self->{errstr};
	if ( !$opt->{userid} ) {
		return "Userid must be present\n";
	}
	my $userid = $opt->{userid};
	my $dn     = $self->GetUserByUID($userid);

	if ( !$dn ) {
		return "User $userid not found in Active Directory\n";
	}

	my $mesg;

	print STDERR "Updating userid $userid with dn $dn\n" if $opt->{debug};
	if ( !$opt->{profile} ) {
		print STDERR "Deleting profile\n" if $opt->{debug};
		$mesg = $self->modify( $dn, delete => ["profilePath"] );

		if ( $mesg->is_error ) {
			$self->errstr = sprintf(
"Unable to clear roaming profile for %s, DN %s:\n\t%s\n",
				$userid, $dn, $mesg->error_text );
		}
		return 0;
	}

	$mesg =
	  $self->modify( $dn, replace => { "profilePath" => $opt->{profile} } );

	if ( $mesg->is_error ) {
		print STDERR "Replacing failed.  Trying an add.\n"
		  if $opt->{debug};
		$mesg =
		  $self->modify( $dn,
			add => { "profilePath" => $opt->{profile} } );
		if ( $mesg->is_error ) {
			$self->{errstr} = sprintf(
"Unable to clear roaming profile for %s, DN %s:\n\t%s\n",
				$userid, $dn, $mesg->error_text );
		}
	}
	0;
}

sub setLDAPPassword {
	my $self = shift;
	my $opt  = &_options;

	if ( !$opt->{password} ) {
		$self->Error("Password must be given");
		return undef;
	}
	my $attrs = { userAccountControl => 512 };
	if ( $opt->{adminset} ) {
		$attrs->{pwdLastSet} = 0;
	}
	if ( !$opt->{dn} ) {
		$self->Error("DN must be given");
		return undef;
	}
	my $pass = $opt->{password};
	my $unicodepw = pack "v*", unpack "C*", qq("$pass");

	#
	# It may work to do both of these in one operation, but we do it in two
	# to make sure that the pwdLastSet flag is correct afterwards
	#
	my $mesg =
	  $self->modify( $opt->{dn}, replace => { unicodePwd => $unicodepw } );

	if ( $mesg->is_error ) {
		$self->Error( $mesg->error_text );
		return undef;
	}

	$mesg = $self->modify( $opt->{dn}, replace => $attrs );

	if ( $mesg->is_error ) {
		$self->Error( $mesg->error_text );
		return undef;
	}
	1;
}

sub setpassword {
	my $self     = shift;
	my $user     = shift;
	my $password = shift;

	if ( !$user ) {
		$self->{errstr} = "Username must be present";
		return 0;
	}
	if ( $user =~ /\s/ ) {
		$self->{errstr} = "Username may not contain whitespace";
		return 0;
	}
	if ( $user !~ /\@/ ) {
		$user .= '@' . uc( $self->{domain} );
	}
	if ( !$password ) {
		$self->{errstr} = "Password must be present";
		return 0;
	}
	my $set = 10;
	while ( $set-- ) {
		local $SIG{PIPE} = 'IGNORE';
		my $cmd = sprintf( "|%s --password-fd 0 %s >/dev/null 2>&1",
			$ksetpw_command, $user );
		if ( !open( KSETPW, $cmd ) ) {
			$self->{errstr} =
			  "Unable to run $ksetpw_command to set password: $!";
			return 0;
		}
		print KSETPW $password . "\n";
		if ( !close KSETPW ) {
			if ( $? == -1 ) {
				$self->{errstr} =
"Unable to run $ksetpw_command to set password: $!";
			} elsif ( $? & 127 ) {
				$self->{errstr} = sprintf(
"%s terminated abnormally with signal %d",
					$ksetpw_command, $? & 127 );
			} else {
				$self->{errstr} =
				  Authen::Krb5::error( $? >> 8 );
			}
		} else {
			return 1;
		}
	}
	0;
}

sub courtesy_conversions($$) {
	my ( $struct, $attrs ) = @_;
	my $deactivated_times = pack( "C21",
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 );

	foreach my $dn ( keys(%$struct) ) {
		my ($active) = 1;
		my (@ou);

		#
		# OU specification derived and added as an attribute
		#
		foreach my $part ( split( /,/, $dn ) ) {
			my (@pair) = split( /=/, $part );
			my ($var)  = shift @pair;
			my ($val)  = join( "=", @pair );

			if ( $var eq "OU" ) {
				push( @{ $struct->{$dn}{"ou"} }, "$var=$val" );
			}
		}

		#
		# logonhours may not be set in all cases (for some reason)
		#
		if ( $attrs && grep( /^logonhours$/, @{$attrs} ) == 1 ) {
			if (       $struct->{$dn}{logonhours}
				&& $struct->{$dn}{logonhours}[0] eq
				$deactivated_times )
			{
				$active = 0;
			}
		}

		#
		# check out each attribute
		#
		foreach my $attr ( keys( %{ $struct->{$dn} } ) ) {

		   #
		   # convert known whacky msdate's to time_t style as a courtesy
		   #
			if ( grep( /^$attr$/, @msdatefields ) ) {
				my @time;
				my @date;
				foreach my $each ( @{ $struct->{$dn}{$attr} } )
				{
					my (@gm);
					my ($time) = ConvertFromMSDate($each);

					@gm = gmtime($time);
					push( @time, $time );
					push(
						@date,
						sprintf(
"%04d-%02d-%02d %02d:%02d:%02d UTC",
							$gm[5] + 1900,
							$gm[4] + 1,
							$gm[3],
							$gm[2],
							$gm[1],
							$gm[0]
						)
					);
				}
				@{ $struct->{$dn}{"jh-$attr"} }      = @time;
				@{ $struct->{$dn}{"jh-$attr-date"} } = @date;
			}

	#
	# courtesy conversions for things that look like this: 20061005183000.0Z
	#
			elsif ( grep( /^$attr$/, @mstimestamps ) ) {
				my @list;
				foreach my $each ( @{ $struct->{$dn}{$attr} } )
				{
					my (@date) = split( //, $each );

					$each = sprintf(
"%04d-%02d-%02d %02d:%02d:%02d UTC",
						join( "", @date[ 0 .. 3 ] ),
						join( "", @date[ 4 .. 5 ] ),
						join( "", @date[ 6 .. 7 ] ),
						join( "", @date[ 8 .. 9 ] ),
						join( "", @date[ 10 .. 11 ] ),
						join( "", @date[ 12 .. 13 ] ),
					);
					push( @list, $each );
				}
				@{ $struct->{$dn}{"jh-$attr"} } = @list;
			}

			#
			# a courtesy conversion for MS code
			#
			elsif ( $attr eq "useraccountcontrol" ) {
				my @list;
				foreach my $each ( @{ $struct->{$dn}{$attr} } )
				{
					push(
						@list,
						_decode_user_account_control(
							$each)
					);
				}
				@{ $struct->{$dn}{"jh-$attr"} } = @list;
			}

			#
			# logonhours
			#
			elsif ( $attr eq "logonhours" ) {
				if (       $struct->{$dn}{logonhours}
					&& $struct->{$dn}{logonhours}[0] eq
					$deactivated_times )
				{
					$active = 0;
				}
			}

			#
			# email member lists
			#
			elsif ( $attr eq "memberof" ) {
				foreach my $each ( @{ $struct->{$dn}{$attr} } )
				{
					my (@d);
					my ($u);
					my ($is_email);

					foreach my $part ( split( /,/, $each ) )
					{
						my (@pair) =
						  split( /=/, $part );
						my ($var) = shift @pair;
						my ($val) = join( "=", @pair );

						if ( $var eq "OU" ) {
							if ( $val eq
"Distribution Groups"
							  )
							{
								$is_email = 1;
							}
						} elsif ( $var eq "CN" ) {
							$u = $val;
							$u =~ s/\s//g;
						} elsif ( $var eq "DC" ) {
							push( @d, $val );
						}
					}
					if ($is_email) {
						push(
							@{
								$struct->{$dn}{
"jh-memberof"
								  }
							  },
							"$u\@" . join( ".", @d )
						);
					}
				}
				if ( !exists( $struct->{$dn}{"jh-memberof"} ) )
				{
					push(
						@{
							$struct->{$dn}
							  {"jh-memberof"}
						  },
						()
					);
				}
			}
		}

		#
		# active flag
		#
		if ( $active == 0 ) {
			push( @{ $struct->{$dn}{"jh-status"} }, "deactivated" );
		} else {
			push( @{ $struct->{$dn}{"jh-status"} }, "active" );
		}
	}
}

DESTROY {
	my $self = shift;
	if ( $self->{_krb} && $self->{_krb}->{cc} ) {
		$self->{_krb}->{cc}->destroy();
	}
	if ( $self->{krb5conf} && -f $self->{krb5conf} ) {
		unlink $self->{krb5conf};
	}
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

JazzHands::ActiveDirectory - Module for manipulating Active Directory

=head1 SYNOPSIS

    use JazzHands::ActiveDirectory;

    $handle = JazzHands::ActiveDirectory->new(OPTIONS);

    $handle->CreateUser(OPTIONS);

    $handle->DecodeUserAccountControl($code);

    $handle->GetHashByMatch($string, \@attributes);

    $handle->GetHashByUID($uid, \@attributes);

    $handle->GetUserByUserName($username);

    $handle->GetUserByUserUID($uid);

    $handle->setpassword(OPTIONS);

    $handle->setRoamingProfile(OPTIONS);

=head1 DESCRIPTION

This module provides a simplified interface for doing things to an
Active Directory installation.  The object returned inherits from Net::LDAP,
so any methods that are valid for a Net::LDAP object are also valid for
a JazzHands::ActiveDirectory object.  Note that a JazzHands::ActiveDirectory
object is already connected and bound to a server when it created.

=head1 METHODS

=over 4

=item B<ConvertFromMSDate>(I<timestamp>)

Convert a Microsoft AD timestamp to a time_t.

=item B<ConvertToMSDate>(I<timestamp>)

Convert a time_t to a Microsoft AD timestamp.

=item B<CreateUser>(OPTIONS)

Creates a new user.  The following options are required:

=over 4

=item login

specify the login name.  To be in compliance with guidelines for the
creation of logins for real people, The following specifications should
be followed (this is true at the time of this writing, who knows what
it is now):

=over 4

=item 1. <first initial> + <last name>

=item 2. <first initial> + <middle initial> + <last name>

=item 3. <first initial> + <last name> + <sequence>

=back

=item ou

=item givenname

=item sn

=item uid

system_user_id that matches JazzHands record.

=item password

Clear text password?

=item cn

=back

Optionally, the following parameters may be supplied as well:

=over 4

=item title

=item department

=item company

=item location

=item city

=item state

=item country

=item address

=item postal_code

=item fax

=item mobile

=item phone

=back

Where does B<nopasswdchg> fall into this?

=item B<DecodeUserAccountControl>($code)

When the attribute useraccountcontrol is returned from the ActiveDirectory
server it is an integer.  To understand what this integer means, the following
values may be returned:

=over 4

=item ENABLED

=item DISABLED

=item DISABLED+PWDCHG

=item DISABLED

=item ENABLED+PWDCHG

=item ENABLED+PWDCHG

=item ENABLED+PWDCHG

=item ENABLED

=item DISABLED+PWDCHG

=back

I<PWGCHG> - the user needs to change their password upon next login.
This is usually initial setup, or a password reset condition.

=item B<new>(OPTIONS)

Creates a new B<JazzHands::ActiveDirectory> object, which is connected and
bound to an ActiveDirectory server. 

=over 4

=item B<authfile> => I<string>

JazzHands::ActiveDirectory utilizes the JazzHands::DBI package to do
authentication through its application interface.  Normally, it
uses the authfile B<ActiveDirectory> (in the /var/local/auth-info/
directory).  You may override this authfile by using the this option.

=item B<domain> => I<string>

Set the ActiveDirectory domain to connect to.  Defaults to 
S<B<example.com>>.  The server is located by looking up the
B<_ldap._tcp.I<domain>> DNS SRV record.  Specifying a B<server> option
overrides this option.

=item B<krbrealm> => I<string>

Is passed unmolested into Kerberos authentication schemes.
The default is the system default.

=item B<password> => I<string>

Clear text password that matches the B<username> option.

=item B<server> => I<string>

Set the ActiveDirectory server to connect to.  The default is to locate
the server by looking up the B<_ldap._tcp.I<domain>> DNS SRV record.
Setting this option prevents this lookup from happening and sets the server
manually.

=item B<username> => I<string>

Immediate credentials.  If the password for this user is non-null, you
must supply it using the B<password> option.

=back 4

=item B<GetHashByMatch>(I<string>, \@attributes)

Search for a user specified by a string which will be matched against,
the samaccountname, login, or real name.  Return a full hash
representing the LDAP entry.  Optionally, specify an arbitrary number
of attributes to return.  An example:

	$dude = GetHashByMatch("user1", ['lastlogon', 'whencreated']);

Fields which are known to be represented in a non-human friendly format
such as Microsoft internal style timestamp are converted to more
friendly formats and stored in an attributed with the same name
prepended with "jh-".  At this time, these fields are
"C<pwdlastset>", "C<lastlogon>", "C<whencreated>", "C<whenchanged>",
and "C<useraccountcontrol>".

Timestamps type fields are also converted to the following date format:
YYYY-MM-DD hh:mm:ss UTC and stored in attributes prepended with "jh-"
and postpended with "-date" as an additional courtesy.

The "C<memberof>" attribute will be copied into the "C<jh-memberof>"
attribute in an easily recognizable email format.  Only those addresses
which are part of the "C<OU=Distribution Groups>" will be considered.

A new attribute called "C<jh-ou>" is derived from the DN key and
it displays all the OU's visible within the DN.  This may be used as
a discription to access controls.

After this function returns, you may replace these fields with logic
such as this:

	foreach my $k (keys(%{$return}))
	{       
		my $nk = "jh-$k";

		if (exists($return->{$nk}))
		{
			$return->{$k} = $return->{$nk};
			delete $return->{$nk};
		}
	}

=item B<GetUserByUID>(I<system_user_id>)

A hash is returned as described by B<GetHashByMatch>, but only matching
system_user_id's are returned.

=item B<GetUserByUID>(I<system_user_id>)

Search for a specific user specified by uid.

=item B<GetUserByUsername>(I<username>)

Search for a specific user specified by username.

=item B<setpassword>(I<username>, I<newpassword>)

Set the password for I<username> to I<newpassword>.  Returns zero on
failure, and non-zero on success.

=item B<setRoamingProfile>(OPTIONS)

Set the roaming profile for the user.  The I<userid> option must be set.

=head1 AUTHOR

Matthew Ragan

=head1 SEE ALSO

Net::LDAP, JazzHands::Management

=cut

