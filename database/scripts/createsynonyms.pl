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

#
# ** WANT TO SKIP AUDIT TABLES, SYNONYMS, MAYBE OTHERS? **
#

use strict;
use DBI;
use DBD::Oracle;
use Pod::Usage;
use Getopt::Long;

BEGIN {
	$ENV{'ORACLE_HOME'} = '/usr/vendor/pkg/oracle/product/10.2.0/'
	  if ( !defined( $ENV{'ORACLE_HOME'} ) );
}

my (
	$verbose, $dbauser,  $appuser, $approle, $create,
	$apppass, $password, $help,    $readonly
);
my $update = 0;
my $schema = "JAZZHANDS";
my $database;

GetOptions(
	"verbose"             => \$verbose,
	"update!"             => \$update,
	"database=s"          => \$database,
	"dba-user=s"          => \$dbauser,
	"dba-user-password=s" => \$password,
	"app-user=s"          => \$appuser,
	"app-user-password=s" => \$apppass,
	"app-role=s"          => \$approle,
	"schema-owner=s"      => \$schema,
	"create-user"         => \$create,
	"read-only"           => \$readonly,
	"help"                => \$help
);

if ($help) {
	pod2usage();
	exit 1;
}

$verbose = 1 if ( !$update );

if ( !$dbauser || !$database || !$appuser ) {
	print
"Usage: $0 [options] --dba-user dba_user --app-user app_user --database database\n";
	print
" [options]:  update! (create sql, but dont execute), verbose (spit out sql), read-only (selects privs only),\n";
	print "             help (get help)\n";
	exit 1;
}

$appuser = uc($appuser);
$schema  = uc($schema);
if ( !$approle ) {
	$approle = $appuser . "_ROLE";
}

if ( !$password ) {
	system('stty -echo');
	print STDERR "Password: ";
	$password = <STDIN>;
	chomp($password);
	print "\n";
	system('stty echo');
}

my @CHR = split //,
  "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz%^*.;:";

my $dbh;
if (
	!(
		$dbh =
		DBI->connect( "dbi:Oracle:" . $database, $dbauser, $password )
	)
  )
{
	printf STDERR "Unable to connect to database: %s\n", $DBI::errstr;
	exit 1;
}
$dbh->{PrintError} = 0;
$dbh->{AutoCommit} = 0;

if ($create) {
	$apppass = &genpass if !$apppass;
	runsql(qq{CREATE USER $appuser IDENTIFIED BY "$apppass"});
	runsql("CREATE ROLE $approle");
	runsql("GRANT CREATE SESSION TO $approle");
	runsql("GRANT $approle TO $appuser");
	if ( !$verbose ) {
		print "User '${appuser}' created with password '${apppass}'\n";
	}
}
my ( $objecth, $q, $sth );

$objecth = $dbh->prepare(
	qq{
	SELECT
		OBJECT_NAME 
	FROM
		DBA_OBJECTS
	WHERE
		OWNER = ? AND
		OBJECT_TYPE = ?
}
);

$objecth->execute( $schema, "TABLE" ) || die $DBI::errstr;
while ( my $table = ( $objecth->fetchrow_array )[0] ) {
	runsql( "DROP SYNONYM ${appuser}.$table", 1 );
	next if ( $table =~ /^AUD\$/ );
	runsql("CREATE SYNONYM ${appuser}.$table FOR ${schema}.$table");
	if ($readonly) {
		runsql("GRANT SELECT ON ${schema}.$table TO ${approle}");
	} else {
		runsql(
"GRANT SELECT, UPDATE, INSERT, DELETE ON ${schema}.$table TO ${approle}"
		);
	}
}

$objecth->execute( $schema, "VIEW" ) || die $DBI::errstr;
while ( my $table = ( $objecth->fetchrow_array )[0] ) {
	runsql( "DROP SYNONYM ${appuser}.$table", 1 );
	runsql("CREATE SYNONYM ${appuser}.$table FOR ${schema}.$table");
	if ($readonly) {
		runsql("GRANT SELECT ON ${schema}.$table TO ${approle}");
	} else {
		runsql(
"GRANT SELECT, UPDATE, INSERT, DELETE ON ${schema}.$table TO ${approle}"
		);
	}
}

