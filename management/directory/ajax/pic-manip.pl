#!/usr/bin/env perl

use strict;
use warnings;
use CGI;
use JSON::PP;
use Carp;
use Data::Dumper;

BEGIN { unshift(@INC, "/Users/kovert"); };

use JazzHands::DBI;
use JazzHands::Common qw(:db);

exit do_work();

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

sub do_work {
	my $cgi = new CGI;

	my $dbh = JazzHands::DBI->connect('directory', {AutoCommit => 0}) ||
		die $JazzHands::DBI::errstr;


	# figure out if person is an admin or editing themselves
	my $personid = $cgi->param('person_id');
	my $login = get_login($dbh, $personid);

	my $commit = 0;

	my $r;
	if($cgi->remote_user() ne $login && !check_admin($dbh, $cgi->remote_user() )) {
		$r = {};
		$r->{error} = "You are not permitted to manipulate this user.";
		$commit = 0;
		print $cgi->header( -type => 'application/json', -charset => 'utf-8');
		print encode_json ( $r );
	} else {
		do_pic_manip($dbh, $cgi);
		$commit = 1;
	}


	if($commit) {
		$dbh->commit;
	} else {
		$dbh->rollback;
	}
	$dbh->disconnect;
	$cgi->redirect($cgi->referer);
	1;
}

################

sub add_pic {
	my($dbh, $personid, $fn, $description, $formatn) = @_;

	$formatn = $fn if(!defined($formatn));

	my $format;
	if($formatn =~ /\.jpe?g$/i) {
		$format = 'jpeg';
	} else {
		$format = $formatn;
		$format =~ s,^.*\.([^.]+)$,$1,;
		$format =~ tr/A-Z/a-z/;
	}

	my $label = $fn;
	$label =~ s,^.*/([^/]+)$,$1,;

	my $oid = $dbh->pg_lo_import($fn);
	die "unable to import $fn for person $personid" if(!$oid);

	my $max = get_max_order($dbh, $personid);

	my $shasum = `shasum -b -a 256 "$fn"`;
	$shasum = (split(/\s+/, $shasum))[0];

	my $oldid = get_image_by_checksum($dbh, $personid, $shasum);

	if(!$oldid) {
		my $sth = $dbh->prepare_cached(qq{
			insert into person_image (
				person_id, image_type, image_blob, 
				person_image_order,
				image_label, image_checksum, description
			) values (
				?, ?, ?, 
				?,
				?, ?, ?
			) returning person_image_id
		}) || die $dbh->errstr;
		$sth->execute(
			$personid, 
			$format, 
			$oid, 
			$max+1, 
			$label, 
			$shasum, 
			$description) || die $sth->errstr;
		my$picid = $sth->fetch()->[0];
		$sth->finish;
		$picid
	} else {
		$oldid;
	}
}

sub has_pic_usage {
	my($dbh, $picid, $usage) = @_;

	my $sth = $dbh->prepare_cached(qq{
		select	count(*)
		  from	person_image_usage
		 where	person_image_id = ?
		   and	person_image_usage = ?
	}) || die $dbh->errstr;

	$sth->execute($picid, $usage) || die $sth->errstr;

	my $tally = ($sth->fetchrow_array)[0];
	$sth->finish;
	$tally;
}

sub get_pic_usage {
	my($dbh, $picid) = @_;

	my $sth = $dbh->prepare_cached(qq{
		select	person_image_usage
		 from	person_image_usage
		where	person_image_id = ?
	}) || die $dbh->errstr;

	$sth->execute($picid) || croak $sth->errstr;
	my(@rv);
	while(my($usg) = $sth->fetchrow_array) {
		push(@rv, $usg);
	}
	$sth->finish;
	\@rv;
}


sub add_pic_usage {
	my($dbh, $picid, $usage) = @_;

	return if(has_pic_usage($dbh, $picid, $usage));

	my $sth = $dbh->prepare_cached(qq{
		insert into person_image_usage (
			person_image_id, person_image_usage
		) values (
			?, ?
		)
	}) || die $dbh->errstr;

	$sth->execute($picid, $usage) || croak $sth->errstr;
	$sth->finish;
}

