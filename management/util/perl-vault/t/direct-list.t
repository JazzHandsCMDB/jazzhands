#
# listing secrets works
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

my $root          = "/scratch";
my $app           = "dlist";
my $rovaultfspath = "/$root/${app}-ro";
my $vaultfspath   = "/$root/$app";

cleanup_vault( $app, $rovaultfspath, $vaultfspath );
setup_vault( $app, $rovaultfspath, $vaultfspath );

my $testname = "Listing secrets";
my @tests    = ( {
	setup => {
		'VaultRoleIdPath'   => "/$vaultfspath/roleid",
		'VaultSecretIdPath' => "$vaultfspath/secretid",
		'VaultServer'       => 'http://vault:8200'
	},
	path   => "secret/data/$app/my-first-key",
	list   => "secret/data/$app",
	output => ['my-first-key'],
	stuff  => {
		data => {
			user     => 'username',
			password => 'password',
			other    => $testname,
		} } } );
plan tests => ( $#tests + 1 ) * 2;

foreach my $test (@tests) {
	my $v = new JazzHands::Vault( %{ $test->{setup} } );
	if ( !$v ) {
		diag($JazzHands::Vault::errstr);
		fail($testname);
	}

	if ( !$v->write( $test->{path}, $test->{stuff} ) ) {
		diag( "write: " . $JazzHands::Vault::errstr );
		fail($testname);
		next;
	}

	my $r = $v->list( $test->{list} );
	if ( !$r ) {
		diag( "list: " . $JazzHands::Vault::errstr );
		fail($testname);
		next;
	} else {
		cmp_deeply( $test->{output}, $r, $testname );
	}

	my $d = $v->delete( $test->{path} );
	if ( !$d ) {
		diag( "delete: " . $JazzHands::Vault::errstr );
		fail($testname);
		next;
	} else {
		ok($testname);
	}

}

cleanup_vault( $app, $rovaultfspath, $vaultfspath );
done_testing();
