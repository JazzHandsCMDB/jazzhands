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
# Common functions used by any module.  These can be overridden in the
# various device-specific modules if necessary.

package JazzHands::Switches::Core;

use 5.008007;
use strict;
use warnings;
use SNMP;    # NetSNMP module
use JazzHands::Switches::Overridden;
use Net::Netmask;
use Data::Dumper;
use Carp;

our @ISA = qw( );

our $VERSION = '1.0.0';

my $uberverbose = 1;

################################### support ##################################

#
# fetch one oid
#
sub fetch_oid {
	my ( $self, $mib, $suboid ) = @_;

	my $sess = $self->sess;

	my $getme = $mib . "::" . $suboid;
	my $resp  = $sess->get($getme);
	$resp;
}

#
# return a hash of the relevant lhs and the rhs
#
# if field is undef, use the entire rhs, otherwise break it into
# elements and pick the number of the ement.
#
# mapfuncion is a function pointer that is passed the appropriate field
# and that is used to assign the value
#
sub walk_oid {
	my ( $self, $mib, $walkroot, $field, $mapfunc, $funcarg, $swap ) = @_;

	#
	# may only want to cache when intermediate values are not (or
	# incorporate them).
	#
	my $walkthisway = ( ($swap) ? "swap__" : "" ) . $mib . "::" . $walkroot;
	if ( exists( $self->{_cache}->{$walkthisway} ) ) {
		return $self->{_cache}->{$walkthisway};
	}

	my $sess = $self->sess;

	my (%rv);

	my $vb = new SNMP::Varbind( [ $mib . "::" . $walkroot ] );
	my $oid = undef;
	do {
		my $val = $sess->getnext($vb);
		my ( $sillystr, $rhs, $type );
		( $oid, $sillystr, $rhs, $type ) = @$vb;
		if ( $oid eq $walkroot ) {
			my $lhs;
			if ( !defined($field) ) {
				$lhs = $sillystr;
			} else {
				$lhs = ( split( /\./, $sillystr ) )[$field];
			}

			if ($swap) {
				my $x = $lhs;
				$lhs = $rhs;
				$rhs = $x;
			}
			if ( !exists( $rv{$lhs} ) && !defined( $rv{$lhs} ) ) {
				if ($mapfunc) {
					$rhs =
					  &$mapfunc( $rhs, $funcarg,
						$sillystr );
				} else {
					if ( $type eq 'OBJECTID' ) {
						$rhs =
						  SNMP::translateObj( $rhs, 0,
							0 );
					}
				}
				if ( defined($rhs) ) {
					$rv{$lhs} = $rhs;
					print "$oid : $lhs -> ",
					  ( defined($rhs) ) ? $rhs : "--", "\n"
					  if ( $self->uberverbose );
				} else {
					print
					  "$oid : skipping $lhs -> $sillystr\n"
					  if ( $self->uberverbose );
				}
			}
		}

	} until ( $oid ne $walkroot );

	if ( !scalar keys %rv ) {
		undef;
	} else {
		if ($walkthisway) {
			$self->{_cache}->{$walkthisway} = \%rv;
		}
		\%rv;
	}
}

#
# this should be replaced with something per-vendor
#
sub fetch_port_to_vlan {
	return undef;
}

sub fetch_if_physaddresses_map {
	my ($self) = @_;
	my $sess = $self->sess;

	my $mib      = 'IF-MIB';
	my $walkroot = 'ifPhysAddress';
	my $x        = $self->walk_oid(
		$mib,
		$walkroot,
		undef,
		sub {
			my ($in_mac) = @_;
			my $mac = "";
			map { $mac .= sprintf( "%02X:", $_ ) } unpack "CCCCCC",
			  $in_mac;
			$mac =~ s/:$// if ($mac);
			$mac;
		}
	);
	$x;
}

sub fetch_if_physaddresses {
	my ($self) = @_;

	my $x = $self->fetch_if_physaddresses_map;
	my (%rv);
	foreach my $mac ( keys %$x ) {
		next if ( $x->{$mac} eq '--' );
		$rv{ $x->{$mac} }++;
	}
	\%rv;
}

