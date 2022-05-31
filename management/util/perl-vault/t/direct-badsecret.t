#
# Try to authenticate with a bum secret id and make sure it fails.
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
my $app         = "dappauthal";
my $vaultfspath = "/$root/$app";

cleanup_vault( $app, $vaultfspath );
setup_vault( $app, $vaultfspath );

put_secret( $app, "secret", "username=myuser", "password=mypass" );

if(my $fh = new FileHandle(">$vaultfspath/secretid")) {
	$fh->printf("i-am-not-a-valid-secret-id");
	$fh->close();
} else {
	diag("Unable to open $vaultfspath/secretid for write: $!");
	fail('setup');
}

my @tests = ( {
	input => {
		'VaultRoleIdPath'   => "/$vaultfspath/roleid",
		'VaultSecretIdPath' => "$vaultfspath/secretid",
		'VaultPath'         => "secret/data/$app/secret",
		'VaultServer'       => 'http://vault:8200'
	},
	comment => 'direct but bad secret-id',
} );
plan tests => $#tests + 1;

for my $test (@tests) {
	my ( $input, $output, $comment ) = @$test{qw/input output comment/};
	my $v = new JazzHands::Vault(%$input);
	if (!$v) {
		ok($comment);
	} else {
		diag("Successfully authenticated!");
		fail($comment);
	}
}

delete_secret( $app, "secret" );
cleanup_vault( $app, $vaultfspath );
done_testing();
