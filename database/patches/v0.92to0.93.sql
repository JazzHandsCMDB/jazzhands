--
-- Copyright (c) 2021 Todd Kover
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

	--suffix=v93
	--scan
	--post
	post
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance(false);
select clock_timestamp(), now(), clock_timestamp() - now() AS len;
--
-- BEGIN: process_ancillary_schema(schema_support)
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_schema_support']);
-- DONE: process_ancillary_schema(schema_support)
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'x509_hash_manip';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS x509_hash_manip;
		CREATE SCHEMA x509_hash_manip AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA x509_hash_manip IS 'part of jazzhands';
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
DROP TRIGGER IF EXISTS trigger_pvtkey_ski_signed_validate ON jazzhands.private_key;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands'::text, object := 'pvtkey_ski_signed_validate (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands'::text]);
DROP FUNCTION IF EXISTS jazzhands.pvtkey_ski_signed_validate (  );
DROP TRIGGER IF EXISTS trigger_x509_signed_ski_pvtkey_validate ON jazzhands.x509_signed_certificate;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands'::text, object := 'x509_signed_ski_pvtkey_validate (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands'::text]);
DROP FUNCTION IF EXISTS jazzhands.x509_signed_ski_pvtkey_validate (  );
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
-- Process middle (non-trigger) schema jazzhands_legacy
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy']);
--
-- Process middle (non-trigger) schema x509_hash_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_x509_hash_manip']);
-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('x509_hash_manip', '_validate_parameter_hashes');
DROP FUNCTION IF EXISTS x509_hash_manip._validate_parameter_hashes ( jsonb );
CREATE OR REPLACE FUNCTION x509_hash_manip._validate_parameter_hashes(hashes jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_res BOOLEAN;
BEGIN
	_res := validate_json_schema(
		$json$ {
			"type": "array",
			"items": {
				"type": "object",
				"properties": {
					"algorithm": { "type": "string" },
					"hash":	     { "type": "string" }
				}
			}
		} $json$::jsonb, hashes
	);

	RETURN _res;
END;
$function$
;

-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('x509_hash_manip', 'get_or_create_public_key_hash_id');
DROP FUNCTION IF EXISTS x509_hash_manip.get_or_create_public_key_hash_id ( jsonb );
CREATE OR REPLACE FUNCTION x509_hash_manip.get_or_create_public_key_hash_id(hashes jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_cnt BIGINT;
	_pkhid jazzhands.public_key_hash.public_key_hash_id%TYPE;
BEGIN
	IF NOT x509_hash_manip._validate_parameter_hashes(hashes) THEN
		RAISE EXCEPTION 'parameter "hashes" does not match JSON schema'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	WITH x AS (
		SELECT algorithm, hash
		FROM jsonb_to_recordset(hashes)
		AS jr(algorithm text, hash text)
	) SELECT count(DISTINCT pkhh.public_key_hash_id),
		min(pkhh.public_key_hash_id)
	INTO _cnt, _pkhid
	FROM jazzhands.public_key_hash_hash pkhh JOIN x
	ON  x.algorithm = pkhh.x509_fingerprint_hash_algorighm
	AND x.hash = pkhh.calculated_hash;

	IF _cnt = 0 THEN
		INSERT INTO jazzhands.public_key_hash(description) VALUES(NULL)
		RETURNING public_key_hash_id INTO _pkhid;
	ELSIF _cnt > 1 THEN
		RAISE EXCEPTION 'multiple public_key_hash_id values found'
		USING ERRCODE = 'data_exception';
	END IF;

	WITH x AS (
		SELECT algorithm, hash
		FROM jsonb_to_recordset(hashes)
		AS jr(algorithm text, hash text)
	) INSERT INTO jazzhands.public_key_hash_hash AS pkhh (
		public_key_hash_id,
		x509_fingerprint_hash_algorighm, calculated_hash
	) SELECT _pkhid, x.algorithm, x.hash FROM x
	ON CONFLICT(public_key_hash_id, x509_fingerprint_hash_algorighm)
	DO UPDATE SET calculated_hash = EXCLUDED.calculated_hash
	WHERE pkhh.calculated_hash IS DISTINCT FROM EXCLUDED.calculated_hash;

RETURN _pkhid;
END;
$function$
;

-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('x509_hash_manip', 'set_private_key_hashes');
DROP FUNCTION IF EXISTS x509_hash_manip.set_private_key_hashes ( integer,jsonb );
CREATE OR REPLACE FUNCTION x509_hash_manip.set_private_key_hashes(private_key_id integer, hashes jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_pkhid jazzhands.public_key_hash_hash.public_key_hash_id%TYPE;
	_cnt INTEGER;
BEGIN
	_pkhid := x509_hash_manip.get_or_create_public_key_hash_id(hashes);

	UPDATE private_key p SET public_key_hash_id = _pkhid
	WHERE p.private_key_id = set_private_key_hashes.private_key_id
	AND public_key_hash_id IS DISTINCT FROM _pkhid;

	GET DIAGNOSTICS _cnt = ROW_COUNT;

	RETURN _cnt;
END;
$function$
;

-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('x509_hash_manip', 'set_x509_signed_certificate_fingerprints');
DROP FUNCTION IF EXISTS x509_hash_manip.set_x509_signed_certificate_fingerprints ( integer,jsonb );
CREATE OR REPLACE FUNCTION x509_hash_manip.set_x509_signed_certificate_fingerprints(x509_cert_id integer, fingerprints jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE _cnt INTEGER;
BEGIN
	IF NOT x509_hash_manip._validate_parameter_hashes(fingerprints) THEN
		RAISE EXCEPTION 'parameter "fingerprints" does not match JSON schema'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	WITH x AS (
		SELECT algorithm, hash
		FROM jsonb_to_recordset(fingerprints)
		AS jr(algorithm text, hash text)
	) INSERT INTO x509_signed_certificate_fingerprint AS fp (
		x509_signed_certificate_id,
		x509_fingerprint_hash_algorighm, fingerprint
	) SELECT x509_cert_id, x.algorithm, x.hash FROM x
	ON CONFLICT (
	    x509_signed_certificate_id, x509_fingerprint_hash_algorighm
	) DO UPDATE SET fingerprint = EXCLUDED.fingerprint
	WHERE fp.fingerprint IS DISTINCT FROM EXCLUDED.fingerprint;

	GET DIAGNOSTICS _cnt = ROW_COUNT;

	RETURN _cnt;
END;
$function$
;

-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('x509_hash_manip', 'set_x509_signed_certificate_hashes');
DROP FUNCTION IF EXISTS x509_hash_manip.set_x509_signed_certificate_hashes ( integer,jsonb,boolean );
CREATE OR REPLACE FUNCTION x509_hash_manip.set_x509_signed_certificate_hashes(x509_cert_id integer, hashes jsonb, update_private_key_hashes boolean DEFAULT false)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_pkid jazzhands.x509_signed_certificate.private_key_id%TYPE;
	_pkhid jazzhands.public_key_hash_hash.public_key_hash_id%TYPE;
	_cnt INTEGER;
BEGIN
	_pkhid := x509_hash_manip.get_or_create_public_key_hash_id(hashes);

	UPDATE x509_signed_certificate SET public_key_hash_id = _pkhid
	WHERE x509_signed_certificate_id = x509_cert_id
	AND public_key_hash_id IS DISTINCT FROM _pkhid
	RETURNING private_key_id INTO _pkid;

	GET DIAGNOSTICS _cnt = ROW_COUNT;

	IF update_private_key_hashes THEN
		RETURN _cnt + x509_hash_manip.set_private_key_hashes(_pkid, hashes);
	ELSE
		RETURN _cnt;
	END IF;
END;
$function$
;

-- Processing tables in main schema...
select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE val_encryption_key_purpose
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_encryption_key_purpose', 'val_encryption_key_purpose');

-- FOREIGN KEYS FROM
ALTER TABLE encryption_key DROP CONSTRAINT IF EXISTS fk_enckey_enckeypurpose_val;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands', object := 'val_encryption_key_purpose', newobject := 'val_encryption_key_purpose', newmap := '{"pk_val_encryption_key_purpose":{"columns":["encryption_key_purpose","encryption_key_purpose_version"],"def":"PRIMARY KEY (encryption_key_purpose, encryption_key_purpose_version)","deferrable":false,"deferred":false,"name":"pk_val_encryption_key_purpose","type":"p"}}');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_encryption_key_purpose DROP CONSTRAINT IF EXISTS pk_val_encryption_key_purpose;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_encryption_key_purpose ON jazzhands.val_encryption_key_purpose;
DROP TRIGGER IF EXISTS trigger_audit_val_encryption_key_purpose ON jazzhands.val_encryption_key_purpose;
DROP FUNCTION IF EXISTS perform_audit_val_encryption_key_purpose();
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands.val_encryption_key_purpose ALTER COLUMN "encryption_key_purpose_version" DROP IDENTITY;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'val_encryption_key_purpose', tags := ARRAY['table_val_encryption_key_purpose']);
---- BEGIN jazzhands_audit.val_encryption_key_purpose TEARDOWN
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'val_encryption_key_purpose', tags := ARRAY['table_val_encryption_key_purpose']);
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_audit', 'val_encryption_key_purpose', 'val_encryption_key_purpose');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands_audit',  object := 'val_encryption_key_purpose');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands_audit.val_encryption_key_purpose DROP CONSTRAINT IF EXISTS val_encryption_key_purpose_pkey;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands_audit"."aud_val_encryption_key_purpose_pk_val_encryption_key_purpose";
DROP INDEX IF EXISTS "jazzhands_audit"."val_encryption_key_purpose_aud#realtime_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."val_encryption_key_purpose_aud#timestamp_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."val_encryption_key_purpose_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands_audit.val_encryption_key_purpose ALTER COLUMN "aud#seq" DROP IDENTITY;
---- DONE jazzhands_audit.val_encryption_key_purpose TEARDOWN


ALTER TABLE val_encryption_key_purpose RENAME TO val_encryption_key_purpose_v93;
ALTER TABLE jazzhands_audit.val_encryption_key_purpose RENAME TO val_encryption_key_purpose_v93;

CREATE TABLE jazzhands.val_encryption_key_purpose
(
	encryption_key_purpose	varchar(50) NOT NULL,
	encryption_key_purpose_version	integer NOT NULL,
	external_id	varchar(255)  NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'val_encryption_key_purpose', false);
ALTER TABLE val_encryption_key_purpose
	ALTER COLUMN encryption_key_purpose_version
	ADD GENERATED BY DEFAULT AS IDENTITY;

INSERT INTO val_encryption_key_purpose (
	encryption_key_purpose,
	encryption_key_purpose_version,
	external_id,		-- new column (external_id)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	encryption_key_purpose,
	encryption_key_purpose_version,
	NULL,		-- new column (external_id)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_encryption_key_purpose_v93;


INSERT INTO jazzhands_audit.val_encryption_key_purpose (
	encryption_key_purpose,
	encryption_key_purpose_version,
	external_id,		-- new column (external_id)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
) SELECT
	encryption_key_purpose,
	encryption_key_purpose_version,
	NULL,		-- new column (external_id)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_encryption_key_purpose_v93;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_encryption_key_purpose ADD CONSTRAINT pk_val_encryption_key_purpose PRIMARY KEY (encryption_key_purpose, encryption_key_purpose_version);

-- Table/Column Comments
COMMENT ON TABLE jazzhands.val_encryption_key_purpose IS 'Valid purpose of encryption used by the key_crypto package; Used to identify which functional application knows the app provided portion of the encryption key';
COMMENT ON COLUMN jazzhands.val_encryption_key_purpose.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_encryption_key_purpose and jazzhands.encryption_key
ALTER TABLE jazzhands.encryption_key
	ADD CONSTRAINT fk_enckey_enckeypurpose_val
	FOREIGN KEY (encryption_key_purpose, encryption_key_purpose_version) REFERENCES jazzhands.val_encryption_key_purpose(encryption_key_purpose, encryption_key_purpose_version);

-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('val_encryption_key_purpose');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_encryption_key_purpose  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_encryption_key_purpose');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'val_encryption_key_purpose');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'val_encryption_key_purpose');
DROP TABLE IF EXISTS val_encryption_key_purpose_v93;
DROP TABLE IF EXISTS jazzhands_audit.val_encryption_key_purpose_v93;
-- DONE DEALING WITH TABLE val_encryption_key_purpose (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_encryption_key_purpose');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old val_encryption_key_purpose failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_encryption_key_purpose');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new val_encryption_key_purpose failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE certificate_signing_request
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'certificate_signing_request', 'certificate_signing_request');

-- FOREIGN KEYS FROM
ALTER TABLE x509_signed_certificate DROP CONSTRAINT IF EXISTS fk_csr_pvtkeyid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.certificate_signing_request DROP CONSTRAINT IF EXISTS fk_pvtkey_csr;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands', object := 'certificate_signing_request', newobject := 'certificate_signing_request', newmap := '{"pk_certificate_signing_request":{"columns":["certificate_signing_request_id"],"def":"PRIMARY KEY (certificate_signing_request_id)","deferrable":false,"deferred":false,"name":"pk_certificate_signing_request","type":"p"}}');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.certificate_signing_request DROP CONSTRAINT IF EXISTS pk_certificate_signing_request;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."fk_csr_pvtkeyid";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_certificate_signing_request ON jazzhands.certificate_signing_request;
DROP TRIGGER IF EXISTS trigger_audit_certificate_signing_request ON jazzhands.certificate_signing_request;
DROP FUNCTION IF EXISTS perform_audit_certificate_signing_request();
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands.certificate_signing_request ALTER COLUMN "certificate_signing_request_id" DROP IDENTITY;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'certificate_signing_request', tags := ARRAY['table_certificate_signing_request']);
---- BEGIN jazzhands_audit.certificate_signing_request TEARDOWN
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'certificate_signing_request', tags := ARRAY['table_certificate_signing_request']);
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_audit', 'certificate_signing_request', 'certificate_signing_request');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands_audit',  object := 'certificate_signing_request');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands_audit.certificate_signing_request DROP CONSTRAINT IF EXISTS certificate_signing_request_pkey;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands_audit"."aud_certificate_signing_request_pk_certificate_signing_request";
DROP INDEX IF EXISTS "jazzhands_audit"."certificate_signing_request_aud#realtime_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."certificate_signing_request_aud#timestamp_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."certificate_signing_request_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands_audit.certificate_signing_request ALTER COLUMN "aud#seq" DROP IDENTITY;
---- DONE jazzhands_audit.certificate_signing_request TEARDOWN


