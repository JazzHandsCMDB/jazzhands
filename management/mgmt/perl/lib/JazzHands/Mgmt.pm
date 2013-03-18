# Copyright (c) 2012,2013 Matthew Ragan
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package JazzHands::Mgmt;

use 5.008007;
use strict;
use warnings;
use JazzHands::DBI;
use JazzHands::Common qw(_options SetError);
use JazzHands::Common::GenericDB;
use JazzHands::Common::Util qw(:all);

use JazzHands::Mgmt::Netblock qw(GetNetblock);
use JazzHands::Mgmt::Collection qw(GetCollection);

use Data::Dumper;

my $ErrMsg = undef;

# The following modules are objectified.  The goal is to move all of the modules
# out of the lower list to the upper list and make the tools use the objectified
# modules.

use DBI;

use POSIX;

use vars qw($VERSION @EXPORT @ISA);

$VERSION = '1.0';    # $Date$

require Exporter;

our @ISA = ("Exporter", "JazzHands::Common::GenericDB", "JazzHands::Common::Util");
*import = \&Exporter::import;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $opt   = &_options;

	my $self = {};
	if ($opt->{dbhandle}) {
		$self->{_dbh} = $opt->{dbhandle};
	} elsif ($opt->{application}) {
		if (!($self->{_dbh} = JazzHands::DBI->new->connect(
				application => $opt->{application},
				cached => 1,
				appuser => $opt->{appuser},
				errors => $opt->{errors}
				))) {
			return undef;
		}
	}
	if ( $opt->{dberrors} ) {
		$self->{_IncludeDBErrors} = 1;
	}
	if ( $opt->{errors} ) {
		$self->{_errors} = $opt->{errors};
	}

	$self->{_dbh}->{AutoCommit} = 0;
	bless $self, $class;
}

sub clone {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $opt   = &_options;

	return undef if !$proto->{_dbh};
	my $self = {};
	$self->{_dbh}             = $proto->{_dbh};
	$self->{_IncludeDBErrors} = $proto->{_IncludeDBErrors};
	$self->{_errors} = $opt->{_errors};

	bless $self, $class;
}

sub ErrorRef {
	my $self = shift;

	if (@_) { $self->{_errors} = shift }
	return $self->{_errors};
}

sub InitializeCache {
	my $self = shift;

	$self->{_cache} = {};
	return $self->{_cache};
}

sub Cache {
	my $self = shift;

	return $self->{_cache};
}

sub DBErrors {
	my $self = shift;

	if (@_) { $self->{_IncludeDBErrors} = shift }
	return $self->{_IncludeDBErrors};
}

sub DESTROY {
	my $self = shift;

	if ( ref($self) eq "JazzHands::Mgmt" ) {
		if ( $self->{_dbh} ) {
			$self->{_dbh}->rollback;
			$self->{_dbh}->disconnect;
		}
	}
}

sub delete {
    my $self = shift;

	#
	# To delete, we get rid of the _current hash and then write
	#
	delete $self->{_current};
	$self->write(@_);
}

