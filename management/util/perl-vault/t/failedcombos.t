#
# write/read/delete tokens using the direct method
#

use strict;
use warnings;

use Test::More;
use Test::Deep;

use lib qw(lib t/lib);
use JazzHands::VaultTestSupport;
use FileHandle;

BEGIN {
	check_vault() || plan skip_all => "Skipping tests due to lack of vault";
}

use JazzHands::Vault;

my $root          = "/scratch";
my $app           = "dwrite";
my $rovaultfspath = "$root/${app}-ro";
my $vaultfspath   = "$root/$app";

cleanup_vault( $app, $rovaultfspath, $vaultfspath );
setup_vault( $app, $rovaultfspath, $vaultfspath );

my $testname = "Various Combinations that _should_ fail";

my $roleidpath   = "$vaultfspath/roleid";
my $secretidpath = "$vaultfspath/secretid";

my ( $roleid, $secretid );
if ( my $fh = new FileHandle($roleidpath) ) {
	$roleid = $fh->getline();
	chomp($roleid);
	$fh->close();
} else {
	diag("$roleidpath: $!");
	fail($testname);
}

if ( my $fh = new FileHandle($secretidpath) ) {
	$secretid = $fh->getline();
	chomp($secretid);
	$fh->close();
} else {
	diag("$secretidpath: $!");
	fail($testname);
}

my @tests = ( {
		setup => {
			'VaultRoleIdPath'   => "$roleidpath",
			'VaultRoleId'       => "$roleid",
			'VaultSecretId'     => "$secretid",
			'VaultSecretIdPath' => "$secretidpath",
			'VaultServer'       => 'http://vault:8200'
		},
		comment => "Both roles and secrets",
	},
	{
		setup => {
			'VaultRoleIdPath' => "$roleidpath",
			'VaultRoleId'     => "$roleid",
			'VaultSecretId'   => "$secretid",
			'VaultServer'     => 'http://vault:8200'
		},
		comment => "Both roles and secret",
	},
	{
		setup => {
			'VaultRoleIdPath'   => "$roleidpath",
			'VaultRoleId'       => "$roleid",
			'VaultSecretIdPath' => "$secretidpath",
			'VaultServer'       => 'http://vault:8200'
		},
		comment => "Both roles and secret path",
	},
	{
		setup => {
			'VaultRoleIdPath'   => "$roleidpath",
			'VaultSecretId'     => "$secretid",
			'VaultSecretIdPath' => "$secretidpath",
			'VaultServer'       => 'http://vault:8200'
		},
		comment => "Role path and both secrets",
	},
	{
		setup => {
			'VaultRoleId'       => "$roleid",
			'VaultSecretId'     => "$secretid",
			'VaultSecretIdPath' => "$secretidpath",
			'VaultServer'       => 'http://vault:8200'
		},
		comment => "Role id and both secrets",
	},
	{
		setup => {
			'VaultRoleId' => "$roleid",
			'VaultServer' => 'http://vault:8200'
		},
		comment => "Role Id and no secret",
	},
	{
		setup => {
			'VaultRoleIdPath' => "$roleidpath",
			'VaultServer'     => 'http://vault:8200'
		},
		comment => "Role Id path and no secret",
	},
	{
		setup => {
			'VaultSecretId' => "$secretid",
			'VaultServer'   => 'http://vault:8200'
		},
		comment => "No role and secret id",
	},
	{
		setup => {
			'VaultSecretIdPath' => "$secretidpath",
			'VaultServer'       => 'http://vault:8200'
		},
		comment => "No role and secret id",
	},
);

plan tests => $#tests + 1;

foreach my $test (@tests) {
	my ( $setup, $comment ) = @$test{qw/setup comment/};
	my $v = new JazzHands::Vault(%$setup);
	if ($v) {
		fail( $comment || $testname );
	} else {
		ok( $comment || $testname );
	}
}

cleanup_vault( $app, $rovaultfspath, $vaultfspath );
done_testing();
