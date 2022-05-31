#
# Direct - write a token but read a different one
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
my $app           = "dwrite";
my $rovaultfspath = "$root/${app}-ro";
my $vaultfspath   = "$root/$app";

cleanup_vault( $app, $rovaultfspath, $vaultfspath );
setup_vault( $app, $rovaultfspath, $vaultfspath );

my $testname = "Write a token and read a different one (and fail)";
my @tests    = ( {
	setup => {
		'VaultRoleIdPath'   => "/$vaultfspath/roleid",
		'VaultSecretIdPath' => "$vaultfspath/secretid",
		'VaultServer'       => 'http://vault:8200'
	},
	path    => "secret/data/$app/my-first-key",
	badpath => "secret/data/$app/my-non-existant-key",
	stuff   => {
		user     => 'username',
		password => 'password',
		other    => $testname,
	} } );
plan tests => ( $#tests + 1 ) * 2;

foreach my $test (@tests) {
	my $v = new JazzHands::Vault( %{ $test->{setup} } );
	if ( !$v ) {
		diag(JazzHands::Vault::errstr);
		fail($testname);
	}

	if ( !$v->write( $test->{path}, { data => $test->{stuff} } ) ) {
		diag( "write: " . $v->errstr );
		fail($testname);
		next;
	}

	my $r = $v->read( $test->{badpath} );
	if ( !$r ) {
		if ( $v->err == 404 ) {
			ok($testname);
		} else {
			diag( "read: " . $v->errstr );
			fail($testname);
			next;
		}
	} else {
		diag("read successfully.");
		fail($testname);
	}

	my $d = $v->delete( $test->{path} );
	if ( !$d ) {
		diag( "delete: " . $v->errstr );
		fail($testname);
		next;
	} else {
		ok($testname);
	}

}

cleanup_vault( $app, $rovaultfspath, $vaultfspath );
done_testing();
