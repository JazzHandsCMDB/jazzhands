

-- Copyright (c) 2015, Todd Kover
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

/*
Invoked:

	--suffix=v62
	--scan-tables
	component_utils.delete_component_hier
	component_utils.set_slot_names
	val_network_range_type
	network_range
	snapshot_manip
	device_utils.purge_physical_path
	netblock_manip.allocate_netblock
	v_lv_hier
	val_token_type
	component_utils.insert_pci_component
	validate_component_property
	create_component_slots_by_trigger
	component_utils.insert_component_into_parent_slot
	component_utils.insert_disk_component
	component_utils.remove_component_hier
	component_utils.replace_component
	val_person_status
	account
	v_device_col_account_cart
	v_device_collection_account_ssh_key
	v_unix_passwd_mappings
	v_unix_group_mappings
	v_dev_col_user_prop_expanded
	v_corp_family_account
	lv_manip.*
	volume_group_physicalish_vol
	v_component_hier
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance();
-- Creating new sequences....

SELECT timeofday();


--------------------------------------------------------------------
-- DEALING WITH TABLE x509_certificate [4591155]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'x509_certificate', 'x509_certificate');

-- FOREIGN KEYS FROM
ALTER TABLE x509_key_usage_attribute DROP CONSTRAINT IF EXISTS fk_x509_certificate;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS fk_x509cert_enc_id_id;
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS fk_x509_cert_cert;
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS fk_x509_cert_revoc_reason;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'x509_certificate');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS ak_x509_cert_ski;
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS pk_x509_certificate;
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS ak_x509_cert_cert_ca_ser;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif3x509_certificate";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS check_yes_no_1933598984;
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS check_yes_no_31190954;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_x509_certificate ON jazzhands.x509_certificate;
DROP TRIGGER IF EXISTS trigger_audit_x509_certificate ON jazzhands.x509_certificate;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'x509_certificate');
---- BEGIN audit.x509_certificate TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'x509_certificate', 'x509_certificate');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'x509_certificate');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."x509_certificate_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'x509_certificate');
---- DONE audit.x509_certificate TEARDOWN


ALTER TABLE x509_certificate RENAME TO x509_certificate_v62;
ALTER TABLE audit.x509_certificate RENAME TO x509_certificate_v62;

CREATE TABLE x509_certificate
(
	x509_cert_id	integer NOT NULL,
	friendly_name	varchar(255) NOT NULL,
	is_active	character(1) NOT NULL,
	is_certificate_authority	character(1) NOT NULL,
	signing_cert_id	integer  NULL,
	x509_ca_cert_serial_number	numeric  NULL,
	public_key	text NULL,
	private_key	text  NULL,
	certificate_sign_req	text  NULL,
	subject	varchar(255) NOT NULL,
	subject_key_identifier	varchar(255) NOT NULL,
	valid_from	timestamp(6) without time zone NOT NULL,
	valid_to	timestamp(6) without time zone NOT NULL,
	x509_revocation_date	timestamp with time zone  NULL,
	x509_revocation_reason	varchar(50)  NULL,
	passphrase	varchar(255)  NULL,
	encryption_key_id	integer  NULL,
	ocsp_uri	varchar(255)  NULL,
	crl_uri	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'x509_certificate', false);
ALTER TABLE x509_certificate
	ALTER x509_cert_id
	SET DEFAULT nextval('x509_certificate_x509_cert_id_seq'::regclass);
ALTER TABLE x509_certificate
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE x509_certificate
	ALTER is_certificate_authority
	SET DEFAULT 'N'::bpchar;
INSERT INTO x509_certificate (
	x509_cert_id,
	friendly_name,
	is_active,
	is_certificate_authority,
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key,
	certificate_sign_req,
	subject,
	subject_key_identifier,
	valid_from,
	valid_to,
	x509_revocation_date,
	x509_revocation_reason,
	passphrase,
	encryption_key_id,
	ocsp_uri,		-- new column (ocsp_uri)
	crl_uri,		-- new column (crl_uri)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	x509_cert_id,
	friendly_name,
	is_active,
	is_certificate_authority,
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key,
	certificate_sign_req,
	subject,
	subject_key_identifier,
	valid_from,
	valid_to,
	x509_revocation_date,
	x509_revocation_reason,
	passphrase,
	encryption_key_id,
	NULL,		-- new column (ocsp_uri)
	NULL,		-- new column (crl_uri)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM x509_certificate_v62;

INSERT INTO audit.x509_certificate (
	x509_cert_id,
	friendly_name,
	is_active,
	is_certificate_authority,
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key,
	certificate_sign_req,
	subject,
	subject_key_identifier,
	valid_from,
	valid_to,
	x509_revocation_date,
	x509_revocation_reason,
	passphrase,
	encryption_key_id,
	ocsp_uri,		-- new column (ocsp_uri)
	crl_uri,		-- new column (crl_uri)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	x509_cert_id,
	friendly_name,
	is_active,
	is_certificate_authority,
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key,
	certificate_sign_req,
	subject,
	subject_key_identifier,
	valid_from,
	valid_to,
	x509_revocation_date,
	x509_revocation_reason,
	passphrase,
	encryption_key_id,
	NULL,		-- new column (ocsp_uri)
	NULL,		-- new column (crl_uri)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.x509_certificate_v62;

ALTER TABLE x509_certificate
	ALTER x509_cert_id
	SET DEFAULT nextval('x509_certificate_x509_cert_id_seq'::regclass);
ALTER TABLE x509_certificate
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE x509_certificate
	ALTER is_certificate_authority
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE x509_certificate ADD CONSTRAINT ak_x509_cert_cert_ca_ser UNIQUE (signing_cert_id, x509_ca_cert_serial_number);
ALTER TABLE x509_certificate ADD CONSTRAINT pk_x509_certificate PRIMARY KEY (x509_cert_id);
ALTER TABLE x509_certificate ADD CONSTRAINT ak_x509_cert_ski UNIQUE (subject_key_identifier);

-- Table/Column Comments
COMMENT ON TABLE x509_certificate IS 'X509 specification Certificate.';
COMMENT ON COLUMN x509_certificate.x509_cert_id IS 'Uniquely identifies Certificate';
COMMENT ON COLUMN x509_certificate.friendly_name IS 'human readable name for certificate.  often just the CN.';
COMMENT ON COLUMN x509_certificate.is_active IS 'indicates certificate is in active use.  This is used by tools to decide how to show it; does not indicate revocation';
COMMENT ON COLUMN x509_certificate.signing_cert_id IS 'x509_cert_id for the certificate that has signed this one.';
COMMENT ON COLUMN x509_certificate.x509_ca_cert_serial_number IS 'Serial INTEGER assigned to the certificate within Certificate Authority. It uniquely identifies certificate within the realm of the CA.';
COMMENT ON COLUMN x509_certificate.public_key IS 'Textual representation of Certificate Public Key. Public Key is a component of X509 standard and is used for encryption.';
COMMENT ON COLUMN x509_certificate.private_key IS 'Textual representation of Certificate Private Key. Private Key is a component of X509 standard and is used for encryption.';
COMMENT ON COLUMN x509_certificate.subject IS 'Textual representation of a certificate subject. Certificate subject is a part of X509 certificate specifications.  This is the full subject from the certificate.  Friendly Name provides a human readable one.';
COMMENT ON COLUMN x509_certificate.subject_key_identifier IS 'colon seperate byte hex string with X509v3 SKIextension of this certificate';
COMMENT ON COLUMN x509_certificate.valid_from IS 'Timestamp indicating when the certificate becomes valid and can be used.';
COMMENT ON COLUMN x509_certificate.valid_to IS 'Timestamp indicating when the certificate becomes invalid and can''t be used.';
COMMENT ON COLUMN x509_certificate.x509_revocation_date IS 'if certificate was revoked, when it was revokeed.  reason must also be set.   NULL means not revoked';
COMMENT ON COLUMN x509_certificate.x509_revocation_reason IS 'if certificate was revoked, why iit was revokeed.  date must also be set.   NULL means not revoked';
COMMENT ON COLUMN x509_certificate.passphrase IS 'passphrase to decrypt key.  If encrypted, encryption_key_id indicates how to decrypt.';
COMMENT ON COLUMN x509_certificate.encryption_key_id IS 'if set, encryption key information for decrypting passphrase.';
COMMENT ON COLUMN x509_certificate.ocsp_uri IS 'The URI (without URI: prefix) of the OCSP server for certs signed by this CA.  This is only valid for CAs.  This URI will be included in said certificates.';
COMMENT ON COLUMN x509_certificate.crl_uri IS 'The URI (without URI: prefix) of the CRL for certs signed by this CA.  This is only valid for CAs.  This URI will be included in said certificates.';
-- INDEXES
CREATE INDEX xif3x509_certificate ON x509_certificate USING btree (x509_revocation_reason);

-- CHECK CONSTRAINTS
ALTER TABLE x509_certificate ADD CONSTRAINT check_yes_no_1933598984
	CHECK (is_active = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE x509_certificate ADD CONSTRAINT check_yes_no_31190954
	CHECK (is_certificate_authority = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK x509_certificate and x509_key_usage_attribute
ALTER TABLE x509_key_usage_attribute
	ADD CONSTRAINT fk_x509_certificate
	FOREIGN KEY (x509_cert_id) REFERENCES x509_certificate(x509_cert_id);

-- FOREIGN KEYS TO
-- consider FK x509_certificate and x509_certificate
ALTER TABLE x509_certificate
	ADD CONSTRAINT fk_x509_cert_cert
	FOREIGN KEY (signing_cert_id) REFERENCES x509_certificate(x509_cert_id);
-- consider FK x509_certificate and encryption_key
ALTER TABLE x509_certificate
	ADD CONSTRAINT fk_x509cert_enc_id_id
	FOREIGN KEY (encryption_key_id) REFERENCES encryption_key(encryption_key_id);
-- consider FK x509_certificate and val_x509_revocation_reason
ALTER TABLE x509_certificate
	ADD CONSTRAINT fk_x509_cert_revoc_reason
	FOREIGN KEY (x509_revocation_reason) REFERENCES val_x509_revocation_reason(x509_revocation_reason);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'x509_certificate');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'x509_certificate');
ALTER SEQUENCE x509_certificate_x509_cert_id_seq
	 OWNED BY x509_certificate.x509_cert_id;
DROP TABLE IF EXISTS x509_certificate_v62;
DROP TABLE IF EXISTS audit.x509_certificate_v62;
-- DONE DEALING WITH TABLE x509_certificate [4626552]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH proc component_utils.delete_component_hier -> delete_component_hier 


DROP FUNCTION IF EXISTS component_utils.delete_component_hier(component_id integer);

-- DONE WITH proc component_utils.delete_component_hier -> delete_component_hier 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc component_utils.set_slot_names -> set_slot_names 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('component_utils', 'set_slot_names', 'set_slot_names');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
-- consider old oid 4596669
DROP FUNCTION IF EXISTS component_utils.set_slot_names(slot_id_list integer[]);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 4632090
CREATE OR REPLACE FUNCTION component_utils.set_slot_names(slot_id_list integer[] DEFAULT NULL::integer[])
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	slot_rec	RECORD;
	sn			text;
BEGIN
	-- Get a list of all slots that have replacement values

	FOR slot_rec IN
		SELECT 
			s.slot_id,
			st.slot_name_template,
			st.slot_index as slot_index,
			pst.slot_index as parent_slot_index
		FROM
			slot s JOIN
			component_type_slot_tmplt st ON (s.component_type_slot_tmplt_id =
				st.component_type_slot_tmplt_id) JOIN
			component c ON (s.component_id = c.component_id) LEFT JOIN
			slot ps ON (c.parent_slot_id = ps.slot_id) LEFT JOIN
			component_type_slot_tmplt pst ON (ps.component_type_slot_tmplt_id =
				pst.component_type_slot_tmplt_id)
		WHERE
			s.slot_id = ANY(slot_id_list) AND
			st.slot_name_template LIKE '%\%{%'
	LOOP
		sn := slot_rec.slot_name_template;
		IF (slot_rec.slot_index IS NOT NULL) THEN
			sn := regexp_replace(sn,
				'%\{slot_index\}', slot_rec.slot_index::text,
				'g');
		END IF;
		IF (slot_rec.parent_slot_index IS NOT NULL) THEN
			sn := regexp_replace(sn,
				'%\{parent_slot_index\}', slot_rec.parent_slot_index::text,
				'g');
		END IF;
		IF (slot_rec.parent_slot_index IS NOT NULL AND
			slot_rec.slot_index IS NOT NULL) THEN
			sn := regexp_replace(sn,
				'%\{relative_slot_index\}', 
				(slot_rec.parent_slot_index + slot_rec.slot_index)::text,
				'g');
		END IF;
		RAISE DEBUG 'Setting name of slot % to %',
			slot_rec.slot_id,
			sn;
		UPDATE slot SET slot_name = sn WHERE slot_id = slot_rec.slot_id;
	END LOOP;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc component_utils.set_slot_names -> set_slot_names 
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_network_range_type
CREATE TABLE val_network_range_type
(
	network_range_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_network_range_type', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_network_range_type ADD CONSTRAINT pk_val_network_range_type PRIMARY KEY (network_range_type);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_network_range_type and network_range
-- does not exist yet
--ALTER TABLE network_range
--	ADD CONSTRAINT fk_netrng_netrng_typ
--	FOREIGN KEY (network_range_type) REFERENCES val_network_range_type(network_range_type);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_network_range_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_network_range_type');

-- Insert a reasonable default

INSERT INTO val_network_range_type ( network_range_type, description)
values ('unknown', 'exists before types');

-- DONE DEALING WITH TABLE val_network_range_type [4626047]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE network_range [4589564]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'network_range', 'network_range');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.network_range DROP CONSTRAINT IF EXISTS fk_net_range_start_netblock;
ALTER TABLE jazzhands.network_range DROP CONSTRAINT IF EXISTS fk_net_range_stop_netblock;
ALTER TABLE jazzhands.network_range DROP CONSTRAINT IF EXISTS fk_net_range_dns_domain_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'network_range');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.network_range DROP CONSTRAINT IF EXISTS pk_network_range;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_netrng_dnsdomainid";
DROP INDEX IF EXISTS "jazzhands"."idx_netrng_startnetblk";
DROP INDEX IF EXISTS "jazzhands"."idx_netrng_stopnetblk";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_audit_network_range ON jazzhands.network_range;
DROP TRIGGER IF EXISTS trig_userlog_network_range ON jazzhands.network_range;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'network_range');
---- BEGIN audit.network_range TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'network_range', 'network_range');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'network_range');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."network_range_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'network_range');
---- DONE audit.network_range TEARDOWN


ALTER TABLE network_range RENAME TO network_range_v62;
ALTER TABLE audit.network_range RENAME TO network_range_v62;

CREATE TABLE network_range
(
	network_range_id	integer NOT NULL,
	network_range_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	parent_netblock_id	integer NOT NULL,
	start_netblock_id	integer NOT NULL,
	stop_netblock_id	integer NOT NULL,
	dns_prefix	varchar(255)  NULL,
	dns_domain_id	integer NOT NULL,
	lease_time	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'network_range', false);
ALTER TABLE network_range
	ALTER network_range_id
	SET DEFAULT nextval('network_range_network_range_id_seq'::regclass);
INSERT INTO network_range (
	network_range_id,
	network_range_type,		-- new column (network_range_type)
	description,
	parent_netblock_id,		-- new column (parent_netblock_id)
	start_netblock_id,
	stop_netblock_id,
	dns_prefix,
	dns_domain_id,
	lease_time,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	o.network_range_id,
	'unknown',	-- new column (network_range_type)
	o.description,
	nb.parent_netblock_id,		-- new column (parent_netblock_id)
	o.start_netblock_id,
	o.stop_netblock_id,
	o.dns_prefix,
	o.dns_domain_id,
	o.lease_time,
	o.data_ins_user,
	o.data_ins_date,
	o.data_upd_user,
	o.data_upd_date
FROM network_range_v62 o
	join netblock nb on nb.netblock_id = o.start_netblock_id;

INSERT INTO audit.network_range (
	network_range_id,
	network_range_type,		-- new column (network_range_type)
	description,
	parent_netblock_id,		-- new column (parent_netblock_id)
	start_netblock_id,
	stop_netblock_id,
	dns_prefix,
	dns_domain_id,
	lease_time,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	o.network_range_id,
	'unknown',	-- new column (network_range_type)
	o.description,
	nb.parent_netblock_id,		-- new column (parent_netblock_id)
	o.start_netblock_id,
	o.stop_netblock_id,
	o.dns_prefix,
	o.dns_domain_id,
	o.lease_time,
	o.data_ins_user,
	o.data_ins_date,
	o.data_upd_user,
	o.data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.network_range_v62 o
	join netblock nb on nb.netblock_id = o.start_netblock_id;

ALTER TABLE network_range
	ALTER network_range_id
	SET DEFAULT nextval('network_range_network_range_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE network_range ADD CONSTRAINT pk_network_range PRIMARY KEY (network_range_id);

-- Table/Column Comments
COMMENT ON COLUMN network_range.parent_netblock_id IS 'The netblock where the range appears.  This can be of a different type than start/stop netblocks, but start/stop need to be within the parent.';
-- INDEXES
CREATE INDEX xif_netrng_prngnblkid ON network_range USING btree (parent_netblock_id);
CREATE INDEX xif_netrng_dnsdomainid ON network_range USING btree (dns_domain_id);
CREATE INDEX xif_netrng_netrng_typ ON network_range USING btree (network_range_type);
CREATE INDEX xif_netrng_stopnetblk ON network_range USING btree (stop_netblock_id);
CREATE INDEX xif_netrng_startnetblk ON network_range USING btree (start_netblock_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK network_range and netblock
ALTER TABLE network_range
	ADD CONSTRAINT fk_net_range_start_netblock
	FOREIGN KEY (start_netblock_id) REFERENCES netblock(netblock_id);
-- consider FK network_range and val_network_range_type
ALTER TABLE network_range
	ADD CONSTRAINT fk_netrng_netrng_typ
	FOREIGN KEY (network_range_type) REFERENCES val_network_range_type(network_range_type);
-- consider FK network_range and netblock
ALTER TABLE network_range
	ADD CONSTRAINT fk_net_range_stop_netblock
	FOREIGN KEY (stop_netblock_id) REFERENCES netblock(netblock_id);
-- consider FK network_range and netblock
ALTER TABLE network_range
	ADD CONSTRAINT fk_netrng_prngnblkid
	FOREIGN KEY (parent_netblock_id) REFERENCES netblock(netblock_id);
-- consider FK network_range and dns_domain
ALTER TABLE network_range
	ADD CONSTRAINT fk_net_range_dns_domain_id
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'network_range');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'network_range');
ALTER SEQUENCE network_range_network_range_id_seq
	 OWNED BY network_range.network_range_id;
DROP TABLE IF EXISTS network_range_v62;
DROP TABLE IF EXISTS audit.network_range_v62;
-- DONE DEALING WITH TABLE network_range [4624951]
--------------------------------------------------------------------

-- triggers

-- Copyright (c) 2015, Kurt Adam
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
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'snapshot_manip';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS snapshot_manip CASCADE;
		-- CREATE SCHEMA snapshot_manip AUTHORIZATION jazzhands;
		CREATE SCHEMA snapshot_manip;
		COMMENT ON SCHEMA snapshot_manip IS 'part of jazzhands';
	END IF;
END;
$$;

CREATE OR REPLACE FUNCTION snapshot_manip.add_snapshot(
	os_name       operating_system.operating_system_name%type,
	os_version    operating_system.version%type,
	snapshot_name operating_system_snapshot.operating_system_snapshot_name%type,
	snapshot_type operating_system_snapshot.operating_system_snapshot_type%type
) RETURNS integer AS $$

DECLARE
	major_version text;
	companyid     company.company_id%type;
	osid          operating_system.operating_system_id%type;
	snapid        operating_system_snapshot.operating_system_snapshot_id%type;
	dcid          device_collection.device_collection_id%type;

BEGIN
	SELECT company.company_id INTO companyid FROM company
		INNER JOIN company_type USING (company_id)
		WHERE company_short_name = os_name
		AND company_type = 'os provider';

	IF NOT FOUND THEN
		RAISE 'Operating system vendor not found';
	END IF;

	SELECT operating_system_id INTO osid FROM operating_system
		WHERE operating_system_name = os_name
		AND version = os_version;

	IF NOT FOUND THEN
		major_version := substring(os_version, '^[^.]+');

		INSERT INTO operating_system (
			operating_system_name,
			company_id,
			major_version,
			version,
			operating_system_family
		) VALUES (
			os_name,
			companyid,
			major_version,
			os_version,
			'Linux'
		) RETURNING * INTO osid;

		INSERT INTO property (
			property_type,
			property_name,
			operating_system_id,
			property_value
		) VALUES (
			'OperatingSystem',
			'AllowOSDeploy',
			osid,
			'N'
		);
	END IF;

	INSERT INTO operating_system_snapshot (
		operating_system_snapshot_name,
		operating_system_snapshot_type,
		operating_system_id
	) VALUES (
		snapshot_name,
		snapshot_type,
		osid
	) RETURNING * INTO snapid;

	INSERT INTO device_collection (
		device_collection_name,
		device_collection_type,
		description
	) VALUES (
		CONCAT(os_name, '-', os_version, '-', snapshot_name),
		'os-snapshot',
		NULL
	) RETURNING * INTO dcid;

	INSERT INTO property (
		property_type,
		property_name,
		device_collection_id,
		operating_system_snapshot_id,
		property_value
	) VALUES (
		'OperatingSystem',
		'DeviceCollection',
		dcid,
		snapid,
		NULL
	), (
		'OperatingSystem',
		'AllowSnapDeploy',
		NULL,
		snapid,
		'N'
	);

	RETURN snapid;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION snapshot_manip.set_default_snapshot(
	os_name       operating_system.operating_system_name%type,
	os_version    operating_system.version%type,
	snapshot_name operating_system_snapshot.operating_system_snapshot_name%type
) RETURNS void AS $$

DECLARE
	osrec           RECORD;
	previous_snapid operating_system_snapshot.operating_system_snapshot_id%type;

BEGIN
	SELECT os.operating_system_id, oss.operating_system_snapshot_id INTO osrec FROM operating_system os
		INNER JOIN operating_system_snapshot oss USING(operating_system_id)
		WHERE operating_system_name = os_name
		AND version = os_version
		AND operating_system_snapshot_name = snapshot_name;

	IF NOT FOUND THEN
		RAISE 'Operating system snapshot not found';
	END IF;

	SELECT oss.operating_system_snapshot_id INTO previous_snapid FROM operating_system_snapshot oss
		INNER JOIN operating_system USING (operating_system_id)
		INNER JOIN property USING (operating_system_snapshot_id)
		WHERE version = os_version
		AND operating_system_name = os_name
		AND property_type = 'OperatingSystem'
		AND property_name = 'DefaultSnapshot';

	IF previous_snapid IS NOT NULL THEN
		IF osrec.operating_system_snapshot_id = previous_snapid THEN
			RETURN;
		END IF;

		DELETE FROM property
			WHERE operating_system_snapshot_id = previous_snapid
			AND property_type = 'OperatingSystem'
			AND property_name = 'DefaultSnapshot';
	END IF;

	INSERT INTO property (
		property_type,
		property_name,
		operating_system_id,
		operating_system_snapshot_id
	) VALUES (
		'OperatingSystem',
		'DefaultSnapshot',
		osrec.operating_system_id,
		osrec.operating_system_snapshot_id
	);
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION snapshot_manip.set_default_os_version(
	os_name       operating_system.operating_system_name%type,
	os_version    operating_system.version%type
) RETURNS void AS $$

DECLARE
	osid          operating_system.operating_system_id%type;
	previous_osid operating_system.operating_system_id%type;

BEGIN
	SELECT os.operating_system_id INTO osid FROM operating_system os
		WHERE operating_system_name = os_name
		AND version = os_version;

	IF NOT FOUND THEN
		RAISE 'Operating system not found';
	END IF;

	SELECT os.operating_system_id INTO previous_osid FROM operating_system os
		INNER JOIN property USING (operating_system_id)
		WHERE operating_system_name = os_name
		AND property_type = 'OperatingSystem'
		AND property_name = 'DefaultVersion';

	IF previous_osid IS NOT NULL THEN
		IF osid = previous_osid THEN
			RETURN;
		END IF;

		DELETE FROM property
			WHERE operating_system_id = previous_osid
			AND property_type = 'OperatingSystem'
			AND property_name = 'DefaultVersion';
	END IF;

	INSERT INTO property (
		property_type,
		property_name,
		operating_system_id,
		property_value
	) VALUES (
		'OperatingSystem',
		'DefaultVersion',
		osid,
		os_name
	);
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION snapshot_manip.delete_snapshot(
	os_name       operating_system.operating_system_name%type,
	os_version    operating_system.version%type,
	snapshot_name operating_system_snapshot.operating_system_snapshot_name%type
) RETURNS void AS $$

DECLARE
	snapid  operating_system_snapshot.operating_system_snapshot_id%type;
	dcid    device_collection.device_collection_id%type;
	dccount integer;

BEGIN
	SELECT operating_system_snapshot_id INTO snapid FROM operating_system
		INNER JOIN operating_system_snapshot USING (operating_system_id)
		WHERE operating_system_name = os_name
		AND operating_system_snapshot_name = snapshot_name
		AND version = os_version;

	IF NOT FOUND THEN
		RAISE 'Operating system snapshot not found';
	END IF;

	SELECT device_collection_id INTO dcid FROM property
		INNER JOIN operating_system_snapshot USING (operating_system_snapshot_id)
		WHERE property_type = 'OperatingSystem'
		AND property_name = 'DeviceCollection'
		AND property.operating_system_snapshot_id = snapid;

	SELECT COUNT(*) INTO dccount FROM device_collection_device where device_collection_id = dcid;

	IF dccount != 0 THEN
		RAISE 'Operating system snapshot still in use by some devices';
	END IF;

	DELETE FROM property WHERE operating_system_snapshot_id = snapid;
	DELETE FROM device_collection WHERE device_collection_name = CONCAT(os_name, '-', os_version, '-', snapshot_name);
	DELETE FROM operating_system_snapshot WHERE operating_system_snapshot_id = snapid;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION snapshot_manip.set_device_snapshot(
	input_device  device.device_id%type,
	os_name       operating_system.operating_system_name%type,
	os_version    operating_system.version%type,
	snapshot_name operating_system_snapshot.operating_system_snapshot_name%type
) RETURNS void AS $$

DECLARE
	snapid        operating_system_snapshot.operating_system_snapshot_id%type;
	previous_dcid device_collection.device_collection_id%type;
	new_dcid      device_collection.device_collection_id%type;

BEGIN
	IF snapshot_name = 'default' THEN
		SELECT oss.operating_system_snapshot_id INTO snapid FROM operating_system_snapshot oss
			INNER JOIN operating_system os USING (operating_system_id)
			INNER JOIN property p USING (operating_system_snapshot_id)
			WHERE os.version = os_version
			AND os.operating_system_name = os_name
			AND p.property_type = 'OperatingSystem'
			AND p.property_name = 'DefaultSnapshot';
	ELSE
		SELECT oss.operating_system_snapshot_id INTO snapid FROM operating_system_snapshot oss
			INNER JOIN operating_system os USING(operating_system_id)
			WHERE os.operating_system_name = os_name
			AND os.version = os_version
			AND oss.operating_system_snapshot_name = snapshot_name;
	END IF;

	IF NOT FOUND THEN
		RAISE 'Operating system snapshot not found';
	END IF;

	SELECT property.device_collection_id INTO new_dcid FROM property
		WHERE operating_system_snapshot_id = snapid
		AND property_type = 'OperatingSystem'
		AND property_name = 'DeviceCollection';

	SELECT device_collection_id INTO previous_dcid FROM device_collection_device
		INNER JOIN device_collection USING(device_collection_id)
		WHERE device_id = input_device
		AND device_collection_type = 'os-snapshot';

	IF FOUND THEN
		IF new_dcid = previous_dcid THEN
			RETURN;
		END IF;

		DELETE FROM device_collection_device
			WHERE device_id = input_device
			AND device_collection_id = previous_dcid;
	END IF;

	INSERT INTO device_collection_device (
		device_id,
		device_collection_id
	) VALUES (
		input_device,
		new_dcid
	);
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

--------------------------------------------------------------------
-- DEALING WITH proc device_utils.purge_physical_path -> purge_physical_path 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('device_utils', 'purge_physical_path', 'purge_physical_path');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
-- consider old oid 4596637
DROP FUNCTION IF EXISTS device_utils.purge_physical_path(_in_l1c integer);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 4632058
CREATE OR REPLACE FUNCTION device_utils.purge_physical_path(_in_l1c integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_r	RECORD;
BEGIN
	FOR _r IN 
	      SELECT  pc.physical_connection_id,
			pc.cable_type,
			p1.physical_port_id as pc_p1_physical_port_id,
			p1.port_name as pc_p1_physical_port_name,
			d1.device_id as pc_p1_device_id,
			d1.device_name as pc_p1_device_name,
			p2.physical_port_id as pc_p2_physical_port_id,
			p2.port_name as pc_p2_physical_port_name,
			d2.device_id as pc_p2_device_id,
			d2.device_name as pc_p2_device_name
		  FROM  v_physical_connection vpc
			INNER JOIN physical_connection pc
				USING (physical_connection_id)
			INNER JOIN physical_port p1
				ON p1.physical_port_id = pc.physical_port1_id
			INNER JOIN device d1
				ON d1.device_id = p1.device_id
			INNER JOIN physical_port p2
				ON p2.physical_port_id = pc.physical_port2_id
			INNER JOIN device d2
				ON d2.device_id = p2.device_id
		WHERE   vpc.inter_component_connection_id = _in_l1c
		ORDER BY level
	LOOP
		DELETE from physical_connecion where physical_connection_id =
			_r.physical_connection_id;
	END LOOP;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc device_utils.purge_physical_path -> purge_physical_path 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc netblock_manip.allocate_netblock -> allocate_netblock 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('netblock_manip', 'allocate_netblock', 'allocate_netblock');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
-- consider old oid 4596660
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock(parent_netblock_id integer, netmask_bits integer, address_type text, can_subnet boolean, allocation_method text, rnd_masklen_threshold integer, rnd_max_count integer, ip_address inet, description character varying, netblock_status character varying);
-- consider old oid 4596661
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock(parent_netblock_list integer[], netmask_bits integer, address_type text, can_subnet boolean, allocation_method text, rnd_masklen_threshold integer, rnd_max_count integer, ip_address inet, description character varying, netblock_status character varying);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 4632081
CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(parent_netblock_id integer, netmask_bits integer DEFAULT NULL::integer, address_type text DEFAULT 'netblock'::text, can_subnet boolean DEFAULT true, allocation_method text DEFAULT NULL::text, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024, ip_address inet DEFAULT NULL::inet, description character varying DEFAULT NULL::character varying, netblock_status character varying DEFAULT 'Allocated'::character varying)
 RETURNS netblock
 LANGUAGE plpgsql
AS $function$
DECLARE
	netblock_rec	RECORD;
BEGIN
	SELECT * into netblock_rec FROM netblock_manip.allocate_netblock(
		parent_netblock_list := ARRAY[parent_netblock_id],
		netmask_bits := netmask_bits,
		address_type := address_type,
		can_subnet := can_subnet,
		description := description,
		allocation_method := allocation_method,
		ip_address := ip_address,
		rnd_masklen_threshold := rnd_masklen_threshold,
		rnd_max_count := rnd_max_count,
		netblock_status := netblock_status
	);
	RETURN netblock_rec;
END;
$function$
;
-- consider NEW oid 4632082
CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(parent_netblock_list integer[], netmask_bits integer DEFAULT NULL::integer, address_type text DEFAULT 'netblock'::text, can_subnet boolean DEFAULT true, allocation_method text DEFAULT NULL::text, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024, ip_address inet DEFAULT NULL::inet, description character varying DEFAULT NULL::character varying, netblock_status character varying DEFAULT 'Allocated'::character varying)
 RETURNS netblock
 LANGUAGE plpgsql
AS $function$
DECLARE
	parent_rec		RECORD;
	netblock_rec	RECORD;
	inet_rec		RECORD;
	loopback_bits	integer;
	inet_family		integer;
	ip_addr			ALIAS FOR ip_address;
BEGIN
	IF parent_netblock_list IS NULL THEN
		RAISE 'parent_netblock_list must be specified'
		USING ERRCODE = 'null_value_not_allowed';
	END IF;

	IF address_type NOT IN ('netblock', 'single', 'loopback') THEN
		RAISE 'address_type must be one of netblock, single, or loopback'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF netmask_bits IS NULL AND address_type = 'netblock' THEN
		RAISE EXCEPTION
			'You must specify a netmask when address_type is netblock'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF ip_address IS NOT NULL THEN
		SELECT 
			array_agg(netblock_id)
		INTO
			parent_netblock_list
		FROM
			netblock n
		WHERE
			ip_addr <<= n.ip_address AND
			netblock_id = ANY(parent_netblock_list);

		IF parent_netblock_list IS NULL THEN
			RETURN NULL;
		END IF;
	END IF;

	-- Lock the parent row, which should keep parallel processes from
	-- trying to obtain the same address

	FOR parent_rec IN SELECT * FROM jazzhands.netblock WHERE netblock_id = 
			ANY(allocate_netblock.parent_netblock_list) ORDER BY netblock_id
			FOR UPDATE LOOP

		IF parent_rec.is_single_address = 'Y' THEN
			RAISE EXCEPTION 'parent_netblock_id refers to a single_address netblock'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF inet_family IS NULL THEN
			inet_family := family(parent_rec.ip_address);
		ELSIF inet_family != family(parent_rec.ip_address) 
				AND ip_address IS NULL THEN
			RAISE EXCEPTION 'Allocation may not mix IPv4 and IPv6 addresses'
			USING ERRCODE = 'JH10F';
		END IF;

		IF address_type = 'loopback' THEN
			loopback_bits := 
				CASE WHEN 
					family(parent_rec.ip_address) = 4 THEN 32 ELSE 128 END;

			IF parent_rec.can_subnet = 'N' THEN
				RAISE EXCEPTION 'parent subnet must have can_subnet set to Y'
					USING ERRCODE = 'JH10B';
			END IF;
		ELSIF address_type = 'single' THEN
			IF parent_rec.can_subnet = 'Y' THEN
				RAISE EXCEPTION
					'parent subnet for single address must have can_subnet set to N'
					USING ERRCODE = 'JH10B';
			END IF;
		ELSIF address_type = 'netblock' THEN
			IF parent_rec.can_subnet = 'N' THEN
				RAISE EXCEPTION 'parent subnet must have can_subnet set to Y'
					USING ERRCODE = 'JH10B';
			END IF;
		END IF;
	END LOOP;

 	IF NOT FOUND THEN
 		RETURN NULL;
 	END IF;

	IF address_type = 'loopback' THEN
		-- If we're allocating a loopback address, then we need to create
		-- a new parent to hold the single loopback address

		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			netmask_bits := loopback_bits,
			single_address := false,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			max_addresses := 1
			);

		IF NOT FOUND THEN
			RETURN NULL;
		END IF;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			inet_rec.netblock_type,
			'N',
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO parent_rec;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			parent_rec.netblock_type,
			'Y',
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		PERFORM dns_utils.add_domains_from_netblock(
			netblock_id := netblock_rec.netblock_id);

		RETURN netblock_rec;
	END IF;

	IF address_type = 'single' THEN
		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			single_address := true,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			rnd_masklen_threshold := rnd_masklen_threshold,
			rnd_max_count := rnd_max_count,
			max_addresses := 1
			);

		IF NOT FOUND THEN
			RETURN NULL;
		END IF;

		RAISE DEBUG 'ip_address is %', inet_rec.ip_address;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			inet_rec.netblock_type,
			'Y',
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		RETURN netblock_rec;
	END IF;
	IF address_type = 'netblock' THEN
		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			netmask_bits := netmask_bits,
			single_address := false,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			max_addresses := 1);

		IF NOT FOUND THEN
			RETURN NULL;
		END IF;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			inet_rec.netblock_type,
			'N',
			CASE WHEN can_subnet THEN 'Y' ELSE 'N' END,
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		PERFORM dns_utils.add_domains_from_netblock(
			netblock_id := netblock_rec.netblock_id);

		RETURN netblock_rec;
	END IF;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc netblock_manip.allocate_netblock -> allocate_netblock 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_lv_hier
CREATE OR REPLACE VIEW v_lv_hier AS
 WITH RECURSIVE lv_hier(physicalish_volume_id, pv_logical_volume_id, volume_group_id, logical_volume_id, pv_path, vg_path, lv_path) AS (
         SELECT pv.physicalish_volume_id,
            pv.logical_volume_id,
            vg.volume_group_id,
            lv.logical_volume_id,
            ARRAY[pv.physicalish_volume_id] AS "array",
            ARRAY[vg.volume_group_id] AS "array",
            ARRAY[lv.logical_volume_id] AS "array"
           FROM physicalish_volume pv
             LEFT JOIN volume_group_physicalish_vol USING (physicalish_volume_id)
             FULL JOIN volume_group vg USING (volume_group_id)
             LEFT JOIN logical_volume lv USING (volume_group_id)
          WHERE lv.logical_volume_id IS NULL OR NOT (lv.logical_volume_id IN ( SELECT physicalish_volume.logical_volume_id
                   FROM physicalish_volume
                  WHERE physicalish_volume.logical_volume_id IS NOT NULL))
        UNION
         SELECT pv.physicalish_volume_id,
            pv.logical_volume_id,
            vg.volume_group_id,
            lv.logical_volume_id,
            array_prepend(pv.physicalish_volume_id, lh.pv_path) AS array_prepend,
            array_prepend(vg.volume_group_id, lh.vg_path) AS array_prepend,
            array_prepend(lv.logical_volume_id, lh.lv_path) AS array_prepend
           FROM physicalish_volume pv
             LEFT JOIN volume_group_physicalish_vol USING (physicalish_volume_id)
             FULL JOIN volume_group vg USING (volume_group_id)
             LEFT JOIN logical_volume lv USING (volume_group_id)
             JOIN lv_hier lh(physicalish_volume_id_1, pv_logical_volume_id, volume_group_id_1, logical_volume_id, pv_path, vg_path, lv_path) ON lv.logical_volume_id = lh.pv_logical_volume_id
        )
 SELECT DISTINCT lv_hier.physicalish_volume_id,
    lv_hier.volume_group_id,
    lv_hier.logical_volume_id,
    unnest(lv_hier.pv_path) AS child_pv_id,
    unnest(lv_hier.vg_path) AS child_vg_id,
    unnest(lv_hier.lv_path) AS child_lv_id,
    lv_hier.pv_path,
    lv_hier.vg_path,
    lv_hier.lv_path
   FROM lv_hier;

delete from __recreate where type = 'view' and object = 'v_lv_hier';
-- DONE DEALING WITH TABLE v_lv_hier [4763835]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_token_type [5075193]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_token_type', 'val_token_type');

-- FOREIGN KEYS FROM
ALTER TABLE token DROP CONSTRAINT IF EXISTS fk_token_ref_v_token_type;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_token_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_token_type DROP CONSTRAINT IF EXISTS pk_val_token_type;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_token_type ON jazzhands.val_token_type;
DROP TRIGGER IF EXISTS trigger_audit_val_token_type ON jazzhands.val_token_type;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_token_type');
---- BEGIN audit.val_token_type TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_token_type', 'val_token_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_token_type');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_token_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_token_type');
---- DONE audit.val_token_type TEARDOWN


ALTER TABLE val_token_type RENAME TO val_token_type_v63;
ALTER TABLE audit.val_token_type RENAME TO val_token_type_v63;

CREATE TABLE val_token_type
(
	token_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	token_digit_count	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_token_type', false);
INSERT INTO val_token_type (
	token_type,
	description,
	token_digit_count,		-- new column (token_digit_count)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	token_type,
	description,
	NULL,		-- new column (token_digit_count)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_token_type_v63;

INSERT INTO audit.val_token_type (
	token_type,
	description,
	token_digit_count,		-- new column (token_digit_count)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	token_type,
	description,
	NULL,		-- new column (token_digit_count)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_token_type_v63;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_token_type ADD CONSTRAINT pk_val_token_type PRIMARY KEY (token_type);

-- Table/Column Comments
COMMENT ON COLUMN val_token_type.token_digit_count IS 'number of digits that the token displays';
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_token_type and token
ALTER TABLE token
	ADD CONSTRAINT fk_token_ref_v_token_type
	FOREIGN KEY (token_type) REFERENCES val_token_type(token_type);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_token_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_token_type');
GRANT SELECT ON val_token_type TO ro_role;
GRANT ALL ON val_token_type TO jazzhands;
GRANT INSERT,UPDATE,DELETE ON val_token_type TO iud_role;
DROP TABLE IF EXISTS val_token_type_v63;
DROP TABLE IF EXISTS audit.val_token_type_v63;
-- DONE DEALING WITH TABLE val_token_type [5035411]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH proc component_utils.insert_pci_component -> insert_pci_component 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('component_utils', 'insert_pci_component', 'insert_pci_component');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
-- consider old oid 6194990
DROP FUNCTION IF EXISTS component_utils.insert_pci_component(pci_vendor_id integer, pci_device_id integer, pci_sub_vendor_id integer, pci_subsystem_id integer, pci_vendor_name text, pci_device_name text, pci_sub_vendor_name text, pci_sub_device_name text, component_function_list text[], slot_type text);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 6189249
CREATE OR REPLACE FUNCTION component_utils.insert_pci_component(pci_vendor_id integer, pci_device_id integer, pci_sub_vendor_id integer DEFAULT NULL::integer, pci_subsystem_id integer DEFAULT NULL::integer, pci_vendor_name text DEFAULT NULL::text, pci_device_name text DEFAULT NULL::text, pci_sub_vendor_name text DEFAULT NULL::text, pci_sub_device_name text DEFAULT NULL::text, component_function_list text[] DEFAULT NULL::text[], slot_type text DEFAULT 'unknown'::text, serial_number text DEFAULT NULL::text)
 RETURNS component
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	sn			ALIAS FOR serial_number;
	ctid		integer;
	comp_id		integer;
	sub_comp_id	integer;
	stid		integer;
	vendor_name	text;
	sub_vendor_name	text;
	model_name	text;
	c			RECORD;
BEGIN
	IF (pci_sub_vendor_id IS NULL AND pci_subsystem_id IS NOT NULL) OR
			(pci_sub_vendor_id IS NOT NULL AND pci_subsystem_id IS NULL) THEN
		RAISE EXCEPTION
			'pci_sub_vendor_id and pci_subsystem_id must be set together';
	END IF;

	--
	-- See if we have this component type in the database already
	--
	SELECT
		vid.component_type_id INTO ctid
	FROM
		component_property vid JOIN
		component_property did ON (
			vid.component_property_name = 'PCIVendorID' AND
			vid.component_property_type = 'PCI' AND
			did.component_property_name = 'PCIDeviceID' AND
			did.component_property_type = 'PCI' AND
			vid.component_type_id = did.component_type_id ) LEFT JOIN
		component_property svid ON (
			svid.component_property_name = 'PCISubsystemVendorID' AND
			svid.component_property_type = 'PCI' AND
			svid.component_type_id = did.component_type_id ) LEFT JOIN
		component_property sid ON (
			sid.component_property_name = 'PCISubsystemID' AND
			sid.component_property_type = 'PCI' AND
			sid.component_type_id = did.component_type_id )
	WHERE
		vid.property_value = pci_vendor_id::varchar AND
		did.property_value = pci_device_id::varchar AND
		svid.property_value IS NOT DISTINCT FROM pci_sub_vendor_id::varchar AND
		sid.property_value IS NOT DISTINCT FROM pci_subsystem_id::varchar;

	--
	-- The device type doesn't exist, so attempt to insert it
	--

	IF NOT FOUND THEN	
		IF pci_device_name IS NULL OR component_function_list IS NULL THEN
			RAISE EXCEPTION 'component_id not found and pci_device_name or component_function_list was not passed' USING ERRCODE = 'JH501';
		END IF;

		--
		-- Ensure that there's a company linkage for the PCI (subsystem)vendor
		--
		SELECT
			company_id, company_name INTO comp_id, vendor_name
		FROM
			property p JOIN
			company c USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'PCIVendorID' AND
			company_id = pci_vendor_id;
		
		IF NOT FOUND THEN
			IF pci_vendor_name IS NULL THEN
				RAISE EXCEPTION 'PCI vendor id mapping not found and pci_vendor_name was not passed' USING ERRCODE = 'JH501';
			END IF;
			SELECT company_id INTO comp_id FROM company
			WHERE company_name = pci_vendor_name;
		
			IF NOT FOUND THEN
				INSERT INTO company (company_name, description)
				VALUES (pci_vendor_name, 'PCI vendor auto-insert')
				RETURNING company_id INTO comp_id;
			END IF;

			INSERT INTO property (
				property_name,
				property_type,
				property_value,
				company_id
			) VALUES (
				'PCIVendorID',
				'DeviceProvisioning',
				pci_vendor_id,
				comp_id
			);
			vendor_name := pci_vendor_name;
		END IF;

		SELECT
			company_id, company_name INTO sub_comp_id, sub_vendor_name
		FROM
			property JOIN
			company c USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'PCIVendorID' AND
			company_id = pci_sub_vendor_id;
		
		IF NOT FOUND THEN
			IF pci_sub_vendor_name IS NULL THEN
				RAISE EXCEPTION 'PCI subsystem vendor id mapping not found and pci_sub_vendor_name was not passed' USING ERRCODE = 'JH501';
			END IF;
			SELECT company_id INTO sub_comp_id FROM company
			WHERE company_name = pci_sub_vendor_name;
		
			IF NOT FOUND THEN
				INSERT INTO company (company_name, description)
				VALUES (pci_sub_vendor_name, 'PCI vendor auto-insert')
				RETURNING company_id INTO sub_comp_id;
			END IF;

			INSERT INTO property (
				property_name,
				property_type,
				property_value,
				company_id
			) VALUES (
				'PCIVendorID',
				'DeviceProvisioning',
				pci_sub_vendor_id,
				sub_comp_id
			);
			sub_vendor_name := pci_sub_vendor_name;
		END IF;

		--
		-- Fetch the slot type
		--

		SELECT 
			slot_type_id INTO stid
		FROM
			slot_type st
		WHERE
			st.slot_type = insert_pci_component.slot_type AND
			slot_function = 'PCI';

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type not found adding component_type'
				USING ERRCODE = 'JH501';
		END IF;

		--
		-- Figure out the best name/description to insert this component with
		--
		IF pci_sub_device_name IS NOT NULL AND pci_sub_device_name != 'Device' THEN
			model_name = concat_ws(' ', 
				sub_vendor_name, pci_sub_device_name,
				'(' || vendor_name, pci_device_name || ')');
		ELSIF pci_sub_device_name = 'Device' THEN
			model_name = concat_ws(' ', 
				vendor_name, '(' || sub_vendor_name || ')', pci_device_name);
		ELSE
			model_name = concat_ws(' ', vendor_name, pci_device_name);
		END IF;
		INSERT INTO component_type (
			company_id,
			model,
			slot_type_id,
			asset_permitted,
			description
		) VALUES (
			CASE WHEN 
				sub_comp_id IS NULL OR
				pci_sub_device_name IS NULL OR
				pci_sub_device_name = 'Device'
			THEN
				comp_id
			ELSE
				sub_comp_id
			END,
			CASE WHEN
				pci_sub_device_name IS NULL OR
				pci_sub_device_name = 'Device'
			THEN
				pci_device_name
			ELSE
				pci_sub_device_name
			END,
			stid,
			'Y',
			model_name
		) RETURNING component_type_id INTO ctid;
		--
		-- Insert properties for the PCI vendor/device IDs
		--
		INSERT INTO component_property (
			component_property_name,
			component_property_type,
			component_type_id,
			property_value
		) VALUES 
			('PCIVendorID', 'PCI', ctid, pci_vendor_id),
			('PCIDeviceID', 'PCI', ctid, pci_device_id);
		
		IF (pci_subsystem_id IS NOT NULL) THEN
			INSERT INTO component_property (
				component_property_name,
				component_property_type,
				component_type_id,
				property_value
			) VALUES 
				('PCISubsystemVendorID', 'PCI', ctid, pci_sub_vendor_id),
				('PCISubsystemID', 'PCI', ctid, pci_subsystem_id);
		END IF;
		--
		-- Insert the component functions
		--

		INSERT INTO component_type_component_func (
			component_type_id,
			component_function
		) SELECT DISTINCT
			ctid,
			cf
		FROM
			unnest(array_append(component_function_list, 'PCI')) x(cf);
	END IF;


	--
	-- We have a component_type_id now, so look to see if this component
	-- serial number already exists
	--
	IF serial_number IS NOT NULL THEN
		SELECT 
			component.* INTO c
		FROM
			component JOIN
			asset a USING (component_id)
		WHERE
			component_type_id = ctid AND
			a.serial_number = sn;

		IF FOUND THEN
			RETURN c;
		END IF;
	END IF;

	INSERT INTO jazzhands.component (
		component_type_id
	) VALUES (
		ctid
	) RETURNING * INTO c;

	IF serial_number IS NOT NULL THEN
		INSERT INTO asset (
			component_id,
			serial_number,
			ownership_status
		) VALUES (
			c.component_id,
			serial_number,
			'unknown'
		);
	END IF;

	RETURN c;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc component_utils.insert_pci_component -> insert_pci_component 
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH proc validate_component_property -> validate_component_property 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_component_property', 'validate_component_property');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
DROP TRIGGER IF EXISTS trigger_validate_component_property ON jazzhands.component_property;
-- consider old oid 5167954
DROP FUNCTION IF EXISTS validate_component_property();

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 5159525
CREATE OR REPLACE FUNCTION jazzhands.validate_component_property()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally				INTEGER;
	v_comp_prop			RECORD;
	v_comp_prop_type	RECORD;
	v_num				bigint;
	v_listvalue			TEXT;
	component_attrs		RECORD;
BEGIN

	-- Pull in the data from the property and property_type so we can
	-- figure out what is and is not valid

	BEGIN
		SELECT * INTO STRICT v_comp_prop FROM val_component_property WHERE
			component_property_name = NEW.component_property_name AND
			component_property_type = NEW.component_property_type;

		SELECT * INTO STRICT v_comp_prop_type FROM val_component_property_type 
			WHERE component_property_type = NEW.component_property_type;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			RAISE EXCEPTION 
				'Component property name or type does not exist'
				USING ERRCODE = 'foreign_key_violation';
			RETURN NULL;
	END;

	-- Check to see if the property itself is multivalue.  That is, if only
	-- one value can be set for this property for a specific property LHS

	IF (v_comp_prop.is_multivalue != 'Y') THEN
		PERFORM 1 FROM component_property WHERE
			component_property_id != NEW.component_property_id AND
			component_property_name = NEW.component_property_name AND
			component_property_type = NEW.component_property_type AND
			component_type_id IS NOT DISTINCT FROM NEW.component_type_id AND
			component_function IS NOT DISTINCT FROM NEW.component_function AND
			component_id iS NOT DISTINCT FROM NEW.component_id AND
			slot_type_id IS NOT DISTINCT FROM NEW.slot_type_id AND
			slot_function IS NOT DISTINCT FROM NEW.slot_function AND
			slot_id IS NOT DISTINCT FROM NEW.slot_id;
			
		IF FOUND THEN
			RAISE EXCEPTION 
				'Property with name % and type % already exists for given LHS and property is not multivalue',
				NEW.component_property_name,
				NEW.component_property_type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;
	END IF;

	-- Check to see if the property type is multivalue.  That is, if only
	-- one property and value can be set for any properties with this type
	-- for a specific property LHS

	IF (v_comp_prop_type.is_multivalue != 'Y') THEN
		PERFORM 1 FROM component_property WHERE
			component_property_id != NEW.component_property_id AND
			component_property_type = NEW.component_property_type AND
			component_type_id IS NOT DISTINCT FROM NEW.component_type_id AND
			component_function IS NOT DISTINCT FROM NEW.component_function AND
			component_id iS NOT DISTINCT FROM NEW.component_id AND
			slot_type_id IS NOT DISTINCT FROM NEW.slot_type_id AND
			slot_function IS NOT DISTINCT FROM NEW.slot_function AND
			slot_id IS NOT DISTINCT FROM NEW.slot_id;

		IF FOUND THEN
			RAISE EXCEPTION 
				'Property % of type % already exists for given LHS and property type is not multivalue',
				NEW.component_property_name, NEW.component_property_type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;
	END IF;

	-- now validate the property_value columns.
	tally := 0;

	--
	-- first determine if the property_value is set properly.
	--

	-- at this point, tally will be set to 1 if one of the other property
	-- values is set to something valid.  Now, check the various options for
	-- PROPERTY_VALUE itself.  If a new type is added to the val table, this
	-- trigger needs to be updated or it will be considered invalid.  If a
	-- new PROPERTY_VALUE_* column is added, then it will pass through without
	-- trigger modification.  This should be considered bad.

	IF NEW.property_value IS NOT NULL THEN
		tally := tally + 1;
		IF v_comp_prop.property_data_type = 'boolean' THEN
			IF NEW.Property_Value != 'Y' AND NEW.Property_Value != 'N' THEN
				RAISE 'Boolean property_value must be Y or N' USING
					ERRCODE = 'invalid_parameter_value';
			END IF;
		ELSIF v_comp_prop.property_data_type = 'number' THEN
			BEGIN
				v_num := to_number(NEW.property_value, '9');
			EXCEPTION
				WHEN OTHERS THEN
					RAISE 'property_value must be numeric' USING
						ERRCODE = 'invalid_parameter_value';
			END;
		ELSIF v_comp_prop.property_data_type = 'list' THEN
			BEGIN
				SELECT valid_property_value INTO STRICT v_listvalue FROM 
					val_component_property_value WHERE
						component_property_name = NEW.component_property_name AND
						component_property_type = NEW.component_property_type AND
						valid_property_value = NEW.property_value;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					RAISE 'property_value must be a valid value' USING
						ERRCODE = 'invalid_parameter_value';
			END;
		ELSIF v_comp_prop.property_data_type != 'string' THEN
			RAISE 'property_data_type is not a known type' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.property_data_type != 'none' AND tally = 0 THEN
		RAISE 'One of the property_value fields must be set.' USING
			ERRCODE = 'invalid_parameter_value';
	END IF;

	IF tally > 1 THEN
		RAISE 'Only one of the property_value fields may be set.' USING
			ERRCODE = 'invalid_parameter_value';
	END IF;

	--
	-- At this point, the value itself is valid for this property, now
	-- determine whether the property is allowed on the target
	--
	-- There needs to be a stanza here for every "lhs".  If a new column is
	-- added to the component_property table, a new stanza needs to be added
	-- here, otherwise it will not be validated.  This should be considered bad.

	IF v_comp_prop.permit_component_type_id = 'REQUIRED' THEN
		IF NEW.component_type_id IS NULL THEN
			RAISE 'component_type_id is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_component_type_id = 'PROHIBITED' THEN
		IF NEW.component_type_id IS NOT NULL THEN
			RAISE 'component_type_id is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_component_function = 'REQUIRED' THEN
		IF NEW.component_function IS NULL THEN
			RAISE 'component_function is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_component_function = 'PROHIBITED' THEN
		IF NEW.component_function IS NOT NULL THEN
			RAISE 'component_function is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_component_id = 'REQUIRED' THEN
		IF NEW.component_id IS NULL THEN
			RAISE 'component_id is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_component_id = 'PROHIBITED' THEN
		IF NEW.component_id IS NOT NULL THEN
			RAISE 'component_id is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_intcomp_conn_id = 'REQUIRED' THEN
		IF NEW.inter_component_connection_id IS NULL THEN
			RAISE 'inter_component_connection_id is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_intcomp_conn_id = 'PROHIBITED' THEN
		IF NEW.inter_component_connection_id IS NOT NULL THEN
			RAISE 'inter_component_connection_id is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_slot_type_id = 'REQUIRED' THEN
		IF NEW.slot_type_id IS NULL THEN
			RAISE 'slot_type_id is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_slot_type_id = 'PROHIBITED' THEN
		IF NEW.slot_type_id IS NOT NULL THEN
			RAISE 'slot_type_id is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_slot_function = 'REQUIRED' THEN
		IF NEW.slot_function IS NULL THEN
			RAISE 'slot_function is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_slot_function = 'PROHIBITED' THEN
		IF NEW.slot_function IS NOT NULL THEN
			RAISE 'slot_function is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_slot_id = 'REQUIRED' THEN
		IF NEW.slot_id IS NULL THEN
			RAISE 'slot_id is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_slot_id = 'PROHIBITED' THEN
		IF NEW.slot_id IS NOT NULL THEN
			RAISE 'slot_id is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	--
	-- LHS population is verified; now validate any particular restrictions
	-- on individual values
	--

	--
	-- For slot_id, validate that the component_type, component_function,
	-- slot_type, and slot_function are all valid
	--
	IF NEW.slot_id IS NOT NULL AND COALESCE(
			v_comp_prop.required_component_type_id::text,
			v_comp_prop.required_component_function,
			v_comp_prop.required_slot_type_id::text,
			v_comp_prop.required_slot_function) IS NOT NULL THEN

		WITH x AS (
			SELECT
				component_type_id,
				array_agg(component_function) as component_function
			FROM
				component_type_component_func
			GROUP BY
				component_type_id
		) SELECT
			component_type_id,
			component_function,
			st.slot_type_id,
			slot_function
		INTO
			component_attrs
		FROM
			slot cs JOIN
			slot_type st USING (slot_type_id) JOIN
			component c USING (component_id) JOIN
			component_type ct USING (component_type_id) LEFT JOIN
			x USING (component_type_id)
		WHERE
			slot_id = NEW.slot_id;

		IF v_comp_prop.required_component_type_id IS NOT NULL AND
				v_comp_prop.required_component_type_id !=
				component_attrs.component_type_id THEN
			RAISE 'component_type for slot_id must be % (is: %)',
					v_comp_prop.required_component_type_id,
					component_attrs.component_type_id
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF v_comp_prop.required_component_function IS NOT NULL AND
				NOT (v_comp_prop.required_component_function =
					ANY(component_attrs.component_function)) THEN
			RAISE 'component_function for slot_id must be % (is: %)',
					v_comp_prop.required_component_function,
					component_attrs.component_function
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF v_comp_prop.required_slot_type_id IS NOT NULL AND
				v_comp_prop.required_slot_type_id !=
				component_attrs.slot_type_id THEN
			RAISE 'slot_type_id for slot_id must be % (is: %)',
					v_comp_prop.required_slot_type_id,
					component_attrs.slot_type_id
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF v_comp_prop.required_slot_function IS NOT NULL AND
				v_comp_prop.required_slot_function !=
				component_attrs.slot_function THEN
			RAISE 'slot_function for slot_id must be % (is: %)',
					v_comp_prop.required_slot_function,
					component_attrs.slot_function
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF NEW.slot_type_id IS NOT NULL AND 
			v_comp_prop.required_slot_function IS NOT NULL THEN

		SELECT
			slot_function
		INTO
			component_attrs
		FROM
			slot_type st
		WHERE
			slot_type_id = NEW.slot_type_id;

		IF v_comp_prop.required_slot_function !=
				component_attrs.slot_function THEN
			RAISE 'slot_function for slot_type_id must be % (is: %)',
					v_comp_prop.required_slot_function,
					component_attrs.slot_function
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF NEW.component_id IS NOT NULL AND COALESCE(
			v_comp_prop.required_component_type_id::text,
			v_comp_prop.required_component_function) IS NOT NULL THEN

		SELECT
			component_type_id,
			array_agg(component_function) as component_function
		INTO
			component_attrs
		FROM
			component c JOIN
			component_type_component_func ctcf USING (component_type_id)
		WHERE
			component_id = NEW.component_id
		GROUP BY
			component_type_id;

		IF v_comp_prop.required_component_type_id IS NOT NULL AND
				v_comp_prop.required_component_type_id !=
				component_attrs.component_type_id THEN
			RAISE 'component_type for component_id must be % (is: %)',
					v_comp_prop.required_component_type_id,
					component_attrs.component_type_id
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF v_comp_prop.required_component_function IS NOT NULL AND
				NOT (v_comp_prop.required_component_function =
					ANY(component_attrs.component_function)) THEN
			RAISE 'component_function for component_id must be % (is: %)',
					v_comp_prop.required_component_function,
					component_attrs.component_function
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF NEW.component_type_id IS NOT NULL AND 
			v_comp_prop.required_component_function IS NOT NULL THEN

		SELECT
			component_type_id,
			array_agg(component_function) as component_function
		INTO
			component_attrs
		FROM
			component_type_component_func ctcf
		WHERE
			component_type_id = NEW.component_type_id
		GROUP BY
			component_type_id;

		IF v_comp_prop.required_component_function IS NOT NULL AND
				NOT (v_comp_prop.required_component_function =
					ANY(component_attrs.component_function)) THEN
			RAISE 'component_function for component_type_id must be % (is: %)',
					v_comp_prop.required_component_function,
					component_attrs.component_function
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
		
	RETURN NEW;
END;
$function$
;
-- triggers on this function (if applicable)
CREATE CONSTRAINT TRIGGER trigger_validate_component_property AFTER INSERT OR UPDATE ON component_property DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE validate_component_property();

-- DONE WITH proc validate_component_property -> validate_component_property 
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH proc create_component_slots_by_trigger -> create_component_slots_by_trigger 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'create_component_slots_by_trigger', 'create_component_slots_by_trigger');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
DROP TRIGGER IF EXISTS trigger_create_component_template_slots ON jazzhands.component;
-- consider old oid 6168604
DROP FUNCTION IF EXISTS create_component_slots_by_trigger();

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 6168128
CREATE OR REPLACE FUNCTION jazzhands.create_component_slots_by_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	-- For inserts, just do a simple slot creation, for updates, things
	-- get more complicated, so try to migrate slots

	IF (TG_OP = 'INSERT' OR OLD.component_type_id != NEW.component_type_id)
	THEN
		PERFORM component_utils.create_component_template_slots(
			component_id := NEW.component_id);
	END IF;
	IF (TG_OP = 'UPDATE' AND OLD.component_type_id != NEW.component_type_id)
	THEN
		PERFORM component_utils.migrate_component_template_slots(
			component_id := NEW.component_id,
			old_component_type_id := OLD.component_type_id,
			new_component_type_id := NEW.component_type_id
			);
	END IF;
	RETURN NEW;
END;
$function$
;
-- triggers on this function (if applicable)
CREATE TRIGGER trigger_create_component_template_slots AFTER INSERT OR UPDATE OF component_type_id ON component FOR EACH ROW EXECUTE PROCEDURE create_component_slots_by_trigger();

-- DONE WITH proc create_component_slots_by_trigger -> create_component_slots_by_trigger 
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH proc component_utils.insert_component_into_parent_slot -> insert_component_into_parent_slot 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 6189277
CREATE OR REPLACE FUNCTION component_utils.insert_component_into_parent_slot(parent_component_id integer, component_id integer, slot_name text, slot_function text, slot_type text DEFAULT 'unknown'::text, slot_index integer DEFAULT NULL::integer, physical_label text DEFAULT NULL::text)
 RETURNS slot
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	pcid 	ALIAS FOR parent_component_id;
	cid		ALIAS FOR component_id;
	sf		ALIAS FOR slot_function;
	sn		ALIAS FOR slot_name;
	st		ALIAS FOR slot_type;
	s		RECORD;
	stid	integer;
BEGIN
	--
	-- Look for this slot assigned to the component
	--
	SELECT
		slot.* INTO s
	FROM
		slot JOIN
		slot_type USING (slot_type_id)
	WHERE
		slot.component_id = pcid AND
		slot_type.slot_type = st AND
		slot_type.slot_function = sf AND
		slot.slot_name = sn;

	IF NOT FOUND THEN
		RAISE DEBUG 'Auto-creating slot for component assignment';
		SELECT
			slot_type_id INTO stid
		FROM
			slot_type
		WHERE
			slot_type.slot_type = st AND
			slot_type.slot_function = sf;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type not found adding component_type'
				USING ERRCODE = 'JH501';
		END IF;

		INSERT INTO slot (
			component_id,
			slot_name,
			slot_index,
			slot_type_id,
			physical_label,
			description
		) VALUES (
			pcid,
			sn,
			slot_index,
			stid,
			physical_label,
			'autocreated component slot'
		) RETURNING * INTO s;
	END IF;

	RAISE DEBUG 'Assigning component with component_id % to slot %',
		cid, s.slot_id;

	UPDATE 
		component c
	SET
		parent_slot_id = s.slot_id
	WHERE
		c.component_id = cid;

	RETURN s;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc component_utils.insert_component_into_parent_slot -> insert_component_into_parent_slot 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc component_utils.insert_disk_component -> insert_disk_component 


SELECT schema_support.save_grants_for_replay('jazzhands', 'insert_disk_component');
-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
SELECT schema_support.retrieve_functions('component_utils', 'insert_disk_component', true);

-- consider NEW oid 6189271
CREATE OR REPLACE FUNCTION component_utils.insert_disk_component(model text, bytes bigint, vendor_name text DEFAULT NULL::text, protocol text DEFAULT 'SATA'::text, media_type text DEFAULT 'Rotational'::text, serial_number text DEFAULT NULL::text)
 RETURNS component
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	m			ALIAS FOR model;
	sn			ALIAS FOR serial_number;
	ctid		integer;
	stid		integer;
	c			RECORD;
	cid			integer;
BEGIN
	cid := NULL;

	IF vendor_name IS NOT NULL THEN	
		SELECT 
			company_id INTO cid
		FROM
			company c LEFT JOIN
			property p USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'VendorDiskProbeString' AND
			property_value = vendor_name;
	END IF;

	--
	-- See if we have this component type in the database already.
	--
	SELECT DISTINCT
		component_type_id INTO ctid
	FROM
		component_type ct JOIN
		component_type_component_func ctcf USING (component_type_id)
	WHERE
		component_function = 'disk' AND
		ct.model = m AND
		CASE WHEN cid IS NOT NULL THEN
			(company_id = cid)
		ELSE
			true
		END;

	--
	-- If the type isn't found, then we need to insert it
	--
	IF NOT FOUND THEN
		--
		-- Fetch the slot type
		--
		SELECT 
			slot_type_id INTO stid
		FROM
			slot_type st
		WHERE
			st.slot_type = protocol AND
			slot_function = 'disk';

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type not found adding component_type'
				USING ERRCODE = 'JH501';
		END IF;

		IF cid IS NULL THEN
			SELECT
				company_id INTO cid
			FROM
				company
			WHERE
				company_name = 'unknown';

			IF NOT FOUND THEN
				IF NOT FOUND THEN
					RAISE EXCEPTION 'company_id for unknown company not found adding component_type'
						USING ERRCODE = 'JH501';
				END IF;
			END IF;
		END IF;

		INSERT INTO component_type (
			company_id,
			model,
			slot_type_id,
			asset_permitted,
			description
		) VALUES (
			cid,
			model,
			stid,
			'Y',
			concat_ws(' ', vendor_name, model, media_type, 'disk')
		) RETURNING component_type_id INTO ctid;

		--
		-- Insert component properties for the disk
		--
		INSERT INTO component_property (
			component_property_name,
			component_property_type,
			component_type_id,
			property_value
		) VALUES 
			('DiskSize', 'disk', ctid, bytes),
			('DiskProtocol', 'disk', ctid, protocol),
			('MediaType', 'disk', ctid, media_type);
		
		--
		-- Insert the component functions
		--

		INSERT INTO component_type_component_func (
			component_type_id,
			component_function
		) SELECT DISTINCT
			ctid,
			cf
		FROM
			unnest(ARRAY['storage', 'disk']) x(cf);
	END IF;

	--
	-- We have a component_type_id now, so look to see if this component
	-- serial number already exists
	--
	IF serial_number IS NOT NULL THEN
		SELECT 
			component.* INTO c
		FROM
			component JOIN
			asset a USING (component_id)
		WHERE
			component_type_id = ctid AND
			a.serial_number = sn;

		IF FOUND THEN
			RETURN c;
		END IF;
	END IF;

	INSERT INTO jazzhands.component (
		component_type_id
	) VALUES (
		ctid
	) RETURNING * INTO c;

	IF serial_number IS NOT NULL THEN
		INSERT INTO asset (
			component_id,
			serial_number,
			ownership_status
		) VALUES (
			c.component_id,
			serial_number,
			'unknown'
		);
	END IF;

	RETURN c;

END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc component_utils.insert_disk_component -> insert_disk_component 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc component_utils.remove_component_hier -> remove_component_hier 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 6189078
CREATE OR REPLACE FUNCTION component_utils.remove_component_hier(component_id integer, really_delete boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	slot_list		integer[];
	shelf_list		integer[];
	delete_list		integer[];
	cid				integer;
BEGIN
	cid := component_id;

	SELECT ARRAY(
		SELECT
			slot_id
		FROM
			v_component_hier h JOIN
			slot s ON (h.child_component_id = s.component_id)
		WHERE
			h.component_id = cid)
	INTO slot_list;

	IF really_delete THEN
		SELECT ARRAY(
			SELECT
				child_component_id
			FROM
				v_component_hier h
			WHERE
				h.component_id = cid)
		INTO delete_list;
	ELSE

		SELECT ARRAY(
			SELECT
				child_component_id
			FROM
				v_component_hier h LEFT JOIN
				asset a on (a.component_id = h.child_component_id)
			WHERE
				h.component_id = cid AND
				serial_number IS NOT NULL
		)
		INTO shelf_list;

		SELECT ARRAY(
			SELECT
				child_component_id
			FROM
				v_component_hier h LEFT JOIN
				asset a on (a.component_id = h.child_component_id)
			WHERE
				h.component_id = cid AND
				serial_number IS NULL
		)
		INTO delete_list;

	END IF;

	DELETE FROM
		inter_component_connection
	WHERE
		slot1_id = ANY (slot_list) OR
		slot2_id = ANY (slot_list);

	UPDATE
		component c
	SET
		parent_slot_id = NULL
	WHERE
		c.component_id = ANY (array_cat(delete_list, shelf_list)) AND
		parent_slot_id IS NOT NULL;

	DELETE FROM component_property cp WHERE
		cp.component_id = ANY (delete_list) OR
		slot_id = ANY (slot_list);
		
	DELETE FROM
		slot s
	WHERE
		slot_id = ANY (slot_list) AND
		s.component_id = ANY(delete_list);
		
	DELETE FROM
		component c
	WHERE
		c.component_id = ANY (delete_list);

	RETURN true;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc component_utils.remove_component_hier -> remove_component_hier 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc component_utils.replace_component -> replace_component 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 6189285
CREATE OR REPLACE FUNCTION component_utils.replace_component(old_component_id integer, new_component_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	oc	RECORD;
BEGIN
	SELECT
		* INTO oc
	FROM
		component
	WHERE
		component_id = old_component_id;

	UPDATE
		component
	SET
		parent_slot_id = NULL
	WHERE
		component_id = old_component_id;

	UPDATE 
		component
	SET
		parent_slot_id = oc.parent_slot_id
	WHERE
		component_id = new_component_id;

	UPDATE
		device
	SET
		component_id = new_component_id
	WHERE
		component_id = old_component_id;
	
	UPDATE
		physicalish_volume
	SET
		component_id = new_component_id
	WHERE
		component_id = old_component_id;

	RETURN;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc component_utils.replace_component -> replace_component 
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_person_status [6036938]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_person_status', 'val_person_status');

-- FOREIGN KEYS FROM
ALTER TABLE person_company DROP CONSTRAINT IF EXISTS fk_person_company_prsncmpy_sta;
ALTER TABLE account DROP CONSTRAINT IF EXISTS fk_acct_stat_id;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_person_status');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_person_status DROP CONSTRAINT IF EXISTS pk_val_person_status;
-- INDEXES
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_person_status DROP CONSTRAINT IF EXISTS check_yes_no_856940377;
ALTER TABLE jazzhands.val_person_status DROP CONSTRAINT IF EXISTS check_yes_no_100412184;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_person_status ON jazzhands.val_person_status;
DROP TRIGGER IF EXISTS trigger_audit_val_person_status ON jazzhands.val_person_status;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_person_status');
---- BEGIN audit.val_person_status TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_person_status', 'val_person_status');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_person_status');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_person_status_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_person_status');
---- DONE audit.val_person_status TEARDOWN


ALTER TABLE val_person_status RENAME TO val_person_status_v63;
ALTER TABLE audit.val_person_status RENAME TO val_person_status_v63;

CREATE TABLE val_person_status
(
	person_status	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	is_disabled	character(1) NOT NULL,
	is_enabled	character(1) NOT NULL,
	propagate_from_person	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_person_status', false);
INSERT INTO val_person_status (
	person_status,
	description,
	is_disabled,
	is_enabled,		-- new column (is_enabled)
	propagate_from_person,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	person_status,
	description,
	is_disabled,
	CASE WHEN is_disabled = 'Y' THEN 'N' ELSE 'Y' END,	-- new column (is_enabled)
	propagate_from_person,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_person_status_v63;

INSERT INTO audit.val_person_status (
	person_status,
	description,
	is_disabled,
	is_enabled,		-- new column (is_enabled)
	propagate_from_person,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	person_status,
	description,
	is_disabled,
	CASE WHEN is_disabled = 'Y' THEN 'N' ELSE 'Y' END,	-- new column (is_enabled)
	propagate_from_person,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_person_status_v63;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_person_status ADD CONSTRAINT pk_val_person_status PRIMARY KEY (person_status);

-- Table/Column Comments
COMMENT ON COLUMN val_person_status.is_disabled IS 'This column is being deprecated.  it is always set to the opposite of IS_ENABLED (enforced by trigger).';
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_person_status ADD CONSTRAINT check_yes_no_100412184
	CHECK (is_disabled = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE val_person_status ADD CONSTRAINT check_yes_no_856940377
	CHECK (propagate_from_person = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE val_person_status ADD CONSTRAINT check_yes_no_vpers_stat_enable
	CHECK (is_enabled = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_person_status and account
ALTER TABLE account
	ADD CONSTRAINT fk_acct_stat_id
	FOREIGN KEY (account_status) REFERENCES val_person_status(person_status);
-- consider FK val_person_status and person_company
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_prsncmpy_sta
	FOREIGN KEY (person_company_status) REFERENCES val_person_status(person_status);

-- FOREIGN KEYS TO

-- TRIGGERS
CREATE OR REPLACE FUNCTION val_person_status_enabled_migration_enforce()
	RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'INSERT' THEN
		IF ( NEW.is_disabled IS NOT NULL AND NEW.is_enabled IS NOT NULL ) THEN
			RAISE EXCEPTION 'May not set both IS_ENABLED and IS_DISABLED.  Set IS_ENABLED only.'
				USING errcode = 'integrity_constraint_violation';
		END IF;

		IF NEW.is_enabled IS NOT NULL THEN
			IF NEW.is_enabled = 'Y' THEN
				NEW.is_disabled := 'N';
			ELSE
				NEW.is_disabled := 'Y';
			END IF;
		ELSIF NEW.is_disabled IS NOT NULL THEN
			IF NEW.is_disabled = 'Y' THEN
				NEW.is_enabled := 'N';
			ELSE
				NEW.is_enabled := 'Y';
			END IF;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF ( OLD.is_disabled != NEW.is_disabled AND
				OLD.is_enabled != NEW.is_enabled ) THEN
			RAISE EXCEPTION 'May not update both IS_ENABLED and IS_DISABLED.  Update IS_ENABLED only.'
				USING errcode = 'integrity_constraint_violation';
		END IF;

		IF OLD.is_enabled != NEW.is_enabled THEN
			IF NEW.is_enabled = 'Y' THEN
				NEW.is_disabled := 'N';
			ELSE
				NEW.is_disabled := 'Y';
			END IF;
		ELSIF OLD.is_disabled != NEW.is_disabled THEN
			IF NEW.is_disabled = 'Y' THEN
				NEW.is_enabled := 'N';
			ELSE
				NEW.is_enabled := 'Y';
			END IF;
		END IF;
	END IF;

	IF NEW.is_enabled = NEW.is_disabled THEN
		RAISE NOTICE 'is_enabled=is_disabled.  This should never happen' 
			USING  errcode = 'integrity_constraint_violation';
	END IF;

	RETURN NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_person_status_enabled_migration_enforce 
	ON account;
CREATE TRIGGER trigger_val_person_status_enabled_migration_enforce 
BEFORE INSERT OR UPDATE of is_disabled, is_enabled
	ON val_person_status
	FOR EACH ROW EXECUTE 
	PROCEDURE val_person_status_enabled_migration_enforce();


-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_person_status');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_person_status');
DROP TABLE IF EXISTS val_person_status_v63;
DROP TABLE IF EXISTS audit.val_person_status_v63;
-- DONE DEALING WITH TABLE val_person_status [6028452]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE account [6034704]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'account', 'account');

-- FOREIGN KEYS FROM
ALTER TABLE appaal_instance DROP CONSTRAINT IF EXISTS fk_appaal_i_reference_fo_accti;
ALTER TABLE sw_package_release DROP CONSTRAINT IF EXISTS fk_sw_pkg_rel_ref_sys_user;
ALTER TABLE account_collection_account DROP CONSTRAINT IF EXISTS fk_acol_account_id;
ALTER TABLE account_password DROP CONSTRAINT IF EXISTS fk_acctpwd_acct_id;
ALTER TABLE account_ssh_key DROP CONSTRAINT IF EXISTS fk_account_ssh_key_ssh_key_id;
ALTER TABLE account_auth_log DROP CONSTRAINT IF EXISTS fk_acctauthlog_accid;
ALTER TABLE klogin DROP CONSTRAINT IF EXISTS fk_klgn_acct_dst_id;
ALTER TABLE department DROP CONSTRAINT IF EXISTS fk_dept_mgr_acct_id;
ALTER TABLE account_token DROP CONSTRAINT IF EXISTS fk_acct_ref_acct_token;
ALTER TABLE account_unix_info DROP CONSTRAINT IF EXISTS fk_auxifo_acct_id;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_acctid;
ALTER TABLE pseudo_klogin DROP CONSTRAINT IF EXISTS fk_pklgn_acct_dstid;
ALTER TABLE klogin DROP CONSTRAINT IF EXISTS fk_klgn_acct_id;
ALTER TABLE account_assignd_cert DROP CONSTRAINT IF EXISTS fk_acct_asdcrt_acctid;
ALTER TABLE device_collection_assignd_cert DROP CONSTRAINT IF EXISTS fk_devcolascrt_flownacctid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.account DROP CONSTRAINT IF EXISTS fk_acct_stat_id;
ALTER TABLE jazzhands.account DROP CONSTRAINT IF EXISTS fk_account_company_person;
ALTER TABLE jazzhands.account DROP CONSTRAINT IF EXISTS fk_account_prsn_cmpy_acct;
ALTER TABLE jazzhands.account DROP CONSTRAINT IF EXISTS fk_acct_vacct_type;
ALTER TABLE jazzhands.account DROP CONSTRAINT IF EXISTS fk_account_acct_rlm_id;
ALTER TABLE jazzhands.account DROP CONSTRAINT IF EXISTS fk_account_acctrole;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'account');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.account DROP CONSTRAINT IF EXISTS ak_uq_account_lgn_realm;
ALTER TABLE jazzhands.account DROP CONSTRAINT IF EXISTS pk_account_id;
ALTER TABLE jazzhands.account DROP CONSTRAINT IF EXISTS ak_acct_acctid_realm_id;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif11account";
DROP INDEX IF EXISTS "jazzhands"."xif12account";
DROP INDEX IF EXISTS "jazzhands"."idx_account_account_status";
DROP INDEX IF EXISTS "jazzhands"."idx_account_account_tpe";
DROP INDEX IF EXISTS "jazzhands"."xif8account";
DROP INDEX IF EXISTS "jazzhands"."xif9account";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_update_peraccount_account_collection ON jazzhands.account;
DROP TRIGGER IF EXISTS trig_add_automated_ac_on_account ON jazzhands.account;
DROP TRIGGER IF EXISTS trig_rm_automated_ac_on_account ON jazzhands.account;
DROP TRIGGER IF EXISTS trigger_delete_peraccount_account_collection ON jazzhands.account;
DROP TRIGGER IF EXISTS trigger_create_new_unix_account ON jazzhands.account;
DROP TRIGGER IF EXISTS trigger_audit_account ON jazzhands.account;
DROP TRIGGER IF EXISTS trig_userlog_account ON jazzhands.account;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'account');
---- BEGIN audit.account TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'account', 'account');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'account');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."account_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'account');
---- DONE audit.account TEARDOWN


ALTER TABLE account RENAME TO account_v63;
ALTER TABLE audit.account RENAME TO account_v63;

CREATE TABLE account
(
	account_id	integer NOT NULL,
	login	varchar(50) NOT NULL,
	person_id	integer NOT NULL,
	company_id	integer NOT NULL,
	is_enabled	character(1) NOT NULL,
	account_realm_id	integer NOT NULL,
	account_status	varchar(50) NOT NULL,
	account_role	varchar(50) NOT NULL,
	account_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'account', false);
ALTER TABLE account
	ALTER account_id
	SET DEFAULT nextval('account_account_id_seq'::regclass);
INSERT INTO account (
	account_id,
	login,
	person_id,
	company_id,
	is_enabled,		-- new column (is_enabled)
	account_realm_id,
	account_status,
	account_role,
	account_type,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	a.account_id,
	a.login,
	a.person_id,
	a.company_id,
	ps.is_enabled,		-- new column (is_enabled)
	a.account_realm_id,
	a.account_status,
	a.account_role,
	a.account_type,
	a.description,
	a.data_ins_user,
	a.data_ins_date,
	a.data_upd_user,
	a.data_upd_date
FROM account_v63  a
	INNER JOIN val_person_status ps ON a.account_status = ps.person_status;

INSERT INTO audit.account (
	account_id,
	login,
	person_id,
	company_id,
	is_enabled,		-- new column (is_enabled)
	account_realm_id,
	account_status,
	account_role,
	account_type,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	a.account_id,
	a.login,
	a.person_id,
	a.company_id,
	ps.is_enabled,		-- new column (is_enabled)
	a.account_realm_id,
	a.account_status,
	a.account_role,
	a.account_type,
	a.description,
	a.data_ins_user,
	a.data_ins_date,
	a.data_upd_user,
	a.data_upd_date,
	a."aud#action",
	a."aud#timestamp",
	a."aud#user",
	a."aud#seq"
FROM audit.account_v63 a
	LEFT JOIN val_person_status ps ON a.account_status = ps.person_status;

ALTER TABLE account
	ALTER account_id
	SET DEFAULT nextval('account_account_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE account ADD CONSTRAINT ak_acct_acctid_realm_id UNIQUE (account_id, account_realm_id);
ALTER TABLE account ADD CONSTRAINT pk_account_id PRIMARY KEY (account_id);
ALTER TABLE account ADD CONSTRAINT ak_uq_account_lgn_realm UNIQUE (account_realm_id, login);

-- Table/Column Comments
COMMENT ON COLUMN account.is_enabled IS 'This column is trigger enforced to match what val_person_status says is the correct value for account_status';
-- INDEXES
CREATE INDEX xif9account ON account USING btree (account_role);
CREATE INDEX xif8account ON account USING btree (account_realm_id);
CREATE INDEX idx_account_account_tpe ON account USING btree (account_type);
CREATE INDEX xif11account ON account USING btree (company_id, person_id);
CREATE INDEX xif12account ON account USING btree (person_id, company_id, account_realm_id);
CREATE INDEX idx_account_account_status ON account USING btree (account_status);

-- CHECK CONSTRAINTS
ALTER TABLE account ADD CONSTRAINT check_yes_no_355473735
	CHECK (is_enabled = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK account and account_password
ALTER TABLE account_password
	ADD CONSTRAINT fk_acctpwd_acct_id
	FOREIGN KEY (account_id, account_realm_id) REFERENCES account(account_id, account_realm_id);
-- consider FK account and account_ssh_key
ALTER TABLE account_ssh_key
	ADD CONSTRAINT fk_account_ssh_key_ssh_key_id
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK account and appaal_instance
ALTER TABLE appaal_instance
	ADD CONSTRAINT fk_appaal_i_reference_fo_accti
	FOREIGN KEY (file_owner_account_id) REFERENCES account(account_id);
-- consider FK account and sw_package_release
ALTER TABLE sw_package_release
	ADD CONSTRAINT fk_sw_pkg_rel_ref_sys_user
	FOREIGN KEY (creation_account_id) REFERENCES account(account_id);
-- consider FK account and account_collection_account
ALTER TABLE account_collection_account
	ADD CONSTRAINT fk_acol_account_id
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK account and account_unix_info
ALTER TABLE account_unix_info
	ADD CONSTRAINT fk_auxifo_acct_id
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK account and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_acctid
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK account and account_assignd_cert
ALTER TABLE account_assignd_cert
	ADD CONSTRAINT fk_acct_asdcrt_acctid
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK account and pseudo_klogin
ALTER TABLE pseudo_klogin
	ADD CONSTRAINT fk_pklgn_acct_dstid
	FOREIGN KEY (dest_account_id) REFERENCES account(account_id);
-- consider FK account and klogin
ALTER TABLE klogin
	ADD CONSTRAINT fk_klgn_acct_id
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK account and device_collection_assignd_cert
ALTER TABLE device_collection_assignd_cert
	ADD CONSTRAINT fk_devcolascrt_flownacctid
	FOREIGN KEY (file_owner_account_id) REFERENCES account(account_id);
-- consider FK account and klogin
ALTER TABLE klogin
	ADD CONSTRAINT fk_klgn_acct_dst_id
	FOREIGN KEY (dest_account_id) REFERENCES account(account_id);
-- consider FK account and department
ALTER TABLE department
	ADD CONSTRAINT fk_dept_mgr_acct_id
	FOREIGN KEY (manager_account_id) REFERENCES account(account_id);
-- consider FK account and account_auth_log
ALTER TABLE account_auth_log
	ADD CONSTRAINT fk_acctauthlog_accid
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK account and account_token
ALTER TABLE account_token
	ADD CONSTRAINT fk_acct_ref_acct_token
	FOREIGN KEY (account_id) REFERENCES account(account_id);

-- FOREIGN KEYS TO
-- consider FK account and account_realm
ALTER TABLE account
	ADD CONSTRAINT fk_account_acct_rlm_id
	FOREIGN KEY (account_realm_id) REFERENCES account_realm(account_realm_id);
-- consider FK account and val_account_role
ALTER TABLE account
	ADD CONSTRAINT fk_account_acctrole
	FOREIGN KEY (account_role) REFERENCES val_account_role(account_role);
-- consider FK account and val_account_type
ALTER TABLE account
	ADD CONSTRAINT fk_acct_vacct_type
	FOREIGN KEY (account_type) REFERENCES val_account_type(account_type);
-- consider FK account and person_account_realm_company
ALTER TABLE account
	ADD CONSTRAINT fk_account_prsn_cmpy_acct
	FOREIGN KEY (person_id, company_id, account_realm_id) REFERENCES person_account_realm_company(person_id, company_id, account_realm_id) DEFERRABLE;
-- consider FK account and val_person_status
ALTER TABLE account
	ADD CONSTRAINT fk_acct_stat_id
	FOREIGN KEY (account_status) REFERENCES val_person_status(person_status);
-- consider FK account and person_company
ALTER TABLE account
	ADD CONSTRAINT fk_account_company_person
	FOREIGN KEY (company_id, person_id) REFERENCES person_company(company_id, person_id) DEFERRABLE;

-- TRIGGERS

/*
 * Enforce that is_enabled should match whatever val_person_status has for it.
 *
 * XXX - this needs to be reimplemented in oracle
 */
