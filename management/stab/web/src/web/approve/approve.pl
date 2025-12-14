#!/usr/bin/env perl
#
# Copyright (c) 2015-2020, Todd M. Kover
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
use Net::IP;

return process_attestment();

sub process_attestment {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";

	#- print $cgi->header, $cgi->start_html, $cgi->Dump, $cgi->end_html; exit;

	my $acctid = $stab->cgi_parse_param('accting_as_account');

	if (   !$stab->check_management_chain($acctid)
		&& !$stab->check_approval_delegation($acctid)
		&& !$stab->check_approval_god_mode() )
	{
		return $stab->error_return(
			"You are not permitted to attest to this person's accounts");
	}

	my $myacctid = $stab->get_account_id()
	  || die $stab->error_return(
		"I was not able to determine who you are trying to validate. This should not happen."
	  );

	#
	#
	# NOTE:  This query is shared with index.pl.  May want to do something
	# about that...
	my $sth = $stab->prepare(
		qq{
		SELECT approver_account_id, aii.*
		FROM	approval_instance ai
				INNER JOIN approval_instance_step ais
					USING (approval_instance_id)
				INNER JOIN approval_instance_item aii
					USING (approval_instance_step_id)
				INNER JOIN approval_instance_link ail
					USING (approval_instance_link_id)
		WHERE   approver_account_id = ?
		AND     approval_type = 'account'
		AND     ais.is_completed = 'N'
		AND		aii.is_approved IS NULL
	}
	) || return $stab->return_db_err;

	$sth->execute($acctid) || return $stab->return_db_err($sth);

	my $wsth = $stab->prepare(
		qq{
		SELECT approval_utils.approve(
			approval_instance_item_id := ?,
			approved := ?,
			approving_account_id := ?,
			new_value := ?
		);
	}
	) || return $stab->return_db_err;

	my $bad = 0;

	my $count = 0;
	while ( my $hr = $sth->fetchrow_hashref ) {
		my $id = $hr->{'APPROVAL_INSTANCE_ITEM_ID'};

		my $action = $cgi->param("ap_$id");

		my $fix;
		my $approved;
		if ( $action eq 'approve' ) {
			$approved = 'Y';
		} elsif ( $action eq 'reject' ) {
			$approved = 'N';
			$fix      = $cgi->param("fix_$id");
			if ( !$fix ) {
				$stab->error_return(
					"All rejected users must have a correction");
			}
			$approved = 'N';
			$bad++;
		} elsif ( !defined($action) || $action eq '' ) {
			$stab->error_return(
				"All users must be approved or a change requested");
		} else {
			$stab->error_return("$action is not a valid action for $id");
		}

		$wsth->execute( $id, $approved, $myacctid, $fix )
		  || return $stab->return_db_err;
		$wsth->finish;
		$count++;
	}

	$stab->commit;
	my $msg = "Submitted $count items succesfully.";
	if ( $bad > 0 ) {
		$msg .=
		  qq{Ticket(s) will be opened on your behalf for the $bad changes and when resolved, you will be asked, via another email, to certify the changes after they are entered.  You may also be asked more questions based on the ticket via e-mail.};
	}

	$stab->msg_return( $msg, undef, 1 );
	0;
}
