-- Copyright (c) 2021, Bernard Jech
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
			AS $$ use MIME::Base64; return 1; $$ LANGUAGE plperl;
	EXCEPTION
		WHEN syntax_error THEN
			RAISE WARNING 'Perl module MIME::Base64 not found';
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
\q
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
-- to the function x509_hash_manip.set_x509_signed_certificate_fingerprints
--
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION x509_plperl_cert_utils.get_public_key_fingerprints(
	jazzhands.x509_signed_certificate.public_key%TYPE
) RETURNS jsonb AS $$
	my $x509   = Crypt::OpenSSL::X509->new_from_string(shift);
	my $sha1   = lc($x509->fingerprint_sha1());
	my $sha256 = lc($x509->fingerprint_sha256());

	$sha1   =~ s/://g;
	$sha256 =~ s/://g;

	my $json1   = sprintf('{"algorithm":"sha1",  "hash":"%s"}', $sha1);
	my $json256 = sprintf('{"algorithm":"sha256","hash":"%s"}', $sha256);
	return sprintf('[%s,%s]', $json1, $json256);
$$ LANGUAGE plperl;

-------------------------------------------------------------------------------
--
-- Return certificate hashes as a JSONB object suitable to be passed
-- to the function x509_hash_manip.set_x509_signed_certificate_hashes
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

REVOKE ALL ON SCHEMA x509_plperl_cert_utils  FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA x509_plperl_cert_utils FROM public;

GRANT USAGE ON SCHEMA x509_plperl_cert_utils TO iud_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA x509_plperl_cert_utils TO ro_role;
