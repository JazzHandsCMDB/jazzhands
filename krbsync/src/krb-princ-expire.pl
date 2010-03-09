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

#
# $Id$
#
# query jazzhands for accounts that should no longer have access and expire
# the principal
#
# --verbose -- print what gets done
# --debug -- print analysis (implies --verbose)
# --full - look at all accounts instead of just the ones from the past 3 days
#

use Sys::Syslog qw/:DEFAULT/;
use POSIX;
use JazzHands::DBI;
use Authen::Krb5;
use Authen::Krb5::Admin qw/:constants/;
use Getopt::Long qw(:config no_ignore_case bundling);

#
# Initialization
#
Authen::Krb5::init_context();

my $admin_princ = "krb_expirator";
my $keytab      = "/etc/krb5.keytab.krb_expirator";

openlog( 'krbsync', 'pid', LOG_LOCAL2 );

#
# Setup Kerberos
#
my $realm = Authen::Krb5::get_default_realm() || warn "failed to get realm";
my $cc    = Authen::Krb5::cc_default()        || warn "failed to get cc";
my $clientp = Authen::Krb5::parse_name($user) || warn "failed to get clientp for
 $user";
$cc->initialize($clientp) || warn "failed to initalize";

my ( $debug, $verbose, $full );

GetOptions(
	'debug'   => \$debug,      # be extra verbose to the point of annoyance
	'verbose' => \$verbose,    # be verbose in what's going on
	'full'    => \$full        # don't limit by date
);

my $dbh = JazzHands::DBI->connect( "jazzhands_krb", { AutoCommit => 0 } );

$verbose = 1 if ($debug);

my $handle = Authen::Krb5::Admin->init_with_skey( $admin_princ, $keytab );

if ( !$handle ) {
	warn Authen::Krb5::Admin::error;
	secretive_death;
}

my $now = time;

my $datelimit = 'and termination_date >= (sysdate - 3)' if ( !defined($full) );

my $q = qq{
	select	system_user_id, login, system_user_status, termination_date
	  from	system_user
	 where	system_user_status in ('forcedisable', 'terminated')
	    or  (system_user_status in 
			('deleted', 'forcedisable', 'terminated', 'walked')
		 $datelimit)
	order by login
};

my $sth = $dbh->prepare($q) || die $dbh->errstr;
$sth->execute || die $sth->errstr;

while ( my ( $id, $login, $status, $termdate ) = $sth->fetchrow_array ) {
	print "Considering $login\n" if ($debug);
	my $search = $login;
	foreach my $dude ( $handle->get_principals("$search*") ) {
		print " -> considering $dude\n" if ($debug);
		my $dudeonly = $dude;
		$dudeonly =~ s/\@.*$//;
		if ( $dudeonly ne $search && $dudeonly !~ m,^$search/, ) {
			next;
		}
		$whence = get_expire_time( $handle, $dude );
		print "    -> $whence aka ", ctime($whence) if ($debug);
		if ( $whence == 0 || $whence >= $now ) {
			print "expiring $dude\n" if ($verbose);
			syslog( LOG_INFO, "expiring krb principal %s", $dude );
			expire_princ( $handle, $dude, $now );
		}
	}
}

$dbh->rollback;
$dbh->disconnect;

sub get_expire_time {
	my ( $krb5, $dude ) = @_;

	# Authen::Krb5::Admin::Policy
	my $name = Authen::Krb5::parse_name($dude) || warn "parse_name($dude)";
	$princ = $krb5->get_principal( $name, KADM5_PRINCIPAL_NORMAL_MASK )
	  || die $krb5->error;
	$princ->princ_expire_time;
}

sub expire_princ {
	my ( $krb5, $dude, $whence ) = @_;

	my $name = Authen::Krb5::parse_name($dude) || warn "parse_name($dude)";
	$princ = $krb5->get_principal( $name, KADM5_PRINCIPAL_NORMAL_MASK )
	  || warn $krb5->error;
	$princ->princ_expire_time($whence);
	$krb5->modify_principal($princ);
}
