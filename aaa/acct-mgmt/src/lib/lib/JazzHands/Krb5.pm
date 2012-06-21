package JazzHands::Krb5;

use strict;
use warnings;

use JazzHands::Krb5::Tools;
use JazzHands::AppAuthAL;
use Carp 'confess';

sub admin {
        my $params = JazzHands::AppAuthAL::find_and_parse_auth($_[1],'','krb5');
        my %params = %$params;
        my $user = $params{user};
        my $realm = $params{realm};
	my $pass = $params{password};
        my $kadm = JazzHands::Krb5::Tools->new(
		user     => $user,
		realm    => $realm,
		password => $pass
	);
	ref($kadm) or die sprintf "Unable to get admin principal to change Kerberos password: %s", $kadm;
	$kadm
}

1
