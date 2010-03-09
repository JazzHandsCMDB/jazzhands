#!/usr/local/bin/perl
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

#
# $Id$
# $HeadURL$
#

use strict;
use warnings;
use Net::Netmask;
use FileHandle;
use JazzHands::STAB;

do_cert_manip();

############################################################################3
#
# everything else is a subroutine
#
############################################################################3

sub do_cert_manip {
	my $stab = new JazzHands::STAB || die "Could not create STAB";

	my $certid = $stab->cgi_parse_param('X509_CERT_ID');

	if ( !$certid ) {
		show_cert_picker($stab);
	} else {
		show_cert( $stab, $certid );
	}
}

sub show_cert_picker {
	my ($stab) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	print $cgi->header;
	print $stab->start_html( -title => 'Certificates' );

	print $cgi->start_form(
		{ -method => 'GET', -action => $cgi->self_url } );
	print $stab->b_dropdown( undef, undef, 'X509_CERT_ID', 'X509_CERT_ID' );
	print $cgi->submit;
	print $cgi->end_form;

	print $cgi->end_html;
}

sub build_cert_table {
	my ( $stab, $x509cert ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $calink = "self signed certificate";
	if ( $x509cert->{X509_CERT_ID} != $x509cert->{SIGNING_CERT_ID} ) {
		$calink = $cgi->a(
			{
				-href => "./?X509_CERT_ID="
				  . $x509cert->{SIGNING_CERT_ID}
			},
			"signing cert (serial#",
			$x509cert->{X509_CA_CERT_SERIAL_NUMBER},
			")"
		);
	}

	my $table = $cgi->table(
		{ -border => 1 },
		$cgi->Tr(
			[
				$cgi->td( [ "Subject", $x509cert->{SUBJECT} ] ),
				$cgi->td( [ "CA",      $calink ] ),
				$cgi->td(
					[
						"Valid From",
						$x509cert->{VALID_FROM}
					]
				),
				$cgi->td(
					[ "Valid To", $x509cert->{VALID_TO} ]
				),
				$cgi->td(
					[
						"Is Revoked",
						$x509cert->{IS_CERT_REVOKED}
					]
				),
			]
		)
	);

	$table;
}

sub build_key_usage_table($$) {
	my ( $stab, $x509cert ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	# [XXX] move to perl library?
	my $sth = $stab->prepare(
		qq{
		select	x509_key_usg
		  from	X509_KEY_USAGE_ATTRIBUTE
		 where	x509_cert_Id = :1
	}
	);
	$sth->execute( $x509cert->{X509_CERT_ID} )
	  || die $stab->return_db_err($sth);

	my $tt = "";
	while ( my $hr = $sth->fetchrow_hashref ) {
		$tt .= $cgi->Tr( $cgi->td( $hr->{X509_KEY_USG} ) );
	}
	$cgi->table( { -style => 'border: 1px solid;' },
		$cgi->caption('Key Usage Attribues'), $tt );
}

sub build_dev_coll_assign($$) {
	my ( $stab, $x509cert ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	# this probably wants to move into the module
	my $sth = $stab->prepare(
		qq{
		select	dcac.*,
				su.login,
				ug.group_name,
				dc.device_collection_id
		 from	DEVICE_COLLECTION_ASSIGND_CERT dcac
				inner join system_user su on su.system_User_id =
					dcac.FILE_OWNER_SYSTEM_USER_ID
				inner join unix_group ug on ug.unix_group_id =
					dcac.FILE_GROUP_UNIX_GROUP_ID
				inner join device_collection dc
					on dc.device_collection_id =
						dcac.DEVICE_COLLECTION_ID
		where	dcac.X509_CERT_ID = :1
	}
	) || die $stab->return_db_err;

	$sth->execute( $x509cert->{X509_CERT_ID} )
	  || die $stab->return_db_err($stab);
	my $tt;
	while ( my $hr = $sth->fetchrow_hashref ) {
		my $pk = "X509_CERT_ID";
		$tt .= $cgi->Tr(
			$cgi->td(
				$cgi->table(
					{ -border => 1 },

		       # [XXX] need to deal with multi-field key in the build_tr
		       # functions
					$stab->build_tr(
						undef,          $hr,
						"b_dropdown",   "Purpose",
						"X509_KEY_USG", $pk
					),
					$stab->build_tr(
						undef,
						$hr,
						"b_dropdown",
						"File Format",
						"X509_FILE_FORMAT",
						$pk
					),
					$stab->build_tr(
						undef,
						$hr,
						"b_textfield",
						"Key Location",
						"FILE_LOCATION_PATH",
						$pk
					),
					$stab->build_tr(
						{
							-deviceCollectionType =>
							  'mclass'
						},
						$hr,
						"b_dropdown",
						"Mclass",
						"DEVICE_COLLECTION_ID",
						$pk
					),
					$cgi->Tr(
						[
							$cgi->td(
								[
"File Owner",
									$hr
									  ->{LOGIN}
								]
							),
							$cgi->td(
								[
"File Group",
									$hr
									  ->{GROUP_NAME}
								]
							),
							$cgi->td(
								[
"File Mode",
									$hr
									  ->{FILE_ACCESS_MODE}
								]
							),
						]
					),
					$stab->build_tr(
						undef,
						$hr,
						"b_textfield",
						"Passphrase Path",
						"FILE_PASSPHRASE_PATH",
						$pk
					),
				)
			)
		);
	}
	$cgi->table( { -style => 'border: 1px solid;', -border => 1 },
		$cgi->caption("Mclass Assignment"), $tt );
}

sub show_cert {
	my ( $stab, $certid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	print $cgi->header;
	print $stab->start_html( -title => 'Certificate' );

	my $x509cert = $stab->get_x509_cert_by_id($certid);
	if ( !$x509cert ) {
		$stab->msg_return("Unknown certificate");
	}

	my $cert_table = build_cert_table( $stab, $x509cert );
	my $keyusg_table = build_key_usage_table( $stab, $x509cert );
	my $mclass_table = build_dev_coll_assign( $stab, $x509cert );

	print $cgi->table(
		{ -align => 'center', -style => 'border: 1px solid;' },
		$cgi->Tr(
			{ -align => 'center' },
			$cgi->td( { -colspan => 2 }, $cert_table )
		),
		$cgi->Tr( $cgi->td( [ $keyusg_table, $mclass_table ] ) ),
	);

	print $cgi->end_html;
}