sub write {
    my $self = shift;
    my $opt = &_options(@_);
	my $dbh;


    if ($opt->{dbh}) {
		$dbh = $opt->{dbh};
	} else {
		eval {
			$dbh = $self->DBHandle;
		};
		if (!$dbh) {
			SetError($opt->{errors},
				"JazzHands::Mgmt::write: dbh parameter must be passed");
			return undef;
		}
    }

	#
	# If we're a collection, process deletions first, so if we're deleting
	# the collection itself, that won't fail because of constraints
	#
	my $memberdiff;
	if ($self->{_objecttype} eq 'membertable') {
		#
		# If the _currentmember hash does not exist, then we're deleting
		#
		if (!exists($self->{_currentmembers})) {
			if (exists($self->{_origmembers})) {
				if (!(JazzHands::Common::GenericDB->DBDelete(
						dbhandle => $dbh,
						table => $self->{_dbmembertable},
						dbkey => { map { $_ => $self->{_orig}->{$_} } 
							@{$self->{_dbkey}} },
						errors => $opt->{errors}))) {
					return undef;
				}
				delete $self->{_origmembers};
			}
		} else {
			if (exists($self->{_origmembers})) {
				$memberdiff = 
					member_hash_diff(
						$self->{_origmembers}, $self->{_currentmembers});

				if (@{$memberdiff->{deletions}}) {
					if (!(JazzHands::Common::GenericDB->DBDelete(
							dbhandle => $dbh,
							table => $self->{_dbmembertable},
							dbkey => { 
								(map { $_ => $self->{_orig}->{$_} } 
									@{$self->{_dbkey}}), 
								$self->{_memberkey} => 
									$memberdiff->{deletions}
							},
							errors => $opt->{errors}))) {
						return undef;
					}
				}
			}
		}
	}
	#
	# If the _current hash does not exist, then we're deleting
	#
	if (!exists($self->{_current})) {
		#
		# If the _orig hash also doesn't exist, then just pretend we
		# succeeded
		#
		if (!exists($self->{_orig})) {
			return 1;
		}
		if (ref($self->{_deletebeforehook}) eq 'CODE') {
			if (!(&{$self->{_deletebeforehook}}($self, @_))) {
				return undef;
			}
		}
		if (!(JazzHands::Common::GenericDB->DBDelete(
				dbhandle => $dbh,
				table => $self->{_dbtable},
				dbkey => { map { $_ => $self->{_orig}->{$_} } 
					@{$self->{_dbkey}} },
				errors => $opt->{errors}))) {
			return undef;
		}
		
		if (ref($self->{_deleteafterhook}) eq 'CODE') {
			if (!(&{$self->{_deleteafterhook}}($self, @_))) {
				return undef;
			}
		}

		delete $self->{_orig};
		return 1;
	}
		
    #
    # If the _orig hash exists, then we read this from the database, so
    # do an update
    #

    if ($self->{_orig}) {
		if (ref($self->{_updatebeforehook}) eq 'CODE') {
			if (!(&{$self->{_updatebeforehook}}($self, @_))) {
				return undef;
			}
		}
		my $updatehash = hash_table_diff(
			$self->{_orig}, $self->{_current});

		if (scalar(%{$updatehash})) {
			if (!(JazzHands::Common::GenericDB->DBUpdate(
					dbhandle => $dbh,
					table => $self->{_dbtable},
					dbkey => { map { $_ => $self->{_orig}->{$_} } 
						@{$self->{_dbkey}} },
					hash => $updatehash,
					errors => $opt->{errors}))) {
				return undef;
			}
		}
		if (ref($self->{_updateafterhook}) eq 'CODE') {
			if (!(&{$self->{_updateafterhook}}($self, @_))) {
				return undef;
			}
		}
    } else {
		if (ref($self->{_insertbeforehook}) eq 'CODE') {
			if (!(&{$self->{_insertbeforehook}}($self, @_))) {
				return undef;
			}
		}
        if (!(JazzHands::Common::GenericDB->DBInsert(
                dbhandle => $dbh,
                table => $self->{_dbtable},
                hash => $self->{_current},
                errors => $opt->{errors}))) {
			return undef;
		}
		if (ref($self->{_insertafterhook}) eq 'CODE') {
			if (!(&{$self->{_insertafterhook}}($self, @_))) {
				return undef;
			}
		}
    }
	#
	# Make _orig match _current
	#
	$self->{_orig} = {};
	foreach my $key (keys %{$self->{_current}}) {
		$self->{_orig}->{$key} = $self->{_current}->{$key};
	}

	#
	# Process member additions (deletes were done above)
	#
	if ($self->{_objecttype} eq 'membertable') {
		my $additions;
		if (exists($self->{_origmembers})) {
			$additions = $memberdiff->{additions};
		} else {
			$additions = [ keys %{$self->{_currentmembers}} ];
		}
		foreach my $key (@$additions) {
			if (!(JazzHands::Common::GenericDB->DBInsert(
					dbhandle => $dbh,
					table => $self->{_dbmembertable},
					hash => { 
						(map { $_ => $self->{_orig}->{$_} } 
							@{$self->{_dbkey}}), 
						$self->{_memberkey} => $key
					},
					errors => $opt->{errors}))) {
				return undef;
			}
		}
		$self->{_origmembers} = { %{$self->{_currentmembers}} };
	}
	
	1;
}

1;
__END__

=head1 NAME

JazzHands::Mgmt - Perl extension for manipulation to the JazzHands database

=head1 SYNOPSIS

  use JazzHands::Mgmt;

=head1 DESCRIPTION

This is used to interface with the JazzHands database.  

=head2 EXPORT

Most of the child modules export into the caller's namespace.

=head1 AUTHORS

	Matthew Ragan

=cut

