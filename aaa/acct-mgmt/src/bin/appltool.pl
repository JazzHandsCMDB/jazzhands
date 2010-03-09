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
# $Id$
#

BEGIN {
	my $dir = $0;
	if ( $dir =~ m,/, ) {
		$dir =~ s!^(.+)/[^/]+$!$1!;
	} else {
		$dir = ".";
	}

	#
	# Copy all of the entries in @INC, and prepend the fakeroot install
	# directory.
	#
	my @SAVEINC = @INC;
	foreach my $incentry (@SAVEINC) {
		unshift( @INC, "$dir/../../fakeroot.lib/$incentry" );
	}
	unshift( @INC, "$dir/../lib/lib" );
}

use strict;
use DBI;
use Getopt::Long;
use Pod::Usage;
use JazzHands::Management qw(:DEFAULT);

my $ShowDevice;
my $ShowMClass;
my $List;
my $Dump;
my $Verbose;
my $ShowPasswords;
my $Application;
my $Create;
my $Rename;
my $Delete;
my $Force;
my $ProdState;
my $DBType;
my $AuthMethod;
my $Username;
my $Password;
my $Keytab;
my $Service;
my $Description;
my @MClass;
my $Add;
my $Remove;
my $Help;

GetOptions(
	"l|list"                       => \$List,
	"f|force"                      => \$Force,
	"d|dump=s"                     => \$Dump,
	"v|verbose"                    => \$Verbose,
	"showdevice|show-device=s"     => \$ShowDevice,
	"showmclass|show-mclass=s"     => \$ShowMClass,
	"create=s"                     => \$Create,
	"delete=s"                     => \$Delete,
	"rename=s"                     => \$Rename,
	"prodstate=s"                  => \$ProdState,
	"dbtype=s"                     => \$DBType,
	"authmethod=s"                 => \$AuthMethod,
	"username=s"                   => \$Username,
	"password=s"                   => \$Password,
	"keytab=s"                     => \$Keytab,
	"service=s"                    => \$Service,
	"description=s"                => \$Description,
	"mclass=s"                     => \@MClass,
	"h|help"                       => \$Help,
	"add"                          => \$Add,
	"remove"                       => \$Remove,
	"showpasswords|show-passwords" => \$ShowPasswords,
);

#
# Process the quick options first.  If we need help, give it.
#
pod2usage() if ($Help);

CheckEligibility();

if ( $Add && $Remove ) {
	print STDERR "May not specify --add and --remove simultaneously\n";
	exit 1;
}

my $jh;
if ( !( $jh = JazzHands::Management->new( application => 'appltool' ) ) ) {
	print STDERR "Unable to open connection to JazzHands\n";
	exit -1;
}

my $dbh = $jh->DBHandle;

if ($List) {
	my $appls = $jh->GetApplications;

	if ( !$appls ) {
		print "No applications.\n";
		exit 0;
	}

	if ($Verbose) {
		printf( "%-5s %-20s %s\n",
			'IntID', 'Name', 'Comment/Description' );
		print
"============================================================\n";
	}
	foreach my $appl ( sort { $a->Name cmp $b->Name } @$appls ) {
		printf( "%5d ", $appl->Id ) if ($Verbose);
		printf( "%-20s ", $appl->{Name} );
		printf( "%s",     $appl->Description )
		  if defined( $appl->Description );
		print "\n";
	}

	exit 0;
}

if ($Dump) {
	my $appl = $jh->GetApplication( name => $Dump );

	if ( !$appl ) {
		print STDERR $jh->Error . "\n";
		exit 0;
	}
	printf "Application:       %s\n",   $appl->Name;
	printf "Application Id:    %s\n\n", $appl->Id;

	my $applinsts = $appl->GetApplicationInstances( application => $appl );

	foreach my $applinst ( values %$applinsts ) {
		PrintApplicationInstanceVerbose($applinst);
		print "\n";
	}
	exit 0;
}

if ($ShowDevice) {
	my $mclasshash = $jh->FindDeviceCollectionForDevice(
		type      => 'mclass',
		name      => $ShowDevice,
		substring => 1
	);
	if ( !$mclasshash ) {
		print STDERR $jh->Error, "\n";
		exit -1;
	}
	foreach my $device ( keys %$mclasshash ) {
		foreach my $devcoll ( $mclasshash->{$device} ) {
			printf "%s is a member of mclass %s\n", $device,
			  $devcoll->Name;
			printf "Application instances assigned to mclass %s:\n",
			  $devcoll->Name;
			PrintMclassApplicationInstances($devcoll);
		}
	}
	exit 0;
}

