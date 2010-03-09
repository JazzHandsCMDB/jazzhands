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
use Getopt::Std;
use Pod::Usage;
use JazzHands::Management;
use JazzHands::ActiveDirectory;
use Net::LDAP::Control::Paged;
use Net::LDAP::Constant qw( LDAP_CONTROL_PAGED );
use Socket;

my $LOG = "/var/log/syncadaccts";

my $defaultou  = "OU=Unsorted Accounts,DC=example,DC=com";
my $inactiveou = "OU=Users,OU=Inactive,OU=Admin,DC=example,DC=com";
my $onleaveou  = "OU=UsersOnLeave,OU=Admin,DC=example,DC=com";
my $wrongdept  = "OU=Wrong Dept,DC=example,DC=com";

#
# Number of days to leave a terminated account before deleting it
#
my $DELETE_DAYS = 60;

my (%opt);
getopts( 'vndp', \%opt );

if ( $opt{d} || $opt{p} ) {
	if ( !open( LOG, ">&STDERR" ) ) {
		print STDERR "Unable to redirect errors.  Bailing.";
		exit 1;
	}
} else {
	if ( !open( LOG, ">>$LOG" ) ) {
		print STDERR "Unable to open log file $LOG.  Bailing.";
		exit 1;
	}
}
LOG->autoflush(1);

#my $jh = JazzHands::Management->new();
my $jh = OpenJHDBConnection();
if ( !$jh ) {
	write_log("Error opening JazzHands!");
	exit;
}
my $adh = JazzHands::ActiveDirectory->new();

if ( !ref($adh) ) {
	write_log($adh);
	exit 1;
}
my $addr = inet_ntoa( ( sockaddr_in( $adh->socket->connected ) )[1] );
my $hostname =
  ( gethostbyaddr( ( sockaddr_in( $adh->socket->connected ) )[1], AF_INET )
	  || $addr );

write_log( "Connected to %s (%s)", $hostname, $addr );

if ( $opt{n} ) {
	$adh->{letsjustpretend} = 1;
}
if ( $opt{v} ) {
	$adh->{verbose} = 1;
}
if ( $opt{p} ) {
	if ( !( open( TTY, "+</dev/tty" ) ) ) {
		print STDERR "No tty\n";
		exit 1;
	}
}

#
# Get list of account management users and stuff
#

$jh->{PrintError} = 0;

my ( $q, $sth );
$q = qq {
	SELECT
		S.System_User_ID,
		Login,
		Last_Name,
		First_Name,
		Middle_Name,
		Preferred_Last_Name,
		Preferred_First_Name,
		System_User_Status,
		System_User_Type,
		Manager_System_User_ID,
		HRIS_ID,
		Position_Title,
		Time_Util.Epoch(Termination_Date) AS Termination_Date,
		C.Company_Name Person_Company_Name,
		DMD.Name Dept_Name,
		Dept_ID
	FROM
		System_User S,
		Company C,
		System_User_Xref X,
		( SELECT
			D.Name,
			DM.System_User_ID,
			DM.Reporting_Type,
			DM.Dept_ID,
			D.Dept_Code
		FROM
			Dept_Member DM,
			Dept D
		WHERE
			DM.Dept_ID = D.Dept_ID AND
			DM.Reporting_Type='direct'
	   ) DMD
	WHERE
		S.System_User_ID = DMD.System_User_ID (+) AND
		S.System_User_ID = X.System_User_ID (+) AND
		S.Company_ID=C.Company_ID (+)
};

if ( !( $sth = $jh->prepare($q) ) ) {
	write_log( "Error executing database query:" . $q . $jh->errstr );
	exit;
}

if ( !$sth->execute ) {
	write_log( "Error executing database query:" . $q . $jh->errstr );
	exit;
}

my $userinfo = $sth->fetchall_hashref("SYSTEM_USER_ID");

$sth->finish;

$q = qq {
	SELECT
		Dept_ID,
		Dept_OU
	FROM
		Dept
	WHERE
		Dept_OU IS NOT NULL
};

$sth = $jh->prepare($q);
if ( !$sth->execute ) {
	write_log( "Error executing database query:" . $q . $jh->errstr );
	exit;
}

