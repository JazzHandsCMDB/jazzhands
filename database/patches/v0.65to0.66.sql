/*
Invoked:

	--scan-tables
	--suffix=v65
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance();
select timeofday(), now();
--
-- Process middle (non-trigger) schema jazzhands
--
--
-- Process middle (non-trigger) schema net_manip
--
--
-- Process middle (non-trigger) schema network_strings
--
--
-- Process middle (non-trigger) schema time_util
--
--
-- Process middle (non-trigger) schema dns_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('dns_utils', 'add_domains_from_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS dns_utils.add_domains_from_netblock ( netblock_id integer );
CREATE OR REPLACE FUNCTION dns_utils.add_domains_from_netblock(netblock_id integer)
 RETURNS TABLE(dns_domain_id integer, soa_name text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	block		inet;
	domain		text;
	domain_id	dns_domain.dns_domain_id%TYPE;
	nid			ALIAS FOR netblock_id;
BEGIN
	SELECT ip_address INTO block FROM netblock n WHERE n.netblock_id = nid; 

	RAISE DEBUG 'Creating inverse DNS zones for %s', block;

	RETURN QUERY SELECT
		dns_utils.add_dns_domain(
			soa_name := x.soa_name,
			dns_domain_type := 'reverse'
			),
		x.soa_name::text
	FROM
		dns_utils.get_all_domain_rows_for_cidr(block) x LEFT JOIN
		dns_domain d USING (soa_name)
	WHERE
		d.dns_domain_id IS NULL;

END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION dns_utils.find_dns_domain(fqdn text)
 RETURNS TABLE(dns_name text, soa_name text, dns_domain_id integer)
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF fqdn !~ '^[^.][a-zA-Z0-9_.-]+[^.]$' THEN
		RAISE EXCEPTION '% is not a valid DNS name', fqdn;
	END IF;

	RETURN QUERY SELECT 
		regexp_replace(fqdn, '.' || dd.soa_name || '$', '')::text,
		dd.soa_name::text,
		dd.dns_domain_id
	FROM
		dns_domain dd
	WHERE
		fqdn LIKE ('%.' || dd.soa_name)
	ORDER BY
		length(dd.soa_name) DESC
	LIMIT 1;

	RETURN;
END;
$function$
;

--
-- Process middle (non-trigger) schema person_manip
--
--
-- Process middle (non-trigger) schema auto_ac_manip
--
--
-- Process middle (non-trigger) schema company_manip
--
--
-- Process middle (non-trigger) schema port_support
--
--
-- Process middle (non-trigger) schema port_utils
--
--
-- Process middle (non-trigger) schema device_utils
--
--
-- Process middle (non-trigger) schema netblock_utils
--
--
-- Process middle (non-trigger) schema netblock_manip
--
--
-- Process middle (non-trigger) schema physical_address_utils
--
--
-- Process middle (non-trigger) schema component_utils
--
--
-- Process middle (non-trigger) schema snapshot_manip
--
--
-- Process middle (non-trigger) schema lv_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('lv_manip', 'delete_lv_hier');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.delete_lv_hier ( INOUT physicalish_volume_list integer[], INOUT volume_group_list integer[], INOUT logical_volume_list integer[] );
CREATE OR REPLACE FUNCTION lv_manip.delete_lv_hier(INOUT physicalish_volume_list integer[] DEFAULT NULL::integer[], INOUT volume_group_list integer[] DEFAULT NULL::integer[], INOUT logical_volume_list integer[] DEFAULT NULL::integer[])
 RETURNS record
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
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
			(CASE WHEN physicalish_volume_list IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = ANY (physical_volume_list)
			END OR
			CASE WHEN volume_group_list  IS NULL
				THEN false
				ELSE lh.volume_group_id = ANY (volume_group_list)
			END OR
			CASE WHEN logical_volume_list IS NULL
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
			(CASE WHEN pv_list IS NULL
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

	DELETE FROM logical_volume_property WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume_purpose WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM volume_group WHERE volume_group_id = ANY(vg_list);
	DELETE FROM physicalish_volume WHERE physicalish_volume_id = ANY(pv_list);

	physicalish_volume_list := pv_list;
	volume_group_list := vg_list;
	logical_volume_list := lv_list;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('lv_manip', 'delete_lv_hier');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.delete_lv_hier ( physicalish_volume_id integer, volume_group_id integer, logical_volume_id integer, OUT pv_list integer[], OUT vg_list integer[], OUT lv_list integer[] );
CREATE OR REPLACE FUNCTION lv_manip.delete_lv_hier(physicalish_volume_id integer DEFAULT NULL::integer, volume_group_id integer DEFAULT NULL::integer, logical_volume_id integer DEFAULT NULL::integer, OUT pv_list integer[], OUT vg_list integer[], OUT lv_list integer[])
 RETURNS record
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
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

	DELETE FROM logical_volume_property WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume_purpose WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM volume_group_purpose WHERE volume_group_id = ANY(vg_list);
	DELETE FROM volume_group WHERE volume_group_id = ANY(vg_list);
	DELETE FROM physicalish_volume WHERE physicalish_volume_id = ANY(pv_list);
END;
$function$
;

--
-- Process middle (non-trigger) schema schema_support
--
--
-- Process middle (non-trigger) schema approval_utils
--
-- Creating new sequences....
CREATE SEQUENCE approval_instance_step_notify_approv_instance_step_notify_i_seq;


--------------------------------------------------------------------
-- DEALING WITH TABLE val_person_company_attr_name [4479430]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_person_company_attr_name', 'val_person_company_attr_name');

-- FOREIGN KEYS FROM
ALTER TABLE val_person_company_attr_value DROP CONSTRAINT IF EXISTS fk_pers_comp_attr_val_name;
ALTER TABLE person_company_attr DROP CONSTRAINT IF EXISTS fk_person_comp_attr_val_name;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.val_person_company_attr_name DROP CONSTRAINT IF EXISTS fk_prescompattr_name_datatyp;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_person_company_attr_name');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_person_company_attr_name DROP CONSTRAINT IF EXISTS pk_val_person_company_attr_nam;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xifprescompattr_name_datatyp";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_person_company_attr_name ON jazzhands.val_person_company_attr_name;
DROP TRIGGER IF EXISTS trigger_audit_val_person_company_attr_name ON jazzhands.val_person_company_attr_name;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_person_company_attr_name');
---- BEGIN audit.val_person_company_attr_name TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_person_company_attr_name', 'val_person_company_attr_name');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_person_company_attr_name');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_person_company_attr_name_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_person_company_attr_name');
---- DONE audit.val_person_company_attr_name TEARDOWN


ALTER TABLE val_person_company_attr_name RENAME TO val_person_company_attr_name_v65;
ALTER TABLE audit.val_person_company_attr_name RENAME TO val_person_company_attr_name_v65;

CREATE TABLE val_person_company_attr_name
(
	person_company_attr_name	varchar(50) NOT NULL,
	person_company_attr_data_type	varchar(50)  NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_person_company_attr_name', false);
INSERT INTO val_person_company_attr_name (
	person_company_attr_name,
	person_company_attr_data_type,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	person_company_attr_name,
	person_company_attr_data_type,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_person_company_attr_name_v65;

INSERT INTO audit.val_person_company_attr_name (
	person_company_attr_name,
	person_company_attr_data_type,
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
	person_company_attr_name,
	person_company_attr_data_type,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_person_company_attr_name_v65;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_person_company_attr_name ADD CONSTRAINT pk_val_person_company_attr_nam PRIMARY KEY (person_company_attr_name);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xifprescompattr_name_datatyp ON val_person_company_attr_name USING btree (person_company_attr_data_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_person_company_attr_name and val_person_company_attr_value
--ALTER TABLE val_person_company_attr_value
--	ADD CONSTRAINT fk_pers_comp_attr_val_name
--	FOREIGN KEY (person_company_attr_name) REFERENCES val_person_company_attr_name(person_company_attr_name);
-- consider FK val_person_company_attr_name and person_company_attr
--ALTER TABLE person_company_attr
--	ADD CONSTRAINT fk_person_comp_attr_val_name
--	FOREIGN KEY (person_company_attr_name) REFERENCES val_person_company_attr_name(person_company_attr_name);

-- FOREIGN KEYS TO
-- consider FK val_person_company_attr_name and val_person_company_attr_dtype
ALTER TABLE val_person_company_attr_name
	ADD CONSTRAINT fk_prescompattr_name_datatyp
	FOREIGN KEY (person_company_attr_data_type) REFERENCES val_person_company_attr_dtype(person_company_attr_data_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_person_company_attr_name');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_person_company_attr_name');
DROP TABLE IF EXISTS val_person_company_attr_name_v65;
DROP TABLE IF EXISTS audit.val_person_company_attr_name_v65;
-- DONE DEALING WITH TABLE val_person_company_attr_name [4469568]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_person_company_attr_value [4479439]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_person_company_attr_value', 'val_person_company_attr_value');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.val_person_company_attr_value DROP CONSTRAINT IF EXISTS fk_pers_comp_attr_val_name;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_person_company_attr_value');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_person_company_attr_value DROP CONSTRAINT IF EXISTS pk_val_pers_company_attr_value;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xifpers_comp_attr_val_name";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_person_company_attr_value ON jazzhands.val_person_company_attr_value;
DROP TRIGGER IF EXISTS trigger_audit_val_person_company_attr_value ON jazzhands.val_person_company_attr_value;
DROP TRIGGER IF EXISTS trigger_validate_pers_comp_attr_value ON jazzhands.val_person_company_attr_value;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_person_company_attr_value');
---- BEGIN audit.val_person_company_attr_value TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_person_company_attr_value', 'val_person_company_attr_value');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_person_company_attr_value');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_person_company_attr_value_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_person_company_attr_value');
---- DONE audit.val_person_company_attr_value TEARDOWN


ALTER TABLE val_person_company_attr_value RENAME TO val_person_company_attr_value_v65;
ALTER TABLE audit.val_person_company_attr_value RENAME TO val_person_company_attr_value_v65;

CREATE TABLE val_person_company_attr_value
(
	person_company_attr_name	varchar(50) NOT NULL,
	person_company_attr_value	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_person_company_attr_value', false);
INSERT INTO val_person_company_attr_value (
	person_company_attr_name,
	person_company_attr_value,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	person_company_attr_name,
	person_company_attr_value,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_person_company_attr_value_v65;

INSERT INTO audit.val_person_company_attr_value (
	person_company_attr_name,
	person_company_attr_value,
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
	person_company_attr_name,
	person_company_attr_value,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_person_company_attr_value_v65;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_person_company_attr_value ADD CONSTRAINT pk_val_pers_company_attr_value PRIMARY KEY (person_company_attr_name, person_company_attr_value);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xifpers_comp_attr_val_name ON val_person_company_attr_value USING btree (person_company_attr_name);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK val_person_company_attr_value and val_person_company_attr_name
ALTER TABLE val_person_company_attr_value
	ADD CONSTRAINT fk_pers_comp_attr_val_name
	FOREIGN KEY (person_company_attr_name) REFERENCES val_person_company_attr_name(person_company_attr_name);

-- TRIGGERS
-- consider NEW oid 4476790
CREATE OR REPLACE FUNCTION jazzhands.validate_pers_comp_attr_value()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally			integer;
BEGIN
	PERFORM 1
	FROM	val_person_company_attr_value
	WHERE	(person_company_attr_name,person_company_attr_value)
			IN
			(OLD.person_company_attr_name,OLD.person_company_attr_value)
	;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'attribute_value must be valid'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;

END;
$function$
;
CREATE TRIGGER trigger_validate_pers_comp_attr_value BEFORE DELETE OR UPDATE OF person_company_attr_name, person_company_attr_value ON val_person_company_attr_value FOR EACH ROW EXECUTE PROCEDURE validate_pers_comp_attr_value();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_person_company_attr_value');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_person_company_attr_value');
DROP TABLE IF EXISTS val_person_company_attr_value_v65;
DROP TABLE IF EXISTS audit.val_person_company_attr_value_v65;
-- DONE DEALING WITH TABLE val_person_company_attr_value [4469577]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE account_token [4476977]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_token', 'account_token');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.account_token DROP CONSTRAINT IF EXISTS fk_acct_ref_acct_token;
ALTER TABLE jazzhands.account_token DROP CONSTRAINT IF EXISTS fk_acct_token_ref_token;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'account_token');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.account_token DROP CONSTRAINT IF EXISTS ak_account_token_tken_acct;
ALTER TABLE jazzhands.account_token DROP CONSTRAINT IF EXISTS pk_account_token;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_account_token ON jazzhands.account_token;
DROP TRIGGER IF EXISTS trigger_audit_account_token ON jazzhands.account_token;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'account_token');
---- BEGIN audit.account_token TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'account_token', 'account_token');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'account_token');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."account_token_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'account_token');
---- DONE audit.account_token TEARDOWN


ALTER TABLE account_token RENAME TO account_token_v65;
ALTER TABLE audit.account_token RENAME TO account_token_v65;

CREATE TABLE account_token
(
	account_token_id	integer NOT NULL,
	account_id	integer NOT NULL,
	token_id	integer NOT NULL,
	issued_date	timestamp with time zone NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'account_token', false);
ALTER TABLE account_token
	ALTER account_token_id
	SET DEFAULT nextval('account_token_account_token_id_seq'::regclass);
INSERT INTO account_token (
	account_token_id,
	account_id,
	token_id,
	issued_date,
	description,		-- new column (description)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	account_token_id,
	account_id,
	token_id,
	issued_date,
	NULL,		-- new column (description)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM account_token_v65;

INSERT INTO audit.account_token (
	account_token_id,
	account_id,
	token_id,
	issued_date,
	description,		-- new column (description)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	account_token_id,
	account_id,
	token_id,
	issued_date,
	NULL,		-- new column (description)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.account_token_v65;

ALTER TABLE account_token
	ALTER account_token_id
	SET DEFAULT nextval('account_token_account_token_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE account_token ADD CONSTRAINT ak_account_token_tken_acct UNIQUE (account_id, token_id);
ALTER TABLE account_token ADD CONSTRAINT pk_account_token PRIMARY KEY (account_token_id);

-- Table/Column Comments
COMMENT ON COLUMN account_token.account_token_id IS 'This is its own PK in order to better handle auditing.';
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK account_token and account
ALTER TABLE account_token
	ADD CONSTRAINT fk_acct_ref_acct_token
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK account_token and token
ALTER TABLE account_token
	ADD CONSTRAINT fk_acct_token_ref_token
	FOREIGN KEY (token_id) REFERENCES token(token_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'account_token');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'account_token');
ALTER SEQUENCE account_token_account_token_id_seq
	 OWNED BY account_token.account_token_id;
DROP TABLE IF EXISTS account_token_v65;
DROP TABLE IF EXISTS audit.account_token_v65;
-- DONE DEALING WITH TABLE account_token [4467112]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE approval_instance_step_notify [4477102]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'approval_instance_step_notify', 'approval_instance_step_notify');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.approval_instance_step_notify DROP CONSTRAINT IF EXISTS fk_appinststep_appinstprocid;
ALTER TABLE jazzhands.approval_instance_step_notify DROP CONSTRAINT IF EXISTS fk_appinststepntfy_ntfy_typ;
ALTER TABLE jazzhands.approval_instance_step_notify DROP CONSTRAINT IF EXISTS fk_appr_inst_step_notif_acct;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'approval_instance_step_notify');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.approval_instance_step_notify DROP CONSTRAINT IF EXISTS pk_approval_instance_step_noti;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1approval_instance_step_not";
DROP INDEX IF EXISTS "jazzhands"."xif2approval_instance_step_not";
DROP INDEX IF EXISTS "jazzhands"."xif3approval_instance_step_not";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_approval_instance_step_notify ON jazzhands.approval_instance_step_notify;
DROP TRIGGER IF EXISTS trigger_audit_approval_instance_step_notify ON jazzhands.approval_instance_step_notify;
DROP TRIGGER IF EXISTS trigger_legacy_approval_instance_step_notify_account ON jazzhands.approval_instance_step_notify;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'approval_instance_step_notify');
---- BEGIN audit.approval_instance_step_notify TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'approval_instance_step_notify', 'approval_instance_step_notify');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'approval_instance_step_notify');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."approval_instance_step_notify_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'approval_instance_step_notify');
---- DONE audit.approval_instance_step_notify TEARDOWN


ALTER TABLE approval_instance_step_notify RENAME TO approval_instance_step_notify_v65;
ALTER TABLE audit.approval_instance_step_notify RENAME TO approval_instance_step_notify_v65;

CREATE TABLE approval_instance_step_notify
(
	approv_instance_step_notify_id	integer NOT NULL,
	approval_instance_step_id	integer NOT NULL,
	approval_notify_type	varchar(50) NOT NULL,
	account_id	integer NOT NULL,
	approval_notify_whence	timestamp with time zone NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'approval_instance_step_notify', false);
ALTER TABLE approval_instance_step_notify
	ALTER approv_instance_step_notify_id
	SET DEFAULT nextval('approval_instance_step_notify_approv_instance_step_notify_i_seq'::regclass);
INSERT INTO approval_instance_step_notify (
	approv_instance_step_notify_id,
	approval_instance_step_id,
	approval_notify_type,
	account_id,
	approval_notify_whence,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	approv_instance_step_notify_id,
	approval_instance_step_id,
	approval_notify_type,
	account_id,
	approval_notify_whence,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM approval_instance_step_notify_v65;

INSERT INTO audit.approval_instance_step_notify (
	approv_instance_step_notify_id,
	approval_instance_step_id,
	approval_notify_type,
	account_id,
	approval_notify_whence,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	approv_instance_step_notify_id,
	approval_instance_step_id,
	approval_notify_type,
	account_id,
	approval_notify_whence,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.approval_instance_step_notify_v65;

ALTER TABLE approval_instance_step_notify
	ALTER approv_instance_step_notify_id
	SET DEFAULT nextval('approval_instance_step_notify_approv_instance_step_notify_i_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE approval_instance_step_notify ADD CONSTRAINT pk_approval_instance_step_noti PRIMARY KEY (approv_instance_step_notify_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1approval_instance_step_not ON approval_instance_step_notify USING btree (approval_notify_type);
CREATE INDEX xif2approval_instance_step_not ON approval_instance_step_notify USING btree (approval_instance_step_id);
CREATE INDEX xif3approval_instance_step_not ON approval_instance_step_notify USING btree (account_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK approval_instance_step_notify and approval_instance_step
ALTER TABLE approval_instance_step_notify
	ADD CONSTRAINT fk_appinststep_appinstprocid
	FOREIGN KEY (approval_instance_step_id) REFERENCES approval_instance_step(approval_instance_step_id);
-- consider FK approval_instance_step_notify and val_approval_notifty_type
ALTER TABLE approval_instance_step_notify
	ADD CONSTRAINT fk_appinststepntfy_ntfy_typ
	FOREIGN KEY (approval_notify_type) REFERENCES val_approval_notifty_type(approval_notify_type);
-- consider FK approval_instance_step_notify and account
ALTER TABLE approval_instance_step_notify
	ADD CONSTRAINT fk_appr_inst_step_notif_acct
	FOREIGN KEY (account_id) REFERENCES account(account_id);

-- TRIGGERS
-- consider NEW oid 4476568
CREATE OR REPLACE FUNCTION jazzhands.legacy_approval_instance_step_notify_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF NEW.account_id IS NULL THEN
		SELECT	approver_account_id
		INTO	NEW.account_id
		FROM	approval_instance_step
		WHERE	approval_instance_step_id =
				NEW.approval_instance_step_id;
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_legacy_approval_instance_step_notify_account BEFORE INSERT OR UPDATE OF account_id ON approval_instance_step_notify FOR EACH ROW EXECUTE PROCEDURE legacy_approval_instance_step_notify_account();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'approval_instance_step_notify');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'approval_instance_step_notify');
ALTER SEQUENCE approval_instance_step_notify_approv_instance_step_notify_i_seq
	 OWNED BY approval_instance_step_notify.approv_instance_step_notify_id;
DROP TABLE IF EXISTS approval_instance_step_notify_v65;
DROP TABLE IF EXISTS audit.approval_instance_step_notify_v65;
-- DONE DEALING WITH TABLE approval_instance_step_notify [4467239]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE person_company_attr [4478253]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'person_company_attr', 'person_company_attr');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.person_company_attr DROP CONSTRAINT IF EXISTS fk_pers_comp_attr_person_comp_;
ALTER TABLE jazzhands.person_company_attr DROP CONSTRAINT IF EXISTS fk_person_comp_att_pers_person;
ALTER TABLE jazzhands.person_company_attr DROP CONSTRAINT IF EXISTS fk_person_comp_attr_val_name;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'person_company_attr');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.person_company_attr DROP CONSTRAINT IF EXISTS ak_person_company_attr_name;
ALTER TABLE jazzhands.person_company_attr DROP CONSTRAINT IF EXISTS pk_person_company_attr;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif2person_company_attr";
DROP INDEX IF EXISTS "jazzhands"."xif3person_company_attr";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_person_company_attr ON jazzhands.person_company_attr;
DROP TRIGGER IF EXISTS trigger_audit_person_company_attr ON jazzhands.person_company_attr;
DROP TRIGGER IF EXISTS trigger_validate_pers_company_attr ON jazzhands.person_company_attr;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'person_company_attr');
---- BEGIN audit.person_company_attr TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'person_company_attr', 'person_company_attr');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'person_company_attr');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."person_company_attr_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'person_company_attr');
---- DONE audit.person_company_attr TEARDOWN


ALTER TABLE person_company_attr RENAME TO person_company_attr_v65;
ALTER TABLE audit.person_company_attr RENAME TO person_company_attr_v65;

CREATE TABLE person_company_attr
(
	company_id	integer NOT NULL,
	person_id	integer NOT NULL,
	person_company_attr_name	varchar(50)  NULL,
	attribute_value	varchar(50)  NULL,
	attribute_value_timestamp	timestamp with time zone  NULL,
	attribute_value_person_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'person_company_attr', false);
INSERT INTO person_company_attr (
	company_id,
	person_id,
	person_company_attr_name,
	attribute_value,
	attribute_value_timestamp,
	attribute_value_person_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	company_id,
	person_id,
	person_company_attr_name,
	attribute_value,
	attribute_value_timestamp,
	attribute_value_person_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM person_company_attr_v65;

INSERT INTO audit.person_company_attr (
	company_id,
	person_id,
	person_company_attr_name,
	attribute_value,
	attribute_value_timestamp,
	attribute_value_person_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	company_id,
	person_id,
	person_company_attr_name,
	attribute_value,
	attribute_value_timestamp,
	attribute_value_person_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.person_company_attr_v65;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE person_company_attr ADD CONSTRAINT ak_person_company_attr_name UNIQUE (company_id, person_id, person_company_attr_name);
ALTER TABLE person_company_attr ADD CONSTRAINT pk_person_company_attr PRIMARY KEY (company_id, person_id);

-- Table/Column Comments
COMMENT ON COLUMN person_company_attr.attribute_value IS 'string value of the attribute.';
COMMENT ON COLUMN person_company_attr.attribute_value_person_id IS 'person_id value of the attribute.';
-- INDEXES
CREATE INDEX xif2person_company_attr ON person_company_attr USING btree (attribute_value_person_id);
CREATE INDEX xif3person_company_attr ON person_company_attr USING btree (person_company_attr_name);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK person_company_attr and person_company
ALTER TABLE person_company_attr
	ADD CONSTRAINT fk_pers_comp_attr_person_comp_
	FOREIGN KEY (company_id, person_id) REFERENCES person_company(company_id, person_id);
-- consider FK person_company_attr and person
ALTER TABLE person_company_attr
	ADD CONSTRAINT fk_person_comp_att_pers_person
	FOREIGN KEY (attribute_value_person_id) REFERENCES person(person_id);
-- consider FK person_company_attr and val_person_company_attr_name
ALTER TABLE person_company_attr
	ADD CONSTRAINT fk_person_comp_attr_val_name
	FOREIGN KEY (person_company_attr_name) REFERENCES val_person_company_attr_name(person_company_attr_name);

-- TRIGGERS
-- consider NEW oid 4476788
CREATE OR REPLACE FUNCTION jazzhands.validate_pers_company_attr()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally			integer;
	v_pc_atr		val_person_company_attr_name%ROWTYPE;
	v_listvalue		Property.Property_Value%TYPE;
BEGIN

	SELECT	*
	INTO	v_pc_atr
	FROM	val_person_company_attr_name
	WHERE	person_company_attr_name = NEW.person_company_attr_name;

	IF v_pc_atr.person_company_attr_data_type IN
			('boolean', 'number', 'string', 'list') THEN
		IF NEW.attribute_value IS NULL THEN
			RAISE EXCEPTION 'attribute_value must be set for %',
				v_pc_atr.person_company_attr_data_type
				USING ERRCODE = 'not_null_violation';
		END IF;
		IF v_pc_atr.person_company_attr_data_type = 'boolean' THEN
			IF NEW.attribute_value NOT IN ('Y', 'N') THEN
				RAISE EXCEPTION 'attribute_value must be boolean (Y,N)'
					USING ERRCODE = 'integrity_constraint_violation';
			END IF;
		ELSIF v_pc_atr.person_company_attr_data_type = 'number' THEN
			IF NEW.attribute_value !~ '^-?(\d*\.?\d*){1}$' THEN
				RAISE EXCEPTION 'attribute_value must be a number'
					USING ERRCODE = 'integrity_constraint_violation';
			END IF;
		ELSIF v_pc_atr.person_company_attr_data_type = 'timestamp' THEN
			IF NEW.attribute_value_timestamp IS NULL THEN
				RAISE EXCEPTION 'attribute_value_timestamp must be set for %',
					v_pc_atr.person_company_attr_data_type
					USING ERRCODE = 'not_null_violation';
			END IF;
		ELSIF v_pc_atr.person_company_attr_data_type = 'list' THEN
			PERFORM 1
			FROM	val_person_company_attr_value
			WHERE	(person_company_attr_name,person_company_attr_value)
					IN
					(NEW.person_company_attr_name,NEW.person_company_attr_value)
			;
			IF NOT FOUND THEN
				RAISE EXCEPTION 'attribute_value must be valid'
					USING ERRCODE = 'integrity_constraint_violation';
			END IF;
		END IF;
	ELSIF v_pc_atr.person_company_attr_data_type = 'person_id' THEN
		IF NEW.attribute_value_timestamp IS NULL THEN
			RAISE EXCEPTION 'attribute_value_timestamp must be set for %',
				v_pc_atr.person_company_attr_data_type
				USING ERRCODE = 'not_null_violation';
		END IF;
	END IF;

	IF NEW.attribute_value IS NOT NULL AND
			(NEW.attribute_value_person_id IS NOT NULL OR
			NEW.attribute_value_timestamp IS NOT NULL) THEN
		RAISE EXCEPTION 'only one attribute_value may be set'
			USING ERRCODE = 'integrity_constraint_violation';
	ELSIF NEW.ttribute_value_person_id IS NOT NULL AND
			(NEW.attribute_value IS NOT NULL OR
			NEW.attribute_value_timestamp IS NOT NULL) THEN
		RAISE EXCEPTION 'only one attribute_value may be set'
			USING ERRCODE = 'integrity_constraint_violation';
	ELSIF NEW.attribute_value_timestamp IS NOT NULL AND
			(NEW.attribute_value_person_id IS NOT NULL OR
			NEW.attribute_value IS NOT NULL) THEN
		RAISE EXCEPTION 'only one attribute_value may be set'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_validate_pers_company_attr BEFORE INSERT OR UPDATE ON person_company_attr FOR EACH ROW EXECUTE PROCEDURE validate_pers_company_attr();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'person_company_attr');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'person_company_attr');
DROP TABLE IF EXISTS person_company_attr_v65;
DROP TABLE IF EXISTS audit.person_company_attr_v65;
-- DONE DEALING WITH TABLE person_company_attr [4468391]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE token [4478802]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'token', 'token');

-- FOREIGN KEYS FROM
ALTER TABLE account_token DROP CONSTRAINT IF EXISTS fk_acct_token_ref_token;
ALTER TABLE token_collection_token DROP CONSTRAINT IF EXISTS fk_tok_col_tok_token_id;
ALTER TABLE token_sequence DROP CONSTRAINT IF EXISTS fk_token_seq_ref_token;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS fk_token_enc_id_id;
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS fk_token_ref_v_token_status;
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS fk_token_ref_v_token_type;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'token');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS ak_token_token_key;
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS pk_token;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_token_tokenstatus";
DROP INDEX IF EXISTS "jazzhands"."idx_token_tokentype";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS check_yes_no_tkn_islckd;
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS sys_c0020104;
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS sys_c0020105;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_token ON jazzhands.token;
DROP TRIGGER IF EXISTS trigger_audit_token ON jazzhands.token;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'token');
---- BEGIN audit.token TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'token', 'token');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'token');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."token_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'token');
---- DONE audit.token TEARDOWN


ALTER TABLE token RENAME TO token_v65;
ALTER TABLE audit.token RENAME TO token_v65;

CREATE TABLE token
(
	token_id	integer NOT NULL,
	token_type	varchar(50) NOT NULL,
	token_status	varchar(50)  NULL,
	description	varchar(255)  NULL,
	token_serial	varchar(20)  NULL,
	zero_time	timestamp with time zone  NULL,
	time_modulo	integer  NULL,
	time_skew	integer  NULL,
	token_key	varchar(512)  NULL,
	encryption_key_id	integer  NULL,
	token_password	varchar(128)  NULL,
	expire_time	timestamp with time zone  NULL,
	is_token_locked	character(1) NOT NULL,
	token_unlock_time	timestamp with time zone  NULL,
	bad_logins	integer  NULL,
	last_updated	timestamp with time zone NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'token', false);
ALTER TABLE token
	ALTER token_id
	SET DEFAULT nextval('token_token_id_seq'::regclass);
ALTER TABLE token
	ALTER is_token_locked
	SET DEFAULT 'N'::bpchar;
INSERT INTO token (
	token_id,
	token_type,
	token_status,
	description,		-- new column (description)
	token_serial,
	zero_time,
	time_modulo,
	time_skew,
	token_key,
	encryption_key_id,
	token_password,
	expire_time,
	is_token_locked,
	token_unlock_time,
	bad_logins,
	last_updated,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	token_id,
	token_type,
	token_status,
	NULL,		-- new column (description)
	token_serial,
	zero_time,
	time_modulo,
	time_skew,
	token_key,
	encryption_key_id,
	token_password,
	expire_time,
	is_token_locked,
	token_unlock_time,
	bad_logins,
	last_updated,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM token_v65;

INSERT INTO audit.token (
	token_id,
	token_type,
	token_status,
	description,		-- new column (description)
	token_serial,
	zero_time,
	time_modulo,
	time_skew,
	token_key,
	encryption_key_id,
	token_password,
	expire_time,
	is_token_locked,
	token_unlock_time,
	bad_logins,
	last_updated,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	token_id,
	token_type,
	token_status,
	NULL,		-- new column (description)
	token_serial,
	zero_time,
	time_modulo,
	time_skew,
	token_key,
	encryption_key_id,
	token_password,
	expire_time,
	is_token_locked,
	token_unlock_time,
	bad_logins,
	last_updated,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.token_v65;

ALTER TABLE token
	ALTER token_id
	SET DEFAULT nextval('token_token_id_seq'::regclass);
ALTER TABLE token
	ALTER is_token_locked
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE token ADD CONSTRAINT ak_token_token_key UNIQUE (token_key);
ALTER TABLE token ADD CONSTRAINT pk_token PRIMARY KEY (token_id);

-- Table/Column Comments
COMMENT ON COLUMN token.encryption_key_id IS 'encryption information for token_key, if used';
-- INDEXES
CREATE INDEX idx_token_tokenstatus ON token USING btree (token_status);
CREATE INDEX idx_token_tokentype ON token USING btree (token_type);

-- CHECK CONSTRAINTS
ALTER TABLE token ADD CONSTRAINT check_yes_no_tkn_islckd
	CHECK (is_token_locked = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE token ADD CONSTRAINT sys_c0020104
	CHECK (token_type IS NOT NULL);
ALTER TABLE token ADD CONSTRAINT sys_c0020105
	CHECK (last_updated IS NOT NULL);

-- FOREIGN KEYS FROM
-- consider FK token and account_token
ALTER TABLE account_token
	ADD CONSTRAINT fk_acct_token_ref_token
	FOREIGN KEY (token_id) REFERENCES token(token_id);
-- consider FK token and token_collection_token
ALTER TABLE token_collection_token
	ADD CONSTRAINT fk_tok_col_tok_token_id
	FOREIGN KEY (token_id) REFERENCES token(token_id);
-- consider FK token and token_sequence
ALTER TABLE token_sequence
	ADD CONSTRAINT fk_token_seq_ref_token
	FOREIGN KEY (token_id) REFERENCES token(token_id);

-- FOREIGN KEYS TO
-- consider FK token and encryption_key
ALTER TABLE token
	ADD CONSTRAINT fk_token_enc_id_id
	FOREIGN KEY (encryption_key_id) REFERENCES encryption_key(encryption_key_id);
-- consider FK token and val_token_status
ALTER TABLE token
	ADD CONSTRAINT fk_token_ref_v_token_status
	FOREIGN KEY (token_status) REFERENCES val_token_status(token_status);
-- consider FK token and val_token_type
ALTER TABLE token
	ADD CONSTRAINT fk_token_ref_v_token_type
	FOREIGN KEY (token_type) REFERENCES val_token_type(token_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'token');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'token');
ALTER SEQUENCE token_token_id_seq
	 OWNED BY token.token_id;
DROP TABLE IF EXISTS token_v65;
DROP TABLE IF EXISTS audit.token_v65;
-- DONE DEALING WITH TABLE token [4468940]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_acct_coll_acct_expanded_detail [4486104]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_acct_coll_acct_expanded_detail', 'v_acct_coll_acct_expanded_detail');
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'v_acct_coll_acct_expanded_detail');
DROP VIEW IF EXISTS jazzhands.v_acct_coll_acct_expanded_detail;
CREATE VIEW jazzhands.v_acct_coll_acct_expanded_detail AS
 WITH RECURSIVE var_recurse(account_collection_id, root_account_collection_id, account_id, acct_coll_level, dept_level, assign_method, array_path, cycle) AS (
         SELECT aca.account_collection_id,
            aca.account_collection_id,
            aca.account_id,
                CASE ac.account_collection_type
                    WHEN 'department'::text THEN 0
                    ELSE 1
                END AS "case",
                CASE ac.account_collection_type
                    WHEN 'department'::text THEN 1
                    ELSE 0
                END AS "case",
                CASE ac.account_collection_type
                    WHEN 'department'::text THEN 'DirectDepartmentAssignment'::text
                    ELSE 'DirectAccountCollectionAssignment'::text
                END AS "case",
            ARRAY[aca.account_collection_id] AS "array",
            false AS bool
           FROM account_collection ac
             JOIN v_account_collection_account aca USING (account_collection_id)
        UNION ALL
         SELECT ach.account_collection_id,
            x.root_account_collection_id,
            x.account_id,
                CASE ac.account_collection_type
                    WHEN 'department'::text THEN x.dept_level
                    ELSE x.acct_coll_level + 1
                END AS "case",
                CASE ac.account_collection_type
                    WHEN 'department'::text THEN x.dept_level + 1
                    ELSE x.dept_level
                END AS dept_level,
                CASE
                    WHEN ac.account_collection_type::text = 'department'::text THEN 'AccountAssignedToChildDepartment'::text
                    WHEN x.dept_level > 1 AND x.acct_coll_level > 0 THEN 'ParentDepartmentAssignedToParentAccountCollection'::text
                    WHEN x.dept_level > 1 THEN 'ParentDepartmentAssignedToAccountCollection'::text
                    WHEN x.dept_level = 1 AND x.acct_coll_level > 0 THEN 'DepartmentAssignedToParentAccountCollection'::text
                    WHEN x.dept_level = 1 THEN 'DepartmentAssignedToAccountCollection'::text
                    ELSE 'AccountAssignedToParentAccountCollection'::text
                END AS assign_method,
            x.array_path || ach.account_collection_id AS array_path,
            ach.account_collection_id = ANY (x.array_path)
           FROM var_recurse x
             JOIN account_collection_hier ach ON x.account_collection_id = ach.child_account_collection_id
             JOIN account_collection ac ON ach.account_collection_id = ac.account_collection_id
          WHERE NOT x.cycle
        )
 SELECT var_recurse.account_collection_id,
    var_recurse.root_account_collection_id,
    var_recurse.account_id,
    var_recurse.acct_coll_level,
    var_recurse.dept_level,
    var_recurse.assign_method,
    array_to_string(var_recurse.array_path, '/'::text) AS text_path,
    var_recurse.array_path
   FROM var_recurse;

delete from __recreate where type = 'view' and object = 'v_acct_coll_acct_expanded_detail';
-- DONE DEALING WITH TABLE v_acct_coll_acct_expanded_detail [4476243]
--------------------------------------------------------------------
--
-- Process trigger procs in jazzhands
--
-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'legacy_approval_instance_step_notify_account');
CREATE OR REPLACE FUNCTION jazzhands.legacy_approval_instance_step_notify_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF NEW.account_id IS NULL THEN
		SELECT	approver_account_id
		INTO	NEW.account_id
		FROM	approval_instance_step
		WHERE	approval_instance_step_id =
				NEW.approval_instance_step_id;
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.account_validate_login()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	correctval	char(1);
BEGIN

	IF NEW.login  ~ '[^-/@a-z0-9_]+' THEN
		RAISE EXCEPTION 'May not update IS_ENABLED to an invalid value for given account_status: %', NEW.account_status
			USING errcode = 'integrity_constraint_violation';
	END IF;

	RETURN NEW;
END;
$function$
;

--
-- Process trigger procs in net_manip
--
--
-- Process trigger procs in network_strings
--
--
-- Process trigger procs in time_util
--
--
-- Process trigger procs in dns_utils
--
--
-- Process trigger procs in person_manip
--
--
-- Process trigger procs in auto_ac_manip
--
--
-- Process trigger procs in company_manip
--
--
-- Process trigger procs in port_support
--
--
-- Process trigger procs in port_utils
--
--
-- Process trigger procs in device_utils
--
--
-- Process trigger procs in netblock_utils
--
--
-- Process trigger procs in netblock_manip
--
--
-- Process trigger procs in physical_address_utils
--
--
-- Process trigger procs in component_utils
--
--
-- Process trigger procs in snapshot_manip
--
--
-- Process trigger procs in lv_manip
--
--
-- Process trigger procs in schema_support
--
--
-- Process trigger procs in approval_utils
--
-- Dropping obsoleted sequences....


-- Dropping obsoleted audit sequences....


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
-- index
-- triggers
CREATE TRIGGER trigger_account_validate_login BEFORE INSERT OR UPDATE OF login ON account FOR EACH ROW EXECUTE PROCEDURE account_validate_login();


-- Clean Up
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_saved_grants();
GRANT select on all tables in schema jazzhands to ro_role;
GRANT insert,update,delete on all tables in schema jazzhands to iud_role;
GRANT select on all sequences in schema jazzhands to ro_role;
GRANT usage on all sequences in schema jazzhands to iud_role;
GRANT select on all tables in schema audit to ro_role;
GRANT select on all sequences in schema audit to ro_role;
SELECT schema_support.end_maintenance();
select timeofday(), now();
