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
	SELECT	public_key_hash_id, id
	INTO	pkhid, id
	FROM	x509_signed_certificate x
	WHERE	x.private_key_id = NEW.private_key_id;

	IF FOUND AND pkhid != NEW.public_key_hash_id THEN
		RAISE EXCEPTION 'public_key_hash_id must match in x509_signed_certificate_id and private_key' USING ERRCODE = 'foreign_key_violation';
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
	IF NEW.private_key_id IS NULL THEN
		RETURN NEW;
	END IF;

	SELECT	public_key_hash_id, id
	INTO	pkhid, id
	FROM	private_key p
	WHERE	p.private_key_id = NEW.private_key_id;

	IF FOUND AND pkhid != NEW.public_key_hash_id THEN
		RAISE EXCEPTION 'public_key_hash_id must match in x509_signed_certificate_id and private_key' USING ERRCODE = 'foreign_key_violation';
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
--
-- BEGIN: process_ancillary_schema(jazzhands_legacy)
--
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
    private_key.private_key,
    private_key.passphrase,
    private_key.encryption_key_id,
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
	OLD.private_key = _or.private_key;
	OLD.passphrase = _or.passphrase;
	OLD.encryption_key_id = _or.encryption_key_id;
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

	EXECUTE 'INSERT INTO jazzhands.private_key (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.private_key_id = _nr.private_key_id;
	NEW.private_key_encryption_type = _nr.private_key_encryption_type;
	NEW.is_active = CASE WHEN _nr.is_active = true THEN 'Y' WHEN _nr.is_active = false THEN 'N' ELSE NULL END;
	NEW.subject_key_identifier = NULL;
	NEW.private_key = _nr.private_key;
	NEW.passphrase = _nr.passphrase;
	NEW.encryption_key_id = _nr.encryption_key_id;
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

	IF OLD.private_key IS DISTINCT FROM NEW.private_key THEN
_uq := array_append(_uq, 'private_key = ' || quote_nullable(NEW.private_key));
	END IF;

	IF OLD.passphrase IS DISTINCT FROM NEW.passphrase THEN
_uq := array_append(_uq, 'passphrase = ' || quote_nullable(NEW.passphrase));
	END IF;

	IF OLD.encryption_key_id IS DISTINCT FROM NEW.encryption_key_id THEN