my $row;
my $dept_ou;

while ( $row = $sth->fetchrow_arrayref ) {
	$dept_ou->{ $row->[0] } = $row->[1];
}
$sth->finish;

$q = qq {
	SELECT
		System_User_ID,
		Phone_Number,
		Phone_Extension,
		Dial_Country_Code,
		Phone_Number_Type
	FROM
		(System_User_Phone A LEFT JOIN Val_Country_Code USING 
			(ISO_Country_Code))
	WHERE
		Phone_Type_Order = (
			SELECT
				MIN(Phone_Type_Order)
			FROM
				System_User_Phone B
			WHERE
				A.System_User_ID = B.System_User_ID AND
				A.Phone_Number_Type = B.Phone_Number_Type
		)
};

$sth = $jh->prepare($q);
if ( !$sth->execute ) {
	write_log( "Error executing database query:" . $q . $jh->errstr );
	exit;
}

while ( $row = $sth->fetchrow_hashref ) {
	my $entry;
	next if !( $entry = $userinfo->{ $row->{SYSTEM_USER_ID} } );
	my $phone =
	  normalizephone( $row->{PHONE_NUMBER}, $row->{DIAL_COUNTRY_CODE} );
	if ( $row->{PHONE_NUMBER_TYPE} eq 'office' ) {
		$userinfo->{ $row->{SYSTEM_USER_ID} }->{OFFICE_PHONE} = $phone;
	}
	if ( $row->{PHONE_NUMBER_TYPE} eq 'mobile' ) {
		$userinfo->{ $row->{SYSTEM_USER_ID} }->{MOBILE_PHONE} = $phone;
	}
	if ( $row->{PHONE_NUMBER_TYPE} eq 'fax' ) {
		$userinfo->{ $row->{SYSTEM_USER_ID} }->{FAX_PHONE} = $phone;
	}
}
$sth->finish;

$q = qq {
	SELECT
		System_User_ID,
		Office_Site,
		Address_1,
		Address_2,
		City,
		State,
		Postal_Code,
		Country,
		Building,
		Floor,
		Section,
		Seat_Number
	FROM
		System_User_Location 
	WHERE
		System_User_Location_Type = 'office'
};

$sth = $jh->prepare($q);
if ( !$sth->execute ) {
	write_log( "Error executing database query:" . $q . $jh->errstr );
	exit;
}

while ( $row = $sth->fetchrow_hashref ) {
	my $entry;
	next if !( $entry = $userinfo->{ $row->{SYSTEM_USER_ID} } );
	$entry->{ADDRESS} = $row->{ADDRESS_1} || '';
	if ( $row->{ADDRESS_2} ) {
		$entry->{ADDRESS} .= ', ' . $row->{ADDRESS_2};
	}
	$entry->{CITY}        = $row->{CITY}        || '';
	$entry->{STATE}       = $row->{STATE}       || '';
	$entry->{POSTAL_CODE} = $row->{POSTAL_CODE} || '';
	$entry->{COUNTRY}     = $row->{COUNTRY}     || '';
	$entry->{LOCATION}    = $row->{OFFICE_SITE} || '';

	if ( $row->{BUILDING} ) {
		$entry->{LOCATION} .= ' ' . $row->{BUILDING};
	}
	if ( $row->{FLOOR} ) {
		$entry->{LOCATION} .= $row->{FLOOR};
	}
	if ( $row->{SECTION} ) {
		$entry->{LOCATION} .= '-' . $row->{SECTION};
	}
	if ( $row->{SEAT_NUMBER} ) {
		$entry->{LOCATION} .= $row->{SEAT_NUMBER};
	}
}
$sth->finish;

#
# Get the default AD OU out of the database.  If we can't get this
# parameter, things will still work, but any user not assigned to a
# department will either a) not have an AD account created, or b)
# will not have their OU moved from wherever it is now.
#

#
# Now get all of the account information from ActiveDirectory
#
my $mesg;
my $page = Net::LDAP::Control::Paged->new( size => 1000 );
my $adusersbyuid = {};

