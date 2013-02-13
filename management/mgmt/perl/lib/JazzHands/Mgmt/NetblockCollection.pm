#
# Copyright (c) 2011, 2012 Matthew Ragan
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#	   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package JazzHands::Mgmt::Netblock;

use strict;
use warnings;

use DBI;
use JazzHands::Common qw(:all);

use vars qw($VERSION @EXPORT @EXPORT_OK @ISA);

$VERSION = '1.0';

require Exporter;
our @ISA = qw ( Exporter JazzHands::Mgmt);

# The only things that should be in this list that require a JazzHands::Mgmt
# object explicity (typically just Get* functions)

@EXPORT_OK = qw(GetNetblockCollection);
sub import {
	JazzHands::Mgmt::NetblockCollection->export_to_level(1, @_);
}

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self;
	my $opt = _options(@_);

	if ($opt->{jhhandle}) {
		$self = $opt->{jhhandle}->clone;
	} else {
		$self = {};
	}

	$self->{_objecttype} = "membertable";
	$self->{_dbtable} = "netblock_collection";
	$self->{_dbmembertable} = "netblock_collection_netblock";
	$self->{_dbkey} = [ qw(netblock_collection_id) ];
	$self->{_memberkey} = [ qw(netblock_id) ];
	$self->{_current} = {};

	bless $self, $class;
	foreach my $key ( qw( netblock_id is_ipv4_address
			is_single_address can_subnet parent_netblock_id netblock_status
			nic_id nic_company_id description netblock_type ip_universe_id
			reservation_ticket_number )) {
		if ($opt->{$key}) {
			$self->{_current}->{$key} = $opt->{$key};
		}
	}

	if (defined($opt->{ip_address})) {
		my @args = (
			'ip_address', $opt->{ip_address},
			'errors', $opt->{errors});
		if (defined($opt->{netmask_bits})) {
			push @args, 'netmask_bits', $opt->{netmask_bits};
		}
		if (!($self->IPAddress(@args))) {
			return undef;
		}
	}
	return $self;
}

sub GetNetblockCollection {
	my $self = shift;
	my $dbh;
	my $opt = &_options(@_);

	if (ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		SetError($opt->{errors}, "Invalid class reference passed");
		return undef;
	}

	my $match;

	if ( $opt->{netblock_collection_id} ) {
		push @$match, {
			key => netblock_collection_id,
			value => $opt->{netblock_collection_id}
		};
	}
	if ( $opt->{netblock_collection_name} ) {
		push @$match, {
			key => netblock_collection_name,
			value => $opt->{netblock_collection_name}
		};
	}
	if ( $opt->{netblock_collection_type} ) {
		push @$match, {
			key => netblock_collection_type,
			value => $opt->{netblock_collection_type}
		};
	}
	
	my $rows = $self->DBFetch(
		dbhandle => $dbh,
		table => 'netblock_collection',
		match => $match,
		errors => $opt->{errors});
	return undef if (!defined($rows));

	if ($opt->{single})
		if (scalar(@$rows) > 1) {
			SetError($opt->{errors},
				"Multiple values returned to GetNetblockCollections")
			return undef;
		}
	}	

	my $matches = [];
	foreach my $row (@$rows) {
		my $object = new JazzHands::Mgmt::NetblockCollection;
		$object->{_orig} = $row;
		foreach my $key (keys %$row) {
			$object->{_current}->{$key} = $row->{$key};
		}
		last if $opt->{single};
		push @$matches, $object;
	}
	
	if ($opt->{single}) {
		return $matches->[0];
	}
	return $matches;
}

1;
