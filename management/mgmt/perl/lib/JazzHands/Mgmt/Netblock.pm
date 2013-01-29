#
# Copyright (c) 2012, 2013 Matthew Ragan
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
use JazzHands::Common;
use JazzHands::GenericDB qw(_dbx);
use NetAddr::IP;
use	Data::Dumper;

use vars qw($VERSION @EXPORT @EXPORT_OK @ISA);

$VERSION = '1.0';

require Exporter;
our @ISA = qw ( Exporter JazzHands::Mgmt);

# The only things that should be in this list that require a JazzHands::Mgmt
# object explicity (typically just Get* functions)

@EXPORT_OK = qw(GetNetblock);
sub import {
	JazzHands::Mgmt::Netblock->export_to_level(1, @_);
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

	$self->{_objecttype} = "objecttable";
	$self->{_dbtable} = "netblock";
	$self->{_dbkey} = [ qw(netblock_id) ];
	$self->{_current} = {};
	$self->{_insertafterhook} = \&_afterhook;
	$self->{_updateafterhook} = \&_afterhook;

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


sub GetNetblock {
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

	SetError($opt->{debug}, "Totally here");
	my $match;

	if ( $opt->{netblock_id} ) {
		push @$match, {
			key => 'netblock_id',
			value => $opt->{netblock_id}
		};
		$opt->{single} = 1;
	} else {
		push @$match, {
			key => 'ip_universe_id',
			value => $opt->{ip_universe_id} || 0
		};
	}
	
	if ( $opt->{ip_address} ) {
		if ( ref($opt->{ip_address}) ) {
			push @$match, {
				key => 'ip_address',
				value => sprintf("%s", $opt->{ip_address})
			};
			push @$match, {
				key => 'netmask_bits',
				value => $opt->{ip_address}->masklen
			};
		} elsif ($opt->{ip_address} && $opt->{netmask_bits}) {
			push @$match, {
				key => 'ip_address',
				value => $opt->{ip_address}
			};
			push @$match, {
				key => 'netmask_bits',
				value => $opt->{netmask_bits}
			};
		}
	}

	foreach my $key ( qw(netblock_type parent_netblock_id is_single_address
			can_subnet is_ipv4_address) ) {
		if ( $opt->{$key} ) {
			push @$match, {
				key => $key,
				value => $opt->{$key}
			};
		}
	}

	my $rows = JazzHands::GenericDB->DBFetch(
		dbhandle => $dbh,
		table => 'netblock',
		match => $match,
		errors => $opt->{errors},
		debug => $opt->{debug});
	return undef if (!defined($rows));

	if ($opt->{single}) {
		if (scalar(@$rows) > 1) {
			SetError($opt->{errors},
				"Multiple values returned to GetNetblock");
			return undef;
		}
	}	

	my $matches = [];
	foreach my $row (@$rows) {
		my $object = new JazzHands::Mgmt::Netblock(jhhandle => $self);
		$object->{_orig} = $row;
		foreach my $key (keys %$row) {
			$object->{_current}->{$key} = $row->{$key};
		}
		$object->{ip_address} = NetAddr::IP->new($row->{ip_address});
		push @$matches, $object;
		last if $opt->{single};
	}
	
	if ($opt->{single}) {
		SetError($opt->{debug}, Dumper($matches->[0]));
		return $matches->[0];
	}
	return $matches;
}

sub hash {
	my $self = shift;

	return $self->{_current};
};

sub IPAddress {
	my $self = shift;
	my $opt = &_options(@_);

	if (!exists($opt->{ip_address})) {
		return $self->{ip_address};
	}

	if (!ref($opt->{ip_address})) {
		my $ip_address;
		if ($opt->{ip_address} =~ m%[0-9:.]+/\d+$%) {
			$ip_address = NetAddr::IP->new($opt->{ip_address});
			if (!$ip_address) {
				SetError($opt->{errors}, 
					sprintf("Invalid network address: %s",
						$opt->{ip_address}));
				return undef;
			}
		} elsif ($opt->{netmask_bits}) {
			$ip_address = NetAddr::IP->new(
				sprintf("%s/%d", $opt->{ip_address}, $opt->{netmask_bits}));
			if (!$ip_address) {
				SetError($opt->{errors}, 
					sprintf("Invalid network address: %s/%s",
						$opt->{ip_address}, $opt->{netmask_bits}));
				return undef;
			}
		} else {
			SetError($opt->{errors}, 
				"netmask_bits must be set or address must be given with /");
			return undef;
		}
		$opt->{ip_address} = $ip_address;
	}
	$self->{ip_address} = $opt->{ip_address};
	$self->{_current}->{ip_address} = sprintf("%s", $opt->{ip_address});
	$self->{_current}->{netmask_bits} = $opt->{ip_address}->masklen;
	$self->{_current}->{is_ipv4_address} = 
		$opt->{ip_address}->version == 4 ? 'Y' : 'N';
	1;
}

sub _afterhook {
    my $self = shift;
    my $opt = &_options(@_);
	my $dbh;

    if ($opt->{dbh}) {
		$dbh = $opt->{dbh};
	} else {
		$dbh = $self->DBHandle;
    }

	#
	# This should only be needed temporarily until the database handles all
	# of this automatically
	#
	my ($q, $sth);
	$q = q {
		SELECT netblock_utils.recalculate_parentage(?)
	};
	if (!($sth = $dbh->prepare($q))) {
		SetError($opt->{errors},
			sprintf("JazzHands::Mgmt::Netblock::write Error preparing statement: %s",
				$dbh->errstr));
		return undef;
	}
	if (!($sth->execute($self->{_current}->{netblock_id}))) {
		SetError($opt->{errors},
			sprintf("JazzHands::Mgmt::Netblock::write Error executing statement: %s",
				$dbh->errstr));
		return undef;
	}
	$self->{_current}->{parent_netblock_id} = $sth->fetchrow_arrayref->[0];
	$sth->finish;
	1;
}

1;
