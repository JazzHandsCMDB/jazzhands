package JazzHands::Krb5;

use strict;
use warnings;

use JazzHands::Krb5::Tools;
use JazzHands::AppAuthAL;
use Carp 'confess';

our $VERSION = '0.01';

sub admin {
        my $params = JazzHands::AppAuthAL::find_and_parse_auth($_[1],'','krb5');
        my $kadm = JazzHands::Krb5::Tools->new( %$params);
	ref($kadm) or confess sprintf "Unable to get admin principal to change Kerberos password: %s", $kadm;
	$kadm
}

1
