#!/usr/bin/env perl
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

=head1 NAME

 mkpasswdfiles - extract files for pwfetch from JazzHands

=head1 SYNOPSIS

 mkpasswdfiles [-v] [-o output_dir] [mclass mclass ...]

=head1 DESCRIPTION

mkpasswdfiles reads user account and server information from JazzHands,
and creates passwd, group, sudoers, k5login-root, dbal, and wwwgroup
files for MCLASSes specified on the command line. If no MCLASSes are
specified, files for all MCLASSes are created. See the DATABASE
PERMISSIONS section below for a list of JazzHands tables and views
mkpasswdfiles reads from. The files created by mkpasswdfiles are
intended to be downloaded by pwfetch.

=head1 OPTIONS

=over 4

=item -v

Turn on more verbose output.

=item -o output_dir

Write the output files to the directory output_dir. The default is
/prod/pwgen/out.

=back

=head1 DATABASE PERMISSIONS

 GRANT SELECT ON APPAAL
 GRANT SELECT ON APPAAL_INSTANCE
 GRANT SELECT ON APPAAL_INSTANCE_DEVICE_COLL
 GRANT SELECT ON APPAAL_INSTANCE_PROPERTY
 GRANT SELECT ON DEVICE
 GRANT SELECT ON DEVICE_COLLECTION
 GRANT SELECT ON DEVICE_COLLECTION_HIER
 GRANT SELECT ON device_collection_device
 GRANT SELECT ON KERBEROS_REALM
 GRANT SELECT ON KLOGIN
 GRANT SELECT ON KLOGIN_MCLASS
 GRANT SELECT ON MCLASS_GROUP
 GRANT SELECT ON MCLASS_UNIX_PROP
 GRANT SELECT ON SUDO_ALIAS
 GRANT SELECT ON SUDO_DEFAULT
 GRANT SELECT ON SUDO_UCLASS_DEVICE_COLLECTION
 GRANT SELECT ON SYSTEM_PASSWORD
 GRANT SELECT ON SYSTEM_USER
 GRANT SELECT ON UCLASS
 GRANT SELECT ON PROPERTY
 GRANT SELECT ON UNIX_GROUP
 GRANT SELECT ON UNIX_GROUP_PROPERTY
 GRANT SELECT ON UNIX_GROUP_UCLASS
 GRANT SELECT ON USER_UNIX_INFO
 GRANT SELECT ON V_DEVICE_COLL_HIER_DETAIL
 GRANT SELECT ON V_DEVICE_COL_UCLASS_EXPANDED
 GRANT SELECT ON V_DEV_COL_USER_PROP_EXPANDED
 GRANT SELECT ON V_UCLASS_USER_EXPANDED

=head1 AUTHOR

=cut

###############################################################################

BEGIN { push(@INC, "/Users/kovert"); }

use strict;
use warnings;
use JazzHands::DBI;
use File::Temp qw(tempdir);
use IO::File;
use File::Copy;
use File::Path;
use Getopt::Long;
use FindBin qw($Script);
use JazzHands::Common qw(:all);

my $o_output_dir = "/prod/pwgen/out";
my $o_verbose;

my ( $q_mclass_ids, $dbh, $g_prop, $passwd_grp, %mclass_file );
my (
	%sudo_defaults,  %sudo_cmnd_aliases, %sudo_uclasses,
	%sudo_user_spec, %sudo_expand_uclass
);

main();
exit(0);

###############################################################################
#
# usage: @pwdline = get_passwd_line($mp, $up, $gp, $u);
#
# Applies various properties and overrides to a raw passwd file line
# record $u. The record is pulled from tables and views SYSTEM_USER,
# USER_UNIX_INFO, UNIX_GROUP, V_DEVICE_COL_UCLASS_EXPANDED,
# DEVICE_COLLECTION, and SYSTEM_PASSWORD with a minimal preprocessing.
# The function returns an array of 8 elements. The first 7 elements
# can be written directly to the passwd file, the 8th element is the
# name of the primary Unix group of the user.
#
# $u is a reference to a hash with the following elements:
#
#   DEVICE_COLLECTION_ID
#   SYSTEM_USER_ID
#   MCLASS
#   LOGIN
#   MD5_PASSWORD,
#   DES_PASSWORD
#   UNIX_UID
#   GROUP_NAME
#   UNIX_GID
#   FIRST_NAME
#   MIDDLE_NAME
#   LAST_NAME
#   DEFAULT_HOME
#   SHELL
#
# $mp is a reference to a hash with the following elements. They are
# pulled from the MCLASS_UNIX_PROP table.
#
#   MCLASS_UNIX_PW_TYPE
#   HOME_PLACE
#   MCLASS_UNIX_HOME_TYPE
#
# $up is a reference to a hash with the following elements. They are
# pulled from the PROPERTY table.
#
#   ForceCrypt
#   ForceUserUID
#   ForceUserGroup
#   ForceHome
#   ForceShell
#   ForceStdShell
#
# $gp is a reference to a hash whose first level key is a Unix group
# name, the second level key is FORCE_GID and the value is the GID for
# this group. This hash reflects the content of the
# UNIX_GROUP_PROPERTY table.
#
# Any and all properties described above can be missing, and $mp, $up,
# and $gp can be completely undefined as appropriate for the MCLASS in
# question.
#
###############################################################################

sub get_passwd_line($$$$) {
	my ( $mp, $up, $gp, $u ) = @_;
	my ( $login, $crypt, $uid, $gname, $gid, $full_name, $home, $shell );

	## Default values

	$login = $u->{_dbx('LOGIN')};
	$crypt = '*';
	$uid   = $u->{_dbx('UNIX_UID')};
	$gid   = $u->{_dbx('UNIX_GID')};
	$home  = $u->{_dbx('DEFAULT_HOME')};
	$shell = $u->{_dbx('SHELL')};

	## Determine the password

	if ( defined( $up->{_dbx('ForceCrypt')} ) ) {
		$crypt = $up->{ForceCrypt};
	}

	else {
		if ( defined( $mp->{_dbx('MCLASS_UNIX_PW_TYPE')} ) ) {
			if (       $login eq 'root'
				|| $mp->{_dbx('MCLASS_UNIX_PW_TYPE')} eq 'des' )
			{
				$crypt = $u->{_dbx('DES_PASSWORD')} || '*';
			}

			elsif ( $mp->{_dbx('MCLASS_UNIX_PW_TYPE')} eq 'md5' ) {
				$crypt = $u->{_dbx('MD5_PASSWORD')} || '*';
			}
		}
	}

	## Determine UID

	$uid = defined( $up->{ForceUserUID} ) ? $up->{ForceUserUID} : $uid;

	## Determine GID

	if ( defined( $up->{ForceUserGroup} ) ) {
		$gname = $up->{ForceUserGroup}{_dbx('GROUP_NAME')};
		$gid =
		  defined( $gp->{$gname} )
		  ? $gp->{$gname}{_dbx('FORCE_GID')}
		  : $up->{ForceUserGroup}{_dbx('UNIX_GID')};
	}

	else {
		$gname = $u->{_dbx('GROUP_NAME')};
		$gid =
		  defined( $gp->{$gname} ) ? $gp->{$gname}{FORCE_GID} : $gid;
	}

	## Determine full name

	$full_name = join(
		' ',
		grep( defined($_),
			$u->{_dbx('FIRST_NAME')}, $u->{_dbx('MIDDLE_NAME')},
			$u->{_dbx('LAST_NAME')} )
	);

	## Determine home directory

	my $hp = defined( $mp->{_dbx('HOME_PLACE')} ) ? $mp->{_dbx('HOME_PLACE')} : '/var/home';
	$home = "$hp/$1" if ( $home =~ m!/([^/]+)$! );

	if ( ( $mp->{_dbx('MCLASS_UNIX_HOME_TYPE')} || '' ) eq 'generic' ) {
		$home = "$hp/generic";
	}

	if ( defined( $up->{ForceHome} ) ) {
		$home = $up->{ForceHome};
		$home .= $login if ( $up->{ForceHome} =~ m!/$! );
	}

	## Determine the login shell

	if ( defined( $up->{ForceShell} ) && !defined( $up->{ForceStdShell} ) )
	{
		$shell = $up->{ForceShell};
	}

	return ( $login, $crypt, $uid, $gid, $full_name, $home, $shell,
		$gname );
}

