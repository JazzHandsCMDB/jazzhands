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
		show_approval_instance($stab, $instid);
	} else {
		show_all_approvals( $stab );
	}

	undef $stab;
}

sub dump_header {
	my($stab, $instid) = @_;
	my $cgi = $stab->cgi() || die "could not create cgi";

	my $sth = $stab->prepare(qq{
		SELECT approval_process_chain_name, aps.is_completed, count(*) as tally
		FROM	approval_instance_step aps
			join approval_process_chain 
				USING (approval_process_chain_id)
		WHERE	approval_instance_id = ?
		GROUP by approval_process_chain_name, aps.is_completed
		order by 1,2
	}) || $stab->return_db_err;

	$sth->execute($instid) || die $stab->return_db_err($sth);

	my $t = "";
	while(my ($ch,$done,$tally) = $sth->fetchrow_array) {
		$t .= $cgi->Tr($cgi->td([$ch, $done, $tally]));
	}

	print $cgi->div({-class=>'reporting'}, $cgi->table({-class=>"reporting"}, 
		$cgi->th(['Chain', 'Completed', 'Total']),
		$t
	));

	$t = "";
}

sub dump_steps {
	my($stab, $instid) = @_;
	my $cgi = $stab->cgi() || die "could not create cgi";

	my $sth = $stab->prepare(qq{
		SELECT approval_instance_step_name, approval_type, is_completed,
				approval_instance_step_start::date || '' as start, 
				approval_instance_step_end::date || '' as end,
				concat (
					coalesce(preferred_first_name, first_name), ' ',
					coalesce(preferred_last_name, last_name), ' (',
					a.login, ')') as name,
				external_reference_name,
				case when is_completed = 'Y' THEN
					(approval_instance_step_end - approval_instance_step_start)::interval::text
					ELSE '' END AS duration
		FROM	approval_instance_step aps
				INNER JOIN approval_instance USING (approval_instance_id)
				INNER JOIN account a ON 
					aps.approver_account_id = a.account_id
				INNER JOIN person p USING (person_id)
		WHERE	approval_instance_id = ?
		order by approval_type, is_completed, last_name, first_name, login

	}) || $stab->return_db_err;

	$sth->execute($instid) || die $stab->return_db_err($sth);

	my $t = "";
	while(my @foo = $sth->fetchrow_array) {
		$t .= $cgi->Tr($cgi->td([@foo]));
	}

	print $cgi->div({-class=>'reporting'}, $cgi->table({-class=>"reporting"}, 
		$cgi->th([qw(
			Name
			Type
			Completed
			Start
			End
			Who
			Reference
			Duration
		)]),
		$t
	));

	$t = "";
}


sub show_approval_instance {
	my($stab, $instid) = @_;

	my $cgi = $stab->cgi() || die "could not create cgi";

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html(
		{ -title => "Approval Reporting", -javascript => 'attest' } ), "\n";

	dump_header($stab, $instid);
	dump_steps($stab, $instid);

	print "\n\n", $cgi->end_html, "\n";
}

sub show_all_approvals {
	my($stab) = @_;

	my $cgi = $stab->cgi() || die "could not create cgi";

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html(
		{ -title => "Approval Instances", -javascript => 'attest' } ), "\n";

	print $cgi->div({-class=>'reporting'},
		$cgi->start_form({-class=>'center_form'}),
		$stab->b_dropdown(undef, undef, 'APPROVAL_INSTANCE_ID'),
		$cgi->br(),
		$cgi->submit({class=>'attestsubmit'}),
		$cgi->end_form,
	);

	print "\n\n", $cgi->end_html, "\n";
}