if ($ShowMClass) {
	my $devcoll = $jh->GetDeviceCollection(
		name => $ShowMClass,
		type => 'mclass'
	);
	if ( !$devcoll ) {
		print STDERR $jh->Error . "\n";
		exit -1;
	}
	printf "Application instances assigned to mclass %s:\n", $devcoll->Name
	  if $Verbose;
	PrintMclassApplicationInstances($devcoll);
	exit;
}

my $appl;
if ($Create) {
	if ( $appl = $jh->GetApplication( name => $Create ) ) {
		print "Application $Create already exists.\n";
		exit -1;
	} else {
		if ($Description) {
			$appl = $jh->CreateApplication(
				name        => $Create,
				description => $Description
			);
		} else {
			$appl = $jh->CreateApplication( name => $Create );
		}
		if ( !$appl ) {
			print $jh->Error . "\n";
			exit 1;
		}
		printf "Application '%s' created with id '%s'.\n", $appl->Name,
		  $appl->Id;
	}
}

if ($Delete) {
	my $applinst;
	if ( !( $appl = $jh->GetApplication( name => $Delete ) ) ) {
		print "Application $Delete does not exist.\n";
		exit -1;
	}
	if ($ProdState) {
		if (
			!(
				$applinst = $appl->GetApplicationInstance(
					application => $appl,
					prodstate   => $ProdState
				)
			)
		  )
		{
			print STDERR $appl->Error . "\n";
			exit 1;
		}
		if ( !( $applinst->Delete( force => $Force ) ) ) {
			print STDERR $applinst->Error . "\n";
		} else {
			printf "%s instance of application '%s' deleted.\n",
			  $ProdState, $Delete;
		}
	} else {
		if ( !( $appl->Delete( force => $Force ) ) ) {
			print STDERR $appl->Error . "\n";
		} else {
			printf "Application '%s' deleted.\n", $Delete;
		}
	}
	$jh->commit;
	exit;
}

#
# All of the other commands require an application to be given, which
# should be the only thing left on the command line after argument
# processing
#

my $applname = shift;
if ( !$appl && !$applname ) {
	print STDERR "Must specify application.\n";
	exit -1;
}

if ( !$appl ) {
	if ( !( $appl = $jh->GetApplication( name => $applname ) ) ) {
		print "Application $applname does not exist.\n";
		exit -1;
	}
}

if ( defined($Description) ) {
	if ( !defined( $appl->Description($Description) ) ) {
		print STDERR $appl->Error . "\n";
		$jh->rollback;
		exit 1;
	}
}

if ($Rename) {
	if ( !defined( $appl->Name($Rename) ) ) {
		print STDERR $appl->Error . "\n";
		$jh->rollback;
		exit 1;
	}
	printf STDERR "Application '%s' renamed to '%s'.\n", $applname, $Rename;
}

#
# Turns out everything else requires an ApplicationInstance, so they require
# the production state, too
#
my $applinst;
my $instcreated = 0;
if ($ProdState) {
	if ( !( $applinst = $appl->GetInstance( prodstate => $ProdState ) ) ) {
		if ( !$DBType ) {
			printf STDERR
"No instance of application '%s' exists with production state '%s'\n",
			  $applname, $ProdState;
			print STDERR
			  "You must specify --dbtype to create this instance\n";
			exit 1;
		}
		if ( !$AuthMethod ) {
			$AuthMethod = 'password';
		}
		if (
			!(
				$applinst = $appl->CreateInstance(
					prodstate  => $ProdState,
					authmethod => $AuthMethod,
					dbtype     => $DBType
				)
			)
		  )
		{
			print STDERR $appl->Error . "\n";
			exit 1;
		}
		$instcreated = 1;
	}
}

# skip this if we just created the instance

if ( $AuthMethod && !$instcreated ) {
	if ( !$applinst ) {
		print STDERR
"Production state must be given with --prodstate to set authentication method\n";
		exit 1;
	}
	if ( !defined( $applinst->AuthMethod($AuthMethod) ) ) {
		print STDERR $applinst->Error . "\n";
		exit 1;
	}
}

# skip this if we just created the instance

if ( $DBType && !$instcreated ) {
	if ( !$applinst ) {
		print STDERR
"Production state must be given with --prodstate to set database type\n";
		exit 1;
	}
	if ( !defined( $applinst->DBType($DBType) ) ) {
		print STDERR $applinst->Error . "\n";
		exit 1;
	}
}

if ($Service) {
	if ( !$applinst ) {
		print STDERR
"Production state must be given with --prodstate to set service\n";
		exit 1;
	}
	if ( !defined( $applinst->Service($Service) ) ) {
		print STDERR $applinst->Error . "\n";
		exit 1;
	}
}

