#
# Copyright (c) 2012 Matthew Ragan
# Copyright (c) 2011-2013 Todd Kover
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

package JazzHands::Common::Util;

use strict;
use warnings;

use Exporter 'import';

use vars qw(@ISA %EXPORT_TAGS @EXPORT);

our $VERSION = '1.0';

our @ISA = qw(
	Exporter
);
our @EXPORT_OK = qw(_options _dbx hash_table_diff );

%EXPORT_TAGS = 
(
	'all' => [qw(_options _dbx hash_table_diff)],
);

our $direction = 'lower';

sub _options {
	my %ret = @_;
	for my $v ( grep { /^-/ } keys %ret ) {
		$ret{ substr( $v, 1 ) } = $ret{$v};
	}
	\%ret;
}


###############################################################################

sub _dbx {
	# XXX if oracle, return upper case, otherwise lower case
	my $x = shift;

	my $dir = $direction;

	if(ref($x)) { 
		if(ref($x) eq 'HASH') {
			my $r = {};
			foreach my $k (keys %$x) {
				if($direction eq 'lower') {
					$r->{ lc($k) } = $x->{$k};
				} else {
					$r->{ uc($k) } = $x->{$k};
				}
			}
			return $r;
		} else {
			return undef;
		}
	} else {
		if($direction eq 'lower') {
			return lc($x);
		} else {
			return uc($x);
		}
	}
}

#
# This takes two hash tables and returns the differences between the two,
# essentially returning the items in the second hash.
#
# It both handles the case of being imported class and being imported
# standalone depending on if there are three arguments or not.
#
# XXX: NOTE, in the case where the first argument is a class, and the
# last argument is left off (the first condition below), it does NOT DTRT.
#
# - If the second hash is not defined, it returns the first hash
# - If a key is in hash1 but does not exist in hash2, it is not included
# - if a key is in hash1 but exists and not defined in hash2, its included
# - if a key is not in hash1, it will not be included
# - if a key exists in hash1 but not defined and is not defined in hash2,
#       it will be included
# - if its defined and both, and they differ, it will be included
sub hash_table_diff {
	my ($arg1, $arg2, $arg3) = @_;

	my($self, $hash1, $hash2);
	if(defined($arg3)) {
		($hash1, $hash2) = ($arg2, $arg3);
	} else {
		($hash1, $hash2) = ($arg1, $arg2);
	}

	my %rv;
	if(!defined($hash2)) {
		%rv = %$hash1;
	} else {
		foreach my $key (keys %$hash1) {
			next if(!exists($hash2->{$key}));
			#- warn "comparing $hash1->{$key} && $hash2->{$key}\n";
			if(!defined($hash1->{$key}) && !defined($hash2->{$key})) {
				next;
			} elsif(defined($hash1->{$key}) && !defined($hash2->{$key})) {
				$rv{$key} = undef;
			} elsif((!defined($hash1->{$key})&&defined($hash2->{$key})) || $hash1->{$key} ne $hash2->{$key}) {
				#- warn "no match, adding $key";
				$rv{$key} = $hash2->{$key};
			}
		}
	}
	\%rv;
}

1;

__END__


=head1 NAME


=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FILES


=head1 AUTHORS

=cut


1;
