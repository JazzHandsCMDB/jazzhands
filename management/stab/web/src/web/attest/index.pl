#!/usr/bin/env perl
#
# Copyright (c) 2015, Todd M. Kover
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
do_attest_toplevel();

sub do_attest_toplevel {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi	  || die "Could not create cgi";

	my $actas = $stab->cgi_parse_param('actas');

	do_my_attest($stab, $actas);

	undef $stab;
}

sub do_my_attest {
	my ($stab, $actas) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html(
		{ -title => "Attesting", -javascript => 'attest' } ), "\n";

	print $cgi->h4( { -align => 'center' }, "Outstanding Attestations" );

	my $acctid = $stab->get_account_id($actas);

	# XXX - need to make it so you can only act as people who work for you!
	# XXX - also need to apply this to the thing that applies the attestation

	my $sth = $stab->prepare(qq{
		SELECT approver_account_id, aii.*, ais.is_completed
		FROM	approval_instance ai
				INNER JOIN approval_instance_step ais
					USING (approval_instance_id)
				INNER JOIN approval_instance_item aii 
					USING (approval_instance_step_id)
				INNER JOIN approval_instance_link ail 
					USING (approval_instance_link_id)
		WHERE	approver_account_id = ?
		AND		approval_type = 'account'
		AND		ais.is_completed = 'N'
		ORDER BY approval_instance_step_id, approved_lhs, approved_label
	}) || return $stab->return_db_err;

	$sth->execute($acctid) || return $stab->return_db_err($sth);

	print $cgi->start_form( {-id=>'attest', -action => "attest.pl" } );
	print $cgi->hidden({-name => 'accting_as_account', -default=>$acctid});

	my $newt = "";

	$newt .= $cgi->start_table( { -class => 'attest' } );

    my $checky = $cgi->checkbox({
        -class => 'approveall',
        -name => 'selectall',
        -label => 'Y'
	});

    my $checkn = $cgi->checkbox({
        -class => 'disproveall',
        -name => 'selectall',
        -label => 'N'
	});
	$checkn = 'N';

	$newt .= $cgi->th([
		$checky, $checkn, 'What', "Who", "Value", "Correction"
	]);

	my $t = $newt;

	my $lastlhs;
	my $classnote = 0;
	my $laststep;
	while(my $hr = $sth->fetchrow_hashref) {
		if($laststep) {
			if($hr->{_dbx('approval_instance_step_id')} != $laststep) {
				$laststep = $hr->{_dbx('approval_instance_step_id')};
				print $t, $cgi->end_table, "\n\n";
				$t = $newt;
			}
		} else {
			$laststep = $hr->{_dbx('approval_instance_step_id')};
		}
		if($lastlhs) {
			if($lastlhs ne $hr->{_dbx('approved_lhs')}) {
				$lastlhs = $hr->{_dbx('approved_lhs')};
				$classnote = 1 - $classnote;
			}
		} else {
			$lastlhs = $hr->{_dbx('approved_lhs')};
		}

		my $myclass;
		if($classnote % 2) {
			$myclass = 'even';
		} else {
			$myclass = 'odd';
		}

		my $yesbox = "";
		my $nobox = "";
		if($hr->{_dbx('IS_APPROVED')} ) {
			$myclass .= " disabled";
		} else {
			$yesbox = $cgi->checkbox({
				-class => 'attesttoggle approve', 
				-name => 'app_'.$hr->{_dbx('approval_instance_item_id')},
				-label => ''}),
			$nobox = $cgi->checkbox({
				-class => 'attesttoggle disapprove', 
				-name => 'dis_'.$hr->{_dbx('approval_instance_item_id')},
				-label => ''}),
		}


		$t .= $cgi->Tr(
			{ -align => 'center', -class => $myclass },
			$cgi->td(
				[
					$yesbox,
					$nobox,
					$hr->{approved_label} || '',
					$hr->{approved_lhs} || '',
					$hr->{approved_rhs} || '',
					$cgi->div({-class=>'correction', -id =>
						$hr->{_dbx('approval_instance_item_id')}}),
				]
			)
		);
	}
	print $t, $cgi->end_table, "\n\n";
	undef $t;

	print $cgi->br, "\n";
	print $cgi->span({-class => 'attestsubmit'}, 
		$cgi->submit({-class=>'attestsubmit'})), "\n";
	print $cgi->end_form, "\n";
	print $cgi->end_html, "\n";
}
