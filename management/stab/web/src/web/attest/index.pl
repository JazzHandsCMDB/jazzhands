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
	my $cgi  = $stab->cgi          || die "Could not create cgi";

	my $actas = $stab->cgi_parse_param('actas') || $stab->username();

	my $stepid = $stab->cgi_parse_param('APPROVAL_INSTANCE_STEP_ID');

	if ($stepid) {
		show_step_attest( $stab, $stepid );
	} else {
		do_my_attest( $stab, $actas );
	}

	undef $stab;
}

sub dump_attest_loop($$;$$) {
	my ( $stab, $sth, $acctid, $ro ) = @_;

	my $cgi = $stab->cgi || die "Could not create cgi";

	my $appall = $cgi->button(
		{
			-class => 'approveall',
			-name  => 'selectall',
			-value => 'approve all',
		}
	);

	if ($ro) {
		$appall = "";
	}

	my $map = {};
	while ( my $hr = $sth->fetchrow_hashref ) {
		my $step = $hr->{ _dbx('approval_instance_step_id') };
		my $item = $hr->{ _dbx('approval_instance_item_id') };

		my $label = $hr->{ _dbx('apprved_label') };
		my $lhs   = $hr->{ _dbx('approved_lhs') };
		my $rhs   = $hr->{ _dbx('approved_rhs') };

		$map->{$step}->{lhs}->{$lhs}->{$item}->{label} = $label;
		$map->{$step}->{lhs}->{$lhs}->{$item}->{rhs}   = $rhs;
		$map->{$step}->{lhs}->{$lhs}->{$item}->{item}  = $item;
		$map->{$step}->{lhs}->{$lhs}->{$item}->{hr}    = $hr;

		$map->{$step}->{hr} = $hr;
	}

	# print $cgi->pre ( Dumper($map) );

	my (@tabs);
	my $classnote = 0;
	foreach my $step ( sort keys %{$map} ) {
		my $shr = $map->{$step}->{hr};

		my $numpending = 0;
		my $t          = "";
		foreach my $lhs ( sort keys %{ $map->{$step}->{lhs} } ) {
			my $numitems =
			  scalar keys %{ $map->{$step}->{lhs}->{$lhs} };

			$classnote++;
			my $perdudetally = 0;
			foreach my $item ( sort keys %{ $map->{$step}->{lhs}->{$lhs} } ) {
				$perdudetally++;

				my $hr =
				  $map->{$step}->{lhs}->{$lhs}->{$item}->{hr};
				my $linkback = "";
				my $linkfwd  = "";
				if ( $hr->{ _dbx('LHS_STEP_ID') } ) {
					my $url = $cgi->url();
					if ($url) {
						$url =
						  "?APPROVAL_INSTANCE_STEP_ID="
						  . $hr->{ _dbx('LHS_STEP_ID') };
						$linkback = $cgi->a(
							{
								-class => 'notreallydisabled',
								-href  => $url
							},
							"<<"
						);
					}
				}
				if ( $hr->{ _dbx('RHS_STEP_ID') } ) {
					my $url = $cgi->url();
					if ($url) {
						my $app =
						  ( $hr->{ _dbx('IS_APPROVED') } )
						  ? $hr->{ _dbx('IS_APPROVED') }
						  : "";
						$url .=
						  "?APPROVAL_INSTANCE_STEP_ID="
						  . $hr->{ _dbx('RHS_STEP_ID') };
						$linkfwd = $cgi->a(
							{
								-class => 'notreallydisabled',
								-href  => $url
							},
							"$app >>"
						);
					}
				}
				my $correction = $cgi->div(
					{
						-class => 'correction',
						-id    => $hr->{ _dbx('approval_instance_item_id') }
					}
				  ),

				  my $myclass = "";
				my $mytrclass;
				if ( $classnote % 2 ) {
					$mytrclass = 'even';
				} else {
					$mytrclass = 'odd';
				}

				if ( $hr->{ _dbx('EXTERNAL_REFERENCE_NAME') } ) {
					my $ref = $hr->{ _dbx('EXTERNAL_REFERENCE_NAME') };
					if ( $hr->{ _dbx('APPROVAL_TYPE') } eq 'jira-hr' ) {
						my $sth = $stab->prepare(
							qq{
							select property_value from property
							where property_name = '_jira_url'
							and property_type = 'Defaults'
						}
						) || return $stab->return_db_err();
						$sth->execute
						  || return $stab->return_db_err($sth);
						my ($url) = $sth->fetchrow_array;
						$sth->finish;
						if ($url) {
							$url =~ s,/$,,;
							$ref = $cgi->a(
								{
									-href    => "$url/browse/$ref",
									- target => "stab-$ref"
								},
								$ref
							);
						}
					}
					my $x =
					  ( !$hr->{ _dbx('IS_APPROVED') } )
					  ? "(pending)"
					  : "";
					$correction = "$x $ref";
				}

				my $whocol = '';
				if ( $perdudetally == 1 ) {

					# $whocol = $hr->{approved_lhs} || '';
					$whocol = $cgi->td(
						{
							-class   => $myclass,
							-rowspan => $numitems
						},
						$hr->{approved_lhs} || ''
					);
				}

				my $approvsw = "";
				if ( $hr->{ _dbx('IS_APPROVED') } ) {
					$myclass .= " disabled";
				} elsif ( !$ro ) {
					$numpending++;

					#$approvsw = $cgi->checkbox({
					#	-class => 'attesttoggle approve',
					#	-name => 'app_'.$hr->{_dbx('approval_instance_item_id')},
					#	-label => ''}),
					$approvsw = $cgi->div(
						{ -class => 'attestbox' },
						$cgi->hidden(
							{
								-class => 'approve_value',
								-name  => 'ap_'
								  . $hr->{ _dbx('approval_instance_item_id') },
								value => ''
							}
						),
						$cgi->button(
							{
								-class => 'attesttoggle approve buttonoff',
								-name  => 'app_'
								  . $hr->{ _dbx('approval_instance_item_id') },
								-type  => 'button',
								-value => 'approve'
							}
						),
						$cgi->button(
							{
								-class => 'attesttoggle disapprove buttonoff',
								-name  => 'dis_'
								  . $hr->{ _dbx('approval_instance_item_id') },
								-type  => 'button',
								-value => 'request change'
							}
						),
					);
				}

				$correction = $cgi->td({-class=>"$myclass correction"},
					$correction);

				$t .= $cgi->Tr(
					{ -class => $mytrclass },
					$cgi->td($linkback),
					$whocol,
					$cgi->td(
						{ -class => $myclass },
						[
							$hr->{approved_label} || '',
							$hr->{approved_rhs}   || '',
							$approvsw,
						]
					),
					$correction,
					$cgi->td($linkfwd),
				);
			}
		}

		my $hdr = "";
		if ($numpending) {
			$hdr = $cgi->th(
				[
					"", 'Who', 'What', "Value", "Approval $appall",
					'Correction', ""
				]
			);
		} else {
			$hdr = $cgi->th( [ "", 'Who', 'What', "Value", "", "", "" ] );
		}

		my $dueclass = 'approvaldue';
		my $due = "Due: End of Day ".$shr->{_dbx('APPROVAL_INSTANCE_STEP_DUE')};
		if($shr->{_dbx('DUE_SECONDS')} < 0) {
			$dueclass .= " overdue";
			$due = "OVERDUE: $due";
		} elsif($shr->{_dbx('DUE_SECONDS')} < 86400) {
			$dueclass .= " duesoon";
			$due = "DUE SOON: $due";
		}

		my $tab = join("\n",
			$cgi->div(
				{ -class => 'description process' },
				$shr->{ _dbx('process_description') }
			), $cgi->hr,

			$cgi->div(
				{ -class => 'description chain' },
				$shr->{ _dbx('chain_description') },
				$cgi->hr,
				$cgi->div({ -class => 'directions' },
					q{
						Please verify each item and either approve or request
						changes from this page.  The "approve all" button can 
						be used to approve all items.
					}),
				$cgi->table( { -class => 'attest' }, $hdr, $t ),
			),
			$cgi->div( {-class=>$dueclass}, $due ),
		);
		# hrn = human readnable, id = for web forms
		my $id = join("_",$shr->{_dbx('APPROVAL_INSTANCE_STEP_ID')},
				$shr->{_dbx('APPROVAL_INSTANCE_NAME')});
		$id =~ s/\s+//g;
		my $hrn = join(" ", $shr->{_dbx('APPROVAL_INSTANCE_NAME')},
				$shr->{_dbx('APPROVAL_INSTANCE_STEP_NAME')});
		push( @tabs, { id => $id, name => $hrn, content => $tab } );
		undef $t;
		undef $tab;

		#} else {
		#	print "There are no outstanding issues";
		#}
	}

	my $form = $cgi->start_form( { -id => 'attest', -action => "attest.pl" } );
	if ($acctid) {
		$form .= $cgi->hidden(
			{
				-name    => 'accting_as_account',
				-default => $acctid
			}
		);
	}
	print $form;


	#
	# build html for the tab bar into $tabbar
	#
	my $count = 0;
	my $tabbar = "";
	for my $h (@tabs) {
		my $class = 'stabtab';
		if($count++ == 0) {
			$class .= ' stabtab_on';
		} else {
			$class .= ' stabtab_off';
		}
		my $id = $h->{id};
		$tabbar .= $cgi->a(
			{
				-class => $class,
				-id => "tab$id",
			},
			$h->{name}
		);
	}


	#
	# build html for the actual tabs in $tabcontent
	#
	$count = 0;
	my $tabcontent = "";
	for my $h (@tabs) {
		my $id = $h->{id};
		my $class = 'stabtab';
		if($count++ == 0) {
			$class .= ' stabtab_on';
		}
		$tabcontent .= $cgi->div({-class=>$class, id=>"tab$id"}, 

			$h->{content}
	);
	}

	print $cgi->div({-class => 'stabtabset'},
		$cgi->div( {-class=>'stabtabbar'}, $tabbar),
		$cgi->div( {-class=>'stabtabcontent'}, $tabcontent),
	);

	if($#tabs >= 0) {
		print $cgi->div( { -class => 'attestsubmit' },
			$cgi->submit( { -class => 'attestsubmit', -label=>"Submit Approval"} ) ),
	  	"\n";
	} else {
		print "There is nothing outstanding for you to do. Thank you for checking";
	}
	print $cgi->end_form, "\n",;
}

