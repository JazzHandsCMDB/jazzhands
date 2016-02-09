/*
Invoked:

	--suffix=v68
	--scan-tables
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
-- Process middle (non-trigger) schema token_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('token_utils', 'set_lock_status');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS token_utils.set_lock_status ( p_token_id integer, p_lock_status character, p_unlock_time timestamp with time zone, p_bad_logins integer, p_last_updated timestamp with time zone );
CREATE OR REPLACE FUNCTION token_utils.set_lock_status(p_token_id integer, p_lock_status character, p_unlock_time timestamp with time zone, p_bad_logins integer, p_last_updated timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_cur		token%ROWTYPE;
BEGIN

	IF p_token_id IS NULL THEN
		RAISE EXCEPTION 'Invalid token %', p_token_id
			USING ERRCODE = invalid_parameter_value;
	END IF;

	EXECUTE '
		SELECT *
		FROM token
		WHERE token_id = $1
	' INTO _cur USING p_token_id;

	IF _cur.last_updated <= p_last_updated THEN
		UPDATE token SET
		is_token_locked = p_lock_status,
			token_unlock_time = p_unlock_time,
			bad_logins = p_bad_logins,
			last_updated = p_last_updated
		WHERE
			Token_ID = p_token_id;
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('token_utils', 'set_sequence');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS token_utils.set_sequence ( p_token_id integer, p_token_sequence integer, p_reset_time timestamp without time zone );
CREATE OR REPLACE FUNCTION token_utils.set_sequence(p_token_id integer, p_token_sequence integer, p_reset_time timestamp without time zone DEFAULT NULL::timestamp without time zone)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_cur		token_sequence%ROWTYPE;
BEGIN

	IF p_token_id IS NULL THEN
		RAISE EXCEPTION 'Invalid token %', p_token_id
			USING ERRCODE = invalid_parameter_value;
	END IF;

	EXECUTE '
		SELECT *
		FROM token_sequence
		WHERE token_id = $1
	' INTO _cur USING p_token_id;

	IF _cur.token_id IS NULL THEN
		EXECUTE '
			INSERT INTO token_sequence (
				token_id, token_sequence, last_updated
			) VALUES (
				$1, $2, $3
			);
		' USING p_token_id, p_token_sequence, p_reset_time;
	ELSE
		IF p_reset_time IS NULL THEN
			-- Using this code path, do not reset the sequence back, ever
			UPDATE Token_Sequence SET
				Token_Sequence = p_token_sequence,
				last_updated = now()
			WHERE
				Token_ID = p_token_id
				AND (token_sequence is NULL OR Token_Sequence < p_token_sequence);
		ELSE
			--
			-- Only reset the sequence back if its newer than what's in the
			-- db
			UPDATE Token_Sequence SET
				Token_Sequence = p_token_sequence,
				Last_Updated = p_reset_time
			WHERE Token_ID = p_token_id
			AND Last_Updated <= p_reset_time;
		END IF;
	END IF;
END;
$function$
;

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
--
-- Process middle (non-trigger) schema schema_support
--
--
-- Process middle (non-trigger) schema approval_utils
--
-- Creating new sequences....


--------------------------------------------------------------------
-- DEALING WITH TABLE v_dev_col_user_prop_expanded [6103984]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dev_col_user_prop_expanded', 'v_dev_col_user_prop_expanded');
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'v_dev_col_user_prop_expanded');
DROP VIEW IF EXISTS jazzhands.v_dev_col_user_prop_expanded;
CREATE VIEW jazzhands.v_dev_col_user_prop_expanded AS
 SELECT upo.property_id,
    dchd.device_collection_id,
    a.account_id,
    a.login,
    a.account_status,
    ar.account_realm_id,
    ar.account_realm_name,
    a.is_enabled,
    upo.property_type,
    upo.property_name,
    upo.property_rank,
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
     JOIN v_property upo ON upo.account_collection_id = u.account_collection_id AND (upo.property_type::text = ANY (ARRAY['CCAForceCreation'::character varying, 'CCARight'::character varying, 'ConsoleACL'::character varying, 'RADIUS'::character varying, 'TokenMgmt'::character varying, 'UnixPasswdFileValue'::character varying, 'UserMgmt'::character varying, 'cca'::character varying, 'feed-attributes'::character varying, 'wwwgroup'::character varying, 'HOTPants'::character varying]::text[]))
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
-- DONE DEALING WITH TABLE v_dev_col_user_prop_expanded [6111766]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_hotpants_account_attribute [6104356]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_hotpants_account_attribute', 'v_hotpants_account_attribute');
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'v_hotpants_account_attribute');
DROP VIEW IF EXISTS jazzhands.v_hotpants_account_attribute;
CREATE VIEW jazzhands.v_hotpants_account_attribute AS
 SELECT v_dev_col_user_prop_expanded.property_id,
    v_dev_col_user_prop_expanded.account_id,
    v_dev_col_user_prop_expanded.device_collection_id,
    v_dev_col_user_prop_expanded.login,
    v_dev_col_user_prop_expanded.property_name,
    v_dev_col_user_prop_expanded.property_type,
    v_dev_col_user_prop_expanded.property_value,
    v_dev_col_user_prop_expanded.property_rank,
    v_dev_col_user_prop_expanded.is_boolean
   FROM v_dev_col_user_prop_expanded
     JOIN device_collection USING (device_collection_id)
  WHERE v_dev_col_user_prop_expanded.is_enabled = 'Y'::bpchar AND ((device_collection.device_collection_type::text = ANY (ARRAY['HOTPants-app'::character varying, 'HOTPants'::character varying]::text[])) OR (v_dev_col_user_prop_expanded.property_type::text = ANY (ARRAY['RADIUS'::character varying, 'HOTPants'::character varying]::text[])));

delete from __recreate where type = 'view' and object = 'v_hotpants_account_attribute';
-- DONE DEALING WITH TABLE v_hotpants_account_attribute [6111933]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_hotpants_client [6104351]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_hotpants_client', 'v_hotpants_client');
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'v_hotpants_client');
DROP VIEW IF EXISTS jazzhands.v_hotpants_client;
CREATE VIEW jazzhands.v_hotpants_client AS
 SELECT dc.device_id,
    d.device_name,
    netblock.ip_address,
    p.property_value AS radius_secret
   FROM v_property p
     JOIN v_device_coll_device_expanded dc USING (device_collection_id)
     JOIN device d USING (device_id)
     JOIN network_interface ni USING (device_id)
     JOIN netblock USING (netblock_id)
  WHERE p.property_name::text = 'RadiusSharedSecret'::text AND p.property_type::text = 'HOTPants'::text;

delete from __recreate where type = 'view' and object = 'v_hotpants_client';
-- DONE DEALING WITH TABLE v_hotpants_client [6111928]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_hotpants_dc_attribute [6104363]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_hotpants_dc_attribute', 'v_hotpants_dc_attribute');
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'v_hotpants_dc_attribute');
DROP VIEW IF EXISTS jazzhands.v_hotpants_dc_attribute;
CREATE VIEW jazzhands.v_hotpants_dc_attribute AS
 SELECT v_property.property_id,
    v_property.device_collection_id,
    v_property.property_name,
    v_property.property_type,
    v_property.property_rank,
    v_property.property_value_password_type AS property_value
   FROM v_property
  WHERE v_property.property_name::text = 'PWType'::text AND v_property.property_type::text = 'HOTPants'::text AND v_property.account_collection_id IS NULL;

delete from __recreate where type = 'view' and object = 'v_hotpants_dc_attribute';
-- DONE DEALING WITH TABLE v_hotpants_dc_attribute [6111938]
--------------------------------------------------------------------
--
-- Process trigger procs in jazzhands
--
-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'upd_v_hotpants_token');
CREATE OR REPLACE FUNCTION jazzhands.upd_v_hotpants_token()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	acct_realm_id	account_realm.account_realm_id%TYPE;
BEGIN
	IF OLD.token_sequence IS DISTINCT FROM NEW.token_sequence THEN
		PERFORM token_utils.set_sequence(
			p_token_id := NEW.token_id,
			p_token_sequence := NEW.token_sequence,
			p_reset_time := NEW.last_updated::timestamp
		);
	END IF;

	IF OLD.bad_logins IS DISTINCT FROM NEW.bad_logins THEN
		PERFORM token_utils.set_lock_status(
			p_token_id := NEW.token_id,
			p_lock_status := NEW.is_token_locked,
			p_unlock_time := NEW.token_unlock_time,
			p_bad_logins := NEW.bad_logins,
			p_last_updated :=NEW.last_updated::timestamp
		);
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
-- Process trigger procs in token_utils
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
