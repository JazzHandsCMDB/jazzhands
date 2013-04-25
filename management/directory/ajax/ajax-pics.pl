#!/usr/bin/env perl

use strict;
use warnings;
use CGI;
use JSON::PP;

BEGIN { unshift(@INC, "/Users/kovert"); };

use JazzHands::DBI;
use Data::Dumper;

exit do_work();

sub get_login {
	my($dbh, $personid) = @_;

	my $sth = $dbh->prepare_cached(qq{
	       select  a.login
		 from   account a
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
	# There is no reason to check for admin here
	$r->{error} = "You are not permitted to manipulate this user.";
	$r = do_pic_manip($dbh, $cgi);

	print $cgi->header( -type => 'application/json', -charset => 'utf-8');
	print encode_json ( $r );

	if($commit) {
		$dbh->commit;
	} else {
		$dbh->rollback;
	}
	$dbh->disconnect;
}

######################

sub do_pic_manip {
	my($dbh, $cgi) = @_;

	my $personid = $cgi->param('person_id');

	my $sth = $dbh->prepare_cached(qq{
		select	pi.person_image_id,
			pi.person_image_order,
			pi.image_label,
			pi.description,
			piu.person_image_usage
		 from	person_image pi
			left join person_image_usage piu
				USING (person_image_id)
	   where	pi.person_id = ?
	}) || die $dbh->errstr;

	$sth->execute($personid) || die $sth->errstr;

	my $r = {};

	my $lastid;
	my $x;
	while(my $hr = $sth->fetchrow_hashref) {
		if(! $x) {
			$x = {};
		}

		if(!$x->{person_image_id} || $x->{person_image_id} != $hr->{person_image_id}) {
			if(defined($x->{person_image_id})) {
				push(@ {$r->{pics}}, $x);
			}
			$x = {};
			$x->{ person_image_id } = $hr->{person_image_id};
			$x->{ person_image_order } = $hr->{person_image_order};
			$x->{ image_label } = $hr->{image_label};
			$x->{ description } = $hr->{description};
			
		}
		push (@{ $x->{ person_image_usage } }, $hr->{person_image_usage});
	}

	if(defined($x)) {
		push(@ {$r->{pics}}, $x);
	}

	$sth = $dbh->prepare_cached(qq{
		select  person_image_usage, is_multivalue
		  from  val_person_image_usage 
	}) || die $dbh->errstr;

	$sth->execute || die $dbh->errstr;

	while(my $hr = $sth->fetchrow_hashref) {
		push(@{$r->{valid_usage}}, $hr);
	}


	$r->{error} = undef;
	$r;
}