if ($Password) {
	if ( !$applinst ) {
		print STDERR
"Production state must be given with --prodstate to set password\n";
		exit 1;
	}
	if ( !defined( $applinst->Password($Password) ) ) {
		print STDERR $applinst->Error . "\n";
		exit 1;
	}
}

if ($Username) {
	if ( !$applinst ) {
		print STDERR
"Production state must be given with --prodstate to set username\n";
		exit 1;
	}
	if ( !defined( $applinst->Username($Username) ) ) {
		print STDERR $applinst->Error . "\n";
		exit 1;
	}
}

if ($Add) {
	if ( !$applinst ) {
		print STDERR
"Production state must be given with --prodstate to add to mclass\n";
		exit 1;
	}
	if ( !@MClass ) {
		print
"Mclass must be given with --mclass when --add is specified\n";
		exit 1;
	}
	foreach my $mclass (@MClass) {
		my $devcoll = $jh->GetDeviceCollection(
			name => $mclass,
			type => 'mclass'
		);
		if ( !$devcoll ) {
			print STDERR $jh->Error . "\n";
			next;
		}
		if ( !( $devcoll->AddApplicationInstance($applinst) ) ) {
			print STDERR $devcoll->Error . "\n";
			next;
		}
		printf
		  "Application '%s', prodstate '%s' added to mclass '%s'\n",
		  $applname, $ProdState, $mclass;
	}
}

if ($Remove) {
	if ( !$applinst ) {
		print STDERR
"Production state must be given with --prodstate to remove from mclass\n";
		exit 1;
	}
	if ( !@MClass ) {
		print
"Mclass must be given with --mclass when --remove is specified\n";
		exit 1;
	}
	foreach my $mclass (@MClass) {
		my $devcoll = $jh->GetDeviceCollection(
			name => $mclass,
			type => 'mclass'
		);
		if ( !$devcoll ) {
			print STDERR $jh->Error . "\n";
			next;
		}
		if ( !( $devcoll->RemoveApplicationInstance($applinst) ) ) {
			print STDERR $devcoll->Error . "\n";
			next;
		}
		printf
		  "Application '%s', prodstate '%s' removed from mclass '%s'\n",
		  $applname, $ProdState, $mclass;
	}
}

$jh->commit;

exit;

sub PrintMclassApplicationInstances {
	my $devcoll = shift;

	my $applinstances =
	  $devcoll->GetApplicationInstances( devicecollection => $devcoll );

	if ( !defined($applinstances) ) {
		print STDERR $jh->Error . "\n";
		exit -1;
	}
	if ($Verbose) {
		if ($ShowPasswords) {
			printf "%-25s  %-10s  %-20s %-15s %-20s %s\n\n",
			  "Application", "ProdState", "Username", "Password",
			  "DBType", "Service";
		} else {
			printf "%-25s  %-10s  %-20s %-15s %s\n\n",
			  "Application", "ProdState", "Username", "DBType",
			  "Service";
		}
	}

	foreach my $instance ( values %$applinstances ) {
		PrintApplicationInstanceBrief($instance);
	}
}

sub PrintApplicationInstanceBrief {
	my $instance = shift;

	if ( !$Verbose ) {
		printf "%-30s  %s\n", $instance->Application->Name,
		  $instance->ProductionState;
	} elsif ($ShowPasswords) {
		printf "%-25s  %-10s  %-20s %-15s %-20s %s\n",
		  $instance->Application->Name, $instance->ProductionState,
		  ( $instance->Username || "" ), ( $instance->Password || "" ),
		  ( $instance->DBType   || "" ), ( $instance->Service  || "" );
	} else {
		printf "%-25s  %-10s  %-20s %-15s %s\n",
		  $instance->Application->Name, $instance->ProductionState,
		  $instance->Username, $instance->DBType, $instance->Service;
	}
}

sub PrintApplicationInstanceVerbose {
	my $instance = shift;

	printf "Production State:  %s\n", $instance->ProductionState;
	printf "Database Type:     %s\n", ( $instance->DBType   || "" );
	printf "Service:           %s\n", ( $instance->Service  || "" );
	printf "Username:          %s\n", ( $instance->Username || "" );
	if ($ShowPasswords) {
		printf "Password:          %s\n", ( $instance->Password || "" );
	}
	printf "MClasses:          ";
	if ( !@{ $instance->DeviceCollections } ) {
		print "none\n";
	} else {
		if ( !$Verbose ) {
			my @devcollnames;
			foreach
			  my $devcoll ( @{ $instance->DeviceCollections } )
			{
				push @devcollnames, $devcoll->Name;
			}
			print( ( join ", ", @devcollnames ) . "\n" );
		} else {
			print "\n";
			foreach
			  my $devcoll ( @{ $instance->DeviceCollections } )
			{
				printf "    %s:\n", $devcoll->Name;
				my $devices = $devcoll->Devices;
				if ( !defined($devices) ) {
					print STDERR $devcoll->Error . "\n";
				}
				foreach my $device (@$devices) {
					printf "        %s\n", $device->Name;
				}
			}
		}
	}
}

