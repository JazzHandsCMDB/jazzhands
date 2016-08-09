#!/usr/bin/env perl

use strict;
use warnings;
use CGI;
use JSON::PP;

BEGIN { unshift(@INC, "/Users/kovert"); };

use JazzHands::DBI;

exit do_work();

sub get_people($$) {
	my ($dbh, $searchfor) = @_;

	my $s = "$searchfor%";

	my $sth = $dbh->prepare_cached(qq{
		select	DISTINCT p.person_id,
				coalesce(p.preferred_first_name, p.first_name) as first_name,
				coalesce(p.preferred_last_name, p.last_name) as last_name,
				p.nickname
		 from	person p
				inner join v_corp_family_account a
					using (person_id)
	   where	( a.account_type = 'person' and a.account_role = 'primary' )
		and a.is_enabeld = 'Y'
		and	(
				lower(p.first_name || ' ' || p.last_name) like :search
			or
				lower(p.preferred_first_name || ' ' || p.preferred_last_name) 
					like :search
			or
				lower(p.first_name || ' ' || p.preferred_last_name) 
					like :search
			or
				lower(p.preferred_first_name || ' ' || p.last_name) 
					like :search
			or
				lower(p.last_name) like :search
			or
				lower(p.preferred_last_name) like :search
			or
				lower(p.nickname) like :search
			)
	   order by	last_name, first_name
	   LIMIT 10
	}) || die $dbh->errstr;

	$sth->bind_param(':search', $s) || die $sth->errstr;

	# XXX - need to process nicknames and maybe add pictures
	$sth->execute || die $sth->errstr;

	my(@rv);
	while(my $hr = $sth->fetchrow_hashref) {
		push(@rv, $hr);
	}
	@rv;
}

sub get_images($$) {
	my($dbh, $personid) = @_;

	my $sth = $dbh->prepare_cached(qq{
		SELECT	person_image_id, person_id
		FROM	person_image
		  		INNER JOIN person_image_usage USING (person_image_id)
		WHERE	person_image_usage = 'corpdirectory'
		AND		person_id = ?
		order by person_id, person_image_id
		LIMIT 1
	}) || die $dbh->errstr;

	$sth->execute($personid) || die $sth->errstr;
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_location($$) {
	my($dbh, $personid) = @_;

	my $sth = $dbh->prepare_cached(qq{
		SELECT	pl.person_id, pa.physical_address_id,
				pa.display_label
		 FROM	person_location pl
				INNER JOIN physical_address pa USING (physical_address_id)
		where   pl.person_location_type = 'office'
		and		pl.person_id = ?
		order by site_rank
		LIMIT 1
	}) || die $dbh->errstr;

	$sth->execute($personid) || die $sth->errstr;
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub do_work {
	my $dbh = JazzHands::DBI->connect('directory', {AutoCommit => 0}) ||
		die $JazzHands::DBI::errstr;

	my $cgi = new CGI;

	#
	# return something always
	#
	my $r = {};
	$r->{type} = 'person';

	my $searchfor = $cgi->param('find');
	if($searchfor) {
		$searchfor =~ s/\s+/ /g;
		$searchfor =~ tr/A-Z/a-z/;

		my @dudes = get_people($dbh, $searchfor);


		foreach my $dude (@dudes) {
			my $x = {};
			my $pi = get_images($dbh, $dude->{person_id});
			if($pi->{person_image_id}) {
				$x->{img} = "picture.php?person_id=$pi->{person_id}&person_image_id=$pi->{person_image_id}&type=thumb";
			}
			$x->{name} = join(" ", $dude->{first_name}, $dude->{last_name});
			$x->{link} = "contact.php?person_id=" . $dude->{person_id};
			my $pl = get_location($dbh, $dude->{person_id});
			$x->{location} = ($pl)?$pl->{display_label}:"";
			push(@ {$r->{people}}, $x);
		}
	}

	$r->{error} = 'Error!';
	$r->{error} = undef;

	print $cgi->header( -type => 'application/json', -charset => 'utf-8');
	print encode_json ( $r );

	$dbh->rollback;
	$dbh->disconnect;
}
