#!/usr/bin/env perl
#
# Copyright (c) 2014 Todd Kover
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and

#
# $Id$
#

use strict;
use warnings;
use FileHandle;
use CGI;
use JazzHands::STAB;
use Data::Dumper;
use JSON::PP;

do_netcol_ajax();

sub do_netcol_ajax {
	my $stab = new JazzHands::STAB( ajax => 'yes' )
	  || die "Could not create STAB";
	my $cgi = $stab->cgi || die "Could not create cgi";
	my $passedin = $stab->cgi_parse_param('passedin') || undef;

	my $mime = $stab->cgi_parse_param('MIME_TYPE') || 'text';
	my $what = $stab->cgi_parse_param('what')      || 'none';

	#
	# passedin contains all the arguments that were passed to the original
	# calling page.  This is sort of gross but basically is used to ensure
	# that fields that were filled in get properly filled in on error
	# conditions that send things back.
	if ($passedin) {
		$passedin =~ s/^.*\?//;
		foreach my $pair ( split( /[;&]/, $passedin ) ) {
			my ( $var, $val ) = split( /=/, $pair, 2 );
			next if ( $var eq 'devid' );
			next if ( $var eq '__notemsg__' );
			next if ( $var eq '__errmsg__' );
			$val = $cgi->unescape($val);
			$cgi->param( $var, $val );
		}
	}

	if ( $mime eq 'xml' ) {
		print $cgi->header("text/xml");
		print '<?xml version="1.0" encoding="utf-8" ?>', "\n\n";
	} elsif ( $mime ne 'json' ) {
		print $cgi->header("text/json");
	} else {
		print $cgi->header("text/html");
	}

	$what = "" if ( !defined($what) );

	if ( $what eq 'Collections' ) {
		my $type  = $stab->cgi_parse_param('type');
		my $r = {};
		$r->{'NETBLOCK_COLLECTIONS'} = {};
		my $sth = $stab->prepare(
			qq{
			select  netblock_collection_id,
				netblock_collection_name, description
			  from  netblock_collection
			where	netblock_collection_type = ?
			order by netblock_collection_name, 
				netblock_collection_type,
				netblock_collection_id
		}
		);
		$sth->execute($type) || die $sth->errstr;
		my $j = JSON::PP->new->utf8;
		while ( my ( $id, $name, $desc ) = $sth->fetchrow_array ) {
			$r->{'NETBLOCK_COLLECTIONS'}->{$id} = "$name".
				(($desc)?" - $desc":"");
		}
		print $j->encode($r);
	} else {
		# catch-all error condition
		print $cgi->div(
			{ -style => 'text-align: center; padding: 50px', },
			$cgi->em("not implemented yet.") );
	}

	if ( $mime eq 'xml' ) {
		print "</response>\n";
	}

	my $dbh = $stab->dbh;
	if ( $dbh && $dbh->{'Active'} ) {
		$dbh->commit;
	}
	undef $stab;
}
