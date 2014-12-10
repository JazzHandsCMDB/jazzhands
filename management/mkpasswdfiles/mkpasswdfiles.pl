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

# Copyright (c) 2013, Todd Kover
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# $Id$
#

=head1 NAME

 mkpasswdfiles - extract files for pwfetch from JazzHands

=head1 SYNOPSIS

 mkpasswdfiles [-v] [-o output_dir] [mclass mclass ...]

=head1 DESCRIPTION

mkpasswdfiles reads user account and server information from JazzHands,
and creates passwd, group, sudoers, k5login-root, appaal, and wwwgroup
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
/var/lib/jazzhands/creds-mgmt-server/ .

=item --random-sleep #

Sleep a random number of seconds up to # before starting

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

use strict;
use warnings;
use JazzHands::DBI;
use File::Temp qw(tempdir);
use IO::File;
use File::Copy;
use File::Path;
use Getopt::Long;
use Data::Dumper;
use FindBin qw($Script);
use JazzHands::Common qw(:all);
use JSON::PP;
use File::Find;

my $o_output_dir = "/var/lib/jazzhands/creds-mgmt-server/out";
my $o_verbose;
my $o_random;

my ( $q_mclass_ids, $dbh, $passwd_grp, %mclass_file );
my (
	%sudo_defaults,  %sudo_cmnd_aliases, %sudo_uclasses,
	%sudo_user_spec, %sudo_expand_uclass
);

my ($support_email);

main();
exit(0);

