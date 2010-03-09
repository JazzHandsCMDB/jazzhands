#
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

# $Id$
#

package JazzHands::Management::User;

use DBI;
use JazzHands::Management::Dept;
use JazzHands::Management::Uclass;

use strict;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Digest::SHA qw(sha1_base64);
use Crypt::Eksblowfish::Bcrypt qw(bcrypt en_base64);

use vars qw($VERSION @EXPORT @ISA);

$VERSION = '1.0.1';    # $Date$

require Exporter;
our @ISA = ( "Exporter", "JazzHands::Management" );
@EXPORT = qw(
  CreateNewUser
  GetUserDataBySystemUserID
  IsValidUserType
  GetUser
  GetUsers
);

sub import {
	JazzHands::Management::User->export_to_level( 1, @_ );
}

sub _options {
	my %ret = @_;
	for my $v ( grep { /^-/ } keys %ret ) {
		$ret{ substr( $v, 1 ) } = $ret{$v};
	}
	\%ret;
}

sub GetUser {
	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error("Invalid class reference passed");
		return undef;
	}

	my $opt = &_options(@_);

	my $where;
	if ( $opt->{login} ) {
		$where = "Login = ?";
	} elsif ( $opt->{id} ) {
		$where = "System_User_ID = ?";
	} else {
		$self->Error("Neither User login nor id were passed");
		return undef;
	}

	my $q = qq {
		SELECT
			System_User_ID,
			Login,
			First_Name,
			Middle_Name,
			Last_Name,
			Name_Suffix,
			System_User_Status,
			System_User_Type,
			Employee_Id,
			Position_Title,
			Badge_Id,
			Gender,
			Preferred_First_Name,
			Preferred_Last_Name,
			Time_Util.Epoch(Hire_Date),
			Time_Util.Epoch(Termination_Date)
		FROM
			System_User
		WHERE
			$where
	};
	my $sth = $dbh->prepare_cached($q);
	if ( !$sth ) {
		my $errstr = "Error preparing database query";
		if ( $self->DBErrors ) {
			$errstr .= ": " . DBI::errstr;
		}
		$self->Error($errstr);
		return undef;
	}

	if ( !( $sth->execute( $opt->{login} ? $opt->{login} : $opt->{id} ) ) )
	{
		my $errstr = "Error executing database query";
		if ( $self->IncludeDBError ) {
			$errstr .= ": " . DBI::errstr;
		}
		$self->Error($errstr);
		return undef;
	}

	my (
		$id,         $login,     $first,     $middle,
		$last,       $suffix,    $status,    $type,
		$empid,      $title,     $badge,     $gender,
		$pref_first, $pref_last, $hire_date, $term_date
	) = $sth->fetchrow_array;

	$sth->finish;
	if ( !$id ) {
		my $errstr = "User does not exist";
		if ( $self->IncludeDBError ) {
			$errstr .= ": " . DBI::errstr;
		}
		$self->Error($errstr);
		return undef;
	}

	$self->Error(undef);
	my $user = $self->copy;
	$user->{Id}                 = $id;
	$user->{Login}              = $login;
	$user->{FirstName}          = $first;
	$user->{MiddleName}         = $middle;
	$user->{LastName}           = $last;
	$user->{NameSuffix}         = $suffix;
	$user->{Status}             = $status;
	$user->{Type}               = $type;
	$user->{EmployeeId}         = $empid;
	$user->{Title}              = $title;
	$user->{BadgeId}            = $badge;
	$user->{Gender}             = $gender;
	$user->{PreferredFirstName} = $pref_first;
	$user->{PreferredLastName}  = $pref_last;
	$user->{HireDate}           = $hire_date;
	$user->{TerminationDate}    = $term_date;
	bless $user;
}

