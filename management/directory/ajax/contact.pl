#!/usr/pkg/bin/perl

use strict;
use warnings;
use CGI;
use JSON::PP;

BEGIN { unshift(@INC, "/Users/kovert"); };

use JazzHands::DBI;

exit do_work();

sub do_work {
	my $dbh = JazzHands::DBI->connect('directory', {AutoCommit => 0}) ||
		die $JazzHands::DBI::errstr;

	my $cgi = new CGI;

	my $type = $cgi->param('type');

	my $r = {};

	if($type) {
		my $sth = $dbh->prepare_cached(qq{
			select	person_contact_technology
			  from	val_person_contact_technology
			 where	person_contact_type = ?
		}) || die $dbh->errstr;

		$sth->execute($type) || die $sth->errstr;

		while(my ($tech) = $sth->fetchrow_array) {
			push(@{$r->{technologies} }, $tech);
		}
		$sth->finish;

		$sth = $dbh->prepare_cached(qq{
			select	person_contact_location_type
			  from	val_person_contact_loc_type
		}) || die $dbh->errstr;

		$sth->execute || die $sth->errstr;

		while(my ($tech) = $sth->fetchrow_array) {
			push(@{$r->{locations} }, $tech);
		}
		$sth->finish;
		$r->{error} = undef;

		push(@{$r->{privacy} }, 'PRIVATE');
		push(@{$r->{privacy} }, 'PUBLIC');
		push(@{$r->{privacy} }, 'HIDDEN');

		# country codes
		$sth = $dbh->prepare_cached(qq{
			select	iso_country_code,
				iso_country_code || ': +' ||
					dial_country_code as display
			  from	val_country_code
			  where ( display_priority > 0 or display_priority is NULL)
			  order by display_priority, iso_country_code
		}) || die $dbh->errstr;

		$sth->execute || die $sth->errstr;

		while(my @x = $sth->fetchrow_array) {
			push(@{$r->{countries} }, \@x);
		}
		$sth->finish;
		$r->{error} = undef;
	} else {
		$r->{error} = "Unknown Type";
	}

	print $cgi->header( -type => 'application/json', -charset => 'utf-8');
	print encode_json ( $r );

	$dbh->rollback;
	$dbh->disconnect;
}
