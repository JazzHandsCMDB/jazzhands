#!/usr/local/bin/perl
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
use JazzHands::ActiveDirectory;
use Authen::Krb5;
use Authen::Krb5::Admin qw/:constants/;
use JazzHands::Management;

Authen::Krb5::init_context();

my $admin_princ = "password_syncer";
my $keytab      = "/etc/krb5.keytab-password_syncer";
my $addomain    = "AD.EXAMPLE.COM";

my $user = lc( param('user') );
my $pw   = param('pw');

$ENV{'KRB5CCNAME'} = "/tmp/passwordsyncer_$user";
my $sam = "$user\@$addomain";

sub baduserpass {
	print header;
	print start_html( -title => 'Sorry!' ), "\n";
	print h3("You either either entered a bad username or a bad password"),
	  "\n";
	print end_html, "\n";
	exit 0;
}

sub secretive_death {
	print header;
	print start_html( -title => 'Sorry!' ), "\n";
	print h3("Something unexpected happened. Check logs."), "\n";
	print end_html, "\n";
	exit 0;
}

#
# requires $user and $pw globals
#
sub syncjhpass {
	my ( $dbh, $userid );
	if (
		!(
			   ( $dbh = OpenJHDbConnection("user-cpw") )
			&& ( $userid = findUserIdFromlogin( $dbh, $user ) )
			&& ChangeUserPassword( $dbh, $userid, $pw )
		)
	  )
	{
		warn "JazzHands failure on syncing for $user";
		secretive_death;
	}
	$dbh->commit;
	$dbh->disconnect;
}

if ( $user !~ /^[\w\-]+$/ ) {
	warn "attempt to change $user";
	secretive_death;
}

#
# AD Bind test -- see if the password can connect to AD's LDAP (catalog server)
#
my $ldap = JazzHands::ActiveDirectory->new(
	username => $user,
	password => $pw
);
if ( !ref($adh) ) {
	warn "ldap->bind failed for $sam: ", $adh;
	baduserpass();
}

#
# Init krb5 server principal
#
my $realm = Authen::Krb5::get_default_realm() || warn "failed to get realm";
my $cc    = Authen::Krb5::cc_default()        || warn "failed to get cc";
my $clientp = Authen::Krb5::parse_name($user) || warn "failed to get clientp for
 $user";
my $serverp = Authen::Krb5::parse_name("krbtgt/$realm\@$realm") || warn "failed
to get clientp for $user";
$cc->initialize($clientp) || warn "failed to initalize";

#
# Try and get user principal with password given. If it works, passwords are already in sync.
#
if ( Authen::Krb5::get_in_tkt_with_password( $clientp, $serverp, $pw, $cc ) ) {

	#
	# really want to verify against a keytab just to make sure it's
	# correct, but since success is the basis for inaction, there's no
	# real point...
	#
	print header;
	print start_html( -title => 'Results of Password Sync!' ), "\n";

	print h3("Your passwords are already sync'd.\n"), "\n";
	unlink $ENV{'KRB5CCNAME'};
	exit 0;
} else {

	#
	# Get an admin handle
	#
	warn "krb5 check: " . Authen::Krb5::error;
	my $handle =
	  Authen::Krb5::Admin->init_with_skey( $admin_princ, $keytab );

	if ( !$handle ) {
		warn Authen::Krb5::Admin::error;
		secretive_death;
	}

	#
	# See if principal already exists
	#
	my $ap = $handle->get_principal( $clientp,
		KADM5_PRINCIPAL_NORMAL_MASK | KADM5_KEY_DATA );
	if ($ap) {

#
# Principal exists, and failed krb auth above, so password must be wrong. Change it.
#
		my $return = $handle->chpass_principal( $clientp, $pw );
		if ( !$return ) {
			warn Authen::Krb5::Admin::error;
			secretive_death;
		}

# sync with jazzhands -- probably redundant since the ldap check we passed pulls from it.
		syncjhpass();

		print header;
		print start_html( -title => 'Results of Password Sync!' ), "\n";
		print h3(
"You already had an account in the new realm, so the password has been synced."
		);
	} else {

		#
		# No Principal. Create one.
		#
		my $newprinc = Authen::Krb5::Admin::Principal->new
		  || warn Authen::Krb5::Admin::error;
		$newprinc->principal($clientp);
		$newprinc->kvno(2);
		$handle->create_principal( $newprinc, $pw )
		  || warn Authen::Krb5::Admin::error;

		print header;
		print start_html( -title => 'Results of Password Sync!' ), "\n";
		print h3("Your Kerberos principal has been created.");
	}

#
# sync with jazzhands -- probably redundant since the ldap check we passed pulls from it.
#
	print h3("Syncing with JazzHands...");
	syncjhpass();
	print h3("Done!");
}
