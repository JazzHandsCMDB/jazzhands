-- Copyright (c) 2021, Bernard Jech
-- Copyright (c) 2023, Todd Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

\set ON_ERROR_STOP

-------------------------------------------------------------------------------
--
-- The following block tests whether the PL/Perl language is enabled
-- and whether all requisite Perl modules are avilable. If not, a warning
-- is emitted and the function pg_temp.pl_perl_failed() returns true.
-- If PL/Perl is enabled and all Perl modules present, the function
-- pg_temp.pl_perl_failed() returns false.
--
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION pg_temp.pl_perl_failed() RETURNS boolean
	AS $$ BEGIN RETURN true; END; $$ LANGUAGE plpgsql;
DO $_$
BEGIN
	BEGIN
		CREATE OR REPLACE FUNCTION pg_temp.pl_perl_failed() RETURNS boolean
			AS $$ use Crypt::OpenSSL::X509; return 1; $$ LANGUAGE plperl;
	EXCEPTION
		WHEN undefined_object THEN
			RAISE WARNING 'Language PL/Perl not enabled';
			RAISE;
		WHEN syntax_error THEN
			RAISE WARNING 'Perl module Crypt::OpenSSL::X509 not found';
			RAISE;
	END;
	BEGIN
		CREATE OR REPLACE FUNCTION pg_temp.pl_perl_failed() RETURNS boolean
			AS $$ use Crypt::OpenSSL::RSA; return 1; $$ LANGUAGE plperl;
	EXCEPTION
		WHEN syntax_error THEN
			RAISE WARNING 'Perl module Crypt::OpenSSL::RSA not found';
			RAISE;
	END;
	BEGIN
		CREATE OR REPLACE FUNCTION pg_temp.pl_perl_failed() RETURNS boolean
			AS $$ use Crypt::OpenSSL::PKCS10; return 1; $$ LANGUAGE plperl;
	EXCEPTION
		WHEN syntax_error THEN
			RAISE WARNING 'Perl module Crypt::OpenSSL::PKCS10 not found';
			RAISE;
	END;
	BEGIN
		CREATE OR REPLACE FUNCTION pg_temp.pl_perl_failed() RETURNS boolean
			AS $$ use MIME::Base64; return 1; $$ LANGUAGE plperl;
	EXCEPTION
		WHEN syntax_error THEN
			RAISE WARNING 'Perl module MIME::Base64 not found';
			RAISE;
	END;
	BEGIN
		CREATE OR REPLACE FUNCTION pg_temp.pl_perl_failed() RETURNS boolean
			AS $$ use File::Temp; return 1; $$ LANGUAGE plperl;
	EXCEPTION
		WHEN syntax_error THEN
			RAISE WARNING 'Perl module File::Temp not found';
			RAISE;
	END;
	BEGIN
		CREATE OR REPLACE FUNCTION pg_temp.pl_perl_failed() RETURNS boolean
			AS $$ use Digest::SHA; return 0; $$ LANGUAGE plperl;
	EXCEPTION
		WHEN syntax_error THEN
			RAISE WARNING 'Perl module Digest::SHA not found';
			RAISE;
	END;
EXCEPTION
	WHEN undefined_object OR syntax_error THEN NULL;
END $_$;

-- Conditionally terminate the script if pg_temp.pl_perl_failed() returns true

SELECT pg_temp.pl_perl_failed() AS pl_perl_failed
\gset
\if :pl_perl_failed

	\if :{?global_failonnoplperl}
		\if :global_failonnoplperl
			DO $_$ BEGIN RAISE 'No pl/perl and it is  declared necessary'; END; $_$;
		\else
			\q
		\endif
	\else
		\q
	\endif
\endif

-- Create the schema x509_plperl_cert_utils

DO $_$
BEGIN
	CREATE SCHEMA x509_plperl_cert_utils AUTHORIZATION jazzhands;
	REVOKE ALL ON SCHEMA x509_plperl_cert_utils FROM public;
	COMMENT ON SCHEMA x509_plperl_cert_utils IS 'part of jazzhands';
EXCEPTION
	WHEN duplicate_schema THEN NULL;
END $_$;

-------------------------------------------------------------------------------
--
-- Return certificate fingerprints as a JSONB object suitable to be passed
-- to the function x509_hash_manip.get_or_create_public_key_hash_id
--
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION x509_plperl_cert_utils.get_public_key_fingerprints(
	jazzhands.x509_signed_certificate.public_key%TYPE
) RETURNS jsonb AS $$
	my $x509   = Crypt::OpenSSL::X509->new_from_string(shift);
	my $sha1   = lc($x509->fingerprint_sha1());
	my $sha256 = lc($x509->fingerprint_sha256());

	$sha1	=~ s/://g;
	$sha256 =~ s/://g;

	my $json1   = sprintf('{"algorithm":"sha1",  "hash":"%s"}', $sha1);
	my $json256 = sprintf('{"algorithm":"sha256","hash":"%s"}', $sha256);
	return sprintf('[%s,%s]', $json1, $json256);
