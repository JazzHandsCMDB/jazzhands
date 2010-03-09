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

use strict;
use JazzHands::Management;
use Getopt::Long;
use Socket;
use POSIX;
use Digest::MD5;

my $verbose            = 0;
my $update             = 1;
my $tacacs             = 1;
my $radius             = 1;
my $radius_username    = "radius";
my $tacacs_username    = "tacacs";
my $tacacs_filename    = "/prod/tacacs/conf/tac_plus.conf";
my $tacacs_acctfile    = "/prod/tacacs/log/tacacs.log";
my $radius_userfile    = "/prod/radius/intaaa/users";
my $radius_clientsfile = "/prod/radius/intaaa/clients.conf";

our $__db_cache = 1;

#
# TACACS KEYS AND RADIUS SECRETS ARE STORED HERE FOR NOW.  THIS NEEDS TO GET
# INTO THE DATABASE SOMEHOW.
#
my $tacacs_key    = "tacsecret";
my $radius_secret = "radsecret";

GetOptions(
	'verbose!'            => \$verbose,
	'update!'             => \$update,
	'tacacs!'             => \$tacacs,
	'radius!'             => \$radius,
	'tacfilename=s'       => \$tacacs_filename,
	'tacacctfile=s'       => \$tacacs_acctfile,
	'raduserfilename=s'   => \$radius_userfile,
	'radclientfilename=s' => \$radius_clientsfile,
	'tackey=s'            => \$tacacs_key,
	'radsecret=s'         => \$radius_secret
);

my $dbh = OpenJHDBConnection || die $DBI::errstr;

###
### All this needs to get moved to modules, but it isn't happening right now
###

# Get a list of network devices and their corresponding mclasses

my ( $q, $sth );

$q = qq{
	SELECT 
		D.Device_Name, DCM.Device_Collection_ID, DF.Device_Function_Type
	FROM 
		Device_Collection_Member DCM, Device_Function DF, Device D,
		Device_Collection DC
	WHERE 
		DCM.Device_ID = D.Device_ID AND
		DF.Device_ID = D.Device_ID AND
		DC.Device_Collection_ID = DCM.Device_Collection_ID AND
		Device_Collection_Type = 'mclass' AND
		DF.Device_Function_Type IN
			('router', 'switch', 'consolesrv', 'firewall', 'rpc')
};

$sth = $dbh->prepare($q) || dbdie($q);
$sth->execute || dbdie($q);

my ( %devicemclass, %devicetype, %mclasses );
while ( my $row = $sth->fetchrow_arrayref ) {

	# Skip if there is no device name
	next if ( !$row->[0] );
	$devicemclass{ $row->[0] } = $row->[1];
	$devicetype{ $row->[0] }   = $row->[2];
	$mclasses{ $row->[1] }++;
}

$sth->finish;

# Get list of active users for all of these mclasses

my ( %loginname, %deleted );
my %mclassusers;

$q = qq { 
	SELECT
		SU.Login, 
		SP.Network_Device
	FROM
		System_User SU,
		System_Password SP
	WHERE
		SU.System_User_ID = ? AND
		SU.System_User_ID = SP.System_User_ID AND
		SU.System_User_Status = 'enabled'
};
my $mcsth = $dbh->prepare($q) || dbdie($q);

foreach my $mclass ( sort keys %mclasses ) {
	$mclassusers{$mclass} = [];
	my $userlist = GetUserListForMclass( $dbh, $mclass, 1, 1 );

	foreach my $key ( keys %$userlist ) {
		if (       !defined( $loginname{$key} )
			&& !defined( $deleted{$key} ) )
		{
			$mcsth->execute($key) || dbdie($q);

			$loginname{$key} = {};
			(
				$loginname{$key}->{username},
				$loginname{$key}->{crypt}
			) = $mcsth->fetchrow_array;
			if ( !$loginname{$key}->{username} ) {
				delete $loginname{$key};
				$deleted{$key} = $key;
				next;
			}
		}
		push @{ $mclassusers{$mclass} }, $loginname{$key}
		  unless $deleted{$key};
	}
	$mcsth->finish;
}

#
# This is a hack.  This authorization needs to move completely into the
# database, but for now, anyone in the 'full-network-device-access' uclass
# will get full enable access, anyone in the 'limited-network-device-access'
# uclass will get limited enable access and others... will not.  Greatest
# access wins (i.e. if a user is in both 'full-...' and 'limited-...',
# he or she will get 'full-...' access
#

my ( $uclass, $users, %fullusers, %limitedusers );

