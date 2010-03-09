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

package JazzHands::Management::Dept;

use strict;
use vars qw($VERSION @EXPORT @ISA);
use Carp qw(cluck confess);
use Data::Dumper;

$VERSION = '1.0.1';    # $Date$

#
# Awesome query:
#
# This query should return expanded uclasses and departments so that its
# its possible to find out all the depts that make up a uclass and all the
# uclasses that make up a dept.
#
# This migrated into some of the views.
#
#select * from (
#        SELECT distinct dhe.child_dept_id as dept_id,
#                uhe.uclass_id
#        FROM
#        (select uclass_id, child_uclass_id from (
#         select uclass_id, uclass_id as child_uclass_id from uclass
#        UNION
#         select connect_by_root uclass_id as uclass_id, child_uclass_id
#          from  uclass_hier
#                connect by prior child_uclass_id = uclass_id
#        )) uhe
#                INNER JOIN uclass_dept ud
#                        on ud.uclass_id = uhe.child_uclass_id
#                INNER JOIN
#        (
#         select dept_id as dept_id, dept_id as child_dept_id from dept
#        UNION
#         select connect_by_root parent_dept_id as dept_id,
#                dept_id as child_dept_Id
#          from  (select * from dept where parent_dept_id is not NULL)
#                connect by prior dept_id = parent_dept_id
#        ) dhe
#                on ud.dept_id = dhe.dept_id
#                or ud.dept_id = dhe.dept_id
#        inner join uclass on uclass.uclass_id = uhe.child_uclass_id
#                and uclass.uclass_type = 'systems'
#)

require Exporter;
our @ISA = ("Exporter");
@EXPORT = qw(
  GetAllDeptUsers
  GetDeptChildren
  GetDeptIdFromName
  GetDeptManager
  SetDeptManager
  GetDeptNameFromId
  GetUserDept
);

sub import {
	JazzHands::Management::Dept->export_to_level( 1, @_ );
}

sub GetAllDeptUsers {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my ( $deptid, $deleted, $recurse ) = @_;

	#
	# backwards compatibility, this is inconsistant with the rest of the
	# system.  yes, yuck.
	#
	if ( !defined($recurse) ) {
		$recurse = 1;
	}

	my $q;
	if ($recurse) {
		$q = qq{
			SELECT
				0,
				Dept_ID,
				Name
			FROM
				Dept
			WHERE
				Dept_ID = :1
		UNION SELECT
				LEVEL,
				Dept_ID,
				Name
			FROM
				Dept
			CONNECT BY PRIOR
				Dept_ID = Parent_Dept_ID
			START WITH
				Parent_Dept_ID = :1
		};
	} else {
		$q = qq{
			SELECT	0, dept_id, name
			  FROM	dept
			 WHERE	dept_id = :1
		};
	}

	if ( !$dbh || !$dbh->ping ) {
		cluck " ++ dbh is not set, yet here we are:";
		return undef;
	}

	my @list;
	my $sth = $dbh->prepare_cached($q) || return (undef);
	$sth->execute($deptid) || return (undef);
	while ( my $hr = $sth->fetchrow_hashref ) {
		push( @list, $hr );
	}
	$sth->finish;

	my $rv = {};
	foreach my $hr (@list) {
		my $level    = $hr->{'LEVEL'};
		my $deptid   = $hr->{'DEPT_ID'};
		my $deptname = $hr->{'NAME'};

		foreach
		  my $login ( GetUsersFromDept( $dbh, $deptid, $deleted ) )
		{

			# THIS SHOULD NOT HAPPEN!
			next if ( defined( $rv->{$login} ) );
			$rv->{$login} = $deptname;
		}
	}
	$rv;
}

sub GetDeptNameFromId {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $id = shift;

	my $q = qq{
		SELECT
			NAME
		FROM
			Dept
		WHERE
			Dept_ID = :1
	};

	my $sth = $dbh->prepare_cached($q) || return undef;
	$sth->execute($id) || return (undef);

	my ($rv) = $sth->fetchrow_array;
	$sth->finish;
	$rv;
}

sub GetDeptIdFromName {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $name = shift;

	my $q = qq{
		SELECT
			Dept_ID
		FROM
			Dept
		WHERE
			Name = :1
	};

	my $sth = $dbh->prepare_cached($q) || return undef;
	$sth->bind_param( 1, $name );
	$sth->execute || return (undef);

	my ($rv) = $sth->fetchrow_array;
	$sth->finish;
	$rv;
}

