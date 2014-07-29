=head1

Example content of json file when SRV record is not used.

{
        "ldap" : {
                "binddn"   : "syncuser",
                "bindpw"   : "secret",
                "LDAPHost" : "sync.example.com",
                "TLS" : { 
                        "verify" : "none",
                        "cafile" : "/etc/pki/tls/certs/trusted_by_openldap_clients.crt" }
        }
}

To use SRV record, replace 'LDAPHost' entry with 'Domain' entry where 'Domain' is to be used in SRV record as follows:

_ldap._tcp.Domain

=cut
package JazzHands::LDAP;

use strict;
use warnings;

use base 'Net::LDAP';

use JazzHands::AppAuthAL;
use AN::DNS;

use Carp qw(confess croak);

#TODO
# pod to describe json file format

our $VERSION = '0.10';

sub new {
	my $class = shift;

	my $params = JazzHands::AppAuthAL::find_and_parse_auth(shift,'','ldap');
	my %params = %$params;
	my $host = $params{LDAPHost};
	unless($host){
		my $domain = $params{Domain} or die "Neither LDAPHost or Domain parameter supplied\n";
		$host = AN::DNS->get_srv(domain => $domain, service => 'ldap')
	}
	my $port = $params{LDAPPort} || 389;
	my $tls = $params{TLS};
	my $bind_dn = $params{binddn};
	my $bind_pw = $params{bindpw};
        my $self = $class->SUPER::new( $host , port => $port) or die "Cannot create an ldap object $@\n";
	if('HASH' eq ref $tls){
		my $mesg = $self->start_tls( %$tls );
		if($mesg->code){ confess "Cannot issue STARTTLS command $!\n" . $mesg->error }
	}
	my @bind_params = $bind_dn ? ($bind_dn, 'password', $bind_pw) : ();
        my $mesg = $self->bind( @bind_params );
        if($mesg->code){ die "cannot bind $!\n" . $mesg->error }
	$self
}

1
