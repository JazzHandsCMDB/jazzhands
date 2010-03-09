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

package JazzHands::Management::UclassProperty;

use strict;
use vars qw($VERSION @EXPORT @ISA);

$VERSION = '1.0.0';    # $Date$

require Exporter;
our @ISA = ( "Exporter", "JazzHands::Management" );
@EXPORT = qw(
  GetUclassProperty
  GetUclassProperties
);

sub import {
	JazzHands::Management::UclassProperty->export_to_level( 1, @_ );
}

sub _options {
	my %ret = @_;
	for my $v ( grep { /^-/ } keys %ret ) {
		$ret{ substr( $v, 1 ) } = $ret{$v};
	}
	\%ret;
}

sub GetUclassProperty {
	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error(
			"GetUclassProperty: Invalid class reference passed");
		return undef;
	}

	my $opt = &_options(@_);
	if ( !$opt->{name} || !$opt->{type} ) {
		$self->Error(
"GetUclassProperty: Uclass property name and type must be passed"
		);
		return undef;
	}
	my ( $q, $sth );

	$q = qq {
		SELECT
			Uclass_Property_Name,
			Uclass_Property_Type,
			Description,
			Is_Multivalue,
			Is_Property_A_Boolean
		FROM
			Val_Uclass_Property_Name
		WHERE
			Uclass_Property_Name = :name AND
			Uclass_Property_Type = :type
	};

	if ( !( $sth = $dbh->prepare_cached($q) ) ) {
		my $errstr =
		  "GetUclassProperty: Error preparing database query: "
		  . DBI::errstr;
		if ( $self->DBErrors ) {
			$errstr .= ": " . $dbh->errstr;
		}
		return undef;
	}
	$sth->bind_param( ":name", $opt->{name} );
	$sth->bind_param( ":type", $opt->{type} );

	if ( !( $sth->execute ) ) {
		my $errstr =
		  "GetUclassProperty: Error executing database query";
		if ( $self->DBErrors ) {
			$errstr .= ": " . $sth->errstr;
		}
		return undef;
	}
	my ( $name, $type, $desc, $multi, $bool ) = $sth->fetchrow_array;
	$sth->finish;
	if ( !$name ) {
		$self->Error(
			sprintf(
q{Uclass property '%s' does not exist with type '%s'},
				$opt->{name}, $opt->{type}
			)
		);
		return undef;
	}
	my $uclassprop = $self->copy;
	$uclassprop->{Name}          = $name;
	$uclassprop->{Type}          = $type;
	$uclassprop->{Description}   = $desc;
	$uclassprop->{Is_Multivalue} = $multi eq 'Y' ? 1 : 0;
	$uclassprop->{Is_Boolean}    = $bool eq 'Y' ? 1 : 0;
	bless $uclassprop;
}

sub GetUclassProperties {
	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error(
			"GetUclassProperties: Invalid class reference passed");
		return undef;
	}

	my $opt = &_options(@_);
	my ( $q, $sth );

	$q = qq {
		SELECT
			Uclass_Property_Name,
			Uclass_Property_Type,
			Description,
			Is_Multivalue,
			Is_Property_A_Boolean
		FROM
			Val_Uclass_Property_Name
	};
	if ( !$opt->{name} || !$opt->{type} ) {
		$q .= qq {
			WHERE
				Uclass_Property_Type = :type
		};
		if ( !( $sth = $dbh->prepare_cached($q) ) ) {
			my $errstr =
			  "GetUclassProperties: Error preparing database query";
			if ( $self->DBErrors ) {
				$errstr .= ': ' . $dbh->errstr;
			}
			$self->Error($errstr);
			return undef;
		}
		$sth->bind_param( ":type", $opt->{type} );
	} else {
		if ( !( $sth = $dbh->prepare_cached($q) ) ) {
			my $errstr =
			  "GetUclassProperties: Error preparing database query";
			if ( $self->DBErrors ) {
				$errstr .= ': ' . $dbh->errstr;
			}
			$self->Error($errstr);
			return undef;
		}
	}

	if ( !( $sth->execute ) ) {
		my $errstr =
		  "GetUclassProperties: Error executing database query";
		if ( $self->DBErrors ) {
			$errstr .= ': ' . $sth->errstr;
		}
		$self->Error($errstr);
		return undef;
	}
	my @rv;
	while ( my ( $name, $type, $desc, $multi, $bool ) =
		$sth->fetchrow_array )
	{
		my $uclassprop = $self->copy;
		$uclassprop->{Name}          = $name;
		$uclassprop->{Type}          = $type;
		$uclassprop->{Description}   = $desc;
		$uclassprop->{IsMultivalued} = $multi ? 1 : 0;
		$uclassprop->{IsBoolean}     = $bool ? 1 : 0;
		bless $uclassprop;
		push @rv, $uclassprop;
	}
	$sth->finish;
	\@rv;
}