ALTER TABLE certificate_signing_request RENAME TO certificate_signing_request_v93;
ALTER TABLE jazzhands_audit.certificate_signing_request RENAME TO certificate_signing_request_v93;

CREATE TABLE jazzhands.certificate_signing_request
(
	certificate_signing_request_id	integer NOT NULL,
	friendly_name	varchar(255) NOT NULL,
	subject	varchar(255) NOT NULL,
	certificate_signing_request	text NOT NULL,
	private_key_id	integer  NULL,
	public_key_hash_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'certificate_signing_request', false);
ALTER TABLE certificate_signing_request
	ALTER COLUMN certificate_signing_request_id
	ADD GENERATED BY DEFAULT AS IDENTITY;

INSERT INTO certificate_signing_request (
	certificate_signing_request_id,
	friendly_name,
	subject,
	certificate_signing_request,
	private_key_id,
	public_key_hash_id,		-- new column (public_key_hash_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	certificate_signing_request_id,
	friendly_name,
	subject,
	certificate_signing_request,
	private_key_id,
	NULL,		-- new column (public_key_hash_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM certificate_signing_request_v93;


INSERT INTO jazzhands_audit.certificate_signing_request (
	certificate_signing_request_id,
	friendly_name,
	subject,
	certificate_signing_request,
	private_key_id,
	public_key_hash_id,		-- new column (public_key_hash_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
) SELECT
	certificate_signing_request_id,
	friendly_name,
	subject,
	certificate_signing_request,
	private_key_id,
	NULL,		-- new column (public_key_hash_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.certificate_signing_request_v93;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.certificate_signing_request ADD CONSTRAINT pk_certificate_signing_request PRIMARY KEY (certificate_signing_request_id);

-- Table/Column Comments
COMMENT ON TABLE jazzhands.certificate_signing_request IS 'Certificiate Signing Requests generated from public key.  This is mostly kept for posterity since its possible to generate these at-wil from the private key.';
COMMENT ON COLUMN jazzhands.certificate_signing_request.certificate_signing_request_id IS 'Uniquely identifies Certificate';
COMMENT ON COLUMN jazzhands.certificate_signing_request.friendly_name IS 'human readable name for certificate.  often just the CN.';
COMMENT ON COLUMN jazzhands.certificate_signing_request.subject IS 'Textual representation of a certificate subject. Certificate subject is a part of X509 certificate specifications.  This is the full subject from the certificate.  Friendly Name provides a human readable one.';
COMMENT ON COLUMN jazzhands.certificate_signing_request.certificate_signing_request IS 'Textual representation of a certificate signing certificate';
COMMENT ON COLUMN jazzhands.certificate_signing_request.private_key_id IS '
';
COMMENT ON COLUMN jazzhands.certificate_signing_request.public_key_hash_id IS 'Used as a unique id that identifies hashes on the same public key.  This is primarily used to correlate private keys and x509 certicates.';
-- INDEXES
CREATE INDEX fk_csr_pvtkeyid ON jazzhands.certificate_signing_request USING btree (private_key_id);
CREATE INDEX xif_x509_csr_public_key_hash ON jazzhands.certificate_signing_request USING btree (public_key_hash_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between certificate_signing_request and jazzhands.x509_signed_certificate
ALTER TABLE jazzhands.x509_signed_certificate
	ADD CONSTRAINT fk_csr_pvtkeyid
	FOREIGN KEY (certificate_signing_request_id) REFERENCES jazzhands.certificate_signing_request(certificate_signing_request_id);

-- FOREIGN KEYS TO
-- consider FK certificate_signing_request and private_key
ALTER TABLE jazzhands.certificate_signing_request
	ADD CONSTRAINT fk_pvtkey_csr
	FOREIGN KEY (private_key_id) REFERENCES jazzhands.private_key(private_key_id);
-- consider FK certificate_signing_request and public_key_hash
ALTER TABLE jazzhands.certificate_signing_request
	ADD CONSTRAINT fk_x509_csr_public_key_hash
	FOREIGN KEY (public_key_hash_id) REFERENCES jazzhands.public_key_hash(public_key_hash_id);

-- TRIGGERS
-- considering NEW jazzhands.x509_signed_pkh_csr_validate
CREATE OR REPLACE FUNCTION jazzhands.x509_signed_pkh_csr_validate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	pkhid	INTEGER;
BEGIN
	--
	-- XXX needs to be tweaked to ensure that both are set or not set.
	--
	IF NEW.private_key_id IS NOT NULL THEN
		SELECT	public_key_hash_id
		INTO	pkhid
		FROM	private_key p
		WHERE	p.private_key_id = NEW.private_key_id;

		IF FOUND AND pkhid != NEW.public_key_hash_id THEN
			RAISE EXCEPTION 'public_key_hash_id must match in x509_signed_certificate_id, private_key and certificate_signing_request_id' USING ERRCODE = 'foreign_key_violation';
		END IF;

		SELECT	public_key_hash_id
		INTO	pkhid
		FROM	x509_signed_certificate x
		WHERE	x.private_key_id = NEW.private_key_id;

		IF FOUND AND pkhid != NEW.public_key_hash_id THEN
			RAISE EXCEPTION 'public_key_hash_id must match in x509_signed_certificate_id, private_key and certificate_signing_request_id' USING ERRCODE = 'foreign_key_violation';
		END IF;

	END IF;

	SELECT	public_key_hash_id
	INTO	pkhid
	FROM	x509_signed_certificate x
	WHERE	x.certificate_signing_request_id = NEW.certificate_signing_request_id;

	IF FOUND AND pkhid != NEW.public_key_hash_id THEN
		RAISE EXCEPTION 'public_key_hash_id must match in x509_signed_certificate_id, private_key and certificate_signing_request_id' USING ERRCODE = 'foreign_key_violation';
	END IF;


	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands.x509_signed_pkh_csr_validate() FROM public;
CREATE CONSTRAINT TRIGGER trigger_x509_signed_pkh_csr_validate AFTER INSERT OR UPDATE OF public_key_hash_id, private_key_id, certificate_signing_request_id ON jazzhands.certificate_signing_request NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.x509_signed_pkh_csr_validate();

DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('certificate_signing_request');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for certificate_signing_request  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'certificate_signing_request');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'certificate_signing_request');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'certificate_signing_request');
DROP TABLE IF EXISTS certificate_signing_request_v93;
DROP TABLE IF EXISTS jazzhands_audit.certificate_signing_request_v93;
-- DONE DEALING WITH TABLE certificate_signing_request (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('certificate_signing_request');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old certificate_signing_request failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('certificate_signing_request');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new certificate_signing_request failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
-- Processing minor changes to private_key
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'private_key');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'private_key');
ALTER TABLE "jazzhands"."private_key" DROP COLUMN IF EXISTS "subject_key_identifier";
ALTER TABLE "jazzhands"."private_key" ALTER COLUMN "private_key" DROP NOT NULL;
ALTER TABLE "jazzhands_audit"."private_key" DROP COLUMN IF EXISTS "subject_key_identifier";
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE private_key
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'private_key', 'private_key');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'audit', object := 'private_key', tags := ARRAY['view_private_key']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS audit.private_key;
CREATE VIEW audit.private_key AS
 SELECT private_key.private_key_id,
    private_key.private_key_encryption_type,
        CASE
            WHEN private_key.is_active IS NULL THEN NULL::text
            WHEN private_key.is_active = true THEN 'Y'::text
            WHEN private_key.is_active = false THEN 'N'::text
            ELSE NULL::text
        END AS is_active,
    NULL::text AS subject_key_identifier,
    private_key.private_key,
    private_key.passphrase,
    private_key.encryption_key_id,
    private_key.data_ins_user,
    private_key.data_ins_date,
    private_key.data_upd_user,
    private_key.data_upd_date,
    private_key."aud#action",
    private_key."aud#timestamp",
    private_key."aud#realtime",
    private_key."aud#txid",
    private_key."aud#user",
    private_key."aud#seq"
   FROM jazzhands_audit.private_key;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'audit' AND type = 'view' AND object IN ('private_key','private_key');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of private_key failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'audit' AND object IN ('private_key');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for private_key  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE private_key (audit)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('private_key');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old private_key failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('private_key');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new private_key failed but that is ok';
	NULL;
END;
$$;

--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE x509_signed_certificate
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'x509_signed_certificate', 'x509_signed_certificate');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'audit', object := 'x509_signed_certificate', tags := ARRAY['view_x509_signed_certificate']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS audit.x509_signed_certificate;
CREATE VIEW audit.x509_signed_certificate AS
 SELECT x509_signed_certificate.x509_signed_certificate_id,
    x509_signed_certificate.x509_certificate_type,
    x509_signed_certificate.subject,
    x509_signed_certificate.friendly_name,
    x509_signed_certificate.subject_key_identifier,
    x509_signed_certificate.public_key_hash_id,
    x509_signed_certificate.description,
        CASE
            WHEN x509_signed_certificate.is_active IS NULL THEN NULL::text
            WHEN x509_signed_certificate.is_active = true THEN 'Y'::text
            WHEN x509_signed_certificate.is_active = false THEN 'N'::text
            ELSE NULL::text
        END AS is_active,
        CASE
            WHEN x509_signed_certificate.is_certificate_authority IS NULL THEN NULL::text
            WHEN x509_signed_certificate.is_certificate_authority = true THEN 'Y'::text
            WHEN x509_signed_certificate.is_certificate_authority = false THEN 'N'::text
            ELSE NULL::text
        END AS is_certificate_authority,
    x509_signed_certificate.signing_cert_id,
    x509_signed_certificate.x509_ca_cert_serial_number,
    x509_signed_certificate.public_key,
    x509_signed_certificate.private_key_id,
    x509_signed_certificate.certificate_signing_request_id,
    x509_signed_certificate.valid_from,
    x509_signed_certificate.valid_to,
    x509_signed_certificate.x509_revocation_date,
    x509_signed_certificate.x509_revocation_reason,
    x509_signed_certificate.ocsp_uri,
    x509_signed_certificate.crl_uri,
    x509_signed_certificate.data_ins_user,
    x509_signed_certificate.data_ins_date,
    x509_signed_certificate.data_upd_user,
    x509_signed_certificate.data_upd_date,
    x509_signed_certificate."aud#action",
    x509_signed_certificate."aud#timestamp",
    x509_signed_certificate."aud#realtime",
    x509_signed_certificate."aud#txid",
    x509_signed_certificate."aud#user",
    x509_signed_certificate."aud#seq"
   FROM jazzhands_audit.x509_signed_certificate;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'audit' AND type = 'view' AND object IN ('x509_signed_certificate','x509_signed_certificate');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of x509_signed_certificate failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'audit' AND object IN ('x509_signed_certificate');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for x509_signed_certificate  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE x509_signed_certificate (audit)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('x509_signed_certificate');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old x509_signed_certificate failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('x509_signed_certificate');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new x509_signed_certificate failed but that is ok';
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
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_cache', 'cache_netblock_hier_handler');
SELECT schema_support.save_grants_for_replay('jazzhands_cache', 'cache_netblock_hier_handler');
CREATE OR REPLACE FUNCTION jazzhands_cache.cache_netblock_hier_handler()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_cnt	INTEGER;
	_r		RECORD;
	_n		RECORD;
