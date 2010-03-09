#
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

# $Id$
#

package JazzHands::Management::UclassPropertyInstance;

use strict;
use vars qw($VERSION @EXPORT @ISA);

$VERSION = '1.0.0';    # $Date$

require Exporter;
our @ISA = ( "Exporter", "JazzHands::Management" );
@EXPORT = qw(
  GetUclassPropertyInstance
  GetUclassPropertyInstances
);

sub import {
	JazzHands::Management::UclassPropertyInstance->export_to_level( 1, @_ );
}

sub _options {
	my %ret = @_;
	for my $v ( grep { /^-/ } keys %ret ) {
		$ret{ substr( $v, 1 ) } = $ret{$v};
	}
	\%ret;
}

sub GetUclassPropertyInstance {

	#
	# returns a UclassPropertyInstance of the given UclassProperty for
	# the given uclass with the given value.  The default value is to
	# always return an instance, creating one if one does not already
	# exist.
	#
	# Required parameters:
	#	property	- UclassProperty object to find instances of
	#	uclass		- Uclass object of instance
	#	value		- value of instance
	#	nocreate	- do not create a new instance if one with the
	#				- given parameters does not exist.
	#

	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error(
"GetUclassPropertyInstance: Invalid class reference passed"
		);
		return undef;
	}

	my $opt = &_options(@_);
	if ( !$opt->{property} || !$opt->{value} || !$opt->{uclass} ) {
		$self->Error(
"GetUClassPropertyInstance: uclass, property, and value must be passed"
		);
		return undef;
	}
	if ( !ref( $opt->{uclass} ) || !( eval { $opt->{uclass}->Id } ) ) {
		$self->Error(
"GetUclassPropertyInstance: Uclass parameter is not a valid object"
		);
		return undef;
	}
	if ( !ref( $opt->{property} ) || !( eval { $opt->{property}->Name } ) )
	{
		$self->Error(
"GetUclassPropertyInstance: Uclass parameter is not a valid object"
		);
		return undef;
	}
	my $prop = $opt->{property};
	my ( $q, $sth );

	$q = qq {
		SELECT
			Uclass_Property_ID
		FROM
			Uclass_Property
		WHERE
			Uclass_Property_Name = :name AND
			Uclass_Property_Type = :type AND
			Property_Value = :value AND
			Uclass_ID = :uclass
	};

	if ( !( $sth = $dbh->prepare_cached($q) ) ) {
		$self->Error(
"GetUclassPropertyInstance: Error preparing database select"
		);
		return undef;
	}
	$sth->bind_param( ":name",   $prop->Name );
	$sth->bind_param( ":type",   $prop->Type );
	$sth->bind_param( ":value",  $opt->{value} );
	$sth->bind_param( ":uclass", $opt->{uclass}->Id );

	if ( !( $sth->execute ) ) {
		$self->Error(
"GetUclassPropertyInstance: Error executing database select"
		);
		return undef;
	}
	my ($propid) = $sth->fetchrow_array;
	$sth->finish;
	if ( !$propid ) {
		if ( $opt->{nocreate} ) {
			$self->Error( "Uclass property '"
				  . $prop->Name
				  . "' does not exist with type '"
				  . $prop->Type
				  . "'" );
			return undef;
		}
		$q = qq {
			INSERT INTO Uclass_Property (
				Uclass_Id,
				Uclass_Property_Name,
				Uclass_Property_Type,
				Property_Value
			) VALUES (
				:uclass,
				:name,
				:type,
				:value
			) RETURNING Uclass_Property_ID INTO :propid
		};
		if ( !( $sth = $dbh->prepare($q) ) ) {
			$self->Error(
"GetUclassPropertyInstance: Error creating new property preparing database insert"
			);
			return undef;
		}
		$sth->bind_param( ":name",   $prop->Name );
		$sth->bind_param( ":type",   $prop->Type );
		$sth->bind_param( ":value",  $opt->{value} );
		$sth->bind_param( ":uclass", $opt->{uclass}->Id );
		$sth->bind_param_inout( ":propid", \$propid, 32 );
		if ( !( $sth->execute ) ) {
			$self->Error(
"GetUclassPropertyInstance: Error creating new property executing database insert"
			);
			return undef;
		}
		$sth->finish;
	}
	my $uclasspropinst = $self->copy;
	$uclasspropinst->{Id}             = $propid;
	$uclasspropinst->{Uclass}         = $opt->{uclass};
	$uclasspropinst->{UclassProperty} = $opt->{property};
	$uclasspropinst->{Value}          = $opt->{value};
	bless $uclasspropinst;
}

