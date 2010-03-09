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

package JazzHands::Management::Application;

use strict;
use vars qw($VERSION @EXPORT @ISA);

$VERSION = '1.0.0';    # $Date$

require Exporter;
our @ISA = ( "Exporter", "JazzHands::Management" );

@EXPORT = qw(
  CreateApplication
  GetApplication
  GetApplications
);

sub import {
	JazzHands::Management::Application->export_to_level( 1, @_ );
}

sub _options {
	my %ret = @_;
	for my $v ( grep { /^-/ } keys %ret ) {
		$ret{ substr( $v, 1 ) } = $ret{$v};
	}
	\%ret;
}

sub GetApplication {
	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error("GetApplication: Invalid class reference passed");
		return undef;
	}

	my $opt = &_options(@_);
	if ( !$opt->{name} && !$opt->{id} ) {
		$self->Error("GetApplication: name or id must be given");
		return undef;
	}

	my ( $q, $sth );

	$q = qq {
		SELECT
			Application_ID,
			Name,
			Description
		FROM
			Application
		WHERE
	};
	if ( $opt->{id} ) {
		$q .= qq {
			Application_ID = :id
		};
	} else {
		$q .= qq {
			Name = :name
		};
	}

	if ( !( $sth = $dbh->prepare_cached($q) ) ) {
		$self->Error( "GetApplication: Error preparing database query: "
			  . DBI::errstr );
		return undef;
	}

	if ( $opt->{id} ) {
		$sth->bind_param( ":id", $opt->{id} );
	} else {
		$sth->bind_param( ":name", $opt->{name} );
	}

	if ( !( $sth->execute ) ) {
		$self->Error("GetApplication: Error executing database query");
		return undef;
	}
	my ( $id, $name, $desc ) = $sth->fetchrow_array;
	$sth->finish;
	if ( !$name ) {
		$self->Error(
			"Application not found with "
			  . (
				$opt->{id}
				? ( "id " . $opt->{id} )
				: ( "name " . $opt->{name} )
			  )
		);
		return undef;
	}
	my $appl = $self->copy;
	$appl->{Id}          = $id;
	$appl->{Name}        = $name;
	$appl->{Description} = $desc;
	bless $appl;
}

sub GetApplications {
	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error("GetApplications: Invalid class reference passed");
		return undef;
	}

	my $opt = &_options(@_);
	my ( $q, $sth );

	$q = qq {
		SELECT
			Application_ID,
			Name,
			Description
		FROM
			Application
	};
	if ( !( $sth = $dbh->prepare_cached($q) ) ) {
		$self->Error("GetApplications: Error preparing database query");
		return undef;
	}

	if ( !( $sth->execute ) ) {
		$self->Error("GetApplications: Error executing database query");
		return undef;
	}

	my @rv;
	while ( my ( $id, $name, $desc ) = $sth->fetchrow_array ) {
		my $appl = $self->copy;
		$appl->{Id}          = $id;
		$appl->{Name}        = $name;
		$appl->{Description} = $desc;
		bless $appl;
		push @rv, $appl;
	}
	$sth->finish;
	\@rv;
}

sub Id {
	my $self = shift;

	return $self->{Id};
}

sub GetInstance {
	my $self = shift;

	return $self->GetApplicationInstance(
		application => $self,
		@_
	);
}

sub GetInstances {
	my $self = shift;

	return $self->GetApplicationInstances(
		application => $self,
		@_
	);
}

sub CreateInstance {
	my $self = shift;

	return $self->CreateApplicationInstance(
		application => $self,
		@_
	);
}

sub Name {
	my $self = shift;

	my $name;
	if ( !( $name = shift ) ) {
		return $self->{Name};
	}

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
		$self->Error("Invalid application object");
		return undef;
	}

	my ( $q, $sth );

	$q = qq{
		UPDATE
			Application
		SET
			Name = :name
		WHERE
			Application_ID = :id
	};

	if ( !( $sth = $dbh->prepare($q) ) ) {
		$self->Error(
"Application::Name: Error preparing database query setting application name"
		);
		return undef;
	}
	$sth->bind_param( ":id",   $id );
	$sth->bind_param( ":name", $name );
	if ( !( $sth->execute ) ) {
		$self->Error(
"Application::Name: Error executing database query setting application name"
		);
	}
	$sth->finish;
	$dbh->commit;
	$self->{Name} = $name;
	return $name;
}

