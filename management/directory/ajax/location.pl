#!/usr/bin/env perl

use strict;
use warnings;
use CGI;
use JSON::PP;
use Data::Dumper;
BEGIN { unshift(@INC, "/Users/kovert"); };

use JazzHands::GenericDB;

use JazzHands::DBI;

exit do_work();

sub do_work {
	my $dbh = JazzHands::DBI->connect('directory', {AutoCommit => 0}) ||
		die $JazzHands::DBI::errstr;

	my $cgi = new CGI;

	my $r = {};

	my $personid = $cgi->param('person_id');
	my $locid = $cgi->param('person_location_id');

	if(!$locid) {

		my $sth = $dbh->prepare(qq{
			select	person_id,
				person_location_id,
				site_code,
				physical_address_id,
				display_label,
				building,
				floor,
				section,
				seat_number
			  from	person_location
				inner join physical_address using (physical_address_id)
			 where	person_id = ?
		}) || die $dbh->errstr;

		$sth->execute($personid) || die $dbh->errstr;

		my $hr = $sth->fetchrow_hashref;

		if($hr) {
			$r->{record} = $hr;
		}

		$r->{error} = undef;

		$sth->finish;
	} else {
		my $building = $cgi->param("building_$locid");
		my $floor = $cgi->param("floor_$locid");
		my $section = $cgi->param("section_$locid");
		my $seat = $cgi->param("seat_number_$locid");

		my $sth = $dbh->prepare_cached(qq{
			select * 
			  from person_location 
			 where person_location_id = ?
		}) || die $dbh->errstr;

		$sth->execute($locid) || die $sth->errstr;
		my $hr = $sth->fetchrow_hashref;
		$sth->finish;

		if(!$hr) {
			die "can not find $locid\n";
		}

		my $nt = {
			person_id => $personid,
			person_location_id => $locid,
			building => $building,
			floor => $floor,
			section => $section,
			seat_number => $seat,
		};

		my $diff = JazzHands::GenericDB::hash_table_diff(undef, $hr, $nt);

		warn Dumper($diff);

		my @error;
		my $ x = JazzHands::GenericDB::DBUpdate(undef,
			dbhandle => $dbh, 
			table => 'person_location', 
			dbkey => 'person_location_id', 
			keyval => $locid, 
			hash => $diff,
			error => \@error
		);
		$r->{success} = $x;
		warn Dumper($r, "error: ", \@error);
	}
	print $cgi->header( -type => 'application/json', -charset => 'utf-8');
	print encode_json ( $r );

	$dbh->commit;
	$dbh->disconnect;
}
