#!/usr/bin/env perl
#
# Copyright (c) 2015-2020, Todd M. Kover
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
use Email::Date::Format qw(email_date);
use DateTime::Format::Strptime;
use FileHandle;
use POSIX;

my $service = "approval-notify";

=head1 NAME

approve-email -
=head1 SYNOPSIS

approval-email [ --debug ][ --dry-run | -n ]  [ --updatedb ] [ --stabroot=url ] [ --mailsender=email ] [ --signatory=text ] [ --login=person ] [--escalation-gap=#days ]  --escalation-level=# [ --random-sleep=# ] [ --reminder-gap=# ]


=head1 DESCRIPTION

approve-email runs periodically and sends email for any outstanding approvals
and attestations based on the contents of the database tables
approval_instance_step and approval_instance_step_notify .

It sends one mail for each step (which tends to correspond to an initial
approval step and additional approvals that may require re-checking or
escalated approval).  When a step becomes overdue, it will send one email
a day.

The --dry-run argument is used to print any emails sent to stdout, and will
not actually send email or update the database than an email was sent.  The
--updatedb option will mark items as having been sent, even if they were not.
--updatedb defaults to set if --dry-run is not specified.

Approvals include a URL that points into stab for users to approve.  This URL
must either be retrieved from the db, via the property Defaults:_stab_root or
approve-email will die.

The sender of the email can be set via the property
Defaults:_approval_email_sender .  It can also be set via the --mailsender
option, which wins over the database.

A link to a site for more information will be inlcuded in the email if
the property Defaults:_approval_faq_site is set.

The --signatory option indicates who signs the email in the body.  If not
set in the db via the property Defaults:_approval_email_signer or set on the
command line, it will just not be included

--login can be used to only send email to one particular account.

--escalation-gap can be set to a number of days to begin copying the next
layer of management on overdue reminders.  That is, if its set to 2, every 2
days, the next layer of management will be copied until there are no more
managers to add.  The default is zero, which turns off esclations.

--escalation-level can be set to a number of tiers above the manager to be
escalated to.  That is, if it set to zero, the escalation-gap option is useless.
If it is set to one, one level of manager will be escalated to, and so on.
The default is to not set this, and thus keep escalating.

--reminder-gap is used to specify how many days after the initial email for a
step that a reminder email is sent.  Only one reminder will be sent.

The --random-sleep option tells the script to sleep for a random time up to the
argument number.  The default is not to sleep

There is support in the database for setting up delegates for individuals
to receive the email intead of the person.  This is handled as part of the
script.  At any point if a task becomes overdue, it will begin copying the
original owner although it will continue to be directed at the delegate.
Note that it is not possible to delegate escalations.  That always follows
the management change.

=head1 BUILDING THE EMAIL

The email subject, and initial body are derived from information in the
database.

The next paragraph will include a link to stab.

The next paragraph will explain a due date as the end of the day of the date
set in the database.

An optional signer signs the email.

=head1 BUGS

The wording and way the delegate stuff was shimmed in is awkward.

=head1 AUTHORS

Todd M. Kover <kovert@omniscient.com>

=cut

exit do_work();

#############################################################################

my $dbh;

sub get_default($$) {
	my ( $dbh, $pn ) = @_;

	my $sth = $dbh->prepare_cached(
		qq{
		SELECT	property_value
		FROM	property
		WHERE	property_name = ?
		AND		property_type = 'Defaults'
		ORDER BY 1
		LIMIT 1
	}
	) || die $dbh->errstr;

	$sth->execute($pn) || die $sth->errstr;

	my ($v) = $sth->fetchrow_array();
	$sth->finish;
	$v;
}

sub do_work {
	$dbh = JazzHands::DBI->connect( $service, { AutoCommit => 0 } )
	  || die $JazzHands::DBI::errstr;

	my ( $stabroot, $debug, $dryrun, $updatedb, $mailfrom, $signer, $login );
	my ( $sleep, $argnow, $remindergap );

	my ($faqurl);

	my $escalationgap = 0;
	my $escalationlevel;

	GetOptions(
		"debug"              => \$debug,
		"dry-run|n"          => \$dryrun,
		"escalation-gap=i"   => \$escalationgap,
		"escalation-level=i" => \$escalationlevel,
		"login=s"            => \$login,
		"mailsender=s"       => \$mailfrom,
		"now=s"              => \$argnow,
		"random-sleep=i"     => \$sleep,
		"reminder-gap=s"     => \$remindergap,
		"signatory=s"        => \$signer,
		"updatedb"           => \$updatedb,
	) || die pod2usage();

	if ( !$updatedb && !$dryrun ) {
		$updatedb = 1;
	}

	if ( !$stabroot ) {
		$stabroot = get_default( $dbh, '_stab_root' );
	}

	if ( !$mailfrom ) {
		$mailfrom = get_default( $dbh, '_approval_email_sender' );
	}

	if ( !$signer ) {
		$signer = get_default( $dbh, '_approval_email_signer' );
	}

	if ( !$faqurl ) {
		$faqurl = get_default( $dbh, '_approval_faq_site' );
	}

	die "There is no stab root set by the command line or in the database\n"
	  if ( !$stabroot );

	if ($sleep) {
		my $delay = int( rand($sleep) );
		warn "Sleeping $delay seconds\n" if ($debug);
		sleep($delay);
	}

	#
	# This is used for debugging
	#
	my ( $binddbnow, $dbnow, $now );
	if ($argnow) {
		$binddbnow = $argnow;
		$dbnow     = "'$argnow'::timestamp";

		my $s = DateTime::Format::Strptime->new(
			pattern   => '%F %T',
			locale    => 'en_US',
			time_zone => 'UTC'
		) || die "Unable to figure out time";
		if ($s) {
			my $dt = $s->parse_datetime($argnow);
			if ($dt) {
				$s->pattern('%s');
				$now = $s->format_datetime($dt);
			} else {
				die "specified date must be YYYY-MM-DD HH:mm:SS\n";
			}
		}
	} else {
		$binddbnow = $argnow || strftime( "%F %T", localtime(time) );
		$dbnow     = 'now()';
		$now       = time();
	}

	# $now = "'2015-11-20'::interval";

	my $sth = $dbh->prepare_cached(
		qq{
		WITH RECURSIVE rec (
				root_account_id,
				account_id,
				manager_account_id,
				apath, cycle
    			) as (
	    			SELECT  account_id as root_account_id,
		    			account_id, manager_account_id,
		    			ARRAY[account_id] as apath, false as cycle
	    			FROM    v_account_manager_map
				UNION ALL
	    			SELECT a.root_account_id, m.account_id, m.manager_account_id,
					a.apath || m.account_id, m.account_id=ANY(a.apath)
	    			FROM rec a join v_account_manager_map m
					ON a.manager_account_id = m.account_id
	    			WHERE not a.cycle
		), all_email as (
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
		), hier_email AS (
			SELECT	r.root_account_id as account_id,
					coalesce(p.preferred_last_name, p.last_name) as last_name,
					coalesce(p.preferred_first_name, p.first_name) as first_name,
					concat(
						coalesce(p.preferred_first_name, p.first_name), ' ',
						coalesce(p.preferred_last_name, p.last_name))
								as name,
					coalesce(email_address, concat(login, '\@', default_domain))
							as email,
					apath
			FROM	rec r
					INNER JOIN account a ON a.account_id = r.manager_account_id
					INNER JOIN person p USING (person_id)
					LEFT JOIN email e USING (person_id),
					defaultdomain
		), agg_email AS (
			SELECT account_id, array_agg(name ORDER BY account_id,apath)
						AS hier_name_tier,
					array_agg(email ORDER BY account_id,apath)
						AS hier_email_tier
			FROM	hier_email
			GROUP BY account_id
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
				coalesce(email_address, concat(login, '\@', default_domain))
					AS email_address,
				delegate_email_address,
				approval_utils.message_replace(
						coalesce(apc.email_message, apc.message),
						approval_instance_step_start::timestamp,
						approval_instance_step_due::timestamp,
						full_stab_url := CONCAT(
							'%{stab_root}/approve?actas=', login)
				) as message,
				ap.approval_expiration_action,
				ais.approval_instance_step_name,
				ai.approval_instance_name,
				approval_instance_step_due::date,
				extract(epoch from approval_instance_step_due)
					as due_epoch,
				extract(epoch from (approval_instance_step_due- $dbnow ))
					as due_seconds,
				approval_notify_type,
				extract(epoch from approval_notify_whence) as approval_notify_whence,
				extract(epoch from ($dbnow - approval_notify_whence) )
					as since_last_pester,
				apc.email_subject_prefix,
				apc.email_subject_suffix,
				ae.hier_name_tier,
				ae.hier_email_tier
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
				LEFT JOIN agg_email ae USING (account_id)
				LEFT JOIN (
					SELECT lhs.account_id as account_id,
						email_address AS delegate_email_address
					FROM property p
						JOIN account_collection_account lhs
							USING (account_collection_id)
						JOIN (
							SELECT account_collection_id
								AS property_value_account_coll_id,
								account_Id, person_id
							FROM account_collection_account
							JOIN account USING (account_Id)
						) rhs USING (property_value_account_coll_id)
						INNER JOIN person USING (person_id)
						INNER JOIN email USING (person_id)
				) deleg USING (account_id)
			,defaultdomain
		WHERE   approval_type = 'account'
		AND  ais.is_completed = 'N'
		ORDER BY email_address
		;
	}
	) || die $dbh->errstr;

	$sth->execute || die $sth->errstr;

	my $wsth = $dbh->prepare_cached(
		q{
		INSERT INTO approval_instance_step_notify (
			approval_instance_step_id, approval_notify_type, approval_notify_whence
		) VALUES (
			?, 'email', ?
		)
	}
	) || die $dbh->errstr;

	while ( my $hr = $sth->fetchrow_hashref ) {
		my $email     = $hr->{email_address};
		my $deleg     = $hr->{delegate_email_address};
		my $action    = $hr->{approval_expiration_action};
		my $due       = $hr->{due_seconds};
		my $due_epoch = $hr->{due_epoch};

		my $prefix = $hr->{email_subject_prefix};
		my $suffix = $hr->{email_subject_suffix};

		my $escname  = $hr->{hier_name_tier};
		my $escemail = $hr->{hier_email_tier};

		next if ( $login && $hr->{login} ne $login );

		#
		# An email has been sent and it is not overdue yet, so do nothing.
		# Unless we are due for a reminder, remindergap after the lastt
		# email, in which case, an email is sent.
		#
		if ( $remindergap && $hr->{due_seconds} > 0 ) {
			my $reminderdays = 86400 * $remindergap;

			if (   $hr->{approval_notify_whence}
				&& $hr->{approval_notify_whence} + $reminderdays > $now )
			{
				next;
			}

		} elsif ( $hr->{due_seconds} > 0 && $hr->{approval_notify_whence} ) {
			next;
		}

		#
		# If it is not set to 'pester' then do nothing even if its past the
		# expiration date
		#
		next
		  if (!$hr->{approval_expiration_action}
			|| $hr->{approval_expiration_action} ne 'pester' );

		#
		# if its overdue, and some pestering was not done in the past day
		# pester again.
		#
		my $overdue = ceil(
			( $hr->{due_seconds} < 0 )
			? abs( $hr->{due_seconds} / 86400 )
			: 0
		);
		my $overdueprint = floor(
			( $hr->{due_seconds} < 0 )
			? abs( $hr->{due_seconds} / 86400 )
			: 0
		);
		if ( $overdue
			&& ( $hr->{since_last_pester} && $hr->{since_last_pester} < 86400 )
		  )
		{
			next;
		}

		my $subj = $hr->{approval_instance_name} . " "
		  . $hr->{approval_instance_step_name};

		if ($prefix) {
			$subj = "$prefix $subj";
		}
		if ($suffix) {
			$subj = "$subj $suffix";
		}

		#
		# If a delegate is set, use that, otherwise use the user's email
		# address.  This could be extended to allow the delegate _and_ the
		# person to get it, but that's more than needed.
		#
		my $rcpt = ($deleg) ? $deleg : $email;

		my ( $copy, $threat );
		$threat = "";
		my $klaxonsounded = 0;
		if ( $overdue && $escalationgap ) {
			my $daysover = abs( int( $hr->{due_seconds} / 86400 ) );

			my $numdudes = int( $daysover / $escalationgap ) - 1;
			my $nextdude = int( $daysover / $escalationgap );

			#
			# If escalationlevel is set, then cap how high it goes.
			#
			my $included = $numdudes;
			if ( defined($escalationlevel)
				&& $included > $escalationlevel - 1 )
			{
				$included = $escalationlevel - 1;
			}

			#
			# Build an array into @escalate of everyone who needs to be
			# copied on the email.
			#
			my @escalate;
			for ( my $i = 0 ; $i <= $#{$escemail} && $i <= $included ; $i++ ) {
				push( @escalate, $escemail->[$i] );
				$klaxonsounded++;
			}
			my $next;

			#
			# determine if escalations should happen after this one.
			#
			my $moreescalate = 0;
			#
			# there's a gap but no level cap, so keep on going.
			#
			if ( !defined($escalationlevel) ) {
				$moreescalate = 1;
			} else {

				# we only go up $escalationlevel number of people
				if ( $nextdude < $escalationlevel ) {
					$moreescalate = 1;
				}
			}

			# if escalation is happening and the person delegated to is not
			# responding, also include the original owner.
			if ( $overdue || ( $deleg && scalar @escalate ) ) {
				unshift( @escalate, $email );
			}

			$copy = join( ", ", @escalate );          # cc:
			$rcpt .= " " . join( " ", @escalate );    # envelope receipt

			if ($moreescalate) {
				if ( $#{$escname} >= $nextdude ) {
					$next = $escname->[$nextdude];
				}
				my $escupwhen =
				  $due_epoch + ( ( $nextdude + 1 ) * 86400 * $escalationgap );
				my $duehuman = strftime( "%F", localtime($escupwhen) );

				if ($next) {
					$threat =
					  "After $duehuman, if this has not been processed, $next will begin to be copied on the reminders.";
				}
			}
			if ( $dryrun && $debug ) {
				warn "Escalation Path($numdudes):",
				  Dumper( $escemail, $escname ), "\n";
			}
		}

		#
		# The stab url is put there automatically in the db so that stab and
		# email have the same content. This all needs to be tweaked so that
		# it's possible to include the ?actas=login part. This all needs to be
		# rethunk.
		#

		my $duewords = "";
		if ($overdue) {
			$duewords = sprintf(
				"PLEASE COMPLETE AS SOON AS POSSIBLE.  It was due on %s and is now %d %s overdue. $threat",
				$hr->{approval_instance_step_due},
				$overdueprint + 1,
				( ( $overdueprint == 0 ) ? "day" : "days" )
			);
		} else {
			my $threat = "";
			if ($escalationgap) {
				$threat = sprintf(
					"  If this has not been processed in a timely manner, your %s will automatically be copied on reminder notifications until completed.",
					( $escalationlevel && $escalationlevel == 1 )
					? "manager"
					: "management" );
			}
			$duewords =
			  sprintf( "Please complete your review by end of day %s.%s",
				$hr->{approval_instance_step_due}, $threat );
		}

		my $msg = $hr->{message};

		if ($klaxonsounded) {
			$duewords .=
			  sprintf
			  "\n\nIn order to complete this on behalf of %s %s, please visit %s\n",
			  $hr->{first_name},
			  $hr->{last_name},
			  $stabroot . "/approve?actas=" . $hr->{login};
		}

		$msg =~ s/%\{due_threat}/$duewords/;
		if ($deleg) {
			$msg = sprintf
			  "You are being sent this as the delegate for %s %s.  In order to complete this on their behalf, please visit %s.\n\n%s",
			  $hr->{first_name},
			  $hr->{last_name},
			  $stabroot . "/approve?actas=" . $hr->{login},
			  $msg;
		}

		my $nr = 0;
		if ($updatedb) {
			$nr = $wsth->execute( $hr->{approval_instance_step_id}, $binddbnow )
			  || die $wsth->errstr;
		}
		my $sm;
		if ($dryrun) {
			$sm = IO::Handle->new()            || die "IO::Handle->new: $!";
			$sm->fdopen( fileno(STDOUT), "w" ) || die "dup stdout: $!";
		} else {
			my $f = "";
			$f  = "-f$mailfrom" if ($mailfrom);
			$sm = new FileHandle("| /usr/sbin/sendmail $f $rcpt")
			  || die "$!";
		}

		if ($dryrun) {
			$sm->print("+RCPT: $rcpt\n");
		}

		if ($deleg) {
			$sm->print("To: $deleg\n");
		} else {
			$sm->print("To: $email\n") if ($email);
		}
		$sm->print("Cc: $copy\n")       if ($copy);
		$sm->print("Subject: $subj\n")  if ($subj);
		$sm->print("From: $mailfrom\n") if ($mailfrom);
		$sm->print( "Date: " . email_date() . "\n" );

		if ($deleg) {
			$sm->print( "\nDear ", $hr->{first_name}, "'s delegate,\n" );
		} else {
			$sm->print( "\nDear ", $hr->{first_name}, ",\n" );
		}

		$sm->print( "\n", $msg, "\n\n" );

		if ($signer) {
			$sm->print("\n\n-- $signer\n");
		}
		$sm->close();

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
