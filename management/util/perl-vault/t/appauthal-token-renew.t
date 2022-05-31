#
# Appauthal: Check to see if a token renews if it's about to expire
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
my $app         = "atokenrenew";
my $vaultfspath = "$root/$app";

cleanup_vault( $app, $vaultfspath );
setup_vault( $app, $vaultfspath );

put_secret( $app, "secret", "username=myuser", "password=mypass" );

get_token($vaultfspath);

my $oldtoken = `cat $vaultfspath/token`;

swap_out_token( "$vaultfspath/token", "-ttl=20s" );

my $testname = "token auto-renew works";

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
	comment => 'vault access obtained',
} );
plan tests => $#tests + 2;

for my $test (@tests) {
	my ( $input, $output, $comment ) = @$test{qw/input output comment/};
	my $v = new JazzHands::Vault( appauthal => $input );
	if ( !$v ) {
		diag(JazzHands::Vault::errstr);
		fail($comment);
	}
	my $newauth = $v->fetch_and_merge_dbauth($input);
	if ( !$newauth ) {
		diag($JazzHands::Vault::errstr);
		fail($comment);
	} else {
		cmp_deeply( $output, $newauth, $comment );
	}
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
