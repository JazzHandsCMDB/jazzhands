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

package JazzHands::Tickets::RT;

use strict;
use warnings;
use LWP::Protocol::https;
use LWP::UserAgent;
use HTTP::Cookies;
use HTTP::Request::Common qw(POST);
use LWP::Debug qw(+);
use Data::Dumper;
use JSON::PP;
use Net::SSLeay;
use Getopt::Long;
use JazzHands::AppAuthAL;
use DateTime::Format::Strptime;
use URI;

use parent 'JazzHands::Tickets';

### Defaults
our $Errstr;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	my $self = bless {}, $class;

	my %args = @_;

	$self->{_service} = $args{service};
	$self->{_queue}   = $args{queue};

	if ( !$self->{_service} ) {
		$Errstr = "Must specify AppAuthAL service name";
		return undef;
	}
	if ( !$self->{_queue} ) {
		$Errstr = "Must specify RT queue";
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

	my $x = $self->{_webroot} . "/REST/1.0";
	$x;
}

sub _rt_req($$$) {
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

	my $req;
	if ( $action eq 'POST' ) {
		$body = join( "\n", map { "$_: " . $body->{$_} } keys %{$body} ) . "\n";
		$body = [ content => [ undef, "", Content => $body ] ];
		$req = POST( $url, $body, Content_type => 'form-data' );
	} else {
		$req = HTTP::Request->new( $action => $url );

		if ($body) {
			$req->content($body);
		}
	}

	if ( !$req ) {
		$Errstr = $self->errstr("HTTP::Request->new: $!");
		return undef;
	}

	$req->authorization_basic( $self->{_username}, $self->{_password} );

	my $res = $ua->request($req);
	if ( $res->is_success ) {
		my $x = $res->content;
		return $x;
	}
	$self->errstr( "RT Error($url): " . $res->status_line );
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

	#	my $content = "id: ticket/new\n"
	#		.	"Queue: " .$self->{_queue}."\n"
	#		.	"Requestor: $login\n"
	#		.	"Subject: $summary\n"
	#		. 	"Text: $msg";
	#
	#	$content = [ content => [ undef, "", Content => $content ] ];

	my $six_spaces = ' ' x 6;
	$six_spaces = "\n" . $six_spaces;
	$msg = join $six_spaces, split( /\n/, $msg );

	my $args = {
		id        => 'ticket/new',
		Queue     => $self->{_queue},
		Requestor => $login,
		Subject   => $summary,
		Text      => $msg
	};

	if ( my $dude = $self->{_forceassign} ) {
		$args->{Requestor} = $dude;
	}

	my $n = $self->_rt_req( "edit", 'POST', $args );
	$n =~ /Ticket\s+(\d+)\s+create/;
	my $rv = $1;

	$rv;
}

sub get($$) {
	my $self = shift @_;
	my $key  = shift @_;

	my $r = $self->_rt_req( "ticket/$key", 'GET' );

	my $rv = {};
	foreach my $l ( split( /\n/, $r ) ) {
		chomp($l);
		my ( $k, $v ) = split( /:/, $l, 2 );
		next if ( !$k || !$v );
		$v =~ s/^\s*//;
		$v =~ s/\s*$//;

		if ( $k eq 'Status' ) {
			$rv->{status} = $v;
		} elsif ( $k eq 'Resolved' && $v ne 'Not set' ) {
			my $s = DateTime::Format::Strptime->new(
				pattern   => '%a %b %d %H:%M:%S %Y',
				locale    => 'en_US',
				time_zone => 'UTC'
			);
			if ($s) {
				my $dt = $s->parse_datetime($v);
				if ($dt) {
					$s->pattern('%Y-%m-%m %H:%M:%s');
					$rv->{resolutiondate} = $s->format_datetime($dt);

					$s->pattern('%s');
					$rv->{resolutionepoch} = $s->format_datetime($dt);
				}
			}
		} elsif ( $k eq 'Owner' ) {
			$rv->{owner} = $v;
		}
	}
	$rv;
}

1;
