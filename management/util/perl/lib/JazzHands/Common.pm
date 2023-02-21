#
# Copyright (c) 2013-2022 Todd Kover
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package JazzHands::Common;

use strict;
use warnings;
use JazzHands::Common::Util qw(:all);
use JazzHands::Common::Error qw(:internal);
use Data::Dumper;

use vars qw(@ISA %EXPORT_TAGS @EXPORT);

use Exporter;    # 'import';

our $VERSION = '1.0';

our @ISA = qw(
  Exporter
  JazzHands::Common::Util
  JazzHands::Common::Error
);

our @EXPORT;
our @EXPORT_OK;
our %EXPORT_TAGS = (
	'all' => [],

	# note that :db is special, see my import function
	'inernal' => [],
);

#foreach my $c (@ISA) {
#	print "C is $c\n";
#	my @x = @{$c::EXPORT};
#	foreach my $name (@x) {
#		print "NAME in $c is $name\n";
#	}
#}

# pull up all the stuff from JazzHands::Common::Util
push( @EXPORT,    @JazzHands::Common::Util::EXPORT );
push( @EXPORT_OK, @JazzHands::Common::Util::EXPORT_OK );
foreach my $name ( keys %JazzHands::Common::Util::EXPORT_TAGS ) {
	push(
		@{ $EXPORT_TAGS{$name} },
		@{ $JazzHands::Common::Util::EXPORT_TAGS{$name} } );
}

# pull up all the stuff from JazzHands::Common::Error
push( @EXPORT,    @JazzHands::Common::Error::EXPORT );
push( @EXPORT_OK, @JazzHands::Common::Error::EXPORT_OK );
foreach my $name ( keys %JazzHands::Common::Error::EXPORT_TAGS ) {
	push(
		@{ $EXPORT_TAGS{$name} },
		@{ $JazzHands::Common::Error::EXPORT_TAGS{$name} } );
}

sub import {
	if ( grep( $_ =~ /^\:(db|all)$/, @_ ) ) {
		require JazzHands::Common::GenericDB;
		JazzHands::Common::GenericDB->import(qw(:all));
		JazzHands::Common::GenericDB->import(qw(:legacy));

		# pull up all the stuff from JazzHands::Common::GenericDB
		push( @EXPORT,    @JazzHands::Common::GenericDB::EXPORT );
		push( @EXPORT_OK, @JazzHands::Common::GenericDB::EXPORT_OK );
		foreach my $name ( keys %JazzHands::Common::GenericDB::EXPORT_TAGS ) {
			push(
				@{ $EXPORT_TAGS{$name} },
				@{ $JazzHands::Common::GenericDB::EXPORT_TAGS{$name} } );
		}
		push(
			@{ $EXPORT_TAGS{'db'} },
			@{ $JazzHands::Common::GenericDB::EXPORT_TAGS{'all'} } );
	}

	my $save = $Exporter::ExportLevel;
	$Exporter::ExportLevel = 1;
	Exporter::import(@_);
	$Exporter::ExportLevel = $save;

}

#
# can be called from a child classs, sets everything up that may be used by
# the routines under this hierarchy
#
sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $opt   = &_options;

	my $self = {};
	bless $self, $class;

	if ( $opt->{debug_callback} ) {
		$self->{_debug_callback} = $opt->{debug_callback};
	}

	$self->{_debug}  = 0 if ( !$self->{_debug} );
	$self->{_errors} = [];
	$self;
}

1;

=head1 NAME

JazzHands::Common - Perl extensions that are used throughout JazzHands

=head1 SYNOPSIS

use JazzHands::Common;

This class imports (and makes available for export) things in other
subclasses.  

=head1 DESCRIPTION
head1 SEE ALSO

JazzHands::Common::Util, JazzHands::Common::GenericDB, 
	JazzHands::Common::Error

=head1 AUTHOR

Todd Kover, Matthew Ragan

=head1 COPYRIGHT AND LICENSE

