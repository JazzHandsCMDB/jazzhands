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

	my $stepid = $stab->cgi_parse_param('APPROVAL_INSTANCE_STEP_ID');

	if($stepid) {
		show_step_attest($stab, $stepid);
	} else {
		do_my_attest($stab, $actas);
	}

	undef $stab;
}

sub dump_attest_loop($$;$$) {
	my ($stab, $sth, $acctid, $ro) = @_;

	my $cgi = $stab->cgi || die "Could not create cgi";

	print $cgi->start_form( {-id=>'attest', -action => "attest.pl" } );
	if($acctid) {
		print $cgi->hidden({-name => 'accting_as_account', -default=>$acctid});
	}

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

	if($ro) {
		$checky = $checkn = "";
	}

	$newt .= $cgi->th([
		"", $checky, $checkn, 'What', "Who", "Value", "Correction", ""
	]);

	my $t = $newt;

	my $lastap = undef;
	my $lastapc = undef;

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

		#
		# note that inserts before the table
		#
		if(!$lastapc || $lastapc ne $hr->{_dbx('approval_process_chain_id')}) {
			$lastapc = $hr->{_dbx('approval_process_chain_id')};
			if( $hr->{ _dbx('chain_description')} ) {
				$t = $cgi->div({-class => 'description chain'},
						$hr->{ _dbx('chain_description') }) . "\n$t";
			}
		}
		if(!$lastap || $lastap ne $hr->{_dbx('approval_process_id')}) {
			$lastap = $hr->{_dbx('approval_process_id')};
			if( $hr->{ _dbx('process_description')} ) {
				$t = $cgi->div({-class => 'description process'},
					$hr->{ _dbx('process_description') }) . "\n$t";
			}
		}

		my $correction = $cgi->div({-class=>'correction', -id =>
				$hr->{_dbx('approval_instance_item_id')}}),

		my $myclass = "";
		my $mytrclass;
		if($classnote % 2) {
			$mytrclass = 'even';
		} else {
			$mytrclass = 'odd';
		}

		my $yesbox = "";
		my $nobox = "";
		if($hr->{_dbx('IS_APPROVED')} ) {
			$myclass .= " disabled";
		} elsif(!$ro) {
			$yesbox = $cgi->checkbox({
				-class => 'attesttoggle approve', 
				-name => 'app_'.$hr->{_dbx('approval_instance_item_id')},
				-label => ''}),
			$nobox = $cgi->checkbox({
				-class => 'attesttoggle disapprove', 
				-name => 'dis_'.$hr->{_dbx('approval_instance_item_id')},
				-label => ''}),
		}

		if($hr->{ _dbx('EXTERNAL_REFERENCE_NAME') }) {
			my $ref = $hr->{ _dbx('EXTERNAL_REFERENCE_NAME') };
			if($hr->{_dbx('APPROVAL_TYPE')} eq 'jira-hr') {
				my $sth = $stab->prepare(qq{
					select property_value from property
					where property_name = '_jira_url'
					and property_type = 'Defaults'
				}) || return $stab->return_db_err();
				$sth->execute || return $stab->return_db_err($sth);
				my ($url) = $sth->fetchrow_array;
				$sth->finish;
				if($url) {
					$ref = $cgi->a({-href=>"$url/browse/$ref",
							-target => "stab-$ref"}, $ref);
				}
			}
			my $ x = (!$hr->{_dbx('IS_APPROVED')} )?"(pending)":"";
			$correction = "$x $ref";
		}

		my $linkback = "";
		my $linkfwd = "";
		if($hr->{ _dbx('LHS_STEP_ID') }) {
			my $url = $cgi->url();
			if($url) {
				$url = "?APPROVAL_INSTANCE_STEP_ID=".  $hr->{_dbx('LHS_STEP_ID')};
				$linkback = $cgi->a({-class=>'notreallydisabled',
					-href=>$url}, "<<");
			}
		}
		if($hr->{ _dbx('RHS_STEP_ID') }) {
			my $url = $cgi->url();
			if($url) {
				my $app = ($hr->{_dbx('IS_APPROVED')})?$hr->{_dbx('IS_APPROVED')}:"";
				$url .= "?APPROVAL_INSTANCE_STEP_ID=".  $hr->{_dbx('RHS_STEP_ID')};
				$linkfwd = $cgi->a({-class=>'notreallydisabled',
					-href=>$url}, "$app >>");
			}
		}

		$t .= $cgi->Tr({ -class => $mytrclass },
			$cgi->td($linkback),
			$cgi->td({-class=>$myclass},
				[
					$yesbox,
					$nobox,
					$hr->{approved_label} || '',
					$hr->{approved_lhs} || '',
					$hr->{approved_rhs} || '',
					$correction,
				]
			),
			$cgi->td($linkfwd),
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
		WITH flow AS (
			select	i.approval_instance_item_id as lhs_item_id,
						i.approval_instance_step_id as lhs_step_id,
						n.approval_instance_item_id as rhs_item_id,
						n.approval_instance_step_id as rhs_step_id
			from		approval_instance_item i
						inner join approval_instance_item n
							on i.next_approval_instance_item_id = 
								n.approval_instance_item_id
		) SELECT approver_account_id, aii.*, ais.is_completed,
					back.lhs_step_id as lhs_step_id,
					fwd.rhs_step_id as rhs_step_id,
					ais.external_reference_name,
					ais.approval_type,
					ap.approval_process_id,
					apc.approval_process_chain_id,
					ai.description as process_description,
					ais.description as chain_description
		FROM	approval_instance ai
				INNER JOIN approval_instance_step ais
					USING (approval_instance_id)
				INNER JOIN approval_instance_item aii 
					USING (approval_instance_step_id)
				INNER JOIN approval_instance_link ail 
					USING (approval_instance_link_id)
				INNER JOIN approval_process_chain apc
					USING (approval_process_chain_id)
				INNER JOIN approval_process ap
					USING (approval_process_id)
				LEFT JOIN flow back on
					back.rhs_item_id = aii.approval_instance_item_id
				LEFT JOIN flow fwd on
					fwd.lhs_item_id = aii.approval_instance_item_id
		WHERE	approver_account_id = ?
		AND		approval_type = 'account'
		AND		ais.is_completed = 'N'
		ORDER BY approval_process_id, approval_process_chain_id,
				approval_instance_step_id, approved_lhs, approved_label
	}) || return $stab->return_db_err;

	$sth->execute($acctid) || return $stab->return_db_err($sth);

	dump_attest_loop($stab, $sth, $acctid);
}