CREATE OR REPLACE FUNCTION account_enforce_is_enabled()
	RETURNS TRIGGER AS $$
DECLARE
	correctval	char(1);
BEGIN
	SELECT is_enabled INTO correctval
	FROM val_person_status 
	WHERE person_status = NEW.account_status;

	IF TG_OP = 'INSERT' THEN
		IF NEW.is_enabled is NULL THEN
			NEW.is_enabled = correctval;
		ELSIF NEW.account_status != correctval THEN
			RAISE EXCEPTION 'May not set IS_ENABLED to an invalid value for given account_status: %', NEW.account_status
				USING errcode = 'integrity_constraint_violation';
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.account_status != OLD.account_status THEN
			IF NEW.is_enabled != correctval THEN
				NEW.is_enabled := correctval;
			END IF;
		ELSIF NEW.is_enabled != correctval THEN
			RAISE EXCEPTION 'May not update IS_ENABLED to an invalid value for given account_status: %', NEW.account_status
				USING errcode = 'integrity_constraint_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_account_enforce_is_enabled 
BEFORE INSERT OR UPDATE of account_status,is_enabled
	ON account
	FOR EACH ROW EXECUTE PROCEDURE account_enforce_is_enabled();

-- XXX - may need to include trigger function
CREATE TRIGGER trigger_update_peraccount_account_collection AFTER INSERT OR UPDATE ON account FOR EACH ROW EXECUTE PROCEDURE update_peraccount_account_collection();

