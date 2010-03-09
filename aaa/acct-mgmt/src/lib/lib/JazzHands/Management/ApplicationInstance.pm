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

package JazzHands::Management::ApplicationInstance;

use strict;
use vars qw($VERSION @EXPORT @ISA);

$VERSION = '1.0.0';    # $Date$

require Exporter;
our @ISA = ( "Exporter", "JazzHands::Management" );

@EXPORT = qw(
  CreateApplicationInstance
  GetApplicationInstance
  GetApplicationInstances
);

sub import {
	JazzHands::Management::ApplicationInstance->export_to_level( 1, @_ );
}

sub _options {
	my %ret = @_;
	for my $v ( grep { /^-/ } keys %ret ) {
		$ret{ substr( $v, 1 ) } = $ret{$v};
	}
	\%ret;
}

sub GetApplicationInstance {
	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error(
			"GetApplicationInstance: Invalid class reference passed"
		);
		return undef;
	}

	my $opt = &_options(@_);
	if ( !$opt->{application} || !$opt->{prodstate} ) {
		$self->Error(
"GetApplicationInstance: application and production state must be given"
		);
		return undef;
	}

	my $application;
	if (       !ref( $opt->{application} )
		|| !( eval { $application = $opt->{application}->Id } ) )
	{
		$self->Error(
"GetUclassPropertyInstance: application parameter is not a valid object"
		);
		return undef;
	}
	my ( $q, $sth );

	$q = qq {
		SELECT
			Application_Instance_Id,
			Production_State,
			Authentication_Method,
			Database_Type,
			Username,
			Password,
			Service_Name,
			Keytab
		FROM
			Application_Instance
		WHERE
			Application_Id = :id AND
			Production_State = :prodstate
	};

	if ( !( $sth = $dbh->prepare_cached($q) ) ) {
		$self->Error(
			"GetApplicationInstance: Error preparing database query"
		);
		return undef;
	}
	$sth->bind_param( ":id",        $application );
	$sth->bind_param( ":prodstate", $opt->{prodstate} );

	if ( !( $sth->execute ) ) {
		$self->Error(
			"GetApplicationInstance: Error executing database query"
		);
		return undef;
	}
	my ( $id, $prodstate, $method, $dbtype, $username, $password, $service,
		$keytab )
	  = $sth->fetchrow_array;
	$sth->finish;
	if ( !$id ) {
		$self->Error(
			    "Application Instance not found for application id "
			  . $application
			  . " and production state "
			  . $opt->{prodstate} );
		return undef;
	}
	my $applinst = $self->copy;
	$applinst->{Id}          = $id;
	$applinst->{Application} = $application;
	$applinst->{ProdState}   = $prodstate;
	$applinst->{AuthMethod}  = $method;
	$applinst->{DBType}      = $dbtype;
	$applinst->{Username}    = $username;
	$applinst->{Password}    = $password;
	$applinst->{Service}     = $service;
	bless $applinst;
}

