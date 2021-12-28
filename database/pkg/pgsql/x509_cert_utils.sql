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

DO $$
BEGIN
	CREATE SCHEMA x509_cert_utils AUTHORIZATION jazzhands;
	REVOKE ALL ON SCHEMA x509_cert_utils FROM public;
	COMMENT ON SCHEMA x509_cert_utils IS 'part of jazzhands';
EXCEPTION
	WHEN duplicate_schema THEN NULL;
END $$;

-------------------------------------------------------------------------------
--
-- Return certificate fingerprints as a JSONB object suitable to be passed
-- to the function x509_hash_manip.set_x509_signed_certificate_fingerprints
--
-------------------------------------------------------------------------------

DO $_$ BEGIN
CREATE OR REPLACE FUNCTION x509_cert_utils.get_public_key_fingerprints(
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
EXCEPTION WHEN undefined_object THEN RAISE NOTICE
	'PL/Perl absent: Function get_public_key_fingerprints() not created';
END $_$;

REVOKE ALL ON SCHEMA x509_cert_utils  FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA x509_cert_utils FROM public;

GRANT USAGE ON SCHEMA x509_cert_utils TO iud_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA x509_cert_utils TO ro_role;
