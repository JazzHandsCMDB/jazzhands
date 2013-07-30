#!/usr/bin/env perl
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
use Getopt::Long;
use FileHandle;
use JSON::PP;

exit do_work();

sub add_key($$$$) {
	my($dbh, $instid, $key, $val) = @_;


	my $sth = $dbh->prepare(q{
			insert into appaal_instance_property (
					appaal_instance_id,
					app_key,
					app_value
				) values (
					?,
					?,
					?
				)
	}) || die $dbh->errstr;

	my $nr = $sth->execute( $instid, $key, $val ) || die $dbh->errstr;
	$sth->finish;
	$nr;
}

sub check_key($$) {
	my($dbh, $key) = @_;

	my $sth = $dbh->prepare(q{
		select count(*) 
		  from val_app_key
		 where app_key = ?
	}) || die $dbh->errstr;

	$sth->execute( $key ) || die $dbh->errstr;

	my $tally = ($sth->fetchrow_array)[0];
	$sth->finish;
	$tally;
}

sub get_instance($$) {
	my($dbh, $appid, $state) = @_;

	my $sth = $dbh->prepare(q{
		select appaal_instance_id 
		  from appaal_instance
		 where appaal_id = ?
		   and service_environment = ?
	}) || die $dbh->errstr;

	$sth->execute( $appid, $state ) || die $dbh->errstr;

	my $id = ($sth->fetchrow_array)[0];
	$sth->finish;
	$id;
}

sub add_instance($$$) {
	my($dbh, $app, $env) = @_;

	if(my $id = get_app($dbh, $app)) {
		return $id;
	}

	my $sth = $dbh->prepare(q{
		WITH ins AS (
			insert into appaal_instance (
					appaal_id,
					service_environment,
					file_mode,
					file_owner_account_id,
					file_group_acct_collection_id
				) values (
					?,
					?,
					0755,
					(select account_id from account where login = 'root'),
					(select account_collection_id from account_collection
					 where account_collection_name = 'root'
					   and account_collection_type = 'per-user'
					)
				)
			returning *
		) select appaal_instance_id from ins
	}) || die $dbh->errstr;

	$sth->execute( $app, $env ) || die $dbh->errstr;

	my $id = ($sth->fetchrow_array)[0];
	$sth->finish;
	$id;
}

#
# apps themselves
#
sub get_app($$) {
	my($dbh, $app) = @_;

	my $sth = $dbh->prepare(q{
		select appaal_id from appaal where appaal_name = ?
	}) || die $dbh->errstr;

	$sth->execute( $app ) || die $dbh->errstr;

	my $id = ($sth->fetchrow_array)[0];
	$sth->finish;
	$id;
}

sub add_app($$) {
	my($dbh, $app) = @_;

	if(my $id = get_app($dbh, $app)) {
		return $id;
	}

	my $sth = $dbh->prepare(q{
		WITH ins AS (
			insert into appaal (appaal_name) values (?)
			returning *
		) select * from ins
	}) || die $dbh->errstr;

	$sth->execute( $app ) || die $dbh->errstr;

	my $id = ($sth->fetchrow_array)[0];
	$sth->finish;
	$id;
}

sub add_dc($$$) {
	my($dbh, $instid, $mclass) = @_;

	my $sth = $dbh->prepare(q{
			insert into appaal_instance_device_coll (
				device_collection_id, 
				appaal_instance_id
			) values (
				(select device_collection_id
				   from device_collection
				  where	device_collection_name = ?
				    and	device_collection_type = 'mclass'
				),
				?
			)
	}) || die $dbh->errstr;

	my $nr = $sth->execute( $mclass, $instid ) || die $dbh->errstr;
	$sth->finish;
	$nr;
}


sub do_work {
	my $dbh = JazzHands::DBI->connect('import-passwd', {AutoCommit=>0}) || confess "Connect to DB: ", $JazzHands::DBI::errstr;

	my $mclass;
	my $jsondir;

	GetOptions(
		"mclass=s",	\$mclass,
		"dir=s",	\$jsondir,
	) || die "bad options";

	die "must specify --mclass= " if(!$mclass);

	foreach my $app (@ARGV) {
		my $fn = "$jsondir/${app}.json";

		my $fh = new FileHandle($fn) || die "$fn: $!";

		my $json = join("", $fh->getlines);
		$fh->close;

		my $apph = decode_json( $json );

		my $appid = add_app($dbh, $app);
		my $instid = add_instance ($dbh, $appid, 'production');

		foreach my $key (keys(%{$apph->{options}})) {
			my $val = $apph->{'options'}->{$key};
			if(check_key($dbh, $key) ) {
				add_key($dbh, $instid, $key, $val);
			} else {
				warn "skipping key $key\n";
			}
		}

		foreach my $list (@{$apph->{database}}) {
			foreach my $key (sort keys(%$list)) {
				my $val = $list->{$key};
				if(check_key($dbh, $key) ) {
					add_key($dbh, $instid, $key, $val);
				} else {
					warn "skipping key $key\n";
				}
			}
			last;	# XXX - only support one databsae just now
		}
		add_dc($dbh, $instid, $mclass);
	}


	$dbh->commit;
	$dbh->disconnect;
}
