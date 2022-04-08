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

my $testname = "Various Role and Secret Id Methods";

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
			'VaultRoleIdPath' => "$roleidpath",
			'VaultSecretId'   => "$secretid",
			'VaultServer'     => 'http://vault:8200'
		},
		path  => "secret/data/$app/my-second-key",
		stuff => {
			data => {
				user     => 'username',
				password => 'password',
				other    => $testname,
			}
		},
		comment => "role id path and secret id",
	},
	{
		setup => {
			'VaultRoleId'       => "$roleid",
			'VaultSecretIdPath' => "$secretidpath",
			'VaultServer'       => 'http://vault:8200'
		},
		path  => "secret/data/$app/my-third-key",
		stuff => {
			data => {
				user     => 'username',
				password => 'password',
				other    => $testname,
			}
		},
		comment => "role id and secret id path",
	},
	{
		setup => {
			'VaultRoleIdPath'   => "$roleidpath",
			'VaultSecretIdPath' => "$secretidpath",
			'VaultServer'       => 'http://vault:8200'
		},
		path  => "secret/data/$app/my-fourth-key",
		stuff => {
			data => {
				user     => 'username',
				password => 'password',
				other    => $testname,
			}
		},
		comment => "role id path and secret id path",
	},
	{
		setup => {
			'VaultRoleId'   => "$roleid",
			'VaultSecretId' => "$secretid",
			'VaultServer'   => 'http://vault:8200'
		},
		path  => "secret/data/$app/my-first-key",
		stuff => {
			data => {
				user     => 'username',
				password => 'password',
				other    => $testname,
			}
		},
		comment => "role id and secret id",
	} );
plan tests => ( $#tests + 1 ) * 2;

foreach my $test (@tests) {
	my ( $setup, $path, $stuff, $comment ) =
	  @$test{qw/setup path stuff comment/};
	my $v = new JazzHands::Vault(%$setup);
	if ( !$v ) {
		diag($JazzHands::Vault::errstr);
		fail( $comment || $testname );
	}

	if ( !$v->write( $path, $stuff ) ) {
		diag( "write($roleid,$secretid): " . $JazzHands::Vault::errstr );
		fail( $comment || $testname );
		next;
	}

	my $r = $v->read($path);
	if ( !$r ) {
		diag( "read: " . $JazzHands::Vault::errstr );
		fail( $comment || $testname );
		next;
	} else {
		cmp_deeply( $stuff->{data}, $r->{data}, $testname );
	}

	my $d = $v->delete($path);
	if ( !$d ) {
		diag( "delete: " . $JazzHands::Vault::errstr );
		fail( $comment || $testname );
		next;
	} else {
		ok( $comment || $testname );
	}
}

cleanup_vault( $app, $rovaultfspath, $vaultfspath );
done_testing();
