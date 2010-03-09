
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

=head1 NAME

 JazzHands::Management::ConsoleACL - JazzHands Perl interface to manipulate console ACLs

=head1 SYNOPSIS

 $is_success = AddConsACLToMclass(
                 { -uclass => $uclass | -user => $user }
                   -mclass => $mclass, [ -permissions => $permissions ] );

 $is_success = RemoveConsACLFromMclass(
                 { -uclass => $uclass | -user => $user }
                   -mclass => $mclass);

 $is_success = AddConsACLToDefault(
                 { -uclass => $uclass | -user => $user });

 $is_success = RemoveConsACLFromDefault(
                 { -uclass => $uclass | -user => $user });

 $is_success = AddSudoGrantsConsole(
                 { -uclass => $uclass | -user => $user },
                 [ -permissions => $permissions ] );

 $is_success = RemoveSudoGrantsConsole(
                 { -uclass => $uclass | -user => $user });

 $aref = $jh->GetConsACLDependencies(
                 { -uclass => $uclass | -user => $user }
                   -mclass => $mclass);

 $text = $jh->GetNconsoleConfUclasses;
 $text = $jh->GetNconsoleConfMclasses;
 $text = $jh->GetNconsoleConf;
 $is_success = $jh->WriteNconsoleConf( -filename => $filename);

=head1 DESCRIPTION

JazzHands::Management::ConsoleACL module provides an object oriented
interface to manipulate console ACL information in JazzHands as stored in
tables uclass_property and MCLASS_PROPERTY_OVERRIDE.

=head1 METHODS

=over 4

=cut

###############################################################################

package JazzHands::Management::ConsoleACL;

use strict;
use vars qw($VERSION @EXPORT @ISA);
use IO::File;
use FindBin qw($Script);

$VERSION = '1.0.0';

require Exporter;
our @ISA = ( "Exporter", "JazzHands::Management" );

@EXPORT = qw(
  AddConsACLToMclass
  RemoveConsACLFromMclass
  AddConsACLToDefault
  RemoveConsACLFromDefault
  AddSudoGrantsConsole
  RemoveSudoGrantsConsole
  GetConsACLDependencies
  GetNconsoleConfUclasses
  GetNconsoleConfMclasses
  GetNconsoleConf
  WriteNconsoleConf
);

our %enabled_uclass;

our %perm2text =
  ( 0, 'r', 1, 'rw', 2, 'rx', 3, 'rxw', 4, 'rb', 5, 'rbw', 6, 'rbx', 7,
	'rbxw' );

our %text2perm = (
	'r',    0, 'rw',   1, 'wr',   1, 'rx',   2, 'xr',   2, 'rxw',  3,
	'rwx',  3, 'wrx',  3, 'wxr',  3, 'xrw',  3, 'xwr',  3, 'rb',   4,
	'br',   4, 'rbw',  5, 'rwb',  5, 'wrb',  5, 'wbr',  5, 'brw',  5,
	'bwr',  5, 'rbx',  6, 'rxb',  6, 'xrb',  6, 'xbr',  6, 'brx',  6,
	'bxr',  6, 'rbxw', 7, 'rbwx', 7, 'rxwb', 7, 'rxbw', 7, 'rwbx', 7,
	'rwxb', 7, 'bxrw', 7, 'bxwr', 7, 'bwrx', 7, 'bwxr', 7, 'brxw', 7,
	'brwx', 7, 'wxrb', 7, 'wxbr', 7, 'wbrx', 7, 'wbxr', 7, 'wrbx', 7,
	'wrxb', 7, 'xwrb', 7, 'xwbr', 7, 'xbrw', 7, 'xbwr', 7, 'xrwb', 7,
	'xrbw', 7
);

###############################################################################

sub import {
	JazzHands::Management::ConsoleACL->export_to_level( 1, @_ );
}

###############################################################################

sub _options {
	my %ret = @_;
	for my $v ( grep { /^-/ } keys %ret ) {
		$ret{ substr( $v, 1 ) } = $ret{$v};
	}
	\%ret;
}

###############################################################################

sub _um_name {
	my ( $id, $name ) = @_;

	$name =~ s/\W/_/g;

	return lc("${name}_${id}");
}

###############################################################################

=pod

=item AddConsACLToMclass(-mclass => $mclass,
-user => $user, -uclass => $uclass, [ -permissions => $permissions ])

Grant uclass $uclass access to console of machines in the mclass
$mclass with permissionss $permissions. If the -permissions option is
not used, permissions 'rwbx' are assigned.

=cut

###############################################################################

