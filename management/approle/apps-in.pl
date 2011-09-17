#!/usr/local/bin/perl
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

#
# Audits a sheet of a defined format against db
#

use strict;
use warnings;
use JazzHands::DBI;
use Data::Dumper;
use Carp;
use FileHandle;

my $in = "applications";

exit do_work();

sub lookfor {
	my($dbh, $name) = @_;

	my $findSth = $dbh->prepare_cached(qq{
		select	device_collection_id
		  from	device_collection
		 where	name = ?
		  and	device_collection_type = 'appgroup'
	}) || die $dbh->errstr;

	$findSth->execute($name) || die $findSth->errstr;
	my ($id) = $findSth->fetchrow_array;
	$findSth->finish;
	$id;
}

sub do_work {
	my $dbh = JazzHands::DBI->connect('apps', {AutoCommit=>0}) || confess;

#	{
#		my $dude = (getpwuid($<))[0] || 'unknown';
#		my $q = qq{ 
#			begin
#				dbms_session.set_identifier ('$dude');
#			end;
#		};
#		if(my $sth = $dbh->prepare($q)) {
#			$sth->execute || confess $sth->errstr;
#		}
#	}

	my ($parentid, $lastindent) = (undef, 0);
	my(@parentage);

	my $fh = new FileHandle($in) || die "$in: $!";

	my $DCsth = $dbh->prepare_cached(qq{
		insert into device_collection 
			(name, device_collection_type,SHOULD_GENERATE_SUDOERS)
		values
			(:name, 'appgroup', 'N')
		returning device_collection_id 
	}) || die $dbh->errstr;
	# INTO missing

	my $HRsth = $dbh->prepare_cached(qq{
		insert into device_collection_hier
			(PARENT_DEVICE_COLLECTION_ID, DEVICE_COLLECTION_ID
			)
		values
			(?, ?)
	}) || die $dbh->errstr;

	while(my $line = $fh->getline) {
		next if($line =~ /^\s*#/);
		next if($line =~ /^\s*$/);
		chomp($line);
		next if($line =~ /^\s*$/);
		my($indent, $name) = ($line =~ /^(\t+)-\s*(\S.+)\s*$/);

		my $li = length($indent);


		for(my $i = $lastindent; $i >= $li; $i--) {
			pop(@parentage);
		}
		my $parent = $parentage[$#parentage] || "";

		print "$#parentage $lastindent $li add $name, parent is ", (($parent)?$parent:"--none--"), "\n";
		$lastindent = $li;

		# if it already exists, skip, it means we're inserting new
		# child records.  If new parentage is inserted this can cause
		# dogs and cats to be living together.
		my $id = lookfor($dbh, $name);
		if(!$id) {
			$id = 0; 	# wtf?
			$DCsth->bind_param(":name", $name) || die $DCsth->errstr;
			# $DCsth->bind_param_inout(':dcid', \$id, 50) || die $DCsth->errstr;
			$DCsth->execute || die $DCsth->errstr, "-- $name";
			$id = $DCsth->fetch()->[0];
			warn "id is totally $id\n";
			$DCsth->finish;

			if($parent) {
				$HRsth->execute($parent, $id) || die $HRsth->errstr;
			}
		}
		push(@parentage, $id);
		
	}
	$fh->close;

	$dbh->commit;
	$dbh->disconnect;
}
