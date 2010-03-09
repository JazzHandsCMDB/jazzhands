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

package JazzHands::Management::DeviceCollection;

use strict;
use vars qw($VERSION @EXPORT @ISA);

$VERSION = '2.0.0';    # $Date$

require Exporter;
our @ISA = ( "Exporter", "JazzHands::Management" );
@EXPORT = qw(
  GetDeviceCollection
  FindDeviceCollectionForDevice
);

sub import {
	JazzHands::Management::DeviceCollection->export_to_level( 1, @_ );
}

sub _options {
	my %ret = @_;
	for my $v ( grep { /^-/ } keys %ret ) {
		$ret{ substr( $v, 1 ) } = $ret{$v};
	}
	\%ret;
}

sub GetDeviceCollection {

	#
	# options:
	#   name         - name of the device collection to find/create
	#   id           - Device_Collection_ID of the device collection to find
	#   create       - create the device collection
	#   type         - set the type of device collection
	#   noexisterror - if true, don't return an error if create is passed
	#                  and the device collection already exists
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

	my $where;
	if ( $opt->{name} ) {
		$where = "Name = :param";
	} elsif ( $opt->{id} ) {
		$where = "Device_Collection_Id = :param";
	} else {
		$self->Error(
			"Neither device collection name nor id were passed");
		return undef;
	}

	if ( !$opt->{type} && !$opt->{id} ) {
		$self->Error("Type of device collection not specified");
		return undef;
	}

	if ( $opt->{type} ) {
		$where .= " AND Device_Collection_Type = :type";
	}

	my ( $q, $sth );

	$q = qq {
		SELECT
			Device_Collection_ID,
			Name,
			Device_Collection_Type
		FROM
			Device_Collection
		WHERE
			$where
	};
	if ( !( $sth = $dbh->prepare_cached($q) ) ) {
		$self->Error("Error preparing database query");
		return undef;
	}

	if ( $opt->{type} ) {
		$sth->bind_param( ':type', $opt->{type} );
	}
	$sth->bind_param( ':param', $opt->{name} ? $opt->{name} : $opt->{id} );

	if ( !( $sth->execute ) ) {
		$self->Error("Error executing database query");
		return undef;
	}

	my ( $id, $name, $type ) = $sth->fetchrow_array;
	$sth->finish;

	# If the device collection exists and either we didn't pass the create
	# flag or specifically want to ignore the fact that the Mclass already
	# existed, return it.

	my $devcoll = $self->copy;
	bless $devcoll;
	if ($id) {
		if ( $opt->{create} && !$opt->{noexisterror} ) {
			$self->Error("Device collection already exists");
			return undef;
		}
	} else {
		if ( $opt->{create} ) {
			if ( !$opt->{name} ) {
				$self->Error(
"Name must be given to create device collection"
				);
				return undef;
			}
			$name = $opt->{name};
			$type = $opt->{type};
			my $valid = $devcoll->__ValidateType($type);
			if ( !defined($valid) ) {
				$self->Error(
"Internal error validating device collection type"
				);
				return undef;
			} elsif ( !$valid ) {
				$self->Error(
"$type is not a valid device collection type"
				);
				return undef;
			}

			$q = qq {
				INSERT INTO Device_Collection (
					Name,
					Device_Collection_Type
				) VALUES (
					:name,
					:type
				) RETURNING
					Device_Collection_ID
				INTO
					:id
			};
			if ( !( $sth = $dbh->prepare($q) ) ) {
				$self->Error("Error preparing database query");
				return undef;
			}
			$sth->bind_param( ":name", $name );
			$sth->bind_param( ":type", $type );
			$sth->bind_param_inout( ":id", \$id, 32 );
			if ( !( $sth->execute ) ) {
				$self->Error(
					"Error creating device collection");
				return undef;
			}
			$sth->finish;
		} else {
			$self->Error("Device collection does not exist");
			return undef;
		}
	}
	$devcoll->{DeviceCollectionId}   = $id;
	$devcoll->{DeviceCollectionName} = $name;
	$devcoll->{DeviceCollectionType} = $type;
	bless $devcoll;
}