sub AddConsACLToMclass {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $q, $sth, @row );
	my ( $mclassid, $uclass, $utype, $uclassid, $perm, $ucpid );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error( "AddConsACLToMclass: "
			  . "Invalid class reference passed" );
		return undef;
	}

	## if the -permissions option was specified, map it to the right value

	if ( defined( $opt->{permissions} ) ) {
		$perm = $text2perm{ $opt->{permissions} };

		unless ( defined $perm ) {
			$self->Error(
				"AddConsACLToMclass: incorrect permissions");
			return undef;
		}
	}

	else {
		$perm = '7';
	}

	## get the mclass_id

	$q =
	  qq{select device_collection_id from device_collection where name = ?};

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("AddConsACLToMclass: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $opt->{mclass} ) ) {
		$self->Error("AddConsACLToMclass: $DBI::errstr");
		return undef;
	}

	unless ( @row = $sth->fetchrow_array ) {
		$self->Error( "AddConsACLToMclass: "
			  . "mclass $opt->{mclass} does not exist" );
		return undef;
	}

	$mclassid = $row[0];
	$sth->finish;

	## get the uclass_id

	$uclass = defined( $opt->{user} ) ? $opt->{user} : $opt->{uclass};
	$utype  = defined( $opt->{user} ) ? 'per-user'   : 'systems';

	$q =
	  qq{select uclass_id from uclass where name = ? and uclass_type = ?};

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("AddConsACLToMclass: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $uclass, $utype ) ) {
		$self->Error("AddConsACLToMclass: $DBI::errstr");
		return undef;
	}

	unless ( @row = $sth->fetchrow_array ) {
		$self->Error( "AddConsACLToMclass: "
			  . "uclass $uclass of type $utype does not exist" );
		return undef;
	}

	$uclassid = $row[0];
	$sth->finish;

	## check whether the entry already exists

	$q = qq{
        select up.property_value
        from uclass_property up, mclass_property_override mo
        where up.uclass_property_id = mo.uclass_property_id
        and up.uclass_id = ? and mo.device_collection_id = ?
        and uclass_property_name = 'PerMclass'
        and uclass_property_type = 'ConsoleACL'
    };

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("AddConsACLToMclass: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $uclassid, $mclassid ) ) {
		$self->Error("AddConsACLToMclass: $DBI::errstr");
		return undef;
	}

	if ( @row = $sth->fetchrow_array ) {
		$self->Error(
			"AddConsACLToMclass: permissions $perm2text{$row[0]} "
			  . "already assigned to this uclass and mclass" );
		return undef;
	}

	## insert a row into uclass_property if it does not exist

	$q = qq{
        insert into uclass_property
        (uclass_id, uclass_property_name, uclass_property_type, property_value)
        select ?, 'PerMclass', 'ConsoleACL', ? from dual
        where not exists (
          select * from uclass_property
          where uclass_id = ? and uclass_property_name = 'PerMclass'
          and uclass_property_type = 'ConsoleACL' and property_value = ?
        )
    };

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("AddConsACLToMclass: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $uclassid, $perm, $uclassid, $perm ) ) {
		$self->Error("AddConsACLToMclass: $DBI::errstr");
		return undef;
	}

	## get the uclass_property_id

	$q = qq{
        select uclass_property_id from uclass_property
        where uclass_id = ? and uclass_property_name = 'PerMclass'
        and uclass_property_type = 'ConsoleACL' and property_value = ?
    };

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("AddConsACLToMclass: $DBI::errstr");
		$dbh->rollback;
		return undef;
	}

	unless ( $sth->execute( $uclassid, $perm ) ) {
		$self->Error("AddConsACLToMclass: $DBI::errstr");
		$dbh->rollback;
		return undef;
	}

	@row   = $sth->fetchrow_array;
	$ucpid = $row[0];

	unless ( defined($ucpid) ) {
		$self->Error(
			"AddConsACLToMclass: this should not happen, seek help"
		);
		$dbh->rollback;
		return undef;
	}

	## create the entry in mclass_property_override

	$q = qq{
        insert into mclass_property_override
        (device_collection_id, uclass_property_id) values(?, ?)
    };

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("AddConsACLToMclass: $DBI::errstr");
		$dbh->rollback;
		return undef;
	}

	unless ( $sth->execute( $mclassid, $ucpid ) ) {
		$self->Error("AddConsACLToMclass: $DBI::errstr");
		$dbh->rollback;
		return undef;
	}

	$dbh->commit;
	return 1;
}

###############################################################################

=pod

=item RemoveConsACLFromMclass(-mclass => $mclass,
-user => $user, -uclass => $uclass)

Remove console access permissions from uclass $uclass on mclass $mclass.

=cut

###############################################################################