###############################################################################
#
# Usage: $supportemail - get_support_email ($dbh)
#
# attempts to look up support email in db.  If its not there, uses an
# example.com address
#
sub get_support_email($) {
	my ($dbh) = @_;

	my $sth = $dbh->prepare_cached(
		q{
    	SELECT	property_value
	  FROM	v_property
	 WHERE	property_name = '_supportemail'
	  AND   property_type = 'Defaults'
    }
	) || die $dbh->errstr;

	$sth->execute || die $sth->errstr;

	my ($addr) = $sth->fetchrow_array;
	$sth->finish;
	$addr = 'support@example.com' if ( !$addr );
	$addr;
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
	 where p.property_type in ( 'MclassUnixProp' )
		and p.property_name != 'UnixLogin'
    	};

	if ($q_mclass_ids) {
		$q .= "and d.device_collection_id in $q_mclass_ids";
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

		if ( $propn eq 'UnixHomeType' && $propt eq 'MclassUnixProp' ) {
			$m_prop->{$dcid}{MCLASS_UNIX_HOME_TYPE} = $propv
			  unless (
				defined $m_prop->{$dcid}{MCLASS_UNIX_HOME_TYPE}
			  );
		}

		if ( $propn eq 'UnixPwType' && $propt eq 'MclassUnixProp' ) {
			$m_prop->{$dcid}{MCLASS_UNIX_PW_TYPE} = $propv
			  unless (
				defined $m_prop->{$dcid}{MCLASS_UNIX_PW_TYPE} );
		}

		if ( $propn eq 'HomePlace' && $propt eq 'MclassUnixProp' ) {
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
	die "attempt to create a non-existant mclass" if ( !$mclass );
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
# usage: generate_passwd_files($dir, $style);
#
# Creates passwd files for all specified MCLASSes in the directory $dir.
#
###############################################################################
sub get_setting_value($$$) {
	my($array, $setting, $default) = @_;


	if($array) {
		for(my $i = 0; $i < scalar(@{$array}); $i += 2) {
			if($array->[$i] eq $setting) {
				return $array->[$i+1];
			}
		}
	}
	$default;
}

sub build_userhash($$) {
	my($r, $pwdlines) = @_;

	### Check to see if the login already exists in the array.  In
	### which case, the first one is favored, except for ssh keys which
	### are added to the existing record.  This is really the only
	## legitimate reason for the same login showing up twice
	##
	## It may be possible to do something clever with unnest
	## in v_device_collection_account_ssh_key to make this
	## go away
	if( $r->{ _dbx('SSH_PUBLIC_KEY') } ) {
		my $login = $r->{ _dbx('LOGIN') };
		my @uh = grep($_->{login} eq $login, @$pwdlines);
		if(scalar @uh ) {
			my $uh = pop(@uh);
			foreach my $k (@{ $r->{ _dbx('SSH_PUBLIC_KEY') } }) {
				push(@ {$uh->{ssh_public_key}}, $k);
			}
			return;  # one dude!
		}
	}

	## We need to store the mapping from DEVICE_COLLECTION_ID and
	## LOGIN to GROUP_NAME and GID. We will need it later to
	## generate the group files. We keep the information in the
	## global variable $passwd_grp which is a hash reference.

	my $userhash = {
		'account_id'    => $r->{ _dbx('ACCOUNT_ID') },
		'login'	 => $r->{ _dbx('LOGIN') },
		'password_hash' => $r->{ _dbx('CRYPT') },
		'uid'	   => int( $r->{ _dbx('UNIX_UID') } ),
		'gecos'	 => $r->{ _dbx('GECOS') },
		'home'	  => $r->{ _dbx('HOME') },
		'shell'	 => $r->{ _dbx('SHELL') },
		'group_name'    => $r->{ _dbx('UNIX_GROUP_NAME') },
		'PreferLocal'   => get_setting_value(
			$r->{ _dbx('setting') },
			'PreferLocal', 'N'
		),
		'PreferLocalSSHAuthorizedKeys' => get_setting_value(
			$r->{ _dbx('setting') },
			'PreferLocalSSHAuthorizedKeys', 'N'
		),
	};

	if ( defined $r->{ _dbx('EXTRA_GROUPS') } ) {
		$userhash->{'extra_groups'} =
		  $r->{ _dbx('EXTRA_GROUPS') };
	}

	if ( defined $r->{ _dbx('SSH_PUBLIC_KEY') } ) {
		$userhash->{'ssh_public_key'} =
		  $r->{ _dbx('SSH_PUBLIC_KEY') };
	}
	$userhash;
}

sub generate_passwd_files($$) {
	my $dir = shift;
	my $style = shift;
	my ( $q, $sth, $r, $last_dcid, $fh, @pwdlines );

	print "Processing passwd files\n" if ($o_verbose);

	## The following query returns the passwd file lines for all MCLASSes,
	## including overrides.

	my $outclass = 'passwd';
	if($style eq 'mclass') {
		my $and = "";
		if ($q_mclass_ids) {
			$and .= "and device_collection_id in $q_mclass_ids";
		}

		$q = qq{
			SELECT	device_collection_name, map.* 
			FROM	v_unix_passwd_mappings map
					INNER JOIN device_collection USING (device_collection_id)
			WHERE	device_collection_type = 'mclass'
					$and
			ORDER BY device_collection_name, unix_uid
		};
	} elsif($style eq 'per-host') {
		$outclass = 'hostpasswd';
		my $and = "";
		if ($q_mclass_ids) {
			$and .= qq{and device_id in (
				select device_id
				FROM	device_collection_device
						INNER JOIN device_collection USING (device_collection_id)
				WHERE	device_collection_id IN $q_mclass_ids
				)
			};
		}
	
		$q = qq{
			SELECT	d.device_name, map.* 
			FROM	v_unix_passwd_mappings map
					INNER JOIN device_collection USING (device_collection_id)
					INNER JOIN device_collection_device 
							USING (device_collection_id)
					INNER JOIN device d USING (device_id)
			WHERE	device_collection_type = 'per-device'
					$and
			ORDER BY device_name, unix_uid
		};
	}

	$sth = $dbh->prepare($q);
	$sth->execute;

	## Iterate over all MCLASSes and UIDs

	while ( $r = $sth->fetchrow_hashref ) {
		my $dcid = $r->{ _dbx('DEVICE_COLLECTION_ID') };
		my $suid = $r->{ _dbx('ACCOUNT_ID') };
		my ( @pwd, $login, $gid, $gname );

		## If we switched to a new MCLASS, write the passwd file
		## and empty @pwdlines

		my $outname = ($style eq 'mclass')?$r->{ _dbx('DEVICE_COLLECTION_NAME') }:
			$r->{ _dbx('DEVICE_NAME') };
		if ( defined($last_dcid) ) {
			if ( $last_dcid != $dcid ) {
				my $json = JSON::PP->new->ascii;
				print $fh $json->pretty->encode( \@pwdlines );
				$fh =
				  new_mclass_file( $dir, $outname, $fh, $outclass );
				$last_dcid = $dcid;
				undef(@pwdlines);
			}
		} else {
			$fh = new_mclass_file( $dir, $outname, $fh, $outclass );
			$last_dcid = $dcid;
		}
		my $userhash = build_userhash($r, \@pwdlines);

		## Accumulate all passwd file lines in @pwdlines.
		## $pwd[7] is the group name. We don't need it anymore.
		push( @pwdlines, $userhash );
	}

	## Let's not forget to write the passwd file for the last MCLASS
	my $json = JSON::PP->new->ascii;
	print $fh $json->pretty->encode( \@pwdlines ) if ($fh);
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

sub generate_group_files($$) {
	my $dir = shift;
	my $style = shift;

	my (
		$q,	 $sth,   $fh,
	);

	print "Processing group files\n" if ($o_verbose);

	my $and = "";
	if ($q_mclass_ids) {
		$and .= "and device_collection_id in $q_mclass_ids";
	}

	my $outclass = 'group';
	if($style eq 'mclass') {
		my $and = "";
		if ($q_mclass_ids) {
			$and .= "and device_collection_id in $q_mclass_ids";
		}

		$q = qq{
			SELECT	device_collection_name, map.* 
			FROM	v_unix_group_mappings map
					INNER JOIN device_collection USING (device_collection_id)
			WHERE	device_collection_type = 'mclass'
					$and
			ORDER BY device_collection_name, unix_gid
		};
	} elsif($style eq 'per-host') {
		$outclass = 'hostgroup';
		my $and = "";
		if ($q_mclass_ids) {
			$and .= qq{and device_id in (
				select device_id
				FROM	device_collection_device
						INNER JOIN device_collection USING (device_collection_id)
				WHERE   device_collection_id IN $q_mclass_ids
				)
			};
		}

		$q = qq{
			SELECT  d.device_name, map.*
			FROM	v_unix_group_mappings map
					INNER JOIN device_collection USING (device_collection_id)
					INNER JOIN device_collection_device
							USING (device_collection_id)
					INNER JOIN device d USING (device_id)
			WHERE   device_collection_type = 'per-device'
					$and
			ORDER BY device_name, unix_gid
		};
	}


	$sth = $dbh->prepare($q);
	$sth->execute;

	my @grplines;
	my $last_dcid;
	while ( my $r = $sth->fetchrow_hashref ) {
		my $dcid = $r->{ _dbx('DEVICE_COLLECTION_ID') };
		my $gname = $r->{ _dbx('GROUP_NAME') };
		my $gid = $r->{ _dbx('UNIX_GID') };
		my $gpwd = $r->{ _dbx('GROUP_PASSWORD') };
		my $peeps = $r->{ _dbx('MEMBERS') };

		my $outname = ($style eq 'mclass')?
			$r->{ _dbx('DEVICE_COLLECTION_NAME') }:
			$r->{ _dbx('DEVICE_NAME') };
		if ( defined($last_dcid) ) {
			if ( $last_dcid != $dcid ) {
				my $json = JSON::PP->new->ascii;
				print $fh $json->pretty->encode( \@grplines );
				$fh =
				  new_mclass_file( $dir, $outname, $fh, $outclass );
				$last_dcid = $dcid;
				undef(@grplines);
			}
		} else {
			$fh = new_mclass_file( $dir, $outname, $fh, $outclass );
			$last_dcid = $dcid;
		}


		# sometimes an undef shows up, so strip it out
		my @peeps = grep ( defined($_), @$peeps);

		push(
			@grplines,
			{
				'group_name'     => $gname,
				'group_password' => '*',
				'gid'	    => int($gid),
				'members'	=> \@peeps
			}
		);
	}

	## Let's not forget to write the passwd file for the last MCLASS
	my $json = JSON::PP->new->ascii;
	print $fh $json->pretty->encode( \@grplines ) if ($fh);
	$fh->close if ( defined $fh );

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
	from	v_property p, device_collection d
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
	SELECT	parent_device_collection_id
	  FROM	v_device_coll_hier_detail
	 WHERE	device_collection_id = ?
	   AND	device_collection_id != parent_device_collection_id
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
	  . "# file please contact $support_email\n"
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
		$fh = new_mclass_file( $dir, $r->{ _dbx('MCLASS') },
			$fh, 'sudoers' );
		print $fh get_sudoers_file(
			$r->{ _dbx('DEVICE_COLLECTION_ID') } );
		$fh->close;
	}

	$sth->finish;
}

###############################################################################
#
# usage: generate_appaal_files($dir);
#
# Create appaal files in the directory $dir for all specified MCLASSes.
# Most of the code is taken from the old mkpasswdfiles.
#
###############################################################################

sub generate_appaal_files($) {
	my $dir = shift;
	my ( $q, $sth, $row, $last_mclass, $last_app, $fh );

	$q = q{
		select	c.device_collection_name mclass,
			a.appaal_name,
			fa.login as file_owner,
			fg.account_collection_name as group_name,
			i.file_mode,
			p.app_key,
			p.app_value
		 from	appaal_instance i
		 	inner join appaal_instance_property p
				on i.appaal_instance_id = p.appaal_instance_id
			inner join appaal a
				on i.appaal_id = a.appaal_id
			inner join appaal_instance_device_coll ac
				on i.appaal_instance_id = ac.appaal_instance_id
			inner join device_collection c
				on c.device_collection_id = ac.device_collection_id
			inner join account fa
				on fa.account_id = i.file_owner_account_id
			inner join account_collection fg
				on fg.account_collection_id = i.file_group_acct_collection_id
		where c.device_collection_type = 'mclass'
	};

	if ($q_mclass_ids) {
		$q .= "and c.device_collection_id in $q_mclass_ids";
	}

	$q .= " order by c.device_collection_name, a.appaal_name";
	$sth = $dbh->prepare($q);
	$sth->execute;

	# This convoluted way of dealing with things is so that the hash for dbs
	# can be built up and written out when complete.  Similarly, a build up
	# for mclasses.  There is probably a smarter way to do it.
	my $allapps;
	my $appkeys     = {};
	my $md	  = {};
	my $closeapp    = 0;
	my $closemclass = 0;
	do {
		$row = $sth->fetchrow_arrayref;
		my ( $mclass, $applname, $owner, $group, $mode, $key, $val );
		if ( !$row ) {
			$closemclass = 1;
			$closeapp    = 1;
		} else {
			(
				$mclass, $applname, $owner, $group, $mode,
				$key, $val
			) = @$row;
			$closemclass = 0;
			$closeapp    = 0;
		}

		## If we switched apps, save out the data for future writing
		if ( defined($last_app) ) {
			if ( defined($applname) ) {
				if ( $last_app ne $applname ) {
					$closeapp = 1;
				}

			} else {
				$closeapp = 1;
			}
		} else {
			$last_app	 = $applname;
			$md->{file_owner} = $owner;
			$md->{file_group} = $group;
			$md->{file_mode} = sprintf "0%o", $mode;
		}

		## If we switched MCLASSes, write the accumulated text to the file,
		## open a new file, and empty the buffer
		if ( defined($last_mclass) ) {
			if ( defined($mclass) ) {
				if ( $last_mclass ne $mclass ) {
					$closemclass = 1;
				}
			} else {
				$closemclass = 1;
			}
		} elsif ($mclass) {
			$fh = new_mclass_file( $dir, $mclass, $fh, 'appaal' );
			$last_mclass = $mclass;
		}

		if ($closeapp) {
			my $go = 1;

	   # check to see fi we are complete.  If not, do not generate an error.
	   # This probably wants a warning...
			$go = 0
			  if ( $appkeys->{'Method'} eq 'Password'
				&& !defined( $appkeys->{'Password'} ) );
			$go = 0
			  if ( $appkeys->{'Method'} eq 'Kerberos'
				&& !defined( $appkeys->{'Keytab'} ) );

			if ($go) {
				my $h = {};
				if (
					exists(
						$appkeys
						  ->{use_session_variables}
					)
				  )
				{
					$h->{options} = {};
					$h->{options}->{use_session_variables}
					  = $appkeys->{use_session_variables};
					delete
					  $appkeys->{use_session_variables};
				}
				push( @{ $h->{database} }, $appkeys );
				$allapps->{$last_app}->{data}     = $h;
				$allapps->{$last_app}->{metadata} = $md;
			}
			$appkeys = {};
			$md      = {};
			if ($applname) {
				$md->{file_owner} = $owner;
				$md->{file_group} = $group;
				$md->{file_mode}  = sprintf "0%o", $mode;
			}
			$last_app = $applname;
		}

		if ($closemclass) {
			my $json = JSON::PP->new->ascii;
			print $fh $json->pretty->encode($allapps);
			if ($mclass) {
				$fh =
				  new_mclass_file( $dir, $mclass, $fh,
					'appaal' );
			}
			$last_mclass = $mclass;
			$allapps     = {};
		}

		if ($key) {
			$appkeys->{$key} = $val;
		}
	} while ( !$closemclass );
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
		my $mclass = $r->{ _dbx('MCLASS') };

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

		$text .= $r->{ _dbx('PRINC_NAME') } . "\n";
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
	left join v_property p on 
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
		my $mclass = $r->{ _dbx('MCLASS') };

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

		push(
			@{ $member{ $r->{ _dbx('WWWGROUP') } } },
			$r->{ _dbx('LOGIN') }
		);
	}

	foreach ( sort { $a cmp $b } keys %member ) {
		print $fh "$_: ", join( ' ', @{ $member{$_} } ), "\n";
	}

	$fh->close if ($fh);
}

sub generate_config_files {
	my ($dir) = @_;

	my $q = q{
		SELECT pv.device_collection_id,
			   pv.property_name,
			   pv.property_type,
			   pv.property_value,
			   dc.device_collection_name
		FROM (
				SELECT device_collection_id, 
					property_name, property_type,
					property_value, rank()
				OVER (PARTITION BY device_collection_id ,
					property_name, property_type
					ORDER BY  device_collection_level)
				FROM (
					select
						dc.device_collection_level,
						dc.device_collection_id,
						p.property_name,
						p.property_type,
						p.property_value
					from   v_property p
					inner join v_device_coll_hier_detail dc on
						p.device_collection_id = dc.parent_device_collection_id
					where   ((
							p.property_name = 'ShouldDeploy'  and
							p.property_type = 'MclassUnixProp'
							) OR (
							p.property_name = 'PermitUIDOverride'  and
							p.property_type = 'MclassUnixProp'
							) OR (
							p.property_name = 'PermitGIDOverride'  and
							p.property_type = 'MclassUnixProp'
							))
				) xxx
		) pv
		INNER JOIN device_collection dc using (device_collection_id)
		WHERE pv.rank = 1
    };

	if ($q_mclass_ids) {
		$q .= "and pv.device_collection_id in $q_mclass_ids";
	}

	my $sth = $dbh->prepare($q);
	$sth->execute;

	my $cfg       = {};
	my $mclass_fn = "_config.json";

	my ( $last_mclass, $fh );
	while ( my $r = $sth->fetchrow_hashref ) {
		my $mclass = $r->{ _dbx('DEVICE_COLLECTION_NAME') };

		## If we switched MCLASSes, write the accumulated text to the file,
		## open a new file, and empty the buffer

		if ( defined($last_mclass) ) {
			if ( $last_mclass ne $mclass ) {
				my $json = JSON::PP->new->ascii;
				print $fh $json->pretty->encode(
					{
						'config' => $cfg
					}
				  ),
				  "\n";
				$fh = new_mclass_file( $dir, $mclass, $fh,
					$mclass_fn );
				$last_mclass = $mclass;
				$cfg	 = {};
			}
		}

		else {
			$fh = new_mclass_file( $dir, $mclass, $fh, $mclass_fn );
			$last_mclass = $mclass;
		}

		$cfg->{ $r->{ _dbx('PROPERTY_NAME') } } =
		  ( $r->{ _dbx('PROPERTY_VALUE') } eq 'Y' ) ? 1 : 0;
	}

	my $json = JSON::PP->new->ascii;
	if ($fh) {
		print $fh $json->pretty->encode(
			{
				'config' => $cfg
			}
		  ),
		  "\n";
		$fh->close;
	}
}

###############################################################################
#
# usage: create_host_symlinks($dir, @mclasses);
#
# This function creates a new directory named after the host, and checks to
# see if it contains a symlink "mclass" and if it points to the right
# mclass.  It changes it otherwise.
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

	foreach my $entry (<$dir/*>) {
		my $target = readlink($entry);

		#
		# This is for conversion, if its a symlink then migrate to a directory
		# and symlink "mclass" to the mclass", then evalute the mclass link.
		if($target) {
			my $n = "$entry.$$";
			mkdir($n, 0750);
			if($target =~ /^\./) {
				symlink("../$target", "$n/mclass");
			} else {
				symlink("$target", "$n/mclass");
			}
			unlink ($entry);
			rename ($n, $entry);
		}

		#
		# Now check things for real
		#
		if(-d "$entry" && -r "$entry/mclass" && !readlink("$entry/mclass")) {
			die "$entry/mclass should be a symlink";
		}
		my ( $device, $mclass );

		## Determine the device name from the symbolic link
		$target = readlink("$entry/mclass");
		if($entry && $target) {
			if ( $entry =~ m|.*/([^/]*)$| ) {
				$device = $1;
			} else {
				die "can't parse link $entry\n";
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
			if ( $new->{$device}{ _dbx('MCLASS') } ne
				$old{$device} )
			{
				unlink("$dir/$device/mclass");
				symlink(
					"../../mclass/$new->{$device}{_dbx('MCLASS')}",
					"$dir/$device/mclass"
				);
			}
		}

		else {
			unlink("$dir/$device");
		}
	}

	foreach my $device ( keys %$new ) {
		my $linkdst = "$dir/$device/mclass";
		unless ( exists $old{$device} ) {
			## The following unlink is useful when we run this script
			## for a few MCLASSes as opposed to all of them and links
			## need to be repointed.
			unlink( $linkdst );
		}
		if(! -f "$dir/$device") {
			mkdir("$dir/$device", 0750);
		}
		symlink( "../../mclass/$new->{$device}{_dbx('MCLASS')}",
			"$linkdst" );
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
	select device_collection_name, device_collection_id from device_collection
	where device_collection_type = 'mclass'
    };

	$q .= "and device_collection_name in ('" . join( "','", @mclasses ) . "')";
	$ref = $dbh->selectall_hashref( $q, _dbx('DEVICE_COLLECTION_NAME') );

	foreach (@mclasses) {
		if ( exists $ref->{$_} ) {
			push( @mclass_ids, $ref->{$_}{_dbx('DEVICE_COLLECTION_ID')} );
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
# usage: create_json_manifest( $dir, $output_dir, $output_file );
#
# Creates a JSON manifest file that is an array of all of the files in the specified directory
#
###############################################################################

sub create_json_manifest {
	my ( $dir, $output_dir, $output_file ) = @_;

	my @files;
	my $finder = sub {
		if ( -f or -l ) {
			my $file = $File::Find::name;
			$file =~ s#^$output_dir/*##;
			push @files, $file;
		}
	};
	find( $finder, $dir );
	@files = sort(@files);
	my $json = JSON::PP->new->ascii;
	my $fh = IO::File->new( "$output_dir/$output_file", "w", 0640 )
	  or die "can't create file $output_dir/$output_file: $!\n";
	print $fh $json->pretty->encode( \@files );
	$fh->close if ( defined $fh );
}

###############################################################################

sub main {
	my $dir;

	chdir("/") if (!-r ".");

	GetOptions(
		'random-sleep=i' => \$o_random,
		'v|verbose'      => \$o_verbose,
		'o|output-dir=s' => \$o_output_dir
	) or exit(2);

	if ($o_random) {
		my $delay = int( rand($o_random) );
		warn "Sleeping $delay seconds\n" if ($o_verbose);
		sleep($delay);
	}

	warn "Connecting to DB..." if ($o_verbose);
	$dbh =
	  JazzHands::DBI->connect( 'mkpwdfiles',
		{ RaiseError => 1, AutoCommit => 0 } );

	if ( !$dbh ) {
		die "mkpwdfiles: ", $dbh->errstr;
	}

	validate_mclasses(@ARGV) if ( $#ARGV >= 0 );

	# umask(027);
	umask(022);

	## Cleanup old temporary directories

	#
	# figure out support email
	#
	$support_email = get_support_email($dbh);

	cleanup_old_tempdirs($o_output_dir);

	## Create a temporary directory to store the files

	$dir = tempdir( 'tmp.XXXXXX', DIR => "$o_output_dir", CLEANUP => 1 );

	## Group properties are used by both generate_passwd_files, and
	## generate_group_files. That's why we store them in a global
	## variable.

	## Generate all the files

	generate_passwd_files($dir, 'mclass');
	generate_group_files($dir, 'mclass');
	retrieve_sudo_data();
	generate_sudoers_files($dir);

	#	generate_appaal_files($dir);
	generate_k5login_root_files($dir);
	generate_wwwgroup_files($dir);

	generate_config_files($dir);

	## Move the files from the temporary directory to the mclass directory

	print "moving files from $dir to $o_output_dir/mclass...\n"
	  if ($o_verbose);
	move_mclass_files( $dir, "$o_output_dir/mclass" );

	## Adjust the symlinks

	create_host_symlinks( "$o_output_dir/hosts", @ARGV );

	## create any per-host files
	generate_passwd_files("$o_output_dir/hosts", 'per-host');
	generate_group_files("$o_output_dir/hosts", 'per-host');

	$dbh->disconnect;

	## Create the manifest
	create_json_manifest( $o_output_dir, $o_output_dir, 'manifest.json' );
}