sub Id {
	my $self = shift;

	return $self->{Id};
}

sub Uclass {
	my $self = shift;

	return $self->{Uclass};
}

sub UclassProperty {
	my $self = shift;

	return $self->{UclassProperty};
}

sub Value {
	my $self = shift;

	return $self->{Value};
}

sub DeviceCollections {
	my $self = shift;

	return $self->{DeviceCollections};
}

sub ValidateInsert {
	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		eval { $dbh = $self->DBHandle };
	}
	if ( !$dbh ) {
		$self->Error("ValidateInsert: Invalid class reference passed");
		return undef;
	}

	if ( !( eval { $self->UclassProperty } ) ) {
		$self->Error(
"ValidateInsert: Invalid uclass property instance object"
		);
		return undef;
	}

	my $devcoll = shift;

	if ( !ref($devcoll) ) {
		$self->Error("ValidateInsert: Must pass device collection");
		return undef;
	}

	my ( $q, $sth );

	# Ok, the tricky thing here is that we need to figure out whether we're
	# going to be allowed to insert this.  First, we need to check the value
	# to verify that if it is a boolean value, it's either a 'Y' or 'N'.

	my $prop = $self->UclassProperty;

	if ( $prop->IsBoolean && $self->Value ne 'Y' && $self->Value ne 'N' ) {
		$self->Error( "'"
			  . $self->Value
			  . "' is an invalid value for this property" );
		return undef;
	}

	# Now, we need to see if this property is multi-valued.  If it is, then
	# we need to see if this particular instance is already associated with
	# this device collection.

	if ( $prop->IsMultivalued ) {
		$q = qq {
			SELECT
				Uclass_Property_Id
			FROM
				Mclass_Property_Override
			WHERE
				Uclass_Property_Id = :propid AND
				Device_Collection_ID = :devcollid
		};
		if ( !( $sth = $dbh->prepare_cached($q) ) ) {
			$self->Error(
"ValidateInsert: Error preparing database select"
			);
			return undef;
		}
		$sth->bind_param( ":propid",    $prop->Id );
		$sth->bind_param( ":devcollid", $devcoll->Id );

		if ( !( $sth->execute ) ) {
			$self->Error(
"ValidateInsert: Error executing database select"
			);
			return undef;
		}
		my ($propid) = $sth->fetchrow_array;
		$sth->finish;
		if ($propid) {
			$self->Error(
"Uclass property instance is already assigned to this device collection"
			);
			return 0;
		} else {
			$self->Error(undef);
			return 1;
		}
	}

      # The property is single-valued, so we need to make sure that there aren't
      # any other instances of this property with different values that are
      # assigned to this device collection.

	$q = qq {
		SELECT
			Uclass_Property_Id
		FROM
			Mclass_Property_Override JOIN Uclass_Property
				USING (Uclass_Property_Id)
		WHERE
			Device_Collection_ID = :devcollid AND
			Uclass_Id = :uclassid AND
			Uclass_Property_Type = :type AND
			Uclass_Property_Name = :name
	};
	if ( !( $sth = $dbh->prepare_cached($q) ) ) {
		$self->Error("ValidateInsert: Error preparing database select");
		return undef;
	}
	$sth->bind_param( ":devcollid", $devcoll->Id );
	$sth->bind_param( ":uclassid",  $self->Uclass->Id );
	$sth->bind_param( ":type",      $prop->Type );
	$sth->bind_param( ":name",      $prop->Name );

	if ( !( $sth->execute ) ) {
		$self->Error("ValidateInsert: Error executing database select");
		return undef;
	}
	my ($propid) = $sth->fetchrow_array;
	$sth->finish;
	if ($propid) {
		$self->Error(
"An identical uclass property instance with a different value is already assigned to this device collection"
		);
		return 0;
	} else {
		$self->Error(undef);
		return 1;
	}
}

