#!/usr/bin/env perl
#
# Copyright (c) 2017, Todd M. Kover
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#
# $Id$
#

use strict;
use warnings;
use POSIX;
use Data::Dumper;
use Carp;
use JazzHands::STAB;
use JazzHands::Common qw(_dbx);
use Net::IP;

# causes stack traces on warnings
# local $SIG{__WARN__} = \&Carp::cluck;

do_ac_toplevel();

sub do_ac_toplevel {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";

	my $acid = $stab->cgi_parse_param('ACCOUNT_COLLECTION_ID');

	if ($acid) {
		edit_acount_collection( $stab, $acid );
	} else {
		do_account_collection_chooser($stab);
	}

	undef $stab;
}

sub build_account_list($$;$) {
	my ( $stab, $acid, $write ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	# deal with accounts already there.
	my $sth = $stab->prepare(
		qq{
		SELECT	account_id,	first_name, last_name, login
		FROM	account_collection_account ac
				JOIN account USING (account_id)
				JOIN v_person USING (person_id)
		WHERE	account_collection_id = ?
		ORDER BY	last_name, first_name, login
	}
	) || $stab->return_db_err();

	$sth->execute($acid) || die $stab->return_db_err();

	my $t = "";
	while ( my $acct = $sth->fetchrow_hashref() ) {
		my $rmrow = "";
		if ($write) {
			$rmrow = $cgi->checkbox(
				{
					-class => 'irrelevant rmrow',
					-name  => "Del_ACCOUNT_ID_" . $acct->{ _dbx('ACCOUNT_ID') },
					-label => '',
				}
			  ).
			  $cgi->a(
				{ -class => 'rmrow' },
				$cgi->img(
					{
						-src   => "../../stabcons/redx.jpg",
						-alt   => "Delete this Record",
						-title => 'Delete This Record',
						-class => 'rmcollrow button',
					}
				)
			  );
		}
		$t .= $cgi->li(
			$rmrow,
			$acct->{ _dbx('FIRST_NAME') } . " " . $acct->{ _dbx('LAST_NAME') },
			"(" . $acct->{ _dbx('LOGIN') } . ")"
		);
	}

	$t;
}

sub build_account_collection_list($$;$) {
	my ( $stab, $acid, $write ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	# deal with accounts already there.
	my $sth = $stab->prepare(
		qq{
		SELECT	ac.*
		FROM	account_collection_hier h
				join account_collection ac on
					ac.account_collection_id = h.child_account_collection_id
		WHERE	h.account_collection_id = ?
		ORDER BY	ac.account_collection_type, ac.account_collection_name
	}
	) || $stab->return_db_err();

	$sth->execute($acid) || die $stab->return_db_err();

	my $t = "";
	while ( my $ac = $sth->fetchrow_hashref() ) {
		my $read = join( ":",
			$ac->{ _dbx('ACCOUNT_COLLECTION_TYPE') },
			$ac->{ _dbx('ACCOUNT_COLLECTION_NAME') } );
		$t .= $cgi->li(
			# can't manipulate these yet, so commenting out.
			#$cgi->checkbox(
			#	{
			#		-class => 'irrelevant rmrow',
			#		-name  => "Del_ACCOUNT_COLLECTION_ID_" . $acct->{ _dbx('ACCOUNT_COLLECTION_ID') },
			#		-label => '',
			#	}
			#),
			# This is just a hack to make the columns line up and be more
			# readable
			($write)?$cgi->a(
				{ -class => 'collpad' },    # was rmrow
				$cgi->img(
					{
						-src => "../../stabcons/redx.jpg",

						#			-alt   => "Delete this Record",
						#			-title => 'Delete This Record',
						-class => 'button',    # was rmcollrow
					}
				)
			):"",
			$cgi->a(
				{
					-class => 'aclink',
					-href  => "./?ACCOUNT_COLLECTION_ID="
					  . $ac->{ _dbx('ACCOUNT_COLLECTION_ID') }
				},
				$read
			)
		);
	}

	$t;
}

sub edit_acount_collection {
	my ( $stab, $acid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	if ( !$acid ) {
		return $stab->error_return("No Collection Specified");
	}

	my $ac = $stab->get_account_collection($acid);

	if ( !$ac ) {
		return $stab->error_return("Unkown Collection Id $acid");
	}

	my $canhazwrite;
	my $admin = $stab->check_role('AccountCollectionAdmin');
	if ( $admin || $stab->check_account_collection_permissions( $acid, 'RW' ) )
	{
		$canhazwrite = 1;
	}

	my $acs = build_account_collection_list( $stab, $acid, $canhazwrite );
	my $accts = build_account_list( $stab, $acid, $canhazwrite );

	my $t = $acs . $accts;

	if ($canhazwrite) {
		$t .= $cgi->li(
			{ -class => 'plus' },
			$cgi->a(
				{ -class => 'addacct', -href => '#' },
				$cgi->img(
					{
						-src   => '../../stabcons/plus.png',
						-alt   => 'Add',
						-title => 'Add',
						-class => 'plusbutton'
					},
				)
			)
		);
	} else {
		$t .= $cgi->span( { -class => 'collpad' }, " " ),;
	}

	### nothing printed above this

	my $me = "Account Collection:"
	  . join( ":",
		$ac->{ _dbx('ACCOUNT_COLLECTION_TYPE') },
		$ac->{ _dbx('ACCOUNT_COLLECTION_NAME') } );

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html( { -title => $me, -javascript => 'ac' } ), "\n";

	print $cgi->div(
		$cgi->div(
			{ -class => 'collectionname' },
			$cgi->a(
				{ -href => '#', -class => 'expandcollection' }, "(expand)"
			),
			$cgi->img(
				{
					-src   => '../../stabcons/progress.gif',
					-class => 'irrelevant dance'
				}
			),
			$cgi->div(
				{ -class => 'irrelevant collectionexpandview', id => $acid },
			),
		),
		$cgi->start_form(
			{
				-class  => 'picker',
				-method => 'GET',
				-action => './update_ac.pl'
			}
		),
		$cgi->hidden( { -name => 'ACCOUNT_COLLECTION_ID', -value => $acid } ),
		$cgi->ul( { -class => 'collectionbox' }, $t ),
		"\n",
		($canhazwrite) ? $cgi->submit( { -class => 'dnssubmit' } ) : "",
		$cgi->end_form(),
		"\n"
	);

	print "\n\n", $cgi->end_html, "\n";
}

sub do_account_collection_chooser {
	my ($stab) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $admin = $stab->check_role('AccountCollectionAdmin');

	#
	# XXX rw should make ro implicit, probably merge in with code in ajax
	# module.
	#
	my $perms = $stab->get_account_collection_permissions("RO");
	if ( !$admin && !$perms ) {
		return $stab->error_return(
			"You do not have permissions to edit any account collections");
	}

	print $cgi->header('text/html');
	print $stab->start_html(
		{
			-title      => "Account Collection Management",
			-javascript => 'ac',
		}
	);

	#
	# restrict only to the account collections the person can see.
	#
	# The javascript will populate the collections that the user can see
	# if there is only one type, which it knows because there is no
	# coltypepicker objects on the page.
	#
	my $type = "";
	my $permcheck;
	if ($admin) {
		$permcheck = sub { 1 };
	}

	if ( $admin || scalar( @{ $perms->{types} } ) > 1 ) {
		my $p = $stab->get_account_collection_permissions('RO');
		if ( !$permcheck ) {
			$permcheck = sub {
				my $t = $_[0];
				scalar grep( $_ eq $t, @{ $p->{types} } );
			};
		}
		$type = $cgi->div(
			$cgi->h3('Pick a type:'),
			$stab->b_dropdown(
				{ -class => 'coltypepicker', -callback => $permcheck },
				undef, 'ACCOUNT_COLLECTION_TYPE', undef, 1
			),
		);
	}

	print $cgi->div(
		{ -class => 'acmanip collectionbox' },
		$cgi->start_form(
			{
				-class  => 'picker',
				-method => 'GET',
				-action => './'
			}
		),
		$type,
		$cgi->img(
			{
				-src   => '../../stabcons/progress.gif',
				-class => 'irrelevant dance'
			}
		),
		$cgi->div(
			{ -id => 'collec_detail', class => 'irrelevant' },

			#	$cgi->h3("Add a new Collection of this Type"),
			#	$cgi->textfield({-name=>'NETBLOCK_COLLECTION_NAME'}),
			#	$cgi->submit(-name=>'submit', -value => 'Add'),
			$cgi->h3('Pick a collection:'),
			$cgi->start_form( { -method => 'GET', -action => './' } ),
			$cgi->div( { -id => 'colbox' }, "" ),
			$cgi->submit( -name => 'submit', -value => 'Modify' ),
		),
		$cgi->end_form(),
	);
	print $cgi->end_html;

}