$uclass = findUclassIdFromName( $dbh, 'full-network-device-access', 'systems' );
if ($uclass) {
	$users = getAllUsersFromUclass( $dbh, $uclass, 0 );
	foreach my $user ( keys %$users ) {
		$fullusers{$user} = $user;
	}
}
$uclass =
  findUclassIdFromName( $dbh, 'limited-network-device-access', 'systems' );
if ($uclass) {
	$users = getAllUsersFromUclass( $dbh, $uclass, 0 );
	foreach my $user ( keys %$users ) {
		$limitedusers{$user} = $user;
	}
}

# Done with the database.  Yay.
$dbh->disconnect;

if ($tacacs) {
	my $tmptacuserfile = $tacacs_filename . "." . time() . "." . $$;
	if (
		!sysopen( TACUSER, $tmptacuserfile,
			O_WRONLY | O_EXCL | O_CREAT, 0644
		)
	  )
	{
		print STDERR
"Unable to open temporary TACACS user file $tmptacuserfile: $!\n";
		exit;
	}

	print TACUSER <<EOM;
##
## This file is automatically generated!
##
## Any changes you make here will be lost!
##

key = $tacacs_key

accounting file = $tacacs_acctfile

group = fulladmin {
	default service = permit
	service = exec {
		priv-lvl = 15
	}
	service = junos-exec {
		local-user-name = operations
	}
}

group = limitedadmin {
	default service = permit
	service = exec {
		priv-lvl = 8
	}
	service = junos-exec {
		local-user-name = restricted
	}
}

EOM

      #
      # This is such a hack.  Basically, what happens here is that if a user
      # is listed as having access to any network device, that users has access
      # to *ALL* network devices.  This sucks, but the TACACS+ daemon doesn't
      # have this kind of granularity built into it.  We will get around this
      # in the near future by using an external script for authorization.  This
      # part will stay the same (with one additional line to specify an external
      # authorization script), but the authorization will take place elsewhere.
      #
	foreach my $user (
		sort {
			$loginname{$a}->{username}
			  cmp $loginname{$b}->{username}
		} keys %loginname
	  )
	{
		my $hash = $loginname{$user};
		next if !$hash->{username};
		printf TACUSER "\nuser = %s {\n\tlogin = des %s\n",
		  $hash->{username}, $hash->{crypt} || '*';
		if ( $fullusers{$user} ) {
			print TACUSER "\tmember = fulladmin\n";
		} elsif ( $limitedusers{$user} ) {
			print TACUSER "\tmember = limitedadmin\n";
		}
		print TACUSER "}\n";
	}

	close TACUSER;
	system("chown $tacacs_username $tmptacuserfile");

	#	system("diff $tacacs_filename $tmptacuserfile >/dev/null 2>&1");
	if ( md5_diff( $tacacs_filename, $tmptacuserfile ) ) {
		unlink $tmptacuserfile;
	} else {
		my ( $dirname, $basename );
		( $dirname, $basename ) = $tacacs_filename =~ m%(.*/?)[^/]*$%;
		if ( !$basename ) {
			$basename = $dirname;
			$dirname  = "";
		}
		my $oldfile;
		my ( $sec, $min, $hour, $mday, $mon, $year ) =
		  ( localtime(time) )[ 0, 1, 2, 3, 4, 5 ];
		$oldfile = sprintf "%ssave/%s.%04d%02d%02d%02d%02d%02d",
		  $dirname, $basename, $year + 1900, $mon + 1, $mday, $hour,
		  $min, $sec;
		rename $tacacs_filename, $oldfile;
		rename $tmptacuserfile,  $tacacs_filename;
		system("pkill -USR1 -u root -P 1 tac_plus") if $update;
	}
}

