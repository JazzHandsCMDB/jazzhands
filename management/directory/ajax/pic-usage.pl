#!/usr/bin/env perl

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

	my $pii = $cgi->param('person_image_id');

	my $r = {};

	my $sth = $dbh->prepare_cached(qq{
		select	vpiu.person_image_usage,
			vpiu.is_multivalue,
			case WHEN piu.person_image_id is NULL
				THEN 'N'
				ELSE 'Y'
			END as is_set
		  from	val_person_image_usage vpiu
			left join person_image_usage piu
			 on piu.person_image_usage =
				vpiu.person_image_usage
			and person_image_id = ?
	}) || die $dbh->errstr;

	$sth->execute($pii) || die $sth->errstr;

	while(my $hr = $sth->fetchrow_hashref) {
		push(@{$r->{usage} }, $hr);
	}
	$sth->finish;

	$r->{error} = undef;

	print $cgi->header( -type => 'application/json', -charset => 'utf-8');
	print encode_json ( $r );

	$dbh->rollback;
	$dbh->disconnect;
}