-- XXX - may need to include trigger function
-- comes later
-- CREATE TRIGGER trig_add_account_automated_reporting_ac AFTER INSERT OR UPDATE OF login ON account FOR EACH ROW EXECUTE PROCEDURE account_automated_reporting_ac();

-- XXX - may need to include trigger function
CREATE TRIGGER trig_add_automated_ac_on_account AFTER INSERT OR UPDATE OF account_type, account_role ON account FOR EACH ROW EXECUTE PROCEDURE automated_ac_on_account();

-- XXX - may need to include trigger function
CREATE TRIGGER trigger_delete_peraccount_account_collection BEFORE DELETE ON account FOR EACH ROW EXECUTE PROCEDURE delete_peraccount_account_collection();

-- XXX - may need to include trigger function
-- comes later
-- CREATE TRIGGER trig_rm_account_automated_reporting_ac BEFORE DELETE ON account FOR EACH ROW EXECUTE PROCEDURE account_automated_reporting_ac();

-- XXX - may need to include trigger function
CREATE TRIGGER trigger_create_new_unix_account AFTER INSERT ON account FOR EACH ROW EXECUTE PROCEDURE create_new_unix_account();

-- XXX - may need to include trigger function
CREATE TRIGGER trig_rm_automated_ac_on_account BEFORE DELETE ON account FOR EACH ROW EXECUTE PROCEDURE automated_ac_on_account();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'account');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'account');
ALTER SEQUENCE account_account_id_seq
	 OWNED BY account.account_id;