__END__;

=head1 NAME

appltool - manage database authentication layer application parameters

=head1 SYNOPSIS

appltool [B<--verbose>] B<--list>

appltool [B<--verbose>] B<--dump> I<application>

appltool B<--showdevice> I<device>

appltool B<--showmclass> I<mclass>

appltool B<--create> I<application>

appltool B<--delete> I<application> [B<--prodstate> I<state>] [B<--force>]

appltool I<application> B<--prodstate> I<state> [B<--dbtype> I<type>] [B<--authmethod> I<method>] [B<--username> I<dbuser>] [B<--password> I<password>] [B<--keytab> I<keytab>] [B<--service> I<service>]

appltool I<application> B<--description> I<description>>

appltool I<application> B<--rename> I<name>

appltool I<application> B<--add> B<--mclass> I<mclass> B<--prodstate> I<state>

appltool I<application> B<--remove> B<--mclass> I<mclass> B<--prodstate> I<state>


=head1 DESCRIPTION

B<appltool> is used to manage database application authentication information
which is used by the database authentication abstraction layer.  B<appltool>
will create, modify, or delete application names and authentication 
data for any of the given production types and can assign it to or remove 
it from an mclass.

=head1 OPTIONS

=over 4

=item B<--help>

Print command usage

=item B<--verbose>

Be more verbose about what is printed.

=item B<--list>

Print a list of applications and their descriptions.  If the B<--verbose>
option is also given, the list will also contain the internal application ID.

=item B<--dump>

Show information about the specific application, including all instances
of the application and the mclasses to which the application is assigned.
If the B<--verbose> option is given, the mclasses are expanded to show all
of the devices to which the application is assigned.

=item B<--showdevice> I<device>

Show information about application assignment to a specific device.

=item B<--showmclass> I<mclass>

Show information about application assignment to a specific mclass 

=item B<--create> I<application>

Create an application with the given name.

=item B<--delete> I<application>

Delete an application.  If the B<--prodstate> option is given, this will
delete only that particular instance of the application.  Before an
application instance can be deleted, all of its mclass assignments must
be removed.  Before an application can be deleted, all application instances
must be deleted from that application.  Passing the B<--force> option
performs these removals with prejudice and without confirmation.

=item B<--description> I<description>

Set the description of the application.  The description can be cleared by
running:

appltool I<application> --description ''

=item B<--prodstate> I<state>

Specify a production state.  This must be specified to assign or remove
an application instance to or from an mclass, or to set any of the
following parameters on an application instance:  dbtype, authmethod,
username, password, keytab, or service.

=item B<--dbtype> I<type>

Set the database type of the application instance.

=item B<--authmethod> I<authmethod>

Set the authentication method of the application instance.

=item B<--username> I<username>

Set the username of the application instance.

=item B<--password> I<password>

Set the password of the application instance.

=item B<--keytab> I<keytab>

Set the path to the Kerberos keytab for the application instance for
applications that use Kerberos/GSSAPI authentication.

=item B<--service> I<service>

Set the service name/database connection parameters for the application
instance.

=item B<--add> B<--mclass> I<mclass> [B<--mclass> I<mclass> ...]

Add the application instance to the specified mclass.  The --mclass
parameter may be repeated to assign it to multiple mclasses.

=item B<--remove> B<--mclass> I<mclass> [B<--mclass> I<mclass> ...]

Remove the application instance from the specified mclass.  The --mclass
parameter may be repeated to remove it from multiple mclasses.

=head1 NOTES

An application instance is comprised of the application authorization 
parameters for a given application for a given production state, and is
identified by specifying the application and the production state.
Application instances are automatically created when their parameters are
set; they are not manually created.  However, the --dbtype parameter is
required for the application instance to be created.  The authentication
method defaults to 'password' unless it is otherwise specified.

=back

=head1 ENVIRONMENT

The environment does not impact this command.

=head1 SEE ALSO

L<usertool(8)>, L<uclasstool(8)>, L<mclasstool(8)>, L<grouptool(8)>, L<depttool(8)>, L<aliastool(8)>

=head1 AUTHOR

Matthew Ragan

=cut
