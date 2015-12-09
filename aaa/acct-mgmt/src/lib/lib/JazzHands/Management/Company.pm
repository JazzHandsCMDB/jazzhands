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

package JazzHands::Management::Company;

use strict;
use vars qw($VERSION @EXPORT @ISA);

$VERSION = '2.0.0';

require Exporter;
our @ISA = ( "Exporter", "JazzHands::Management" );
@EXPORT = qw(
  FindCompanyByID
);

#
# options:
#
#	none
#
# though i suppose i can re-write this function like this:
#
#	FindCompany({-company_id => n, -company_name => aaa})
#
sub FindCompanyByID {
	my ( $self, $company_id ) = @_;
	my $dbh;
	my ($hash);
	my ($sql);
	my ($sth);

	#
	# database handle
	#
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error("Invalid class reference passed");
		return undef;
	}

	#
	# query to get all access
	#
	$sql = qq(
		SELECT company_id, company_name, company_code, description
		FROM company
			INNER JOIN company_type using (company_id)
		WHERE company_id = $company_id
		AND company_type = 'corporate family'
	);
	if ( !( $sth = $dbh->prepare_cached($sql) ) ) {
		$JazzHands::Management::Errmsg =
		  "prepare_cached failed for: \"$sql\"";
		return undef;
	}
	if ( !$sth->execute ) {
		$JazzHands::Management::Errmsg = "execute failed for: \"$sql\"";
		return undef;
	}
	if ( !( $hash = $sth->fetchall_hashref("COMPANY_ID") ) ) {
		$JazzHands::Management::Errmsg =
		  "fetchall_hashref failed for: \"$sql\"";
		return undef;
	}

	#
	# success
	#
	return $hash->{$company_id};
}

1;
