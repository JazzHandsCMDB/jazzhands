--
-- Copyright (c) 2022 Todd Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.


\pset pager
/*
Invoked:

	--suffix=v94
	--scan
	--pre
	pre
	--post
	post
	jazzhands_legacy.x509_certificate_upd
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance(false);
select clock_timestamp(), now(), clock_timestamp() - now() AS len;


-- BEGIN Misc that does not apply to above
DO $$
BEGIN
        CREATE EXTENSION IF NOT EXISTS plperl;
EXCEPTION WHEN undefined_file THEN
        RAISE NOTICE 'Failed to create EXTENSION for pl/perl, proceeding because this is optional (%)', SQLERRM;
WHEN duplicate_schema THEN
        NULL;
END;
$$;


-- END Misc that does not apply to above
--
-- BEGIN: process_ancillary_schema(schema_support)
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_schema_support']);
-- DONE: process_ancillary_schema(schema_support)
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	_tal := 0;
	SELECT count(*) INTO _tal FROM pg_extension WHERE extname = 'plperl';

	-- certain schemas are optional and the first conditional
	-- is true if the schem is optional.
	IF false OR _tal = 1 THEN
		CREATE SCHEMA x509_plperl_cert_utils AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA x509_plperl_cert_utils IS 'part of jazzhands';
	END IF;
END;
			$$;--
-- Process middle (non-trigger) schema jazzhands_cache
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_cache']);
--
-- Process middle (non-trigger) schema account_collection_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_account_collection_manip']);
--
-- Process middle (non-trigger) schema account_password_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_account_password_manip']);
--
-- Process middle (non-trigger) schema approval_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_approval_utils']);
--
-- Process middle (non-trigger) schema audit
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_audit']);
--
-- Process middle (non-trigger) schema auto_ac_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_auto_ac_manip']);
--
-- Process middle (non-trigger) schema backend_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_backend_utils']);
--
-- Process middle (non-trigger) schema company_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_company_manip']);
--
-- Process middle (non-trigger) schema component_connection_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_connection_utils']);
--
-- Process middle (non-trigger) schema component_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_manip']);
--
-- Process middle (non-trigger) schema component_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_utils']);
--
-- Process middle (non-trigger) schema device_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_device_manip']);
--
-- Process middle (non-trigger) schema device_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_device_utils']);
--
-- Process middle (non-trigger) schema dns_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_dns_manip']);
--
-- Process middle (non-trigger) schema dns_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_dns_utils']);
--
-- Process middle (non-trigger) schema jazzhands
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands']);
--
-- Process middle (non-trigger) schema layerx_network_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_layerx_network_manip']);
--
-- Process middle (non-trigger) schema logical_port_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_logical_port_manip']);
--
-- Process middle (non-trigger) schema lv_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_lv_manip']);
--
-- Process middle (non-trigger) schema net_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_net_manip']);
--
-- Process middle (non-trigger) schema netblock_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_netblock_manip']);
--
-- Process middle (non-trigger) schema netblock_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_netblock_utils']);
--
-- Process middle (non-trigger) schema network_strings
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_network_strings']);
--
-- Process middle (non-trigger) schema obfuscation_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_obfuscation_utils']);
--
-- Process middle (non-trigger) schema person_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_person_manip']);
--
-- Process middle (non-trigger) schema pgcrypto
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_pgcrypto']);
--
-- Process middle (non-trigger) schema physical_address_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_physical_address_utils']);
--
-- Process middle (non-trigger) schema port_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_port_utils']);
--
-- Process middle (non-trigger) schema property_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_property_utils']);
--
-- Process middle (non-trigger) schema rack_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_rack_utils']);
--
-- Process middle (non-trigger) schema schema_support
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_schema_support']);
--
-- Process middle (non-trigger) schema script_hooks
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_script_hooks']);
--
-- Process middle (non-trigger) schema service_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_service_manip']);
--
-- Process middle (non-trigger) schema service_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_service_utils']);
--
-- Process middle (non-trigger) schema snapshot_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_snapshot_manip']);
--
-- Process middle (non-trigger) schema time_util
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_time_util']);
--
-- Process middle (non-trigger) schema token_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_token_utils']);
--
-- Process middle (non-trigger) schema versioning_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_versioning_utils']);
--
-- Process middle (non-trigger) schema x509_hash_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_x509_hash_manip']);
--
-- Process middle (non-trigger) schema jazzhands_legacy
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy']);
--
-- Process middle (non-trigger) schema x509_plperl_cert_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_x509_plperl_cert_utils']);
-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('x509_plperl_cert_utils', 'get_csr_hashes');
DROP FUNCTION IF EXISTS x509_plperl_cert_utils.get_csr_hashes ( text );
DO $plperlthing$ BEGIN
CREATE OR REPLACE FUNCTION x509_plperl_cert_utils.get_csr_hashes(text)
 RETURNS jsonb
 LANGUAGE plperl
AS $function$
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
$function$
;

EXCEPTION WHEN invalid_schema_name THEN NULL; END; $plperlthing$
;
-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('x509_plperl_cert_utils', 'get_public_key_fingerprints');
DROP FUNCTION IF EXISTS x509_plperl_cert_utils.get_public_key_fingerprints ( text );
DO $plperlthing$ BEGIN
CREATE OR REPLACE FUNCTION x509_plperl_cert_utils.get_public_key_fingerprints(text)
 RETURNS jsonb
 LANGUAGE plperl
AS $function$
	my $x509   = Crypt::OpenSSL::X509->new_from_string(shift);
	my $sha1   = lc($x509->fingerprint_sha1());
	my $sha256 = lc($x509->fingerprint_sha256());

	$sha1	=~ s/://g;
	$sha256 =~ s/://g;

	my $json1   = sprintf('{"algorithm":"sha1",  "hash":"%s"}', $sha1);
	my $json256 = sprintf('{"algorithm":"sha256","hash":"%s"}', $sha256);
	return sprintf('[%s,%s]', $json1, $json256);
$function$
;

EXCEPTION WHEN invalid_schema_name THEN NULL; END; $plperlthing$
;
-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('x509_plperl_cert_utils', 'get_public_key_hashes');
DROP FUNCTION IF EXISTS x509_plperl_cert_utils.get_public_key_hashes ( text );
DO $plperlthing$ BEGIN
CREATE OR REPLACE FUNCTION x509_plperl_cert_utils.get_public_key_hashes(text)
 RETURNS jsonb
 LANGUAGE plperl
AS $function$
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
$function$
;

EXCEPTION WHEN invalid_schema_name THEN NULL; END; $plperlthing$
;
-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('x509_plperl_cert_utils', 'get_public_key_ski');
DROP FUNCTION IF EXISTS x509_plperl_cert_utils.get_public_key_ski ( text );
DO $plperlthing$ BEGIN
CREATE OR REPLACE FUNCTION x509_plperl_cert_utils.get_public_key_ski(text)
 RETURNS character varying
 LANGUAGE plperl
AS $function$
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
$function$
;

EXCEPTION WHEN invalid_schema_name THEN NULL; END; $plperlthing$
;
-- Processing tables in main schema...
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_service_source_repository_uri
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_service_source_repository_uri', 'v_service_source_repository_uri');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_service_source_repository_uri', tags := ARRAY['view_v_service_source_repository_uri']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands.v_service_source_repository_uri;
CREATE VIEW jazzhands.v_service_source_repository_uri AS
 SELECT service_source_repository.service_id,
    service_source_repository.is_enabled,
    service_source_repository.is_primary,
    service_source_repository.service_source_repository_id,
    source_repository.source_repository_provider_id,
    source_repository.source_repository_project_id,
    source_repository_project.source_repository_project_name,
    service_source_repository.source_repository_id,
    source_repository.source_repository_name,
    source_repository_provider_uri_template.source_repository_protocol,
    source_repository_provider_uri_template.source_repository_uri_purpose,
    service_source_repository.service_source_control_purpose,
    service_utils.build_software_repository_uri(template => concat_ws('/'::text, regexp_replace(source_repository_provider_uri_template.source_repository_uri::text, '/$'::text, ''::text), regexp_replace(concat_ws('/'::text, source_repository_provider_uri_template.source_repository_template_path_fragment, source_repository.source_repository_path_fragment, service_source_repository.service_source_repository_path_fragment), '//'::text, '/'::text, 'g'::text)), project_name => source_repository_project.source_repository_project_name::text, repository_name => source_repository.source_repository_name::text) AS source_repository_uri
   FROM jazzhands.service_source_repository
     JOIN jazzhands.source_repository USING (source_repository_id)
     JOIN jazzhands.source_repository_project USING (source_repository_provider_id, source_repository_project_id)
     JOIN jazzhands.source_repository_provider_uri_template USING (source_repository_provider_id);

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object IN ('v_service_source_repository_uri','v_service_source_repository_uri');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_service_source_repository_uri failed but that is ok';
	NULL;
END;
$$;

-- just in case
SELECT schema_support.prepare_for_object_replay();

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('v_service_source_repository_uri');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_service_source_repository_uri  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_service_source_repository_uri (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_service_source_repository_uri');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old v_service_source_repository_uri failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_service_source_repository_uri');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new v_service_source_repository_uri failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
--
-- Process all procs in jazzhands_cache
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_cache']);
--
-- Process all procs in account_collection_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_account_collection_manip']);
--
-- Process all procs in account_password_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_account_password_manip']);
--
-- Process all procs in approval_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_approval_utils']);
--
-- Process all procs in audit
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_audit']);
--
-- Process all procs in auto_ac_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_auto_ac_manip']);
--
-- Process all procs in backend_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_backend_utils']);
--
-- Process all procs in company_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_company_manip']);
--
-- Process all procs in component_connection_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_connection_utils']);
--
-- Process all procs in component_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_manip']);
--
-- Process all procs in component_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_utils']);
--
-- Process all procs in device_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_device_manip']);
--
-- Process all procs in device_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_device_utils']);
--
-- Process all procs in dns_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_dns_manip']);
--
-- Process all procs in dns_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_dns_utils']);
--
-- Process all procs in jazzhands
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands']);
-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION jazzhands.delete_dangling_public_key_hashes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	DELETE FROM public_key_hash_hash
	WHERE public_key_hash_id NOT IN (
		SELECT public_key_hash_id
		FROM x509_signed_certificate
		WHERE public_key_hash_id IS NOT NULL
	) AND public_key_hash_id NOT IN (
		SELECT public_key_hash_id
		FROM private_key
		WHERE public_key_hash_id IS NOT NULL
	) AND public_key_hash_id NOT IN (
		SELECT public_key_hash_id
		FROM certificate_signing_request
		WHERE public_key_hash_id IS NOT NULL
	);

	DELETE FROM public_key_hash
	WHERE public_key_hash_id NOT IN (
		SELECT public_key_hash_id
		FROM x509_signed_certificate
		WHERE public_key_hash_id IS NOT NULL
	) AND public_key_hash_id NOT IN (
		SELECT public_key_hash_id
		FROM private_key
		WHERE public_key_hash_id IS NOT NULL
	) AND public_key_hash_id NOT IN (
		SELECT public_key_hash_id
		FROM certificate_signing_request
		WHERE public_key_hash_id IS NOT NULL
	);

	RETURN NULL;
END;
$function$
;

-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION jazzhands.set_csr_hashes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_hashes JSONB;
	_pkhid jazzhands.certificate_signing_request.public_key_hash_id%TYPE;
BEGIN
	BEGIN
		_hashes := x509_plperl_cert_utils.get_csr_hashes(NEW.certificate_signing_request);
		_pkhid := x509_hash_manip.get_or_create_public_key_hash_id(_hashes);
		IF NEW.public_key_hash_id IS NOT NULL THEN
			IF NEW.public_key_hash_id IS DISTINCT FROM _pkhid THEN
				RAISE EXCEPTION 'public_key_hash_id does not match certificate_signing_request'
				USING ERRCODE = 'data_exception';
			END IF;
		ELSE
			NEW.public_key_hash_id := _pkhid;
		END IF;
	EXCEPTION
		WHEN undefined_function OR invalid_schema_name THEN NULL;
	END;
	RETURN NEW;
END;
$function$
;

-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION jazzhands.set_x509_certificate_fingerprints()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_fingerprints JSONB;
	_cnt INTEGER;
BEGIN
	BEGIN
		IF NEW.public_key IS NOT NULL THEN
			_fingerprints := x509_plperl_cert_utils.get_public_key_fingerprints(NEW.public_key);
			_cnt := x509_hash_manip.set_x509_signed_certificate_fingerprints(NEW.x509_signed_certificate_id, _fingerprints);
		END IF;
	EXCEPTION
		WHEN undefined_function OR invalid_schema_name THEN NULL;
	END;
	RETURN NEW;
END;
$function$
;

-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION jazzhands.set_x509_certificate_ski_and_hashes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_hashes JSONB;
	_pkhid jazzhands.public_key_hash.public_key_hash_id%TYPE;
	_ski jazzhands.x509_signed_certificate.subject_key_identifier%TYPE;
BEGIN
	BEGIN
		IF NEW.public_key IS NOT NULL THEN
			_hashes := x509_plperl_cert_utils.get_public_key_hashes(NEW.public_key);
			_pkhid := x509_hash_manip.get_or_create_public_key_hash_id(_hashes);
			_ski := x509_plperl_cert_utils.get_public_key_ski(NEW.public_key);

			IF NEW.public_key_hash_id IS NOT NULL THEN
				IF NEW.public_key_hash_id IS DISTINCT FROM _pkhid THEN
					RAISE EXCEPTION 'public_key_hash_id does not match public_key'
					USING ERRCODE = 'data_exception';
				END IF;
			ELSE
				NEW.public_key_hash_id := _pkhid;
			END IF;

			IF NEW.subject_key_identifier IS NOT NULL THEN
				IF NEW.subject_key_identifier IS DISTINCT FROM _ski THEN
					RAISE EXCEPTION 'subject_key_identifier does not match public_key'
					USING ERRCODE = 'data_exception';
				END IF;
			ELSE
				NEW.subject_key_identifier := _ski;
			END IF;
		END IF;
	EXCEPTION
		WHEN undefined_function OR invalid_schema_name THEN NULL;
	END;
	RETURN NEW;
END;
$function$
;

--
-- Process all procs in layerx_network_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_layerx_network_manip']);
--
-- Process all procs in logical_port_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_logical_port_manip']);
--
-- Process all procs in lv_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_lv_manip']);
--
-- Process all procs in net_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_net_manip']);
--
-- Process all procs in netblock_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_netblock_manip']);
--
-- Process all procs in netblock_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_netblock_utils']);
--
-- Process all procs in network_strings
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_network_strings']);
--
-- Process all procs in obfuscation_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_obfuscation_utils']);
--
-- Process all procs in person_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_person_manip']);
--
-- Process all procs in pgcrypto
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_pgcrypto']);
--
-- Process all procs in physical_address_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_physical_address_utils']);
--
-- Process all procs in port_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_port_utils']);
--
-- Process all procs in property_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_property_utils']);
--
-- Process all procs in rack_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_rack_utils']);
--
-- Process all procs in schema_support
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_schema_support']);
--
-- Process all procs in script_hooks
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_script_hooks']);
--
-- Process all procs in service_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_service_manip']);
--
-- Process all procs in service_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_service_utils']);
--
-- Process all procs in snapshot_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_snapshot_manip']);
--
-- Process all procs in time_util
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_time_util']);
--
-- Process all procs in token_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_token_utils']);
--
-- Process all procs in versioning_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_versioning_utils']);
--
-- Process all procs in x509_hash_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_x509_hash_manip']);
--
-- Process all procs in x509_plperl_cert_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_x509_plperl_cert_utils']);
--
-- Recreate the saved views in the base schema
--
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', type := 'view');


-- BEGIN Misc that does not apply to above
SELECT schema_support.set_schema_version(
        version := '0.94',
        schema := 'jazzhands'
);


-- END Misc that does not apply to above
--
-- BEGIN: process_ancillary_schema(jazzhands_legacy)
--

--------------------------------------------------------------------
-- DEALING WITH proc jazzhands_legacy.x509_certificate_upd -> x509_certificate_upd

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'x509_certificate_upd', 'x509_certificate_upd');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
DROP TRIGGER IF EXISTS trigger_x509_certificate_upd ON jazzhands_legacy.x509_certificate;
-- consider old oid 15569399
DROP TRIGGER IF EXISTS trigger_x509_certificate_upd ON jazzhands_legacy.x509_certificate;
DROP FUNCTION IF EXISTS jazzhands_legacy.x509_certificate_upd();

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- considering NEW jazzhands_legacy.x509_certificate_upd
CREATE OR REPLACE FUNCTION jazzhands_legacy.x509_certificate_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	crt	jazzhands.x509_signed_certificate%rowtype;
	key	jazzhands.private_key%rowtype;
	csr	jazzhands.certificate_signing_request%rowtype;
	_uq	text[];
BEGIN
	SELECT * INTO crt FROM jazzhands.x509_signed_certificate
        WHERE x509_signed_certificate_id = OLD.x509_cert_id;

	IF crt.private_key_ID IS NULL AND NEW.private_key IS NOT NULL THEN
		INSERT INTO private_key (
			private_key_encryption_type,
			is_active,
			subject_key_identifier,
			private_key,
			passphrase,
			encryption_key_id
		) VALUES (
			'rsa',
			NEW.is_active,
			NEW.subject_key_identifier,
			NEW.private_key,
			NEW.passphrase,
			NEW.encryption_key_id
		) RETURNING * INTO key;
	ELSE IF crt.private_key_id IS NOT NULL THEN
		SELECT * INTO key FROM jazzhands.private_key k
			WHERE k.private_key_id =  crt.private_key_id;

		-- delete happens at the end, after update
		IF NEW.private_key IS NOT NULL THEN
			IF OLD.subject_key_identifier IS DISTINCT FROM NEW.subject_key_identifier THEN
				_uq := array_append(_uq,
					'subject_key_identifier = ' || quote_nullable(NEW.subject_key_identifier)
				);
			END IF;
			IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
				IF NEW.is_active = 'Y' THEN
					_uq := array_append(_uq, 'is_active = true');
				ELSIF NEW.is_active = 'N' THEN
					_uq := array_append(_uq, 'is_active = false');
				ELSE
					_uq := array_append(_uq, 'is_active = NULL');
				END IF;
			END IF;
			IF OLD.private_key IS DISTINCT FROM NEW.private_key THEN
				_uq := array_append(_uq,
					'private_key = ' || quote_nullable(NEW.private_key)
				);
			END IF;
			IF OLD.passphrase IS DISTINCT FROM NEW.passphrase THEN
				_uq := array_append(_uq,
					'passphrase = ' || quote_nullable(NEW.passphrase)
				);
			END IF;
			IF OLD.encryption_key_id IS DISTINCT FROM NEW.encryption_key_id THEN
				_uq := array_append(_uq,
					'encryption_key_id = ' || quote_nullable(NEW.encryption_key_id)
				);
			END IF;
			IF OLD.public_key_hash_id IS DISTINCT FROM NEW.public_key_hash_id THEN
				_uq := array_append(_uq,
					'public_key_hash_id = ' || quote_nullable(NEW.public_key_hash_id)
				);
			END IF;

			IF array_length(_uq, 1) > 0 THEN
				EXECUTE format('UPDATE private_key SET %s WHERE private_key_id = $1 RETURNING *',
					array_to_string(_uq, ', '))
					USING crt.private_key_id
					INTO key;
			END IF;
		END IF;

		NEW.private_key 		= key.private_key;
		NEW.is_active 			= CASE WHEN key.is_active THEN 'Y' ELSE 'N' END;
		NEW.passphrase 			= key.passphrase;
		NEW.encryption_key_id	= key.encryption_key_id;
	END IF;

	-- private_key pieces are now what it is supposed to be.
	_uq := NULL;

	IF crt.certificate_signing_request_id IS NULL AND NEW.certificate_sign_req IS NOT NULL THEN
		INSERT INTO jazzhands.certificate_signing_request (
			friendly_name,
			subject,
			certificate_signing_request,
			private_key_id,
			public_key_hash_id
		) VALUES (
			NEW.friendly_name,
			NEW.subject,
			NEW.certificate_sign_req,
			key.private_key_id,
			NEW.public_key_hash_id
		) RETURNING * INTO csr;
	ELSIF crt.certificate_signing_request_id IS NOT NULL THEN
		SELECT * INTO csr FROM jazzhands.certificate_signing_request c
			WHERE c.certificate_signing_request_id =  crt.certificate_signing_request_id;

		-- delete happens at the end, after update
		IF NEW.certificate_sign_req IS NOT NULL THEN
			IF OLD.certificate_sign_req IS DISTINCT FROM NEW.certificate_sign_req THEN
				_uq := array_append(_uq,
					'certificate_signing_request = ' || quote_nullable(NEW.certificate_sign_req)
				);
			END IF;
			IF OLD.subject IS DISTINCT FROM NEW.subject THEN
				_uq := array_append(_uq,
					'subject = ' || quote_nullable(NEW.subject)
				);
			END IF;
			IF OLD.friendly_name IS DISTINCT FROM NEW.friendly_name THEN
				_uq := array_append(_uq,
					'friendly_name = ' || quote_nullable(NEW.friendly_name)
				);
			END IF;
			IF OLD.public_key_hash_id IS DISTINCT FROM key.public_key_hash_id THEN
				_uq := array_append(_uq,
					'public_key_hash_id = ' || quote_nullable(NEW.public_key_hash_id)
				);
			END IF;

			IF array_length(_uq, 1) > 0 THEN
				EXECUTE format('UPDATE certificate_signing_request SET %s WHERE certificate_signing_request_id = $1 RETURNING *',
					array_to_string(_uq, ', '))
					USING crt.certificate_signing_request_id
					INTO csr;
			END IF;
		END IF;

		NEW.certificate_sign_req 	= csr.certificate_signing_request;
	END IF;

	-- csr and private_key pieces are now what it is supposed to be.
	_uq := NULL;

	IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
		IF NEW.is_active = 'Y' THEN
			_uq := array_append(_uq, 'is_active = true');
		ELSIF NEW.is_active = 'N' THEN
			_uq := array_append(_uq, 'is_active = false');
		ELSE
			_uq := array_append(_uq, 'is_active = NULL');
		END IF;
	END IF;

	END IF;
	IF OLD.friendly_name IS DISTINCT FROM NEW.friendly_name THEN
		_uq := array_append(_uq,
			'friendly_name = ' || quote_literal(NEW.friendly_name)
		);
	END IF;
	IF OLD.subject IS DISTINCT FROM NEW.subject THEN
		_uq := array_append(_uq,
			'subject = ' || quote_literal(NEW.subject)
		);
	END IF;
	IF OLD.subject_key_identifier IS DISTINCT FROM NEW.subject_key_identifier THEN
		_uq := array_append(_uq,
			'subject_key_identifier = ' || quote_nullable(NEW.subject_key_identifier)
		);
	END IF;
	IF OLD.public_key_hash_id IS DISTINCT FROM NEW.public_key_hash_id THEN
		_uq := array_append(_uq,
			'public_key_hash_id = ' || quote_nullable(NEW.public_key_hash_id)
		);
	END IF;
	IF OLD.description IS DISTINCT FROM NEW.description THEN
		_uq := array_append(_uq,
			'description = ' || quote_nullable(NEW.description)
		);
	END IF;

	IF OLD.is_certificate_authority IS DISTINCT FROM NEW.is_certificate_authority THEN
		IF NEW.is_certificate_authority = 'Y' THEN
			_uq := array_append(_uq, 'is_certificate_authority = true');
		ELSIF NEW.is_certificate_authority = 'N' THEN
			_uq := array_append(_uq, 'is_certificate_authority = false');
		ELSE
			_uq := array_append(_uq, 'is_certificate_authority = NULL');
		END IF;
	END IF;

	IF OLD.signing_cert_id IS DISTINCT FROM NEW.signing_cert_id THEN
		_uq := array_append(_uq,
			'signing_cert_id = ' || quote_nullable(NEW.signing_cert_id)
		);
	END IF;
	IF OLD.x509_ca_cert_serial_number IS DISTINCT FROM NEW.x509_ca_cert_serial_number THEN
		_uq := array_append(_uq,
			'x509_ca_cert_serial_number = ' || quote_nullable(NEW.x509_ca_cert_serial_number)
		);
	END IF;
	IF OLD.public_key IS DISTINCT FROM NEW.public_key THEN
		_uq := array_append(_uq,
			'public_key = ' || quote_nullable(NEW.public_key)
		);
	END IF;
	IF OLD.valid_from IS DISTINCT FROM NEW.valid_from THEN
		_uq := array_append(_uq,
			'valid_from = ' || quote_nullable(NEW.valid_from)
		);
	END IF;
	IF OLD.valid_to IS DISTINCT FROM NEW.valid_to THEN
		_uq := array_append(_uq,
			'valid_to = ' || quote_nullable(NEW.valid_to)
		);
	END IF;
	IF OLD.x509_revocation_date IS DISTINCT FROM NEW.x509_revocation_date THEN
		_uq := array_append(_uq,
			'x509_revocation_date = ' || quote_nullable(NEW.x509_revocation_date)
		);
	END IF;
	IF OLD.x509_revocation_reason IS DISTINCT FROM NEW.x509_revocation_reason THEN
		_uq := array_append(_uq,
			'x509_revocation_reason = ' || quote_nullable(NEW.x509_revocation_reason)
		);
	END IF;
	IF OLD.ocsp_uri IS DISTINCT FROM NEW.ocsp_uri THEN
		_uq := array_append(_uq,
			'ocsp_uri = ' || quote_nullable(NEW.ocsp_uri)
		);
	END IF;
	IF OLD.crl_uri IS DISTINCT FROM NEW.crl_uri THEN
		_uq := array_append(_uq,
			'crl_uri = ' || quote_nullable(NEW.crl_uri)
		);
	END IF;

	IF array_length(_uq, 1) > 0 THEN
		EXECUTE 'UPDATE x509_signed_certificate SET '
			|| array_to_string(_uq, ', ')
			|| ' WHERE x509_signed_certificate_id = '
			|| NEW.x509_cert_id;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.x509_signed_certificate SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  x509_signed_certificate_id = $1 RETURNING *'  USING OLD.x509_cert_id
			INTO crt;

		NEW.x509_cert_id = crt.x509_signed_certificate_id;
		NEW.friendly_name = crt.friendly_name;
		NEW.is_active = CASE WHEN crt.is_active = true THEN 'Y' WHEN crt.is_active = false THEN 'N' ELSE NULL END;
		NEW.is_certificate_authority = CASE WHEN crt.is_certificate_authority = true THEN 'Y' WHEN crt.is_certificate_authority = false THEN 'N' ELSE NULL END;
		NEW.signing_cert_id = crt.signing_cert_id;
		NEW.x509_ca_cert_serial_number = crt.x509_ca_cert_serial_number;
		NEW.public_key = crt.public_key;
		NEW.subject = crt.subject;
		NEW.subject_key_identifier = crt.subject_key_identifier;
		NEW.public_key_hash_id = crt.public_key_hash_id;
		NEW.description = crt.description;
		NEW.valid_from = crt.valid_from;
		NEW.valid_to = crt.valid_to;
		NEW.x509_revocation_date = crt.x509_revocation_date;
		NEW.x509_revocation_reason = crt.x509_revocation_reason;
		NEW.ocsp_uri = crt.ocsp_uri;
		NEW.crl_uri = crt.crl_uri;
		NEW.data_ins_user = crt.data_ins_user;
		NEW.data_ins_date = crt.data_ins_date;
		NEW.data_upd_user = crt.data_upd_user;
		NEW.data_upd_date = crt.data_upd_date;
	END IF;

	IF OLD.certificate_sign_req IS NOT NULL AND NEW.certificate_sign_req IS NULL THEN
		DELETE FROM jazzhands.certificate_signing_request
		WHERE certificate_signing_request_id = crt.certificate_signing_request_id;
	END IF;

	IF OLD.private_key IS NOT NULL AND NEW.private_key IS NULL THEN
		DELETE FROM jazzhands.private_key
		WHERE private_key_id = crt.private_key_id;
	END IF;

	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands_legacy.x509_certificate_upd() FROM public;
-- triggers on this function (if applicable)
DROP TRIGGER IF EXISTS trigger_x509_certificate_upd ON jazzhands_legacy.x509_certificate;
CREATE TRIGGER trigger_x509_certificate_upd INSTEAD OF UPDATE ON jazzhands_legacy.x509_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands_legacy.x509_certificate_upd();

-- DONE WITH proc jazzhands_legacy.x509_certificate_upd -> x509_certificate_upd
--------------------------------------------------------------------

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy']);
-- DONE: process_ancillary_schema(jazzhands_legacy)
--
-- BEGIN: Fix cache table entries.
--
-- removing old
-- adding new cache tables that are not there
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled
	) SELECT 'jazzhands_cache' , 'ct_netblock_hier' , 'jazzhands_cache' , 'v_netblock_hier' , '1'  WHERE ('jazzhands_cache' , 'ct_netblock_hier' , 'jazzhands_cache' , 'v_netblock_hier' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled
	) SELECT 'jazzhands_cache' , 'ct_device_components' , 'jazzhands_cache' , 'v_device_components' , '1'  WHERE ('jazzhands_cache' , 'ct_device_components' , 'jazzhands_cache' , 'v_device_components' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled
	) SELECT 'jazzhands_cache' , 'ct_netblock_hier' , 'jazzhands_cache' , 'v_netblock_hier' , '1'  WHERE ('jazzhands_cache' , 'ct_netblock_hier' , 'jazzhands_cache' , 'v_netblock_hier' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled
	) SELECT 'jazzhands_cache' , 'ct_account_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_account_collection_hier_from_ancestor' , '1'  WHERE ('jazzhands_cache' , 'ct_account_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_account_collection_hier_from_ancestor' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled
	) SELECT 'jazzhands_cache' , 'ct_device_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_device_collection_hier_from_ancestor' , '1'  WHERE ('jazzhands_cache' , 'ct_device_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_device_collection_hier_from_ancestor' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled
	) SELECT 'jazzhands_cache' , 'ct_netblock_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_netblock_collection_hier_from_ancestor' , '1'  WHERE ('jazzhands_cache' , 'ct_netblock_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_netblock_collection_hier_from_ancestor' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled
	) SELECT 'jazzhands_cache' , 'ct_jazzhands_legacy_device_support' , 'jazzhands_cache' , 'v_jazzhands_legacy_device_support' , '1'  WHERE ('jazzhands_cache' , 'ct_jazzhands_legacy_device_support' , 'jazzhands_cache' , 'v_jazzhands_legacy_device_support' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
--
-- DONE: Fix cache table entries.
--


-- Clean Up
-- Dropping obsoleted sequences....


-- Dropping obsoleted jazzhands_audit sequences....


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
-- index
-- triggers
DROP TRIGGER IF EXISTS trig_userlog_account_assigned_certificate ON account_assigned_certificate;
CREATE TRIGGER trig_userlog_account_assigned_certificate BEFORE INSERT OR UPDATE ON jazzhands.account_assigned_certificate FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trig_userlog_certificate_signing_request ON certificate_signing_request;
CREATE TRIGGER trig_userlog_certificate_signing_request BEFORE INSERT OR UPDATE ON jazzhands.certificate_signing_request FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_csr_set_hashes ON certificate_signing_request;
CREATE TRIGGER trigger_csr_set_hashes BEFORE INSERT OR UPDATE OF certificate_signing_request, public_key_hash_id ON jazzhands.certificate_signing_request FOR EACH ROW EXECUTE FUNCTION jazzhands.set_csr_hashes();
DROP TRIGGER IF EXISTS trigger_x509_signed_pkh_csr_validate ON certificate_signing_request;
CREATE CONSTRAINT TRIGGER trigger_x509_signed_pkh_csr_validate AFTER INSERT OR UPDATE OF public_key_hash_id, private_key_id, certificate_signing_request_id ON jazzhands.certificate_signing_request NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.x509_signed_pkh_csr_validate();
DROP TRIGGER IF EXISTS trig_userlog_device_collection_assigned_certificate ON device_collection_assigned_certificate;
CREATE TRIGGER trig_userlog_device_collection_assigned_certificate BEFORE INSERT OR UPDATE ON jazzhands.device_collection_assigned_certificate FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trig_userlog_private_key ON private_key;
CREATE TRIGGER trig_userlog_private_key BEFORE INSERT OR UPDATE ON jazzhands.private_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_private_key_delete_dangling_hashes ON private_key;
CREATE TRIGGER trigger_private_key_delete_dangling_hashes AFTER DELETE OR UPDATE OF public_key_hash_id ON jazzhands.private_key FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.delete_dangling_public_key_hashes();
DROP TRIGGER IF EXISTS trigger_pvtkey_pkh_signed_validate ON private_key;
CREATE CONSTRAINT TRIGGER trigger_pvtkey_pkh_signed_validate AFTER UPDATE OF public_key_hash_id, private_key_id ON jazzhands.private_key NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.pvtkey_pkh_signed_validate();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_x509_certificate ON service_endpoint_x509_certificate;
CREATE TRIGGER trig_userlog_service_endpoint_x509_certificate BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_x509_certificate FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trig_userlog_val_private_key_encryption_type ON val_private_key_encryption_type;
CREATE TRIGGER trig_userlog_val_private_key_encryption_type BEFORE INSERT OR UPDATE ON jazzhands.val_private_key_encryption_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_certificate_file_format ON val_x509_certificate_file_format;
CREATE TRIGGER trig_userlog_val_x509_certificate_file_format BEFORE INSERT OR UPDATE ON jazzhands.val_x509_certificate_file_format FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_certificate_type ON val_x509_certificate_type;
CREATE TRIGGER trig_userlog_val_x509_certificate_type BEFORE INSERT OR UPDATE ON jazzhands.val_x509_certificate_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_fingerprint_hash_algorithm ON val_x509_fingerprint_hash_algorithm;
CREATE TRIGGER trig_userlog_val_x509_fingerprint_hash_algorithm BEFORE INSERT OR UPDATE ON jazzhands.val_x509_fingerprint_hash_algorithm FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_key_usage ON val_x509_key_usage;
CREATE TRIGGER trig_userlog_val_x509_key_usage BEFORE INSERT OR UPDATE ON jazzhands.val_x509_key_usage FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_key_usage_category ON val_x509_key_usage_category;
CREATE TRIGGER trig_userlog_val_x509_key_usage_category BEFORE INSERT OR UPDATE ON jazzhands.val_x509_key_usage_category FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_revocation_reason ON val_x509_revocation_reason;
CREATE TRIGGER trig_userlog_val_x509_revocation_reason BEFORE INSERT OR UPDATE ON jazzhands.val_x509_revocation_reason FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trig_userlog_x509_key_usage_attribute ON x509_key_usage_attribute;
CREATE TRIGGER trig_userlog_x509_key_usage_attribute BEFORE INSERT OR UPDATE ON jazzhands.x509_key_usage_attribute FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trig_userlog_x509_key_usage_categorization ON x509_key_usage_categorization;
CREATE TRIGGER trig_userlog_x509_key_usage_categorization BEFORE INSERT OR UPDATE ON jazzhands.x509_key_usage_categorization FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trig_userlog_x509_key_usage_default ON x509_key_usage_default;
CREATE TRIGGER trig_userlog_x509_key_usage_default BEFORE INSERT OR UPDATE ON jazzhands.x509_key_usage_default FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trig_userlog_x509_signed_certificate ON x509_signed_certificate;
CREATE TRIGGER trig_userlog_x509_signed_certificate BEFORE INSERT OR UPDATE ON jazzhands.x509_signed_certificate FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_x509_signed_delete_dangling_hashes ON x509_signed_certificate;
CREATE TRIGGER trigger_x509_signed_delete_dangling_hashes AFTER DELETE OR UPDATE OF public_key_hash_id ON jazzhands.x509_signed_certificate FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.delete_dangling_public_key_hashes();
DROP TRIGGER IF EXISTS trigger_x509_signed_pkh_pvtkey_validate ON x509_signed_certificate;
CREATE CONSTRAINT TRIGGER trigger_x509_signed_pkh_pvtkey_validate AFTER INSERT OR UPDATE OF public_key_hash_id, private_key_id, certificate_signing_request_id ON jazzhands.x509_signed_certificate NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.x509_signed_pkh_pvtkey_validate();
DROP TRIGGER IF EXISTS trigger_x509_signed_set_fingerprints ON x509_signed_certificate;
CREATE TRIGGER trigger_x509_signed_set_fingerprints AFTER INSERT OR UPDATE OF public_key ON jazzhands.x509_signed_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands.set_x509_certificate_fingerprints();
DROP TRIGGER IF EXISTS trigger_x509_signed_set_ski_and_hashes ON x509_signed_certificate;
CREATE TRIGGER trigger_x509_signed_set_ski_and_hashes BEFORE INSERT OR UPDATE OF public_key, public_key_hash_id, subject_key_identifier ON jazzhands.x509_signed_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands.set_x509_certificate_ski_and_hashes();
DROP TRIGGER IF EXISTS trig_userlog_x509_signed_certificate_fingerprint ON x509_signed_certificate_fingerprint;
CREATE TRIGGER trig_userlog_x509_signed_certificate_fingerprint BEFORE INSERT OR UPDATE ON jazzhands.x509_signed_certificate_fingerprint FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();

--
-- BEGIN: Procesing things saved for end
--
SAVEPOINT beforerecreate;

--
-- END: Procesing things saved for end
--

SELECT schema_support.replay_object_recreates(beverbose := true);
SELECT schema_support.replay_saved_grants(beverbose := true);

--
-- BEGIN: Running final cache table sync
-- SAVEPOINT beforecache;
-- SELECT schema_support.synchronize_cache_tables();

--
-- END: Running final cache table sync
-- SAVEPOINT beforereset;
-- SELECT schema_support.reset_all_schema_table_sequences('jazzhands');
-- SELECT schema_support.reset_all_schema_table_sequences('jazzhands_audit');
SAVEPOINT beforegrant;
GRANT select on all tables in schema jazzhands to ro_role;
GRANT insert,update,delete on all tables in schema jazzhands to iud_role;
GRANT insert,update,delete on all tables in schema jazzhands_legacy to iud_role;
GRANT select on all sequences in schema jazzhands to ro_role;
GRANT usage on all sequences in schema jazzhands to iud_role;
GRANT select on all tables in schema jazzhands_audit to ro_role;
GRANT select on all sequences in schema jazzhands_audit to ro_role;
GRANT select on all tables in schema jazzhands_audit to ro_role;
GRANT select on all sequences in schema jazzhands_audit to ro_role;
-- schema_support changes.  schema_owners needs to be documented somewhere
GRANT execute on all functions in schema schema_support to schema_owners;
REVOKE execute on all functions in schema schema_support from public;

SELECT schema_support.end_maintenance();
SAVEPOINT maintend;
select clock_timestamp(), now(), clock_timestamp() - now() AS len;
