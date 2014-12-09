/*
 *
 * Copyright (c) 2014 Todd Kover
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
Invoked:

	--suffix=v59
	--scan-tables
	account_password
	v_unix_passwd_mappings
	v_unix_group_mappings
	device_utils.retire_device
	netblock_utils.find_best_parent_id
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance();
-- Creating new sequences....


--------------------------------------------------------------------
-- DEALING WITH TABLE account_password [920561]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_password', 'account_password');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.account_password DROP CONSTRAINT IF EXISTS fk_system_password;
ALTER TABLE jazzhands.account_password DROP CONSTRAINT IF EXISTS fk_system_pass_ref_vpasstype;
ALTER TABLE jazzhands.account_password DROP CONSTRAINT IF EXISTS pk_system_password;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_audit_account_password ON jazzhands.account_password;
DROP TRIGGER IF EXISTS trig_userlog_account_password ON jazzhands.account_password;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'account_password');
---- BEGIN audit.account_password TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."account_password_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'account_password');
---- DONE audit.account_password TEARDOWN


ALTER TABLE account_password RENAME TO account_password_v59;
ALTER TABLE audit.account_password RENAME TO account_password_v59;

CREATE TABLE account_password
(
	account_id	integer NOT NULL,
	password_type	varchar(50) NOT NULL,
	password	varchar(255) NOT NULL,
	change_time	timestamp with time zone  NULL,
	expire_time	timestamp with time zone  NULL,
	unlock_time	timestamp with time zone  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'account_password', false);
INSERT INTO account_password (
	account_id,
	password_type,
	password,
	change_time,
	expire_time,
	unlock_time,		-- new column (unlock_time)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	account_id,
	password_type,
	password,
	change_time,
	expire_time,
	NULL,		-- new column (unlock_time)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM account_password_v59;

INSERT INTO audit.account_password (
	account_id,
	password_type,
	password,
	change_time,
	expire_time,
	unlock_time,		-- new column (unlock_time)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	account_id,
	password_type,
	password,
	change_time,
	expire_time,
	NULL,		-- new column (unlock_time)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.account_password_v59;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE account_password ADD CONSTRAINT pk_system_password PRIMARY KEY (account_id, password_type);

-- Table/Column Comments
COMMENT ON COLUMN account_password.change_time IS 'The last thie this password was changed';
COMMENT ON COLUMN account_password.expire_time IS 'The time this password expires, if different from the default';
COMMENT ON COLUMN account_password.unlock_time IS 'indicates the time that the password is unlocked and can thus be changed; NULL means the password can be changed.  This is application enforced.';
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK account_password and val_password_type
ALTER TABLE account_password
	ADD CONSTRAINT fk_system_pass_ref_vpasstype
	FOREIGN KEY (password_type) REFERENCES val_password_type(password_type);
-- consider FK account_password and account
ALTER TABLE account_password
	ADD CONSTRAINT fk_system_password
	FOREIGN KEY (account_id) REFERENCES account(account_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'account_password');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'account_password');
DROP TABLE IF EXISTS account_password_v59;
DROP TABLE IF EXISTS audit.account_password_v59;
-- DONE DEALING WITH TABLE account_password [905352]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE account_password [920561]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_password', 'account_password');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.account_password DROP CONSTRAINT IF EXISTS fk_system_pass_ref_vpasstype;
ALTER TABLE jazzhands.account_password DROP CONSTRAINT IF EXISTS fk_system_password;
ALTER TABLE jazzhands.account_password DROP CONSTRAINT IF EXISTS pk_system_password;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_account_password ON jazzhands.account_password;
DROP TRIGGER IF EXISTS trigger_audit_account_password ON jazzhands.account_password;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'account_password');
---- BEGIN audit.account_password TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."account_password_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'account_password');
---- DONE audit.account_password TEARDOWN


ALTER TABLE account_password RENAME TO account_password_v59;
ALTER TABLE audit.account_password RENAME TO account_password_v59;

CREATE TABLE account_password
(
	account_id	integer NOT NULL,
	password_type	varchar(50) NOT NULL,
	password	varchar(255) NOT NULL,
	change_time	timestamp with time zone  NULL,
	expire_time	timestamp with time zone  NULL,
	unlock_time	timestamp with time zone  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'account_password', false);
INSERT INTO account_password (
	account_id,
	password_type,
	password,
	change_time,
	expire_time,
	unlock_time,		-- new column (unlock_time)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	account_id,
	password_type,
	password,
	change_time,
	expire_time,
	NULL,		-- new column (unlock_time)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM account_password_v59;

INSERT INTO audit.account_password (
	account_id,
	password_type,
	password,
	change_time,
	expire_time,
	unlock_time,		-- new column (unlock_time)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	account_id,
	password_type,
	password,
	change_time,
	expire_time,
	NULL,		-- new column (unlock_time)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.account_password_v59;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE account_password ADD CONSTRAINT pk_system_password PRIMARY KEY (account_id, password_type);

-- Table/Column Comments
COMMENT ON COLUMN account_password.change_time IS 'The last thie this password was changed';
COMMENT ON COLUMN account_password.expire_time IS 'The time this password expires, if different from the default';
COMMENT ON COLUMN account_password.unlock_time IS 'indicates the time that the password is unlocked and can thus be changed; NULL means the password can be changed.  This is application enforced.';
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK account_password and account
ALTER TABLE account_password
	ADD CONSTRAINT fk_system_password
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK account_password and val_password_type
ALTER TABLE account_password
	ADD CONSTRAINT fk_system_pass_ref_vpasstype
	FOREIGN KEY (password_type) REFERENCES val_password_type(password_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'account_password');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'account_password');
DROP TABLE IF EXISTS account_password_v59;
DROP TABLE IF EXISTS audit.account_password_v59;
-- DONE DEALING WITH TABLE account_password [905352]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_unix_passwd_mappings [927727]
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
             JOIN val_person_status vps ON a.account_status::text = vps.person_status::text
          WHERE vps.is_disabled = 'N'::bpchar
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
            ugac.account_collection_name AS unix_group_name,
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
-- DONE DEALING WITH TABLE v_unix_passwd_mappings [912518]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_unix_group_mappings [927742]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_unix_group_mappings', 'v_unix_group_mappings');
CREATE VIEW v_unix_group_mappings AS
 WITH accts AS (
         SELECT a_1.account_id,
            a_1.login,
            a_1.person_id,
            a_1.company_id,
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
             JOIN val_person_status vps ON a_1.account_status::text = vps.person_status::text
          WHERE vps.is_disabled = 'N'::bpchar
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
            g.account_realm_id,
            g.account_status,
            g.account_role,
            g.account_type,
            g.description,
            g.data_ins_user_1 AS data_ins_user,
            g.data_ins_date_1 AS data_ins_date,
            g.data_upd_user_1 AS data_upd_user,
            g.data_upd_date_1 AS data_upd_date
           FROM grp_members g(account_id, device_collection_id, account_collection_id, unix_uid, unix_group_acct_collection_id, shell, default_home, data_ins_user, data_ins_date, data_upd_user, data_upd_date, login, person_id, company_id, account_realm_id, account_status, account_role, account_type, description, data_ins_user_1, data_ins_date_1, data_upd_user_1, data_upd_date_1)
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
     LEFT JOIN grp_accounts a(account_id, device_collection_id, account_collection_id, unix_uid, unix_group_acct_collection_id, shell, default_home, data_ins_user, data_ins_date, data_upd_user, data_upd_date, login, person_id, company_id, account_realm_id, account_status, account_role, account_type, description, data_ins_user_1, data_ins_date_1, data_upd_user_1, data_upd_date_1) USING (device_collection_id, account_collection_id)
     LEFT JOIN v_unix_mclass_settings mcs ON mcs.device_collection_id = dc.device_collection_id
  GROUP BY dc.device_collection_id, ac.account_collection_id, ac.account_collection_name, unix_group.unix_gid, unix_group.group_password, o.setting, mcs.mclass_setting
  ORDER BY dc.device_collection_id, ac.account_collection_id;

delete from __recreate where type = 'view' and object = 'v_unix_group_mappings';
-- DONE DEALING WITH TABLE v_unix_group_mappings [912533]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH proc device_utils.retire_device -> retire_device 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('device_utils', 'retire_device', 'retire_device');

-- DROP OLD FUNCTION
-- consider old oid 927809
DROP FUNCTION IF EXISTS device_utils.retire_device(in_device_id integer, retire_modules boolean);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 927809
DROP FUNCTION IF EXISTS device_utils.retire_device(in_device_id integer, retire_modules boolean);
-- consider NEW oid 912591
CREATE OR REPLACE FUNCTION device_utils.retire_device(in_device_id integer, retire_modules boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally		INTEGER;
	_r			RECORD;
	_d			DEVICE%ROWTYPE;
	_mgrid		DEVICE.DEVICE_ID%TYPE;
	_purgedev	boolean;
BEGIN
	_purgedev := false;

	BEGIN
		PERFORM local_hooks.device_retire_early(in_Device_Id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	SELECT * INTO _d FROM device WHERE device_id = in_Device_id;
	delete from dns_record where netblock_id in (
		select netblock_id 
		from network_interface where device_id = in_Device_id
	);

	delete from network_interface_purpose where device_id = in_Device_id;
	delete from network_interface where device_id = in_Device_id;

	PERFORM device_utils.purge_physical_ports( in_Device_id);
	PERFORM device_utils.purge_power_ports( in_Device_id);

	delete from property where device_collection_id in (
		SELECT	dc.device_collection_id 
		  FROM	device_collection dc
				INNER JOIN device_collection_device dcd
		 			USING (device_collection_id)
		WHERE	dc.device_collection_type = 'per-device'
		  AND	dcd.device_id = in_Device_id
	);

	delete from device_collection_device where device_id = in_Device_id;
	delete from snmp_commstr where device_id = in_Device_id;

		
	IF _d.rack_location_id IS NOT NULL  THEN
		UPDATE device SET rack_location_id = NULL 
		WHERE device_id = in_Device_id;

		-- This should not be permitted based on constraints, but in case
		-- that constraint had to be disabled...
		SELECT	count(*)
		  INTO	tally
		  FROM	device
		 WHERE	rack_location_id = _d.RACK_LOCATION_ID;

		IF tally = 0 THEN
			DELETE FROM rack_location 
			WHERE rack_location_id = _d.RACK_LOCATION_ID;
		END IF;
	END IF;

	IF _d.chassis_location_id IS NOT NULL THEN
		RAISE EXCEPTION 'Retiring modules is not supported yet.';
	END IF;

	SELECT	manager_device_id
	INTO	_mgrid
	 FROM	device_management_controller
	WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc'
	LIMIT 1;

	IF _mgrid IS NOT NULL THEN
		DELETE FROM device_management_controller
		WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc'
			AND manager_device_id = _mgrid;

		PERFORM device_utils.retire_device( manager_device_id)
		  FROM	device_management_controller
		WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc';
	END IF;

	BEGIN
		PERFORM local_hooks.device_retire_late(in_Device_Id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	SELECT count(*)
	INTO tally
	FROM device_note
	WHERE device_id = in_Device_id;

	--
	-- If there is no notes or serial number its save to remove
	-- 
	IF tally = 0 AND _d.ASSET_ID is NULL THEN
		_purgedev := true;
	END IF;

	IF _purgedev THEN
		--
		-- If there is an fk violation, we just preserve the record but
		-- delete all the identifying characteristics
		--
		BEGIN
			DELETE FROM device where device_id = in_Device_Id;
			return false;
		EXCEPTION WHEN foreign_key_violation THEN
			PERFORM 1;
		END;
	END IF;

	UPDATE device SET 
		device_name =NULL,
		service_environment_id = (
			select service_environment_id from service_environment
			where service_environment_name = 'unallocated'),
		device_status = 'removed',
		voe_symbolic_track_id = NULL,
		is_monitored = 'N',
		should_fetch_config = 'N',
		description = NULL
	WHERE device_id = in_Device_id;

	return true;
END;
$function$
;

-- DONE WITH proc device_utils.retire_device -> retire_device 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc netblock_utils.find_best_parent_id -> find_best_parent_id 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_best_parent_id', 'find_best_parent_id');

-- DROP OLD FUNCTION
-- consider old oid 927814
DROP FUNCTION IF EXISTS netblock_utils.find_best_parent_id(in_netblock_id integer);
-- consider old oid 927813
DROP FUNCTION IF EXISTS netblock_utils.find_best_parent_id(in_ipaddress inet, in_netmask_bits integer, in_netblock_type character varying, in_ip_universe_id integer, in_is_single_address character, in_netblock_id integer, in_fuzzy_can_subnet boolean, can_fix_can_subnet boolean);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 927814
DROP FUNCTION IF EXISTS netblock_utils.find_best_parent_id(in_netblock_id integer);
-- consider old oid 927813
DROP FUNCTION IF EXISTS netblock_utils.find_best_parent_id(in_ipaddress inet, in_netmask_bits integer, in_netblock_type character varying, in_ip_universe_id integer, in_is_single_address character, in_netblock_id integer, in_fuzzy_can_subnet boolean, can_fix_can_subnet boolean);
-- consider NEW oid 912596
CREATE OR REPLACE FUNCTION netblock_utils.find_best_parent_id(in_netblock_id integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
	nbrec		RECORD;
BEGIN
	SELECT * INTO nbrec FROM jazzhands.netblock WHERE 
		netblock_id = in_netblock_id;

	RETURN netblock_utils.find_best_parent_id(
		nbrec.ip_address,
		masklen(nbrec.ip_address),
		nbrec.netblock_type,
		nbrec.ip_universe_id,
		nbrec.is_single_address,
		in_netblock_id
	);
END;
$function$
;
-- consider NEW oid 912595
CREATE OR REPLACE FUNCTION netblock_utils.find_best_parent_id(in_ipaddress inet, in_netmask_bits integer DEFAULT NULL::integer, in_netblock_type character varying DEFAULT 'default'::character varying, in_ip_universe_id integer DEFAULT 0, in_is_single_address character DEFAULT 'N'::bpchar, in_netblock_id integer DEFAULT NULL::integer, in_fuzzy_can_subnet boolean DEFAULT false, can_fix_can_subnet boolean DEFAULT false)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	par_nbid	jazzhands.netblock.netblock_id%type;
BEGIN
	IF (in_netmask_bits IS NOT NULL) THEN
		in_IpAddress := set_masklen(in_IpAddress, in_Netmask_Bits);
	END IF;

	select  Netblock_Id
	  into	par_nbid
	  from  ( select Netblock_Id, Ip_Address
		    from jazzhands.netblock
		   where
		   	in_IpAddress <<= ip_address
		    and is_single_address = 'N'
			and netblock_type = in_netblock_type
			and ip_universe_id = in_ip_universe_id
		    and (
				(in_is_single_address = 'N' AND 
					masklen(ip_address) < masklen(In_IpAddress))
				OR
				(in_is_single_address = 'Y' AND can_subnet = 'N' AND
					(in_Netmask_Bits IS NULL 
						OR masklen(Ip_Address) = in_Netmask_Bits))
			)
			and (in_netblock_id IS NULL OR
				netblock_id != in_netblock_id)
		order by masklen(ip_address) desc
	) subq LIMIT 1;

	IF par_nbid IS NULL AND in_is_single_address = 'Y' AND in_fuzzy_can_subnet THEN
		select  Netblock_Id
		  into	par_nbid
		  from  ( select Netblock_Id, Ip_Address
			    from jazzhands.netblock
			   where
			   	in_IpAddress <<= ip_address
			    and is_single_address = 'N'
				and netblock_type = in_netblock_type
				and ip_universe_id = in_ip_universe_id
			    and 
					(in_is_single_address = 'Y' AND can_subnet = 'Y' AND
						(in_Netmask_Bits IS NULL 
							OR masklen(Ip_Address) = in_Netmask_Bits))
				and (in_netblock_id IS NULL OR
					netblock_id != in_netblock_id)
				and netblock_id not IN (
					select parent_netblock_id from jazzhands.netblock 
						where is_single_address = 'N'
						and parent_netblock_id is not null
				)
			order by masklen(ip_address) desc
		) subq LIMIT 1;

		IF can_fix_can_subnet AND par_nbid IS NOT NULL THEN
			UPDATE netblock SET can_subnet = 'N' where netblock_id = par_nbid;
		END IF;
	END IF;


	return par_nbid;
END;
$function$
;

-- DONE WITH proc netblock_utils.find_best_parent_id -> find_best_parent_id 
--------------------------------------------------------------------

-- Dropping obsoleted sequences....


-- Dropping obsoleted audit sequences....


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
-- triggers


-- Clean Up
SELECT schema_support.replay_saved_grants();
SELECT schema_support.replay_object_recreates();
GRANT select on all tables in schema jazzhands to ro_role;
GRANT insert,update,delete on all tables in schema jazzhands to iud_role;
GRANT select on all sequences in schema jazzhands to ro_role;
GRANT usage on all sequences in schema jazzhands to iud_role;
SELECT schema_support.end_maintenance();
