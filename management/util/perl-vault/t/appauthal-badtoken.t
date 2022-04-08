
#
# AppAuthAL - Make sure it works if just a token is passed in
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
my $app         = "notoken";
my $vaultfspath = "/$root/$app";

cleanup_vault( $app, $vaultfspath );
setup_vault( $app, $vaultfspath );

put_secret( $app, "secret", "username=myuser", "password=mypass" );

get_token($vaultfspath);

my $testname = "non-existant token path";

my @tests = ( {
	input => {
		'map' => {
			'Password' => 'password',
			'Username' => 'username'
		},
		'VaultTokenPath' => "/path/to/no/path",
		'VaultPath'      => "secret/data/$app/secret",
		'Method'         => 'vault',
		'import'         => {
			'DBName' => 'jazzhands',
			'DBType' => 'postgresql',
			'Method' => 'password',
			'DBHost' => 'mydbhost'
		},
		'VaultServer' => 'http://vault:8200'
	},
	output => {
		'DBType'   => 'postgresql',
		'Method'   => 'password',
		'Username' => 'myuser',
		'Password' => 'mypass',
		'DBHost'   => 'mydbhost',
		'DBName'   => 'jazzhands'
	},
	comment => $testname,
} );
plan tests => $#tests + 1;

for my $test (@tests) {
	my ( $input, $output, $comment ) = @$test{qw/input output comment/};
	my $v = new JazzHands::Vault( appauthal => $input );
	if ($v) {
		fail("Got a token when we should not");
	} else {
		ok($comment);
	}
}

if ( !check_token($vaultfspath) ) {
	fail("token is no longer valid.");
}

revoke_token($vaultfspath);

delete_secret( $app, "secret" );
cleanup_vault( $app, $vaultfspath );
done_testing();