while (1) {
	$mesg = $adh->search(
		base    => "dc=example,dc=com",
		filter  => "(jazzHandsSystemUserID=*)",
		control => [$page]
	);

	if ( $mesg->is_error ) {
		write_log( $mesg->error_text );
		exit 1;
	}

	#
	# Now, rearrange the LDAP search to arrange keys based on
	# jazzHandsSystemUserID
	#
	my $adusers = $mesg->as_struct();
	foreach my $dn ( keys %$adusers ) {

		# This should never be false, but stranger things have happened
		if ( my $tmpuid =
			${ $adusers->{$dn}->{jazzhandssystemuserid} }[0] )
		{
			$adusersbyuid->{$tmpuid} = $adusers->{$dn};
			$adusersbyuid->{$tmpuid}->{dn} = $dn;
		}
	}
	my ($resp) = $mesg->control(LDAP_CONTROL_PAGED) or last;
	my $cookie = $resp->cookie || last;

	$page->cookie($cookie);
}

#
# First pass through all the users is to normalize some things and figure out
# display names
#

my %displayname;

foreach my $uid ( keys %$userinfo ) {
	my $entry = $userinfo->{$uid};

	my $displayName =
	    ( $entry->{PREFERRED_FIRST_NAME} || $entry->{FIRST_NAME} ) . ' '
	  . ( $entry->{PREFERRED_LAST_NAME}  || $entry->{LAST_NAME} );

	my $displayMiddleName =
	    ( $entry->{PREFERRED_FIRST_NAME} || $entry->{FIRST_NAME} ) . ' '
	  . ( $entry->{MIDDLE_NAME} ? $entry->{MIDDLE_NAME} . ' ' : '' )
	  . ( $entry->{PREFERRED_LAST_NAME} || $entry->{LAST_NAME} );

	$entry->{DISPLAY_NAME}        = $displayName;
	$entry->{DISPLAY_MIDDLE_NAME} = $displayMiddleName;

	if ( !defined( $displayname{$displayName} ) ) {
		$displayname{$displayName} = 0;
	}
	if (
		$adusersbyuid->{$uid}
		|| (
			IsUserEnabled( $entry->{SYSTEM_USER_STATUS} )
			&& (       $entry->{SYSTEM_USER_TYPE} eq "employee"
				|| $entry->{SYSTEM_USER_TYPE} eq "contractor" )
		)
	  )
	{
		$displayname{$displayName}++;
	}

	#
	# Set the manager_system_user_id for the user to be the DN
	#
	if (       $entry->{MANAGER_SYSTEM_USER_ID}
		&& $adusersbyuid->{ $entry->{MANAGER_SYSTEM_USER_ID} } )
	{
		$entry->{MANAGER_SYSTEM_USER_ID} =
		  $adusersbyuid->{ $entry->{MANAGER_SYSTEM_USER_ID} }->{dn};
	} else {
		undef $entry->{MANAGER_SYSTEM_USER_ID};
	}

}

