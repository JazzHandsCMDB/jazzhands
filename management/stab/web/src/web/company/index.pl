#!/usr/bin/env perl
#
# Copyright (c) 2016, Todd M. Kover
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
do_company_toplevel();

sub show_entity_props($$) {
	my ( $stab, $companyid ) = @_;

	my $cgi = $stab->cgi;

	my $sth = $stab->prepare(qq{
		SELECT	vp.property_name,
				vp.property_type,
				vp.description,
				vp.property_data_type
		FROM	property_collection pc
				JOIN property_collection_property 
					USING (property_collection_id)
				JOIN val_property vp 
					USING (property_name, property_type)
		WHERE	pc.property_collection_name = 'EntityProperties'
		AND		pc.property_collection_type = 'legalentity'
	}) || die $stab->return_db_err();

	$sth->execute || $stab->return_db_err($sth);

	my $t = "";

	while(my $hr = $sth->fetchrow_hashref) {
		my $val = "--";
		if($hr->{_dbx('PROPERTY_DATA_TYPE')} eq 'list') {
			$val = $stab->b_prop_list({-type=>'legalentity'}, $hr, $hr->{property_name},
				'COMPANY_ID');
		} elsif($hr->{_dbx('PROPERTY_DATA_TYPE')} eq 'string') {
			$val = $cgi->textfield();
		} elsif($hr->{_dbx('PROPERTY_DATA_TYPE')} eq 'boolean') {
		     $val = $stab->build_checkbox( { -nodbx => 1},
			 			$hr->{property_name}, 'ShelfCompany',
			         	'COMPANY_ID')
					       . "\n";

		}

		$t .= $cgi->Tr($cgi->td([
			$hr->{ _dbx('DESCRIPTION') } || $hr->{ _dbx('PROPERTY_NAME') },
			$val,
		]));
	}
	$cgi->table({-class => 'major'}, $t);
}

sub show_company($$) {
	my ( $stab, $companyid ) = @_;

	my $cgi = $stab->cgi;

	my $sth = $stab->prepare(qq{
		select *
		from	company
		where	company_id = ?
	}) || die $stab->return_db_err();

	$sth->execute($companyid) || die $stab->return_db_err($sth);

	my $comp = $sth->fetchrow_hashref();
	$sth->finish;

	if(!$comp) {
		$stab->error_return("Unknown Company $companyid");
	}

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html(
		{ -title => $comp->{_dbx('COMPANY_NAME')},
		-javascript => 'company' } ), "\n";

	print $cgi->p(),
		$cgi->div( { -class => 'companies' },
		$cgi->start_form( { -class => 'center_form', -method => 'GET' } ),
		$cgi->table({class => 'major'}, 
		$stab->build_tr($comp, 'b_textfield', 'Company Name',
			'COMPANY_NAME', 'COMPANY_ID'),
		$stab->build_tr($comp, 'b_textfield', 'Short Name',
			'COMPANY_SHORT_NAME', 'COMPANY_ID'),
		$stab->build_tr($comp, 'b_textfield', 'Description',
			'DESCRIPTION', 'COMPANY_ID'),
		$stab->build_tr($comp, 'b_dropdown', 'Parent',
			'PARENT_COMPANY_ID', 'COMPANY_ID'),
		),
		show_entity_props($stab, $companyid),
		$cgi->submit( { class => 'companysubmit' } ),
		$cgi->end_form,
	);

	print $cgi->end_html();
}

sub pick_companies($) {
	my ( $stab ) = @_;

	my $cgi = $stab->cgi;

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html(
		{ -title => "Companies", -javascript => 'company' } ), "\n";

	print $cgi->div(
		{ -class => 'companies' },
		$cgi->start_form( { -class => 'center_form', -method => 'GET' } ),
		$stab->b_dropdown( {-company_type=>'corporate family'},
			undef, 'COMPANY_ID' ),
		$cgi->br(),
		$cgi->submit( { class => 'companysubmit' } ),
		$cgi->end_form,
	);

	print $cgi->end_html();
}

sub do_company_toplevel {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";

	my $companyid = $stab->cgi_parse_param('COMPANY_ID');

	if ($companyid) {
		show_company( $stab, $companyid );
	} else {
		pick_companies($stab);
	}

	undef $stab;
## Please see file perltidy.ERR
}

1;
