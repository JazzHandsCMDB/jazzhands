#!/usr/bin/env perl
#
# Copyright (c) 2015, Todd M. Kover
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#	   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;
use Data::Dumper;
use JSON::PP;
use JazzHands::DBI;
use Net::SSLeay;
use Pod::Usage;
use Getopt::Long;
use JazzHands::AppAuthAL;

my $mailfrom = 'approval-notifications';
my $service = "approval-notify";

my $dryrun;

=head1 NAME

process-jira - 
=head1 SYNOPSIS

approval-email [ --dry-run | -n ] 

=head1 DESCRIPTION

=head1 AUTHORS

Todd M. Kover <kovert@omniscient.com>

=cut 

exit do_work();

#############################################################################

my $dbh;

sub do_work {
	$dbh = JazzHands::DBI->connect($service, {AutoCommit => 0}) || die $JazzHands::DBI::errstr;

	GetOptions(
		"dry-run|n"	   => \$dryrun,
		# "one-email"	   => \$oneemail,
	) || die pod2usage();

	#if ( !scalar @labels ) {	push( @labels, 'physical-access-verify' );}

	my $sth = $dbh->prepare_cached(q{
		WITH all_email as (
			SELECT	person_id, person_contact_account_name as email_address,
					rank() OVER (partition by person_id 
							ORDER BY person_contact_order) as tier
			FROM	person_contact
			WHERE	person_contact_technology = 'email'
			AND		person_contact_location_type = 'office'
		), email AS (
			select * from all_email where tier = 1
		), defaultdomain AS (
			select property_value as default_domain
			from property 
			where property_name = '_defaultdomain'
			and property_type = 'Defaults' 
			order by property_id LIMIT 1 
		), notifications AS (
			SELECT approval_instance_step_id, approval_notify_type,
					approval_notify_whence,
					rank() OVER (partition by approval_instance_step_id 
							ORDER BY approval_notify_whence desc) as tier
			FROM approval_instance_step_notify
			WHERE approval_notify_type  = 'email'
		), lastnotify AS (
			SELECT * from notifications where tier = 1
		) SELECT	account_id, login, 
				approval_instance_step_id,
				coalesce(p.preferred_last_name, p.last_name) as last_name,
				coalesce(p.preferred_first_name, p.first_name) as first_name,
				coalesce(email_address, concat(login, '@', default_domain))
					as email_address,
				apc.message, 
				ap.approval_expiration_action,
				ais.approval_instance_step_name,
				ai.approval_instance_name,
				approval_instance_step_due,
				extract(epoch from approval_instance_step_due- now() )
					as due_seconds,
				approval_notify_type,
				extract(epoch from approval_notify_whence) as approval_notify_whence,
				extract(epoch from now() - approval_notify_whence )
					as since_last_pester
		FROM	approval_instance ai
				INNER JOIN approval_instance_step ais
					USING (approval_instance_id)
				INNER JOIN approval_process_chain apc
					USING (approval_process_chain_id)
				INNER JOIN approval_process ap
					USING (approval_process_id)
				INNER JOIN account a
					ON a.account_id = approver_account_id
				INNER JOIN person p USING (person_id)
				LEFT JOIN email USING (person_id)
				LEFT JOIN lastnotify USING (approval_instance_step_id)
			,defaultdomain
		WHERE   approval_type = 'account'
		AND  ais.is_completed = 'N'
		ORDER BY email_address
		;
	}) || die $dbh->errstr;

	$sth->execute || die $sth->errstr;

	my $wsth = $dbh->prepare_cached(q{
		INSERT INTO approval_instance_step_notify (
			approval_instance_step_id, approval_notify_type, approval_notify_whence
		) VALUES (
			?, 'email', now()
		)
	}) || die $dbh->errstr;

	while(my $hr = $sth->fetchrow_hashref) {
		my $email = $hr->{email_address};
		my $action = $hr->{approval_expiration_action};
		my $due = $hr->{due_seconds};

		#
		# An email has been sent and it is not overdue yet, so do nothing.
		#
		if($hr->{due_seconds} > 0 && $hr->{approval_notify_whence}) {
			next;
		}

		#
		# If it is not set to 'pester' then do nothing even if its past the
		# expiration date
		#
		next if(!$hr->{approval_expiration_action} || $hr->{approval_expiration_action} ne 'pester');

		#
		# if its overdue, and some pestering was not done in the past day
		# pester again.
		#
		my $overdue = ($hr->{due_seconds} < 0)?1:0;
		if($overdue && $hr->{since_last_pester} < 86400) {
			next;
		}

		my $subj = $hr->{approval_instance_name}." ".
				$hr->{approval_instance_step_name};


		my $nr = $wsth->execute( $hr->{approval_instance_step_id} ) || die $wsth->errstr;
		print "Sending to $email - $subj ($nr)\n";
	}

	$dbh->commit;

	0;
}


END {
	if ($dbh) {
		$dbh->rollback;
		$dbh->disconnect;
		$dbh = undef;
	}
}
