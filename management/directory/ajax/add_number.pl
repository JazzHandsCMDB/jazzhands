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

	my $r = {};

	my $personid = $cgi->param('person_id');
	my $loc = $cgi->param('locations');
	my $tech = $cgi->param('technology');
	my $privacy = $cgi->param('privacy');
	my $country = $cgi->param('country');
	my $phone = $cgi->param('phone');
	my $pin = $cgi->param('pin');

	# grey'd out defaults
	$phone = undef if($phone eq 'phone');
	$pin = undef if($pin eq 'pin');
	
	my $sth = $dbh->prepare_cached(qq{
		select dial_country_code
		  from	val_country_code
		 where	iso_country_code = ?
	}) || die $dbh->errstr;

	$sth->execute($country) || die $dbh->errstr;
	my $cc = ($sth->fetchrow_array)[0];
	$sth->finish;

	$sth = $dbh->prepare_cached(qq{
		insert into person_contact (
			person_id, 
			person_contact_type,
			person_contact_technology,
			person_contact_location_type, 
			person_contact_privacy,
			iso_country_code,
			phone_number,
			phone_pin,
			person_contact_order
		) values (
			?, ?,
			?,
			?,
			?,
			?,
			?,
			?,
			(select max(person_contact_order) + 1
			   from	person_contact
			  where	person_id = ?
			)
		) RETURNING person_contact_id
	}) || die $dbh->errstr;
	$sth->execute(
		$personid, 
		'phone',
		$tech,
		$loc,
		$privacy,
		$country,
		$phone,
		$pin,
		$personid,
	) || die $sth->errstr;

	my $pimgid = $sth->fetch()->[0] || die "unable to get image_id";
	$sth->finish;

	$r->{record}->{person_contact_id} = $pimgid;
	$r->{record}->{technology} = $tech;
	$r->{record}->{country} = $country;
	$r->{record}->{phone} = $phone;
	$r->{record}->{pin} = $pin;
	$r->{record}->{privacy} = $privacy;
	$r->{record}->{print_title} = "$tech($loc)";
	$r->{record}->{print_number} = "+$cc $phone";

	# need to deal with HIDDEN like php
	if($privacy ne 'PUBLIC') {
		$r->{record}->{print_number} .= " ($privacy)"
	}

	$r->{error} = 'No Permission';
	$r->{error} = undef;

	print $cgi->header( -type => 'application/json', -charset => 'utf-8');
	print encode_json ( $r );

	$dbh->commit;
	$dbh->disconnect;
}