sub RemoveConsACLFromMclass {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $q, $sth, @row );
	my ( $mclassid, $uclass, $utype, $uclassid, $perm, $ucpid );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error( "RemoveConsACLFromMclass: "
			  . "Invalid class reference passed" );
		return undef;
	}

	## get the mclass_id

	$q =
	  qq{select device_collection_id from device_collection where name = ?};

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("RemoveConsACLFromMclass: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $opt->{mclass} ) ) {
		$self->Error("RemoveConsACLFromMclass: $DBI::errstr");
		return undef;
	}

	unless ( @row = $sth->fetchrow_array ) {
		$self->Error( "RemoveConsACLFromMclass: "
			  . "mclass $opt->{mclass} does not exist" );
		return undef;
	}

	$mclassid = $row[0];
	$sth->finish;

	## get the uclass_id

	$uclass = defined( $opt->{user} ) ? $opt->{user} : $opt->{uclass};
	$utype  = defined( $opt->{user} ) ? 'per-user'   : 'systems';

	$q =
	  qq{select uclass_id from uclass where name = ? and uclass_type = ?};

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("RemoveConsACLFromMclass: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $uclass, $utype ) ) {
		$self->Error("RemoveConsACLFromMclass: $DBI::errstr");
		return undef;
	}

	unless ( @row = $sth->fetchrow_array ) {
		$self->Error( "RemoveConsACLFromMclass: "
			  . "uclass $uclass of type $utype does not exist" );
		return undef;
	}

	$uclassid = $row[0];
	$sth->finish;

	## delete the entry from mclass_property_override

	$q = qq{
        delete from mclass_property_override where rowid in (
          select mo.rowid
          from uclass_property up, mclass_property_override mo
          where up.uclass_property_id = mo.uclass_property_id
          and up.uclass_id = ? and mo.device_collection_id = ?
          and uclass_property_name = 'PerMclass'
          and uclass_property_type = 'ConsoleACL'
        )
    };

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("RemoveConsACLFromMclass: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $uclassid, $mclassid ) ) {
		$self->Error("RemoveConsACLFromMclass: $DBI::errstr");
		return undef;
	}

	unless ( $sth->rows ) {
		$self->Error( "RemoveConsACLFromMclass: "
			  . "the specified entry does not exist" );
		return undef;
	}

	## delete all loose ConsoleACL entries from uclass_property

	$q = qq{
        delete from uclass_property up
        where uclass_property_type = 'ConsoleACL'
        and uclass_property_name = 'PerMclass'
        and not exists (
          select * from mclass_property_override mo
          where up.uclass_property_id = mo.uclass_property_id
        )
    };

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("RemoveConsACLFromMclass: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute ) {
		$self->Error("RemoveConsACLFromMclass: $DBI::errstr");
		return undef;
	}

	$dbh->commit;
	return 1;
}

###############################################################################

=pod

=item AddConsACLToDefault(-user => $user, -uclass => $uclass)

Grant uclass $uclass access to console on all machines.

=cut

###############################################################################

sub AddConsACLToDefault {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $q, $sth, @row );
	my ( $uclass, $utype, $uclassid );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error( "AddConsACLToDefault: "
			  . "Invalid class reference passed" );
		return undef;
	}

	## get the uclass_id

	$uclass = defined( $opt->{user} ) ? $opt->{user} : $opt->{uclass};
	$utype  = defined( $opt->{user} ) ? 'per-user'   : 'systems';

	$q =
	  qq{select uclass_id from uclass where name = ? and uclass_type = ?};

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("AddConsACLToDefault: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $uclass, $utype ) ) {
		$self->Error("AddConsACLToDefault: $DBI::errstr");
		return undef;
	}

	unless ( @row = $sth->fetchrow_array ) {
		$self->Error( "AddConsACLToDefault: "
			  . "uclass $uclass of type $utype does not exist" );
		return undef;
	}

	$uclassid = $row[0];
	$sth->finish;

	## check whether the entry already exists

	$q = qq{
        select up.property_value from uclass_property up
        where up.uclass_id = ?
        and uclass_property_name = 'AllMclasses'
        and uclass_property_type = 'ConsoleACL'
    };

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("AddConsACLToDefault: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute($uclassid) ) {
		$self->Error("AddConsACLToDefault: $DBI::errstr");
		return undef;
	}

	if ( @row = $sth->fetchrow_array ) {
		$self->Error(
			"AddConsACLToDefault: permissions $perm2text{$row[0]} "
			  . "already assigned to this uclass" );
		return undef;
	}

	## insert a row into uclass_property if it does not exist

	$q = qq{
        insert into uclass_property
        (uclass_id, uclass_property_name, uclass_property_type, property_value)
        values(?, 'AllMclasses', 'ConsoleACL', '7')
    };

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("AddConsACLToDefault: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute($uclassid) ) {
		$self->Error("AddConsACLToDefault: $DBI::errstr");
		return undef;
	}

	$dbh->commit;
	return 1;
}

###############################################################################

=pod

=item RemoveConsACLFromDefault(-user => $user, -uclass => $uclass)

Remove console access permissions from uclass $uclass on all machines
as granted by the AddConsACLToDefault.

=cut

###############################################################################

sub RemoveConsACLFromDefault {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $q, $sth, @row );
	my ( $uclass, $utype, $uclassid );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error( "RemoveConsACLFromDefault: "
			  . "Invalid class reference passed" );
		return undef;
	}

	## get the uclass_id

	$uclass = defined( $opt->{user} ) ? $opt->{user} : $opt->{uclass};
	$utype  = defined( $opt->{user} ) ? 'per-user'   : 'systems';

	$q =
	  qq{select uclass_id from uclass where name = ? and uclass_type = ?};

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("RemoveConsACLFromDefault: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $uclass, $utype ) ) {
		$self->Error("RemoveConsACLFromDefault: $DBI::errstr");
		return undef;
	}

	unless ( @row = $sth->fetchrow_array ) {
		$self->Error( "RemoveConsACLFromDefault: "
			  . "uclass $uclass of type $utype does not exist" );
		return undef;
	}

	$uclassid = $row[0];
	$sth->finish;

	## delete the entry from uclass_property

	$q = qq{
        delete from uclass_property
         where uclass_property_name = 'AllMclasses'
         and uclass_property_type = 'ConsoleACL' and uclass_id = ?
    };

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("RemoveConsACLFromDefault: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute($uclassid) ) {
		$self->Error("RemoveConsACLFromDefault: $DBI::errstr");
		return undef;
	}

	unless ( $sth->rows ) {
		$self->Error( "RemoveConsACLFromDefault: "
			  . "the specified entry does not exist" );
		return undef;
	}

	$dbh->commit;
	return 1;
}

