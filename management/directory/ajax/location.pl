#!/usr/bin/env perl

use strict;
use warnings;
use CGI;
use JSON::PP;
use Data::Dumper;
BEGIN { unshift(@INC, "/Users/kovert"); };

use JazzHands::Common qw(:all);

use JazzHands::DBI;

exit do_work();

sub get_login {
	my($dbh, $personid) = @_;

	my $sth = $dbh->prepare_cached(qq{
	       select  a.login
		 from   v_corp_family_account a
			inner join v_person_company_expanded pc
				using (person_id)
		where   person_id = ?
		and     pc.company_id in (
				select  property_value_company_id
				  from  property
				 where  property_name = '_rootcompanyid'
				   and  property_type = 'Defaults'
			)
	}) || die $dbh->errstr;
	$sth->execute($personid) || die $sth->errstr;
	my $login = ($sth->fetchrow_array)[0];
	$sth->finish;
	$login;
}


# XXX - need to move to a library; this is shared in a few plces
sub check_admin {
	my ($dbh, $login) = @_;

	my $sth = $dbh->prepare_cached(qq {
		select  count(*) as tally
		 from   property p
			inner join account_collection ac
				on ac.account_collection_id =
					p.property_value_account_coll_id
			inner join v_acct_coll_acct_expanded ae
				on ae.account_collection_id =
					ac.account_collection_id
			inner join v_corp_family_account a
				on ae.account_id = a.account_id
		 where  p.property_name = 'PhoneDirectoryAdmin'
		  and   p.property_type = 'PhoneDirectoryAttributes'
		  and   a.login = ?
	}) || die $dbh->errstr;

	$sth->execute($login) || die $sth->errstr;
	my $hr = $sth->fetchrow_hashref();
	$sth->finish;

	if($hr && $hr->{tally} > 0) {
		return 1;
	} else {
		return 0;
	}
}

sub do_work {
	my $dbh = JazzHands::DBI->connect('directory_rw', {AutoCommit => 0}) ||
		die $JazzHands::DBI::errstr;

	my $cgi = new CGI;

	# figure out if person is an admin or editing themselves
	my $personid = $cgi->param('person_id');

	my $commit = 1;
	my $r = do_location_manip($dbh, $cgi);

	print $cgi->header( -type => 'application/json', -charset => 'utf-8');
	print encode_json ( $r );

	if($commit) {
		$dbh->commit;
	} else {
		$dbh->rollback;
	}
	$dbh->disconnect;
}

################

sub do_location_manip {
	my($dbh, $cgi) = @_;

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
		my $login = get_login($dbh, $personid);
		if($cgi->remote_user() ne $login && !check_admin($dbh, $cgi->remote_user())) {
			$r->{error} = "You are not permitted to manipulate this user.";
			return $r;
		}
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

		my $diff = JazzHands::Common::GenericDB::hash_table_diff(undef, $hr, $nt);

		my @error;
		my $ x = JazzHands::Common::GenericDB::DBUpdate(undef,
			dbhandle => $dbh, 
			table => 'person_location', 
			dbkey => 'person_location_id', 
			keyval => $locid, 
			hash => $diff,
			error => \@error
		);
		$r->{success} = $x;
	}
	$r;
}

