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

package JazzHands::Management::Uclass;

use JazzHands::Management::Dept;

use strict;
use vars qw($VERSION @EXPORT @ISA);

$VERSION = '1.0.1';    # $Date$

require Exporter;
our @ISA = ( "Exporter", "JazzHands::Management" );
@EXPORT = qw(
  GetUclassFromName
  GetPerUclass
  GetAllUclassesForUser
  GetAllUsersFromUclass
  GetUclass
  GetUclassTypes
  CreatePerUserUclass
  AddUsertoUclass
  CreateUclass
  VerifyUclassPropertyType
);

sub import {
	JazzHands::Management::Uclass->export_to_level( 2, @_ );
	JazzHands::Management::Uclass->export_to_level( 1, @_ );
}

sub _options {
	my %ret = @_;
	for my $v ( grep { /^-/ } keys %ret ) {
		$ret{ substr( $v, 1 ) } = $ret{$v};
	}
	\%ret;
}

sub GetUclass {
	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error("GetUclass: Invalid class reference passed");
		return undef;
	}

	my $opt = &_options(@_);

	my $where;
	if ( $opt->{id} ) {
		$where = "Uclass_ID = :id";
	} elsif ( $opt->{type} && $opt->{name} ) {
		$where = "Name = :name AND Uclass_Type = :type";
	} else {
		$self->Error(
"GetUclass: Uclass name and type must be specified without id"
		);
		return undef;
	}

	my ( $q, $sth );

	$q = qq {
		SELECT
			Uclass_ID,
			Name,
			Uclass_Type
		FROM
			Uclass
		WHERE
			$where
	};
	if ( !( $sth = $dbh->prepare_cached($q) ) ) {
		$self->Error("GetUclass: Error preparing database query");
		return undef;
	}
	if ( $opt->{id} ) {
		$sth->bind_param( ':id', $opt->{id} );
	} else {
		$sth->bind_param( ':name', $opt->{name} );
		$sth->bind_param( ':type', $opt->{type} );
	}
	if ( !( $sth->execute ) ) {
		$self->Error("GetUclass: Error executing database query");
		return undef;
	}
	my ( $id, $name, $type ) = $sth->fetchrow_array;
	$sth->finish;
	if ( !$id ) {
		if ( !$opt->{create} ) {
			$self->Error("Uclass does not exist");
			return undef;
		}
		$q = qq {
			INSERT INTO Uclass (
				Uclass_Type,
				Name
			) VALUES (
				:type,
				:name
			) RETURNING Uclass_ID INTO :id
		};
		if ( !( $sth = $dbh->prepare($q) ) ) {
			$self->Error(
				"GetUclass: Error preparing database insert");
			return undef;
		}
		$sth->bind_param( ':type', $opt->{type} );
		$sth->bind_param( ':name', $opt->{name} );
		$sth->bind_param_inout( ':id', \$id, 32 );
		if ( !( $sth->execute ) ) {
			$self->Error(
				"GetUclass: Error executing database insert");
			return undef;
		}
	}
	my $uclass = $self->copy;
	$uclass->{Id}   = $id;
	$uclass->{Name} = $name;
	$uclass->{Type} = $type;
	bless $uclass;
}

sub Id {
	my $self = shift;

	return $self->{Id};
}

sub Name {
	my $self = shift;

	return $self->{Name};
}

sub Type {
	my $self = shift;

	return $self->{Type};
}

sub AddUser {
	my $self = shift;
	my $dbh;

	if ( ref($self) ) {
		eval { $dbh = $self->DBHandle };
	}

	if ( !$dbh ) {
		$self->Error("Uclass::AddUser: Invalid class reference passed");
		return undef;
	}

	my $user = shift;
	if ( !( eval { $user->Login } ) ) {
		$self->Error("Uclass::AddUser: Invalid user object");
		return undef;
	}

	my ( $q, $sth );
	$q = qq {
		INSERT INTO Uclass_User (
			Uclass_ID,
			System_User_ID
		) VALUES (
			:uclassid,
			:userid
		)
	};
	if ( !( $sth = $dbh->prepare($q) ) ) {
		my $errstr = "Uclass::Adduser: Error preparing database insert";
		if ( $self->DBErrors ) {
			$errstr .= ": " . DBI::errstr;
		}
		$self->Error($errstr);

		return undef;
	}
	$sth->bind_param( ':uclassid', $self->Id );
	$sth->bind_param( ':userid',   $user->Id );
	if ( !( $sth->execute ) ) {
		my $errstr = "Uclass::Adduser: Error executing database insert"
		  . DBI::errstr;
		if ( $self->DBErrors ) {
			$errstr .= ": " . DBI::errstr;
		}
		$self->Error($errstr);
		return undef;
	}

	return 1;
}

