#!/usr/pkg/bin/perl

use strict;
use warnings;
use CGI;
use JSON::PP;
use Carp;

BEGIN { unshift(@INC, "/Users/kovert"); };

use JazzHands::DBI;

exit do_work();

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

sub do_work {
	my $dbh = JazzHands::DBI->connect('directory', {AutoCommit => 0}) ||
		die $JazzHands::DBI::errstr;

	# XXX - should make sure that this person is PERMITTED to manipulate
	# this picture!!

	my $cgi = CGI->new;

	my $personid = $cgi->param("person_id");

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
				my $sth = $dbh->prepare_cached(qq{
					select	person_image_usage
				  	from	person_image_usage
				 	where	person_image_id = ?
				});
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

	# print $cgi->header, $cgi->start_html;
	# print $cgi->Dump, $cgi->end_html; 
	$dbh->commit;
	$dbh->disconnect;
	$cgi->redirect($cgi->referer);
}
