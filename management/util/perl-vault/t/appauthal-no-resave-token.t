#
# AppAuthAL based test that checks to see if a token is saved that a
# second use of the token will not resave it or otherwise change it
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
my $app         = "noresave";
my $vaultfspath = "/$root/$app";

cleanup_vault( $app, $vaultfspath );
setup_vault( $app, $vaultfspath );

put_secret( $app, "secret", "username=myuser", "password=mypass" );

get_token($vaultfspath);

unlink("$vaultfspath/token");

fail("Token exists despite best efforts.") if -r "$vaultfspath/token";

my $testname = 'same token does not get overwritten';

my @tests = ( {
	input => {
		'map' => {
			'Password' => 'password',
			'Username' => 'username'
		},
		'VaultRoleIdPath'   => "$vaultfspath/roleid",
		'VaultSecretIdPath' => "$vaultfspath/secretid",
		'VaultTokenPath'    => "$vaultfspath/token",
		'VaultPath'         => "secret/data/$app/secret",
		'Method'            => 'vault',
		'import'            => {
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

my $oldts;
for ( my $i = 0 ; $i < 1 ; $i++ ) {
	for my $test (@tests) {
		my ( $input, $output, $comment ) = @$test{qw/input output comment/};
		my $v = new JazzHands::Vault( appauthal => $input );
		if ( !$v ) {
			diag($JazzHands::Vault::errstr);
			fail($comment);
		}
		my $newauth = $v->fetch_and_merge_dbauth($input);
		if ( !$newauth ) {
			diag("Error: ", $JazzHands::Vault::errstr);
			fail($comment);
		}
	}

	if ( !-r "$vaultfspath/token" ) {
		diag("$vaultfspath/token was not saved.");
	}

	if ( $i == 0 ) {

		# make it something different
		`touch -r /boot $vaultfspath/token`;
		$oldts = ( stat("$vaultfspath/token") )[8];
	}
}

my $newts = ( stat("$vaultfspath/token") )[8];
if ( $oldts != $newts ) {
	diag("Token was rewritten despite being the same");
	fail($testname);
}

if ( !check_token($vaultfspath) ) {
	diag("token is no longer valid!");
	fail($testname);
}

ok($testname);

revoke_token($vaultfspath);

delete_secret( $app, "secret" );
cleanup_vault( $app, $vaultfspath );
done_testing();