###############################################################################
#
# usage: $u_prop = get_uclass_properties();
#
# Retrieves PROPERTYs for all MCLASSes and all enabled
# users. Uses the V_DEV_COL_USER_PROP_EXPANDED view to expand UCLASSes
# all the way down to individual users, take inheritance into account,
# and resolve conflicting properties. Returns a reference to a hash.
# The first level key is DEVICE_COLLECTION_ID, the second level key is
# SYSTEM_USER_ID, the third level key is PROPERTY_NAME, and the
# value is PROPERTY_VALUE. If PROPERTY_NAME is ForceUserGroup,
# there are two fourth level keys GROUP_NAME and UNIX_GID, and the
# values are the group name and the GID of the group.
#
###############################################################################

sub get_uclass_properties() {
	my ( $q, $sth, $mu_prop, @r );

	# XXX - need to port this.  Its not clear that a group name 
	return  undef;

	$q = q{
        select device_collection_id, system_user_id,
               property_name, property_value,
               case when property_name = 'ForceUserGroup'
                    then to_char(unix_gid) 
                    else null end unix_gid
        from v_dev_col_user_prop_expanded pe
        left join unix_group ug on pe.property_value = ug.group_name
        where system_user_status in ('enabled', 'onleave-enable')
        and property_type = 'UnixPasswdFileValue'
        and device_collection_id is not null
    };

	if ($q_mclass_ids) {
		$q .= "and device_collection_id in $q_mclass_ids";
	}

	$sth = $dbh->prepare($q);
	$sth->execute;

	## If there are lines with duplicate device_collection_id,
    ## system_user_id, property_name, the first line is what counts.

	while ( @r = $sth->fetchrow_array ) {
		my ( $dcid, $suid, $upn, $pv, $gid ) = @r;

		unless ( exists $mu_prop->{$dcid}{$suid}{$upn} ) {
			if ( $upn eq 'ForceUserGroup' ) {
				$mu_prop->{$dcid}{$suid}{$upn} = {
					GROUP_NAME => $pv,
					UNIX_GID   => $gid
				};
			}

			else {
				$mu_prop->{$dcid}{$suid}{$upn} = $pv;
			}
		}
	}

	return $mu_prop;
}

###############################################################################
#
# usage: $m_prop = get_mclass_properties();
#
# Retrieves MCLASS_UNIX_PROPs for all MCLASSes properly adjusting for
# MCLASS inheritance. Merges different properties from different
# levels in the inheritance together to mimic the behavior of the old
# mkpasswdfiles. For example, if MCLASS abc is the parent of the
# MCLASS def, and MCLASS_UNIX_HOME_TYPE is defined for abc,
# MCLASS_UNIX_PW_TYPE is NULL for abc, MCLASS_UNIX_HOME_TYPE is NULL
# for def, and MCLASS_UNIX_PW_TYPE is defined for def, both
# MCLASS_UNIX_HOME_TYPE and MCLASS_UNIX_PW_TYPE will be defined for
# the MCLASS def. Again, this is just to make sure the behavior is the
# same as that of the old mkpasswdfiles even if it is incorrect. The
# function returns a reference to a hash. The first level key is the
# DEVICE_COLLECTION_ID, the second level key is one of
# DEVICE_COLLECTION_ID, MCLASS_UNIX_HOME_TYPE, MCLASS_UNIX_PW_TYPE,
# HOME_PLACE, and the value is the value of the corresponding
# attribute.
#
###############################################################################

sub get_mclass_properties {
	my ( $q, $sth, $m_prop, @r );

	$q = q{
	select	d.device_collection_id,
		p.property_name,
		p.property_type,
		p.property_value
	  from	v_property p
		join v_device_coll_hier_detail d
			on p.device_collection_id = 
				d.parent_device_collection_id
	 where p.property_type = 'MclassUnixProp'
    	};

	if ($q_mclass_ids) {
		$q .= "where d.device_collection_id in $q_mclass_ids";
	}

	$q .=
	  " order by device_collection_level, d.parent_device_collection_id";
	$sth = $dbh->prepare($q);
	$sth->execute;

	## Find the first defined property in the inheritance tree, and
	## store that.

	while ( @r = $sth->fetchrow_array ) {
		my ( $dcid, $propn, $propt, $propv ) = @r;

		$m_prop->{$dcid}{DEVICE_COLLECTION_ID} = $dcid
		  unless ( defined $m_prop->{$dcid}{DEVICE_COLLECTION_ID} );

		if($propn eq 'UnixHomeType' && $propt eq 'MclassUnixProp') {
			$m_prop->{$dcid}{MCLASS_UNIX_HOME_TYPE} = $propv
		  	unless ( defined $m_prop->{$dcid}{MCLASS_UNIX_HOME_TYPE} );
		}

		if($propn eq 'UnixPwType' && $propt eq 'MclassUnixProp') {
		    $m_prop->{$dcid}{MCLASS_UNIX_PW_TYPE} = $propv
		      unless ( defined $m_prop->{$dcid}{MCLASS_UNIX_PW_TYPE} );
		}

		if($propn eq 'HomePlace' && $propt eq 'MclassUnixProp') {
		    $m_prop->{$dcid}{HOME_PLACE} = $propv
		      unless ( defined $m_prop->{$dcid}{HOME_PLACE} );
		}

		# XXX consider logging when unidentified properties have showed up?
		# probably need to keep track of ones we don't pay attention to here
		# such as UnixLogin and UnixGroupAssign
	}

	return $m_prop;
}

###############################################################################
#
# usage: $g_prop = get_group_properties();
#
# Retrieves UNIX_GROUP_PROPERTY values for all MCLASSes and all
# UNIX_GROUPs. Takes inheritance into account, and resolves conflicts
# between properties at different levels in the inheritance
# tree. Returns a reference to a hash. The first level key is the
# DEVICE_COLLECTION_ID, the second level key is the group name, the
# third level key is one of DEVICE_COLLECTION_ID, GROUP_NAME, or
# FORCE_GID, and the value is the value of the corresponding
# attribute.
#
###############################################################################

sub get_group_properties() {
	my ( $q, $sth, $g_prop, $r );

	$q = q{
        select device_collection_id, 
		ac.account_collection_name as group_name, force_gid
        from unix_group g
        join (
          select row_number()
            over (partition by hd.device_collection_id, gp.account_collection_id
                  order by device_collection_level,
                        hd.parent_device_collection_id) r,
            hd.device_collection_id, account_collection_id, 
	    property_value AS force_gid
          from v_device_coll_hier_detail hd
          join v_property gp
          on hd.parent_device_collection_id = gp.device_collection_id
          where gp.property_name = 'ForceGroupGID'
	  	and gp.property_type = 'UnixGroupFileProperty') y
	join account_collection ac
		using (account_collection_id)
        on g.account_collection_id = y.account_collection_id
        where r = 1
    };

	if ($q_mclass_ids) {
		$q .= "and device_collection_id in $q_mclass_ids";
	}

	$sth = $dbh->prepare($q);
	$sth->execute;

	while ( $r = $sth->fetchrow_hashref ) {
		$g_prop->{ $r->{_dbx('DEVICE_COLLECTION_ID')} }{ $r->{_dbx('GROUP_NAME')} } =
		  $r;
	}

	return $g_prop;
}

