#
# Direct: Check to see if a token renews if it's about to expire
#

use strict;
use warnings;

use Test::More;
use Test::Deep;

use lib qw(lib t/lib);
use JazzHands::VaultTestSupport;

my $testname = 'direct renew about to expire token';

BEGIN {
	check_vault() || plan skip_all => "Skipping tests due to lack of vault";
}

use JazzHands::Vault;

my $root        = "/scratch";
my $app         = "dtokennorewrite";
my $vaultfspath = "$root/$app";

cleanup_vault( $app, $vaultfspath );
setup_vault( $app, $vaultfspath );

put_secret( $app, "secret", "username=myuser", "password=mypass" );

get_token($vaultfspath);

if ( !-r "$vaultfspath/token" ) {
	diag("OLD: $vaultfspath/token does not exist");
	fail($testname);
}

my $oldtoken = `cat $vaultfspath/token`;

swap_out_token( "$vaultfspath/token", "-ttl=20s" );

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
	comment => 'get a token'
} );
plan tests => $#tests + 2;

for my $test (@tests) {
	my ( $input, $output, $comment ) = @$test{qw/input output comment/};
	my $v = new JazzHands::Vault(%$input);
	if ($v) {
		ok($comment);
	} else {
		diag(JazzHands::Vault::errstr);
		fail($comment);
	}
}

if ( !-r "$vaultfspath/token" ) {
	diag("NEW: $vaultfspath/token does not exist");
	fail($testname);
}

my $newtoken = `cat $vaultfspath/token`;

if ( $oldtoken eq $newtoken ) {
	diag("$oldtoken matches");
	fail($testname);
} else {
	ok($testname);
}

delete_secret( $app, "secret" );
cleanup_vault( $app, $vaultfspath );
done_testing();
