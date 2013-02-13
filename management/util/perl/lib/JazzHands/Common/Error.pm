#
# Copyright (c) 2012-2013 Matthew Ragan
# Copyright (c) 2012-2013 Todd Kover
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

use Exporter 'import';

our $VERSION = '1.0';

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(SetError );

our %EXPORT_TAGS = 
(
        'all' => [qw(SetError)],
);


sub SetError {
	my $error = shift;

	if (ref($error) eq "ARRAY") {
		push @{$error}, @_;
		return;
	}

	if (ref($error) eq "SCALAR") {
		$$error = shift;
		return;
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

