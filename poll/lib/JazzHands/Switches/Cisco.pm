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
# Cisco specific code for pulling data.  Where possible, it uses common
# functions in JazzHands::Switches::Core
#

#
# link aggregation:
# IEEE8023-LAG-MIB is not terribly useful
# CISCO-PAGP-MIB+CISCO-LAG-MIB provide some usefulness
#

package JazzHands::Switches::Cisco;

use JazzHands::Switches::Core;
use 5.008007;
use strict;
use warnings;
use SNMP;    # NetSNMP module

our @ISA = qw( JazzHands::Switches::Core );

our $VERSION = '1.0.0';

################################### core ##################################

sub fetch_port_to_vlan {
	my ($self) = @_;

	$self->walk_oid( 'CISCO-VLAN-IFTABLE-RELATIONSHIP-MIB',
		'cviRoutedVlanIfIndex', 0, undef, undef, 1 );
}

#
# stackable's vlan list to figure out what to ping.  almost certainly varies
# by model! [XXX]
#
sub fetch_vlan_list {
	my ($self) = @_;

	if ( $self->{_vlanlist} ) {
		return $self->{_vlanlist};
	}

	my $vlans = $self->walk_oid( 'CISCO-VLAN-IFTABLE-RELATIONSHIP-MIB',
		'cviRoutedVlanIfIndex', 0, undef, undef, 0 );

	$self->{_vlanlist} = $vlans;
	$vlans;

}

#
# returns a hash, key is the interface name, value is a hash of the info
# on the peer, its interface, and hardware type.
#
sub neighbors {
	my ($self) = @_;

	my (%macs);
	if ( $self->{_neighbors} ) {
		return $self->{_neighbors};
	}

	my $ifnames = $self->walk_oid( 'IF-MIB', 'ifName' ) || die;
	my $peername =
	  $self->walk_oid( 'CISCO-CDP-MIB', 'cdpCacheDeviceId', 0 );
	my $peerports =
	  $self->walk_oid( 'CISCO-CDP-MIB', 'cdpCacheDevicePort', 0 );
	my $peerhw = $self->walk_oid( 'CISCO-CDP-MIB', 'cdpCachePlatform', 0 );

	my $rv = {};
	foreach my $peerif ( keys %$peername ) {
		my $name = $ifnames->{$peerif};
		$rv->{$name}             = {};
		$rv->{$name}->{peer}     = $peername->{$peerif};
		$rv->{$name}->{peerif}   = $peerports->{$peerif};
		$rv->{$name}->{peertype} = $peerhw->{$peerif};
	}
	$self->{_neighbors} = $rv;
	$rv;
}

#
# returns a HASH, key is the port, value is an array of the mac addresses
# on that port
#
#
sub mac_to_port {
	my ($self) = @_;

	my (%macs);
	if ( $self->{_macs} ) {
		return $self->{_macs};
	}

	my $in_hostname = $self->hostname;
	my $comm        = $self->community;
	my $sess        = $self->sess;

	my $if2mac = $self->fetch_bridge_if_to_mac() || die;

	# [XXX] may need to do ifName.  This is ubersilly!
	my $ifnames = $self->walk_oid( 'IF-MIB', 'ifDescr' ) || die;

	# this returns ports that are tagged to a given vlan, but will not
	# return ports that are trunked
	my $vlan2port = $self->walk_oid( 'CISCO-VLAN-MEMBERSHIP-MIB', 'vmVlan' )
	  || die;

	my (%vlanlist);
	foreach my $if ( keys(%$vlan2port) ) {
		$vlanlist{ $vlan2port->{$if} }++;
	}

	#
	# cisco is awesome.
	#
	my (%macmap);
	foreach my $vlan ( keys %vlanlist ) {
		my $vlanself = new JazzHands::Switches(
			hostname  => $in_hostname,
			community => "$comm\@$vlan"
		);
		$if2mac = $vlanself->fetch_bridge_if_to_mac($if2mac) || die;
	}

	# use vlan2port to find things that are not on trunked ports
	# use if2mac if you want to show trunked ports, too.
	foreach my $if ( keys(%$if2mac) ) {
		my $name = $ifnames->{$if} || "unknown";
		if ( defined( $if2mac->{$if} ) ) {
			$macs{$name} = $if2mac->{$if};
		}
	}

	$self->{_macs} = \%macs;
	\%macs;
}

#
# returns an HASH.  keys are the grouped ports, and the value
# is an array of the interfaces that make up that group.
#
sub linkaggmap {
	my ($self) = @_;

	my $ifnames = $self->walk_oid( 'IF-MIB', 'ifDescr' ) || die;

	my (@portAStatus) = ( 'unknown', 'off', 'on', 'active', 'passive' );

	my $pagpMember = $self->walk_oid( 'CISCO-PAGP-MIB', 'pagpGroupIfIndex' )
	  || die;
	my $ifAggEnable = $self->walk_oid(
		'CISCO-LAG-MIB',
		'clagAggPortAdminStatus',
		undef,
		sub {
			return ${ $_[1] }[ $_[0] ];
		},
		\@portAStatus
	);

	my ($map) = {};
	foreach my $ifnum ( keys(%$ifnames) ) {
		my $memnum = $pagpMember->{$ifnum};
		next if ( !$memnum );
		next if ( $memnum == $ifnum || $memnum <= 0 );
		next if ( $ifAggEnable->{$ifnum} eq 'off' );
		my $otherside = $ifnames->{$memnum};
		push( @{ $map->{$otherside} }, $ifnames->{$ifnum} );
	}
	$map;

}

sub hsrp {
	my ($self) = @_;

	my $ifnames = $self->walk_oid( 'IF-MIB', 'ifDescr' ) || die;

	#
	# need to handle more than two in an hsrp group, I think?
	#

	$self->uberverbose(1);
	my $virtIps =
	  $self->walk_oid( 'CISCO-HSRP-MIB', 'cHsrpGrpActiveRouter' );
	my $useVirt =
	  $self->walk_oid( 'CISCO-HSRP-MIB', 'cHsrpGrpUseConfigVirtualIpAddr' );
	my $activeR =
	  $self->walk_oid( 'CISCO-HSRP-MIB', 'cHsrpGrpActiveRouter' );
	my $standBy =
	  $self->walk_oid( 'CISCO-HSRP-MIB', 'cHsrpGrpStandbyRouter' );
	my $virtMac = $self->walk_oid(
		'CISCO-HSRP-MIB',
		'cHsrpGrpVirtualMacAddr',
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
	my $pri     = $self->walk_oid( 'CISCO-HSRP-MIB', 'cHsrpGrpPriority' );
	my $preempt = $self->walk_oid( 'CISCO-HSRP-MIB', 'cHsrpGrpPreempt' );

	undef;
}

sub ifnicks {
	my ($self) = @_;

	my $ifnames = $self->walk_oid( 'IF-MIB', 'ifName' )  || die;
	my $ifdescr = $self->walk_oid( 'IF-MIB', 'ifDescr' ) || die;

	my $rv = {};
	foreach my $if ( keys(%$ifdescr) ) {
		next if ( !exists( $ifdescr->{$if} ) );
		next if ( !exists( $ifnames->{$if} ) );
		$rv->{ $ifdescr->{$if} } = $ifnames->{$if};
	}
	$rv;
}

1;
