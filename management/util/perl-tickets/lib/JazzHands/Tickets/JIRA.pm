#!/usr/bin/env perl
# Copyright (c) 2015-2017, Todd M. Kover
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

package JazzHands::Tickets::JIRA;

use strict;
use warnings;
use LWP::Protocol::https;
use LWP::UserAgent;
use HTTP::Cookies;
use LWP::Debug qw(+);
use Data::Dumper;
use JSON::PP;
use Net::SSLeay;
use Getopt::Long;
use JazzHands::AppAuthAL;
use parent 'JazzHands::Tickets';

### Defaults
our $Errstr;

# This script basically makes a post like this:
# curl --insecure -D- -u 'user:pw' -X POST --data @json.txt -H "Content-Type: application/json" https://jira.example.com/rest/api/2/issue/

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	my $self = bless {}, $class;

	my %args = @_;

	$self->{_service}   = $args{service};
	$self->{_project}   = $args{project};
	$self->{_priority}  = $args{priority} || 'Critical';
	$self->{_issuetype} = $args{issuetype} || 'Task';
	$self->{_dryrun}    = 1 if ( $args{dryrun} );
	$self->{_debug}     = 1 if ( $args{debug} );

	if ( !$self->{_service} ) {
		$Errstr = "Must specify AppAuthAL service name";
		return undef;
	}
	if ( !$self->{_project} ) {
		$Errstr = "Must specify jiraproject";
		return undef;
	}

	### checks done, now go and initialize...

	$self->SUPER::new(@_);

	my $appauth =
	  JazzHands::AppAuthAL::find_and_parse_auth( $self->{_service}, undef,
		'web' );
	if ($appauth) {
		if ( ref($appauth) eq 'ARRAY' ) {
			$appauth = $appauth->[0];
		}
		$self->{_webroot}  = $appauth->{'URL'};
		$self->{_username} = $appauth->{'Username'};
		$self->{_password} = $appauth->{'Password'};
	}

	$self;
}

sub get_apiroot {
	my $self = shift @_;

	my $x = $self->{_webroot} . "/rest/api/2";
	$x;
}

sub _jira_req($$$) {
	my ( $self, $what, $action, $body ) = @_;
	my $jiraapiroot = $self->get_apiroot();

	$action = 'GET' if ( !$action );

	my $url = "$jiraapiroot/$what";
	my $ua  = LWP::UserAgent->new(
		ssl_opts => {
			SSL_verify_mode => Net::SSLeay->VERIFY_NONE(),
			verify_hostname => 0
		}
	);
	if ( !$ua ) {
		$Errstr = $self->errstr("LWP::UserAgent->new: $!");
		return undef;
	}
	$ua->agent('jazzhands_tickets/1.0');

	my $req = HTTP::Request->new( $action => $url );

	if ( !$req ) {
		$Errstr = $self->errstr("HTTP::Request->new: $!");
		return undef;
	}

	if ($body) {
		$req->content($body);
	}
	$req->authorization_basic( $self->{_username}, $self->{_password} );
	$req->header( "Content-Type" => "application/json" );

	my $res = $ua->request($req);
	if ( $res->is_success ) {
		if ( $res->content && length( $res->content ) ) {
			return decode_json( $res->content );
		} else {
			return {};
		}
	}
	$self->errstr( "Jira Error($url): " . $res->status_line );
	return undef;
}

sub open {
	my $self = shift @_;
	my %args = @_;

	my $login       = $args{requestor};
	my $msg         = $args{body};
	my $summary     = $args{summary};
	my $assignee    = $args{assignee};
	my $norequestor = $args{norequestor};

	if ( !$login && !$norequestor ) {
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

	my $jiraapiroot = $self->get_apiroot();

	my $jira = {
		'fields' => {
			'project' => { 'key' => $self->{_project} },
			'summary' => $summary,

			# 'labels'      => \@labels,
			'description' => $msg,
			'priority'    => { 'name' => $self->{_priority} },
			'issuetype'   => { 'name' => $self->{_issuetype} },
		},
	};

	if ($login) {
		$jira->{fields}->{'reporter'}->{'name'} = $login;
	}

	if ($assignee) {
		$jira->{fields}->{'assignee'}->{'name'} = $assignee;
	}

	my $j = new JSON::PP;
	my $p = $j->pretty->encode($jira);
	if ( $self->{_debug} ) {
		print "posting: $p";
	}
	if ( $self->{_dryrun} ) {
		return {};
	}

	my $n = $self->_jira_req( "issue/", 'POST', $p );
	if ($n) {
		return $n->{key};
	}
}

sub get($$) {
	my $self = shift @_;
	my $key  = shift @_;

	my $r = $self->_jira_req( "issue/$key", 'GET' );

	if ( !$r || ref($r) ne 'HASH' || !$r->{fields} ) {
		return undef;
	}

	my $rv = {};
	if ( $r->{fields}->{resolutiondate} ) {
		$rv->{resolutiondate} = $r->{fields}->{resolutiondate};
	}

	if ( $r->{fields}->{status} ) {
		#
		# WithPrejudice: This should probably be configurable.  Basically
		# indicate if the reason code was a hard resolution or soft.  The
		# hard/soft logic is used by the approval subsystem to indicate if it
		# should be kicked back to the requestor for further consideration or
		# just end there.
		#
		my $stat = $r->{fields}->{status};
		if ( $stat->{name} =~ /^(Declined)$/ ) {
			$rv->{status} = 'Rejected';
			$rv->{WithPrejudice} = 'Yes';
		} elsif ( $stat->{name} =~ /^(Closed|Resolved|Done|Fixed)/ ) {
			$rv->{status} = 'Resolved';
			$rv->{WithPrejudice} = 'No';
		} else {
			$rv->{status} = 'Rejected';
			$rv->{WithPrejudice} = 'No';
		}

	}
	if ( $r->{fields} && $r->{fields}->{assignee} ) {
		$rv->{owner} = $r->{fields}->{assignee}->{name};
	}

	$rv;
}

sub delete($$) {
	my $self = shift @_;
	my $key  = shift @_;

	my $r = $self->_jira_req( "issue/$key", 'DELETE' );
	$r;
}

1;