BEGIN
	IF TG_OP IN ('UPDATE','INSERT') AND NEW.is_single_address = 'Y' THEN
		RETURN NULL;
	END IF;

	IF TG_OP IN ('DELETE','UPDATE') THEN
		RAISE DEBUG 'ENTER cache_netblock_hier_handler OLD: % %',
			TG_OP, to_json(OLD);
	END IF;
	IF TG_OP IN ('INSERT','UPDATE') THEN
		RAISE DEBUG 'ENTER cache_netblock_hier_handler NEW: % %',
			TG_OP, to_json(NEW);
		IF NEW.parent_netblock_id IS NOT NULL AND NEW.netblock_id = NEW.parent_netblock_id THEN
			RAISE DEBUG 'aborting because this row is self referrential';
			RETURN NULL;
		END IF;
	END IF;

	--
	-- Delete any rows that are invalidated due to a parent change.
	-- Any parent change means recreating all the rows related to the node
	-- that changes; due to how the netblock triggers work, this may result
	-- in records being changed multiple times.
	--
	IF TG_OP = 'DELETE' OR
		(
			TG_OP = 'UPDATE' AND OLD.parent_netblock_id IS NOT NULL
		)
	THEN
		RAISE DEBUG '% cleanup for %, % [%]',
			TG_OP, OLD.netblock_id, OLD.parent_netblock_id, OLD.ip_address;
		FOR _r IN
		DELETE FROM jazzhands_cache.ct_netblock_hier
		WHERE	OLD.netblock_id = ANY(path)
		RETURNING *
		LOOP
			RAISE DEBUG '-> rm/DEL %', to_json(_r);
		END LOOP;
		get diagnostics _cnt = row_count;
		RAISE DEBUG 'nbcache: Deleting upstream references to netblock % from cache == %',
			OLD.netblock_id, _cnt;
	ELSIF TG_OP = 'INSERT' THEN
		FOR _r IN
		DELETE FROM jazzhands_cache.ct_netblock_hier
		-- WHERE	NEW.netblock_id = ANY(path)
		WHERE root_netblocK_id = NEW.netblock_id
		RETURNING *
		LOOP
			RAISE DEBUG '-> rm/INS?! %', to_json(_r);
		END LOOP;
	END IF;


	--
	-- XXX deal with parent becoming NULL!
	--

	IF TG_OP IN ('INSERT', 'UPDATE') THEN
		RAISE DEBUG 'nbcache: % reference for new netblock %, % [%]',
			TG_OP, NEW.netblock_id, NEW.parent_netblock_id, NEW.ip_address;

		--
		-- XXX: This is no longer true.  Not sure why it wasn't deleted: "This
		-- runs even if parent_netblock_id is NULL in order to get the
		-- row that includes the netblock into itself.
		--
		-- revisited later:  This takes care of everthing "above the netblock"
		-- This actually does not seem to delete things if the parent changes
		-- which would only happen on ip universe change or some such, which
		-- may be disallowed elsewhere?
		--
		FOR _r IN
		WITH RECURSIVE tier (
			root_netblock_id,
			intermediate_netblock_id,
			netblock_id,
			path
		)AS (
			SELECT parent_netblock_id,
				parent_netblock_id,
				netblock_id,
				ARRAY[netblock_id, parent_netblock_id]
			FROM netblock WHERE netblock_id = NEW.netblock_id
			AND parent_netblock_id IS NOT NULL
		UNION ALL
			SELECT n.parent_netblock_id,
				tier.intermediate_netblock_id,
				tier.netblock_id,
				array_append(tier.path, n.parent_netblock_id)
			FROM tier
				JOIN netblock n ON n.netblock_id = tier.root_netblock_id
			WHERE n.parent_netblock_id IS NOT NULL
		), combo AS (
			SELECT * FROM tier
			UNION ALL
			SELECT netblock_id, netblock_id, netblock_id, ARRAY[netblock_id]
			FROM netblock WHERE netblock_id = NEW.netblock_id
		) SELECT * FROM combo
			WHERE path NOT IN (
				--
				-- This is really to exclude things that existed because of
				-- an update, such as adding a new parent to something that
				-- previously did not have one.
				SELECT path FROM jazzhands_cache.ct_netblock_hier
			)
		LOOP
			RAISE DEBUG 'nb/ins up %', to_json(_r);
			BEGIN
				--
				-- It is not clear if the unique violation check is needed here
				-- or not.  It was inserted when the one in the next block was
				-- so possibly makes sense to remove to not hide a bug.
				INSERT INTO jazzhands_cache.ct_netblock_hier (
					root_netblock_id, intermediate_netblock_id,
					netblock_id, path
				) VALUES (
					_r.root_netblock_id, _r.intermediate_netblock_id,
					_r.netblock_id, _r.path
				);
			EXCEPTION WHEN unique_violation THEN
				RAISE DEBUG '... failed due to unique violation';
			END;
		END LOOP;

		FOR _r IN
			SELECT h.*, ip_address
			FROM jazzhands_cache.ct_netblock_hier h
				JOIN netblock n ON
					n.netblock_id = h.root_netblock_id
			AND n.parent_netblock_id = NEW.netblock_id
			-- AND array_length(path, 1) > 1
		LOOP
			RAISE DEBUG 'nb/ins from %', to_json(_r);
			_r.root_netblock_id := NEW.netblock_id;
			IF array_length(_r.path, 1) = 1 THEN
				_r.intermediate_netblock_id := NEW.netblock_id;
			ELSE
				_r.intermediate_netblock_id := _r.intermediate_netblock_id;
			END IF;
			_r.netblock_id := _r.netblock_id;
			_r.path := array_append(_r.path, NEW.netblock_id);

			RAISE DEBUG '... %', to_json(_r);
			BEGIN
				--
				-- unique violations can happen if it's the edge case.  The
				-- array_length() that's commented out was proabbly meant to
				-- deal with this but I'm not doing that just now.
				--
				-- This is specifically to deal with the
				-- condition in tests where there a new
				-- grandparent isinserted.
				--
				INSERT INTO jazzhands_cache.ct_netblock_hier (
					root_netblock_id, intermediate_netblock_id,
					netblock_id, path
				) VALUES (
					_r.root_netblock_id, _r.intermediate_netblock_id,
					_r.netblock_id, _r.path
				);
			EXCEPTION WHEN unique_violation THEN
				RAISE DEBUG '... failed due to unique violation';
			END;
		END LOOP;

		--
		-- now combine all the kids and all the parents with this row in
		-- the middle
		--
		IF TG_OP = 'INSERT' THEN
			FOR _r IN
				SELECT
					hpar.root_netblock_id,
					hkid.intermediate_netblock_id as intermediate_netblock_id,
					hkid.netblock_id,
					array_cat( hkid.path, hpar.path[2:]) as path,
					hkid.path as hkid_path,
					hpar.path as hpar_path
				FROM jazzhands_cache.ct_netblock_hier hkid
					JOIN jazzhands_cache.ct_netblock_hier hpar
						ON hkid.root_netblock_id = hpar.netblock_id
				WHERE hpar.netblock_id = NEW.netblock_id
				AND array_length(hpar.path, 1) > 1
				AND array_length(hkid.path, 1) > 2
			LOOP
				RAISE DEBUG 'XXX nb ins/comp: %', to_json(_r);
				INSERT INTO jazzhands_cache.ct_netblock_hier (
					root_netblock_id, intermediate_netblock_id,
					netblock_id, path
				) VALUES (
					_r.root_netblock_id, _r.intermediate_netblock_id,
					_r.netblock_id, _r.path
				);
				END LOOP;
		END IF;
	END IF;
	RAISE DEBUG 'EXIT jazzhands_cache.cache_netblock_hier_handler';
	RETURN NULL;