#
# The second pass is to go through the account management tables and create
# accounts for anyone who doesn't exist.
#
foreach my $uid ( keys %$userinfo ) {
	my $entry = $userinfo->{$uid};

	#
	# If there is more than one user with this display name (e.g. two
	# "John Smith"s), use the middle name/initial as well.  If those also
	# collide, they just do, and it isn't too tragic.
	#
	if ( ( $displayname{ $entry->{DISPLAY_NAME} } ) > 1 ) {
		$entry->{DISPLAY_NAME} = $entry->{DISPLAY_MIDDLE_NAME};
	}

       #
       # Create accounts for only 'enabled employees'.  This eventually needs to
       # handle contractors.
       #
	if (
		   !$adusersbyuid->{$uid}
		&& IsUserEnabled( $entry->{SYSTEM_USER_STATUS} )
		&& (       $entry->{SYSTEM_USER_TYPE} eq "employee"
			|| $entry->{SYSTEM_USER_TYPE} eq "contractor" )
	  )
	{

		write_log( "%s: creating account", $entry->{LOGIN} );

	  #
	  # Figure out OU in which to place the user by the department assigned.
	  # If no department, fall back to a default.  If no default, punt.
	  #
		my $ou =
		  ( $entry->{DEPT_ID} && $dept_ou->{ $entry->{DEPT_ID} } )
		  ? $dept_ou->{ $entry->{DEPT_ID} }
		  : $defaultou;
		if ( !$ou ) {
			write_log(
"Skipping account creation.  No department or default OU information found"
			);
			next;
		}

		#
		# Figure out all of the parameters we need to set.
		#

		my $login = $entry->{LOGIN};

		#		my $password = makeuprandompasswd();
		my $password = '!Voice9';

		my @args = (
			login     => $entry->{LOGIN},
			ou        => $ou,
			givenname => $entry->{PREFERRED_FIRST_NAME}
			  || $entry->{FIRST_NAME},
			sn => $entry->{PREFERRED_LAST_NAME}
			  || $entry->{LAST_NAME},
			uid         => $entry->{SYSTEM_USER_ID},
			password    => $password,
			cn          => $entry->{DISPLAY_NAME},
			displayname => $entry->{DISPLAY_NAME}
		);

		if ( $entry->{ADDRESS} ) {
			push @args, address => $entry->{ADDRESS};
		}
		if ( $entry->{CITY} ) {
			push @args, city => $entry->{CITY};
		}
		if ( $entry->{STATE} ) {
			push @args, state => $entry->{STATE};
		}
		if ( $entry->{POSTAL_CODE} ) {
			push @args, postal_code => $entry->{POSTAL_CODE};
		}
		if ( $entry->{COUNTRY} ) {
			push @args, country => $entry->{COUNTRY};
		}
		if ( $entry->{LOCATION} ) {
			push @args, location => $entry->{LOCATION};
		}
		if ( $entry->{OFFICE_PHONE} ) {
			push @args, phone => $entry->{OFFICE_PHONE};
		}
		if ( $entry->{MOBILE_PHONE} ) {
			push @args, mobile => $entry->{MOBILE_PHONE};
		}
		if ( $entry->{FAX_PHONE} ) {
			push @args, fax => $entry->{FAX_PHONE};
		}
		if ( $entry->{POSITION_TITLE} ) {
			push @args, title       => $entry->{POSITION_TITLE};
			push @args, description => $entry->{POSITION_TITLE};
		}
		if ( $entry->{DEPT_NAME} ) {
			push @args, department => $entry->{DEPT_NAME};
		}
		if ( $entry->{PERSON_COMPANY_NAME} ) {
			push @args, company => $entry->{PERSON_COMPANY_NAME};
		}

		if ( $opt{p} ) {
			print TTY "Perform modification? ";
			my $ans = <TTY>;
			exit if $ans =~ /^[xX]/;
			next if $ans !~ /^[yY]/;
		}

		if ( my $error = $adh->CreateUser(@args) ) {
			write_log($error);
		}
		next;
	}
}

#
# logonhours is a bitfield of 7 sets of 24 bits specifying which hours of
# which day of the week a user is allowed to log in.
#
my $deactivated_times =
  pack( "C21", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 );

my $activated_times = pack( "C21",
	255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
	255, 255, 255, 255, 255, 255, 255, 255, 255, 255 );

