#!/usr/bin/env perl

use strict;
use warnings;
use CGI;
use JSON::PP;

BEGIN { unshift(@INC, "/Users/kovert"); };

use JazzHands::DBI;
use Data::Dumper;

exit do_work();

sub do_work {
	my $dbh = JazzHands::DBI->connect('directory', {AutoCommit => 0}) ||
		die $JazzHands::DBI::errstr;

	my $cgi = new CGI;

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


	$r->{error} = 'Error!';
	$r->{error} = undef;

	print $cgi->header( -type => 'application/json', -charset => 'utf-8');
	print encode_json ( $r );

	$dbh->rollback;
	$dbh->disconnect;
}