DROP TABLE IF EXISTS account_v63;
DROP TABLE IF EXISTS audit.account_v63;
-- DONE DEALING WITH TABLE account [6026209]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_device_col_account_cart [6079364]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_col_account_cart', 'v_device_col_account_cart');
CREATE VIEW v_device_col_account_cart AS
 WITH x AS (
         SELECT v_device_col_acct_col_unixlogin.device_collection_id,
            v_device_col_acct_col_unixlogin.account_id,
            NULL::character varying[] AS setting
           FROM v_device_col_acct_col_unixlogin
             JOIN account USING (account_id)
             JOIN account_unix_info USING (account_id)
        UNION
         SELECT v_unix_account_overrides.device_collection_id,
            v_unix_account_overrides.account_id,
            v_unix_account_overrides.setting
           FROM v_unix_account_overrides
             JOIN account USING (account_id)
             JOIN account_unix_info USING (account_id)
             JOIN v_device_col_acct_col_unixlogin USING (device_collection_id, account_id)
        )
 SELECT xx.device_collection_id,
    xx.account_id,
    xx.setting
   FROM ( SELECT x.device_collection_id,
            x.account_id,
            x.setting,
            row_number() OVER (PARTITION BY x.device_collection_id, x.account_id ORDER BY x.setting) AS rn
           FROM x) xx
  WHERE xx.rn = 1;