sub do_my_attest {
	my ( $stab, $actas ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	# XXX - need to make it so you can only act as people who work for you!
	# XXX - also need to apply this to the thing that applies the attestation
	my $acctid = $stab->get_account_id($actas);

	my $sth = $stab->prepare(
		qq{
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
					ais.approval_instance_step_name,
					ap.approval_process_id,
					apc.approval_process_chain_id,
					ai.approval_instance_name,
					approval_instance_step_due::date
						as approval_instance_step_due,
					extract(epoch from approval_instance_step_due- now() )
						as due_seconds,
					ai.description as process_description,
					apc.message as chain_description
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
	}
	) || return $stab->return_db_err;

	$sth->execute($acctid) || return $stab->return_db_err($sth);


	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html(
		{ -title => "Approvals", -javascript => 'attest' } ), "\n";

	my $for = "";
	if($acctid != $stab->get_account_id() ) {
		$for = " for $actas";
	}

	print $cgi->h4( { -align => 'center' },
		"Outstanding Approvals $for" );

	dump_attest_loop( $stab, $sth, $acctid );

	print "\n\n", $cgi->end_html, "\n";
}

sub show_step_attest {
	my ( $stab, $stepid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html(
		{ -title => "Attesting", -javascript => 'attest' } ), "\n";

	print $cgi->h4( { -align => 'center' }, "Approval Step" );

	my $sth = $stab->prepare(
		qq{
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
	}
	) || return $stab->return_db_err;

	$sth->execute($stepid) || return $stab->return_db_err($sth);

	dump_attest_loop( $stab, $sth, undef, 1 );
}

1;