sub AddUclassPropertyInstance {
	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error(
"AddUclassPropertyInstance: Invalid class reference passed"
		);
		return undef;
	}

	my $instance = shift;
	if ( !eval { $instance->UclassProperty } ) {
		$self->Error(
			"AddUclassPropertyInstance: Instance must be specified"
		);
		return undef;
	}

	if ( !$instance->ValidateInsert($self) ) {
		$self->Error( $instance->Error );
		return undef;
	}

	my ( $q, $sth );
	$q = qq {
		INSERT INTO Mclass_Property_Override (
			Uclass_Property_Id,
			Device_Collection_Id
		) VALUES (
			:ucpropid,
			:devcollid
		)
	};
	if ( !( $sth = $dbh->prepare($q) ) ) {
		$self->Error(
"AddUclassPropertyInstance: Error preparing database insert"
		);
		return undef;
	}
	$sth->bind_param( ":ucpropid",  $instance->Id );
	$sth->bind_param( ":devcollid", $self->Id );
	if ( !( $sth->execute ) ) {
		$self->Error(
"AddUclassPropertyInstance: Error executing database insert"
		);
		return undef;
	}
	$sth->finish;

	return 1;
}

sub RemoveUclassPropertyInstance {
	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error(
"RemoveUclassPropertyInstance: Invalid class reference passed"
		);
		return undef;
	}

	my $instance = shift;
	if ( !eval { $instance->UclassProperty } ) {
		$self->Error(
"RemoveUclassPropertyInstance: Instance must be specified"
		);
		return undef;
	}

	my ( $q, $sth );
	$q = qq {
		DELETE FROM 
			Mclass_Property_Override
		WHERE
			Uclass_Property_Id = :ucpropid AND
			Device_Collection_Id = :devcollid
	};
	if ( !( $sth = $dbh->prepare($q) ) ) {
		$self->Error(
"RemoveUclassPropertyInstance: Error preparing database delete"
		);
		return undef;
	}
	$sth->bind_param( ":ucpropid",  $instance->Id );
	$sth->bind_param( ":devcollid", $self->Id );
	if ( !( $sth->execute ) ) {
		$self->Error(
"RemoveUclassPropertyInstance: Error executing database delete"
		);
		return undef;
	}
	$sth->finish;

	return 1;
}

sub FindDeviceCollectionForDevice {

	#
	# This should probably be 'DeviceCollectionSearch' and take all kinds
	# of wild-ass parameters.
	#
	# options:
	#   name		- name of the device to search for
	#   id			- device id of the device to search for
	#   type		- the device collection type to restrict the search to
	#	substring	- if 'name' is passed, do a substring match on the
	#					device
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

	my ( $q, $sth, $where );
	my @params;

	if ( $opt->{name} ) {
		if ( $opt->{substring} ) {
			$where = " Device.Device_Name LIKE ?";
			push @params, ( '%' . $opt->{name} . '%' );
		} else {
			$where = " Device.Device_Name = ?";
			push @params, ( $opt->{name} );
		}
	} elsif ( $opt->{id} ) {
		$where = "Device_ID = ?";
		push @params, ( $opt->{id} );
	} else {
		$self->Error("Neither device name nor id were given");
		return undef;
	}

	$q = qq {
		SELECT
			Device.Device_Name,
			Device_Collection.Name,
			Device_Collection_ID,
			Device_Collection.Device_Collection_Type
		FROM
			(Device_Collection JOIN Device_Collection_Member 
				USING (Device_Collection_Id)) JOIN
			Device USING (Device_ID)
		WHERE
			} . $where;
	if ( !( $sth = $dbh->prepare_cached($q) ) ) {
		$self->Error("Error preparing database query");
		return undef;
	}

	if ( !( $sth->execute(@params) ) ) {
		$self->Error("Error executing database query");
		return undef;
	}

	my %ret;
	while ( my ( $device, $name, $id, $type ) = $sth->fetchrow_array ) {
		%{ $ret{$device} } = %$self;
		$ret{$device}->{DeviceCollectionId}   = $id;
		$ret{$device}->{DeviceCollectionName} = $name;
		$ret{$device}->{DeviceCollectionType} = $type;
		bless $ret{$device};
	}
	$sth->finish;
	return \%ret;
}

sub Id {
	my $self = shift;

	return $self->{DeviceCollectionId};
}

sub Name {
	my $self = shift;

	return $self->{DeviceCollectionName};
}

sub Type {
	my $self = shift;

	return $self->{DeviceCollectionType};
}

