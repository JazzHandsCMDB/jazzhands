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
use JazzHands::Common qw(_dbx);
use Data::Dumper;
use JSON::PP;

do_acctcol_ajax();

sub do_acctcol_ajax {
	my $stab = new JazzHands::STAB( ajax => 'yes' )
	  || die "Could not create STAB";
	my $cgi      = $stab->cgi || die "Could not create cgi";
	my $passedin = $stab->cgi_parse_param('passedin') || undef;

	my $mime  = $stab->cgi_parse_param('MIME_TYPE') || 'text';
	my $what  = $stab->cgi_parse_param('what')      || 'none';
	my $type  = $stab->cgi_parse_param('type')      || 'none';
	my $query = $stab->cgi_parse_param('query')     || 'none';
	my $id    = $stab->cgi_parse_param('id')        || 'none';

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
		print $cgi->header("application/json");
	} else {
		print $cgi->header("text/html");
	}

	$what = "" if ( !defined($what) );

	if ( $what eq 'Collections' ) {
		my $admin = $stab->check_role('AccountCollectionAdmin');
		my $perms = $stab->get_account_collection_permissions("RO");

		# Assume admin access on development servers
		if( $ENV{'development'} =~ /true/ ) {
			$admin = 1;
		}
		if ( !$admin && !$perms ) {
			$stab->error_return("No permission to edit account collections");
		}

		# if no type is passed in, and user only has access to one type,
		# then assume that one.
		# XXX - handle no type gracefully
		if ( !$admin ) {
			$type = $stab->cgi_parse_param('type');
			if ( ( scalar @{ $perms->{types} } ) == 1 ) {
				$type = ${ $perms->{types} }[0];
			}
		}

		# unused at inception and ripped from netblock collections
		my $r = {};
		$r->{'ACCOUNT_COLLECTIONS'} = {};
		my $sth = $stab->prepare( qq{
			select  account_collection_id,
				account_collection_name, description
			  from  account_collection
			where	account_collection_type = ?
			order by account_collection_name,
				account_collection_type,
				account_collection_id
		}
		);
		$sth->execute($type) || die $sth->errstr;
		my $j = JSON::PP->new->utf8;

		while ( my ( $id, $name, $desc ) = $sth->fetchrow_array ) {
			if ( !$admin && !$stab->check_account_collection_permissions($id) )
			{
				next;
			}
			$r->{'ACCOUNT_COLLECTIONS'}->{$id} =
			  "$name" . ( ($desc) ? " - $desc" : "" );
		}
		print $j->encode($r);
	} elsif ( $what eq 'ExpandMembers' ) {
		my $r   = {};
		my $sth = $stab->prepare_cached( qq{
			SELECT  account_id, first_name, last_name, login
			FROM    v_acct_coll_acct_expanded_detail
					JOIN account USING (account_id)
					JOIN v_person USING (person_id)
			WHERE   account_collection_id = ?
			AND 	is_enabled = 'Y'
			ORDER BY last_name, first_name, login
		}
		) || $stab->return_db_err();
		$sth->execute($id) || die $stab->return_db_err($sth);
		while ( my ( $id, $fn, $ln, $login ) = $sth->fetchrow_array ) {
			my $print = "$fn $ln ($login)";
			push( @{ $r->{ACCOUNTS} }, { print => $print, account_id => $id } );
		}
		my $j = JSON::PP->new->utf8;
		print $j->encode($r);
	} elsif ( $what eq 'autocomplete' ) {
		if ( $type eq 'account' ) {
			my $r   = { query => 'unit', suggestions => [] };
			my $sth = $stab->prepare_cached( qq{
				SELECT  account_id, first_name, last_name, login
				FROM    v_corp_family_account
						JOIN v_person USING (person_id)
				WHERE   account_type = 'person' and account_role = 'primary'
				AND 	is_enabled = 'Y'
				AND ( 	lower(login) LIKE :1
				 OR		lower(first_name) lIKE :1
				 OR		lower(last_name) lIKE :1
				 OR		lower(concat(first_name, ' ', last_name)) lIKE :1
				)
				ORDER BY last_name, first_name, login
				LIMIT 10
			}
			) || $stab->return_db_err();
			$sth->bind_param( ':1', $query . "%" )
			  || die $stab->return_db_err($sth);
			$sth->execute || die $stab->return_db_err($sth);
			while ( my ( $id, $fn, $ln, $login ) = $sth->fetchrow_array ) {
				my $print = "$fn $ln ($login)";
				push( @{ $r->{suggestions} },
					{ value => $print, data => $id } );
			}
			my $j = JSON::PP->new->utf8;
			print $j->encode($r);
		}

	} else {

		# catch-all error condition
		print $cgi->div( { -style => 'text-align: center; padding: 50px', },
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