sub Name {
	my $self = shift;

	return $self->{Name};
}

sub Type {
	my $self = shift;

	return $self->{Type};
}

sub Description {
	my $self = shift;

	return $self->{Description};
}

sub IsMultivalued {
	my $self = shift;

	return $self->{Is_Multivalued};
}

sub IsBoolean {
	my $self = shift;

	return $self->{Is_Boolean};
}

sub GetUserUclassPropertyValues {

      #
      # returns a hash of UclassProperty objects with a value field that match
      # the given parameters.  These are not the same as UClassPropertyInstances
      # as they do not have IDs or UClasses.  Any or all parameters can be
      # specified, which will narrow the results.  For instance, if only
      # 'property' is specified, then all of the properties which match
      # the given uclass with the given value.
      #
      # Parameters:
      #
      #	property			- UclassProperty object to find values of
      #	user				- User object.  If not given, all matching users
      #						  are returned
      #	devicecollection	- DeviceCollection object to which instance
      #						- is assigned
      #	value				- matching value
      #	name				- name of uclass property
      #	type				- type of uclass property
      #
      #	If property is given, it will supercede any value given for
      #	name or type.
      #
      #	For multi-value properties, a union of all of the property values
      #	(in the same order as single-value properties are determined)
      #	is returned.
      #
      #	For single-value properties, the value of the highest priority
      #	property is returned.  Because users can be assigned to multiple
      #	uclasses each containing different (conflicting) values for the
      #	property, the prioriy of assignment is as follows:
      #		- per-user uclasses
      #		- property value uclasses
      #		- systems uclasses
      #		- all others
      #	Within these different uclass types, properties are assigned
      #	with the following rules
      #		a direct uclass assignment wins over a department assignment
      #		uclass hierarchy wins over department hierarchy
      #		in the event of a tie, the lowest uclass_id wins
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
	my ( $q, $sth );

	#
	# Set up our base query.
	#
	$q = qq {
		SELECT 
			System_User_Id,
			Uclass_Property_Name,
			Uclass_Property_Type,
			Property_Value,
			Is_Multivalue,
			Device_Collection_Id
		FROM
			V_Dev_Col_User_Prop_Expanded
	};

	my @where;

	my ( $devcollid, $name, $type, $value, $userid );

	if ( defined( $opt->{devicecollection} ) && $opt->{devicecollection} ) {
		if ( !eval { $devcollid = $opt->{devicecollection}->Id } ) {
			$self->Error(
"GetUclassPropertyValues: Invalid device collection object"
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
				"GetUclassPropertyValues: Invalid user object");
			return undef;
		}
		push @where, qq{
			System_User_ID = :userid };
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
		$q .= qq {
			WHERE
		} . join " AND ", @where;
	}

	if ( !( $sth = $dbh->prepare_cached($q) ) ) {
		my $errstr =
		  "GetUclassPropertyValues: Error preparing database select: ";
		if ( $self->DBErrors ) {
			$errstr .= ": " . $dbh->errstr;
		}
		$self->Error($errstr);
		return undef;
	}
	if ($devcollid) {
		$sth->bind_param( ":devcollid", $devcollid );
	}
	if ($userid) {
		$sth->bind_param( ":userid", $userid );
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
		my $errstr =
		  "GetUclassPropertyValues: Error executing database select";
		if ( $self->DBErrors ) {
			$errstr .= ": " . $dbh->errstr;
		}
		$self->Error($errstr);
		return undef;
	}
	my $multivalue;
	my %ret;
	while ( ( $userid, $name, $type, $value, $multivalue, $devcollid ) =
		$sth->fetchrow_array )
	{
		if ( !$ret{$userid} ) {
			$ret{$userid} = {};
		}
		if ( !$ret{$userid}->{$type} ) {
			$ret{$userid}->{$type} = {};
		}

		#
		# If don't have a value, then create an entry, otherwise add
		# the value the array iff it's multivalue
		#
		if ( !$ret{$userid}->{$type}->{$name} ) {
			$ret{$userid}->{$type}->{$name} = {};
			$ret{$userid}->{$type}->{$name}->{multivalue} =
			  $multivalue;
		}
		my $entry = $ret{$userid}->{$type}->{$name};
		if ($devcollid) {
			if ( !$entry->{$devcollid} ) {
				$entry->{$devcollid} = {};
			}
			$entry = $entry->{$devcollid};
		}
		if ($multivalue) {
			if ( !defined( $entry->{value} ) ) {
				$entry->{value} = [$value];
			} else {
				push @{ $entry->{value} }, $value;
			}
		} else {
			if ( !defined( $entry->{value} ) ) {
				$entry->{value} = $value;
			}
		}
	}
	$sth->finish;
	return \%ret;
}