END
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_cache' AND type = 'function' AND object IN ('cache_netblock_hier_handler');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc cache_netblock_hier_handler failed but that is ok';
	NULL;
END;
$$;

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
DROP TRIGGER IF EXISTS trigger_pvtkey_ski_signed_validate ON jazzhands.private_key;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands'::text, object := 'pvtkey_ski_signed_validate (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands'::text]);
DROP FUNCTION IF EXISTS jazzhands.pvtkey_ski_signed_validate (  );
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'validate_val_property');
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_val_property');
CREATE OR REPLACE FUNCTION jazzhands.validate_val_property()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	IF NEW.property_data_type = 'json' AND NEW.property_value_json_schema IS NULL THEN
		RAISE 'property_data_type json requires a schema to be set'
			USING ERRCODE = 'invalid_parameter_value';
	ELSIF NEW.property_data_type != 'json' AND NEW.property_value_json_schema IS NOT NULL THEN
		RAISE 'property_data_type % may not have a json schema set',
			NEW.property_data_type
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF TG_OP = 'UPDATE' AND OLD.property_data_type != NEW.property_data_type THEN
		SELECT	count(*)
		INTO	_tally
		FROM	property
		WHERE	property_name = NEW.property_name
		AND		property_type = NEW.property_type;

		IF _tally > 0  THEN
			RAISE 'May not change property type if there are existing proeprties'
				USING ERRCODE = 'foreign_key_violation';

		END IF;
	END IF;

	IF TG_OP = 'INSERT' AND NEW.permit_company_id != 'PROHIBITED' OR
		( TG_OP = 'UPDATE' AND NEW.permit_company_id != 'PROHIBITED' AND
			OLD.permit_company_id IS DISTINCT FROM NEW.permit_company_id )
	THEN
		RAISE 'property.company_id is being retired.  Please use per-company collections'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;
	RETURN NEW;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'function' AND object IN ('validate_val_property');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc validate_val_property failed but that is ok';
	NULL;
END;
$$;

DROP TRIGGER IF EXISTS trigger_x509_signed_ski_pvtkey_validate ON jazzhands.x509_signed_certificate;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands'::text, object := 'x509_signed_ski_pvtkey_validate (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands'::text]);
DROP FUNCTION IF EXISTS jazzhands.x509_signed_ski_pvtkey_validate (  );
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands']);
-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION jazzhands.pvtkey_pkh_signed_validate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	pkhid	INTEGER;
	id	INTEGER;
BEGIN
	SELECT	public_key_hash_id
	INTO	pkhid
	FROM	x509_signed_certificate x
	WHERE	x.private_key_id = NEW.private_key_id;

	IF FOUND AND pkhid != NEW.public_key_hash_id THEN
		RAISE EXCEPTION 'public_key_hash_id must match in x509_signed_certificate_id and private_key' USING ERRCODE = 'foreign_key_violation';
	END IF;

	SELECT	public_key_hash_id
	INTO	pkhid
	FROM	certificate_signing_request x
	WHERE	x.private_key_id = NEW.private_key_id;

	IF FOUND AND pkhid != NEW.public_key_hash_id THEN
		RAISE EXCEPTION 'public_key_hash_id must match in x509_signed_certificate_id and private_key' USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION jazzhands.x509_signed_pkh_csr_validate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	pkhid	INTEGER;
BEGIN
	--
	-- XXX needs to be tweaked to ensure that both are set or not set.
	--
	IF NEW.private_key_id IS NOT NULL THEN
		SELECT	public_key_hash_id
		INTO	pkhid
		FROM	private_key p
		WHERE	p.private_key_id = NEW.private_key_id;

		IF FOUND AND pkhid != NEW.public_key_hash_id THEN
			RAISE EXCEPTION 'public_key_hash_id must match in x509_signed_certificate_id, private_key and certificate_signing_request_id' USING ERRCODE = 'foreign_key_violation';
		END IF;

		SELECT	public_key_hash_id
		INTO	pkhid
		FROM	x509_signed_certificate x
		WHERE	x.private_key_id = NEW.private_key_id;

		IF FOUND AND pkhid != NEW.public_key_hash_id THEN
			RAISE EXCEPTION 'public_key_hash_id must match in x509_signed_certificate_id, private_key and certificate_signing_request_id' USING ERRCODE = 'foreign_key_violation';
		END IF;

	END IF;

	SELECT	public_key_hash_id
	INTO	pkhid
	FROM	x509_signed_certificate x
	WHERE	x.certificate_signing_request_id = NEW.certificate_signing_request_id;

	IF FOUND AND pkhid != NEW.public_key_hash_id THEN
		RAISE EXCEPTION 'public_key_hash_id must match in x509_signed_certificate_id, private_key and certificate_signing_request_id' USING ERRCODE = 'foreign_key_violation';
	END IF;


	RETURN NEW;
END;
$function$
;

-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION jazzhands.x509_signed_pkh_pvtkey_validate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	pkhid	INTEGER;
	id	INTEGER;
BEGIN
	--
	-- XXX needs to be tweaked to ensure that both are set or not set.
	--
	IF NEW.private_key_id IS NOT NULL THEN
		SELECT	public_key_hash_id
		INTO	pkhid
		FROM	private_key p
		WHERE	p.private_key_id = NEW.private_key_id;

		IF FOUND AND pkhid != NEW.public_key_hash_id THEN
			RAISE EXCEPTION 'public_key_hash_id must match in x509_signed_certificate_id, private_key and certificate_signing_request_id' USING ERRCODE = 'foreign_key_violation';
		END IF;

		SELECT	public_key_hash_id
		INTO	pkhid
		FROM	certificate_signing_request p
		WHERE	p.private_key_id = NEW.private_key_id;

		IF FOUND AND pkhid != NEW.public_key_hash_id THEN
			RAISE EXCEPTION 'public_key_hash_id must match in x509_signed_certificate_id and private_key' USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;

	IF NEW.certificate_signing_request_id IS NOT NULL THEN
		SELECT	public_key_hash_id
		INTO	pkhid
		FROM	certificate_signing_request p
		WHERE	p.certificate_signing_request_id = NEW.certificate_signing_request_id;

		IF FOUND AND pkhid != NEW.public_key_hash_id THEN
			RAISE EXCEPTION 'public_key_hash_id must match in x509_signed_certificate_id, private_key and certificate_signing_request_id' USING ERRCODE = 'foreign_key_violation';
		END IF;

		SELECT	public_key_hash_id
		INTO	pkhid
		FROM	certificate_signing_request p
		WHERE	p.private_key_id = NEW.private_key_id;

		IF FOUND AND pkhid != NEW.public_key_hash_id THEN
			RAISE EXCEPTION 'public_key_hash_id must match in x509_signed_certificate_id and private_key' USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;


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
-- Recreate the saved views in the base schema
--
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', type := 'view');


-- BEGIN Misc that does not apply to above
SELECT schema_support.set_schema_version(
        version := '0.93',
        schema := 'jazzhands'
);


-- END Misc that does not apply to above
--
-- BEGIN: process_ancillary_schema(jazzhands_legacy)
--
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE certificate_signing_request
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'certificate_signing_request', 'certificate_signing_request');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'certificate_signing_request', tags := ARRAY['view_certificate_signing_request']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.certificate_signing_request;
CREATE VIEW jazzhands_legacy.certificate_signing_request AS
 SELECT certificate_signing_request.certificate_signing_request_id,
    certificate_signing_request.friendly_name,
    certificate_signing_request.subject,
    certificate_signing_request.certificate_signing_request,
    certificate_signing_request.private_key_id,
    certificate_signing_request.public_key_hash_id,
    certificate_signing_request.data_ins_user,
    certificate_signing_request.data_ins_date,
    certificate_signing_request.data_upd_user,
    certificate_signing_request.data_upd_date
   FROM jazzhands.certificate_signing_request;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('certificate_signing_request','certificate_signing_request');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of certificate_signing_request failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('certificate_signing_request');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for certificate_signing_request  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE certificate_signing_request (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('certificate_signing_request');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old certificate_signing_request failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('certificate_signing_request');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new certificate_signing_request failed but that is ok';
	NULL;
END;
$$;

--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE private_key
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'private_key', 'private_key');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'private_key', tags := ARRAY['view_private_key']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.private_key;
CREATE VIEW jazzhands_legacy.private_key AS
 SELECT private_key.private_key_id,
    private_key.private_key_encryption_type,
        CASE
            WHEN private_key.is_active IS NULL THEN NULL::text
            WHEN private_key.is_active = true THEN 'Y'::text
            WHEN private_key.is_active = false THEN 'N'::text
            ELSE NULL::text
        END AS is_active,
    NULL::text AS subject_key_identifier,
    private_key.public_key_hash_id,
    private_key.description,
    private_key.private_key,
    private_key.passphrase,
    private_key.encryption_key_id,
    private_key.external_id,
    private_key.data_ins_user,
    private_key.data_ins_date,
    private_key.data_upd_user,
    private_key.data_upd_date
   FROM jazzhands.private_key;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('private_key','private_key');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of private_key failed but that is ok';
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
-- considering NEW jazzhands_legacy.private_key_del
CREATE OR REPLACE FUNCTION jazzhands_legacy.private_key_del()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_or	jazzhands.private_key%rowtype;
BEGIN
	DELETE FROM jazzhands.private_key
	WHERE  private_key_id = OLD.private_key_id  RETURNING *
	INTO _or;
	OLD.private_key_id = _or.private_key_id;
	OLD.private_key_encryption_type = _or.private_key_encryption_type;
	OLD.is_active = CASE WHEN _or.is_active = true THEN 'Y' WHEN _or.is_active = false THEN 'N' ELSE NULL END;
	OLD.subject_key_identifier = NULL;
	OLD.public_key_hash_id = _or.public_key_hash_id;
	OLD.description = _or.description;
	OLD.private_key = _or.private_key;
	OLD.passphrase = _or.passphrase;
	OLD.encryption_key_id = _or.encryption_key_id;
	OLD.external_id = _or.external_id;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands_legacy.private_key_del() FROM public;
CREATE TRIGGER trigger_private_key_del INSTEAD OF DELETE ON jazzhands_legacy.private_key FOR EACH ROW EXECUTE FUNCTION jazzhands_legacy.private_key_del();