sub GetUsers {
	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error("Invalid class reference passed");
		return undef;
	}

	my $opt = &_options(@_);

	my @ors;
	my @ands;

	if ( $opt->{fuzzy} ) {
		if ( $opt->{login} ) {
			push @ors, "Login LIKE :login";
		}
		if ( $opt->{first} ) {
			push @ors,
"(LOWER(First_Name) LIKE LOWER(:first) OR LOWER(Preferred_First_Name) LIKE LOWER(:first))";
		}
		if ( $opt->{last} ) {
			push @ors,
"(LOWER(Last_Name) LIKE LOWER(:last) OR LOWER(Preferred_Last_Name) LIKE LOWER(:last))";
		}
	} else {
		if ( $opt->{login} ) {
			push @ands, "Login = :login";
		}
		if ( $opt->{first} ) {
			push @ands,
"(First_Name = :first OR Preferred_First_Name = :first)";
		}
		if ( $opt->{last} ) {
			push @ands,
			  "(Last_Name = :last OR Preferred_Last_Name = :last)";
		}
	}
	if ( $opt->{type} ) {
		push @ands, "System_User_Type = :type";
	}
	if ( $opt->{enabled_only} ) {
		push @ands,
		  "System_User_Status IN ('enabled', 'onleave-enabled')";
	}
	if ( $opt->{disabled_only} ) {
		push @ands,
		  "System_User_Status NOT IN ('enabled', 'onleave-enabled')";
	}
	if ( $opt->{status} ) {
		push @ands, "System_User_Status = :status";
	}
	my $q = qq {
		SELECT
			System_User_ID,
			Login,
			First_Name,
			Middle_Name,
			Last_Name,
			Name_Suffix,
			System_User_Status,
			System_User_Type,
			Employee_Id,
			Position_Title,
			Badge_Id,
			Gender,
			Preferred_First_Name,
			Preferred_Last_Name,
			Time_Util.Epoch(Hire_Date),
			Time_Util.Epoch(Termination_Date)
		FROM
			System_User
	};
	if ( @ands || @ors ) {
		if ( $opt->{fuzzy} ) {
			if (@ors) {
				push @ands, '(' . join( " OR\n", @ors ) . ')';
			}
			$q .= "		WHERE\n" . join( " AND\n", @ands );
		} else {
			$q .= "		WHERE\n" . join( " AND\n", @ors, @ands );
		}
	}
	$q .= "ORDER BY Login";
	my $sth;
	if ( !( $sth = $dbh->prepare_cached($q) ) ) {
		my $errstr = "Error preparing database query";
		if ( $self->IncludeDBError ) {
			$errstr .= ": " . DBI::errstr;
		}
		$self->Error($errstr);
		return undef;
	}
	foreach my $i ( "login", "first", "last" ) {
		if ( $opt->{$i} ) {
			if ( $opt->{fuzzy} ) {
				$sth->bind_param( ":" . $i,
					"%" . $opt->{$i} . "%" );
			} else {
				$sth->bind_param( ":" . $i, $opt->{$i} );
			}
		}
	}
	if ( $opt->{type} ) {
		$sth->bind_param( ":type", $opt->{type} );
	}
	if ( $opt->{status} ) {
		$sth->bind_param( ":status", $opt->{status} );
	}
	if ( !( $sth->execute() ) ) {
		my $errstr = "Error executing database query";
		if ( $self->IncludeDBError ) {
			$errstr .= ": " . DBI::errstr;
		}
		$self->Error($errstr);
		return undef;
	}

	my @ret;
	while (
		my (
			$id,         $login,     $first,     $middle,
			$last,       $suffix,    $status,    $type,
			$empid,      $title,     $badge,     $gender,
			$pref_first, $pref_last, $hire_date, $term_date
		)
		= $sth->fetchrow_array
	  )
	{

		my $user = $self->copy;
		$user->{Id}                 = $id;
		$user->{Login}              = $login;
		$user->{FirstName}          = $first;
		$user->{MiddleName}         = $middle;
		$user->{LastName}           = $last;
		$user->{NameSuffix}         = $suffix;
		$user->{Status}             = $status;
		$user->{Type}               = $type;
		$user->{EmployeeId}         = $empid;
		$user->{Title}              = $title;
		$user->{BadgeId}            = $badge;
		$user->{Gender}             = $gender;
		$user->{PreferredFirstName} = $pref_first;
		$user->{PreferredLastName}  = $pref_last;
		$user->{HireDate}           = $hire_date;
		$user->{TerminationDate}    = $term_date;
		$user->{_complete}          = 1;
		bless $user;
		push @ret, $user;
	}
	$sth->finish;

	$self->Error(undef);
	return \@ret;
}

