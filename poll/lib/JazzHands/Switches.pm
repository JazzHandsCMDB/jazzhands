#!/usr/local/bin/perl
# Copyright (c) 2005-2010, Vonage Holdings Corp.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#
# $Id$
#
#
# This is largely a stuff for the interface to the outside world and contains
# methods to be used there.  Depending on the type of router passed in or
# derived in a new, that module is included on the ISA path first.
#
# Common code for all modules should be put in 'Core'.  Hopefully there won't
# be a router/module type called 'Core'.  :)
#

package JazzHands::Switches;

use JazzHands::Switches::Foundry;
use JazzHands::Switches::Cisco;
use JazzHands::Switches::Juniper;
use JazzHands::Switches::Netscreen;
use JazzHands::Switches::Force10;
use JazzHands::Switches::Core;
use JazzHands::Switches::Overridden;
use 5.008007;
use strict;
use warnings;
use SNMP;    # NetSNMP module
use Carp;

#our @ISA = qw( JazzHands::Switches::Foundry JazzHands::Switches::Cisco );
our @ISA = qw( JazzHands::Switches::Overridden JazzHands::Switches::Core );

our $VERSION = '1.0.0';

my $uberverbose = 1;

sub _options {
	my %ret = @_;
	for my $v ( grep { /^-/ } keys %ret ) {
		$ret{ substr( $v, 1 ) } = $ret{$v};
	}
	\%ret;
}

sub new {
	my $class = shift(@_);

	my $self = {};
	bless $self, $class;

	my $vals = _options(@_);

	$self->{_hostname}  = $vals->{hostname}  || return undef;
	$self->{_community} = $vals->{community} || return undef;

	$self->{_sess} = new SNMP::Session(
		DestHost  => $self->{_hostname},
		Community => $self->{_community},
		Version   => 1,
		UseEnums  => 1,
		TimeOUt   => 100000000
	);

	if ( !$self->{_sess} ) {
		warn "could not establish a session!\n";
		return undef;
	}

	if ( !$vals->{type} ) {

		# need to ascertain type and do it smarter.
		my $s = $self->{_sess};
		my $x = $self->walk_oid( "SNMPv2-MIB", "sysDescr" );

		if ( !$x ) {
			warn "could not poll ", $self->{_hostname}, ":",
			  $self->{_community}, " for SNMPv2-MIB::sysDescr: ",
			  $s->{ErrorStr};
			return undef;
		}
		my $str = $x->{0};
		if ( $str =~ /Foundry/ ) {
			$vals->{type} = 'Foundry';
		} elsif ( $str =~ /Cisco/ ) {
			$vals->{type} = 'Cisco';
		} elsif ( $str =~ /Juniper/ ) {
			$vals->{type} = 'Juniper';
		} elsif ( $str =~ /NetScreen/i ) {
			$vals->{type} = 'Netscreen';
		} elsif ( $str =~ /Force10/i ) {
			$vals->{type} = 'Force10';
		} else {

			#return undef;
		}

		$self->{_cache} = {};

	}

	if ( $vals->{type} ) {
		$self->{_type} = $vals->{type};
		return undef
		  if ( $vals->{type} !~
			/^(Cisco|Foundry|Juniper|Netscreen|Force10)$/ );
		unshift( @ISA, "JazzHands::Switches::" . $vals->{type} );
	}

	$self;
}