sub show_step_attest {
	my ($stab, $stepid) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html(
		{ -title => "Attesting", -javascript => 'attest' } ), "\n";

	print $cgi->h4( { -align => 'center' }, "Approval Step" );

	my $sth = $stab->prepare(qq{
		WITH flow AS (
			select	i.approval_instance_item_id as lhs_item_id,
						i.approval_instance_step_id as lhs_step_id,
						n.approval_instance_item_id as rhs_item_id,
						n.approval_instance_step_id as rhs_step_id
			from		approval_instance_item i
						inner join approval_instance_item n
							on i.next_approval_instance_item_id = 
								n.approval_instance_item_id
		) SELECT approver_account_id, aii.*, ais.is_completed,
					back.lhs_step_id as lhs_step_id,
					fwd.rhs_step_id as rhs_step_id,
					ais.external_reference_name,
					ais.approval_type,
					ap.approval_process_id,
					apc.approval_process_chain_id,
					ai.description as process_description,
					ais.description as chain_description
		FROM	approval_instance ai
				INNER JOIN approval_instance_step ais
					USING (approval_instance_id)
				INNER JOIN approval_instance_item aii 
					USING (approval_instance_step_id)
				INNER JOIN approval_instance_link ail 
					USING (approval_instance_link_id)
				INNER JOIN approval_process_chain apc
					USING (approval_process_chain_id)
				INNER JOIN approval_process ap
					USING (approval_process_id)
				LEFT JOIN flow back on
					back.rhs_item_id = aii.approval_instance_item_id
				LEFT JOIN flow fwd on
					fwd.lhs_item_id = aii.approval_instance_item_id
		WHERE	approval_instance_step_id = ?
		ORDER BY approval_process_id, approval_process_chain_id,
				approval_instance_step_id, approved_lhs, approved_label
	}) || return $stab->return_db_err;

	$sth->execute($stepid) || return $stab->return_db_err($sth);

	dump_attest_loop($stab, $sth, undef, 1);
}


1;