sub Id {
	my $self = shift;

	return $self->{Id};
}

sub Login {
	my $self = shift;

	return $self->{Login};
}

sub FirstName {
	my $self = shift;

	return $self->{FirstName};
}

sub MiddleName {
	my $self = shift;

	return $self->{MiddleName};
}

sub LastName {
	my $self = shift;

	return $self->{LastName};
}

sub NameSuffix {
	my $self = shift;

	return $self->{NameSuffix};
}

sub Status {
	my $self = shift;

	return $self->{Status};
}

sub Type {
	my $self = shift;

	return $self->{Type};
}

sub EmployeeId {
	my $self = shift;

	return $self->{EmployeeId};
}

sub Title {
	my $self = shift;

	return $self->{Title};
}

sub BadgeId {
	my $self = shift;

	return $self->{BadgeId};
}

sub PreferredFirstName {
	my $self = shift;

	return $self->{PreferredFirstName};
}

sub PreferredLastName {
	my $self = shift;

	return $self->{PreferredLastName};
}

sub HireDate {
	my $self = shift;

	return $self->{HireDate};
}

sub TerminationDate {
	my $self = shift;

	return $self->{TerminationDate};
}

sub GetUserUclass {
	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		eval { $dbh = $self->DBHandle };
	}
	if ( !$dbh ) {
		$self->Error("Invalid class reference passed");
		return undef;
	}

	if ( !( eval { $self->Id } ) ) {
		$self->Error("Invalid user object");
		return undef;
	}
	$self->Error(undef);

	my $opt = &_options(@_);

	my $uclass =
	  $self->GetUclass( name => $self->Login, type => 'per-user' );

	if ( ref($uclass) ) {
		return $uclass;
	}

	# Either we had a database error, or the user didn't exist.  At this
	# point, we don't really care, but we'll figure it out now.  Try
	# to create the uclass

	$uclass = $self->GetUclass(
		name   => $self->Login,
		type   => 'per-user',
		create => 1
	);

	if ( !ref($uclass) ) {
		return $uclass;
	}

	# Now that we have the uclass created, add the user to the uclass.

	if ( !$uclass->AddUser($self) ) {
		$self->Error( $uclass->Error );
		return undef;
	}

	return $uclass;
}

my @itoa64 = split( '',
	"./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz" );

sub i32toa64 {
	my $val  = shift;
	my $size = shift;
	my $string;

	while ( --$size >= 0 ) {
		$string .= $itoa64[ $val & 0x3f ];
		$val >>= 6;
	}
	return $string;
}

#====