$$ LANGUAGE plperl;

-------------------------------------------------------------------------------
--
-- Return certificate hashes as a JSONB object suitable to be passed
-- to the function x509_hash_manip.get_or_create_public_key_hash_id
--
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION x509_plperl_cert_utils.get_public_key_hashes(
	jazzhands.x509_signed_certificate.public_key%TYPE
) RETURNS jsonb AS $$
	my $x509   = Crypt::OpenSSL::X509->new_from_string(shift);
	my $pubstr = $x509->pubkey;

	if ( $x509->key_alg_name eq 'rsaEncryption' ) {
		my $rsapub = Crypt::OpenSSL::RSA->new_public_key($pubstr);
		$pubstr = $rsapub->get_public_key_x509_string;
	}

	$pubstr =~ s/-----(BEGIN|END) PUBLIC KEY-----//g;

	my $der	   = decode_base64($pubstr);
	my $sha1   = sha1_hex($der);
	my $sha256 = sha256_hex($der);

	my $json1   = sprintf('{"algorithm":"sha1",  "hash":"%s"}', $sha1);
	my $json256 = sprintf('{"algorithm":"sha256","hash":"%s"}', $sha256);
	return sprintf('[%s,%s]', $json1, $json256);
$$ LANGUAGE plperl;

-------------------------------------------------------------------------------
--
-- Return certificate subject key identifier
--
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION x509_plperl_cert_utils.get_public_key_ski(
	jazzhands.x509_signed_certificate.public_key%TYPE
) RETURNS
	jazzhands.x509_signed_certificate.subject_key_identifier%TYPE
AS $_$
	my $x509 = Crypt::OpenSSL::X509->new_from_string(shift);

	if ( $x509->num_extensions > 0 ) {
		my $exts    = $x509->extensions_by_name();
		my $ski_ext = $$exts{subjectKeyIdentifier};

		if ( defined $ski_ext ) {
			my $ski_ext_value = $ski_ext->value();

			if ( $ski_ext_value =~ /#0414([0-9A-F]{40})/ ) {
				my $ski = $1;
				$ski =~ s/..\K(?=.)/:/sg;
				return $ski;
			}
		}
	}

	return;
$_$ LANGUAGE plperl;

-------------------------------------------------------------------------------
--
-- Return CSR hashes as a JSONB object suitable to be passed
-- to the function x509_hash_manip.get_or_create_public_key_hash_id
--
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION x509_plperl_cert_utils.get_csr_hashes(
	jazzhands.certificate_signing_request.certificate_signing_request%TYPE
) RETURNS jsonb AS $$
	my $csr_pem = shift;
	my $tmp	    = File::Temp->new();

	print $tmp $csr_pem;
	$tmp->close;

	my $csr	   = Crypt::OpenSSL::PKCS10->new_from_file($tmp->filename);
	my $pubstr = $csr->get_pem_pubkey();

	$pubstr =~ s/-----(BEGIN|END) PUBLIC KEY-----//g;

	my $der	   = decode_base64($pubstr);
	my $sha1   = sha1_hex($der);
	my $sha256 = sha256_hex($der);

	my $json1   = sprintf('{"algorithm":"sha1",  "hash":"%s"}', $sha1);
	my $json256 = sprintf('{"algorithm":"sha256","hash":"%s"}', $sha256);
	return sprintf('[%s,%s]', $json1, $json256);
$$ LANGUAGE plperl;

