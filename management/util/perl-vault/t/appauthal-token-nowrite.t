
#
# AppAuthAL - If a token file is specified but not writable, still work.
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
my $app         = "tokennorewrite";
my $vaultfspath = "/$root/$app";

cleanup_vault( $app, $vaultfspath );
setup_vault( $app, $vaultfspath );

put_secret( $app, "secret", "username=myuser", "password=mypass" );

unlink("$app/token");

my $testname = 'unwritable token still pows through';
my @tests    = ( {
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

my $olduid = $>;
$> = 1000 || die "could not setuid down";
for my $test (@tests) {
	my ( $input, $output, $comment ) = @$test{qw/input output comment/};
	my $v = new JazzHands::Vault( appauthal => $input );
	if ( !$v ) {
		diag(JazzHands::Vault::errstr);
		fail($comment);
	}
	my $newauth = $v->fetch_and_merge_dbauth($input);
	if ( !$newauth ) {
		diag( $v->errstr );
		fail($comment);
	} else {
		cmp_deeply( $output, $newauth, $comment );
	}
}
$> = $olduid;

if ( -r "$vaultfspath/token" ) {
	diag("Token file was written despite best efforts");
	fail($testname);
}

delete_secret( $app, "secret" );
cleanup_vault( $app, $vaultfspath );
done_testing();