delete from __recreate where type = 'view' and object = 'v_device_col_account_cart';
-- DONE DEALING WITH TABLE v_device_col_account_cart [6070824]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_device_collection_account_ssh_key [6079349]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_collection_account_ssh_key', 'v_device_collection_account_ssh_key');
CREATE VIEW v_device_collection_account_ssh_key AS
 SELECT allkeys.device_collection_id,
    allkeys.account_id,
    array_agg(allkeys.ssh_public_key) AS ssh_public_key
   FROM ( SELECT keylist.device_collection_id,
            keylist.account_id,
            keylist.ssh_public_key
           FROM ( SELECT dchd.device_collection_id,
                    ac.account_id,
                    ssh_key.ssh_public_key
                   FROM device_collection_ssh_key dcssh
                     JOIN ssh_key USING (ssh_key_id)
                     JOIN v_acct_coll_acct_expanded ac USING (account_collection_id)
                     JOIN account a USING (account_id)
                     JOIN v_device_coll_hier_detail dchd ON dchd.parent_device_collection_id = dcssh.device_collection_id
                UNION
                 SELECT NULL::integer AS device_collection_id,
                    ask.account_id,
                    skey.ssh_public_key
                   FROM account_ssh_key ask
                     JOIN ssh_key skey USING (ssh_key_id)) keylist
          ORDER BY keylist.account_id, COALESCE(keylist.device_collection_id, 0), keylist.ssh_public_key) allkeys
  GROUP BY allkeys.device_collection_id, allkeys.account_id;

delete from __recreate where type = 'view' and object = 'v_device_collection_account_ssh_key';
-- DONE DEALING WITH TABLE v_device_collection_account_ssh_key [6070809]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_unix_passwd_mappings [6054181]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_unix_passwd_mappings', 'v_unix_passwd_mappings');
CREATE VIEW v_unix_passwd_mappings AS
 WITH passtype AS (
         SELECT ap.account_id,
            ap.password,
            ap.expire_time,
            ap.change_time,
            subq.device_collection_id,
            subq.password_type,
            subq.ord
           FROM ( SELECT dchd.device_collection_id,
                    p.property_value_password_type AS password_type,
                    row_number() OVER (PARTITION BY dchd.device_collection_id) AS ord
                   FROM v_property p
                     JOIN v_device_coll_hier_detail dchd ON dchd.parent_device_collection_id = p.device_collection_id
                  WHERE p.property_name::text = 'UnixPwType'::text AND p.property_type::text = 'MclassUnixProp'::text) subq
             JOIN account_password ap USING (password_type)
             JOIN account_unix_info a USING (account_id)
          WHERE subq.ord = 1
        ), accts AS (
         SELECT a.account_id,
            a.login,
            a.person_id,
            a.company_id,
            a.is_enabled,
            a.account_realm_id,
            a.account_status,
            a.account_role,
            a.account_type,
            a.description,
            a.data_ins_user,
            a.data_ins_date,
            a.data_upd_user,
            a.data_upd_date,
            aui.unix_uid,
            aui.unix_group_acct_collection_id,
            aui.shell,
            aui.default_home
           FROM account a
             JOIN account_unix_info aui USING (account_id)
          WHERE a.is_enabled = 'Y'::bpchar
        ), extra_groups AS (
         SELECT p.device_collection_id,
            acae.account_id,
            array_agg(ac.account_collection_name) AS group_names
           FROM v_property p
             JOIN device_collection dc USING (device_collection_id)
             JOIN account_collection ac USING (account_collection_id)
             JOIN account_collection pac ON pac.account_collection_id = p.property_value_account_coll_id
             JOIN v_acct_coll_acct_expanded acae ON pac.account_collection_id = acae.account_collection_id
          WHERE p.property_type::text = 'MclassUnixProp'::text AND p.property_name::text = 'UnixGroupMemberOverride'::text AND dc.device_collection_type::text <> 'mclass'::text
          GROUP BY p.device_collection_id, acae.account_id
        )
 SELECT s.device_collection_id,
    s.account_id,
    s.login,
    s.crypt,
    s.unix_uid,
    s.unix_group_name,
    regexp_replace(s.gecos, ' +'::text, ' '::text, 'g'::text) AS gecos,
    regexp_replace(
        CASE
            WHEN s.forcehome IS NOT NULL AND s.forcehome::text ~ '/$'::text THEN concat(s.forcehome, s.login)
            WHEN s.home IS NOT NULL AND s.home::text ~ '^/'::text THEN s.home::text
            WHEN s.hometype::text = 'generic'::text THEN concat(COALESCE(s.homeplace, '/home'::character varying), '/', 'generic')
            WHEN s.home IS NOT NULL AND s.home::text ~ '/$'::text THEN concat(s.home, '/', s.login)
            WHEN s.homeplace IS NOT NULL AND s.homeplace::text ~ '/$'::text THEN concat(s.homeplace, '/', s.login)
            ELSE concat(COALESCE(s.homeplace, '/home'::character varying), '/', s.login)
        END, '/+'::text, '/'::text, 'g'::text) AS home,
    s.shell,
    s.ssh_public_key,
    s.setting,
    s.mclass_setting,
    s.group_names AS extra_groups
   FROM ( SELECT o.device_collection_id,
            a.account_id,
            a.login,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceCrypt'::text)]::text,
                CASE
                    WHEN pwt.expire_time IS NOT NULL AND now() < pwt.expire_time OR (now() - pwt.change_time) < concat(COALESCE((( SELECT v_property.property_value
                       FROM v_property
                      WHERE v_property.property_type::text = 'Defaults'::text AND v_property.property_name::text = '_maxpasswdlife'::text))::text, 90::text), 'days')::interval THEN pwt.password
                    ELSE NULL::character varying
                END::text, '*'::text) AS crypt,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceUserUID'::text)]::integer, a.unix_uid) AS unix_uid,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceUserGroup'::text)]::character varying(255), ugac.account_collection_name) AS unix_group_name,
                CASE
                    WHEN a.description IS NOT NULL THEN a.description::text
                    ELSE concat(COALESCE(p.preferred_first_name, p.first_name), ' ',
                    CASE
                        WHEN p.middle_name IS NOT NULL AND length(p.middle_name::text) = 1 THEN concat(p.middle_name, '.')::character varying
                        ELSE p.middle_name
                    END, ' ', COALESCE(p.preferred_last_name, p.last_name))
                END AS gecos,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceHome'::text)], a.default_home) AS home,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceShell'::text)], a.shell) AS shell,
            o.setting,
            mcs.mclass_setting,
            o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceHome'::text)] AS forcehome,
            mcs.mclass_setting[( SELECT i.i + 1
                   FROM generate_subscripts(mcs.mclass_setting, 1) i(i)
                  WHERE mcs.mclass_setting[i.i]::text = 'HomePlace'::text)] AS homeplace,
            mcs.mclass_setting[( SELECT i.i + 1
                   FROM generate_subscripts(mcs.mclass_setting, 1) i(i)
                  WHERE mcs.mclass_setting[i.i]::text = 'UnixHomeType'::text)] AS hometype,
            ssh.ssh_public_key,
            extra_groups.group_names
           FROM accts a
             JOIN v_device_col_account_cart o USING (account_id)
             JOIN device_collection dc USING (device_collection_id)
             JOIN person p USING (person_id)
             JOIN unix_group ug ON a.unix_group_acct_collection_id = ug.account_collection_id
             JOIN account_collection ugac ON ugac.account_collection_id = ug.account_collection_id
             LEFT JOIN extra_groups USING (device_collection_id, account_id)
             LEFT JOIN v_device_collection_account_ssh_key ssh ON a.account_id = ssh.account_id AND (ssh.device_collection_id IS NULL OR ssh.device_collection_id = o.device_collection_id)
             LEFT JOIN v_unix_mclass_settings mcs ON mcs.device_collection_id = dc.device_collection_id
             LEFT JOIN passtype pwt ON o.device_collection_id = pwt.device_collection_id AND a.account_id = pwt.account_id) s
  ORDER BY s.device_collection_id, s.account_id;

