--
-- Copyright (c) 2017 Todd Kover
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

	--scan-tables
	--suffix
	v075
	val_ip_group_protocol:val_shared_netblock_protocol
	ip_group:shared_netblock
	ip_group_network_interface:shared_netblock_network_int
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance();
select timeofday(), now();
CREATE SCHEMA rack_utils AUTHORIZATION jazzhands;
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
-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_last_changed');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_last_changed ( relation text, schema text, debug boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_last_changed(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SET search_path TO schema_support
AS $function$
DECLARE
	audsch	text;
	rk	char;
	rv	timestamp;
	ts	timestamp;
	obj	text;
	objaud text;
	objkind text;
	objschema text;
BEGIN
	SELECT	audit_schema
	INTO	audsch
	FROM	schema_support.schema_audit_map m
	WHERE	m.schema = relation_last_changed.schema;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Schema % not configured for this', schema;
	END IF;

	SELECT 	relkind
	INTO	rk
	FROM	pg_catalog.pg_class c
		JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
	WHERE	n.nspname = relation_last_changed.schema
	AND	c.relname = relation_last_changed.relation;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'No such object %.%', schema, relation;
	END IF;

	IF rk = 'r' THEN
		EXECUTE 'SELECT max(pg_xact_commit_timestamp(xmin))
			FROM '||quote_ident(audsch)||'.'|| quote_ident(relation)
		INTO rv;
		IF rv IS NULL THEN
			EXECUTE '
				SELECT	max("aud#timestamp")
				FROM	'||quote_ident(audsch)||'.'||quote_ident(relation)
			INTO rv;
		END IF;

		IF rv IS NULL THEN
			RETURN '-infinity'::interval;
		ELSE
			RETURN rv;
		END IF;
	END IF;

	IF rk = 'v' OR rk = 'm' THEN
		FOR obj,objaud,objkind, objschema IN WITH RECURSIVE recur AS (
                SELECT distinct rewrite.ev_class as root_oid, d.refobjid as oid
                FROM pg_depend d
                    JOIN pg_rewrite rewrite ON d.objid = rewrite.oid
                    JOIN pg_class c on rewrite.ev_class = c.oid
                    JOIN pg_namespace n on n.oid = c.relnamespace
                WHERE c.relname = relation
                AND n.nspname = relation_last_changed.schema
                AND d.refobjsubid > 0
            UNION ALL
                SELECT recur.root_oid, d.refobjid as oid
                FROM pg_depend d
                    JOIN pg_rewrite rewrite ON d.objid = rewrite.oid
                    JOIN pg_class c on rewrite.ev_class = c.oid
                JOIN recur ON recur.oid = rewrite.ev_class
                AND d.refobjsubid > 0
		AND c.relkind != 'm'
            ), list AS ( select distinct m.audit_schema, c.relname, c.relkind, n.nspname as relschema, recur.*
                FROM pg_class c
                    JOIN recur on recur.oid = c.oid
                    JOIN pg_namespace n on c.relnamespace = n.oid
                    JOIN schema_support.schema_audit_map m
                        ON m.schema = n.nspname
                WHERE relkind IN ('r', 'm')
		) SELECT relname, audit_schema, relkind, relschema from list
		LOOP
			-- if there is no audit table, assume its kept current.  This is
			-- likely some sort of cache table.  XXX - should probably be
			-- updated to use the materialized view update bits
			BEGIN
				IF objkind = 'r' THEN
					EXECUTE 'SELECT max(pg_xact_commit_timestamp(xmin))
						FROM '||quote_ident(objaud)||'.'|| quote_ident(obj) ||' 
						WHERE "aud#timestamp" > (
								SELECT max("aud#timestamp") 
								FROM '||quote_ident(objaud)||'.'|| quote_ident(obj) || '
							) - ''10 day''::interval'
						INTO ts;
					IF ts IS NULL THEN
						EXECUTE 'SELECT max("aud#timestamp")
							FROM '||quote_ident(objaud)||'.'|| quote_ident(obj)
							INTO ts;
					END IF;
				ELSIF objkind = 'm' THEN
					SELECT refresh INTO ts FROM schema_support.mv_refresh m WHERE m.schema = objschema
						AND m.view = obj;
				ELSE
					RAISE NOTICE 'Unknown object kind % for %.%', objkind, objaud, obj;
				END IF;
				IF debug THEN
					RAISE NOTICE 'schema_support.relation_last_changed(): %.% -> %', objaud, obj, ts;
				END IF;
				IF rv IS NULL OR ts > rv THEN
					rv := ts;
				END IF;
			EXCEPTION WHEN undefined_table THEN
				IF debug THEN
					RAISE NOTICE 'schema_support.relation_last_changed(): skipping %.%', schema, obj;
				END IF;
			END;
		END LOOP;
		RETURN rv;
	END IF;

	RAISE EXCEPTION 'Unable to process relkind %', rk;
END;
$function$
;

