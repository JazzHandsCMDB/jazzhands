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

my $defaultou  = "OU=Unsorted Accounts,DC=example,DC=com";
my $inactiveou = "OU=Users,OU=Inactive,OU=Admin,DC=example,DC=com";

#
# Come up with common mail attributes
my $dept_ou = {};

my (%opt);
getopts( 'vn', \%opt );

if ( !@ARGV ) {
	print "Usage: $0 <login>...\n";
	exit 1;
}

#my $jh = JazzHands::Management->new();
my $jh = OpenJHDBConnection();
if ( !$jh ) {
	print "Error opening JazzHands!\n";
	exit;
}
$jh->{PrintError} = 0;
my $adh = JazzHands::ActiveDirectory->new();

if ( !ref($adh) ) {
	print STDERR $adh . "\n";
	exit 1;
}

if ( $opt{n} ) {
	$adh->{letsjustpretend} = 1;
}
if ( $opt{v} ) {
	$adh->{verbose} = 1;
}

my @systemuserids;
while (@ARGV) {
	my $user = shift;
	my $userid;
	if ( defined( $userid = findUserIdFromlogin( $jh, $user ) ) ) {
		push @systemuserids, $userid;
	} else {
		printf STDERR
		  "No information found in JazzHands for user '%s'\n", $user;
	}
}

if ( !@systemuserids ) {
	print STDERR "Nothing to do.\n";
	exit;
}

#
# Get list of account management users and stuff
#

my ( $q, $sth );
$q = qq {
	SELECT 
		System_User_ID,
		Login,
		Last_Name,
		First_Name,
		Middle_Name,
		System_User_Status,
		System_User_Type,
		Dept_ID,
		Dept_Name,
		Person_Company_Name
	FROM
		V_System_User
};

if ( !( $sth = $jh->prepare($q) ) ) {
	print STDERR "Error preparing database query:" 
	  . $q
	  . $jh->errstr . "\n";
	exit;
}

if ( !$sth->execute ) {
	print STDERR "Error executing database query:" 
	  . $q
	  . $jh->errstr . "\n";
	exit;
}

my $userinfo = $sth->fetchall_hashref("SYSTEM_USER_ID");

$sth->finish;

$q = qq {
	SELECT
		System_User_ID,
		Phone_Number,
		Phone_Extension,
		Dial_Country_Code,
		Phone_Number_Type
	FROM
		System_User_Phone LEFT JOIN Val_Country_Code USING (ISO_Country_Code)
};

$sth = $jh->prepare($q);
if ( !$sth->execute ) {
	print STDERR "Error executing database query:" 
	  . $q
	  . $jh->errstr . "\n";
	exit;
}

my $row;
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
	print STDERR "Error executing database query:" 
	  . $q
	  . $jh->errstr . "\n";
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
		print STDERR $mesg->error_text . "\n";
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
# Our first pass is to go through the account management tables and create
# accounts for anyone who doesn't exist.
#
foreach my $uid (@systemuserids) {
	my $entry = $userinfo->{$uid};

	#
	# Since we're forcing it, assume that we want to handle any type
	# of user accounts
	#
	if ( $adusersbyuid->{$uid} ) {
		printf STDERR
		  "Account '%s' already exists in Active Directory\n",
		  $entry->{LOGIN};
		next;
	}
	if ( $entry->{SYSTEM_USER_STATUS} eq "enabled" ) {

		printf "Creating account for '%s'\n", $entry->{LOGIN};

	  #
	  # Figure out OU in which to place the user by the department assigned.
	  # If no department, fall back to a default.  If no default, punt.
	  #
		my $ou =
		  ( $entry->{DEPT_ID} && $dept_ou->{ $entry->{DEPT_ID} } )
		  ? $dept_ou->{ $entry->{DEPT_ID} }
		  : $defaultou;
		if ( !$ou ) {
			print STDERR
"Skipping account creation.  No department or default OU information found\n";
			next;
		}

		#
		# Figure out all of the parameters we need to set.
		#
		my $cn = $entry->{FIRST_NAME};
		if ( $entry->{MIDDLE_NAME} ) {
			$cn .= " " . $entry->{MIDDLE_NAME};
		}
		$cn .= " " . $entry->{LAST_NAME};

		my $displayName =
		    ( $entry->{PREFERRED_FIRST_NAME} || $entry->{FIRST_NAME} )
		  . ' '
		  . ( $entry->{PREFERRED_LAST_NAME} || $entry->{LAST_NAME} );

		my $login = $entry->{LOGIN};

		#		my $password = makeuprandompasswd();
		my $password = '!Voice';

		my @args = (
			login     => $entry->{LOGIN},
			ou        => $ou,
			givenname => $entry->{PREFERRED_FIRST_NAME}
			  || $entry->{FIRST_NAME},
			sn => $entry->{PREFERRED_LAST_NAME}
			  || $entry->{LAST_NAME},
			uid         => $entry->{SYSTEM_USER_ID},
			password    => $password,
			cn          => $cn,
			displayname => $displayName
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

		if ( my $error = $adh->CreateUser(@args) ) {
			printf STDERR $error if $opt{v};
		}
		next;
	} else {
		printf STDERR
		  "Account '%s' is does not have enabled status.  Skipping.\n",
		  $entry->{LOGIN};
	}
}

#
# Deletes are handled correctly by syncadaccts.pl
#

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
		print "Error with phone $phone - cc does not exist!\n";
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
