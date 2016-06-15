#
# Copyright (c) 2012-2013 Matthew Ragan
# Copyright (c) 2012-2016 Todd Kover
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

our $errstr;

use Exporter 'import';

our $VERSION = '1.0';

our @ISA       = qw(Exporter );
# note:  exporting variables is bad, but this allows for a common errstr
# throughout all the JazzHands::Common family.
our @EXPORT_OK = qw(SetError $errstr );

our %EXPORT_TAGS = ( 
	'all' => [qw(SetError)], 
	'internal' => [qw(SetError $errstr)] );

#
# This is used external to JazzHands and thus can't really change
# It is used internally to these libraries in a few places to handle cases
# where calls are bath both inside and not inside this library
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
# everything after this is not exported but part of the module
#

#
# tacks all arguments on to the end of the internal error array
#
# pass undef as the first argument and it clears out all existing errors
#
sub Error {
	my $self = shift @_;

	if($#_ >= 0 && !defined($_[0]) ) {
		delete $self->{_errors};
		$self->{_errors} = [];
		return;
	}

	SetError( $self->{_errors}, @_ );
	if(wantarray) {
		return @{$self->{_errors}};
	} else {
		$errstr = join("\n", @{$self->{_errors}});
		return $errstr;
	}
}

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


sub SetDebug {
	my $self = shift;
	if (@_) { $self->{_debug} = shift; }
	return $self->{_debug};
}

sub _Debug {
	my $self  = shift;
	my $level = shift;

	if ( $level <= $self->{_debug} && @_ ) {
		if($self->{_debug_callback}) {
			my $fmt = shift @_;
			my $str = sprintf ($fmt, @_);
			&{$self->{_debug_callback}}($level, $str);
		} else {
			printf STDERR @_; print STDERR "\n";
		}
	}
}


1;

__END__


=head1 NAME


=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FILES


=head1 AUTHORS

=cut