sub GetApplicationInstances {

	#
	# returns an hash of ApplicationInstance objects that match
	# the given parameters.  Any or all parameters can be specified,
	# which will narrow the search.  For instance, if only 'property'
	# is specified, then all of the properties which match
	# the given uclass with the given value.
	#
	# Parameters:
	#
	#	application			- Application object to find instances of
	#	devicecollection	- DeviceCollection object to which instance
	#						- is assigned
	#	prodstate			- production state of ApplicationInstance
	#	dbtype				- type of database
	#	username			- username of application user
	#	authmethod			- method for authentication
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

	my $prop = $opt->{property};
	my ( $q, $sth );

	#
	# Set up our base query.
	#
	$q = qq {
		SELECT
			Application_Instance_Id,
			Application_Id,
			Production_State,
			Authentication_Method,
			Database_Type,
			Username,
			Password,
			Service_Name,
			Keytab,
			Device_Collection_Id
		FROM
			Application_Instance LEFT JOIN
			Mclass_Application USING (Application_Instance_Id)
	};

	my @where;

	my (
		$devcollid, $applid,     $prodstate, $dbtype,
		$username,  $authmethod, $service
	);

	if ( $opt->{application} ) {
		if ( !eval { $applid = $opt->{application}->Id } ) {
			$self->Error(
				"application parameter is not a valid object");
			return undef;
		}
		push @where, qq{
			Application_ID = :applid };
	}

	if ( $opt->{devicecollection} ) {
		if ( !eval { $devcollid = $opt->{devicecollection}->Id } ) {
			$self->Error(
"GetApplicationInstances: Invalid device collection object"
			);
			return undef;
		}
		push @where, qq{
			Device_Collection_ID = :devcollid };
	}

	if ( $opt->{prodstate} ) {
		push @where, qq {
			Production_State = :prodstate };
		$prodstate = $opt->{prodstate};
	}

	if ( $opt->{dbtype} ) {
		push @where, qq {
			Database_Type = :dbtype };
		$dbtype = $opt->{dbtype};
	}

	if ( $opt->{username} ) {
		push @where, qq {
			Username = :username };
		$username = $opt->{username};
	}

	if ( $opt->{authmethod} ) {
		push @where, qq {
			Authentication_Method = :authmethod };
		$authmethod = $opt->{authmethod};
	}

	if ( $opt->{service} ) {
		push @where, qq {
			Service_Name = :service };
		$service = $opt->{service};
	}

	if (@where) {
		$q .= qq {
			WHERE
		} . join " AND ", @where;
	}

	if ( !( $sth = $dbh->prepare_cached($q) ) ) {
		$self->Error(
"GetApplicationInstances: Error preparing database select"
		);
		return undef;
	}
	if ($applid) {
		$sth->bind_param( ":applid", $applid );
	}
	if ($devcollid) {
		$sth->bind_param( ":devcollid", $devcollid );
	}
	if ($prodstate) {
		$sth->bind_param( ":prodstate", $prodstate );
	}
	if ($dbtype) {
		$sth->bind_param( ":dbtype", $dbtype );
	}
	if ($username) {
		$sth->bind_param( ":username", $username );
	}
	if ($authmethod) {
		$sth->bind_param( ":authmethod", $authmethod );
	}
	if ($service) {
		$sth->bind_param( ":service", $service );
	}

	if ( !( $sth->execute ) ) {
		$self->Error(
"GetApplicationInstances: Error executing database select"
		);
		return undef;
	}
	my %ret;
	my ( $applinstid, $password, $keytab );
	while (
		(
			$applinstid, $applid,   $prodstate, $authmethod,
			$dbtype,     $username, $password,  $service,
			$keytab,     $devcollid
		)
		= $sth->fetchrow_array
	  )
	{
		if ( !$ret{$applinstid} ) {
			my $applinst = $self->copy;
			$applinst->{Id} = $applinstid;
			if ( $opt->{application} ) {
				$applinst->{Application} = $opt->{application};
			} else {

				# Shouldn't happen
				if (
					!(
						$applinst->{Application} =
						$self->GetApplication(
							id => $applid
						)
					)
				  )
				{
					next;
				}
			}
			if ( $opt->{devicecollection} ) {
				$applinst->{DeviceCollections} =
				  [ $opt->{devicecollection} ];
			} elsif ($devcollid) {
				$applinst->{DeviceCollections} = [
					$self->GetDeviceCollection(
						id => $devcollid
					)
				];
			} else {
				$applinst->{DeviceCollections} = [];
			}
			$applinst->{ProdState}  = $prodstate;
			$applinst->{AuthMethod} = $authmethod;
			$applinst->{DBType}     = $dbtype;
			$applinst->{Username}   = $username;
			$applinst->{Password}   = $password;
			$applinst->{Service}    = $service;
			bless $applinst;
			$ret{$applinstid} = $applinst;
		} else {

	       # If it's a duplicate, then it's assigned to an additional device
	       # collection
			push @{ $ret{$applinstid}->{DeviceCollections} },
			  $self->GetDeviceCollection( id => $devcollid );
		}
	}
	$sth->finish;
	return \%ret;
}

