/*
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

	--nomaint
	--suffix
	v57
	--scan-tables
	--preschema
	schema_support
	--postschema=jazzhands
	--postschema=netblock_utils
	--postschema=netblock_manip
	dns_record
	v_property
	person_manip.get_unix_uid
	netblock_utils.find_best_parent_id
*/

select now();

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance();

-- Changed function

SELECT schema_support.save_grants_for_replay('schema_support', 'begin_maintenance');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.begin_maintenance ( shouldbesuper boolean );
CREATE OR REPLACE FUNCTION schema_support.begin_maintenance(shouldbesuper boolean DEFAULT true)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE 
	issuper	boolean;
	_tally	integer;
BEGIN
	IF shouldbesuper THEN
		SELECT usesuper INTO issuper FROM pg_user where usename = current_user;
		IF issuper IS false THEN
			RAISE EXCEPTION 'User must be a super user.';
		END IF;
	END IF;
	-- Not sure how reliable this is.
	-- http://www.postgresql.org/docs/9.3/static/monitoring-stats.html
	SELECT count(*)
	  INTO _tally
	  FROM	pg_stat_activity
	 WHERE	pid = pg_backend_pid()
	   AND	query_start = xact_start;
	IF _tally > 0 THEN
		RAISE EXCEPTION 'Must run maintenance in a transaction.';
	END IF;
	RETURN true;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'end_maintenance');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.end_maintenance (  );
CREATE OR REPLACE FUNCTION schema_support.end_maintenance()
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE issuper boolean;
BEGIN
		SELECT usesuper INTO issuper FROM pg_user where usename = current_user;
		IF issuper THEN
			EXECUTE 'ALTER USER ' || current_user || ' NOSUPERUSER';
		END IF;
		RETURN true;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'prepare_for_grant_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.prepare_for_grant_replay (  );
CREATE OR REPLACE FUNCTION schema_support.prepare_for_grant_replay()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_tally integer;
BEGIN
	SELECT	count(*)
	  INTO	_tally
	  FROM	pg_catalog.pg_class
	 WHERE	relname = '__regrants'
	   AND	relpersistence = 't';

	IF _tally = 0 THEN
		CREATE TEMPORARY TABLE IF NOT EXISTS __regrants (id SERIAL, schema text, object text, newname text, regrant text);
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'prepare_for_object_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.prepare_for_object_replay (  );
CREATE OR REPLACE FUNCTION schema_support.prepare_for_object_replay()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_tally integer;
BEGIN
	SELECT	count(*)
	  INTO	_tally
	  FROM	pg_catalog.pg_class
	 WHERE	relname = '__recreate'
	   AND	relpersistence = 't';

	IF _tally = 0 THEN
		CREATE TEMPORARY TABLE IF NOT EXISTS __recreate (id SERIAL, schema text, object text, owner text, type text, ddl text, idargs text);
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_stamp_trigger');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_stamp_trigger ( tbl_schema character varying, table_name character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_stamp_trigger(tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    EXECUTE 'DROP TRIGGER IF EXISTS '
	|| quote_ident('trig_userlog_' || table_name)
	|| ' ON ' || quote_ident(tbl_schema) || '.' || quote_ident(table_name);

    EXECUTE 'CREATE TRIGGER '
	|| quote_ident('trig_userlog_' || table_name)
	|| ' BEFORE INSERT OR UPDATE ON '
	|| quote_ident(tbl_schema) || '.' || quote_ident(table_name)
	|| ' FOR EACH ROW EXECUTE PROCEDURE'
	|| ' schema_support.trigger_ins_upd_generic_func()';
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_stamp_triggers');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_stamp_triggers ( tbl_schema character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_stamp_triggers(tbl_schema character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    DECLARE
	tab RECORD;
    BEGIN
	FOR tab IN 
	    SELECT table_name FROM information_schema.tables
	    WHERE table_schema = tbl_schema AND table_type = 'BASE TABLE'
	    AND table_name NOT LIKE 'aud$%'
	LOOP
	    PERFORM schema_support.rebuild_stamp_trigger
		(tbl_schema, tab.table_name);
	END LOOP;
    END;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'replay_object_recreates');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.replay_object_recreates ( beverbose boolean );
CREATE OR REPLACE FUNCTION schema_support.replay_object_recreates(beverbose boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_tally	integer;
BEGIN
	SELECT	count(*)
	  INTO	_tally
	  FROM	pg_catalog.pg_class
	 WHERE	relname = '__recreate'
	   AND	relpersistence = 't';

	IF _tally > 0 THEN
		FOR _r in SELECT * from __recreate ORDER BY id DESC FOR UPDATE
		LOOP
			IF beverbose THEN
				RAISE NOTICE 'Regrant: %.%', _r.schema, _r.object;
			END IF;
			EXECUTE _r.ddl; 
			IF _r.owner is not NULL THEN
				IF _r.type = 'view' THEN
					EXECUTE 'ALTER VIEW ' || _r.schema || '.' || _r.object ||
						' OWNER TO ' || _r.owner || ';';
				ELSIF _r.type = 'function' THEN
					EXECUTE 'ALTER FUNCTION ' || _r.schema || '.' || _r.object ||
						'(' || _r.idargs || ') OWNER TO ' || _r.owner || ';';
				ELSE
					RAISE EXCEPTION 'Unable to restore grant for %', _r;
				END IF;
			END IF;
			DELETE from __recreate where id = _r.id;
		END LOOP;

		SELECT count(*) INTO _tally from __recreate;
		IF _tally > 0 THEN
			RAISE EXCEPTION '% objects still exist for recreating after a complete loop', _tally;
		ELSE
			DROP TABLE __recreate;
		END IF;
	ELSE
		RAISE NOTICE '**** WARNING: replay_object_recreates did NOT have anything to regrant!';
	END IF;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'replay_saved_grants');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.replay_saved_grants ( beverbose boolean );