###############################################################################

=pod

=item AddSudoGrantsConsole({ -user => $user | -uclass => $uclass},
[ -permissions => $permissions ])

Set the "sudo grants console" attribute for uclass $uclass or user
$user to grant permissions $permissions.

=cut

###############################################################################

sub AddSudoGrantsConsole {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh,    $q,     $sth,      @row );
	my ( $uclass, $utype, $uclassid, $perm );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error( "AddSudoGrantsConsole: "
			  . "Invalid class reference passed" );
		return undef;
	}

	## if the -permissions option was specified, map it to the right value

	if ( defined( $opt->{permissions} ) ) {
		$perm = $text2perm{ $opt->{permissions} };

		unless ( defined $perm ) {
			$self->Error(
				"AddConsACLToMclass: incorrect permissions");
			return undef;
		}
	}

	else {
		$perm = '7';
	}

	## get the uclass_id

	$uclass = defined( $opt->{user} ) ? $opt->{user} : $opt->{uclass};
	$utype  = defined( $opt->{user} ) ? 'per-user'   : 'systems';

	$q =
	  qq{select uclass_id from uclass where name = ? and uclass_type = ?};

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("AddSudoGrantsConsole: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $uclass, $utype ) ) {
		$self->Error("AddSudoGrantsConsole: $DBI::errstr");
		return undef;
	}

	unless ( @row = $sth->fetchrow_array ) {
		$self->Error( "AddSudoGrantsConsole: "
			  . "uclass $uclass of type $utype does not exist" );
		return undef;
	}

	$uclassid = $row[0];
	$sth->finish;

	## check whether the entry already exists

	$q = qq{
        select up.property_value from uclass_property up
        where up.uclass_id = ?
        and uclass_property_name = 'SudoGrantsConsole'
        and uclass_property_type = 'ConsoleACL'
    };

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("AddSudoGrantsConsole: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute($uclassid) ) {
		$self->Error("AddSudoGrantsConsole: $DBI::errstr");
		return undef;
	}

	if ( @row = $sth->fetchrow_array ) {
		$self->Error(
			"AddSudoGrantsConsole: permissions $perm2text{$row[0]} "
			  . "already assigned to this uclass" );
		return undef;
	}

	## insert a row into uclass_property if it does not exist

	$q = qq{
        insert into uclass_property
        (uclass_id, uclass_property_name, uclass_property_type, property_value)
        values(?, 'SudoGrantsConsole', 'ConsoleACL', ?)
    };

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("AddSudoGrantsConsole: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $uclassid, $perm ) ) {
		$self->Error("AddSudoGrantsConsole: $DBI::errstr");
		return undef;
	}

	$dbh->commit;
	return 1;
}

###############################################################################

=pod

=item RemoveSudoGrantsConsole(-user => $user, -uclass => $uclass)

Remove the "sudo grants console" attribute from user $user or uclass $uclass.

=cut

###############################################################################

sub RemoveSudoGrantsConsole {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $q, $sth, @row );
	my ( $uclass, $utype, $uclassid );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error( "RemoveSudoGrantsConsole: "
			  . "Invalid class reference passed" );
		return undef;
	}

	## get the uclass_id

	$uclass = defined( $opt->{user} ) ? $opt->{user} : $opt->{uclass};
	$utype  = defined( $opt->{user} ) ? 'per-user'   : 'systems';

	$q =
	  qq{select uclass_id from uclass where name = ? and uclass_type = ?};

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("RemoveSudoGrantsConsole: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $uclass, $utype ) ) {
		$self->Error("RemoveSudoGrantsConsole: $DBI::errstr");
		return undef;
	}

	unless ( @row = $sth->fetchrow_array ) {
		$self->Error( "RemoveSudoGrantsConsole: "
			  . "uclass $uclass of type $utype does not exist" );
		return undef;
	}

	$uclassid = $row[0];
	$sth->finish;

	## delete the entry from uclass_property

	$q = qq{
        delete from uclass_property
         where uclass_property_name = 'SudoGrantsConsole'
         and uclass_property_type = 'ConsoleACL' and uclass_id = ?
    };

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("RemoveSudoGrantsConsole: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute($uclassid) ) {
		$self->Error("RemoveSudoGrantsConsole: $DBI::errstr");
		return undef;
	}

	unless ( $sth->rows ) {
		$self->Error( "RemoveSudoGrantsConsole: "
			  . "the specified entry does not exist" );
		return undef;
	}

	$dbh->commit;
	return 1;
}

###############################################################################

=pod

=item GetConsACLDependencies([ -user => $user | -uclass => $uclass, ]
[ -mclass => $mclass, ]);

Return a reference to a list of lists of console access dependencies.
Columns in the list are mclass, uclass, uclass_property_type,
property_value. If any of the optional parameters are specified, only
entries matching the parameter are returned.

=cut

###############################################################################

