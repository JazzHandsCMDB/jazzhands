#!/usr/bin/env perl

use strict;
use warnings;
use CGI;
use JSON::PP;

BEGIN { unshift(@INC, "/Users/kovert"); };

use JazzHands::DBI;

exit do_work();

sub get_login {
	my($dbh, $personid) = @_;

	my $sth = $dbh->prepare_cached(qq{
	       select  lower(a.login) as login
		 from   v_corp_family_account a
		where   person_id = ?
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
		  and   lower(a.login) = lower(?)
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

sub get_pic_owner {
	my($dbh, $contactid) = @_;

	my $sth = $dbh->prepare(qq{
		select	person_id
		 from	person_contact
		where	person_contact_id = ?
	}) || die $dbh->errorstr();

	$sth->execute($contactid) || die $sth->errstr;
	my $r = ($sth->fetchrow_array)[0];
	$sth->finish;
	$r;
}

sub do_work {
	my $cgi = new CGI;

	my $dbh = JazzHands::DBI->connect('directory_rw', {AutoCommit => 0}) ||
		die $JazzHands::DBI::errstr;


	# figure out if person is an admin or editing themselves
	my $contactid = $cgi->param('person_contact_id');
	if(!$contactid) {
		die "Must specify a contact id\n";
	}
	my $personid = get_pic_owner($dbh, $contactid);
	if(!$contactid) {
		die "Must specify a valid contact id\n";
	}
	my $login = get_login($dbh, $personid);

	my $commit = 0;

	my $r;
	if($cgi->remote_user() ne $login && !check_admin($dbh, $cgi->remote_user())) {
		$r = {};
		$r->{error} = "You are not permitted to manipulate this user.";
		$commit = 0;
	} else {
		$r = do_remove_number($dbh, $cgi);
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

sub do_remove_number {
	my($dbh, $cgi) = @_;

	my $contactid = $cgi->param('person_contact_id');

	my $sth = $dbh->prepare_cached(qq{
		delete	from person_contact
		 where	person_contact_id = ?
	}) || die $dbh->errstr;

	my $nr = $sth->execute($contactid) || die $sth->errstr;

	my $r = {};
	$r->{error} = undef;
	# XXX - note if it didn't suceed?
	if($nr >= 1) {
		$r->{error} = undef;
	} else {
		$r->{error} = undef;
	}
	$r;
}

