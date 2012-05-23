package JazzHands::LDAP;

use strict;
use warnings;

use JazzHands::AppAuthAL;
use Carp 'confess';
use Net::LDAP;

our $VERSION = '0.10';

sub new {
	my $class = shift;

	my $params = JazzHands::AppAuthAL::find_and_parse_auth(shift,'','ldap');
	my %params = %$params;
	my $host = $params{LDAPHost};
	my $port = $params{LDAPPort} || 389;
	my $tls = $params{TLS};
	my $bind_dn = $params{binddn};
	my $bind_pw = $params{bindpw};
        my $ldap = Net::LDAP->new( $host , port => $port) or die "Cannot create an ldap object $@\n";
	if('HASH' eq ref $tls){
		my $mesg = $ldap->start_tls( %$tls );
		if($mesg->code){ confess "cannot issue STARTTLS command $!\n" . $mesg->error }
	}
	my @bind_params = $bind_dn ? ($bind_dn, 'password', $bind_pw) : ();
        my $mesg = $ldap->bind( @bind_params );
        if($mesg->code){ die "cannot bind $!\n" . $mesg->error }
	$ldap
}

1