sub GetConsACLDependencies {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $q, $sth, $aref );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error(
			"GetConsACLDependencies: Invalid class reference passed"
		);
		return undef;
	}

	## assemble the SQL query

	$q = qq{
       select c.name, u.name, u.uclass_type, up.uclass_property_name,
              decode(uo.property_value,
	             '0', 'r',  1, 'rw',  2, 'rx',  3, 'rxw',
                      4,  'rb', 5, 'rbw', 6, 'rbx', 7, 'rbxw') propval
       from uclass u, device_collection c, uclass_property up,
            mclass_property_override mo
       where u.uclass_id = up.uclass_id
       and up.uclass_property_id = mo.uclass_property_id
       and mo.device_collection_id = c.device_collection_id
       and up.uclass_property_type = 'ConsoleACL'
    };

	if ( defined $opt->{mclass} ) {
		$q .= 'and c.name = :2 ';
	}

	if ( defined $opt->{user} ) {
		$q .= qq{and u.name = :3 and u.uclass_type = 'per-user' };
	}

	if ( defined $opt->{uclass} ) {
		$q .= qq{and u.name = :3 and u.uclass_type = 'systems' };
	}

	$q .= qq{
        union
        select NULL, u.name, u.uclass_type, up.uclass_property_name,
               decode(uo.property_value,
	              '0', 'r',  1, 'rw',  2, 'rx',  3, 'rxw',
                       4,  'rb', 5, 'rbw', 6, 'rbx', 7, 'rbxw') propval
        from uclass u, uclass_property up
        where u.uclass_id = up.uclass_id
        and up.uclass_property_type = 'ConsoleACL'
        and up.uclass_property_name in ('AllMclasses', 'SudoGrantsConsole')
    };

	if ( defined $opt->{user} ) {
		$q .= qq{and u.name = :3 and u.uclass_type = 'per-user' };
	}

	if ( defined $opt->{uclass} ) {
		$q .= qq{and u.name = :3 and u.uclass_type = 'systems' };
	}

	$q .= 'order by 1,2';

	## prepare the query

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("GetSudoDependencies: $DBI::errstr");
		return undef;
	}

	## bind parameters

	if ( defined $opt->{mclass} ) {
		$sth->bind_param( 2, $opt->{mclass} );
	}

	if ( defined $opt->{user} ) {
		$sth->bind_param( 3, $opt->{user} );
	}

	if ( defined $opt->{uclass} ) {
		$sth->bind_param( 3, $opt->{uclass} );
	}

	## execute the query

	unless ( $sth->execute ) {
		$self->Error("GetConsACLDependencies: $DBI::errstr");
		return undef;
	}

	return $sth->fetchall_arrayref;
}

###############################################################################

=pod

=item GetNconsoleConfUclasses

Returns the uclass definitions part of the nconsole.conf file. Returns
undef on error. Also sets the global hash %enabled_uclass to true for
all uclasses that are in the nconsole.conf file.

=cut

###############################################################################

sub GetNconsoleConfUclasses {
	my $self = shift;
	my ( $dbh, $q, $aref, $row, $last_uclassid, $last_uclass, @logins,
		$text );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error(
"GetNconsoleConfUclasses: Invalid class reference passed"
		);
		return undef;
	}

	## get the list of enabled users who have any console privileges

	$q = qq{
        select distinct u.uclass_id, u.name, su.login
        from uclass u, uclass_property p,
             system_user su, v_uclass_user_expanded e
        where p.uclass_id = u.uclass_id
        and uclass_property_type = 'ConsoleACL'
        and e.uclass_id = u.uclass_id
        and su.system_user_id = e.system_user_id
        and su.system_user_status = 'enabled'
        order by u.uclass_id, su.login
    };

	unless ( $aref = $dbh->selectall_arrayref($q) ) {
		$self->Error("GetNconsoleConfUclasses: $DBI::errstr");
		return undef;
	}

	$text = '';

	## assemble the text of the nconsole.conf file

	foreach $row (@$aref) {
		my ( $uclassid, $uclass, $login ) = @$row;

		if ( defined($last_uclassid) && $uclassid != $last_uclassid ) {
			$enabled_uclass{$last_uclassid} = 1;
			$text .= "uclass: "
			  . _um_name( $last_uclassid, $last_uclass ) . " {\n";
			$text .= "\tusers: " . join( ' ', @logins ) . "\n";
			$text .= "}\n\n";
			@logins = ();
		}

		$last_uclassid = $uclassid;
		$last_uclass   = $uclass;
		push( @logins, $login );
	}

	if (@$aref) {
		$enabled_uclass{$last_uclassid} = 1;
		$text .= "uclass: "
		  . _um_name( $last_uclassid, $last_uclass ) . " {\n";
		$text .= "\tusers: " . join( ' ', @logins ) . "\n";
		$text .= "}\n\n";
	}

	return $text;
}

###############################################################################
#
# usage: @names = _device_port_names($sth->fetchall_arrayref);
#
# This function is very similar to generate_new_tcp_file in stab2tcp.
# The query is expected to return device names in the first column,
# and port names in the second column. The function returns a list of
# names, one name per input row. If a device in the input has only one
# port, the device name is returned in the output. If a device has
# multiple ports, the device name is returned for the first port, and
# port name prepended to the device name for each secondary port.
#
###############################################################################

