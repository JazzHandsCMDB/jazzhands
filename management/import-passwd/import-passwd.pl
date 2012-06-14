#!/usr/local/bin/perl
# Copyright (c) 2010, Todd Kover
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

#
# Quick and dirty script for importing passwd/group/shadow files into db.
# this is meant more as a debugging tool than proper import (which should
# be done via a smarter web serviec).  This just is a get 'r done script.
#

use strict;
use warnings;
use JazzHands::DBI;
use Data::Dumper;
use Carp;
use FileHandle;

exit do_work();

sub process_groups {
	my($dbh, $groupfn) = @_;

	my $fh = new FileHandle($groupfn) || die "$groupfn: $!";
	
	my $g = {};
	while(my $line = $fh->getline) {
		chomp($line);
		my($name,$pwd,$gid,$members) = split(/:/, $line, 4);
		# print "++ processing $name\n";
		$g->{$name} = {};
		$g->{$name}->{members} = $members;
		# XXX - need to deal with there being a mismatch between the local
		# machine and db for the gid.  (this was quick and dirty...)
		$g->{$name}->{gid} = $gid;

		my $namesth = $dbh->prepare_cached(qq{
			select	uclass_id
			  from	uclass
			 where	uclass_type = 'unix-group'
			  and	name = :1
		}) || die $dbh->errstr;
		$namesth->execute($name) || die $namesth->errstr;
		my ($id) = ($namesth->fetchrow_array)[0];
		$namesth->finish;
		if(defined($id)) {
			$g->{$name}->{id} = $id;
			next;
		}

		my $idsth = $dbh->prepare_cached(qq{
			select	u.uclass_id, u.name
			  from	unix_group ug
					inner join uclass u
						on u.uclass_id = ug.uclass_id
			 where	u.uclass_type = 'unix-group'
			  and	ug.unix_gid = :1
		}) || die $dbh->errstr;
		$idsth->execute($gid) || die $idsth->errstr;
		my ($dbid, $dbname) = ($idsth->fetchrow_array)[0, 1];
		$idsth->finish;
		if(defined($dbid) && $dbname) {
			warn "skipping gid $gid (db $dbname (id#$dbid)\n"; 
			next;
		}

		my $sth = $dbh->prepare_cached(qq{
			begin
				insert into uclass
					(name, uclass_type)
				values
					(:name, 'unix-group')
				returning uclass_id into :uclassid;

				insert into unix_group (
					uclass_id, group_name,
					unix_gid, group_password
				) values (
					:uclassid, :name,
					:gid, :pwd
				);
			end;
		}) || die $dbh->errstr;

		$pwd = undef if($pwd && $pwd =~ /^.$/);
		$sth->bind_param(':name', $name) || die $sth->errstr;
		$sth->bind_param(':gid', $gid) || die $sth->errstr;
		$sth->bind_param(':pwd', $pwd) || die $sth->errstr;
		$sth->bind_param_inout(':uclassid', \$id, 50) || die $sth->errstr;
		$sth->execute || die $sth->errstr;

		$g->{$name}->{id} = $id;
	}
	$fh->close;
	$g;
}

sub add_user {
	my($dbh, $dude, $gecos, $type) = @_;

	$gecos =~ s/&/$dude/g;

	# if user is there, do nothing.
	# need to have bjech's magical name matching logic apply.

	my $sth = $dbh->prepare_cached(qq{
		begin
			system_user_util.user_add(
				p_system_user_id => :id,
				p_login => :login,
				p_first_name => :first,
				p_middle_name => :middle,
				p_last_name => :last,
				p_system_user_status => 'enabled',
				p_system_user_type => :type,
				p_company_id => 0,
				p_employee_id => :empid,
				p_name_suffix => NULL,
				p_position_title => NULL,
				p_gender => NULL,
				p_preferred_first_name => NULL,
				p_preferred_last_name => NULL,
				p_hire_date => NULL,
				p_shirt_size => NULL,
				p_pant_size => NULL,
				p_hat_size => NULL
			);
		end;
	}) || die $dbh->errstr;

	print "processing $gecos -- $dude\n";
	$gecos =~ /^(\S+)\s+((.+)\s+)*([^,]+)(,.*)*$/;
	my($first, $middle, $last) = ($1,$3,$4);

	if(!$first || !$last) {
		warn "\tfudging gecos for $gecos\n";
		$last = $gecos;
		$last =~ s/,.*$//;
		$first = "unknown";
	}

	$sth->bind_param(':login', $dude) || die $sth->errstr;
	$sth->bind_param(':first', $first) || die $sth->errstr;
	$sth->bind_param(':middle', $middle) || die $sth->errstr;
	$sth->bind_param(':last', $last) || die $sth->errstr;
	$sth->bind_param(':type', $type) || die $sth->errstr;

	my ($id, $empid);
	$sth->bind_param_inout(':id', \$id, 50) || die $sth->errstr;
	$sth->bind_param_inout(':empid', \$empid, 50) || die $sth->errstr;
	$sth->execute || die $sth->errstr;
	$id;
}