sub CreateApplicationInstance {
	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error(
"CreateApplicationInstance: Invalid class reference passed"
		);
		return undef;
	}

	my $opt = &_options(@_);
	if ( !$opt->{application} ) {
		$self->Error(
			"CreateApplicationInstance: application must be given");
		return undef;
	}

	my $applid;
	eval { $applid = $opt->{application}->Id };
	if ( !defined($applid) ) {
		$self->Error(
			"CreateApplicationInstance: Invalid application object"
		);
		return undef;
	}

	if ( !$opt->{prodstate} ) {
		$self->Error(
			"CreateApplicationInstance: prodstate must be given");
		return undef;
	}

	if (
		$self->GetApplicationInstance(
			application => $opt->{application},
			prodstate   => $opt->{prodstate},
		)
	  )
	{
		$self->Error("Application instance already exists");
		return undef;
	}

	if ( !$opt->{authmethod} ) {
		$self->Error(
			"CreateApplicationInstance: authmethod must be given");
		return undef;
	}

	if ( !$opt->{dbtype} ) {
		$self->Error("CreateApplicationInstance: dbtype must be given");
		return undef;
	}

	my ( $q, $sth );

	$q = qq {
		INSERT INTO Application_Instance (
			Application_Id,
			Production_State,
			Authentication_Method,
			Database_Type
		) VALUES (
			:applid,
			:prodstate,
			:authmethod,
			:dbtype
		) RETURNING Application_Instance_ID INTO :id
	};

	if ( !( $sth = $dbh->prepare($q) ) ) {
		$self->Error(
"CreateApplicationInstance: Error preparing database query: "
			  . DBI::errstr );
		return undef;
	}

	$sth->bind_param( ":applid",     $applid );
	$sth->bind_param( ":prodstate",  $opt->{prodstate} );
	$sth->bind_param( ":authmethod", $opt->{authmethod} );
	$sth->bind_param( ":dbtype",     $opt->{dbtype} );
	my $id;
	$sth->bind_param_inout( ":id", \$id, 32 );

	if ( !( $sth->execute ) ) {
		$self->Error(
"CreateApplicationInstance: Error executing database query: "
			  . DBI::errstr );
		return undef;
	}
	my $applinst = $self->copy;
	$applinst->{Id}          = $id;
	$applinst->{Application} = $opt->{application};
	$applinst->{ProdState}   = $opt->{prodstate};
	$applinst->{AuthMethod}  = $opt->{authmethod};
	bless $applinst;
}

sub Id {
	my $self = shift;

	return $self->{Id};
}

sub Application {
	my $self = shift;

	return $self->{Application};
}

sub ProductionState {
	my $self = shift;

	return $self->{ProdState};
}

sub DeviceCollections {
	my $self = shift;

	return $self->{DeviceCollections};
}

sub AuthMethod {
	my $self = shift;

	my $authmethod;
	if ( !( $authmethod = shift ) ) {
		return $self->{AuthMethod};
	}

	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error(
"ApplicationInstance::AuthMethod: Invalid class reference passed"
		);
		return undef;
	}

	my $id;
	eval { $id = $self->Id };
	if ( !defined($id) ) {
		$self->Error(
"ApplicationInstance::AuthMethod: Invalid application object"
		);
		return undef;
	}

	my ( $q, $sth );

	$q = qq{
		UPDATE
			Application_Instance
		SET
			Authentication_Method = :authmethod
		WHERE
			Application_Instance_ID = :id
	};

	if ( !( $sth = $dbh->prepare($q) ) ) {
		$self->Error(
"ApplicationInstance::AuthMethod: Error preparing database query setting authentication method"
		);
		return undef;
	}
	$sth->bind_param( ":id",         $id );
	$sth->bind_param( ":authmethod", $authmethod );
	if ( !( $sth->execute ) ) {
		$self->Error(
"AuthenticationInstance::AuthMethod: Error executing database query setting authentication method: "
			  . $dbh->errstr );
		return undef;
	}
	$sth->finish;
	$self->{AuthMethod} = $authmethod;
	return $authmethod;
}