_uq := array_append(_uq, 'encryption_key_id = ' || quote_nullable(NEW.encryption_key_id));
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
		NEW.private_key = _nr.private_key;
		NEW.passphrase = _nr.passphrase;
		NEW.encryption_key_id = _nr.encryption_key_id;
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
		IF NEW.subject_key_identifier IS NOT NULL THEN
			SELECT *
			INTO key
			FROM private_key
			WHERE subject_key_identifier = NEW.subject_key_identifier;

			SELECT private_key
			INTO NEW.private_key
			FROM private_key
			WHERE private_key_id = key.private_key_id;
		END IF;
	END IF;

	IF NEW.certificate_sign_req IS NOT NULL THEN
		INSERT INTO jazzhands.certificate_signing_request (
			friendly_name,
			subject,
			certificate_signing_request,
			private_key_id
		) VALUES (
			NEW.friendly_name,
			NEW.subject,
			NEW.certificate_sign_req,
			key.private_key_id
		) RETURNING * INTO csr;
		IF NEW.x509_cert_id IS NULL THEN
			NEW.x509_cert_id := csr.certificate_signing_request_id;
		END IF;
	ELSE
		IF NEW.subject_key_identifier IS NOT NULL THEN
			SELECT certificate_signing_request_id
			INTO csr
			FROM certificate_signing_request
				JOIN private_key USING (private_key_id)
			WHERE subject_key_identifier = NEW.subject_key_identifier
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
		NEW.description 			= crt.description;
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
			private_key_id
		) VALUES (
			NEW.friendly_name,
			NEW.subject,
			NEW.certificate_sign_req,
			key.private_key_id
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
			IF OLD.private_key IS DISTINCT FROM key.private_key THEN
				_uq := array_append(_uq,
					'private_key = ' || quote_nullable(NEW.private_key)
				);
			END IF;

			IF array_length(_uq, 1) > 0 THEN
				EXECUTE format('UPDATE private_key SET %s WHERE private_key_id = $1 RETURNING *',
					array_to_string(_uq, ', '))
					USING crt.private_key_id
					INTO key;
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
DROP TRIGGER IF EXISTS trig_account_change_realm_aca_realm ON account;
CREATE TRIGGER trig_account_change_realm_aca_realm BEFORE UPDATE OF account_realm_id ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.account_change_realm_aca_realm();
DROP TRIGGER IF EXISTS trig_add_account_automated_reporting_ac ON account;
CREATE TRIGGER trig_add_account_automated_reporting_ac AFTER INSERT OR UPDATE OF login, account_status ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.account_automated_reporting_ac();
DROP TRIGGER IF EXISTS trig_add_automated_ac_on_account ON account;
CREATE TRIGGER trig_add_automated_ac_on_account AFTER INSERT OR UPDATE OF account_type, account_role, account_status ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.automated_ac_on_account();
DROP TRIGGER IF EXISTS trig_rm_account_automated_reporting_ac ON account;
CREATE TRIGGER trig_rm_account_automated_reporting_ac BEFORE DELETE ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.account_automated_reporting_ac();
DROP TRIGGER IF EXISTS trig_rm_automated_ac_on_account ON account;
CREATE TRIGGER trig_rm_automated_ac_on_account BEFORE DELETE ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.automated_ac_on_account();
DROP TRIGGER IF EXISTS trig_userlog_account ON account;
CREATE TRIGGER trig_userlog_account BEFORE INSERT OR UPDATE ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_account_enforce_is_enabled ON account;
CREATE TRIGGER trigger_account_enforce_is_enabled BEFORE INSERT OR UPDATE OF account_status, is_enabled ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.account_enforce_is_enabled();
DROP TRIGGER IF EXISTS trigger_account_status_per_row_after_hooks ON account;
CREATE TRIGGER trigger_account_status_per_row_after_hooks AFTER UPDATE OF account_status ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.account_status_per_row_after_hooks();
DROP TRIGGER IF EXISTS trigger_account_validate_login ON account;
CREATE TRIGGER trigger_account_validate_login BEFORE INSERT OR UPDATE OF login ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.account_validate_login();
DROP TRIGGER IF EXISTS trigger_audit_account ON account;
CREATE TRIGGER trigger_audit_account AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account();
DROP TRIGGER IF EXISTS trigger_create_new_unix_account ON account;
CREATE TRIGGER trigger_create_new_unix_account AFTER INSERT ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.create_new_unix_account();
DROP TRIGGER IF EXISTS trigger_delete_peraccount_account_collection ON account;
CREATE TRIGGER trigger_delete_peraccount_account_collection BEFORE DELETE ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.delete_peraccount_account_collection();
DROP TRIGGER IF EXISTS trigger_update_peraccount_account_collection ON account;
CREATE TRIGGER trigger_update_peraccount_account_collection AFTER INSERT OR UPDATE ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.update_peraccount_account_collection();
DROP TRIGGER IF EXISTS trig_userlog_account_assigned_certificate ON account_assigned_certificate;
CREATE TRIGGER trig_userlog_account_assigned_certificate BEFORE INSERT OR UPDATE ON jazzhands.account_assigned_certificate FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_assigned_certificate ON account_assigned_certificate;
CREATE TRIGGER trigger_audit_account_assigned_certificate AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_assigned_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_assigned_certificate();
DROP TRIGGER IF EXISTS trig_userlog_account_authentication_log ON account_authentication_log;
CREATE TRIGGER trig_userlog_account_authentication_log BEFORE INSERT OR UPDATE ON jazzhands.account_authentication_log FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_authentication_log ON account_authentication_log;
CREATE TRIGGER trigger_audit_account_authentication_log AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_authentication_log FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_authentication_log();
DROP TRIGGER IF EXISTS aaa_account_collection_base_handler ON account_collection;
CREATE TRIGGER aaa_account_collection_base_handler AFTER INSERT OR DELETE OR UPDATE OF account_collection_id ON jazzhands.account_collection FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.account_collection_base_handler();
DROP TRIGGER IF EXISTS trig_account_collection_realm ON account_collection;
CREATE TRIGGER trig_account_collection_realm AFTER UPDATE OF account_collection_type ON jazzhands.account_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.account_collection_realm();
DROP TRIGGER IF EXISTS trig_userlog_account_collection ON account_collection;
CREATE TRIGGER trig_userlog_account_collection BEFORE INSERT OR UPDATE ON jazzhands.account_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_collection ON account_collection;
CREATE TRIGGER trigger_audit_account_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_collection();
DROP TRIGGER IF EXISTS trigger_validate_account_collection_type_change ON account_collection;
CREATE TRIGGER trigger_validate_account_collection_type_change BEFORE UPDATE OF account_collection_type ON jazzhands.account_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_account_collection_type_change();
DROP TRIGGER IF EXISTS trig_account_collection_account_realm ON account_collection_account;
CREATE TRIGGER trig_account_collection_account_realm AFTER INSERT OR UPDATE ON jazzhands.account_collection_account FOR EACH ROW EXECUTE FUNCTION jazzhands.account_collection_account_realm();
DROP TRIGGER IF EXISTS trig_userlog_account_collection_account ON account_collection_account;
CREATE TRIGGER trig_userlog_account_collection_account BEFORE INSERT OR UPDATE ON jazzhands.account_collection_account FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_account_coll_member_relation_enforce ON account_collection_account;
CREATE CONSTRAINT TRIGGER trigger_account_coll_member_relation_enforce AFTER INSERT OR UPDATE ON jazzhands.account_collection_account DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.account_coll_member_relation_enforce();
DROP TRIGGER IF EXISTS trigger_account_collection_member_enforce ON account_collection_account;
CREATE CONSTRAINT TRIGGER trigger_account_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.account_collection_account DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.account_collection_member_enforce();
DROP TRIGGER IF EXISTS trigger_audit_account_collection_account ON account_collection_account;
CREATE TRIGGER trigger_audit_account_collection_account AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_collection_account FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_collection_account();
DROP TRIGGER IF EXISTS trigger_pgnotify_account_collection_account_token_changes ON account_collection_account;
CREATE TRIGGER trigger_pgnotify_account_collection_account_token_changes AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_collection_account FOR EACH ROW EXECUTE FUNCTION jazzhands.pgnotify_account_collection_account_token_changes();
DROP TRIGGER IF EXISTS aaa_account_collection_root_handler ON account_collection_hier;
CREATE TRIGGER aaa_account_collection_root_handler AFTER INSERT OR DELETE OR UPDATE OF account_collection_id, child_account_collection_id ON jazzhands.account_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.account_collection_root_handler();
DROP TRIGGER IF EXISTS trig_account_collection_hier_realm ON account_collection_hier;
CREATE TRIGGER trig_account_collection_hier_realm AFTER INSERT OR UPDATE ON jazzhands.account_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.account_collection_hier_realm();
DROP TRIGGER IF EXISTS trig_userlog_account_collection_hier ON account_collection_hier;
CREATE TRIGGER trig_userlog_account_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.account_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_account_collection_hier_enforce ON account_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_account_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.account_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.account_collection_hier_enforce();
DROP TRIGGER IF EXISTS trigger_audit_account_collection_hier ON account_collection_hier;
CREATE TRIGGER trigger_audit_account_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_collection_hier();
DROP TRIGGER IF EXISTS trigger_check_account_collection_hier_loop ON account_collection_hier;
CREATE TRIGGER trigger_check_account_collection_hier_loop AFTER INSERT OR UPDATE ON jazzhands.account_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.check_account_colllection_hier_loop();
DROP TRIGGER IF EXISTS trig_userlog_account_collection_type_relation ON account_collection_type_relation;
CREATE TRIGGER trig_userlog_account_collection_type_relation BEFORE INSERT OR UPDATE ON jazzhands.account_collection_type_relation FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_collection_type_relation ON account_collection_type_relation;
CREATE TRIGGER trigger_audit_account_collection_type_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_collection_type_relation FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_collection_type_relation();
DROP TRIGGER IF EXISTS trig_userlog_account_password ON account_password;
CREATE TRIGGER trig_userlog_account_password BEFORE INSERT OR UPDATE ON jazzhands.account_password FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_password ON account_password;
CREATE TRIGGER trigger_audit_account_password AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_password FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_password();
DROP TRIGGER IF EXISTS trigger_pgnotify_account_password_changes ON account_password;
CREATE TRIGGER trigger_pgnotify_account_password_changes AFTER INSERT OR UPDATE ON jazzhands.account_password FOR EACH ROW EXECUTE FUNCTION jazzhands.pgnotify_account_password_changes();
DROP TRIGGER IF EXISTS trigger_pull_password_account_realm_from_account ON account_password;
CREATE TRIGGER trigger_pull_password_account_realm_from_account BEFORE INSERT OR UPDATE OF account_id ON jazzhands.account_password FOR EACH ROW EXECUTE FUNCTION jazzhands.pull_password_account_realm_from_account();
DROP TRIGGER IF EXISTS trigger_unrequire_password_change ON account_password;
CREATE TRIGGER trigger_unrequire_password_change BEFORE INSERT OR UPDATE OF password ON jazzhands.account_password FOR EACH ROW EXECUTE FUNCTION jazzhands.unrequire_password_change();
DROP TRIGGER IF EXISTS trig_userlog_account_realm ON account_realm;
CREATE TRIGGER trig_userlog_account_realm BEFORE INSERT OR UPDATE ON jazzhands.account_realm FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_realm ON account_realm;
CREATE TRIGGER trigger_audit_account_realm AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_realm FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_realm();
DROP TRIGGER IF EXISTS trig_userlog_account_realm_account_collection_type ON account_realm_account_collection_type;
CREATE TRIGGER trig_userlog_account_realm_account_collection_type BEFORE INSERT OR UPDATE ON jazzhands.account_realm_account_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_realm_account_collection_type ON account_realm_account_collection_type;
CREATE TRIGGER trigger_audit_account_realm_account_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_realm_account_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_realm_account_collection_type();
DROP TRIGGER IF EXISTS trig_userlog_account_realm_company ON account_realm_company;
CREATE TRIGGER trig_userlog_account_realm_company BEFORE INSERT OR UPDATE ON jazzhands.account_realm_company FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_realm_company ON account_realm_company;
CREATE TRIGGER trigger_audit_account_realm_company AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_realm_company FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_realm_company();
DROP TRIGGER IF EXISTS trig_userlog_account_realm_password_type ON account_realm_password_type;
CREATE TRIGGER trig_userlog_account_realm_password_type BEFORE INSERT OR UPDATE ON jazzhands.account_realm_password_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_realm_password_type ON account_realm_password_type;
CREATE TRIGGER trigger_audit_account_realm_password_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_realm_password_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_realm_password_type();
DROP TRIGGER IF EXISTS trig_userlog_account_ssh_key ON account_ssh_key;
CREATE TRIGGER trig_userlog_account_ssh_key BEFORE INSERT OR UPDATE ON jazzhands.account_ssh_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_ssh_key ON account_ssh_key;
CREATE TRIGGER trigger_audit_account_ssh_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_ssh_key FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_ssh_key();
DROP TRIGGER IF EXISTS trig_userlog_account_token ON account_token;
CREATE TRIGGER trig_userlog_account_token BEFORE INSERT OR UPDATE ON jazzhands.account_token FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_token ON account_token;
CREATE TRIGGER trigger_audit_account_token AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_token FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_token();
DROP TRIGGER IF EXISTS trigger_pgnotify_account_token_change ON account_token;
CREATE TRIGGER trigger_pgnotify_account_token_change AFTER INSERT OR UPDATE ON jazzhands.account_token FOR EACH ROW EXECUTE FUNCTION jazzhands.pgnotify_account_token_change();
DROP TRIGGER IF EXISTS trig_userlog_account_unix_info ON account_unix_info;
CREATE TRIGGER trig_userlog_account_unix_info BEFORE INSERT OR UPDATE ON jazzhands.account_unix_info FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_unix_info ON account_unix_info;
CREATE TRIGGER trigger_audit_account_unix_info AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_unix_info FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_unix_info();
DROP TRIGGER IF EXISTS trig_userlog_appaal ON appaal;
CREATE TRIGGER trig_userlog_appaal BEFORE INSERT OR UPDATE ON jazzhands.appaal FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_appaal ON appaal;
CREATE TRIGGER trigger_audit_appaal AFTER INSERT OR DELETE OR UPDATE ON jazzhands.appaal FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_appaal();
DROP TRIGGER IF EXISTS trig_userlog_appaal_instance ON appaal_instance;
CREATE TRIGGER trig_userlog_appaal_instance BEFORE INSERT OR UPDATE ON jazzhands.appaal_instance FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_appaal_instance ON appaal_instance;
CREATE TRIGGER trigger_audit_appaal_instance AFTER INSERT OR DELETE OR UPDATE ON jazzhands.appaal_instance FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_appaal_instance();
DROP TRIGGER IF EXISTS trig_userlog_appaal_instance_device_collection ON appaal_instance_device_collection;
CREATE TRIGGER trig_userlog_appaal_instance_device_collection BEFORE INSERT OR UPDATE ON jazzhands.appaal_instance_device_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_appaal_instance_device_collection ON appaal_instance_device_collection;
CREATE TRIGGER trigger_audit_appaal_instance_device_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.appaal_instance_device_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_appaal_instance_device_collection();
DROP TRIGGER IF EXISTS trig_userlog_appaal_instance_property ON appaal_instance_property;
CREATE TRIGGER trig_userlog_appaal_instance_property BEFORE INSERT OR UPDATE ON jazzhands.appaal_instance_property FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_appaal_instance_property ON appaal_instance_property;
CREATE TRIGGER trigger_audit_appaal_instance_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.appaal_instance_property FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_appaal_instance_property();
DROP TRIGGER IF EXISTS trig_userlog_approval_instance ON approval_instance;
CREATE TRIGGER trig_userlog_approval_instance BEFORE INSERT OR UPDATE ON jazzhands.approval_instance FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_approval_instance ON approval_instance;
CREATE TRIGGER trigger_audit_approval_instance AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_instance FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_approval_instance();
DROP TRIGGER IF EXISTS trig_userlog_approval_instance_item ON approval_instance_item;
CREATE TRIGGER trig_userlog_approval_instance_item BEFORE INSERT OR UPDATE ON jazzhands.approval_instance_item FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_approval_instance_item_approval_notify ON approval_instance_item;
CREATE TRIGGER trigger_approval_instance_item_approval_notify AFTER INSERT OR UPDATE OF is_approved ON jazzhands.approval_instance_item FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.approval_instance_item_approval_notify();
DROP TRIGGER IF EXISTS trigger_approval_instance_item_approved_immutable ON approval_instance_item;
CREATE TRIGGER trigger_approval_instance_item_approved_immutable BEFORE UPDATE OF is_approved ON jazzhands.approval_instance_item FOR EACH ROW EXECUTE FUNCTION jazzhands.approval_instance_item_approved_immutable();
DROP TRIGGER IF EXISTS trigger_approval_instance_step_auto_complete ON approval_instance_item;
CREATE TRIGGER trigger_approval_instance_step_auto_complete AFTER INSERT OR UPDATE OF is_approved ON jazzhands.approval_instance_item FOR EACH ROW EXECUTE FUNCTION jazzhands.approval_instance_step_auto_complete();
DROP TRIGGER IF EXISTS trigger_audit_approval_instance_item ON approval_instance_item;
CREATE TRIGGER trigger_audit_approval_instance_item AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_instance_item FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_approval_instance_item();
DROP TRIGGER IF EXISTS trig_userlog_approval_instance_link ON approval_instance_link;
CREATE TRIGGER trig_userlog_approval_instance_link BEFORE INSERT OR UPDATE ON jazzhands.approval_instance_link FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_approval_instance_link ON approval_instance_link;
CREATE TRIGGER trigger_audit_approval_instance_link AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_instance_link FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_approval_instance_link();
DROP TRIGGER IF EXISTS trig_userlog_approval_instance_step ON approval_instance_step;
CREATE TRIGGER trig_userlog_approval_instance_step BEFORE INSERT OR UPDATE ON jazzhands.approval_instance_step FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_approval_instance_step_completed_immutable ON approval_instance_step;
CREATE TRIGGER trigger_approval_instance_step_completed_immutable BEFORE UPDATE OF is_completed ON jazzhands.approval_instance_step FOR EACH ROW EXECUTE FUNCTION jazzhands.approval_instance_step_completed_immutable();
DROP TRIGGER IF EXISTS trigger_approval_instance_step_resolve_instance ON approval_instance_step;
CREATE TRIGGER trigger_approval_instance_step_resolve_instance AFTER UPDATE OF is_completed ON jazzhands.approval_instance_step FOR EACH ROW EXECUTE FUNCTION jazzhands.approval_instance_step_resolve_instance();
DROP TRIGGER IF EXISTS trigger_audit_approval_instance_step ON approval_instance_step;
CREATE TRIGGER trigger_audit_approval_instance_step AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_instance_step FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_approval_instance_step();
DROP TRIGGER IF EXISTS trig_userlog_approval_instance_step_notify ON approval_instance_step_notify;
CREATE TRIGGER trig_userlog_approval_instance_step_notify BEFORE INSERT OR UPDATE ON jazzhands.approval_instance_step_notify FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_approval_instance_step_notify ON approval_instance_step_notify;
CREATE TRIGGER trigger_audit_approval_instance_step_notify AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_instance_step_notify FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_approval_instance_step_notify();
DROP TRIGGER IF EXISTS trigger_legacy_approval_instance_step_notify_account ON approval_instance_step_notify;
CREATE TRIGGER trigger_legacy_approval_instance_step_notify_account BEFORE INSERT OR UPDATE OF account_id ON jazzhands.approval_instance_step_notify FOR EACH ROW EXECUTE FUNCTION jazzhands.legacy_approval_instance_step_notify_account();
DROP TRIGGER IF EXISTS trig_userlog_approval_process ON approval_process;
CREATE TRIGGER trig_userlog_approval_process BEFORE INSERT OR UPDATE ON jazzhands.approval_process FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_approval_process ON approval_process;
CREATE TRIGGER trigger_audit_approval_process AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_process FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_approval_process();
DROP TRIGGER IF EXISTS trig_userlog_approval_process_chain ON approval_process_chain;
CREATE TRIGGER trig_userlog_approval_process_chain BEFORE INSERT OR UPDATE ON jazzhands.approval_process_chain FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_approval_process_chain ON approval_process_chain;
CREATE TRIGGER trigger_audit_approval_process_chain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_process_chain FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_approval_process_chain();
DROP TRIGGER IF EXISTS trig_userlog_asset ON asset;
CREATE TRIGGER trig_userlog_asset BEFORE INSERT OR UPDATE ON jazzhands.asset FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_asset ON asset;
CREATE TRIGGER trigger_audit_asset AFTER INSERT OR DELETE OR UPDATE ON jazzhands.asset FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_asset();
DROP TRIGGER IF EXISTS trigger_validate_asset_component_assignment ON asset;
CREATE CONSTRAINT TRIGGER trigger_validate_asset_component_assignment AFTER INSERT OR UPDATE OF component_id ON jazzhands.asset DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_asset_component_assignment();
DROP TRIGGER IF EXISTS trig_userlog_badge ON badge;
CREATE TRIGGER trig_userlog_badge BEFORE INSERT OR UPDATE ON jazzhands.badge FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_badge ON badge;
CREATE TRIGGER trigger_audit_badge AFTER INSERT OR DELETE OR UPDATE ON jazzhands.badge FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_badge();
DROP TRIGGER IF EXISTS trig_userlog_badge_type ON badge_type;
CREATE TRIGGER trig_userlog_badge_type BEFORE INSERT OR UPDATE ON jazzhands.badge_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_badge_type ON badge_type;
CREATE TRIGGER trigger_audit_badge_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.badge_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_badge_type();
DROP TRIGGER IF EXISTS trig_userlog_certificate_signing_request ON certificate_signing_request;
CREATE TRIGGER trig_userlog_certificate_signing_request BEFORE INSERT OR UPDATE ON jazzhands.certificate_signing_request FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_certificate_signing_request ON certificate_signing_request;
CREATE TRIGGER trigger_audit_certificate_signing_request AFTER INSERT OR DELETE OR UPDATE ON jazzhands.certificate_signing_request FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_certificate_signing_request();
DROP TRIGGER IF EXISTS trig_userlog_chassis_location ON chassis_location;
CREATE TRIGGER trig_userlog_chassis_location BEFORE INSERT OR UPDATE ON jazzhands.chassis_location FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_chassis_location ON chassis_location;
CREATE TRIGGER trigger_audit_chassis_location AFTER INSERT OR DELETE OR UPDATE ON jazzhands.chassis_location FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_chassis_location();
DROP TRIGGER IF EXISTS trig_userlog_circuit ON circuit;
CREATE TRIGGER trig_userlog_circuit BEFORE INSERT OR UPDATE ON jazzhands.circuit FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_circuit ON circuit;
CREATE TRIGGER trigger_audit_circuit AFTER INSERT OR DELETE OR UPDATE ON jazzhands.circuit FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_circuit();
DROP TRIGGER IF EXISTS trig_userlog_company ON company;
CREATE TRIGGER trig_userlog_company BEFORE INSERT OR UPDATE ON jazzhands.company FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_company ON company;
CREATE TRIGGER trigger_audit_company AFTER INSERT OR DELETE OR UPDATE ON jazzhands.company FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_company();
DROP TRIGGER IF EXISTS trigger_company_insert_function_nudge ON company;
CREATE TRIGGER trigger_company_insert_function_nudge BEFORE INSERT ON jazzhands.company FOR EACH ROW EXECUTE FUNCTION jazzhands.company_insert_function_nudge();
DROP TRIGGER IF EXISTS trigger_delete_per_company_company_collection ON company;
CREATE TRIGGER trigger_delete_per_company_company_collection BEFORE DELETE ON jazzhands.company FOR EACH ROW EXECUTE FUNCTION jazzhands.delete_per_company_company_collection();
DROP TRIGGER IF EXISTS trigger_update_per_company_company_collection ON company;
CREATE TRIGGER trigger_update_per_company_company_collection AFTER INSERT OR UPDATE ON jazzhands.company FOR EACH ROW EXECUTE FUNCTION jazzhands.update_per_company_company_collection();
DROP TRIGGER IF EXISTS trig_userlog_company_collection ON company_collection;
CREATE TRIGGER trig_userlog_company_collection BEFORE INSERT OR UPDATE ON jazzhands.company_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_company_collection ON company_collection;
CREATE TRIGGER trigger_audit_company_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.company_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_company_collection();
DROP TRIGGER IF EXISTS trigger_manip_company_collection_bytype_del ON company_collection;
CREATE TRIGGER trigger_manip_company_collection_bytype_del BEFORE DELETE ON jazzhands.company_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_company_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_company_collection_bytype_insup ON company_collection;
CREATE TRIGGER trigger_manip_company_collection_bytype_insup AFTER INSERT OR UPDATE OF company_collection_type ON jazzhands.company_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_company_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_company_collection_type_change ON company_collection;
CREATE TRIGGER trigger_validate_company_collection_type_change BEFORE UPDATE OF company_collection_type ON jazzhands.company_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_company_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_company_collection_company ON company_collection_company;
CREATE TRIGGER trig_userlog_company_collection_company BEFORE INSERT OR UPDATE ON jazzhands.company_collection_company FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_company_collection_company ON company_collection_company;
CREATE TRIGGER trigger_audit_company_collection_company AFTER INSERT OR DELETE OR UPDATE ON jazzhands.company_collection_company FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_company_collection_company();
DROP TRIGGER IF EXISTS trigger_company_collection_member_enforce ON company_collection_company;
CREATE CONSTRAINT TRIGGER trigger_company_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.company_collection_company DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.company_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_company_collection_hier ON company_collection_hier;
CREATE TRIGGER trig_userlog_company_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.company_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_company_collection_hier ON company_collection_hier;
CREATE TRIGGER trigger_audit_company_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.company_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_company_collection_hier();
DROP TRIGGER IF EXISTS trigger_company_collection_hier_enforce ON company_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_company_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.company_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.company_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_company_type ON company_type;
CREATE TRIGGER trig_userlog_company_type BEFORE INSERT OR UPDATE ON jazzhands.company_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_company_type ON company_type;
CREATE TRIGGER trigger_audit_company_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.company_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_company_type();
DROP TRIGGER IF EXISTS aaa_tg_cache_component_parent_handler ON component;
CREATE TRIGGER aaa_tg_cache_component_parent_handler AFTER INSERT OR DELETE OR UPDATE OF parent_slot_id ON jazzhands.component FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.cache_component_parent_handler();
DROP TRIGGER IF EXISTS aab_tg_cache_device_component_component_handler ON component;
CREATE TRIGGER aab_tg_cache_device_component_component_handler AFTER INSERT OR DELETE OR UPDATE OF parent_slot_id ON jazzhands.component FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.cache_device_component_component_handler();
DROP TRIGGER IF EXISTS trig_userlog_component ON component;
CREATE TRIGGER trig_userlog_component BEFORE INSERT OR UPDATE ON jazzhands.component FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_component ON component;
CREATE TRIGGER trigger_audit_component AFTER INSERT OR DELETE OR UPDATE ON jazzhands.component FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_component();
DROP TRIGGER IF EXISTS trigger_create_component_template_slots ON component;
CREATE TRIGGER trigger_create_component_template_slots AFTER INSERT OR UPDATE OF component_type_id ON jazzhands.component FOR EACH ROW EXECUTE FUNCTION jazzhands.create_component_slots_by_trigger();
DROP TRIGGER IF EXISTS trigger_validate_component_parent_slot_id ON component;
CREATE CONSTRAINT TRIGGER trigger_validate_component_parent_slot_id AFTER INSERT OR UPDATE OF parent_slot_id, component_type_id ON jazzhands.component DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_component_parent_slot_id();
DROP TRIGGER IF EXISTS trigger_validate_component_rack_location ON component;
CREATE CONSTRAINT TRIGGER trigger_validate_component_rack_location AFTER INSERT OR UPDATE OF rack_location_id ON jazzhands.component DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_component_rack_location();
DROP TRIGGER IF EXISTS trigger_zzz_generate_slot_names ON component;
CREATE TRIGGER trigger_zzz_generate_slot_names AFTER INSERT OR UPDATE OF parent_slot_id ON jazzhands.component FOR EACH ROW EXECUTE FUNCTION jazzhands.set_slot_names_by_trigger();
DROP TRIGGER IF EXISTS trig_userlog_component_property ON component_property;
CREATE TRIGGER trig_userlog_component_property BEFORE INSERT OR UPDATE ON jazzhands.component_property FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_component_property ON component_property;
CREATE TRIGGER trigger_audit_component_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.component_property FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_component_property();
DROP TRIGGER IF EXISTS trigger_validate_component_property ON component_property;
CREATE CONSTRAINT TRIGGER trigger_validate_component_property AFTER INSERT OR UPDATE ON jazzhands.component_property DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_component_property();
DROP TRIGGER IF EXISTS trig_userlog_component_type ON component_type;
CREATE TRIGGER trig_userlog_component_type BEFORE INSERT OR UPDATE ON jazzhands.component_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_component_type ON component_type;
CREATE TRIGGER trigger_audit_component_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.component_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_component_type();
DROP TRIGGER IF EXISTS trig_userlog_component_type_component_function ON component_type_component_function;
CREATE TRIGGER trig_userlog_component_type_component_function BEFORE INSERT OR UPDATE ON jazzhands.component_type_component_function FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_component_type_component_function ON component_type_component_function;
CREATE TRIGGER trigger_audit_component_type_component_function AFTER INSERT OR DELETE OR UPDATE ON jazzhands.component_type_component_function FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_component_type_component_function();
DROP TRIGGER IF EXISTS trig_userlog_component_type_slot_template ON component_type_slot_template;
CREATE TRIGGER trig_userlog_component_type_slot_template BEFORE INSERT OR UPDATE ON jazzhands.component_type_slot_template FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_component_type_slot_template ON component_type_slot_template;
CREATE TRIGGER trigger_audit_component_type_slot_template AFTER INSERT OR DELETE OR UPDATE ON jazzhands.component_type_slot_template FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_component_type_slot_template();
DROP TRIGGER IF EXISTS trig_userlog_contract ON contract;
CREATE TRIGGER trig_userlog_contract BEFORE INSERT OR UPDATE ON jazzhands.contract FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_contract ON contract;
CREATE TRIGGER trigger_audit_contract AFTER INSERT OR DELETE OR UPDATE ON jazzhands.contract FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_contract();
DROP TRIGGER IF EXISTS trig_userlog_contract_type ON contract_type;
CREATE TRIGGER trig_userlog_contract_type BEFORE INSERT OR UPDATE ON jazzhands.contract_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_contract_type ON contract_type;
CREATE TRIGGER trigger_audit_contract_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.contract_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_contract_type();
DROP TRIGGER IF EXISTS trig_userlog_department ON department;
CREATE TRIGGER trig_userlog_department BEFORE INSERT OR UPDATE ON jazzhands.department FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_department ON department;
CREATE TRIGGER trigger_audit_department AFTER INSERT OR DELETE OR UPDATE ON jazzhands.department FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_department();
DROP TRIGGER IF EXISTS tg_cache_device_component_device_handler ON device;
CREATE TRIGGER tg_cache_device_component_device_handler AFTER INSERT OR DELETE OR UPDATE OF component_id ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.cache_device_component_device_handler();
DROP TRIGGER IF EXISTS trig_userlog_device ON device;
CREATE TRIGGER trig_userlog_device BEFORE INSERT OR UPDATE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device ON device;
CREATE TRIGGER trigger_audit_device AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device();
DROP TRIGGER IF EXISTS trigger_create_device_component ON device;
CREATE TRIGGER trigger_create_device_component BEFORE INSERT OR UPDATE OF device_type_id ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands.create_device_component_by_trigger();
DROP TRIGGER IF EXISTS trigger_del_jazzhands_legacy_support ON device;
CREATE TRIGGER trigger_del_jazzhands_legacy_support BEFORE DELETE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands.del_jazzhands_legacy_support();
DROP TRIGGER IF EXISTS trigger_delete_per_device_device_collection ON device;
CREATE TRIGGER trigger_delete_per_device_device_collection BEFORE DELETE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands.delete_per_device_device_collection();
DROP TRIGGER IF EXISTS trigger_device_one_location_validate ON device;
CREATE TRIGGER trigger_device_one_location_validate BEFORE INSERT OR UPDATE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands.device_one_location_validate();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_device_del ON device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_device_del BEFORE DELETE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_device_del();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_device_ins ON device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_device_ins AFTER INSERT ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_device_ins();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_device_upd ON device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_device_upd AFTER UPDATE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_device_upd();
DROP TRIGGER IF EXISTS trigger_update_per_device_device_collection ON device;
CREATE TRIGGER trigger_update_per_device_device_collection AFTER INSERT OR UPDATE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands.update_per_device_device_collection();
DROP TRIGGER IF EXISTS trigger_validate_device_component_assignment ON device;
CREATE CONSTRAINT TRIGGER trigger_validate_device_component_assignment AFTER INSERT OR UPDATE OF device_type_id, component_id ON jazzhands.device DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_device_component_assignment();
DROP TRIGGER IF EXISTS aaa_device_collection_base_handler ON device_collection;
CREATE TRIGGER aaa_device_collection_base_handler AFTER INSERT OR DELETE OR UPDATE OF device_collection_id ON jazzhands.device_collection FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.device_collection_base_handler();
DROP TRIGGER IF EXISTS trig_userlog_device_collection ON device_collection;
CREATE TRIGGER trig_userlog_device_collection BEFORE INSERT OR UPDATE ON jazzhands.device_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_collection ON device_collection;
CREATE TRIGGER trigger_audit_device_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_collection();
DROP TRIGGER IF EXISTS trigger_manip_device_collection_bytype_del ON device_collection;
CREATE TRIGGER trigger_manip_device_collection_bytype_del BEFORE DELETE ON jazzhands.device_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_device_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_device_collection_bytype_insup ON device_collection;
CREATE TRIGGER trigger_manip_device_collection_bytype_insup AFTER INSERT OR UPDATE OF device_collection_type ON jazzhands.device_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_device_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_device_collection_type_change ON device_collection;
CREATE TRIGGER trigger_validate_device_collection_type_change BEFORE UPDATE OF device_collection_type ON jazzhands.device_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_device_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_device_collection_assigned_certificate ON device_collection_assigned_certificate;
CREATE TRIGGER trig_userlog_device_collection_assigned_certificate BEFORE INSERT OR UPDATE ON jazzhands.device_collection_assigned_certificate FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_collection_assigned_certificate ON device_collection_assigned_certificate;
CREATE TRIGGER trigger_audit_device_collection_assigned_certificate AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_assigned_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_collection_assigned_certificate();
DROP TRIGGER IF EXISTS trig_userlog_device_collection_device ON device_collection_device;
CREATE TRIGGER trig_userlog_device_collection_device BEFORE INSERT OR UPDATE ON jazzhands.device_collection_device FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_collection_device ON device_collection_device;
CREATE TRIGGER trigger_audit_device_collection_device AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_device FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_collection_device();
DROP TRIGGER IF EXISTS trigger_device_collection_member_enforce ON device_collection_device;
CREATE CONSTRAINT TRIGGER trigger_device_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.device_collection_device DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.device_collection_member_enforce();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_dcd_del ON device_collection_device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_dcd_del BEFORE DELETE ON jazzhands.device_collection_device FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_dcd_del();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_dcd_ins ON device_collection_device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_dcd_ins AFTER INSERT ON jazzhands.device_collection_device FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_dcd_ins();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_dcd_upd ON device_collection_device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_dcd_upd AFTER UPDATE ON jazzhands.device_collection_device FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_dcd_upd();
DROP TRIGGER IF EXISTS trigger_member_device_collection_after_hooks ON device_collection_device;
CREATE TRIGGER trigger_member_device_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_device FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.device_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_member_device_collection_after_row_hooks ON device_collection_device;
CREATE TRIGGER trigger_member_device_collection_after_row_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_device FOR EACH ROW EXECUTE FUNCTION jazzhands.device_collection_device_after_row_hooks();
DROP TRIGGER IF EXISTS aaa_device_collection_root_handler ON device_collection_hier;
CREATE TRIGGER aaa_device_collection_root_handler AFTER INSERT OR DELETE OR UPDATE OF device_collection_id, child_device_collection_id ON jazzhands.device_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.device_collection_root_handler();
DROP TRIGGER IF EXISTS trig_userlog_device_collection_hier ON device_collection_hier;
CREATE TRIGGER trig_userlog_device_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.device_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_collection_hier ON device_collection_hier;
CREATE TRIGGER trigger_audit_device_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_collection_hier();
DROP TRIGGER IF EXISTS trigger_check_device_collection_hier_loop ON device_collection_hier;
CREATE TRIGGER trigger_check_device_collection_hier_loop AFTER INSERT OR UPDATE ON jazzhands.device_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.check_device_colllection_hier_loop();
DROP TRIGGER IF EXISTS trigger_device_collection_hier_enforce ON device_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_device_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.device_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.device_collection_hier_enforce();
DROP TRIGGER IF EXISTS trigger_hier_device_collection_after_hooks ON device_collection_hier;
CREATE TRIGGER trigger_hier_device_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_hier FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.device_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_hier_device_collection_after_row_hooks ON device_collection_hier;
CREATE TRIGGER trigger_hier_device_collection_after_row_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.device_collection_hier_after_row_hooks();
DROP TRIGGER IF EXISTS trig_userlog_device_collection_ssh_key ON device_collection_ssh_key;
CREATE TRIGGER trig_userlog_device_collection_ssh_key BEFORE INSERT OR UPDATE ON jazzhands.device_collection_ssh_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_collection_ssh_key ON device_collection_ssh_key;
CREATE TRIGGER trigger_audit_device_collection_ssh_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_ssh_key FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_collection_ssh_key();
DROP TRIGGER IF EXISTS trig_userlog_device_encapsulation_domain ON device_encapsulation_domain;
CREATE TRIGGER trig_userlog_device_encapsulation_domain BEFORE INSERT OR UPDATE ON jazzhands.device_encapsulation_domain FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_encapsulation_domain ON device_encapsulation_domain;
CREATE TRIGGER trigger_audit_device_encapsulation_domain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_encapsulation_domain FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_encapsulation_domain();
DROP TRIGGER IF EXISTS trig_userlog_device_layer2_network ON device_layer2_network;
CREATE TRIGGER trig_userlog_device_layer2_network BEFORE INSERT OR UPDATE ON jazzhands.device_layer2_network FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_layer2_network ON device_layer2_network;
CREATE TRIGGER trigger_audit_device_layer2_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_layer2_network FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_layer2_network();
DROP TRIGGER IF EXISTS trig_userlog_device_management_controller ON device_management_controller;
CREATE TRIGGER trig_userlog_device_management_controller BEFORE INSERT OR UPDATE ON jazzhands.device_management_controller FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_management_controller ON device_management_controller;
CREATE TRIGGER trigger_audit_device_management_controller AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_management_controller FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_management_controller();
DROP TRIGGER IF EXISTS trig_userlog_device_note ON device_note;
CREATE TRIGGER trig_userlog_device_note BEFORE INSERT OR UPDATE ON jazzhands.device_note FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_note ON device_note;
CREATE TRIGGER trigger_audit_device_note AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_note FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_note();
DROP TRIGGER IF EXISTS trig_userlog_device_ssh_key ON device_ssh_key;
CREATE TRIGGER trig_userlog_device_ssh_key BEFORE INSERT OR UPDATE ON jazzhands.device_ssh_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_ssh_key ON device_ssh_key;
CREATE TRIGGER trigger_audit_device_ssh_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_ssh_key FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_ssh_key();
DROP TRIGGER IF EXISTS trig_userlog_device_ticket ON device_ticket;
CREATE TRIGGER trig_userlog_device_ticket BEFORE INSERT OR UPDATE ON jazzhands.device_ticket FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_ticket ON device_ticket;
CREATE TRIGGER trigger_audit_device_ticket AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_ticket FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_ticket();
DROP TRIGGER IF EXISTS trig_userlog_device_type ON device_type;
CREATE TRIGGER trig_userlog_device_type BEFORE INSERT OR UPDATE ON jazzhands.device_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_type ON device_type;
CREATE TRIGGER trigger_audit_device_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_type();
DROP TRIGGER IF EXISTS trigger_device_type_chassis_check ON device_type;
CREATE TRIGGER trigger_device_type_chassis_check BEFORE UPDATE OF is_chassis ON jazzhands.device_type FOR EACH ROW EXECUTE FUNCTION jazzhands.device_type_chassis_check();
DROP TRIGGER IF EXISTS trigger_device_type_model_to_name ON device_type;
CREATE TRIGGER trigger_device_type_model_to_name BEFORE INSERT OR UPDATE OF device_type_name, model ON jazzhands.device_type FOR EACH ROW EXECUTE FUNCTION jazzhands.device_type_model_to_name();
DROP TRIGGER IF EXISTS trig_userlog_device_type_module ON device_type_module;
CREATE TRIGGER trig_userlog_device_type_module BEFORE INSERT OR UPDATE ON jazzhands.device_type_module FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_type_module ON device_type_module;
CREATE TRIGGER trigger_audit_device_type_module AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_type_module FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_type_module();
DROP TRIGGER IF EXISTS trigger_device_type_module_chassis_check ON device_type_module;
CREATE TRIGGER trigger_device_type_module_chassis_check BEFORE INSERT OR UPDATE OF device_type_id ON jazzhands.device_type_module FOR EACH ROW EXECUTE FUNCTION jazzhands.device_type_module_chassis_check();
DROP TRIGGER IF EXISTS trigger_device_type_module_sanity_set ON device_type_module;
CREATE TRIGGER trigger_device_type_module_sanity_set BEFORE INSERT OR UPDATE ON jazzhands.device_type_module FOR EACH ROW EXECUTE FUNCTION jazzhands.device_type_module_sanity_set();
DROP TRIGGER IF EXISTS trig_userlog_device_type_module_device_type ON device_type_module_device_type;
CREATE TRIGGER trig_userlog_device_type_module_device_type BEFORE INSERT OR UPDATE ON jazzhands.device_type_module_device_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_type_module_device_type ON device_type_module_device_type;
CREATE TRIGGER trigger_audit_device_type_module_device_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_type_module_device_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_type_module_device_type();
DROP TRIGGER IF EXISTS trig_userlog_dns_change_record ON dns_change_record;
CREATE TRIGGER trig_userlog_dns_change_record BEFORE INSERT OR UPDATE ON jazzhands.dns_change_record FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_change_record ON dns_change_record;
CREATE TRIGGER trigger_audit_dns_change_record AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_change_record FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_change_record();
DROP TRIGGER IF EXISTS trigger_dns_change_record_pgnotify ON dns_change_record;
CREATE TRIGGER trigger_dns_change_record_pgnotify AFTER INSERT OR UPDATE ON jazzhands.dns_change_record FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.dns_change_record_pgnotify();
DROP TRIGGER IF EXISTS trig_userlog_dns_domain ON dns_domain;
CREATE TRIGGER trig_userlog_dns_domain BEFORE INSERT OR UPDATE ON jazzhands.dns_domain FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_domain ON dns_domain;
CREATE TRIGGER trigger_audit_dns_domain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_domain FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_domain();
DROP TRIGGER IF EXISTS trigger_dns_domain_trigger_change ON dns_domain;
CREATE TRIGGER trigger_dns_domain_trigger_change AFTER INSERT OR UPDATE OF dns_domain_name ON jazzhands.dns_domain FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_trigger_change();
DROP TRIGGER IF EXISTS trig_userlog_dns_domain_collection ON dns_domain_collection;
CREATE TRIGGER trig_userlog_dns_domain_collection BEFORE INSERT OR UPDATE ON jazzhands.dns_domain_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_domain_collection ON dns_domain_collection;
CREATE TRIGGER trigger_audit_dns_domain_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_domain_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_domain_collection();
DROP TRIGGER IF EXISTS trigger_manip_dns_domain_collection_bytype_del ON dns_domain_collection;
CREATE TRIGGER trigger_manip_dns_domain_collection_bytype_del BEFORE DELETE ON jazzhands.dns_domain_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_dns_domain_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_dns_domain_collection_bytype_insup ON dns_domain_collection;
CREATE TRIGGER trigger_manip_dns_domain_collection_bytype_insup AFTER INSERT OR UPDATE OF dns_domain_collection_type ON jazzhands.dns_domain_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_dns_domain_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_dns_domain_collection_type_change ON dns_domain_collection;
CREATE TRIGGER trigger_validate_dns_domain_collection_type_change BEFORE UPDATE OF dns_domain_collection_type ON jazzhands.dns_domain_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_dns_domain_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_dns_domain_collection_dns_domain ON dns_domain_collection_dns_domain;
CREATE TRIGGER trig_userlog_dns_domain_collection_dns_domain BEFORE INSERT OR UPDATE ON jazzhands.dns_domain_collection_dns_domain FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_domain_collection_dns_domain ON dns_domain_collection_dns_domain;
CREATE TRIGGER trigger_audit_dns_domain_collection_dns_domain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_domain_collection_dns_domain FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_domain_collection_dns_domain();
DROP TRIGGER IF EXISTS trigger_dns_domain_collection_member_enforce ON dns_domain_collection_dns_domain;
CREATE CONSTRAINT TRIGGER trigger_dns_domain_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.dns_domain_collection_dns_domain DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_dns_domain_collection_hier ON dns_domain_collection_hier;
CREATE TRIGGER trig_userlog_dns_domain_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.dns_domain_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_domain_collection_hier ON dns_domain_collection_hier;
CREATE TRIGGER trigger_audit_dns_domain_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_domain_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_domain_collection_hier();
DROP TRIGGER IF EXISTS trigger_dns_domain_collection_hier_enforce ON dns_domain_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_dns_domain_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.dns_domain_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_dns_domain_ip_universe ON dns_domain_ip_universe;
CREATE TRIGGER trig_userlog_dns_domain_ip_universe BEFORE INSERT OR UPDATE ON jazzhands.dns_domain_ip_universe FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_domain_ip_universe ON dns_domain_ip_universe;
CREATE TRIGGER trigger_audit_dns_domain_ip_universe AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_domain_ip_universe FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_domain_ip_universe();
DROP TRIGGER IF EXISTS trigger_dns_domain_ip_universe_can_generate ON dns_domain_ip_universe;
CREATE TRIGGER trigger_dns_domain_ip_universe_can_generate AFTER INSERT OR UPDATE OF should_generate ON jazzhands.dns_domain_ip_universe FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_ip_universe_can_generate();
DROP TRIGGER IF EXISTS trigger_dns_domain_ip_universe_trigger_change ON dns_domain_ip_universe;
CREATE TRIGGER trigger_dns_domain_ip_universe_trigger_change AFTER INSERT OR UPDATE OF soa_class, soa_ttl, soa_serial, soa_refresh, soa_retry, soa_expire, soa_minimum, soa_mname, soa_rname, should_generate ON jazzhands.dns_domain_ip_universe FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_ip_universe_trigger_change();
DROP TRIGGER IF EXISTS trigger_dns_domain_ip_universe_trigger_del ON dns_domain_ip_universe;
CREATE TRIGGER trigger_dns_domain_ip_universe_trigger_del BEFORE DELETE ON jazzhands.dns_domain_ip_universe FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_ip_universe_trigger_del();
DROP TRIGGER IF EXISTS trig_userlog_dns_record ON dns_record;
CREATE TRIGGER trig_userlog_dns_record BEFORE INSERT OR UPDATE ON jazzhands.dns_record FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_record ON dns_record;
CREATE TRIGGER trigger_audit_dns_record AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_record FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_record();
DROP TRIGGER IF EXISTS trigger_check_ip_universe_dns_record ON dns_record;
CREATE CONSTRAINT TRIGGER trigger_check_ip_universe_dns_record AFTER INSERT OR UPDATE OF dns_record_id, ip_universe_id ON jazzhands.dns_record DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.check_ip_universe_dns_record();
DROP TRIGGER IF EXISTS trigger_dns_a_rec_validation ON dns_record;
CREATE TRIGGER trigger_dns_a_rec_validation BEFORE INSERT OR UPDATE ON jazzhands.dns_record FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_a_rec_validation();
DROP TRIGGER IF EXISTS trigger_dns_non_a_rec_validation ON dns_record;
CREATE TRIGGER trigger_dns_non_a_rec_validation BEFORE INSERT OR UPDATE ON jazzhands.dns_record FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_non_a_rec_validation();
DROP TRIGGER IF EXISTS trigger_dns_rec_prevent_dups ON dns_record;
CREATE CONSTRAINT TRIGGER trigger_dns_rec_prevent_dups AFTER INSERT OR UPDATE ON jazzhands.dns_record NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_rec_prevent_dups();
DROP TRIGGER IF EXISTS trigger_dns_record_check_name ON dns_record;
CREATE TRIGGER trigger_dns_record_check_name BEFORE INSERT OR UPDATE OF dns_name, should_generate_ptr ON jazzhands.dns_record FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_record_check_name();
DROP TRIGGER IF EXISTS trigger_dns_record_cname_checker ON dns_record;
CREATE CONSTRAINT TRIGGER trigger_dns_record_cname_checker AFTER INSERT OR UPDATE OF dns_class, dns_type, dns_name, dns_domain_id, is_enabled ON jazzhands.dns_record NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_record_cname_checker();
DROP TRIGGER IF EXISTS trigger_dns_record_enabled_check ON dns_record;
CREATE TRIGGER trigger_dns_record_enabled_check BEFORE INSERT OR UPDATE OF is_enabled ON jazzhands.dns_record FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_record_enabled_check();
DROP TRIGGER IF EXISTS trigger_dns_record_update_nontime ON dns_record;
CREATE TRIGGER trigger_dns_record_update_nontime AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_record FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_record_update_nontime();
DROP TRIGGER IF EXISTS trig_userlog_dns_record_relation ON dns_record_relation;
CREATE TRIGGER trig_userlog_dns_record_relation BEFORE INSERT OR UPDATE ON jazzhands.dns_record_relation FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_record_relation ON dns_record_relation;
CREATE TRIGGER trigger_audit_dns_record_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_record_relation FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_record_relation();
DROP TRIGGER IF EXISTS trig_userlog_encapsulation_domain ON encapsulation_domain;
CREATE TRIGGER trig_userlog_encapsulation_domain BEFORE INSERT OR UPDATE ON jazzhands.encapsulation_domain FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_encapsulation_domain ON encapsulation_domain;
CREATE TRIGGER trigger_audit_encapsulation_domain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.encapsulation_domain FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_encapsulation_domain();
DROP TRIGGER IF EXISTS trig_userlog_encapsulation_range ON encapsulation_range;
CREATE TRIGGER trig_userlog_encapsulation_range BEFORE INSERT OR UPDATE ON jazzhands.encapsulation_range FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_encapsulation_range ON encapsulation_range;
CREATE TRIGGER trigger_audit_encapsulation_range AFTER INSERT OR DELETE OR UPDATE ON jazzhands.encapsulation_range FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_encapsulation_range();
DROP TRIGGER IF EXISTS trig_userlog_encryption_key ON encryption_key;
CREATE TRIGGER trig_userlog_encryption_key BEFORE INSERT OR UPDATE ON jazzhands.encryption_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_encryption_key ON encryption_key;
CREATE TRIGGER trigger_audit_encryption_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.encryption_key FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_encryption_key();
DROP TRIGGER IF EXISTS trig_userlog_inter_component_connection ON inter_component_connection;
CREATE TRIGGER trig_userlog_inter_component_connection BEFORE INSERT OR UPDATE ON jazzhands.inter_component_connection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_inter_component_connection ON inter_component_connection;
CREATE TRIGGER trigger_audit_inter_component_connection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.inter_component_connection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_inter_component_connection();
DROP TRIGGER IF EXISTS trigger_validate_inter_component_connection ON inter_component_connection;
CREATE CONSTRAINT TRIGGER trigger_validate_inter_component_connection AFTER INSERT OR UPDATE ON jazzhands.inter_component_connection DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_inter_component_connection();
DROP TRIGGER IF EXISTS trig_userlog_ip_universe ON ip_universe;
CREATE TRIGGER trig_userlog_ip_universe BEFORE INSERT OR UPDATE ON jazzhands.ip_universe FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_ip_universe ON ip_universe;
CREATE TRIGGER trigger_audit_ip_universe AFTER INSERT OR DELETE OR UPDATE ON jazzhands.ip_universe FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_ip_universe();
DROP TRIGGER IF EXISTS trig_userlog_ip_universe_visibility ON ip_universe_visibility;
CREATE TRIGGER trig_userlog_ip_universe_visibility BEFORE INSERT OR UPDATE ON jazzhands.ip_universe_visibility FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_ip_universe_visibility ON ip_universe_visibility;
CREATE TRIGGER trigger_audit_ip_universe_visibility AFTER INSERT OR DELETE OR UPDATE ON jazzhands.ip_universe_visibility FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_ip_universe_visibility();
DROP TRIGGER IF EXISTS trig_userlog_kerberos_realm ON kerberos_realm;
CREATE TRIGGER trig_userlog_kerberos_realm BEFORE INSERT OR UPDATE ON jazzhands.kerberos_realm FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_kerberos_realm ON kerberos_realm;
CREATE TRIGGER trigger_audit_kerberos_realm AFTER INSERT OR DELETE OR UPDATE ON jazzhands.kerberos_realm FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_kerberos_realm();
DROP TRIGGER IF EXISTS trig_userlog_klogin ON klogin;
CREATE TRIGGER trig_userlog_klogin BEFORE INSERT OR UPDATE ON jazzhands.klogin FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_klogin ON klogin;
CREATE TRIGGER trigger_audit_klogin AFTER INSERT OR DELETE OR UPDATE ON jazzhands.klogin FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_klogin();
DROP TRIGGER IF EXISTS trig_userlog_klogin_mclass ON klogin_mclass;
CREATE TRIGGER trig_userlog_klogin_mclass BEFORE INSERT OR UPDATE ON jazzhands.klogin_mclass FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_klogin_mclass ON klogin_mclass;
CREATE TRIGGER trigger_audit_klogin_mclass AFTER INSERT OR DELETE OR UPDATE ON jazzhands.klogin_mclass FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_klogin_mclass();
DROP TRIGGER IF EXISTS trig_userlog_layer2_connection ON layer2_connection;
CREATE TRIGGER trig_userlog_layer2_connection BEFORE INSERT OR UPDATE ON jazzhands.layer2_connection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_connection ON layer2_connection;
CREATE TRIGGER trigger_audit_layer2_connection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_connection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer2_connection();
DROP TRIGGER IF EXISTS trig_userlog_layer2_connection_layer2_network ON layer2_connection_layer2_network;
CREATE TRIGGER trig_userlog_layer2_connection_layer2_network BEFORE INSERT OR UPDATE ON jazzhands.layer2_connection_layer2_network FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_connection_layer2_network ON layer2_connection_layer2_network;
CREATE TRIGGER trigger_audit_layer2_connection_layer2_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_connection_layer2_network FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer2_connection_layer2_network();
DROP TRIGGER IF EXISTS trig_userlog_layer2_network ON layer2_network;
CREATE TRIGGER trig_userlog_layer2_network BEFORE INSERT OR UPDATE ON jazzhands.layer2_network FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_network ON layer2_network;
CREATE TRIGGER trigger_audit_layer2_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer2_network();
DROP TRIGGER IF EXISTS layer2_net_collection_member_enforce_on_type_change ON layer2_network_collection;
CREATE CONSTRAINT TRIGGER layer2_net_collection_member_enforce_on_type_change AFTER UPDATE OF layer2_network_collection_type ON jazzhands.layer2_network_collection DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.layer2_net_collection_member_enforce_on_type_change();
DROP TRIGGER IF EXISTS trig_userlog_layer2_network_collection ON layer2_network_collection;
CREATE TRIGGER trig_userlog_layer2_network_collection BEFORE INSERT OR UPDATE ON jazzhands.layer2_network_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_network_collection ON layer2_network_collection;
CREATE TRIGGER trigger_audit_layer2_network_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer2_network_collection();
DROP TRIGGER IF EXISTS trigger_manip_layer2_network_collection_bytype_del ON layer2_network_collection;
CREATE TRIGGER trigger_manip_layer2_network_collection_bytype_del BEFORE DELETE ON jazzhands.layer2_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer2_network_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_layer2_network_collection_bytype_insup ON layer2_network_collection;
CREATE TRIGGER trigger_manip_layer2_network_collection_bytype_insup AFTER INSERT OR UPDATE OF layer2_network_collection_type ON jazzhands.layer2_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer2_network_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_layer2_network_collection_type_change ON layer2_network_collection;
CREATE TRIGGER trigger_validate_layer2_network_collection_type_change BEFORE UPDATE OF layer2_network_collection_type ON jazzhands.layer2_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_layer2_network_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_layer2_network_collection_hier ON layer2_network_collection_hier;
CREATE TRIGGER trig_userlog_layer2_network_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.layer2_network_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_network_collection_hier ON layer2_network_collection_hier;
CREATE TRIGGER trigger_audit_layer2_network_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer2_network_collection_hier();
DROP TRIGGER IF EXISTS trigger_hier_layer2_network_collection_after_hooks ON layer2_network_collection_hier;
CREATE TRIGGER trigger_hier_layer2_network_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network_collection_hier FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.layer2_network_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_layer2_network_collection_hier_enforce ON layer2_network_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_layer2_network_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.layer2_network_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.layer2_network_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_layer2_network_collection_layer2_network ON layer2_network_collection_layer2_network;
CREATE TRIGGER trig_userlog_layer2_network_collection_layer2_network BEFORE INSERT OR UPDATE ON jazzhands.layer2_network_collection_layer2_network FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_network_collection_layer2_network ON layer2_network_collection_layer2_network;
CREATE TRIGGER trigger_audit_layer2_network_collection_layer2_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network_collection_layer2_network FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer2_network_collection_layer2_network();
DROP TRIGGER IF EXISTS trigger_layer2_network_collection_member_enforce ON layer2_network_collection_layer2_network;
CREATE CONSTRAINT TRIGGER trigger_layer2_network_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.layer2_network_collection_layer2_network DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.layer2_network_collection_member_enforce();
DROP TRIGGER IF EXISTS trigger_member_layer2_network_collection_after_hooks ON layer2_network_collection_layer2_network;
CREATE TRIGGER trigger_member_layer2_network_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network_collection_layer2_network FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.layer2_network_collection_after_hooks();
DROP TRIGGER IF EXISTS trig_userlog_layer3_acl_chain ON layer3_acl_chain;
CREATE TRIGGER trig_userlog_layer3_acl_chain BEFORE INSERT OR UPDATE ON jazzhands.layer3_acl_chain FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_acl_chain ON layer3_acl_chain;
CREATE TRIGGER trigger_audit_layer3_acl_chain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_acl_chain FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_acl_chain();
DROP TRIGGER IF EXISTS trig_userlog_layer3_acl_chain_layer3_interface ON layer3_acl_chain_layer3_interface;
CREATE TRIGGER trig_userlog_layer3_acl_chain_layer3_interface BEFORE INSERT OR UPDATE ON jazzhands.layer3_acl_chain_layer3_interface FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_acl_chain_layer3_interface ON layer3_acl_chain_layer3_interface;
CREATE TRIGGER trigger_audit_layer3_acl_chain_layer3_interface AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_acl_chain_layer3_interface FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_acl_chain_layer3_interface();
DROP TRIGGER IF EXISTS trig_userlog_layer3_acl_group ON layer3_acl_group;
CREATE TRIGGER trig_userlog_layer3_acl_group BEFORE INSERT OR UPDATE ON jazzhands.layer3_acl_group FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_acl_group ON layer3_acl_group;
CREATE TRIGGER trigger_audit_layer3_acl_group AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_acl_group FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_acl_group();
DROP TRIGGER IF EXISTS trig_userlog_layer3_acl_rule ON layer3_acl_rule;
CREATE TRIGGER trig_userlog_layer3_acl_rule BEFORE INSERT OR UPDATE ON jazzhands.layer3_acl_rule FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_acl_rule ON layer3_acl_rule;
CREATE TRIGGER trigger_audit_layer3_acl_rule AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_acl_rule FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_acl_rule();
DROP TRIGGER IF EXISTS trig_userlog_layer3_interface ON layer3_interface;
CREATE TRIGGER trig_userlog_layer3_interface BEFORE INSERT OR UPDATE ON jazzhands.layer3_interface FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_interface ON layer3_interface;
CREATE TRIGGER trigger_audit_layer3_interface AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_interface FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_interface();
DROP TRIGGER IF EXISTS trigger_net_int_device_id_upd ON layer3_interface;
CREATE TRIGGER trigger_net_int_device_id_upd AFTER UPDATE OF device_id ON jazzhands.layer3_interface FOR EACH ROW EXECUTE FUNCTION jazzhands.net_int_device_id_upd();
DROP TRIGGER IF EXISTS trigger_net_int_nb_device_id_ins_before ON layer3_interface;
CREATE TRIGGER trigger_net_int_nb_device_id_ins_before BEFORE UPDATE OF device_id ON jazzhands.layer3_interface FOR EACH ROW EXECUTE FUNCTION jazzhands.net_int_nb_device_id_ins_before();
DROP TRIGGER IF EXISTS trig_userlog_layer3_interface_netblock ON layer3_interface_netblock;
CREATE TRIGGER trig_userlog_layer3_interface_netblock BEFORE INSERT OR UPDATE ON jazzhands.layer3_interface_netblock FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_interface_netblock ON layer3_interface_netblock;
CREATE TRIGGER trigger_audit_layer3_interface_netblock AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_interface_netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_interface_netblock();
DROP TRIGGER IF EXISTS trigger_net_int_nb_device_id_ins ON layer3_interface_netblock;
CREATE TRIGGER trigger_net_int_nb_device_id_ins BEFORE INSERT OR UPDATE OF layer3_interface_id ON jazzhands.layer3_interface_netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.net_int_nb_device_id_ins();
DROP TRIGGER IF EXISTS trigger_net_int_nb_device_id_ins_after ON layer3_interface_netblock;
CREATE TRIGGER trigger_net_int_nb_device_id_ins_after AFTER INSERT OR UPDATE OF layer3_interface_id ON jazzhands.layer3_interface_netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.net_int_nb_device_id_ins_after();
DROP TRIGGER IF EXISTS trigger_net_int_nb_single_address ON layer3_interface_netblock;
CREATE TRIGGER trigger_net_int_nb_single_address BEFORE INSERT OR UPDATE OF netblock_id ON jazzhands.layer3_interface_netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.net_int_nb_single_address();
DROP TRIGGER IF EXISTS trig_userlog_layer3_interface_purpose ON layer3_interface_purpose;
CREATE TRIGGER trig_userlog_layer3_interface_purpose BEFORE INSERT OR UPDATE ON jazzhands.layer3_interface_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_interface_purpose ON layer3_interface_purpose;
CREATE TRIGGER trigger_audit_layer3_interface_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_interface_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_interface_purpose();
DROP TRIGGER IF EXISTS trig_userlog_layer3_network ON layer3_network;
CREATE TRIGGER trig_userlog_layer3_network BEFORE INSERT OR UPDATE ON jazzhands.layer3_network FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_network ON layer3_network;
CREATE TRIGGER trigger_audit_layer3_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_network();
DROP TRIGGER IF EXISTS trigger_layer3_network_validate_netblock ON layer3_network;
CREATE CONSTRAINT TRIGGER trigger_layer3_network_validate_netblock AFTER INSERT OR UPDATE OF netblock_id ON jazzhands.layer3_network NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.layer3_network_validate_netblock();
DROP TRIGGER IF EXISTS layer3_net_collection_member_enforce_on_type_change ON layer3_network_collection;
CREATE CONSTRAINT TRIGGER layer3_net_collection_member_enforce_on_type_change AFTER UPDATE OF layer3_network_collection_type ON jazzhands.layer3_network_collection DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.layer3_net_collection_member_enforce_on_type_change();
DROP TRIGGER IF EXISTS trig_userlog_layer3_network_collection ON layer3_network_collection;
CREATE TRIGGER trig_userlog_layer3_network_collection BEFORE INSERT OR UPDATE ON jazzhands.layer3_network_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_network_collection ON layer3_network_collection;
CREATE TRIGGER trigger_audit_layer3_network_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_network_collection();
DROP TRIGGER IF EXISTS trigger_manip_layer3_network_collection_bytype_del ON layer3_network_collection;
CREATE TRIGGER trigger_manip_layer3_network_collection_bytype_del BEFORE DELETE ON jazzhands.layer3_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer3_network_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_layer3_network_collection_bytype_insup ON layer3_network_collection;
CREATE TRIGGER trigger_manip_layer3_network_collection_bytype_insup AFTER INSERT OR UPDATE OF layer3_network_collection_type ON jazzhands.layer3_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer3_network_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_layer3_network_collection_type_change ON layer3_network_collection;
CREATE TRIGGER trigger_validate_layer3_network_collection_type_change BEFORE UPDATE OF layer3_network_collection_type ON jazzhands.layer3_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_layer3_network_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_layer3_network_collection_hier ON layer3_network_collection_hier;
CREATE TRIGGER trig_userlog_layer3_network_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.layer3_network_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_network_collection_hier ON layer3_network_collection_hier;
CREATE TRIGGER trigger_audit_layer3_network_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_network_collection_hier();
DROP TRIGGER IF EXISTS trigger_hier_layer3_network_collection_after_hooks ON layer3_network_collection_hier;
CREATE TRIGGER trigger_hier_layer3_network_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network_collection_hier FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.layer3_network_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_layer3_network_collection_hier_enforce ON layer3_network_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_layer3_network_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.layer3_network_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.layer3_network_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_layer3_network_collection_layer3_network ON layer3_network_collection_layer3_network;
CREATE TRIGGER trig_userlog_layer3_network_collection_layer3_network BEFORE INSERT OR UPDATE ON jazzhands.layer3_network_collection_layer3_network FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_network_collection_layer3_network ON layer3_network_collection_layer3_network;
CREATE TRIGGER trigger_audit_layer3_network_collection_layer3_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network_collection_layer3_network FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_network_collection_layer3_network();
DROP TRIGGER IF EXISTS trigger_layer3_network_collection_member_enforce ON layer3_network_collection_layer3_network;
CREATE CONSTRAINT TRIGGER trigger_layer3_network_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.layer3_network_collection_layer3_network DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.layer3_network_collection_member_enforce();
DROP TRIGGER IF EXISTS trigger_member_layer3_network_collection_after_hooks ON layer3_network_collection_layer3_network;
CREATE TRIGGER trigger_member_layer3_network_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network_collection_layer3_network FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.layer3_network_collection_after_hooks();
DROP TRIGGER IF EXISTS trig_userlog_logical_port ON logical_port;
CREATE TRIGGER trig_userlog_logical_port BEFORE INSERT OR UPDATE ON jazzhands.logical_port FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_logical_port ON logical_port;
CREATE TRIGGER trigger_audit_logical_port AFTER INSERT OR DELETE OR UPDATE ON jazzhands.logical_port FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_logical_port();
DROP TRIGGER IF EXISTS trig_userlog_logical_port_slot ON logical_port_slot;
CREATE TRIGGER trig_userlog_logical_port_slot BEFORE INSERT OR UPDATE ON jazzhands.logical_port_slot FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_logical_port_slot ON logical_port_slot;
CREATE TRIGGER trigger_audit_logical_port_slot AFTER INSERT OR DELETE OR UPDATE ON jazzhands.logical_port_slot FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_logical_port_slot();
DROP TRIGGER IF EXISTS trig_userlog_logical_volume ON logical_volume;
CREATE TRIGGER trig_userlog_logical_volume BEFORE INSERT OR UPDATE ON jazzhands.logical_volume FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_logical_volume ON logical_volume;
CREATE TRIGGER trigger_audit_logical_volume AFTER INSERT OR DELETE OR UPDATE ON jazzhands.logical_volume FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_logical_volume();
DROP TRIGGER IF EXISTS trig_userlog_logical_volume_property ON logical_volume_property;
CREATE TRIGGER trig_userlog_logical_volume_property BEFORE INSERT OR UPDATE ON jazzhands.logical_volume_property FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_logical_volume_property ON logical_volume_property;
CREATE TRIGGER trigger_audit_logical_volume_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.logical_volume_property FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_logical_volume_property();
DROP TRIGGER IF EXISTS trig_userlog_logical_volume_purpose ON logical_volume_purpose;
CREATE TRIGGER trig_userlog_logical_volume_purpose BEFORE INSERT OR UPDATE ON jazzhands.logical_volume_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_logical_volume_purpose ON logical_volume_purpose;
CREATE TRIGGER trigger_audit_logical_volume_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.logical_volume_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_logical_volume_purpose();
DROP TRIGGER IF EXISTS trig_userlog_mlag_peering ON mlag_peering;
CREATE TRIGGER trig_userlog_mlag_peering BEFORE INSERT OR UPDATE ON jazzhands.mlag_peering FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_mlag_peering ON mlag_peering;
CREATE TRIGGER trigger_audit_mlag_peering AFTER INSERT OR DELETE OR UPDATE ON jazzhands.mlag_peering FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_mlag_peering();
DROP TRIGGER IF EXISTS aaa_ta_manipulate_netblock_parentage ON netblock;
CREATE CONSTRAINT TRIGGER aaa_ta_manipulate_netblock_parentage AFTER INSERT OR DELETE ON jazzhands.netblock NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.manipulate_netblock_parentage_after();
DROP TRIGGER IF EXISTS tb_a_validate_netblock ON netblock;
CREATE TRIGGER tb_a_validate_netblock BEFORE INSERT OR UPDATE OF netblock_id, ip_address, netblock_type, is_single_address, can_subnet, parent_netblock_id, ip_universe_id ON jazzhands.netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_netblock();
DROP TRIGGER IF EXISTS tb_manipulate_netblock_parentage ON netblock;
CREATE TRIGGER tb_manipulate_netblock_parentage BEFORE INSERT OR UPDATE OF ip_address, netblock_type, ip_universe_id, netblock_id, can_subnet, is_single_address ON jazzhands.netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.manipulate_netblock_parentage_before();
DROP TRIGGER IF EXISTS trig_userlog_netblock ON netblock;
CREATE TRIGGER trig_userlog_netblock BEFORE INSERT OR UPDATE ON jazzhands.netblock FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_netblock ON netblock;
CREATE TRIGGER trigger_audit_netblock AFTER INSERT OR DELETE OR UPDATE ON jazzhands.netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_netblock();
DROP TRIGGER IF EXISTS trigger_cache_netblock_hier_truncate ON netblock;
CREATE TRIGGER trigger_cache_netblock_hier_truncate AFTER TRUNCATE ON jazzhands.netblock FOR EACH STATEMENT EXECUTE FUNCTION jazzhands_cache.cache_netblock_hier_truncate_handler();
DROP TRIGGER IF EXISTS trigger_check_ip_universe_netblock ON netblock;
CREATE CONSTRAINT TRIGGER trigger_check_ip_universe_netblock AFTER UPDATE OF netblock_id, ip_universe_id ON jazzhands.netblock DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.check_ip_universe_netblock();
DROP TRIGGER IF EXISTS trigger_nb_dns_a_rec_validation ON netblock;
CREATE TRIGGER trigger_nb_dns_a_rec_validation BEFORE UPDATE OF ip_address, is_single_address ON jazzhands.netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.nb_dns_a_rec_validation();
DROP TRIGGER IF EXISTS trigger_netblock_single_address_ni ON netblock;
CREATE TRIGGER trigger_netblock_single_address_ni BEFORE UPDATE OF is_single_address, netblock_type ON jazzhands.netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.netblock_single_address_ni();
DROP TRIGGER IF EXISTS trigger_netblock_validate_layer3_network_netblock ON netblock;
CREATE CONSTRAINT TRIGGER trigger_netblock_validate_layer3_network_netblock AFTER UPDATE OF can_subnet, is_single_address ON jazzhands.netblock NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.netblock_validate_layer3_network_netblock();
DROP TRIGGER IF EXISTS trigger_validate_netblock_parentage ON netblock;
CREATE CONSTRAINT TRIGGER trigger_validate_netblock_parentage AFTER INSERT OR UPDATE OF netblock_id, ip_address, netblock_type, is_single_address, can_subnet, parent_netblock_id, ip_universe_id ON jazzhands.netblock DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_netblock_parentage();
DROP TRIGGER IF EXISTS trigger_validate_netblock_to_range_changes ON netblock;
CREATE CONSTRAINT TRIGGER trigger_validate_netblock_to_range_changes AFTER UPDATE OF ip_address, is_single_address, can_subnet, netblock_type ON jazzhands.netblock DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_netblock_to_range_changes();
DROP TRIGGER IF EXISTS zaa_ta_cache_netblock_hier_handler ON netblock;
CREATE TRIGGER zaa_ta_cache_netblock_hier_handler AFTER INSERT OR DELETE OR UPDATE OF ip_address, parent_netblock_id ON jazzhands.netblock FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.cache_netblock_hier_handler();
DROP TRIGGER IF EXISTS aaa_netblock_collection_base_handler ON netblock_collection;
CREATE TRIGGER aaa_netblock_collection_base_handler AFTER INSERT OR DELETE OR UPDATE OF netblock_collection_id ON jazzhands.netblock_collection FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.netblock_collection_base_handler();
DROP TRIGGER IF EXISTS trig_userlog_netblock_collection ON netblock_collection;
CREATE TRIGGER trig_userlog_netblock_collection BEFORE INSERT OR UPDATE ON jazzhands.netblock_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_netblock_collection ON netblock_collection;
CREATE TRIGGER trigger_audit_netblock_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.netblock_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_netblock_collection();
DROP TRIGGER IF EXISTS trigger_manip_netblock_collection_bytype_del ON netblock_collection;
CREATE TRIGGER trigger_manip_netblock_collection_bytype_del BEFORE DELETE ON jazzhands.netblock_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_netblock_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_netblock_collection_bytype_insup ON netblock_collection;
CREATE TRIGGER trigger_manip_netblock_collection_bytype_insup AFTER INSERT OR UPDATE OF netblock_collection_type ON jazzhands.netblock_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_netblock_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_netblock_collection_type_change ON netblock_collection;
CREATE TRIGGER trigger_validate_netblock_collection_type_change BEFORE UPDATE OF netblock_collection_type ON jazzhands.netblock_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_netblock_collection_type_change();
DROP TRIGGER IF EXISTS aaa_netblock_collection_root_handler ON netblock_collection_hier;
CREATE TRIGGER aaa_netblock_collection_root_handler AFTER INSERT OR DELETE OR UPDATE OF netblock_collection_id, child_netblock_collection_id ON jazzhands.netblock_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.netblock_collection_root_handler();
DROP TRIGGER IF EXISTS trig_userlog_netblock_collection_hier ON netblock_collection_hier;
CREATE TRIGGER trig_userlog_netblock_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.netblock_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_netblock_collection_hier ON netblock_collection_hier;
CREATE TRIGGER trigger_audit_netblock_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.netblock_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_netblock_collection_hier();
DROP TRIGGER IF EXISTS trigger_check_netblock_collection_hier_loop ON netblock_collection_hier;
CREATE TRIGGER trigger_check_netblock_collection_hier_loop AFTER INSERT OR UPDATE ON jazzhands.netblock_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.check_netblock_colllection_hier_loop();
DROP TRIGGER IF EXISTS trigger_netblock_collection_hier_enforce ON netblock_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_netblock_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.netblock_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.netblock_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_netblock_collection_netblock ON netblock_collection_netblock;
CREATE TRIGGER trig_userlog_netblock_collection_netblock BEFORE INSERT OR UPDATE ON jazzhands.netblock_collection_netblock FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_netblock_collection_netblock ON netblock_collection_netblock;
CREATE TRIGGER trigger_audit_netblock_collection_netblock AFTER INSERT OR DELETE OR UPDATE ON jazzhands.netblock_collection_netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_netblock_collection_netblock();
DROP TRIGGER IF EXISTS trigger_netblock_collection_member_enforce ON netblock_collection_netblock;
CREATE CONSTRAINT TRIGGER trigger_netblock_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.netblock_collection_netblock DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.netblock_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_network_range ON network_range;
CREATE TRIGGER trig_userlog_network_range BEFORE INSERT OR UPDATE ON jazzhands.network_range FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_network_range ON network_range;
CREATE TRIGGER trigger_audit_network_range AFTER INSERT OR DELETE OR UPDATE ON jazzhands.network_range FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_network_range();
DROP TRIGGER IF EXISTS trigger_validate_network_range_dns ON network_range;
CREATE CONSTRAINT TRIGGER trigger_validate_network_range_dns AFTER INSERT OR UPDATE OF dns_domain_id ON jazzhands.network_range DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_network_range_dns();
DROP TRIGGER IF EXISTS trigger_validate_network_range_ips ON network_range;
CREATE CONSTRAINT TRIGGER trigger_validate_network_range_ips AFTER INSERT OR UPDATE OF start_netblock_id, stop_netblock_id, parent_netblock_id, network_range_type ON jazzhands.network_range DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_network_range_ips();
DROP TRIGGER IF EXISTS trig_userlog_network_service ON network_service;
CREATE TRIGGER trig_userlog_network_service BEFORE INSERT OR UPDATE ON jazzhands.network_service FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_network_service ON network_service;
CREATE TRIGGER trigger_audit_network_service AFTER INSERT OR DELETE OR UPDATE ON jazzhands.network_service FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_network_service();
DROP TRIGGER IF EXISTS trig_userlog_operating_system ON operating_system;
CREATE TRIGGER trig_userlog_operating_system BEFORE INSERT OR UPDATE ON jazzhands.operating_system FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_operating_system ON operating_system;
CREATE TRIGGER trigger_audit_operating_system AFTER INSERT OR DELETE OR UPDATE ON jazzhands.operating_system FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_operating_system();
DROP TRIGGER IF EXISTS trig_userlog_operating_system_snapshot ON operating_system_snapshot;
CREATE TRIGGER trig_userlog_operating_system_snapshot BEFORE INSERT OR UPDATE ON jazzhands.operating_system_snapshot FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_operating_system_snapshot ON operating_system_snapshot;
CREATE TRIGGER trigger_audit_operating_system_snapshot AFTER INSERT OR DELETE OR UPDATE ON jazzhands.operating_system_snapshot FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_operating_system_snapshot();
DROP TRIGGER IF EXISTS trig_userlog_person ON person;
CREATE TRIGGER trig_userlog_person BEFORE INSERT OR UPDATE ON jazzhands.person FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person ON person;
CREATE TRIGGER trigger_audit_person AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person();
DROP TRIGGER IF EXISTS trig_userlog_person_account_realm_company ON person_account_realm_company;
CREATE TRIGGER trig_userlog_person_account_realm_company BEFORE INSERT OR UPDATE ON jazzhands.person_account_realm_company FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_account_realm_company ON person_account_realm_company;
CREATE TRIGGER trigger_audit_person_account_realm_company AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_account_realm_company FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_account_realm_company();
DROP TRIGGER IF EXISTS trig_userlog_person_authentication_question ON person_authentication_question;
CREATE TRIGGER trig_userlog_person_authentication_question BEFORE INSERT OR UPDATE ON jazzhands.person_authentication_question FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_authentication_question ON person_authentication_question;
CREATE TRIGGER trigger_audit_person_authentication_question AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_authentication_question FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_authentication_question();
DROP TRIGGER IF EXISTS trig_userlog_person_company ON person_company;
CREATE TRIGGER trig_userlog_person_company BEFORE INSERT OR UPDATE ON jazzhands.person_company FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_company ON person_company;
CREATE TRIGGER trigger_audit_person_company AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_company FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_company();
DROP TRIGGER IF EXISTS trigger_propagate_person_status_to_account ON person_company;
CREATE TRIGGER trigger_propagate_person_status_to_account AFTER UPDATE ON jazzhands.person_company FOR EACH ROW EXECUTE FUNCTION jazzhands.propagate_person_status_to_account();
DROP TRIGGER IF EXISTS trigger_z_automated_ac_on_person_company ON person_company;
CREATE TRIGGER trigger_z_automated_ac_on_person_company AFTER UPDATE OF is_management, is_exempt, is_full_time, person_id, company_id, manager_person_id ON jazzhands.person_company FOR EACH ROW EXECUTE FUNCTION jazzhands.automated_ac_on_person_company();
DROP TRIGGER IF EXISTS trig_userlog_person_company_attribute ON person_company_attribute;
CREATE TRIGGER trig_userlog_person_company_attribute BEFORE INSERT OR UPDATE ON jazzhands.person_company_attribute FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_company_attribute ON person_company_attribute;
CREATE TRIGGER trigger_audit_person_company_attribute AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_company_attribute FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_company_attribute();
DROP TRIGGER IF EXISTS trigger_validate_person_company_attribute ON person_company_attribute;
CREATE TRIGGER trigger_validate_person_company_attribute BEFORE INSERT OR UPDATE ON jazzhands.person_company_attribute FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_person_company_attribute();
DROP TRIGGER IF EXISTS trig_userlog_person_company_badge ON person_company_badge;
CREATE TRIGGER trig_userlog_person_company_badge BEFORE INSERT OR UPDATE ON jazzhands.person_company_badge FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_company_badge ON person_company_badge;
CREATE TRIGGER trigger_audit_person_company_badge AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_company_badge FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_company_badge();
DROP TRIGGER IF EXISTS trig_userlog_person_contact ON person_contact;
CREATE TRIGGER trig_userlog_person_contact BEFORE INSERT OR UPDATE ON jazzhands.person_contact FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_contact ON person_contact;
CREATE TRIGGER trigger_audit_person_contact AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_contact FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_contact();
DROP TRIGGER IF EXISTS trig_userlog_person_image ON person_image;
CREATE TRIGGER trig_userlog_person_image BEFORE INSERT OR UPDATE ON jazzhands.person_image FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_image ON person_image;
CREATE TRIGGER trigger_audit_person_image AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_image FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_image();
DROP TRIGGER IF EXISTS trigger_fix_person_image_oid_ownership ON person_image;
CREATE TRIGGER trigger_fix_person_image_oid_ownership BEFORE INSERT ON jazzhands.person_image FOR EACH ROW EXECUTE FUNCTION jazzhands.fix_person_image_oid_ownership();
DROP TRIGGER IF EXISTS trig_userlog_person_image_usage ON person_image_usage;
CREATE TRIGGER trig_userlog_person_image_usage BEFORE INSERT OR UPDATE ON jazzhands.person_image_usage FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_image_usage ON person_image_usage;
CREATE TRIGGER trigger_audit_person_image_usage AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_image_usage FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_image_usage();
DROP TRIGGER IF EXISTS trigger_check_person_image_usage_mv ON person_image_usage;
CREATE TRIGGER trigger_check_person_image_usage_mv AFTER INSERT OR UPDATE ON jazzhands.person_image_usage FOR EACH ROW EXECUTE FUNCTION jazzhands.check_person_image_usage_mv();
DROP TRIGGER IF EXISTS trig_automated_realm_site_ac_pl ON person_location;
CREATE TRIGGER trig_automated_realm_site_ac_pl AFTER INSERT OR DELETE OR UPDATE OF site_code, person_id ON jazzhands.person_location FOR EACH ROW EXECUTE FUNCTION jazzhands.automated_realm_site_ac_pl();
DROP TRIGGER IF EXISTS trig_userlog_person_location ON person_location;
CREATE TRIGGER trig_userlog_person_location BEFORE INSERT OR UPDATE ON jazzhands.person_location FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_location ON person_location;
CREATE TRIGGER trigger_audit_person_location AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_location FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_location();
DROP TRIGGER IF EXISTS trig_userlog_person_note ON person_note;
CREATE TRIGGER trig_userlog_person_note BEFORE INSERT OR UPDATE ON jazzhands.person_note FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_note ON person_note;
CREATE TRIGGER trigger_audit_person_note AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_note FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_note();
DROP TRIGGER IF EXISTS trig_userlog_person_parking_pass ON person_parking_pass;
CREATE TRIGGER trig_userlog_person_parking_pass BEFORE INSERT OR UPDATE ON jazzhands.person_parking_pass FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_parking_pass ON person_parking_pass;
CREATE TRIGGER trigger_audit_person_parking_pass AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_parking_pass FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_parking_pass();
DROP TRIGGER IF EXISTS trig_userlog_person_vehicle ON person_vehicle;
CREATE TRIGGER trig_userlog_person_vehicle BEFORE INSERT OR UPDATE ON jazzhands.person_vehicle FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_vehicle ON person_vehicle;
CREATE TRIGGER trigger_audit_person_vehicle AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_vehicle FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_vehicle();
DROP TRIGGER IF EXISTS trig_userlog_physical_address ON physical_address;
CREATE TRIGGER trig_userlog_physical_address BEFORE INSERT OR UPDATE ON jazzhands.physical_address FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_physical_address ON physical_address;
CREATE TRIGGER trigger_audit_physical_address AFTER INSERT OR DELETE OR UPDATE ON jazzhands.physical_address FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_physical_address();
DROP TRIGGER IF EXISTS trig_userlog_physical_connection ON physical_connection;
CREATE TRIGGER trig_userlog_physical_connection BEFORE INSERT OR UPDATE ON jazzhands.physical_connection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_physical_connection ON physical_connection;
CREATE TRIGGER trigger_audit_physical_connection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.physical_connection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_physical_connection();
DROP TRIGGER IF EXISTS trigger_verify_physical_connection ON physical_connection;
CREATE TRIGGER trigger_verify_physical_connection AFTER INSERT OR UPDATE ON jazzhands.physical_connection FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.verify_physical_connection();
DROP TRIGGER IF EXISTS trig_userlog_physicalish_volume ON physicalish_volume;
CREATE TRIGGER trig_userlog_physicalish_volume BEFORE INSERT OR UPDATE ON jazzhands.physicalish_volume FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_physicalish_volume ON physicalish_volume;
CREATE TRIGGER trigger_audit_physicalish_volume AFTER INSERT OR DELETE OR UPDATE ON jazzhands.physicalish_volume FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_physicalish_volume();
DROP TRIGGER IF EXISTS trigger_verify_physicalish_volume ON physicalish_volume;
CREATE TRIGGER trigger_verify_physicalish_volume BEFORE INSERT OR UPDATE ON jazzhands.physicalish_volume FOR EACH ROW EXECUTE FUNCTION jazzhands.verify_physicalish_volume();
DROP TRIGGER IF EXISTS trig_userlog_port_range ON port_range;
CREATE TRIGGER trig_userlog_port_range BEFORE INSERT OR UPDATE ON jazzhands.port_range FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_port_range ON port_range;
CREATE TRIGGER trigger_audit_port_range AFTER INSERT OR DELETE OR UPDATE ON jazzhands.port_range FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_port_range();
DROP TRIGGER IF EXISTS trigger_port_range_manage_singleton ON port_range;
CREATE TRIGGER trigger_port_range_manage_singleton BEFORE INSERT ON jazzhands.port_range FOR EACH ROW EXECUTE FUNCTION jazzhands.port_range_manage_singleton();
DROP TRIGGER IF EXISTS trigger_port_range_sanity_check ON port_range;
CREATE CONSTRAINT TRIGGER trigger_port_range_sanity_check AFTER INSERT OR UPDATE OF port_start, port_end, is_singleton ON jazzhands.port_range NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.port_range_sanity_check();
DROP TRIGGER IF EXISTS trigger_pvtkey_ski_signed_validate ON private_key;
DROP TRIGGER IF EXISTS trig_userlog_private_key ON private_key;
CREATE TRIGGER trig_userlog_private_key BEFORE INSERT OR UPDATE ON jazzhands.private_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_private_key ON private_key;
CREATE TRIGGER trigger_audit_private_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.private_key FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_private_key();
DROP TRIGGER IF EXISTS trigger_pvtkey_pkh_signed_validate ON private_key;
CREATE CONSTRAINT TRIGGER trigger_pvtkey_pkh_signed_validate AFTER UPDATE OF public_key_hash_id ON jazzhands.private_key NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.pvtkey_pkh_signed_validate();
DROP TRIGGER IF EXISTS trig_userlog_property ON property;
CREATE TRIGGER trig_userlog_property BEFORE INSERT OR UPDATE ON jazzhands.property FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_property ON property;
CREATE TRIGGER trigger_audit_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_property();
DROP TRIGGER IF EXISTS trigger_validate_property ON property;
CREATE TRIGGER trigger_validate_property BEFORE INSERT OR UPDATE ON jazzhands.property FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_property();
DROP TRIGGER IF EXISTS trig_userlog_property_name_collection ON property_name_collection;
CREATE TRIGGER trig_userlog_property_name_collection BEFORE INSERT OR UPDATE ON jazzhands.property_name_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_property_name_collection ON property_name_collection;
CREATE TRIGGER trigger_audit_property_name_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property_name_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_property_name_collection();
DROP TRIGGER IF EXISTS trigger_validate_property_name_collection_type_change ON property_name_collection;
CREATE TRIGGER trigger_validate_property_name_collection_type_change BEFORE UPDATE OF property_name_collection_type ON jazzhands.property_name_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_property_name_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_property_name_collection_hier ON property_name_collection_hier;
CREATE TRIGGER trig_userlog_property_name_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.property_name_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_property_name_collection_hier ON property_name_collection_hier;
CREATE TRIGGER trigger_audit_property_name_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property_name_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_property_name_collection_hier();
DROP TRIGGER IF EXISTS trigger_hier_property_name_collection_after_hooks ON property_name_collection_hier;
CREATE TRIGGER trigger_hier_property_name_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property_name_collection_hier FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.property_name_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_property_name_collection_hier_enforce ON property_name_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_property_name_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.property_name_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.property_name_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_property_name_collection_property_name ON property_name_collection_property_name;
CREATE TRIGGER trig_userlog_property_name_collection_property_name BEFORE INSERT OR UPDATE ON jazzhands.property_name_collection_property_name FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_property_name_collection_property_name ON property_name_collection_property_name;
CREATE TRIGGER trigger_audit_property_name_collection_property_name AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property_name_collection_property_name FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_property_name_collection_property_name();
DROP TRIGGER IF EXISTS trigger_member_property_name_collection_after_hooks ON property_name_collection_property_name;
CREATE TRIGGER trigger_member_property_name_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property_name_collection_property_name FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.property_name_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_property_name_collection_member_enforce ON property_name_collection_property_name;
CREATE CONSTRAINT TRIGGER trigger_property_name_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.property_name_collection_property_name DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.property_name_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_protocol ON protocol;
CREATE TRIGGER trig_userlog_protocol BEFORE INSERT OR UPDATE ON jazzhands.protocol FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_protocol ON protocol;
CREATE TRIGGER trigger_audit_protocol AFTER INSERT OR DELETE OR UPDATE ON jazzhands.protocol FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_protocol();
DROP TRIGGER IF EXISTS trig_userlog_pseudo_klogin ON pseudo_klogin;
CREATE TRIGGER trig_userlog_pseudo_klogin BEFORE INSERT OR UPDATE ON jazzhands.pseudo_klogin FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_pseudo_klogin ON pseudo_klogin;
CREATE TRIGGER trigger_audit_pseudo_klogin AFTER INSERT OR DELETE OR UPDATE ON jazzhands.pseudo_klogin FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_pseudo_klogin();
DROP TRIGGER IF EXISTS trig_userlog_public_key_hash ON public_key_hash;
CREATE TRIGGER trig_userlog_public_key_hash BEFORE INSERT OR UPDATE ON jazzhands.public_key_hash FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_public_key_hash ON public_key_hash;
CREATE TRIGGER trigger_audit_public_key_hash AFTER INSERT OR DELETE OR UPDATE ON jazzhands.public_key_hash FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_public_key_hash();
DROP TRIGGER IF EXISTS trig_userlog_public_key_hash_hash ON public_key_hash_hash;
CREATE TRIGGER trig_userlog_public_key_hash_hash BEFORE INSERT OR UPDATE ON jazzhands.public_key_hash_hash FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_public_key_hash_hash ON public_key_hash_hash;
CREATE TRIGGER trigger_audit_public_key_hash_hash AFTER INSERT OR DELETE OR UPDATE ON jazzhands.public_key_hash_hash FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_public_key_hash_hash();
DROP TRIGGER IF EXISTS trig_userlog_rack ON rack;
CREATE TRIGGER trig_userlog_rack BEFORE INSERT OR UPDATE ON jazzhands.rack FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_rack ON rack;
CREATE TRIGGER trigger_audit_rack AFTER INSERT OR DELETE OR UPDATE ON jazzhands.rack FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_rack();
DROP TRIGGER IF EXISTS trig_userlog_rack_location ON rack_location;
CREATE TRIGGER trig_userlog_rack_location BEFORE INSERT OR UPDATE ON jazzhands.rack_location FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_rack_location ON rack_location;
CREATE TRIGGER trigger_audit_rack_location AFTER INSERT OR DELETE OR UPDATE ON jazzhands.rack_location FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_rack_location();
DROP TRIGGER IF EXISTS trig_userlog_service ON service;
CREATE TRIGGER trig_userlog_service BEFORE INSERT OR UPDATE ON jazzhands.service FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service ON service;
CREATE TRIGGER trigger_audit_service AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service();
DROP TRIGGER IF EXISTS trigger_check_service_namespace ON service;
CREATE CONSTRAINT TRIGGER trigger_check_service_namespace AFTER INSERT OR UPDATE OF service_name, service_type ON jazzhands.service NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.check_service_namespace();
DROP TRIGGER IF EXISTS trigger_create_all_services_collection ON service;
CREATE TRIGGER trigger_create_all_services_collection AFTER INSERT OR UPDATE OF service_name ON jazzhands.service FOR EACH ROW EXECUTE FUNCTION jazzhands.create_all_services_collection();
DROP TRIGGER IF EXISTS trigger_create_all_services_collection_del ON service;
CREATE TRIGGER trigger_create_all_services_collection_del BEFORE DELETE ON jazzhands.service FOR EACH ROW EXECUTE FUNCTION jazzhands.create_all_services_collection();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint ON service_endpoint;
CREATE TRIGGER trig_userlog_service_endpoint BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint ON service_endpoint;
CREATE TRIGGER trigger_audit_service_endpoint AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint();
DROP TRIGGER IF EXISTS trigger_service_endpoint_direct_check ON service_endpoint;
CREATE CONSTRAINT TRIGGER trigger_service_endpoint_direct_check AFTER INSERT OR UPDATE OF dns_record_id, port_range_id ON jazzhands.service_endpoint NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_endpoint_direct_check();
DROP TRIGGER IF EXISTS trigger_validate_service_endpoint_fksets ON service_endpoint;
CREATE CONSTRAINT TRIGGER trigger_validate_service_endpoint_fksets AFTER INSERT OR UPDATE OF dns_record_id, port_range_id ON jazzhands.service_endpoint NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_service_endpoint_fksets();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_health_check ON service_endpoint_health_check;
CREATE TRIGGER trig_userlog_service_endpoint_health_check BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_health_check FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_health_check ON service_endpoint_health_check;
CREATE TRIGGER trigger_audit_service_endpoint_health_check AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_health_check FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_health_check();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_provider ON service_endpoint_provider;
CREATE TRIGGER trig_userlog_service_endpoint_provider BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_provider FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_provider ON service_endpoint_provider;
CREATE TRIGGER trigger_audit_service_endpoint_provider AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_provider FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_provider();
DROP TRIGGER IF EXISTS trigger_service_endpoint_provider_direct_check ON service_endpoint_provider;
CREATE CONSTRAINT TRIGGER trigger_service_endpoint_provider_direct_check AFTER INSERT OR UPDATE OF service_endpoint_provider_type, dns_record_id ON jazzhands.service_endpoint_provider NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_endpoint_provider_direct_check();
DROP TRIGGER IF EXISTS trigger_service_endpoint_provider_dns_netblock_check ON service_endpoint_provider;
CREATE CONSTRAINT TRIGGER trigger_service_endpoint_provider_dns_netblock_check AFTER INSERT OR UPDATE OF dns_record_id, netblock_id ON jazzhands.service_endpoint_provider NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_endpoint_provider_dns_netblock_check();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_provider_collection ON service_endpoint_provider_collection;
CREATE TRIGGER trig_userlog_service_endpoint_provider_collection BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_provider_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_provider_collection ON service_endpoint_provider_collection;
CREATE TRIGGER trigger_audit_service_endpoint_provider_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_provider_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_provider_collection();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_provider_collection_service_endpo ON service_endpoint_provider_collection_service_endpoint_provider;
CREATE TRIGGER trig_userlog_service_endpoint_provider_collection_service_endpo BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_provider_collection_service_endpoint_provider FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_provider_collection_service_endp ON service_endpoint_provider_collection_service_endpoint_provider;
CREATE TRIGGER trigger_audit_service_endpoint_provider_collection_service_endp AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_provider_collection_service_endpoint_provider FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_provider_collection_service_endp();
DROP TRIGGER IF EXISTS trigger_svc_ep_coll_sep_direct_check ON service_endpoint_provider_collection_service_endpoint_provider;
CREATE CONSTRAINT TRIGGER trigger_svc_ep_coll_sep_direct_check AFTER INSERT OR UPDATE OF service_endpoint_provider_collection_id, service_endpoint_provider_id ON jazzhands.service_endpoint_provider_collection_service_endpoint_provider NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.svc_ep_coll_sep_direct_check();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_provider_service_instance ON service_endpoint_provider_service_instance;
CREATE TRIGGER trig_userlog_service_endpoint_provider_service_instance BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_provider_service_instance FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_provider_service_instance ON service_endpoint_provider_service_instance;
CREATE TRIGGER trigger_audit_service_endpoint_provider_service_instance AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_provider_service_instance FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_provider_service_instance();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_provider_shared_netblock_layer3_i ON service_endpoint_provider_shared_netblock_layer3_interface;
CREATE TRIGGER trig_userlog_service_endpoint_provider_shared_netblock_layer3_i BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_provider_shared_netblock_layer3_interface FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_provider_shared_netblock_layer3_ ON service_endpoint_provider_shared_netblock_layer3_interface;
CREATE TRIGGER trigger_audit_service_endpoint_provider_shared_netblock_layer3_ AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_provider_shared_netblock_layer3_interface FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_provider_shared_netblock_layer3_();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_service_endpoint_provider_collect ON service_endpoint_service_endpoint_provider_collection;
CREATE TRIGGER trig_userlog_service_endpoint_service_endpoint_provider_collect BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_service_endpoint_provider_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_service_endpoint_provider_collec ON service_endpoint_service_endpoint_provider_collection;
CREATE TRIGGER trigger_audit_service_endpoint_service_endpoint_provider_collec AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_service_endpoint_provider_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_service_endpoint_provider_collec();
DROP TRIGGER IF EXISTS trigger_svc_end_prov_svc_end_col_direct_check ON service_endpoint_service_endpoint_provider_collection;
CREATE CONSTRAINT TRIGGER trigger_svc_end_prov_svc_end_col_direct_check AFTER INSERT OR UPDATE OF service_endpoint_provider_collection_id, service_endpoint_relation_type, service_endpoint_relation_key ON jazzhands.service_endpoint_service_endpoint_provider_collection NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.svc_end_prov_svc_end_col_direct_check();
DROP TRIGGER IF EXISTS trigger_svc_ep_svc_epp_coll_direct ON service_endpoint_service_endpoint_provider_collection;
CREATE CONSTRAINT TRIGGER trigger_svc_ep_svc_epp_coll_direct AFTER INSERT OR UPDATE OF service_endpoint_relation_type, service_endpoint_relation_key ON jazzhands.service_endpoint_service_endpoint_provider_collection NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.svc_ep_svc_epp_coll_direct();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_service_sla ON service_endpoint_service_sla;
CREATE TRIGGER trig_userlog_service_endpoint_service_sla BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_service_sla FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_service_sla ON service_endpoint_service_sla;
CREATE TRIGGER trigger_audit_service_endpoint_service_sla AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_service_sla FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_service_sla();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_service_sla_service_feature ON service_endpoint_service_sla_service_feature;
CREATE TRIGGER trig_userlog_service_endpoint_service_sla_service_feature BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_service_sla_service_feature FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_service_sla_service_feature ON service_endpoint_service_sla_service_feature;
CREATE TRIGGER trigger_audit_service_endpoint_service_sla_service_feature AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_service_sla_service_feature FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_service_sla_service_feature();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_x509_certificate ON service_endpoint_x509_certificate;
CREATE TRIGGER trig_userlog_service_endpoint_x509_certificate BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_x509_certificate FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_x509_certificate ON service_endpoint_x509_certificate;
CREATE TRIGGER trigger_audit_service_endpoint_x509_certificate AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_x509_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_x509_certificate();
DROP TRIGGER IF EXISTS trig_userlog_service_environment ON service_environment;
CREATE TRIGGER trig_userlog_service_environment BEFORE INSERT OR UPDATE ON jazzhands.service_environment FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_environment ON service_environment;
CREATE TRIGGER trigger_audit_service_environment AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_environment FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_environment();
DROP TRIGGER IF EXISTS trigger_delete_per_service_environment_service_environment_coll ON service_environment;
CREATE TRIGGER trigger_delete_per_service_environment_service_environment_coll BEFORE DELETE ON jazzhands.service_environment FOR EACH ROW EXECUTE FUNCTION jazzhands.delete_per_service_environment_service_environment_collection();
DROP TRIGGER IF EXISTS trigger_update_per_service_environment_service_environment_coll ON service_environment;
CREATE TRIGGER trigger_update_per_service_environment_service_environment_coll AFTER INSERT OR UPDATE ON jazzhands.service_environment FOR EACH ROW EXECUTE FUNCTION jazzhands.update_per_service_environment_service_environment_collection();
DROP TRIGGER IF EXISTS trig_userlog_service_environment_collection ON service_environment_collection;
CREATE TRIGGER trig_userlog_service_environment_collection BEFORE INSERT OR UPDATE ON jazzhands.service_environment_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_environment_collection ON service_environment_collection;
CREATE TRIGGER trigger_audit_service_environment_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_environment_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_environment_collection();
DROP TRIGGER IF EXISTS trigger_manip_service_environment_collection_bytype_del ON service_environment_collection;
CREATE TRIGGER trigger_manip_service_environment_collection_bytype_del BEFORE DELETE ON jazzhands.service_environment_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_service_environment_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_service_environment_collection_bytype_insup ON service_environment_collection;
CREATE TRIGGER trigger_manip_service_environment_collection_bytype_insup AFTER INSERT OR UPDATE OF service_environment_collection_type ON jazzhands.service_environment_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_service_environment_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_service_environment_collection_type_change ON service_environment_collection;
CREATE TRIGGER trigger_validate_service_environment_collection_type_change BEFORE UPDATE OF service_environment_collection_type ON jazzhands.service_environment_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_service_environment_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_service_environment_collection_hier ON service_environment_collection_hier;
CREATE TRIGGER trig_userlog_service_environment_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.service_environment_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_environment_collection_hier ON service_environment_collection_hier;
CREATE TRIGGER trigger_audit_service_environment_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_environment_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_environment_collection_hier();
DROP TRIGGER IF EXISTS trigger_check_svcenv_collection_hier_loop ON service_environment_collection_hier;
CREATE TRIGGER trigger_check_svcenv_collection_hier_loop AFTER INSERT OR UPDATE ON jazzhands.service_environment_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.check_svcenv_colllection_hier_loop();
DROP TRIGGER IF EXISTS trigger_service_environment_collection_hier_enforce ON service_environment_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_service_environment_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.service_environment_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_environment_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_service_environment_collection_service_environment ON service_environment_collection_service_environment;
CREATE TRIGGER trig_userlog_service_environment_collection_service_environment BEFORE INSERT OR UPDATE ON jazzhands.service_environment_collection_service_environment FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_environment_collection_service_environmen ON service_environment_collection_service_environment;
CREATE TRIGGER trigger_audit_service_environment_collection_service_environmen AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_environment_collection_service_environment FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_environment_collection_service_environmen();
DROP TRIGGER IF EXISTS trigger_service_environment_collection_member_enforce ON service_environment_collection_service_environment;
CREATE CONSTRAINT TRIGGER trigger_service_environment_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.service_environment_collection_service_environment DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_environment_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_service_instance ON service_instance;
CREATE TRIGGER trig_userlog_service_instance BEFORE INSERT OR UPDATE ON jazzhands.service_instance FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_instance ON service_instance;
CREATE TRIGGER trigger_audit_service_instance AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_instance FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_instance();
DROP TRIGGER IF EXISTS trig_userlog_service_instance_provided_feature ON service_instance_provided_feature;
CREATE TRIGGER trig_userlog_service_instance_provided_feature BEFORE INSERT OR UPDATE ON jazzhands.service_instance_provided_feature FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_instance_provided_feature ON service_instance_provided_feature;
CREATE TRIGGER trigger_audit_service_instance_provided_feature AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_instance_provided_feature FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_instance_provided_feature();
DROP TRIGGER IF EXISTS trigger_service_instance_feature_check ON service_instance_provided_feature;
CREATE CONSTRAINT TRIGGER trigger_service_instance_feature_check AFTER INSERT ON jazzhands.service_instance_provided_feature NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_instance_feature_check();
DROP TRIGGER IF EXISTS trigger_service_instance_service_feature_rename ON service_instance_provided_feature;
CREATE CONSTRAINT TRIGGER trigger_service_instance_service_feature_rename AFTER UPDATE OF service_feature, service_instance_id ON jazzhands.service_instance_provided_feature NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_instance_service_feature_rename();
DROP TRIGGER IF EXISTS trig_userlog_service_layer3_acl ON service_layer3_acl;
CREATE TRIGGER trig_userlog_service_layer3_acl BEFORE INSERT OR UPDATE ON jazzhands.service_layer3_acl FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_layer3_acl ON service_layer3_acl;
CREATE TRIGGER trigger_audit_service_layer3_acl AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_layer3_acl FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_layer3_acl();
DROP TRIGGER IF EXISTS trig_userlog_service_relationship ON service_relationship;
CREATE TRIGGER trig_userlog_service_relationship BEFORE INSERT OR UPDATE ON jazzhands.service_relationship FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_relationship ON service_relationship;
CREATE TRIGGER trigger_audit_service_relationship AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_relationship FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_relationship();
DROP TRIGGER IF EXISTS trigger_check_service_relationship_rhs ON service_relationship;
CREATE CONSTRAINT TRIGGER trigger_check_service_relationship_rhs AFTER INSERT OR UPDATE OF related_service_version_id, service_version_restriction_service_id, service_version_restriction ON jazzhands.service_relationship NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.check_service_relationship_rhs();
DROP TRIGGER IF EXISTS trig_userlog_service_relationship_service_feature ON service_relationship_service_feature;
CREATE TRIGGER trig_userlog_service_relationship_service_feature BEFORE INSERT OR UPDATE ON jazzhands.service_relationship_service_feature FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_relationship_service_feature ON service_relationship_service_feature;
CREATE TRIGGER trigger_audit_service_relationship_service_feature AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_relationship_service_feature FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_relationship_service_feature();
DROP TRIGGER IF EXISTS trigger_service_relationship_feature_check ON service_relationship_service_feature;
CREATE CONSTRAINT TRIGGER trigger_service_relationship_feature_check AFTER INSERT OR UPDATE OF service_feature ON jazzhands.service_relationship_service_feature NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_relationship_feature_check();
DROP TRIGGER IF EXISTS trig_userlog_service_sla ON service_sla;
CREATE TRIGGER trig_userlog_service_sla BEFORE INSERT OR UPDATE ON jazzhands.service_sla FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_sla ON service_sla;
CREATE TRIGGER trigger_audit_service_sla AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_sla FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_sla();
DROP TRIGGER IF EXISTS trig_userlog_service_software_repository ON service_software_repository;
CREATE TRIGGER trig_userlog_service_software_repository BEFORE INSERT OR UPDATE ON jazzhands.service_software_repository FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_software_repository ON service_software_repository;
CREATE TRIGGER trigger_audit_service_software_repository AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_software_repository FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_software_repository();
DROP TRIGGER IF EXISTS trig_userlog_service_source_repository ON service_source_repository;
CREATE TRIGGER trig_userlog_service_source_repository BEFORE INSERT OR UPDATE ON jazzhands.service_source_repository FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_source_repository ON service_source_repository;
CREATE TRIGGER trigger_audit_service_source_repository AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_source_repository FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_source_repository();
DROP TRIGGER IF EXISTS trigger_service_source_repository_sanity ON service_source_repository;
CREATE CONSTRAINT TRIGGER trigger_service_source_repository_sanity AFTER INSERT OR UPDATE OF is_primary ON jazzhands.service_source_repository NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_source_repository_sanity();
DROP TRIGGER IF EXISTS trigger_service_source_repository_service_match_check ON service_source_repository;
CREATE CONSTRAINT TRIGGER trigger_service_source_repository_service_match_check AFTER UPDATE OF service_id, service_source_repository_id ON jazzhands.service_source_repository NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_source_repository_service_match_check();
DROP TRIGGER IF EXISTS trig_userlog_service_version ON service_version;
CREATE TRIGGER trig_userlog_service_version BEFORE INSERT OR UPDATE ON jazzhands.service_version FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version ON service_version;
CREATE TRIGGER trigger_audit_service_version AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version();
DROP TRIGGER IF EXISTS trigger_manip_all_svc_collection_members ON service_version;
CREATE TRIGGER trigger_manip_all_svc_collection_members AFTER INSERT ON jazzhands.service_version FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_all_svc_collection_members();
DROP TRIGGER IF EXISTS trigger_manip_all_svc_collection_members_del ON service_version;
CREATE TRIGGER trigger_manip_all_svc_collection_members_del BEFORE DELETE ON jazzhands.service_version FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_all_svc_collection_members();
DROP TRIGGER IF EXISTS trigger_propagate_service_type_to_version ON service_version;
CREATE TRIGGER trigger_propagate_service_type_to_version BEFORE INSERT ON jazzhands.service_version FOR EACH ROW EXECUTE FUNCTION jazzhands.propagate_service_type_to_version();
DROP TRIGGER IF EXISTS trig_userlog_service_version_artifact ON service_version_artifact;
CREATE TRIGGER trig_userlog_service_version_artifact BEFORE INSERT OR UPDATE ON jazzhands.service_version_artifact FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version_artifact ON service_version_artifact;
CREATE TRIGGER trigger_audit_service_version_artifact AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version_artifact FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version_artifact();
DROP TRIGGER IF EXISTS trig_userlog_service_version_collection ON service_version_collection;
CREATE TRIGGER trig_userlog_service_version_collection BEFORE INSERT OR UPDATE ON jazzhands.service_version_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version_collection ON service_version_collection;
CREATE TRIGGER trigger_audit_service_version_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version_collection();
DROP TRIGGER IF EXISTS trig_userlog_service_version_collection_hier ON service_version_collection_hier;
CREATE TRIGGER trig_userlog_service_version_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.service_version_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version_collection_hier ON service_version_collection_hier;
CREATE TRIGGER trigger_audit_service_version_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version_collection_hier();
DROP TRIGGER IF EXISTS trig_userlog_service_version_collection_permitted_feature ON service_version_collection_permitted_feature;
CREATE TRIGGER trig_userlog_service_version_collection_permitted_feature BEFORE INSERT OR UPDATE ON jazzhands.service_version_collection_permitted_feature FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version_collection_permitted_feature ON service_version_collection_permitted_feature;
CREATE TRIGGER trigger_audit_service_version_collection_permitted_feature AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version_collection_permitted_feature FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version_collection_permitted_feature();
DROP TRIGGER IF EXISTS trigger_service_version_feature_permitted_rename ON service_version_collection_permitted_feature;
CREATE CONSTRAINT TRIGGER trigger_service_version_feature_permitted_rename AFTER UPDATE OF service_feature ON jazzhands.service_version_collection_permitted_feature NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_version_feature_permitted_rename();
DROP TRIGGER IF EXISTS trig_userlog_service_version_collection_service_version ON service_version_collection_service_version;
CREATE TRIGGER trig_userlog_service_version_collection_service_version BEFORE INSERT OR UPDATE ON jazzhands.service_version_collection_service_version FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version_collection_service_version ON service_version_collection_service_version;
CREATE TRIGGER trigger_audit_service_version_collection_service_version AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version_collection_service_version FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version_collection_service_version();
DROP TRIGGER IF EXISTS trig_userlog_service_version_software_artifact_repository ON service_version_software_artifact_repository;
CREATE TRIGGER trig_userlog_service_version_software_artifact_repository BEFORE INSERT OR UPDATE ON jazzhands.service_version_software_artifact_repository FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version_software_artifact_repository ON service_version_software_artifact_repository;
CREATE TRIGGER trigger_audit_service_version_software_artifact_repository AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version_software_artifact_repository FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version_software_artifact_repository();
DROP TRIGGER IF EXISTS trig_userlog_service_version_source_repository ON service_version_source_repository;
CREATE TRIGGER trig_userlog_service_version_source_repository BEFORE INSERT OR UPDATE ON jazzhands.service_version_source_repository FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version_source_repository ON service_version_source_repository;
CREATE TRIGGER trigger_audit_service_version_source_repository AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version_source_repository FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version_source_repository();
DROP TRIGGER IF EXISTS trigger_service_version_source_repository_service_match_check ON service_version_source_repository;
CREATE CONSTRAINT TRIGGER trigger_service_version_source_repository_service_match_check AFTER INSERT OR UPDATE OF service_version_id, service_source_repository_id ON jazzhands.service_version_source_repository NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_version_source_repository_service_match_check();
DROP TRIGGER IF EXISTS trig_userlog_shared_netblock ON shared_netblock;
CREATE TRIGGER trig_userlog_shared_netblock BEFORE INSERT OR UPDATE ON jazzhands.shared_netblock FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_shared_netblock ON shared_netblock;
CREATE TRIGGER trigger_audit_shared_netblock AFTER INSERT OR DELETE OR UPDATE ON jazzhands.shared_netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_shared_netblock();
DROP TRIGGER IF EXISTS trig_userlog_shared_netblock_layer3_interface ON shared_netblock_layer3_interface;
CREATE TRIGGER trig_userlog_shared_netblock_layer3_interface BEFORE INSERT OR UPDATE ON jazzhands.shared_netblock_layer3_interface FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_shared_netblock_layer3_interface ON shared_netblock_layer3_interface;
CREATE TRIGGER trigger_audit_shared_netblock_layer3_interface AFTER INSERT OR DELETE OR UPDATE ON jazzhands.shared_netblock_layer3_interface FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_shared_netblock_layer3_interface();
DROP TRIGGER IF EXISTS trig_userlog_site ON site;
CREATE TRIGGER trig_userlog_site BEFORE INSERT OR UPDATE ON jazzhands.site FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_site ON site;
CREATE TRIGGER trigger_audit_site AFTER INSERT OR DELETE OR UPDATE ON jazzhands.site FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_site();
DROP TRIGGER IF EXISTS trigger_del_site_netblock_collections ON site;
CREATE TRIGGER trigger_del_site_netblock_collections BEFORE DELETE ON jazzhands.site FOR EACH ROW EXECUTE FUNCTION jazzhands.del_site_netblock_collections();
DROP TRIGGER IF EXISTS trigger_ins_site_netblock_collections ON site;
CREATE TRIGGER trigger_ins_site_netblock_collections AFTER INSERT ON jazzhands.site FOR EACH ROW EXECUTE FUNCTION jazzhands.ins_site_netblock_collections();
DROP TRIGGER IF EXISTS trigger_upd_site_netblock_collections ON site;
CREATE TRIGGER trigger_upd_site_netblock_collections AFTER UPDATE ON jazzhands.site FOR EACH ROW EXECUTE FUNCTION jazzhands.upd_site_netblock_collections();
DROP TRIGGER IF EXISTS trig_userlog_slot ON slot;
CREATE TRIGGER trig_userlog_slot BEFORE INSERT OR UPDATE ON jazzhands.slot FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_slot ON slot;
CREATE TRIGGER trigger_audit_slot AFTER INSERT OR DELETE OR UPDATE ON jazzhands.slot FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_slot();
DROP TRIGGER IF EXISTS trig_userlog_slot_type ON slot_type;
CREATE TRIGGER trig_userlog_slot_type BEFORE INSERT OR UPDATE ON jazzhands.slot_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_slot_type ON slot_type;
CREATE TRIGGER trigger_audit_slot_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.slot_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_slot_type();
DROP TRIGGER IF EXISTS trig_userlog_slot_type_permitted_component_slot_type ON slot_type_permitted_component_slot_type;
CREATE TRIGGER trig_userlog_slot_type_permitted_component_slot_type BEFORE INSERT OR UPDATE ON jazzhands.slot_type_permitted_component_slot_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_slot_type_permitted_component_slot_type ON slot_type_permitted_component_slot_type;
CREATE TRIGGER trigger_audit_slot_type_permitted_component_slot_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.slot_type_permitted_component_slot_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_slot_type_permitted_component_slot_type();
DROP TRIGGER IF EXISTS trig_userlog_slot_type_permitted_remote_slot_type ON slot_type_permitted_remote_slot_type;
CREATE TRIGGER trig_userlog_slot_type_permitted_remote_slot_type BEFORE INSERT OR UPDATE ON jazzhands.slot_type_permitted_remote_slot_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_slot_type_permitted_remote_slot_type ON slot_type_permitted_remote_slot_type;
CREATE TRIGGER trigger_audit_slot_type_permitted_remote_slot_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.slot_type_permitted_remote_slot_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_slot_type_permitted_remote_slot_type();
DROP TRIGGER IF EXISTS trig_userlog_software_artifact_name ON software_artifact_name;
CREATE TRIGGER trig_userlog_software_artifact_name BEFORE INSERT OR UPDATE ON jazzhands.software_artifact_name FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_software_artifact_name ON software_artifact_name;
CREATE TRIGGER trigger_audit_software_artifact_name AFTER INSERT OR DELETE OR UPDATE ON jazzhands.software_artifact_name FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_software_artifact_name();
DROP TRIGGER IF EXISTS trig_userlog_software_artifact_provider ON software_artifact_provider;
CREATE TRIGGER trig_userlog_software_artifact_provider BEFORE INSERT OR UPDATE ON jazzhands.software_artifact_provider FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_software_artifact_provider ON software_artifact_provider;
CREATE TRIGGER trigger_audit_software_artifact_provider AFTER INSERT OR DELETE OR UPDATE ON jazzhands.software_artifact_provider FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_software_artifact_provider();
DROP TRIGGER IF EXISTS trig_userlog_software_artifact_repository ON software_artifact_repository;
CREATE TRIGGER trig_userlog_software_artifact_repository BEFORE INSERT OR UPDATE ON jazzhands.software_artifact_repository FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_software_artifact_repository ON software_artifact_repository;
CREATE TRIGGER trigger_audit_software_artifact_repository AFTER INSERT OR DELETE OR UPDATE ON jazzhands.software_artifact_repository FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_software_artifact_repository();
DROP TRIGGER IF EXISTS trig_userlog_software_artifact_repository_relation ON software_artifact_repository_relation;
CREATE TRIGGER trig_userlog_software_artifact_repository_relation BEFORE INSERT OR UPDATE ON jazzhands.software_artifact_repository_relation FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_software_artifact_repository_relation ON software_artifact_repository_relation;
CREATE TRIGGER trigger_audit_software_artifact_repository_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.software_artifact_repository_relation FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_software_artifact_repository_relation();
DROP TRIGGER IF EXISTS trig_userlog_software_artifact_repository_uri ON software_artifact_repository_uri;
CREATE TRIGGER trig_userlog_software_artifact_repository_uri BEFORE INSERT OR UPDATE ON jazzhands.software_artifact_repository_uri FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_software_artifact_repository_uri ON software_artifact_repository_uri;
CREATE TRIGGER trigger_audit_software_artifact_repository_uri AFTER INSERT OR DELETE OR UPDATE ON jazzhands.software_artifact_repository_uri FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_software_artifact_repository_uri();
DROP TRIGGER IF EXISTS trigger_software_artifact_repository_uri_endpoint_enforce ON software_artifact_repository_uri;
CREATE CONSTRAINT TRIGGER trigger_software_artifact_repository_uri_endpoint_enforce AFTER INSERT OR UPDATE OF software_artifact_repository_uri, service_endpoint_id ON jazzhands.software_artifact_repository_uri NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.software_artifact_repository_uri_endpoint_enforce();
DROP TRIGGER IF EXISTS trig_userlog_source_repository ON source_repository;
CREATE TRIGGER trig_userlog_source_repository BEFORE INSERT OR UPDATE ON jazzhands.source_repository FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_source_repository ON source_repository;
CREATE TRIGGER trigger_audit_source_repository AFTER INSERT OR DELETE OR UPDATE ON jazzhands.source_repository FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_source_repository();
DROP TRIGGER IF EXISTS trig_userlog_source_repository_commit ON source_repository_commit;
CREATE TRIGGER trig_userlog_source_repository_commit BEFORE INSERT OR UPDATE ON jazzhands.source_repository_commit FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_source_repository_commit ON source_repository_commit;
CREATE TRIGGER trigger_audit_source_repository_commit AFTER INSERT OR DELETE OR UPDATE ON jazzhands.source_repository_commit FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_source_repository_commit();
DROP TRIGGER IF EXISTS trig_userlog_source_repository_project ON source_repository_project;
CREATE TRIGGER trig_userlog_source_repository_project BEFORE INSERT OR UPDATE ON jazzhands.source_repository_project FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_source_repository_project ON source_repository_project;
CREATE TRIGGER trigger_audit_source_repository_project AFTER INSERT OR DELETE OR UPDATE ON jazzhands.source_repository_project FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_source_repository_project();
DROP TRIGGER IF EXISTS trig_userlog_source_repository_provider ON source_repository_provider;
CREATE TRIGGER trig_userlog_source_repository_provider BEFORE INSERT OR UPDATE ON jazzhands.source_repository_provider FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_source_repository_provider ON source_repository_provider;
CREATE TRIGGER trigger_audit_source_repository_provider AFTER INSERT OR DELETE OR UPDATE ON jazzhands.source_repository_provider FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_source_repository_provider();
DROP TRIGGER IF EXISTS trig_userlog_source_repository_provider_uri_template ON source_repository_provider_uri_template;
CREATE TRIGGER trig_userlog_source_repository_provider_uri_template BEFORE INSERT OR UPDATE ON jazzhands.source_repository_provider_uri_template FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_source_repository_provider_uri_template ON source_repository_provider_uri_template;
CREATE TRIGGER trigger_audit_source_repository_provider_uri_template AFTER INSERT OR DELETE OR UPDATE ON jazzhands.source_repository_provider_uri_template FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_source_repository_provider_uri_template();
DROP TRIGGER IF EXISTS trigger_source_repository_provider_uri_template_endpoint_enforc ON source_repository_provider_uri_template;
CREATE CONSTRAINT TRIGGER trigger_source_repository_provider_uri_template_endpoint_enforc AFTER INSERT OR UPDATE OF source_repository_uri, service_endpoint_id ON jazzhands.source_repository_provider_uri_template NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.source_repository_provider_uri_template_endpoint_enforce();
DROP TRIGGER IF EXISTS trig_userlog_ssh_key ON ssh_key;
CREATE TRIGGER trig_userlog_ssh_key BEFORE INSERT OR UPDATE ON jazzhands.ssh_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_ssh_key ON ssh_key;
CREATE TRIGGER trigger_audit_ssh_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.ssh_key FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_ssh_key();
DROP TRIGGER IF EXISTS trig_userlog_static_route ON static_route;
CREATE TRIGGER trig_userlog_static_route BEFORE INSERT OR UPDATE ON jazzhands.static_route FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_static_route ON static_route;
CREATE TRIGGER trigger_audit_static_route AFTER INSERT OR DELETE OR UPDATE ON jazzhands.static_route FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_static_route();
DROP TRIGGER IF EXISTS trig_userlog_static_route_template ON static_route_template;
CREATE TRIGGER trig_userlog_static_route_template BEFORE INSERT OR UPDATE ON jazzhands.static_route_template FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_static_route_template ON static_route_template;
CREATE TRIGGER trigger_audit_static_route_template AFTER INSERT OR DELETE OR UPDATE ON jazzhands.static_route_template FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_static_route_template();
DROP TRIGGER IF EXISTS trig_userlog_sudo_account_collection_device_collection ON sudo_account_collection_device_collection;
CREATE TRIGGER trig_userlog_sudo_account_collection_device_collection BEFORE INSERT OR UPDATE ON jazzhands.sudo_account_collection_device_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_sudo_account_collection_device_collection ON sudo_account_collection_device_collection;
CREATE TRIGGER trigger_audit_sudo_account_collection_device_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.sudo_account_collection_device_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_sudo_account_collection_device_collection();
DROP TRIGGER IF EXISTS trig_userlog_sudo_alias ON sudo_alias;
CREATE TRIGGER trig_userlog_sudo_alias BEFORE INSERT OR UPDATE ON jazzhands.sudo_alias FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_sudo_alias ON sudo_alias;
CREATE TRIGGER trigger_audit_sudo_alias AFTER INSERT OR DELETE OR UPDATE ON jazzhands.sudo_alias FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_sudo_alias();
DROP TRIGGER IF EXISTS trig_userlog_ticketing_system ON ticketing_system;
CREATE TRIGGER trig_userlog_ticketing_system BEFORE INSERT OR UPDATE ON jazzhands.ticketing_system FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_ticketing_system ON ticketing_system;
CREATE TRIGGER trigger_audit_ticketing_system AFTER INSERT OR DELETE OR UPDATE ON jazzhands.ticketing_system FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_ticketing_system();
DROP TRIGGER IF EXISTS trig_userlog_token ON token;
CREATE TRIGGER trig_userlog_token BEFORE INSERT OR UPDATE ON jazzhands.token FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_token ON token;
CREATE TRIGGER trigger_audit_token AFTER INSERT OR DELETE OR UPDATE ON jazzhands.token FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_token();
DROP TRIGGER IF EXISTS trigger_pgnotify_token_change ON token;
CREATE TRIGGER trigger_pgnotify_token_change AFTER INSERT OR UPDATE ON jazzhands.token FOR EACH ROW EXECUTE FUNCTION jazzhands.pgnotify_token_change();
DROP TRIGGER IF EXISTS trig_userlog_token_collection ON token_collection;
CREATE TRIGGER trig_userlog_token_collection BEFORE INSERT OR UPDATE ON jazzhands.token_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_token_collection ON token_collection;
CREATE TRIGGER trigger_audit_token_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.token_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_token_collection();
DROP TRIGGER IF EXISTS trig_userlog_token_collection_hier ON token_collection_hier;
CREATE TRIGGER trig_userlog_token_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.token_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_token_collection_hier ON token_collection_hier;
CREATE TRIGGER trigger_audit_token_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.token_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_token_collection_hier();
DROP TRIGGER IF EXISTS trigger_check_token_collection_hier_loop ON token_collection_hier;
CREATE TRIGGER trigger_check_token_collection_hier_loop AFTER INSERT OR UPDATE ON jazzhands.token_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.check_token_colllection_hier_loop();
DROP TRIGGER IF EXISTS trigger_token_collection_hier_enforce ON token_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_token_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.token_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.token_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_token_collection_token ON token_collection_token;
CREATE TRIGGER trig_userlog_token_collection_token BEFORE INSERT OR UPDATE ON jazzhands.token_collection_token FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_token_collection_token ON token_collection_token;
CREATE TRIGGER trigger_audit_token_collection_token AFTER INSERT OR DELETE OR UPDATE ON jazzhands.token_collection_token FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_token_collection_token();
DROP TRIGGER IF EXISTS trigger_token_collection_member_enforce ON token_collection_token;
CREATE CONSTRAINT TRIGGER trigger_token_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.token_collection_token DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.token_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_unix_group ON unix_group;
CREATE TRIGGER trig_userlog_unix_group BEFORE INSERT OR UPDATE ON jazzhands.unix_group FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_unix_group ON unix_group;
CREATE TRIGGER trigger_audit_unix_group AFTER INSERT OR DELETE OR UPDATE ON jazzhands.unix_group FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_unix_group();
DROP TRIGGER IF EXISTS trig_userlog_val_account_collection_relation ON val_account_collection_relation;
CREATE TRIGGER trig_userlog_val_account_collection_relation BEFORE INSERT OR UPDATE ON jazzhands.val_account_collection_relation FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_acct_coll_preserve_direct ON val_account_collection_relation;
CREATE CONSTRAINT TRIGGER trigger_acct_coll_preserve_direct AFTER DELETE OR UPDATE ON jazzhands.val_account_collection_relation DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.acct_coll_preserve_direct();
DROP TRIGGER IF EXISTS trigger_audit_val_account_collection_relation ON val_account_collection_relation;
CREATE TRIGGER trigger_audit_val_account_collection_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_account_collection_relation FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_account_collection_relation();
DROP TRIGGER IF EXISTS trig_account_collection_type_realm ON val_account_collection_type;
CREATE TRIGGER trig_account_collection_type_realm AFTER UPDATE OF account_realm_id ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.account_collection_type_realm();
DROP TRIGGER IF EXISTS trig_userlog_val_account_collection_type ON val_account_collection_type;
CREATE TRIGGER trig_userlog_val_account_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_acct_coll_insert_direct ON val_account_collection_type;
CREATE TRIGGER trigger_acct_coll_insert_direct AFTER INSERT ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.acct_coll_insert_direct();
DROP TRIGGER IF EXISTS trigger_acct_coll_remove_direct ON val_account_collection_type;
CREATE TRIGGER trigger_acct_coll_remove_direct BEFORE DELETE ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.acct_coll_remove_direct();
DROP TRIGGER IF EXISTS trigger_acct_coll_update_direct_before ON val_account_collection_type;
CREATE TRIGGER trigger_acct_coll_update_direct_before AFTER UPDATE OF account_collection_type ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.acct_coll_update_direct_before();
DROP TRIGGER IF EXISTS trigger_audit_val_account_collection_type ON val_account_collection_type;
CREATE TRIGGER trigger_audit_val_account_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_account_collection_type();
DROP TRIGGER IF EXISTS trig_userlog_val_account_role ON val_account_role;
CREATE TRIGGER trig_userlog_val_account_role BEFORE INSERT OR UPDATE ON jazzhands.val_account_role FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_account_role ON val_account_role;
CREATE TRIGGER trigger_audit_val_account_role AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_account_role FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_account_role();
DROP TRIGGER IF EXISTS trig_userlog_val_account_type ON val_account_type;
CREATE TRIGGER trig_userlog_val_account_type BEFORE INSERT OR UPDATE ON jazzhands.val_account_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_account_type ON val_account_type;
CREATE TRIGGER trigger_audit_val_account_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_account_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_account_type();
DROP TRIGGER IF EXISTS trig_userlog_val_appaal_group_name ON val_appaal_group_name;
CREATE TRIGGER trig_userlog_val_appaal_group_name BEFORE INSERT OR UPDATE ON jazzhands.val_appaal_group_name FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_appaal_group_name ON val_appaal_group_name;
CREATE TRIGGER trigger_audit_val_appaal_group_name AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_appaal_group_name FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_appaal_group_name();
DROP TRIGGER IF EXISTS trig_userlog_val_application_key ON val_application_key;
CREATE TRIGGER trig_userlog_val_application_key BEFORE INSERT OR UPDATE ON jazzhands.val_application_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_application_key ON val_application_key;
CREATE TRIGGER trigger_audit_val_application_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_application_key FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_application_key();
DROP TRIGGER IF EXISTS trig_userlog_val_application_key_values ON val_application_key_values;
CREATE TRIGGER trig_userlog_val_application_key_values BEFORE INSERT OR UPDATE ON jazzhands.val_application_key_values FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_application_key_values ON val_application_key_values;
CREATE TRIGGER trigger_audit_val_application_key_values AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_application_key_values FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_application_key_values();
DROP TRIGGER IF EXISTS trig_userlog_val_approval_chain_response_period ON val_approval_chain_response_period;
CREATE TRIGGER trig_userlog_val_approval_chain_response_period BEFORE INSERT OR UPDATE ON jazzhands.val_approval_chain_response_period FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_approval_chain_response_period ON val_approval_chain_response_period;
CREATE TRIGGER trigger_audit_val_approval_chain_response_period AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_approval_chain_response_period FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_approval_chain_response_period();
DROP TRIGGER IF EXISTS trig_userlog_val_approval_expiration_action ON val_approval_expiration_action;
CREATE TRIGGER trig_userlog_val_approval_expiration_action BEFORE INSERT OR UPDATE ON jazzhands.val_approval_expiration_action FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_approval_expiration_action ON val_approval_expiration_action;
CREATE TRIGGER trigger_audit_val_approval_expiration_action AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_approval_expiration_action FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_approval_expiration_action();
DROP TRIGGER IF EXISTS trig_userlog_val_approval_notifty_type ON val_approval_notifty_type;
CREATE TRIGGER trig_userlog_val_approval_notifty_type BEFORE INSERT OR UPDATE ON jazzhands.val_approval_notifty_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_approval_notifty_type ON val_approval_notifty_type;
CREATE TRIGGER trigger_audit_val_approval_notifty_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_approval_notifty_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_approval_notifty_type();
DROP TRIGGER IF EXISTS trig_userlog_val_approval_process_type ON val_approval_process_type;
CREATE TRIGGER trig_userlog_val_approval_process_type BEFORE INSERT OR UPDATE ON jazzhands.val_approval_process_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_approval_process_type ON val_approval_process_type;
CREATE TRIGGER trigger_audit_val_approval_process_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_approval_process_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_approval_process_type();
DROP TRIGGER IF EXISTS trig_userlog_val_approval_type ON val_approval_type;
CREATE TRIGGER trig_userlog_val_approval_type BEFORE INSERT OR UPDATE ON jazzhands.val_approval_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_approval_type ON val_approval_type;
CREATE TRIGGER trigger_audit_val_approval_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_approval_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_approval_type();
DROP TRIGGER IF EXISTS trig_userlog_val_attestation_frequency ON val_attestation_frequency;
CREATE TRIGGER trig_userlog_val_attestation_frequency BEFORE INSERT OR UPDATE ON jazzhands.val_attestation_frequency FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_attestation_frequency ON val_attestation_frequency;
CREATE TRIGGER trigger_audit_val_attestation_frequency AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_attestation_frequency FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_attestation_frequency();
DROP TRIGGER IF EXISTS trig_userlog_val_authentication_question ON val_authentication_question;
CREATE TRIGGER trig_userlog_val_authentication_question BEFORE INSERT OR UPDATE ON jazzhands.val_authentication_question FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_authentication_question ON val_authentication_question;
CREATE TRIGGER trigger_audit_val_authentication_question AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_authentication_question FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_authentication_question();
DROP TRIGGER IF EXISTS trig_userlog_val_authentication_resource ON val_authentication_resource;
CREATE TRIGGER trig_userlog_val_authentication_resource BEFORE INSERT OR UPDATE ON jazzhands.val_authentication_resource FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_authentication_resource ON val_authentication_resource;
CREATE TRIGGER trigger_audit_val_authentication_resource AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_authentication_resource FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_authentication_resource();
DROP TRIGGER IF EXISTS trig_userlog_val_badge_status ON val_badge_status;
CREATE TRIGGER trig_userlog_val_badge_status BEFORE INSERT OR UPDATE ON jazzhands.val_badge_status FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_badge_status ON val_badge_status;
CREATE TRIGGER trigger_audit_val_badge_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_badge_status FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_badge_status();
DROP TRIGGER IF EXISTS trig_userlog_val_cable_type ON val_cable_type;
CREATE TRIGGER trig_userlog_val_cable_type BEFORE INSERT OR UPDATE ON jazzhands.val_cable_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_cable_type ON val_cable_type;
CREATE TRIGGER trigger_audit_val_cable_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_cable_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_cable_type();
DROP TRIGGER IF EXISTS trig_userlog_val_checksum_algorithm ON val_checksum_algorithm;
CREATE TRIGGER trig_userlog_val_checksum_algorithm BEFORE INSERT OR UPDATE ON jazzhands.val_checksum_algorithm FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_checksum_algorithm ON val_checksum_algorithm;
CREATE TRIGGER trigger_audit_val_checksum_algorithm AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_checksum_algorithm FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_checksum_algorithm();
DROP TRIGGER IF EXISTS trig_userlog_val_company_collection_type ON val_company_collection_type;
CREATE TRIGGER trig_userlog_val_company_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_company_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_company_collection_type ON val_company_collection_type;
CREATE TRIGGER trigger_audit_val_company_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_company_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_company_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_company_collection_type_bytype_del ON val_company_collection_type;
CREATE TRIGGER trigger_manip_company_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_company_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_company_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_company_collection_type_bytype_insup ON val_company_collection_type;
CREATE TRIGGER trigger_manip_company_collection_type_bytype_insup AFTER INSERT OR UPDATE OF company_collection_type ON jazzhands.val_company_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_company_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_company_type ON val_company_type;
CREATE TRIGGER trig_userlog_val_company_type BEFORE INSERT OR UPDATE ON jazzhands.val_company_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_company_type ON val_company_type;
CREATE TRIGGER trigger_audit_val_company_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_company_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_company_type();
DROP TRIGGER IF EXISTS trig_userlog_val_company_type_purpose ON val_company_type_purpose;
CREATE TRIGGER trig_userlog_val_company_type_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_company_type_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_company_type_purpose ON val_company_type_purpose;
CREATE TRIGGER trigger_audit_val_company_type_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_company_type_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_company_type_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_component_function ON val_component_function;
CREATE TRIGGER trig_userlog_val_component_function BEFORE INSERT OR UPDATE ON jazzhands.val_component_function FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_component_function ON val_component_function;
CREATE TRIGGER trigger_audit_val_component_function AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_component_function FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_component_function();
DROP TRIGGER IF EXISTS trig_userlog_val_component_property ON val_component_property;
CREATE TRIGGER trig_userlog_val_component_property BEFORE INSERT OR UPDATE ON jazzhands.val_component_property FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_component_property ON val_component_property;
CREATE TRIGGER trigger_audit_val_component_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_component_property FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_component_property();
DROP TRIGGER IF EXISTS trig_userlog_val_component_property_type ON val_component_property_type;
CREATE TRIGGER trig_userlog_val_component_property_type BEFORE INSERT OR UPDATE ON jazzhands.val_component_property_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_component_property_type ON val_component_property_type;
CREATE TRIGGER trigger_audit_val_component_property_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_component_property_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_component_property_type();
DROP TRIGGER IF EXISTS trig_userlog_val_component_property_value ON val_component_property_value;
CREATE TRIGGER trig_userlog_val_component_property_value BEFORE INSERT OR UPDATE ON jazzhands.val_component_property_value FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_component_property_value ON val_component_property_value;
CREATE TRIGGER trigger_audit_val_component_property_value AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_component_property_value FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_component_property_value();
DROP TRIGGER IF EXISTS trig_userlog_val_contract_type ON val_contract_type;
CREATE TRIGGER trig_userlog_val_contract_type BEFORE INSERT OR UPDATE ON jazzhands.val_contract_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_contract_type ON val_contract_type;
CREATE TRIGGER trigger_audit_val_contract_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_contract_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_contract_type();
DROP TRIGGER IF EXISTS trig_userlog_val_country_code ON val_country_code;
CREATE TRIGGER trig_userlog_val_country_code BEFORE INSERT OR UPDATE ON jazzhands.val_country_code FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_country_code ON val_country_code;
CREATE TRIGGER trigger_audit_val_country_code AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_country_code FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_country_code();
DROP TRIGGER IF EXISTS trig_userlog_val_device_collection_type ON val_device_collection_type;
CREATE TRIGGER trig_userlog_val_device_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_device_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_device_collection_type ON val_device_collection_type;
CREATE TRIGGER trigger_audit_val_device_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_device_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_device_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_device_collection_type_bytype_del ON val_device_collection_type;
CREATE TRIGGER trigger_manip_device_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_device_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_device_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_device_collection_type_bytype_insup ON val_device_collection_type;
CREATE TRIGGER trigger_manip_device_collection_type_bytype_insup AFTER INSERT OR UPDATE OF device_collection_type ON jazzhands.val_device_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_device_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_device_management_controller_type ON val_device_management_controller_type;
CREATE TRIGGER trig_userlog_val_device_management_controller_type BEFORE INSERT OR UPDATE ON jazzhands.val_device_management_controller_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_device_management_controller_type ON val_device_management_controller_type;
CREATE TRIGGER trigger_audit_val_device_management_controller_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_device_management_controller_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_device_management_controller_type();
DROP TRIGGER IF EXISTS trig_userlog_val_device_status ON val_device_status;
CREATE TRIGGER trig_userlog_val_device_status BEFORE INSERT OR UPDATE ON jazzhands.val_device_status FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_device_status ON val_device_status;
CREATE TRIGGER trigger_audit_val_device_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_device_status FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_device_status();
DROP TRIGGER IF EXISTS trig_userlog_val_diet ON val_diet;
CREATE TRIGGER trig_userlog_val_diet BEFORE INSERT OR UPDATE ON jazzhands.val_diet FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_diet ON val_diet;
CREATE TRIGGER trigger_audit_val_diet AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_diet FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_diet();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_class ON val_dns_class;
CREATE TRIGGER trig_userlog_val_dns_class BEFORE INSERT OR UPDATE ON jazzhands.val_dns_class FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_class ON val_dns_class;
CREATE TRIGGER trigger_audit_val_dns_class AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_class FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_dns_class();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_domain_collection_type ON val_dns_domain_collection_type;
CREATE TRIGGER trig_userlog_val_dns_domain_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_dns_domain_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_domain_collection_type ON val_dns_domain_collection_type;
CREATE TRIGGER trigger_audit_val_dns_domain_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_domain_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_dns_domain_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_dns_domain_collection_type_bytype_del ON val_dns_domain_collection_type;
CREATE TRIGGER trigger_manip_dns_domain_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_dns_domain_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_dns_domain_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_dns_domain_collection_type_bytype_insup ON val_dns_domain_collection_type;
CREATE TRIGGER trigger_manip_dns_domain_collection_type_bytype_insup AFTER INSERT OR UPDATE OF dns_domain_collection_type ON jazzhands.val_dns_domain_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_dns_domain_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_domain_type ON val_dns_domain_type;
CREATE TRIGGER trig_userlog_val_dns_domain_type BEFORE INSERT OR UPDATE ON jazzhands.val_dns_domain_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_domain_type ON val_dns_domain_type;
CREATE TRIGGER trigger_audit_val_dns_domain_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_domain_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_dns_domain_type();
DROP TRIGGER IF EXISTS trigger_dns_domain_type_should_generate ON val_dns_domain_type;
CREATE TRIGGER trigger_dns_domain_type_should_generate AFTER UPDATE OF can_generate ON jazzhands.val_dns_domain_type FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_type_should_generate();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_record_relation_type ON val_dns_record_relation_type;
CREATE TRIGGER trig_userlog_val_dns_record_relation_type BEFORE INSERT OR UPDATE ON jazzhands.val_dns_record_relation_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_record_relation_type ON val_dns_record_relation_type;
CREATE TRIGGER trigger_audit_val_dns_record_relation_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_record_relation_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_dns_record_relation_type();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_srv_service ON val_dns_srv_service;
CREATE TRIGGER trig_userlog_val_dns_srv_service BEFORE INSERT OR UPDATE ON jazzhands.val_dns_srv_service FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_srv_service ON val_dns_srv_service;
CREATE TRIGGER trigger_audit_val_dns_srv_service AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_srv_service FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_dns_srv_service();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_type ON val_dns_type;
CREATE TRIGGER trig_userlog_val_dns_type BEFORE INSERT OR UPDATE ON jazzhands.val_dns_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_type ON val_dns_type;
CREATE TRIGGER trigger_audit_val_dns_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_dns_type();
DROP TRIGGER IF EXISTS trig_userlog_val_encapsulation_mode ON val_encapsulation_mode;
CREATE TRIGGER trig_userlog_val_encapsulation_mode BEFORE INSERT OR UPDATE ON jazzhands.val_encapsulation_mode FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_encapsulation_mode ON val_encapsulation_mode;
CREATE TRIGGER trigger_audit_val_encapsulation_mode AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_encapsulation_mode FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_encapsulation_mode();
DROP TRIGGER IF EXISTS trig_userlog_val_encapsulation_type ON val_encapsulation_type;
CREATE TRIGGER trig_userlog_val_encapsulation_type BEFORE INSERT OR UPDATE ON jazzhands.val_encapsulation_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_encapsulation_type ON val_encapsulation_type;
CREATE TRIGGER trigger_audit_val_encapsulation_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_encapsulation_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_encapsulation_type();
DROP TRIGGER IF EXISTS trig_userlog_val_encryption_method ON val_encryption_method;
CREATE TRIGGER trig_userlog_val_encryption_method BEFORE INSERT OR UPDATE ON jazzhands.val_encryption_method FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_encryption_method ON val_encryption_method;
CREATE TRIGGER trigger_audit_val_encryption_method AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_encryption_method FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_encryption_method();
DROP TRIGGER IF EXISTS trig_userlog_val_filesystem_type ON val_filesystem_type;
CREATE TRIGGER trig_userlog_val_filesystem_type BEFORE INSERT OR UPDATE ON jazzhands.val_filesystem_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_filesystem_type ON val_filesystem_type;
CREATE TRIGGER trigger_audit_val_filesystem_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_filesystem_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_filesystem_type();
DROP TRIGGER IF EXISTS trig_userlog_val_gender ON val_gender;
CREATE TRIGGER trig_userlog_val_gender BEFORE INSERT OR UPDATE ON jazzhands.val_gender FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_gender ON val_gender;
CREATE TRIGGER trigger_audit_val_gender AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_gender FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_gender();
DROP TRIGGER IF EXISTS trig_userlog_val_image_type ON val_image_type;
CREATE TRIGGER trig_userlog_val_image_type BEFORE INSERT OR UPDATE ON jazzhands.val_image_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_image_type ON val_image_type;
CREATE TRIGGER trigger_audit_val_image_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_image_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_image_type();
DROP TRIGGER IF EXISTS trig_userlog_val_ip_namespace ON val_ip_namespace;
CREATE TRIGGER trig_userlog_val_ip_namespace BEFORE INSERT OR UPDATE ON jazzhands.val_ip_namespace FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_ip_namespace ON val_ip_namespace;
CREATE TRIGGER trigger_audit_val_ip_namespace AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_ip_namespace FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_ip_namespace();
DROP TRIGGER IF EXISTS trig_userlog_val_iso_currency_code ON val_iso_currency_code;
CREATE TRIGGER trig_userlog_val_iso_currency_code BEFORE INSERT OR UPDATE ON jazzhands.val_iso_currency_code FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_iso_currency_code ON val_iso_currency_code;
CREATE TRIGGER trigger_audit_val_iso_currency_code AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_iso_currency_code FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_iso_currency_code();
DROP TRIGGER IF EXISTS trig_userlog_val_key_usage_reason_for_assignment ON val_key_usage_reason_for_assignment;
CREATE TRIGGER trig_userlog_val_key_usage_reason_for_assignment BEFORE INSERT OR UPDATE ON jazzhands.val_key_usage_reason_for_assignment FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_key_usage_reason_for_assignment ON val_key_usage_reason_for_assignment;
CREATE TRIGGER trigger_audit_val_key_usage_reason_for_assignment AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_key_usage_reason_for_assignment FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_key_usage_reason_for_assignment();
DROP TRIGGER IF EXISTS trig_userlog_val_layer2_network_collection_type ON val_layer2_network_collection_type;
CREATE TRIGGER trig_userlog_val_layer2_network_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_layer2_network_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_layer2_network_collection_type ON val_layer2_network_collection_type;
CREATE TRIGGER trigger_audit_val_layer2_network_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_layer2_network_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_layer2_network_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_layer2_network_collection_type_bytype_del ON val_layer2_network_collection_type;
CREATE TRIGGER trigger_manip_layer2_network_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_layer2_network_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer2_network_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_layer2_network_collection_type_bytype_insup ON val_layer2_network_collection_type;
CREATE TRIGGER trigger_manip_layer2_network_collection_type_bytype_insup AFTER INSERT OR UPDATE OF layer2_network_collection_type ON jazzhands.val_layer2_network_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer2_network_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_layer3_acl_group_type ON val_layer3_acl_group_type;
CREATE TRIGGER trig_userlog_val_layer3_acl_group_type BEFORE INSERT OR UPDATE ON jazzhands.val_layer3_acl_group_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_layer3_acl_group_type ON val_layer3_acl_group_type;
CREATE TRIGGER trigger_audit_val_layer3_acl_group_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_layer3_acl_group_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_layer3_acl_group_type();
DROP TRIGGER IF EXISTS trig_userlog_val_layer3_interface_purpose ON val_layer3_interface_purpose;
CREATE TRIGGER trig_userlog_val_layer3_interface_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_layer3_interface_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_layer3_interface_purpose ON val_layer3_interface_purpose;
CREATE TRIGGER trigger_audit_val_layer3_interface_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_layer3_interface_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_layer3_interface_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_layer3_interface_type ON val_layer3_interface_type;
CREATE TRIGGER trig_userlog_val_layer3_interface_type BEFORE INSERT OR UPDATE ON jazzhands.val_layer3_interface_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_layer3_interface_type ON val_layer3_interface_type;
CREATE TRIGGER trigger_audit_val_layer3_interface_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_layer3_interface_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_layer3_interface_type();
DROP TRIGGER IF EXISTS trig_userlog_val_layer3_network_collection_type ON val_layer3_network_collection_type;
CREATE TRIGGER trig_userlog_val_layer3_network_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_layer3_network_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_layer3_network_collection_type ON val_layer3_network_collection_type;
CREATE TRIGGER trigger_audit_val_layer3_network_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_layer3_network_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_layer3_network_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_layer3_network_collection_type_bytype_del ON val_layer3_network_collection_type;
CREATE TRIGGER trigger_manip_layer3_network_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_layer3_network_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer3_network_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_layer3_network_collection_type_bytype_insup ON val_layer3_network_collection_type;
CREATE TRIGGER trigger_manip_layer3_network_collection_type_bytype_insup AFTER INSERT OR UPDATE OF layer3_network_collection_type ON jazzhands.val_layer3_network_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer3_network_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_logical_port_type ON val_logical_port_type;
CREATE TRIGGER trig_userlog_val_logical_port_type BEFORE INSERT OR UPDATE ON jazzhands.val_logical_port_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_logical_port_type ON val_logical_port_type;
CREATE TRIGGER trigger_audit_val_logical_port_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_logical_port_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_logical_port_type();
DROP TRIGGER IF EXISTS trig_userlog_val_logical_volume_property ON val_logical_volume_property;
CREATE TRIGGER trig_userlog_val_logical_volume_property BEFORE INSERT OR UPDATE ON jazzhands.val_logical_volume_property FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_logical_volume_property ON val_logical_volume_property;
CREATE TRIGGER trigger_audit_val_logical_volume_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_logical_volume_property FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_logical_volume_property();
DROP TRIGGER IF EXISTS trig_userlog_val_logical_volume_purpose ON val_logical_volume_purpose;
CREATE TRIGGER trig_userlog_val_logical_volume_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_logical_volume_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_logical_volume_purpose ON val_logical_volume_purpose;
CREATE TRIGGER trigger_audit_val_logical_volume_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_logical_volume_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_logical_volume_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_logical_volume_type ON val_logical_volume_type;
CREATE TRIGGER trig_userlog_val_logical_volume_type BEFORE INSERT OR UPDATE ON jazzhands.val_logical_volume_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_logical_volume_type ON val_logical_volume_type;
CREATE TRIGGER trigger_audit_val_logical_volume_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_logical_volume_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_logical_volume_type();
DROP TRIGGER IF EXISTS trig_userlog_val_netblock_collection_type ON val_netblock_collection_type;
CREATE TRIGGER trig_userlog_val_netblock_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_netblock_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_netblock_collection_type ON val_netblock_collection_type;
CREATE TRIGGER trigger_audit_val_netblock_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_netblock_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_netblock_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_netblock_collection_type_bytype_del ON val_netblock_collection_type;
CREATE TRIGGER trigger_manip_netblock_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_netblock_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_netblock_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_netblock_collection_type_bytype_insup ON val_netblock_collection_type;
CREATE TRIGGER trigger_manip_netblock_collection_type_bytype_insup AFTER INSERT OR UPDATE OF netblock_collection_type ON jazzhands.val_netblock_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_netblock_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_netblock_status ON val_netblock_status;
CREATE TRIGGER trig_userlog_val_netblock_status BEFORE INSERT OR UPDATE ON jazzhands.val_netblock_status FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_netblock_status ON val_netblock_status;
CREATE TRIGGER trigger_audit_val_netblock_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_netblock_status FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_netblock_status();
DROP TRIGGER IF EXISTS trig_userlog_val_netblock_type ON val_netblock_type;
CREATE TRIGGER trig_userlog_val_netblock_type BEFORE INSERT OR UPDATE ON jazzhands.val_netblock_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_netblock_type ON val_netblock_type;
CREATE TRIGGER trigger_audit_val_netblock_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_netblock_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_netblock_type();
DROP TRIGGER IF EXISTS trig_userlog_val_network_range_type ON val_network_range_type;
CREATE TRIGGER trig_userlog_val_network_range_type BEFORE INSERT OR UPDATE ON jazzhands.val_network_range_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_network_range_type ON val_network_range_type;
CREATE TRIGGER trigger_audit_val_network_range_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_network_range_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_network_range_type();
DROP TRIGGER IF EXISTS trigger_validate_net_range_toggle_nonoverlap ON val_network_range_type;
CREATE CONSTRAINT TRIGGER trigger_validate_net_range_toggle_nonoverlap AFTER UPDATE OF can_overlap, require_cidr_boundary ON jazzhands.val_network_range_type DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_net_range_toggle_nonoverlap();
DROP TRIGGER IF EXISTS trigger_validate_val_network_range_type ON val_network_range_type;
CREATE CONSTRAINT TRIGGER trigger_validate_val_network_range_type AFTER UPDATE OF dns_domain_required, netblock_type ON jazzhands.val_network_range_type DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_val_network_range_type();
DROP TRIGGER IF EXISTS trig_userlog_val_network_service_type ON val_network_service_type;
CREATE TRIGGER trig_userlog_val_network_service_type BEFORE INSERT OR UPDATE ON jazzhands.val_network_service_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_network_service_type ON val_network_service_type;
CREATE TRIGGER trigger_audit_val_network_service_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_network_service_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_network_service_type();
DROP TRIGGER IF EXISTS trig_userlog_val_operating_system_family ON val_operating_system_family;
CREATE TRIGGER trig_userlog_val_operating_system_family BEFORE INSERT OR UPDATE ON jazzhands.val_operating_system_family FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_operating_system_family ON val_operating_system_family;
CREATE TRIGGER trigger_audit_val_operating_system_family AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_operating_system_family FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_operating_system_family();
DROP TRIGGER IF EXISTS trig_userlog_val_operating_system_snapshot_type ON val_operating_system_snapshot_type;
CREATE TRIGGER trig_userlog_val_operating_system_snapshot_type BEFORE INSERT OR UPDATE ON jazzhands.val_operating_system_snapshot_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_operating_system_snapshot_type ON val_operating_system_snapshot_type;
CREATE TRIGGER trigger_audit_val_operating_system_snapshot_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_operating_system_snapshot_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_operating_system_snapshot_type();
DROP TRIGGER IF EXISTS trig_userlog_val_ownership_status ON val_ownership_status;
CREATE TRIGGER trig_userlog_val_ownership_status BEFORE INSERT OR UPDATE ON jazzhands.val_ownership_status FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_ownership_status ON val_ownership_status;
CREATE TRIGGER trigger_audit_val_ownership_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_ownership_status FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_ownership_status();
DROP TRIGGER IF EXISTS trig_userlog_val_password_type ON val_password_type;
CREATE TRIGGER trig_userlog_val_password_type BEFORE INSERT OR UPDATE ON jazzhands.val_password_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_password_type ON val_password_type;
CREATE TRIGGER trigger_audit_val_password_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_password_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_password_type();
DROP TRIGGER IF EXISTS trig_userlog_val_person_company_attribute_data_type ON val_person_company_attribute_data_type;
CREATE TRIGGER trig_userlog_val_person_company_attribute_data_type BEFORE INSERT OR UPDATE ON jazzhands.val_person_company_attribute_data_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_company_attribute_data_type ON val_person_company_attribute_data_type;
CREATE TRIGGER trigger_audit_val_person_company_attribute_data_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_company_attribute_data_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_company_attribute_data_type();
DROP TRIGGER IF EXISTS trig_userlog_val_person_company_attribute_name ON val_person_company_attribute_name;
CREATE TRIGGER trig_userlog_val_person_company_attribute_name BEFORE INSERT OR UPDATE ON jazzhands.val_person_company_attribute_name FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_company_attribute_name ON val_person_company_attribute_name;
CREATE TRIGGER trigger_audit_val_person_company_attribute_name AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_company_attribute_name FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_company_attribute_name();
DROP TRIGGER IF EXISTS trig_userlog_val_person_company_attribute_value ON val_person_company_attribute_value;
CREATE TRIGGER trig_userlog_val_person_company_attribute_value BEFORE INSERT OR UPDATE ON jazzhands.val_person_company_attribute_value FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_company_attribute_value ON val_person_company_attribute_value;
CREATE TRIGGER trigger_audit_val_person_company_attribute_value AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_company_attribute_value FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_company_attribute_value();
DROP TRIGGER IF EXISTS trigger_person_company_attribute_change_after_row_hooks ON val_person_company_attribute_value;
CREATE TRIGGER trigger_person_company_attribute_change_after_row_hooks AFTER INSERT OR UPDATE ON jazzhands.val_person_company_attribute_value FOR EACH ROW EXECUTE FUNCTION jazzhands.person_company_attribute_change_after_row_hooks();
DROP TRIGGER IF EXISTS trigger_validate_pers_comp_attr_value ON val_person_company_attribute_value;
CREATE TRIGGER trigger_validate_pers_comp_attr_value BEFORE DELETE OR UPDATE OF person_company_attribute_name, person_company_attribute_value ON jazzhands.val_person_company_attribute_value FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_pers_comp_attr_value();
DROP TRIGGER IF EXISTS trig_userlog_val_person_company_relation ON val_person_company_relation;
CREATE TRIGGER trig_userlog_val_person_company_relation BEFORE INSERT OR UPDATE ON jazzhands.val_person_company_relation FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_company_relation ON val_person_company_relation;
CREATE TRIGGER trigger_audit_val_person_company_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_company_relation FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_company_relation();
DROP TRIGGER IF EXISTS trig_userlog_val_person_contact_location_type ON val_person_contact_location_type;
CREATE TRIGGER trig_userlog_val_person_contact_location_type BEFORE INSERT OR UPDATE ON jazzhands.val_person_contact_location_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_contact_location_type ON val_person_contact_location_type;
CREATE TRIGGER trigger_audit_val_person_contact_location_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_contact_location_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_contact_location_type();
DROP TRIGGER IF EXISTS trig_userlog_val_person_contact_technology ON val_person_contact_technology;
CREATE TRIGGER trig_userlog_val_person_contact_technology BEFORE INSERT OR UPDATE ON jazzhands.val_person_contact_technology FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_contact_technology ON val_person_contact_technology;
CREATE TRIGGER trigger_audit_val_person_contact_technology AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_contact_technology FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_contact_technology();
DROP TRIGGER IF EXISTS trig_userlog_val_person_contact_type ON val_person_contact_type;
CREATE TRIGGER trig_userlog_val_person_contact_type BEFORE INSERT OR UPDATE ON jazzhands.val_person_contact_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_contact_type ON val_person_contact_type;
CREATE TRIGGER trigger_audit_val_person_contact_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_contact_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_contact_type();
DROP TRIGGER IF EXISTS trig_userlog_val_person_image_usage ON val_person_image_usage;
CREATE TRIGGER trig_userlog_val_person_image_usage BEFORE INSERT OR UPDATE ON jazzhands.val_person_image_usage FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_image_usage ON val_person_image_usage;
CREATE TRIGGER trigger_audit_val_person_image_usage AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_image_usage FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_image_usage();
DROP TRIGGER IF EXISTS trig_userlog_val_person_location_type ON val_person_location_type;
CREATE TRIGGER trig_userlog_val_person_location_type BEFORE INSERT OR UPDATE ON jazzhands.val_person_location_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_location_type ON val_person_location_type;
CREATE TRIGGER trigger_audit_val_person_location_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_location_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_location_type();
DROP TRIGGER IF EXISTS trig_userlog_val_person_status ON val_person_status;
CREATE TRIGGER trig_userlog_val_person_status BEFORE INSERT OR UPDATE ON jazzhands.val_person_status FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_status ON val_person_status;
CREATE TRIGGER trigger_audit_val_person_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_status FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_status();
DROP TRIGGER IF EXISTS trig_userlog_val_physical_address_type ON val_physical_address_type;
CREATE TRIGGER trig_userlog_val_physical_address_type BEFORE INSERT OR UPDATE ON jazzhands.val_physical_address_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_physical_address_type ON val_physical_address_type;
CREATE TRIGGER trigger_audit_val_physical_address_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_physical_address_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_physical_address_type();
DROP TRIGGER IF EXISTS trig_userlog_val_physicalish_volume_type ON val_physicalish_volume_type;
CREATE TRIGGER trig_userlog_val_physicalish_volume_type BEFORE INSERT OR UPDATE ON jazzhands.val_physicalish_volume_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_physicalish_volume_type ON val_physicalish_volume_type;
CREATE TRIGGER trigger_audit_val_physicalish_volume_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_physicalish_volume_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_physicalish_volume_type();
DROP TRIGGER IF EXISTS trig_userlog_val_port_range_type ON val_port_range_type;
CREATE TRIGGER trig_userlog_val_port_range_type BEFORE INSERT OR UPDATE ON jazzhands.val_port_range_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_port_range_type ON val_port_range_type;
CREATE TRIGGER trigger_audit_val_port_range_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_port_range_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_port_range_type();
DROP TRIGGER IF EXISTS trigger_val_port_range_sanity_check ON val_port_range_type;
CREATE CONSTRAINT TRIGGER trigger_val_port_range_sanity_check AFTER UPDATE OF range_permitted ON jazzhands.val_port_range_type NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.val_port_range_sanity_check();
DROP TRIGGER IF EXISTS trig_userlog_val_private_key_encryption_type ON val_private_key_encryption_type;
CREATE TRIGGER trig_userlog_val_private_key_encryption_type BEFORE INSERT OR UPDATE ON jazzhands.val_private_key_encryption_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_private_key_encryption_type ON val_private_key_encryption_type;
CREATE TRIGGER trigger_audit_val_private_key_encryption_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_private_key_encryption_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_private_key_encryption_type();
DROP TRIGGER IF EXISTS trig_userlog_val_processor_architecture ON val_processor_architecture;
CREATE TRIGGER trig_userlog_val_processor_architecture BEFORE INSERT OR UPDATE ON jazzhands.val_processor_architecture FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_processor_architecture ON val_processor_architecture;
CREATE TRIGGER trigger_audit_val_processor_architecture AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_processor_architecture FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_processor_architecture();
DROP TRIGGER IF EXISTS trig_userlog_val_production_state ON val_production_state;
CREATE TRIGGER trig_userlog_val_production_state BEFORE INSERT OR UPDATE ON jazzhands.val_production_state FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_production_state ON val_production_state;
CREATE TRIGGER trigger_audit_val_production_state AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_production_state FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_production_state();
DROP TRIGGER IF EXISTS trig_userlog_val_property ON val_property;
CREATE TRIGGER trig_userlog_val_property BEFORE INSERT OR UPDATE ON jazzhands.val_property FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_property ON val_property;
CREATE TRIGGER trigger_audit_val_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_property FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_property();
DROP TRIGGER IF EXISTS trigger_validate_val_property ON val_property;
CREATE TRIGGER trigger_validate_val_property BEFORE INSERT OR UPDATE OF property_data_type, property_value_json_schema, permit_company_id ON jazzhands.val_property FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_val_property();
DROP TRIGGER IF EXISTS trigger_validate_val_property_after ON val_property;
CREATE CONSTRAINT TRIGGER trigger_validate_val_property_after AFTER UPDATE ON jazzhands.val_property DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_val_property_after();
DROP TRIGGER IF EXISTS trig_userlog_val_property_data_type ON val_property_data_type;
CREATE TRIGGER trig_userlog_val_property_data_type BEFORE INSERT OR UPDATE ON jazzhands.val_property_data_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_property_data_type ON val_property_data_type;
CREATE TRIGGER trigger_audit_val_property_data_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_property_data_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_property_data_type();
DROP TRIGGER IF EXISTS trig_userlog_val_property_name_collection_type ON val_property_name_collection_type;
CREATE TRIGGER trig_userlog_val_property_name_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_property_name_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_property_name_collection_type ON val_property_name_collection_type;
CREATE TRIGGER trigger_audit_val_property_name_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_property_name_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_property_name_collection_type();
DROP TRIGGER IF EXISTS trig_userlog_val_property_type ON val_property_type;
CREATE TRIGGER trig_userlog_val_property_type BEFORE INSERT OR UPDATE ON jazzhands.val_property_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_property_type ON val_property_type;
CREATE TRIGGER trigger_audit_val_property_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_property_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_property_type();
DROP TRIGGER IF EXISTS trig_userlog_val_property_value ON val_property_value;
CREATE TRIGGER trig_userlog_val_property_value BEFORE INSERT OR UPDATE ON jazzhands.val_property_value FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_property_value ON val_property_value;
CREATE TRIGGER trigger_audit_val_property_value AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_property_value FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_property_value();
DROP TRIGGER IF EXISTS trigger_val_property_value_del_check ON val_property_value;
CREATE CONSTRAINT TRIGGER trigger_val_property_value_del_check AFTER DELETE ON jazzhands.val_property_value DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.val_property_value_del_check();
DROP TRIGGER IF EXISTS trig_userlog_val_rack_type ON val_rack_type;
CREATE TRIGGER trig_userlog_val_rack_type BEFORE INSERT OR UPDATE ON jazzhands.val_rack_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_rack_type ON val_rack_type;
CREATE TRIGGER trigger_audit_val_rack_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_rack_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_rack_type();
DROP TRIGGER IF EXISTS trig_userlog_val_raid_type ON val_raid_type;
CREATE TRIGGER trig_userlog_val_raid_type BEFORE INSERT OR UPDATE ON jazzhands.val_raid_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_raid_type ON val_raid_type;
CREATE TRIGGER trigger_audit_val_raid_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_raid_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_raid_type();
DROP TRIGGER IF EXISTS trig_userlog_val_service_affinity ON val_service_affinity;
CREATE TRIGGER trig_userlog_val_service_affinity BEFORE INSERT OR UPDATE ON jazzhands.val_service_affinity FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_affinity ON val_service_affinity;
CREATE TRIGGER trigger_audit_val_service_affinity AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_affinity FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_affinity();
DROP TRIGGER IF EXISTS trig_userlog_val_service_endpoint_provider_collection_type ON val_service_endpoint_provider_collection_type;
CREATE TRIGGER trig_userlog_val_service_endpoint_provider_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_endpoint_provider_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_endpoint_provider_collection_type ON val_service_endpoint_provider_collection_type;
CREATE TRIGGER trigger_audit_val_service_endpoint_provider_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_endpoint_provider_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_endpoint_provider_collection_type();
DROP TRIGGER IF EXISTS trig_userlog_val_service_endpoint_provider_type ON val_service_endpoint_provider_type;
CREATE TRIGGER trig_userlog_val_service_endpoint_provider_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_endpoint_provider_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_endpoint_provider_type ON val_service_endpoint_provider_type;
CREATE TRIGGER trigger_audit_val_service_endpoint_provider_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_endpoint_provider_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_endpoint_provider_type();
DROP TRIGGER IF EXISTS trig_userlog_val_service_environment_collection_type ON val_service_environment_collection_type;
CREATE TRIGGER trig_userlog_val_service_environment_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_environment_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_environment_collection_type ON val_service_environment_collection_type;
CREATE TRIGGER trigger_audit_val_service_environment_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_environment_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_environment_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_service_environment_collection_type_bytype_del ON val_service_environment_collection_type;
CREATE TRIGGER trigger_manip_service_environment_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_service_environment_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_service_environment_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_service_environment_collection_type_bytype_insup ON val_service_environment_collection_type;
CREATE TRIGGER trigger_manip_service_environment_collection_type_bytype_insup AFTER INSERT OR UPDATE OF service_environment_collection_type ON jazzhands.val_service_environment_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_service_environment_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_service_environment_type ON val_service_environment_type;
CREATE TRIGGER trig_userlog_val_service_environment_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_environment_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_environment_type ON val_service_environment_type;
CREATE TRIGGER trigger_audit_val_service_environment_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_environment_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_environment_type();
DROP TRIGGER IF EXISTS trig_userlog_val_service_feature ON val_service_feature;
CREATE TRIGGER trig_userlog_val_service_feature BEFORE INSERT OR UPDATE ON jazzhands.val_service_feature FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_feature ON val_service_feature;
CREATE TRIGGER trigger_audit_val_service_feature AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_feature FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_feature();
DROP TRIGGER IF EXISTS trig_userlog_val_service_namespace ON val_service_namespace;
CREATE TRIGGER trig_userlog_val_service_namespace BEFORE INSERT OR UPDATE ON jazzhands.val_service_namespace FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_namespace ON val_service_namespace;
CREATE TRIGGER trigger_audit_val_service_namespace AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_namespace FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_namespace();
DROP TRIGGER IF EXISTS trig_userlog_val_service_relationship_type ON val_service_relationship_type;
CREATE TRIGGER trig_userlog_val_service_relationship_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_relationship_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_relationship_type ON val_service_relationship_type;
CREATE TRIGGER trigger_audit_val_service_relationship_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_relationship_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_relationship_type();
DROP TRIGGER IF EXISTS trig_userlog_val_service_source_control_purpose ON val_service_source_control_purpose;
CREATE TRIGGER trig_userlog_val_service_source_control_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_service_source_control_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_source_control_purpose ON val_service_source_control_purpose;
CREATE TRIGGER trigger_audit_val_service_source_control_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_source_control_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_source_control_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_service_type ON val_service_type;
CREATE TRIGGER trig_userlog_val_service_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_type ON val_service_type;
CREATE TRIGGER trigger_audit_val_service_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_type();
DROP TRIGGER IF EXISTS trigger_check_service_type_namespace ON val_service_type;
CREATE CONSTRAINT TRIGGER trigger_check_service_type_namespace AFTER UPDATE OF service_namespace ON jazzhands.val_service_type NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.check_service_type_namespace();
DROP TRIGGER IF EXISTS trigger_check_service_type_relation_regexp_change ON val_service_type;
CREATE CONSTRAINT TRIGGER trigger_check_service_type_relation_regexp_change AFTER UPDATE OF service_version_restriction_regular_expression ON jazzhands.val_service_type NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.check_service_type_relation_regexp_change();
DROP TRIGGER IF EXISTS trig_userlog_val_service_version_collection_type ON val_service_version_collection_type;
CREATE TRIGGER trig_userlog_val_service_version_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_version_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_version_collection_type ON val_service_version_collection_type;
CREATE TRIGGER trigger_audit_val_service_version_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_version_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_version_collection_type();
DROP TRIGGER IF EXISTS trig_userlog_val_shared_netblock_protocol ON val_shared_netblock_protocol;
CREATE TRIGGER trig_userlog_val_shared_netblock_protocol BEFORE INSERT OR UPDATE ON jazzhands.val_shared_netblock_protocol FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_shared_netblock_protocol ON val_shared_netblock_protocol;
CREATE TRIGGER trigger_audit_val_shared_netblock_protocol AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_shared_netblock_protocol FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_shared_netblock_protocol();
DROP TRIGGER IF EXISTS trig_userlog_val_slot_function ON val_slot_function;
CREATE TRIGGER trig_userlog_val_slot_function BEFORE INSERT OR UPDATE ON jazzhands.val_slot_function FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_slot_function ON val_slot_function;
CREATE TRIGGER trigger_audit_val_slot_function AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_slot_function FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_slot_function();
DROP TRIGGER IF EXISTS trig_userlog_val_slot_physical_interface ON val_slot_physical_interface;
CREATE TRIGGER trig_userlog_val_slot_physical_interface BEFORE INSERT OR UPDATE ON jazzhands.val_slot_physical_interface FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_slot_physical_interface ON val_slot_physical_interface;
CREATE TRIGGER trigger_audit_val_slot_physical_interface AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_slot_physical_interface FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_slot_physical_interface();
DROP TRIGGER IF EXISTS trig_userlog_val_software_artifact_relationship ON val_software_artifact_relationship;
CREATE TRIGGER trig_userlog_val_software_artifact_relationship BEFORE INSERT OR UPDATE ON jazzhands.val_software_artifact_relationship FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_software_artifact_relationship ON val_software_artifact_relationship;
CREATE TRIGGER trigger_audit_val_software_artifact_relationship AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_software_artifact_relationship FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_software_artifact_relationship();
DROP TRIGGER IF EXISTS trig_userlog_val_software_artifact_repository_uri_type ON val_software_artifact_repository_uri_type;
CREATE TRIGGER trig_userlog_val_software_artifact_repository_uri_type BEFORE INSERT OR UPDATE ON jazzhands.val_software_artifact_repository_uri_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_software_artifact_repository_uri_type ON val_software_artifact_repository_uri_type;
CREATE TRIGGER trigger_audit_val_software_artifact_repository_uri_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_software_artifact_repository_uri_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_software_artifact_repository_uri_type();
DROP TRIGGER IF EXISTS trig_userlog_val_software_artifact_type ON val_software_artifact_type;
CREATE TRIGGER trig_userlog_val_software_artifact_type BEFORE INSERT OR UPDATE ON jazzhands.val_software_artifact_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_software_artifact_type ON val_software_artifact_type;
CREATE TRIGGER trigger_audit_val_software_artifact_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_software_artifact_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_software_artifact_type();
DROP TRIGGER IF EXISTS trig_userlog_val_source_repository_method ON val_source_repository_method;
CREATE TRIGGER trig_userlog_val_source_repository_method BEFORE INSERT OR UPDATE ON jazzhands.val_source_repository_method FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_source_repository_method ON val_source_repository_method;
CREATE TRIGGER trigger_audit_val_source_repository_method AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_source_repository_method FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_source_repository_method();
DROP TRIGGER IF EXISTS trig_userlog_val_source_repository_protocol ON val_source_repository_protocol;
CREATE TRIGGER trig_userlog_val_source_repository_protocol BEFORE INSERT OR UPDATE ON jazzhands.val_source_repository_protocol FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_source_repository_protocol ON val_source_repository_protocol;
CREATE TRIGGER trigger_audit_val_source_repository_protocol AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_source_repository_protocol FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_source_repository_protocol();
DROP TRIGGER IF EXISTS trig_userlog_val_source_repository_uri_purpose ON val_source_repository_uri_purpose;
CREATE TRIGGER trig_userlog_val_source_repository_uri_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_source_repository_uri_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_source_repository_uri_purpose ON val_source_repository_uri_purpose;
CREATE TRIGGER trigger_audit_val_source_repository_uri_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_source_repository_uri_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_source_repository_uri_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_ssh_key_type ON val_ssh_key_type;
CREATE TRIGGER trig_userlog_val_ssh_key_type BEFORE INSERT OR UPDATE ON jazzhands.val_ssh_key_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_ssh_key_type ON val_ssh_key_type;
CREATE TRIGGER trigger_audit_val_ssh_key_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_ssh_key_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_ssh_key_type();
DROP TRIGGER IF EXISTS trig_userlog_val_token_collection_type ON val_token_collection_type;
CREATE TRIGGER trig_userlog_val_token_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_token_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_token_collection_type ON val_token_collection_type;
CREATE TRIGGER trigger_audit_val_token_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_token_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_token_collection_type();
DROP TRIGGER IF EXISTS trig_userlog_val_token_status ON val_token_status;
CREATE TRIGGER trig_userlog_val_token_status BEFORE INSERT OR UPDATE ON jazzhands.val_token_status FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_token_status ON val_token_status;
CREATE TRIGGER trigger_audit_val_token_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_token_status FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_token_status();
DROP TRIGGER IF EXISTS trig_userlog_val_token_type ON val_token_type;
CREATE TRIGGER trig_userlog_val_token_type BEFORE INSERT OR UPDATE ON jazzhands.val_token_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_token_type ON val_token_type;
CREATE TRIGGER trigger_audit_val_token_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_token_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_token_type();
DROP TRIGGER IF EXISTS trig_userlog_val_volume_group_purpose ON val_volume_group_purpose;
CREATE TRIGGER trig_userlog_val_volume_group_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_volume_group_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_volume_group_purpose ON val_volume_group_purpose;
CREATE TRIGGER trigger_audit_val_volume_group_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_volume_group_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_volume_group_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_volume_group_relation ON val_volume_group_relation;
CREATE TRIGGER trig_userlog_val_volume_group_relation BEFORE INSERT OR UPDATE ON jazzhands.val_volume_group_relation FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_volume_group_relation ON val_volume_group_relation;
CREATE TRIGGER trigger_audit_val_volume_group_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_volume_group_relation FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_volume_group_relation();
DROP TRIGGER IF EXISTS trig_userlog_val_volume_group_type ON val_volume_group_type;
CREATE TRIGGER trig_userlog_val_volume_group_type BEFORE INSERT OR UPDATE ON jazzhands.val_volume_group_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_volume_group_type ON val_volume_group_type;
CREATE TRIGGER trigger_audit_val_volume_group_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_volume_group_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_volume_group_type();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_certificate_file_format ON val_x509_certificate_file_format;
CREATE TRIGGER trig_userlog_val_x509_certificate_file_format BEFORE INSERT OR UPDATE ON jazzhands.val_x509_certificate_file_format FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_certificate_file_format ON val_x509_certificate_file_format;
CREATE TRIGGER trigger_audit_val_x509_certificate_file_format AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_certificate_file_format FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_x509_certificate_file_format();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_certificate_type ON val_x509_certificate_type;
CREATE TRIGGER trig_userlog_val_x509_certificate_type BEFORE INSERT OR UPDATE ON jazzhands.val_x509_certificate_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_certificate_type ON val_x509_certificate_type;
CREATE TRIGGER trigger_audit_val_x509_certificate_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_certificate_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_x509_certificate_type();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_fingerprint_hash_algorithm ON val_x509_fingerprint_hash_algorithm;
CREATE TRIGGER trig_userlog_val_x509_fingerprint_hash_algorithm BEFORE INSERT OR UPDATE ON jazzhands.val_x509_fingerprint_hash_algorithm FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_fingerprint_hash_algorithm ON val_x509_fingerprint_hash_algorithm;
CREATE TRIGGER trigger_audit_val_x509_fingerprint_hash_algorithm AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_fingerprint_hash_algorithm FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_x509_fingerprint_hash_algorithm();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_key_usage ON val_x509_key_usage;
CREATE TRIGGER trig_userlog_val_x509_key_usage BEFORE INSERT OR UPDATE ON jazzhands.val_x509_key_usage FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_key_usage ON val_x509_key_usage;
CREATE TRIGGER trigger_audit_val_x509_key_usage AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_key_usage FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_x509_key_usage();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_key_usage_category ON val_x509_key_usage_category;
CREATE TRIGGER trig_userlog_val_x509_key_usage_category BEFORE INSERT OR UPDATE ON jazzhands.val_x509_key_usage_category FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_key_usage_category ON val_x509_key_usage_category;
CREATE TRIGGER trigger_audit_val_x509_key_usage_category AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_key_usage_category FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_x509_key_usage_category();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_revocation_reason ON val_x509_revocation_reason;
CREATE TRIGGER trig_userlog_val_x509_revocation_reason BEFORE INSERT OR UPDATE ON jazzhands.val_x509_revocation_reason FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_revocation_reason ON val_x509_revocation_reason;
CREATE TRIGGER trigger_audit_val_x509_revocation_reason AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_revocation_reason FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_x509_revocation_reason();
DROP TRIGGER IF EXISTS trig_userlog_volume_group ON volume_group;
CREATE TRIGGER trig_userlog_volume_group BEFORE INSERT OR UPDATE ON jazzhands.volume_group FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_volume_group ON volume_group;
CREATE TRIGGER trigger_audit_volume_group AFTER INSERT OR DELETE OR UPDATE ON jazzhands.volume_group FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_volume_group();
DROP TRIGGER IF EXISTS trig_userlog_volume_group_physicalish_volume ON volume_group_physicalish_volume;
CREATE TRIGGER trig_userlog_volume_group_physicalish_volume BEFORE INSERT OR UPDATE ON jazzhands.volume_group_physicalish_volume FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_volume_group_physicalish_volume ON volume_group_physicalish_volume;
CREATE TRIGGER trigger_audit_volume_group_physicalish_volume AFTER INSERT OR DELETE OR UPDATE ON jazzhands.volume_group_physicalish_volume FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_volume_group_physicalish_volume();
DROP TRIGGER IF EXISTS trig_userlog_volume_group_purpose ON volume_group_purpose;
CREATE TRIGGER trig_userlog_volume_group_purpose BEFORE INSERT OR UPDATE ON jazzhands.volume_group_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_volume_group_purpose ON volume_group_purpose;
CREATE TRIGGER trigger_audit_volume_group_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.volume_group_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_volume_group_purpose();
DROP TRIGGER IF EXISTS trig_userlog_x509_key_usage_attribute ON x509_key_usage_attribute;
CREATE TRIGGER trig_userlog_x509_key_usage_attribute BEFORE INSERT OR UPDATE ON jazzhands.x509_key_usage_attribute FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_x509_key_usage_attribute ON x509_key_usage_attribute;
CREATE TRIGGER trigger_audit_x509_key_usage_attribute AFTER INSERT OR DELETE OR UPDATE ON jazzhands.x509_key_usage_attribute FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_x509_key_usage_attribute();
DROP TRIGGER IF EXISTS trig_userlog_x509_key_usage_categorization ON x509_key_usage_categorization;
CREATE TRIGGER trig_userlog_x509_key_usage_categorization BEFORE INSERT OR UPDATE ON jazzhands.x509_key_usage_categorization FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_x509_key_usage_categorization ON x509_key_usage_categorization;
CREATE TRIGGER trigger_audit_x509_key_usage_categorization AFTER INSERT OR DELETE OR UPDATE ON jazzhands.x509_key_usage_categorization FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_x509_key_usage_categorization();
DROP TRIGGER IF EXISTS trig_userlog_x509_key_usage_default ON x509_key_usage_default;
CREATE TRIGGER trig_userlog_x509_key_usage_default BEFORE INSERT OR UPDATE ON jazzhands.x509_key_usage_default FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_x509_key_usage_default ON x509_key_usage_default;
CREATE TRIGGER trigger_audit_x509_key_usage_default AFTER INSERT OR DELETE OR UPDATE ON jazzhands.x509_key_usage_default FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_x509_key_usage_default();
DROP TRIGGER IF EXISTS trigger_x509_signed_ski_pvtkey_validate ON x509_signed_certificate;
DROP TRIGGER IF EXISTS trig_userlog_x509_signed_certificate ON x509_signed_certificate;
CREATE TRIGGER trig_userlog_x509_signed_certificate BEFORE INSERT OR UPDATE ON jazzhands.x509_signed_certificate FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_x509_signed_certificate ON x509_signed_certificate;
CREATE TRIGGER trigger_audit_x509_signed_certificate AFTER INSERT OR DELETE OR UPDATE ON jazzhands.x509_signed_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_x509_signed_certificate();
DROP TRIGGER IF EXISTS trigger_x509_signed_pkh_pvtkey_validate ON x509_signed_certificate;
CREATE CONSTRAINT TRIGGER trigger_x509_signed_pkh_pvtkey_validate AFTER INSERT OR UPDATE OF public_key_hash_id, private_key_id ON jazzhands.x509_signed_certificate NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.x509_signed_pkh_pvtkey_validate();
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
SELECT schema_support.synchronize_cache_tables();

--
-- END: Running final cache table sync
SAVEPOINT beforereset;
SELECT schema_support.reset_all_schema_table_sequences('jazzhands');
SELECT schema_support.reset_all_schema_table_sequences('jazzhands_audit');
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
