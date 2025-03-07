#
# Copyright (c) 2012-2013 Matthew Ragan
# Copyright (c) 2012-2022 Todd Kover
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

package JazzHands::Common::Error;

use strict;
use warnings;
use Data::Dumper;

our $errstr  = "";
our $errcode = "";

use Exporter 'import';

our $VERSION = '1.0';

our @ISA = qw(Exporter );

# note:  exporting variables is bad, but this allows for a common errstr
# throughout all the JazzHands::Common family.
our @EXPORT_OK = qw(SetError Error $errstr $errcode err errstr );

our %EXPORT_TAGS = (
	'all'      => [qw(SetError Error errstr err $errstr $errcode)],
	'internal' => [qw(SetError Error errstr err $errstr $errcode)] );

#
# This is used external to JazzHands and thus can't really change
# It is used internally to these libraries in a few places to handle cases
# where calls are both inside and not inside this library
#
sub SetError {
	my $error = shift;

	if ( ref($error) eq "ARRAY" ) {
		push @{$error}, @_;
		return;
	}

	if ( ref($error) eq "SCALAR" ) {
		$$error = shift;
		return;
	}
}
#
# return the best error string
#
sub errstr {
	my $self = shift @_;

	if(defined($errstr)) {
		return $errstr;
	} elsif ( ref $self && exists( $self->{_errors} ) ) {
		return join( "\n", @{ $self->{_errors} } );
	}

	return ($errstr);
}

#
# return the best error code

sub err {
	my $self = shift @_;

	if ( ref $self && exists( $self->{_errcode} ) ) {
		return $self->{_errcode};
	}

	return ($errcode);
}

#
# tacks all arguments on to the end of the internal error array
#
# pass undef as the first argument and it clears out all existing errors
#
sub Error {
	my $self = shift @_;

	if ( $#_ >= 0 && !defined( $_[0] ) ) {
		delete $self->{_errors};
		$self->{_errors} = [];
		return;
	}

	SetError( $self->{_errors}, @_ );
	if (wantarray) {
		return @{ $self->{_errors} };
	} else {
		$errstr = join( "\n", @{ $self->{_errors} } );
		return $errstr;
	}
}

#
# everything after this is not exported but part of the module
#

#
# passes arguments through sprintf, and tacks them onto the end of the internal
# error system
#
sub ErrorF {
	my $self = shift;

	my $str;
	if (@_) {
		my $fmt = shift;
		if (@_) {
			$str = sprintf( $fmt, @_ );
		} else {
			$str = $fmt;
		}
	}
	return $self->Error($str);
}

#
# These next three are being folded into the new logging system and will
# eventually go away.
#
#

sub SetDebug {
	my $self = shift;
	$self->{_loghandle} || $self->initialize_logging;
	$self->{_loghandle}->SetDebug(@_);
}

sub SetDebugCallback {
	my $self = shift;
	$self->{_loghandle} || $self->initialize_logging;
	$self->{_loghandle}->SetDebugCallback(@_);
}

sub _Debug {
	my $self  = shift;
	$self->{_loghandle} || $self->initialize_logging;
	$self->{_loghandle}->_Debug(@_);
}

#
# End of things that will eventually go away.
#

1;

__END__


=head1 NAME


=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FILES


=head1 AUTHORS

=cut