sub Devices {
	my $self = shift;

	return $self->GetDevices( devicecollection => $self );
}

sub Delete {
	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error("Invalid class reference passed");
		return undef;
	}

	my $id = $self->Id;
	if ( !defined($id) ) {
		$self->Error("Invalid device collection object");
		return undef;
	}

	my ( $q, $sth );
	$q = qq {
		DELETE FROM
			Device_Collection
		WHERE
			Device_Collection_ID = :id
	};
	$sth = $dbh->prepare($q) || return "Error preparing database query";
	$sth->bind_param( ":id", $id );
	if ( !$sth->execute ) {
		$self->Error( $dbh->errstr );
		return undef;
	}
	$sth->finish;
	$self->Error(undef);
	return 1;
}

sub __ValidateType {

	# Validates that a device_collection_type exists
	# returns 1 if it exists, 0 if it does not, and undef on error

	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error("Invalid class reference passed");
		return undef;
	}

	my $type = shift;
	if ( !$type ) {
		$self->Error("Type must be passed");
		return undef;
	}

	my ( $q, $sth );

	$q = qq {
		SELECT
			Device_Collection_Type
		FROM
			Val_Device_Collection_Type
		WHERE
			Device_Collection_Type = ?
	};
	if ( !( $sth = $dbh->prepare_cached($q) ) ) {
		$self->Error("Error preparing database query");
		return undef;
	}

	if ( !( $sth->execute($type) ) ) {
		$self->Error("Error executing database query");
		return undef;
	}

	$type = ( $sth->fetchrow_array )[0];
	$sth->finish;

	if ($type) {
		return 1;
	} else {
		return 0;
	}
}

sub AddApplicationInstance {
	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error(
			"AddApplicationInstance: Invalid class reference passed"
		);
		return undef;
	}
	my $applinst = shift;
	my $applinstid;
	if ( !eval { $applinstid = $applinst->Id } ) {
		$self->Error(
"AddApplicationInstance: application instance parameter is not a valid object"
		);
		return undef;
	}

	#
	# Ensure that there are no other instances of this application assigned
	# to this device collection
	#

	my $applinstances;
	if (
		$applinstances = $self->GetApplicationInstances(
			application      => $applinst->Application,
			devicecollection => $self
		)
	  )
	{
		$self->Error(
			sprintf(
"A instance this application of type '%s' is already assigned to this device collection",
				$applinstances->{ each %$applinstances }
				  ->ProdState )
		);
		return undef;
	}
	my ( $q, $sth );
	$q = qq {
		INSERT INTO MClass_Application (
			Device_Collection_ID,
			Application_Instance_ID
		) VALUES (
			:devcollid,
			:applinstid
		)
	};

	if ( !( $sth = $dbh->prepare($q) ) ) {
		$self->Error(
			"AddApplicationInstance: Error preparing database query"
		);
		return undef;
	}
	$sth->bind_param( ":devcollid",  $self->Id );
	$sth->bind_param( ":applinstid", $applinstid );
	if ( !( $sth->execute ) ) {
		$self->Error(
			"AddApplicationInstance: Error executing database query"
		);
		return undef;
	}
	$sth->finish;
	1;
}

sub RemoveApplicationInstance {
	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error(
"RemoveApplicationInstance: Invalid class reference passed"
		);
		return undef;
	}
	my $applinst = shift;
	my $applinstid;
	if ( !eval { $applinstid = $applinst->Id } ) {
		$self->Error(
"RemoveApplicationInstance: application instance parameter is not a valid object"
		);
		return undef;
	}

	my ( $q, $sth );
	$q = qq {
		DELETE FROM
			MClass_Application
		WHERE
			Device_Collection_Id = :devcollid AND
			Application_Instance_Id = :applinstid
	};

	if ( !( $sth = $dbh->prepare($q) ) ) {
		$self->Error(
"RemoveApplicationInstance: Error preparing database query"
		);
		return undef;
	}
	$sth->bind_param( ":devcollid",  $self->Id );
	$sth->bind_param( ":applinstid", $applinstid );
	if ( !( $sth->execute ) ) {
		$self->Error(
"RemoveApplicationInstance: Error executing database query:"
			  . DBI::errstr );
		return undef;
	}
	$sth->finish;
	1;
}

1;
