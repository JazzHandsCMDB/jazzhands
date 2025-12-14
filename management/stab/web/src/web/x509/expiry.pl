#!/usr/bin/env perl
#
# Copyright (c) 2017, Todd M. Kover
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
#

#
# $Id$
#

use strict;
use warnings;
use POSIX;
use Data::Dumper;
use Carp;
use JazzHands::STAB;

# causes stack traces on warnings
# local $SIG{__WARN__} = \&Carp::cluck;

do_cert_expiry_toplevel();

sub do_cert_expiry_toplevel {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html( {
		-title      => "Expiring Certificates next 120 days",
		-javascript => 'reporting'
	  } ),
	  "\n";

	print $cgi->h4( { -align => 'center' }, "Expiring Certificates" );

	print $stab->build_table_from_query(
		query => qq{
			SELECT	
					date_part('days', c.valid_to - now()) as "Lifetime (days)",
					c.x509_signed_certificate_id as "ID",
					c.friendly_name as "Friendly Name",
					c.valid_to as "Valid To",
					ca.x509_signed_certificate_id
						AS ca_x509_signed_certificate_id,
					ca.friendly_name AS "CA"
			FROM	x509_signed_certificate c
					JOIN x509_signed_certificate ca ON
						ca.x509_signed_certificate_id = c.signing_cert_id
			WHERE	c.is_active = 'Y'
			AND	c.x509_revocation_date IS NULL
			AND	c.valid_to <= now() + '120 days'::interval
			ORDER BY c.valid_to;
		},
		caption => 'Expiring Certificates',
		class   => 'reporting',
		tableid => 'approvalreport',
		hidden  => ['ca_x509_signed_certificate_id'],
		urlmap  => {
			"ID"            => "./?X509_CERT_ID=%{ID}",
			"Friendly Name" => "./?X509_CERT_ID=%{ID}",
			"CA" => "./?X509_CERT_ID=%{ca_x509_signed_certificate_id}",
		}
	);
	print "\n\n", $cgi->end_html, "\n";
}