sub CreateNewUser {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $dude = shift;
	my ($gid);
	my ($uid);
	my ($userid);
	my ($employee_id);

	if ( !$dude->{last} ) {
		( $dude->{first}, $dude->{middle}, $dude->{last} ) =
		  ( $dude->{name} =~ /^(\S+)\s*(.*)\s+(\S+)$/ );
	}

	my ( $q, $sth );
	my $type = lc( $dude->{type} );
	my $company;
	if ( $dude->{company} ) {
		$q = qq {
			SELECT
				Company_ID
			FROM
				Company 
			WHERE
				Company_Name = '$dude->{company}'
		};
		$sth = $dbh->prepare_cached($q);
		if ( !$sth || !( $sth->execute ) ) {
			$JazzHands::Management::Errmsg = "$q: " . $DBI::errstr;
			goto failure;
		}
		$company = ( $sth->fetchrow_array )[0];
		$sth->finish;
	}

	if ( !$company ) {
		$q = qq {
			SELECT
				Company_ID
			FROM
				Company 
			WHERE
				Company_Name = 'none'
		};
		$sth = $dbh->prepare_cached($q);
		if ( !$sth || !( $sth->execute ) ) {
			$JazzHands::Management::Errmsg = "$q: " . $DBI::errstr;
			goto failure;
		}
		$company = ( $sth->fetchrow_array )[0];
		$sth->finish;
	}

	if ( !defined($company) ) {
		$JazzHands::Management::Errmsg =
		  "Unable to obtain an appropriate company id";
		goto failure;
	}

	$dude->{title}  = "" if ( !$dude->{title} );
	$dude->{suffix} = "" if ( !$dude->{suffix} );
	$dude->{gender} = "" if ( !$dude->{gender} );

	#
	# add the system_user record
	#
	$q = qq/
		BEGIN
			system_user_util.user_add
			(
				:userid,
				:employee_id,
				:login,
				:first,
				:middle,
				:last,
				:suffix,
				'enabled',
				:type,
				:title,
				:companyid,
				:gender,
				null,
				null,
				sysdate,
				null,
				null,
				null
			);
		END;
	/;
	$sth = $dbh->prepare($q);
	$sth->bind_param( ":login",     $dude->{user} );
	$sth->bind_param( ":first",     $dude->{first} );
	$sth->bind_param( ":middle",    $dude->{middle} );
	$sth->bind_param( ":last",      $dude->{last} );
	$sth->bind_param( ":suffix",    $dude->{suffix} );
	$sth->bind_param( ":type",      $dude->{type} );
	$sth->bind_param( ":title",     $dude->{title} );
	$sth->bind_param( ":companyid", $company );
	$sth->bind_param( ":gender",    $dude->{gender} );
	$sth->bind_param_inout( ":userid",      \$userid,      32 );
	$sth->bind_param_inout( ":employee_id", \$employee_id, 32 );

	if ( !$sth || !( $sth->execute() ) ) {
		$JazzHands::Management::Errmsg = "$q: " . $DBI::errstr;
		goto failure;
	}

	#
	# add the authorization record
	#
	$q = qq/
		BEGIN
			unix_util.unix_add
			(
				$userid,
				'$dude->{shell}',
				'$dude->{home}',
				'*',
				:uid,
				:gid
			);
		END;
	/;
	$sth = $dbh->prepare($q);
	$sth->bind_param_inout( ":uid", \$uid, 32 );
	$sth->bind_param_inout( ":gid", \$gid, 32 );
	if ( !$sth || !( $sth->execute() ) ) {
		$JazzHands::Management::Errmsg = "$q: " . $DBI::errstr;
		goto failure;
	}

	if ( defined($type) ) {
		my $uclass = "all_$type";
		$uclass =~ tr/A-Z/a-z/;

		my $uclassid = GetUclassFromName( $dbh, $uclass );
		if ($uclassid) {
			$q = qq{
				INSERT INTO Uclass_User (
					UClass_ID,
					System_User_ID,
					UClass_Type
				) VALUES (
					$uclassid,
					$userid,
					'systems'
				)
			};
			$sth = $dbh->prepare($q);
			$sth->execute;
		}

	}

	if ( $dude->{passwd} ) {
		my $salt = join '',
		  ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' )
		  [ rand 64, rand 64 ];
		my $md5salt = '$1$'
		  . i32toa64( rand(0xffffffff), 4 )
		  . i32toa64( rand(0xffffffff), 4 ) . '$';
		my ( $crypt, $md5, $sha1, $lanman, $nt );
		if ( defined( $dude->{passwd} ) ) {
			$crypt = crypt( $dude->{passwd}, $salt );
			$md5   = crypt( $dude->{passwd}, $md5salt );
			$sha1  = sha1_base64( $dude->{passwd} );
			( $lanman, $nt ) = ( "*", "*" );
		} else {
			$crypt = "*";
			$md5   = "*";
			$sha1  = "*";
			( $lanman, $nt ) = ( "*", "*" );
		}

		#
		# [XXX] create kerberos password here!
		#

		$q = qq/
			BEGIN
				unix_util.user_password($userid, 'crypt', '$crypt');
				unix_util.user_password($userid, 'md5hash', '$md5');
				unix_util.user_password($userid, 'sha1', '$sha1');
			END;
		/;
		$sth = runquery( $dbh, $q );
		if ( !$sth ) {
			$JazzHands::Management::Errmsg = $DBI::errstr;
			goto failure;
		}

	} elsif ( $dude->{crypt} ) {
		my $crypt = $dude->{crypt};
		$q = qq/
			BEGIN
				unix_util.user_password($userid, 'crypt', '$crypt');
			END;
		/;
		$sth = runquery( $dbh, $q );
		if ( !$sth ) {
			$JazzHands::Management::Errmsg = $DBI::errstr;
			goto failure;
		}
	}

	return ($userid);

      failure:
	$dbh->rollback;
	print "$JazzHands::Management::Errmsg\n";
	return (undef);
}