sub Description {
	my $self = shift;

	my $desc;
	if ( !@_ ) {
		return $self->{Description};
	}
	$desc = shift;

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
		$self->Error("Invalid application object");
		return undef;
	}

	my ( $q, $sth );

	$q = qq{
		UPDATE
			Application
		SET
			Description = :description
		WHERE
			Application_ID = :id
	};

	if ( !( $sth = $dbh->prepare($q) ) ) {
		$self->Error(
"Application::Description: Error preparing database query setting description"
		);
		return undef;
	}
	$sth->bind_param( ":id",          $id );
	$sth->bind_param( ":description", $desc );
	if ( !( $sth->execute ) ) {
		$self->Error(
"Application::Description: Error executing database query setting description"
		);
	}
	$sth->finish;
	$self->{Description} = $desc;
	return $desc;
}

sub CreateApplication {
	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error(
			"CreateApplication: Invalid class reference passed");
		return undef;
	}

	my $opt = &_options(@_);
	if ( !$opt->{name} ) {
		$self->Error(
			"CreateApplication: new application name must be given"
		);
		return undef;
	}

	if ( $self->GetApplication( name => $opt->{name} ) ) {
		$self->Error("Application already exists");
		return undef;
	}
	my ( $q, $sth );

	$q = qq {
		INSERT INTO Application (
			Name,
			Description
		) VALUES (
			:name,
			:description
		) RETURNING Application_ID INTO :id
	};

	if ( !( $sth = $dbh->prepare($q) ) ) {
		$self->Error(
			"CreateApplication: Error preparing database query: "
			  . DBI::errstr );
		return undef;
	}

	$sth->bind_param( ":name", $opt->{name} );
	if ( $opt->{description} ) {
		$opt->{description} = undef;
	}
	$sth->bind_param( ":description", $opt->{description} );
	my $id;
	$sth->bind_param_inout( ":id", \$id, 32 );

	if ( !( $sth->execute ) ) {
		$self->Error( "GetApplication: Error executing database query: "
			  . DBI::errstr );
		return undef;
	}
	$dbh->commit;
	my $appl = $self->copy;
	$appl->{Id}          = $id;
	$appl->{Name}        = $opt->{name};
	$appl->{Description} = $opt->{description};
	bless $appl;
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

	my $opt = &_options(@_);

	my $id = $self->Id;
	if ( !defined($id) ) {
		$self->Error("Invalid application object");
		return undef;
	}

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
				Application_Instance_ID IN (
					SELECT
						Application_Instance_ID
					FROM
						Application_Instance
					WHERE
						Application_ID = :id
				)
		};

		if ( !( $sth = $dbh->prepare($q) ) ) {
			$self->Error(
"Application::Delete: Error preparing database query deleting application instance assignments"
			);
			return undef;
		}
		$sth->bind_param( ":id", $id );
		if ( !( $sth->execute ) ) {
			$self->Error(
"Application::Delete: Error executing database query deleting application instance assignments"
			);
		}
		$sth->finish;

		#
		# Get rid of all of the instances of this application
		#
		$q = qq{
			DELETE FROM
				Application_Instance
			WHERE
				Application_ID = :id
		};

		if ( !( $sth = $dbh->prepare($q) ) ) {
			$self->Error(
"Application::Delete: Error preparing database query deleting application instances"
			);
			return undef;
		}
		$sth->bind_param( ":id", $id );
		if ( !( $sth->execute ) ) {
			$self->Error(
"Application::Delete: Error executing database query deleting application instances"
			);
		}
		$sth->finish;
	}

	#
	# Delete the application
	#
	$q = qq {
		DELETE FROM
			Application
		WHERE
			Application_Id = :id
	};

	if ( !( $sth = $dbh->prepare($q) ) ) {
		$self->Error(
"Application::Delete: Error preparing database query deleting application"
		);
		return undef;
	}
	$sth->bind_param( ":id", $id );
	if ( !( $sth->execute ) ) {
		$self->Error(
"Application::Delete: Error executing database query deleting application"
		);
		return undef;
	}
	if ( DBI::err && DBI::err == "2292" ) {
		$self->Error(
"All application instances must be removed before the application can be deleted"
		);
		return undef;
	}

	$sth->finish;
	$dbh->commit;
	$self->Error(undef);
	return 1;
}

1;
__END__