sub GetUclassPropertyInstances {

	#
	# returns an array of UclassPropertyInstance objects that match
	# the given parameters.  Any or all parameters can be specified,
	# which will narrow the search.  For instance, if only 'property'
	# is specified, then all of the properties which match
	# the given uclass with the given value.
	#
	# Parameters:
	#
	#	property			- UclassProperty object to find instances of
	#	uclass				- Uclass object of instance
	#	user				- User object
	#	devicecollection	- DeviceCollection object to which instance
	#						- is assigned
	#	value				- value of instance
	#	name				- name of uclass property
	#	type				- type of uclass property
	#
	#	If property is given, it will supercede any value given for
	#	name or type.  If user is given, it will override any value for
	#	uclass.  Note that querying by user causes the search to be different,
	#	as it will return properties acquired by uclass and department
	#	membership
	#

	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error("Invalid class reference passed");
		return undef;
	}

	my $opt = &_options(@_);

	if ( $opt->{property} && !( eval { $opt->{property}->Name } ) ) {
		$self->Error("UclassProperty parameter is not a valid object");
		return undef;
	}
	if ( $opt->{user} && !( eval { $opt->{user}->Id } ) ) {
		$self->Error("User parameter is not a valid object");
		return undef;
	}
	my $prop = $opt->{property};
	my ( $q, $sth, $userq, $orderclause );

	#
	# Set up our base query.
	#
	if ( !$opt->{user} ) {
		$q = qq {
			SELECT
				Uclass_Property_ID,
				Uclass_ID,
				Uclass_Property_Type,
				Uclass_Property_Name,
				Property_Value,
				Is_Multivalue,
				Device_Collection_Id
			FROM
				Uclass_Property JOIN
				VAL_Uclass_Property_Name USING 
					(Uclass_Property_Name, Uclass_Property_Type) LEFT JOIN
				Mclass_Property_Override USING (Uclass_Property_Id)

			};
	} else {
		$q = qq {
			SELECT 
				Uclass_Property_Id,
				Uclass_Property_Name,
				Uclass_Property_Type,
				Property_Value,
				Is_Multivalue,
				Device_Collection_Id
			FROM
				V_Uclass_User_Expanded_Detail JOIN UClass USING (Uclass_ID) JOIN
				Uclass_Property USING (Uclass_ID) JOIN
				VAL_Uclass_Property_Name USING 
					(Uclass_Property_Name, Uclass_Property_Type)
				LEFT JOIN Mclass_Property_Override USING (Uclass_Property_ID)
			WHERE
				UClass_Type IN ('per-user', 'property', 'systems') AND
		};
	}
	$orderclause = qq {
		ORDER BY
			DECODE(UClass_Type, 'per-user', 0, 'properties', 1, 2),
			Dept_Level, UClass_Level, UClass_ID
	};

	my @where;

	my ( $devcollid, $name, $type, $value, $uclassid, $userid );
	if ( defined( $opt->{devicecollection} ) && $opt->{devicecollection} ) {
		if ( !eval { $devcollid = $opt->{devicecollection}->Id } ) {
			$self->Error(
"GetUclassPropertyInstances: Invalid device collection object"
			);
			return undef;
		}
		push @where, qq{
			Device_Collection_ID = :devcollid };
	} else {
		push @where, qq{
			Device_Collection_ID IS NULL };
	}

	if ( $opt->{user} ) {
		if ( !eval { $userid = $opt->{user}->Id } ) {
			$self->Error(
"GetUclassPropertyInstances: Invalid user object"
			);
			return undef;
		}
		push @where, qq{
			System_User_ID = :uclassid };
	} elsif ( $opt->{uclass} ) {
		if ( !eval { $uclassid = $opt->{uclass}->Id } ) {
			$self->Error(
"GetUclassPropertyInstances: Invalid uclass object"
			);
			return undef;
		}
		push @where, qq{
			Uclass_ID = :uclassid };
	}
	$name = $opt->{name};
	$type = $opt->{type};

	if ( $opt->{property} ) {
		if ( !eval { $name = $opt->{property}->Name } ) {
			$self->Error("Invalid property object");
			return undef;
		}
		push @where, qq {
			Uclass_Property_Name = :name AND
			Uclass_Property_Type = :type };
		$type = $opt->{property}->Type;
	} else {
		if ( $opt->{name} ) {
			push @where, qq {
				Uclass_Property_Name = :name };
			$name = $opt->{name};
		}
		if ( $opt->{type} ) {
			push @where, qq {
				Uclass_Property_Type = :type };
			$type = $opt->{type};
		}
	}

	if ( $opt->{value} ) {
		push @where, qq {
			Property_Value = :value };
		$value = $opt->{value};
	}

	if (@where) {
		if ($userid) {
			$q .= join( " AND ", @where ) . $orderclause;
		} else {
			$q .= qq {
				WHERE
			} . join " AND ", @where;
		}
	}

	if ( !( $sth = $dbh->prepare_cached($q) ) ) {
		$self->Error(
"GetUclassPropertyInstances: Error preparing database select"
		);
		return undef;
	}
	if ($devcollid) {
		$sth->bind_param( ":devcollid", $devcollid );
	}
	if ($userid) {
		$sth->bind_param( ":userid", $userid );
	} elsif ($uclassid) {
		$sth->bind_param( ":uclassid", $uclassid );
	}
	if ($name) {
		$sth->bind_param( ":name", $name );
	}
	if ($type) {
		$sth->bind_param( ":type", $type );
	}
	if ($value) {
		$sth->bind_param( ":value", $value );
	}

	if ( !( $sth->execute ) ) {
		$self->Error(
"GetUclassPropertyInstances: Error executing database select"
		);
		return undef;
	}
	my $propid;
	my %ret;
	my $order = 0;
	while ( ( $propid, $uclassid, $type, $name, $value, $devcollid ) =
		$sth->fetchrow_array )
	{
		if ( !$ret{$propid} ) {
			my $propinst = $self->copy;
			$propinst->{Id} = $propid;
			if ( $opt->{uclass} ) {
				$propinst->{Uclass} = $opt->{uclass};
			} else {
				if (
					!(
						$propinst->{Uclass} =
						$self->GetUclass(
							id => $uclassid
						)
					)
				  )
				{
					next;
				}
			}
			if ( $opt->{devicecollection} ) {
				$propinst->{DeviceCollections} =
				  [ $opt->{devicecollection} ];
			} else {
				$propinst->{DeviceCollections} = [
					$self->GetDeviceCollection(
						id => $devcollid
					)
				];
			}
			if ( $opt->{property} ) {
				$propinst->{UclassProperty} = $opt->{property};
			} else {
				$propinst->{UclassProperty} =
				  $self->GetUclassProperty(
					name => $name,
					type => $type
				  );
			}
			$propinst->{Value} = $value;
			$propinst->{Order} = ++$order;
			bless $propinst;
			$ret{$propid} = $propinst;
		} else {

	       # If it's a duplicate, then it's assigned to an additional device
	       # collection
			push @{ $ret{propid}->{DeviceCollection} },
			  $self->GetDeviceCollection( id => $devcollid );
		}
	}
	$sth->finish;
	return \%ret;
}

1;
