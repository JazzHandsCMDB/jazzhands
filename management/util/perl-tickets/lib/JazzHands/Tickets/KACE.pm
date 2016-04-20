#!/usr/bin/env perl
# Copyright (c) 2016, Ryan D Williams
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

package JazzHands::Tickets::KACE;

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Email::Simple;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP;
use JazzHands::AppAuthAL;
use DateTime::Format::Strptime;

use parent 'JazzHands::Tickets';

### Defaults
our $Errstr;

# This script sends an email directly to KACE.  The SMTP connection will not 
# return until the ticket has been commited.  The ticket number is captured by
# querying the KACE DB.

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	my $self = bless {}, $class;

	my %args = @_;

	$self->{_service}   = $args{service};
	$self->{_queue}   	= $args{queue};

	if ( !$self->{_service} ) {
		$Errstr = "Must specify AppAuthAL service name";
		return undef;
	}
	if ( !$self->{_queue} ) {
		$Errstr = "Must specify KACE queue";
		return undef;
	}

	### checks done, now go and initialize...

	$self->SUPER::new(@_);

	my $appauth = JazzHands::AppAuthAL::find_and_parse_auth( $self->{_service},
		undef, 'email' );
	if ($appauth) {
		if ( ref($appauth) eq 'ARRAY' ) {
			$appauth = $appauth->[0];
		}
		$self->{_smtp_server} 	= $appauth->{'SMTPServer'};
		$self->{_domain} 		= $appauth->{'Domain'};
	}

	$self->{_smtp_transport} = Email::Sender::Transport::SMTP->new(
		{
			host => $self->{_smtp_server}, 
			port => 25
		}
	);

	$self->{_dbh} = JazzHands::DBI->connect( $self->{_service} ) 
		|| die $JazzHands::DBI::errstr;

	$self;
}

sub _get_dbh {
	my $self = shift @_;
	unless ( $self->{_dbh}->ping ) {
		$self->{_dbh} = JazzHands::DBI->connect( $self->{_service} ) 
			|| die $JazzHands::DBI::errstr;
	}
	$self->{_dbh};
}

sub _get_user_email($$) {
	my ($self, $login) = @_;

	my $dbh = $self->_get_dbh;
	my $sth = $dbh->prepare('SELECT EMAIL FROM USER WHERE LDAP_UID = ?')
		|| die $dbh->errstr;
	$sth->execute( $login ) || die $dbh->errstr;
	my $email = $sth->fetchrow_array;
	$sth->finish;

	$email;
}

sub _get_ticket_id {
	my ( $self, $login, $ticket_status, $queue, $summary ) = @_;
	my $ticket_id;

	my $dbh = $self->_get_dbh;
	my $sth = $dbh->prepare(
		q{
			SELECT
				HD_TICKET.ID
			FROM
				HD_TICKET
			INNER JOIN
				USER
				ON USER.ID = HD_TICKET.SUBMITTER_ID
			INNER JOIN
				HD_STATUS
				ON HD_TICKET.HD_STATUS_ID = HD_STATUS.ID
			INNER JOIN
				HD_QUEUE
				ON HD_TICKET.HD_QUEUE_ID = HD_QUEUE.ID
			WHERE
				USER.LDAP_UID = ?
				AND
				HD_STATUS.NAME = ?
				AND
				HD_QUEUE.EMAIL_USER = ?
				AND
				HD_TICKET.TITLE = ?
			ORDER BY
				HD_TICKET.ID DESC
			LIMIT 1
		}
	) || die $dbh->errstr;

	my $tid_timeout = 0;
	while ( !$ticket_id && $tid_timeout != 30 ) {
		sleep 1;
		$sth->execute( $login, $ticket_status, $queue, $summary )
			|| die $dbh->errstr;
		$ticket_id = $sth->fetchrow_array;
		$tid_timeout++;
	}
	$sth->finish;

	if ( !$ticket_id ) {
		$Errstr = $self->errstr("failed to retreive id for ticket:\nlogin: $login\n
			queue: $queue\nsummary: $summary");
	}

	$ticket_id;
}

sub open {
	my $self = shift @_;
	my %args = @_;

	my $login   			= $args{requestor};
	my $msg     			= $args{body};
	my $summary 			= $args{summary};
	my $queue_email 		= $self->{_queue} . '@' . $self->{_domain};
	my $new_ticket_status 	= 'New';
	my $requestor_email		= $self->_get_user_email($login);

	if ( !$login ) {
		$Errstr = $self->errstr("Must specify requestor");
		return undef;
	}

	if ( !$msg ) {
		$Errstr = $self->errstr("Must specify body");
		return undef;
	}

	if ( !$summary ) {
		$Errstr = $self->errstr("Must specify summary");
		return undef;
	}

	my $email = Email::Simple->create(
		header => [
			From    =>  $requestor_email,
			To      =>  $queue_email,
			Subject =>  $summary,
		],
		body => $msg
	);

	if ( $self->{_dryrun} ) {
		print "submitting:\n" . $email->as_string;
		return {};
	}

	sendmail( $email, { transport => $self->{_smtp_transport} } );

	$self->_get_ticket_id( $login, $new_ticket_status,
		$self->{_queue}, $summary );
}

sub get {
	my ( $self, $ticket_id ) = @_;

	my $dbh = $self->_get_dbh;
	my $sth = $dbh->prepare(
		q{
			SELECT
				HD_TICKET.TIME_CLOSED,
				USER.LDAP_UID
			FROM
				HD_TICKET
			INNER JOIN
				HD_STATUS
				ON HD_TICKET.HD_STATUS_ID = HD_STATUS.ID
			INNER JOIN
				USER
				ON HD_TICKET.OWNER_ID = USER.ID
			INNER JOIN
				HD_QUEUE
				ON HD_TICKET.HD_QUEUE_ID = HD_QUEUE.ID
			WHERE
				HD_TICKET.ID = ?
				AND
				HD_STATUS.NAME = 'Closed'
		}
	);
	$sth->execute( $ticket_id ) || die $dbh->errstr;

	my @r = $sth->fetchrow_array;
	unless ( @r ) {
		return {};
	}
	my $s = DateTime::Format::Strptime->new(
		pattern   => '%F %T',
		locale    => 'en_US',
		time_zone => 'America/New_York',
		on_error  => 'croak'
	);
	my $dt = $s->parse_datetime($r[0]); 
	$dt->set_time_zone('UTC');

	my $res_date 	= $s->format_datetime($dt); 
	$s->{pattern} 	= '%s';
	my $res_epoch 	= $s->format_datetime($dt);

	my $rv = {
		resolutiondate 	=> $res_date,
		resolutionepoch	=> $res_epoch,
		owner 			=> $r[1],
		status 			=> 'Resolved'
	};

	$rv;
}

1;