--
-- Process middle (non-trigger) schema backend_utils
--
--
-- Process middle (non-trigger) schema rack_utils
--
-- New function
CREATE OR REPLACE FUNCTION rack_utils.set_rack_location(rack_id integer, device_id integer DEFAULT NULL::integer, component_id integer DEFAULT NULL::integer, rack_u_offset_of_device_top integer DEFAULT NULL::integer, rack_side character varying DEFAULT 'FRONT'::character varying, allow_duplicates boolean DEFAULT true)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	rid		ALIAS FOR	rack_id;
	devid	ALIAS FOR	device_id;
	cid		ALIAS FOR	component_id;
	rack_u	ALIAS FOR	rack_u_offset_of_device_top;
	side	ALIAS FOR	rack_side;
	rlid	jazzhands.rack_location.rack_location_id%TYPE;
	rec		RECORD;
	tally	integer;
BEGIN
	IF rack_id IS NULL THEN
		RAISE 'rack_id must be specified to rack_utils.set_rack_location()';
	END IF;

	SELECT
		rl.rack_location_id INTO rlid
	FROM
		rack_location rl
	WHERE
		rl.rack_id = rid AND
		rl.rack_u_offset_of_device_top IS NOT DISTINCT FROM rack_u AND
		rl.rack_side = side;
	
	IF NOT FOUND THEN
		INSERT INTO rack_location (
			rack_id,
			rack_u_offset_of_device_top,
			rack_side
		) VALUES (
			rid,
			rack_u,
			side
		) RETURNING rack_location_id INTO rlid;
	END IF;
	
	IF device_id IS NOT NULL THEN
		SELECT * INTO rec FROM device d WHERE d.device_id = devid;
		IF rec.rack_location_id IS DISTINCT FROM rlid THEN
			UPDATE device d SET rack_location_id = rlid WHERE
				d.device_id = devid;
			BEGIN
				DELETE FROM rack_location rl WHERE rl.rack_location_id = 
					rec.rack_location_id;
			EXCEPTION
				WHEN foreign_key_violation THEN
					NULL;
			END;
		END IF;
	END IF;

	IF component_id IS NOT NULL THEN
		SELECT * INTO rec FROM component c WHERE d.component_id = cid;
		IF rec.rack_location_id IS DISTINCT FROM rlid THEN
			UPDATE component c SET rack_location_id = rlid WHERE
				c.component_id = cid;
			BEGIN
				DELETE FROM rack_location rl WHERE rl.rack_location_id = 
					rec.rack_location_id;
			EXCEPTION
				WHEN foreign_key_violation THEN
					NULL;
			END;
		END IF;
	END IF;
	RETURN rlid;
END;
$function$
;

-- Creating new sequences....
CREATE SEQUENCE shared_netblock_shared_netblock_id_seq;


--------------------------------------------------------------------
-- DEALING WITH TABLE val_ip_group_protocol
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_ip_group_protocol', 'val_shared_netblock_protocol');
-- transfering grants from old object to new
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_ip_group_protocol', 'val_ip_group_protocol');

-- FOREIGN KEYS FROM
ALTER TABLE ip_group DROP CONSTRAINT IF EXISTS fk_ip_grp_ip_grp_proto;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_ip_group_protocol');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_ip_group_protocol DROP CONSTRAINT IF EXISTS pk_val_ip_group_protocol;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_ip_group_protocol ON jazzhands.val_ip_group_protocol;
DROP TRIGGER IF EXISTS trigger_audit_val_ip_group_protocol ON jazzhands.val_ip_group_protocol;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_ip_group_protocol');
---- BEGIN audit.val_ip_group_protocol TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_ip_group_protocol', 'val_shared_netblock_protocol');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_ip_group_protocol');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.val_ip_group_protocol DROP CONSTRAINT IF EXISTS val_ip_group_protocol_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_val_ip_group_protocol_pk_val_ip_group_protocol";
DROP INDEX IF EXISTS "audit"."val_ip_group_protocol_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.val_ip_group_protocol TEARDOWN


ALTER TABLE val_ip_group_protocol RENAME TO val_ip_group_protocol_v075;
ALTER TABLE audit.val_ip_group_protocol RENAME TO val_ip_group_protocol_v075;

CREATE TABLE val_shared_netblock_protocol
(
	shared_netblock_protocol	character(18) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
ALTER SEQUENCE audit.val_ip_group_protocol_seq  RENAME TO val_shared_netblock_protocol_seq;
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_shared_netblock_protocol', false);
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_shared_netblock_protocol');
INSERT INTO val_shared_netblock_protocol (
	shared_netblock_protocol,		-- new column (shared_netblock_protocol)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	ip_group_protocol,		-- new column (shared_netblock_protocol)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_ip_group_protocol_v075;

INSERT INTO audit.val_shared_netblock_protocol (
	shared_netblock_protocol,		-- new column (shared_netblock_protocol)
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
	ip_group_protocol,		-- new column (shared_netblock_protocol)
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
FROM audit.val_ip_group_protocol_v075;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_shared_netblock_protocol ADD CONSTRAINT pk_val_shared_netblock_protoco PRIMARY KEY (shared_netblock_protocol);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_shared_netblock_protocol and shared_netblock
-- Skipping this FK since column does not exist yet
--ALTER TABLE shared_netblock
--	ADD CONSTRAINT fk_shrdnet_shrdnet_proto
--	FOREIGN KEY (shared_netblock_protocol) REFERENCES val_shared_netblock_protocol(shared_netblock_protocol);


-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_shared_netblock_protocol');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'val_shared_netblock_protocol');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_shared_netblock_protocol');
DROP TABLE IF EXISTS val_ip_group_protocol_v075;
DROP TABLE IF EXISTS audit.val_ip_group_protocol_v075;
-- DONE DEALING WITH TABLE val_shared_netblock_protocol
--------------------------------------------------------------------
--
-- Skipping val_shared_netblock_protocol as its been renamed to val_ip_group_protocol
--

--------------------------------------------------------------------
-- DEALING WITH TABLE ip_group
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'ip_group', 'shared_netblock');
-- transfering grants from old object to new
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'ip_group', 'ip_group');