delete from __recreate where type = 'view' and object = 'v_unix_passwd_mappings';
GRANT INSERT,UPDATE,DELETE ON v_unix_passwd_mappings TO iud_role;
GRANT ALL ON v_unix_passwd_mappings TO jazzhands;
GRANT SELECT ON v_unix_passwd_mappings TO ro_role;
-- DONE DEALING WITH TABLE v_unix_passwd_mappings [6070829]
-------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_unix_group_mappings [6054186]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_unix_group_mappings', 'v_unix_group_mappings');
CREATE VIEW v_unix_group_mappings AS
 WITH accts AS (
         SELECT a_1.account_id,
            a_1.login,
            a_1.person_id,
            a_1.company_id,
            a_1.is_enabled,
            a_1.account_realm_id,
            a_1.account_status,
            a_1.account_role,
            a_1.account_type,
            a_1.description,
            a_1.data_ins_user,
            a_1.data_ins_date,
            a_1.data_upd_user,
            a_1.data_upd_date
           FROM account a_1
             JOIN account_unix_info USING (account_id)
          WHERE a_1.is_enabled = 'Y'::bpchar
        ), ugmap AS (
         SELECT dch.device_collection_id,
            vace.account_collection_id
           FROM v_property p
             JOIN v_device_coll_hier_detail dch ON p.device_collection_id = dch.parent_device_collection_id
             JOIN v_account_collection_expanded vace ON vace.root_account_collection_id = p.account_collection_id
          WHERE p.property_name::text = 'UnixGroup'::text AND p.property_type::text = 'MclassUnixProp'::text
        UNION
         SELECT dch.device_collection_id,
            uag.account_collection_id
           FROM v_property p
             JOIN v_device_coll_hier_detail dch ON p.device_collection_id = dch.parent_device_collection_id
             JOIN v_acct_coll_acct_expanded vace USING (account_collection_id)
             JOIN accts a_1 ON vace.account_id = a_1.account_id
             JOIN account_unix_info aui ON a_1.account_id = aui.account_id
             JOIN unix_group ug ON ug.account_collection_id = aui.unix_group_acct_collection_id
             JOIN account_collection uag ON ug.account_collection_id = uag.account_collection_id
          WHERE p.property_name::text = 'UnixLogin'::text AND p.property_type::text = 'MclassUnixProp'::text
        ), dcugm AS (
         SELECT dch.device_collection_id,
            p.account_collection_id,
            aca.account_id
           FROM v_property p
             JOIN unix_group ug USING (account_collection_id)
             JOIN v_device_coll_hier_detail dch ON p.device_collection_id = dch.parent_device_collection_id
             JOIN v_acct_coll_acct_expanded aca ON p.property_value_account_coll_id = aca.account_collection_id
          WHERE p.property_name::text = 'UnixGroupMemberOverride'::text AND p.property_type::text = 'MclassUnixProp'::text
        ), grp_members AS (
         SELECT actoa.account_id,
            actoa.device_collection_id,
            actoa.account_collection_id,
            ui.unix_uid,
            ui.unix_group_acct_collection_id,
            ui.shell,
            ui.default_home,
            ui.data_ins_user,
            ui.data_ins_date,
            ui.data_upd_user,
            ui.data_upd_date,
            a_1.login,
            a_1.person_id,
            a_1.company_id,
            a_1.is_enabled,
            a_1.account_realm_id,
            a_1.account_status,
            a_1.account_role,
            a_1.account_type,
            a_1.description,
            a_1.data_ins_user,
            a_1.data_ins_date,
            a_1.data_upd_user,
            a_1.data_upd_date
           FROM ( SELECT dc_1.device_collection_id,
                    ae.account_collection_id,
                    ae.account_id
                   FROM device_collection dc_1,
                    v_acct_coll_acct_expanded ae
                     JOIN unix_group unix_group_1 USING (account_collection_id)
                     JOIN account_collection inac USING (account_collection_id)
                  WHERE dc_1.device_collection_type::text = 'mclass'::text
                UNION
                 SELECT dcugm.device_collection_id,
                    dcugm.account_collection_id,
                    dcugm.account_id
                   FROM dcugm) actoa
             JOIN account_unix_info ui USING (account_id)
             JOIN accts a_1 USING (account_id)
        ), grp_accounts AS (
         SELECT g.account_id,
            g.device_collection_id,
            g.account_collection_id,
            g.unix_uid,
            g.unix_group_acct_collection_id,
            g.shell,
            g.default_home,
            g.data_ins_user,
            g.data_ins_date,
            g.data_upd_user,
            g.data_upd_date,
            g.login,
            g.person_id,
            g.company_id,
            g.is_enabled,
            g.account_realm_id,
            g.account_status,
            g.account_role,
            g.account_type,
            g.description,
            g.data_ins_user_1 AS data_ins_user,
            g.data_ins_date_1 AS data_ins_date,
            g.data_upd_user_1 AS data_upd_user,
            g.data_upd_date_1 AS data_upd_date
           FROM grp_members g(account_id, device_collection_id, account_collection_id, unix_uid, unix_group_acct_collection_id, shell, default_home, data_ins_user, data_ins_date, data_upd_user, data_upd_date, login, person_id, company_id, is_enabled, account_realm_id, account_status, account_role, account_type, description, data_ins_user_1, data_ins_date_1, data_upd_user_1, data_upd_date_1)
             JOIN accts USING (account_id)
             JOIN v_unix_passwd_mappings USING (device_collection_id, account_id)
        )
 SELECT dc.device_collection_id,
    ac.account_collection_id,
    ac.account_collection_name AS group_name,
    COALESCE(o.setting[( SELECT i.i + 1
           FROM generate_subscripts(o.setting, 1) i(i)
          WHERE o.setting[i.i]::text = 'ForceGroupGID'::text)]::integer, unix_group.unix_gid) AS unix_gid,
    unix_group.group_password,
    o.setting,
    mcs.mclass_setting,
    array_agg(DISTINCT a.login ORDER BY a.login) AS members
   FROM device_collection dc
     JOIN ugmap USING (device_collection_id)
     JOIN account_collection ac USING (account_collection_id)
     JOIN unix_group USING (account_collection_id)
     LEFT JOIN v_device_col_account_col_cart o USING (device_collection_id, account_collection_id)
     LEFT JOIN grp_accounts a(account_id, device_collection_id, account_collection_id, unix_uid, unix_group_acct_collection_id, shell, default_home, data_ins_user, data_ins_date, data_upd_user, data_upd_date, login, person_id, company_id, is_enabled, account_realm_id, account_status, account_role, account_type, description, data_ins_user_1, data_ins_date_1, data_upd_user_1, data_upd_date_1) USING (device_collection_id, account_collection_id)
     LEFT JOIN v_unix_mclass_settings mcs ON mcs.device_collection_id = dc.device_collection_id
  GROUP BY dc.device_collection_id, ac.account_collection_id, ac.account_collection_name, unix_group.unix_gid, unix_group.group_password, o.setting, mcs.mclass_setting
  ORDER BY dc.device_collection_id, ac.account_collection_id;

delete from __recreate where type = 'view' and object = 'v_unix_group_mappings';
GRANT SELECT ON v_unix_group_mappings TO ro_role;
GRANT ALL ON v_unix_group_mappings TO jazzhands;
GRANT INSERT,UPDATE,DELETE ON v_unix_group_mappings TO iud_role;
-- DONE DEALING WITH TABLE v_unix_group_mappings [6070845]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- BEGIN auto_ac_manip

insert into val_property (
        property_name, property_type,
        permit_account_id,
        permit_account_realm_id,
        property_data_type,
        is_multivalue
) values (
        'AutomatedDirectsAC', 'auto_acct_coll',
        'REQUIRED',
        'REQUIRED',
        'account_collection_id',
        'N'
);

insert into val_property (
        property_name, property_type,
        permit_account_id,
        permit_account_realm_id,
        property_data_type,
        is_multivalue
) values (
        'AutomatedRollupsAC', 'auto_acct_coll',
        'REQUIRED',
        'REQUIRED',
        'account_collection_id',
        'N'
);

/*
 * Copyright (c) 2015 Todd Kover
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * These routines support the management of account collections for people that
 * report to and rollup to a given person.
 *
 * They were written with multiple account_realms in mind, although the triggers
 * only support all this for the default realm as defined by properties, so
 * a multiple realm context is untested.
 *
 * Many of the routines accept optional arguments for various fields.  This is
 * to speed up calling functions so the same queries do not need to be run
 * multiple times.  There is probably room for additional cleverness around
 * all this.  If those values are not specified, then they get looked up.
 *
 * This handles both contractors and employees.  It should probably be
 * tweaked to just handle employees.
 */

/*
 * $Id$
 */

-- Create schema if it does not exist, do nothing otherwise.
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'auto_ac_manip';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS auto_ac_manip;
		CREATE SCHEMA auto_ac_manip AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA auto_ac_manip IS 'part of jazzhands';
	END IF;
END;
$$;

\set ON_ERROR_STOP


--------------------------------------------------------------------------------
-- returns the Id tag for CM
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.id_tag()
RETURNS VARCHAR AS $$
BEGIN
	RETURN('<-- $Id$ -->');
END;
$$ LANGUAGE plpgsql;
-- end of procedure id_tag

--------------------------------------------------------------------------------
--
-- renames a person's magic account collection when login name changes
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.rename_automated_report_acs(
	account_id			account.account_id%TYPE,
	old_login			account.login%TYPE,
	new_login			account.login%TYPE,
	account_realm_id	account.account_realm_id%TYPE
) RETURNS VOID AS $_$
BEGIN
	EXECUTE '
		UPDATE account_collection
		  SET	account_collection_name =
		  			replace(account_collection_name, $6, $7)
		WHERE	account_collection_id IN (
				SELECT property_value_account_coll_id
				FROM	property
				WHERE	property_name IN ($3, $4)
				AND		property_type = $5
				AND		account_id = $1
				AND		account_realm_id = $2
		)' USING	account_id, account_realm_id,
				'AutomatedDirectsAC','AutomatedRollupsAC','auto_acct_coll',
				old_login, new_login;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

--------------------------------------------------------------------------------
--
-- returns the number of direct reports to a person
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.get_num_direct_reports(
	account_id 	account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE
) RETURNS INTEGER AS $_$
DECLARE
	_numrpt	INTEGER;
BEGIN
	-- get number of direct reports
	EXECUTE '
		WITH peeps AS (
			SELECT	account_realm_id, account_id, login, person_id, 
					manager_person_id
			FROM	account a
				INNER JOIN person_company USING (person_id, company_id)
				INNER JOIN val_person_status vps ON
					vps.person_status = a.account_status
			WHERE	account_role = $3
			AND		account_type = ''person''
			AND		person_company_relation = ''employee''
			AND		vps.is_disabled = ''N''
		) SELECT count(*)
		FROM peeps reports
			INNER JOIN peeps managers on  
				managers.person_id = reports.manager_person_id
			AND	managers.account_realm_id = reports.account_realm_id
		WHERE	managers.account_id = $1
		AND		managers.account_realm_id = $2
	' INTO _numrpt USING account_id, account_realm_id, 'primary';

	RETURN _numrpt;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

--------------------------------------------------------------------------------
--
-- returns the number of direct reports that have reports
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.get_num_reports_with_reports(
	account_id 	account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE
) RETURNS INTEGER AS $_$
DECLARE
	_numrlup	INTEGER;
BEGIN
	EXECUTE '
		WITH peeps AS (
			SELECT	account_realm_id, account_id, login, person_id, 
					manager_person_id
			FROM	account a
				INNER JOIN person_company USING (person_id, company_id)
				INNER JOIN val_person_status vps ON
					vps.person_status = a.account_status
			WHERE	account_role = $3
			AND		account_type = ''person''
			AND		person_company_relation = ''employee''
			AND		account_realm_id = $2
			AND		vps.is_disabled = ''N''
		), agg AS ( SELECT reports.*, managers.account_id as manager_account_id,
				managers.login as manager_login, p.property_name,
				p.property_value_account_coll_id as account_collection_id
			FROM peeps reports
			INNER JOIN peeps managers
				ON managers.person_id = reports.manager_person_id
				AND	managers.account_realm_id = reports.account_realm_id
			INNER JOIN property p 
				ON p.account_id = reports.account_id
				AND p.account_realm_id = reports.account_realm_id
				AND p.property_name IN ($4,$5)
				AND p.property_type = $6
		), rank AS (
			SELECT *,
				rank() OVER (partition by account_id ORDER BY property_name desc)
					as rank
			FROM agg
		) SELECT count(*) from rank
		WHERE	manager_account_id =  $1
		AND 	account_realm_id = $2
		AND	rank = 1;
	' INTO _numrlup USING account_id, account_realm_id, 'primary',
				'AutomatedDirectsAC','AutomatedRollupsAC','auto_acct_coll';

	RETURN _numrlup;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;


--------------------------------------------------------------------------------
--
-- returns the automated ac for a given account for a given purpose, creates
-- if necessary.
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.find_or_create_automated_ac(
	account_id 	account.account_id%TYPE,
	ac_type		property.property_name%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE DEFAULT NULL,
	login				account.login%TYPE DEFAULT NULL
)  RETURNS account_collection.account_collection_id%TYPE AS $_$
DECLARE
	_acname		text;
	_acid		account_collection.account_collection_id%TYPE;
BEGIN
	IF login is NULL THEN
		EXECUTE 'SELECT account_realm_id,login 
			FROM account where account_id = $1' 
			INTO account_realm_id,login USING account_id;
	END IF;

	IF ac_type = 'AutomatedDirectsAC' THEN
		_acname := concat(login, '-employee-directs');
	ELSIF ac_type = 'AutomatedRollupsAC' THEN
		_acname := concat(login, '-employee-rollup');
	ELSE
		RAISE EXCEPTION 'Do not know how to name Automated AC type %', ac_type;
	END IF;

	--
	-- Check to see if a -direct account collection exists already.  If not,
	-- create it.  There is a bit of a problem here if the name is not unique
	-- or otherwise messed up.  This will just raise errors.
	--
	EXECUTE 'SELECT ac.account_collection_id
			FROM account_collection ac
				INNER JOIN property p
					ON p.property_value_account_coll_id = ac.account_collection_id
		   WHERE ac.account_collection_name = $1
		    AND	ac.account_collection_type = $2
			AND	p.property_name = $3
			AND p.property_type = $4
			AND p.account_id = $5
			AND p.account_realm_id = $6
		' INTO _acid USING _acname, 'automated',
				ac_type, 'auto_acct_coll', account_id,
				account_realm_id;

	-- Assume the person is always in their own account collection, or if tehy
	-- are not someone took them out for a good reason.  (Thus, they are only
	-- added on creation).
	IF _acid IS NULL THEN
		EXECUTE 'INSERT INTO account_collection (
					account_collection_name, account_collection_type
				) VALUES ( $1, $2) RETURNING *
			' INTO _acid USING _acname, 'automated';

		IF ac_type = 'AutomatedDirectsAC' THEN
			EXECUTE 'INSERT INTO account_collection_account (
						account_collection_id, account_id
					) VALUES (  $1, $2 )
				' USING _acid, account_id;
		END IF;

		EXECUTE '
			INSERT INTO property ( 
				account_id,
				account_realm_id,
				property_name,
				property_type,
				property_value_account_coll_id
			)  VALUES ( $1, $2, $3, $4, $5)'
			USING account_id, account_realm_id,
				ac_type, 'auto_acct_coll', _acid;
	END IF;

	RETURN _acid;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

--------------------------------------------------------------------------------
--
-- Creates the account collection and associated property if it exists,
-- makes sure the membership is what it should be (excluding the account,
-- itself, which may be a mistake -- the assumption is it was removed for a
-- good reason.
--
-- Returns the account_collection_id
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.populate_direct_report_ac(
	account_id 	account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE DEFAULT NULL,
	login				account.login%TYPE DEFAULT NULL
)  RETURNS account_collection.account_collection_id%TYPE AS $_$
DECLARE
	_directac	account_collection.account_collection_id%TYPE;
BEGIN
	_directac := auto_ac_manip.find_or_create_automated_ac(
		account_id := account_id,
		account_realm_id := account_realm_id,
		ac_type := 'AutomatedDirectsAC'
	);

	--
	-- Make membership right
	--
	EXECUTE '
		WITH peeps AS (
			SELECT	account_realm_id, account_id, login, person_id, 
					manager_person_id
			FROM	account a
				INNER JOIN person_company USING (person_id, company_id)
				INNER JOIN val_person_status vps ON
					vps.person_status = a.account_status
			WHERE	account_role = $2
			AND		account_type = ''person''
			AND		person_company_relation = ''employee''
			AND		vps.is_disabled = ''N''
		), arethere AS (
			SELECT account_collection_id, account_id FROM
				account_collection_account
				WHERE account_collection_id = $3
		), shouldbethere AS (
			SELECT $3 as account_collection_id, reports.account_id
			FROM peeps reports
				INNER JOIN peeps managers on  
					managers.person_id = reports.manager_person_id
				AND	managers.account_realm_id = reports.account_realm_id
			WHERE	managers.account_id =  $1
			UNION SELECT $3, $1
		), ins AS (
			INSERT INTO account_collection_account 
				(account_collection_id, account_id)
			SELECT account_collection_id, account_id 
			FROM shouldbethere
			WHERE (account_collection_id, account_id)
				NOT IN (select account_collection_id, account_id FROM arethere)
			RETURNING *
		), del AS (
			DELETE FROM account_collection_account
			WHERE (account_collection_id, account_id)
			IN (
				SELECT account_collection_id, account_id 
				FROM arethere
			) AND (account_collection_id, account_id) NOT IN (
				SELECT account_collection_id, account_id 
				FROM shouldbethere
			) RETURNING *
		) SELECT * from ins UNION SELECT * from del
		'USING account_id, 'primary', _directac;

	RETURN _directac;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

--------------------------------------------------------------------------------
--
-- Creates the account collection and associated property if it exists,
-- makes sure the membership is what it should be .  This does NOT manipulate
-- the -direct account collection at all
--
-- Returns the account_collection_id
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.populate_rollup_report_ac(
	account_id 	account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE DEFAULT NULL,
	login				account.login%TYPE DEFAULT NULL
)  RETURNS account_collection.account_collection_id%TYPE AS $_$
DECLARE
	_rollupac	account_collection.account_collection_id%TYPE;
BEGIN
	_rollupac := auto_ac_manip.find_or_create_automated_ac(
		account_id := account_id,
		account_realm_id := account_realm_id,
		ac_type := 'AutomatedRollupsAC'
	);

	EXECUTE '
		WITH peeps AS (
			SELECT	account_realm_id, account_id, login, person_id, 
					manager_person_id
			FROM	account a
				INNER JOIN person_company USING (person_id, company_id)
				INNER JOIN val_person_status vps
					ON vps.person_status=a.account_status
			WHERE	account_role = $2
			AND		account_type = ''person''
			AND		person_company_relation = ''employee''
			AND		vps.is_disabled = ''N''
		), agg AS ( SELECT reports.*, managers.account_id as manager_account_id,
				managers.login as manager_login, p.property_name,
				p.property_value_account_coll_id as account_collection_id
			FROM peeps reports
			INNER JOIN peeps managers
				ON managers.person_id = reports.manager_person_id
				AND	managers.account_realm_id = reports.account_realm_id
			INNER JOIN property p 
				ON p.account_id = reports.account_id
				AND p.account_realm_id = reports.account_realm_id
				AND p.property_name IN ($3,$4)
				AND p.property_type = $5
		), rank AS (
			SELECT *,
				rank() OVER (partition by account_id ORDER BY property_name desc)
					as rank
			FROM agg
		), shouldbethere AS (
			SELECT $6 as account_collection_id,
					account_collection_id as child_account_collection_id
			FROM rank
	 		WHERE	manager_account_id =  $1
			AND	rank = 1
		), arethere AS (
			SELECT account_collection_id, child_account_collection_id FROM
				account_collection_hier
			WHERE account_collection_id = $6
		), ins AS (
			INSERT INTO account_collection_hier 
				(account_collection_id, child_account_collection_id)
			SELECT account_collection_id, child_account_collection_id
			FROM shouldbethere
			WHERE (account_collection_id, child_account_collection_id)
				NOT IN (SELECT * from arethere)
			RETURNING *
		), del AS (
			DELETE FROM account_collection_hier
			WHERE (account_collection_id, child_account_collection_id)
				IN (SELECT * from arethere)
			AND (account_collection_id, child_account_collection_id)
				NOT IN (SELECT * FROM shouldbethere)
			RETURNING *
		) select * from ins UNION select * from del;

	' USING account_id, 'primary',
				'AutomatedDirectsAC','AutomatedRollupsAC','auto_acct_coll',
				_rollupac;

	RETURN _rollupac;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;


--------------------------------------------------------------------------------
--
-- makes sure that the -direct and -rollup account collections exist for
-- someone that should.  Does not destroy
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.create_report_account_collections(
	account_id 	account.account_id%TYPE,
	account_realm_id	account.account_realm_id%TYPE,
	login				account.login%TYPE,
	numrpt				integer DEFAULT NULL,
	numrlup				integer DEFAULT NULL
)  RETURNS VOID AS $_$
DECLARE
	_account	account%ROWTYPE;
	_directac	account_collection.account_collection_id%TYPE;
	_rollupac	account_collection.account_collection_id%TYPE;
BEGIN
	IF numrpt IS NULL THEN
		numrpt := auto_ac_manip.get_num_direct_reports(account_id, account_realm_id);
	END IF;

	IF numrpt = 0 THEN
		RETURN;
	END IF;

	_directac := auto_ac_manip.populate_direct_report_ac(account_id, account_realm_id, login);

	IF numrlup IS NULL THEN
		numrlup := auto_ac_manip.get_num_reports_with_reports(account_id, account_realm_id);
	END IF;

	IF numrlup = 0 THEN
		RETURN;
	END IF;

	_rollupac := auto_ac_manip.populate_rollup_report_ac(account_id, account_realm_id, login);

	-- add directs to rollup
	EXECUTE 'INSERT INTO account_collection_hier (
			account_collection_id, child_account_collection_id
		) VALUES (
			$1, $2
		)' USING _rollupac, _directac;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