if ( !$readonly ) {

	#$objecth->execute($schema, "SEQUENCE") || die $DBI::errstr;
	while ( my $sequence = ( $objecth->fetchrow_array )[0] ) {
		runsql( "DROP SYNONYM ${appuser}.$sequence", 1 );

	#	runsql("CREATE SYNONYM ${appuser}.$sequence FOR ${schema}.$sequence");
	#	runsql("GRANT SELECT ON ${schema}.$sequence TO ${approle}");
	}

	$objecth->execute( $schema, "PACKAGE" ) || die $DBI::errstr;
	while ( my $package = ( $objecth->fetchrow_array )[0] ) {
		runsql( "DROP SYNONYM ${appuser}.$package", 1 );
		runsql(
"CREATE SYNONYM ${appuser}.$package FOR ${schema}.$package"
		);
		runsql("GRANT EXECUTE ON ${schema}.$package TO ${approle}");
		runsql("GRANT EXECUTE ON ${schema}.$package TO ${approle}");
	}
}
$objecth->finish;

$dbh->disconnect;

sub runsql {
	my $sql         = shift;
	my $ignoreerror = shift;

	if ($verbose) {
		print $sql, ";\n";
	}
	return if ( !$update );

	my $sth;
	if ( !( $sth = $dbh->prepare($sql) ) ) {
		printf STDERR "Error preparing SQL statement:\n%s\n%s\n", $sql,
		  $DBI::errstr;
		exit 1;
	}
	if ( !$sth->execute && !$ignoreerror ) {
		printf STDERR "Error executing SQL statement:\n%s\n%s\n", $sql,
		  $DBI::errstr;
		exit 1;
	}
	$sth->finish;
}

sub genpass {
	my $pass;
	foreach my $i ( 1 .. 8 ) {
		$pass .= $CHR[ int( rand( $#CHR + 1 ) ) ];
	}
	return $pass;
}

__END__

=head1 NAME

createsynonyms - create synonyms and grant permissions to jazzhands objects

=head1 SYNOPSIS

Usage: createsynonyms [options] B<--dba-user> I<dbauser> B<--app-user> I<appuser>

=head1 DESCRIPTION

createsynonyms connects to an Oracle database instance and creates synonyms
for and grants to all the object in the (by default) JAZZHANDS schema.  An
account with DBA privileges needs to be used to perform this.  Optionally,
the target user account and associated role can be created, or the SQL
to effect these changes can be listed without actually making the change
in the database.

=head1 MANDATORIES AND OPTIONS

=over 4

=item B<--dba-user> I<dbauser>

Connect to the database as I<dbauser>.  This user must have DBA privileges
on the database, or createsynonyms will fail.  This parameter has no
defaults and must be given.

=item B<--app-user> I<appuser>

Application target user to create synonyms and grants for.  This user (and
its corresponding role) must exist in the database, unless the B<--create-user>
option is given.  This parameter has no defaults and must be given.

=item B<--database> I<database>

Connect to database I<database>.  This parameter has no defaults and must
be given

=item B<--read-only>

Give read-only access to schema objects.

=item B<--schema-owner> I<user>

Create synonyms and grants from schema I<user> instead of the default
JAZZHANDS.  I<user> is case-sensitive.

=item B<--app-role> I<approle>

Use I<approle> for the name of the ROLE to grant permissions to.  By
default, this is I<appuser>_ROLE

=item B<--create-user>

Create the application user and its corresponding role (either the default
or passed by B<--app-role> if it does not exist.

=item B<--app-user-password> I<password>

Assign I<password> to the application user if B<--create-user> is given.
If this parameter is not given, a random password will be generated
and displayed

=item B<--dba-user-password> I<password>

Use I<password> for the DBA user password instead of prompting for it.
Not recommended.

=item B<--[no]update>

If B<--update> is given, modifications will be made to the database will be
made.  B<--noupdate> implies B<--verbose>.

=item B<--verbose>

Print SQL that is to be executed.

=back 4