-- FOREIGN KEYS FROM
ALTER TABLE ip_group_network_interface DROP CONSTRAINT IF EXISTS fk_ip_grp_netint_ip_grp_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.ip_group DROP CONSTRAINT IF EXISTS fk_ip_grp_ip_grp_proto;
ALTER TABLE jazzhands.ip_group DROP CONSTRAINT IF EXISTS fk_ip_proto_netblk_coll_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'ip_group');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.ip_group DROP CONSTRAINT IF EXISTS pk_ip_group;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1ip_group";
DROP INDEX IF EXISTS "jazzhands"."xif2ip_group";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_ip_group ON jazzhands.ip_group;
DROP TRIGGER IF EXISTS trigger_audit_ip_group ON jazzhands.ip_group;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'ip_group');
---- BEGIN audit.ip_group TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'ip_group', 'shared_netblock');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'ip_group');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.ip_group DROP CONSTRAINT IF EXISTS ip_group_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_ip_group_pk_ip_group";
DROP INDEX IF EXISTS "audit"."ip_group_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.ip_group TEARDOWN


ALTER TABLE ip_group RENAME TO ip_group_v075;
ALTER TABLE audit.ip_group RENAME TO ip_group_v075;

CREATE TABLE shared_netblock
(
	shared_netblock_id	integer NOT NULL,
	shared_netblock_protocol	character(18) NOT NULL,
	netblock_id	integer  NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
ALTER SEQUENCE audit.ip_group_seq  RENAME TO shared_netblock_seq;
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'shared_netblock', false);
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'shared_netblock');
ALTER TABLE shared_netblock
	ALTER shared_netblock_id
	SET DEFAULT nextval('shared_netblock_shared_netblock_id_seq'::regclass);
INSERT INTO shared_netblock (
	shared_netblock_id,		-- new column (shared_netblock_id)
	shared_netblock_protocol,		-- new column (shared_netblock_protocol)
	netblock_id,		-- new column (netblock_id)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	nextval('shared_netblock_shared_netblock_id_seq'::regclass),		-- new column (shared_netblock_id)
	ip_group_protocol,		-- new column (shared_netblock_protocol)
	NULL,		-- new column (netblock_id)
	v.description,
	v.data_ins_user,
	v.data_ins_date,
	v.data_upd_user,
	v.data_upd_date
FROM ip_group_v075 v
	JOIN netblock_collection_netblock USING (netblock_collection_id);

INSERT INTO audit.shared_netblock (
	shared_netblock_id,		-- new column (shared_netblock_id)
	shared_netblock_protocol,		-- new column (shared_netblock_protocol)
	netblock_id,		-- new column (netblock_id)
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
	ip_group_id,		-- new column (shared_netblock_id)
	ip_group_protocol,	-- new column (shared_netblock_protocol)
	NULL,		-- new column (netblock_id)
	v.description,
	v.data_ins_user,
	v.data_ins_date,
	v.data_upd_user,
	v.data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM audit.ip_group_v075 v
	JOIN netblock_collection_netblock USING (netblock_collection_id);

ALTER TABLE shared_netblock
	ALTER shared_netblock_id
	SET DEFAULT nextval('shared_netblock_shared_netblock_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE shared_netblock ADD CONSTRAINT pk_shared_netblock PRIMARY KEY (shared_netblock_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1shared_netblock ON shared_netblock USING btree (shared_netblock_protocol);
CREATE INDEX xif2shared_netblock ON shared_netblock USING btree (netblock_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between shared_netblock and shared_netblock_network_int
-- Skipping this FK since column does not exist yet
--ALTER TABLE shared_netblock_network_int
--	ADD CONSTRAINT fk_shrdnet_netint_shrdnet_id
--	FOREIGN KEY (shared_netblock_id) REFERENCES shared_netblock(shared_netblock_id);


-- FOREIGN KEYS TO
-- consider FK shared_netblock and netblock
ALTER TABLE shared_netblock
	ADD CONSTRAINT fk_shared_net_netblock_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
-- consider FK shared_netblock and val_shared_netblock_protocol
ALTER TABLE shared_netblock
	ADD CONSTRAINT fk_shrdnet_shrdnet_proto
	FOREIGN KEY (shared_netblock_protocol) REFERENCES val_shared_netblock_protocol(shared_netblock_protocol);

-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'shared_netblock');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'shared_netblock');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'shared_netblock');
ALTER SEQUENCE shared_netblock_shared_netblock_id_seq
	 OWNED BY shared_netblock.shared_netblock_id;
DROP TABLE IF EXISTS ip_group_v075;
DROP TABLE IF EXISTS audit.ip_group_v075;
-- DONE DEALING WITH TABLE shared_netblock
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE ip_group_network_interface
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'ip_group_network_interface', 'shared_netblock_network_int');
-- transfering grants from old object to new
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'ip_group_network_interface', 'ip_group_network_interface');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.ip_group_network_interface DROP CONSTRAINT IF EXISTS fk_ip_grp_netint_ip_grp_id;
ALTER TABLE jazzhands.ip_group_network_interface DROP CONSTRAINT IF EXISTS fk_ipgrp_netint_netint_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'ip_group_network_interface');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.ip_group_network_interface DROP CONSTRAINT IF EXISTS pk_ip_group_network_interface;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1ip_group_network_interface";
DROP INDEX IF EXISTS "jazzhands"."xif2ip_group_network_interface";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_ip_group_network_interface ON jazzhands.ip_group_network_interface;
DROP TRIGGER IF EXISTS trigger_audit_ip_group_network_interface ON jazzhands.ip_group_network_interface;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'ip_group_network_interface');
---- BEGIN audit.ip_group_network_interface TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'ip_group_network_interface', 'shared_netblock_network_int');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'ip_group_network_interface');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.ip_group_network_interface DROP CONSTRAINT IF EXISTS ip_group_network_interface_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_ip_group_network_interface_pk_ip_group_network_interface";
DROP INDEX IF EXISTS "audit"."ip_group_network_interface_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.ip_group_network_interface TEARDOWN