###############################################################################
#
# usage: $fh = new_mclass_file($dir, $mclass, $fh, $filename);
#
# Closes the filehandle $fh if $fh is defined. Creates the directory
# "$dir/$mclass" if it does not exist. Creates a new file in this
# directory, and returns the filehandle. Records the created file in
# %mclass_file so that we know about all the files we created.
#
###############################################################################

sub new_mclass_file($$$$) {
	my ( $dir, $mclass, $fh, $filename ) = @_;
	my $mdir = "$dir/$mclass";

	$fh->close if ( defined $fh );
	print "writing $mdir/$filename\n" if ($o_verbose);

	if ( !-d $mdir ) {
		mkdir( $mdir, 0750 )
		  or die "can't create directory $mdir: $!\n";
	}

	$fh = IO::File->new( "$mdir/$filename", "w", 0640 )
	  or die "can't create file $mdir/$filename: $!\n";

	$mclass_file{$mclass}{$filename}++;
	return $fh;
}

###############################################################################

sub _by_uid($$) {
	my ( $a, $b ) = @_;

	return $a->[2] <=> $b->[2];
}

###############################################################################
#
# usage: generate_passwd_files($dir);
#
# Creates passwd files for all specified MCLASSes in the directory $dir.
#
###############################################################################

sub generate_passwd_files($) {
	my $dir = shift;
	my ( $q, $sth, $m_prop, $u_prop, $r, $last_dcid, $fh, @pwdlines );

	$u_prop = get_uclass_properties();
	$m_prop = get_mclass_properties();

	## The following query returns the passwd file lines for all MCLASSes
	## but without the overrides. Overrides are applied later.

	my $dys = "90";	# XXX - oracle, need to be smarter
	$dys = "interval '90 days'";

	my $now = "sysdate";	# XXX - oracle, need to be smarter
	$now = "current_timestamp";

	$q = qq{
        select distinct c.device_collection_id, a.account_id, 
			   c.device_collection_name mclass,
               login,
               case when login = 'root'
                      or coalesce(p1.expire_time, p1.change_time + $dys) > $now
                    then p1.password else null end md5_password,
               case when login = 'root'
                      or coalesce(p2.expire_time, p2.change_time + $dys) > $now
                    then p2.password else null end des_password,
               unix_uid, ac.account_collection_name as group_name, 
			   unix_gid, first_name, 
               case when length(middle_name) = 1
                    then middle_name || '.' else middle_name end middle_name,
               last_name, default_home, shell
        from account a
			join person p
				on (p.person_id = a.person_id)
             join account_unix_info ui
                on (a.account_id = ui.account_id)
             join unix_group ug
                on (ui.unix_group_acct_collection_id 
					= ug.account_collection_id)
             join v_device_col_acct_col_expanded cce
                on (a.account_id = cce.account_id)
             join device_collection c
                on (cce.device_collection_id = c.device_collection_id)
             join account_collection ac on 
		(cce.account_collection_id = ac.account_collection_id)
             left join account_password p1
                on (a.account_id = p1.account_id
                    and p1.password_type = 'md5')
             left join account_password p2
                on (a.account_id = p2.account_id
                    and p2.password_type = 'des')
        where account_status in ('enabled', 'onleave-enable')
        and c.device_collection_type = 'mclass'
        and ac.account_collection_type in ('systems', 'per-user')
    };

	if ($q_mclass_ids) {
		$q .= "and cce.device_collection_id in $q_mclass_ids";
	}

	$q .= " order by device_collection_id, unix_uid";

	$sth = $dbh->prepare($q);
	$sth->execute;

	## Iterate over all MCLASSes and UIDs

	while ( $r = $sth->fetchrow_hashref ) {
		my $dcid = $r->{_dbx('DEVICE_COLLECTION_ID')};
		my $suid = $r->{_dbx('ACCOUNT_ID')};
		my ( @pwd, $login, $gid, $gname );

		## If we switched to a new MCLASS, write the passwd file
		## and empty @pwdlines

		if ( defined($last_dcid) ) {
			if ( $last_dcid != $dcid ) {
				foreach my $p ( sort _by_uid @pwdlines ) {
					if (grep { !defined($_) } @$p) {
						warn "MCLASS_ID $last_dcid: malformed passwd line: " .
							join(':',map { defined($_) ? $_ : '' } @$p) . "\n";
					} else {
						print $fh join( ':', @$p ), "\n";
					}
				}
				$fh =
				  new_mclass_file( $dir, $r->{_dbx('MCLASS')}, $fh,
					'passwd' );
				$last_dcid = $dcid;
				undef(@pwdlines);
			}
		}

		else {
			$fh =
			  new_mclass_file( $dir, $r->{_dbx('MCLASS')}, $fh, 'passwd' );
			$last_dcid = $dcid;
		}

		## Apply all overrides to the passwd file line $r

		@pwd =
		  get_passwd_line( $m_prop->{$dcid}, $u_prop->{$dcid}{$suid},
			$g_prop->{$dcid}, $r );

		## We need to store the mapping from DEVICE_COLLECTION_ID and
		## LOGIN to GROUP_NAME and GID. We will need it later to
		## generate the group files. We keep the information in the
		## global variable $passwd_grp which is a hash reference.

		$login                       = $pwd[0];
		$gid                         = $pwd[3];
		$gname                       = $pwd[7];
		$passwd_grp->{$dcid}{$login} = {
			GROUP_NAME => $gname,
			GID        => $gid
		};

		## Accumulate all passwd file lines in @pwdlines.
		## $pwd[7] is the group name. We don't need it anymore.

		push( @pwdlines, [ @pwd[ 0 .. 6 ] ] );
	}

	## Let's not forget to write the passwd file for the last MCLASS

	foreach my $p ( sort _by_uid @pwdlines ) {
		if (grep { !defined($_) } @$p) {
			warn "MCLASS_ID $last_dcid: malformed passwd line: " .
				join(':', map { defined($_) ? $_ : '' } @$p) . "\n";
		} else {
			print $fh join( ':', @$p ), "\n";
		}
	}

	$fh->close if ( defined $fh );
}

###############################################################################
#
# usage: generate_group_files($dir);
#
# Creates group files for all specified MCLASSes in the directory
# $dir. This is the most difficult and convoluted of the generate_xxx
# functions. There are few reasons why it's so difficult. We need to
# combine groups that are directly assigned to the MCLASS properly
# taking account of inheritance, and we need to combine that with the
# primary groups for all users who are on the same MCLASS. Groups can
# be forced to have a different GID from the one in UNIX_GROUP on
# certain MCLASSes, and users can be forced to have different primary
# groups on different MCLASSes, and the ForceUserGroup specifies the
# *name* of the group, not the UNIX_GROUP_ID, which makes it
# interesting.  Users can also be added to a Unix group only on
# certain MCLASSes (using the DEVICE_COLLECTION_ID column in
# UNIX_GROUP_UCLASS). All in all, it's a pretty convoluted mess, and I
# feel sorry for anybody who ever needs to touch the code in here.
#
###############################################################################

