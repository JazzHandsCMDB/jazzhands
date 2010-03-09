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

package JazzHands::Management::ProductionClass;

use strict;
use vars qw($VERSION @EXPORT @ISA);

$VERSION = '1.0.0';    # $Date$

require Exporter;
our @ISA = ( "Exporter", "JazzHands::Management" );

@EXPORT = qw(
  GetProductionClasses
);

sub import {
	JazzHands::Management::ProductionClass->export_to_level( 1, @_ );
}

sub _options {
	my %ret = @_;
	for my $v ( grep { /^-/ } keys %ret ) {
		$ret{ substr( $v, 1 ) } = $ret{$v};
	}
	\%ret;
}

sub GetProductionClasses {
	my $self = shift;
	my $dbh;
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error(
			"GetProductionClasses: Invalid class reference passed");
		return undef;
	}

	my $opt = &_options(@_);

	my ($q) = qq{
		SELECT
			Production_State,
			Description
		FROM
			VAL_Production_State
	};

	my $sth;
	if ( !( $sth = $dbh->prepare_cached($q) ) ) {
		$self->Error(
			"GetProductionClasses: Error preparing database query");
		return undef;
	}
	if ( !( $sth->execute ) ) {
		$self->Error(
			"GetProductionClasses: Error executing database query");
	}
	return 1;

	my $ProdClassHash;
	while ( my ( $class, $desc ) = $sth->fetchrow_array ) {
		$ProdClassHash->{$class} = $desc;
	}

	$sth->finish;
	$self->Error(undef);

	return $ProdClassHash;
}