ALTER TABLE ip_group_network_interface RENAME TO ip_group_network_interface_v075;
ALTER TABLE audit.ip_group_network_interface RENAME TO ip_group_network_interface_v075;

CREATE TABLE shared_netblock_network_int
(
	shared_netblock_id	integer NOT NULL,
	network_interface_id	integer NOT NULL,
	priority	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
ALTER SEQUENCE audit.ip_group_network_interface_seq  RENAME TO shared_netblock_network_int_seq;
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'shared_netblock_network_int', false);
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'shared_netblock_network_int');
INSERT INTO shared_netblock_network_int (
	shared_netblock_id,		-- new column (shared_netblock_id)
	network_interface_id,
	priority,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	NULL,		-- new column (shared_netblock_id)
	network_interface_id,
	priority,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM ip_group_network_interface_v075;

INSERT INTO audit.shared_netblock_network_int (
	shared_netblock_id,		-- new column (shared_netblock_id)
	network_interface_id,
	priority,
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
	NULL,		-- new column (shared_netblock_id)
	network_interface_id,
	priority,
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
FROM audit.ip_group_network_interface_v075;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE shared_netblock_network_int ADD CONSTRAINT pk_ip_group_network_interface PRIMARY KEY (shared_netblock_id, network_interface_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1shared_netblock_network_in ON shared_netblock_network_int USING btree (shared_netblock_id);
CREATE INDEX xif2shared_netblock_network_in ON shared_netblock_network_int USING btree (network_interface_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK shared_netblock_network_int and network_interface
ALTER TABLE shared_netblock_network_int
	ADD CONSTRAINT fk_shrdnet_netint_netint_id
	FOREIGN KEY (network_interface_id) REFERENCES network_interface(network_interface_id);
-- consider FK shared_netblock_network_int and shared_netblock
ALTER TABLE shared_netblock_network_int
	ADD CONSTRAINT fk_shrdnet_netint_shrdnet_id
	FOREIGN KEY (shared_netblock_id) REFERENCES shared_netblock(shared_netblock_id);

-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'shared_netblock_network_int');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'shared_netblock_network_int');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'shared_netblock_network_int');
DROP TABLE IF EXISTS ip_group_network_interface_v075;
DROP TABLE IF EXISTS audit.ip_group_network_interface_v075;
-- DONE DEALING WITH TABLE shared_netblock_network_int
--------------------------------------------------------------------
--
-- Skipping shared_netblock as its been renamed to ip_group
--

--
-- Skipping shared_netblock_network_int as its been renamed to ip_group_network_interface
--

--------------------------------------------------------------------
-- DEALING WITH TABLE v_network_interface_trans
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_network_interface_trans', 'v_network_interface_trans');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_network_interface_trans');
DROP VIEW IF EXISTS jazzhands.v_network_interface_trans;
CREATE VIEW jazzhands.v_network_interface_trans AS
 SELECT network_interface.network_interface_id,
    network_interface.device_id,
    network_interface.network_interface_name,
    network_interface.description,
    network_interface.parent_network_interface_id,
    network_interface.parent_relation_type,
    network_interface.netblock_id,
    network_interface.physical_port_id,
    network_interface.slot_id,
    network_interface.logical_port_id,
    network_interface.network_interface_type,
    network_interface.is_interface_up,
    network_interface.mac_addr,
    network_interface.should_monitor,
    network_interface.provides_nat,
    network_interface.should_manage,
    network_interface.provides_dhcp,
    network_interface.data_ins_user,
    network_interface.data_ins_date,
    network_interface.data_upd_user,
    network_interface.data_upd_date
   FROM network_interface;