-- considering NEW jazzhands_legacy.private_key_ins
CREATE OR REPLACE FUNCTION jazzhands_legacy.private_key_ins()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.private_key%rowtype;
BEGIN

	IF NEW.private_key_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('private_key_id'));
		_vq := array_append(_vq, quote_nullable(NEW.private_key_id));
	END IF;

	IF NEW.private_key_encryption_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('private_key_encryption_type'));
		_vq := array_append(_vq, quote_nullable(NEW.private_key_encryption_type));
	END IF;

	IF NEW.is_active IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_active'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_active = 'Y' THEN true WHEN NEW.is_active = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.subject_key_identifier IS NOT NULL THEN
		RAISE EXCEPTION 'subject_key_identifier has been deprecated and can not be set'
			USING ERRCODE = invalid_parameter_value;
	END IF;

	IF NEW.public_key_hash_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('public_key_hash_id'));
		_vq := array_append(_vq, quote_nullable(NEW.public_key_hash_id));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.private_key IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('private_key'));
		_vq := array_append(_vq, quote_nullable(NEW.private_key));
	END IF;

	IF NEW.passphrase IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('passphrase'));
		_vq := array_append(_vq, quote_nullable(NEW.passphrase));
	END IF;

	IF NEW.encryption_key_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('encryption_key_id'));
		_vq := array_append(_vq, quote_nullable(NEW.encryption_key_id));
	END IF;

	IF NEW.external_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('external_id'));
		_vq := array_append(_vq, quote_nullable(NEW.external_id));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.private_key (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.private_key_id = _nr.private_key_id;
	NEW.private_key_encryption_type = _nr.private_key_encryption_type;
	NEW.is_active = CASE WHEN _nr.is_active = true THEN 'Y' WHEN _nr.is_active = false THEN 'N' ELSE NULL END;
	NEW.subject_key_identifier = NULL;
	NEW.public_key_hash_id = _nr.public_key_hash_id;
	NEW.description = _nr.description;
	NEW.private_key = _nr.private_key;
	NEW.passphrase = _nr.passphrase;
	NEW.encryption_key_id = _nr.encryption_key_id;
	NEW.external_id = _nr.external_id;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands_legacy.private_key_ins() FROM public;
CREATE TRIGGER trigger_private_key_ins INSTEAD OF INSERT ON jazzhands_legacy.private_key FOR EACH ROW EXECUTE FUNCTION jazzhands_legacy.private_key_ins();

-- considering NEW jazzhands_legacy.private_key_upd
CREATE OR REPLACE FUNCTION jazzhands_legacy.private_key_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_r	jazzhands_legacy.private_key%rowtype;
	_nr	jazzhands.private_key%rowtype;
	_uq	text[];
BEGIN

	IF OLD.private_key_id IS DISTINCT FROM NEW.private_key_id THEN
_uq := array_append(_uq, 'private_key_id = ' || quote_nullable(NEW.private_key_id));
	END IF;

	IF OLD.private_key_encryption_type IS DISTINCT FROM NEW.private_key_encryption_type THEN
_uq := array_append(_uq, 'private_key_encryption_type = ' || quote_nullable(NEW.private_key_encryption_type));
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

	IF OLD.subject_key_identifier IS DISTINCT FROM NEW.subject_key_identifier THEN
		IF NEW.subject_key_identifier IS NOT NULL THEN
			RAISE EXCEPTION 'subject_key_identifier has been deprecated and can not be set'
				USING ERRCODE = invalid_parameter_value;
		END IF;
	END IF;

	IF OLD.public_key_hash_id IS DISTINCT FROM NEW.public_key_hash_id THEN
_uq := array_append(_uq, 'public_key_hash_id = ' || quote_nullable(NEW.public_key_hash_id));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.private_key IS DISTINCT FROM NEW.private_key THEN
_uq := array_append(_uq, 'private_key = ' || quote_nullable(NEW.private_key));
	END IF;

	IF OLD.passphrase IS DISTINCT FROM NEW.passphrase THEN
_uq := array_append(_uq, 'passphrase = ' || quote_nullable(NEW.passphrase));
	END IF;

	IF OLD.encryption_key_id IS DISTINCT FROM NEW.encryption_key_id THEN
_uq := array_append(_uq, 'encryption_key_id = ' || quote_nullable(NEW.encryption_key_id));
	END IF;

	IF OLD.external_id IS DISTINCT FROM NEW.external_id THEN
_uq := array_append(_uq, 'external_id = ' || quote_nullable(NEW.external_id));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.private_key SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  private_key_id = $1 RETURNING *'  USING OLD.private_key_id
			INTO _nr;

		NEW.private_key_id = _nr.private_key_id;
		NEW.private_key_encryption_type = _nr.private_key_encryption_type;
		NEW.is_active = CASE WHEN _nr.is_active = true THEN 'Y' WHEN _nr.is_active = false THEN 'N' ELSE NULL END;
		NEW.subject_key_identifier = NULL;
		NEW.public_key_hash_id = _nr.public_key_hash_id;
		NEW.description = _nr.description;
		NEW.private_key = _nr.private_key;
		NEW.passphrase = _nr.passphrase;
		NEW.encryption_key_id = _nr.encryption_key_id;
		NEW.external_id = _nr.external_id;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands_legacy.private_key_upd() FROM public;
CREATE TRIGGER trigger_private_key_upd INSTEAD OF UPDATE ON jazzhands_legacy.private_key FOR EACH ROW EXECUTE FUNCTION jazzhands_legacy.private_key_upd();

DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('private_key');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for private_key  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE private_key (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('private_key');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old private_key failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('private_key');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new private_key failed but that is ok';
	NULL;
END;
$$;

--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE val_encryption_key_purpose
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'val_encryption_key_purpose', 'val_encryption_key_purpose');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'val_encryption_key_purpose', tags := ARRAY['view_val_encryption_key_purpose']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.val_encryption_key_purpose;
CREATE VIEW jazzhands_legacy.val_encryption_key_purpose AS
 SELECT val_encryption_key_purpose.encryption_key_purpose,
    val_encryption_key_purpose.encryption_key_purpose_version,
    val_encryption_key_purpose.external_id,
    val_encryption_key_purpose.description,
    val_encryption_key_purpose.data_ins_user,
    val_encryption_key_purpose.data_ins_date,
    val_encryption_key_purpose.data_upd_user,
    val_encryption_key_purpose.data_upd_date
   FROM jazzhands.val_encryption_key_purpose;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('val_encryption_key_purpose','val_encryption_key_purpose');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of val_encryption_key_purpose failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('val_encryption_key_purpose');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_encryption_key_purpose  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_encryption_key_purpose (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('val_encryption_key_purpose');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old val_encryption_key_purpose failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('val_encryption_key_purpose');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new val_encryption_key_purpose failed but that is ok';
	NULL;
END;
$$;

--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE x509_certificate
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'x509_certificate', 'x509_certificate');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'x509_certificate', tags := ARRAY['view_x509_certificate']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.x509_certificate;
CREATE VIEW jazzhands_legacy.x509_certificate AS
 SELECT crt.x509_signed_certificate_id AS x509_cert_id,
    crt.friendly_name,
        CASE
            WHEN crt.is_active IS NULL THEN NULL::text
            WHEN crt.is_active = true THEN 'Y'::text
            WHEN crt.is_active = false THEN 'N'::text
            ELSE NULL::text
        END AS is_active,
        CASE
            WHEN crt.is_certificate_authority IS NULL THEN NULL::text
            WHEN crt.is_certificate_authority = true THEN 'Y'::text
            WHEN crt.is_certificate_authority = false THEN 'N'::text
            ELSE NULL::text
        END AS is_certificate_authority,
    crt.signing_cert_id,
    crt.x509_ca_cert_serial_number,
    crt.public_key,
    key.private_key,
    csr.certificate_signing_request AS certificate_sign_req,
    crt.subject,
    crt.subject_key_identifier,
    crt.public_key_hash_id,
    crt.description,
    crt.valid_from,
    crt.valid_to,
    crt.x509_revocation_date,
    crt.x509_revocation_reason,
    key.passphrase,
    key.encryption_key_id,
    crt.ocsp_uri,
    crt.crl_uri,
    crt.data_ins_user,
    crt.data_ins_date,
    crt.data_upd_user,
    crt.data_upd_date
   FROM jazzhands.x509_signed_certificate crt
     LEFT JOIN jazzhands.private_key key USING (private_key_id)
     LEFT JOIN jazzhands.certificate_signing_request csr USING (certificate_signing_request_id);

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('x509_certificate','x509_certificate');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of x509_certificate failed but that is ok';
	NULL;
END;
$$;

-- just in case
SELECT schema_support.prepare_for_object_replay();
ALTER TABLE jazzhands_legacy.x509_certificate
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE jazzhands_legacy.x509_certificate
	ALTER is_certificate_authority
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- considering NEW jazzhands_legacy.x509_certificate_del
CREATE OR REPLACE FUNCTION jazzhands_legacy.x509_certificate_del()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	crt     jazzhands.x509_signed_certificate%ROWTYPE;
	key     jazzhands.private_key%ROWTYPE;
	csr     jazzhands.certificate_signing_request%ROWTYPE;
BEGIN
	SELECT * INTO crt FROM jazzhands.x509_signed_certificate
		WHERE x509_signed_certificate_id = OLD.x509_cert_id;

	IF crt.private_key_id IS NOT NULL THEN
		DELETE FROM jazzhands.private_key
		WHERE private_key_id = crt.private_key_id
		RETURNING * INTO key;
	END IF;

	IF crt.private_key_id IS NOT NULL THEN
		DELETE FROM jazzhands.certificate_signing_request
		WHERE certificate_signing_request_id =
		crt.certificate_signing_request_id
		RETURNING * INTO crt;
	END IF;

	OLD.x509_cert_id = crt.x509_signed_certiciate_id;
	OLD.friendly_name = crt.friendly_name;
	OLD.is_active = CASE WHEN crt.is_active = true THEN 'Y' WHEN crt.is_active = false THEN 'N' ELSE NULL END;
	OLD.is_certificate_authority = CASE WHEN crt.is_certificate_authority = true THEN 'Y' WHEN crt.is_certificate_authority = false THEN 'N' ELSE NULL END;
	OLD.signing_cert_id = crt.signing_cert_id;
	OLD.x509_ca_cert_serial_number = crt.x509_ca_cert_serial_number;
	OLD.public_key = crt.public_key;
	OLD.private_key = key.private_key;
	OLD.certificate_sign_req = crt.certificate_signing_request;
	OLD.subject = crt.subject;
	OLD.subject_key_identifier = crt.subject_key_identifier;
	OLD.public_key_hash_id = crt.public_key_hash_id;
	OLD.description = crt.description;
	OLD.valid_from = crt.valid_from;
	OLD.valid_to = crt.valid_to;
	OLD.x509_revocation_date = crt.x509_revocation_date;
	OLD.x509_revocation_reason = crt.x509_revocation_reason;
	OLD.passphrase = key.passphrase;
	OLD.encryption_key_id = key.encryption_key_id;
	OLD.ocsp_uri = crt.ocsp_uri;
	OLD.crl_uri = crt.crl_uri;
	OLD.data_ins_user = crt.data_ins_user;
	OLD.data_ins_date = crt.data_ins_date;
	OLD.data_upd_user = crt.data_upd_user;
	OLD.data_upd_date = crt.data_upd_date;
	RETURN OLD;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands_legacy.x509_certificate_del() FROM public;
CREATE TRIGGER trigger_x509_certificate_del INSTEAD OF DELETE ON jazzhands_legacy.x509_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands_legacy.x509_certificate_del();

-- considering NEW jazzhands_legacy.x509_certificate_ins
CREATE OR REPLACE FUNCTION jazzhands_legacy.x509_certificate_ins()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	key	jazzhands.private_key%rowtype;
	csr	jazzhands.certificate_signing_request%rowtype;
	crt	jazzhands.x509_signed_certificate%rowtype;
BEGIN
	IF NEW.private_key IS NOT NULL THEN
		INSERT INTO jazzhands.private_key (
			private_key_encryption_type,
			is_active,
			public_key_hash_id,
			private_key,
			passphrase,
			encryption_key_id
		) VALUES (
			'rsa',
			CASE WHEN NEW.is_active = 'Y' THEN true
				WHEN NEW.is_active = 'N' THEN false
				ELSE NULL END,
			NEW.public_key_hash_id,
			NEW.private_key,
			NEW.passphrase,
			NEW.encryption_key_id
		) RETURNING * INTO key;
		NEW.x509_cert_id := key.private_key_id;
	ELSE
		IF NEW.public_key_hash_id IS NOT NULL THEN
			SELECT *
			INTO key
			FROM private_key
			WHERE public_key_hash_id = NEW.public_key_hash_id;

			IF key IS NOT NULL THEN
				SELECT private_key
				INTO NEW.private_key
				FROM private_key
				WHERE private_key_id = key.private_key_id;
			END IF;
		END IF;
	END IF;

	IF NEW.certificate_sign_req IS NOT NULL THEN
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
		IF NEW.x509_cert_id IS NULL THEN
			NEW.x509_cert_id := csr.certificate_signing_request_id;
		END IF;
	ELSE
		IF NEW.subject_key_identifier IS NOT NULL THEN
			SELECT c.*
			INTO csr
			FROM certificate_signing_request c
			WHERE c.public_key_hash_id = NEW.public_key_hash_id
			ORDER BY certificate_signing_request_id
			LIMIT 1;

			SELECT certificate_signing_request
			INTO NEW.certificate_sign_req
			FROM certificate_signing_request
			WHERE certificate_signing_request_id  = csr.certificate_signing_request_id;
		END IF;
	END IF;

	IF NEW.public_key IS NOT NULL THEN
		INSERT INTO jazzhands.x509_signed_certificate (
			friendly_name,
			is_active,
			is_certificate_authority,
			signing_cert_id,
			x509_ca_cert_serial_number,
			public_key,
			subject,
			subject_key_identifier,
			public_key_hash_id,
			description,
			valid_from,
			valid_to,
			x509_revocation_date,
			x509_revocation_reason,
			ocsp_uri,
			crl_uri,
			private_key_id,
			certificate_signing_request_id
		) VALUES (
			NEW.friendly_name,
			CASE WHEN NEW.is_active = 'Y' THEN true
				WHEN NEW.is_active = 'N' THEN false
				ELSE NULL END,
			CASE WHEN NEW.is_certificate_authority = 'Y' THEN true
				WHEN NEW.is_certificate_authority = 'N' THEN false
				ELSE NULL END,
			NEW.signing_cert_id,
			NEW.x509_ca_cert_serial_number,
			NEW.public_key,
			NEW.subject,
			NEW.subject_key_identifier,
			NEW.public_key_hash_id,
			NEW.description,
			NEW.valid_from,
			NEW.valid_to,
			NEW.x509_revocation_date,
			NEW.x509_revocation_reason,
			NEW.ocsp_uri,
			NEW.crl_uri,
			key.private_key_id,
			csr.certificate_signing_request_id
		) RETURNING * INTO crt;

		NEW.x509_cert_id 		= crt.x509_signed_certificate_id;
		NEW.friendly_name 		= crt.friendly_name;
		NEW.is_active 			= CASE WHEN crt.is_active = true THEN 'Y'
									WHEN crt.is_active = false THEN 'N'
									ELSE NULL END;
		NEW.is_certificate_authority = CASE WHEN crt.is_certificate_authority =
										true THEN 'Y'
									WHEN crt.is_certificate_authority = false
										THEN 'N'
									ELSE NULL END;

		NEW.signing_cert_id 			= crt.signing_cert_id;
		NEW.x509_ca_cert_serial_number	= crt.x509_ca_cert_serial_number;
		NEW.public_key 					= crt.public_key;
		NEW.private_key 				= key.private_key;
		NEW.certificate_sign_req 		= csr.certificate_signing_request;
		NEW.subject 					= crt.subject;
		NEW.subject_key_identifier 		= crt.subject_key_identifier;
		NEW.public_key_hash_id 			= crt.public_key_hash_id;
		NEW.description 				= crt.description;
		NEW.valid_from 					= crt.valid_from;
		NEW.valid_to 					= crt.valid_to;
		NEW.x509_revocation_date 		= crt.x509_revocation_date;
		NEW.x509_revocation_reason 		= crt.x509_revocation_reason;
		NEW.passphrase 					= key.passphrase;
		NEW.encryption_key_id 			= key.encryption_key_id;
		NEW.ocsp_uri 					= crt.ocsp_uri;
		NEW.crl_uri 					= crt.crl_uri;
		NEW.data_ins_user 				= crt.data_ins_user;
		NEW.data_ins_date 				= crt.data_ins_date;
		NEW.data_upd_user 				= crt.data_upd_user;
		NEW.data_upd_date 				= crt.data_upd_date;
	END IF;
	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands_legacy.x509_certificate_ins() FROM public;
CREATE TRIGGER trigger_x509_certificate_ins INSTEAD OF INSERT ON jazzhands_legacy.x509_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands_legacy.x509_certificate_ins();

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
			IF OLD.certificate_signing_request IS DISTINCT FROM key.certificate_signing_request THEN
				_uq := array_append(_uq,
					'certificate_signing_request = ' || quote_nullable(NEW.certificate_signing_request)
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
CREATE TRIGGER trigger_x509_certificate_upd INSTEAD OF UPDATE ON jazzhands_legacy.x509_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands_legacy.x509_certificate_upd();

DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('x509_certificate');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for x509_certificate  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE x509_certificate (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('x509_certificate');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old x509_certificate failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('x509_certificate');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new x509_certificate failed but that is ok';
	NULL;
END;
$$;

--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE x509_signed_certificate
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'x509_signed_certificate', 'x509_signed_certificate');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'x509_signed_certificate', tags := ARRAY['view_x509_signed_certificate']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.x509_signed_certificate;
CREATE VIEW jazzhands_legacy.x509_signed_certificate AS
 SELECT x509_signed_certificate.x509_signed_certificate_id,
    x509_signed_certificate.x509_certificate_type,
    x509_signed_certificate.subject,
    x509_signed_certificate.friendly_name,
    x509_signed_certificate.subject_key_identifier,
    x509_signed_certificate.public_key_hash_id,
    x509_signed_certificate.description,
        CASE
            WHEN x509_signed_certificate.is_active IS NULL THEN NULL::text
            WHEN x509_signed_certificate.is_active = true THEN 'Y'::text
            WHEN x509_signed_certificate.is_active = false THEN 'N'::text
            ELSE NULL::text
        END AS is_active,
        CASE
            WHEN x509_signed_certificate.is_certificate_authority IS NULL THEN NULL::text
            WHEN x509_signed_certificate.is_certificate_authority = true THEN 'Y'::text
            WHEN x509_signed_certificate.is_certificate_authority = false THEN 'N'::text
            ELSE NULL::text
        END AS is_certificate_authority,
    x509_signed_certificate.signing_cert_id,
    x509_signed_certificate.x509_ca_cert_serial_number,
    x509_signed_certificate.public_key,
    x509_signed_certificate.private_key_id,
    x509_signed_certificate.certificate_signing_request_id,
    x509_signed_certificate.valid_from,
    x509_signed_certificate.valid_to,
    x509_signed_certificate.x509_revocation_date,
    x509_signed_certificate.x509_revocation_reason,
    x509_signed_certificate.ocsp_uri,
    x509_signed_certificate.crl_uri,
    x509_signed_certificate.data_ins_user,
    x509_signed_certificate.data_ins_date,
    x509_signed_certificate.data_upd_user,
    x509_signed_certificate.data_upd_date
   FROM jazzhands.x509_signed_certificate;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('x509_signed_certificate','x509_signed_certificate');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of x509_signed_certificate failed but that is ok';
	NULL;
END;
$$;

-- just in case
SELECT schema_support.prepare_for_object_replay();
ALTER TABLE jazzhands_legacy.x509_signed_certificate
	ALTER x509_certificate_type
	SET DEFAULT 'default'::character varying;
ALTER TABLE jazzhands_legacy.x509_signed_certificate
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE jazzhands_legacy.x509_signed_certificate
	ALTER is_certificate_authority
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- considering NEW jazzhands_legacy.x509_signed_certificate_del
CREATE OR REPLACE FUNCTION jazzhands_legacy.x509_signed_certificate_del()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_or	jazzhands.x509_signed_certificate%rowtype;
BEGIN
	DELETE FROM jazzhands.x509_signed_certificate
	WHERE  x509_signed_certificate_id = OLD.x509_signed_certificate_id  RETURNING *
	INTO _or;
	OLD.x509_signed_certificate_id = _or.x509_signed_certificate_id;
	OLD.x509_certificate_type = _or.x509_certificate_type;
	OLD.subject = _or.subject;
	OLD.friendly_name = _or.friendly_name;
	OLD.subject_key_identifier = _or.subject_key_identifier;
	OLD.public_key_hash_id = _or.public_key_hash_id;
	OLD.description = _or.description;
	OLD.is_active = CASE WHEN _or.is_active = true THEN 'Y' WHEN _or.is_active = false THEN 'N' ELSE NULL END;
	OLD.is_certificate_authority = CASE WHEN _or.is_certificate_authority = true THEN 'Y' WHEN _or.is_certificate_authority = false THEN 'N' ELSE NULL END;
	OLD.signing_cert_id = _or.signing_cert_id;
	OLD.x509_ca_cert_serial_number = _or.x509_ca_cert_serial_number;
	OLD.public_key = _or.public_key;
	OLD.private_key_id = _or.private_key_id;
	OLD.certificate_signing_request_id = _or.certificate_signing_request_id;
	OLD.valid_from = _or.valid_from;
	OLD.valid_to = _or.valid_to;
	OLD.x509_revocation_date = _or.x509_revocation_date;
	OLD.x509_revocation_reason = _or.x509_revocation_reason;
	OLD.ocsp_uri = _or.ocsp_uri;
	OLD.crl_uri = _or.crl_uri;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands_legacy.x509_signed_certificate_del() FROM public;
CREATE TRIGGER trigger_x509_signed_certificate_del INSTEAD OF DELETE ON jazzhands_legacy.x509_signed_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands_legacy.x509_signed_certificate_del();

-- considering NEW jazzhands_legacy.x509_signed_certificate_ins
CREATE OR REPLACE FUNCTION jazzhands_legacy.x509_signed_certificate_ins()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.x509_signed_certificate%rowtype;
BEGIN

	IF NEW.x509_signed_certificate_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('x509_signed_certificate_id'));
		_vq := array_append(_vq, quote_nullable(NEW.x509_signed_certificate_id));
	END IF;

	IF NEW.x509_certificate_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('x509_certificate_type'));
		_vq := array_append(_vq, quote_nullable(NEW.x509_certificate_type));
	END IF;

	IF NEW.subject IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('subject'));
		_vq := array_append(_vq, quote_nullable(NEW.subject));
	END IF;

	IF NEW.friendly_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('friendly_name'));
		_vq := array_append(_vq, quote_nullable(NEW.friendly_name));
	END IF;

	IF NEW.subject_key_identifier IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('subject_key_identifier'));
		_vq := array_append(_vq, quote_nullable(NEW.subject_key_identifier));
	END IF;

	IF NEW.public_key_hash_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('public_key_hash_id'));
		_vq := array_append(_vq, quote_nullable(NEW.public_key_hash_id));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.is_active IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_active'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_active = 'Y' THEN true WHEN NEW.is_active = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.is_certificate_authority IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_certificate_authority'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_certificate_authority = 'Y' THEN true WHEN NEW.is_certificate_authority = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.signing_cert_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('signing_cert_id'));
		_vq := array_append(_vq, quote_nullable(NEW.signing_cert_id));
	END IF;

	IF NEW.x509_ca_cert_serial_number IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('x509_ca_cert_serial_number'));
		_vq := array_append(_vq, quote_nullable(NEW.x509_ca_cert_serial_number));
	END IF;

	IF NEW.public_key IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('public_key'));
		_vq := array_append(_vq, quote_nullable(NEW.public_key));
	END IF;

	IF NEW.private_key_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('private_key_id'));
		_vq := array_append(_vq, quote_nullable(NEW.private_key_id));
	END IF;

	IF NEW.certificate_signing_request_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('certificate_signing_request_id'));
		_vq := array_append(_vq, quote_nullable(NEW.certificate_signing_request_id));
	END IF;

	IF NEW.valid_from IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('valid_from'));
		_vq := array_append(_vq, quote_nullable(NEW.valid_from));
	END IF;

	IF NEW.valid_to IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('valid_to'));
		_vq := array_append(_vq, quote_nullable(NEW.valid_to));
	END IF;

	IF NEW.x509_revocation_date IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('x509_revocation_date'));
		_vq := array_append(_vq, quote_nullable(NEW.x509_revocation_date));
	END IF;

	IF NEW.x509_revocation_reason IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('x509_revocation_reason'));
		_vq := array_append(_vq, quote_nullable(NEW.x509_revocation_reason));
	END IF;

	IF NEW.ocsp_uri IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('ocsp_uri'));
		_vq := array_append(_vq, quote_nullable(NEW.ocsp_uri));
	END IF;

	IF NEW.crl_uri IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('crl_uri'));
		_vq := array_append(_vq, quote_nullable(NEW.crl_uri));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.x509_signed_certificate (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.x509_signed_certificate_id = _nr.x509_signed_certificate_id;
	NEW.x509_certificate_type = _nr.x509_certificate_type;
	NEW.subject = _nr.subject;
	NEW.friendly_name = _nr.friendly_name;
	NEW.subject_key_identifier = _nr.subject_key_identifier;
	NEW.public_key_hash_id = _nr.public_key_hash_id;
	NEW.description = _nr.description;
	NEW.is_active = CASE WHEN _nr.is_active = true THEN 'Y' WHEN _nr.is_active = false THEN 'N' ELSE NULL END;
	NEW.is_certificate_authority = CASE WHEN _nr.is_certificate_authority = true THEN 'Y' WHEN _nr.is_certificate_authority = false THEN 'N' ELSE NULL END;
	NEW.signing_cert_id = _nr.signing_cert_id;
	NEW.x509_ca_cert_serial_number = _nr.x509_ca_cert_serial_number;
	NEW.public_key = _nr.public_key;
	NEW.private_key_id = _nr.private_key_id;
	NEW.certificate_signing_request_id = _nr.certificate_signing_request_id;
	NEW.valid_from = _nr.valid_from;
	NEW.valid_to = _nr.valid_to;
	NEW.x509_revocation_date = _nr.x509_revocation_date;
	NEW.x509_revocation_reason = _nr.x509_revocation_reason;
	NEW.ocsp_uri = _nr.ocsp_uri;
	NEW.crl_uri = _nr.crl_uri;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands_legacy.x509_signed_certificate_ins() FROM public;
CREATE TRIGGER trigger_x509_signed_certificate_ins INSTEAD OF INSERT ON jazzhands_legacy.x509_signed_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands_legacy.x509_signed_certificate_ins();

-- considering NEW jazzhands_legacy.x509_signed_certificate_upd
CREATE OR REPLACE FUNCTION jazzhands_legacy.x509_signed_certificate_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_r	jazzhands_legacy.x509_signed_certificate%rowtype;
	_nr	jazzhands.x509_signed_certificate%rowtype;
	_uq	text[];
BEGIN

	IF OLD.x509_signed_certificate_id IS DISTINCT FROM NEW.x509_signed_certificate_id THEN
_uq := array_append(_uq, 'x509_signed_certificate_id = ' || quote_nullable(NEW.x509_signed_certificate_id));
	END IF;

	IF OLD.x509_certificate_type IS DISTINCT FROM NEW.x509_certificate_type THEN
_uq := array_append(_uq, 'x509_certificate_type = ' || quote_nullable(NEW.x509_certificate_type));
	END IF;

	IF OLD.subject IS DISTINCT FROM NEW.subject THEN
_uq := array_append(_uq, 'subject = ' || quote_nullable(NEW.subject));
	END IF;

	IF OLD.friendly_name IS DISTINCT FROM NEW.friendly_name THEN
_uq := array_append(_uq, 'friendly_name = ' || quote_nullable(NEW.friendly_name));
	END IF;

	IF OLD.subject_key_identifier IS DISTINCT FROM NEW.subject_key_identifier THEN
_uq := array_append(_uq, 'subject_key_identifier = ' || quote_nullable(NEW.subject_key_identifier));
	END IF;

	IF OLD.public_key_hash_id IS DISTINCT FROM NEW.public_key_hash_id THEN
_uq := array_append(_uq, 'public_key_hash_id = ' || quote_nullable(NEW.public_key_hash_id));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
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
_uq := array_append(_uq, 'signing_cert_id = ' || quote_nullable(NEW.signing_cert_id));
	END IF;

	IF OLD.x509_ca_cert_serial_number IS DISTINCT FROM NEW.x509_ca_cert_serial_number THEN
_uq := array_append(_uq, 'x509_ca_cert_serial_number = ' || quote_nullable(NEW.x509_ca_cert_serial_number));
	END IF;

	IF OLD.public_key IS DISTINCT FROM NEW.public_key THEN
_uq := array_append(_uq, 'public_key = ' || quote_nullable(NEW.public_key));
	END IF;

	IF OLD.private_key_id IS DISTINCT FROM NEW.private_key_id THEN
_uq := array_append(_uq, 'private_key_id = ' || quote_nullable(NEW.private_key_id));
	END IF;

	IF OLD.certificate_signing_request_id IS DISTINCT FROM NEW.certificate_signing_request_id THEN
_uq := array_append(_uq, 'certificate_signing_request_id = ' || quote_nullable(NEW.certificate_signing_request_id));
	END IF;

	IF OLD.valid_from IS DISTINCT FROM NEW.valid_from THEN
_uq := array_append(_uq, 'valid_from = ' || quote_nullable(NEW.valid_from));
	END IF;

	IF OLD.valid_to IS DISTINCT FROM NEW.valid_to THEN
_uq := array_append(_uq, 'valid_to = ' || quote_nullable(NEW.valid_to));
	END IF;

	IF OLD.x509_revocation_date IS DISTINCT FROM NEW.x509_revocation_date THEN
_uq := array_append(_uq, 'x509_revocation_date = ' || quote_nullable(NEW.x509_revocation_date));
	END IF;

	IF OLD.x509_revocation_reason IS DISTINCT FROM NEW.x509_revocation_reason THEN
_uq := array_append(_uq, 'x509_revocation_reason = ' || quote_nullable(NEW.x509_revocation_reason));
	END IF;

	IF OLD.ocsp_uri IS DISTINCT FROM NEW.ocsp_uri THEN
_uq := array_append(_uq, 'ocsp_uri = ' || quote_nullable(NEW.ocsp_uri));
	END IF;

	IF OLD.crl_uri IS DISTINCT FROM NEW.crl_uri THEN
_uq := array_append(_uq, 'crl_uri = ' || quote_nullable(NEW.crl_uri));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.x509_signed_certificate SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  x509_signed_certificate_id = $1 RETURNING *'  USING OLD.x509_signed_certificate_id
			INTO _nr;

		NEW.x509_signed_certificate_id = _nr.x509_signed_certificate_id;
		NEW.x509_certificate_type = _nr.x509_certificate_type;
		NEW.subject = _nr.subject;
		NEW.friendly_name = _nr.friendly_name;
		NEW.subject_key_identifier = _nr.subject_key_identifier;
		NEW.public_key_hash_id = _nr.public_key_hash_id;
		NEW.description = _nr.description;
		NEW.is_active = CASE WHEN _nr.is_active = true THEN 'Y' WHEN _nr.is_active = false THEN 'N' ELSE NULL END;
		NEW.is_certificate_authority = CASE WHEN _nr.is_certificate_authority = true THEN 'Y' WHEN _nr.is_certificate_authority = false THEN 'N' ELSE NULL END;
		NEW.signing_cert_id = _nr.signing_cert_id;
		NEW.x509_ca_cert_serial_number = _nr.x509_ca_cert_serial_number;
		NEW.public_key = _nr.public_key;
		NEW.private_key_id = _nr.private_key_id;
		NEW.certificate_signing_request_id = _nr.certificate_signing_request_id;
		NEW.valid_from = _nr.valid_from;
		NEW.valid_to = _nr.valid_to;
		NEW.x509_revocation_date = _nr.x509_revocation_date;
		NEW.x509_revocation_reason = _nr.x509_revocation_reason;
		NEW.ocsp_uri = _nr.ocsp_uri;
		NEW.crl_uri = _nr.crl_uri;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands_legacy.x509_signed_certificate_upd() FROM public;
CREATE TRIGGER trigger_x509_signed_certificate_upd INSTEAD OF UPDATE ON jazzhands_legacy.x509_signed_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands_legacy.x509_signed_certificate_upd();

DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('x509_signed_certificate');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for x509_signed_certificate  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE x509_signed_certificate (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('x509_signed_certificate');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old x509_signed_certificate failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('x509_signed_certificate');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new x509_signed_certificate failed but that is ok';
	NULL;
END;
$$;

--------------------------------------------------------------------
-- DEALING WITH NEW TABLE public_key_hash (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'public_key_hash');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_audit', 'public_key_hash');
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.public_key_hash;
CREATE VIEW jazzhands_legacy.public_key_hash AS
 SELECT public_key_hash.public_key_hash_id,
    public_key_hash.description,
    public_key_hash.data_ins_user,
    public_key_hash.data_ins_date,
    public_key_hash.data_upd_user,
    public_key_hash.data_upd_date
   FROM jazzhands.public_key_hash;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('public_key_hash','public_key_hash');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of public_key_hash failed but that is ok';
	NULL;
END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('public_key_hash');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for public_key_hash  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE public_key_hash (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('public_key_hash');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old public_key_hash failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('public_key_hash');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new public_key_hash failed but that is ok';
	NULL;
END;
$$;

--------------------------------------------------------------------
-- DEALING WITH NEW TABLE public_key_hash_hash (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'public_key_hash_hash');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_audit', 'public_key_hash_hash');
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.public_key_hash_hash;
CREATE VIEW jazzhands_legacy.public_key_hash_hash AS
 SELECT public_key_hash_hash.public_key_hash_id,
    public_key_hash_hash.x509_fingerprint_hash_algorighm,
    public_key_hash_hash.calculated_hash,
    public_key_hash_hash.data_ins_user,
    public_key_hash_hash.data_ins_date,
    public_key_hash_hash.data_upd_user,
    public_key_hash_hash.data_upd_date
   FROM jazzhands.public_key_hash_hash;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('public_key_hash_hash','public_key_hash_hash');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of public_key_hash_hash failed but that is ok';
	NULL;
END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('public_key_hash_hash');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for public_key_hash_hash  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE public_key_hash_hash (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('public_key_hash_hash');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old public_key_hash_hash failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('public_key_hash_hash');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new public_key_hash_hash failed but that is ok';
	NULL;
END;
$$;

--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_x509_fingerprint_hash_algorithm (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_x509_fingerprint_hash_algorithm');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_audit', 'val_x509_fingerprint_hash_algorithm');
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.val_x509_fingerprint_hash_algorithm;
CREATE VIEW jazzhands_legacy.val_x509_fingerprint_hash_algorithm AS
 SELECT val_x509_fingerprint_hash_algorithm.x509_fingerprint_hash_algorighm,
    val_x509_fingerprint_hash_algorithm.description,
    val_x509_fingerprint_hash_algorithm.data_ins_user,
    val_x509_fingerprint_hash_algorithm.data_ins_date,
    val_x509_fingerprint_hash_algorithm.data_upd_user,
    val_x509_fingerprint_hash_algorithm.data_upd_date
   FROM jazzhands.val_x509_fingerprint_hash_algorithm;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('val_x509_fingerprint_hash_algorithm','val_x509_fingerprint_hash_algorithm');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of val_x509_fingerprint_hash_algorithm failed but that is ok';
	NULL;
END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('val_x509_fingerprint_hash_algorithm');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_x509_fingerprint_hash_algorithm  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_x509_fingerprint_hash_algorithm (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('val_x509_fingerprint_hash_algorithm');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old val_x509_fingerprint_hash_algorithm failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('val_x509_fingerprint_hash_algorithm');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new val_x509_fingerprint_hash_algorithm failed but that is ok';
	NULL;
END;
$$;

--------------------------------------------------------------------
-- DEALING WITH NEW TABLE x509_signed_certificate_fingerprint (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'x509_signed_certificate_fingerprint');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_audit', 'x509_signed_certificate_fingerprint');
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.x509_signed_certificate_fingerprint;
CREATE VIEW jazzhands_legacy.x509_signed_certificate_fingerprint AS
 SELECT x509_signed_certificate_fingerprint.x509_signed_certificate_id,
    x509_signed_certificate_fingerprint.x509_fingerprint_hash_algorighm,
    x509_signed_certificate_fingerprint.fingerprint,
    x509_signed_certificate_fingerprint.description,
    x509_signed_certificate_fingerprint.data_ins_user,
    x509_signed_certificate_fingerprint.data_ins_date,
    x509_signed_certificate_fingerprint.data_upd_user,
    x509_signed_certificate_fingerprint.data_upd_date
   FROM jazzhands.x509_signed_certificate_fingerprint;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('x509_signed_certificate_fingerprint','x509_signed_certificate_fingerprint');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of x509_signed_certificate_fingerprint failed but that is ok';
	NULL;
END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('x509_signed_certificate_fingerprint');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for x509_signed_certificate_fingerprint  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE x509_signed_certificate_fingerprint (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('x509_signed_certificate_fingerprint');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old x509_signed_certificate_fingerprint failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('x509_signed_certificate_fingerprint');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new x509_signed_certificate_fingerprint failed but that is ok';
	NULL;
END;
$$;

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
ALTER TABLE private_key DROP CONSTRAINT IF EXISTS ak_private_key;
ALTER TABLE private_key
	DROP CONSTRAINT IF EXISTS ckc_external_id_mutually_exclusive_203372048;
ALTER TABLE private_key
ADD CONSTRAINT ckc_external_id_mutually_exclusive_203372048
	CHECK ((((private_key IS NOT NULL) AND (external_id IS NULL)) OR ((private_key IS NULL) AND (external_id IS NOT NULL))));

-- index
-- triggers
DROP TRIGGER IF EXISTS trigger_pvtkey_ski_signed_validate ON private_key;
DROP TRIGGER IF EXISTS trig_userlog_private_key ON private_key;
CREATE TRIGGER trig_userlog_private_key BEFORE INSERT OR UPDATE ON jazzhands.private_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_private_key ON private_key;
CREATE TRIGGER trigger_audit_private_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.private_key FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_private_key();
DROP TRIGGER IF EXISTS trigger_pvtkey_pkh_signed_validate ON private_key;
CREATE CONSTRAINT TRIGGER trigger_pvtkey_pkh_signed_validate AFTER UPDATE OF public_key_hash_id, private_key_id ON jazzhands.private_key NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.pvtkey_pkh_signed_validate();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_x509_certificate ON service_endpoint_x509_certificate;
CREATE TRIGGER trig_userlog_service_endpoint_x509_certificate BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_x509_certificate FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_x509_certificate ON service_endpoint_x509_certificate;
CREATE TRIGGER trigger_audit_service_endpoint_x509_certificate AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_x509_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_x509_certificate();
DROP TRIGGER IF EXISTS trig_userlog_val_private_key_encryption_type ON val_private_key_encryption_type;
CREATE TRIGGER trig_userlog_val_private_key_encryption_type BEFORE INSERT OR UPDATE ON jazzhands.val_private_key_encryption_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_private_key_encryption_type ON val_private_key_encryption_type;
CREATE TRIGGER trigger_audit_val_private_key_encryption_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_private_key_encryption_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_private_key_encryption_type();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_certificate_file_format ON val_x509_certificate_file_format;
CREATE TRIGGER trig_userlog_val_x509_certificate_file_format BEFORE INSERT OR UPDATE ON jazzhands.val_x509_certificate_file_format FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_certificate_file_format ON val_x509_certificate_file_format;
CREATE TRIGGER trigger_audit_val_x509_certificate_file_format AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_certificate_file_format FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_x509_certificate_file_format();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_certificate_type ON val_x509_certificate_type;
CREATE TRIGGER trig_userlog_val_x509_certificate_type BEFORE INSERT OR UPDATE ON jazzhands.val_x509_certificate_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_certificate_type ON val_x509_certificate_type;
CREATE TRIGGER trigger_audit_val_x509_certificate_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_certificate_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_x509_certificate_type();
DROP TRIGGER IF EXISTS trigger_x509_signed_ski_pvtkey_validate ON x509_signed_certificate;
DROP TRIGGER IF EXISTS trig_userlog_x509_signed_certificate ON x509_signed_certificate;
CREATE TRIGGER trig_userlog_x509_signed_certificate BEFORE INSERT OR UPDATE ON jazzhands.x509_signed_certificate FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_x509_signed_certificate ON x509_signed_certificate;
CREATE TRIGGER trigger_audit_x509_signed_certificate AFTER INSERT OR DELETE OR UPDATE ON jazzhands.x509_signed_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_x509_signed_certificate();
DROP TRIGGER IF EXISTS trigger_x509_signed_pkh_pvtkey_validate ON x509_signed_certificate;
CREATE CONSTRAINT TRIGGER trigger_x509_signed_pkh_pvtkey_validate AFTER INSERT OR UPDATE OF public_key_hash_id, private_key_id, certificate_signing_request_id ON jazzhands.x509_signed_certificate NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.x509_signed_pkh_pvtkey_validate();
DROP TRIGGER IF EXISTS trig_userlog_x509_signed_certificate_fingerprint ON x509_signed_certificate_fingerprint;
CREATE TRIGGER trig_userlog_x509_signed_certificate_fingerprint BEFORE INSERT OR UPDATE ON jazzhands.x509_signed_certificate_fingerprint FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_x509_signed_certificate_fingerprint ON x509_signed_certificate_fingerprint;
CREATE TRIGGER trigger_audit_x509_signed_certificate_fingerprint AFTER INSERT OR DELETE OR UPDATE ON jazzhands.x509_signed_certificate_fingerprint FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_x509_signed_certificate_fingerprint();

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
SAVEPOINT beforecache;
-- skipping this this time around
-- SELECT schema_support.synchronize_cache_tables();

--
-- END: Running final cache table sync
SAVEPOINT beforereset;
-- SELECT schema_support.reset_all_schema_table_sequences('jazzhands');
-- SELECT schema_support.reset_all_schema_table_sequences('jazzhands_audit');
SELECT schema_support.reset_table_sequence(schema := 'jazzhands', table_name := 'certificate_signing_request');
SELECT schema_support.reset_table_sequence(schema := 'jazzhands', table_name := 'private_key');
SELECT schema_support.reset_table_sequence(schema := 'jazzhands', table_name := 'x509_certificate');

SELECT schema_support.reset_table_sequence(schema := 'jazzhands_audit', table_name := 'certificate_signing_request');
SELECT schema_support.reset_table_sequence(schema := 'jazzhands_audit', table_name := 'private_key');
SELECT schema_support.reset_table_sequence(schema := 'jazzhands_audit', table_name := 'x509_certificate');

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