sub do_work {
	my $dbh = JazzHands::DBI->connect('jazzhands', {AutoCommit=>0}) || confess;

	{
		my $dude = (getpwuid($<))[0] || 'unknown';
		my $q = qq{ 
			begin
				dbms_session.set_identifier ('$dude');
			end;
		};
		if(my $sth = $dbh->prepare($q)) {
			$sth->execute || confess $sth->errstr;
		}
	}

	#
	# XXX - needs to be converted to arguments, and also
	#
	my $group="group";
	my $passwd="master.passwd";
	my $shadow="shadow";

	# my $fmt = "shadow";
	my $fmt = "masterpasswd";

	my $grp = process_groups($dbh, $group);

	my $pwd = {};
	if($fmt eq 'shadow') {
		my $fh = new FileHandle($shadow) || die "$shadow: $!";
		while(my $line = $fh->getline) {
			my($dude,$pw) = split(/:/, $line);
			next if($dude eq 'root');
			next if($pw =~ /^.$/);
			$pwd->{$dude} = $pw;
		}
		$fh->close;
	}

	my $grps = {};
	my $fh = new FileHandle($passwd) || die "$passwd: $!";
	while(my $line = $fh->getline) {
		chomp($line);
		my(@f) = split(/:/, $line);
		my($dude,$crypt,$uid,$gid,$gecos,$home,$shell);
		# XXX - need to deal with the rest of the master.passwd entries
		if($fmt eq 'masterpasswd') {
			($dude,$crypt,$uid,$gid,$gecos,$home,$shell) = @f[0,1,2,3,7,8,9];
		} elsif($fmt eq 'shadow') {
			($dude,$crypt,$uid,$gid,$gecos,$home,$shell) = @f[0,1,2,3,4,5,6];
		}
		# next if(!defined($pwd->{$dude}));
		push(@{$grps->{$gid}}, $dude);

		# skip netbsd system users XXX
		next if($dude =~/^_/);

		# look up dude.  need to deal with if the user already exists,
		# including if password type is not there (may be a bad idea)
		if($dude) {
			my $sth = $dbh->prepare_cached(qq{
				select	system_user_id
				 from	system_user
				where	login = :1
			}) || die $dbh->errstr;
			$sth->execute($dude) || die $sth->errstr;
			my $suid = ($sth->fetchrow_array)[0];
			$sth->finish;
			if(defined($suid)) {
				warn "skipping $dude, already exists\n";
				next;
			}
		}

		if(my $suid = add_user($dbh, $dude, $gecos, 'employee')) {
			print "inserted $suid\n";
			my $pwtype;
			if($fmt eq 'shadow') {
				$crypt = $pwd->{$dude};	
			}
			if(defined($crypt) && $crypt =~ /^\$/) {
				if($crypt =~ /^\$2/) {
					$pwtype = 'blowfish';
				} elsif($crypt =~ /^\$s/) {
					$pwtype = 'sha1';
				} elsif($crypt =~ /^\$1/) {
					$pwtype = 'md5';
				} elsif($crypt =~ /^\**$/) {
					$pwtype = undef;
				} else {
					$pwtype = 'md5';
				}
			} else {
				$pwtype = 'des';
			}
			if($pwtype) {
				my $sth = $dbh->prepare_cached(qq{
					insert into system_password (
						system_user_id,
						password_type,
						user_password
					) values (
						:1,
						:2,
						:3
					)
				}) || die $dbh->errstr;
				$sth->execute($suid, $pwtype, $crypt) || die $sth->errstr;
			}

			# XXX - need to switch to using package utils for
			# this.
			if($uid) {
				my $dbgid;
				# XXX need to cache better
				foreach my $g (keys %{$grp}) {
					if($grp->{$g}->{gid} == $gid) {
						$dbgid = $grp->{$g}->{id};
						last;
					}
				}
				if(!$dbgid) {
					warn "skipping user $dude, no primary group in /etc/group";
					next;
				}
				my $sth = $dbh->prepare_cached(qq{
					insert into user_unix_info (
						system_user_id,
						unix_uid,
						unix_group_uclass_id,
						shell,
						default_home
					) values (
						:1,
						:2,
						:3,
						:4,
						:5
					)
				}) || die $dbh->errstr;
				$sth->execute($suid,$uid,$dbgid,$shell,$home) || die $sth->errstr;
			}
		}
	}

	$dbh->commit;
	$dbh->disconnect;
}
