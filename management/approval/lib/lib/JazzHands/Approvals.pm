#!/usr/bin/env perl
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

package JazzHands::Approvals;

use strict;
use warnings;
use Data::Dumper;
use JSON::PP;
use JazzHands::DBI;
use IO::Select;
use POSIX;
use Sys::Syslog;

=head1 NAME

Approvals - 
=head1 SYNOPSIS

Approvals - perl module that handles approvals (just for tickets now)

=head1 DESCRIPTION

=head1 AUTHORS

Todd M. Kover <kovert@omniscient.com>

=cut 

#############################################################################

our $Errstr;

sub daemonize {
	my $self = shift @_;
	if ( !( open STDOUT, '>', '/dev/null' ) ) {
		$Errstr = "unable to redirect stdout: $!";
		if ($self) { $self->errstr($Errstr); }
		return undef;
	}

	if ( !( open STDIN, '<', '/dev/null' ) ) {
		$Errstr = "unable to redirect stdin : $!";
		if ($self) { $self->errstr($Errstr); }
		return undef;
	}
	if ( !( defined( my $pid = fork ) ) ) {
		$Errstr = "fork(): $!";
		if ($self) { $self->errstr($Errstr); }
		return undef;
	} else {
		exit if $pid;
	}
	setsid();

	# open STDERR, '>&STDOUT';
	1;
}

sub dryrun {
	my $self = shift @_;
	$self->set( 'dryrun', shift @_ );
}

sub set {
	my $self = shift @_;

	my $x = "_" . shift @_;

	if ( my $v = shift @_ ) {
		$self->{$x} = $v;
	}
	$self->{$x};
}

sub errstr($$;$) {
	my $self = shift @_;

	$self->set( 'errstr', @_ );
}

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	my $self = bless {}, $class;

	my %args = @_;

	$self->{_service} = $args{service};
	$self->{_apptype} = $args{type};
	$self->{_verbose} = $args{verbose};
	$self->{_myname} = $args{myname};
	if ( $args{debug} ) {
		$self->{_debug} = $self->{_verbose} = $args{debug};
	}

	if ( !$self->{_service} ) {
		$Errstr = "Must specify Databse service name";
		return undef;
	}
	if ( !$self->{_apptype} ) {
		$Errstr = "Must specify Approval Type";
		return undef;
	}
	$self->{_dbh} =
	  JazzHands::DBI->connect( $self->{_service}, { AutoCommit => 0 } );

	if ( !$self->{_dbh} ) {
		$Errstr = $JazzHands::DBI::errstr;
		return undef;
	}

	if ( $args{daemonize} ) {
		$self->daemonize() || return undef;
		$self->{_dbh} = $self->{_dbh}->clone();

		$self->{_daemon} = 1;
		$self->{_shouldsyslog} = 1;

		my $name = $self->{_myname} || 'approval-app';
		openlog($name, 'ndelay,nofatal', 'daemon');
	}

	$self;
}

sub get_account_id($$) {
	my ( $self, $login ) = @_;

	my $dbh = $self->{_dbh};

	my $sth = $dbh->prepare_cached(
		qq{
		select	account_id
		from	v_corp_family_account
		where	login = ?
		LIMIT 1
	}
	) || die $dbh->errstr;

	$sth->execute($login) || die $sth->errstr;
	my ($id) = $sth->fetchrow_array;
	$sth->finish;
	$id;
}