sub generate_group_files($) {
	my $dir = shift;
	my (
		$q,         $sth,   $r,      $fh,
		$mclass,    %group, %member, %m_member,
		%gn_member, %gn_m_member
	);

	## The following query determines which unix groups are assigned
	## to which MCLASSes taking inheritance 
	## into account. The query also determines the group password and
	## the default GID which the group would have without any overrides.

	$q = q{
        select distinct dchd2.device_collection_id, 
			   c.device_collection_name mclass, 
               ug.account_collection_id, 
			   ugu.account_collection_name as group_name, ug.unix_gid, 
               ug.group_password	-- XXX needs to be a property
        from v_device_coll_hier_detail dchd2
        join v_property mg2
        	on mg2.device_collection_id = dchd2.parent_device_collection_id
        join device_collection c
        	on dchd2.device_collection_id = c.device_collection_id
        join unix_group ug on 
			mg2.property_value_account_coll_id = ug.account_collection_id
		join account_collection ugu on 
			ugu.account_collection_id = ug.account_collection_id 
        where c.device_collection_type = 'mclass'
		and mg2.property_name = 'MclassUnixProp'
		and mg2.property_name = 'UnixGroupAssign'
    };

	if ($q_mclass_ids) {
		$q .= "and dchd2.device_collection_id in $q_mclass_ids";
	}

	$sth = $dbh->prepare($q);
	$sth->execute;

	## We store the results in the hash %group which has the
	## DEVICE_COLLECTION_ID and UNIX_GROUP_ID as it's keys.

	while ( $r = $sth->fetchrow_hashref ) {
		my $dcid = $r->{_dbx('DEVICE_COLLECTION_ID')};
		my $ugid = $r->{_dbx('UNIX_GROUP_ID')};

		$group{$dcid}{$ugid} = $r;
	}

	## This is an auxiliary query which maps MCLASS IDs to MCLASS names

	$q = q{
        select device_collection_id, device_collection_name mclass 
		from device_collection
        where device_collection_type = 'mclass'
    };

	$mclass = $dbh->selectall_hashref( $q, _dbx('DEVICE_COLLECTION_ID') );

	## The following query determines Unix group membership. It maps
	## Unix groups to logins that belong to each particular group for
	## entries in UNIX_GROUP_UCLASS that have the DEVICE_COLLECTION_ID
	## attribute set.

	$q = q{
        select c.device_collection_id, 
			   ug.account_collection_id, gac.account_collection_name, a.login
        from device_collection c
        join v_property ugu
        	on c.device_collection_id = ugu.device_collection_id
        join unix_group ug on 
			ugu.account_collection_id = ug.account_collection_id
		join account_collection gac on
			ug.account_collection_id = gac.account_collection_id
        join v_acct_coll_acct_expanded vuue 
			on ugu.property_value_account_coll_id = vuue.account_collection_id
        join account a on vuue.account_id = a.account_id
        where a.account_status in ('enabled', 'onleave-enable')
		and ugu.property_name = 'UnixGroupAssign'
		and ugu.property_type = 'MclassUnixProp'
    };

	if ($q_mclass_ids) {
		$q .= "and c.device_collection_id in $q_mclass_ids";
	}

	$sth = $dbh->prepare($q);
	$sth->execute;

	## We store the results in two hashes, $m_member and $gn_m_member.
	## The first level key is the DEVICE_COLLECTION_ID for both. The
	## second level key of $m_member is the UNIX_GROUP_ID. The second
	## level key of $gn_m_member is the group name. The value for both
	## hashes is a reference to the list of the group members.

	while ( $r = $sth->fetchrow_hashref ) {
		my $dcid  = $r->{_dbx('DEVICE_COLLECTION_ID')};
		my $ugid  = $r->{_dbx('ACCOUNT_COLLECTION_ID')};
		my $gname = $r->{_dbx('GROUP_NAME')};

		push( @{ $m_member{$dcid}{$ugid} },     $r->{_dbx('LOGIN')} );
		push( @{ $gn_m_member{$dcid}{$gname} }, $r->{_dbx('LOGIN')} );
	}

	## The following query determines Unix group membership. It maps
	## Unix groups to logins that belong to each particular group for
	## entries in V_PROPERTY (device_collection to uclass mapping)
	## that have DEVICE_COLLECTION_ID NULL. I would have loved to combine 
	## this query and the previous
	## one into one query (using the UNION keyword), but Oracle just
	## could not handle it. Each query separately takes a few seconds,
	## but once they are combined, it never finishes.

	$q = q{
        select ug.account_collection_id, 
		gac.account_collection_name as group_name, a.login
        from v_property ugu
        join unix_group ug on 
		ug.account_collection_id = ugu.property_value_account_coll_id
	join account_collection gac on
		gac.account_collection_id = ug.account_collection_id
        join v_acct_coll_acct_expanded vuue on 
		ugu.account_collection_id = vuue.account_collection_id
        join account a on vuue.account_id = a.account_id
        where a.account_status in ('enabled', 'onleave-enable')
        and ugu.device_collection_id is null
		and ugu.property_name = 'UnixGroupAssign'
		and ugu.property_type = 'MclassUnixProp'
    };

	$sth = $dbh->prepare($q);
	$sth->execute;

	## We store the results in two hashes, $member and $gn_member.
	## The first level key is the DEVICE_COLLECTION_ID for both. The
	## second level key of $member is the UNIX_GROUP_ID. The second
	## level key of $gn_member is the group name. The value for both
	## hashes is a reference to the list of the group members.

	while ( $r = $sth->fetchrow_hashref ) {
		my $ugid  = $r->{_dbx('UNIX_GROUP_ID') };
		my $gname = $r->{_dbx('GROUP_NAME') };

		push( @{ $member{$ugid} },     $r->{_dbx('LOGIN')} );
		push( @{ $gn_member{$gname} }, $r->{_dbx('LOGIN')} );
	}

	## The $passwd_grp hash is built during generation of passwd
	## files. The first level key is the DEVICE_COLLECTION_ID, the
	## second level key is LOGIN, the third level keys are
	## 'GROUP_NAME' and 'GID'. The hash stores the primary Unix group
	## information for all users on all MCLASSes. Let's iterate over
	## all MCLASSes that have any users in the passwd file then.

	foreach my $dcid ( keys %$passwd_grp ) {
		my $gdc = $group{$dcid};
		my $gp  = $g_prop->{$dcid};
		my $gm;

		## $gm will store group member information for this MCLASS.
		## The first level key is the group name. The second level
		## keys are 'gid', 'password', and 'members'.

		## First add to $gm all groups that are assigned this MCLASS

		foreach my $ugid ( keys %$gdc ) {
			my $g     = $gdc->{$ugid};
			my $gpass = $g->{_dbx('GROUP_PASSWORD')} || '*';
			my $gname = $g->{_dbx('GROUP_NAME')};
			my $gid =
			    $gp && defined( $gp->{$gname} )
			  ? $gp->{$gname}{_dbx('FORCE_GID')}
			  : $g->{_dbx('UNIX_GID')};

			$gm->{$gname}{gid}      = $gid;
			$gm->{$gname}{password} = $gpass;

			## Add members that this group has everywhere

			push( @{ $gm->{$gname}{members} }, @{ $member{$ugid} } )
			  if ( defined $member{$ugid} );

			## Add members that are specific to this MCLASS

			push(
				@{ $gm->{$gname}{members} },
				@{ $m_member{$dcid}{$ugid} }
			) if ( defined $m_member{$dcid}{$ugid} );
		}

		## Now add default groups for users on this MCLASS. We take
		## the group information from $passwd_grp which stores the
		## primary group information from the passwd file.

		foreach my $login ( keys %{ $passwd_grp->{$dcid} } ) {
			my $gname = $passwd_grp->{$dcid}{$login}{GROUP_NAME};
			my $gid   = $passwd_grp->{$dcid}{$login}{GID};

			$gm->{$gname}{gid} ||= $gid;
			$gm->{$gname}{password} ||= '*';

			## Add members that this group has everywhere

			push(
				@{ $gm->{$gname}{members} },
				@{ $gn_member{$gname} }
			) if ( defined $gn_member{$gname} );

			## Add members that are specific to this MCLASS

			push(
				@{ $gm->{$gname}{members} },
				@{ $gn_m_member{$dcid}{$gname} }
			) if ( defined $gn_m_member{$dcid}{$gname} );
		}

		## And now write all the groups to the group file

		$fh = new_mclass_file( $dir, $mclass->{$dcid}{MCLASS},
			$fh, 'group' );

		foreach my $gname (
			sort    ## by GID
			{
				$gm->{$a}{gid} <=> $gm->{$b}{gid}
			} keys %$gm
		  )
		{
			my $gpass = $gm->{$gname}{password};
			my $gid   = $gm->{$gname}{gid};
			my ( @m, %is_mem );

			## Some Unix groups are actually empty in JazzHands, that's why
			## we need the if statement here.

			@m = @{ $gm->{$gname}{members} }
			  if ( defined $gm->{$gname}{members} );

			## Remove duplicate members from @m

			map { $is_mem{$_} = 1 } @m;
			@m = keys(%is_mem);

			## Remove users who are not in the passwd file

			@m = grep( defined( $passwd_grp->{$dcid}{$_} ), @m );

			print $fh "$gname:*:$gid:"
			  . join( ',', sort { $a cmp $b } @m ) . "\n";
		}
	}
}