sub _device_port_names {
	my $aref = shift;
	my ( $host, %ts, @names );

	## parse the JazzHands data into %ts

	foreach my $r (@$aref) {
		my ( $host, $hport ) = @$r;

		warn "duplicate entry for $host:$hport\n"
		  if ( exists $ts{$host}{$hport} );

		$ts{$host}{$hport} = 1;
	}

	## transform %ts into the list of names

	foreach $host ( keys %ts ) {
		my $n = 0;

		## for most hosts, the following loop will only have 1 iteration

		foreach my $hport ( sort keys %{ $ts{$host} } ) {

			## if the host has multiple ports, prepend port name

			if ( $n++ > 0 ) {
				$hport =~ s/[^\w-]/_/g;
				$host = $hport . '.' . $host;
			}

			push( @names, $host );
		}
	}

	return @names;
}

###############################################################################

=pod

=item GetNconsoleConfMclasses

Returns the mclass definitions part of the nconsole.conf file. Returns
undef on error.

=cut

###############################################################################

sub GetNconsoleConfMclasses {
	my $self = shift;
	my ( $dbh, $q, $aref, @mc, $mcl, $mcle, $row );
	my ( $sth1, $sth2, $lastlev, $text, %mc_out, %permission );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error(
"GetNconsoleConfUclasses: Invalid class reference passed"
		);
		return undef;
	}

	## First of all, get a list of device_collection_ids for which
	## console privileges are present

	$q = qq{
        select distinct devcolid from (
          select su.device_collection_id devcolid
          from sudo_uclass_device_collection su, uclass_property up
          where su.uclass_id = up.uclass_id
          and su.sudo_alias_name = 'ALL' and su.run_as_uclass_id is NULL
          and up.uclass_property_type = 'ConsoleACL'
          and up.uclass_property_name = 'SudoGrantsConsole'
          union
          select mo.device_collection_id devcolid
          from mclass_property_override mo, uclass_property up
          where up.uclass_property_id = mo.uclass_property_id
          and up.uclass_property_type = 'ConsoleACL'
        )
    };

	unless ( $aref = $dbh->selectcol_arrayref($q) ) {
		$self->Error("GetNconsoleConfUclasses: $DBI::errstr");
		return undef;
	}

	if (@$aref) { @mc = @$aref; $mcl = join( ', ', @$aref ); }
	else        { @mc = @$aref; $mcl = '0'; }

	## From all children of mlasses in $mcl find those that have a parent

	$q = qq{
        select distinct connect_by_root device_collection_id
        from device_collection_hier
        connect by prior parent_device_collection_id = device_collection_id
        start with parent_device_collection_id in ($mcl)
    };

	unless ( $aref = $dbh->selectcol_arrayref($q) ) {
		$self->Error("GetNconsoleConfUclasses: $DBI::errstr");
		return undef;
	}

	if (@$aref) { $mcle = join( ', ', @$aref ); }
	else        { $mcle = '0'; }

	## The following query returns the inheritance tree for MCLASSes
	## for which console privileges are present. The problem is that
	## we must expand MCLASSes in the nconsole.conf file in the
	## inheritance order, which is what this query returns.

	$q = qq{
        select parent_device_collection_id as parent_id,
               device_collection_id child_id, level as my_level
        from device_collection_hier
        where parent_device_collection_id in ($mcl)
        and device_collection_id in ($mcl)
        connect by prior device_collection_id = parent_device_collection_id
        start with parent_device_collection_id in ($mcl)
        and parent_device_collection_id not in ($mcle)
    };

	unless ( $aref = $dbh->selectall_arrayref($q) ) {
		$self->Error("GetNconsoleConfUclasses: $DBI::errstr");
		return undef;
	}

	## the following query returns the list of uclasses and their respective
	## console permissions for an mclass

	$q = qq{
        select distinct ucname, ucid, ucprop from (
          select u.name ucname, u.uclass_id ucid, up.property_value ucprop
          from uclass u,
               uclass_property up, mclass_property_override mo
          where up.uclass_property_id = mo.uclass_property_id
          and u.uclass_id = up.uclass_id and mo.device_collection_id = ?
          union
          select u.name ucname, u.uclass_id ucid, up.property_value ucprop
          from uclass u, 
               uclass_property up, sudo_uclass_device_collection su
          where up.uclass_id = su.uclass_id
          and su.sudo_alias_name = 'ALL' and su.run_as_uclass_id is NULL
          and up.uclass_property_type = 'ConsoleACL'
          and up.uclass_property_name = 'SudoGrantsConsole'
          and u.uclass_id = up.uclass_id and su.device_collection_id = ?
        )
    };

	unless ( $sth1 = $dbh->prepare($q) ) {
		$self->Error("GetNconsoleConfMclasses: $DBI::errstr");
		return undef;
	}

	## The following query is based on a similar query in stab2tcp. It
	## combines two things. It expands the mclass ? into the list of
	## devices including devices in inherited mclasses, and from those
	## devices it finds those that have a serial port connected to a
	## terminal server. The query returns the device name and the name
	## of the port. We need this because we need to enable access to
	## secondary ports on devices with more than one serial console.

	$q = qq{
        select d1.device_name, p1.port_name
        from layer1_connection l1c, physical_port p1, physical_port p2,
             device_function f2, device d1
        where l1c.physical_port1_id = p1.physical_port_id
        and   l1c.physical_port2_id = p2.physical_port_id
        and   p1.device_id = d1.device_id
        and   p2.device_id = f2.device_id
        and   p1.port_type = 'serial' and p2.port_type = 'serial'
        and   f2.device_function_type = 'consolesrv'
        and   (p2.port_name like 'ttyS%' or p2.port_name like 'line%')
        and   d1.device_id in (
          select m.device_id
          from device_collection c, device_collection_member m
          where c.device_collection_id = m.device_collection_id
          and (c.device_collection_id = ? or c.device_collection_id in (
              select device_collection_id child_id from device_collection_hier
              connect by
              prior device_collection_id = parent_device_collection_id
              start with parent_device_collection_id = ?
          ))
        )
        union
        select d1.device_name, p1.port_name
        from layer1_connection l1c, physical_port p1, physical_port p2,
             device_function f2, device d1
        where l1c.physical_port2_id = p1.physical_port_id
        and   l1c.physical_port1_id = p2.physical_port_id
        and   p1.device_id = d1.device_id
        and   p2.device_id = f2.device_id
        and   p1.port_type = 'serial' and p2.port_type = 'serial'
        and   f2.device_function_type = 'consolesrv'
        and   (p2.port_name like 'ttyS%' or p2.port_name like 'line%')
        and   d1.device_id in (
          select m.device_id
          from device_collection c, device_collection_member m
          where c.device_collection_id = m.device_collection_id
          and (c.device_collection_id = ? or c.device_collection_id in (
              select device_collection_id child_id from device_collection_hier
              connect by
              prior device_collection_id = parent_device_collection_id
              start with parent_device_collection_id = ?
          ))
        )
    };

	unless ( $sth2 = $dbh->prepare($q) ) {
		$self->Error("GetNconsoleConfMclasses: $DBI::errstr");
		return undef;
	}

	$text = '';

	## walk the mclass inheritance tree top-down

	foreach $row (@$aref) {
		my ( $parent_id, $child_id, $level ) = @$row;
		my ( $uclass, $uclass_id, $perms, @devices, $device, $mclass );

		## if this is another branch of the tree, empty the accumulated perms

		if ( $level < $lastlev ) {
			%permission = ();
		}

		$lastlev = $level;

		## get all devices in the $parent_id mclass
		## setting $mclass is as a side-effect

		unless (
			$sth2->execute(
				$parent_id, $parent_id,
				$parent_id, $parent_id
			)
		  )
		{
			$self->Error("GetNconsoleConfMclasses: $DBI::errstr");
			return undef;
		}

		@devices = _device_port_names( $sth2->fetchall_arrayref );
		$sth2->finish;
		$mclass = $self->findMclassNameFromId($parent_id);

		## get the uclass names, uclass ids, and console permissions
		## for the $parent_id mclass

		unless ( $sth1->execute( $parent_id, $parent_id ) ) {
			$self->Error("GetNconsoleConfMclasses: $DBI::errstr");
			return undef;
		}

		## create an entry in nconsole.conf for each uclass for which console
		## permissions are defined for the parent mclass

		while ( ( $uclass, $uclass_id, $perms ) =
			$sth1->fetchrow_array )
		{
			$permission{$parent_id}{$uclass_id} |= $perms;

			if (       @devices
				&& !$mc_out{$parent_id}
				&& $enabled_uclass{$uclass_id} )
			{
				$text .=
				    "mclass: "
				  . _um_name( $parent_id, $mclass ) . " {\n"
				  . "\tmachines: "
				  . join( ' ', @devices ) . "\n"
				  . "\tpermissions: "
				  . $perm2text{ $permission{$parent_id}
					  {$uclass_id} }
				  . "\n"
				  . "\tusers: \%"
				  . _um_name( $uclass_id, $uclass )
				  . "\n}\n\n";
			}
		}

		$mc_out{$parent_id} = 1;    ## mark the mclass as processed
		$sth1->finish;

		## get all devices in the $child_id mclass

		unless (
			$sth2->execute(
				$child_id, $child_id, $child_id, $child_id
			)
		  )
		{
			$self->Error("GetNconsoleConfMclasses: $DBI::errstr");
			return undef;
		}

		@devices = _device_port_names( $sth2->fetchall_arrayref );
		$sth2->finish;
		$mclass = $self->findMclassNameFromId($child_id);

		## get the uclass names, uclass ids, and console permissions
		## for the $child_id mclass

		unless ( $sth1->execute( $child_id, $child_id ) ) {
			$self->Error("GetNconsoleConfMclasses: $DBI::errstr");
			return undef;
		}

		## create an entry in nconsole.conf for each uclass for which console
		## permissions are defined for the child mclass

		while ( ( $uclass, $uclass_id, $perms ) =
			$sth1->fetchrow_array )
		{
			$permission{$child_id}{$uclass_id} |=
			  $permission{$parent_id}{$uclass_id} | $perms;

			if (       @devices
				&& !$mc_out{$child_id}
				&& $enabled_uclass{$uclass_id} )
			{
				$text .=
				    "mclass: "
				  . _um_name( $child_id, $mclass ) . " {\n"
				  . "\tmachines: "
				  . join( ' ', @devices ) . "\n"
				  . "\tpermissions: "
				  . $perm2text{ $permission{$child_id}
					  {$uclass_id} }
				  . "\n"
				  . "\tusers: \%"
				  . _um_name( $uclass_id, $uclass )
				  . "\n}\n\n";
			}
		}

		$sth1->finish;
		$mc_out{$child_id} = 1;
	}

	## ok, we have processed all mclasses that are related, now we
	## need to process mclasses with no relationships

	foreach my $mclass_id (@mc) {
		my ( $uclass, $uclass_id, $perms, @devices, $device, $mclass );

		## get all devices in the $mclass_id mclass

		unless (
			$sth2->execute(
				$mclass_id, $mclass_id,
				$mclass_id, $mclass_id
			)
		  )
		{
			$self->Error("GetNconsoleConfMclasses: $DBI::errstr");
			return undef;
		}

		@devices = _device_port_names( $sth2->fetchall_arrayref );
		$sth2->finish;
		$mclass = $self->findMclassNameFromId($mclass_id);

		## get the uclass names, uclass ids, and console permissions
		## for the $mclass_id mclass

		unless ( $sth1->execute( $mclass_id, $mclass_id ) ) {
			$self->Error("GetNconsoleConfMclasses: $DBI::errstr");
			return undef;
		}

		## create an entry in nconsole.conf for each uclass for which console
		## permissions are defined for the mclass

		while ( ( $uclass, $uclass_id, $perms ) =
			$sth1->fetchrow_array )
		{
			$permission{$mclass_id}{$uclass_id} |= $perms;

			if (       @devices
				&& !$mc_out{$mclass_id}
				&& $enabled_uclass{$uclass_id} )
			{
				$text .=
				    "mclass: "
				  . _um_name( $mclass_id, $mclass ) . " {\n"
				  . "\tmachines: "
				  . join( ' ', @devices ) . "\n"
				  . "\tpermissions: "
				  . $perm2text{ $permission{$mclass_id}
					  {$uclass_id} }
				  . "\n"
				  . "\tusers: \%"
				  . _um_name( $uclass_id, $uclass )
				  . "\n}\n\n";
			}
		}
	}

	return $text;
}