sub open_new_issues($$) {
	my ( $self, $tix ) = @_;


	my $dbh = $self->{_dbh};
	#
	# Build $map up to have a list of dcs and a human readable list of names that
	# should have access
	#
	my $map = {};
	my $sth = $dbh->prepare_cached(
		qq{
	       SELECT approver_account_id, aii.*, ais.is_completed, a.login,
					coalesce(p.preferred_first_name,  p.first_name) as manager_first_name,
					coalesce(p.preferred_last_name,  p.last_name) as manager_last_name
		FROM    approval_instance ai
			INNER JOIN approval_instance_step ais
			    USING (approval_instance_id)
			INNER JOIN approval_instance_item aii
			    USING (approval_instance_step_id)
			INNER JOIN approval_instance_link ail
			    USING (approval_instance_link_id)
			INNER JOIN account a ON
				a.account_id = ais.approver_account_id
			INNER JOIN person p USING (person_id)
		Where     approval_type = ?
		AND     ais.is_completed = 'N'
			AND		ais.external_reference_name IS NULL
		ORDER BY approval_instance_step_id, approved_lhs, approved_category
	}
	) || die $dbh->errstr;

	$sth->execute( $self->{_apptype} ) || die $sth->errstr;

	my $catmap = {
		'ReportingAttest' => 'Manager',
		'department'      => 'Department',
		'position_title'  => 'Title',
	};

	while ( my $hr = $sth->fetchrow_hashref ) {
		my $step = $hr->{approval_instance_step_id};
		my $lhs  = $hr->{approved_lhs};

		if ( !defined( $map->{$step}->{$lhs} ) ) {
			$map->{$step}->{login}                     = $hr->{login};
			$map->{$step}->{hr}                        = $hr;
			$map->{$step}->{approval_instance_step_id} = $step;
		}

		my $category = $hr->{approved_category} || $hr->{approved_label};

		if ( $catmap->{$category} ) {
			$category = $catmap->{$category};
		}

		$map->{$step}->{changes}->{$lhs}->{$category} =
		  $hr->{approved_rhs};

	}

	$sth->finish;

	my $header = qq{
		During the regular audit of organizational information,
		the manager of record requested the following changes.
		Please update the HR system, accordingly or work with
		the manager if there are issues with the changes.  When
		complete, please resolve this ticket/issue so the changes can
		be sent back to the manager for verification.
	};

	my $wsth = $dbh->prepare_cached(
		qq{
		UPDATE approval_instance_step
		SET external_reference_name = :name
		WHERE approval_instance_step_id = :id
	}
	) || die $dbh->errstr;

	foreach my $step ( sort keys( %{$map} ) ) {
		my $msg  = "$header\n";
		my $name = $map->{$step}->{hr}->{manager_first_name} . " "
		  . $map->{$step}->{hr}->{manager_last_name};
		my $login = $map->{$step}->{login};
		foreach my $dude ( sort keys %{ $map->{$step}->{changes} } ) {
			$msg .= "\nChanges for $dude:\n";

			my $x = $map->{$step}->{changes}->{$dude};
			$msg .=
			  join( "\n", map { "* $_ becomes '" . $x->{$_} . "'" } keys %{$x} )
			  . "\n";
		}
		$msg =~ s/^\t{1,3}//mg;
		my $summary = "Organizational Corrections for $name ($login)";

		if ( !$self->{_dryrun} ) {
			my $tid = $tix->open(
				requestor => $login,
				body      => $msg,
				summary   => $summary
			);

			# XXX error checking!
			$wsth->bind_param( ':name', $tid )  || die $sth->errstr;
			$wsth->bind_param( ':id',   $step ) || die $sth->errstr;
			$wsth->execute || die $sth->errstr;
			$wsth->finish;

			$self->log( 'verbose', "Opened $tid for $step" );
		} else {
			warn "would send ", Dumper( $login, $msg, $summary, $step );
		}
	}
	1;
}