sub GetUsersFromDept {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my ( $deptid, $deleted ) = @_;
	my @rv;

	my $q = qq{
		SELECT
			Dept_Member.System_User_ID
		FROM
			Dept_Member,
			System_User
		WHERE
			Dept_ID = ? AND
			(Finish_Date IS NULL OR Finish_Date >= SYSDATE) AND
			(Start_Date IS NULL OR Start_Date <= SYSDATE) AND
			System_User.System_User_ID = Dept_Member.System_User_ID
	};
	if ( !$deleted ) {
		$q .= qq {
			    AND
			System_User.System_User_Status IN ('enabled', 'onleave-enable')
		};
	}
	my $sth = $dbh->prepare_cached($q) || return (undef);
	$sth->execute($deptid) || return (undef);

	while ( my ($userid) = $sth->fetchrow_array ) {
		push @rv, $userid;
	}
	$sth->finish;
}

sub GetDeptManager {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $deptid = shift;

	my $q = qq{
		SELECT
			Dept.Manager_System_User_ID,
			System_User.Login,
			System_User.First_Name,
			System_User.Middle_Name,
			System_User.Last_Name,
			System_User.Name_Suffix
		FROM
			Dept,
			System_User
		WHERE
			Dept.Dept_ID = ? AND
			Dept.Manager_System_User_ID = System_User.System_User_ID
	};
	my $sth = $dbh->prepare_cached($q) || die($q);
	$sth->execute($deptid) || die($q);

	my ( $managerid, $login, $first, $middle, $last, $suffix );

	if (
		!(
			( $managerid, $login, $first, $middle, $last, $suffix )
			= $sth->fetchrow_array
		)
	  )
	{
		$sth->finish;
		return undef;
	}
	$sth->finish;
	my $mgrhash = {};
	$mgrhash->{userid} = $managerid;
	$mgrhash->{login}  = $login;
	$mgrhash->{first}  = $first;
	$mgrhash->{middle} = $middle;
	$mgrhash->{last}   = $last;
	$mgrhash->{suffix} = $suffix;

	return $mgrhash;
}

sub SetDeptManager {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my ( $deptid, $managerid ) = @_;

	my $q = qq{
		UPDATE
			Dept
		SET
			Manager_System_User_ID = ?
		WHERE
			Dept_ID = ?
	};
	my $sth = $dbh->prepare_cached($q) || die($q);
	$sth->execute( $managerid, $deptid ) || die($q);

	return 1;
}

sub GetUserDept {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my $userid = shift;

	my $q = qq {
		select	dept_id
		  from	dept_member
		 where	finish_date is NULL
		   and	system_user_id = ?
	};

	my $sth = $dbh->prepare_cached($q) || goto failure;
	$sth->execute($userid) || goto failure;

	my ($deptid) = $sth->fetchrow_array;
	$sth->finish;

	$JazzHands::Management::Errmsg = undef;
	return $deptid;
      failure:
	$JazzHands::Management::Errmsg = $DBI::errstr;
	print STDERR "err is $JazzHands::Management::Errmsg\n";
	undef;
}

sub GetDeptChildren {
	my $dbh = shift;

	if ( ref($dbh) eq "JazzHands::Management" ) {
		$dbh = $dbh->DBHandle;
	}
	return undef if !$dbh;

	my ( $deptid, $recurse ) = @_;

	my $q;

	if ($recurse) {
		$q = qq{
			select  level, dept_id, name
			  from  dept
			connect by prior dept_id = parent_dept_id
			start with parent_dept_id = :1
		};
	} else {
		$q = qq {
			select	1, dept_id, name
			  from	dept
			 where	parent_dept_id = :1
		};
	}

	my $sth = $dbh->prepare_cached($q) || goto failure;
	$sth->execute($deptid) || goto failure;

	my (@rv);
	while ( my ( $level, $dept_id, $name ) = $sth->fetchrow_array ) {
		my %x;
		$x{'deptid'} = $dept_id;
		$x{'level'}  = $level;
		$x{'name'}   = $name;
		push( @rv, \%x );
	}

	return undef if ( $#rv == -1 );
	return ( \@rv );

      failure:
	$JazzHands::Management::Errmsg = $DBI::errstr;
	print STDERR "err is $JazzHands::Management::Errmsg\n";
	undef;

}

1;

