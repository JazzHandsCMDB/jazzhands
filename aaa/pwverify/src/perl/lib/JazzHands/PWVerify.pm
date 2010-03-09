# $Id$
# Copyright (c) 2005-2010, Vonage Holdings Corp.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

package JazzHands::PWVerify;

use strict;
use warnings;

use Crypt::Cracklib;

use vars qw($VERSION @EXPORT @ISA);
$VERSION = '1.0';

require Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = ("Exporter");
*import = \&Exporter::import;

@EXPORT = ();

my $MINLENGTH      = 7;
my $MINCHARCLASSES = 3;
my $HISTORY        = 365;

sub _options {
	my %ret = @_;
	for my $v ( grep { /^-/ } keys %ret ) {
		$ret{ substr( $v, 1 ) } = $ret{$v};
	}
	\%ret;
}

#
# ALL OF THESE PASSWORD CHECKS NEED TO BE CONFIGURABLE PARAMETERS!!!
#

sub VerifyPassword {
	my $opt = &_options;

	my $password;
	if ( !( $password = $opt->{password} ) ) {
		return "Password not present";
	}
	my $user       = $opt->{user};
	my $dictionary = $opt->{dictionary}
	  || '/usr/local/lib/cracklib/pw_dict';

	if ( length($password) < $MINLENGTH ) {
		return "Password is too short";
	}

	if ( $password =~ /\s+/ ) {
		return "Password may not contain whitespace";
	}

	my $classcount = 0;
	$classcount++ if $password =~ /[a-z]/;
	$classcount++ if $password =~ /[A-Z]/;
	$classcount++ if $password =~ /[0-9]/;
	$classcount++ if $password =~ /[^a-zA-Z0-9]/;
	if ( $classcount < $MINCHARCLASSES ) {
		return
"Password must use at least three different types of characters (lowercase, uppercase, numbers, symbols)";
	}

	#
	# Check cracklib
	#
	my $message = Crypt::Cracklib::fascist_check( $password,
		"/usr/local/lib/cracklib/pw_dict" );

	if ( $message ne 'ok' ) {
		return $message;
	}

	#
	# If we have a database handle, see if the passwords have been used in
	# the past year.
	#
	if ( ref($user) ) {
		my $dbh = eval { $user->DBHandle };
		if ( !$dbh ) {
			return "Fatal error with user object";
		}

	       # We're going to select the previous MD5 hashes, just to pick one

		my ( $q, $sth );
		$q = sprintf q {
			SELECT UNIQUE
				User_Password
			FROM
				JazzHands.AUD$System_Password
			WHERE
				System_User_ID = :sysuid AND
				Password_Type = 'md5' AND
				AUD#Timestamp > SYSDATE - %s
		}, $HISTORY;
		if ( !( $sth = $dbh->prepare($q) ) ) {
			return
"Error preparing database query for password checking: "
			  . $dbh->errstr;
		}
		$sth->bind_param( ':sysuid', $user->Id );
		if ( !$sth->execute ) {
			return
"Error executing database query for password checking: "
			  . $dbh->errstr;
		}
		my $passwordused = 0;
		while ( my $checkpass = ( $sth->fetchrow_array() )[0] ) {
			if ( crypt( $password, $checkpass ) eq $checkpass ) {
				$passwordused = 1;
				last;
			}
		}
		$sth->finish;
		if ($passwordused) {
			return
			  "You have used this password in the past "
			  . $HISTORY . " days";
		}
	}

	#
	# If we get here, the password is okay
	#
	return 0;
}

1;

__END__