sub check_pending_issues($$) {
	my ( $self, $tix ) = @_;

	my $dbh = $self->{_dbh};
	my $sth = $dbh->prepare_cached(
		qq{
	       SELECT approver_account_id, aii.*, ais.is_completed, a.login,
					ais.external_reference_name
		FROM    approval_instance ai
			INNER JOIN approval_instance_step ais
			    USING (approval_instance_id)
			INNER JOIN approval_instance_item aii
			    USING (approval_instance_step_id)
			INNER JOIN approval_instance_link ail
			    USING (approval_instance_link_id)
			INNER JOIN account a ON
				a.account_id = ais.approver_account_id
		Where     approval_type = ?
		AND     ais.is_completed = 'N'
			AND		aii.is_approved IS NULL
			AND		ais.external_reference_name IS NOT NULL
		ORDER BY approval_instance_step_id, approved_lhs, approved_category
	}
	) || die $dbh->errstr;

	$sth->execute( $self->{_apptype} ) || die $sth->errstr;

	my $wsth = $dbh->prepare_cached(
		qq{
		SELECT approval_utils.approve(
			approval_instance_item_id := ?,
			approved := ?,
			approving_account_id := ?
		);
	}
	) || die $dbh->errstr;

	my $cache = {};
	while ( my $hr = $sth->fetchrow_hashref ) {
		my $aii_id = $hr->{approval_instance_item_id};
		my $key    = $hr->{external_reference_name};

		if ( !exists( $cache->{$key} ) ) {
			my $r = $tix->get($key);
			if ( $r->{resolutiondate} ) {
				$cache->{$key}->{status}   = 'resolved';
				$cache->{$key}->{approved} = 'Y';
			}

			if ( $r->{owner} ) {
				$cache->{$key}->{assignee} = $r->{owner};
				$cache->{$key}->{acctid} =
				  $self->get_account_id( $r->{owner} );
			}
		}
		if ( defined( $cache->{$key}->{approved} ) ) {
			if ( $self->{_dryrun} ) {
				$self->log( 'debug',
					"For $key, resolving $aii_id (not really)\n" );
				next;
			}
			$self->log( undef, "For $key, resolving $aii_id\n" );
			$wsth->execute(
				$aii_id,
				$cache->{$key}->{approved},
				$cache->{$key}->{acctid}
			) || die $wsth->errstr;
			$self->log( 'debug', "updated db" );
		}
	}
	$sth->finish;
	$wsth->finish;
	1;
}

############################################################################

sub onetime {
	my ( $self, $tix ) = @_;

	my $rv;
	$rv = $self->check_pending_issues($tix) || return undef;
	$rv = $self->open_new_issues($tix) || return undef;
	$self->{_dbh}->commit;
	1;
}

sub mainloop {
	my ( $self, $tix ) = @_;

	$self->onetime($tix);

	my $dbh = $self->{_dbh};
	$dbh->commit;

	$dbh->do("LISTEN approval_instance_item_approval_change;")
	  || die $dbh->errstr;

	my $pgsock = $dbh->{pg_socket};

	my $timeout = $self->{_timeout} || 60;

	# NOTE: AutoCommit must be set (or some similar behavior) while waiting
	# on the socket, otherwise the notifies never come through.

	my $s = IO::Select->new();
	$s->add($pgsock);
	$dbh->{AutoCommit} = 1;
	$self->log( undef, 'About to begin loop' );
	do {
		my @ready = $s->can_read($timeout);
		$self->log( 'debug', "wake up - ", $#ready );
		$dbh->{AutoCommit} = 0;

		$self->check_pending_issues($tix);

		foreach my $fh (@ready) {
			if ( $fh == $pgsock ) {
				my $tally = 0;
				while ( my $notify = $dbh->pg_notifies ) {
					$tally++;
					my ( $name, $pid, $payload ) = @{$notify};
					$self->log( 'debug',
						"notify received: $name / $pid / $payload" );
				}
				$self->log( 'verbose', "received $tally notifies" );
				$self->open_new_issues($tix);
			} else {
				$self->log( undef, "received fh $fh, which was unexpected." );
			}

			if ( 0 && !$dbh->ping() ) {
				$dbh->disconnect;
				$dbh = undef;
				$dbh = reconnect();
				$s->remove($pgsock);
				$pgsock = $dbh->{pg_socket};
				$s->add($pgsock);
			}
		}
		$dbh->commit;
		$dbh->{AutoCommit} = 1;
		$dbh->do("LISTEN approval_instance_item_approval_change;")
		  || die $dbh->errstr;
	} while (1);

	return (0);
}

sub log {
	my $self = shift @_;
	my $pri  = shift @_;

	if ($pri) {
		if ( $pri eq 'debug' && !$self->{_debug} ) {
			return;
		}
		if ( $pri eq 'verbose' && !$self->{_verbose} ) {
			return;
		}
	}

	if($self->{_shouldsyslog}) {
		$pri = 'notice' if(!$pri);
		syslog($pri, join(" ", @_));
	} else {
		warn join( " ", @_ ), "\n";
	}
}

sub DESTROY {
	my $self = shift @_;

	if ( my $dbh = $self->{_dbh} ) {
		$dbh->disconnect;
	}
	undef( $self->{_dbh} );
}

1;