sub GetPerUclass {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $user = shift;

	my $q = qq{
		select	System_User_ID
		 from 	System_User 
		where 	Login = ?
	};

	my $sth = $dbh->prepare_cached($q) || return undef;
	$sth->execute($user) || return undef;

	$q = qq{
		SELECT
			UClass_ID
		FROM
			UClass
		WHERE
			Name = ? AND
			UClass_Type = 'per-user'
	};

	$sth = $dbh->prepare_cached($q) || return undef;
	$sth->execute($user) || return undef;

	my ($id) = ( $sth->fetchrow_array )[0];

	$sth->finish;
	$id;
}

sub GetUclassFromName {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my ( $name, $type ) = @_;
	$type = 'systems' if !$type;

	my $q = qq{
		SELECT
			UClass_Id
		FROM
			Uclass
		WHERE
			Name = ? AND
			UClass_Type = ?
	};

	my $sth = $dbh->prepare_cached($q) || return undef;
	$sth->execute( $name, $type ) || return undef;

	my $rv = ( $sth->fetchrow_array )[0];

	$sth->finish;
	$rv;
}

sub GetUclassTypes {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $q = qq {
		SELECT
			UClass_Type,
			Description
		FROM
			VAL_UClass_Type
	};

	my $sth = $dbh->prepare_cached($q) || return undef;
	$sth->execute() || return undef;
	my $gUThash = {};
	while ( my ( $type, $desc ) = $sth->fetchrow_array ) {
		$gUThash->{$type} = $desc;
	}
	$gUThash;
}

sub AddUsertoUclass {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my ( $uclassid, $user ) = shift;

	my $q = qq{
		INSERT INTO UClass_User (
			UClass_ID,
			System_User_ID
		) VALUES (
			?,
			?
		)};
	my $sth = $dbh->prepare($q) || return undef;
	$sth->execute( $uclassid, $user ) || return undef;
}

sub CreateUclass {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my ( $name, $type ) = shift;

	my $q = qq{
		INSERT INTO UClass (
			UClass_Type,
			Name
		) VALUES (
			:type,
			:name
		)
		RETURNING Uclass_ID INTO :id
	};
	my $sth = $dbh->prepare($q) || return undef;
	my $id;
	$sth->bind_param( ":name",  $name );
	$sth->bind_param( ":ttype", $type );
	$sth->bind_param_inout( ":id", \$id, 32 );
	$sth->execute || return undef;
	$sth->finish;
	$id;
}

sub CreatePerUserUclass {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $user = shift;

	return undef if ( !findUserIdFromlogin( $dbh, $user ) );

	if ( my $id = GetPerUclass( $dbh, $user ) ) {
		return $id;
	}

	my $id = CreateUclass( $dbh, $user, 'per-user' );
	AddUsertoUclass( $dbh, $id, $user );
	$id;
}

sub GetUsersFromUclass {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my ( $uclassid, $deleted ) = @_;
	my (@rv);
	$deleted = 1 if ( !defined($deleted) );

	my $q = qq{
		SELECT
			UClass_User.System_User_ID 
		FROM
			UClass_User
			INNER JOIN  System_User
				on UClass_User.System_User_ID = System_User.System_User_ID
		WHERE
			UClass_ID = :1
	};
	if ( !$deleted ) {
		$q .= qq{
				AND
			System_User.System_User_Status IN ('enabled', 
				'onleave-enabled')
		};
	}
	my $sth = $dbh->prepare_cached($q) || return (undef);
	$sth->bind_param( 1, $uclassid );
	$sth->execute || return (undef);
	while ( my ($login) = $sth->fetchrow_array ) {
		push( @rv, $login );
	}

	@rv;
}

sub GetDeptsForUclass {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $uclassid = shift;
	my (@rv);

	my $q = qq{
		SELECT	Dept.Name 
	  	  FROM	Dept
			INNER JOIN UClass_Dept
 				on UClass_Dept.Dept_ID = Dept.Dept_ID
	   	WHERE	UClass_Dept.UClass_ID = :1
	};
	my $sth = $dbh->prepare_cached($q) || return (undef);
	$sth->bind_param( 1, $uclassid );
	$sth->execute || return (undef);
	while ( my ($deptname) = $sth->fetchrow_array ) {
		push( @rv, $deptname );
	}

	@rv;
}

