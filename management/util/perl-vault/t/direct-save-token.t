#
# Direct style - if a tokenfile is passed in addition to role/secret, fetch
# and store the token.
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
my $app         = "dsavetoken";
my $vaultfspath = "/$root/$app";

cleanup_vault( $app, $vaultfspath );
setup_vault( $app, $vaultfspath );

put_secret( $app, "secret", "username=myuser", "password=mypass" );

unlink($vaultfspath);

my $testname = 'direct saving a token works';
my @tests    = ( {
	input => {
		'VaultRoleIdPath'   => "$vaultfspath/roleid",
		'VaultSecretIdPath' => "$vaultfspath/secretid",
		'VaultTokenPath'    => "$vaultfspath/token",
		'VaultPath'         => "secret/data/$app/secret",
		'VaultServer'       => 'http://vault:8200'
	},
	comment => $testname,
} );
plan tests => $#tests + 1;

for my $test (@tests) {
	my ( $input, $output, $comment ) = @$test{qw/input output comment/};
	my $v = new JazzHands::Vault(%$input);
	if ( !$v ) {
		diag($JazzHands::Vault::errstr);
		fail($comment);
	} else {
		ok($comment) if $v;
	}
}

if ( !-r "$vaultfspath/token" ) {
	diag("$vaultfspath/token was not saved.");
	fail($testname);
}

if ( !check_token($vaultfspath) ) {
	diag("token is no longer valid!");
	fail($testname);
}

revoke_token($vaultfspath);

delete_secret( $app, "secret" );
cleanup_vault( $app, $vaultfspath );
done_testing();