###############################################################################
#
# usage: move_mclass_files($srcdir, $dstdir);
#
# Moves all files that are recorded in %mclass_file from the directory
# "$srcdir/$mclass" to the directory "$dstdir/$mclass" where $mclass
# is one of the MCLASSes recorded as the first level key in
# %mclass_file. The directory "$dstdir/$mclass" will be created if it
# does not exist already. Files previously existing in
# "$dstdir/$mclass" that are not being replaced with a new file will
# be deleted.
#
###############################################################################

sub move_mclass_files($$) {
	my $srcdir = shift;
	my $dstdir = shift;

	unless ( -d $dstdir ) {
		mkdir( $dstdir, 0750 ) or die "mkdir($dstdir) failed: $!\n";
	}

	foreach my $mclass ( keys %mclass_file ) {
		my %exist_file;

		## If the MCLASS directory exists, note all existing files in
		## %exist_file.

		if ( -d "$dstdir/$mclass" ) {
			map { $exist_file{$_} = 1 } <$dstdir/$mclass/*>;
		}

		## Otherwise, create the directory.

		else {
			mkdir( "$dstdir/$mclass", 0750 )
			  or die "mkdir($dstdir/$mclass) failed: $!\n";
		}

		## Move all files we created from the temporary directory to
		## the MCLASS directory.

		foreach my $file ( keys %{ $mclass_file{$mclass} } ) {
			unlink("$dstdir/$mclass/$file");
			delete $exist_file{"$dstdir/$mclass/$file"};
			move( "$srcdir/$mclass/$file", "$dstdir/$mclass" )
			  or die "move($srcdir/$mclass/$file, "
			  . "$dstdir/$mclass) failed: $!\n";
		}

		## Delete all remaining files from the MCLASS directory

		map { unlink($_) } keys %exist_file;
	}
}

###############################################################################
#
# usage: retrieve_sudo_data();
#
# Populates all %sudo_ global hashes with sudoers data.
#
###############################################################################

sub retrieve_sudo_data() {
	my ( $q, $aref );

	## defaults

	$q = q{
        select	d.device_collection_id, property_value AS sudo_value
        from	property p, device_collection d
        where	p.device_collection_id = d.device_collection_id
	and	p.property_name = 'sudo-default'
	and	p.property_type = 'sudoers'
    };

	$aref = $dbh->selectall_arrayref($q);

	foreach (@$aref) {
		my $k = shift(@$_);
		push( @{ $sudo_defaults{$k} }, @$_ );
	}

	## command aliases

	$q = q{
        select device_collection_id, a.sudo_alias_name, sudo_alias_value
        from sudo_acct_col_device_collectio c, sudo_alias a
        where c.sudo_alias_name = a.sudo_alias_name
    };

	$aref = $dbh->selectall_arrayref($q);

	foreach (@$aref) {
		my $k = shift(@$_);
		push( @{ $sudo_cmnd_aliases{$k} }, @$_ );
	}

	## uclasses

	$q = q{
        select distinct c1.device_collection_id, 'U', 
		u1.account_collection_id, u1.account_collection_name
        from sudo_acct_col_device_collectio c1, account_collection u1
        where c1.account_collection_id = u1.account_collection_id
        union
        select distinct c2.device_collection_id, 'R', 
               c2.run_as_account_collection_id, u2.account_collection_name
        from sudo_acct_col_device_collectio c2, account_collection u2
        where c2.run_as_account_collection_id = u2.account_collection_id
        and c2.run_as_account_collection_id is not null
    };

	$aref = $dbh->selectall_arrayref($q);

	foreach (@$aref) {
		my $k = shift(@$_);
		push( @{ $sudo_uclasses{$k} }, @$_ );
	}

	## User specifications

	$q = q{
        select device_collection_id, sudo_alias_name, account_collection_id,
               run_as_account_collection_id, requires_password, can_exec_child
        from sudo_acct_col_device_collectio
        order by account_collection_id
    };

	$aref = $dbh->selectall_arrayref($q);

	foreach (@$aref) {
		my $k = shift(@$_);
		push( @{ $sudo_user_spec{$k} }, @$_ );
	}

	## Expand UCLASSes found in sudoers files into logins

	$q = q{
        select account_collection_id, login from account
        join v_acct_coll_acct_expanded using(account_id)
        where account_id in (
          select account_id from sudo_acct_col_device_collectio
          union
          select run_as_account_collection_id from 
			sudo_acct_col_device_collectio
        )
        and account_status in ('enabled', 'onleave-enable')
    };

	$aref = $dbh->selectall_arrayref($q);

	foreach (@$aref) {
		my $k = shift(@$_);
		push( @{ $sudo_expand_uclass{$k} }, @$_ );
	}
}

###############################################################################
#
# @parent_mclass_ids = get_parents_for_mclass($mclass_id);
#
# Returns MCLASS ids of the parent MCLASSes of the MCLASS identified
# by $mclass_id. Copied from JazzHands::Management::DeviceCollection
# to ensure results are consistent.
#
###############################################################################

sub get_parents_for_mclass($) {
	my $dcid = shift;
	my ( $q, $sth, @ids );

	$q = q{
        select parent_device_collection_id
        from device_collection_hier
        connect by prior parent_device_collection_id = device_collection_id
	start with device_collection_id = ?
    };

	$sth = $dbh->prepare($q);
	$sth->execute($dcid);

	while ( my $id = ( ( $sth->fetchrow_array )[0] ) ) {
		next if ( grep( $id eq $_, @ids ) );
		unshift( @ids, $id );
	}

	$sth->finish;

	return @ids;
}

###############################################################################
#
# %uc_name = get_sudo_uclasses_for_mclass($mclass_id)
#
# Returns a hash whose keys are UCLASS_IDs of the UCLASSes that need to
# be expanded in the sudoers file for the MCLASS $mclassid with either
# 'U' or 'R' prepended to the UCLASS_ID depending on whether it needs to
# expand into a User_Alias or Runas_Alias. Values are the user alias
# names as they will appear in the sudoers file. The user alias name
# consists of the letter 'U' or 'R' followed by the UCLASS_ID followed
# by the UCLASS name. The function caches the results of the database
# query for all MCLASSes such that subsequent calls do not need to query
# the database.
#
###############################################################################

sub get_sudo_uclasses_for_mclass($) {
	my $mclass_id = shift;
	my ( @c, %uc_name );

	@c = @{ $sudo_uclasses{$mclass_id} }
	  if ( defined $sudo_uclasses{$mclass_id} );

	## @c = ('U', uclassid, uclassname, 'R', uclassid, uclassname, ...)

	while (@c) {
		my $utype    = shift(@c);    ## 'R' or 'U'
		my $uclassid = shift(@c);
		my $name     = shift(@c);

		$name = uc($name);
		$name =~ s/\W/_/g;
		$name = "${utype}${uclassid}_${name}";
		$uc_name{"$utype$uclassid"} = $name;
	}

	return %uc_name;
}

###############################################################################
#
# $wrapped_text = _wrap($sep, $nl, $maxlen, @strings);
#
# Joins @strings using $sep or $nl as separators such that the length of the
# string from $nl to the next $nl is not longer than $maxlen
#
###############################################################################

sub _wrap($$$@) {
	my ( $sep, $nl, $maxlen, @strings ) = @_;
	my ( $line, @lines );

	return '' unless ( $line = shift(@strings) );

	while (@strings) {
		my $s = shift(@strings);
		my $tl = join( $sep, $line, $s );

		if ( length($tl) > $maxlen ) {
			push( @lines, $line );
			$line = $s;
		}

		else {
			$line = $tl;
		}
	}

	return join( $nl, @lines, $line );
}

###############################################################################
#
# $text = get_sudoers_user_aliases(\%uc_name);
#
# The input parameter %uc_name is a reference to a hash returned by the
# function get_sudo_uclasses_for_mclass. Returns the part of the sudoers file
# which contains user aliases for the MCLASS $mclassid or undef on
# error. Also modifies %uc_name such that values for uclasses containing
# just a single login are set to this login. Uclasses that would expand
# as empty are deleted from %uc_name.
#
###############################################################################

sub get_sudoers_user_aliases($) {
	my $ucnref = shift;
	my $text   = '';

	foreach my $ruclassid ( sort { $a cmp $b } keys %$ucnref ) {
		my ( $uclassid, $ids, @logins );

		## strip the initial 'U' or 'R' from $ruclassid to get $uclassid

		$uclassid = $ruclassid;
		$uclassid =~ s/^[RU]//;

		## expand the uclass into the list of logins

		@logins = @{ $sudo_expand_uclass{$uclassid} }
		  if ( defined $sudo_expand_uclass{$uclassid} );

		## delete empty uclasses from $ucnref

		if ( $#logins < 0 ) {
			delete $ucnref->{$ruclassid};
		}

		## if the uclass expanded into a single login, modify $ucnref
		## appropriately

		elsif ( $#logins == 0 ) {
			$ucnref->{$ruclassid} = $logins[0];
		}

		## otherwise write the expansion to the output

		else {
			my @sl = sort { $a cmp $b } @logins;
			my $ur_alias =
			  $ruclassid =~ /^U/ ? 'User_Alias' : 'Runas_Alias';

			$text .= _wrap(
				", ",
				",\\\n\t",
				70,
				"$ur_alias $ucnref->{$ruclassid} = "
				  . shift(@sl),
				sort { $a cmp $b } @sl
			) . "\n";
		}
	}

	return $text;
}

###############################################################################
#
# usage: $text = get_sudoers_file($mclass_id);
#
# Returns the content of the sudoers file for the MCLASS identified by
# $mclass_id.
#
###############################################################################

sub get_sudoers_file {
	my ($mclass_id) = @_;
	my ( @ids, $text, $default, %sg, %cmnd, %ucn, @uspec );

	$text =
"# Do not edit this file, it is generated automatically. All changes\n"
	  . "# made by hand will be lost. For assistance with changes to this\n"
	  . "# file please contact nsisystems-tickets\@example.com\n"
	  . "# Generated on "
	  . scalar( gmtime(time) )
	  . " by $Script\n" . "# "
	  . '$Revision$' . "\n\n";

	%cmnd = %ucn = @uspec = ();

	## build the inheritance sequence of MCLASS_IDs

	@ids = get_parents_for_mclass($mclass_id);
	push( @ids, $mclass_id );

	## walk the MCLASS inheritance tree from the top down
	## and build the data structures that will be used later

	foreach my $mid (@ids) {
		my $d = $sudo_defaults{$mclass_id}->[0];
		my %u = get_sudo_uclasses_for_mclass($mid);
		my %c = @{ $sudo_cmnd_aliases{$mid} }
		  if ( defined( $sudo_cmnd_aliases{$mid} ) );

		## more specific defaults replace less specific ones

		$default = $d if ( defined $d );

		## uclass and command aliases are merged

		%ucn  = ( %ucn,  %u ) if (%u);
		%cmnd = ( %cmnd, %c ) if (%c);

		next unless ( exists( $sudo_user_spec{$mid} ) );

		## user specifications are merged too

		push( @uspec, @{ $sudo_user_spec{$mid} } );
	}

	## add defaults to the output

	$text .= "# Defaults specification\n\n";

	if ( defined $default ) {
		chomp($default);
		$text .= "Defaults $default\n\n";
	}

	$text .= "# Cmnd alias specification\n\n";

	## add command aliases to the output

	foreach ( sort { $a cmp $b } keys %cmnd ) {
		next if ( $_ eq 'ALL' );
		chomp( $cmnd{$_} );
		$text .= "Cmnd_Alias $_ = $cmnd{$_}\n";
	}

	$text .= "\n# User alias specification\n\n";

	## add user aliases to the output

	if (%ucn) {
		$text .= get_sudoers_user_aliases( \%ucn );
	}

	$text .= "\n# User privilege specification\n\n";

	## add user specifications to the output

	while (@uspec) {
		my $cmnd_alias = shift(@uspec);
		my $uclass_id  = shift(@uspec);
		my $run_asid   = shift(@uspec) || 'ALL';
		my $ynpass     = shift(@uspec);
		my $ynexec     = shift(@uspec);
		my ( $uclass, $runas );

		## user specifications for empty uclasses are excluded

		next if ( !exists( $ucn{"U$uclass_id"} ) );
		next if ( $run_asid ne 'ALL' && !exists( $ucn{"R$run_asid"} ) );

		$uclass = $ucn{"U$uclass_id"};
		$runas = $run_asid eq 'ALL' ? 'ALL' : $ucn{"R$run_asid"};

		## $ynpass and $ynexec can be NULL, 'Y', or 'N'

		$ynpass =
		  defined($ynpass)
		  ? ( $ynpass eq 'Y' ? 'PASSWD:' : 'NOPASSWD:' )
		  : '';

		$ynexec =
		  defined($ynexec)
		  ? ( $ynexec eq 'Y' ? 'EXEC:' : 'NOEXEC:' )
		  : '';

		$text .= "$uclass ALL = ($runas) $ynpass$ynexec$cmnd_alias\n";
	}

	return $text;
}

###############################################################################
#
# usage: generate_sudoers_files($dir);
#
# Create sudoers files in the directory $dir for all specified MCLASSes.
#
###############################################################################

sub generate_sudoers_files($) {
	my $dir = shift;
	my ( $q, $sth, $r, $fh );

	$q = q{
        select device_collection_id, device_collection_name mclass 
	  from device_collection
		join v_property using (device_collection_id)
        where property_name = 'generate-sudoers'
         and  property_type = 'sudoers'
    };

	if ($q_mclass_ids) {
		$q .= "and device_collection_id in $q_mclass_ids";
	}

	$sth = $dbh->prepare($q);
	$sth->execute;

	while ( $r = $sth->fetchrow_hashref ) {
		$fh = new_mclass_file( $dir, $r->{_dbx('MCLASS')}, 
			$fh, 'sudoers' );
		print $fh get_sudoers_file( $r->{_dbx('DEVICE_COLLECTION_ID')} );
		$fh->close;
	}

	$sth->finish;
}

###############################################################################
#
# usage: generate_dbal_files($dir);
#
# Create dbal files in the directory $dir for all specified MCLASSes.
# Most of the code is taken from the old mkpasswdfiles.
#
###############################################################################

sub generate_dbal_files($) {
	my $dir = shift;
	my ( $q, $sth, $row, $last_mclass, $fh, $text );

	$q = q{
        select c.device_collection_name mclass, a.appaal_name,
	  max(CASE WHEN p.app_key = 'Method' THEN p.app_value ELSE NULL END ) as method,
	  max(CASE WHEN p.app_key = 'DBType' THEN p.app_value ELSE NULL END ) as dbtype,
	  max(CASE WHEN p.app_key = 'Username' THEN p.app_value ELSE NULL END ) as username,
	  max(CASE WHEN p.app_key = 'Password' THEN p.app_value ELSE NULL END ) as password,
	  max(CASE WHEN p.app_key = 'ServiceName' THEN p.app_value ELSE NULL END ) as servicename,
	  max(CASE WHEN p.app_key = 'Keytab' THEN p.app_value ELSE NULL END ) as keytab
        from appaal_instance i
        join appaal_instance_property p
        on i.appaal_instance_id = p.appaal_instance_id
        join appaal a on i.appaal_id = a.appaal_id
        join appaal_instance_device_coll ac
        on i.appaal_instance_id = ac.appaal_instance_id
        join device_collection c
        on c.device_collection_id = ac.device_collection_id
        where c.device_collection_type = 'mclass'        
    };

	if ($q_mclass_ids) {
		$q .= "and c.device_collection_id in $q_mclass_ids";
	}

	$q .= " group by c.device_collection_name, a.appaal_name order by c.device_collection_name, a.appaal_name";
	$sth = $dbh->prepare($q);
	$sth->execute;

	while ( $row = $sth->fetchrow_arrayref ) {
		my ( $mclass, $applname, $method, $dbtype, $username, $password,
			$servicename, $keytab )
		  = @$row;

		## If we switched MCLASSes, write the accumulated text to the file,
		## open a new file, and empty the buffer

		if ( defined($last_mclass) ) {
			if ( $last_mclass ne $mclass ) {
				print $fh $text;
				$fh =
				  new_mclass_file( $dir, $mclass, $fh, 'dbal' );
				$last_mclass = $mclass;
				undef($text);
			}
		}

		else {
			$fh = new_mclass_file( $dir, $mclass, $fh, 'dbal' );
			$last_mclass = $mclass;
		}

		## This part of the code is copied from the old mkpasswdfiles.
		## It will need to be modified to support arbitrary key/value pairs
		## in DBAAL files.

		next if ( !$username || !$method || !$servicename );

		if ( $method eq "password" ) {
			next if ( !$password );
		}

		elsif ( $method eq "kerberos" ) {
			next if ( !$keytab );
		}

		$text .= "Application:\t$applname\n";
		$text .= "Method:\t$method\n";
		$text .= "DBType:\t$dbtype\n";
		$text .= "ServiceName:\t$servicename\n";
		$text .= "Username:\t$username\n";
	## placeholder for setting perms on this generated file.
	## mode will be the usual 4 digit octal 
	## user, group will be login-names/group-names
	## these are optional and if found & valid will
	## override the defaults of 0644, root, root.
	## $text .= "AuthFileMode:\t$blah\n";
	## $text .= "AuthFileUser:\t$blah\n";
	## $text .= "AuthFileGroup:\t$blah\n";

		if ( $method eq "password" ) {
			$text .= "Password:\t$password\n";
		}

		elsif ( $method eq "kerberos" ) {
			$text .= "Keytab:\t$keytab\n";
		}

		$text .= "\n";
	}

	print $fh $text if ( $fh && $text );
	$fh->close if ($fh);
}

###############################################################################
#
# usage: generate_k5login_root_files($dir);
#
# Create k5login-root files in the directory $dir for all specified MCLASSes.
#
###############################################################################

sub generate_k5login_root_files($) {
	my $dir = shift;
	my ( $q, $sth, $r, $last_mclass, $fh, $text );

	$q = q{
        select distinct c.device_collection_name mclass,
          a.login || '/' || k.krb_instance || '@' || kr.realm_name princ_name
        from v_device_coll_hier_detail dchd2
        join klogin_mclass km2
        on km2.device_collection_id = dchd2.parent_device_collection_id
        join device_collection c
        on dchd2.device_collection_id = c.device_collection_id
        join klogin k on km2.klogin_id = k.klogin_id
        join kerberos_realm kr on k.krb_realm_id = kr.krb_realm_id
        join account a on a.account_id = k.account_id
        where k.dest_account_Id = 
        (select account_id from account where login = 'root')
        and a.account_status in ('enabled', 'onleave-enable')
        and c.device_collection_type = 'mclass'
        and km2.include_exclude_flag = 'INCLUDE'
        and not exists (
            select * from v_device_coll_hier_detail dchd1
            join klogin_mclass km1
            on km1.device_collection_id = dchd1.parent_device_collection_id
            where km1.include_exclude_flag = 'EXCLUDE'
            and dchd1.device_collection_id = dchd2.device_collection_id
            and km1.klogin_id = km2.klogin_id)
    };

	if ($q_mclass_ids) {
		$q .= "and c.device_collection_id in $q_mclass_ids";
	}

	$q .= " order by mclass, princ_name";

	$sth = $dbh->prepare($q);
	$sth->execute;

	while ( $r = $sth->fetchrow_hashref ) {
		my $mclass = $r->{_dbx('MCLASS')};

		## If we switched MCLASSes, write the accumulated text to the file,
		## open a new file, and empty the buffer

		if ( defined($last_mclass) ) {
			if ( $last_mclass ne $mclass ) {
				print $fh $text;
				$fh = new_mclass_file( $dir, $mclass, $fh,
					'k5login-root' );
				$last_mclass = $mclass;
				undef($text);
			}
		}

		else {
			$fh =
			  new_mclass_file( $dir, $mclass, $fh, 'k5login-root' );
			$last_mclass = $mclass;
		}

		$text .= $r->{_dbx('PRINC_NAME')} . "\n";
	}

	print $fh $text if ( $fh && $text );
	$fh->close if ($fh);
}

###############################################################################
#
# usage: generate_wwwgroup_files($dir);
#
# Create wwwgroup files in the directory $dir for all specified MCLASSes.
#
###############################################################################

sub generate_wwwgroup_files($) {
	my $dir = shift;
	my ( $q, $sth, $r, $last_mclass, $fh, %member );

	$q = q{
        select distinct c.device_collection_name mclass,
               coalesce(p.property_value, u.account_collection_name) wwwgroup, 
	       a.login
        from device_collection c
        join v_device_col_acct_col_expanded dcue
        	on c.device_collection_id = dcue.device_collection_id
        join account a on dcue.account_id = a.account_id
        join account_collection u on 
		dcue.account_collection_id = u.account_collection_id
        left join property p on 
		(u.account_collection_id = p.account_collection_id
        and p.property_type = 'wwwgroup'
        and p.property_name = 'WWWGroupName')
        where u.account_collection_type = 'wwwgroup'
        and c.device_collection_type = 'mclass'
        and a.account_status in ('enabled', 'onleave-enable')
    };

	if ($q_mclass_ids) {
		$q .= "and c.device_collection_id in $q_mclass_ids";
	}

	$q .= " order by mclass, wwwgroup, login";

	$sth = $dbh->prepare($q);
	$sth->execute;

	while ( $r = $sth->fetchrow_hashref ) {
		my $mclass = $r->{_dbx('MCLASS')};

		## If we switched MCLASSes, write the accumulated text to the file,
		## open a new file, and empty the buffer

		if ( defined($last_mclass) ) {
			if ( $last_mclass ne $mclass ) {
				foreach ( sort { $a cmp $b } keys %member ) {
					print $fh "$_: ",
					  join( ' ', @{ $member{$_} } ), "\n";
				}

				$fh = new_mclass_file( $dir, $mclass, $fh,
					'wwwgroup' );
				print $fh "# Apache group file\n";
				$last_mclass = $mclass;
				undef(%member);
			}
		}

		else {
			$fh = new_mclass_file( $dir, $mclass, $fh, 'wwwgroup' );
			print $fh "# Apache group file\n";
			$last_mclass = $mclass;
		}

		push( @{ $member{ $r->{_dbx('WWWGROUP')} } }, $r->{_dbx('LOGIN')} );
	}

	foreach ( sort { $a cmp $b } keys %member ) {
		print $fh "$_: ", join( ' ', @{ $member{$_} } ), "\n";
	}

	$fh->close if ($fh);
}

###############################################################################
#
# usage: create_host_symlinks($dir, @mclasses);
#
# The function adjusts host symbolic links in the directory $dir to
# correctly point to the mclass directory for the specified
# MCLASSes. Symbolic links are modified only when necessary. If they
# point to the right MCLASS already, they are left alone.
#
###############################################################################

sub create_host_symlinks($@) {
	my ( $dir, @mclasses ) = @_;
	my ( $q, %old, $new );

	unless ( -d $dir ) {
		mkdir( $dir, 0750 ) or die "mkdir($dir) failed: $!\n";
	}

	## Examine the existing symbolic links in $dir, and record
	## information about them in %old.

	foreach my $link (<$dir/*>) {
		my $target = readlink($link);
		my ( $device, $mclass );

		## Determine the device name from the symbolic link

		if ( $link =~ m|.*/([^/]*)$| ) {
			$device = $1;
		}

		else {
			die "can't parse link $link\n";
		}

		## Determine the MCLASS name from the symlink target

		if ( $target =~ m|\.\./mclass/([^/]+)| ) {
			$mclass = $1;
		}

		else {
			die "can't parse link target $target\n";
		}

		## Add the symlink info to %old if the script runs for all
		## MCLASSes or if this MCLASS is one of the specified MCLASSes.

		if ( !@mclasses || grep( $mclass eq $_, @mclasses ) > 0 ) {
			$old{$device} = $mclass;
		}
	}

	## Now retrieve the current host -> mclass mapping from JazzHands

	$q = q{
        select device_name, device_collection_name mclass
        from device_collection
        join device_collection_device using (device_collection_id) 
        join device using (device_id)
        where device_collection_type = 'mclass' and device_name is not null
    };

	if ($q_mclass_ids) {
		$q .= "and device_collection_id in $q_mclass_ids";
	}

	$q .= " order by mclass, device_name";
	$new = $dbh->selectall_hashref( $q, _dbx('DEVICE_NAME') );

	## Adjust the symbolic links to point to the right place.

	foreach my $device ( keys %old ) {
		if ( exists $new->{$device} ) {
			if ( $new->{$device}{_dbx('MCLASS')} ne $old{$device} ) {
				unlink("$dir/$device");
				symlink( "../mclass/$new->{$device}{_dbx('MCLASS')}",
					"$dir/$device" );
			}
		}

		else {
			unlink("$dir/$device");
		}
	}

	foreach my $device ( keys %$new ) {
		unless ( exists $old{$device} ) {
			## The following unlink is useful when we run this script
			## for a few MCLASSes as opposed to all of them and links
			## need to be repointed.
			unlink("$dir/$device");
			symlink( "../mclass/$new->{$device}{_dbx('MCLASS')}",
				"$dir/$device" );
		}
	}
}

