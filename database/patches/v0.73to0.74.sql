--
-- Copyright (c) 2016 Todd Kover
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

/*
Invoked:

	--suffix=v74
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
-- Process middle (non-trigger) schema approval_utils
--
--
-- Process middle (non-trigger) schema account_collection_manip
--
--
-- Process middle (non-trigger) schema script_hooks
--
--
-- Process middle (non-trigger) schema schema_support
--
--
-- Process middle (non-trigger) schema backend_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('backend_utils', 'refresh_if_needed');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS backend_utils.refresh_if_needed ( object text );
CREATE OR REPLACE FUNCTION backend_utils.refresh_if_needed(object text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	rk char;
BEGIN
	SELECT  relkind
	INTO    rk
	FROM    pg_catalog.pg_class c
		JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
	WHERE   n.nspname = 'jazzhands'
	AND     c.relname = object;

	-- silently ignore things that are not materialized views
	IF rk = 'm' THEN
		PERFORM schema_support.refresh_mv_if_needed(object, 'jazzhands');
	END IF;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION backend_utils.block_for_opaque_txid(opaqueid text, maxdelay integer DEFAULT NULL::integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO pg_catalog
AS $function$
DECLARE
	count	integer;
BEGIN
	IF opaqueid IS NULL THEN
		RETURN true;
	END IF;
	count := 0;
	WHILE maxdelay IS NULL OR count < maxdelay 
	LOOP
		IF txid_visible_in_snapshot(opaqueid::bigint,txid_current_snapshot()) THEN
			RETURN true;
		END IF;
		count := count + 1;
		PERFORM pg_sleep(1);
	END LOOP;
	RETURN false;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION backend_utils.get_opaque_txid()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	rv	text;
BEGIN
	SELECT txid_current()::text INTO rv;
	RETURN rv;
EXCEPTION WHEN read_only_sql_transaction THEN
	RETURN NULL;
END;
$function$
;

-- Creating new sequences....


--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_components_expanded
DROP VIEW IF EXISTS jazzhands.v_device_components_expanded;
CREATE VIEW jazzhands.v_device_components_expanded AS
 WITH ctf AS (
         SELECT ctcf.component_type_id,
            array_agg(ctcf.component_function ORDER BY ctcf.component_function) AS functions
           FROM component_type_component_func ctcf
          GROUP BY ctcf.component_type_id
        ), ds AS (
         SELECT cp.component_type_id,
            cp.property_value::bigint AS disk_size
           FROM component_property cp
          WHERE cp.component_property_name::text = 'DiskSize'::text AND cp.component_property_type::text = 'disk'::text
        ), ms AS (
         SELECT cp.component_type_id,
            cp.property_value::bigint AS memory_size
           FROM component_property cp
          WHERE cp.component_property_name::text = 'MemorySize'::text AND cp.component_property_type::text = 'memory'::text
        )
 SELECT dc.device_id,
    c.component_id,
    s.slot_id,
    ct.model,
    a.serial_number,
    ctf.functions,
    s.slot_name,
    ms.memory_size,
    ds.disk_size
   FROM v_device_components dc
     JOIN component c ON dc.component_id = c.component_id
     LEFT JOIN asset a ON c.component_id = a.component_id
     JOIN component_type ct USING (component_type_id)
     JOIN ctf USING (component_type_id)
     LEFT JOIN ds USING (component_type_id)
     LEFT JOIN ms USING (component_type_id)
     LEFT JOIN slot s ON c.parent_slot_id = s.slot_id;

-- DONE DEALING WITH TABLE v_device_components_expanded
--------------------------------------------------------------------
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
--
-- Process drops in jazzhands
--
--
-- Process drops in net_manip
--
--
-- Process drops in network_strings
--
--
-- Process drops in time_util
--
--
-- Process drops in dns_utils
--
--
-- Process drops in person_manip
--
--
-- Process drops in auto_ac_manip
--
--
-- Process drops in company_manip
--
--
-- Process drops in token_utils
--
--
-- Process drops in port_support
--
--
-- Process drops in port_utils
--
--
-- Process drops in device_utils
--
--
-- Process drops in netblock_utils
--
--
-- Process drops in netblock_manip
--
--
-- Process drops in physical_address_utils
--
--
-- Process drops in component_utils
--
--
-- Process drops in snapshot_manip
--
--
-- Process drops in lv_manip
--
--
-- Process drops in approval_utils
--
--
-- Process drops in account_collection_manip
--
--
-- Process drops in script_hooks
--
--
-- Process drops in schema_support
--
--
-- Process drops in backend_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('backend_utils', 'refresh_if_needed');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS backend_utils.refresh_if_needed ( object text );
CREATE OR REPLACE FUNCTION backend_utils.refresh_if_needed(object text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	rk char;
BEGIN
	SELECT  relkind
	INTO    rk
	FROM    pg_catalog.pg_class c
		JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
	WHERE   n.nspname = 'jazzhands'
	AND     c.relname = object;

	-- silently ignore things that are not materialized views
	IF rk = 'm' THEN
		PERFORM schema_support.refresh_mv_if_needed(object, 'jazzhands');
	END IF;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION backend_utils.block_for_opaque_txid(opaqueid text, maxdelay integer DEFAULT NULL::integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO pg_catalog
AS $function$
DECLARE
	count	integer;
BEGIN
	IF opaqueid IS NULL THEN
		RETURN true;
	END IF;
	count := 0;
	WHILE maxdelay IS NULL OR count < maxdelay 
	LOOP
		IF txid_visible_in_snapshot(opaqueid::bigint,txid_current_snapshot()) THEN
			RETURN true;
		END IF;
		count := count + 1;
		PERFORM pg_sleep(1);
	END LOOP;
	RETURN false;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION backend_utils.get_opaque_txid()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	rv	text;
BEGIN
	SELECT txid_current()::text INTO rv;
	RETURN rv;
EXCEPTION WHEN read_only_sql_transaction THEN
	RETURN NULL;
END;
$function$
;

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