if ($radius) {
	my $tmpraduserfile = $radius_userfile . "." . time() . "." . $$;
	if (
		!sysopen( RADUSER, $tmpraduserfile,
			O_WRONLY | O_EXCL | O_CREAT, 0644
		)
	  )
	{
		print STDERR
"Unable to open temporary RADIUS user file $tmpraduserfile: $!\n";
		exit;
	}

	my $tmpradclientsfile = $radius_clientsfile . "." . time() . "." . $$;
	if (
		!sysopen( RADCLIENT, $tmpradclientsfile,
			O_WRONLY | O_EXCL | O_CREAT, 0644
		)
	  )
	{
		print STDERR
"Unable to open temporary RADIUS client file $tmpradclientsfile: $!\n";
		exit;
	}

      #
      # Now process the RADIUS file.  It's a little more complicated, because
      # TACACS+ is dumber in this regard.  One day these will both have the same
      # capabilities.
      #

	print RADUSER "##\n## This file is automatically generated!\n##\n";
	print RADUSER "## Any changes you make here will be lost!\n##\n\n";

	print RADCLIENT "##\n## This file is automatically generated!\n##\n";
	print RADCLIENT "## Any changes you make here will be lost!\n##\n\n";

	foreach my $device ( sort keys %devicemclass ) {
		my $ip = gethostbyname($device);
		if ( !$ip ) {
			print STDERR
			  "gethostbyname of $device failed with: $?\n"
			  if $verbose;
			next;
		}
		$ip = inet_ntoa($ip);
		my $shortname = $device;
		$shortname = join( ".", ( split( /\./, $device ) )[ 0, 1 ] );
		printf RADCLIENT qq/
client %s {
	secret		= $radius_secret
	shortname	= %s
}

/, $ip, $shortname;
		print RADUSER
		  "###\n### Access controls for for $device ($ip)\n###\n";
		foreach my $user ( sort { $a->{username} cmp $b->{username} }
			@{ $mclassusers{ $devicemclass{$device} } } )
		{
			next if !defined( $user->{username} );
			printf RADUSER
qq {%s\tAuth-Type := Crypt-Local, Crypt-Password == "%s", NAS-IP-Address == %s\n},
			  $user->{username}, $user->{crypt} || "*", $ip;
			if ( $devicetype{$device} eq "rpc" ) {
				print RADUSER
				  "\tAPC-Service-Type = Administrator\n";
			}
			print RADUSER "\n";
		}
	}

	print RADUSER "\n\nDEFAULT\tAuth-Type := Reject\n\n";
	close RADUSER;
	close RADCLIENT;

	system("chown $radius_username $tmpraduserfile $tmpradclientsfile");

	#	system("diff $radius_userfile $tmpraduserfile >/dev/null 2>&1");
	if ( md5_diff( $radius_userfile, $tmpraduserfile ) ) {
		unlink $tmpraduserfile;
	} else {
		my ( $dirname, $basename );
		( $dirname, $basename ) = $radius_userfile =~ m%(.*/?)[^/]*$%;
		if ( !$basename ) {
			$basename = $dirname;
			$dirname  = "";
		}
		my $oldfile;
		my ( $sec, $min, $hour, $mday, $mon, $year ) =
		  ( localtime(time) )[ 0, 1, 2, 3, 4, 5 ];
		$oldfile = sprintf "%ssave/%s.%04d%02d%02d%02d%02d%02d",
		  $dirname, $basename, $year + 1900, $mon + 1, $mday, $hour,
		  $min, $sec;
		rename $radius_userfile, $oldfile;
		rename $tmpraduserfile,  $radius_userfile;
	}
	system("diff $radius_clientsfile $tmpradclientsfile >/dev/null 2>&1");
	if ( !$? ) {
		unlink $tmpradclientsfile;
	} else {
		my ( $dirname, $basename );
		( $dirname, $basename ) =
		  $radius_clientsfile =~ m%(.*/?)[^/]*$%;
		if ( !$basename ) {
			$basename = $dirname;
			$dirname  = "";
		}
		my $oldfile;
		my ( $sec, $min, $hour, $mday, $mon, $year ) =
		  ( localtime(time) )[ 0, 1, 2, 3, 4, 5 ];
		$oldfile = sprintf "%ssave/%s.%04d%02d%02d%02d%02d%02d",
		  $dirname, $basename, $year + 1900, $mon + 1, $mday, $hour,
		  $min, $sec;
		rename $radius_clientsfile, $oldfile;
		rename $tmpradclientsfile,  $radius_clientsfile;

	}
	if ($update) {
		system("pkill -HUP -u radius -P 1 radiusd");
	}
}

exit 0;

sub md5_diff {
	my $file1 = shift;
	my $file2 = shift;

	if ( !open( FIRST, $file1 ) ) {
		return undef;
	}
	if ( !open( SECOND, $file2 ) ) {
		close FIRST;
		return undef;
	}
	my $ctx1 = Digest::MD5->new;
	my $ctx2 = Digest::MD5->new;
	$ctx1->addfile(*FIRST);

	#	print "%s: %s\n", $file1, $ctx1->hexdigest;
	$ctx2->addfile(*SECOND);

	#	print "%s: %s\n", $file2, $ctx2->hexdigest;
	close FIRST;
	close SECOND;

	return ( $ctx1->hexdigest eq $ctx2->hexdigest );
}

