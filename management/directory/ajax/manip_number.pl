#!/usr/bin/env perl

use strict;
use warnings;
use CGI;
use Data::Dumper;
use JSON::PP;
use JazzHands::Common qw(:db);

BEGIN { unshift(@INC, "/Users/kovert"); };

use JazzHands::DBI;

exit do_work();

sub get_login {
	my($dbh, $personid) = @_;

	my $sth = $dbh->prepare_cached(qq{
		select	a.login
		 from	account a
		 	inner join v_person_company_expanded pc
				using (person_id, company_id)
		where	person_id = ?
                and     company_id = (
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
                        inner join account a
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
	my $cgi = new CGI;

	my $dbh = JazzHands::DBI->connect('directory', {AutoCommit => 0}) ||
		die $JazzHands::DBI::errstr;


	# figure out if person is an admin or editing themselves
	my $personid = $cgi->param('person_id');
	my $login = get_login($dbh, $personid);

	my $commit = 0;

	my $r;
	if($cgi->remote_user() ne $login && !check_admin($dbh, $cgi->remote_user())) {
		$r = {};
		$r->{error} = "You are not permitted to manipulate this user.";
		$commit = 0;
	} else {
		$r = do_db_manip($dbh, $cgi);
		$commit = 1;
	}

	print $cgi->header( -type => 'application/json', -charset => 'utf-8');
	print encode_json ( $r );

	if($commit) {
		$dbh->commit;
	} else {
		$dbh->rollback;
	}
	$dbh->disconnect;
}

sub do_db_manip {
	my $dbh = shift @_;
	my $cgi = shift @_;

	my $c = new JazzHands::Common;

	my $r = {};

	my $personid = $cgi->param('person_id');
	my $pcid = $cgi->param('person_contact_id');
	my $loc = $cgi->param('locations');
	my $tech = $cgi->param('technology');
	my $privacy = $cgi->param('privacy');
	my $country = $cgi->param('country');
	my $phone = $cgi->param('phone');
	my $pin = $cgi->param('pin');
	my $ext = $cgi->param('phone_extension');

	# grey'd out defaults
	if(defined($pin) && (!length($pin) || $pin eq 'pin')) {
		$pin = undef;
	}

	if(defined($ext) && (!length($ext) || $ext eq 'ext')) {
		$ext = undef;
	}

	if(defined($phone) && (!length($phone) || $phone eq 'phone')) {
		$phone = undef;
	}

	my $sth = $dbh->prepare_cached(qq{
		select dial_country_code
		  from	val_country_code
		 where	iso_country_code = ?
	}) || die $dbh->errstr;

	$sth->execute($country) || die $dbh->errstr;
	my $cc = ($sth->fetchrow_array)[0];
	$sth->finish;

	# not updating existing records...
	if(!$pcid) {
		$sth = $dbh->prepare_cached(qq{
			insert into person_contact (
				person_id, 
				person_contact_type,
				person_contact_technology,
				person_contact_location_type, 
				person_contact_privacy,
				iso_country_code,
				phone_number,
				phone_extension,
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
			$ext,
			$pin,
			$personid,
		) || die $sth->errstr;


		$pcid = $sth->fetch()->[0] || die "unable to get image_id";
		$sth->finish;
	} else {
		my $sth = $dbh->prepare_cached(qq{
			select *
			  from	person_contact
			 where	person_contact_id = ?
		}) || die $sth->errstr;
		$sth->execute($pcid) || die $sth->errstr;
		my $hr = $sth->fetchrow_hashref;
		$sth->finish;

		my $n = {
			person_contact_id		=> $pcid,
			person_contact_type		=> 'phone',
			person_contact_technology	=> $tech,
			person_contact_location_type	=> $loc,
			person_contact_privacy		=> $privacy,
			iso_country_code		=> $country,
			phone_number			=> $phone,
			phone_extension			=> $ext,
			phone_pin			=> $pin,
		};

		my $diff = $c->hash_table_diff($hr, $n);
		if(keys $diff > 0) {
			$c->DBUpdate(
				dbhandle => $dbh,
				table => 'person_contact',
				dbkey => 'person_contact_id',
				keyval => $pcid,
				hash => $diff
			);
		}
	}


	$r->{record}->{person_contact_id} = $pcid;
	$r->{record}->{technology} = $tech;
	$r->{record}->{country} = $country;
	$r->{record}->{phone} = $phone;
	$r->{record}->{pin} = $pin;
	$r->{record}->{phone_extension} = $ext;
	$r->{record}->{privacy} = $privacy;
	$r->{record}->{print_title} = "$tech($loc)";
	$r->{record}->{print_number} = "+$cc $phone";

	# need to deal with HIDDEN like php
	if($privacy ne 'PUBLIC') {
		$r->{record}->{print_number} .= " ($privacy)"
	}

	$r->{error} = undef;
	$r;
}