CREATE OR REPLACE FUNCTION schema_support.replay_saved_grants(beverbose boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_tally	integer;
BEGIN
	 SELECT  count(*)
      INTO  _tally
      FROM  pg_catalog.pg_class
     WHERE  relname = '__regrants'
       AND  relpersistence = 't';

	IF _tally > 0 THEN
	    FOR _r in SELECT * from __regrants FOR UPDATE
	    LOOP
		    IF beverbose THEN
			    RAISE NOTICE 'Regrant Executing: %', _r.regrant;
		    END IF;
		    EXECUTE _r.regrant; 
		    DELETE from __regrants where id = _r.id;
	    END LOOP;
    
	    SELECT count(*) INTO _tally from __regrants;
	    IF _tally > 0 THEN
		    RAISE EXCEPTION 'Grant extractions were run while replaying grants - %.', _tally;
	    ELSE
		    DROP TABLE __regrants;
	    END IF;
	ELSE
		RAISE NOTICE '**** WARNING: replay_saved_grants did NOT have anything to regrant!';
	END IF;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_constraint_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_constraint_for_replay ( schema character varying, object character varying, dropit boolean );
CREATE OR REPLACE FUNCTION schema_support.save_constraint_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

	FOR _r in 	SELECT n.nspname, c.relname, con.conname,
				pg_get_constraintdef(con.oid, true) as def
		FROM pg_constraint con
			INNER JOIN pg_class c on (c.relnamespace, c.oid) =
				(con.connamespace, con.conrelid)
			INNER JOIN pg_namespace n on n.oid = c.relnamespace
		WHERE con.confrelid in (
			select c.oid 
			from pg_class c
				inner join pg_namespace n on n.oid = c.relnamespace
			WHERE c.relname = object
			AND n.nspname = schema
		) AND n.nspname != schema
	LOOP
		_ddl := 'ALTER TABLE ' || _r.nspname || '.' || _r.relname ||
			' ADD CONSTRAINT ' || _r.conname || ' ' || _r.def;
		IF _ddl is NULL THEN
			RAISE EXCEPTION 'Unable to define constraint for %', _r;
		END IF;
		INSERT INTO __recreate (schema, object, type, ddl )
			VALUES (
				_r.nspname, _r.relname, 'constraint', _ddl
			);
		IF dropit  THEN
			_cmd = 'ALTER TABLE ' || _r.nspname || '.' || _r.relname || 
				' DROP CONSTRAINT ' || _r.conname || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_function_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_function_for_replay ( schema character varying, object character varying, dropit boolean );
CREATE OR REPLACE FUNCTION schema_support.save_function_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

	-- implicitly save regrants
	PERFORM schema_support.save_grants_for_replay(schema, object);
	FOR _r IN SELECT n.nspname, p.proname, 
				coalesce(u.usename, 'public') as owner,
				pg_get_functiondef(p.oid) as funcdef,
				pg_get_function_identity_arguments(p.oid) as idargs
		FROM    pg_catalog.pg_proc  p
				INNER JOIN pg_catalog.pg_namespace n on n.oid = p.pronamespace
				INNER JOIN pg_catalog.pg_language l on l.oid = p.prolang
				INNER JOIN pg_catalog.pg_user u on u.usesysid = p.proowner
		WHERE   n.nspname = schema
		  AND	p.proname = object
	LOOP
		INSERT INTO __recreate (schema, object, type, owner, ddl, idargs )
		VALUES (
			_r.nspname, _r.proname, 'function', _r.owner, _r.funcdef, _r.idargs
		);
		IF dropit  THEN
			_cmd = 'DROP FUNCTION ' || _r.nspname || '.' ||
				_r.proname || '(' || _r.idargs || ');';
			EXECUTE _cmd;
		END IF;

	END LOOP;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_grants_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_grants_for_replay ( schema character varying, object character varying, newname character varying );
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay(schema character varying, object character varying, newname character varying DEFAULT NULL::character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
	PERFORM schema_support.save_grants_for_replay_relations(schema, object, newname);
	PERFORM schema_support.save_grants_for_replay_functions(schema, object, newname);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_grants_for_replay_functions');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_grants_for_replay_functions ( schema character varying, object character varying, newname character varying );
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay_functions(schema character varying, object character varying, newname character varying DEFAULT NULL::character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_schema		varchar;
	_object		varchar;
	_procs		RECORD;
	_perm		RECORD;
	_grant		varchar;
	_role		varchar;
	_fullgrant		varchar;
BEGIN
	_schema := schema;
	_object := object;
	if newname IS NULL THEN
		newname := _object;
	END IF;
	PERFORM schema_support.prepare_for_grant_replay();
	FOR _procs IN SELECT  n.nspname as schema, p.proname,
			pg_get_function_identity_arguments(p.oid) as args,
			proacl as privs
		FROM    pg_catalog.pg_proc  p
				inner join pg_catalog.pg_namespace n on n.oid = p.pronamespace
		WHERE   n.nspname = _schema
	 	 AND    p.proname = _object
	LOOP
		-- NOTE:  We lose who granted it.  Oh Well.
		FOR _perm IN SELECT * FROM pg_catalog.aclexplode(acl := _procs.privs)
		LOOP
			--  grantor | grantee | privilege_type | is_grantable 
			IF _perm.is_grantable THEN
				_grant = ' WITH GRANT OPTION';
			ELSE
				_grant = '';
			END IF;
			IF _perm.grantee = 0 THEN
				_role := 'PUBLIC';
			ELSE
				_role := pg_get_userbyid(_perm.grantee);
			END IF;
			_fullgrant := 'GRANT ' || 
				_perm.privilege_type || ' on FUNCTION ' ||
				_schema || '.' ||
				newname || '(' || _procs.args || ')  to ' ||
				_role || _grant;
			-- RAISE DEBUG 'inserting % for %', _fullgrant, _perm;
			INSERT INTO __regrants (schema, object, newname, regrant) values (schema,object, newname, _fullgrant );
		END LOOP;
	END LOOP;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_grants_for_replay_relations');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_grants_for_replay_relations ( schema character varying, object character varying, newname character varying );
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay_relations(schema character varying, object character varying, newname character varying DEFAULT NULL::character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_schema		varchar;
	_object	varchar;
	_tabs		RECORD;
	_perm		RECORD;
	_grant		varchar;
	_fullgrant		varchar;
	_role		varchar;
BEGIN
	_schema := schema;
	_object := object;
	if newname IS NULL THEN
		newname := _object;
	END IF;
	PERFORM schema_support.prepare_for_grant_replay();
	FOR _tabs IN SELECT  n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'v' THEN 'view'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as "Type",
			c.relacl as privs
		FROM    pg_catalog.pg_class c
			LEFT JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
		WHERE c.relkind IN ('r', 'v', 'S', 'f')
		  AND c.relname = _object
		  AND n.nspname = _schema
		ORDER BY 1, 2
	LOOP
		-- NOTE:  We lose who granted it.  Oh Well.
		FOR _perm IN SELECT * FROM pg_catalog.aclexplode(acl := _tabs.privs)
		LOOP
			--  grantor | grantee | privilege_type | is_grantable 
			IF _perm.is_grantable THEN
				_grant = ' WITH GRANT OPTION';
			ELSE
				_grant = '';
			END IF;
			IF _perm.grantee = 0 THEN
				_role := 'PUBLIC';
			ELSE
				_role := pg_get_userbyid(_perm.grantee);
			END IF;
			_fullgrant := 'GRANT ' || 
				_perm.privilege_type || ' on ' ||
				_schema || '.' ||
				newname || ' to ' ||
				_role || _grant;
			IF _fullgrant IS NULL THEN
				RAISE EXCEPTION 'built up grant for %.% (%) is NULL',
					schema, object, newname;
	    END IF;
			INSERT INTO __regrants (schema, object, newname, regrant) values (schema,object, newname, _fullgrant );
		END LOOP;
	END LOOP;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_trigger_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_trigger_for_replay ( schema character varying, object character varying, dropit boolean );
CREATE OR REPLACE FUNCTION schema_support.save_trigger_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

	FOR _r in 	
		SELECT n.nspname, c.relname, trg.tgname,
				pg_get_triggerdef(trg.oid, true) as def
		FROM pg_trigger trg
			INNER JOIN pg_class c on trg.tgrelid =  c.oid
			INNER JOIN pg_namespace n on n.oid = c.relnamespace
		WHERE n.nspname = schema and c.relname = object
	LOOP
		INSERT INTO __recreate (schema, object, type, ddl )
			VALUES (
				_r.nspname, _r.relname, 'trigger', _r.def
			);
		IF dropit  THEN
			_cmd = 'DROP TRIGGER ' || _r.tgname || ' ON ' ||
				_r.nspname || '.' || _r.relname || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_view_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_view_for_replay ( schema character varying, object character varying, dropit boolean );
CREATE OR REPLACE FUNCTION schema_support.save_view_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

	-- implicitly save regrants
	PERFORM schema_support.save_grants_for_replay(schema, object);

	-- save any triggers on the view
	PERFORM schema_support.save_trigger_for_replay(schema, object, dropit);
	FOR _r in SELECT n.nspname, c.relname, 'view',
				coalesce(u.usename, 'public') as owner,
				pg_get_viewdef(c.oid, true) as viewdef
		FROM pg_class c
		INNER JOIN pg_namespace n on n.oid = c.relnamespace
		LEFT JOIN pg_user u on u.usesysid = c.relowner
		WHERE c.relname = object
		AND n.nspname = schema
	LOOP
		_ddl := 'CREATE OR REPLACE VIEW ' || _r.nspname || '.' || _r.relname ||
			' AS ' || _r.viewdef;
		IF _ddl is NULL THEN
			RAISE EXCEPTION 'Unable to define view for %', _r;
		END IF;
		INSERT INTO __recreate (schema, object, owner, type, ddl )
			VALUES (
				_r.nspname, _r.relname, _r.owner, 'view', _ddl
			);
		IF dropit  THEN
			_cmd = 'DROP VIEW ' || _r.nspname || '.' || _r.relname || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_dependant_objects_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO schema_support
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	RAISE NOTICE 'processing %.%', schema, object;
	-- process stored procedures
	FOR _r in SELECT  distinct np.nspname::text, dependent.proname::text
		FROM   pg_depend dep
			INNER join pg_type dependee on dependee.oid = dep.refobjid
			INNER join pg_namespace n on n.oid = dependee.typnamespace
			INNER join pg_proc dependent on dependent.oid = dep.objid
			INNER join pg_namespace np on np.oid = dependent.pronamespace
			WHERE   dependee.typname = object
			  AND	  n.nspname = schema
	LOOP
		RAISE NOTICE '1 dealing with  %.%', _r.nspname, _r.proname;
		PERFORM schema_support.save_constraint_for_replay(_r.nspname, _r.proname, dropit);
		PERFORM schema_support.save_dependant_objects_for_replay(_r.nspname, _r.proname, dropit);
		PERFORM schema_support.save_function_for_replay(_r.nspname, _r.proname, dropit);
	END LOOP;

	-- save any triggers on the view
	FOR _r in SELECT distinct n.nspname::text, dependee.relname::text, dependee.relkind
		FROM pg_depend
		JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid
		JOIN pg_class as dependee ON pg_rewrite.ev_class = dependee.oid
		JOIN pg_class as dependent ON pg_depend.refobjid = dependent.oid
		JOIN pg_namespace n on n.oid = dependee.relnamespace
		JOIN pg_namespace sn on sn.oid = dependent.relnamespace
		JOIN pg_attribute ON pg_depend.refobjid = pg_attribute.attrelid
   			AND pg_depend.refobjsubid = pg_attribute.attnum
		WHERE dependent.relname = object
  		AND sn.nspname = schema
	LOOP
		IF _r.relkind = 'v' THEN
			RAISE NOTICE '2 dealing with  %.%', _r.nspname, _r.relname;
			PERFORM * FROM save_dependant_objects_for_replay(_r.nspname, _r.relname, dropit);
			PERFORM schema_support.save_view_for_replay(_r.nspname, _r.relname, dropit);
		END IF;
	END LOOP;
END;
$function$
;

-- Creating new sequences....
CREATE SEQUENCE logical_port_logical_port_id_seq;
CREATE SEQUENCE mlag_peering_mlag_peering_id_seq;
CREATE SEQUENCE layer3_network_layer3_network_id_seq;
CREATE SEQUENCE layer2_network_layer2_network_id_seq;
CREATE SEQUENCE asset_asset_id_seq;

-- These should not be necessary here
SELECT schema_support.save_constraint_for_replay('jazzhands', 'device');
SELECT schema_support.save_constraint_for_replay('jazzhands', 'network_interface');
SELECT schema_support.save_constraint_for_replay('jazzhands', 'dns_domain');


--------------------------------------------------------------------
-- DEALING WITH TABLE val_account_collection_type [4203720]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_account_collection_type', 'val_account_collection_type');

-- FOREIGN KEYS FROM
ALTER TABLE val_property_type DROP CONSTRAINT IF EXISTS fk_prop_typ_pv_uctyp_rst;
ALTER TABLE account_collection DROP CONSTRAINT IF EXISTS fk_acctcol_usrcoltyp;
ALTER TABLE val_property DROP CONSTRAINT IF EXISTS fk_valprop_pv_actyp_rst;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.val_account_collection_type DROP CONSTRAINT IF EXISTS pk_val_account_collection_type;
-- INDEXES
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_account_collection_type DROP CONSTRAINT IF EXISTS check_yes_no_1816418084;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_audit_val_account_collection_type ON jazzhands.val_account_collection_type;
DROP TRIGGER IF EXISTS trig_userlog_val_account_collection_type ON jazzhands.val_account_collection_type;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_account_collection_type');
---- BEGIN audit.val_account_collection_type TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_account_collection_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_account_collection_type');
---- DONE audit.val_account_collection_type TEARDOWN


ALTER TABLE val_account_collection_type RENAME TO val_account_collection_type_v57;
ALTER TABLE audit.val_account_collection_type RENAME TO val_account_collection_type_v57;

CREATE TABLE val_account_collection_type
(
	account_collection_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	is_infrastructure_type	character(1) NOT NULL,
	max_num_members	integer  NULL,
	max_num_collections	integer  NULL,
	can_have_hierarchy	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_account_collection_type', false);
ALTER TABLE val_account_collection_type
	ALTER is_infrastructure_type
	SET DEFAULT 'N'::bpchar;
ALTER TABLE val_account_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;
INSERT INTO val_account_collection_type (
	account_collection_type,
	description,
	is_infrastructure_type,
	max_num_members,		-- new column (max_num_members)
	max_num_collections,		-- new column (max_num_collections)
	can_have_hierarchy,		-- new column (can_have_hierarchy)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	account_collection_type,
	description,
	is_infrastructure_type,
	NULL,		-- new column (max_num_members)
	NULL,		-- new column (max_num_collections)
	'Y'::bpchar,		-- new column (can_have_hierarchy)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_account_collection_type_v57;

INSERT INTO audit.val_account_collection_type (
	account_collection_type,
	description,
	is_infrastructure_type,
	max_num_members,		-- new column (max_num_members)
	max_num_collections,		-- new column (max_num_collections)
	can_have_hierarchy,		-- new column (can_have_hierarchy)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	account_collection_type,
	description,
	is_infrastructure_type,
	NULL,		-- new column (max_num_members)
	NULL,		-- new column (max_num_collections)
	NULL,		-- new column (can_have_hierarchy)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_account_collection_type_v57;

ALTER TABLE val_account_collection_type
	ALTER is_infrastructure_type
	SET DEFAULT 'N'::bpchar;
ALTER TABLE val_account_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_account_collection_type ADD CONSTRAINT pk_val_account_collection_type PRIMARY KEY (account_collection_type);

-- Table/Column Comments
COMMENT ON COLUMN val_account_collection_type.max_num_members IS 'Maximum INTEGER of members in a given collection of this type
';
COMMENT ON COLUMN val_account_collection_type.max_num_collections IS 'Maximum INTEGER of collections a given member can be a part of of this type.
';
COMMENT ON COLUMN val_account_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_account_collection_type ADD CONSTRAINT check_yes_no_act_chh
	CHECK (can_have_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE val_account_collection_type ADD CONSTRAINT check_yes_no_1816418084
	CHECK (is_infrastructure_type = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_account_collection_type and account_collection
ALTER TABLE account_collection
	ADD CONSTRAINT fk_acctcol_usrcoltyp
	FOREIGN KEY (account_collection_type) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK val_account_collection_type and val_property
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_pv_actyp_rst
	FOREIGN KEY (prop_val_acct_coll_type_rstrct) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK val_account_collection_type and account_realm_acct_coll_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE account_realm_acct_coll_type
--	ADD CONSTRAINT fk_acct_realm_acct_coll_typ
--	FOREIGN KEY (account_collection_type) REFERENCES val_account_collection_type(account_collection_type);

-- consider FK val_account_collection_type and val_property_type
ALTER TABLE val_property_type
	ADD CONSTRAINT fk_prop_typ_pv_uctyp_rst
	FOREIGN KEY (prop_val_acct_coll_type_rstrct) REFERENCES val_account_collection_type(account_collection_type);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_account_collection_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_account_collection_type');
DROP TABLE IF EXISTS val_account_collection_type_v57;
DROP TABLE IF EXISTS audit.val_account_collection_type_v57;
-- DONE DEALING WITH TABLE val_account_collection_type [4210611]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_property [4369091]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_property', 'val_property');

-- FOREIGN KEYS FROM
ALTER TABLE val_property_value DROP CONSTRAINT IF EXISTS fk_valproval_namtyp;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_nmtyp;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_proptyp;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_pv_actyp_rst;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_prop_nblk_coll_type;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_propdttyp;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS pk_val_property;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif3val_property";
DROP INDEX IF EXISTS "jazzhands"."xif2val_property";
DROP INDEX IF EXISTS "jazzhands"."xif1val_property";
DROP INDEX IF EXISTS "jazzhands"."xif4val_property";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_osid;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pdnsdomid;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_prodstate;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pacct_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_2139007167;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pdevcol_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_cmp_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_606225804;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_354296970;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_sitec;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pucls_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_ismulti;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_audit_val_property ON jazzhands.val_property;
DROP TRIGGER IF EXISTS trig_userlog_val_property ON jazzhands.val_property;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_property');
---- BEGIN audit.val_property TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_property_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_property');
---- DONE audit.val_property TEARDOWN


ALTER TABLE val_property RENAME TO val_property_v57;
ALTER TABLE audit.val_property RENAME TO val_property_v57;

CREATE TABLE val_property
(
	property_name	varchar(255) NOT NULL,
	property_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	is_multivalue	character(1) NOT NULL,
	prop_val_acct_coll_type_rstrct	varchar(50)  NULL,
	prop_val_nblk_coll_type_rstrct	varchar(50)  NULL,
	property_data_type	varchar(50) NOT NULL,
	permit_account_collection_id	character(10) NOT NULL,
	permit_account_id	character(10) NOT NULL,
	permit_account_realm_id	character(10) NOT NULL,
	permit_company_id	character(10) NOT NULL,
	permit_device_collection_id	character(10) NOT NULL,
	permit_dns_domain_id	character(10) NOT NULL,
	permit_layer2_network_id	character(10) NOT NULL,
	permit_layer3_network_id	character(10) NOT NULL,
	permit_netblock_collection_id	character(10) NOT NULL,
	permit_operating_system_id	character(10) NOT NULL,
	permit_person_id	character(10) NOT NULL,
	permit_service_env_collection	character(10) NOT NULL,
	permit_site_code	character(10) NOT NULL,
	permit_property_rank	character(10) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_property', false);
ALTER TABLE val_property
	ALTER permit_account_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_realm_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_company_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_device_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_dns_domain_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer2_network_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer3_network_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_netblock_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_operating_system_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_person_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_service_env_collection
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_site_code
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_property_rank
	SET DEFAULT 'PROHIBITED'::bpchar;
INSERT INTO val_property (
	property_name,
	property_type,
	description,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,		-- new column (permit_account_realm_id)
	permit_company_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_layer2_network_id,		-- new column (permit_layer2_network_id)
	permit_layer3_network_id,		-- new column (permit_layer3_network_id)
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_person_id,
	permit_service_env_collection,
	permit_site_code,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	property_name,
	property_type,
	description,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	'PROHIBITED'::bpchar,		-- new column (permit_account_realm_id)
	permit_company_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	'PROHIBITED'::bpchar,		-- new column (permit_layer2_network_id)
	'PROHIBITED'::bpchar,		-- new column (permit_layer3_network_id)
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_person_id,
	permit_service_env_collection,
	permit_site_code,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_property_v57;

INSERT INTO audit.val_property (
	property_name,
	property_type,
	description,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,		-- new column (permit_account_realm_id)
	permit_company_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_layer2_network_id,		-- new column (permit_layer2_network_id)
	permit_layer3_network_id,		-- new column (permit_layer3_network_id)
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_person_id,
	permit_service_env_collection,
	permit_site_code,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	property_name,
	property_type,
	description,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	NULL,		-- new column (permit_account_realm_id)
	permit_company_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	NULL,		-- new column (permit_layer2_network_id)
	NULL,		-- new column (permit_layer3_network_id)
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_person_id,
	permit_service_env_collection,
	permit_site_code,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_property_v57;

ALTER TABLE val_property
	ALTER permit_account_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_realm_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_company_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_device_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_dns_domain_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer2_network_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer3_network_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_netblock_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_operating_system_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_person_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_service_env_collection
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_site_code
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_property_rank
	SET DEFAULT 'PROHIBITED'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_property ADD CONSTRAINT pk_val_property PRIMARY KEY (property_name, property_type);

-- Table/Column Comments
COMMENT ON TABLE val_property IS 'valid values and attributes for (name,type) pairs in the property table';
COMMENT ON COLUMN val_property.property_name IS 'property name for validation purposes';
COMMENT ON COLUMN val_property.property_type IS 'property type for validation purposes';
COMMENT ON COLUMN val_property.is_multivalue IS 'If N, acts like an ak on property.(*_id,property_type)';
COMMENT ON COLUMN val_property.property_data_type IS 'which of the property_table_* columns should be used for this value';
COMMENT ON COLUMN val_property.permit_account_collection_id IS 'defines how company id should be used in the property for this (name,type)';
COMMENT ON COLUMN val_property.permit_account_id IS 'defines how company id should be used in the property for this (name,type)';
COMMENT ON COLUMN val_property.permit_company_id IS 'defines how company id should be used in the property for this (name,type)';
COMMENT ON COLUMN val_property.permit_device_collection_id IS 'defines how company id should be used in the property for this (name,type)';
COMMENT ON COLUMN val_property.permit_dns_domain_id IS 'defines how company id should be used in the property for this (name,type)';
-- INDEXES
CREATE INDEX xif1val_property ON val_property USING btree (property_data_type);
CREATE INDEX xif4val_property ON val_property USING btree (prop_val_nblk_coll_type_rstrct);
CREATE INDEX xif3val_property ON val_property USING btree (prop_val_acct_coll_type_rstrct);
CREATE INDEX xif2val_property ON val_property USING btree (property_type);

-- CHECK CONSTRAINTS
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pdevcol_id
	CHECK (permit_device_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_2016888554
	CHECK (permit_account_realm_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_2139007167
	CHECK (permit_property_rank = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pacct_id
	CHECK (permit_account_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_354296970
	CHECK (permit_netblock_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_606225804
	CHECK (permit_person_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_cmp_id
	CHECK (permit_company_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pdnsdomid
	CHECK (permit_dns_domain_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_osid
	CHECK (permit_operating_system_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_prodstate
	CHECK (permit_service_env_collection = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_1279736503
	CHECK (permit_layer2_network_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_1279736247
	CHECK (permit_layer3_network_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pucls_id
	CHECK (permit_account_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_sitec
	CHECK (permit_site_code = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_ismulti
	CHECK (is_multivalue = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_property and val_property_value
ALTER TABLE val_property_value
	ADD CONSTRAINT fk_valproval_namtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
-- consider FK val_property and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_nmtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);

-- FOREIGN KEYS TO
-- consider FK val_property and val_account_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_pv_actyp_rst
	FOREIGN KEY (prop_val_acct_coll_type_rstrct) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK val_property and val_property_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_proptyp
	FOREIGN KEY (property_type) REFERENCES val_property_type(property_type);
-- consider FK val_property and val_property_data_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_propdttyp
	FOREIGN KEY (property_data_type) REFERENCES val_property_data_type(property_data_type);
-- consider FK val_property and val_netblock_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_nblk_coll_type
	FOREIGN KEY (prop_val_nblk_coll_type_rstrct) REFERENCES val_netblock_collection_type(netblock_collection_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_property');
DROP TABLE IF EXISTS val_property_v57;
DROP TABLE IF EXISTS audit.val_property_v57;
-- DONE DEALING WITH TABLE val_property [4353294]
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH TABLE encapsulation [4202874]

-- FOREIGN KEYS FROM
ALTER TABLE layer2_encapsulation DROP CONSTRAINT IF EXISTS fk_l2encap_encap_id;
ALTER TABLE encapsulation_netblock DROP CONSTRAINT IF EXISTS fk_encap_netblock_encap_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.encapsulation DROP CONSTRAINT IF EXISTS fk_encapsul_fk_encaps_vlan_ran;
ALTER TABLE jazzhands.encapsulation DROP CONSTRAINT IF EXISTS fk_encapsul_fk_encaps_val_enca;
ALTER TABLE jazzhands.encapsulation DROP CONSTRAINT IF EXISTS pk_encapsulation;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_encaps_vlanrange";
DROP INDEX IF EXISTS "jazzhands"."idx_encaps_encapstype";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.encapsulation DROP CONSTRAINT IF EXISTS ckc_vlan_boundary_typ_encapsul;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_audit_encapsulation ON jazzhands.encapsulation;
DROP TRIGGER IF EXISTS trig_userlog_encapsulation ON jazzhands.encapsulation;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'encapsulation');
---- BEGIN audit.encapsulation TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."encapsulation_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'encapsulation');
---- DONE audit.encapsulation TEARDOWN


ALTER TABLE encapsulation RENAME TO encapsulation_v57;
ALTER TABLE audit.encapsulation RENAME TO encapsulation_v57;

DROP TABLE IF EXISTS encapsulation_v57;
DROP TABLE IF EXISTS audit.encapsulation_v57;
-- DONE DEALING WITH OLD TABLE encapsulation [4202874]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE person_company [4203194]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'person_company', 'person_company');

-- FOREIGN KEYS FROM
ALTER TABLE account DROP CONSTRAINT IF EXISTS fk_account_company_person;
ALTER TABLE person_company_badge DROP CONSTRAINT IF EXISTS fk_person_company_badge_pc;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.person_company DROP CONSTRAINT IF EXISTS fk_person_company_mgrprsn_id;
ALTER TABLE jazzhands.person_company DROP CONSTRAINT IF EXISTS fk_person_company_sprprsn_id;
ALTER TABLE jazzhands.person_company DROP CONSTRAINT IF EXISTS fk_person_company_prsncmpyrelt;
ALTER TABLE jazzhands.person_company DROP CONSTRAINT IF EXISTS fk_person_company_prsnid;
ALTER TABLE jazzhands.person_company DROP CONSTRAINT IF EXISTS fk_person_company_prsncmpy_sta;
ALTER TABLE jazzhands.person_company DROP CONSTRAINT IF EXISTS fk_person_company_company_id;
ALTER TABLE jazzhands.person_company DROP CONSTRAINT IF EXISTS ak_uq_person_company_empid;
ALTER TABLE jazzhands.person_company DROP CONSTRAINT IF EXISTS pk_person_company;
ALTER TABLE jazzhands.person_company DROP CONSTRAINT IF EXISTS ak_uq_prson_company_bdgid;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif4person_company";
DROP INDEX IF EXISTS "jazzhands"."xif6person_company";
DROP INDEX IF EXISTS "jazzhands"."xifperson_company_person_id";
DROP INDEX IF EXISTS "jazzhands"."xif5person_company";
DROP INDEX IF EXISTS "jazzhands"."xifperson_company_company_id";
DROP INDEX IF EXISTS "jazzhands"."xif3person_company";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.person_company DROP CONSTRAINT IF EXISTS check_yes_no_prsncmpy_mgmt;
ALTER TABLE jazzhands.person_company DROP CONSTRAINT IF EXISTS check_yes_no_691526916;
ALTER TABLE jazzhands.person_company DROP CONSTRAINT IF EXISTS check_yes_no_1391508687;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_person_company ON jazzhands.person_company;
DROP TRIGGER IF EXISTS trigger_audit_person_company ON jazzhands.person_company;
DROP TRIGGER IF EXISTS trigger_automated_ac_on_person_company ON jazzhands.person_company;
DROP TRIGGER IF EXISTS trigger_propagate_person_status_to_account ON jazzhands.person_company;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'person_company');
---- BEGIN audit.person_company TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."person_company_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'person_company');
---- DONE audit.person_company TEARDOWN


ALTER TABLE person_company RENAME TO person_company_v57;
ALTER TABLE audit.person_company RENAME TO person_company_v57;

CREATE TABLE person_company
(
	company_id	integer NOT NULL,
	person_id	integer NOT NULL,
	person_company_status	varchar(50) NOT NULL,
	person_company_relation	varchar(50) NOT NULL,
	is_exempt	character(1) NOT NULL,
	is_management	character(1) NOT NULL,
	is_full_time	character(1) NOT NULL,
	description	varchar(255)  NULL,
	employee_id	varchar(255)  NULL,
	payroll_id	varchar(255)  NULL,
	external_hr_id	varchar(255)  NULL,
	position_title	varchar(50)  NULL,
	badge_system_id	varchar(255)  NULL,
	hire_date	timestamp with time zone  NULL,
	termination_date	timestamp with time zone  NULL,
	manager_person_id	integer  NULL,
	supervisor_person_id	integer  NULL,
	nickname	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'person_company', false);
ALTER TABLE person_company
	ALTER is_exempt
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE person_company
	ALTER is_management
	SET DEFAULT 'N'::bpchar;
ALTER TABLE person_company
	ALTER is_full_time
	SET DEFAULT 'Y'::bpchar;
INSERT INTO person_company (
	company_id,
	person_id,
	person_company_status,
	person_company_relation,
	is_exempt,
	is_management,
	is_full_time,
	description,
	employee_id,
	payroll_id,
	external_hr_id,
	position_title,
	badge_system_id,
	hire_date,
	termination_date,
	manager_person_id,
	supervisor_person_id,
	nickname,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	company_id,
	person_id,
	person_company_status,
	person_company_relation,
	is_exempt,
	is_management,
	is_full_time,
	description,
	employee_id,
	payroll_id,
	external_hr_id,
	position_title,
	badge_system_id,
	hire_date,
	termination_date,
	manager_person_id,
	supervisor_person_id,
	nickname,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM person_company_v57;

INSERT INTO audit.person_company (
	company_id,
	person_id,
	person_company_status,
	person_company_relation,
	is_exempt,
	is_management,
	is_full_time,
	description,
	employee_id,
	payroll_id,
	external_hr_id,
	position_title,
	badge_system_id,
	hire_date,
	termination_date,
	manager_person_id,
	supervisor_person_id,
	nickname,
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
	person_company_status,
	person_company_relation,
	is_exempt,
	is_management,
	is_full_time,
	description,
	employee_id,
	payroll_id,
	external_hr_id,
	position_title,
	badge_system_id,
	hire_date,
	termination_date,
	manager_person_id,
	supervisor_person_id,
	nickname,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.person_company_v57;

ALTER TABLE person_company
	ALTER is_exempt
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE person_company
	ALTER is_management
	SET DEFAULT 'N'::bpchar;
ALTER TABLE person_company
	ALTER is_full_time
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE person_company ADD CONSTRAINT ak_uq_prson_company_bdgid UNIQUE (badge_system_id, company_id);
ALTER TABLE person_company ADD CONSTRAINT pk_person_company PRIMARY KEY (company_id, person_id);
ALTER TABLE person_company ADD CONSTRAINT ak_uq_person_company_empid UNIQUE (employee_id, company_id);

-- Table/Column Comments
COMMENT ON COLUMN person_company.nickname IS 'Nickname in the context of a given company.  This is less likely to be used, the value in person is preferrred.';
-- INDEXES
CREATE INDEX xifperson_company_company_id ON person_company USING btree (company_id);
CREATE INDEX xif5person_company ON person_company USING btree (person_company_status);
CREATE INDEX xif3person_company ON person_company USING btree (manager_person_id);
CREATE INDEX xifperson_company_person_id ON person_company USING btree (person_id);
CREATE INDEX xif6person_company ON person_company USING btree (person_company_relation);
CREATE INDEX xif4person_company ON person_company USING btree (supervisor_person_id);

-- CHECK CONSTRAINTS
ALTER TABLE person_company ADD CONSTRAINT check_yes_no_1391508687
	CHECK (is_exempt = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE person_company ADD CONSTRAINT check_yes_no_prsncmpy_mgmt
	CHECK (is_management = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE person_company ADD CONSTRAINT check_yes_no_691526916
	CHECK (is_full_time = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK person_company and person_company_badge
ALTER TABLE person_company_badge
	ADD CONSTRAINT fk_person_company_badge_pc
	FOREIGN KEY (company_id, person_id) REFERENCES person_company(company_id, person_id);
-- consider FK person_company and account
ALTER TABLE account
	ADD CONSTRAINT fk_account_company_person
	FOREIGN KEY (company_id, person_id) REFERENCES person_company(company_id, person_id) DEFERRABLE;

-- FOREIGN KEYS TO
-- consider FK person_company and val_person_status
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_prsncmpy_sta
	FOREIGN KEY (person_company_status) REFERENCES val_person_status(person_status);
-- consider FK person_company and company
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id);
-- consider FK person_company and person
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_sprprsn_id
	FOREIGN KEY (supervisor_person_id) REFERENCES person(person_id);
-- consider FK person_company and person
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_mgrprsn_id
	FOREIGN KEY (manager_person_id) REFERENCES person(person_id);
-- consider FK person_company and person
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_prsnid
	FOREIGN KEY (person_id) REFERENCES person(person_id);
-- consider FK person_company and val_person_company_relation
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_prsncmpyrelt
	FOREIGN KEY (person_company_relation) REFERENCES val_person_company_relation(person_company_relation);

-- TRIGGERS
CREATE TRIGGER trigger_propagate_person_status_to_account AFTER UPDATE ON person_company FOR EACH ROW EXECUTE PROCEDURE propagate_person_status_to_account();

-- XXX - may need to include trigger function
CREATE TRIGGER trigger_automated_ac_on_person_company AFTER UPDATE ON person_company FOR EACH ROW EXECUTE PROCEDURE automated_ac_on_person_company();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'person_company');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'person_company');
DROP TABLE IF EXISTS person_company_v57;
DROP TABLE IF EXISTS audit.person_company_v57;
-- DONE DEALING WITH TABLE person_company [4210085]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_device_collection_type [4203838]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_device_collection_type', 'val_device_collection_type');

-- FOREIGN KEYS FROM
ALTER TABLE device_collection DROP CONSTRAINT IF EXISTS fk_devc_devctyp_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.val_device_collection_type DROP CONSTRAINT IF EXISTS pk_val_device_collection_type;
-- INDEXES
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_device_collection_type DROP CONSTRAINT IF EXISTS ckc_can_have_acctcol_val_devi;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_device_collection_type ON jazzhands.val_device_collection_type;
DROP TRIGGER IF EXISTS trigger_audit_val_device_collection_type ON jazzhands.val_device_collection_type;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_device_collection_type');
---- BEGIN audit.val_device_collection_type TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_device_collection_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_device_collection_type');
---- DONE audit.val_device_collection_type TEARDOWN


ALTER TABLE val_device_collection_type RENAME TO val_device_collection_type_v57;
ALTER TABLE audit.val_device_collection_type RENAME TO val_device_collection_type_v57;

CREATE TABLE val_device_collection_type
(
	device_collection_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	max_num_members	integer  NULL,
	max_num_collections	integer  NULL,
	can_have_hierarchy	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_device_collection_type', false);
ALTER TABLE val_device_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;
INSERT INTO val_device_collection_type (
	device_collection_type,
	description,
	max_num_members,		-- new column (max_num_members)
	max_num_collections,		-- new column (max_num_collections)
	can_have_hierarchy,		-- new column (can_have_hierarchy)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	device_collection_type,
	description,
	NULL,		-- new column (max_num_members)
	NULL,		-- new column (max_num_collections)
	'Y'::bpchar,		-- new column (can_have_hierarchy)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_device_collection_type_v57;

INSERT INTO audit.val_device_collection_type (
	device_collection_type,
	description,
	max_num_members,		-- new column (max_num_members)
	max_num_collections,		-- new column (max_num_collections)
	can_have_hierarchy,		-- new column (can_have_hierarchy)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	device_collection_type,
	description,
	NULL,		-- new column (max_num_members)
	NULL,		-- new column (max_num_collections)
	NULL,		-- new column (can_have_hierarchy)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_device_collection_type_v57;

ALTER TABLE val_device_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_device_collection_type ADD CONSTRAINT pk_val_device_collection_type PRIMARY KEY (device_collection_type);

-- Table/Column Comments
COMMENT ON COLUMN val_device_collection_type.max_num_members IS 'Maximum INTEGER of members in a given collection of this type
';
COMMENT ON COLUMN val_device_collection_type.max_num_collections IS 'Maximum INTEGER of collections a given member can be a part of of this type.
';
COMMENT ON COLUMN val_device_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_device_collection_type ADD CONSTRAINT check_yes_no_dct_chh
	CHECK (can_have_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_device_collection_type and device_collection
ALTER TABLE device_collection
	ADD CONSTRAINT fk_devc_devctyp_id
	FOREIGN KEY (device_collection_type) REFERENCES val_device_collection_type(device_collection_type);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_device_collection_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_device_collection_type');
DROP TABLE IF EXISTS val_device_collection_type_v57;
DROP TABLE IF EXISTS audit.val_device_collection_type_v57;
-- DONE DEALING WITH TABLE val_device_collection_type [4210739]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_netblock_collection_type [4203976]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_netblock_collection_type', 'val_netblock_collection_type');

-- FOREIGN KEYS FROM
ALTER TABLE val_property DROP CONSTRAINT IF EXISTS fk_val_prop_nblk_coll_type;
ALTER TABLE netblock_collection DROP CONSTRAINT IF EXISTS fk_nblk_coll_v_nblk_c_typ;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.val_netblock_collection_type DROP CONSTRAINT IF EXISTS pk_val_netblock_collection_typ;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_netblock_collection_type ON jazzhands.val_netblock_collection_type;
DROP TRIGGER IF EXISTS trigger_audit_val_netblock_collection_type ON jazzhands.val_netblock_collection_type;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_netblock_collection_type');
---- BEGIN audit.val_netblock_collection_type TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_netblock_collection_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_netblock_collection_type');
---- DONE audit.val_netblock_collection_type TEARDOWN


ALTER TABLE val_netblock_collection_type RENAME TO val_netblock_collection_type_v57;
ALTER TABLE audit.val_netblock_collection_type RENAME TO val_netblock_collection_type_v57;

CREATE TABLE val_netblock_collection_type
(
	netblock_collection_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	max_num_members	integer  NULL,
	max_num_collections	integer  NULL,
	can_have_hierarchy	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_netblock_collection_type', false);
ALTER TABLE val_netblock_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;
INSERT INTO val_netblock_collection_type (
	netblock_collection_type,
	description,
	max_num_members,		-- new column (max_num_members)
	max_num_collections,		-- new column (max_num_collections)
	can_have_hierarchy,		-- new column (can_have_hierarchy)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	netblock_collection_type,
	description,
	NULL,		-- new column (max_num_members)
	NULL,		-- new column (max_num_collections)
	'Y'::bpchar,		-- new column (can_have_hierarchy)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_netblock_collection_type_v57;

INSERT INTO audit.val_netblock_collection_type (
	netblock_collection_type,
	description,
	max_num_members,		-- new column (max_num_members)
	max_num_collections,		-- new column (max_num_collections)
	can_have_hierarchy,		-- new column (can_have_hierarchy)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	netblock_collection_type,
	description,
	NULL,		-- new column (max_num_members)
	NULL,		-- new column (max_num_collections)
	NULL,		-- new column (can_have_hierarchy)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_netblock_collection_type_v57;

ALTER TABLE val_netblock_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_netblock_collection_type ADD CONSTRAINT pk_val_netblock_collection_typ PRIMARY KEY (netblock_collection_type);

-- Table/Column Comments
COMMENT ON COLUMN val_netblock_collection_type.max_num_members IS 'Maximum INTEGER of members in a given collection of this type
';
COMMENT ON COLUMN val_netblock_collection_type.max_num_collections IS 'Maximum INTEGER of collections a given member can be a part of of this type.
';
COMMENT ON COLUMN val_netblock_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_netblock_collection_type ADD CONSTRAINT check_yes_no_nct_chh
	CHECK (can_have_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_netblock_collection_type and netblock_collection
ALTER TABLE netblock_collection
	ADD CONSTRAINT fk_nblk_coll_v_nblk_c_typ
	FOREIGN KEY (netblock_collection_type) REFERENCES val_netblock_collection_type(netblock_collection_type);
-- consider FK val_netblock_collection_type and val_property
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_nblk_coll_type
	FOREIGN KEY (prop_val_nblk_coll_type_rstrct) REFERENCES val_netblock_collection_type(netblock_collection_type);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_netblock_collection_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_netblock_collection_type');
DROP TABLE IF EXISTS val_netblock_collection_type_v57;
DROP TABLE IF EXISTS audit.val_netblock_collection_type_v57;
-- DONE DEALING WITH TABLE val_netblock_collection_type [4210887]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE property [4368262]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'property', 'property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_svc_env_coll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_dnsdomid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_devcolid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_compid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_nmtyp;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_compid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_nblk_coll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_acct_colid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_osid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_dnsdomid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_tokcolid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acct_col;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acctid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_swpkgid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pv_nblkcol_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_val_prsnid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_site_code;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_pwdtyp;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_person_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS pk_property;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xifprop_acctcol_id";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_dnsdomid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_osid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_dnsdomid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_acct_colid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_nmtyp";
DROP INDEX IF EXISTS "jazzhands"."xifprop_compid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_account_id";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_pwdtyp";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_swpkgid";
DROP INDEX IF EXISTS "jazzhands"."xif21property";
DROP INDEX IF EXISTS "jazzhands"."xif17property";
DROP INDEX IF EXISTS "jazzhands"."xifprop_devcolid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_site_code";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_compid";
DROP INDEX IF EXISTS "jazzhands"."xif19property";
DROP INDEX IF EXISTS "jazzhands"."xif20property";
DROP INDEX IF EXISTS "jazzhands"."xif18property";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_tokcolid";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS ckc_prop_isenbld;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_audit_property ON jazzhands.property;
DROP TRIGGER IF EXISTS trigger_validate_property ON jazzhands.property;
DROP TRIGGER IF EXISTS trig_userlog_property ON jazzhands.property;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'property');
---- BEGIN audit.property TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."property_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'property');
---- DONE audit.property TEARDOWN


ALTER TABLE property RENAME TO property_v57;
ALTER TABLE audit.property RENAME TO property_v57;

CREATE TABLE property
(
	property_id	integer NOT NULL,
	account_collection_id	integer  NULL,
	account_id	integer  NULL,
	account_realm_id	integer  NULL,
	company_id	integer  NULL,
	device_collection_id	integer  NULL,
	dns_domain_id	integer  NULL,
	netblock_collection_id	integer  NULL,
	layer2_network_id	integer  NULL,
	layer3_network_id	integer  NULL,
	operating_system_id	integer  NULL,
	person_id	integer  NULL,
	service_env_collection_id	integer  NULL,
	site_code	varchar(50)  NULL,
	property_name	varchar(255) NOT NULL,
	property_type	varchar(50) NOT NULL,
	property_value	varchar(1024)  NULL,
	property_value_timestamp	timestamp without time zone  NULL,
	property_value_company_id	integer  NULL,
	property_value_account_coll_id	integer  NULL,
	property_value_dns_domain_id	integer  NULL,
	property_value_nblk_coll_id	integer  NULL,
	property_value_password_type	varchar(50)  NULL,
	property_value_person_id	integer  NULL,
	property_value_sw_package_id	integer  NULL,
	property_value_token_col_id	integer  NULL,
	property_rank	integer  NULL,
	start_date	timestamp without time zone  NULL,
	finish_date	timestamp without time zone  NULL,
	is_enabled	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'property', false);
ALTER TABLE property
	ALTER property_id
	SET DEFAULT nextval('property_property_id_seq'::regclass);
ALTER TABLE property
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;
INSERT INTO property (
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,		-- new column (account_realm_id)
	company_id,
	device_collection_id,
	dns_domain_id,
	netblock_collection_id,
	layer2_network_id,		-- new column (layer2_network_id)
	layer3_network_id,		-- new column (layer3_network_id)
	operating_system_id,
	person_id,
	service_env_collection_id,
	site_code,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_dns_domain_id,
	property_value_nblk_coll_id,
	property_value_password_type,
	property_value_person_id,
	property_value_sw_package_id,
	property_value_token_col_id,
	property_rank,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	property_id,
	account_collection_id,
	account_id,
	NULL,		-- new column (account_realm_id)
	company_id,
	device_collection_id,
	dns_domain_id,
	netblock_collection_id,
	NULL,		-- new column (layer2_network_id)
	NULL,		-- new column (layer3_network_id)
	operating_system_id,
	person_id,
	service_env_collection_id,
	site_code,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_dns_domain_id,
	property_value_nblk_coll_id,
	property_value_password_type,
	property_value_person_id,
	property_value_sw_package_id,
	property_value_token_col_id,
	property_rank,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM property_v57;

INSERT INTO audit.property (
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,		-- new column (account_realm_id)
	company_id,
	device_collection_id,
	dns_domain_id,
	netblock_collection_id,
	layer2_network_id,		-- new column (layer2_network_id)
	layer3_network_id,		-- new column (layer3_network_id)
	operating_system_id,
	person_id,
	service_env_collection_id,
	site_code,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_dns_domain_id,
	property_value_nblk_coll_id,
	property_value_password_type,
	property_value_person_id,
	property_value_sw_package_id,
	property_value_token_col_id,
	property_rank,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	property_id,
	account_collection_id,
	account_id,
	NULL,		-- new column (account_realm_id)
	company_id,
	device_collection_id,
	dns_domain_id,
	netblock_collection_id,
	NULL,		-- new column (layer2_network_id)
	NULL,		-- new column (layer3_network_id)
	operating_system_id,
	person_id,
	service_env_collection_id,
	site_code,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_dns_domain_id,
	property_value_nblk_coll_id,
	property_value_password_type,
	property_value_person_id,
	property_value_sw_package_id,
	property_value_token_col_id,
	property_rank,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.property_v57;

ALTER TABLE property
	ALTER property_id
	SET DEFAULT nextval('property_property_id_seq'::regclass);
ALTER TABLE property
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE property ADD CONSTRAINT pk_property PRIMARY KEY (property_id);

-- Table/Column Comments
COMMENT ON TABLE property IS 'generic property instance that describes system wide properties, as well as properties for various values of columns used throughout the db for configuration, acls, defaults, etc; also used to relate some tables';
COMMENT ON COLUMN property.property_id IS 'primary key for table to uniquely identify rows.';
COMMENT ON COLUMN property.account_collection_id IS 'user collection that properties may be set on.';
COMMENT ON COLUMN property.account_id IS 'system user that properties may be set on.';
COMMENT ON COLUMN property.company_id IS 'company that properties may be set on.';
COMMENT ON COLUMN property.device_collection_id IS 'device collection that properties may be set on.';
COMMENT ON COLUMN property.dns_domain_id IS 'dns domain that properties may be set on.';
COMMENT ON COLUMN property.operating_system_id IS 'operating system that properties may be set on.';
COMMENT ON COLUMN property.site_code IS 'site_code that properties may be set on';
COMMENT ON COLUMN property.property_name IS 'textual name of a property';
COMMENT ON COLUMN property.property_type IS 'textual type of a department';
COMMENT ON COLUMN property.property_value IS 'general purpose column for value of property not defined by other types.  This may be enforced by fk (trigger) if val_property.property_data_type is list (fk is to val_property_value).';
COMMENT ON COLUMN property.property_value_timestamp IS 'property is defined as a timestamp';
COMMENT ON COLUMN property.start_date IS 'date/time that the assignment takes effect';
COMMENT ON COLUMN property.finish_date IS 'date/time that the assignment ceases taking effect';
COMMENT ON COLUMN property.is_enabled IS 'indiciates if the property is temporarily disabled or not.';
-- INDEXES
CREATE INDEX xif20property ON property USING btree (netblock_collection_id);
CREATE INDEX xif19property ON property USING btree (property_value_nblk_coll_id);
CREATE INDEX xifprop_pval_tokcolid ON property USING btree (property_value_token_col_id);
CREATE INDEX xif18property ON property USING btree (person_id);
CREATE INDEX xif21property ON property USING btree (service_env_collection_id);
CREATE INDEX xifprop_pval_compid ON property USING btree (property_value_company_id);
CREATE INDEX xifprop_site_code ON property USING btree (site_code);
CREATE INDEX xif17property ON property USING btree (property_value_person_id);
CREATE INDEX xifprop_devcolid ON property USING btree (device_collection_id);
CREATE INDEX xifprop_account_id ON property USING btree (account_id);
CREATE INDEX xifprop_compid ON property USING btree (company_id);
CREATE INDEX xifprop_nmtyp ON property USING btree (property_name, property_type);
CREATE INDEX xif23property ON property USING btree (layer2_network_id);
CREATE INDEX xif24property ON property USING btree (layer3_network_id);
CREATE INDEX xifprop_pval_swpkgid ON property USING btree (property_value_sw_package_id);
CREATE INDEX xif22property ON property USING btree (account_realm_id);
CREATE INDEX xifprop_pval_pwdtyp ON property USING btree (property_value_password_type);
CREATE INDEX xifprop_pval_dnsdomid ON property USING btree (property_value_dns_domain_id);
CREATE INDEX xifprop_acctcol_id ON property USING btree (account_collection_id);
CREATE INDEX xifprop_pval_acct_colid ON property USING btree (property_value_account_coll_id);
CREATE INDEX xifprop_dnsdomid ON property USING btree (dns_domain_id);
CREATE INDEX xifprop_osid ON property USING btree (operating_system_id);

-- CHECK CONSTRAINTS
ALTER TABLE property ADD CONSTRAINT ckc_prop_isenbld
	CHECK (is_enabled = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK property and layer3_network
-- Skipping this FK since table does not exist yet
--ALTER TABLE property
--	ADD CONSTRAINT fk_prop_l3netid
--	FOREIGN KEY (layer3_network_id) REFERENCES layer3_network(layer3_network_id);

-- consider FK property and person
ALTER TABLE property
	ADD CONSTRAINT fk_property_val_prsnid
	FOREIGN KEY (property_value_person_id) REFERENCES person(person_id);
-- consider FK property and sw_package
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_swpkgid
	FOREIGN KEY (property_value_sw_package_id) REFERENCES sw_package(sw_package_id);
-- consider FK property and netblock_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_pv_nblkcol_id
	FOREIGN KEY (property_value_nblk_coll_id) REFERENCES netblock_collection(netblock_collection_id);
-- consider FK property and account
ALTER TABLE property
	ADD CONSTRAINT fk_property_acctid
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK property and layer2_network
-- Skipping this FK since table does not exist yet
--ALTER TABLE property
--	ADD CONSTRAINT fk_prop_l2netid
--	FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id);

-- consider FK property and person
ALTER TABLE property
	ADD CONSTRAINT fk_property_person_id
	FOREIGN KEY (person_id) REFERENCES person(person_id);
-- consider FK property and val_password_type
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_pwdtyp
	FOREIGN KEY (property_value_password_type) REFERENCES val_password_type(password_type);
-- consider FK property and site
ALTER TABLE property
	ADD CONSTRAINT fk_property_site_code
	FOREIGN KEY (site_code) REFERENCES site(site_code);
-- consider FK property and val_property
ALTER TABLE property
	ADD CONSTRAINT fk_property_nmtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
-- consider FK property and company
ALTER TABLE property
	ADD CONSTRAINT fk_property_compid
	FOREIGN KEY (company_id) REFERENCES company(company_id);
-- consider FK property and service_environment_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_svc_env_coll_id
	FOREIGN KEY (service_env_collection_id) REFERENCES service_environment_collection(service_env_collection_id);
-- consider FK property and device_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_devcolid
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
-- consider FK property and dns_domain
ALTER TABLE property
	ADD CONSTRAINT fk_property_dnsdomid
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);
-- consider FK property and dns_domain
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_dnsdomid
	FOREIGN KEY (property_value_dns_domain_id) REFERENCES dns_domain(dns_domain_id);
-- consider FK property and operating_system
ALTER TABLE property
	ADD CONSTRAINT fk_property_osid
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);
-- consider FK property and account_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_acct_colid
	FOREIGN KEY (property_value_account_coll_id) REFERENCES account_collection(account_collection_id);
-- consider FK property and token_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_tokcolid
	FOREIGN KEY (property_value_token_col_id) REFERENCES token_collection(token_collection_id);
-- consider FK property and account_realm
ALTER TABLE property
	ADD CONSTRAINT fk_property_acctrealmid
	FOREIGN KEY (account_realm_id) REFERENCES account_realm(account_realm_id);
-- consider FK property and account_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_acct_col
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);
-- consider FK property and netblock_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_nblk_coll_id
	FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id);
-- consider FK property and company
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_compid
	FOREIGN KEY (property_value_company_id) REFERENCES company(company_id);

-- TRIGGERS
CREATE TRIGGER trigger_validate_property BEFORE INSERT OR UPDATE ON property FOR EACH ROW EXECUTE PROCEDURE validate_property();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'property');
ALTER SEQUENCE property_property_id_seq
	 OWNED BY property.property_id;
DROP TABLE IF EXISTS property_v57;
DROP TABLE IF EXISTS audit.property_v57;
-- DONE DEALING WITH TABLE property [4352444]
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH TABLE vlan_range [4204396]

-- FOREIGN KEYS FROM
-- Skipping this FK since table been dropped
--ALTER TABLE encapsulation DROP CONSTRAINT IF EXISTS fk_encapsul_fk_encaps_vlan_ran;


-- FOREIGN KEYS TO
ALTER TABLE jazzhands.vlan_range DROP CONSTRAINT IF EXISTS fk_vlan_range_ref_parent_range;
ALTER TABLE jazzhands.vlan_range DROP CONSTRAINT IF EXISTS fk_vlan_ran_ref_site;
ALTER TABLE jazzhands.vlan_range DROP CONSTRAINT IF EXISTS pk_vlan_range;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_vlanrange_sitecode";
DROP INDEX IF EXISTS "jazzhands"."idx_vlanrange_parentvlan";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_audit_vlan_range ON jazzhands.vlan_range;
DROP TRIGGER IF EXISTS trig_userlog_vlan_range ON jazzhands.vlan_range;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'vlan_range');
---- BEGIN audit.vlan_range TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."vlan_range_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'vlan_range');
---- DONE audit.vlan_range TEARDOWN


ALTER TABLE vlan_range RENAME TO vlan_range_v57;
ALTER TABLE audit.vlan_range RENAME TO vlan_range_v57;

DROP TABLE IF EXISTS vlan_range_v57;
DROP TABLE IF EXISTS audit.vlan_range_v57;
-- DONE DEALING WITH OLD TABLE vlan_range [4204396]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_service_env_coll_type [4204274]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_service_env_coll_type', 'val_service_env_coll_type');

-- FOREIGN KEYS FROM
ALTER TABLE service_environment_collection DROP CONSTRAINT IF EXISTS fk_svc_env_col_v_svc_env_type;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.val_service_env_coll_type DROP CONSTRAINT IF EXISTS pk_val_service_env_coll_type;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_service_env_coll_type ON jazzhands.val_service_env_coll_type;
DROP TRIGGER IF EXISTS trigger_audit_val_service_env_coll_type ON jazzhands.val_service_env_coll_type;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_service_env_coll_type');
---- BEGIN audit.val_service_env_coll_type TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_service_env_coll_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_service_env_coll_type');
---- DONE audit.val_service_env_coll_type TEARDOWN


ALTER TABLE val_service_env_coll_type RENAME TO val_service_env_coll_type_v57;
ALTER TABLE audit.val_service_env_coll_type RENAME TO val_service_env_coll_type_v57;

CREATE TABLE val_service_env_coll_type
(
	service_env_collection_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	max_num_members	integer  NULL,
	max_num_collections	integer  NULL,
	can_have_hierarchy	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_service_env_coll_type', false);
ALTER TABLE val_service_env_coll_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;
INSERT INTO val_service_env_coll_type (
	service_env_collection_type,
	description,
	max_num_members,		-- new column (max_num_members)
	max_num_collections,		-- new column (max_num_collections)
	can_have_hierarchy,		-- new column (can_have_hierarchy)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	service_env_collection_type,
	description,
	NULL,		-- new column (max_num_members)
	NULL,		-- new column (max_num_collections)
	'Y'::bpchar,		-- new column (can_have_hierarchy)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_service_env_coll_type_v57;

INSERT INTO audit.val_service_env_coll_type (
	service_env_collection_type,
	description,
	max_num_members,		-- new column (max_num_members)
	max_num_collections,		-- new column (max_num_collections)
	can_have_hierarchy,		-- new column (can_have_hierarchy)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	service_env_collection_type,
	description,
	NULL,		-- new column (max_num_members)
	NULL,		-- new column (max_num_collections)
	NULL,		-- new column (can_have_hierarchy)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_service_env_coll_type_v57;

ALTER TABLE val_service_env_coll_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_service_env_coll_type ADD CONSTRAINT pk_val_service_env_coll_type PRIMARY KEY (service_env_collection_type);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_service_env_coll_type ADD CONSTRAINT check_yes_nosect_hier
	CHECK (can_have_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_service_env_coll_type and service_environment_collection
ALTER TABLE service_environment_collection
	ADD CONSTRAINT fk_svc_env_col_v_svc_env_type
	FOREIGN KEY (service_env_collection_type) REFERENCES val_service_env_coll_type(service_env_collection_type);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_service_env_coll_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_service_env_coll_type');
DROP TABLE IF EXISTS val_service_env_coll_type_v57;
DROP TABLE IF EXISTS audit.val_service_env_coll_type_v57;
-- DONE DEALING WITH TABLE val_service_env_coll_type [4211189]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE layer2_encapsulation [4202997]

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.layer2_encapsulation DROP CONSTRAINT IF EXISTS fk_l2encap_physport_id;
ALTER TABLE jazzhands.layer2_encapsulation DROP CONSTRAINT IF EXISTS fk_l2_encap_val_l2encap_type;
ALTER TABLE jazzhands.layer2_encapsulation DROP CONSTRAINT IF EXISTS fk_l2encap_encap_id;
ALTER TABLE jazzhands.layer2_encapsulation DROP CONSTRAINT IF EXISTS pk_layer2_encapsulation;
ALTER TABLE jazzhands.layer2_encapsulation DROP CONSTRAINT IF EXISTS ak_uq_layer2_encapsul_layer2_e;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_l2encaps_encapsid";
DROP INDEX IF EXISTS "jazzhands"."xif3layer2_encapsulation";
DROP INDEX IF EXISTS "jazzhands"."idx_l2encaps_physport";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_layer2_encapsulation ON jazzhands.layer2_encapsulation;
DROP TRIGGER IF EXISTS trigger_audit_layer2_encapsulation ON jazzhands.layer2_encapsulation;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'layer2_encapsulation');
---- BEGIN audit.layer2_encapsulation TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."layer2_encapsulation_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'layer2_encapsulation');
---- DONE audit.layer2_encapsulation TEARDOWN


ALTER TABLE layer2_encapsulation RENAME TO layer2_encapsulation_v57;
ALTER TABLE audit.layer2_encapsulation RENAME TO layer2_encapsulation_v57;

DROP TABLE IF EXISTS layer2_encapsulation_v57;
DROP TABLE IF EXISTS audit.layer2_encapsulation_v57;
-- DONE DEALING WITH OLD TABLE layer2_encapsulation [4202997]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE network_interface [4203070]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'network_interface', 'network_interface');

-- FOREIGN KEYS FROM
ALTER TABLE secondary_netblock DROP CONSTRAINT IF EXISTS fk_secnblk_netint_id;
ALTER TABLE ip_group_network_interface DROP CONSTRAINT IF EXISTS fk_ipgrp_netint_netint_id;
ALTER TABLE network_service DROP CONSTRAINT IF EXISTS fk_netsvc_netint_id;
ALTER TABLE network_interface_purpose DROP CONSTRAINT IF EXISTS fk_netint_purp_dev_ni_id;
ALTER TABLE static_route_template DROP CONSTRAINT IF EXISTS fk_static_rt_net_interface;
ALTER TABLE static_route DROP CONSTRAINT IF EXISTS fk_statrt_netintdst_id;

SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'network_interface');

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS fk_netint_netblk_v4id;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS fk_netint_device_id;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS fk_network_int_phys_port_devid;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS fk_netint_netinttyp_id;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS fk_netint_ref_parentnetint;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS pk_network_interface_id;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS ak_net_int_devid_netintid;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS fk_netint_devid_name;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_netint_isifaceup";
DROP INDEX IF EXISTS "jazzhands"."idx_netint_shouldmange";
DROP INDEX IF EXISTS "jazzhands"."idx_netint_shouldmonitor";
DROP INDEX IF EXISTS "jazzhands"."ix_netint_typeid";
DROP INDEX IF EXISTS "jazzhands"."idx_netint_parentnetint";
DROP INDEX IF EXISTS "jazzhands"."ix_netint_netdev_id";
DROP INDEX IF EXISTS "jazzhands"."ix_netint_prim_v4id";
DROP INDEX IF EXISTS "jazzhands"."idx_netint_provides_dhcp";
DROP INDEX IF EXISTS "jazzhands"."xif8network_interface";
DROP INDEX IF EXISTS "jazzhands"."idx_netint_providesnat";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS ckc_provides_dhcp_network_;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS ckc_provides_nat_network_;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS ckc_is_interface_up_network_;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS ckc_netint_parent_r_1604677531;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS ckc_should_manage_network_;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_network_interface ON jazzhands.network_interface;
DROP TRIGGER IF EXISTS trigger_audit_network_interface ON jazzhands.network_interface;
---- BEGIN audit.network_interface TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."network_interface_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'network_interface');
---- DONE audit.network_interface TEARDOWN


ALTER TABLE network_interface RENAME TO network_interface_v57;
ALTER TABLE audit.network_interface RENAME TO network_interface_v57;

CREATE TABLE network_interface
(
	network_interface_id	integer NOT NULL,
	device_id	integer NOT NULL,
	network_interface_name	varchar(255)  NULL,
	description	varchar(255)  NULL,
	parent_network_interface_id	integer  NULL,
	parent_relation_type	varchar(255)  NULL,
	netblock_id	integer  NULL,
	physical_port_id	integer  NULL,
	logical_port_id	integer  NULL,
	network_interface_type	varchar(50) NOT NULL,
	is_interface_up	character(1) NOT NULL,
	mac_addr	macaddr  NULL,
	should_monitor	varchar(255) NOT NULL,
	provides_nat	character(1) NOT NULL,
	should_manage	character(1) NOT NULL,
	provides_dhcp	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'network_interface', false);
ALTER TABLE network_interface
	ALTER network_interface_id
	SET DEFAULT nextval('network_interface_network_interface_id_seq'::regclass);
ALTER TABLE network_interface
	ALTER is_interface_up
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE network_interface
	ALTER provides_nat
	SET DEFAULT 'N'::bpchar;
ALTER TABLE network_interface
	ALTER should_manage
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE network_interface
	ALTER provides_dhcp
	SET DEFAULT 'N'::bpchar;
INSERT INTO network_interface (
	network_interface_id,
	device_id,
	network_interface_name,
	description,
	parent_network_interface_id,
	parent_relation_type,
	netblock_id,
	physical_port_id,
	logical_port_id,		-- new column (logical_port_id)
	network_interface_type,
	is_interface_up,
	mac_addr,
	should_monitor,
	provides_nat,
	should_manage,
	provides_dhcp,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	network_interface_id,
	device_id,
	network_interface_name,
	description,
	parent_network_interface_id,
	parent_relation_type,
	netblock_id,
	physical_port_id,
	NULL,		-- new column (logical_port_id)
	network_interface_type,
	is_interface_up,
	mac_addr,
	should_monitor,
	provides_nat,
	should_manage,
	provides_dhcp,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM network_interface_v57;

INSERT INTO audit.network_interface (
	network_interface_id,
	device_id,
	network_interface_name,
	description,
	parent_network_interface_id,
	parent_relation_type,
	netblock_id,
	physical_port_id,
	logical_port_id,		-- new column (logical_port_id)
	network_interface_type,
	is_interface_up,
	mac_addr,
	should_monitor,
	provides_nat,
	should_manage,
	provides_dhcp,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	network_interface_id,
	device_id,
	network_interface_name,
	description,
	parent_network_interface_id,
	parent_relation_type,
	netblock_id,
	physical_port_id,
	NULL,		-- new column (logical_port_id)
	network_interface_type,
	is_interface_up,
	mac_addr,
	should_monitor,
	provides_nat,
	should_manage,
	provides_dhcp,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.network_interface_v57;

ALTER TABLE network_interface
	ALTER network_interface_id
	SET DEFAULT nextval('network_interface_network_interface_id_seq'::regclass);
ALTER TABLE network_interface
	ALTER is_interface_up
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE network_interface
	ALTER provides_nat
	SET DEFAULT 'N'::bpchar;
ALTER TABLE network_interface
	ALTER should_manage
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE network_interface
	ALTER provides_dhcp
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE network_interface ADD CONSTRAINT pk_network_interface_id PRIMARY KEY (network_interface_id);
ALTER TABLE network_interface ADD CONSTRAINT ak_net_int_devid_netintid UNIQUE (network_interface_id, device_id);
ALTER TABLE network_interface ADD CONSTRAINT fk_netint_devid_name UNIQUE (device_id, network_interface_name);

-- Table/Column Comments
COMMENT ON COLUMN network_interface.physical_port_id IS 'This column will be dropped!';
-- INDEXES
CREATE INDEX xif_netint_typeid ON network_interface USING btree (network_interface_type);
CREATE INDEX xif_net_int_lgl_port_id ON network_interface USING btree (logical_port_id);
CREATE INDEX xif_netint_prim_v4id ON network_interface USING btree (netblock_id);
CREATE INDEX xif_netint_parentnetint ON network_interface USING btree (parent_network_interface_id);
CREATE INDEX idx_netint_isifaceup ON network_interface USING btree (is_interface_up);
CREATE INDEX idx_netint_shouldmange ON network_interface USING btree (should_manage);
CREATE INDEX xif_net_int_phs_port_devid ON network_interface USING btree (physical_port_id, device_id);
CREATE INDEX idx_netint_provides_dhcp ON network_interface USING btree (provides_dhcp);
CREATE INDEX idx_netint_providesnat ON network_interface USING btree (provides_nat);
CREATE INDEX idx_netint_shouldmonitor ON network_interface USING btree (should_monitor);
CREATE INDEX xif_netint_netdev_id ON network_interface USING btree (device_id);

-- CHECK CONSTRAINTS
ALTER TABLE network_interface ADD CONSTRAINT ckc_should_manage_network_
	CHECK ((should_manage = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((should_manage)::text = upper((should_manage)::text)));
ALTER TABLE network_interface ADD CONSTRAINT ckc_netint_parent_r_1604677531
	CHECK ((parent_relation_type)::text = ANY ((ARRAY['NONE'::character varying, 'SUBINTERFACE'::character varying, 'SECONDARY'::character varying])::text[]));
ALTER TABLE network_interface ADD CONSTRAINT ckc_is_interface_up_network_
	CHECK ((is_interface_up = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_interface_up)::text = upper((is_interface_up)::text)));
ALTER TABLE network_interface ADD CONSTRAINT ckc_provides_nat_network_
	CHECK ((provides_nat = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((provides_nat)::text = upper((provides_nat)::text)));
ALTER TABLE network_interface ADD CONSTRAINT ckc_provides_dhcp_network_
	CHECK ((provides_dhcp = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((provides_dhcp)::text = upper((provides_dhcp)::text)));

-- FOREIGN KEYS FROM
-- consider FK network_interface and network_service
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_netint_id
	FOREIGN KEY (network_interface_id) REFERENCES network_interface(network_interface_id);
-- consider FK network_interface and ip_group_network_interface
ALTER TABLE ip_group_network_interface
	ADD CONSTRAINT fk_ipgrp_netint_netint_id
	FOREIGN KEY (network_interface_id) REFERENCES network_interface(network_interface_id);
-- consider FK network_interface and static_route_template
ALTER TABLE static_route_template
	ADD CONSTRAINT fk_static_rt_net_interface
	FOREIGN KEY (network_interface_dst_id) REFERENCES network_interface(network_interface_id);
-- consider FK network_interface and static_route
ALTER TABLE static_route
	ADD CONSTRAINT fk_statrt_netintdst_id
	FOREIGN KEY (network_interface_dst_id) REFERENCES network_interface(network_interface_id);
-- consider FK network_interface and network_interface_netblock
-- Skipping this FK since table does not exist yet
--ALTER TABLE network_interface_netblock
--	ADD CONSTRAINT fk_netint_nb_nblk_id
--	FOREIGN KEY (network_interface_id) REFERENCES network_interface(network_interface_id);

-- consider FK network_interface and network_interface_purpose
ALTER TABLE network_interface_purpose
	ADD CONSTRAINT fk_netint_purp_dev_ni_id
	FOREIGN KEY (network_interface_id, device_id) REFERENCES network_interface(network_interface_id, device_id);

-- FOREIGN KEYS TO
-- consider FK network_interface and physical_port
ALTER TABLE network_interface
	ADD CONSTRAINT fk_network_int_phys_port_devid
	FOREIGN KEY (physical_port_id, device_id) REFERENCES physical_port(physical_port_id, device_id);
-- consider FK network_interface and val_network_interface_type
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_netinttyp_id
	FOREIGN KEY (network_interface_type) REFERENCES val_network_interface_type(network_interface_type);
-- consider FK network_interface and netblock
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_netblk_v4id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
-- consider FK network_interface and device
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK network_interface and network_interface
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_ref_parentnetint
	FOREIGN KEY (parent_network_interface_id) REFERENCES network_interface(network_interface_id);
-- consider FK network_interface and logical_port
-- Skipping this FK since table does not exist yet
--ALTER TABLE network_interface
--	ADD CONSTRAINT fk_net_int_lgl_port_id
--	FOREIGN KEY (logical_port_id) REFERENCES logical_port(logical_port_id);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'network_interface');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'network_interface');
ALTER SEQUENCE network_interface_network_interface_id_seq
	 OWNED BY network_interface.network_interface_id;
DROP TABLE IF EXISTS network_interface_v57;
DROP TABLE IF EXISTS audit.network_interface_v57;
-- DONE DEALING WITH TABLE network_interface [4209950]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE secondary_netblock [4203450]

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.secondary_netblock DROP CONSTRAINT IF EXISTS fk_secnblk_nblk_id;
ALTER TABLE jazzhands.secondary_netblock DROP CONSTRAINT IF EXISTS fk_secnblk_netint_id;
ALTER TABLE jazzhands.secondary_netblock DROP CONSTRAINT IF EXISTS pk_secondary_netblock_id;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_secntblk_netblock";
DROP INDEX IF EXISTS "jazzhands"."idx_secntblk_netint";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.secondary_netblock DROP CONSTRAINT IF EXISTS ckc_mac_addr_secondar;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_audit_secondary_netblock ON jazzhands.secondary_netblock;
DROP TRIGGER IF EXISTS trig_userlog_secondary_netblock ON jazzhands.secondary_netblock;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'secondary_netblock');
---- BEGIN audit.secondary_netblock TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."secondary_netblock_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'secondary_netblock');
---- DONE audit.secondary_netblock TEARDOWN


ALTER TABLE secondary_netblock RENAME TO secondary_netblock_v57;
ALTER TABLE audit.secondary_netblock RENAME TO secondary_netblock_v57;

DROP TABLE IF EXISTS secondary_netblock_v57;
DROP TABLE IF EXISTS audit.secondary_netblock_v57;
-- DONE DEALING WITH OLD TABLE secondary_netblock [4203450]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE device [4202600]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'device', 'device');

-- FOREIGN KEYS FROM
ALTER TABLE physical_port DROP CONSTRAINT IF EXISTS fk_phys_port_dev_id;
ALTER TABLE network_interface_purpose DROP CONSTRAINT IF EXISTS fk_netint_purpose_device_id;
ALTER TABLE device_power_interface DROP CONSTRAINT IF EXISTS fk_device_device_power_supp;
ALTER TABLE device_ticket DROP CONSTRAINT IF EXISTS fk_dev_tkt_dev_id;
ALTER TABLE device_management_controller DROP CONSTRAINT IF EXISTS fk_dvc_mgmt_ctrl_mgr_dev_id;
ALTER TABLE static_route DROP CONSTRAINT IF EXISTS fk_statrt_devsrc_id;
ALTER TABLE network_service DROP CONSTRAINT IF EXISTS fk_netsvc_device_id;
ALTER TABLE chassis_location DROP CONSTRAINT IF EXISTS fk_chass_loc_chass_devid;
ALTER TABLE layer1_connection DROP CONSTRAINT IF EXISTS fk_l1conn_ref_device;
ALTER TABLE device_collection_device DROP CONSTRAINT IF EXISTS fk_devcolldev_dev_id;
ALTER TABLE network_interface DROP CONSTRAINT IF EXISTS fk_netint_device_id;
ALTER TABLE snmp_commstr DROP CONSTRAINT IF EXISTS fk_snmpstr_device_id;
ALTER TABLE device_note DROP CONSTRAINT IF EXISTS fk_device_note_device;
ALTER TABLE device_ssh_key DROP CONSTRAINT IF EXISTS fk_dev_ssh_key_ssh_key_id;
ALTER TABLE device_management_controller DROP CONSTRAINT IF EXISTS fk_dev_mgmt_ctlr_dev_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_ref_parent_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_legacy_location_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_dnsrecord;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_chasloc_chass_devid;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_reference_val_devi;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_ref_voesymbtrk;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_vownerstatus;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_fk_dev_v_svcenv;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_site_code;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_os_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_chass_loc_id_mod_enfc;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_fk_dev_val_stat;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_rack_location_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_fk_voe;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_devtp_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS pk_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ak_device_rack_location_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ak_device_chassis_location_id;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_dev_islclymgd";
DROP INDEX IF EXISTS "jazzhands"."xif13device";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_osid";
DROP INDEX IF EXISTS "jazzhands"."idx_device_type_location";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_dev_status";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_svcenv";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_iddnsrec";
DROP INDEX IF EXISTS "jazzhands"."xif16device";
DROP INDEX IF EXISTS "jazzhands"."xifdevice_sitecode";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_ownershipstatus";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_voeid";
DROP INDEX IF EXISTS "jazzhands"."ix_netdev_devtype_id";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_ismonitored";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069059;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069056;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069055;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069060;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069054;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ckc_is_virtual_device_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ckc_is_monitored_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ckc_is_locally_manage_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069057;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ckc_should_fetch_conf_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069061;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ckc_is_baselined_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069052;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069051;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_aaa_device_location_migration_1 ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_delete_per_device_device_collection ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_device_update_location_fix ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_audit_device ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_device_one_location_validate ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_verify_device_voe ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_update_per_device_device_collection ON jazzhands.device;
DROP TRIGGER IF EXISTS trig_userlog_device ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_aaa_device_location_migration_2 ON jazzhands.device;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'device');
---- BEGIN audit.device TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."device_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'device');
---- DONE audit.device TEARDOWN


ALTER TABLE device RENAME TO device_v57;
ALTER TABLE audit.device RENAME TO device_v57;

CREATE TABLE device
(
	device_id	integer NOT NULL,
	device_type_id	integer NOT NULL,
	company_id	integer  NULL,
	asset_id	integer  NULL,
	device_name	varchar(255)  NULL,
	site_code	varchar(50)  NULL,
	identifying_dns_record_id	integer  NULL,
	serial_number	varchar(255)  NULL,
	part_number	varchar(255)  NULL,
	host_id	varchar(255)  NULL,
	physical_label	varchar(255)  NULL,
	asset_tag	varchar(255)  NULL,
	rack_location_id	integer  NULL,
	chassis_location_id	integer  NULL,
	parent_device_id	integer  NULL,
	description	varchar(255)  NULL,
	device_status	varchar(50) NOT NULL,
	service_environment	varchar(50) NOT NULL,
	operating_system_id	integer NOT NULL,
	voe_id	integer  NULL,
	ownership_status	varchar(50) NOT NULL,
	auto_mgmt_protocol	varchar(50)  NULL,
	voe_symbolic_track_id	integer  NULL,
	is_locally_managed	character(1) NOT NULL,
	is_monitored	character(1) NOT NULL,
	is_virtual_device	character(1) NOT NULL,
	should_fetch_config	character(1) NOT NULL,
	is_baselined	character(1) NOT NULL,
	lease_expiration_date	timestamp with time zone  NULL,
	date_in_service	timestamp with time zone  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device', false);
ALTER TABLE device
	ALTER device_id
	SET DEFAULT nextval('device_device_id_seq'::regclass);
ALTER TABLE device
	ALTER operating_system_id
	SET DEFAULT 0;
ALTER TABLE device
	ALTER is_locally_managed
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE device
	ALTER is_virtual_device
	SET DEFAULT 'N'::bpchar;
ALTER TABLE device
	ALTER should_fetch_config
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE device
	ALTER is_baselined
	SET DEFAULT 'N'::bpchar;
INSERT INTO device (
	device_id,
	device_type_id,
	company_id,		-- new column (company_id)
	asset_id,		-- new column (asset_id)
	device_name,
	site_code,
	identifying_dns_record_id,
	serial_number,
	part_number,
	host_id,
	physical_label,
	asset_tag,
	rack_location_id,
	chassis_location_id,
	parent_device_id,
	description,
	device_status,
	service_environment,
	operating_system_id,
	voe_id,
	ownership_status,
	auto_mgmt_protocol,
	voe_symbolic_track_id,
	is_locally_managed,
	is_monitored,
	is_virtual_device,
	should_fetch_config,
	is_baselined,
	lease_expiration_date,
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	device_id,
	device_type_id,
	NULL,		-- new column (company_id)
	NULL,		-- new column (asset_id)
	device_name,
	site_code,
	identifying_dns_record_id,
	serial_number,
	part_number,
	host_id,
	physical_label,
	asset_tag,
	rack_location_id,
	chassis_location_id,
	parent_device_id,
	description,
	device_status,
	service_environment,
	operating_system_id,
	voe_id,
	ownership_status,
	auto_mgmt_protocol,
	voe_symbolic_track_id,
	is_locally_managed,
	is_monitored,
	is_virtual_device,
	should_fetch_config,
	is_baselined,
	lease_expiration_date,
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM device_v57;

INSERT INTO audit.device (
	device_id,
	device_type_id,
	company_id,		-- new column (company_id)
	asset_id,		-- new column (asset_id)
	device_name,
	site_code,
	identifying_dns_record_id,
	serial_number,
	part_number,
	host_id,
	physical_label,
	asset_tag,
	rack_location_id,
	chassis_location_id,
	parent_device_id,
	description,
	device_status,
	service_environment,
	operating_system_id,
	voe_id,
	ownership_status,
	auto_mgmt_protocol,
	voe_symbolic_track_id,
	is_locally_managed,
	is_monitored,
	is_virtual_device,
	should_fetch_config,
	is_baselined,
	lease_expiration_date,
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	device_id,
	device_type_id,
	NULL,		-- new column (company_id)
	NULL,		-- new column (asset_id)
	device_name,
	site_code,
	identifying_dns_record_id,
	serial_number,
	part_number,
	host_id,
	physical_label,
	asset_tag,
	rack_location_id,
	chassis_location_id,
	parent_device_id,
	description,
	device_status,
	service_environment,
	operating_system_id,
	voe_id,
	ownership_status,
	auto_mgmt_protocol,
	voe_symbolic_track_id,
	is_locally_managed,
	is_monitored,
	is_virtual_device,
	should_fetch_config,
	is_baselined,
	lease_expiration_date,
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.device_v57;

ALTER TABLE device
	ALTER device_id
	SET DEFAULT nextval('device_device_id_seq'::regclass);
ALTER TABLE device
	ALTER operating_system_id
	SET DEFAULT 0;
ALTER TABLE device
	ALTER is_locally_managed
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE device
	ALTER is_virtual_device
	SET DEFAULT 'N'::bpchar;
ALTER TABLE device
	ALTER should_fetch_config
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE device
	ALTER is_baselined
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device ADD CONSTRAINT ak_device_chassis_location_id UNIQUE (chassis_location_id);
-- ALTER TABLE device ADD CONSTRAINT ak_device_rack_location_id UNIQUE (rack_location_id);
ALTER TABLE device ADD CONSTRAINT pk_device PRIMARY KEY (device_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif17device ON device USING btree (company_id);
CREATE INDEX idx_dev_voeid ON device USING btree (voe_id);
CREATE INDEX idx_dev_ownershipstatus ON device USING btree (ownership_status);
CREATE INDEX xifdevice_sitecode ON device USING btree (site_code);
CREATE INDEX xif18device ON device USING btree (asset_id);
CREATE INDEX idx_dev_ismonitored ON device USING btree (is_monitored);
CREATE INDEX idx_dev_osid ON device USING btree (operating_system_id);
CREATE INDEX idx_dev_islclymgd ON device USING btree (is_locally_managed);
CREATE INDEX idx_device_type_location ON device USING btree (device_type_id);
CREATE INDEX idx_dev_svcenv ON device USING btree (service_environment);
CREATE INDEX xif16device ON device USING btree (chassis_location_id, parent_device_id, device_type_id);
CREATE INDEX idx_dev_iddnsrec ON device USING btree (identifying_dns_record_id);
CREATE INDEX idx_dev_dev_status ON device USING btree (device_status);

-- CHECK CONSTRAINTS
ALTER TABLE device ADD CONSTRAINT sys_c0069060
	CHECK (should_fetch_config IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069056
	CHECK (ownership_status IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069059
	CHECK (is_virtual_device IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT dev_osid_notnull
	CHECK (operating_system_id IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069057
	CHECK (is_monitored IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT ckc_is_locally_manage_device
	CHECK ((is_locally_managed = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_locally_managed)::text = upper((is_locally_managed)::text)));
ALTER TABLE device ADD CONSTRAINT ckc_is_baselined_device
	CHECK ((is_baselined = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_baselined)::text = upper((is_baselined)::text)));
ALTER TABLE device ADD CONSTRAINT sys_c0069051
	CHECK (device_id IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069052
	CHECK (device_type_id IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069061
	CHECK (is_baselined IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT ckc_should_fetch_conf_device
	CHECK ((should_fetch_config = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((should_fetch_config)::text = upper((should_fetch_config)::text)));
ALTER TABLE device ADD CONSTRAINT sys_c0069054
	CHECK (service_environment IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT ckc_is_virtual_device_device
	CHECK ((is_virtual_device = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_virtual_device)::text = upper((is_virtual_device)::text)));
ALTER TABLE device ADD CONSTRAINT ckc_is_monitored_device
	CHECK ((is_monitored = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_monitored)::text = upper((is_monitored)::text)));

-- FOREIGN KEYS FROM
-- consider FK device and device_ticket
ALTER TABLE device_ticket
	ADD CONSTRAINT fk_dev_tkt_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and device_management_controller
ALTER TABLE device_management_controller
	ADD CONSTRAINT fk_dvc_mgmt_ctrl_mgr_dev_id
	FOREIGN KEY (manager_device_id) REFERENCES device(device_id);
-- consider FK device and device_layer2_network
-- Skipping this FK since table does not exist yet
--ALTER TABLE device_layer2_network
--	ADD CONSTRAINT fk_device_l2_net_devid
--	FOREIGN KEY (device_id) REFERENCES device(device_id);

-- consider FK device and physical_port
ALTER TABLE physical_port
	ADD CONSTRAINT fk_phys_port_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and device_encapsulation_domain
-- Skipping this FK since table does not exist yet
--ALTER TABLE device_encapsulation_domain
--	ADD CONSTRAINT fk_dev_encap_domain_devid
--	FOREIGN KEY (device_id) REFERENCES device(device_id);

-- consider FK device and mlag_peering
-- Skipping this FK since table does not exist yet
--ALTER TABLE mlag_peering
--	ADD CONSTRAINT fk_mlag_peering_devid2
--	FOREIGN KEY (device2_id) REFERENCES device(device_id);

-- consider FK device and snmp_commstr
ALTER TABLE snmp_commstr
	ADD CONSTRAINT fk_snmpstr_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and device_management_controller
ALTER TABLE device_management_controller
	ADD CONSTRAINT fk_dev_mgmt_ctlr_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and device_ssh_key
ALTER TABLE device_ssh_key
	ADD CONSTRAINT fk_dev_ssh_key_ssh_key_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and device_note
ALTER TABLE device_note
	ADD CONSTRAINT fk_device_note_device
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and layer1_connection
ALTER TABLE layer1_connection
	ADD CONSTRAINT fk_l1conn_ref_device
	FOREIGN KEY (tcpsrv_device_id) REFERENCES device(device_id);
-- consider FK device and device_collection_device
ALTER TABLE device_collection_device
	ADD CONSTRAINT fk_devcolldev_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and network_interface
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and static_route
ALTER TABLE static_route
	ADD CONSTRAINT fk_statrt_devsrc_id
	FOREIGN KEY (device_src_id) REFERENCES device(device_id);
-- consider FK device and network_service
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and network_interface_purpose
ALTER TABLE network_interface_purpose
	ADD CONSTRAINT fk_netint_purpose_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and device_power_interface
ALTER TABLE device_power_interface
	ADD CONSTRAINT fk_device_device_power_supp
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and mlag_peering
-- Skipping this FK since table does not exist yet
--ALTER TABLE mlag_peering
--	ADD CONSTRAINT fk_mlag_peering_devid1
--	FOREIGN KEY (device1_id) REFERENCES device(device_id);

-- consider FK device and chassis_location
ALTER TABLE chassis_location
	ADD CONSTRAINT fk_chass_loc_chass_devid
	FOREIGN KEY (chassis_device_id) REFERENCES device(device_id) DEFERRABLE;

-- FOREIGN KEYS TO
-- consider FK device and site
ALTER TABLE device
	ADD CONSTRAINT fk_device_site_code
	FOREIGN KEY (site_code) REFERENCES site(site_code);
-- consider FK device and service_environment
ALTER TABLE device
	ADD CONSTRAINT fk_device_fk_dev_v_svcenv
	FOREIGN KEY (service_environment) REFERENCES service_environment(service_environment);
-- consider FK device and company
ALTER TABLE device
	ADD CONSTRAINT fk_device_company__id
	FOREIGN KEY (company_id) REFERENCES company(company_id);
-- consider FK device and rack_location
ALTER TABLE device
	ADD CONSTRAINT fk_dev_rack_location_id
	FOREIGN KEY (rack_location_id) REFERENCES rack_location(rack_location_id);
-- consider FK device and val_device_status
ALTER TABLE device
	ADD CONSTRAINT fk_device_fk_dev_val_stat
	FOREIGN KEY (device_status) REFERENCES val_device_status(device_status);
-- consider FK device and dns_record
ALTER TABLE device
	ADD CONSTRAINT fk_device_dnsrecord
	FOREIGN KEY (identifying_dns_record_id) REFERENCES dns_record(dns_record_id);
-- consider FK device and operating_system
ALTER TABLE device
	ADD CONSTRAINT fk_dev_os_id
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);
-- consider FK device and val_ownership_status
ALTER TABLE device
	ADD CONSTRAINT fk_device_vownerstatus
	FOREIGN KEY (ownership_status) REFERENCES val_ownership_status(ownership_status);
-- consider FK device and voe_symbolic_track
ALTER TABLE device
	ADD CONSTRAINT fk_device_ref_voesymbtrk
	FOREIGN KEY (voe_symbolic_track_id) REFERENCES voe_symbolic_track(voe_symbolic_track_id);
-- consider FK device and voe
ALTER TABLE device
	ADD CONSTRAINT fk_device_fk_voe
	FOREIGN KEY (voe_id) REFERENCES voe(voe_id);
-- consider FK device and device_type
ALTER TABLE device
	ADD CONSTRAINT fk_dev_devtp_id
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);
-- consider FK device and asset
-- Skipping this FK since table does not exist yet
--ALTER TABLE device
--	ADD CONSTRAINT fk_device_asset_id
--	FOREIGN KEY (asset_id) REFERENCES asset(asset_id);

-- consider FK device and chassis_location
ALTER TABLE device
	ADD CONSTRAINT fk_dev_chass_loc_id_mod_enfc
	FOREIGN KEY (chassis_location_id, parent_device_id, device_type_id) REFERENCES chassis_location(chassis_location_id, chassis_device_id, module_device_type_id) DEFERRABLE;
-- consider FK device and val_device_auto_mgmt_protocol
ALTER TABLE device
	ADD CONSTRAINT fk_device_reference_val_devi
	FOREIGN KEY (auto_mgmt_protocol) REFERENCES val_device_auto_mgmt_protocol(auto_mgmt_protocol);
-- consider FK device and chassis_location
ALTER TABLE device
	ADD CONSTRAINT fk_chasloc_chass_devid
	FOREIGN KEY (chassis_location_id) REFERENCES chassis_location(chassis_location_id) DEFERRABLE;
-- consider FK device and device
ALTER TABLE device
	ADD CONSTRAINT fk_device_ref_parent_device
	FOREIGN KEY (parent_device_id) REFERENCES device(device_id);

-- TRIGGERS
CREATE TRIGGER trigger_device_one_location_validate BEFORE INSERT OR UPDATE ON device FOR EACH ROW EXECUTE PROCEDURE device_one_location_validate();

-- XXX - may need to include trigger function
CREATE TRIGGER trigger_verify_device_voe BEFORE INSERT OR UPDATE ON device FOR EACH ROW EXECUTE PROCEDURE verify_device_voe();

-- XXX - may need to include trigger function
CREATE TRIGGER trigger_delete_per_device_device_collection BEFORE DELETE ON device FOR EACH ROW EXECUTE PROCEDURE delete_per_device_device_collection();

-- XXX - may need to include trigger function
CREATE TRIGGER trigger_update_per_device_device_collection AFTER INSERT OR UPDATE ON device FOR EACH ROW EXECUTE PROCEDURE update_per_device_device_collection();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device');
ALTER SEQUENCE device_device_id_seq
	 OWNED BY device.device_id;
DROP TABLE IF EXISTS device_v57;
DROP TABLE IF EXISTS audit.device_v57;
-- DONE DEALING WITH TABLE device [4209385]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE encapsulation_netblock [4202886]

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.encapsulation_netblock DROP CONSTRAINT IF EXISTS fk_encap_netblock_nblk_id;
ALTER TABLE jazzhands.encapsulation_netblock DROP CONSTRAINT IF EXISTS fk_encap_netblock_encap_id;
ALTER TABLE jazzhands.encapsulation_netblock DROP CONSTRAINT IF EXISTS pk_encapsulation_netblock;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1encapsulation_netblock";
DROP INDEX IF EXISTS "jazzhands"."xif2encapsulation_netblock";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_encapsulation_netblock ON jazzhands.encapsulation_netblock;
DROP TRIGGER IF EXISTS trigger_audit_encapsulation_netblock ON jazzhands.encapsulation_netblock;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'encapsulation_netblock');
---- BEGIN audit.encapsulation_netblock TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."encapsulation_netblock_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'encapsulation_netblock');
---- DONE audit.encapsulation_netblock TEARDOWN


ALTER TABLE encapsulation_netblock RENAME TO encapsulation_netblock_v57;
ALTER TABLE audit.encapsulation_netblock RENAME TO encapsulation_netblock_v57;

DROP TABLE IF EXISTS encapsulation_netblock_v57;
DROP TABLE IF EXISTS audit.encapsulation_netblock_v57;
-- DONE DEALING WITH OLD TABLE encapsulation_netblock [4202886]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE device_coll_account_coll [4202644]

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.device_coll_account_coll DROP CONSTRAINT IF EXISTS fk_devcolacct_col_devcolid;
ALTER TABLE jazzhands.device_coll_account_coll DROP CONSTRAINT IF EXISTS fk_dev_coll_acct_coll_acctcoli;
ALTER TABLE jazzhands.device_coll_account_coll DROP CONSTRAINT IF EXISTS pk_device_coll_account_coll;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xifk_devcolacct_col_devcolid";
DROP INDEX IF EXISTS "jazzhands"."xifk_devcolacct_col_acctcolid";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_device_coll_account_coll ON jazzhands.device_coll_account_coll;
DROP TRIGGER IF EXISTS trigger_audit_device_coll_account_coll ON jazzhands.device_coll_account_coll;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'device_coll_account_coll');
---- BEGIN audit.device_coll_account_coll TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."device_coll_account_coll_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'device_coll_account_coll');
---- DONE audit.device_coll_account_coll TEARDOWN


ALTER TABLE device_coll_account_coll RENAME TO device_coll_account_coll_v57;
ALTER TABLE audit.device_coll_account_coll RENAME TO device_coll_account_coll_v57;

DROP TABLE IF EXISTS device_coll_account_coll_v57;
DROP TABLE IF EXISTS audit.device_coll_account_coll_v57;
-- DONE DEALING WITH OLD TABLE device_coll_account_coll [4202644]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_layer2_encapsulation_type [4203968]

-- FOREIGN KEYS FROM
-- Skipping this FK since table been dropped
--ALTER TABLE layer2_encapsulation DROP CONSTRAINT IF EXISTS fk_l2_encap_val_l2encap_type;


-- FOREIGN KEYS TO
ALTER TABLE jazzhands.val_layer2_encapsulation_type DROP CONSTRAINT IF EXISTS pk_val_layer2_encapsulation_ty;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_layer2_encapsulation_type ON jazzhands.val_layer2_encapsulation_type;
DROP TRIGGER IF EXISTS trigger_audit_val_layer2_encapsulation_type ON jazzhands.val_layer2_encapsulation_type;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_layer2_encapsulation_type');
---- BEGIN audit.val_layer2_encapsulation_type TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_layer2_encapsulation_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_layer2_encapsulation_type');
---- DONE audit.val_layer2_encapsulation_type TEARDOWN


ALTER TABLE val_layer2_encapsulation_type RENAME TO val_layer2_encapsulation_type_v57;
ALTER TABLE audit.val_layer2_encapsulation_type RENAME TO val_layer2_encapsulation_type_v57;

DROP TABLE IF EXISTS val_layer2_encapsulation_type_v57;
DROP TABLE IF EXISTS audit.val_layer2_encapsulation_type_v57;
-- DONE DEALING WITH OLD TABLE val_layer2_encapsulation_type [4203968]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE dns_domain [4202829]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_domain', 'dns_domain');

-- FOREIGN KEYS FROM
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_pval_dnsdomid;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_dnsdomid;
ALTER TABLE dns_record DROP CONSTRAINT IF EXISTS fk_dnsid_dnsdom_id;
ALTER TABLE network_range DROP CONSTRAINT IF EXISTS fk_net_range_dns_domain_id;
ALTER TABLE dns_change_record DROP CONSTRAINT IF EXISTS fk_dns_chg_dns_domain;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.dns_domain DROP CONSTRAINT IF EXISTS fk_dns_dom_dns_dom_typ;
ALTER TABLE jazzhands.dns_domain DROP CONSTRAINT IF EXISTS fk_dnsdom_dnsdom_id;
ALTER TABLE jazzhands.dns_domain DROP CONSTRAINT IF EXISTS pk_dns_domain;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xifdns_dom_dns_dom_type";
DROP INDEX IF EXISTS "jazzhands"."idx_dnsdomain_parentdnsdomain";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.dns_domain DROP CONSTRAINT IF EXISTS ckc_should_generate_dns_doma;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_audit_dns_domain ON jazzhands.dns_domain;
DROP TRIGGER IF EXISTS trig_userlog_dns_domain ON jazzhands.dns_domain;
DROP TRIGGER IF EXISTS trigger_dns_domain_trigger_change ON jazzhands.dns_domain;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'dns_domain');
---- BEGIN audit.dns_domain TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."dns_domain_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'dns_domain');
---- DONE audit.dns_domain TEARDOWN


ALTER TABLE dns_domain RENAME TO dns_domain_v57;
ALTER TABLE audit.dns_domain RENAME TO dns_domain_v57;

CREATE TABLE dns_domain
(
	dns_domain_id	integer NOT NULL,
	soa_name	varchar(255)  NULL,
	soa_class	varchar(50)  NULL,
	soa_ttl	integer  NULL,
	soa_serial	bigint  NULL,
	soa_refresh	integer  NULL,
	soa_retry	integer  NULL,
	soa_expire	integer  NULL,
	soa_minimum	integer  NULL,
	soa_mname	varchar(255)  NULL,
	soa_rname	varchar(255) NOT NULL,
	parent_dns_domain_id	integer  NULL,
	should_generate	character(1) NOT NULL,
	last_generated	timestamp with time zone  NULL,
	dns_domain_type	varchar(50) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'dns_domain', false);
ALTER TABLE dns_domain
	ALTER dns_domain_id
	SET DEFAULT nextval('dns_domain_dns_domain_id_seq'::regclass);
INSERT INTO dns_domain (
	dns_domain_id,
	soa_name,
	soa_class,
	soa_ttl,
	soa_serial,
	soa_refresh,
	soa_retry,
	soa_expire,
	soa_minimum,
	soa_mname,
	soa_rname,
	parent_dns_domain_id,
	should_generate,
	last_generated,
	dns_domain_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	dns_domain_id,
	soa_name,
	soa_class,
	soa_ttl,
	soa_serial,
	soa_refresh,
	soa_retry,
	soa_expire,
	soa_minimum,
	soa_mname,
	soa_rname,
	parent_dns_domain_id,
	should_generate,
	last_generated,
	dns_domain_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM dns_domain_v57;

INSERT INTO audit.dns_domain (
	dns_domain_id,
	soa_name,
	soa_class,
	soa_ttl,
	soa_serial,
	soa_refresh,
	soa_retry,
	soa_expire,
	soa_minimum,
	soa_mname,
	soa_rname,
	parent_dns_domain_id,
	should_generate,
	last_generated,
	dns_domain_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	dns_domain_id,
	soa_name,
	soa_class,
	soa_ttl,
	soa_serial,
	soa_refresh,
	soa_retry,
	soa_expire,
	soa_minimum,
	soa_mname,
	soa_rname,
	parent_dns_domain_id,
	should_generate,
	last_generated,
	dns_domain_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.dns_domain_v57;

ALTER TABLE dns_domain
	ALTER dns_domain_id
	SET DEFAULT nextval('dns_domain_dns_domain_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE dns_domain ADD CONSTRAINT pk_dns_domain PRIMARY KEY (dns_domain_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xifdns_dom_dns_dom_type ON dns_domain USING btree (dns_domain_type);
CREATE INDEX idx_dnsdomain_parentdnsdomain ON dns_domain USING btree (parent_dns_domain_id);

-- CHECK CONSTRAINTS
ALTER TABLE dns_domain ADD CONSTRAINT ckc_should_generate_dns_doma
	CHECK ((should_generate = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((should_generate)::text = upper((should_generate)::text)));

-- FOREIGN KEYS FROM
-- consider FK dns_domain and dns_record
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsid_dnsdom_id
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);
-- consider FK dns_domain and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_dnsdomid
	FOREIGN KEY (property_value_dns_domain_id) REFERENCES dns_domain(dns_domain_id);
-- consider FK dns_domain and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_dnsdomid
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);
-- consider FK dns_domain and dns_change_record
ALTER TABLE dns_change_record
	ADD CONSTRAINT fk_dns_chg_dns_domain
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);
-- consider FK dns_domain and network_range
ALTER TABLE network_range
	ADD CONSTRAINT fk_net_range_dns_domain_id
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);

-- FOREIGN KEYS TO
-- consider FK dns_domain and val_dns_domain_type
ALTER TABLE dns_domain
	ADD CONSTRAINT fk_dns_dom_dns_dom_typ
	FOREIGN KEY (dns_domain_type) REFERENCES val_dns_domain_type(dns_domain_type);
-- consider FK dns_domain and dns_domain
ALTER TABLE dns_domain
	ADD CONSTRAINT fk_dnsdom_dnsdom_id
	FOREIGN KEY (parent_dns_domain_id) REFERENCES dns_domain(dns_domain_id);

-- TRIGGERS
CREATE TRIGGER trigger_dns_domain_trigger_change AFTER INSERT OR UPDATE OF soa_name, soa_class, soa_ttl, soa_refresh, soa_retry, soa_expire, soa_minimum, soa_mname, soa_rname, should_generate ON dns_domain FOR EACH ROW EXECUTE PROCEDURE dns_domain_trigger_change();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'dns_domain');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'dns_domain');
ALTER SEQUENCE dns_domain_dns_domain_id_seq
	 OWNED BY dns_domain.dns_domain_id;
DROP TABLE IF EXISTS dns_domain_v57;
DROP TABLE IF EXISTS audit.dns_domain_v57;
-- DONE DEALING WITH TABLE dns_domain [4209647]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_token_collection_type [4204330]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_token_collection_type', 'val_token_collection_type');

-- FOREIGN KEYS FROM
ALTER TABLE token_collection DROP CONSTRAINT IF EXISTS fk_tok_col_mem_token_col_type;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.val_token_collection_type DROP CONSTRAINT IF EXISTS pk_val_token_collection_type;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_audit_val_token_collection_type ON jazzhands.val_token_collection_type;
DROP TRIGGER IF EXISTS trig_userlog_val_token_collection_type ON jazzhands.val_token_collection_type;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_token_collection_type');
---- BEGIN audit.val_token_collection_type TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_token_collection_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_token_collection_type');
---- DONE audit.val_token_collection_type TEARDOWN


ALTER TABLE val_token_collection_type RENAME TO val_token_collection_type_v57;
ALTER TABLE audit.val_token_collection_type RENAME TO val_token_collection_type_v57;

CREATE TABLE val_token_collection_type
(
	token_collection_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	max_num_members	integer  NULL,
	max_num_collections	integer  NULL,
	can_have_hierarchy	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_token_collection_type', false);
ALTER TABLE val_token_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;
INSERT INTO val_token_collection_type (
	token_collection_type,
	description,
	max_num_members,		-- new column (max_num_members)
	max_num_collections,		-- new column (max_num_collections)
	can_have_hierarchy,		-- new column (can_have_hierarchy)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	token_collection_type,
	description,
	NULL,		-- new column (max_num_members)
	NULL,		-- new column (max_num_collections)
	'Y'::bpchar,		-- new column (can_have_hierarchy)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_token_collection_type_v57;

INSERT INTO audit.val_token_collection_type (
	token_collection_type,
	description,
	max_num_members,		-- new column (max_num_members)
	max_num_collections,		-- new column (max_num_collections)
	can_have_hierarchy,		-- new column (can_have_hierarchy)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	token_collection_type,
	description,
	NULL,		-- new column (max_num_members)
	NULL,		-- new column (max_num_collections)
	NULL,		-- new column (can_have_hierarchy)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_token_collection_type_v57;

ALTER TABLE val_token_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_token_collection_type ADD CONSTRAINT pk_val_token_collection_type PRIMARY KEY (token_collection_type);

-- Table/Column Comments
COMMENT ON TABLE val_token_collection_type IS 'Assign purposes to arbitrary groupings';
COMMENT ON COLUMN val_token_collection_type.max_num_members IS 'Maximum INTEGER of members in a given collection of this type';
COMMENT ON COLUMN val_token_collection_type.max_num_collections IS 'Maximum INTEGER of collections a given member can be a part of of this type.';
COMMENT ON COLUMN val_token_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_token_collection_type ADD CONSTRAINT check_yes_no_126727163
	CHECK (can_have_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_token_collection_type and token_collection
ALTER TABLE token_collection
	ADD CONSTRAINT fk_tok_col_mem_token_col_type
	FOREIGN KEY (token_collection_type) REFERENCES val_token_collection_type(token_collection_type);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_token_collection_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_token_collection_type');
DROP TABLE IF EXISTS val_token_collection_type_v57;
DROP TABLE IF EXISTS audit.val_token_collection_type_v57;
-- DONE DEALING WITH TABLE val_token_collection_type [4211247]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE physical_port [4203353]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'physical_port', 'physical_port');

-- FOREIGN KEYS FROM
ALTER TABLE physical_connection DROP CONSTRAINT IF EXISTS fk_patch_panel_port2;
ALTER TABLE network_interface DROP CONSTRAINT IF EXISTS fk_network_int_phys_port_devid;
ALTER TABLE layer1_connection DROP CONSTRAINT IF EXISTS fk_layer1_cnct_phys_port1;
ALTER TABLE layer1_connection DROP CONSTRAINT IF EXISTS fk_layer1_cnct_phys_port2;
ALTER TABLE physical_connection DROP CONSTRAINT IF EXISTS fk_patch_panel_port1;
-- Skipping this FK since table been dropped
--ALTER TABLE layer2_encapsulation DROP CONSTRAINT IF EXISTS fk_l2encap_physport_id;


-- FOREIGN KEYS TO
ALTER TABLE jazzhands.physical_port DROP CONSTRAINT IF EXISTS fk_physical_fk_physic_val_port;
ALTER TABLE jazzhands.physical_port DROP CONSTRAINT IF EXISTS fk_phys_port_dev_id;
ALTER TABLE jazzhands.physical_port DROP CONSTRAINT IF EXISTS fk_phys_port_port_medium;
ALTER TABLE jazzhands.physical_port DROP CONSTRAINT IF EXISTS fk_phys_port_ref_vportpurp;
ALTER TABLE jazzhands.physical_port DROP CONSTRAINT IF EXISTS fk_phys_port_val_port_speed;
ALTER TABLE jazzhands.physical_port DROP CONSTRAINT IF EXISTS fk_phys_port_val_protocol;
ALTER TABLE jazzhands.physical_port DROP CONSTRAINT IF EXISTS pk_physical_port;
ALTER TABLE jazzhands.physical_port DROP CONSTRAINT IF EXISTS iak_pport_dvid_pportid;
ALTER TABLE jazzhands.physical_port DROP CONSTRAINT IF EXISTS ak_physical_port_devnamtype;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_physport_porttype";
DROP INDEX IF EXISTS "jazzhands"."idx_physport_device_id";
DROP INDEX IF EXISTS "jazzhands"."xif5physical_port";
DROP INDEX IF EXISTS "jazzhands"."xif6physical_port";
DROP INDEX IF EXISTS "jazzhands"."xif4physical_port";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.physical_port DROP CONSTRAINT IF EXISTS check_yes_no_1847015416;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_physical_port ON jazzhands.physical_port;
DROP TRIGGER IF EXISTS trigger_audit_physical_port ON jazzhands.physical_port;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'physical_port');
---- BEGIN audit.physical_port TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."physical_port_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'physical_port');
---- DONE audit.physical_port TEARDOWN


ALTER TABLE physical_port RENAME TO physical_port_v57;
ALTER TABLE audit.physical_port RENAME TO physical_port_v57;

CREATE TABLE physical_port
(
	physical_port_id	integer NOT NULL,
	device_id	integer NOT NULL,
	port_name	varchar(50) NOT NULL,
	port_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	port_plug_style	varchar(50)  NULL,
	port_medium	varchar(50)  NULL,
	port_protocol	varchar(50)  NULL,
	port_speed	varchar(50)  NULL,
	physical_label	varchar(50)  NULL,
	port_purpose	varchar(50)  NULL,
	logical_port_id	integer  NULL,
	tcp_port	integer  NULL,
	is_hardwired	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'physical_port', false);
ALTER TABLE physical_port
	ALTER physical_port_id
	SET DEFAULT nextval('physical_port_physical_port_id_seq'::regclass);
ALTER TABLE physical_port
	ALTER is_hardwired
	SET DEFAULT 'Y'::bpchar;
INSERT INTO physical_port (
	physical_port_id,
	device_id,
	port_name,
	port_type,
	description,
	port_plug_style,
	port_medium,
	port_protocol,
	port_speed,
	physical_label,
	port_purpose,
	logical_port_id,		-- new column (logical_port_id)
	tcp_port,
	is_hardwired,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	physical_port_id,
	device_id,
	port_name,
	port_type,
	description,
	port_plug_style,
	port_medium,
	port_protocol,
	port_speed,
	physical_label,
	port_purpose,
	NULL,		-- new column (logical_port_id)
	tcp_port,
	is_hardwired,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM physical_port_v57;

INSERT INTO audit.physical_port (
	physical_port_id,
	device_id,
	port_name,
	port_type,
	description,
	port_plug_style,
	port_medium,
	port_protocol,
	port_speed,
	physical_label,
	port_purpose,
	logical_port_id,		-- new column (logical_port_id)
	tcp_port,
	is_hardwired,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	physical_port_id,
	device_id,
	port_name,
	port_type,
	description,
	port_plug_style,
	port_medium,
	port_protocol,
	port_speed,
	physical_label,
	port_purpose,
	NULL,		-- new column (logical_port_id)
	tcp_port,
	is_hardwired,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.physical_port_v57;

ALTER TABLE physical_port
	ALTER physical_port_id
	SET DEFAULT nextval('physical_port_physical_port_id_seq'::regclass);
ALTER TABLE physical_port
	ALTER is_hardwired
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE physical_port ADD CONSTRAINT pk_physical_port PRIMARY KEY (physical_port_id);
ALTER TABLE physical_port ADD CONSTRAINT ak_physical_port_devnamtype UNIQUE (device_id, port_name, port_type);
ALTER TABLE physical_port ADD CONSTRAINT iak_pport_dvid_pportid UNIQUE (physical_port_id, device_id);

-- Table/Column Comments
COMMENT ON TABLE physical_port IS 'Non-power plugs on devices.  Something gets plugged into these.';
COMMENT ON COLUMN physical_port.is_hardwired IS 'Indicates that the port is physically hardwired into the device and can not be removed.';
-- INDEXES
CREATE INDEX xif4physical_port ON physical_port USING btree (port_protocol);
CREATE INDEX xif6physical_port ON physical_port USING btree (port_speed);
CREATE INDEX xif7physical_port ON physical_port USING btree (logical_port_id);
CREATE INDEX xif5physical_port ON physical_port USING btree (port_medium, port_plug_style);
CREATE INDEX idx_physport_device_id ON physical_port USING btree (device_id);
CREATE INDEX idx_physport_porttype ON physical_port USING btree (port_type);

-- CHECK CONSTRAINTS
ALTER TABLE physical_port ADD CONSTRAINT check_yes_no_1847015416
	CHECK (is_hardwired = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK physical_port and physical_connection
ALTER TABLE physical_connection
	ADD CONSTRAINT fk_patch_panel_port2
	FOREIGN KEY (physical_port2_id) REFERENCES physical_port(physical_port_id);
-- consider FK physical_port and network_interface
ALTER TABLE network_interface
	ADD CONSTRAINT fk_network_int_phys_port_devid
	FOREIGN KEY (physical_port_id, device_id) REFERENCES physical_port(physical_port_id, device_id);
-- consider FK physical_port and layer1_connection
ALTER TABLE layer1_connection
	ADD CONSTRAINT fk_layer1_cnct_phys_port1
	FOREIGN KEY (physical_port1_id) REFERENCES physical_port(physical_port_id);
-- consider FK physical_port and physical_connection
ALTER TABLE physical_connection
	ADD CONSTRAINT fk_patch_panel_port1
	FOREIGN KEY (physical_port1_id) REFERENCES physical_port(physical_port_id);
-- consider FK physical_port and layer1_connection
ALTER TABLE layer1_connection
	ADD CONSTRAINT fk_layer1_cnct_phys_port2
	FOREIGN KEY (physical_port2_id) REFERENCES physical_port(physical_port_id);

-- FOREIGN KEYS TO
-- consider FK physical_port and val_port_speed
ALTER TABLE physical_port
	ADD CONSTRAINT fk_phys_port_val_port_speed
	FOREIGN KEY (port_speed) REFERENCES val_port_speed(port_speed);
-- consider FK physical_port and val_port_protocol
ALTER TABLE physical_port
	ADD CONSTRAINT fk_phys_port_val_protocol
	FOREIGN KEY (port_protocol) REFERENCES val_port_protocol(port_protocol);
-- consider FK physical_port and logical_port
-- Skipping this FK since table does not exist yet
--ALTER TABLE physical_port
--	ADD CONSTRAINT fk_physical_port_lgl_port_id
--	FOREIGN KEY (logical_port_id) REFERENCES logical_port(logical_port_id);

-- consider FK physical_port and val_port_type
ALTER TABLE physical_port
	ADD CONSTRAINT fk_physical_fk_physic_val_port
	FOREIGN KEY (port_type) REFERENCES val_port_type(port_type);
-- consider FK physical_port and device
ALTER TABLE physical_port
	ADD CONSTRAINT fk_phys_port_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK physical_port and val_port_medium
ALTER TABLE physical_port
	ADD CONSTRAINT fk_phys_port_port_medium
	FOREIGN KEY (port_medium, port_plug_style) REFERENCES val_port_medium(port_medium, port_plug_style);
-- consider FK physical_port and val_port_purpose
ALTER TABLE physical_port
	ADD CONSTRAINT fk_phys_port_ref_vportpurp
	FOREIGN KEY (port_purpose) REFERENCES val_port_purpose(port_purpose);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'physical_port');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'physical_port');
ALTER SEQUENCE physical_port_physical_port_id_seq
	 OWNED BY physical_port.physical_port_id;
DROP TABLE IF EXISTS physical_port_v57;
DROP TABLE IF EXISTS audit.physical_port_v57;
-- DONE DEALING WITH TABLE physical_port [4210244]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device_layer2_network
CREATE TABLE device_layer2_network
(
	device_id	integer NOT NULL,
	layer2_network_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device_layer2_network', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device_layer2_network ADD CONSTRAINT pk_device_layer2_network PRIMARY KEY (device_id, layer2_network_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_device_l2_net_l2netid ON device_layer2_network USING btree (layer2_network_id);
CREATE INDEX xif_device_l2_net_devid ON device_layer2_network USING btree (device_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK device_layer2_network and device
ALTER TABLE device_layer2_network
	ADD CONSTRAINT fk_device_l2_net_devid
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device_layer2_network and layer2_network
-- Skipping this FK since table does not exist yet
--ALTER TABLE device_layer2_network
--	ADD CONSTRAINT fk_device_l2_net_l2netid
--	FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device_layer2_network');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device_layer2_network');
-- DONE DEALING WITH TABLE device_layer2_network [4209493]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE encapsulation_domain
CREATE TABLE encapsulation_domain
(
	encapsulation_domain	varchar(50) NOT NULL,
	encapsulation_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'encapsulation_domain', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE encapsulation_domain ADD CONSTRAINT pk_encapsulation_domain PRIMARY KEY (encapsulation_domain, encapsulation_type);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_encap_domain_encap_typ ON encapsulation_domain USING btree (encapsulation_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK encapsulation_domain and layer2_network
-- Skipping this FK since table does not exist yet
--ALTER TABLE layer2_network
--	ADD CONSTRAINT fk_l2_net_encap_domain
--	FOREIGN KEY (encapsulation_domain, encapsulation_type) REFERENCES encapsulation_domain(encapsulation_domain, encapsulation_type);

-- consider FK encapsulation_domain and device_encapsulation_domain
-- Skipping this FK since table does not exist yet
--ALTER TABLE device_encapsulation_domain
--	ADD CONSTRAINT fk_dev_encap_domain_enc_domtyp
--	FOREIGN KEY (encapsulation_domain, encapsulation_type) REFERENCES encapsulation_domain(encapsulation_domain, encapsulation_type);


-- FOREIGN KEYS TO
-- consider FK encapsulation_domain and val_encapsulation_type
ALTER TABLE encapsulation_domain
	ADD CONSTRAINT fk_encap_domain_encap_typ
	FOREIGN KEY (encapsulation_type) REFERENCES val_encapsulation_type(encapsulation_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'encapsulation_domain');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'encapsulation_domain');
-- DONE DEALING WITH TABLE encapsulation_domain [4209690]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE network_interface_netblock
CREATE TABLE network_interface_netblock
(
	network_interface_id	integer NOT NULL,
	netblock_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'network_interface_netblock', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE network_interface_netblock ADD CONSTRAINT pk_network_interface_netblock PRIMARY KEY (network_interface_id, netblock_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_netint_nb_nblk_id ON network_interface_netblock USING btree (network_interface_id);
CREATE INDEX xif_netint_nb_netint_id ON network_interface_netblock USING btree (netblock_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK network_interface_netblock and netblock
ALTER TABLE network_interface_netblock
	ADD CONSTRAINT fk_netint_nb_netint_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
-- consider FK network_interface_netblock and network_interface
ALTER TABLE network_interface_netblock
	ADD CONSTRAINT fk_netint_nb_nblk_id
	FOREIGN KEY (network_interface_id) REFERENCES network_interface(network_interface_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'network_interface_netblock');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'network_interface_netblock');
-- DONE DEALING WITH TABLE network_interface_netblock [4209983]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE layer2_connection
CREATE TABLE layer2_connection
(
	layer2_connection_id	integer NOT NULL,
	logical_port1_id	integer  NULL,
	logical_port2_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'layer2_connection', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE layer2_connection ADD CONSTRAINT pk_layer2_connection PRIMARY KEY (layer2_connection_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_l2_conn_l1port ON layer2_connection USING btree (logical_port1_id);
CREATE INDEX xif_l2_conn_l2port ON layer2_connection USING btree (logical_port2_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK layer2_connection and layer2_connection_l2_network
-- Skipping this FK since table does not exist yet
--ALTER TABLE layer2_connection_l2_network
--	ADD CONSTRAINT fk_l2c_l2n_l2connid
--	FOREIGN KEY (layer2_connection_id) REFERENCES layer2_connection(layer2_connection_id);


-- FOREIGN KEYS TO
-- consider FK layer2_connection and logical_port
-- Skipping this FK since table does not exist yet
--ALTER TABLE layer2_connection
--	ADD CONSTRAINT fk_l2_conn_l2port
--	FOREIGN KEY (logical_port2_id) REFERENCES logical_port(logical_port_id);

-- consider FK layer2_connection and logical_port
-- Skipping this FK since table does not exist yet
--ALTER TABLE layer2_connection
--	ADD CONSTRAINT fk_l2_conn_l1port
--	FOREIGN KEY (logical_port1_id) REFERENCES logical_port(logical_port_id);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'layer2_connection');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'layer2_connection');
-- DONE DEALING WITH TABLE layer2_connection [4209808]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE logical_port
CREATE TABLE logical_port
(
	logical_port_id	integer NOT NULL,
	logical_port_name	varchar(50) NOT NULL,
	logical_port_type	varchar(50)  NULL,
	parent_logical_port_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'logical_port', true);
ALTER TABLE logical_port
	ALTER logical_port_id
	SET DEFAULT nextval('logical_port_logical_port_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE logical_port ADD CONSTRAINT pk_logical_port PRIMARY KEY (logical_port_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_logical_port_parnet_id ON logical_port USING btree (parent_logical_port_id);
CREATE INDEX xif_logical_port_lg_port_type ON logical_port USING btree (logical_port_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK logical_port and network_interface
ALTER TABLE network_interface
	ADD CONSTRAINT fk_net_int_lgl_port_id
	FOREIGN KEY (logical_port_id) REFERENCES logical_port(logical_port_id);
-- consider FK logical_port and layer2_connection
ALTER TABLE layer2_connection
	ADD CONSTRAINT fk_l2_conn_l2port
	FOREIGN KEY (logical_port2_id) REFERENCES logical_port(logical_port_id);
-- consider FK logical_port and physical_port
ALTER TABLE physical_port
	ADD CONSTRAINT fk_physical_port_lgl_port_id
	FOREIGN KEY (logical_port_id) REFERENCES logical_port(logical_port_id);
-- consider FK logical_port and layer2_connection
ALTER TABLE layer2_connection
	ADD CONSTRAINT fk_l2_conn_l1port
	FOREIGN KEY (logical_port1_id) REFERENCES logical_port(logical_port_id);

-- FOREIGN KEYS TO
-- consider FK logical_port and val_logical_port_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE logical_port
--	ADD CONSTRAINT fk_logical_port_lg_port_type
--	FOREIGN KEY (logical_port_type) REFERENCES val_logical_port_type(logical_port_type);

-- consider FK logical_port and logical_port
ALTER TABLE logical_port
	ADD CONSTRAINT fk_logical_port_parent_id
	FOREIGN KEY (parent_logical_port_id) REFERENCES logical_port(logical_port_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'logical_port');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'logical_port');
ALTER SEQUENCE logical_port_logical_port_id_seq
	 OWNED BY logical_port.logical_port_id;
-- DONE DEALING WITH TABLE logical_port [4209867]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_contract_type
CREATE TABLE val_contract_type
(
	contract_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_contract_type', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_contract_type ADD CONSTRAINT pk_val_contract_type PRIMARY KEY (contract_type);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_contract_type and contract_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE contract_type
--	ADD CONSTRAINT fk_contract_contract_type
--	FOREIGN KEY (contract_type) REFERENCES val_contract_type(contract_type);


-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_contract_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_contract_type');
-- DONE DEALING WITH TABLE val_contract_type [4210707]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE layer2_network
CREATE TABLE layer2_network
(
	layer2_network_id	integer NOT NULL,
	encapsulation_name	character(32)  NULL,
	encapsulation_domain	varchar(50)  NULL,
	encapsulation_type	varchar(50)  NULL,
	encapsulation_tag	integer  NULL,
	description	varchar(255)  NULL,
	encapsulation_range_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'layer2_network', true);
ALTER TABLE layer2_network
	ALTER layer2_network_id
	SET DEFAULT nextval('layer2_network_layer2_network_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE layer2_network ADD CONSTRAINT ak_l2net_encap_tag UNIQUE (encapsulation_type, encapsulation_domain, encapsulation_tag);
ALTER TABLE layer2_network ADD CONSTRAINT ak_l2_net_l2net_encap_typ UNIQUE (layer2_network_id, encapsulation_type);
ALTER TABLE layer2_network ADD CONSTRAINT ak_l2net_encap_name UNIQUE (encapsulation_domain, encapsulation_type, encapsulation_name);
ALTER TABLE layer2_network ADD CONSTRAINT pk_layer2_network PRIMARY KEY (layer2_network_id);

-- Table/Column Comments
COMMENT ON COLUMN layer2_network.encapsulation_range_id IS 'Administrative information about which range this is a part of';
-- INDEXES
CREATE INDEX xif_l2_net_encap_domain ON layer2_network USING btree (encapsulation_domain, encapsulation_type);
CREATE INDEX xif_l2_net_encap_range_id ON layer2_network USING btree (encapsulation_range_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK layer2_network and layer3_network
-- Skipping this FK since table does not exist yet
--ALTER TABLE layer3_network
--	ADD CONSTRAINT fk_l3net_l2net
--	FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id);

-- consider FK layer2_network and property
ALTER TABLE property
	ADD CONSTRAINT fk_prop_l2netid
	FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id);
-- consider FK layer2_network and layer2_connection_l2_network
-- Skipping this FK since table does not exist yet
--ALTER TABLE layer2_connection_l2_network
--	ADD CONSTRAINT fk_l2c_l2n_l2netid
--	FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id);

-- consider FK layer2_network and layer2_connection_l2_network
-- Skipping this FK since table does not exist yet
--ALTER TABLE layer2_connection_l2_network
--	ADD CONSTRAINT fk_l2cl2n_l2net_id_encap_typ
--	FOREIGN KEY (layer2_network_id, encapsulation_type) REFERENCES layer2_network(layer2_network_id, encapsulation_type);

-- consider FK layer2_network and device_layer2_network
ALTER TABLE device_layer2_network
	ADD CONSTRAINT fk_device_l2_net_l2netid
	FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id);

-- FOREIGN KEYS TO
-- consider FK layer2_network and encapsulation_domain
ALTER TABLE layer2_network
	ADD CONSTRAINT fk_l2_net_encap_domain
	FOREIGN KEY (encapsulation_domain, encapsulation_type) REFERENCES encapsulation_domain(encapsulation_domain, encapsulation_type);
-- consider FK layer2_network and encapsulation_range
-- Skipping this FK since table does not exist yet
--ALTER TABLE layer2_network
--	ADD CONSTRAINT fk_l2_net_encap_range_id
--	FOREIGN KEY (encapsulation_range_id) REFERENCES encapsulation_range(encapsulation_range_id);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'layer2_network');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'layer2_network');
ALTER SEQUENCE layer2_network_layer2_network_id_seq
	 OWNED BY layer2_network.layer2_network_id;
-- DONE DEALING WITH TABLE layer2_network [4209832]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device_type_module_device_type
CREATE TABLE device_type_module_device_type
(
	module_device_type_id	integer NOT NULL,
	device_type_id	integer NOT NULL,
	device_type_module_name	varchar(255) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device_type_module_device_type', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device_type_module_device_type ADD CONSTRAINT pk_device_type_module_device_t PRIMARY KEY (module_device_type_id, device_type_id, device_type_module_name);

-- Table/Column Comments
COMMENT ON TABLE device_type_module_device_type IS 'Used to validate that a given module device_type is allowed to be placed inside a specific module in a chassis_device_type';
COMMENT ON COLUMN device_type_module_device_type.module_device_type_id IS 'Id of a module that is permitted to be placed in this slot';
COMMENT ON COLUMN device_type_module_device_type.device_type_id IS 'Device Type of the Container Device (Chassis)';
COMMENT ON COLUMN device_type_module_device_type.device_type_module_name IS 'Name used to describe the module programatically.';
-- INDEXES
CREATE INDEX xif_dt_mod_dev_type_dtmod ON device_type_module_device_type USING btree (device_type_id, device_type_module_name);
CREATE INDEX xif_dt_mod_dev_type_mod_dtid ON device_type_module_device_type USING btree (module_device_type_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK device_type_module_device_type and chassis_location
ALTER TABLE chassis_location
	ADD CONSTRAINT fk_dtyp_mod_dev_chass_location
	FOREIGN KEY (module_device_type_id, chassis_device_type_id, device_type_module_name) REFERENCES device_type_module_device_type(module_device_type_id, device_type_id, device_type_module_name);

-- FOREIGN KEYS TO
-- consider FK device_type_module_device_type and device_type
ALTER TABLE device_type_module_device_type
	ADD CONSTRAINT fk_dt_mod_dev_type_mod_dtid
	FOREIGN KEY (module_device_type_id) REFERENCES device_type(device_type_id);
-- consider FK device_type_module_device_type and device_type_module
ALTER TABLE device_type_module_device_type
	ADD CONSTRAINT fk_dt_mod_dev_type_dtmod
	FOREIGN KEY (device_type_id, device_type_module_name) REFERENCES device_type_module(device_type_id, device_type_module_name);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device_type_module_device_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device_type_module_device_type');
-- DONE DEALING WITH TABLE device_type_module_device_type [4209596]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device_collection_ssh_key
CREATE TABLE device_collection_ssh_key
(
	ssh_key_id	integer NOT NULL,
	device_collection_id	integer NOT NULL,
	account_collection_id	integer NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device_collection_ssh_key', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device_collection_ssh_key ADD CONSTRAINT pk_device_collection_ssh_key PRIMARY KEY (ssh_key_id, device_collection_id, account_collection_id);

-- Table/Column Comments
COMMENT ON COLUMN device_collection_ssh_key.ssh_key_id IS 'SSH Public Key that gets placed in a user''s authorized keys file';
COMMENT ON COLUMN device_collection_ssh_key.device_collection_id IS 'Device collection that gets this key assigned to users';
COMMENT ON COLUMN device_collection_ssh_key.account_collection_id IS 'Destination account(s) that get the ssh keys';
-- INDEXES
CREATE INDEX xif3device_collection_ssh_key ON device_collection_ssh_key USING btree (account_collection_id);
CREATE INDEX xif2device_collection_ssh_key ON device_collection_ssh_key USING btree (device_collection_id);
CREATE INDEX xif1device_collection_ssh_key ON device_collection_ssh_key USING btree (ssh_key_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK device_collection_ssh_key and ssh_key
ALTER TABLE device_collection_ssh_key
	ADD CONSTRAINT fk_dev_coll_ssh_key_ssh_key
	FOREIGN KEY (ssh_key_id) REFERENCES ssh_key(ssh_key_id);
-- consider FK device_collection_ssh_key and account_collection
ALTER TABLE device_collection_ssh_key
	ADD CONSTRAINT fk_dev_coll_ssh_key_acct_col
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);
-- consider FK device_collection_ssh_key and device_collection
ALTER TABLE device_collection_ssh_key
	ADD CONSTRAINT fk_dev_coll_ssh_key_devcoll
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device_collection_ssh_key');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device_collection_ssh_key');
-- DONE DEALING WITH TABLE device_collection_ssh_key [4209471]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE token_collection_hier
CREATE TABLE token_collection_hier
(
	token_collection_id	integer NOT NULL,
	child_token_collection_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'token_collection_hier', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE token_collection_hier ADD CONSTRAINT pk_token_collection_hier PRIMARY KEY (token_collection_id, child_token_collection_id);

-- Table/Column Comments
COMMENT ON TABLE token_collection_hier IS 'Assign individual tokens to groups.';
-- INDEXES
CREATE INDEX xif_tok_col_hier_ch_tok_colid ON token_collection_hier USING btree (token_collection_id);
CREATE INDEX xif_tok_col_hier_tok_colid ON token_collection_hier USING btree (child_token_collection_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK token_collection_hier and token_collection
ALTER TABLE token_collection_hier
	ADD CONSTRAINT fk_tok_col_hier_tok_colid
	FOREIGN KEY (child_token_collection_id) REFERENCES token_collection(token_collection_id);
-- consider FK token_collection_hier and token_collection
ALTER TABLE token_collection_hier
	ADD CONSTRAINT fk_tok_col_hier_ch_tok_colid
	FOREIGN KEY (token_collection_id) REFERENCES token_collection(token_collection_id);

-- TRIGGERS
-- comes into existance later
-- CREATE CONSTRAINT TRIGGER trigger_token_collection_hier_enforce AFTER INSERT OR UPDATE ON token_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE token_collection_hier_enforce();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'token_collection_hier');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'token_collection_hier');
-- DONE DEALING WITH TABLE token_collection_hier [4210574]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE encapsulation_range
CREATE TABLE encapsulation_range
(
	encapsulation_range_id	integer NOT NULL,
	parent_encapsulation_range_id	integer  NULL,
	site_code	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'encapsulation_range', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE encapsulation_range ADD CONSTRAINT pk_vlan_range PRIMARY KEY (encapsulation_range_id);

-- Table/Column Comments
COMMENT ON TABLE encapsulation_range IS 'Captures how tables are assigned administratively.  This is not use for enforcement but primarily for presentation';
-- INDEXES
CREATE INDEX ixf_encap_range_parentvlan ON encapsulation_range USING btree (parent_encapsulation_range_id);
CREATE INDEX ixf_encap_range_sitecode ON encapsulation_range USING btree (site_code);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK encapsulation_range and layer2_network
ALTER TABLE layer2_network
	ADD CONSTRAINT fk_l2_net_encap_range_id
	FOREIGN KEY (encapsulation_range_id) REFERENCES encapsulation_range(encapsulation_range_id);

-- FOREIGN KEYS TO
-- consider FK encapsulation_range and site
ALTER TABLE encapsulation_range
	ADD CONSTRAINT fk_encap_range_sitecode
	FOREIGN KEY (site_code) REFERENCES site(site_code);
-- consider FK encapsulation_range and encapsulation_range
ALTER TABLE encapsulation_range
	ADD CONSTRAINT fk_encap_range_parent_encap_id
	FOREIGN KEY (parent_encapsulation_range_id) REFERENCES encapsulation_range(encapsulation_range_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'encapsulation_range');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'encapsulation_range');
-- DONE DEALING WITH TABLE encapsulation_range [4209699]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE account_realm_acct_coll_type
CREATE TABLE account_realm_acct_coll_type
(
	account_realm_id	integer NOT NULL,
	account_collection_type	varchar(50) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'account_realm_acct_coll_type', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE account_realm_acct_coll_type ADD CONSTRAINT pk_account_realm_acct_coll_typ PRIMARY KEY (account_realm_id, account_collection_type);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1_acct_realm_acct_coll_typ ON account_realm_acct_coll_type USING btree (account_collection_type);
CREATE INDEX xif2_acct_realm_acct_coll_arid ON account_realm_acct_coll_type USING btree (account_realm_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK account_realm_acct_coll_type and val_account_collection_type
ALTER TABLE account_realm_acct_coll_type
	ADD CONSTRAINT fk_acct_realm_acct_coll_typ
	FOREIGN KEY (account_collection_type) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK account_realm_acct_coll_type and account_realm
ALTER TABLE account_realm_acct_coll_type
	ADD CONSTRAINT fk_acct_realm_acct_coll_arid
	FOREIGN KEY (account_realm_id) REFERENCES account_realm(account_realm_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'account_realm_acct_coll_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'account_realm_acct_coll_type');
-- DONE DEALING WITH TABLE account_realm_acct_coll_type [4209151]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE contract_type
CREATE TABLE contract_type
(
	contract_id	integer NOT NULL,
	contract_type	varchar(50) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'contract_type', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE contract_type ADD CONSTRAINT pk_contract_type PRIMARY KEY (contract_id, contract_type);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_contract_contract_type ON contract_type USING btree (contract_type);
CREATE INDEX xif_contract_contract_id ON contract_type USING btree (contract_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK contract_type and val_contract_type
ALTER TABLE contract_type
	ADD CONSTRAINT fk_contract_contract_type
	FOREIGN KEY (contract_type) REFERENCES val_contract_type(contract_type);
-- consider FK contract_type and contract
-- Skipping this FK since table does not exist yet
--ALTER TABLE contract_type
--	ADD CONSTRAINT fk_contract_contract_id
--	FOREIGN KEY (contract_id) REFERENCES contract(contract_id);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'contract_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'contract_type');
-- DONE DEALING WITH TABLE contract_type [4209360]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE layer3_network
CREATE TABLE layer3_network
(
	layer3_network_id	integer NOT NULL,
	netblock_id	integer  NULL,
	layer2_network_id	integer  NULL,
	default_gateway_netblock_id	integer NOT NULL,
	rendevous_point_netblock_id	integer NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'layer3_network', true);
ALTER TABLE layer3_network
	ALTER layer3_network_id
	SET DEFAULT nextval('layer3_network_layer3_network_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE layer3_network ADD CONSTRAINT pk_layer3_network PRIMARY KEY (layer3_network_id);
ALTER TABLE layer3_network ADD CONSTRAINT ak_layer3_network_netblock_id UNIQUE (netblock_id);

-- Table/Column Comments
COMMENT ON COLUMN layer3_network.rendevous_point_netblock_id IS 'Multicast Rendevous Point Address';
-- INDEXES
CREATE INDEX xif_l3_net_def_gate_nbid ON layer3_network USING btree (default_gateway_netblock_id);
CREATE INDEX xif_l3net_rndv_pt_nblk_id ON layer3_network USING btree (rendevous_point_netblock_id);
CREATE INDEX xif_l3net_l2net ON layer3_network USING btree (layer2_network_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK layer3_network and property
ALTER TABLE property
	ADD CONSTRAINT fk_prop_l3netid
	FOREIGN KEY (layer3_network_id) REFERENCES layer3_network(layer3_network_id);

-- FOREIGN KEYS TO
-- consider FK layer3_network and layer2_network
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_l3net_l2net
	FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id);
-- consider FK layer3_network and netblock
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_l3_net_def_gate_nbid
	FOREIGN KEY (default_gateway_netblock_id) REFERENCES netblock(netblock_id);
-- consider FK layer3_network and netblock
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_layer3_network_netblock_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
-- consider FK layer3_network and netblock
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_l3net_rndv_pt_nblk_id
	FOREIGN KEY (rendevous_point_netblock_id) REFERENCES netblock(netblock_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'layer3_network');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'layer3_network');
ALTER SEQUENCE layer3_network_layer3_network_id_seq
	 OWNED BY layer3_network.layer3_network_id;
-- DONE DEALING WITH TABLE layer3_network [4209851]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_encapsulation_mode
CREATE TABLE val_encapsulation_mode
(
	encapsulation_mode	varchar(50) NOT NULL,
	encapsulation_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_encapsulation_mode', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_encapsulation_mode ADD CONSTRAINT pk_val_encapsulation_mode PRIMARY KEY (encapsulation_mode, encapsulation_type);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_val_encap_mode_type ON val_encapsulation_mode USING btree (encapsulation_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_encapsulation_mode and layer2_connection_l2_network
-- Skipping this FK since table does not exist yet
--ALTER TABLE layer2_connection_l2_network
--	ADD CONSTRAINT fk_l2c_l2n_encap_mode_type
--	FOREIGN KEY (encapsulation_mode, encapsulation_type) REFERENCES val_encapsulation_mode(encapsulation_mode, encapsulation_type);


-- FOREIGN KEYS TO
-- consider FK val_encapsulation_mode and val_encapsulation_type
ALTER TABLE val_encapsulation_mode
	ADD CONSTRAINT fk_val_encap_mode_type
	FOREIGN KEY (encapsulation_type) REFERENCES val_encapsulation_type(encapsulation_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_encapsulation_mode');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_encapsulation_mode');
-- DONE DEALING WITH TABLE val_encapsulation_mode [4210814]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE contract
CREATE TABLE contract
(
	contract_id	integer NOT NULL,
	company_id	integer NOT NULL,
	contract_name	varchar(255) NOT NULL,
	vendor_contract_name	varchar(255)  NULL,
	description	varchar(255)  NULL,
	contract_termination_date	timestamp with time zone  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'contract', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE contract ADD CONSTRAINT pk_contract PRIMARY KEY (contract_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xifcontract_company_id ON contract USING btree (company_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK contract and contract_type
ALTER TABLE contract_type
	ADD CONSTRAINT fk_contract_contract_id
	FOREIGN KEY (contract_id) REFERENCES contract(contract_id);
-- consider FK contract and asset
-- Skipping this FK since table does not exist yet
--ALTER TABLE asset
--	ADD CONSTRAINT fk_asset_contract_id
--	FOREIGN KEY (contract_id) REFERENCES contract(contract_id);


-- FOREIGN KEYS TO
-- consider FK contract and company
ALTER TABLE contract
	ADD CONSTRAINT fk_contract_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'contract');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'contract');
-- DONE DEALING WITH TABLE contract [4209351]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE layer2_connection_l2_network
CREATE TABLE layer2_connection_l2_network
(
	layer2_connection_id	integer NOT NULL,
	layer2_network_id	integer NOT NULL,
	encapsulation_mode	varchar(50)  NULL,
	encapsulation_type	varchar(50)  NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'layer2_connection_l2_network', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE layer2_connection_l2_network ADD CONSTRAINT pk_val_layer2_encapsulation_ty PRIMARY KEY (layer2_connection_id, layer2_network_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_l2c_l2n_l2netid ON layer2_connection_l2_network USING btree (layer2_network_id);
CREATE INDEX xif_l2c_l2n_l2connid ON layer2_connection_l2_network USING btree (layer2_connection_id);
CREATE INDEX xif_l2c_l2n_encap_mode_type ON layer2_connection_l2_network USING btree (encapsulation_mode, encapsulation_type);
CREATE INDEX xif_l2cl2n_l2net_id_encap_typ ON layer2_connection_l2_network USING btree (layer2_network_id, encapsulation_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK layer2_connection_l2_network and layer2_network
ALTER TABLE layer2_connection_l2_network
	ADD CONSTRAINT fk_l2cl2n_l2net_id_encap_typ
	FOREIGN KEY (layer2_network_id, encapsulation_type) REFERENCES layer2_network(layer2_network_id, encapsulation_type);
-- consider FK layer2_connection_l2_network and layer2_connection
ALTER TABLE layer2_connection_l2_network
	ADD CONSTRAINT fk_l2c_l2n_l2connid
	FOREIGN KEY (layer2_connection_id) REFERENCES layer2_connection(layer2_connection_id);
-- consider FK layer2_connection_l2_network and layer2_network
ALTER TABLE layer2_connection_l2_network
	ADD CONSTRAINT fk_l2c_l2n_l2netid
	FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id);
-- consider FK layer2_connection_l2_network and val_encapsulation_mode
ALTER TABLE layer2_connection_l2_network
	ADD CONSTRAINT fk_l2c_l2n_encap_mode_type
	FOREIGN KEY (encapsulation_mode, encapsulation_type) REFERENCES val_encapsulation_mode(encapsulation_mode, encapsulation_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'layer2_connection_l2_network');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'layer2_connection_l2_network');
-- DONE DEALING WITH TABLE layer2_connection_l2_network [4209818]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_logical_port_type
CREATE TABLE val_logical_port_type
(
	logical_port_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_logical_port_type', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_logical_port_type ADD CONSTRAINT pk_val_logical_port_type PRIMARY KEY (logical_port_type);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_logical_port_type and logical_port
ALTER TABLE logical_port
	ADD CONSTRAINT fk_logical_port_lg_port_type
	FOREIGN KEY (logical_port_type) REFERENCES val_logical_port_type(logical_port_type);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_logical_port_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_logical_port_type');
-- DONE DEALING WITH TABLE val_logical_port_type [4210879]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE mlag_peering
CREATE TABLE mlag_peering
(
	mlag_peering_id	integer NOT NULL,
	device1_id	integer  NULL,
	device2_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'mlag_peering', true);
ALTER TABLE mlag_peering
	ALTER mlag_peering_id
	SET DEFAULT nextval('mlag_peering_mlag_peering_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE mlag_peering ADD CONSTRAINT pk_mlag_peering PRIMARY KEY (mlag_peering_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_mlag_peering_devid1 ON mlag_peering USING btree (device1_id);
CREATE INDEX xif_mlag_peering_devid2 ON mlag_peering USING btree (device2_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK mlag_peering and device
ALTER TABLE mlag_peering
	ADD CONSTRAINT fk_mlag_peering_devid2
	FOREIGN KEY (device2_id) REFERENCES device(device_id);
-- consider FK mlag_peering and device
ALTER TABLE mlag_peering
	ADD CONSTRAINT fk_mlag_peering_devid1
	FOREIGN KEY (device1_id) REFERENCES device(device_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'mlag_peering');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'mlag_peering');
ALTER SEQUENCE mlag_peering_mlag_peering_id_seq
	 OWNED BY mlag_peering.mlag_peering_id;
-- DONE DEALING WITH TABLE mlag_peering [4209880]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE asset
CREATE TABLE asset
(
	asset_id	integer NOT NULL,
	description	varchar(255)  NULL,
	serial_number	varchar(255)  NULL,
	part_number	varchar(255)  NULL,
	asset_tag	varchar(255)  NULL,
	ownership_status	varchar(50) NOT NULL,
	lease_expiration_date	timestamp with time zone  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL,
	contract_id	integer  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'asset', true);
ALTER TABLE asset
	ALTER asset_id
	SET DEFAULT nextval('asset_asset_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE asset ADD CONSTRAINT pk_asset PRIMARY KEY (asset_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_asset_contract_id ON asset USING btree (contract_id);
CREATE INDEX xif_asset_ownshp_stat ON asset USING btree (ownership_status);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK asset and device
ALTER TABLE device
	ADD CONSTRAINT fk_device_asset_id
	FOREIGN KEY (asset_id) REFERENCES asset(asset_id);

-- FOREIGN KEYS TO
-- consider FK asset and contract
ALTER TABLE asset
	ADD CONSTRAINT fk_asset_contract_id
	FOREIGN KEY (contract_id) REFERENCES contract(contract_id);
-- consider FK asset and val_ownership_status
ALTER TABLE asset
	ADD CONSTRAINT fk_asset_ownshp_stat
	FOREIGN KEY (ownership_status) REFERENCES val_ownership_status(ownership_status);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'asset');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'asset');
ALTER SEQUENCE asset_asset_id_seq
	 OWNED BY asset.asset_id;
-- DONE DEALING WITH TABLE asset [4209253]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device_encapsulation_domain
CREATE TABLE device_encapsulation_domain
(
	device_id	integer NOT NULL,
	encapsulation_type	varchar(50) NOT NULL,
	encapsulation_domain	varchar(50)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device_encapsulation_domain', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device_encapsulation_domain ADD CONSTRAINT pk_device_encapsulation_domain PRIMARY KEY (device_id, encapsulation_type);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_dev_encap_domain_devid ON device_encapsulation_domain USING btree (device_id);
CREATE INDEX xif_dev_encap_domain_enc_domty ON device_encapsulation_domain USING btree (encapsulation_domain, encapsulation_type);
CREATE INDEX xif_dev_encap_domain_encaptyp ON device_encapsulation_domain USING btree (encapsulation_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK device_encapsulation_domain and encapsulation_domain
ALTER TABLE device_encapsulation_domain
	ADD CONSTRAINT fk_dev_encap_domain_enc_domtyp
	FOREIGN KEY (encapsulation_domain, encapsulation_type) REFERENCES encapsulation_domain(encapsulation_domain, encapsulation_type);
-- consider FK device_encapsulation_domain and device
ALTER TABLE device_encapsulation_domain
	ADD CONSTRAINT fk_dev_encap_domain_devid
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device_encapsulation_domain and val_encapsulation_type
ALTER TABLE device_encapsulation_domain
	ADD CONSTRAINT fk_dev_encap_domain_encaptyp
	FOREIGN KEY (encapsulation_type) REFERENCES val_encapsulation_type(encapsulation_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device_encapsulation_domain');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device_encapsulation_domain');
-- DONE DEALING WITH TABLE device_encapsulation_domain [4209482]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE dns_record [4202843]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_record', 'dns_record');

-- FOREIGN KEYS FROM
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_device_dnsrecord;
ALTER TABLE dns_record_relation DROP CONSTRAINT IF EXISTS fk_dnsrec_ref_dnsrecrltn_rl_id;
ALTER TABLE network_service DROP CONSTRAINT IF EXISTS fk_netsvc_dnsid_id;
ALTER TABLE dns_record_relation DROP CONSTRAINT IF EXISTS fk_dns_rec_ref_dns_rec_rltn;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS fk_dns_record_vdnsclass;
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS fk_dnsid_dnsdom_id;
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS fk_dnsrec_ref_dns_ref_id;
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS fk_dnsid_nblk_id;
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS fk_dnsrec_vdnssrvsrvc;
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS fk_dnsrecord_vdnstype;
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS fk_dnsrecord_dnsrecord;
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS pk_dns_record;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_dnsrec_dnstype";
DROP INDEX IF EXISTS "jazzhands"."ix_dnsid_domid";
DROP INDEX IF EXISTS "jazzhands"."idx_dnsrec_refdnsrec";
DROP INDEX IF EXISTS "jazzhands"."idx_dnsrec_dnssrvservice";
DROP INDEX IF EXISTS "jazzhands"."idx_dnsrec_dnsclass";
DROP INDEX IF EXISTS "jazzhands"."ix_dnsid_netblock_id";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS ckc_should_generate_p_dns_reco;
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS ckc_dns_srv_protocol_dns_reco;
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS ckc_is_enabled_dns_reco;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_update_dns_zone ON jazzhands.dns_record;
DROP TRIGGER IF EXISTS trig_userlog_dns_record ON jazzhands.dns_record;
DROP TRIGGER IF EXISTS trigger_dns_non_a_rec_validation ON jazzhands.dns_record;
DROP TRIGGER IF EXISTS trigger_dns_rec_before ON jazzhands.dns_record;
DROP TRIGGER IF EXISTS trigger_dns_a_rec_validation ON jazzhands.dns_record;
DROP TRIGGER IF EXISTS trigger_audit_dns_record ON jazzhands.dns_record;
DROP TRIGGER IF EXISTS trigger_dns_record_update_nontime ON jazzhands.dns_record;
DROP TRIGGER IF EXISTS trigger_dns_rec_prevent_dups ON jazzhands.dns_record;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'dns_record');
---- BEGIN audit.dns_record TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."dns_record_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'dns_record');
---- DONE audit.dns_record TEARDOWN


ALTER TABLE dns_record RENAME TO dns_record_v57;
ALTER TABLE audit.dns_record RENAME TO dns_record_v57;

CREATE TABLE dns_record
(
	dns_record_id	integer NOT NULL,
	dns_name	varchar(255)  NULL,
	dns_domain_id	integer NOT NULL,
	dns_ttl	integer  NULL,
	dns_class	varchar(50) NOT NULL,
	dns_type	varchar(50) NOT NULL,
	dns_value	varchar(512)  NULL,
	dns_priority	integer  NULL,
	dns_srv_service	varchar(50)  NULL,
	dns_srv_protocol	varchar(4)  NULL,
	dns_srv_weight	integer  NULL,
	dns_srv_port	integer  NULL,
	netblock_id	integer  NULL,
	reference_dns_record_id	integer  NULL,
	dns_value_record_id	integer  NULL,
	should_generate_ptr	character(1) NOT NULL,
	is_enabled	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'dns_record', false);
ALTER TABLE dns_record
	ALTER dns_record_id
	SET DEFAULT nextval('dns_record_dns_record_id_seq'::regclass);
ALTER TABLE dns_record
	ALTER dns_class
	SET DEFAULT 'IN'::character varying;
ALTER TABLE dns_record
	ALTER should_generate_ptr
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE dns_record
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;
INSERT INTO dns_record (
	dns_record_id,
	dns_name,
	dns_domain_id,
	dns_ttl,
	dns_class,
	dns_type,
	dns_value,
	dns_priority,
	dns_srv_service,
	dns_srv_protocol,
	dns_srv_weight,
	dns_srv_port,
	netblock_id,
	reference_dns_record_id,
	dns_value_record_id,
	should_generate_ptr,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	dns_record_id,
	dns_name,
	dns_domain_id,
	dns_ttl,
	dns_class,
	dns_type,
	dns_value,
	dns_priority,
	dns_srv_service,
	dns_srv_protocol,
	dns_srv_weight,
	dns_srv_port,
	netblock_id,
	reference_dns_record_id,
	dns_value_record_id,
	should_generate_ptr,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM dns_record_v57;

INSERT INTO audit.dns_record (
	dns_record_id,
	dns_name,
	dns_domain_id,
	dns_ttl,
	dns_class,
	dns_type,
	dns_value,
	dns_priority,
	dns_srv_service,
	dns_srv_protocol,
	dns_srv_weight,
	dns_srv_port,
	netblock_id,
	reference_dns_record_id,
	dns_value_record_id,
	should_generate_ptr,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	dns_record_id,
	dns_name,
	dns_domain_id,
	dns_ttl,
	dns_class,
	dns_type,
	dns_value,
	dns_priority,
	dns_srv_service,
	dns_srv_protocol,
	dns_srv_weight,
	dns_srv_port,
	netblock_id,
	reference_dns_record_id,
	dns_value_record_id,
	should_generate_ptr,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.dns_record_v57;

ALTER TABLE dns_record
	ALTER dns_record_id
	SET DEFAULT nextval('dns_record_dns_record_id_seq'::regclass);
ALTER TABLE dns_record
	ALTER dns_class
	SET DEFAULT 'IN'::character varying;
ALTER TABLE dns_record
	ALTER should_generate_ptr
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE dns_record
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE dns_record ADD CONSTRAINT pk_dns_record PRIMARY KEY (dns_record_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX idx_dnsrec_dnssrvservice ON dns_record USING btree (dns_srv_service);
CREATE INDEX idx_dnsrec_dnsclass ON dns_record USING btree (dns_class);
CREATE INDEX ix_dnsid_domid ON dns_record USING btree (dns_domain_id);
CREATE INDEX idx_dnsrec_refdnsrec ON dns_record USING btree (reference_dns_record_id);
CREATE INDEX idx_dnsrec_dnstype ON dns_record USING btree (dns_type);
CREATE INDEX ix_dnsid_netblock_id ON dns_record USING btree (netblock_id);

-- CHECK CONSTRAINTS
ALTER TABLE dns_record ADD CONSTRAINT ckc_is_enabled_dns_reco
	CHECK ((is_enabled = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_enabled)::text = upper((is_enabled)::text)));
ALTER TABLE dns_record ADD CONSTRAINT ckc_should_generate_p_dns_reco
	CHECK ((should_generate_ptr = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((should_generate_ptr)::text = upper((should_generate_ptr)::text)));
ALTER TABLE dns_record ADD CONSTRAINT ckc_dns_srv_protocol_dns_reco
	CHECK ((dns_srv_protocol IS NULL) OR (((dns_srv_protocol)::text = ANY ((ARRAY['tcp'::character varying, 'udp'::character varying])::text[])) AND ((dns_srv_protocol)::text = lower((dns_srv_protocol)::text))));

-- FOREIGN KEYS FROM
-- consider FK dns_record and network_service
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_dnsid_id
	FOREIGN KEY (dns_record_id) REFERENCES dns_record(dns_record_id);
-- consider FK dns_record and dns_record_relation
ALTER TABLE dns_record_relation
	ADD CONSTRAINT fk_dns_rec_ref_dns_rec_rltn
	FOREIGN KEY (dns_record_id) REFERENCES dns_record(dns_record_id);
-- consider FK dns_record and dns_record_relation
ALTER TABLE dns_record_relation
	ADD CONSTRAINT fk_dnsrec_ref_dnsrecrltn_rl_id
	FOREIGN KEY (related_dns_record_id) REFERENCES dns_record(dns_record_id);
-- consider FK dns_record and device
ALTER TABLE device
	ADD CONSTRAINT fk_device_dnsrecord
	FOREIGN KEY (identifying_dns_record_id) REFERENCES dns_record(dns_record_id);

-- FOREIGN KEYS TO
-- consider FK dns_record and netblock
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsid_nblk_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
-- consider FK dns_record and dns_record
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsrec_ref_dns_ref_id
	FOREIGN KEY (dns_value_record_id) REFERENCES dns_record(dns_record_id);
-- consider FK dns_record and val_dns_class
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dns_record_vdnsclass
	FOREIGN KEY (dns_class) REFERENCES val_dns_class(dns_class);
-- consider FK dns_record and dns_domain
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsid_dnsdom_id
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);
-- consider FK dns_record and dns_record
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsrecord_dnsrecord
	FOREIGN KEY (reference_dns_record_id) REFERENCES dns_record(dns_record_id);
-- consider FK dns_record and val_dns_type
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsrecord_vdnstype
	FOREIGN KEY (dns_type) REFERENCES val_dns_type(dns_type);
-- consider FK dns_record and val_dns_srv_service
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsrec_vdnssrvsrvc
	FOREIGN KEY (dns_srv_service) REFERENCES val_dns_srv_service(dns_srv_service);

-- TRIGGERS
CREATE TRIGGER trigger_dns_non_a_rec_validation BEFORE INSERT OR UPDATE ON dns_record FOR EACH ROW EXECUTE PROCEDURE dns_non_a_rec_validation();

-- XXX - may need to include trigger function
CREATE TRIGGER trigger_dns_record_update_nontime AFTER INSERT OR DELETE OR UPDATE ON dns_record FOR EACH ROW EXECUTE PROCEDURE dns_record_update_nontime();

-- XXX - may need to include trigger function
CREATE TRIGGER trigger_dns_a_rec_validation BEFORE INSERT OR UPDATE ON dns_record FOR EACH ROW EXECUTE PROCEDURE dns_a_rec_validation();

-- XXX - may need to include trigger function
CREATE TRIGGER trigger_dns_rec_prevent_dups BEFORE INSERT OR UPDATE ON dns_record FOR EACH ROW EXECUTE PROCEDURE dns_rec_prevent_dups();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'dns_record');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'dns_record');
ALTER SEQUENCE dns_record_dns_record_id_seq
	 OWNED BY dns_record.dns_record_id;
DROP TABLE IF EXISTS dns_record_v57;
DROP TABLE IF EXISTS audit.dns_record_v57;
-- DONE DEALING WITH TABLE dns_record [4209661]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_property [4208753]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_property', 'v_property');
CREATE VIEW v_property AS
 SELECT property.property_id,
    property.account_collection_id,
    property.account_id,
    property.account_realm_id,
    property.company_id,
    property.device_collection_id,
    property.dns_domain_id,
    property.netblock_collection_id,
    property.layer2_network_id,
    property.layer3_network_id,
    property.operating_system_id,
    property.person_id,
    property.service_env_collection_id,
    property.site_code,
    property.property_name,
    property.property_type,
    property.property_value,
    property.property_value_timestamp,
    property.property_value_company_id,
    property.property_value_account_coll_id,
    property.property_value_dns_domain_id,
    property.property_value_nblk_coll_id,
    property.property_value_password_type,
    property.property_value_person_id,
    property.property_value_sw_package_id,
    property.property_value_token_col_id,
    property.property_rank,
    property.start_date,
    property.finish_date,
    property.is_enabled,
    property.data_ins_user,
    property.data_ins_date,
    property.data_upd_user,
    property.data_upd_date
   FROM property
  WHERE property.is_enabled = 'Y'::bpchar AND (property.start_date IS NULL AND property.finish_date IS NULL OR property.start_date IS NULL AND now() <= property.finish_date OR property.start_date <= now() AND property.finish_date IS NULL OR property.start_date <= now() AND now() <= property.finish_date);

delete from __recreate where type = 'view' and object = 'v_property';
-- DONE DEALING WITH TABLE v_property [4216030]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH proc person_manip.get_unix_uid -> get_unix_uid 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('person_manip', 'get_unix_uid', 'get_unix_uid');

-- DROP OLD FUNCTION
-- consider old oid 4208882
DROP FUNCTION IF EXISTS person_manip.get_unix_uid(account_type character varying);
-- consider old oid 4208883
DROP FUNCTION IF EXISTS person_manip.get_unix_uid(person_id integer, account_type integer);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 4208882
DROP FUNCTION IF EXISTS person_manip.get_unix_uid(account_type character varying);
-- consider old oid 4208883
DROP FUNCTION IF EXISTS person_manip.get_unix_uid(person_id integer, account_type integer);
-- consider NEW oid 4216159
CREATE OR REPLACE FUNCTION person_manip.get_unix_uid(account_type character varying)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE new_id INTEGER;
BEGIN
        IF account_type = 'people' OR account_type = 'person' THEN
                SELECT
                        coalesce(max(unix_uid),9999)  INTO new_id
                FROM
                        account_unix_info aui
                JOIN
                        account a
                USING
                        (account_id)
                JOIN
                        person p
                USING
                        (person_id)
                WHERE
                        p.person_id != 0;
		new_id = new_id + 1;
        ELSE
                SELECT
                        coalesce(min(unix_uid),10000)  INTO new_id
                FROM
                        account_unix_info aui
                JOIN
                        account a
                USING
                        (account_id)
                JOIN
                        person p
                USING
                        (person_id)
                WHERE
                        p.person_id = 0 AND unix_uid >6000;
		new_id = new_id - 1;
        END IF;
        RETURN new_id;
END;
$function$
;
-- consider NEW oid 4216160
CREATE OR REPLACE FUNCTION person_manip.get_unix_uid(person_id integer, account_type integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	gettype	CHARACTER VARYING;
BEGIN
	IF person_id = 0 OR account.account_type != 'pseduouser' THEN
		gettype := 'people';
	ELSE
		gettype := 'not-people';
	END IF;
	return person_manip.get_unix_uid(gettype);
END;
$function$
;

-- DONE WITH proc person_manip.get_unix_uid -> get_unix_uid 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc netblock_utils.find_best_parent_id -> find_best_parent_id 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_best_parent_id', 'find_best_parent_id');

-- DROP OLD FUNCTION
-- consider old oid 4208915
DROP FUNCTION IF EXISTS netblock_utils.find_best_parent_id(in_netblock_id integer);
-- consider old oid 4208914
DROP FUNCTION IF EXISTS netblock_utils.find_best_parent_id(in_ipaddress inet, in_netmask_bits integer, in_netblock_type character varying, in_ip_universe_id integer, in_is_single_address character, in_netblock_id integer);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 4208915
DROP FUNCTION IF EXISTS netblock_utils.find_best_parent_id(in_netblock_id integer);
-- consider old oid 4208914
DROP FUNCTION IF EXISTS netblock_utils.find_best_parent_id(in_ipaddress inet, in_netmask_bits integer, in_netblock_type character varying, in_ip_universe_id integer, in_is_single_address character, in_netblock_id integer);
-- consider NEW oid 4216192
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
-- consider NEW oid 4216191
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
		    from netblock
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
		RAISE NOTICE 'oh, yeah...';
		select  Netblock_Id
		  into	par_nbid
		  from  ( select Netblock_Id, Ip_Address, Netmask_Bits
			    from netblock
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
					select parent_netblock_id from netblock 
						where is_single_address = 'N'
						and parent_netblock_id is not null
				)
			order by masklen(ip_address) desc
		) subq LIMIT 1;

		IF can_fix_can_subnet AND par_nbd IS NOT NULL THEN
			UPDATE netblock SET can_subnet = 'N' where netblock_id = par_nbid;
		END IF;
	END IF;


	return par_nbid;
END;
$function$
;

-- DONE WITH proc netblock_utils.find_best_parent_id -> find_best_parent_id 
--------------------------------------------------------------------

DROP FUNCTION IF EXISTS aaa_device_location_migration_1 (  );
DROP FUNCTION IF EXISTS aaa_device_location_migration_2 (  );
-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_non_a_rec_validation');
CREATE OR REPLACE FUNCTION jazzhands.dns_non_a_rec_validation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_ip		netblock.ip_address%type;
BEGIN
	IF NEW.dns_type NOT in ('A', 'AAAA', 'REVERSE_ZONE_BLOCK_PTR') AND NEW.dns_value IS NULL THEN
		RAISE EXCEPTION 'Attempt to set % record without a value',
			NEW.dns_type
			USING ERRCODE = 'not_null_violation';
	END IF;

	RETURN NEW;
END;
$function$
;

DROP FUNCTION IF EXISTS dns_rec_before (  );
-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_record_update_nontime');
CREATE OR REPLACE FUNCTION jazzhands.dns_record_update_nontime()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_dnsdomainid	DNS_DOMAIN.DNS_DOMAIN_ID%type;
	_ipaddr			NETBLOCK.IP_ADDRESS%type;
	_mkold			boolean;
	_mknew			boolean;
	_mkdom			boolean;
	_mkip			boolean;
BEGIN
	_mkold = false;
	_mkold = false;
	_mknew = true;

	IF TG_OP = 'DELETE' THEN
		_mknew := false;
		_mkold := true;
		_mkdom := true;
		if  OLD.netblock_id is not null  THEN
			_mkip := true;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		_mkold := false;
		_mkdom := true;
		if  NEW.netblock_id is not null  THEN
			_mkip := true;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF OLD.DNS_DOMAIN_ID != NEW.DNS_DOMAIN_ID THEN
			_mkold := true;
			_mkip := true;
		END IF;
		_mkdom := true;

		IF (OLD.DNS_NAME is NULL and NEW.DNS_NAME is not NULL )
				OR (OLD.DNS_NAME IS NOT NULL and NEW.DNS_NAME is NULL)
				OR (OLD.DNS_NAME IS NOT NULL and NEW.DNS_NAME IS NOT NULL
					AND OLD.DNS_NAME != NEW.DNS_NAME) THEN
			_mknew := true;
			IF NEW.DNS_TYPE = 'A' OR NEW.DNS_TYPE = 'AAAA' THEN
				IF NEW.SHOULD_GENERATE_PTR = 'Y' THEN
					_mkip := true;
				END IF;
			END IF;
		END IF;

		IF OLD.SHOULD_GENERATE_PTR != NEW.SHOULD_GENERATE_PTR THEN
			_mkold := true;
			_mkip := true;
		END IF;

		IF (OLD.NETBLOCK_ID is NULL and NEW.NETBLOCK_ID is not NULL )
				OR (OLD.NETBLOCK_ID IS NOT NULL and NEW.NETBLOCK_ID is NULL)
				OR (OLD.NETBLOCK_ID IS NOT NULL and NEW.NETBLOCK_ID IS NOT NULL
					AND OLD.NETBLOCK_ID != NEW.NETBLOCK_ID) THEN
			_mkold := true;
			_mknew := true;
			_mkip := true;
		END IF;
	END IF;
				
	if _mkold THEN
		IF _mkdom THEN
			_dnsdomainid := OLD.dns_domain_id;
		ELSE
			_dnsdomainid := NULL;
		END IF;
		if _mkip and OLD.netblock_id is not NULL THEN
			SELECT	ip_address 
			  INTO	_ipaddr 
			  FROM	netblock 
			 WHERE	netblock_id  = OLD.netblock_id;
		ELSE
			_ipaddr := NULL;
		END IF;
		insert into DNS_CHANGE_RECORD
			(dns_domain_id, ip_address) VALUES (_dnsdomainid, _ipaddr);
	END IF;
	if _mknew THEN
		if _mkdom THEN
			_dnsdomainid := NEW.dns_domain_id;
		ELSE
			_dnsdomainid := NULL;
		END IF;
		if _mkip and NEW.netblock_id is not NULL THEN
			SELECT	ip_address 
			  INTO	_ipaddr 
			  FROM	netblock 
			 WHERE	netblock_id  = NEW.netblock_id;
		ELSE
			_ipaddr := NULL;
		END IF;
		insert into DNS_CHANGE_RECORD
			(dns_domain_id, ip_address) VALUES (_dnsdomainid, _ipaddr);
	END IF;
	IF TG_OP = 'DELETE' THEN
		return OLD;
	END IF;
	return NEW;
END;
$function$
;

DROP FUNCTION IF EXISTS perform_audit_device_coll_account_coll (  );
DROP FUNCTION IF EXISTS perform_audit_encapsulation (  );
DROP FUNCTION IF EXISTS perform_audit_encapsulation_netblock (  );
DROP FUNCTION IF EXISTS perform_audit_layer2_encapsulation (  );
DROP FUNCTION IF EXISTS perform_audit_secondary_netblock (  );
DROP FUNCTION IF EXISTS perform_audit_val_layer2_encapsulation_type (  );
DROP FUNCTION IF EXISTS perform_audit_vlan_range (  );
DROP FUNCTION IF EXISTS update_dns_zone (  );

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_property');
CREATE OR REPLACE FUNCTION jazzhands.validate_property()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally			integer;
	v_prop			VAL_Property%ROWTYPE;
	v_proptype		VAL_Property_Type%ROWTYPE;
	v_account_collection	account_collection%ROWTYPE;
	v_netblock_collection	netblock_collection%ROWTYPE;
	v_num			integer;
	v_listvalue		Property.Property_Value%TYPE;
BEGIN

	-- Pull in the data from the property and property_type so we can
	-- figure out what is and is not valid

	BEGIN
		SELECT * INTO STRICT v_prop FROM VAL_Property WHERE
			Property_Name = NEW.Property_Name AND
			Property_Type = NEW.Property_Type;

		SELECT * INTO STRICT v_proptype FROM VAL_Property_Type WHERE
			Property_Type = NEW.Property_Type;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			RAISE EXCEPTION 
				'Property name or type does not exist'
				USING ERRCODE = 'foreign_key_violation';
			RETURN NULL;
	END;

	-- Check to see if the property itself is multivalue.  That is, if only
	-- one value can be set for this property for a specific property LHS

	IF (v_prop.is_multivalue = 'N') THEN
		PERFORM 1 FROM Property WHERE
			Property_Id != NEW.Property_Id AND
			Property_Name = NEW.Property_Name AND
			Property_Type = NEW.Property_Type AND
			((Company_Id IS NULL AND NEW.Company_Id IS NULL) OR
				(Company_Id = NEW.Company_Id)) AND
			((Device_Collection_Id IS NULL AND NEW.Device_Collection_Id IS NULL) OR
				(Device_Collection_Id = NEW.Device_Collection_Id)) AND
			((DNS_Domain_Id IS NULL AND NEW.DNS_Domain_Id IS NULL) OR
				(DNS_Domain_Id = NEW.DNS_Domain_Id)) AND
			((Operating_System_Id IS NULL AND NEW.Operating_System_Id IS NULL) OR
				(Operating_System_Id = NEW.Operating_System_Id)) AND
			((service_env_collection_id IS NULL AND NEW.service_env_collection_id IS NULL) OR
				(service_env_collection_id = NEW.service_env_collection_id)) AND
			((Site_Code IS NULL AND NEW.Site_Code IS NULL) OR
				(Site_Code = NEW.Site_Code)) AND
			((Account_Id IS NULL AND NEW.Account_Id IS NULL) OR
				(Account_Id = NEW.Account_Id)) AND
			((Account_Realm_Id IS NULL AND NEW.Account_Realm_Id IS NULL) OR
				(Account_Realm_Id = NEW.Account_Realm_Id)) AND
			((account_collection_Id IS NULL AND NEW.account_collection_Id IS NULL) OR
				(account_collection_Id = NEW.account_collection_Id)) AND
			((netblock_collection_Id IS NULL AND NEW.netblock_collection_Id IS NULL) OR
				(netblock_collection_Id = NEW.netblock_collection_Id)) AND
			((layer2_network_id IS NULL AND NEW.layer2_network_id IS NULL) OR
				(layer2_network_id = NEW.layer2_network_id)) AND
			((layer3_network_id IS NULL AND NEW.layer3_network_id IS NULL) OR
				(layer3_network_id = NEW.layer3_network_id)) AND
			((person_id IS NULL AND NEW.Person_id IS NULL) OR
				(Person_Id = NEW.person_id))
			;
			
		IF FOUND THEN
			RAISE EXCEPTION 
				'Property of type % already exists for given LHS and property is not multivalue',
				NEW.Property_Type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;
	END IF;

	-- Check to see if the property type is multivalue.  That is, if only
	-- one property and value can be set for any properties with this type
	-- for a specific property LHS

	IF (v_proptype.is_multivalue = 'N') THEN
		PERFORM 1 FROM Property WHERE
			Property_Id != NEW.Property_Id AND
			Property_Type = NEW.Property_Type AND
			((Company_Id IS NULL AND NEW.Company_Id IS NULL) OR
				(Company_Id = NEW.Company_Id)) AND
			((Device_Collection_Id IS NULL AND NEW.Device_Collection_Id IS NULL) OR
				(Device_Collection_Id = NEW.Device_Collection_Id)) AND
			((DNS_Domain_Id IS NULL AND NEW.DNS_Domain_Id IS NULL) OR
				(DNS_Domain_Id = NEW.DNS_Domain_Id)) AND
			((Operating_System_Id IS NULL AND NEW.Operating_System_Id IS NULL) OR
				(Operating_System_Id = NEW.Operating_System_Id)) AND
			((service_env_collection_id IS NULL AND NEW.service_env_collection_id IS NULL) OR
				(service_env_collection_id = NEW.service_env_collection_id)) AND
			((Site_Code IS NULL AND NEW.Site_Code IS NULL) OR
				(Site_Code = NEW.Site_Code)) AND
			((Person_id IS NULL AND NEW.Person_id IS NULL) OR
				(Person_Id = NEW.Person_Id)) AND
			((Account_Id IS NULL AND NEW.Account_Id IS NULL) OR
				(Account_Id = NEW.Account_Id)) AND
			((Account_Id IS NULL AND NEW.Account_Id IS NULL) OR
				(Account_Id = NEW.Account_Id)) AND
			((Account_Realm_id IS NULL AND NEW.Account_Realm_id IS NULL) OR
				(Account_Realm_id = NEW.Account_Realm_id)) AND
			((account_collection_Id IS NULL AND NEW.account_collection_Id IS NULL) OR
				(account_collection_Id = NEW.account_collection_Id)) AND
			((layer2_network_id IS NULL AND NEW.layer2_network_id IS NULL) OR
				(layer2_network_id = NEW.layer2_network_id)) AND
			((layer3_network_id IS NULL AND NEW.layer3_network_id IS NULL) OR
				(layer3_network_id = NEW.layer3_network_id)) AND
			((netblock_collection_Id IS NULL AND NEW.netblock_collection_Id IS NULL) OR
				(netblock_collection_Id = NEW.netblock_collection_Id));

		IF FOUND THEN
			RAISE EXCEPTION 
				'Property % of type % already exists for given LHS and property type is not multivalue',
				NEW.Property_Name, NEW.Property_Type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;
	END IF;

	-- now validate the property_value columns.
	tally := 0;

	--
	-- first determine if the property_value is set properly.
	--

	-- iterate over each of fk PROPERTY_VALUE columns and if a valid
	-- value is set, increment tally, otherwise raise an exception.
	IF NEW.Property_Value_Company_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'company_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Company_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Password_Type IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'password_type' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Password_Type' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Token_Col_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'token_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Token_Collection_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_SW_Package_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'sw_package_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be SW_Package_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Account_Coll_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'account_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be account_collection_id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_nblk_Coll_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'netblock_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be nblk_collection_id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Timestamp IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'timestamp' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Timestamp' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_DNS_Domain_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'dns_domain_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be DNS_Domain_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Person_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'Person_Id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Person_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	-- at this point, tally will be set to 1 if one of the other property
	-- values is set to something valid.  Now, check the various options for
	-- PROPERTY_VALUE itself.  If a new type is added to the val table, this
	-- trigger needs to be updated or it will be considered invalid.  If a
	-- new PROPERTY_VALUE_* column is added, then it will pass through without
	-- trigger modification.  This should be considered bad.

	IF NEW.Property_Value IS NOT NULL THEN
		tally := tally + 1;
		IF v_prop.Property_Data_Type = 'boolean' THEN
			IF NEW.Property_Value != 'Y' AND NEW.Property_Value != 'N' THEN
				RAISE 'Boolean Property_Value must be Y or N' USING
					ERRCODE = 'invalid_parameter_value';
			END IF;
		ELSIF v_prop.Property_Data_Type = 'number' THEN
			BEGIN
				v_num := to_number(NEW.property_value, '9');
			EXCEPTION
				WHEN OTHERS THEN
					RAISE 'Property_Value must be numeric' USING
						ERRCODE = 'invalid_parameter_value';
			END;
		ELSIF v_prop.Property_Data_Type = 'list' THEN
			BEGIN
				SELECT Valid_Property_Value INTO STRICT v_listvalue FROM 
					VAL_Property_Value WHERE
						Property_Name = NEW.Property_Name AND
						Property_Type = NEW.Property_Type AND
						Valid_Property_Value = NEW.Property_Value;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					RAISE 'Property_Value must be a valid value' USING
						ERRCODE = 'invalid_parameter_value';
			END;
		ELSIF v_prop.Property_Data_Type != 'string' THEN
			RAISE 'Property_Data_Type is not a known type' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_prop.Property_Data_Type != 'none' AND tally = 0 THEN
		RAISE 'One of the PROPERTY_VALUE fields must be set.' USING
			ERRCODE = 'invalid_parameter_value';
	END IF;

	IF tally > 1 THEN
		RAISE 'Only one of the PROPERTY_VALUE fields may be set.' USING
			ERRCODE = 'invalid_parameter_value';
	END IF;

	-- If the RHS contains a account_collection_ID, check to see if it must be a
	-- specific type (e.g. per-user), and verify that if so
	IF NEW.Property_Value_Account_Coll_Id IS NOT NULL THEN
		IF v_prop.prop_val_acct_coll_type_rstrct IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_account_collection 
					FROM account_collection WHERE
					account_collection_Id = NEW.Property_Value_Account_Coll_Id;
				IF v_account_collection.account_collection_Type != v_prop.prop_val_acct_coll_type_rstrct
				THEN
					RAISE 'Property_Value_Account_Coll_Id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the RHS contains a netblock_collection_ID, check to see if it must be a
	-- specific type and verify that if so
	IF NEW.Property_Value_nblk_Coll_Id IS NOT NULL THEN
		IF v_prop.prop_val_acct_coll_type_rstrct IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_netblock_collection 
					FROM netblock_collection WHERE
					netblock_collection_Id = NEW.Property_Value_nblk_Coll_Id;
				IF v_netblock_collection.netblock_collection_Type != v_prop.prop_val_acct_coll_type_rstrct
				THEN
					RAISE 'Property_Value_nblk_Coll_Id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- At this point, the RHS has been checked, so now we verify data
	-- set on the LHS

	-- There needs to be a stanza here for every "lhs".  If a new column is
	-- added to the property table, a new stanza needs to be added here,
	-- otherwise it will not be validated.  This should be considered bad.

	IF v_prop.Permit_Company_Id = 'REQUIRED' THEN
			IF NEW.Company_Id IS NULL THEN
				RAISE 'Company_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Company_Id = 'PROHIBITED' THEN
			IF NEW.Company_Id IS NOT NULL THEN
				RAISE 'Company_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Device_Collection_Id = 'REQUIRED' THEN
			IF NEW.Device_Collection_Id IS NULL THEN
				RAISE 'Device_Collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;

	ELSIF v_prop.Permit_Device_Collection_Id = 'PROHIBITED' THEN
			IF NEW.Device_Collection_Id IS NOT NULL THEN
				RAISE 'Device_Collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_DNS_Domain_Id = 'REQUIRED' THEN
			IF NEW.DNS_Domain_Id IS NULL THEN
				RAISE 'DNS_Domain_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_DNS_Domain_Id = 'PROHIBITED' THEN
			IF NEW.DNS_Domain_Id IS NOT NULL THEN
				RAISE 'DNS_Domain_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_service_env_collection = 'REQUIRED' THEN
			IF NEW.service_env_collection_id IS NULL THEN
				RAISE 'service_env_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_service_env_collection = 'PROHIBITED' THEN
			IF NEW.service_env_collection_id IS NOT NULL THEN
				RAISE 'service_environment is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Operating_System_Id = 'REQUIRED' THEN
			IF NEW.Operating_System_Id IS NULL THEN
				RAISE 'Operating_System_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Operating_System_Id = 'PROHIBITED' THEN
			IF NEW.Operating_System_Id IS NOT NULL THEN
				RAISE 'Operating_System_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Site_Code = 'REQUIRED' THEN
			IF NEW.Site_Code IS NULL THEN
				RAISE 'Site_Code is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Site_Code = 'PROHIBITED' THEN
			IF NEW.Site_Code IS NOT NULL THEN
				RAISE 'Site_Code is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Account_Id = 'REQUIRED' THEN
			IF NEW.Account_Id IS NULL THEN
				RAISE 'Account_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Account_Id = 'PROHIBITED' THEN
			IF NEW.Account_Id IS NOT NULL THEN
				RAISE 'Account_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Account_Realm_Id = 'REQUIRED' THEN
			IF NEW.Account_Realm_Id IS NULL THEN
				RAISE 'Account_Realm_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Account_Realm_Id = 'PROHIBITED' THEN
			IF NEW.Account_Realm_Id IS NOT NULL THEN
				RAISE 'Account_Realm_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_account_collection_Id = 'REQUIRED' THEN
			IF NEW.account_collection_Id IS NULL THEN
				RAISE 'account_collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_account_collection_Id = 'PROHIBITED' THEN
			IF NEW.account_collection_Id IS NOT NULL THEN
				RAISE 'account_collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_layer2_network_id = 'REQUIRED' THEN
			IF NEW.layer2_network_id IS NULL THEN
				RAISE 'layer2_network_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_layer2_network_id = 'PROHIBITED' THEN
			IF NEW.layer2_network_id IS NOT NULL THEN
				RAISE 'layer2_network_id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_layer3_network_id = 'REQUIRED' THEN
			IF NEW.layer3_network_id IS NULL THEN
				RAISE 'layer3_network_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_layer3_network_id = 'PROHIBITED' THEN
			IF NEW.layer3_network_id IS NOT NULL THEN
				RAISE 'layer3_network_id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_netblock_collection_Id = 'REQUIRED' THEN
			IF NEW.netblock_collection_Id IS NULL THEN
				RAISE 'netblock_collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_netblock_collection_Id = 'PROHIBITED' THEN
			IF NEW.netblock_collection_Id IS NOT NULL THEN
				RAISE 'netblock_collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Person_Id = 'REQUIRED' THEN
			IF NEW.Person_Id IS NULL THEN
				RAISE 'Person_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Person_Id = 'PROHIBITED' THEN
			IF NEW.Person_Id IS NOT NULL THEN
				RAISE 'Person_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Property_Rank = 'REQUIRED' THEN
			IF NEW.property_rank IS NULL THEN
				RAISE 'property_rank is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Property_Rank = 'PROHIBITED' THEN
			IF NEW.property_rank IS NOT NULL THEN
				RAISE 'property_rank is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.account_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	act	val_account_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	act
	FROM	val_account_collection_type
	WHERE	account_collection_type =
		(select account_collection_type from account_collection
			where account_collection_id = NEW.account_collection_id);

	IF act.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Device Collections of type % may not be hierarcical',
			act.account_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.account_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	act	val_account_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	act
	FROM	val_account_collection_type
	WHERE	account_collection_type =
		(select account_collection_type from account_collection
			where account_collection_id = NEW.account_collection_id);

	IF act.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from account_collection_account
		  where account_collection_id = NEW.account_collection_id;
		IF tally > act.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF act.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from account_collection_account
		  		inner join account_collection using (account_collection_id)
		  where account_id = NEW.account_id
		  and	account_collection_type = act.account_collection_type;
		IF tally > act.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Device may not be a member of more than % collections of type %',
				act.MAX_NUM_COLLECTIONS, act.account_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.device_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	dct	val_device_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_device_collection_type
	WHERE	device_collection_type =
		(select device_collection_type from device_collection
			where device_collection_id = NEW.parent_device_collection_id);

	IF dct.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Device Collections of type % may not be hierarcical',
			dct.device_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.device_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	dct	val_device_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_device_collection_type
	WHERE	device_collection_type =
		(select device_collection_type from device_collection
			where device_collection_id = NEW.device_collection_id);

	IF dct.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from device_collection_device
		  where device_collection_id = NEW.device_collection_id;
		IF tally > dct.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF dct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from device_collection_device
		  		inner join device_collection using (device_collection_id)
		  where device_id = NEW.device_id
		  and	device_collection_type = dct.device_collection_type;
		IF tally > dct.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Device may not be a member of more than % collections of type %',
				dct.MAX_NUM_COLLECTIONS, dct.device_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.netblock_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	nct	val_netblock_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	nct
	FROM	val_netblock_collection_type
	WHERE	netblock_collection_type =
		(select netblock_collection_type from netblock_collection
			where netblock_collection_id = NEW.netblock_collection_id);

	IF nct.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Device Collections of type % may not be hierarcical',
			nct.netblock_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.netblock_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	nct	val_netblock_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	nct
	FROM	val_netblock_collection_type
	WHERE	netblock_collection_type =
		(select netblock_collection_type from netblock_collection
			where netblock_collection_id = NEW.netblock_collection_id);

	IF nct.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from netblock_collection_netblock
		  where netblock_collection_id = NEW.netblock_collection_id;
		IF tally > nct.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF nct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from netblock_collection_netblock
		  		inner join netblock_collection using (netblock_collection_id)
		  where netblock_id = NEW.netblock_id
		  and	netblock_collection_type = nct.netblock_collection_type;
		IF tally > nct.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Device may not be a member of more than % collections of type %',
				nct.MAX_NUM_COLLECTIONS, nct.netblock_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.perform_audit_account_realm_acct_coll_type()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO audit.account_realm_acct_coll_type
		    VALUES ( OLD.*, 'DEL', now(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO audit.account_realm_acct_coll_type
		    VALUES ( NEW.*, 'UPD', now(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO audit.account_realm_acct_coll_type
		    VALUES ( NEW.*, 'INS', now(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.perform_audit_asset()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO audit.asset
		    VALUES ( OLD.*, 'DEL', now(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO audit.asset
		    VALUES ( NEW.*, 'UPD', now(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO audit.asset
		    VALUES ( NEW.*, 'INS', now(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.perform_audit_contract()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO audit.contract
		    VALUES ( OLD.*, 'DEL', now(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO audit.contract
		    VALUES ( NEW.*, 'UPD', now(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO audit.contract
		    VALUES ( NEW.*, 'INS', now(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.perform_audit_contract_type()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO audit.contract_type
		    VALUES ( OLD.*, 'DEL', now(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO audit.contract_type
		    VALUES ( NEW.*, 'UPD', now(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO audit.contract_type
		    VALUES ( NEW.*, 'INS', now(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.perform_audit_device_collection_ssh_key()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO audit.device_collection_ssh_key
		    VALUES ( OLD.*, 'DEL', now(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO audit.device_collection_ssh_key
		    VALUES ( NEW.*, 'UPD', now(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO audit.device_collection_ssh_key
		    VALUES ( NEW.*, 'INS', now(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.perform_audit_device_encapsulation_domain()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO audit.device_encapsulation_domain
		    VALUES ( OLD.*, 'DEL', now(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO audit.device_encapsulation_domain
		    VALUES ( NEW.*, 'UPD', now(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO audit.device_encapsulation_domain
		    VALUES ( NEW.*, 'INS', now(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.perform_audit_device_layer2_network()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO audit.device_layer2_network
		    VALUES ( OLD.*, 'DEL', now(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO audit.device_layer2_network
		    VALUES ( NEW.*, 'UPD', now(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO audit.device_layer2_network
		    VALUES ( NEW.*, 'INS', now(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.perform_audit_device_type_module_device_type()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO audit.device_type_module_device_type
		    VALUES ( OLD.*, 'DEL', now(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO audit.device_type_module_device_type
		    VALUES ( NEW.*, 'UPD', now(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO audit.device_type_module_device_type
		    VALUES ( NEW.*, 'INS', now(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.perform_audit_encapsulation_domain()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO audit.encapsulation_domain
		    VALUES ( OLD.*, 'DEL', now(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO audit.encapsulation_domain
		    VALUES ( NEW.*, 'UPD', now(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO audit.encapsulation_domain
		    VALUES ( NEW.*, 'INS', now(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.perform_audit_encapsulation_range()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO audit.encapsulation_range
		    VALUES ( OLD.*, 'DEL', now(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO audit.encapsulation_range
		    VALUES ( NEW.*, 'UPD', now(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO audit.encapsulation_range
		    VALUES ( NEW.*, 'INS', now(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.perform_audit_layer2_connection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO audit.layer2_connection
		    VALUES ( OLD.*, 'DEL', now(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO audit.layer2_connection
		    VALUES ( NEW.*, 'UPD', now(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO audit.layer2_connection
		    VALUES ( NEW.*, 'INS', now(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.perform_audit_layer2_connection_l2_network()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO audit.layer2_connection_l2_network
		    VALUES ( OLD.*, 'DEL', now(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO audit.layer2_connection_l2_network
		    VALUES ( NEW.*, 'UPD', now(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO audit.layer2_connection_l2_network
		    VALUES ( NEW.*, 'INS', now(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.perform_audit_layer2_network()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO audit.layer2_network
		    VALUES ( OLD.*, 'DEL', now(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO audit.layer2_network
		    VALUES ( NEW.*, 'UPD', now(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO audit.layer2_network
		    VALUES ( NEW.*, 'INS', now(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.perform_audit_layer3_network()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO audit.layer3_network
		    VALUES ( OLD.*, 'DEL', now(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO audit.layer3_network
		    VALUES ( NEW.*, 'UPD', now(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO audit.layer3_network
		    VALUES ( NEW.*, 'INS', now(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.perform_audit_logical_port()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO audit.logical_port
		    VALUES ( OLD.*, 'DEL', now(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO audit.logical_port
		    VALUES ( NEW.*, 'UPD', now(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO audit.logical_port
		    VALUES ( NEW.*, 'INS', now(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.perform_audit_mlag_peering()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO audit.mlag_peering
		    VALUES ( OLD.*, 'DEL', now(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO audit.mlag_peering
		    VALUES ( NEW.*, 'UPD', now(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO audit.mlag_peering
		    VALUES ( NEW.*, 'INS', now(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.perform_audit_network_interface_netblock()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO audit.network_interface_netblock
		    VALUES ( OLD.*, 'DEL', now(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO audit.network_interface_netblock
		    VALUES ( NEW.*, 'UPD', now(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO audit.network_interface_netblock
		    VALUES ( NEW.*, 'INS', now(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.perform_audit_token_collection_hier()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO audit.token_collection_hier
		    VALUES ( OLD.*, 'DEL', now(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO audit.token_collection_hier
		    VALUES ( NEW.*, 'UPD', now(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO audit.token_collection_hier
		    VALUES ( NEW.*, 'INS', now(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.perform_audit_val_contract_type()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO audit.val_contract_type
		    VALUES ( OLD.*, 'DEL', now(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO audit.val_contract_type
		    VALUES ( NEW.*, 'UPD', now(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO audit.val_contract_type
		    VALUES ( NEW.*, 'INS', now(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.perform_audit_val_encapsulation_mode()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO audit.val_encapsulation_mode
		    VALUES ( OLD.*, 'DEL', now(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO audit.val_encapsulation_mode
		    VALUES ( NEW.*, 'UPD', now(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO audit.val_encapsulation_mode
		    VALUES ( NEW.*, 'INS', now(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.perform_audit_val_logical_port_type()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO audit.val_logical_port_type
		    VALUES ( OLD.*, 'DEL', now(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO audit.val_logical_port_type
		    VALUES ( NEW.*, 'UPD', now(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO audit.val_logical_port_type
		    VALUES ( NEW.*, 'INS', now(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.service_environment_coll_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	svcenvt	val_service_env_coll_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	svcenvt
	FROM	val_service_env_coll_type
	WHERE	service_env_collection_type =
		(select service_env_collection_type 
			from service_environment_collection
			where service_env_collection_id = 
				NEW.service_env_collection_id);

	IF svcenvt.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Device Collections of type % may not be hierarcical',
			svcenvt.service_env_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.service_environment_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	svcenvt	val_service_env_coll_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	svcenvt
	FROM	val_service_env_coll_type
	WHERE	service_env_collection_type =
		(select service_env_collection_type 
			from service_environment_collection
			where service_env_collection_id = 
				NEW.service_env_collection_id);

	IF svcenvt.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from svc_environment_coll_svc_env
		  where service_env_collection_id = NEW.service_env_collection_id;
		IF tally > svcenvt.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF svcenvt.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from svc_environment_coll_svc_env
		  		inner join service_environment_collection 
					USING (service_env_collection_id)
		  where service_environment = NEW.service_environment
		  and	service_env_collection_type = 
					svcenvt.service_env_collection_type;
		IF tally > svcenvt.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Device may not be a member of more than % collections of type %',
				svcenvt.MAX_NUM_COLLECTIONS, svcenvt.service_env_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.token_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	tct	val_token_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	tct
	FROM	val_token_collection_type
	WHERE	token_collection_type =
		(select token_collection_type from token_collection
			where token_collection_id = NEW.token_collection_id);

	IF tct.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Device Collections of type % may not be hierarcical',
			tct.token_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.token_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	tct	val_token_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	tct
	FROM	val_token_collection_type
	WHERE	token_collection_type =
		(select token_collection_type from token_collection
			where token_collection_id = NEW.token_collection_id);

	IF tct.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from token_collection_token
		  where token_collection_id = NEW.token_collection_id;
		IF tally > tct.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF tct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from token_collection_token
		  		inner join token_collection using (token_collection_id)
		  where token_id = NEW.token_id
		  and	token_collection_type = tct.token_collection_type;
		IF tally > tct.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Device may not be a member of more than % collections of type %',
				tct.MAX_NUM_COLLECTIONS, tct.token_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

DROP FUNCTION IF EXISTS find_best_parent_id ( in_ipaddress inet, in_netmask_bits integer, in_netblock_type character varying, in_ip_universe_id integer, in_is_single_address character, in_netblock_id integer );
-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_best_parent_id');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_best_parent_id ( in_netblock_id integer );
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

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_free_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_free_netblock ( parent_netblock_id integer, netmask_bits integer, single_address boolean, allocate_from_bottom boolean );
CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblock(parent_netblock_id integer, netmask_bits integer DEFAULT NULL::integer, single_address boolean DEFAULT false, allocate_from_bottom boolean DEFAULT true)
 RETURNS TABLE(ip_address inet, netblock_type character varying, ip_universe_id integer)
 LANGUAGE plpgsql
AS $function$
BEGIN
	RETURN QUERY SELECT netblock_utils.find_free_netblocks(
		parent_netblock_id := parent_netblock_id,
		netmask_bits := netmask_bits,
		single_address := single_address,
		allocate_from_bottom := allocate_from_bottom,
		max_addresses := 1);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_free_netblocks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_free_netblocks ( parent_netblock_id integer, netmask_bits integer, single_address boolean, allocate_from_bottom boolean, max_addresses integer );
CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblocks(parent_netblock_id integer, netmask_bits integer DEFAULT NULL::integer, single_address boolean DEFAULT false, allocate_from_bottom boolean DEFAULT true, max_addresses integer DEFAULT 1024)
 RETURNS TABLE(ip_address inet, netblock_type character varying, ip_universe_id integer)
 LANGUAGE plpgsql
AS $function$
BEGIN
	RETURN QUERY SELECT netblock_utils.find_free_netblocks(
		parent_netblock_list := ARRAY[parent_netblock_id],
		netmask_bits := netmask_bits,
		single_address := single_address,
		allocate_from_bottom := allocate_from_bottom,
		max_addresses := max_addresses);
END;
$function$
;

-- New function
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
		    from netblock
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
		RAISE NOTICE 'oh, yeah...';
		select  Netblock_Id
		  into	par_nbid
		  from  ( select Netblock_Id, Ip_Address, Netmask_Bits
			    from netblock
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
					select parent_netblock_id from netblock 
						where is_single_address = 'N'
						and parent_netblock_id is not null
				)
			order by masklen(ip_address) desc
		) subq LIMIT 1;

		IF can_fix_can_subnet AND par_nbd IS NOT NULL THEN
			UPDATE netblock SET can_subnet = 'N' where netblock_id = par_nbid;
		END IF;
	END IF;


	return par_nbid;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblocks(parent_netblock_list integer[], netmask_bits integer DEFAULT NULL::integer, single_address boolean DEFAULT false, allocate_from_bottom boolean DEFAULT true, max_addresses integer DEFAULT 1024)
 RETURNS TABLE(ip_address inet, netblock_type character varying, ip_universe_id integer)
 LANGUAGE plpgsql
AS $function$
DECLARE
	parent_nbid		jazzhands.netblock.netblock_id%TYPE;
	step			integer;
	nb_size			integer;
	offset			integer;
	netblock_rec	jazzhands.netblock%ROWTYPE;
	current_ip		inet;
	min_ip			inet;
	max_ip			inet;
	matches			integer;
	family_bits		integer;
BEGIN
	matches := 0;
	FOREACH parent_nbid IN ARRAY parent_netblock_list LOOP
		SELECT 
			* INTO netblock_rec
		FROM
			jazzhands.netblock n
		WHERE
			n.netblock_id = parent_nbid;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'Netblock % does not exist', parent_nbid;
		END IF;

		family_bits := 
			(CASE family(netblock_rec.ip_address) WHEN 4 THEN 32 ELSE 128 END);

		IF single_address THEN 
			netmask_bits := family_bits;
		ELSIF netmask_bits <= masklen(netblock_rec.ip_address) THEN
			RAISE EXCEPTION 'netmask_bits must be larger than the netblock (%)',
				masklen(netblock_rec.ip_address);
		END IF;

		IF netmask_bits > family_bits
			THEN
			RAISE EXCEPTION 'netmask_bits must be no more than % for netblock %',
				family_bits,
				netblock_rec.ip_address;
		END IF;

		IF single_address AND netblock_rec.can_subnet = 'Y' THEN
			RAISE EXCEPTION 'single addresses may not be assigned to to a block where can_subnet is Y';
		END IF;

		IF (NOT single_address) AND netblock_rec.can_subnet = 'N' THEN
			RAISE EXCEPTION 'Netblock % (%) may not be subnetted',
				netblock_rec.ip_address,
				netblock_rec.netblock_id;
		END IF;

		-- It would be nice to be able to use generate_series here, but
		-- that could get really huge

		nb_size := 1 << ( family_bits - netmask_bits );
		min_ip := netblock_rec.ip_address;
		max_ip := min_ip + (1 << (family_bits - masklen(min_ip)));

		IF allocate_from_bottom THEN
			current_ip := set_masklen(netblock_rec.ip_address, netmask_bits);
		ELSE
			current_ip := set_masklen(max_ip, netmask_bits) - nb_size;
			nb_size := -nb_size;
		END IF;

		RAISE DEBUG 'Searching netblock % (%)',
			netblock_rec.netblock_id,
			netblock_rec.ip_address;

		-- For single addresses, make the netmask match the netblock of the
		-- containing block, and skip the network and broadcast addresses

		IF single_address THEN
			current_ip := set_masklen(current_ip, masklen(netblock_rec.ip_address));
			IF family(netblock_rec.ip_address) = 4 AND
					masklen(netblock_rec.ip_address) < 31 THEN
				current_ip := current_ip + nb_size;
				min_ip := min_ip - 1;
				max_ip := max_ip - 1;
			END IF;
		END IF;

		RAISE DEBUG 'Starting with IP address % with step of %',
			current_ip,
			nb_size;

		WHILE (
				current_ip >= min_ip AND
				current_ip < max_ip AND
				matches < max_addresses
		) LOOP
			RAISE DEBUG '   Checking netblock %', current_ip;

			PERFORM * FROM netblock n WHERE
				n.ip_universe_id = netblock_rec.ip_universe_id AND
				n.netblock_type = netblock_rec.netblock_type AND
				-- A block with the parent either contains or is contained
				-- by this block
				n.parent_netblock_id = netblock_rec.netblock_id AND
				CASE WHEN single_address THEN
					n.ip_address = current_ip
				ELSE
					(n.ip_address >>= current_ip OR current_ip >>= n.ip_address)
				END;
			IF NOT FOUND THEN
				find_free_netblocks.netblock_type :=
					netblock_rec.netblock_type;
				find_free_netblocks.ip_universe_id :=
					netblock_rec.ip_universe_id;
				find_free_netblocks.ip_address := current_ip;
				RETURN NEXT;
				matches := matches + 1;
			END IF;

			current_ip := current_ip + nb_size;
		END LOOP;
	END LOOP;
	RETURN;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'allocate_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock ( parent_netblock_id integer, netmask_bits integer, address_type text, can_subnet boolean, allocate_from_bottom boolean, description character varying, netblock_status character varying );
CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(parent_netblock_id integer, netmask_bits integer DEFAULT NULL::integer, address_type text DEFAULT 'netblock'::text, can_subnet boolean DEFAULT true, allocate_from_bottom boolean DEFAULT true, description character varying DEFAULT NULL::character varying, netblock_status character varying DEFAULT NULL::character varying)
 RETURNS netblock
 LANGUAGE plpgsql
AS $function$
DECLARE
	netblock_rec	RECORD;
BEGIN
	SELECT netblock_manip.allocate_netblock(
		parent_netblock_list := ARRAY[parent_netblock_id],
		netmask_bits := netmask_bits,
		address_type := address_type,
		can_subnet := can_subnet,
		allocate_from_bottom := allocate_from_bottom,
		description := description,
		netblock_status := netblock_status
	) into netblock_rec;
	RETURN netblock_rec;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(parent_netblock_list integer[], netmask_bits integer DEFAULT NULL::integer, address_type text DEFAULT 'netblock'::text, can_subnet boolean DEFAULT true, allocate_from_bottom boolean DEFAULT true, description character varying DEFAULT NULL::character varying, netblock_status character varying DEFAULT NULL::character varying)
 RETURNS netblock
 LANGUAGE plpgsql
AS $function$
DECLARE
	parent_rec		RECORD;
	netblock_rec	RECORD;
	inet_rec		RECORD;
	loopback_bits	integer;
	inet_family		integer;
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

	-- Lock the parent row, which should keep parallel processes from
	-- trying to obtain the same address

	FOR parent_rec IN SELECT * FROM netblock WHERE netblock_id = 
			ANY(allocate_netblock.parent_netblock_list) FOR UPDATE LOOP

		IF parent_rec.is_single_address = 'Y' THEN
			RAISE EXCEPTION 'parent_netblock_id refers to a single_address netblock'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF inet_family IS NULL THEN
			inet_family := family(parent_rec.ip_address);
		ELSIF inet_family != family(parent_rec.ip_address) THEN
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
 		RAISE EXCEPTION 'parent_netblock_list is not valid'
 			USING ERRCODE = 'invalid_parameter_value';
 	END IF;

	IF address_type = 'loopback' THEN
		-- If we're allocating a loopback address, then we need to create
		-- a new parent to hold the single loopback address

		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			netmask_bits := loopback_bits,
			single_address := false,
			allocate_from_bottom := allocate_from_bottom,
			max_addresses := 1
			);

		IF NOT FOUND THEN
			RAISE EXCEPTION 'No valid netblocks found to allocate'
			USING ERRCODE = 'JH110';
		END IF;

		INSERT INTO netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			loopback_bits,
			inet_rec.netblock_type,
			'N',
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO parent_rec;

		INSERT INTO netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec,
			masklen(inet_rec),
			parent_rec.netblock_type,
			'Y',
			'N',
			parent_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		RETURN netblock_rec;
	END IF;

	IF address_type = 'single' THEN
		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			single_address := true,
			allocate_from_bottom := allocate_from_bottom,
			max_addresses := 1
			);

		IF NOT FOUND THEN
			RAISE EXCEPTION 'No valid netblocks found to allocate'
			USING ERRCODE = 'JH110';
		END IF;

		RAISE NOTICE 'ip_address is %', inet_rec.ip_address;

		INSERT INTO netblock (
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
			allocate_from_bottom := allocate_from_bottom,
			max_addresses := 1);

		IF NOT FOUND THEN
			RAISE EXCEPTION 'No valid netblocks found to allocate'
			USING ERRCODE = 'JH110';
		END IF;

		INSERT INTO netblock (
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

		RETURN netblock_rec;
	END IF;
END;
$function$
;

-- Dropping obsoleted sequences....
DROP SEQUENCE IF EXISTS layer2_encapsulation_layer2_encapsulation_id_seq;
DROP SEQUENCE IF EXISTS vlan_range_vlan_range_id_seq;
DROP SEQUENCE IF EXISTS secondary_netblock_secondary_netblock_id_seq;
DROP SEQUENCE IF EXISTS encapsulation_encapsulation_id_seq;


-- Dropping obsoleted audit sequences....
DROP SEQUENCE IF EXISTS audit.vlan_range_seq;
DROP SEQUENCE IF EXISTS audit.secondary_netblock_seq;
DROP SEQUENCE IF EXISTS audit.layer2_encapsulation_seq;
DROP SEQUENCE IF EXISTS audit.val_layer2_encapsulation_type_seq;
DROP SEQUENCE IF EXISTS audit.encapsulation_seq;
DROP SEQUENCE IF EXISTS audit.device_coll_account_coll_seq;
DROP SEQUENCE IF EXISTS audit.encapsulation_netblock_seq;


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
ALTER TABLE account DROP CONSTRAINT IF EXISTS fk_account_company_person;
ALTER TABLE account
	ADD CONSTRAINT fk_account_company_person
	FOREIGN KEY (company_id, person_id) REFERENCES person_company(company_id, person_id) DEFERRABLE;

ALTER TABLE account DROP CONSTRAINT IF EXISTS fk_account_prsn_cmpy_acct;
ALTER TABLE account
	ADD CONSTRAINT fk_account_prsn_cmpy_acct
	FOREIGN KEY (person_id, company_id, account_realm_id) REFERENCES person_account_realm_company(person_id, company_id, account_realm_id) DEFERRABLE;

ALTER TABLE device_power_interface DROP CONSTRAINT IF EXISTS r_509;
ALTER TABLE device_power_interface
	ADD CONSTRAINT fk_dev_pwr_int_pwr_plug
	FOREIGN KEY (power_plug_style) REFERENCES val_power_plug_style(power_plug_style);

-- triggers
CREATE CONSTRAINT TRIGGER trigger_account_collection_member_enforce AFTER INSERT OR UPDATE ON account_collection_account DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE account_collection_member_enforce();
CREATE CONSTRAINT TRIGGER trigger_account_collection_hier_enforce AFTER INSERT OR UPDATE ON account_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE account_collection_hier_enforce();
CREATE CONSTRAINT TRIGGER trigger_device_collection_member_enforce AFTER INSERT OR UPDATE ON device_collection_device DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE device_collection_member_enforce();
CREATE CONSTRAINT TRIGGER trigger_device_collection_hier_enforce AFTER INSERT OR UPDATE ON device_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE device_collection_hier_enforce();
DROP TRIGGER IF EXISTS trigger_dns_rec_before ON dns_record;
DROP TRIGGER IF EXISTS trigger_update_dns_zone ON dns_record;
CREATE CONSTRAINT TRIGGER trigger_netblock_collection_hier_enforce AFTER INSERT OR UPDATE ON netblock_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE netblock_collection_hier_enforce();
CREATE CONSTRAINT TRIGGER trigger_netblock_collection_member_enforce AFTER INSERT OR UPDATE ON netblock_collection_netblock DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE netblock_collection_member_enforce();
CREATE CONSTRAINT TRIGGER trigger_service_environment_coll_hier_enforce AFTER INSERT OR UPDATE ON service_environment_coll_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE service_environment_coll_hier_enforce();
CREATE CONSTRAINT TRIGGER trigger_service_environment_collection_member_enforce AFTER INSERT OR UPDATE ON svc_environment_coll_svc_env DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE service_environment_collection_member_enforce();
CREATE CONSTRAINT TRIGGER trigger_token_collection_member_enforce AFTER INSERT OR UPDATE ON token_collection_token DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE token_collection_member_enforce();
CREATE CONSTRAINT TRIGGER trigger_token_collection_hier_enforce AFTER INSERT OR UPDATE ON token_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE token_collection_hier_enforce();

CREATE INDEX xif5chassis_location ON chassis_location USING btree (module_device_type_id, chassis_device_type_id, device_type_module_name);

DROP TRIGGER IF EXISTS trigger_device_update_location_fix ON device;
drop function if exists device_update_location_fix();

-- Random clean up of regrant/recreate
delete from __recreate where schema = 'netblock_utils' and object = 'find_best_parent_id';
UPDATE __regrants SET 
	regrant = replace(regrant, 'in_is_single_address character, in_netblock_id integer', 'in_is_single_address character, in_netblock_id integer, in_fuzzy_can_subnet boolean, can_fix_can_subnet boolean')
WHERE schema = 'netblock_utils' 
AND object = 'find_best_parent_id';

-- AN specific
UPDATE __recreate SET
	ddl = replace(ddl, 'ON d.location_id =', 'ON d.rack_location_id =')
WHERE
	schema = 'cloudapi' and object = 'network_device';

UPDATE __recreate SET
	ddl = replace(ddl, 'ON d.location_id =', 'ON d.rack_location_id =')
WHERE
	schema = 'cloudapi' and object = 'server';

DROP VIEW IF EXISTS location;
DROP FUNCTION IF EXISTS del_location_transition();
DROP FUNCTION IF EXISTS upd_location_transition();
DROP FUNCTION IF EXISTS ins_location_transition();

-- Clean Up
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_saved_grants();

SELECT schema_support.end_maintenance();

select now();