sub GetUserUclassPropertyValue {

      #
      # returns a hash of UclassProperty objects with a value field that match
      # the given parameters.  These are not the same as UClassPropertyInstances
      # as they do not have IDs or UClasses.  Any or all parameters can be
      # specified, which will narrow the results.  For instance, if only
      # 'property' is specified, then all of the properties which match
      # the given uclass with the given value.
      #
      # Parameters:
      #
      #	user				- User object.
      #	property			- UclassProperty object to find values of
      #	name				- name of uclass property
      #	type				- type of uclass property
      #	devicecollection	- DeviceCollection object to which instance
      #						  is assigned.  If this is not given, then
      #						  only properties which are not assigned to
      #						  a device collection will be returned
      #
      #	If property is given, it will supercede any value given for
      #	name or type.  Either 'property' or both of 'name' and 'type'
      #	must be given
      #
      #	For multi-value properties, a union of all of the property values
      #	(in the same order as single-value properties are determined)
      #	is returned.
      #
      #	For single-value properties, the value of the highest priority
      #	property is returned.  Because users can be assigned to multiple
      #	uclasses each containing different (conflicting) values for the
      #	property, the prioriy of assignment is as follows:
      #		- per-user uclasses
      #		- property value uclasses
      #		- systems uclasses
      #		- all others
      #	Within these different uclass types, properties are assigned
      #	with the following rules
      #		a direct uclass assignment wins over a department assignment
      #		uclass hierarchy wins over department hierarchy
      #		in the event of a tie, the lowest uclass_id wins
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
		$self->Error(
"property parameter is not a valid UclassProperty object"
		);
		return undef;
	}
	if ( !$opt->{user} ) {
		$self->Error("user parameter must be given");
		return undef;
	}
	my ( $name, $type, $userid );
	if ( !eval { $userid = $opt->{user}->Id } ) {
		$self->Error("user parameter is not a valid User object");
		return undef;
	}
	if ( $opt->{property} ) {
		$opt->{name} = $opt->{property}->Name;
		$opt->{type} = $opt->{property}->Type;
	}
	if ( !$opt->{name} || !$opt->{type} ) {
		$self->Error(
			"property parameter or both name and type must be given"
		);
		return undef;
	}

	my $prop = $opt->{property};
	my ( $q, $sth );

	#
	# Set up our base query.
	#
	$q = qq {
		SELECT 
			Property_Value,
			DECODE(Is_Multivalue, 'N', 0, 'Y', 1) Is_Multivalue,
			DECODE(Is_Property_A_Boolean, 'N', 0, 'Y', 1) Is_Boolean,
			Device_Collection_Id
		FROM
			V_Dev_Col_User_Prop_Expanded
	};

	my @where;

	my ( $devcollid, $value );

	if ( defined( $opt->{devicecollection} ) && $opt->{devicecollection} ) {
		if ( !eval { $devcollid = $opt->{devicecollection}->Id } ) {
			$self->Error(
"GetUclassPropertyValue: Invalid device collection object"
			);
			return undef;
		}
		push @where, qq{
			Device_Collection_ID = :devcollid };
	} else {
		push @where, qq{
			Device_Collection_ID IS NULL };
	}

	push @where, qq{ System_User_ID = :userid };

	push @where, qq {
		Uclass_Property_Name = :name AND
		Uclass_Property_Type = :type };

	$q .= qq {
		WHERE
	} . join " AND ", @where;

	if ( !( $sth = $dbh->prepare_cached($q) ) ) {
		my $errstr =
		  "GetUclassPropertyValue: Error preparing database select";
		if ( $self->DBErrors ) {
			$errstr .= ": " . $dbh->errstr;
		}
		$self->Error($errstr);
		return undef;
	}
	if ($devcollid) {
		$sth->bind_param( ":devcollid", $devcollid );
	}
	$sth->bind_param( ":userid", $userid );
	$sth->bind_param( ":name",   $opt->{name} );
	$sth->bind_param( ":type",   $opt->{type} );

	if ( !( $sth->execute ) ) {
		my $errstr =
		  "GetUclassPropertyValue: Error executing database select";
		if ( $self->DBErrors ) {
			$errstr .= ": " . $sth->errstr;
		}
		$self->Error($errstr);
		return undef;
	}
	my ( $multivalue, $boolean );
	my $ret;
	while ( ( $value, $multivalue, $boolean, $devcollid ) =
		$sth->fetchrow_array )
	{
		if ($boolean) {
			$value = ( $value eq 'Y' ? 1 : 0 );
		}
		if ($multivalue) {
			if ( !defined($ret) ) {
				$ret = [$value];
			} else {
				push @$ret, $value;
			}
		} else {
			$ret = $value;
			last;
		}
	}
	$sth->finish;
	return $ret;
}

1;