sub Password {
	my $self = shift;

	my $password;
	if ( !( $password = shift ) ) {
		return $self->{Password};
	}

	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error(
"ApplicationInstance::Password: Invalid class reference passed"
		);
		return undef;
	}

	my $id;
	eval { $id = $self->Id };
	if ( !defined($id) ) {
		$self->Error(
"ApplicationInstance::Password: Invalid application object"
		);
		return undef;
	}

	if ( $self->AuthMethod ne 'password' ) {
		$self->Error(
			sprintf(
"Authentication method for application '%s', production state '%s' is not of type 'password'",
				$self->Application->Name, $self->ProdState
			)
		);
		return undef;
	}

	my ( $q, $sth );

	$q = qq{
		UPDATE
			Application_Instance
		SET
			Password = :password
		WHERE
			Application_Instance_ID = :id
	};

	if ( !( $sth = $dbh->prepare($q) ) ) {
		$self->Error(
"ApplicationInstance::Password: Error preparing database query setting password"
		);
		return undef;
	}
	$sth->bind_param( ":id",       $id );
	$sth->bind_param( ":password", $password );
	if ( !( $sth->execute ) ) {
		$self->Error(
"AuthenticationInstance::Password: Error executing database query setting password"
		);
		return undef;
	}
	$sth->finish;
	$self->{Password} = $password;
	return $password;
}

sub Keytab {
	my $self = shift;

	my $keytab;
	if ( !( $keytab = shift ) ) {
		return $self->{Keytab};
	}

	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error(
"ApplicationInstance::Keytab: Invalid class reference passed"
		);
		return undef;
	}

	my $id;
	eval { $id = $self->Id };
	if ( !defined($id) ) {
		$self->Error(
"ApplicationInstance::Keytab: Invalid application object"
		);
		return undef;
	}

	if ( $self->AuthMethod ne 'keytab' ) {
		$self->Error(
			sprintf(
"Authentication method for application '%s', production state '%s' is not of type 'keytab'",
				$self->Application->Name, $self->ProdState
			)
		);
		return undef;
	}

	my ( $q, $sth );

	$q = qq{
		UPDATE
			Application_Instance
		SET
			Keytab = :keytab
		WHERE
			Application_Instance_ID = :id
	};

	if ( !( $sth = $dbh->prepare($q) ) ) {
		$self->Error(
"ApplicationInstance::Keytab: Error preparing database query setting keytab"
		);
		return undef;
	}
	$sth->bind_param( ":id",     $id );
	$sth->bind_param( ":keytab", $keytab );
	if ( !( $sth->execute ) ) {
		$self->Error(
"AuthenticationInstance::Keytab: Error executing database query setting keytab"
		);
		return undef;
	}
	$sth->finish;
	$self->{Keytab} = $keytab;
	return $keytab;
}

sub Username {
	my $self = shift;

	my $username;
	if ( !( $username = shift ) ) {
		return $self->{Username};
	}

	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error(
"ApplicationInstance::Username: Invalid class reference passed"
		);
		return undef;
	}

	my $id;
	eval { $id = $self->Id };
	if ( !defined($id) ) {
		$self->Error(
"ApplicationInstance::Username: Invalid application object"
		);
		return undef;
	}

	my ( $q, $sth );

	$q = qq{
		UPDATE
			Application_Instance
		SET
			Username = :username
		WHERE
			Application_Instance_ID = :id
	};

	if ( !( $sth = $dbh->prepare($q) ) ) {
		$self->Error(
"ApplicationInstance::Username: Error preparing database query setting username"
		);
		return undef;
	}
	$sth->bind_param( ":id",       $id );
	$sth->bind_param( ":username", $username );
	if ( !( $sth->execute ) ) {
		$self->Error(
"AuthenticationInstance::Username: Error executing database query setting username"
		);
		return undef;
	}
	$sth->finish;
	$self->{Username} = $username;
	return $username;
}

