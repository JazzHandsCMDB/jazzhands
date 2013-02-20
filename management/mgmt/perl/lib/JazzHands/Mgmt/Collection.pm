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

package JazzHands::Mgmt::Collection;

use strict;
use warnings;

use DBI;
use JazzHands::Common qw(:all);
use JazzHands::Common::GenericDB qw(:all);
use JazzHands::Mgmt::Netblock;

use Data::Dumper;

use vars qw($VERSION @EXPORT @EXPORT_OK @ISA);

$VERSION = '1.0';

require Exporter;
our @ISA = qw ( Exporter JazzHands::Mgmt);

# The only things that should be in this list that require a JazzHands::Mgmt
# object explicity (typically just Get* functions)

@EXPORT_OK = qw(GetCollection);
sub import {
	JazzHands::Mgmt::Collection->export_to_level(1, @_);
}

my $collection_params = {
	'netblock' => {
		_dbtable => "netblock_collection",
		_dbmembertable => "netblock_collection_netblock",
		_memberobject => 'JazzHands::Mgmt::Netblock',
		_memberfetchfunction => \&JazzHands::Mgmt::Netblock::GetNetblock,
		_dbkey => [ qw(netblock_collection_id) ],
		_memberkey => "netblock_id",
		_validmatch => [ qw(
			netblock_collection_id 
			netblock_collection_name 
			netblock_collection_type )],
	},
};
		
sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self;
	my $opt = _options(@_);

	if (ref($proto)) {
		$self = $proto->clone;
	} elsif ($opt->{jhhandle}) {
		$self = $opt->{jhhandle}->clone;
	} else {
		$self = {};
	}

	if (!$opt->{type}) {
		SetError($opt->{errors}, 
			"type must be passed to JazzHands::Mgmt::Collection::new");
		return undef;
	} elsif (!$collection_params->{$opt->{type}}) {
		SetError($opt->{errors}, 
			"invalid type passed to JazzHands::Mgmt::Collection::new");
		return undef;
	}
	$self->{_objecttype} = 'membertable';
	foreach my $key (keys %{$collection_params->{$opt->{type}}}) {
		$self->{$key} = $collection_params->{$opt->{type}}->{$key};
	}
	$self->{_current} = {};

	bless $self, $class;
	#
	# members must be either an array or an unblessed hash
	#
	if (exists $opt->{members}) {
		if (ref($opt->{members}) eq 'ARRAY') {
			$self->{_current} = { map { $_ => undef } @{$opt->{members}} };
		} elsif (ref($opt->{members}) eq 'HASH') {
			$self->{_current} = { %{$opt->{members}} };
		} else {
			SetError($opt->{errors},
				"members option to JazzHands::Mgmt::Collection::new must be an array or unblessed hash");
			return undef;
		}
	}

	return $self;
}

sub GetCollection {
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

	my $type = $opt->{type};
	if (!$type) {
		SetError($opt->{errors}, 
			"type must be passed to JazzHands::Mgmt::Collection::GetCollection");
		return undef;
	} elsif (!$collection_params->{$type}) {
		SetError($opt->{errors}, 
			"invalid type passed to JazzHands::Mgmt::Collection::GetCollection");
		return undef;
	}
	my $match;

	foreach my $key ( @{$collection_params->{$type}->{_validmatch}}) {
		if ($opt->{$key}) {
			push @$match, {
				key => $key,
				value => $opt->{$key}
			};
		}
	}
	
	my $rows = DBFetch(
		dbhandle => $dbh,
		table => $collection_params->{$type}->{_dbtable},
		match => $match,
		errors => $opt->{errors});

	return undef if (!defined($rows));

	if ($opt->{single}) {
		if (scalar(@$rows) > 1) {
			SetError($opt->{errors},
				"Multiple values returned to GetCollections");
			return undef;
		}
	}	

	my $matches = [];
	foreach my $row (@$rows) {
		my $object = new JazzHands::Mgmt::Collection(
			jhhandle => $self,
			type => $type);
		$object->{_orig} = $row;
		$object->{_current} = { %$row };

		#
		# Fetch the collection members
		#
		my $collrows = DBFetch(
			dbhandle => $dbh,
			table => $object->{_dbmembertable},
			match => [ map { { key => $_, value => $object->{_current}->{$_} } }
				@{$object->{_dbkey}} ],
			errors => $opt->{errors});

		return undef if (!defined($collrows));

		#
		# If we want to pull in the complete objects, fetch them, otherwise
		# just use null values
		#
		if ($opt->{fullobjects}) {
			my $memberobj = &{$object->{_memberfetchfunction}}(
				$self,
				$object->{_memberkey} => 
					[ map { $_->{$object->{_memberkey}} } @$collrows ],
				errors => $opt->{errors}
			);
			return undef if (!defined($memberobj));
			$object->{_origmembers} = 
				{ map { $_->{_orig}->{$object->{_memberkey}} => $_ }
						@$memberobj
				};

		} else {
			$object->{_origmembers} = 
				{ map { $_->{$object->{_memberkey}} => undef } @$collrows };
		}
		$object->{_currentmembers} = { %{$object->{_origmembers}} };
		push @$matches, $object;
	}
	
	if ($opt->{single}) {
		return $matches->[0];
	}
	return $matches;
}

sub DeleteObject {
	my $self = shift;
	my $opt = _options(@_);

	if (!$opt->{object}) {
		SetError($opt->{errors}, 
			"object must be passed to JazzHands::Mgmt::Collection::delete");
		return undef;
	}
	my $objlist;
	if (ref($opt->{object}) eq 'ARRAY') {
		$objlist = $opt->{object};
	} else {
		$objlist = [ $opt->{object} ];
	}
	#
	# Validate all of the object types first
	#
	foreach my $obj (@$objlist) {
		if (ref($obj) && ref($obj) ne $self->{_memberobject}) {
			SetError($opt->{errors}, 
				sprintf("all objects passed must be of type %s not %s",
				$self->{_memberobject}, ref($obj)));
			return undef;
		}
	}
	#
	# Now delete them
	#
	foreach my $obj (@$objlist) {
		if (!ref($obj)) {
			delete $self->{_currentmembers}->{$obj};
		} else {
			delete $self->{_currentmembers}->{$obj->{_current}->
					{$self->{_memberkey}}};
		}
	}
	return 1;
}

sub AddObject {
	my $self = shift;
	my $opt = _options(@_);

	if (!$opt->{object}) {
		SetError($opt->{errors}, 
			"object must be passed to JazzHands::Mgmt::Collection::add");
		return undef;
	}
	my $objlist;
	if (ref($opt->{object}) eq 'ARRAY') {
		$objlist = $opt->{object};
	} else {
		$objlist = [ $opt->{object} ];
	}
	#
	# Validate all of the object types first
	#
	foreach my $obj (@$objlist) {
		if (ref($obj) && ref($obj) ne $self->{_memberobject}) {
			SetError($opt->{errors}, 
				sprintf("all objects passed must be of type %s not %s",
				$self->{_memberobject}, ref($obj)));
			return undef;
		}
	}
	#
	# Now add them
	#
	foreach my $obj (@$objlist) {
		if (!ref($obj)) {
			$self->{_currentmembers}->{$obj} = undef;
		} else {
			$self->{_currentmembers}->{$obj->{_current}->
					{$self->{_memberkey}}} = $obj;
		}
	}
	return 1;
}

1;