sub GetUserDataBySystemUserID {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $id = shift;

	my $q = qq {
		SELECT
			System_User_ID		AS SYSTEM_USER_ID,
			SU.Login 				AS LOGIN,
			SU.System_User_Status 	AS SYSTEM_USER_STATUS,
			SU.System_User_Type 	AS SYSTEM_USER_TYPE,
			SU.Login 				AS LOGIN,
			UUI.Unix_UID 			AS UNIX_UID,
			UUI.Unix_Group_ID 		AS UNIX_GROUP_ID,
			UUI.Shell				AS SHELL,
			UUI.Default_Home		AS DEFAULT_HOME
		FROM
			System_User SU LEFT JOIN User_Unix_Info UUI USING (System_User_ID)
		WHERE
			System_User_ID = ?
	};
	my $sth = runquery( $dbh, $q, $id );
	if ( !$sth ) {
		$JazzHands::Management::Errmsg = $DBI::errstr;
		return undef;
	}
	my ($row) = $sth->fetchrow_hashref || return undef;
	return $row;
}

#
# determine if a given type passed in is valid
#
sub IsValidUserType {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $type = shift;
	my $q    = qq{
		SELECT	
			count(*)
		  FROM
			VAL_System_User_Type
		 WHERE
			system_user_type = :1
	};
	my $sth = $dbh->prepare_cached($q) || die("$q");
	$sth->execute($type) || die("$q");

	my $tally = ( $sth->fetchrow_array )[0];
	$sth->finish;

	$tally;
}

