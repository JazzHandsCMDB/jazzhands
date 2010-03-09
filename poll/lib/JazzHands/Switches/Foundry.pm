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
# Foundry specific code for pulling data.  Where possible, it uses common
# functions in JazzHands::Switches::Core
#

package JazzHands::Switches::Foundry;

use JazzHands::Switches::Core;
use 5.007007;
use strict;
use warnings;
use SNMP;    # NetSNMP module
use Data::Dumper;
use Carp;

our @ISA = qw( JazzHands::Switches::Core );

our $VERSION = '1.0.0';

#
# stackable's vlan list to figure out what to ping.  almost certainly varies
# by model! [XXX]
#
sub fetch_vlan_list {
	my ($self) = @_;

	if ( $self->{_vlanlist} ) {
		return $self->{_vlanlist};
	}

	my $vlans =
	  $self->walk_oid( 'FOUNDRY-SN-SWITCH-GROUP-MIB', 'snVLanByPortVLanId',
		undef, undef, undef, 1 );

	$self->{_vlanlist} = $vlans;
	$vlans;

}

sub fetch_port_to_vlan {
	my ($self) = @_;

	my (%rv);
	my $mib = 'FOUNDRY-SN-SWITCH-GROUP-MIB';

	# this is effing stupid.
	my $iftoIdx =
	  $self->walk_oid( 'IF-MIB', 'ifName', undef, undef, undef, 1 );

	my $vlanToVE = $self->walk_oid( $mib, "snVLanByPortCfgRouterIntf" );

	my $rv = {};
	foreach my $vlan ( keys %$vlanToVE ) {
		next if ( !$vlanToVE->{$vlan} );
		my $ifname = "ve" . $vlanToVE->{$vlan};    # yay!  gross
		$rv->{ $iftoIdx->{$ifname} } = $vlan;
	}

	# everything under here MAY be needed, particularly if physical
	# interfaces need to be consulted.  Its not clear if that's
	# relevant, because of how foundry does vlans...

	#[XXX] - maybe needed?  it maps ifIndexes to foundry names, which is
	#handy for some smarts, but not clear where its used, especially
	#since the name actually needs to be constructed.
	#my $veToIf = $self->walk_oid($mib, "snIfIndexLookupInterfaceId");

	#	my $defaultVlan = $self->walk_oid($mib, "snSwDefaultVLanId");
	#	my $StpVlan = $self->walk_oid($mib, "snSwSingleStpVLanId");
	#	my(@vlanignore);
	#	foreach my $x (values %$defaultVlan) {
	#		push(@vlanignore, $x);
	#	}
	#	foreach my $x (values %$StpVlan) {
	#		push(@vlanignore, $x);
	#	}

	# consider snVLanByPortMemberVLanId for numbered physical interfaces.
	# this can probably used to get a list of all vlans, though the format
	# is most confusing.
	$rv;
}

sub fetch_foundryport_to_if_bigiron {
	my ($self) = @_;

	my (%rv);

	my $mib      = "FOUNDRY-SN-SWITCH-GROUP-MIB";
	my $walkroot = "snIfIndexLookupIfIndex";
	$self->walk_oid( $mib, $walkroot );
}

sub fetch_foundryport_to_if_fastiron {
	my ($self) = @_;

	my (%rv);

	my $mib      = "FOUNDRY-SN-SWITCH-GROUP-MIB";
	my $walkroot = "snSwPortIfIndex";
	my $x        = $self->walk_oid( $mib, $walkroot )
	  || $self->fetch_foundryport_to_if_bigiron();

}

#############################################################################
#
# fuckers
#
sub fetch_port_tag_status_fgs {
	my ($self) = @_;

	my (%rv);

	my $mib      = "FOUNDRY-SN-SWITCH-GROUP-MIB";
	my $walkroot = "snSwPortInfo.1.1.3";
	my $x        = $self->walk_oid( $mib, $walkroot );
	$x;
}

sub fetch_port_tag_status_bigiron {
	my ($self) = @_;

	my (%rv);

	my $mib      = "FOUNDRY-SN-SWITCH-GROUP-MIB";
	my $walkroot = "snFdpCachePortTagMode";
	$self->walk_oid( $mib, $walkroot, 0 )
	  || $self->fetch_port_tag_status_fgs();
}

sub fetch_port_tag_status_fastiron {
	my ($self) = @_;

	my (%rv);

	my $mib      = "FOUNDRY-SN-SWITCH-GROUP-MIB";
	my $walkroot = "snSwPortInfoTagMode";
	my $x        = $self->walk_oid( $mib, $walkroot, undef )
	  || $self->fetch_port_tag_status_bigiron();
}

