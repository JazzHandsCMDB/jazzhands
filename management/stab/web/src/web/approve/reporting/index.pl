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

do_attest_reporting();

sub do_attest_reporting {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";

	my $instid = $stab->cgi_parse_param('APPROVAL_INSTANCE_ID');

	if ($instid) {
		show_approval_instance( $stab, $instid );
	} else {
		show_all_approvals($stab);
	}

	undef $stab;
}

sub dump_header {
	my ( $stab, $instid ) = @_;

	print $stab->build_table_from_query(
		query => qq{
			WITH tallies AS (
				SELECT approval_instance_id,
						approval_process_chain_name,
						aps.is_completed,
						count(*) as tally
				FROM	approval_instance_step aps
					join approval_process_chain
						USING (approval_process_chain_id)
				GROUP by approval_instance_id,
						approval_process_chain_name, aps.is_completed
			), y AS (
				SELECT * FROM tallies where is_completed = 'Y'
			), n AS (
				SELECT * FROM tallies where is_completed = 'N'
			), q AS (SELECT DISTINCT
					approval_instance_id, approval_process_chain_name,
					y.tally as completed,
					n.tally as uncompleted,
					y.tally+n.tally as total
				FROM	tallies
				LEFT JOIN y USING (approval_instance_id, approval_process_chain_name)
				LEFT JOIN n USING (approval_instance_id, approval_process_chain_name)
				WHERE approval_instance_id = ?
			), output AS ( SELECT approval_process_chain_name as chain,
				completed,
				round((completed::decimal/total)*100.0, 2) ||'%' as pctcompleted,
				uncompleted,
				round((uncompleted::decimal/total)*100.0, 2) ||'%' as pctuncompleted,
				total
				FROM q
				order by 1,2 desc
			) select chain as "Chain",
				coalesce(completed::text, 'none') as "# Completed",
				case WHEN completed IS NULL THEN 'none'
					WHEN pctcompleted IS NULL THEN '100%'
					ELSE pctcompleted END as "% Completed",
				coalesce(uncompleted::text, 'none') as "# Oustanding",
				case WHEN uncompleted IS NULL THEN 'none'
					WHEN pctuncompleted IS NULL THEN '100%'
					ELSE pctuncompleted END as "% Outstanding",
				coalesce(total, coalesce(completed,0)+coalesce(uncompleted,0)) as total
			FROM output
		},
		bind    => [$instid],
		caption => 'Overall Step Completion Statistics',
		class   => 'reporting'
	);
}

sub dump_step_state {
	my ( $stab, $instid ) = @_;
	my $cgi = $stab->cgi() || die "could not create cgi";

	print $stab->build_table_from_query(
		query => qq{
			WITH tallies AS (
				SELECT approval_instance_id,
						approval_process_chain_name,
						aps.is_completed,
						count(*) as tally
				FROM	approval_instance_step aps
					join approval_process_chain
						USING (approval_process_chain_id)
				GROUP by approval_instance_id,
						approval_process_chain_name, aps.is_completed
			), y AS (
				SELECT * FROM tallies where is_completed = 'Y'
			), n AS (
				SELECT * FROM tallies where is_completed = 'N'
			), q AS (SELECT DISTINCT
					approval_instance_id, approval_process_chain_name,
					y.tally as completed,
					n.tally as uncompleted,
					y.tally+n.tally as total
				FROM	tallies
				LEFT JOIN y USING (approval_instance_id, approval_process_chain_name)
				LEFT JOIN n USING (approval_instance_id, approval_process_chain_name)
				WHERE approval_instance_id = 1
			) SELECT approval_process_chain_name,
				completed as "# Completed",
				round((completed::decimal/total)*100.0, 2) ||'%' as "% Completed",
				uncompleted as "# Outstanding",
				round((uncompleted::decimal/total)*100.0, 2) ||'%' as "% Outstanding",
				total
			FROM q
			order by 1,2 desc
		}
	);
}