sub getDeptIdsFromUclass {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $uclassid = shift;
	my (@rv);

	my $dq = qq{
		SELECT	dept_id
	  	 FROM	UClass_Dept
	 	WHERE	UClass_Dept.UClass_ID = :1
	};
	my $dsth = $dbh->prepare_cached($dq) || return (undef);
	$dsth->bind_param( 1, $uclassid );
	$dsth->execute || return (undef);
	while ( my ($deptid) = $dsth->fetchrow_array ) {
		push( @rv, $deptid );
	}
	@rv;
}

sub GetUclassHier {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $uclassid = shift;
	my @rv;

	my $q = qq{
		SELECT
			0,
			Name,
			UClass_ID
		FROM
			UClass
		WHERE
			UClass_ID = ?
		UNION
		SELECT
			Level,
			Name,
			Child_UClass_ID
		FROM
			(	SELECT
					uch.Child_UClass_ID,
					uc.Name, 
					uch.UClass_ID
				FROM
					UClass_Hier	uch,
					UClass		uc
				WHERE
					uc.UClass_ID = uch.Child_UClass_ID
			)
		CONNECT BY 
			PRIOR Child_UClass_ID = UClass_ID
		START WITH
			UClass_ID = ?
	};

	my $sth = $dbh->prepare_cached($q) || return (undef);
	$sth->execute( $uclassid, $uclassid ) || return (undef);

	while ( my ( $level, $uclassname, $ucid ) = $sth->fetchrow_array ) {
		push @rv, [ $level, $uclassname, $ucid ];
	}
	$sth->finish;
	@rv;
}

sub GetAllUsersFromUclass {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my ( $uclassid, $deleted, $recurse ) = @_;

	$deleted = 1 if ( !defined($deleted) );

	my $rv = {};
	foreach my $entry ( GetUclassHier( $dbh, $uclassid ) ) {
		my ( $level, $uclassname, $ucid ) = @$entry;

		foreach
		  my $login ( GetUsersFromUclass( $dbh, $ucid, $deleted ) )
		{
			next if ( defined( $rv->{$login} ) );
			$rv->{$login} = $uclassname;
		}

		foreach my $deptid ( getDeptIdsFromUclass( $dbh, $ucid ) ) {
			my $dudes =
			  GetAllDeptUsers( $dbh, $deptid, $deleted, $recurse );
			foreach my $key ( sort keys(%$dudes) ) {
				$rv->{$key} =
				  "$uclassname via " . $dudes->{$key};
			}
		}
	}
	$rv;
}

sub GetAllUclassesForUser {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my ( $userid, $type ) = shift;
	$type = 'systems' if ( !$type );

	my (%rv);
	if ($userid) {
		my $q = qq{
			select	uclass.name, uclass.uclass_id
			  from	uclass
					inner join uclass_user ucu on
							ucu.uclass_id = uclass.uclass_id
			 where
					ucu.system_user_id = ?
			    and
					uclass.uclass_type = ?
		};
		my $sth = $dbh->prepare_cached($q) || goto failure;
		$sth->execute( $userid, $type ) || goto failure;
		while ( my ( $name, $id ) = $sth->fetchrow_array ) {
			$rv{$name}->{'type'}     = 'uclass';
			$rv{$name}->{'uclassid'} = $id;
		}
	}

	my $deptid = GetUserDept( $dbh, $userid );
	if ($deptid) {
		my $q = qq{
			select	uclass.name, uclass.uclass_id, dept.name
			  from	uclass_dept ucd
					inner join uclass
						on ucd.uclass_id = uclass.uclass_id
					inner join dept
						on ucd.dept_id = dept.dept_id
			 where
					ucd.dept_id = ?
			   and
					uclass.uclass_type = 'systems'
		};

		my $sth = $dbh->prepare_cached($q) || goto failure;
		$sth->execute($deptid) || goto failure;

		while ( my ( $name, $uclassid, $deptname ) =
			$sth->fetchrow_array )
		{
			$rv{$name}->{'type'}     = 'dept';
			$rv{$name}->{'uclassid'} = $uclassid;
			$rv{$name}->{'deptid'}   = $deptid;
			$rv{$name}->{'dept'}     = $deptname;
		}
	}

	$JazzHands::Management::Errmsg = undef;
	return \%rv;

      failure:
	$JazzHands::Management::Errmsg = $DBI::errstr;
	undef;
}

#
# Checks for property validity
#
sub VerifyUclassPropertyType {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $type = shift;

	# This needs to use the validation table instead

	return undef if ( !$type );

	my @valid = (
		'ForceCrypt',     'ForceMD5',
		'ForceUserUID',   'ForceUserGID',
		'ForceUserGroup', 'ForceShell',
		'ForceHome',      'ForceStdShell',
		'ForceStdHome'
	);

	my @rv = grep( $_ eq $type, @valid );
	return undef if ( $#rv == -1 );
	1;
}

1;