#
# Ok, now we need to go through the AD accounts and see what needs to be
# done to the account
#
my $curtime = time();
foreach my $uid ( keys %$adusersbyuid ) {

	my $entry   = $userinfo->{$uid} if $userinfo->{$uid};
	my $adentry = $adusersbyuid->{$uid};
	my $acctval = $adentry->{useraccountcontrol}->[0];

      #
      # If the entry points to a JazzHands record and that record does not exist
      # or if the person was terminated more than DELETE_DAYS days ago, blow
      # away the account.
      #
	if (
		!$entry
		|| (       $entry->{TERMINATION_DATE}
			&& !IsUserEnabled( $entry->{SYSTEM_USER_STATUS} )
			&& $entry->{SYSTEM_USER_STATUS} ne "onleave"
			&& int( $curtime - $entry->{TERMINATION_DATE} ) /
			86400 > $DELETE_DAYS )
	  )
	{

		my $logstr;
		if ($entry) {
			my ( $sec, $min, $hour, $mday, $month, $year ) =
			  localtime( $entry->{TERMINATION_DATE} );
			$logstr = sprintf(
"%s: deleting OU %s, termination date %04d-%02d-%02d",
				$entry->{LOGIN}, $adentry->{dn}, $year + 1900,
				$month + 1, $mday
			);
		} else {
			$logstr = sprintf(
"%s: deleting OU %s, corresponding JazzHands account (%d) deleted",
				$adentry->{samaccountname}->[0],
				$adentry->{dn}, $uid
			);
		}
		write_log($logstr);

		next if $opt{n};

		if ( $opt{p} ) {
			print TTY "Perform modification? ";
			my $ans = <TTY>;
			exit if $ans =~ /^[xX]/;
			next if $ans !~ /^[yY]/;
		}

		$mesg = $adh->delete( $adentry->{dn} );
		if ( $mesg->is_error ) {
			write_log(
				"%s: unable to delete entry %s: %s",
				$entry
				? $entry->{LOGIN}
				: $adentry->{samaccountname}->[0],
				$adentry->{dn},
				$mesg->error_text
			);
		}
		next;
	}

	# Account doesn't exist in user management or is deactivated in
	# JazzHands, but is still active in AD, so deactivate it

	if ( !IsUserEnabled( $entry->{SYSTEM_USER_STATUS} ) ) {

		if ( !defined( $adentry->{logonhours} )
			|| ( $adentry->{logonhours}->[0] ne $deactivated_times )
		  )
		{
			write_log(
				"%s:disabling (%s) %s",       $entry->{LOGIN},
				$entry->{SYSTEM_USER_STATUS}, $adentry->{dn}
			);

			# Okay, start building our Array of Awesomeness (+3)

			my @changes;
			if ( $adentry->{logonhours} ) {
				push @changes, replace =>
				  [ logonhours => $deactivated_times ];
			} else {
				push @changes,
				  add => [ logonhours => $deactivated_times ];
			}
			push @changes,
			  replace => [ userAccountControl => $acctval & ~2 ];

			next if $opt{n};

			if ( $opt{p} ) {
				print TTY "Perform modification? ";
				my $ans = <TTY>;
				exit if $ans =~ /^[xX]/;
				next if $ans !~ /^[yY]/;
			}

			$mesg =
			  $adh->modify( $adentry->{dn}, changes => \@changes );

			if ( $mesg->is_error ) {
				write_log(
"Unable to deactivate account for %s, DN %s: %s",
					$entry->{LOGIN}, $adentry->{dn},
					$mesg->error_text );
			}

	      #
	      # Randomize the password for people who are being disabled who are
	      # not going on leave, just in case someone does something stupid.
	      #
			if (       $entry
				&& $entry->{SYSTEM_USER_STATUS} eq 'onleave' )
			{
				my $password = makeuprandompasswd();
				if (
					!$adh->setpassword(
						$userinfo->{$uid}->{LOGIN},
						$password
					)
				  )
				{
					write_log(
"%s: unable to randomize password",
						$userinfo->{$uid}->{LOGIN}
					);
				}
			}
		}

		# Don't do the rest of this if people are just on leave

		next if ( $entry && $entry->{SYSTEM_USER_STATUS} eq 'onleave' );

	      #
	      # Because AD is so completely awesome, you get an error if you
	      # try to delete an attribute that is not present, so we have to
	      # check to see which of the Exchange parameters are set and delete
	      # only the ones that are present.  It's possible that this is
	      # an LDAP issue and not just limited to AD.  Turns out it doesn't
	      # matter.
	      #
	      # Parameters from http://support.microsoft.com/?kbid=307350
	      #

		# This is dumb

		if ( !$adentry->{msexchhidefromaddresslists} ) {
			write_log(
"Adding msexchhidefromaddresslist parameter for %s",
				$adentry->{dn}
			);
			$mesg = $adh->modify( $adentry->{dn},
				add => { msexchhidefromaddresslists => 'TRUE' }
			);

			if ( $mesg->is_error ) {
				write_log(
"Unable to add msexchhidefromaddresslist parameter for %s: %s",
					$adentry->{dn}, $mesg->error_text
				);
			}
		} elsif (
			$adentry->{msexchhidefromaddresslists}->[0] ne 'TRUE' )
		{
			write_log(
"Replacing msexchhidefromaddresslist parameter for %s",
				$adentry->{dn}
			);
			$mesg = $adh->modify( $adentry->{dn},
				replace =>
				  { msexchhidefromaddresslists => 'TRUE' } );

			if ( $mesg->is_error ) {
				write_log(
"Unable to add msexchhidefromaddresslist parameter for %s: %s",
					$adentry->{dn}, $mesg->error_text
				);
			}
		}

		foreach my $attr ( "manager", "telephonenumber", "mobile" ) {
			if ( $adentry->{$attr} ) {
				write_log( "Deleting %s attribute from %s",
					$attr, $adentry->{dn} );

				$mesg = $adh->modify( $adentry->{dn},
					delete => { $attr => $adentry->{$attr} }
				);

				if ( $mesg->is_error ) {
					write_log(
"Unable to delete attributes for %s, DN %s: %s",
						$entry->{LOGIN},
						$adentry->{dn},
						$mesg->error_text
					);
				}
			}
		}
		next;
	}

	# Account exists in user management and is activated in
	# user management, but is deactivated in AD

	if (       $entry
		&& ( IsUserEnabled( $entry->{SYSTEM_USER_STATUS} ) )
		&& defined( $adentry->{logonhours}->[0] )
		&& ( $adentry->{logonhours}->[0] ne $activated_times ) )
	{

		write_log(
			"%s: reactivating %s - %s",
			$entry->{LOGIN},
			$adusersbyuid->{$uid}->{dn},
			$entry->{SYSTEM_USER_STATUS}
		);

		my @changes;

	      #
	      # If an address book entry exists, assume that the user is already
	      # added to them.
	      #
		if ( !( $adentry->{showinaddressbook} ) ) {
			push @changes, add => [
				showInAddressBook => [
"CN=Default Global Address List,CN=All Global Address Lists,CN=Address Lists Container,CN=My Company,CN=Microsoft Exchange,CN=Services,CN=Configuration,DC=example,DC=com",
"CN=All Users,CN=All Address Lists,CN=Address Lists Container,CN=My Company,CN=Microsoft Exchange,CN=Services,CN=Configuration,DC=example,DC=com"
				]
			];
		}

		if (       $adentry->{msexchhidefromaddresslists}
			&& $adentry->{msexchhidefromaddresslists}->[0] ne
			'FALSE' )
		{
			$mesg = $adh->modify( $adentry->{dn},
				replace =>
				  { msexchhidefromaddresslists => 'FALSE' } );

			if ( $mesg->is_error ) {
				write_log(
"Unable to add msexchhidefromaddresslist parameter for %s: %s",
					$adentry->{dn}, $mesg->error_text
				);
			}
		}

		#
		# Reactivate the user
		#
		if ( $adentry->{logonhours} ) {
			push @changes,
			  replace => [ logonhours => $activated_times ];
		} else {
			push @changes,
			  add => [ logonhours => $activated_times ];
		}
		push @changes,
		  replace => [ userAccountControl => $acctval & ~2 ];

		next if $opt{n};

		if ( $opt{p} ) {
			print TTY "Perform modification? ";
			my $ans = <TTY>;
			exit if $ans =~ /^[xX]/;
			next if $ans !~ /^[yY]/;
		}

		$mesg = $adh->modify( $adusersbyuid->{$uid}->{dn},
			changes => \@changes );

		if ( $mesg->is_error ) {
			write_log(
				"%s: failed to reactivate %s: %s",
				$entry->{LOGIN},
				$adusersbyuid->{$uid}->{dn},
				$mesg->error_text
			);
			next;
		}
		next;
	}
}