select schema_support.prepare_for_object_replay();
delete from __recreate where type = 'view' and object = 'v_network_interface_trans';
-- DONE DEALING WITH TABLE v_network_interface_trans
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_netblock_coll_expanded
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_netblock_coll_expanded');
DROP VIEW IF EXISTS jazzhands.v_netblock_coll_expanded;
CREATE VIEW jazzhands.v_netblock_coll_expanded AS
 WITH RECURSIVE netblock_coll_recurse(level, root_netblock_collection_id, netblock_collection_id, array_path, rvs_array_path, cycle) AS (
         SELECT 0 AS level,
            nc.netblock_collection_id AS root_netblock_collection_id,
            nc.netblock_collection_id,
            ARRAY[nc.netblock_collection_id] AS array_path,
            ARRAY[nc.netblock_collection_id] AS rvs_array_path,
            false AS bool
           FROM netblock_collection nc
        UNION ALL
         SELECT x.level + 1 AS level,
            x.root_netblock_collection_id,
            nch.netblock_collection_id,
            x.array_path || nch.netblock_collection_id AS array_path,
            nch.netblock_collection_id || x.rvs_array_path AS rvs_array_path,
            nch.netblock_collection_id = ANY (x.array_path) AS cycle
           FROM netblock_coll_recurse x
             JOIN netblock_collection_hier nch ON x.netblock_collection_id = nch.child_netblock_collection_id
          WHERE NOT x.cycle
        )
 SELECT netblock_coll_recurse.level,
    netblock_coll_recurse.netblock_collection_id,
    netblock_coll_recurse.root_netblock_collection_id,
    array_to_string(netblock_coll_recurse.array_path, '/'::text) AS text_path,
    netblock_coll_recurse.array_path,
    netblock_coll_recurse.rvs_array_path
   FROM netblock_coll_recurse;

-- DONE DEALING WITH TABLE v_netblock_coll_expanded
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_dns_domain_nouniverse
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_dns_domain_nouniverse');
DROP VIEW IF EXISTS jazzhands.v_dns_domain_nouniverse;
CREATE VIEW jazzhands.v_dns_domain_nouniverse AS
 SELECT dns_domain.dns_domain_id,
    dns_domain.soa_name,
    dns_domain.soa_class,
    dns_domain.soa_ttl,
    dns_domain.soa_serial,
    dns_domain.soa_refresh,
    dns_domain.soa_retry,
    dns_domain.soa_expire,
    dns_domain.soa_minimum,
    dns_domain.soa_mname,
    dns_domain.soa_rname,
    dns_domain.parent_dns_domain_id,
    dns_domain.should_generate,
    dns_domain.last_generated,
    dns_domain.dns_domain_type,
    dns_domain.data_ins_user,
    dns_domain.data_ins_date,
    dns_domain.data_upd_user,
    dns_domain.data_upd_date
   FROM dns_domain;

-- DONE DEALING WITH TABLE v_dns_domain_nouniverse
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
SELECT schema_support.replay_object_recreates();
--
-- Process drops in jazzhands
--
-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'ins_x509_certificate');
CREATE OR REPLACE FUNCTION jazzhands.ins_x509_certificate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	key	private_key.private_key_id%TYPE;
	csr	certificate_signing_request.certificate_signing_request_id%TYPE;
	crt	x509_signed_certificate.x509_signed_certificate_id%TYPE;
BEGIN
	IF NEW.private_key IS NOT NULL THEN
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
		) RETURNING private_key_id INTO key;
		NEW.x509_cert_id := key;
	END IF;

	IF NEW.certificate_sign_req IS NOT NULL THEN
		INSERT INTO certificate_signing_request (
			friendly_name,
			subject,
			certificate_signing_request,
			private_key_id
		) VALUES (
			NEW.friendly_name,
			NEW.subject,
			NEW.certificate_sign_req,
			key
		) RETURNING certificate_signing_request_id INTO csr;
		IF NEW.x509_cert_id IS NULL THEN
			NEW.x509_cert_id := csr;
		END IF;
	END IF;

	IF NEW.public_key IS NOT NULL THEN
		INSERT INTO x509_signed_certificate (
			friendly_name,
			is_active,
			is_certificate_authority,
			signing_cert_id,
			x509_ca_cert_serial_number,
			public_key,
			subject,
			subject_key_identifier,
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
			NEW.is_active,
			NEW.is_certificate_authority,
			NEW.signing_cert_id,
			NEW.x509_ca_cert_serial_number,
			NEW.public_key,
			NEW.subject,
			NEW.subject_key_identifier,
			NEW.valid_from,
			NEW.valid_to,
			NEW.x509_revocation_date,
			NEW.x509_revocation_reason,
			NEW.ocsp_uri,
			NEW.crl_uri,
			key,
			csr
		) RETURNING x509_signed_certificate_id INTO crt;
		NEW.x509_cert_id := crt;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'upd_x509_certificate');
CREATE OR REPLACE FUNCTION jazzhands.upd_x509_certificate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	upq	TEXT[];
	crt	x509_signed_certificate%ROWTYPE;
	key private_key.private_key_id%TYPE;