sub SetPassword {
	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		eval { $dbh = $self->DBHandle };
	}
	if ( !$dbh ) {
		$self->Error("Invalid class reference passed");
		return undef;
	}

	if ( !( eval { $self->Id } ) ) {
		$self->Error("Invalid user object");
		return undef;
	}
	$self->Error(undef);

	my $opt = &_options(@_);

	if ( $opt->{password} ) {
		foreach my $i ( "md5", "des", "sha1-nosalt", "blowfish" ) {
			$opt->{$i} = $opt->{password};
		}
	}

	if ( $opt->{md5} ) {
		my $md5salt = '$1$'
		  . i32toa64( rand(0xffffffff), 4 )
		  . i32toa64( rand(0xffffffff), 4 ) . '$';
		$opt->{md5} = crypt( $opt->{md5}, $md5salt );
	}

	if ( $opt->{networkdevice} ) {
		my $md5salt = '$1$'
		  . i32toa64( rand(0xffffffff), 4 )
		  . i32toa64( rand(0xffffffff), 4 ) . '$';
		$opt->{networkdevice} =
		  crypt( $opt->{networkdevice}, $md5salt );
	}

	if ( $opt->{des} ) {
		my $dessalt = join '',
		  ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' )
		  [ rand 64, rand 64 ];
		$opt->{des} = crypt( $opt->{des}, $dessalt );
	}

	if ( $opt->{'sha1-nosalt'} ) {
		$opt->{sha1} = sha1_base64( $opt->{sha1} );
	}

	if ( $opt->{blowfish} ) {
		$opt->{blowfish} = bcrypt(
			$opt->{blowfish},
			'$2a$07$'
			  . en_base64(
				pack( "LLLL",
					rand(0xffffffff), rand(0xffffffff),
					rand(0xffffffff), rand(0xffffffff) )
			  )
		);
	}

	#
	# [XXX] change kerberos password here?
	#
	# get principal
	# if (!there) {
	#	create principal
	# }
	# set password
	# set expiration
	# party
	#

	my $q = qq{
		UPDATE
			System_Password
		SET
			User_Password = :pass,
			Change_Time = SYSDATE
		WHERE
			System_User_ID = :id AND
			Password_Type = :pwtype
	};
	my $updsth;
	if ( !( $updsth = $dbh->prepare_cached($q) ) ) {
		my $errstr = "Error preparing database query";
		if ( $self->DBErrors ) {
			$errstr .= ": " . DBI::errstr;
		}
		$self->Error($errstr);
		return undef;
	}

	$q = qq{
		INSERT INTO System_Password (
			System_User_ID,
			Password_Type,
			User_Password,
			Change_Time
		) VALUES (
			:id,
			:pwtype,
			:pass,
			SYSDATE
		)
	};
	my $inssth;
	if ( !( $inssth = $dbh->prepare_cached($q) ) ) {
		my $errstr = "Error preparing database query";
		if ( $self->DBErrors ) {
			$errstr .= ": " . DBI::errstr;
		}
		$self->Error($errstr);
		return undef;
	}

	foreach my $pwtype ( "md5", "des", "sha1", "blowfish", "networkdevice" )
	{
		next if ( !$opt->{$pwtype} );
		$updsth->bind_param( ":id",     $self->Id );
		$updsth->bind_param( ":pwtype", $pwtype );
		$updsth->bind_param( ":pass",   $opt->{$pwtype} );

		if ( !( $updsth->execute() ) ) {
			my $errstr = "Error executing database update";
			if ( $self->DBErrors ) {
				$errstr .= ": " . DBI::errstr;
			}
			$self->Error($errstr);
			return undef;
		}
		if ( $updsth->rows == 0 ) {
			$inssth->bind_param( ":id",     $self->Id );
			$inssth->bind_param( ":pwtype", $pwtype );
			$inssth->bind_param( ":pass",   $opt->{$pwtype} );

			if ( !( $inssth->execute() ) ) {
				my $errstr = "Error executing database insert";
				if ( $self->DBErrors ) {
					$errstr .= ": " . DBI::errstr;
				}
				$self->Error($errstr);
				return undef;
			}
		}
	}
	return 1;
}

sub SetUserAuthQuestions {
	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		eval { $dbh = $self->DBHandle };
	}
	if ( !$dbh ) {
		$self->Error("Invalid class reference passed");
		return undef;
	}

	if ( !( eval { $self->Login } ) ) {
		$self->Error("Invalid user object");
		return undef;
	}
	$self->Error(undef);

	my $opt = &_options(@_);

	my $questions = $opt->{questions};
	if ( !( ref($questions) eq 'HASH' ) ) {
		$self->Error("questions option must be a hash reference");
	}

	#
	# We only allow setting of new auth questions.  They may not be changed
	# (for now)
	#
	my ( $q, $sth );
	$q = q {
		BEGIN
			INSERT INTO System_User_Auth_Question (
				System_User_ID,
				Auth_Question_ID,
				User_Answer
			) VALUES (
				:sysuid,
				:qid,
				:answer
			);
		EXCEPTION
			WHEN DUP_VAL_ON_INDEX THEN
				UPDATE System_User_Auth_Question SET
					User_Answer = :answer
				WHERE
					System_User_ID = :sysuid AND
					Auth_Question_ID = :qid;
		END;
	};
	if ( !( $sth = $dbh->prepare($q) ) ) {
		$self->Error( "Error preparing auth question set query: "
			  . ( $self->DBErrors ? ": " . $sth->errstr : "" ) );
		return undef;
	}
	foreach my $questionid ( keys %$questions ) {
		$sth->bind_param( ':sysuid', $self->Id );
		$sth->bind_param( ':qid',    $questionid );
		$sth->bind_param( ':answer', $questions->{$questionid} );
		if ( !( $sth->execute ) ) {
			$self->Error(
				"Error executing auth question set query"
				  . (
					$self->DBErrors
					? ": " . $sth->errstr
					: ""
				  )
			);
			return undef;
		}
	}
	return 1;
}

1;