###############################################################################

=pod

=item GetNconsoleConf

Returns the content of the nconsole.conf file or undef on error.

=cut

###############################################################################

sub GetNconsoleConf {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $q, $aref, $text, $rv );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error(
			"WriteNconsoleConf: Invalid class reference passed");
		return undef;
	}

	$text =
"# Do not edit this file, it is generated automatically. All changes\n"
	  . "# made by hand will be lost.\n"
	  . "# Generated on "
	  . scalar( gmtime(time) )
	  . " by $Script\n"
	  . "# ConsoleACL.pm "
	  . '$Revision$' . "\n\n";

	$q = qq{
        select u.uclass_id, u.name from uclass u, uclass_property p
        where p.uclass_id = u.uclass_id
        and uclass_property_type = 'ConsoleACL'
        and uclass_property_name = 'AllMclasses'
        and u.uclass_id in (
            select uclass_id from v_uclass_user_expanded e, system_user su
            where su.system_user_id = e.system_user_id
            and su.system_user_status = 'enabled'
        )
    };

	unless ( $aref = $dbh->selectall_arrayref($q) ) {
		$self->Error("GetNconsoleConf: $DBI::errstr");
		return undef;
	}

	if (@$aref) {
		$text .=
		    'users: %'
		  . join( ' %', map { _um_name( $_->[0], $_->[1] ) } @$aref )
		  . "\n";
		$text .= "permissions: rwbx\n\n";
	}

	unless ( defined( $rv = $self->GetNconsoleConfUclasses ) ) {
		return undef;
	}

	$text .= $rv;

	unless ( defined( $rv = $self->GetNconsoleConfMclasses ) ) {
		return undef;
	}

	$text .= $rv;

	return $text;
}