###############################################################################
#
# usage: validate_mclasses(@mclasses);
#
# Checks whether all MCLASS names in @mclasses belong are valid, and
# adds the MCLASS ids to the global array @mclass_ids.
#
###############################################################################

sub validate_mclasses(@) {
	my @mclasses = @_;
	my ( $q, $ref, @mclass_ids );

	$q = q{
        select name, device_collection_id from device_collection
        where device_collection_type = 'mclass'
    };

	$q .= "and name in ('" . join( "','", @mclasses ) . "')";
	$ref = $dbh->selectall_hashref( $q, 'NAME' );

	foreach (@mclasses) {
		if ( exists $ref->{$_} ) {
			push( @mclass_ids, $ref->{$_}{DEVICE_COLLECTION_ID} );
		}

		else {
			die "$_ is not a valid MCLASS\n";
		}
	}

	$q_mclass_ids = "(" . join( ',', @mclass_ids ) . ")";
}

###############################################################################
#
# usage: cleanup_old_tempdirs($dir);
#
# Removes all directories older than 24 hours from the directory $dir
# that are named 'tmp.*'.
#
###############################################################################

sub cleanup_old_tempdirs($) {
	my $dir = shift;

	foreach my $f (<$dir/*>) {
		my @s;

		next unless ( -d $f && $f =~ m|/tmp\.......$| );
		@s = stat(_);

		if ( $s[10] < time - 24 * 60 * 60 ) {
			print "removing old temporary directory $f\n"
			  if ($o_verbose);
			rmtree($f);
		}
	}
}

###############################################################################

sub main {
	my $dir;

	GetOptions(
		'v|verbose'      => \$o_verbose,
		'o|output-dir=s' => \$o_output_dir
	) or exit(2);

	$dbh =
	  JazzHands::DBI->connect( 'mkpwdfiles',
		{ RaiseError => 1, AutoCommit => 0 } );

	validate_mclasses(@ARGV) if ( $#ARGV >= 0 );
	umask(027);

	## Cleanup old temporary directories

	cleanup_old_tempdirs($o_output_dir);

	## Create a temporary directory to store the files

	$dir = tempdir( 'tmp.XXXXXX', DIR => "$o_output_dir", CLEANUP => 1 );

	## Group properties are used by both generate_passwd_files, and
	## generate_group_files. That's why we store them in a global
	## variable.

	$g_prop = get_group_properties();

	## Generate all the files

	generate_passwd_files($dir);
	generate_group_files($dir);
	retrieve_sudo_data();
	generate_sudoers_files($dir);
	generate_dbal_files($dir);
	generate_k5login_root_files($dir);
	generate_wwwgroup_files($dir);

	## Move the files from the temporary directory to the mclass directory

	print "moving files from $dir to $o_output_dir/mclass...\n"
	  if ($o_verbose);
	move_mclass_files( $dir, "$o_output_dir/mclass" );

	## Adjust the symlinks

	create_host_symlinks( "$o_output_dir/hosts", @ARGV );
	$dbh->disconnect;
}
