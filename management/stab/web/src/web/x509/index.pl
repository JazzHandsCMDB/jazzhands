#!/usr/bin/env perl
#
# Copyright (c) 2015, Todd M. Kover
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
use JazzHands::Common qw(_dbx);
use Net::IP;

# causes stack traces on warnings
# local $SIG{__WARN__} = \&Carp::cluck;

do_cert_toplevel();

sub do_cert_toplevel {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";

	my $crtid = $stab->cgi_parse_param('X509_CERT_ID');

	if ($crtid) {
		dump_cert($stab, $crtid);
	} else {
		show_pending_certs( $stab );
	}

	undef $stab;
}

sub show_pending_certs {
	my ( $stab, ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html(
		{ -title => "Certificates", -javascript => 'reporting' } ), "\n";

	print $cgi->h4( { -align => 'center' }, "Active Certificates" );


	print $stab->build_table_from_query(
		query => qq{
			SELECT	x.x509_cert_id,
					ca.x509_cert_id AS ca_x509_cert_id,
					x.is_active as "Act",
					x.friendly_name as "Friendly Name",
					x.is_certificate_authority AS "CA",
					x.valid_from as "Valid From",
					x.valid_to as "Valid To",
					x.valid_to - now() as "Lifetime",
					coalesce(ca.friendly_name, '') as "Sign"
			FROM	x509_certificate x
					LEFT JOIN x509_certificate ca ON
						ca.x509_cert_id = x.signing_cert_id
			WHERE	x.is_active = 'Y'
			order by x.valid_from desc
		},
		caption => 'Certificates',
		class   => 'reporting',
		tableid => 'approvalreport',
		hidden	=> [ 'x509_cert_id', 'ca_x509_cert_id' ],
		urlmap => {
			"Friendly Name" => "?X509_CERT_ID=%{x509_cert_id}",
			"Sign" => "?X509_CERT_ID=%{ca_x509_cert_id}",
		}
	);
	print "\n\n", $cgi->end_html, "\n";
}

sub dump_cert {
	my ($stab, $crtid) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html(
		{ -title => "Certificates", -javascript => 'reporting' } ), "\n";

	my $sth = $stab->prepare(qq{
		select 
			x509_cert_id,
			friendly_name,
			is_active,
			is_certificate_authority,
			signing_cert_id,
			x509_ca_cert_serial_number,
			public_key,
			certificate_sign_req,
			subject,
			subject_key_identifier,
			valid_from,
			valid_to,
			x509_revocation_date,
			x509_revocation_reason,
			ocsp_uri,
			crl_uri
		from x509_certificate
		where x509_cert_id = ?
	}) || return $stab->return_db_err();
		
	$sth->execute($crtid) || return $stab->return_db_err();
	my @cols = @{$sth->{NAME}};

	my @rows = $sth->fetchrow_array;
	$sth->finish;



	my $t = "";
	for(my $i = 0; $i < $#rows; $i++)  {
		$t .= $cgi->Tr(
			$cgi->td( [ $cols[$i], $rows[$i]||'' ] )
		);
	}

	print $cgi->h4( { -align => 'center' }, "Cert $crtid" );

	print $cgi->table({class=>'reporting'}, $t);
	print "\n\n", $cgi->end_html, "\n";

}
