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
use CGI qw/:standard :html4/;
use Authen::Krb5;
use Crypt::Cracklib;

# use JazzHands::Management qw(:DEFAULT);

$ENV{PATH} = "/bin:/usr/bin";
delete $ENV{IFS};
my $REALM   = "EXAMPLE.COM";
my $contact = "nobody\@EXAMPLE.COM";

my $k5pw   = param("k5password");
my $newpw  = param("newpassword");
my $newpw2 = param("newpasswordagain");

sub error {
	my $error = shift || "For unknown reasons";
	my $tmpfail = shift;

	print h1("Password Change Failed!\n");
	print br, $error, br;
	print br, "Please report this to <a href=\"$contact\">$contact</a>"
	  if ($tmpfail);
	print end_html;
	exit 1;
}

print header;
print start_html(
	-title => "Results of Password Change!",
	-style =>
	  { -code => "\tbody {background: lightyellow; color:black;}\n" }
);
print "\n";
my $krbobj = Authen::Krb5::init_context();

if ( !$krbobj ) {
	error( "Unable to initalize Kerberos context to check password!", 1 );
}

my $name = $ENV{'REMOTE_USER'};

# Remove kerberos realm from the user.

if ( !$name ) {
	error( "Unable to determine login name!", 1 );
}
$name =~ s/\@.+$//g;

if ( !defined($k5pw) || !defined($newpw) ) {
	error(
"You must provide both your current Kerberos password and your new network device password."
	);
	exit 0;
}

if ( !defined($newpw2) || $newpw ne $newpw2 ) {
	error("Both values for the new network device password did not match.");
	exit 0;
}

if ( $k5pw eq $newpw ) {
	error(
"Your network device password must not be the same as your Kerberos/login password."
	);
	exit 0;
}

if ( length($newpw) < 8 ) {
	error(
"Your network device password must be at least eight characters long."
	);
	exit 0;
}

if ( !check( $newpw, "/usr/local/lib/cracklib/pw_dict" ) ) {
	error("You have choosen a password that is too easy to guess.");
	exit 0;
}

my $ccache = Authen::Krb5::cc_resolve('MEMORY:setnpasswd');
if ( !defined($ccache) ) {
	error(
"Unable to establish Kerberos credentials cache to check password",
		1
	);
}

my $client = Authen::Krb5::parse_name( $name . '@' . $REALM );

if ( !$client ) {
	error( "Unable to construct client principal for $name", 1 );
}

my $service = Authen::Krb5::parse_name( "krbtgt/" . $REALM . '@' . $REALM );

if ( !$service ) {
	error(
"Unable to construct service principal for password verification",
		1
	);
}

my $code =
  Authen::Krb5::get_in_tkt_with_password( $client, $service, $k5pw, $ccache );
if ( !defined($code) ) {
	my $msg = Authen::Krb5::error();
	if ( $msg eq 'Decrypt integrity check failed' ) {
		error("Your submitted Kerberos password is incorrect.");
	}
	if ( $msg eq 'Client not found in Kerberos database' ) {
		error("You do not have a Kerberos principal.");
	}
	error( "Unknown error: " . $msg );
}

my ( $dbh, $userid );
if (       ( $dbh = OpenJHDBConnection("user-cpw") )
	&& ( $userid = findUserIdFromlogin( $dbh, $name ) )
	&& ChangeUserNetworkPassword( $dbh, $userid, $newpw ) )
{
	print h1("Password Changed Successfully!\n");
	print
	  "It may take up to 15 minutes for your password to propagate to\n";
	print "all of the authentication servers.\n<br>\n";
} else {
	$dbh->disconnect;
	error("Error committing network device password into system database!");
}

print end_html;
$dbh->disconnect;
exit 0;