#
# Loop through all the enabled accounts and set AD attributes for which
# we are authoritative.
#
# We could have done this above, but we're keeping it here for clarity.
#
foreach my $uid ( keys %$adusersbyuid ) {
	my $entry = $userinfo->{$uid} if $userinfo->{$uid};
	my $adentry = $adusersbyuid->{$uid};

	next if !$entry;

	if ( !( IsUserEnabled( $entry->{SYSTEM_USER_STATUS} ) )
		&& $entry->{SYSTEM_USER_STATUS} ne "onleave" )
	{
		next;
	}

	my @changes;

	my %sync = (
		displayname                => "DISPLAY_NAME",
		mobile                     => "MOBILE_PHONE",
		title                      => "POSITION_TITLE",
		description                => "POSITION_TITLE",
		department                 => "DEPT_NAME",
		manager                    => "MANAGER_SYSTEM_USER_ID",
		telephonenumber            => "OFFICE_PHONE",
		roomnumber                 => "LOCATION",
		physicaldeliveryofficename => "LOCATION",
		company                    => "PERSON_COMPANY_NAME"
	);

	foreach my $key ( keys %sync ) {

		#
		# Sync the AD value to the jazzhands value
		#
		if (
			$entry->{ $sync{$key} }
			&& (
				!$adentry->{$key}
				|| ( $adentry->{$key}->[0] ne
					$entry->{ $sync{$key} } )
			)
		  )
		{
			if ( defined( $adentry->{$key} ) ) {
				write_log(
					"%s: changing %s from '%s' to '%s'",
					$entry->{LOGIN},
					$key,
					$adentry->{$key}->[0],
					$entry->{ $sync{$key} }
				);
			} else {
				write_log( "%s: adding %s as '%s'",
					$entry->{LOGIN}, $key,
					$entry->{ $sync{$key} } );
			}
			push @changes,
			  ( defined( $adentry->{$key} ) ? 'replace' : 'add' ) =>
			  [ $key => $entry->{ $sync{$key} } ];
		}

		#
		# Delete the AD value if it does not occur in jazzhands
		#
		if ( $adentry->{$key} && !( $entry->{ $sync{$key} } ) ) {
			write_log( "%s: removing attribute %s (was '%s')",
				$entry->{LOGIN}, $key, $adentry->{$key}->[0] );
			push @changes, delete => [ $key => [] ];
		}
	}

	if (@changes) {
		my $modify = 1;
		$modify = 0 if $opt{n};
		if ( $opt{p} && !$opt{n} ) {
			print TTY "Perform modification? ";
			my $ans = <TTY>;
			exit if $ans =~ /^[xX]/;
			$modify = 0 if $ans !~ /^[yY]/;
		}

		if ($modify) {
			$mesg = $adh->modify( $adusersbyuid->{$uid}->{dn},
				changes => \@changes );

			if ( $mesg->is_error ) {
				write_log(
"%s: error modifying attributes for DN %s: %s",
					$userinfo->{$uid}->{LOGIN},
					$adusersbyuid->{$uid}->{dn},
					$mesg->error_text
				);
			}
		}
	}

	#
	# Check to see if the CN needs to be changed
	#
	if ( $adentry->{cn}->[0] ne $entry->{DISPLAY_NAME} ) {
		write_log(
			"%s: changing CN from '%s' to '%s'",
			$entry->{LOGIN},
			$adentry->{cn}->[0],
			$entry->{DISPLAY_NAME}
		);
		my $modify = 1;
		$modify = 0 if $opt{n};
		if ( $opt{p} && !$opt{n} ) {
			print TTY "Perform modification? ";
			my $ans = <TTY>;
			exit if $ans =~ /^[xX]/;
			$modify = 0 if $ans !~ /^[yY]/;
		}

		if ($modify) {
			$mesg = $adh->moddn(
				$adusersbyuid->{$uid}->{dn},
				newrdn       => "CN=" . $entry->{DISPLAY_NAME},
				deleteoldrdn => 1,
			);

			if ( $mesg->is_error ) {
				write_log(
"%s: error modifying attributes for DN %s: %s",
					$userinfo->{$uid}->{LOGIN},
					$adusersbyuid->{$uid}->{dn},
					$mesg->error_text
				);
			}
		}
	}
}

