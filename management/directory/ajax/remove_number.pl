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

	my $contactid = $cgi->param('person_contact_id');

	my $sth = $dbh->prepare_cached(qq{
		delete	from person_contact
		 where	person_contact_id = ?
	}) || die $dbh->errstr;

	my $nr = $sth->execute($contactid) || die $sth->errstr;

	# permissions check...
	# $r->{error} = "No Permission for contact $contactid";

	my $r = {};
	$r->{error} = undef;
	# XXX - note if it didn't suceed?
	if($nr >= 1) {
		$r->{error} = undef;
	} else {
		$r->{error} = undef;
	}

	print $cgi->header( -type => 'application/json', -charset => 'utf-8');
	print encode_json ( $r );

	$dbh->commit;
	$dbh->disconnect;
}