BEGIN
	SELECT * INTO crt FROM x509_signed_certificate
	WHERE x509_signed_certificate_id = OLD.x509_cert_id;

	IF OLD.x509_cert_id != NEW.x509_cert_id THEN
		RAISE EXCEPTION 'Can not change x509_cert_id' USING ERRCODE = 'invalid_parameter_value';
	END IF;

	key := crt.private_key_id;

	IF crt.private_key_ID IS NULL AND NEW.private_key IS NOT NULL THEN
		WITH ins AS (
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
			) RETURNING *
		), upd AS (
			UPDATE x509_signed_certificate
			SET private_key_id = ins.private_key_id
			WHERE x509_signed_certificate_id = OLD.x509_cert_id
			RETURNING *
		)  SELECT private_key_id INTO key FROM upd;
	ELSIF crt.private_key_id IS NOT NULL AND NEW.private_key IS NULL THEN
		UPDATE x509_signed_certificate
			SET private_key_id = NULL
			WHERE x509_signed_certificate_id = OLD.x509_cert_id;
		BEGIN
			DELETE FROM private_key where private_key_id = crt.private_key_id;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	ELSE
		IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
			upq := array_append(upq,
				'is_active = ' || quote_literal(NEW.is_active)
			);
		END IF;

		IF OLD.subject_key_identifier IS DISTINCT FROM NEW.subject_key_identifier THEN
			upq := array_append(upq,
				'subject_key_identifier = ' || quote_nullable(NEW.subject_key_identifier)
			);
		END IF;

		IF OLD.private_key IS DISTINCT FROM NEW.private_key THEN
			upq := array_append(upq,
				'private_key = ' || quote_nullable(NEW.private_key)
			);
		END IF;

		IF OLD.passphrase IS DISTINCT FROM NEW.passphrase THEN
			upq := array_append(upq,
				'passphrase = ' || quote_nullable(NEW.passphrase)
			);
		END IF;

		IF OLD.encryption_key_id IS DISTINCT FROM NEW.encryption_key_id THEN
			upq := array_append(upq,
				'encryption_key_id = ' || quote_nullable(NEW.encryption_key_id)
			);
		END IF;

		IF array_length(upq, 1) > 0 THEN
			EXECUTE 'UPDATE private_key SET '
				|| array_to_string(upq, ', ')
				|| ' WHERE private_key_id = '
				|| crt.private_key_id;
		END IF;
	END IF;

	upq := NULL;
	IF crt.certificate_signing_request_id IS NULL AND NEW.certificate_sign_req IS NOT NULL THEN
		WITH ins AS (
			INSERT INTO certificate_signing_request (
				friendly_name,
				subject,
				certificate_signing_request,
				private_key_id
			) VALUES (
				NEW.friendly_name,
				NEW.subject,
				NEW.certificate_sign_req,
				key
			) RETURNING *
		) UPDATE x509_signed_certificate
		SET certificate_signing_request_id = ins.certificate_signing_request_id
		WHERE x509_signed_certificate_id = OLD.x509_cert_id;
	ELSIF crt.certificate_signing_request_id IS NOT NULL AND
				NEW.certificate_sign_req IS NULL THEN
		-- if its removed, we still keep the csr/key link
		WITH del AS (
			UPDATE x509_signed_certificate
			SET certificate_signing_request = NULL
			WHERE x509_signed_certificate_id = OLD.x509_cert_id
			RETURNING *
		) DELETE FROM certificate_signing_request
		WHERE certificate_signing_request_id =
			crt.certificate_signing_request_id;
	ELSE
		IF OLD.friendly_name IS DISTINCT FROM NEW.friendly_name THEN
			upq := array_append(upq,
				'friendly_name = ' || quote_literal(NEW.friendly_name)
			);
		END IF;

		IF OLD.subject IS DISTINCT FROM NEW.subject THEN
			upq := array_append(upq,
				'subject = ' || quote_literal(NEW.subject)
			);
		END IF;

		IF OLD.certificate_sign_req IS DISTINCT FROM
				NEW.certificate_sign_req THEN
			upq := array_append(upq,
				'certificate_signing_request = ' ||
					quote_literal(NEW.certificate_sign_req)
			);
		END IF;

		IF array_length(upq, 1) > 0 THEN
			EXECUTE 'UPDATE certificate_signing_request SET '
				|| array_to_string(upq, ', ')
				|| ' WHERE x509_signed_certificate_id = '
				|| crt.x509_signed_certificate_id;
		END IF;
	END IF;

	upq := NULL;
	IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
		upq := array_append(upq,
			'is_active = ' || quote_literal(NEW.is_active)
		);
	END IF;
	IF OLD.friendly_name IS DISTINCT FROM NEW.friendly_name THEN
		upq := array_append(upq,
			'friendly_name = ' || quote_literal(NEW.friendly_name)
		);
	END IF;
	IF OLD.subject IS DISTINCT FROM NEW.subject THEN
		upq := array_append(upq,
			'subject = ' || quote_literal(NEW.subject)
		);
	END IF;
	IF OLD.subject_key_identifier IS DISTINCT FROM NEW.subject_key_identifier THEN
		upq := array_append(upq,
			'subject_key_identifier = ' || quote_nullable(NEW.subject_key_identifier)
		);
	END IF;
	IF OLD.is_certificate_authority IS DISTINCT FROM NEW.is_certificate_authority THEN
		upq := array_append(upq,
			'is_certificate_authority = ' || quote_nullable(NEW.is_certificate_authority)
		);
	END IF;
	IF OLD.signing_cert_id IS DISTINCT FROM NEW.signing_cert_id THEN
		upq := array_append(upq,
			'signing_cert_id = ' || quote_nullable(NEW.signing_cert_id)
		);
	END IF;
	IF OLD.x509_ca_cert_serial_number IS DISTINCT FROM NEW.x509_ca_cert_serial_number THEN
		upq := array_append(upq,
			'x509_ca_cert_serial_number = ' || quote_nullable(NEW.x509_ca_cert_serial_number)
		);
	END IF;
	IF OLD.public_key IS DISTINCT FROM NEW.public_key THEN
		upq := array_append(upq,
			'public_key = ' || quote_nullable(NEW.public_key)
		);
	END IF;
	IF OLD.valid_from IS DISTINCT FROM NEW.valid_from THEN
		upq := array_append(upq,
			'valid_from = ' || quote_nullable(NEW.valid_from)
		);
	END IF;
	IF OLD.valid_to IS DISTINCT FROM NEW.valid_to THEN
		upq := array_append(upq,
			'valid_to = ' || quote_nullable(NEW.valid_to)
		);
	END IF;
	IF OLD.x509_revocation_date IS DISTINCT FROM NEW.x509_revocation_date THEN
		upq := array_append(upq,
			'x509_revocation_date = ' || quote_nullable(NEW.x509_revocation_date)
		);
	END IF;
	IF OLD.x509_revocation_reason IS DISTINCT FROM NEW.x509_revocation_reason THEN
		upq := array_append(upq,
			'x509_revocation_reason = ' || quote_nullable(NEW.x509_revocation_reason)
		);
	END IF;
	IF OLD.ocsp_uri IS DISTINCT FROM NEW.ocsp_uri THEN
		upq := array_append(upq,
			'ocsp_uri = ' || quote_nullable(NEW.ocsp_uri)
		);
	END IF;
	IF OLD.crl_uri IS DISTINCT FROM NEW.crl_uri THEN
		upq := array_append(upq,
			'crl_uri = ' || quote_nullable(NEW.crl_uri)
		);
	END IF;

	IF array_length(upq, 1) > 0 THEN
		EXECUTE 'UPDATE x509_signed_certificate SET '
			|| array_to_string(upq, ', ')
			|| ' WHERE x509_signed_certificate_id = '
			|| NEW.x509_cert_id;
	END IF;

	RETURN NEW;