sub remove_pic_usage {
	my($dbh, $picid, $usage) = @_;

	my $sth = $dbh->prepare_cached(qq{
		delete from person_image_usage
		 where	person_image_id = ?
		   and	person_image_usage = ?
	}) || die $dbh->errstr;

	$sth->execute($picid, $usage) || croak $sth->errstr;
	$sth->finish;
}


sub get_image_by_checksum {
	my($dbh, $personid, $checksum) = @_;

	my $sth = $dbh->prepare_cached(qq{
		select	person_image_id
		  from	person_image
		 where	person_id = ?
		   and	image_checksum = ?
	}) || die $dbh->errstr;

	$sth->execute($personid, $checksum) || die $sth->errstr;

	my ($id) = $sth->fetchrow_array;
	$sth->finish;
	$id;
}


sub get_max_order {
	my($dbh, $personid) = @_;

	my $sth = $dbh->prepare_cached(qq{
		select	max(person_image_order)
		  from	person_image
		 where	person_id = ?
	}) || die $dbh->errstr;

	$sth->execute($personid) || die $sth->errstr;

	my $max = ($sth->fetchrow_array)[0];
	$sth->finish;
	defined($max)?$max:0;
}

sub do_pic_manip {
	my($dbh, $cgi) = @_;

	# print $cgi->header, $cgi->start_html;
	# print $cgi->Dump, $cgi->end_html;  exit;

	my $c = new JazzHands::Common;
	$c->DBHandle($dbh);

	my $personid = $cgi->param("person_id");

	my @errs;
	foreach my $row (@{$c->DBFetch(
			table => 'person_image',
			match => { person_id => $personid },
			errors => \@errs)}) {
		my $picid = $row->{person_image_id};

		# objects with no person image usage at all will not show up as params,
		# so need to look at the db and see if usage is still set.
		my $oldusg = get_pic_usage($dbh, $picid);
		my @newusg = $cgi->param("person_image_usage_$picid");

		foreach my $usg (@$oldusg) {
			if( ! grep($_ eq $usg, @newusg)) {
				remove_pic_usage($dbh, $picid, $usg);
			}
		}

		# also check to see if other fields (such as description) were changed
		my $d = $cgi->param("description_$picid");

		my $new = {
			description => $d,
		};
		my $diff = $c->hash_table_diff($row, $new);
		if(scalar %$diff) {
			$c->DBUpdate(
				table => 'person_image',
				dbkey => 'person_image_id',
				keyval => $picid,
				hash => $diff,
				errs => \@errs,
			) || die join(" ", @errs);
		}

	}

	# remove usage from things that have it off
	foreach my $param ($cgi->param) {
		if($param =~ /^person_image_usage_(\d+)/) {
			my $picid = $1;
			my $oldusg = get_pic_usage($dbh, $picid);
			my @newusg = $cgi->param("person_image_usage_$picid");

			foreach my $usg (@$oldusg) {
				if( ! grep($_ eq $usg, @newusg)) {
					remove_pic_usage($dbh, $picid, $usg);
				}
			}
		}
	}

	# add any new paramters
	foreach my $param ($cgi->param) {
		if($param =~ /^newpic_file_(\d+)/) {
			my $offset = $1;
			my $fn = $cgi->param($param);
			my $tfn = $cgi->tmpFileName($fn);

			my $description = $cgi->param("new_description_$offset");

			my @usg = $cgi->param("new_person_image_usage_$offset");
			if(my $picid = add_pic($dbh, $personid, $tfn, $description, $fn)) {
				foreach my $usg (@usg) {
					add_pic_usage($dbh, $picid, $usg);
				}
				#my $sth = $dbh->prepare_cached(qq{
				#	select	person_image_usage
				#  	from	person_image_usage
				# 	where	person_image_id = ?
				#});
			}

		} elsif($param =~ /^person_image_usage_(\d+)/) {
			my $picid = $1;
			my $oldusg = get_pic_usage($dbh, $picid);
			my @newusg = $cgi->param("person_image_usage_$picid");

			foreach my $usg (@newusg) {
				if( ! grep($_ eq $usg, @$oldusg)) {
					add_pic_usage($dbh, $picid, $usg);
				}
			}

		}
	}

	# now go over the old ones and fix things that have changed.
	1;
}

