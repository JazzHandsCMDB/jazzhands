#
# Bad token path correctly causes failure
#

use strict;
use warnings;

use Test::More;
use Test::Deep;

use lib qw(lib t/lib);
use JazzHands::VaultTestSupport;

BEGIN {
	check_vault() || plan skip_all => "Skipping tests due to lack of vault";
}

use JazzHands::Vault;

my $root        = "/scratch";
my $app         = "dnotoken";
my $vaultfspath = "/$root/$app";

cleanup_vault( $app, $vaultfspath );
setup_vault( $app, $vaultfspath );

put_secret( $app, "secret", "username=myuser", "password=mypass" );

get_token($vaultfspath);

my $testname = 'non-existant token path';
my @tests    = ( {
	input => {
		'VaultTokenPath' => "/path/to/no/path",
		'VaultPath'      => "secret/data/$app/secret",
		'VaultServer'    => 'http://vault:8200'
	},
	comment => $testname
} );
plan tests => $#tests + 1;

for my $test (@tests) {
	my ( $input, $output, $comment ) = @$test{qw/input output comment/};
	my $v = new JazzHands::Vault(%$input);
	if ($v) {
		diag("Got a token when we should not");
		fail($comment);
	} else {
		if (JazzHands::Vault::errstr) {
			ok($comment);
		} else {
			diag("Did not get an error string");
			fail($comment);
		}
	}
}

if ( !check_token($vaultfspath) ) {
	diag("token is no longer valid.");
	fail($testname);
}

revoke_token($vaultfspath);

delete_secret( $app, "secret" );
cleanup_vault( $app, $vaultfspath );
done_testing();