-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--
-- Returns a JSON blob with all the information about an x509 certificate so
-- that it can be inserted into the database
--
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION x509_plperl_cert_utils.parse_x509_certificate(
	certificate jazzhands.x509_signed_certificate.public_key%TYPE
) RETURNS jsonb AS $pgsql$
	my $pem = shift || return undef;

	my $x509 = Crypt::OpenSSL::X509->new_from_string($pem) || return undef;

	my $friendly;
	my $names = $x509->subject_name()->entries();
	foreach my $e ( @{$names} ) {
		next if $e->type() ne 'CN';
		$friendly = $e->value();
		last;
	}

	my @ku;
	my @san;

	my ( $ski, $aki, $ca );
	my $exts = $x509->extensions_by_oid();
	foreach my $oid ( keys %$exts ) {
		my $ext = $$exts{$oid};
		if ( $oid eq '2.5.29.14' ) {
			$ski = $ext->to_string();
			$ski =~ s/\s+$//;
		} elsif ( $oid eq '2.5.29.35' ) {
			$aki = $ext->to_string();
			$aki =~ s/keyid://;
			$aki =~ s/\s+$//;
		} elsif ( $oid eq '2.5.29.19' ) {

			# basic constraints;
			my $x = $ext->to_string();
			if ( $x && $x =~ /CA:TRUE/i ) {
				$ca = 1;
			}
		} elsif ( $oid eq '2.5.29.15' ) {

			# my $c = $ext->critical();
			my $map = {
				"Digital Signature" => "digitalSignature",
				"Non Repudiation"   => "nonRepudiation",
				"Key Encipherment"  => "keyEncipherment",
				"Data Encipherment" => "dataEncipherment",
				"Key Agreement"     => "keyAgreement",
				"Certificate Sign"  => "keyCertSign",
				"CRL Sign"          => "cRLSign",
				"Encipher Only"     => "encipherOnly",
				"Decipher Only"     => "decipherOnly",
			};

			# yes, I threw up a litle; these are from crypto/x509v3/v3_bitst.c
			foreach my $ku ( split( /,\s*/, $ext->to_string() ) ) {
				push( @ku, $map->{$ku} ) if ( $map->{$ku} );
			}

		} elsif ( $oid eq '2.5.29.37' ) {
			my $map = {
				"serverAuth"      => "TLS Web Server Authentication",
				"clientAuth"      => "TLS Web Client Authentication",
				"codeSigning"     => "Code Signing",
				"emailProtection" => "E-mail Protection",
				"timeStamping"    => "Time Stamping",
				"OCSPSigning"     => "OCSP Signing"
			};

			# yes, I threw up a litle; these are from crypto/objects/obj_dat.h
			foreach my $ku ( split( /,\s*/, $ext->to_string() ) ) {
				push( @ku, $map->{$ku} ) if ( $map->{$ku} );
			}

		} elsif ($oid eq '2.5.29.17') {
			push(@san, split(/,\s*/, $ext->to_string() ));
		} else {
			next;
		}
	}

	@ku = map { qq{"$_"} } @ku;
	@san = map { qq{"$_"} } @san;
	my $rv = {
		friendly_name            => $friendly,
		subject                  => $x509->subject(),
		issuer                   => $x509->issuer(),
		serial                   => $x509->serial(),
		signing_algorithm        => $x509->sig_alg_name(),
		key_algorithm            => $x509->key_alg_name(),
		is_ca                    => $ca,
		valid_from               => $x509->notBefore,
		valid_to                 => $x509->notAfter,
		self_signed              => ( $x509->is_selfsigned() ) ? 1 : undef,
		subject_key_identifier   => $ski,
		authority_key_identifier => $aki,
		keyUsage                 => \@ku,
		subjectAlternateName     => \@san,
	};

	# this is naaaasty but I did not want to require the JSON pp module
	my $x = sprintf "{ %s }", join(
		',',
		map {
			qq{"$_": }
			  . (
				( defined( $rv->{$_} ) )
				? (
					( ref( $rv->{$_} ) eq 'ARRAY' )
					? '[ ' . join( ',', @{ $rv->{$_} } ) . ' ]'
					: qq{"$rv->{$_}"}
				  )
				: 'null'
			  )
		} keys %$rv
	);
	$x;
$pgsql$ LANGUAGE plperl;

-------------------------------------------------------------------------------
--
-- Returns a JSON blob with all the information about an PKCS10 cert sign req
-- so that it can be inserted into the database
--
-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION x509_plperl_cert_utils.parse_csr(
	certificate_signing_request
		 jazzhands.certificate_signing_request.certificate_signing_request%TYPE
) RETURNS jsonb AS $pgsql$
    my $csr_pem = shift || return undef;

    my $tmp = File::Temp->new();
    print $tmp $csr_pem;
    my $fname = $tmp->filename();

    my $req = Crypt::OpenSSL::PKCS10->new_from_file($fname) || return undef;
    $tmp->close;

    my $friendly = $req->subject;
    $friendly =~ s/^.*CN=(\s*[^,]*)(,.*)?$/$1/;

    my $rv = {
        friendly_name => $friendly,
        subject       => $req->subject(),
    };

    # this is naaaasty but I did not want to require the JSON pp module
    my $x = sprintf "{ %s }", join(
        ',',
        map {
            qq{"$_": }
              . (
                ( defined( $rv->{$_} ) )
                ? (
                    ( ref( $rv->{$_} ) eq 'ARRAY' )
                    ? '[ ' . join( ',', @{ $rv->{$_} } ) . ' ]'
                    : qq{"$rv->{$_}"}
                  )
                : 'null'
              )
        } keys %$rv
    );

    $x;
$pgsql$ LANGUAGE plperl;

-------------------------------------------------------------------------------


REVOKE ALL ON SCHEMA x509_plperl_cert_utils  FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA x509_plperl_cert_utils FROM public;

GRANT USAGE ON SCHEMA x509_plperl_cert_utils TO iud_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA x509_plperl_cert_utils TO ro_role;
