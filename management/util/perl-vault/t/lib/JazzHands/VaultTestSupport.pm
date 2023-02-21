#
# common code the tests call to deal with getting vault ready
#
# calls external scripts that just minimally invoke vault in order to setup
# and test things.  This is just to ensure perl bugs don't crop up in both
# places.
#

use strict;
use warnings;

use lib 'lib';
use base 'Exporter';

our @EXPORT =
  qw (setup_vault cleanup_vault check_vault put_secret delete_secret get_token revoke_token check_token swap_out_token);

sub check_vault {
	if ( !-r "/scratch/vault-output" ) {
		return 0;
	}
	return 1;
}

sub setup_vault {
	system( "/usr/bin/setup-vault-app", @_ );
	( $? >> 8 ) == 0;
}

sub cleanup_vault {
	system( "/usr/bin/cleanup-vault-app", @_ );
	( $? >> 8 ) == 0;
}

sub put_secret {
	system( "/usr/bin/put-vault-secret", @_ );
	( $? >> 8 ) == 0;
}

sub delete_secret {
	system( "/usr/bin/delete-vault-secret", @_ );
	( $? >> 8 ) == 0;
}

sub get_token {
	system( "/usr/bin/get-token", @_ );
	( $? >> 8 ) == 0;
}

sub revoke_token {
	system( "/usr/bin/revoke-token", @_ );
	( $? >> 8 ) == 0;
}

sub check_token {
	system( "/usr/bin/check-token", @_ );
	( $? >> 8 ) == 0;
}

sub swap_out_token {
	system( "/usr/bin/swap-out-token", @_ );
	( $? >> 8 ) == 0;
}

1;
