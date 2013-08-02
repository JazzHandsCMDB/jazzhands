#!/usr/bin/env perl
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
			select	account_collection_id
			  from	account_collection
			 where	account_collection_type = 'unix-group'
			  and	account_collection_name = ?
		}) || die $dbh->errstr;
		$namesth->execute($name) || die $namesth->errstr;
		my ($id) = ($namesth->fetchrow_array)[0];
		$namesth->finish;
		if(defined($id)) {
			$g->{$name}->{id} = $id;
			next;
		}

		my $idsth = $dbh->prepare_cached(qq{
			select	ac.account_collection_id, ac.account_collection_name
			  from	unix_group ug
					inner join account_collection ac
					on ac.account_collection_id = ug.account_collection_id
			 where	ac.account_collection_type = 'unix-group'
			  and	ug.unix_gid = ?
		}) || die $dbh->errstr;
		$idsth->execute($gid) || die $idsth->errstr;
		my ($dbid, $dbname) = ($idsth->fetchrow_array)[0, 1];
		$idsth->finish;
		if(defined($dbid) && $dbname) {
			warn "skipping gid $gid (db $dbname (id#$dbid)\n"; 
			next;
		}

		my $sth = $dbh->prepare_cached(qq{
			WITH ins as (
				insert into account_collection
					(account_collection_name, account_collection_type)
				values
					(:acname, 'unix-group')
				returning account_collection_id
			) SELECT account_collection_id from ins
		}) || die $dbh->errstr;
		$sth->bind_param(':acname', $name) || die $sth->errstr;
		# NOTE: This does not work in oracle!
		$sth->execute || die $sth->errstr;
		my($acid) = $sth->fetchrow_array || die "could not get acid";
		$sth->finish;

		$sth = $dbh->prepare_cached(qq{
				insert into unix_group (
					account_collection_id, 
					unix_gid, group_password
				) values (
					:ac_id,
					:gid, :pwd
				)
		}) || die $dbh->errstr;

		$pwd = undef if($pwd && $pwd =~ /^.$/);
		$sth->bind_param(':gid', $gid) || die $sth->errstr;
		$sth->bind_param(':pwd', $pwd) || die $sth->errstr;
		$sth->bind_param(':ac_id', $acid) || die $sth->errstr;
		$sth->execute || die $sth->errstr;

		$g->{$name}->{id} = $acid;
	}
	$fh->close;
	$g;
}

sub add_user {
	my($dbh, $dude, $gecos, $type) = @_;

	$gecos =~ s/&/$dude/g;

	# if user is there, do nothing.
	# need to have bjech's magical name matching logic apply.

	# NOTE: XXX - this needs to distinguish between people and non-people
	# (pseudousers).  Right not it assumes everyone is a person which is
	# WRONG.
	my $sth = $dbh->prepare_cached(qq{
		begin
			PERFORM person_manip.add_person (
				__person_id => :id,
				login => :login,
				p_first_name => :first,
				p_middle_name => :middle,
				p_last_name => :last,
				is_manager => 'N',
				is_exempt => 'N',
				is_full_time => 'N',
				person_company_relation => 'employee'
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

	my ($id, $empid);
	$sth->bind_param_inout(':id', \$id, 50) || die $sth->errstr;
	$sth->execute || die $sth->errstr;
	$id;
}

sub do_work {
	my $dbh = JazzHands::DBI->connect('import-passwd', {AutoCommit=>0}) || confess "Connect to DB: ", $JazzHands::DBI::errstr;

	#
	# XXX - needs to be converted to arguments, and also
	#
	my $group="group";
	#my $passwd="master.passwd";
	my $passwd="/etc/passwd";
	my $shadow="shadow";

	# my $fmt = "shadow";
	# my $fmt = "masterpasswd";
	my $fmt = "passwd";

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
		} elsif($fmt eq 'passwd') {
			($dude,$crypt,$uid,$gid,$gecos,$home,$shell) = @f[0,1,2,3,4,5,6];
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
				select	account_id
				 from	account
				where	login = ?
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
						?,
						?,
						?
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
					insert into account_unix_info (
						system_user_id,
						unix_uid,
						unix_group_acct_collection_id,
						shell,
						default_home
					) values (
						?,
						?,
						?,
						?,
						?
					)
				}) || die $dbh->errstr;
				$sth->execute($suid,$uid,$dbgid,$shell,$home) || die $sth->errstr;
			}
		}
	}

	$dbh->commit;
	$dbh->disconnect;
}