END;
$function$
;

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
-- Process drops in backend_utils
--
--
-- Process drops in schema_support
--
-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_last_changed');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_last_changed ( relation text, schema text, debug boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_last_changed(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SET search_path TO schema_support
AS $function$
DECLARE
	audsch	text;
	rk	char;
	rv	timestamp;
	ts	timestamp;
	obj	text;
	objaud text;
	objkind text;
	objschema text;
BEGIN
	SELECT	audit_schema
	INTO	audsch
	FROM	schema_support.schema_audit_map m
	WHERE	m.schema = relation_last_changed.schema;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Schema % not configured for this', schema;
	END IF;

	SELECT 	relkind
	INTO	rk
	FROM	pg_catalog.pg_class c
		JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
	WHERE	n.nspname = relation_last_changed.schema
	AND	c.relname = relation_last_changed.relation;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'No such object %.%', schema, relation;
	END IF;

	IF rk = 'r' THEN
		EXECUTE 'SELECT max(pg_xact_commit_timestamp(xmin))
			FROM '||quote_ident(audsch)||'.'|| quote_ident(relation)
		INTO rv;
		IF rv IS NULL THEN
			EXECUTE '
				SELECT	max("aud#timestamp")
				FROM	'||quote_ident(audsch)||'.'||quote_ident(relation)
			INTO rv;
		END IF;

		IF rv IS NULL THEN
			RETURN '-infinity'::interval;
		ELSE
			RETURN rv;
		END IF;
	END IF;

	IF rk = 'v' OR rk = 'm' THEN
		FOR obj,objaud,objkind, objschema IN WITH RECURSIVE recur AS (
                SELECT distinct rewrite.ev_class as root_oid, d.refobjid as oid
                FROM pg_depend d
                    JOIN pg_rewrite rewrite ON d.objid = rewrite.oid
                    JOIN pg_class c on rewrite.ev_class = c.oid
                    JOIN pg_namespace n on n.oid = c.relnamespace
                WHERE c.relname = relation
                AND n.nspname = relation_last_changed.schema
                AND d.refobjsubid > 0
            UNION ALL
                SELECT recur.root_oid, d.refobjid as oid
                FROM pg_depend d
                    JOIN pg_rewrite rewrite ON d.objid = rewrite.oid
                    JOIN pg_class c on rewrite.ev_class = c.oid
                JOIN recur ON recur.oid = rewrite.ev_class
                AND d.refobjsubid > 0
		AND c.relkind != 'm'
            ), list AS ( select distinct m.audit_schema, c.relname, c.relkind, n.nspname as relschema, recur.*
                FROM pg_class c
                    JOIN recur on recur.oid = c.oid
                    JOIN pg_namespace n on c.relnamespace = n.oid
                    JOIN schema_support.schema_audit_map m
                        ON m.schema = n.nspname
                WHERE relkind IN ('r', 'm')
		) SELECT relname, audit_schema, relkind, relschema from list
		LOOP
			-- if there is no audit table, assume its kept current.  This is
			-- likely some sort of cache table.  XXX - should probably be
			-- updated to use the materialized view update bits
			BEGIN
				IF objkind = 'r' THEN
					EXECUTE 'SELECT max(pg_xact_commit_timestamp(xmin))
						FROM '||quote_ident(objaud)||'.'|| quote_ident(obj) ||' 
						WHERE "aud#timestamp" > (
								SELECT max("aud#timestamp") 
								FROM '||quote_ident(objaud)||'.'|| quote_ident(obj) || '
							) - ''10 day''::interval'
						INTO ts;
					IF ts IS NULL THEN
						EXECUTE 'SELECT max("aud#timestamp")
							FROM '||quote_ident(objaud)||'.'|| quote_ident(obj)
							INTO ts;
					END IF;
				ELSIF objkind = 'm' THEN
					SELECT refresh INTO ts FROM schema_support.mv_refresh m WHERE m.schema = objschema
						AND m.view = obj;
				ELSE
					RAISE NOTICE 'Unknown object kind % for %.%', objkind, objaud, obj;
				END IF;
				IF debug THEN
					RAISE NOTICE 'schema_support.relation_last_changed(): %.% -> %', objaud, obj, ts;
				END IF;
				IF rv IS NULL OR ts > rv THEN
					rv := ts;
				END IF;
			EXCEPTION WHEN undefined_table THEN
				IF debug THEN
					RAISE NOTICE 'schema_support.relation_last_changed(): skipping %.%', schema, obj;
				END IF;
			END;
		END LOOP;
		RETURN rv;
	END IF;

	RAISE EXCEPTION 'Unable to process relkind %', rk;