CREATE OR REPLACE FUNCTION auto_ac_manip.purge_report_account_collection(
	account_id 	account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE,
	ac_type		property.property_name%TYPE
) RETURNS VOID AS $_$
BEGIN
	EXECUTE '
		DELETE FROM account_collection_account
		WHERE account_collection_ID IN (
			SELECT	property_value_account_coll_id
			FROM	property
			WHERE	property_name = $3
			AND		property_type = $4
			AND		account_id = $1
			AND		account_realm_id = $2
		)' USING account_id, account_realm_id, ac_type, 'auto_acct_coll';

	EXECUTE '
		WITH p AS (
			SELECT	property_value_account_coll_id AS account_collection_id
			FROM	property
			WHERE	property_name = $3
			AND		property_type = $4
			AND		account_id = $1
			AND		account_realm_id = $2
		)
		DELETE FROM account_collection_hier
		WHERE account_collection_id IN ( select account_collection_id from p)
		OR child_account_collection_id IN 
			( select account_collection_id from p)
		' USING account_id, account_realm_id, ac_type, 'auto_acct_coll';

	EXECUTE '
		WITH list AS (
			SELECT	property_value_account_coll_id as account_collection_id,
					property_id
			FROM	property
			WHERE	property_name = $3
			AND		property_type = $4
			AND		account_id = $1
			AND		account_realm_id = $2
		), props AS (
			DELETE FROM property WHERE property_id IN
				(select property_id FROM list ) RETURNING *
		) DELETE FROM account_collection WHERE account_collection_id IN
				(select property_value_account_coll_id FROM props )
		' USING account_id, account_realm_id, ac_type, 'auto_acct_coll';

END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

--------------------------------------------------------------------------------
--
-- makes sure that the -direct and -rollup account collections do exist for
-- someone if they should not.  Removes if necessary, and also removes them
-- from other account collections.  Arguably should also remove other
-- properties associated but I opted out of that for now. 
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.destroy_report_account_collections(
	account_id 	account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE DEFAULT NULL,
	numrpt				integer DEFAULT NULL,
	numrlup				integer DEFAULT NULL
)  RETURNS VOID AS $_$
DECLARE
	_account	account%ROWTYPE;
	_directac	account_collection.account_collection_id%TYPE;
	_rollupac	account_collection.account_collection_id%TYPE;
BEGIN
	IF account_realm_id IS NULL THEN
		EXECUTE '
			SELECT account_realm_id
			FROM	account
			WHERE	account_id = $1
		' INTO account_realm_id USING account_id;
	END IF;

	IF numrpt IS NULL THEN
		numrpt := auto_ac_manip.get_num_direct_reports(account_id, account_realm_id);
	END IF;
	IF numrpt = 0 THEN
		PERFORM auto_ac_manip.purge_report_account_collection(
			account_id := account_id, 
			account_realm_id := account_realm_id,
			ac_type := 'AutomatedDirectsAC');
		RETURN;
	END IF;

	IF numrlup IS NULL THEN
		numrlup := auto_ac_manip.get_num_reports_with_reports(account_id, account_realm_id);
	END IF;
	IF numrlup = 0 THEN 
		PERFORM auto_ac_manip.purge_report_account_collection(
			account_id := account_id, 
			account_realm_id := account_realm_id,
			ac_type := 'AutomatedDirectsAC');
		RETURN;
	END IF;

END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

--------------------------------------------------------------------------------
--
-- one routine that just goes and fixes all the -direct and -rollup auto
-- account collections to be right.  Note that this just calls other routines
-- and relies on them to decide if things should be purged or not.
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.make_auto_report_acs_right(
	account_id 			account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE DEFAULT NULL,
	login				account.login%TYPE DEFAULT NULL
)  RETURNS VOID AS $_$
DECLARE
	_numrpt	INTEGER;
	_numrlup INTEGER;
BEGIN
	_numrpt := auto_ac_manip.get_num_direct_reports(account_id, account_realm_id);
	_numrlup := auto_ac_manip.get_num_reports_with_reports(account_id, account_realm_id);
	PERFORM auto_ac_manip.destroy_report_account_collections(account_id, account_realm_id, _numrpt, _numrlup);
	PERFORM auto_ac_manip.create_report_account_collections(account_id, account_realm_id, login, _numrpt, _numrlup);
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;


grant usage on schema auto_ac_manip to iud_role;
revoke all on schema auto_ac_manip from public;
revoke all on  all functions in schema auto_ac_manip from public;
grant execute on all functions in schema auto_ac_manip to iud_role;


-- DONE auto_ac_manip
--------------------------------------------------------------------

--------------------------------------------------------------------
-- BEGIN auto account collection triggers