sub Service {
	my $self = shift;

	my $service;
	if ( !( $service = shift ) ) {
		return $self->{Service};
	}

	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error(
"ApplicationInstance::Service: Invalid class reference passed"
		);
		return undef;
	}

	my $id;
	eval { $id = $self->Id };
	if ( !defined($id) ) {
		$self->Error(
"ApplicationInstance::Service: Invalid application object"
		);
		return undef;
	}

#	if ($self->AuthMethod ne 'service') {
#		$self->Error(sprintf(
#			"Authentication method for application '%s', production state '%s' is not of type 'service'",
#			$self->Application->Name,
#			$self->ProdState
#			));
#		return undef;
#	}

	my ( $q, $sth );

	$q = qq{
		UPDATE
			Application_Instance
		SET
			Service_Name = :service
		WHERE
			Application_Instance_ID = :id
	};

	if ( !( $sth = $dbh->prepare($q) ) ) {
		$self->Error(
"ApplicationInstance::Service: Error preparing database query setting service"
		);
		return undef;
	}
	$sth->bind_param( ":id",      $id );
	$sth->bind_param( ":service", $service );
	if ( !( $sth->execute ) ) {
		$self->Error(
"AuthenticationInstance::Service: Error executing database query setting service"
		);
		return undef;
	}
	$sth->finish;
	$self->{Service} = $service;
	return $service;
}

sub DBType {
	my $self = shift;

	my $dbtype;
	if ( !( $dbtype = shift ) ) {
		return $self->{DBType};
	}

	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error(
"ApplicationInstance::DBType: Invalid class reference passed"
		);
		return undef;
	}

	my $id;
	eval { $id = $self->Id };
	if ( !defined($id) ) {
		$self->Error(
"ApplicationInstance::DBType: Invalid application object"
		);
		return undef;
	}

	my ( $q, $sth );

	$q = qq{
		UPDATE
			Application_Instance
		SET
			Database_Type = :dbtype
		WHERE
			Application_Instance_ID = :id
	};

	if ( !( $sth = $dbh->prepare($q) ) ) {
		$self->Error(
"ApplicationInstance::DBType: Error preparing database query setting dbtype"
		);
		return undef;
	}
	$sth->bind_param( ":id",     $id );
	$sth->bind_param( ":dbtype", $dbtype );
	if ( !( $sth->execute ) ) {
		$self->Error(
"AuthenticationInstance::DBType: Error executing database query setting dbtype"
		);
		return undef;
	}
	$sth->finish;
	$self->{DBType} = $dbtype;
	return $dbtype;
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
		$self->Error("Invalid application instance object");
		return undef;
	}

	my $opt = &_options(@_);

	my ( $q, $sth );

	# Cascade if we're given the force option, otherwise, Vv

	if ( $opt->{force} ) {

		#
		# Remove this application from any Mclasses
		#
		$q = qq{
			DELETE FROM
				MClass_Application
			WHERE
				Application_Instance_ID = :id
		};

		if ( !( $sth = $dbh->prepare($q) ) ) {
			$self->Error(
"ApplicationInstance::Delete: Error preparing database query deleting application instance assignments"
			);
			return undef;
		}
		$sth->bind_param( ":id", $id );
		if ( !( $sth->execute ) ) {
			$self->Error(
"ApplicationInstance::Delete: Error executing database query deleting application instance assignments"
			);
		}
		$sth->finish;
	}

	#
	# Delete the application instance
	#
	$q = qq {
		DELETE FROM
			Application_Instance
		WHERE
			Application_Instance_Id = :id
	};

	if ( !( $sth = $dbh->prepare($q) ) ) {
		$self->Error(
"ApplicationInstance::Delete: Error preparing database query deleting application instance"
		);
		return undef;
	}
	$sth->bind_param( ":id", $id );
	if ( !( $sth->execute ) ) {
		$self->Error(
"ApplicationInstance::Delete: Error executing database query deleting application instance"
		);
	}
	if ( DBI::err && DBI::err == "2292" ) {
		$self->Error(
"Application instance must be removed from all mclasses before it can be deleted"
		);
		return undef;
	}
	$sth->finish;
	$self->Error(undef);
	return 1;
}

1;
__END__