sub fetch_bridge_silly_to_mac {
	my ($self) = @_;
	my $sess = $self->sess;

	my $ignoremacs = $self->fetch_if_physaddresses;

	my $mib      = 'BRIDGE-MIB';
	my $walkroot = 'dot1dTpFdbAddress';
	$self->walk_oid(
		$mib,
		$walkroot,
		undef,
		sub {
			my ($in_mac) = @_;
			my $mac = "";
			map { $mac .= sprintf( "%02X:", $_ ) } unpack "CCCCCC",
			  $in_mac;
			$mac =~ s/:$// if ($mac);
			return undef if ( defined( $ignoremacs->{$mac} ) );
			$mac;
		}
	);
}

sub fetch_bridge_silly_to_if {
	my ($self) = @_;
	my $sess = $self->sess;

	my $mib      = 'BRIDGE-MIB';
	my $walkroot = 'dot1dTpFdbPort';
	$self->walk_oid( $mib, $walkroot );
}

sub fetch_bridge_if_to_mac {
	my ( $self, $src ) = @_;
	my $sess = $self->sess;

	my $macs  = $self->fetch_bridge_silly_to_mac($sess);
	my $ports = $self->fetch_bridge_silly_to_if($sess);
	my $ifs   = $self->walk_oid( 'BRIDGE-MIB', 'dot1dBasePortIfIndex' );

	my (%rv);
	$src = \%rv if ( !$src );
	foreach my $p ( keys(%$macs) ) {
		if ( !$ports->{$p} ) {
			warn "WHOA, can't find a mac for silly $p";
			next;
		}
		my $if = $ports->{$p};
		$if = $ifs->{ $ports->{$p} }
		  if ( $ifs && $ifs->{ $ports->{$p} } );
		push( @{ $src->{$if} }, $macs->{$p} );
		print "fbim: ", $macs->{$p}, " is on ", $ports->{$p}, "\n"
		  if ( $self->uberverbose );
	}
	$src;
}

sub intaddrs {
	my ( $self, $augment ) = @_;

	my $vlanToIf = $self->fetch_port_to_vlan;

	my $ifnames = $self->iflist || confess $self->{_community};
	my $physaddr = $self->fetch_if_physaddresses_map() || die;

	my $iptoInt = $self->walk_oid( 'IP-MIB', 'ipAdEntIfIndex' ) || die;
	my $ipMask  = $self->walk_oid( 'IP-MIB', 'ipAdEntNetMask' ) || die;

	my ($rv);
	if ($augment) {
		$rv = $augment;
	} else {
		$rv = {};
	}
	foreach my $ip ( keys(%$iptoInt) ) {
		my $ifnum  = $iptoInt->{$ip};
		my $ifname = $ifnames->{$ifnum};
		my $mask   = $ipMask->{$ip};
		my $x      = new Net::Netmask( $ip, $mask );
		if ( !exists( $rv->{$ifname} ) ) {
			$rv->{$ifname} = {};
			if ( defined( $physaddr->{$ifnum} ) ) {
				$rv->{$ifname}->{mac} = $physaddr->{$ifnum};
			}
			if (       defined($vlanToIf)
				&& defined( $vlanToIf->{$ifnum} ) )
			{
				$rv->{$ifname}->{vlan} = $vlanToIf->{$ifnum};
			}
		}

		push( @{ $rv->{$ifname}->{ip} }, "$ip/" . $x->bits );
	}
	$rv;
}

sub ifnicks {
	\{};
}

sub physicalifs {
	my ($self) = @_;

	my $ifTypes = $self->walk_oid( 'IF-MIB', 'ifType' ) || die;

	foreach my $if ( keys %$ifTypes ) {

		# [XXX] need to expand beyond ethernet
		# print "considering $if $ifTypes->{$if}\n";
		next if ( $ifTypes->{$if} eq 'ethernetCsmacd' );
		next if ( $ifTypes->{$if} eq 'gigabitEthernet' );
		delete( $ifTypes->{$if} );
	}
	$ifTypes;
}

sub hostname {
	my $self = shift;
	if (@_) { $self->{_hostname} = shift }
	return $self->{_hostname};
}

sub community {
	my $self = shift;
	if (@_) { $self->{_community} = shift }
	return $self->{_community};
}

sub sess {
	my $self = shift;
	if (@_) { $self->{_sess} = shift }
	return $self->{_sess};
}

sub uberverbose {
	my $self = shift;
	if (@_) { $self->{_uberverbose} = shift }
	return $self->{_uberverbose};
}

# primarily foundry
sub fetch_bogus_ifips {
	return undef;
}

1;