/*
 * Copyright (c) 2015 Todd Kover
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

--
-- Changes to account trigger addition/removal from various things.  This is
-- actually redundant with the second two triggers on person_company and
-- person, which deal with updates.  This covers the case of accounts coming
-- into existance after the rows in person/person_company
--
-- This currently does not move an account out of a "site" class when someone 
-- moves around, which should probably be revisited.
--
CREATE OR REPLACE FUNCTION account_automated_reporting_ac() 
RETURNS TRIGGER AS $_$
DECLARE
	_tally	INTEGER;
	_numrpt	INTEGER;
	_r		RECORD;
BEGIN
	IF TG_OP = 'DELETE' THEN
		IF OLD.account_role != 'primary' THEN
			RETURN OLD;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.account_role != 'primary' AND OLD.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
	END IF;

	-- XXX check account realm to see if we should be inserting for this
	-- XXX account realm

	IF TG_OP = 'INSERT' THEN
		PERFORM auto_ac_manip.create_report_account_collections(
			account_id := NEW.account_id, 
			account_realm_id := NEW.account_realm_id,
			login := NEW.login
		);
	ELSIF TG_OP = 'UPDATE' THEN
		PERFORM auto_ac_manip.rename_automated_report_acs(
			NEW.account_id, OLD.login, NEW.login, NEW.account_realm_id);
	ELSIF TG_OP = 'DELETE' THEN
		PERFORM auto_ac_manip.destroy_report_account_collections(
			account_id := OLD.account_id,
			account_realm_id := OLD.account_realm_id
		);
	END IF;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$_$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trig_add_account_automated_reporting_ac ON account;
CREATE TRIGGER trig_add_account_automated_reporting_ac 
	AFTER INSERT OR UPDATE OF login
	ON account 
	FOR EACH ROW 
	EXECUTE PROCEDURE account_automated_reporting_ac();

DROP TRIGGER IF EXISTS trig_rm_account_automated_reporting_ac ON account;
CREATE TRIGGER trig_rm_account_automated_reporting_ac 
	BEFORE DELETE 
	ON account 
	FOR EACH ROW 
	EXECUTE PROCEDURE account_automated_reporting_ac();

--------------------------------------------------------------------------

--
-- If a person changes managers, and they are in the default account realm
-- rearrange all the automated tiered account collections
--
CREATE OR REPLACE FUNCTION automated_ac_on_person_company() 
RETURNS TRIGGER AS $_$
DECLARE
	_acc	account%ROWTYPE;
BEGIN
	SELECT * INTO _acc 
	FROM account
	WHERE person_id = NEW.person_id
	AND account_role = 'primary'
	AND account_realm_id IN (
		SELECT account_realm_id FROM property 
		WHERE property_name = '_root_account_realm_id'
		AND property_type = 'Defaults'
	);

	IF NOT FOUND THEN
		RETURN NEW;
	END IF;

	SELECT * INTO _acc 
	FROM account
	WHERE person_id = OLD.manager_person_id
	AND account_role = 'primary'
	AND account_realm_id IN (
		SELECT account_realm_id FROM property 
		WHERE property_name = '_root_account_realm_id'
		AND property_type = 'Defaults'
	);
	IF FOUND THEN
		PERFORM auto_ac_manip.make_auto_report_acs_right(_acc.account_id, _acc.account_realm_id, _acc.login);
	END IF;

	SELECT * INTO _acc 
	FROM account
	WHERE person_id = NEW.manager_person_id
	AND account_role = 'primary'
	AND account_realm_id IN (
		SELECT account_realm_id FROM property 
		WHERE property_name = '_root_account_realm_id'
		AND property_type = 'Defaults'
	);
	IF FOUND THEN
		PERFORM auto_ac_manip.make_auto_report_acs_right(_acc.account_id, _acc.account_realm_id, _acc.login);
	END IF;


	RETURN NEW;
END;
$_$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_automated_ac_on_person_company ON person_company;
CREATE TRIGGER trigger_automated_ac_on_person_company 
	AFTER UPDATE OF manager_person_id
	ON person_company 
	FOR EACH ROW EXECUTE PROCEDURE 
	automated_ac_on_person_company();

--------------------------------------------------------------------------
-- DONE auto account collection triggers
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_dev_col_user_prop_expanded [6054191]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dev_col_user_prop_expanded', 'v_dev_col_user_prop_expanded');
CREATE VIEW v_dev_col_user_prop_expanded AS
 SELECT dchd.device_collection_id,
    a.account_id,
    a.login,
    a.account_status,
    ar.account_realm_id,
    ar.account_realm_name,
    a.is_enabled,
    upo.property_type,
    upo.property_name,
    COALESCE(upo.property_value_password_type, upo.property_value) AS property_value,
        CASE
            WHEN upn.is_multivalue = 'N'::bpchar THEN 0
            ELSE 1
        END AS is_multivalue,
        CASE
            WHEN pdt.property_data_type::text = 'boolean'::text THEN 1
            ELSE 0
        END AS is_boolean
   FROM v_acct_coll_acct_expanded_detail uued
     JOIN account_collection u USING (account_collection_id)
     JOIN v_property upo ON upo.account_collection_id = u.account_collection_id AND (upo.property_type::text = ANY (ARRAY['CCAForceCreation'::character varying, 'CCARight'::character varying, 'ConsoleACL'::character varying, 'RADIUS'::character varying, 'TokenMgmt'::character varying, 'UnixPasswdFileValue'::character varying, 'UserMgmt'::character varying, 'cca'::character varying, 'feed-attributes'::character varying, 'wwwgroup'::character varying]::text[]))
     JOIN val_property upn ON upo.property_name::text = upn.property_name::text AND upo.property_type::text = upn.property_type::text
     JOIN val_property_data_type pdt ON upn.property_data_type::text = pdt.property_data_type::text
     JOIN account a ON uued.account_id = a.account_id
     JOIN account_realm ar ON a.account_realm_id = ar.account_realm_id
     LEFT JOIN v_device_coll_hier_detail dchd ON dchd.parent_device_collection_id = upo.device_collection_id
  ORDER BY dchd.device_collection_level,
        CASE
            WHEN u.account_collection_type::text = 'per-account'::text THEN 0
            WHEN u.account_collection_type::text = 'property'::text THEN 1
            WHEN u.account_collection_type::text = 'systems'::text THEN 2
            ELSE 3
        END,
        CASE
            WHEN uued.assign_method = 'Account_CollectionAssignedToPerson'::text THEN 0
            WHEN uued.assign_method = 'Account_CollectionAssignedToDept'::text THEN 1
            WHEN uued.assign_method = 'ParentAccount_CollectionOfAccount_CollectionAssignedToPerson'::text THEN 2
            WHEN uued.assign_method = 'ParentAccount_CollectionOfAccount_CollectionAssignedToDept'::text THEN 2
            WHEN uued.assign_method = 'Account_CollectionAssignedToParentDept'::text THEN 3
            WHEN uued.assign_method = 'ParentAccount_CollectionOfAccount_CollectionAssignedToParentDep'::text THEN 3
            ELSE 6
        END, uued.dept_level, uued.acct_coll_level, dchd.device_collection_id, u.account_collection_id;

delete from __recreate where type = 'view' and object = 'v_dev_col_user_prop_expanded';
GRANT ALL ON v_dev_col_user_prop_expanded TO jazzhands;
GRANT INSERT,UPDATE,DELETE ON v_dev_col_user_prop_expanded TO iud_role;
GRANT SELECT ON v_dev_col_user_prop_expanded TO ro_role;
-- DONE DEALING WITH TABLE v_dev_col_user_prop_expanded [6062243]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_corp_family_account [6082824]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_corp_family_account', 'v_corp_family_account');
CREATE VIEW v_corp_family_account AS
 SELECT a.account_id,
    a.login,
    a.person_id,
    a.company_id,
    a.account_realm_id,
    a.account_status,
    a.account_role,
    a.account_type,
    a.description,
    a.is_enabled,
    a.data_ins_user,
    a.data_ins_date,
    a.data_upd_user,
    a.data_upd_date
   FROM account a
  WHERE (a.account_realm_id IN ( SELECT property.account_realm_id
           FROM property
          WHERE property.property_name::text = '_root_account_realm_id'::text AND property.property_type::text = 'Defaults'::text));

delete from __recreate where type = 'view' and object = 'v_corp_family_account';
GRANT INSERT,UPDATE,DELETE ON v_corp_family_account TO iud_role;
GRANT SELECT ON v_corp_family_account TO ro_role;
GRANT ALL ON v_corp_family_account TO jazzhands;
-- DONE DEALING WITH TABLE v_corp_family_account [6070789]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH SCHEMA lv_manip

--
-- Copyright (c) 2015 Matthew Ragan
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
--

DO $$
DECLARE
        _tal INTEGER;
BEGIN
        select count(*)
        from pg_catalog.pg_namespace
        into _tal
        where nspname = 'lv_manip';
        IF _tal = 0 THEN
                DROP SCHEMA IF EXISTS lv_manip;
                CREATE SCHEMA lv_manip AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA lv_manip IS 'part of jazzhands';
        END IF;
END;
$$;

CREATE OR REPLACE FUNCTION lv_manip.delete_lv_hier(
	physicalish_volume_id	integer DEFAULT NULL,
	volume_group_id			integer DEFAULT NULL,
	logical_volume_id		integer DEFAULT NULL,
	pv_list	OUT integer[],
	vg_list	OUT integer[],
	lv_list	OUT integer[]
) RETURNS RECORD AS $$
DECLARE
	pvid ALIAS FOR physicalish_volume_id;
	vgid ALIAS FOR volume_group_id;
	lvid ALIAS FOR logical_volume_id;
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_pv_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = pvid
			END OR
			CASE WHEN vgid  IS NULL
				THEN false
				ELSE lh.volume_group_id = vgid
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = lvid
			END)
			AND child_pv_id IS NOT NULL
	) INTO pv_list;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_vg_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = pvid
			END OR
			CASE WHEN vgid  IS NULL
				THEN false
				ELSE lh.volume_group_id = vgid
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = lvid
			END)
			AND child_vg_id IS NOT NULL
	) INTO vg_list;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_lv_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = pvid
			END OR
			CASE WHEN vgid  IS NULL
				THEN false
				ELSE lh.volume_group_id = vgid
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = lvid
			END)
			AND child_lv_id IS NOT NULL
	) INTO lv_list;

	DELETE FROM logical_volume WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM volume_group WHERE volume_group_id = ANY(vg_list);
	DELETE FROM physicalish_volume WHERE physicalish_volume_id = ANY(pv_list);
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lv_manip.delete_lv_hier(
	INOUT physicalish_volume_list	integer[] DEFAULT NULL,
	INOUT volume_group_list		integer[] DEFAULT NULL,
	INOUT logical_volume_list		integer[] DEFAULT NULL
) RETURNS RECORD AS $$
DECLARE
	pv_list	integer[];
	vg_list	integer[];
	lv_list	integer[];
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_pv_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = ANY (physical_volume_list)
			END OR
			CASE WHEN vgid  IS NULL
				THEN false
				ELSE lh.volume_group_id = ANY (volume_group_list)
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = ANY (logical_volume_list)
			END)
			AND child_pv_id IS NOT NULL
	) INTO pv_list;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_vg_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = ANY (physicalish_volume_list)
			END OR
			CASE WHEN vgid  IS NULL
				THEN false
				ELSE lh.volume_group_id = ANY (volume_group_list)
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = ANY (logical_volume_list)
			END)
			AND child_vg_id IS NOT NULL
	) INTO vg_list;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_lv_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = ANY (physicalish_volume_list)
			END OR
			CASE WHEN vgid  IS NULL
				THEN false
				ELSE lh.volume_group_id = ANY (volume_group_list)
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = ANY (logical_volume_list)
			END)
			AND child_lv_id IS NOT NULL
	) INTO lv_list;

	DELETE FROM logical_volume WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM volume_group WHERE volume_group_id = ANY(vg_list);
	DELETE FROM physicalish_volume WHERE physicalish_volume_id = ANY(pv_list);

	physicalish_volume_list := pv_list;
	volume_group_list := vg_list;
	logical_volume_list := lv_list;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql;

--
-- This needs to be done recursively because lower level volume groups may
-- contain physicalish volumes that are not from this hierarchy
--
CREATE OR REPLACE FUNCTION lv_manip.delete_pv(
	physicalish_volume_list	integer[],
	purge_orphans			boolean DEFAULT false
) RETURNS VOID AS $$
DECLARE
	pvid integer;
	vgid integer;
BEGIN
	PERFORM * FROM lv_manip.remove_pv_membership(
		physicalish_volume_list,
		purge_orphans
	);

	DELETE FROM physicalish_volume WHERE
		physicalish_volume_id = ANY(physicalish_volume_list);
END;
$$
SET search_path = jazzhands
LANGUAGE plpgsql;

--
-- This needs to be done recursively because lower level volume groups may
-- contain physicalish volumes that are not from this hierarchy
--
CREATE OR REPLACE FUNCTION lv_manip.remove_pv_membership(
	physicalish_volume_list	integer[],
	purge_orphans			boolean DEFAULT false
) RETURNS VOID AS $$
DECLARE
	pvid integer;
	vgid integer;
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	FOREACH pvid IN ARRAY physicalish_volume_list LOOP
		DELETE FROM 
			volume_group_physicalish_vol vgpv
		WHERE
			vgpv.physicalish_volume_id = pvid
		RETURNING
			volume_group_id INTO vgid;
		
		IF FOUND AND purge_orphans THEN
			PERFORM * FROM
				volume_group_physicalish_vol vgpv
			WHERE
				volume_group_id = vgid;

			IF NOT FOUND THEN
				PERFORM lv_manip.delete_vg(
					volume_group_id := vgid,
					purge_orphans := purge_orphans
				);
			END IF;
		END IF;

	END LOOP;
END;
$$
SET search_path = jazzhands
LANGUAGE plpgsql;


SELECT schema_support.save_grants_for_replay('lv_manip', 'delete_vg');
SELECT schema_support.retrieve_functions('lv_manip', 'delete_vg', true);
CREATE OR REPLACE FUNCTION lv_manip.delete_vg(
	volume_group_id	integer,
	purge_orphans boolean DEFAULT false
) RETURNS VOID AS $$
DECLARE
	lvids	integer[];
BEGIN
	PERFORM lv_manip.delete_vg(
		volume_group_list := ARRAY [ volume_group_id ],
		purge_orphans := purge_orphans
	);
END;
$$
SET search_path = jazzhands
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lv_manip.delete_vg(
	volume_group_list	integer[],
	purge_orphans boolean DEFAULT false
) RETURNS VOID AS $$
DECLARE
	lvids	integer[];
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	SELECT ARRAY(
		SELECT
			logical_volume_id
		FROM
			logical_volume lv
		WHERE
			lv.volume_group_id = ANY(volume_group_list)
	) INTO lvids;

	PERFORM lv_manip.delete_pv(
		physicalish_volume_list := (
			SELECT ARRAY (SELECT
				physicalish_volume_id
			FROM
				physicalish_volume
			WHERE
				logical_volume_id = ANY(lvids)
		)),
		purge_orphans := purge_orphans
	);

	DELETE FROM
		volume_group_physicalish_vol vgpv
	WHERE
		vgpv.volume_group_id = ANY(volume_group_list);
	
	DELETE FROM
		volume_group vg
	WHERE
		vg.volume_group_id = ANY(volume_group_list);

	DELETE FROM
		logical_volume
	WHERE
		logical_volume_id = ANY(lvids);
	
	DELETE FROM
		volume_group vg
	WHERE
		vg.volume_group_id = ANY(volume_group_list);
END;
$$
SET search_path = jazzhands
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lv_manip.delete_lv(
	logical_volume_id	integer,
	purge_orphans boolean DEFAULT false
) RETURNS VOID AS $$
BEGIN
	PERFORM lv_manip.delete_lv(
		logical_volume_list := ARRAY [ logical_volume_id ],
		purge_orphans := purge_orphans
	);
END;
$$
SET search_path = jazzhands
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lv_manip.delete_lv(
	logical_volume_list	integer[],
	purge_orphans boolean DEFAULT false
) RETURNS VOID AS $$
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	PERFORM lv_manip.delete_pv(
		physicalish_volume_list := (
			SELECT ARRAY (SELECT
				physicalish_volume_id
			FROM
				physicalish_volume pv
			WHERE
				pv.logical_volume_id = ANY(logical_volume_list)
		)),
		purge_orphans := purge_orphans
	);

	DELETE FROM
		logical_volume_property lvp
	WHERE
		lvp.logical_volume_id = ANY(logical_volume_list);
	
	DELETE FROM
		logical_volume_purpose lvp
	WHERE
		lvp.logical_volume_id = ANY(logical_volume_list);
	
	DELETE FROM
		logical_volume lv
	WHERE
		lv.logical_volume_id = ANY(logical_volume_list);
END;
$$
SET search_path = jazzhands
LANGUAGE plpgsql;

GRANT USAGE ON SCHEMA lv_manip TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA lv_manip TO ro_role;

-- DONE DEALING WITH SCHEMA lv_manip
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE volume_group_physicalish_vol [6542038]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'volume_group_physicalish_vol', 'volume_group_physicalish_vol');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_vgp_phy_phyid;
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_physvol_vg_phsvol_dvid;
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_vg_physvol_vgrel;
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_vgp_phy_vgrpid_devid;
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_vgp_phy_vgrpid;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'volume_group_physicalish_vol');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS pk_volume_group_physicalish_vo;
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS ak_volgrp_pv_position;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_physvol_vg_phsvol_dvid";
DROP INDEX IF EXISTS "jazzhands"."xif_vgp_phy_phyid";
DROP INDEX IF EXISTS "jazzhands"."xif_vgp_phy_vgrpid";
DROP INDEX IF EXISTS "jazzhands"."xif_vgp_phy_vgrpid_devid";
DROP INDEX IF EXISTS "jazzhands"."xif_vg_physvol_vgrel";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_audit_volume_group_physicalish_vol ON jazzhands.volume_group_physicalish_vol;
DROP TRIGGER IF EXISTS trig_userlog_volume_group_physicalish_vol ON jazzhands.volume_group_physicalish_vol;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'volume_group_physicalish_vol');
---- BEGIN audit.volume_group_physicalish_vol TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'volume_group_physicalish_vol', 'volume_group_physicalish_vol');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'volume_group_physicalish_vol');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."volume_group_physicalish_vol_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'volume_group_physicalish_vol');
---- DONE audit.volume_group_physicalish_vol TEARDOWN


ALTER TABLE volume_group_physicalish_vol RENAME TO volume_group_physicalish_vol_v63;
ALTER TABLE audit.volume_group_physicalish_vol RENAME TO volume_group_physicalish_vol_v63;

CREATE TABLE volume_group_physicalish_vol
(
	physicalish_volume_id	integer NOT NULL,
	volume_group_id	integer NOT NULL,
	device_id	integer  NULL,
	volume_group_position	integer  NULL,
	volume_group_relation	varchar(50) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'volume_group_physicalish_vol', false);
INSERT INTO volume_group_physicalish_vol (
	physicalish_volume_id,
	volume_group_id,
	device_id,
	volume_group_position,
	volume_group_relation,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	physicalish_volume_id,
	volume_group_id,
	device_id,
	volume_group_position,
	volume_group_relation,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM volume_group_physicalish_vol_v63;

INSERT INTO audit.volume_group_physicalish_vol (
	physicalish_volume_id,
	volume_group_id,
	device_id,
	volume_group_position,
	volume_group_relation,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	physicalish_volume_id,
	volume_group_id,
	device_id,
	volume_group_position,
	volume_group_relation,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.volume_group_physicalish_vol_v63;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE volume_group_physicalish_vol ADD CONSTRAINT uq_volgrp_pv_position UNIQUE (volume_group_id, volume_group_position) DEFERRABLE;
ALTER TABLE volume_group_physicalish_vol ADD CONSTRAINT pk_volume_group_physicalish_vo PRIMARY KEY (physicalish_volume_id, volume_group_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_vgp_phy_phyid ON volume_group_physicalish_vol USING btree (physicalish_volume_id);
CREATE INDEX xif_physvol_vg_phsvol_dvid ON volume_group_physicalish_vol USING btree (physicalish_volume_id, device_id);
CREATE INDEX xiq_volgrp_pv_position ON volume_group_physicalish_vol USING btree (volume_group_id, volume_group_position);
CREATE INDEX xif_vgp_phy_vgrpid_devid ON volume_group_physicalish_vol USING btree (device_id, volume_group_id);
CREATE INDEX xif_vg_physvol_vgrel ON volume_group_physicalish_vol USING btree (volume_group_relation);
CREATE INDEX xif_vgp_phy_vgrpid ON volume_group_physicalish_vol USING btree (volume_group_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK volume_group_physicalish_vol and val_volume_group_relation
-- Skipping this FK since table does not exist yet
--ALTER TABLE volume_group_physicalish_vol
--	ADD CONSTRAINT fk_vg_physvol_vgrel
--	FOREIGN KEY (volume_group_relation) REFERENCES val_volume_group_relation(volume_group_relation) DEFERRABLE;

-- consider FK volume_group_physicalish_vol and volume_group
-- Skipping this FK since table does not exist yet
--ALTER TABLE volume_group_physicalish_vol
--	ADD CONSTRAINT fk_vgp_phy_vgrpid_devid
--	FOREIGN KEY (volume_group_id, device_id) REFERENCES volume_group(volume_group_id, device_id) DEFERRABLE;

-- consider FK volume_group_physicalish_vol and volume_group
-- Skipping this FK since table does not exist yet
--ALTER TABLE volume_group_physicalish_vol
--	ADD CONSTRAINT fk_vgp_phy_vgrpid
--	FOREIGN KEY (volume_group_id) REFERENCES volume_group(volume_group_id) DEFERRABLE;

-- consider FK volume_group_physicalish_vol and physicalish_volume
-- Skipping this FK since table does not exist yet
--ALTER TABLE volume_group_physicalish_vol
--	ADD CONSTRAINT fk_physvol_vg_phsvol_dvid
--	FOREIGN KEY (physicalish_volume_id, device_id) REFERENCES physicalish_volume(physicalish_volume_id, device_id) DEFERRABLE;

-- consider FK volume_group_physicalish_vol and physicalish_volume
-- Skipping this FK since table does not exist yet
--ALTER TABLE volume_group_physicalish_vol
--	ADD CONSTRAINT fk_vgp_phy_phyid
--	FOREIGN KEY (physicalish_volume_id) REFERENCES physicalish_volume(physicalish_volume_id) DEFERRABLE;


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'volume_group_physicalish_vol');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'volume_group_physicalish_vol');
DROP TABLE IF EXISTS volume_group_physicalish_vol_v63;
DROP TABLE IF EXISTS audit.volume_group_physicalish_vol_v63;
-- DONE DEALING WITH TABLE volume_group_physicalish_vol [6533530]
--------------------------------------------------------------------

--
-- Copyright (c) 2015 Matthew Ragan
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
--
CREATE OR REPLACE VIEW jazzhands.v_component_hier (
	component_id,
	child_component_id,
	component_path,
	level
	) AS
WITH RECURSIVE component_hier (
		component_id,
		child_component_id,
		slot_id,
		component_path
) AS (
	SELECT
		c.component_id, 
		c.component_id, 
		s.slot_id,
		ARRAY[c.component_id]::integer[]
	FROM
		component c LEFT JOIN
		slot s USING (component_id)
	UNION
	SELECT
		p.component_id,
		c.component_id,
		s.slot_id,
		array_prepend(c.component_id, p.component_path)
	FROM
		component_hier p JOIN
		component c ON (p.slot_id = c.parent_slot_id) LEFT JOIN
		slot s ON (s.component_id = c.component_id)
)
SELECT DISTINCT component_id, child_component_id, component_path, array_length(component_path, 1) FROM component_hier;

-- Dropping obsoleted sequences....
-- Dropping obsoleted audit sequences....

-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
ALTER TABLE logical_volume DROP CONSTRAINT IF EXISTS fk_logvol_device_id;
ALTER TABLE logical_volume
   ADD CONSTRAINT fk_logvol_device_id
   FOREIGN KEY (device_id) REFERENCES device(device_id) DEFERRABLE;

ALTER TABLE logical_volume DROP CONSTRAINT IF EXISTS fk_logvol_fstype;
ALTER TABLE logical_volume
   ADD CONSTRAINT fk_logvol_fstype
   FOREIGN KEY (filesystem_type) REFERENCES val_filesystem_type(filesystem_type) DEFERRABLE;

ALTER TABLE logical_volume DROP CONSTRAINT IF EXISTS fk_logvol_vgid;
ALTER TABLE logical_volume
   ADD CONSTRAINT fk_logvol_vgid
   FOREIGN KEY (volume_group_id, device_id) REFERENCES volume_group(volume_group_id, device_id) DEFERRABLE;

ALTER TABLE logical_volume_property DROP CONSTRAINT IF EXISTS fk_lvol_prop_lvid_fstyp;
ALTER TABLE logical_volume_property
   ADD CONSTRAINT fk_lvol_prop_lvid_fstyp
   FOREIGN KEY (logical_volume_id, filesystem_type) REFERENCES logical_volume(logical_volume_id, filesystem_type) DEFERRABLE;

ALTER TABLE logical_volume_property DROP CONSTRAINT IF EXISTS fk_lvol_prop_lvpn_fsty;
ALTER TABLE logical_volume_property
   ADD CONSTRAINT fk_lvol_prop_lvpn_fsty
   FOREIGN KEY (logical_volume_property_name, filesystem_type) REFERENCES val_logical_volume_property(logical_volume_property_name, filesystem_type) DEFERRABLE;

ALTER TABLE logical_volume_purpose DROP CONSTRAINT IF EXISTS fk_lvpurp_lvid;
ALTER TABLE logical_volume_purpose
   ADD CONSTRAINT fk_lvpurp_lvid
   FOREIGN KEY (logical_volume_id) REFERENCES logical_volume(logical_volume_id) DEFERRABLE;

ALTER TABLE logical_volume_purpose DROP CONSTRAINT IF EXISTS fk_lvpurp_val_lgpuprp;
ALTER TABLE logical_volume_purpose
   ADD CONSTRAINT fk_lvpurp_val_lgpuprp
   FOREIGN KEY (logical_volume_purpose) REFERENCES val_logical_volume_purpose(logical_volume_purpose) DEFERRABLE;

ALTER TABLE physicalish_volume DROP CONSTRAINT IF EXISTS fk_physicalish_vol_pvtype;
ALTER TABLE physicalish_volume
   ADD CONSTRAINT fk_physicalish_vol_pvtype
   FOREIGN KEY (physicalish_volume_type) REFERENCES val_physicalish_volume_type(physicalish_volume_type);

ALTER TABLE physicalish_volume DROP CONSTRAINT IF EXISTS fk_physvol_compid;
ALTER TABLE physicalish_volume
   ADD CONSTRAINT fk_physvol_compid
   FOREIGN KEY (component_id) REFERENCES component(component_id) DEFERRABLE;

ALTER TABLE physicalish_volume DROP CONSTRAINT IF EXISTS fk_physvol_device_id;
ALTER TABLE physicalish_volume
   ADD CONSTRAINT fk_physvol_device_id
   FOREIGN KEY (device_id) REFERENCES device(device_id) DEFERRABLE;

ALTER TABLE physicalish_volume DROP CONSTRAINT IF EXISTS fk_physvol_lvid;
ALTER TABLE physicalish_volume
   ADD CONSTRAINT fk_physvol_lvid
   FOREIGN KEY (logical_volume_id) REFERENCES logical_volume(logical_volume_id) DEFERRABLE;

ALTER TABLE volume_group DROP CONSTRAINT IF EXISTS fk_volgrp_devid;
ALTER TABLE volume_group
   ADD CONSTRAINT fk_volgrp_devid
   FOREIGN KEY (device_id) REFERENCES device(device_id) DEFERRABLE;

ALTER TABLE volume_group DROP CONSTRAINT IF EXISTS fk_volgrp_rd_type;
ALTER TABLE volume_group
   ADD CONSTRAINT fk_volgrp_rd_type
   FOREIGN KEY (raid_type) REFERENCES val_raid_type(raid_type) DEFERRABLE;

ALTER TABLE volume_group DROP CONSTRAINT IF EXISTS fk_volgrp_volgrp_type;
ALTER TABLE volume_group
   ADD CONSTRAINT fk_volgrp_volgrp_type
   FOREIGN KEY (volume_group_type) REFERENCES val_volume_group_type(volume_group_type) DEFERRABLE;

ALTER TABLE volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_physvol_vg_phsvol_dvid;
ALTER TABLE volume_group_physicalish_vol
   ADD CONSTRAINT fk_physvol_vg_phsvol_dvid
   FOREIGN KEY (physicalish_volume_id, device_id) REFERENCES physicalish_volume(physicalish_volume_id, device_id) DEFERRABLE;

ALTER TABLE volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_vg_physvol_vgrel;
ALTER TABLE volume_group_physicalish_vol
	ADD CONSTRAINT fk_vg_physvol_vgrel
	FOREIGN KEY (volume_group_relation) REFERENCES val_volume_group_relation(volume_group_relation) DEFERRABLE;

ALTER TABLE volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_vgp_phy_phyid;
ALTER TABLE volume_group_physicalish_vol
	ADD CONSTRAINT fk_vgp_phy_phyid
	FOREIGN KEY (physicalish_volume_id) REFERENCES physicalish_volume(physicalish_volume_id) DEFERRABLE;

ALTER TABLE volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_vgp_phy_vgrpid;
ALTER TABLE volume_group_physicalish_vol
	ADD CONSTRAINT fk_vgp_phy_vgrpid
	FOREIGN KEY (volume_group_id) REFERENCES volume_group(volume_group_id) DEFERRABLE;

ALTER TABLE volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_vgp_phy_vgrpid_devid;
ALTER TABLE volume_group_physicalish_vol
	ADD CONSTRAINT fk_vgp_phy_vgrpid_devid
	FOREIGN KEY (volume_group_id, device_id) REFERENCES volume_group(volume_group_id, device_id) DEFERRABLE;

ALTER TABLE volume_group_purpose DROP CONSTRAINT IF EXISTS fk_val_volgrp_purp_vgid;
ALTER TABLE volume_group_purpose
	ADD CONSTRAINT fk_val_volgrp_purp_vgid
	FOREIGN KEY (volume_group_id) REFERENCES volume_group(volume_group_id) DEFERRABLE;

ALTER TABLE volume_group_purpose DROP CONSTRAINT IF EXISTS fk_val_volgrp_purp_vgpurp;
ALTER TABLE volume_group_purpose
	ADD CONSTRAINT fk_val_volgrp_purp_vgpurp
	FOREIGN KEY (volume_group_purpose) REFERENCES val_volume_group_purpose(volume_group_purpose) DEFERRABLE;

ALTER TABLE PHYSICALISH_VOLUME DROP CONSTRAINT IF EXISTS FK_PHYSICALISH_VOL_PVTYPE;
ALTER TABLE PHYSICALISH_VOLUME 
	ADD CONSTRAINT FK_PHYSICALISH_VOL_PVTYPE 
	FOREIGN KEY (PHYSICALISH_VOLUME_TYPE) REFERENCES VAL_PHYSICALISH_VOLUME_TYPE (PHYSICALISH_VOLUME_TYPE) DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE physicalish_volume DROP CONSTRAINT IF EXISTS ak_physvolname_type_devid;
ALTER TABLE ONLY physicalish_volume
	ADD CONSTRAINT ak_physvolname_type_devid 
	UNIQUE (device_id, physicalish_volume_name, physicalish_volume_type);

GRANT USAGE ON SCHEMA snapshot_manip TO iud_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA snapshot_manip TO iud_role;

-- rename weird seuqnce names to make them right if needed
DO $$
DECLARE
	_tally	integer;
BEGIN
	SELECT count(*) 
	INTO _tally
	FROM pg_class c
		INNER JOIN pg_namespace n ON n.oid = c.relnamespace
	WHERE c.relname = 'logical_volume_prop_logical_volume_prop_id_seq'
	AND  c.relkind = 'S'
	AND n.nspname = 'jazzhands';

	IF _tally > 0 THEN
		ALTER SEQUENCE logical_volume_prop_logical_volume_prop_id_seq
			RENAME TO
			logical_volume_property_logical_volume_property_id_seq;
		ALTER TABLE logical_volume_property
			ALTER logical_volume_property_id
			SET DEFAULT
			nextval('logical_volume_property_logical_volume_property_id_seq');
		ALTER SEQUENCE 
			logical_volume_property_logical_volume_property_id_seq
	 		OWNED BY 
			logical_volume_property.logical_volume_property_id;
	END IF;
END;
$$;

DROP SEQUENCE IF EXISTS logical_vol_prop_logical_vol_prop_id_seq;

-- make logical_volume_property.logical_volume_property_id a serial if it is not
-- already.
DO $$
DECLARE
	_tally	integer;
BEGIN
	SELECT count(*) 
	INTO _tally
	FROM pg_class c
		INNER JOIN pg_namespace n ON n.oid = c.relnamespace
	WHERE c.relname = 'logical_volume_property_logical_volume_property_id_seq'
	AND  c.relkind = 'S'
	AND n.nspname = 'jazzhands';

	IF _tally = 0 THEN
		CREATE SEQUENCE 
			logical_volume_property_logical_volume_property_id_seq;
		ALTER TABLE logical_volume_property
			ALTER logical_volume_property_id
			SET DEFAULT
			nextval('logical_volume_property_logical_volume_property_id_seq');
		ALTER SEQUENCE 
			logical_volume_property_logical_volume_property_id_seq
	 		OWNED BY 
			logical_volume_property.logical_volume_property_id;
	END IF;
END;
$$;

-- slot changes
ALTER TABLE slot ALTER slot_side drop default;
ALTER TABLE slot ALTER slot_side drop not null;

drop trigger IF EXISTS trig_userlog_token_sequence on token_sequence;
drop trigger IF EXISTS trigger_audit_token_sequence on token_sequence;

ALTER FUNCTION dns_utils.add_domains_from_netblock(integer) SECURITY DEFINER;

SELECT timeofday();
-- Clean Up
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_saved_grants();

GRANT select on all tables in schema jazzhands to ro_role;
GRANT insert,update,delete on all tables in schema jazzhands to iud_role;
GRANT select on all sequences in schema jazzhands to ro_role;
GRANT usage on all sequences in schema jazzhands to iud_role;
GRANT select on all tables in schema audit to ro_role;
GRANT select on all sequences in schema audit to ro_role;

SELECT timeofday();

-- update all the auto account collections for people that already exist
WITH dudes AS (
	SELECT	DISTINCT level, a.login, a.person_id, a.account_id,
		a.account_realm_id
	from	v_person_company_hier pc
		INNER JOIN v_corp_family_account a USING (person_id)
	where	is_enabled = 'Y'
	and	account_role = 'primary'
	and	account_type = 'person'
), sorted AS (
	SELECT	d.*,
		rank() OVER (partition by account_id ORDER BY level desc) as r
	FROM dudes d
), last AS (
	select * from sorted where r =1
), preped AS (
	SELECT * from last ORDER BY level , login
), work AS (
select *,
	auto_ac_manip.make_auto_report_acs_right(
		account_id,
		account_realm_id,
		login) 
from preped
) select count(*) from work;
SELECT timeofday();

SELECT schema_support.end_maintenance();
SELECT timeofday();
