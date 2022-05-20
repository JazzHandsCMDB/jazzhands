
#
# Direct based test that checks to see if a token is saved that a second use
# of the token will not resave it or otherwise change it
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
my $app         = "dnoresave";
my $vaultfspath = "/$root/$app";

cleanup_vault( $app, $vaultfspath );
setup_vault( $app, $vaultfspath );

put_secret( $app, "secret", "username=myuser", "password=mypass" );

get_token($vaultfspath);

unlink("$vaultfspath/token");

die "Token exists despite best efforts." if -r "$vaultfspath/token";

my $testname = 'direct same token does not get overwritten';
my @tests    = ( {
	input => {
		'VaultRoleIdPath'   => "$vaultfspath/roleid",
		'VaultSecretIdPath' => "$vaultfspath/secretid",
		'VaultTokenPath'    => "$vaultfspath/token",
		'VaultPath'         => "secret/data/$app/secret",
		'VaultServer'       => 'http://vault:8200'
	},
	comment => $testname
} );
plan tests => $#tests + 1;

my $oldts;
for ( my $i = 0 ; $i < 1 ; $i++ ) {
	for my $test (@tests) {
		my ( $input, $output, $comment ) = @$test{qw/input output comment/};
		my $v = new JazzHands::Vault(%$input);
	}

	if ( !-r "$vaultfspath/token" ) {
		diag("$vaultfspath/token was not saved.");
		fail($testname);
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
} else {
	ok($testname);
}

if ( !check_token($vaultfspath) ) {
	diag("token is no longer valid!");
	fail($testname);
}

revoke_token($vaultfspath);

delete_secret( $app, "secret" );
cleanup_vault( $app, $vaultfspath );
done_testing();