###############################################################################

=pod

=item WriteNconsoleConf(-filename => $filename)

Write the console ACL file nconsole.conf to $filename.

=cut

###############################################################################

sub WriteNconsoleConf {
	my $self  = shift;
	my $opt   = &_options(@_);
	my $tmpfn = $opt->{filename} . ".$$";
	my ( $text, $fh );

	return undef unless ( $text = $self->GetNconsoleConf(@_) );

	## write the content to a temporary file

	unless ( $fh = IO::File->new(">$tmpfn") ) {
		$self->Error("WriteNconsoleConf: can't open $tmpfn");
		return undef;
	}

	print $fh $text;
	$fh->close;

	## rename the temporary file to $opt->{filename}

	unlink( $opt->{filename} );

	unless ( rename( $tmpfn, $opt->{filename} ) ) {
		$self->Error("WriteNconsoleConf: rename failed: $!");
		unlink($tmpfn);
		return undef;
	}

	return 1;
}

1;

=pod

=back

=head1 BUGS

If the number of MCLASSes with assigned console privileges ever gets
above 1000, the method GetNconsoleConfMclasses will stop working
because the MCLASSes are enumerated in the IN (...) part of an SQL
query. I certainly hope this will never be the case because the total
number of all mclasses today is around 500, and there is a strong
desire to bring this number much lower, not higher.

=head1 AUTHOR

Bernard Jech

=cut

