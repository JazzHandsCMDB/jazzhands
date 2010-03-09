#!/usr/local/bin/perl -w
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

use strict;
use Authen::Krb5;
use Crypt::Cracklib;
use JazzHands::Management qw(:DEFAULT);

$ENV{PATH} = "/bin:/usr/bin";
delete $ENV{IFS};
my $REALM   = "EXAMPLE.COM";
my $contact = "nobody\@EXAMPLE.COM";

sub error {
	if ( my $error = shift ) {
		print STDERR $error;
		print STDERR "\nPlease report this to $contact\n";
		exit 1;
	}
}

my $krbobj = Authen::Krb5::init_context();

if ( !$krbobj ) {
	error("Unable to initalize Kerberos context to check password!\n");
}

my $name = getlogin();
if ( !$name ) {
	error("Unable to determine login name!\n");
}

print <<EOF;
At the following prompts, you will need to provide your system/Kerberos
password to verify your identity, and then the password that you want to
set your network password to twice.  Your password will need to pass
checks for a strong password before it is accepted.  For information on
choosing a strong password, see:

https://WWW.EXAMPLE.COM/accounts/choosing-good-passwords.html

EOF
print "Setting network password for $name\n\n";
my $ccache = Authen::Krb5::cc_resolve('MEMORY:setnpasswd');
if ( !defined($ccache) ) {
	error(
"Unable to establish Kerberos credentials cache to check password"
	);
}

my $client = Authen::Krb5::parse_name( $name . '@' . $REALM );

if ( !$client ) {
	error("Unable to construct client principal for $name");
}

my $service = Authen::Krb5::parse_name( "krbtgt/" . $REALM . '@' . $REALM );

if ( !$service ) {
	error( "Unable to construct service principal for password verification"
	);
}

my $tries     = 0;
my $pwcorrect = 0;
my $oldpass;
while ( $tries++ <= 3 ) {
	print "Enter Kerberos password: ";
	system("/bin/stty -echo");
	$oldpass = <>;
	system("/bin/stty echo");
	chomp($oldpass);
	print "\n";

	my $code =
	  Authen::Krb5::get_in_tkt_with_password( $client, $service, $oldpass,
		$ccache );
	if ( !defined($code) ) {
		my $msg = Authen::Krb5::error();
		if ( $msg eq 'Decrypt integrity check failed' ) {
			print STDERR "Password incorrect\n";
			next;
		}
		if ( $msg eq 'Client not found in Kerberos database' ) {
			error("You do not have a Kerberos principal.");
		}
		error( "Unknown error: " . $msg );
	} else {
		$pwcorrect = 1;
		last;
	}
}
if ( !$pwcorrect ) {
	print STDERR "Too many incorrect passwords.\n";
	exit 1;
}

my ( $pass1, $pass2 );
while (1) {
	print "Enter new network password: ";
	system("stty -echo");
	$pass1 = <>;
	system("stty echo");
	chomp($pass1);
	print "\n";
	if ( $pass1 eq $oldpass ) {
		print STDERR
"Your network device password should not be the same as your Kerberos\n";
		print STDERR "password!\n";
		next;
	}
	if (
		!Crypt::Cracklib::check(
			$pass1, "/usr/local/lib/cracklib/pw_dict"
		)
	  )
	{
		print STDERR
"That password is too easy to guess.  Please pick a different one\n";
		next;
	}
	print "Enter new network password again: ";
	system("stty -echo");
	$pass2 = <>;
	system("stty echo");
	chomp($pass2);
	print "\n";
	if ( $pass1 ne $pass2 ) {
		print STDERR "Passwords do not match.  Try again\n";
	} else {
		last;
	}
}

my ( $dbh, $userid );
if (       ( $dbh = OpenJHDBConnection("user-cpw") )
	&& ( $userid = findUserIdFromlogin( $dbh, $name ) )
	&& ChangeUserNetworkPassword( $dbh, $userid, $pass1 ) )
{
	print "Password Changed.\n";
} else {
	error("Password change failed!");
}
$dbh->disconnect;