END;
$function$
;

--
-- Process drops in rack_utils
--
-- New function
CREATE OR REPLACE FUNCTION rack_utils.set_rack_location(rack_id integer, device_id integer DEFAULT NULL::integer, component_id integer DEFAULT NULL::integer, rack_u_offset_of_device_top integer DEFAULT NULL::integer, rack_side character varying DEFAULT 'FRONT'::character varying, allow_duplicates boolean DEFAULT true)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	rid		ALIAS FOR	rack_id;
	devid	ALIAS FOR	device_id;
	cid		ALIAS FOR	component_id;
	rack_u	ALIAS FOR	rack_u_offset_of_device_top;
	side	ALIAS FOR	rack_side;
	rlid	jazzhands.rack_location.rack_location_id%TYPE;
	rec		RECORD;
	tally	integer;
BEGIN
	IF rack_id IS NULL THEN
		RAISE 'rack_id must be specified to rack_utils.set_rack_location()';
	END IF;

	SELECT
		rl.rack_location_id INTO rlid
	FROM
		rack_location rl
	WHERE
		rl.rack_id = rid AND
		rl.rack_u_offset_of_device_top IS NOT DISTINCT FROM rack_u AND
		rl.rack_side = side;
	
	IF NOT FOUND THEN
		INSERT INTO rack_location (
			rack_id,
			rack_u_offset_of_device_top,
			rack_side
		) VALUES (
			rid,
			rack_u,
			side
		) RETURNING rack_location_id INTO rlid;
	END IF;
	
	IF device_id IS NOT NULL THEN
		SELECT * INTO rec FROM device d WHERE d.device_id = devid;
		IF rec.rack_location_id IS DISTINCT FROM rlid THEN
			UPDATE device d SET rack_location_id = rlid WHERE
				d.device_id = devid;
			BEGIN
				DELETE FROM rack_location rl WHERE rl.rack_location_id = 
					rec.rack_location_id;
			EXCEPTION
				WHEN foreign_key_violation THEN
					NULL;
			END;
		END IF;
	END IF;

	IF component_id IS NOT NULL THEN
		SELECT * INTO rec FROM component c WHERE d.component_id = cid;
		IF rec.rack_location_id IS DISTINCT FROM rlid THEN
			UPDATE component c SET rack_location_id = rlid WHERE
				c.component_id = cid;
			BEGIN
				DELETE FROM rack_location rl WHERE rl.rack_location_id = 
					rec.rack_location_id;
			EXCEPTION
				WHEN foreign_key_violation THEN
					NULL;
			END;
		END IF;
	END IF;
	RETURN rlid;
END;
$function$
;

-- Dropping obsoleted sequences....
DROP SEQUENCE IF EXISTS ip_group_ip_group_id_seq;


-- Dropping obsoleted audit sequences....
DROP SEQUENCE IF EXISTS audit.ip_group_network_interface_seq;
DROP SEQUENCE IF EXISTS audit.ip_group_seq;
DROP SEQUENCE IF EXISTS audit.val_ip_group_protocol_seq;

DROP FUNCTION perform_audit_ip_group();
DROP FUNCTION perform_audit_ip_group_network_interface();
DROP FUNCTION perform_audit_val_ip_group_protocol();

-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
-- index
-- triggers

COMMENT ON SCHEMA rack_utils IS 'part of jazzhands';

DELETE FROM __regrants WHERE object ~ 'ip_group';

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