sub dump_steps {
	my ( $stab, $instid ) = @_;
	my $cgi = $stab->cgi() || die "could not create cgi";

	print $stab->build_table_from_query(
		query => qq{
			SELECT 	approval_instance_step_name as "Step Name",
					coalesce(vat.description,approval_type) as "Approval Type",
					is_completed as "Completed",
					approval_instance_step_start::date || '' as "Start",
					approval_instance_step_end::date || '' as "End",
					concat (
						coalesce(preferred_first_name, first_name), ' ',
						coalesce(preferred_last_name, last_name), ' (',
						a.login, ')') as "Relevant User",
					external_reference_name as "Reference ID",
					case when is_completed = 'Y' THEN
						age(date_trunc('second',approval_instance_step_end),
							date_trunc('second',approval_instance_step_start))::text
						ELSE '' END AS "Duration Open",
					a.login
			FROM	approval_instance_step aps
					INNER JOIN approval_process_chain apc
						USING (approval_process_chain_id)
					INNER JOIN approval_instance USING (approval_instance_id)
					INNER JOIN account a ON
						aps.approver_account_id = a.account_id
					INNER JOIN person p USING (person_id)
					INNER JOIN val_approval_type vat USING (approval_type)
			WHERE	approval_instance_id = ?
			order by approval_type, is_completed, last_name, first_name, login
		},
		bind    => [$instid],
		caption => 'Detailed Completion Information',
		class   => 'reporting',
		tableid => 'approvalreport',
		urlmap  => { 'Relevant User' => '../?actas=%{login}' },
		hidden  => ['login'],
	);
}

sub dump_peruser {
	my ( $stab, $instid ) = @_;
	my $cgi = $stab->cgi() || die "could not create cgi";

	print $stab->build_table_from_query(
		query => qq{
			WITH a AS (
				SELECT a.account_id, a.login,
					coalesce(preferred_first_name,first_name) as first_name,
					coalesce(preferred_last_name,last_name) as last_name
				FROM account a
					INNER JOIN person p USING (person_id)
			), h AS (
				SELECT	a.*,
					concat(first_name, ' ', last_name, ' (', login, ')')
						AS human_name
				FROM a
			) SELECT
				human_name as "Approving User",
				login,
				s.approval_instance_step_name as "Outstanding Steps",
				count(*) as "# Items"
			FROM  v_approval_instance_step_expanded x
				inner join approval_instance_step s
					USING (approval_instance_step_id)
				inner join approval_instance_step rs
					ON x.root_step_id = rs.approval_instance_step_id
				inner join h
					ON h.account_id = rs.approver_account_id
			where s.is_completed = 'N'
			and is_approved is null
			and rs.approval_instance_id = ?
			group by human_name, login, s.approval_instance_step_name
			order by 1, 2
		},
		bind    => [$instid],
		caption => 'State of Each Outstanding Recertification by User',
		class   => 'reporting',
		urlmap  => { 'Approving User' => '../?actas=%{login}' },
		hidden  => ['login'],
		tableid => 'approvalperuser'
	);
}

sub show_approval_instance {
	my ( $stab, $instid ) = @_;

	my $cgi = $stab->cgi() || die "could not create cgi";

	my $sth = $stab->prepare( qq{
		SELECT  *,
				date_trunc('seconds', approval_start) as start,
				date_trunc('seconds', approval_end) as end
		FROM	approval_instance
		WHERE	approval_instance_id = ?
	}
	) || return $stab->return_db_err();

	$sth->execute($instid) || return $stab->return_db_err();

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;

	my $title = "Approval Reporting";

	if ($hr) {
		$title = $hr->{ _dbx('APPROVAL_INSTANCE_NAME') } . " "
		  . $hr->{ _dbx('DESCRIPTION') };
	}

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html( { -title => $title, -javascript => 'reporting' } ),
	  "\n";

	if ($hr) {
		print $cgi->div( $cgi->table(
			{ -class => 'reporting' },
			$cgi->caption("Time Frames"),
			$cgi->Tr( $cgi->td( [ 'Start', $hr->{ _dbx('START') } ] ) ),
			$cgi->Tr( $cgi->td( [ 'End',   $hr->{ _dbx('END') } || '' ] ) ),
		) );
	}

	print $cgi->hr();
	dump_header( $stab, $instid );
	print $cgi->hr();
	dump_steps( $stab, $instid );
	print $cgi->hr();
	dump_peruser( $stab, $instid );
	print $cgi->hr();

	print "\n\n", $cgi->end_html, "\n";
}

sub show_all_approvals {
	my ($stab) = @_;

	my $cgi = $stab->cgi() || die "could not create cgi";

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html(
		{ -title => "Approval Instances", -javascript => 'reporting' } ), "\n";

	print $cgi->div(
		{ -class => 'reporting' },
		$cgi->start_form( { -class => 'center_form', -method => 'GET' } ),
		$stab->b_dropdown( undef, undef, 'APPROVAL_INSTANCE_ID' ),
		$cgi->br(),
		$cgi->submit( { class => 'attestsubmit' } ),
		$cgi->end_form,
	);

	print "\n\n", $cgi->end_html, "\n";
}