sub fetch_port_tag_status_mlx {
	my ($self) = @_;

	my (%rv);

	my $mib = "FOUNDRY-SN-SWITCH-GROUP-MIB";

	my $defaultVlan = $self->walk_oid( $mib, "snSwDefaultVLanId" );
	my $StpVlan     = $self->walk_oid( $mib, "snSwSingleStpVLanId" );
	my (@vlanignore);
	foreach my $x ( values %$defaultVlan ) {
		push( @vlanignore, $x );
	}
	foreach my $x ( values %$StpVlan ) {
		push( @vlanignore, $x );
	}

	my $walkroot = "snVLanByPortMemberTagMode";

	# note, for tagged ports, this will end up writing multiple
	# entries, since you also figure out which vlans are tagged to a port
	# from this mib.
	my $x = $self->walk_oid(
		$mib,
		$walkroot,
		1,
		sub {
			my ( $x, $y ) = split( /\./, $_[2] );
			return undef if ( grep( $_ eq $x, @vlanignore ) );
			return $_[0];
		}
	) || $self->fetch_port_tag_status_fastiron;
}
#############################################################################

sub neighbors {
	my ($self) = @_;

	if ( $self->{_neighbors} ) {
		return $self->{_neighbors};
	}

	my $ifnames = $self->walk_oid( "IF-MIB", "ifName" ) || die;
	my $peername =
	  $self->walk_oid( 'FOUNDRY-SN-SWITCH-GROUP-MIB', 'snFdpCacheDeviceId',
		0 )
	  || die;
	my $peerports =
	  $self->walk_oid( 'FOUNDRY-SN-SWITCH-GROUP-MIB',
		'snFdpCacheDevicePort', 0 )
	  || die;
	my $peerhw =
	  $self->walk_oid( 'FOUNDRY-SN-SWITCH-GROUP-MIB', 'snFdpCachePlatform',
		0 )
	  || die;

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

sub if_to_vlan {
	my ($self) = @_;

	# [XXX] probably be combined with stuff in mac_to_port and stored
	my $vlan2port = $self->fetch_port_to_vlan() || die;
	my $portmap = $self->fetch_foundryport_to_if_fastiron() || die; # fports

}

#
# should return a hash of interfaces and the macs on those interfaces
#
sub mac_to_port {
	my ($self) = @_;

	if ( $self->{_macs} ) {
		return $self->{_macs};
	}

	my $if2mac = $self->fetch_bridge_if_to_mac() || confess;
	my $ifnames = $self->walk_oid( "IF-MIB", "ifName" ) || confess;
	my $vlan2port = $self->fetch_port_to_vlan()        || confess; # ifports
	my $tagmap    = $self->fetch_port_tag_status_mlx() || die;     # fports
	my $fportmap = $self->fetch_foundryport_to_if_fastiron()
	  || die;                                                      # fports

	## XXX - these are both vlans, need to pass an ignore function, I guess
	## XXX - consider ignoring FOUNDRY-SN-SWITCH-GROUP-MIB::snSwDefaultVLanId
	## XXX - consider ignoring FOUNDRY-SN-SWITCH-GROUP-MIB::snSwSingleStpVLanId.0

	my $fdp_peers = $self->neighbors();

	my (%macs);
	foreach my $fport ( keys(%$tagmap) ) {
		my $if = $fportmap->{$fport};
		my $name = $ifnames->{$if} if ($if);
		if ( !$tagmap->{$fport} || $tagmap->{$fport} ne 'untagged' ) {
			print "theoretically skipping ($name) ",
			  ( $tagmap->{$fport} ) ? $tagmap->{$fport} : "--", "\n"
			  if ( $self->uberverbose );
			print "\tmaps to ", $fdp_peers->{$name}, "\n"
			  if ( $fdp_peers->{$name} && $self->uberverbose );
			next;
		}

		#next if(!exists($if2mac->{$if}));	# nothing there.
		# print "XX: $name -> ", join(" ", @{$vlan2port->{$if}}), "\n";
		if ( defined( $if2mac->{$if} ) ) {
			my $taggy = $tagmap->{$fport} || "--unknown--";

		 #print "$name($taggy) -> ", join(" ", @{$if2mac->{$if}}), "\n";
			$macs{$name} = $if2mac->{$if};
		}
	}
	$self->{_macs} = \%macs;
	\%macs;
}

sub linkaggmap {
	my ($self) = @_;

	# $self->uberverbose(1);
	my $ifnames = $self->walk_oid( "IF-MIB", "ifName" ) || die;

	my $trunkgrp =
	  $self->walk_oid( "FOUNDRY-SN-SWITCH-GROUP-MIB", "snMSTrunkIfList" )
	  || die;

	my $rv = {};
	for my $lhs ( keys(%$trunkgrp) ) {
		my $x    = $trunkgrp->{$lhs};
		my $lhif = $ifnames->{$lhs};
		for my $innerif ( unpack( "n*", $x ) ) {
			push( @{ $rv->{$lhif} }, $ifnames->{$innerif} );
		}
	}

	\%$rv;
}

#
# The foundry stackable FGSs set the ip address for the device in some funky
# way that actually isn't associated with an interface even though the mib
# somewhat implies that it is.  If this is set, it appears that the interface
# with this ip needs to be treated special.
#
sub fetch_bogus_ifips {
	my ($self) = @_;

}

sub vrrp {
	my ($self) = @_;

	undef;
}

1;
