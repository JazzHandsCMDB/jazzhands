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

package JazzHands::Tickets;

use strict;
use warnings;
use Data::Dumper;
use JSON::PP;
use JazzHands::DBI;
use JazzHands::AppAuthAL;
use IO::Select;

=head1 NAME

=head1 DESCRIPTION

=head1 AUTHORS

Todd M. Kover <kovert@omniscient.com>

=cut 

our $Errstr;

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

#
# sets up general purpose stuff used by all ticket interfaces
#
sub new {
	my $self = shift @_;
	my %args = @_;

	my $service = $self->{_service};

	$self;
}

sub errstr($$;$) {
	my $self = shift @_;

	$self->set( 'errstr', @_ );
}

1;
