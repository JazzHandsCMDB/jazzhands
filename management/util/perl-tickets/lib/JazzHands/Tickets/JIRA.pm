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
	$self->{_issuetype} = $args{priority} || 'Task';

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
		$self->{_webroot} = $appauth->{'URL'};
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
		return decode_json( $res->content );
	}
	$self->errstr( "Jira Error($url): " . $res->status_line );
	return undef;
}

sub open {
	my $self = shift @_;
	my %args = @_;

	my $login   = $args{requestor};
	my $msg     = $args{body};
	my $summary = $args{summary};

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

	my $jiraapiroot = $self->get_apiroot();

	my $jira = {
		'fields' => {
			'project' => { 'key' => $self->{_project} },
			'summary' => $summary,

			# 'labels'      => \@labels,
			'description' => $msg,
			'priority'    => { 'name' => $self->{_priority} },
			'issuetype'   => { 'name' => $self->{_issuetype} },
			'reporter'    => { 'name' => $login },
		},
	};
	my $j = new JSON::PP;
	my $p = $j->pretty->encode($jira);
	if ( $self->{_dryrun} ) {
		print "posting: $p";
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
		my $stat = $r->{fields}->{status};
		if ( $stat->{name} =~ /^(Closed|Resolved|Done)/ ) {
			$rv->{status} = 'Resolved';
		} else {
			$rv->{status} = $stat->{name};
		}
	}
	if ( $r->{fields} && $r->{fields}->{assignee} ) {
		$rv->{owner} = $r->{fields}->{assignee}->{name};
	}

	$rv;
}

1;