#
# Now for the most fun part.  Find any user accounts which need to move
# OUs and do that.  We do this at the end, so we don't have to worry about
# having information out of sync above.
#

foreach my $uid ( keys %$userinfo ) {
	my ($dept_id);
	next if ( !$adusersbyuid->{$uid} );
	my $entry = $userinfo->{$uid};
	my ( $adcn, $adou ) = $adusersbyuid->{$uid}->{dn} =~ /(CN=[^,]+),(.*)/;

	my $amou;
	if ( IsUserEnabled( $entry->{SYSTEM_USER_STATUS} ) ) {
		if ( $entry->{DEPT_ID} ) {
			$dept_id = $entry->{DEPT_ID};
		} else {
			write_log( "%s: user does not have a department",
				$entry->{LOGIN} )
			  if $opt{v};
			$dept_id = 0;
		}
		$amou =
		  ( $dept_id && $dept_ou->{$dept_id} )
		  ? $dept_ou->{$dept_id}
		  : $defaultou;

	} elsif ( $entry->{SYSTEM_USER_STATUS} eq "onleave" ) {
		$amou = $onleaveou;
	} else {

	   # If they aren't enabled or on leave, they get tossed in the inactive
	   # bucket
		$amou = $inactiveou;
	}

	next if !$amou;

	if ( lc($adou) ne lc($amou) ) {

		if ( ( lc($adou) eq lc($wrongdept) ) ) {
			write_log(
"%s: not moving OU from %s to %s.  User is in locked OU.",
				$entry->{LOGIN}, $adou, $amou )
			  if $opt{v};
			next;
		}

		write_log( "%s: moving OU from %s to %s",
			$entry->{LOGIN}, $adou, $amou );

		next if $opt{n};

		if ( $opt{p} ) {
			print TTY "Perform modification? ";
			my $ans = <TTY>;
			exit if $ans =~ /^[xX]/;
			next if $ans !~ /^[yY]/;
		}

		$mesg = $adh->moddn(
			$adusersbyuid->{$uid}->{dn},
			newrdn       => $adcn,
			deleteoldrdn => 1,
			newsuperior  => $amou
		);

		if ( $mesg->is_error ) {
			write_log( "%s: error moving user: %s",
				$mesg->error_text );
		}
	}
}

sub makeuprandompasswd {
	my $p = "";
	for ( my $i = 0 ; $i < 7 ; $i++ ) {
		$p .=
		  ( 'A' .. 'Z', '%', '$', '.', '!', '-', 0 .. 9, 'a' .. 'z' )
		  [ rand 64 ];
	}
	$p;
}

sub normalizephone {
	my $phone        = shift;
	my $country_code = shift;

	# There should be no spaces, but whatever.

	return '' if ( !$phone );
	$phone =~ s/[^0-9]//g;
	if ( $phone && !$country_code ) {
		write_log( "Error with phone %s - country code does not exist",
			$phone );
		return "";
	}
	if ( $country_code eq '1' ) {
		$phone =~ s/^1//;
		$phone = join( " ", $phone =~ /(\d\d\d)(\d\d\d)(\d\d\d\d)/ );
		$phone = "+1 " . $phone;
	} elsif ( $country_code eq '44' ) {
		if ( $phone =~ /^2/ ) {
			$phone = join( " ", $phone =~ /(\d\d)(\d\d\d\d)(\d+)/ );
		} elsif (  $phone =~ /^[8]/
			|| $phone =~ /^1\d1/
			|| $phone =~ /^11/ )
		{
			$phone = join( " ", $phone =~ /(\d\d\d)(\d+)/ );
		} else {
			$phone = join( " ", $phone =~ /(\d\d\d\d)(\d+)/ );
		}
		$phone = "+44 (0)" . $phone;
	} else {
		$phone = "+" . $country_code . " " . $phone;
	}

	return $phone;
}

sub write_log {
	my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime( time() );
	printf LOG "%04d-%02d-%02d %02d:%02d:%02d ", $year + 1900, $mon + 1,
	  $mday, $hour, $min, $sec;
	if (@_) {
		printf LOG @_;
	}
	printf LOG "\n";
}
