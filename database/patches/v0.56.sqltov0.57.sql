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


-- Objects affected...

-- schema_support.begin_maintenance schema_support.end_maintenance schema_support.prepare_for_grant_replay schema_support.save_grants_for_replay_relations schema_support.save_grants_for_replay_procedures schema_support.save_grants_for_replay schema_support.replay_saved_grants device_type_module dns_change_record location ticketing_system person_manip.add_user person_manip.get_unix_uid person_manip.add_person jazzhands.dns_record_update_nontime dns_rec_type_validation dns_rec_prevent_dups device_update_location_fix device_type_module_sanity_set device_utils.retire_device_ancillary netblock_utils.find_best_parent_id
-- location_complex_sanity device_type_module_sanity_del device_type_module_sanity_set manipulate_netblock_parentage_before person_manip.pick_login person_manip.setup_unix_account
-- physical_port device_ticket
-- automated_ac
-- automated_ac_on_person
-- automated_ac_on_person_company
-- automated_realm_site_ac_pl
-- check_person_image_usage_mv
-- create_new_unix_account delete_per_device_device_collection delete_peruser_account_collection propagate_person_status_to_account update_account_type_account_collection update_per_svc_env_svc_env_collection update_peruser_account_collection update_dns_zone
-- delete_per_svc_env_svc_env_collection update_per_device_device_collection validate_netblock validate_property verify_device_voe verify_layer1_connection person_manip.add_account_non_person
-- port_utils.setup_device_physical_ports
-- schema_support.build_audit_table
-- device_power_interface device_type
-- validate_netblock_parentage
-- device_type_phys_port_templt

\set ON_ERROR_STOP

---------- ========================================================= ----------
--- BEGIN: recreate schema_support

-- :r ../ddl/schema/pgsql/create_schema_support.sql

--
-- $HeadURL$
-- $Id$
--


-- Create schema if it does not exist, do nothing otherwise.
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*) 
	from pg_catalog.pg_namespace 
	into _tal
	where nspname = 'schema_support';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS schema_support;
		CREATE SCHEMA schema_support AUTHORIZATION jazzhands;
	END IF;
END;
$$;


-------------------------------------------------------------------
-- returns the Id tag for CM
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION schema_support.id_tag()
RETURNS VARCHAR AS $$
BEGIN
    RETURN('<-- $Id -->');
END;
$$ LANGUAGE plpgsql;
-- end of procedure id_tag
-------------------------------------------------------------------

CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_trigger
    ( aud_schema VARCHAR, tbl_schema VARCHAR, table_name VARCHAR )
RETURNS VOID AS $$
BEGIN
    EXECUTE 'CREATE OR REPLACE FUNCTION ' || quote_ident(tbl_schema)
	|| '.' || quote_ident('perform_audit_' || table_name)
	|| $ZZ$() RETURNS TRIGGER AS $TQ$
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
		    INSERT INTO $ZZ$ || quote_ident(aud_schema) 
			|| '.' || quote_ident(table_name) || $ZZ$
		    VALUES ( OLD.*, 'DEL', now(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO $ZZ$ || quote_ident(aud_schema)
			|| '.' || quote_ident(table_name) || $ZZ$
		    VALUES ( NEW.*, 'UPD', now(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO $ZZ$ || quote_ident(aud_schema)
			|| '.' || quote_ident(table_name) || $ZZ$
		    VALUES ( NEW.*, 'INS', now(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$TQ$ LANGUAGE plpgsql SECURITY DEFINER
    $ZZ$;

    EXECUTE 'DROP TRIGGER IF EXISTS ' || quote_ident('trigger_audit_'
	|| table_name) || ' ON ' || quote_ident(tbl_schema) || '.'
	|| quote_ident(table_name);

    EXECUTE 'CREATE TRIGGER ' || quote_ident('trigger_audit_' || table_name)
	|| ' AFTER INSERT OR UPDATE OR DELETE ON ' || quote_ident(tbl_schema)
	|| '.' || quote_ident(table_name) || ' FOR EACH ROW EXECUTE PROCEDURE ' 
	|| quote_ident(tbl_schema) || '.' || quote_ident('perform_audit_'
	|| table_name) || '()';
END;
$$ LANGUAGE plpgsql;

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_triggers
    ( aud_schema varchar, tbl_schema varchar )
RETURNS VOID AS $$
DECLARE
    table_list RECORD;
BEGIN
    --
    -- select tables with audit tables
    --
    FOR table_list IN
	SELECT table_name FROM information_schema.tables
	WHERE table_type = 'BASE TABLE' AND table_schema = tbl_schema
	AND table_name IN (
	    SELECT table_name FROM information_schema.tables
	    WHERE table_schema = aud_schema AND table_type = 'BASE TABLE'
	) ORDER BY table_name
    LOOP
	PERFORM schema_support.rebuild_audit_trigger
	    (aud_schema, tbl_schema, table_list.table_name);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION schema_support.build_audit_table(
    aud_schema VARCHAR, tbl_schema VARCHAR, table_name VARCHAR,
    first_time boolean DEFAULT true
)
RETURNS VOID AS $FUNC$
BEGIN
    IF first_time THEN
	EXECUTE 'CREATE SEQUENCE ' || quote_ident(aud_schema) || '.'
	    || quote_ident(table_name || '_seq');
    END IF;

    EXECUTE 'CREATE TABLE ' || quote_ident(aud_schema) || '.'
	|| quote_ident(table_name) || ' AS '
	|| 'SELECT *, NULL::char(3) as "aud#action", now() as "aud#timestamp", '
	|| 'NULL::varchar(255) AS "aud#user", NULL::integer AS "aud#seq" '
	|| 'FROM ' || quote_ident(tbl_schema) || '.' || quote_ident(table_name) 
	|| ' LIMIT 0';

    EXECUTE 'ALTER TABLE ' || quote_ident(aud_schema) || '.'
	|| quote_ident(table_name)
	|| $$ ALTER COLUMN "aud#seq" SET NOT NULL, $$
	|| $$ ALTER COLUMN "aud#seq" SET DEFAULT nextval('$$
	|| quote_ident(aud_schema) || '.' || quote_ident(table_name || '_seq')
	|| $$')$$;

    EXECUTE 'CREATE INDEX ' 
	|| quote_ident( table_name || '_aud#timestamp_idx')
	|| ' ON ' || quote_ident(aud_schema) || '.'
	|| quote_ident(table_name) || '("aud#timestamp")';

    IF first_time THEN
	PERFORM schema_support.rebuild_audit_trigger
	    ( aud_schema, tbl_schema, table_name );
    END IF;
END;
$FUNC$ LANGUAGE plpgsql;

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION schema_support.build_audit_tables
    ( aud_schema varchar, tbl_schema varchar )
RETURNS VOID AS $FUNC$
DECLARE
     table_list RECORD;
BEGIN
    FOR table_list IN
	SELECT table_name FROM information_schema.tables
	WHERE table_type = 'BASE TABLE' AND table_schema = tbl_schema
	AND NOT ( 
	    table_name IN (
		SELECT table_name FROM information_schema.tables
		WHERE table_schema = aud_schema
	    )
	)
	ORDER BY table_name
    LOOP
	PERFORM schema_support.build_audit_table
	    ( aud_schema, tbl_schema, table_list.table_name );
    END LOOP;

    PERFORM schema_support.rebuild_audit_triggers(aud_schema, tbl_schema);
END;
$FUNC$ LANGUAGE plpgsql;

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION schema_support.trigger_ins_upd_generic_func()
RETURNS TRIGGER AS $$
DECLARE
    appuser VARCHAR;
BEGIN
    BEGIN
	appuser := session_user || '/' || current_setting('jazzhands.appuser');
    EXCEPTION
	WHEN OTHERS THEN appuser := session_user;
    END;

    appuser = substr(appuser, 1, 255);

    IF TG_OP = 'INSERT' THEN
	NEW.data_ins_user = appuser;
	NEW.data_ins_date = 'now';
    END IF;

    IF TG_OP = 'UPDATE' THEN
	NEW.data_upd_user = appuser;
	NEW.data_upd_date = 'now';

	IF OLD.data_ins_user != NEW.data_ins_user THEN
	    RAISE EXCEPTION
		'Non modifiable column "DATA_INS_USER" cannot be modified.';
	END IF;

	IF OLD.data_ins_date != NEW.data_ins_date THEN
	    RAISE EXCEPTION
		'Non modifiable column "DATA_INS_DATE" cannot be modified.';
	END IF;
    END IF;

    RETURN NEW;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION schema_support.rebuild_stamp_trigger
    (tbl_schema VARCHAR, table_name VARCHAR)
RETURNS VOID AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION schema_support.rebuild_stamp_triggers
    (tbl_schema VARCHAR)
RETURNS VOID AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-------------------------------------------------------------------------------

-- MAINTENANCE SUPPORT FUNCTIONS

--
-- Check for ideal maintenance conditions.
-- Are we superuser? (argument turns this off if it is not necessary
-- Are we in a transaction?
--
-- Raise an exception now
--
CREATE OR REPLACE FUNCTION schema_support.begin_maintenance(
	shouldbesuper boolean DEFAULT true
)
RETURNS BOOLEAN AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

--
-- Revokes superuser if its set on the current user
--
CREATE OR REPLACE FUNCTION schema_support.end_maintenance()
RETURNS BOOLEAN AS $$
DECLARE issuper boolean;
BEGIN
		SELECT usesuper INTO issuper FROM pg_user where usename = current_user;
		IF issuper THEN
			EXECUTE 'ALTER USER ' || current_user || ' NOSUPERUSER';
		END IF;
		RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--
-- Sets up temporary tables for replaying grants if it does not exist
--
-- This is called by other functions in this module.
--
CREATE OR REPLACE FUNCTION schema_support.prepare_for_grant_replay()
RETURNS VOID AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

--
-- Collect grants for relations and saves them for future replay (if objects
-- are dropped and recreated)
--
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay_relations(
	schema varchar,
	object varchar,
	newname varchar DEFAULT NULL
) RETURNS VOID AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

--
-- Collect grants for functions and saves them for future replay (if objects
-- are dropped and recreated)
--
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay_functions(
	schema varchar,
	object varchar,
	newname varchar DEFAULT NULL
) RETURNS VOID AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

--
-- save grants for object regardless of if its a relation or function.
--
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay(
	schema varchar,
	object varchar,
	newname varchar DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
	PERFORM schema_support.save_grants_for_replay_relations(schema, object, newname);
	PERFORM schema_support.save_grants_for_replay_functions(schema, object, newname);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--
-- replay saved grants, drop temporary tables
--
CREATE OR REPLACE FUNCTION schema_support.replay_saved_grants(
	beverbose	boolean DEFAULT false
) 
RETURNS VOID AS $$
DECLARE
	_r		RECORD;
	_tally	integer;
BEGIN
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

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--
-- Sets up temporary tables for replaying grants if it does not exist
--
-- This is called by other functions in this module.
--
CREATE OR REPLACE FUNCTION schema_support.prepare_for_object_replay()
RETURNS VOID AS $$
DECLARE
	_tally integer;
BEGIN
	SELECT	count(*)
	  INTO	_tally
	  FROM	pg_catalog.pg_class
	 WHERE	relname = '__recreate'
	   AND	relpersistence = 't';

	IF _tally = 0 THEN
		CREATE TEMPORARY TABLE IF NOT EXISTS __recreate (id SERIAL, schema text, object text, type text, ddl text);
	END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--
-- Saves view definition for replay later.  This is to allow for dropping
-- dependant views and having a migration script recreate them.
--
CREATE OR REPLACE FUNCTION schema_support.save_view_for_replay(
	schema varchar,
	object varchar,
	dropit boolean DEFAULT true
) RETURNS VOID AS $$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

	-- implicitly save regrants
	PERFORM schema_support.save_grants_for_replay(schema, object);
	FOR _r in SELECT n.nspname, c.relname, 'view', 
				pg_get_viewdef(c.oid, true) as viewdef
		FROM pg_class c
		INNER JOIN pg_namespace n on n.oid = c.relnamespace
		WHERE c.relname = object
		AND n.nspname = schema
	LOOP
		_ddl := 'CREATE OR REPLACE VIEW ' || _r.nspname || '.' || _r.relname ||
			' AS ' || _r.viewdef;
		IF _ddl is NULL THEN
			RAISE EXCEPTION 'Unable to define view for %', _r;
		END IF;
		INSERT INTO __recreate (schema, object, type, ddl )
			VALUES (
				_r.nspname, _r.relname, 'view', _ddl
			);
		IF dropit  THEN
			_cmd = 'DROP VIEW ' || _r.nspname || '.' || _r.relname || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--
-- Saves view definition for replay later.  This is to allow for dropping
-- dependant functions and having a migration script recreate them.
--
-- Note this will drop and recreate all functions of the name.  This sh
--
CREATE OR REPLACE FUNCTION schema_support.save_function_for_replay(
	schema varchar,
	object varchar,
	dropit boolean DEFAULT true
) RETURNS VOID AS $$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

	-- implicitly save regrants
	PERFORM schema_support.save_grants_for_replay(schema, object);
	FOR _r IN SELECT n.nspname, p.proname, 
				pg_get_functiondef(p.oid) as funcdef,
				pg_get_function_identity_arguments(p.oid) as idargs
		FROM    pg_catalog.pg_proc  p
				INNER JOIN pg_catalog.pg_namespace n on n.oid = p.pronamespace
				INNER JOIN pg_catalog.pg_language l on l.oid = p.prolang
		WHERE   n.nspname = schema
		  AND	p.proname = object
	LOOP
		INSERT INTO __recreate (schema, object, type, ddl )
		VALUES (
			_r.nspname, _r.proname, 'function', _r.funcdef
		);
		IF dropit  THEN
			_cmd = 'DROP FUNCTION ' || _r.nspname || '.' ||
				_r.proname || '(' || _r.idargs || ');';
			EXECUTE _cmd;
		END IF;

	END LOOP;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION schema_support.replay_object_recreates(
	beverbose	boolean DEFAULT false
) 
RETURNS VOID AS $$
DECLARE
	_r		RECORD;
	_tally	integer;
BEGIN
	FOR _r in SELECT * from __recreate ORDER BY id DESC FOR UPDATE
	LOOP
		IF beverbose THEN
			RAISE NOTICE 'Regrant: %.%', _r.schema, _r.object;
		END IF;
		EXECUTE _r.ddl; 
		DELETE from __recreate where id = _r.id;
	END LOOP;

	SELECT count(*) INTO _tally from __recreate;
	IF _tally > 0 THEN
		RAISE EXCEPTION '% objects still exist for recreating after a complete loop', _tally;
	ELSE
		DROP TABLE __recreate;
	END IF;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Notable queries..
-- select schema_support.save_grants_for_replay('jazzhands', 'physical_port');
-- select schema_support.save_grants_for_replay('port_support', 
-- 'do_l1_connection_update');
-- SELECT  schema_support.replay_saved_grants();
-- SELECT schema_support.save_view_for_replay('jazzhands', 
--	'v_l1_all_physical_ports');

-------------------------------------------------------------------------------
-- select schema_support.rebuild_stamp_triggers();
-- SELECT schema_support.build_audit_tables();
--- DONE:  recreate schema_support
---------- ========================================================= ----------
-- Begin dealing with actual maint.  The above is preliminary work.

SELECT schema_support.begin_maintenance();

drop trigger IF EXISTS trigger_dns_rec_a_type_validation ON dns_record;

CREATE INDEX idx_device_type_location ON device USING btree (device_type_id, location_id);
CREATE INDEX xif13device ON device USING btree (location_id, device_type_id);


SELECT schema_support.save_view_for_replay('jazzhands', 'v_l1_all_physical_ports');

-- drop these index if they exist so things are recreated properly.
-- Later, we will do this as part of the table teardown..  Did not make this
-- revision of the migration generator.
DROP INDEX IF EXISTS audit."location_aud#timestamp_idx";
DROP INDEX IF EXISTS audit."physical_port_aud#timestamp_idx";
DROP INDEX IF EXISTS audit."device_ticket_aud#timestamp_idx";
DROP INDEX IF EXISTS audit."device_power_interface_aud#timestamp_idx";
DROP INDEX IF EXISTS audit."device_type_aud#timestamp_idx";
DROP INDEX IF EXISTS audit."device_type_phys_port_templt_aud#timestamp_idx";


--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device_type_module
CREATE TABLE device_type_module
(
	device_type_id	integer NOT NULL,
	device_type_module_name	varchar(255) NOT NULL,
	description	varchar(255)  NULL,
	device_type_x_offset	character(18)  NULL,
	device_type_y_offset	character(18)  NULL,
	device_type_z_offset	character(18)  NULL,
	device_type_side	character(18)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device_type_module', true);
ALTER TABLE device_type_module
	ALTER device_type_side
	SET DEFAULT 'FRONT'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device_type_module ADD CONSTRAINT pk_device_type_module PRIMARY KEY (device_type_id, device_type_module_name);

-- Table/Column Comments
COMMENT ON COLUMN device_type_module.device_type_z_offset IS 'Offset inside the device (front to back, yes, that is Z).  Only this or device_type_side may be set.';
COMMENT ON COLUMN device_type_module.device_type_side IS 'Only this or z_offset may be set.';
-- INDEXES
CREATE INDEX xif1device_type_module ON device_type_module USING btree (device_type_id);

-- CHECK CONSTRAINTS
ALTER TABLE device_type_module ADD CONSTRAINT ckc_dt_mod_dt_side
	CHECK (device_type_side = ANY (ARRAY['FRONT'::bpchar, 'BACK'::bpchar]));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE device_type_module
	ADD CONSTRAINT fk_devt_mod_dev_type_id
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);

CREATE OR REPLACE FUNCTION jazzhands.device_type_module_sanity_set()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF NEW.DEVICE_TYPE_Z_OFFSET IS NOT NULL AND NEW.DEVICE_TYPE_SIDE IS NOT NULL THEN
		RAISE EXCEPTION 'Both Z Offset and Device_Type_Side may not be set';
	END IF;
	RETURN NEW;
END;
$function$
;

-- RECREATE FUNCTION
-- consider NEW oid 667093
CREATE OR REPLACE FUNCTION jazzhands.device_type_module_sanity_del()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	SELECT	COUNT(*)
	  INTO	_tally
	  FROM	jazzhands.location
	 WHERE	(OLD.device_type_id, OLD.device_type_module_name) 
		 		IN (device_type_id, device_type_module_name) ;

	IF _tally == 0 THEN
		RAISE EXCEPTION '(device_type_id, device_type_module_name) must NOT exist in location.';
	END IF;
	
	RETURN OLD;
END;
$function$
;


-- TRIGGERS
CREATE TRIGGER trigger_device_type_module_sanity_set
        BEFORE INSERT OR DELETE ON device_type_module
        FOR EACH ROW
        EXECUTE PROCEDURE device_type_module_sanity_set();
CREATE TRIGGER trigger_device_type_module_sanity_del
        BEFORE DELETE ON device_type_module
        FOR EACH ROW
        EXECUTE PROCEDURE device_type_module_sanity_del();

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device_type_module');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device_type_module');
-- DONE DEALING WITH TABLE device_type_module [660918]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE dns_change_record
CREATE TABLE dns_change_record
(
	dns_change_record_id	bigint NOT NULL,
	dns_domain_id	integer  NULL,
	ip_address	inet  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'dns_change_record', true);
create sequence dns_change_record_dns_change_record_id_seq;
ALTER TABLE dns_change_record
	ALTER dns_change_record_id
	SET DEFAULT nextval('dns_change_record_dns_change_record_id_seq'::regclass);

ALTER SEQUENCE dns_change_record_dns_change_record_id_seq OWNED BY dns_change_record.dns_change_record_id;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE dns_change_record ADD CONSTRAINT pk_dns_change_record PRIMARY KEY (dns_change_record_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1dns_change_record ON dns_change_record USING btree (dns_domain_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE dns_change_record
	ADD CONSTRAINT fk_dns_chg_dns_domain
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'dns_change_record');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'dns_change_record');
-- DONE DEALING WITH TABLE dns_change_record [660958]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE location [535393]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'location', 'location');

-- FOREIGN KEYS FROM
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_dev_location_id;

-- FOREIGN KEYS TO
ALTER TABLE location DROP CONSTRAINT IF EXISTS fk_location_ref_rack;
ALTER TABLE location DROP CONSTRAINT IF EXISTS pk_location_id;
ALTER TABLE location DROP CONSTRAINT IF EXISTS ak_uq_rack_offset_sid_location;
-- INDEXES
-- CHECK CONSTRAINTS, etc
ALTER TABLE location DROP CONSTRAINT IF EXISTS ckc_rack_side_location;
-- TRIGGERS, etc
DROP TRIGGER trig_userlog_location ON location;
DROP TRIGGER trigger_audit_location ON location;


ALTER TABLE location RENAME TO location_v56;
ALTER TABLE audit.location RENAME TO location_v56;

CREATE TABLE location
(
	location_id	integer NOT NULL,
	device_type_id	integer NULL,
	device_type_module_name	character(18)  NULL,
	rack_id	integer  NULL,
	rack_u_offset_of_device_top	integer  NULL,
	rack_side	varchar(10)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'location', false);
INSERT INTO location (
	location_id,
	device_type_id,		-- new column (device_type_id)
	device_type_module_name,		-- new column (device_type_module_name)
	rack_id,
	rack_u_offset_of_device_top,
	rack_side,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	l.location_id,
	NULL,		-- new column (device_type_id)
	NULL,		-- new column (device_type_module_name)
	l.rack_id,
	l.rack_u_offset_of_device_top,
	l.rack_side,
	l.data_ins_user,
	l.data_ins_date,
	l.data_upd_user,
	l.data_upd_date
FROM location_v56 l;

INSERT INTO audit.location (
	location_id,
	device_type_id,		-- new column (device_type_id)
	device_type_module_name,		-- new column (device_type_module_name)
	rack_id,
	rack_u_offset_of_device_top,
	rack_side,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	l.location_id,
	NULL,		-- new column (device_type_id)
	NULL,		-- new column (device_type_module_name)
	l.rack_id,
	l.rack_u_offset_of_device_top,
	l.rack_side,
	l.data_ins_user,
	l.data_ins_date,
	l.data_upd_user,
	l.data_upd_date,
	l."aud#action",
	l."aud#timestamp",
	l."aud#user",
	l."aud#seq"
FROM audit.location_v56 l;


ALTER TABLE location
	ALTER location_id
	SET DEFAULT nextval('location_location_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE location ADD CONSTRAINT pk_location_id PRIMARY KEY (location_id);
-- Not going to strictly require this yet.
-- ALTER TABLE location ADD CONSTRAINT ak_location_id_device_typ_id UNIQUE (location_id, device_type_id);
ALTER TABLE location ADD CONSTRAINT ak_uq_rack_offset_sid_location UNIQUE (rack_id, rack_u_offset_of_device_top, rack_side);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif2location ON location USING btree (device_type_id);

-- CHECK CONSTRAINTS
ALTER TABLE location ADD CONSTRAINT ckc_rack_side_location
	CHECK ((((rack_side)::text = ANY (ARRAY[('FRONT'::character varying)::text, ('BACK'::character varying)::text])) AND ((rack_side)::text = upper((rack_side)::text))));

-- FOREIGN KEYS FROM
-- ALTER TABLE device
--	ADD CONSTRAINT fk_dev_location_id
--	FOREIGN KEY (location_id, device_type_id) REFERENCES location(location_id, device_type_id);

ALTER TABLE device
	ADD CONSTRAINT fk_dev_location_id
	FOREIGN KEY (location_id) REFERENCES location(location_id);

-- FOREIGN KEYS TO
ALTER TABLE location
	ADD CONSTRAINT fk_location_ref_rack
	FOREIGN KEY (rack_id) REFERENCES rack(rack_id);
ALTER TABLE location
	ADD CONSTRAINT fk_location_device_type_id
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);

CREATE OR REPLACE FUNCTION jazzhands.location_complex_sanity()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	--
	-- If rack_* is set, then all rack_* must be set.
	--
	-- If rack_* is set, then device_type_module must not be set.
	--
	-- device_type_module_name is special
	--
	IF NEW.RACK_ID IS NOT NULL OR NEW.RACK_U_OFFSET_OF_DEVICE_TOP IS NOT NULL
			OR NEW.RACK_SIDE IS NOT NULL THEN
		-- default
		IF NEW.RACK_SIDE IS NULL THEN
			NEW.RACK_SIDE = 'FRONT';
		END IF;
		IF NEW.RACK_ID IS NULL OR NEW.RACK_U_OFFSET_OF_DEVICE_TOP IS NULL
				OR NEW.RACK_SIDE IS NULL THEN
			RAISE EXCEPTION 'LOCATION.RACK_* Values must be set if one is set.';
		END IF;
		IF NEW.DEVICE_TYPE_MODULE_NAME IS NOT NULL THEN
			RAISE EXCEPTION 'LOCATION.RACK_* must not be set at the same time as DEVICE_MODULE_NAME';
		END IF;
	ELSE
		IF NEW.DEVICE_TYPE_MODULE_NAME IS NULL THEN
			RAISE EXCEPTION 'All of LOCATION.RACK_* or DEVICE_MODULE_NAME must be set.';
		ELSE
			SELECT	COUNT(*)
			  INTO	_tally
			  FROM	jazzhands.device_type_module
			 WHERE	(NEW.device_type_id, NEW.device_type_module_name) 
			 		IN (device_type_id, device_type_module_name) ;

			IF _tally == 0 THEN
				RAISE EXCEPTION '(device_type_id, device_type_module_name) must exist in device_type_module.';
			END IF;
		END IF;
	END IF;
	
	RETURN NEW;
END;
$function$
;


-- TRIGGERS
CREATE TRIGGER trigger_location_complex_sanity
        BEFORE INSERT OR UPDATE
        ON location
        FOR EACH ROW
        EXECUTE PROCEDURE location_complex_sanity();

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'location');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'location');
ALTER SEQUENCE location_location_id_seq
	 OWNED BY location.location_id;
DROP TABLE IF EXISTS location_v56;
DROP TABLE IF EXISTS audit.location_v56;
-- DONE DEALING WITH TABLE location [661153]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE ticketing_system
CREATE TABLE ticketing_system
(
	ticketing_system_id	integer NOT NULL,
	ticketing_system_name	varchar(50) NOT NULL,
	ticketing_system_url	varchar(255)  NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'ticketing_system', true);
create sequence ticketing_system_ticketing_system_id_seq;
ALTER TABLE ticketing_system
	ALTER ticketing_system_id
	SET DEFAULT nextval('ticketing_system_ticketing_system_id_seq'::regclass);

ALTER SEQUENCE ticketing_system_ticketing_system_id_seq OWNED BY ticketing_system.ticketing_system_id;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE ticketing_system ADD CONSTRAINT pk_ticketing_system_id PRIMARY KEY (ticketing_system_id);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
--ALTER TABLE device_ticket
--	ADD CONSTRAINT fk_dev_tkt_tkt_system
--	FOREIGN KEY (ticketing_system_id) 
--	REFERENCES ticketing_system(ticketing_system_id);

-- FOREIGN KEYS TO
-- device_power_interface device_type

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'ticketing_system');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'ticketing_system');
-- DONE DEALING WITH TABLE ticketing_system [661796]
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH TABLE physical_port [670749]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'physical_port', 'physical_port');

-- FOREIGN KEYS FROM
ALTER TABLE layer1_connection DROP CONSTRAINT IF EXISTS fk_layer1_cnct_phys_port1;
ALTER TABLE physical_connection DROP CONSTRAINT IF EXISTS fk_patch_panel_port1;
ALTER TABLE layer2_encapsulation DROP CONSTRAINT IF EXISTS fk_l2encap_physport_id;
ALTER TABLE physical_connection DROP CONSTRAINT IF EXISTS fk_patch_panel_port2;
ALTER TABLE layer1_connection DROP CONSTRAINT IF EXISTS fk_layer1_cnct_phys_port2;
ALTER TABLE network_interface DROP CONSTRAINT IF EXISTS fk_network_int_phys_port_devid;

-- FOREIGN KEYS TO
ALTER TABLE physical_port DROP CONSTRAINT IF EXISTS fk_physical_fk_physic_val_port;
ALTER TABLE physical_port DROP CONSTRAINT IF EXISTS fk_phys_port_val_port_speed;
ALTER TABLE physical_port DROP CONSTRAINT IF EXISTS fk_phys_port_ref_vportpurp;
ALTER TABLE physical_port DROP CONSTRAINT IF EXISTS fk_phys_port_val_protocol;
ALTER TABLE physical_port DROP CONSTRAINT IF EXISTS fk_phys_port_port_medium;
ALTER TABLE physical_port DROP CONSTRAINT IF EXISTS fk_phys_port_dev_id;
ALTER TABLE physical_port DROP CONSTRAINT IF EXISTS pk_physical_port;
ALTER TABLE physical_port DROP CONSTRAINT IF EXISTS ak_physical_port_devnamtype;
ALTER TABLE physical_port DROP CONSTRAINT IF EXISTS iak_pport_dvid_pportid;
-- INDEXES
DROP INDEX IF EXISTS xif6physical_port;
DROP INDEX IF EXISTS xif5physical_port;
DROP INDEX IF EXISTS xif4physical_port;
DROP INDEX IF EXISTS idx_physport_porttype;
DROP INDEX IF EXISTS idx_physport_device_id;
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER trigger_audit_physical_port ON physical_port;
DROP TRIGGER trig_userlog_physical_port ON physical_port;


ALTER TABLE physical_port RENAME TO physical_port_v56;
ALTER TABLE audit.physical_port RENAME TO physical_port_v56;

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
	tcp_port	integer  NULL,
	is_hardwired	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'physical_port', false);
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
	tcp_port,
	is_hardwired,		-- new column (is_hardwired)
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
	tcp_port,
	'Y',		-- new column (is_hardwired)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM physical_port_v56;

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
	tcp_port,
	is_hardwired,		-- new column (is_hardwired)
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
	tcp_port,
	'Y',		-- new column (is_hardwired)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.physical_port_v56;

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
CREATE INDEX idx_physport_device_id ON physical_port USING btree (device_id);
CREATE INDEX idx_physport_porttype ON physical_port USING btree (port_type);
CREATE INDEX xif4physical_port ON physical_port USING btree (port_protocol);
CREATE INDEX xif5physical_port ON physical_port USING btree (port_medium, port_plug_style);
CREATE INDEX xif6physical_port ON physical_port USING btree (port_speed);

-- CHECK CONSTRAINTS
ALTER TABLE physical_port ADD CONSTRAINT check_yes_no_1847015416
	CHECK (is_hardwired = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
ALTER TABLE layer1_connection
	ADD CONSTRAINT fk_layer1_cnct_phys_port1
	FOREIGN KEY (physical_port1_id) REFERENCES physical_port(physical_port_id);
ALTER TABLE physical_connection
	ADD CONSTRAINT fk_patch_panel_port1
	FOREIGN KEY (physical_port1_id) REFERENCES physical_port(physical_port_id);
ALTER TABLE physical_connection
	ADD CONSTRAINT fk_patch_panel_port2
	FOREIGN KEY (physical_port2_id) REFERENCES physical_port(physical_port_id);
ALTER TABLE layer2_encapsulation
	ADD CONSTRAINT fk_l2encap_physport_id
	FOREIGN KEY (physical_port_id) REFERENCES physical_port(physical_port_id);
ALTER TABLE network_interface
	ADD CONSTRAINT fk_network_int_phys_port_devid
	FOREIGN KEY (physical_port_id, device_id) REFERENCES physical_port(physical_port_id, device_id);
ALTER TABLE layer1_connection
	ADD CONSTRAINT fk_layer1_cnct_phys_port2
	FOREIGN KEY (physical_port2_id) REFERENCES physical_port(physical_port_id);

-- FOREIGN KEYS TO
ALTER TABLE physical_port
	ADD CONSTRAINT fk_phys_port_port_medium
	FOREIGN KEY (port_medium, port_plug_style) REFERENCES val_port_medium(port_medium, port_plug_style);
ALTER TABLE physical_port
	ADD CONSTRAINT fk_phys_port_val_protocol
	FOREIGN KEY (port_protocol) REFERENCES val_port_protocol(port_protocol);
ALTER TABLE physical_port
	ADD CONSTRAINT fk_phys_port_ref_vportpurp
	FOREIGN KEY (port_purpose) REFERENCES val_port_purpose(port_purpose);
ALTER TABLE physical_port
	ADD CONSTRAINT fk_phys_port_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE physical_port
	ADD CONSTRAINT fk_phys_port_val_port_speed
	FOREIGN KEY (port_speed) REFERENCES val_port_speed(port_speed);
ALTER TABLE physical_port
	ADD CONSTRAINT fk_physical_fk_physic_val_port
	FOREIGN KEY (port_type) REFERENCES val_port_type(port_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'physical_port');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'physical_port');
ALTER SEQUENCE physical_port_physical_port_id_seq
	 OWNED BY physical_port.physical_port_id;
DROP TABLE IF EXISTS physical_port_v56;
DROP TABLE IF EXISTS audit.physical_port_v56;
-- DONE DEALING WITH TABLE physical_port [661510]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE device_ticket [670156]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_ticket', 'device_ticket');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE device_ticket DROP CONSTRAINT IF EXISTS fk_dev_tkt_dev_id;
ALTER TABLE device_ticket DROP CONSTRAINT IF EXISTS pk_device_ticket;
-- INDEXES
DROP INDEX IF EXISTS xifdev_tkt_dev_id;
-- CHECK CONSTRAINTS, etc
ALTER TABLE device_ticket DROP CONSTRAINT IF EXISTS ckc_device_ticket_is_phys;
-- TRIGGERS, etc
DROP TRIGGER trigger_audit_device_ticket ON device_ticket;
DROP TRIGGER trig_userlog_device_ticket ON device_ticket;


ALTER TABLE device_ticket RENAME TO device_ticket_v56;
ALTER TABLE audit.device_ticket RENAME TO device_ticket_v56;

CREATE TABLE device_ticket
(
	device_id	integer NOT NULL,
	ticketing_system_id	integer NOT NULL,
	ticket_number	varchar(30) NOT NULL,
	device_ticket_notes	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device_ticket', false);
INSERT INTO device_ticket (
	device_id,
	ticketing_system_id,		-- new column (ticketing_system_id)
	ticket_number,
	device_ticket_notes,		-- new column (device_ticket_notes)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	device_id,
	NULL,		-- new column (ticketing_system_id)
	ticket_number,
	NULL,		-- new column (device_ticket_notes)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM device_ticket_v56;

INSERT INTO audit.device_ticket (
	device_id,
	ticketing_system_id,		-- new column (ticketing_system_id)
	ticket_number,
	device_ticket_notes,		-- new column (device_ticket_notes)
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
	NULL,		-- new column (ticketing_system_id)
	ticket_number,
	NULL,		-- new column (device_ticket_notes)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.device_ticket_v56;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device_ticket ADD CONSTRAINT pk_device_ticket PRIMARY KEY (device_id, ticketing_system_id, ticket_number);

-- Table/Column Comments
COMMENT ON TABLE device_ticket IS 'associates devices and trouble tickets together (external to jazzhands)';
COMMENT ON COLUMN device_ticket.ticket_number IS 'trouble ticketing system id';
COMMENT ON COLUMN device_ticket.device_ticket_notes IS 'free form notes about the ticket/device association';
-- INDEXES
CREATE INDEX xifdev_tkt_tkt_system ON device_ticket USING btree (ticketing_system_id);
CREATE INDEX xifdev_tkt_dev_id ON device_ticket USING btree (device_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE device_ticket
	ADD CONSTRAINT fk_dev_tkt_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE device_ticket
	ADD CONSTRAINT fk_dev_tkt_tkt_system
	FOREIGN KEY (ticketing_system_id) REFERENCES ticketing_system(ticketing_system_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device_ticket');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device_ticket');
DROP TABLE IF EXISTS device_ticket_v56;
DROP TABLE IF EXISTS audit.device_ticket_v56;
-- DONE DEALING WITH TABLE device_ticket [660891]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH proc person_manip.add_user -> add_user 


-- RECREATE FUNCTION
-- consider NEW oid 666975
CREATE OR REPLACE FUNCTION person_manip.add_user(company_id integer, person_company_relation character varying, login character varying DEFAULT NULL::character varying, first_name character varying DEFAULT NULL::character varying, middle_name character varying DEFAULT NULL::character varying, last_name character varying DEFAULT NULL::character varying, name_suffix character varying DEFAULT NULL::character varying, gender character varying DEFAULT NULL::character varying, preferred_last_name character varying DEFAULT NULL::character varying, preferred_first_name character varying DEFAULT NULL::character varying, birth_date date DEFAULT NULL::date, external_hr_id character varying DEFAULT NULL::character varying, person_company_status character varying DEFAULT 'enabled'::character varying, is_manager character varying DEFAULT 'N'::character varying, is_exempt character varying DEFAULT 'Y'::character varying, is_full_time character varying DEFAULT 'Y'::character varying, employee_id integer DEFAULT NULL::integer, hire_date date DEFAULT NULL::date, termination_date date DEFAULT NULL::date, job_title character varying DEFAULT NULL::character varying, department_name character varying DEFAULT NULL::character varying, description character varying DEFAULT NULL::character varying, unix_uid character varying DEFAULT NULL::character varying, INOUT person_id integer DEFAULT NULL::integer, OUT dept_account_collection_id integer, OUT account_id integer)
 RETURNS record
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_account_realm_id INTEGER;
	_account_type VARCHAR;
	_uid INTEGER;
	_uxaccountid INTEGER;
	_companyid INTEGER;
	_personid INTEGER;
	_accountid INTEGER;
BEGIN
	IF company_id is NULL THEN
		RAISE EXCEPTION 'Must specify company id';
	END IF;
	_companyid := company_id;

	SELECT arc.account_realm_id 
	  INTO _account_realm_id 
	  FROM account_realm_company arc
	 WHERE arc.company_id = _companyid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Cannot find account_realm_id with company id %', company_id;
	END IF;

	IF login is NULL THEN
		IF first_name IS NULL or last_name IS NULL THEN 
			RAISE EXCEPTION 'Must specify login name or first name+last name';
		ELSE 
			login := person_manip.pick_login(
				in_account_realm_id	:= _account_realm_id,
				in_first_name := coalesce(preferred_first_name, first_name),
				in_middle_name := middle_name,
				in_last_name := coalesce(preferred_last_name, last_name)
			);
		END IF;
	END IF;

	IF person_company_relation = 'pseudouser' THEN
		person_id := 0;
		_account_type := 'pseudouser';
	ELSE
		_account_type := 'person';
		IF person_id IS NULL THEN
			INSERT INTO person (first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
				VALUES (first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
			RETURNING person.person_id into _personid;
			person_id = _personid;
		ELSE
			INSERT INTO person (person_id, first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
				VALUES (person_id, first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date);
		END IF;
		INSERT INTO person_company
			(person_id,company_id,external_hr_id,person_company_status,is_management, is_exempt, is_full_time, employee_id,hire_date,termination_date,person_company_relation, position_title)
			VALUES
			(person_id, company_id, external_hr_id, person_company_status, is_manager, is_exempt, is_full_time, employee_id, hire_date, termination_date, person_company_relation, job_title);
		INSERT INTO person_account_realm_company ( person_id, company_id, account_realm_id) VALUES ( person_id, company_id, _account_realm_id);
	END IF;

	INSERT INTO account ( login, person_id, company_id, account_realm_id, account_status, description, account_role, account_type)
		VALUES (login, person_id, company_id, _account_realm_id, person_company_status, description, 'primary', _account_type)
	RETURNING account.account_id INTO account_id;

	IF department_name IS NOT NULL THEN
		dept_account_collection_id = person_manip.get_account_collection_id(department_name, 'department');
		INSERT INTO account_collection_account (account_collection_id, account_id) VALUES ( dept_account_collection_id, account_id);
	END IF;

	IF unix_uid IS NOT NULL THEN
		_accountid = account_id;
		SELECT	aui.account_id
		  INTO	_uxaccountid
		  FROM	account_unix_info aui
		 WHERE	aui.account_id = _accountid;

		--
		-- This is creatd by trigger for non-pseudousers, which will
		-- eventually change, so this is here once it goes away.
		--
		IF _uxaccountid IS NULL THEN
			IF unix_uid = 'auto' THEN
				_uid :=  person_manip.get_unix_uid(_account_type);
			ELSE
				_uid := unix_uid::int;
			END IF;

			PERFORM person_manip.setup_unix_account(
				in_account_id := account_id,
				in_account_type := _account_type,
				in_uid := _uid
			);
		END IF;
	END IF;
END;
$function$
;

-- DONE WITH proc person_manip.add_user -> add_user 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc person_manip.get_unix_uid -> get_unix_uid 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('person_manip', 'get_unix_uid', 'get_unix_uid');

-- DROP OLD FUNCTION
-- consider old oid 540953
DROP FUNCTION IF EXISTS person_manip.get_unix_uid(account_type character varying);

-- RECREATE FUNCTION
-- consider NEW oid 666980
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
                        p.person_id = 0 AND unix_uid >5000;
		new_id = new_id - 1;
        END IF;
        RETURN new_id;
END;
$function$
;
-- consider NEW oid 666981
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
-- DEALING WITH proc person_manip.add_person -> add_person 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('person_manip', 'add_person', 'add_person');

-- DROP OLD FUNCTION
-- consider old oid 540951
DROP FUNCTION IF EXISTS person_manip.add_person(__person_id integer, first_name character varying, middle_name character varying, last_name character varying, name_suffix character varying, gender character varying, preferred_last_name character varying, preferred_first_name character varying, birth_date date, _company_id integer, external_hr_id character varying, person_company_status character varying, is_manager character varying, is_exempt character varying, is_full_time character varying, employee_id integer, hire_date date, termination_date date, person_company_relation character varying, job_title character varying, department character varying, login character varying, OUT _person_id integer, OUT _account_collection_id integer, OUT _account_id integer);

-- RECREATE FUNCTION
-- consider NEW oid 666977
CREATE OR REPLACE FUNCTION person_manip.add_person(__person_id integer, first_name character varying, middle_name character varying, last_name character varying, name_suffix character varying, gender character varying, preferred_last_name character varying, preferred_first_name character varying, birth_date date, _company_id integer, external_hr_id character varying, person_company_status character varying, is_manager character varying, is_exempt character varying, is_full_time character varying, employee_id integer, hire_date date, termination_date date, person_company_relation character varying, job_title character varying, department character varying, login character varying, OUT _person_id integer, OUT _account_collection_id integer, OUT _account_id integer)
 RETURNS record
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_account_realm_id INTEGER;
BEGIN
	SELECT	
		xxx.person_id,
		xxx.dept_account_collection_id,
		xxx.account_id
	INTO
		_person_id,
		_account_collection_id,
		_account_id
	FROM	person_manip.add_user (
			person_id := __person_id,
			first_name := first_name,
			middle_name := middle_name,
			last_name := last_name,
			name_suffix := name_suffix,
			gender := gender,
			preferred_last_name := preferred_last_name,
			preferred_first_name := preferred_first_name,
			birth_date := birth_date,
			company_id := _company_id,
			external_hr_id := external_hr_id,
			person_company_status := person_company_status,
			is_manager := is_manager,
			is_exempt := is_exempt,
			is_full_time := is_full_time,
			employee_id := employee_id,
			hire_date := hire_date,
			termination_date := termination_date,
			person_company_relation := person_company_relation,
			job_title := job_title,
			department_name := department,
			login := login
		) xxx; 
END;
$function$
;

-- DONE WITH proc person_manip.add_person -> add_person 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc jazzhands.dns_record_update_nontime -> dns_record_update_nontime 


-- RECREATE FUNCTION
-- consider NEW oid 667082
CREATE OR REPLACE FUNCTION jazzhands.dns_record_update_nontime()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
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

	IF TG_OP = 'DELETE' THEN
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
			_mknew := true;
			_mkdom := true;
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
			  FROM	jazzhands.netblock 
			 WHERE	netblock_id  = OLD.netblock_id;
		ELSE
			_ipaddr := NULL;
		END IF;
		insert into jazzhands.DNS_RECORD_CHANGE
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
			  FROM	jazzhands.netblock 
			 WHERE	netblock_id  = NEW.netblock_id;
		ELSE
			_ipaddr := NULL;
		END IF;
		insert into jazzhands.DNS_RECORD_CHANGE
			(dns_domain_id, ip_address) VALUES (_dnsdomainid, _ipaddr);
	END IF;
	IF TG_OP = 'DELETE' THEN
		return OLD;
	ELSE
		return NEW;
	END IF;
END;
$function$
;

CREATE TRIGGER trigger_dns_record_update_nontime 
	BEFORE INSERT OR DELETE OR UPDATE OF netblock_id, dns_domain_id 
	ON dns_record 
	FOR EACH ROW 
	EXECUTE PROCEDURE dns_record_update_nontime();


-- DONE WITH proc jazzhands.dns_record_update_nontime -> dns_record_update_nontime 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc dns_rec_type_validation -> dns_rec_type_validation 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_rec_type_validation', 'dns_rec_type_validation');

-- DROP OLD FUNCTION
-- consider old oid 541042
-- DROP FUNCTION IF EXISTS dns_rec_type_validation();

-- RECREATE FUNCTION
-- consider NEW oid 667086
CREATE OR REPLACE FUNCTION jazzhands.dns_a_rec_validation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF NEW.dns_type in ('A', 'AAAA') AND NEW.netblock_id IS NULL THEN
		RAISE EXCEPTION 'Attempt to set % record without a Netblock',
			NEW.dns_type;
	END IF;

	IF NEW.netblock_Id is not NULL and 
			( NEW.dns_value IS NOT NULL OR NEW.dns_value_record_id IS NOT NULL ) THEN
		RAISE EXCEPTION 'Both dns_value and netblock_id may not be set';
	END IF;

	IF NEW.dns_value IS NOT NULL AND NEW.dns_value_record_id IS NOT NULL THEN
		RAISE EXCEPTION 'Both dns_value and dns_value_record_id may not be set';
	END IF;
	RETURN NEW;
END;
$function$
;

DROP TRIGGER IF EXISTS trigger_dns_a_rec_validation ON dns_record;
CREATE TRIGGER trigger_dns_a_rec_validation
        BEFORE INSERT OR UPDATE
        ON dns_record
        FOR EACH ROW
        EXECUTE PROCEDURE dns_a_rec_validation();


DROP TRIGGER IF EXISTS trigger_dns_rec_type_validation ON dns_record;
DROP FUNCTION IF EXISTS dns_rec_type_validation();
-- DONE WITH proc dns_rec_type_validation -> dns_rec_type_validation 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc dns_rec_prevent_dups -> dns_rec_prevent_dups 


-- RECREATE FUNCTION
-- consider NEW oid 667089
CREATE OR REPLACE FUNCTION jazzhands.dns_rec_prevent_dups()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	IF NEW.DNS_TYPE = 'A' OR NEW.DNS_TYPE = 'AAAA' THEN
		IF NEW.SHOULD_GENERATE_PTR = 'Y' THEN
			SELECT	count(*)
			 INTO	_tally
			 FROM	jazzhands.dns_record
			WHERE dns_class = 'IN' 
			AND dns_type = 'A' 
			AND should_generate_ptr = 'Y'
			AND is_enabled = 'Y'
			AND netblock_id = NEW.NETBLOCK_ID
			AND dns_record_id != NEW.DNS_RECORD_ID;
	
			IF _tally != 0 THEN
				RAISE EXCEPTION 'May not have more than one SHOULD_GENERATE_PTR record on the same netblock';
			END IF;
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

CREATE TRIGGER trigger_dns_rec_prevent_dups
        BEFORE INSERT OR UPDATE
        ON dns_record
        FOR EACH ROW
        EXECUTE PROCEDURE dns_rec_prevent_dups();


-- DONE WITH proc dns_rec_prevent_dups -> dns_rec_prevent_dups 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc device_update_location_fix -> device_update_location_fix 


-- RECREATE FUNCTION
-- consider NEW oid 667070
CREATE OR REPLACE FUNCTION jazzhands.device_update_location_fix()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF OLD.DEVICE_TYPE_ID != NEW.DEVICE_TYPE_ID THEN
		IF NEW.location_id IS NOT NULL THEN
			UPDATE jazzhands.location SET devivce_type_id = NEW.device_type_id
			WHERE location_id = NEW.location_id;
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

DROP TRIGGER IF EXISTS trigger_device_update_location_fix ON device;
CREATE TRIGGER trigger_device_update_location_fix
        BEFORE UPDATE OF DEVICE_TYPE_ID
        ON device FOR EACH ROW EXECUTE PROCEDURE device_update_location_fix();


-- DONE WITH proc device_update_location_fix -> device_update_location_fix 
--------------------------------------------------------------------



--------------------------------------------------------------------

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_best_parent_id', 'find_best_parent_id');

-- adjust the regrant for this becuase the functoin definition changes.
update __regrants set regrant = replace(regrant, 'in_is_single_address character)', 'in_is_single_address character, in_netblock_id integer)') where object = 'find_best_parent_id';

-- DROP OLD FUNCTION
-- consider old oid 540965
DROP FUNCTION IF EXISTS netblock_utils.find_best_parent_id(in_netblock_id integer);
-- consider old oid 540964
DROP FUNCTION IF EXISTS netblock_utils.find_best_parent_id(in_ipaddress inet, in_netmask_bits integer, in_netblock_type character varying, in_ip_universe_id integer, in_is_single_address character);

-- RECREATE FUNCTION
-- consider NEW oid 666993
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
		nbrec.netmask_bits,
		nbrec.netblock_type,
		nbrec.ip_universe_id,
		nbrec.is_single_address,
		in_netblock_id
	);
END;
$function$
;
-- consider NEW oid 666992
CREATE OR REPLACE FUNCTION netblock_utils.find_best_parent_id(in_ipaddress inet, in_netmask_bits integer DEFAULT NULL::integer, in_netblock_type character varying DEFAULT 'default'::character varying, in_ip_universe_id integer DEFAULT 0, in_is_single_address character DEFAULT 'N'::bpchar, in_netblock_id integer DEFAULT NULL::integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
	par_nbid	jazzhands.netblock.netblock_id%type;
BEGIN
	IF (in_netmask_bits IS NOT NULL) THEN
		in_IpAddress := set_masklen(in_IpAddress, in_Netmask_Bits);
	END IF;

	select  Netblock_Id
	  into	par_nbid
	  from  ( select Netblock_Id, Ip_Address, Netmask_Bits
		    from jazzhands.netblock
		   where
		   	in_IpAddress <<= ip_address
		    and is_single_address = 'N'
			and netblock_type = in_netblock_type
			and ip_universe_id = in_ip_universe_id
		    and (
				(in_is_single_address = 'N' AND netmask_bits < in_Netmask_Bits)
				OR
				(in_is_single_address = 'Y' AND 
					(in_Netmask_Bits IS NULL OR netmask_bits = in_Netmask_Bits))
			)
			and (in_netblock_id IS NULL OR
				netblock_id != in_netblock_id)
		order by netmask_bits desc
	) subq LIMIT 1;

	return par_nbid;
END;
$function$
;

-- DONE WITH proc netblock_utils.find_best_parent_id -> find_best_parent_id 
--------------------------------------------------------------------


-- Copyright (c) 2005-2010, Vonage Holdings Corp.
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

/*
 * Copyright (c) 2013-2014 Todd Kover
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
 * $Id$
 */

drop schema if exists device_utils cascade;
create schema device_utils authorization jazzhands;


-------------------------------------------------------------------
-- returns the Id tag for CM
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_utils.id_tag()
RETURNS VARCHAR AS $$
BEGIN
	RETURN('<-- $Id$ -->');
END;
$$ LANGUAGE plpgsql;
--end of procedure id_tag
-------------------------------------------------------------------

CREATE OR REPLACE FUNCTION device_utils.retire_device_ancillary (
	in_Device_id device.device_id%type
) RETURNS VOID AS $$
DECLARE
	v_loc_id	location.location_id%type;
BEGIN
	delete from device_collection_device where device_id = in_Device_id;
	delete from snmp_commstr where device_id = in_Device_id;

	select	location_id
	  into	v_loc_id
	  from	device
	 where	device_id = in_Device_id;

	IF v_loc_id is not NULL  THEN
		update device set location_Id = NULL where device_id = in_device_id;
		delete from location where location_id = v_loc_id;
	END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
--end of retire_device_ancillary id_tag
-------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH TABLE device_power_interface [782756]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_power_interface', 'device_power_interface');

-- FOREIGN KEYS FROM
ALTER TABLE device_power_connection DROP CONSTRAINT IF EXISTS fk_dev_ps_dev_power_conn_srv;
ALTER TABLE device_power_connection DROP CONSTRAINT IF EXISTS fk_dev_ps_dev_power_conn_rpc;

-- FOREIGN KEYS TO
ALTER TABLE device_power_interface DROP CONSTRAINT IF EXISTS fk_device_device_power_supp;
ALTER TABLE device_power_interface DROP CONSTRAINT IF EXISTS pk_device_power_interface;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER trig_userlog_device_power_interface ON device_power_interface;
DROP TRIGGER trigger_audit_device_power_interface ON device_power_interface;


ALTER TABLE device_power_interface RENAME TO device_power_interface_v56;
ALTER TABLE audit.device_power_interface RENAME TO device_power_interface_v56;

CREATE TABLE device_power_interface
(
	device_id	integer NOT NULL,
	power_interface_port	varchar(20) NOT NULL,
	provides_power	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device_power_interface', false);
INSERT INTO device_power_interface (
	device_id,
	power_interface_port,
	provides_power,		-- new column (provides_power)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	device_id,
	power_interface_port,
	'N',		-- new column (provides_power)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM device_power_interface_v56;

INSERT INTO audit.device_power_interface (
	device_id,
	power_interface_port,
	provides_power,		-- new column (provides_power)
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
	power_interface_port,
	'N',		-- new column (provides_power)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.device_power_interface_v56;

ALTER TABLE device_power_interface
	ALTER provides_power
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device_power_interface ADD CONSTRAINT pk_device_power_interface PRIMARY KEY (device_id, power_interface_port);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE device_power_interface ADD CONSTRAINT check_yes_no_2067088750
	CHECK (provides_power = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
ALTER TABLE device_power_connection
	ADD CONSTRAINT fk_dev_ps_dev_power_conn_rpc
	FOREIGN KEY (rpc_device_id, rpc_power_interface_port) REFERENCES device_power_interface(device_id, power_interface_port);
ALTER TABLE device_power_connection
	ADD CONSTRAINT fk_dev_ps_dev_power_conn_srv
	FOREIGN KEY (device_id, power_interface_port) REFERENCES device_power_interface(device_id, power_interface_port);

-- FOREIGN KEYS TO
ALTER TABLE device_power_interface
	ADD CONSTRAINT fk_device_device_power_supp
	FOREIGN KEY (device_id) REFERENCES device(device_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device_power_interface');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device_power_interface');
DROP TABLE IF EXISTS device_power_interface_v56;
DROP TABLE IF EXISTS audit.device_power_interface_v56;
-- DONE DEALING WITH TABLE device_power_interface [749717]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE device_type [782786]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_type', 'device_type');

-- FOREIGN KEYS FROM
ALTER TABLE location DROP CONSTRAINT IF EXISTS fk_location_device_type_id;
ALTER TABLE device_type_phys_port_templt DROP CONSTRAINT IF EXISTS fk_devtype_ref_devtphysprttmpl;
ALTER TABLE device_type_power_port_templt DROP CONSTRAINT IF EXISTS fk_dev_type_dev_pwr_prt_tmpl;
ALTER TABLE device_type_module DROP CONSTRAINT IF EXISTS fk_devt_mod_dev_type_id;
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_dev_devtp_id;

-- FOREIGN KEYS TO
ALTER TABLE device_type DROP CONSTRAINT IF EXISTS fk_device_t_fk_device_val_proc;
ALTER TABLE device_type DROP CONSTRAINT IF EXISTS fk_devtyp_company;
ALTER TABLE device_type DROP CONSTRAINT IF EXISTS pk_device_type;
-- INDEXES
DROP INDEX IF EXISTS xif4device_type;
-- CHECK CONSTRAINTS, etc
ALTER TABLE device_type DROP CONSTRAINT IF EXISTS ckc_has_802_11_interf_device_t;
ALTER TABLE device_type DROP CONSTRAINT IF EXISTS ckc_snmp_capable_device_t;
ALTER TABLE device_type DROP CONSTRAINT IF EXISTS ckc_has_802_3_interfa_device_t;
ALTER TABLE device_type DROP CONSTRAINT IF EXISTS ckc_devtyp_ischs;
-- TRIGGERS, etc
DROP TRIGGER trigger_audit_device_type ON device_type;
DROP TRIGGER trig_userlog_device_type ON device_type;


ALTER TABLE device_type RENAME TO device_type_v56;
ALTER TABLE audit.device_type RENAME TO device_type_v56;

CREATE TABLE device_type
(
	device_type_id	integer NOT NULL,
	company_id	integer  NULL,
	model	varchar(255) NOT NULL,
	device_type_depth_in_cm	character(18)  NULL,
	processor_architecture	varchar(50)  NULL,
	config_fetch_type	varchar(50)  NULL,
	rack_units	integer NOT NULL,
	description	varchar(4000)  NULL,
	has_802_3_interface	character(1) NOT NULL,
	has_802_11_interface	character(1) NOT NULL,
	snmp_capable	character(1) NOT NULL,
	is_chassis	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device_type', false);
INSERT INTO device_type (
	device_type_id,
	company_id,
	model,
	device_type_depth_in_cm,		-- new column (device_type_depth_in_cm)
	processor_architecture,
	config_fetch_type,
	rack_units,
	description,
	has_802_3_interface,
	has_802_11_interface,
	snmp_capable,
	is_chassis,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	device_type_id,
	company_id,
	model,
	NULL,		-- new column (device_type_depth_in_cm)
	processor_architecture,
	config_fetch_type,
	rack_units,
	description,
	has_802_3_interface,
	has_802_11_interface,
	snmp_capable,
	is_chassis,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM device_type_v56;

INSERT INTO audit.device_type (
	device_type_id,
	company_id,
	model,
	device_type_depth_in_cm,		-- new column (device_type_depth_in_cm)
	processor_architecture,
	config_fetch_type,
	rack_units,
	description,
	has_802_3_interface,
	has_802_11_interface,
	snmp_capable,
	is_chassis,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	device_type_id,
	company_id,
	model,
	NULL,		-- new column (device_type_depth_in_cm)
	processor_architecture,
	config_fetch_type,
	rack_units,
	description,
	has_802_3_interface,
	has_802_11_interface,
	snmp_capable,
	is_chassis,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.device_type_v56;

ALTER TABLE device_type
	ALTER device_type_id
	SET DEFAULT nextval('device_type_device_type_id_seq'::regclass);
ALTER TABLE device_type
	ALTER is_chassis
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device_type ADD CONSTRAINT pk_device_type PRIMARY KEY (device_type_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif4device_type ON device_type USING btree (company_id);

-- CHECK CONSTRAINTS
ALTER TABLE device_type ADD CONSTRAINT ckc_devtyp_ischs
	CHECK (is_chassis = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE device_type ADD CONSTRAINT ckc_has_802_3_interfa_device_t
	CHECK (has_802_3_interface = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE device_type ADD CONSTRAINT ckc_snmp_capable_device_t
	CHECK (snmp_capable = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE device_type ADD CONSTRAINT ckc_has_802_11_interf_device_t
	CHECK (has_802_11_interface = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
ALTER TABLE device_type_module
	ADD CONSTRAINT fk_devt_mod_dev_type_id
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);
ALTER TABLE device
	ADD CONSTRAINT fk_dev_devtp_id
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);
ALTER TABLE device_type_phys_port_templt
	ADD CONSTRAINT fk_devtype_ref_devtphysprttmpl
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);
ALTER TABLE device_type_power_port_templt
	ADD CONSTRAINT fk_dev_type_dev_pwr_prt_tmpl
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);
ALTER TABLE location
	ADD CONSTRAINT fk_location_device_type_id
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);

-- FOREIGN KEYS TO
ALTER TABLE device_type
	ADD CONSTRAINT fk_device_t_fk_device_val_proc
	FOREIGN KEY (processor_architecture) REFERENCES val_processor_architecture(processor_architecture);
ALTER TABLE device_type
	ADD CONSTRAINT fk_devtyp_company
	FOREIGN KEY (company_id) REFERENCES company(company_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device_type');
ALTER SEQUENCE device_type_device_type_id_seq
	 OWNED BY device_type.device_type_id;
DROP TABLE IF EXISTS device_type_v56;
DROP TABLE IF EXISTS audit.device_type_v56;
-- DONE DEALING WITH TABLE device_type [749749]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE device_type_phys_port_templt [851147]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_type_phys_port_templt', 'device_type_phys_port_templt');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE device_type_phys_port_templt DROP CONSTRAINT IF EXISTS fk_devtype_ref_devtphysprttmpl;
ALTER TABLE device_type_phys_port_templt DROP CONSTRAINT IF EXISTS fk_dt_phsport_tmp_val_prt_spd;
ALTER TABLE device_type_phys_port_templt DROP CONSTRAINT IF EXISTS fk_devtphyprttmpl_ref_vprtpurp;
ALTER TABLE device_type_phys_port_templt DROP CONSTRAINT IF EXISTS fk_dt_phsport_tmp_v_protocol;
ALTER TABLE device_type_phys_port_templt DROP CONSTRAINT IF EXISTS fk_dt_phsport_tmpl_v_port_medm;
ALTER TABLE device_type_phys_port_templt DROP CONSTRAINT IF EXISTS fk_dt_phs_port_templt_port_typ;
ALTER TABLE device_type_phys_port_templt DROP CONSTRAINT IF EXISTS pk_device_type_phys_port_templ;
-- INDEXES
DROP INDEX IF EXISTS xif3device_type_phys_port_temp;
DROP INDEX IF EXISTS xif6device_type_phys_port_temp;
DROP INDEX IF EXISTS xif5device_type_phys_port_temp;
DROP INDEX IF EXISTS xif4device_type_phys_port_temp;
-- CHECK CONSTRAINTS, etc
ALTER TABLE device_type_phys_port_templt DROP CONSTRAINT IF EXISTS ckc_dvtyp_physp_tmp_opt;
-- TRIGGERS, etc
DROP TRIGGER trigger_audit_device_type_phys_port_templt ON device_type_phys_port_templt;
DROP TRIGGER trig_userlog_device_type_phys_port_templt ON device_type_phys_port_templt;


ALTER TABLE device_type_phys_port_templt RENAME TO device_type_phys_port_templt_v56;
ALTER TABLE audit.device_type_phys_port_templt RENAME TO device_type_phys_port_templt_v56;

CREATE TABLE device_type_phys_port_templt
(
	port_name	varchar(50) NOT NULL,
	device_type_id	integer NOT NULL,
	port_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	port_plug_style	varchar(50)  NULL,
	port_medium	varchar(50)  NULL,
	port_protocol	varchar(50)  NULL,
	port_speed	varchar(50)  NULL,
	physical_label	varchar(50)  NULL,
	port_purpose	varchar(50)  NULL,
	tcp_port	integer  NULL,
	is_hardwired	character(1) NOT NULL,
	is_optional	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device_type_phys_port_templt', false);
INSERT INTO device_type_phys_port_templt (
	port_name,
	device_type_id,
	port_type,
	description,
	port_plug_style,
	port_medium,
	port_protocol,
	port_speed,
	physical_label,
	port_purpose,
	tcp_port,
	is_hardwired,		-- new column (is_hardwired)
	is_optional,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	port_name,
	device_type_id,
	port_type,
	description,
	port_plug_style,
	port_medium,
	port_protocol,
	port_speed,
	physical_label,
	port_purpose,
	tcp_port,
	'Y',		-- new column (is_hardwired)
	is_optional,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM device_type_phys_port_templt_v56;

INSERT INTO audit.device_type_phys_port_templt (
	port_name,
	device_type_id,
	port_type,
	description,
	port_plug_style,
	port_medium,
	port_protocol,
	port_speed,
	physical_label,
	port_purpose,
	tcp_port,
	is_hardwired,		-- new column (is_hardwired)
	is_optional,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	port_name,
	device_type_id,
	port_type,
	description,
	port_plug_style,
	port_medium,
	port_protocol,
	port_speed,
	physical_label,
	port_purpose,
	tcp_port,
	'Y',		-- new column (is_hardwired)
	is_optional,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.device_type_phys_port_templt_v56;

ALTER TABLE device_type_phys_port_templt
	ALTER is_hardwired
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE device_type_phys_port_templt
	ALTER is_optional
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device_type_phys_port_templt ADD CONSTRAINT pk_device_type_phys_port_templ PRIMARY KEY (port_name, device_type_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif5device_type_phys_port_temp ON device_type_phys_port_templt USING btree (port_medium, port_plug_style);
CREATE INDEX xif6device_type_phys_port_temp ON device_type_phys_port_templt USING btree (port_speed);
CREATE INDEX xif3device_type_phys_port_temp ON device_type_phys_port_templt USING btree (port_type);
CREATE INDEX xif4device_type_phys_port_temp ON device_type_phys_port_templt USING btree (port_protocol);

-- CHECK CONSTRAINTS
ALTER TABLE device_type_phys_port_templt ADD CONSTRAINT check_yes_no_400418313
	CHECK (is_hardwired = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE device_type_phys_port_templt ADD CONSTRAINT ckc_dvtyp_physp_tmp_opt
	CHECK (is_optional = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE device_type_phys_port_templt
	ADD CONSTRAINT fk_dt_phsport_tmp_val_prt_spd
	FOREIGN KEY (port_speed) REFERENCES val_port_speed(port_speed);
ALTER TABLE device_type_phys_port_templt
	ADD CONSTRAINT fk_devtphyprttmpl_ref_vprtpurp
	FOREIGN KEY (port_purpose) REFERENCES val_port_purpose(port_purpose);
ALTER TABLE device_type_phys_port_templt
	ADD CONSTRAINT fk_devtype_ref_devtphysprttmpl
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);
ALTER TABLE device_type_phys_port_templt
	ADD CONSTRAINT fk_dt_phs_port_templt_port_typ
	FOREIGN KEY (port_type) REFERENCES val_port_type(port_type);
ALTER TABLE device_type_phys_port_templt
	ADD CONSTRAINT fk_dt_phsport_tmp_v_protocol
	FOREIGN KEY (port_protocol) REFERENCES val_port_protocol(port_protocol);
ALTER TABLE device_type_phys_port_templt
	ADD CONSTRAINT fk_dt_phsport_tmpl_v_port_medm
	FOREIGN KEY (port_medium, port_plug_style) REFERENCES val_port_medium(port_medium, port_plug_style);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device_type_phys_port_templt');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device_type_phys_port_templt');
DROP TABLE IF EXISTS device_type_phys_port_templt_v56;
DROP TABLE IF EXISTS audit.device_type_phys_port_templt_v56;
-- DONE DEALING WITH TABLE device_type_phys_port_templt [844535]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH proc device_type_module_sanity_set -> device_type_module_sanity_set 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_type_module_sanity_set', 'device_type_module_sanity_set');

-- DROP OLD FUNCTION
-- consider old oid 689346
-- DROP FUNCTION IF EXISTS device_type_module_sanity_set();

-- RECREATE FUNCTION
-- consider NEW oid 667095
CREATE OR REPLACE FUNCTION jazzhands.device_type_module_sanity_set()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF NEW.DEVICE_TYPE_Z_OFFSET IS NOT NULL AND NEW.DEVICE_TYPE_SIDE IS NOT NULL THEN
		RAISE EXCEPTION 'Both Z Offset and Device_Type_Side may not be set';
	END IF;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc device_type_module_sanity_set -> device_type_module_sanity_set 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc manipulate_netblock_parentage_before -> manipulate_netblock_parentage_before 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'manipulate_netblock_parentage_before', 'manipulate_netblock_parentage_before');

-- DROP OLD FUNCTION
-- consider old oid 689036
-- DROP FUNCTION IF EXISTS manipulate_netblock_parentage_before();

-- RECREATE FUNCTION
-- consider NEW oid 667051
CREATE OR REPLACE FUNCTION jazzhands.manipulate_netblock_parentage_before()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$

DECLARE
	nbtype				record;
	v_netblock_type		jazzhands.val_netblock_type.netblock_type%TYPE;
BEGIN
	/*
	 * Get the parameters for the given netblock type to see if we need
	 * to do anything
	 */

	RAISE DEBUG 'Performing % on netblock %', TG_OP, NEW.netblock_id;
		
	SELECT * INTO nbtype FROM jazzhands.val_netblock_type WHERE 
		netblock_type = NEW.netblock_type;

	IF (NOT FOUND) OR nbtype.db_forced_hierarchy != 'Y' THEN
		RETURN NEW;
	END IF;

	/*
	 * Find the correct parent netblock
	 */ 

	RAISE DEBUG 'Setting forced hierarchical netblock %', NEW.netblock_id;
	NEW.parent_netblock_id := netblock_utils.find_best_parent_id(
		NEW.ip_address,
		NEW.netmask_bits,
		NEW.netblock_type,
		NEW.ip_universe_id,
		NEW.is_single_address,
		NEW.netblock_id
		);

	RAISE DEBUG 'Setting parent for netblock % (%, type %, universe %, single-address %) to %', 
		NEW.netblock_id, NEW.ip_address, NEW.netblock_type,
		NEW.ip_universe_id, NEW.is_single_address,
		NEW.parent_netblock_id;

	/*
	 * If we are an end-node, then we're done
	 */

	IF NEW.is_single_address = 'Y' THEN
		RETURN NEW;
	END IF;

	/*
	 * If we're updating and we're a container netblock, find
	 * all of the children of our new parent that should be ours and take 
	 * them.  They will already be guaranteed to be of the correct
	 * netblock_type and ip_universe_id.  We can't do this for inserts
	 * because the row doesn't exist causing foreign key problems, so
	 * that needs to be done in an after trigger.
	 */
	IF TG_OP = 'UPDATE' THEN
		RAISE DEBUG 'Setting parent for all child netblocks of parent netblock % that belong to %',
			NEW.parent_netblock_id,
			NEW.netblock_id;
		UPDATE
			jazzhands.netblock
		SET
			parent_netblock_id = NEW.netblock_id
		WHERE
			parent_netblock_id = NEW.parent_netblock_id AND
			ip_address <<= NEW.ip_address AND
			netblock_id != NEW.netblock_id;

		RAISE DEBUG 'Setting parent for all child netblocks of netblock % that no longer belong to it to %',
			NEW.parent_netblock_id,
			NEW.netblock_id;
		RAISE DEBUG 'Setting parent % to %',
			OLD.netblock_id,
			OLD.parent_netblock_id;
		UPDATE
			jazzhands.netblock
		SET
			parent_netblock_id = OLD.parent_netblock_id
		WHERE
			parent_netblock_id = NEW.netblock_id AND
			(ip_universe_id != NEW.ip_universe_id OR
			 netblock_type != NEW.netblock_type OR
			 NOT(ip_address <<= NEW.ip_address));
	END IF;

	RETURN NEW;
END;
$function$
;

-- DONE WITH proc manipulate_netblock_parentage_before -> manipulate_netblock_parentage_before 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc person_manip.pick_login -> pick_login 


-- RECREATE FUNCTION
-- consider NEW oid 666972
CREATE OR REPLACE FUNCTION person_manip.pick_login(in_account_realm_id integer, in_first_name character varying DEFAULT NULL::character varying, in_middle_name character varying DEFAULT NULL::character varying, in_last_name character varying DEFAULT NULL::character varying)
 RETURNS character varying
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_acctrealmid	integer;
	_login			varchar;
	_trylogin		varchar;
    id				account.account_id%TYPE;
BEGIN
	_acctrealmid := in_account_realm_id;
	-- Try first initial, last name
	_login = lpad(lower(in_first_name), 1) || lower(in_last_name);
	SELECT account_id into id FROM account where account_realm_id = _acctrealmid
		AND login = _login;

	IF id IS NULL THEN
		RETURN _login;
	END IF;

	-- Try first initial, middle initial, last name
	if in_middle_name IS NOT NULL THEN
		_login = lpad(lower(in_first_name), 1) || lpad(lower(in_middle_name), 1) || lower(in_last_name);
		SELECT account_id into id FROM account where account_realm_id = _acctrealmid
			AND login = _login;
		IF id IS NULL THEN
			RETURN _login;
		END IF;
	END IF;

	-- if length of first+last is <= 10 then try that.
	_login = lower(in_first_name) || lower(in_last_name);
	IF char_length(_login) < 10 THEN
		SELECT account_id into id FROM account where account_realm_id = _acctrealmid
			AND login = _login;
		IF id IS NULL THEN
			RETURN _login;
		END IF;
	END IF;

	-- ok, keep trying to add a number to first initial, last
	_login = lpad(lower(in_first_name), 1) || lower(in_last_name);
	FOR i in 1..500 LOOP
		_trylogin := _login || i;
		SELECT account_id into id FROM account where account_realm_id = _acctrealmid
			AND login = _trylogin;
		IF id IS NULL THEN
			RETURN _trylogin;
		END IF;
	END LOOP;

	-- wtf. this should never happen
	RETURN NULL;
END;
$function$
;

-- DONE WITH proc person_manip.pick_login -> pick_login 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc person_manip.setup_unix_account -> setup_unix_account 


-- RECREATE FUNCTION
-- consider NEW oid 666979
CREATE OR REPLACE FUNCTION person_manip.setup_unix_account(in_account_id integer, in_account_type character varying, in_uid integer DEFAULT NULL::integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	acid			account_collection.account_collection_id%TYPE;
	_login			account.login%TYPE;
	new_uid			account_unix_info.unix_uid%TYPE	DEFAULT NULL;
BEGIN
	SELECT login INTO _login FROM account WHERE account_id = in_account_id;

	INSERT INTO account_collection (
		account_collection_name, account_collection_type)
	values (
		_login, 'unix-group'
	) RETURNING account_collection_id INTO acid;

	insert into account_collection_account (
		account_collection_id, account_id
	) values (
		acid, in_account_id
	);

	IF in_uid is NOT NULL THEN
		new_uid := in_uid;
	ELSE
		new_uid := person_manip.get_unix_uid(in_account_type);
	END IF;

	INSERT INTO account_unix_info (
		account_id,
		unix_uid,
		unix_group_acct_collection_id,
		shell
	) values (
		in_account_id,
		new_uid,
		acid,
		'bash'
	);

	INSERT INTO unix_group (
		account_collection_id,
		unix_gid
	) values (
		acid,
		new_uid
	);
	RETURN in_account_id;
END;
$function$
;

-- DONE WITH proc person_manip.setup_unix_account -> setup_unix_account 
--------------------------------------------------------------------




--------------------------------------------------------------------
-- DEALING WITH proc automated_ac -> automated_ac 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'automated_ac', 'automated_ac');

-- DROP OLD FUNCTION
-- consider old oid 695656
-- DROP FUNCTION IF EXISTS automated_ac();

-- RECREATE FUNCTION
-- consider NEW oid 667097
CREATE OR REPLACE FUNCTION jazzhands.automated_ac()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	acr	VARCHAR;
	c_name VARCHAR;
	sc VARCHAR;
	ac_ids INTEGER[];
	delete_aca BOOLEAN;
	_gender VARCHAR;
	_person_company RECORD;
	acr_c_name VARCHAR;
	gender_string VARCHAR;
	_status RECORD;
BEGIN
	IF TG_OP = 'INSERT' THEN
		IF NEW.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
		PERFORM 1 FROM jazzhands.val_person_status WHERE NEW.account_status = person_status AND is_disabled = 'N';
		IF NOT FOUND THEN
			RETURN NEW;
		END IF;
	-- The triggers need not deal with account realms companies or sites being renamed, although we may want to revisit this later.
	ELSIF NEW.account_id != OLD.account_id THEN
		RAISE NOTICE 'This trigger does not handle changing account id';
		RETURN NEW;
	ELSIF NEW.account_realm_id != OLD.account_realm_id THEN
		RAISE NOTICE 'This trigger does not handle changing account_realm_id';
		RETURN NEW;
	ELSIF NEW.company_id != OLD.company_id THEN
		RAISE NOTICE 'This trigger does not handle changing company_id';
		RETURN NEW;
	END IF;
	ac_ids = '{-1,-1,-1,-1,-1,-1,-1}';
	SELECT account_realm_name INTO acr FROM jazzhands.account_realm WHERE account_realm_id = NEW.account_realm_id;
	ac_ids[0] = acct_coll_manip.get_automated_account_collection_id(acr || '_' || NEW.account_type);
	SELECT company_short_name INTO c_name FROM jazzhands.company WHERE company_id = NEW.company_id AND company_short_name IS NOT NULL;
	IF NOT FOUND THEN
		RAISE NOTICE 'Company short name cannot be determined from company_id % in %', NEW.company_id, TG_NAME;
	ELSE
		acr_c_name = acr || '_' || c_name;
		ac_ids[1] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || NEW.account_type);
		SELECT
			pc.*
		INTO
			_person_company
		FROM
			jazzhands.person_company pc
		JOIN
			jazzhands.account a
		USING
			(person_id)
		WHERE
			a.person_id != 0 AND account_id = NEW.account_id;
		IF FOUND THEN
			IF _person_company.is_exempt IS NOT NULL THEN
				SELECT * INTO _status FROM acct_coll_manip.person_company_flags_to_automated_ac_name(_person_company.is_exempt, 'exempt');
				-- will remove account from old account collection
				ac_ids[2] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || _status.name);
			END IF;
			SELECT * INTO _status FROM acct_coll_manip.person_company_flags_to_automated_ac_name(_person_company.is_full_time, 'full_time');
			ac_ids[3] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || _status.name);
			SELECT * INTO _status FROM acct_coll_manip.person_company_flags_to_automated_ac_name(_person_company.is_management, 'management');
			ac_ids[4] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || _status.name);
		END IF;
		SELECT
			gender
		INTO
			_gender
		FROM
			jazzhands.person
		JOIN
			jazzhands.account a
		USING
			(person_id)
		WHERE
			account_id = NEW.account_id AND a.person_id !=0 AND gender IS NOT NULL;
		IF FOUND THEN
			gender_string = acct_coll_manip.person_gender_char_to_automated_ac_name(_gender);
			IF gender_string IS NOT NULL THEN
				ac_ids[5] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || gender_string);
			END IF;
		END IF;
	END IF;
	SELECT site_code INTO sc FROM jazzhands.person_location WHERE person_id = NEW.person_id AND site_code IS NOT NULL;
	IF FOUND THEN
		ac_ids[6] = acct_coll_manip.get_automated_account_collection_id(acr || '_' || sc);
	END IF;
	delete_aca = 't';
	IF TG_OP = 'INSERT' THEN
		delete_aca = 'f';
	ELSE
		IF NEW.account_role != 'primary' AND NEW.account_role != OLD.account_role THEN
			-- reaching here means account must be removed from all automated account collections
			PERFORM acct_coll_manip.insert_or_delete_automated_ac('t', OLD.account_id, ac_ids);
			RETURN NEW;
		END IF;
		PERFORM 1 FROM jazzhands.val_person_status WHERE NEW.account_status = person_status AND is_disabled = 'N';
		IF NOT FOUND THEN
			-- reaching here means account must be removed from all automated account collections
			PERFORM acct_coll_manip.insert_or_delete_automated_ac('t', OLD.account_id, ac_ids);
			RETURN NEW;
		END IF;
		IF NEW.account_role = 'primary' AND NEW.account_role != OLD.account_role OR
			NEW.account_status != OLD.account_status THEN
			-- reaching here means there were no automated account collection for this account
			-- and this is the first time this account goes into the automated collections even though this is not SQL insert
			-- notice that NEW.account_status here is 'enabled' or similar type
			delete_aca = 'f';
		END IF;
	END IF;
	IF NOT delete_aca THEN
		-- do all inserts
		PERFORM acct_coll_manip.insert_or_delete_automated_ac('f', NEW.account_id, ac_ids);
	END IF;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc automated_ac -> automated_ac 
--------------------------------------------------------------------




--------------------------------------------------------------------
-- DEALING WITH proc automated_ac_on_person -> automated_ac_on_person 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'automated_ac_on_person', 'automated_ac_on_person');

-- DROP OLD FUNCTION
-- consider old oid 702539
-- DROP FUNCTION IF EXISTS automated_ac_on_person();

-- RECREATE FUNCTION
-- consider NEW oid 667101
CREATE OR REPLACE FUNCTION jazzhands.automated_ac_on_person()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	ac_id INTEGER[];
	c_name VARCHAR;
	old_c_name VARCHAR;
	old_acr_c_name VARCHAR;
	acr_c_name VARCHAR;
	gender_string VARCHAR;
	r RECORD;
	old_r RECORD;
BEGIN
	IF NEW.gender = OLD.gender OR NEW.person_id = 0 AND OLD.person_id = 0 THEN
		RETURN NEW;
	END IF;
	IF OLD.person_id != NEW.person_id THEN
		RAISE NOTICE 'This trigger % does not support changing person_id.  old person_id % new person_id %', TG_NAME, OLD.person_id, NEW.person_id;
		RETURN NEW;
	END IF;
	FOR old_r
		IN SELECT
			account_realm_name, account_id, company_id
		FROM
			jazzhands.account_realm ar
		JOIN
			jazzhands.account a
		USING
			(account_realm_id)
		JOIN
			jazzhands.val_person_status vps
		ON
			account_status = vps.person_status AND vps.is_disabled='N'
		WHERE
			a.person_id = OLD.person_id
	LOOP
		SELECT company_short_name INTO old_c_name FROM jazzhands.company WHERE company_id = old_r.company_id AND company_short_name IS NOT NULL;
		IF FOUND THEN
			old_acr_c_name = old_r.account_realm_name || '_' || old_c_name;
			gender_string = acct_coll_manip.person_gender_char_to_automated_ac_name(OLD.gender);
			IF gender_string IS NOT NULL THEN
				DELETE FROM jazzhands.account_collection_account WHERE account_id = old_r.account_id
					AND account_collection_id = acct_coll_manip.get_automated_account_collection_id(old_acr_c_name || '_' ||  gender_string);
			END IF;
		ELSE
			RAISE NOTICE 'Company short name cannot be determined from company_id % in %', old_r.company_id, TG_NAME;
		END IF;
		-- looping over the same set of data.  TODO: optimize for speed
		FOR r
			IN SELECT
				account_realm_name, account_id, company_id
			FROM
				jazzhands.account_realm ar
			JOIN
				jazzhands.account a
			USING
				(account_realm_id)
			JOIN
				jazzhands.val_person_status vps
			ON
				account_status = vps.person_status AND vps.is_disabled='N'
			WHERE
				a.person_id = NEW.person_id
		LOOP
			IF old_r.company_id = r.company_id THEN
				IF old_c_name IS NULL THEN
					RAISE NOTICE 'The new company short name is null like the old company short name. Going to the next record if there is any';
					CONTINUE;
				END IF;
				c_name = old_c_name;
			ELSE
				SELECT company_short_name INTO c_name FROM jazzhands.company WHERE company_id = r.company_id AND company_short_name IS NOT NULL;
				IF NOT FOUND THEN
					RAISE NOTICE 'New company short name cannot be determined from company_id % in %', r.company_id, TG_NAME;
					CONTINUE;
				END IF;
			END IF;
			acr_c_name = r.account_realm_name || '_' || c_name;
			gender_string = acct_coll_manip.person_gender_char_to_automated_ac_name(NEW.gender);
			IF gender_string IS NULL THEN
				CONTINUE;
			END IF;
			ac_id[0] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || gender_string);
			PERFORM acct_coll_manip.insert_or_delete_automated_ac('f', r.account_id, ac_id);
		END LOOP;
	END LOOP;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc automated_ac_on_person -> automated_ac_on_person 
--------------------------------------------------------------------



--------------------------------------------------------------------
-- DEALING WITH proc automated_ac_on_person_company -> automated_ac_on_person_company 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'automated_ac_on_person_company', 'automated_ac_on_person_company');

-- DROP OLD FUNCTION
-- consider old oid 709418
-- DROP FUNCTION IF EXISTS automated_ac_on_person_company();

-- RECREATE FUNCTION
-- consider NEW oid 667099
CREATE OR REPLACE FUNCTION jazzhands.automated_ac_on_person_company()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	ac_id INTEGER[];
	c_name VARCHAR;
	old_acr_c_name VARCHAR;
	acr_c_name VARCHAR;
	exempt_status RECORD;
	new_exempt_status RECORD;
	full_time_status RECORD;
	manager_status RECORD;
	old_r RECORD;
	r RECORD;
BEGIN
	-- at this time person_company.is_exempt column can be null.
	-- take into account of is_exempt going from null to not null
	IF (NEW.is_exempt IS NOT NULL AND OLD.is_exempt IS NOT NULL AND NEW.is_exempt = OLD.is_exempt OR NEW.is_exempt IS NULL AND OLD.is_exempt IS NULL)
		AND NEW.is_management = OLD.is_management AND NEW.is_full_time = OLD.is_full_time
		OR (NEW.person_id = 0 AND OLD.person_id = 0) THEN
		RETURN NEW;
	END IF;
	IF NEW.person_id != OLD.person_id THEN
		RAISE NOTICE 'This trigger % does not support changing person_id', TG_NAME;
		RETURN NEW;
	ELSIF NEW.company_id != OLD.company_id THEN
		RAISE NOTICE 'This trigger % does not support changing company_id', TG_NAME;
		RETURN NEW;
	END IF;
	SELECT company_short_name INTO c_name FROM jazzhands.company WHERE company_id = OLD.company_id AND company_short_name IS NOT NULL;
	IF NOT FOUND THEN
		RAISE NOTICE 'Company short name cannot be determined from company_id % in trigger %', OLD.company_id, TG_NAME;
		RETURN NEW;
	END IF;
	FOR old_r
		IN SELECT
			account_realm_name, account_id
		FROM
			jazzhands.account_realm ar
		JOIN
			jazzhands.account a
		USING
			(account_realm_id)
		JOIN
			jazzhands.val_person_status vps
		ON
			account_status = vps.person_status AND vps.is_disabled='N'
		WHERE
			a.person_id = OLD.person_id AND a.company_id = OLD.company_id
	LOOP
		old_acr_c_name = old_r.account_realm_name || '_' || c_name;
		IF coalesce(NEW.is_exempt, '') != coalesce(OLD.is_exempt, '') THEN
			IF OLD.is_exempt IS NOT NULL THEN
				SELECT * INTO exempt_status FROM acct_coll_manip.person_company_flags_to_automated_ac_name(OLD.is_exempt, 'exempt');
				DELETE FROM jazzhands.account_collection_account WHERE account_id = old_r.account_id
					AND account_collection_id = acct_coll_manip.get_automated_account_collection_id(old_acr_c_name || '_' || exempt_status.name);
			END IF;
		END IF;
		IF NEW.is_full_time != OLD.is_full_time THEN
			SELECT * INTO full_time_status FROM acct_coll_manip.person_company_flags_to_automated_ac_name(OLD.is_full_time, 'full_time');
			DELETE FROM jazzhands.account_collection_account WHERE account_id = old_r.account_id
				AND account_collection_id = acct_coll_manip.get_automated_account_collection_id(old_acr_c_name || '_' || full_time_status.name);
		END IF;
		IF NEW.is_management != OLD.is_management THEN
			SELECT * INTO manager_status FROM acct_coll_manip.person_company_flags_to_automated_ac_name(OLD.is_management, 'management');
			DELETE FROM jazzhands.account_collection_account WHERE account_id = old_r.account_id
				AND account_collection_id = acct_coll_manip.get_automated_account_collection_id(old_acr_c_name || '_' || manager_status.name);
		END IF;
		-- looping over the same set of data.  TODO: optimize for speed
		FOR r
			IN SELECT
				account_realm_name, account_id
			FROM
				jazzhands.account_realm ar
			JOIN
				jazzhands.account a
			USING
				(account_realm_id)
			JOIN
				jazzhands.val_person_status vps
			ON
				account_status = vps.person_status AND vps.is_disabled='N'
			WHERE
				a.person_id = NEW.person_id AND a.company_id = NEW.company_id
		LOOP
			acr_c_name = r.account_realm_name || '_' || c_name;
			IF coalesce(NEW.is_exempt, '') != coalesce(OLD.is_exempt, '') THEN
				IF NEW.is_exempt IS NOT NULL THEN
					SELECT * INTO new_exempt_status FROM acct_coll_manip.person_company_flags_to_automated_ac_name(NEW.is_exempt, 'exempt');
					ac_id[0] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || new_exempt_status.name);
					PERFORM acct_coll_manip.insert_or_delete_automated_ac('f', r.account_id, ac_id);
				END IF;
			END IF;
			IF NEW.is_full_time != OLD.is_full_time THEN
				ac_id[0] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || full_time_status.non_name);
				PERFORM acct_coll_manip.insert_or_delete_automated_ac('f', r.account_id, ac_id);
			END IF;
			IF NEW.is_management != OLD.is_management THEN
				ac_id[0] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || manager_status.non_name);
				PERFORM acct_coll_manip.insert_or_delete_automated_ac('f', r.account_id, ac_id);
			END IF;
		END LOOP;
	END LOOP;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc automated_ac_on_person_company -> automated_ac_on_person_company 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc automated_realm_site_ac_pl -> automated_realm_site_ac_pl 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'automated_realm_site_ac_pl', 'automated_realm_site_ac_pl');

-- DROP OLD FUNCTION
-- consider old oid 716021
-- DROP FUNCTION IF EXISTS automated_realm_site_ac_pl();

-- RECREATE FUNCTION
-- consider NEW oid 667103
CREATE OR REPLACE FUNCTION jazzhands.automated_realm_site_ac_pl()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	sc VARCHAR;
	r RECORD;
	ac_id INTEGER;
	ac_name VARCHAR;
	p_id INTEGER;
BEGIN
	IF TG_OP = 'UPDATE' THEN
		IF NEW.person_location_id != OLD.person_location_id THEN
			RAISE NOTICE 'This trigger % does not support changing person_location_id', TG_NAME;
			RETURN NEW;
		END IF;
		IF NEW.person_id IS NOT NULL AND OLD.person_id IS NOT NULL AND NEW.person_id != OLD.person_id THEN
			RAISE NOTICE 'This trigger % does not support changing person_id', TG_NAME;
			RETURN NEW;
		END IF;
		IF NEW.person_id IS NULL OR OLD.person_id IS NULL THEN
			-- setting person_id to NULL is done by 'usermgr merge'
			-- RAISE NOTICE 'This trigger % does not support null person_id', TG_NAME;
			RETURN NEW;
		END IF;
		IF NEW.site_code IS NOT NULL AND OLD.site_code IS NOT NULL AND NEW.site_code = OLD.site_code
			OR NEW.person_location_type != 'office' AND OLD.person_location_type != 'office' THEN
			RETURN NEW;
		END IF;
	END IF;

	IF TG_OP = 'INSERT' AND NEW.person_location_type != 'office' THEN
		RETURN NEW;
	END IF;

	IF TG_OP = 'DELETE' THEN
		IF OLD.person_location_type != 'office' THEN
			RETURN OLD;
		END IF;
		p_id = OLD.person_id;
		sc = OLD.site_code;
	ELSE
		p_id = NEW.person_id;
		sc = NEW.site_code;
	END IF;

	FOR r IN SELECT account_realm_name, account_id
		FROM
			jazzhands.account_realm ar
		JOIN
			jazzhands.account a
		ON
			ar.account_realm_id=a.account_realm_id AND a.account_role = 'primary' AND a.person_id = p_id 
		JOIN
			jazzhands.val_person_status vps
		ON
			vps.person_status = a.account_status AND vps.is_disabled='N'
		JOIN
			jazzhands.site s
		ON
			s.site_code = sc AND a.company_id = s.colo_company_id
	LOOP
		IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
			ac_name = r.account_realm_name || '_' || sc;
			ac_id = acct_coll_manip.get_automated_account_collection_id( r.account_realm_name || '_' || sc );
			IF TG_OP != 'UPDATE' OR NEW.person_location_type = 'office' THEN
				PERFORM 1 FROM jazzhands.account_collection_account WHERE account_collection_id = ac_id AND account_id = r.account_id;
				IF NOT FOUND THEN
					INSERT INTO account_collection_account (account_collection_id, account_id) VALUES (ac_id, r.account_id);
				END IF;
			END IF;
		END IF;
		IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
			IF OLD.site_code IS NULL THEN
				CONTINUE;
			END IF;
			ac_name = r.account_realm_name || '_' || OLD.site_code;
			SELECT account_collection_id INTO ac_id FROM jazzhands.account_collection WHERE account_collection_name = ac_name AND account_collection_type ='automated';
			IF NOT FOUND THEN
				RAISE NOTICE 'Account collection name % of type "automated" not found in %', ac_name, TG_NAME;
				CONTINUE;
			END IF;
			DELETE FROM jazzhands.account_collection_account WHERE account_collection_id = ac_id AND account_id = r.account_id;
		END IF;
	END LOOP;
	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	END IF;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc automated_realm_site_ac_pl -> automated_realm_site_ac_pl 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc check_person_image_usage_mv -> check_person_image_usage_mv 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'check_person_image_usage_mv', 'check_person_image_usage_mv');

-- DROP OLD FUNCTION
-- consider old oid 722580
-- DROP FUNCTION IF EXISTS check_person_image_usage_mv();

-- RECREATE FUNCTION
-- consider NEW oid 667043
CREATE OR REPLACE FUNCTION jazzhands.check_person_image_usage_mv()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	ismv	char;
	tally	INTEGER;
BEGIN
	select  vpiu.is_multivalue, count(*)
 	  into	ismv, tally
	  from  jazzhands.person_image pi
		inner join jazzhands.person_image_usage piu
			using (person_image_id)
		inner join jazzhands.val_person_image_usage vpiu
			using (person_image_usage)
	 where	pi.person_id in
	 	(select person_id from jazzhands.person_image
		 where person_image_id = NEW.person_image_id
		)
	  and	person_image_usage = NEW.person_image_usage
	group by vpiu.is_multivalue;

	IF ismv = 'N' THEN
		IF tally > 1 THEN
			RAISE EXCEPTION
				'Person may only be assigned %s for one image',
				NEW.person_image_usage
			USING ERRCODE = 20705;
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc check_person_image_usage_mv -> check_person_image_usage_mv 
--------------------------------------------------------------------



--------------------------------------------------------------------
-- DEALING WITH proc create_new_unix_account -> create_new_unix_account 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'create_new_unix_account', 'create_new_unix_account');

-- DROP OLD FUNCTION
-- consider old oid 729183
-- DROP FUNCTION IF EXISTS create_new_unix_account();

-- RECREATE FUNCTION
-- consider NEW oid 667047
CREATE OR REPLACE FUNCTION jazzhands.create_new_unix_account()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
	unix_id INTEGER;
	_account_collection_id integer;
BEGIN
	IF NEW.person_id != 0 THEN
		PERFORM person_manip.setup_unix_account(
			in_account_id := NEW.account_id,
			in_account_type := NEW.account_type
		);
	END IF;
	RETURN NEW;	
END;
$function$
;

-- DONE WITH proc create_new_unix_account -> create_new_unix_account 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc delete_per_device_device_collection -> delete_per_device_device_collection 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'delete_per_device_device_collection', 'delete_per_device_device_collection');

-- DROP OLD FUNCTION
-- consider old oid 729196
-- DROP FUNCTION IF EXISTS delete_per_device_device_collection();

-- RECREATE FUNCTION
-- consider NEW oid 667064
CREATE OR REPLACE FUNCTION jazzhands.delete_per_device_device_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	dcid			jazzhands.device_collection.device_collection_id%TYPE;
BEGIN
	SELECT	device_collection_id
	  FROM  jazzhands.device_collection
	  INTO	dcid
	 WHERE	device_collection_type = 'per-device'
	   AND	device_collection_id in
		(select device_collection_id
		 from jazzhands.device_collection_device
		where device_id = OLD.device_id
		)
	ORDER BY device_collection_id
	LIMIT 1;

	IF dcid IS NOT NULL THEN
		DELETE FROM jazzhands.device_collection_device
		WHERE device_collection_id = dcid;

		DELETE from jazzhands.device_collection
		WHERE device_collection_id = dcid;
	END IF;

	RETURN OLD;
END;
$function$
;

-- DONE WITH proc delete_per_device_device_collection -> delete_per_device_device_collection 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc delete_peruser_account_collection -> delete_peruser_account_collection 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'delete_peruser_account_collection', 'delete_peruser_account_collection');

-- DROP OLD FUNCTION
-- consider old oid 729167
-- DROP FUNCTION IF EXISTS delete_peruser_account_collection();

-- RECREATE FUNCTION
-- consider NEW oid 667031
CREATE OR REPLACE FUNCTION jazzhands.delete_peruser_account_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	def_acct_rlm	account_realm.account_realm_id%TYPE;
	acid			account_collection.account_collection_id%TYPE;
BEGIN
	IF TG_OP = 'DELETE' THEN
		SELECT	account_realm_id
		  INTO	def_acct_rlm
		  FROM	jazzhands.account_realm_company
		 WHERE	company_id IN
		 		(select property_value_company_id
				   from jazzhands.property
				  where	property_name = '_rootcompanyid'
				    and	property_type = 'Defaults'
				);
		IF def_acct_rlm is not NULL AND OLD.account_realm_id = def_acct_rlm THEN
				SELECT	account_collection_id 
				  FROM	jazzhands.account_collection
				  INTO	acid
				 WHERE	account_collection_name = OLD.login
				   AND	account_collection_type = 'per-user';
	
				 DELETE from jazzhands.account_collection_account
				  where account_collection_id = acid;
	
				 DELETE from jazzhands.account_collection
				  where account_collection_id = acid;
		END IF;
	END IF;
	RETURN OLD;
END;
$function$
;

-- DONE WITH proc delete_peruser_account_collection -> delete_peruser_account_collection 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc propagate_person_status_to_account -> propagate_person_status_to_account 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'propagate_person_status_to_account', 'propagate_person_status_to_account');

-- DROP OLD FUNCTION
-- consider old oid 729173
-- DROP FUNCTION IF EXISTS propagate_person_status_to_account();

-- RECREATE FUNCTION
-- consider NEW oid 667037
CREATE OR REPLACE FUNCTION jazzhands.propagate_person_status_to_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	should_propagate 	val_person_status.propagate_from_person%type;
BEGIN
	
	IF OLD.person_company_status != NEW.person_company_status THEN
		select propagate_from_person
		  into should_propagate
		 from	jazzhands.val_person_status
		 where	person_status = NEW.person_company_status;
		IF should_propagate = 'Y' THEN
			update jazzhands.account
			  set	account_status = NEW.person_company_status
			 where	person_id = NEW.person_id
			  AND	company_id = NEW.company_id;
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc propagate_person_status_to_account -> propagate_person_status_to_account 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc update_account_type_account_collection -> update_account_type_account_collection 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'update_account_type_account_collection', 'update_account_type_account_collection');

-- DROP OLD FUNCTION
-- consider old oid 729171
-- DROP FUNCTION IF EXISTS update_account_type_account_collection();

-- RECREATE FUNCTION
-- consider NEW oid 667035
CREATE OR REPLACE FUNCTION jazzhands.update_account_type_account_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	uc_name		account_collection.account_collection_Name%TYPE;
	ucid		account_collection.account_collection_Id%TYPE;
BEGIN
	IF TG_OP = 'UPDATE' THEN
		IF OLD.Account_Type = NEW.Account_Type THEN 
			RETURN NEW;
		END IF;

	uc_name := OLD.Account_Type;

	DELETE FROM account_collection_Account WHERE Account_Id = OLD.Account_Id AND
		account_collection_ID = (
			SELECT account_collection_ID 
			FROM jazzhands.account_collection 
			WHERE account_collection_Name = uc_name 
			AND account_collection_Type = 'usertype');

	END IF;
	uc_name := NEW.Account_Type;
	BEGIN
		SELECT account_collection_ID INTO STRICT ucid 
		  FROM jazzhands.account_collection 
		 WHERE account_collection_Name = uc_name 
		AND account_collection_Type = 'usertype';
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			INSERT INTO jazzhands.account_collection (
				account_collection_Name, account_collection_Type
			) VALUES (
				uc_name, 'usertype'
			) RETURNING account_collection_Id INTO ucid;
	END;
	IF ucid IS NOT NULL THEN
		INSERT INTO jazzhands.account_collection_Account (
			account_collection_ID,
			Account_Id
		) VALUES (
			ucid,
			NEW.Account_Id
		);
	END IF;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc update_account_type_account_collection -> update_account_type_account_collection 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc update_per_svc_env_svc_env_collection -> update_per_svc_env_svc_env_collection 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'update_per_svc_env_svc_env_collection', 'update_per_svc_env_svc_env_collection');

-- DROP OLD FUNCTION
-- consider old oid 729204
-- DROP FUNCTION IF EXISTS update_per_svc_env_svc_env_collection();

-- RECREATE FUNCTION
-- consider NEW oid 667075
CREATE OR REPLACE FUNCTION jazzhands.update_per_svc_env_svc_env_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	secid		service_environment_collection.service_env_collection_id%TYPE;
BEGIN
	IF TG_OP = 'INSERT' THEN
		insert into jazzhands.service_environment_collection 
			(service_env_collection_name, service_env_collection_type)
		values
			(NEW.service_environment, 'per-environment')
		RETURNING service_env_collection_id INTO secid;
		insert into jazzhands.svc_environment_coll_svc_env 
			(service_env_collection_id, service_environment)
		VALUES
			(secid, NEW.service_environment);
	ELSIF TG_OP = 'UPDATE'  AND OLD.service_environment != NEW.service_environment THEN
		UPDATE	jazzhands.service_environment_collection
		   SET	service_env_collection_name = NEW.service_environment
		 WHERE	service_env_collection_name != NEW.service_environment
		   AND	service_env_collection_type = 'per-environment'
		   AND	service_environment in (
			SELECT	service_environment
			  FROM	jazzhands.svc_environment_coll_svc_env
			 WHERE	service_environment = NEW.service_environment
			);
	END IF;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc update_per_svc_env_svc_env_collection -> update_per_svc_env_svc_env_collection 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc update_peruser_account_collection -> update_peruser_account_collection 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'update_peruser_account_collection', 'update_peruser_account_collection');

-- DROP OLD FUNCTION
-- consider old oid 729169
-- DROP FUNCTION IF EXISTS update_peruser_account_collection();

-- RECREATE FUNCTION
-- consider NEW oid 667033
CREATE OR REPLACE FUNCTION jazzhands.update_peruser_account_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	def_acct_rlm	account_realm.account_realm_id%TYPE;
	acid			account_collection.account_collection_id%TYPE;
BEGIN
	SELECT	account_realm_id
	  INTO	def_acct_rlm
	  FROM	jazzhands.account_realm_company
	 WHERE	company_id IN
	 		(select property_value_company_id
			   from jazzhands.property
			  where	property_name = '_rootcompanyid'
			    and	property_type = 'Defaults'
			);
	IF def_acct_rlm is not NULL AND NEW.account_realm_id = def_acct_rlm THEN
		if TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.account_realm_id != NEW.account_realm_id) THEN
			insert into jazzhands.account_collection 
				(account_collection_name, account_collection_type)
			values
				(NEW.login, 'per-user')
			RETURNING account_collection_id INTO acid;
			insert into jazzhands.account_collection_account 
				(account_collection_id, account_id)
			VALUES
				(acid, NEW.account_id);
		END IF;

		IF TG_OP = 'UPDATE' AND OLD.login != NEW.login THEN
			IF OLD.account_realm_id = NEW.account_realm_id THEN
				update	jazzhands.account_collection
				    set	account_collection_name = NEW.login
				  where	account_collection_type = 'per-user'
				    and	account_collection_name = OLD.login;
			END IF;
		END IF;
	END IF;

	-- remove the per-user entry if the new account realm is not the default
	IF TG_OP = 'UPDATE'  THEN
		IF def_acct_rlm is not NULL AND OLD.account_realm_id = def_acct_rlm AND NEW.account_realm_id != OLD.account_realm_id THEN
			SELECT	account_collection_id
		      FROM	jazzhands.account_collection
			  INTO	acid
			 WHERE	account_collection_name = OLD.login
			   AND	account_collection_type = 'per-user';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc update_peruser_account_collection -> update_peruser_account_collection 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc update_dns_zone -> update_dns_zone 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'update_dns_zone', 'update_dns_zone');

-- DROP OLD FUNCTION
-- consider old oid 729208
-- DROP FUNCTION IF EXISTS update_dns_zone();

-- RECREATE FUNCTION
-- consider NEW oid 667079
CREATE OR REPLACE FUNCTION jazzhands.update_dns_zone()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
		UPDATE jazzhands.dns_domain SET zone_last_updated = clock_timestamp()
            WHERE dns_domain_id = NEW.dns_domain_id
			AND ( zone_last_updated < last_generated
			OR zone_last_updated is NULL);

		IF TG_OP = 'UPDATE' THEN
			IF OLD.dns_domain_id != NEW.dns_domain_id THEN
				UPDATE jazzhands.dns_domain SET zone_last_updated = clock_timestamp()
					 WHERE dns_domain_id = OLD.dns_domain_id
					 AND ( zone_last_updated < last_generated or zone_last_updated is NULL );
			END IF;
			IF NEW.netblock_id != OLD.netblock_id THEN
				UPDATE jazzhands.dns_domain SET zone_last_updated = clock_timestamp()
					 WHERE dns_domain_id in (
						 netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id),
						 netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
					)
				     AND ( zone_last_updated < last_generated or zone_last_updated is NULL );
			END IF;
		ELSIF TG_OP = 'INSERT' AND NEW.netblock_id is not NULL THEN
			UPDATE jazzhands.dns_domain SET zone_last_updated = clock_timestamp()
				WHERE dns_domain_id = 
					netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
				AND ( zone_last_updated < last_generated or zone_last_updated is NULL );

		END IF;
	END IF;

    IF TG_OP = 'DELETE' THEN
        UPDATE jazzhands.dns_domain SET zone_last_updated = clock_timestamp()
			WHERE dns_domain_id = OLD.dns_domain_id
			AND ( zone_last_updated < last_generated or zone_last_updated is NULL );

		IF OLD.dns_type = 'A' OR OLD.dns_type = 'AAAA' THEN
			UPDATE jazzhands.dns_domain SET zone_last_updated = clock_timestamp()
                 WHERE  dns_domain_id = netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id)
				 AND ( zone_last_updated < last_generated or zone_last_updated is NULL );
        END IF;
    END IF;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc update_dns_zone -> update_dns_zone 
--------------------------------------------------------------------



--------------------------------------------------------------------
-- DEALING WITH proc delete_per_svc_env_svc_env_collection -> delete_per_svc_env_svc_env_collection 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'delete_per_svc_env_svc_env_collection', 'delete_per_svc_env_svc_env_collection');

-- DROP OLD FUNCTION
-- consider old oid 735813
-- DROP FUNCTION IF EXISTS delete_per_svc_env_svc_env_collection();

-- RECREATE FUNCTION
-- consider NEW oid 667073
CREATE OR REPLACE FUNCTION jazzhands.delete_per_svc_env_svc_env_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	secid	service_environment_collection.service_env_collection_id%TYPE;
BEGIN
	SELECT	service_env_collection_id
	  FROM  jazzhands.service_environment_collection
	  INTO	secid
	 WHERE	service_env_collection_type = 'per-environment'
	   AND	service_env_collection_id in
		(select service_env_collection_id
		 from jazzhands.svc_environment_coll_svc_env
		where service_environment = OLD.service_environment
		)
	ORDER BY service_env_collection_id
	LIMIT 1;

	IF secid IS NOT NULL THEN
		DELETE FROM jazzhands.svc_environment_coll_svc_env
		WHERE service_env_collection_id = secid;

		DELETE from jazzhands.service_environment_collection
		WHERE service_env_collection_id = secid;
	END IF;

	RETURN OLD;
END;
$function$
;

-- DONE WITH proc delete_per_svc_env_svc_env_collection -> delete_per_svc_env_svc_env_collection 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc update_per_device_device_collection -> update_per_device_device_collection 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'update_per_device_device_collection', 'update_per_device_device_collection');

-- DROP OLD FUNCTION
-- consider old oid 735809
-- DROP FUNCTION IF EXISTS update_per_device_device_collection();

-- RECREATE FUNCTION
-- consider NEW oid 667066
CREATE OR REPLACE FUNCTION jazzhands.update_per_device_device_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	dcid		jazzhands.device_collection.device_collection_id%TYPE;
	newname		jazzhands.device_collection.device_collection_name%TYPE;
BEGIN
	IF NEW.device_name IS NOT NULL THEN
		newname = NEW.device_name || '_' || NEW.device_id;
	ELSE
		newname = 'per_d_dc_contrived_' || NEW.device_id;
	END IF;

	IF TG_OP = 'INSERT' THEN
		insert into jazzhands.device_collection 
			(device_collection_name, device_collection_type)
		values
			(newname, 'per-device')
		RETURNING device_collection_id INTO dcid;
		insert into jazzhands.device_collection_device 
			(device_collection_id, device_id)
		VALUES
			(dcid, NEW.device_id);
	ELSIF TG_OP = 'UPDATE'  THEN
		UPDATE	device_collection
		   SET	device_collection_name = newname
		 WHERE	device_collection_name != newname
		   AND	device_collection_type = 'per-device'
		   AND	device_collection_id in (
			SELECT	device_collection_id
			  FROM	jazzhands.device_collection_device
			 WHERE	device_id = NEW.device_id
			);
	END IF;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc update_per_device_device_collection -> update_per_device_device_collection 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc validate_netblock -> validate_netblock 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_netblock', 'validate_netblock');

-- DROP OLD FUNCTION
-- consider old oid 735796
-- DROP FUNCTION IF EXISTS validate_netblock();

-- RECREATE FUNCTION
-- consider NEW oid 667049
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	nbtype				RECORD;
	v_netblock_id		jazzhands.netblock.netblock_id%TYPE;
	parent_netblock		RECORD;
BEGIN
	/*
	 * Force netmask_bits to be authoritative.  If netblock_bits is NULL
	 * and this is a validated hierarchy, then set things to match the best
	 * parent
	 */

	IF NEW.netmask_bits IS NULL THEN
		/*
		 * If netmask_bits is not set, and ip_address has a netmask that is
		 * not a /32 (the default), then use that for the netmask.
		 */

		IF (NEW.ip_address IS NOT NULL and masklen(NEW.ip_address) != 32) THEN
			NEW.netmask_bits := masklen(NEW.ip_address);
		END IF;

		/*
		 * Don't automatically determine the netmask unless is_single_address
		 * is 'Y'.  If it is, enforce it if it's a managed hierarchy
		 */
		IF NEW.is_single_address = 'Y' THEN
			SELECT * INTO nbtype FROM jazzhands.val_netblock_type WHERE 
				netblock_type = NEW.netblock_type;

			IF (NOT FOUND) OR nbtype.db_forced_hierarchy != 'Y' THEN
				RAISE EXCEPTION 'Column netmask_bits may not be null'
					USING ERRCODE = 'not_null_violation';
			END IF;
	
			RAISE DEBUG 'Calculating netmask for new netblock';

			v_netblock_id := netblock_utils.find_best_parent_id(
				NEW.ip_address,
				NULL,
				NEW.netblock_type,
				NEW.ip_universe_id,
				NEW.is_single_address,
				NEW.netblock_id
				);
		
			SELECT masklen(ip_address) INTO NEW.netmask_bits FROM
				jazzhands.netblock WHERE netblock_id = v_netblock_id;

		END IF;
		IF NEW.netmask_bits IS NULL THEN
			RAISE EXCEPTION 'Column netmask_bits may not be null'
				USING ERRCODE = 'not_null_violation';
		END IF;
	END IF;

	/*
	 * If netmask_bits was not NULL, then it wins.  This will go away
	 * in the future
	 */
	NEW.ip_address = set_masklen(NEW.ip_address, NEW.netmask_bits);

	IF NEW.can_subnet = 'Y' AND NEW.is_single_address = 'Y' THEN
		RAISE EXCEPTION 'Single addresses may not be subnettable'
			USING ERRCODE = 22106;
	END IF;

	IF NEW.is_single_address = 'N' AND (NEW.ip_address != cidr(NEW.ip_address))
			THEN
		RAISE EXCEPTION
			'Non-network bits must be zero if is_single_address is N for %',
			NEW.ip_address
			USING ERRCODE = 22103;
	END IF;

	/*
	 * Commented out check for RFC1918 space.  This is probably handled
	 * well enough by the ip_universe/netblock_type additions, although
	 * it's possible that netblock_type may need to have an additional
	 * field added to allow people to be stupid (for example,
	 * allow_duplicates='Y','N','RFC1918')
	 */

/*
	IF NOT net_manip.inet_is_private(NEW.ip_address) THEN
*/
			PERFORM netblock_id 
			   FROM jazzhands.netblock 
			  WHERE ip_address = NEW.ip_address AND
					ip_universe_id = NEW.ip_universe_id AND
					netblock_type = NEW.netblock_type AND
					is_single_address = NEW.is_single_address;
			IF (TG_OP = 'INSERT' AND FOUND) THEN 
				RAISE EXCEPTION 'Unique Constraint Violated on IP Address: %', 
					NEW.ip_address
					USING ERRCODE= 'unique_violation';
			END IF;
			IF (TG_OP = 'UPDATE') THEN
				IF (NEW.ip_address != OLD.ip_address AND FOUND) THEN
					RAISE EXCEPTION 
						'Unique Constraint Violated on IP Address: %', 
						NEW.ip_address
						USING ERRCODE = 'unique_violation';
				END IF;
			END IF;
/*
	END IF;
*/

	/*
	 * Parent validation is performed in the deferred after trigger
	 */

	 RETURN NEW;
END;
$function$
;

-- DONE WITH proc validate_netblock -> validate_netblock 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc validate_property -> validate_property 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_property', 'validate_property');

-- DROP OLD FUNCTION
-- consider old oid 735774
-- DROP FUNCTION IF EXISTS validate_property();

-- RECREATE FUNCTION
-- consider NEW oid 667028
CREATE OR REPLACE FUNCTION jazzhands.validate_property()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
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
		SELECT * INTO STRICT v_prop FROM jazzhands.VAL_Property WHERE
			Property_Name = NEW.Property_Name AND
			Property_Type = NEW.Property_Type;

		SELECT * INTO STRICT v_proptype FROM jazzhands.VAL_Property_Type WHERE
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
			((account_collection_Id IS NULL AND NEW.account_collection_Id IS NULL) OR
				(account_collection_Id = NEW.account_collection_Id)) AND
			((netblock_collection_Id IS NULL AND NEW.netblock_collection_Id IS NULL) OR
				(netblock_collection_Id = NEW.netblock_collection_Id)) AND
			((person_id IS NULL AND NEW.Person_id IS NULL) OR
				(Account_Id = NEW.person_id))
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
		PERFORM 1 FROM jazzhands.Property WHERE
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
			((account_collection_Id IS NULL AND NEW.account_collection_Id IS NULL) OR
				(account_collection_Id = NEW.account_collection_Id)) AND
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
					FROM jazzhands.account_collection WHERE
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
					FROM jazzhands.netblock_collection WHERE
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

-- DONE WITH proc validate_property -> validate_property 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc verify_device_voe -> verify_device_voe 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'verify_device_voe', 'verify_device_voe');

-- DROP OLD FUNCTION
-- consider old oid 735811
-- DROP FUNCTION IF EXISTS verify_device_voe();

-- RECREATE FUNCTION
-- consider NEW oid 667068
CREATE OR REPLACE FUNCTION jazzhands.verify_device_voe()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	voe_sw_pkg_repos		jazzhands.sw_package_repository.sw_package_repository_id%TYPE;
	os_sw_pkg_repos		jazzhands.operating_system.sw_package_repository_id%TYPE;
	voe_sym_trx_sw_pkg_repo_id	jazzhands.voe_symbolic_track.sw_package_repository_id%TYPE;
BEGIN

	IF (NEW.operating_system_id IS NOT NULL)
	THEN
		SELECT sw_package_repository_id INTO os_sw_pkg_repos
			FROM
				jazzhands.operating_system
			WHERE
				operating_system_id = NEW.operating_system_id;
	END IF;

	IF (NEW.voe_id IS NOT NULL) THEN
		SELECT sw_package_repository_id INTO voe_sw_pkg_repos
			FROM
				jazzhands.voe
			WHERE
				voe_id=NEW.voe_id;
		IF (voe_sw_pkg_repos != os_sw_pkg_repos) THEN
			RAISE EXCEPTION 
				'Device OS and VOE have different SW Pkg Repositories';
		END IF;
	END IF;

	IF (NEW.voe_symbolic_track_id IS NOT NULL) THEN
		SELECT sw_package_repository_id INTO voe_sym_trx_sw_pkg_repo_id	
			FROM
				jazzhands.voe_symbolic_track
			WHERE
				voe_symbolic_track_id=NEW.voe_symbolic_track_id;
		IF (voe_sym_trx_sw_pkg_repo_id != os_sw_pkg_repos) THEN
			RAISE EXCEPTION 
				'Device OS and VOE track have different SW Pkg Repositories';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc verify_device_voe -> verify_device_voe 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc verify_layer1_connection -> verify_layer1_connection 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'verify_layer1_connection', 'verify_layer1_connection');

-- DROP OLD FUNCTION
-- consider old oid 735767
-- DROP FUNCTION IF EXISTS verify_layer1_connection();

-- RECREATE FUNCTION
-- consider NEW oid 667023
CREATE OR REPLACE FUNCTION jazzhands.verify_layer1_connection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	PERFORM 1 FROM 
		jazzhands.layer1_connection l1 
			JOIN jazzhands.layer1_connection l2 ON 
				l1.physical_port1_id = l2.physical_port2_id AND
				l1.physical_port2_id = l2.physical_port1_id;
	IF FOUND THEN
		RAISE EXCEPTION 'Connection already exists in opposite direction';
	END IF;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc verify_layer1_connection -> verify_layer1_connection 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc person_manip.add_account_non_person -> add_account_non_person 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('person_manip', 'add_account_non_person', 'add_account_non_person');

-- DROP OLD FUNCTION
-- consider old oid 735722
-- DROP FUNCTION IF EXISTS person_manip.add_account_non_person(_company_id integer, _account_status character varying, _login character varying, _description character varying);

-- RECREATE FUNCTION
-- consider NEW oid 666978
CREATE OR REPLACE FUNCTION person_manip.add_account_non_person(_company_id integer, _account_status character varying, _login character varying, _description character varying)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	__account_id INTEGER;
BEGIN
    SELECT account_id
     INTO  __account_id
     FROM  person_manip.add_user(
        company_id := _company_id,
        person_company_relation := 'pseudouser',
        login := _login,
        description := _description,
        person_company_status := 'enabled'
    );
	RETURN __account_id;
END;
$function$
;

-- DONE WITH proc person_manip.add_account_non_person -> add_account_non_person 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc validate_netblock_parentage -> validate_netblock_parentage 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_netblock_parentage', 'validate_netblock_parentage');

-- DROP OLD FUNCTION
-- consider old oid 742392
-- DROP FUNCTION IF EXISTS validate_netblock_parentage();

-- RECREATE FUNCTION
-- consider NEW oid 667060
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock_parentage()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	nbrec			record;
	realnew			record;
	nbtype			record;
	parent_nbid		jazzhands.netblock.netblock_id%type;
	ipaddr			inet;
	parent_ipaddr	inet;
	single_count	integer;
	nonsingle_count	integer;
	pip	    		jazzhands.netblock.ip_address%type;
BEGIN

	RAISE DEBUG 'Validating % of netblock %', TG_OP, NEW.netblock_id;

	SELECT * INTO nbtype FROM jazzhands.val_netblock_type WHERE 
		netblock_type = NEW.netblock_type;

	IF (NOT FOUND) THEN
		RETURN NULL;
	END IF;

	/*
	 * It's possible that due to delayed triggers that what is stored in
	 * NEW is not current, so fetch the current values
	 */
	
	SELECT * INTO realnew FROM jazzhands.netblock WHERE netblock_id =
		NEW.netblock_id;
	IF NOT FOUND THEN
		/* 
		 * If the netblock isn't there, it was subsequently deleted, so 
		 * our parentage doesn't need to be checked
		 */
		RETURN NULL;
	END IF;
	
	
	/*
	 * If the parent changed above (or somewhere else between update and
	 * now), just bail, because another trigger will have been fired that
	 * we can do the full check with.
	 */
	IF NEW.parent_netblock_id != realnew.parent_netblock_id AND
		realnew.parent_netblock_id IS NOT NULL
	THEN
		RAISE DEBUG '... skipping for now';
		RETURN NULL;
	END IF;

	/*
	 * Validate that parent and all children are of the same netblock_type and
	 * in the same ip_universe.  We care about this even if the
	 * netblock type is not a validated type.
	 */
	
	RAISE DEBUG 'Verifying child ip_universe and type match';
	PERFORM netblock_id FROM jazzhands.netblock WHERE
		parent_netblock_id = realnew.netblock_id AND
		netblock_type != realnew.netblock_type AND
		ip_universe_id != realnew.ip_universe_id;

	IF FOUND THEN
		RAISE EXCEPTION 'Netblock children must all be of the same type and universe as the parent'
			USING ERRCODE = 22109;
	END IF;

	RAISE DEBUG '... OK';

	/*
	 * validate that this netblock is attached to its correct parent
	 */
	IF realnew.parent_netblock_id IS NULL THEN
		IF nbtype.is_validated_hierarchy='N' THEN
			RETURN NULL;
		END IF;
		RAISE DEBUG 'Checking hierarchical netblock_id % with NULL parent',
			NEW.netblock_id;

		IF realnew.is_single_address = 'Y' THEN
			RAISE 'A single address (%) must be the child of a parent netblock',
				realnew.ip_address
				USING ERRCODE = 22105;
		END IF;		

		/*
		 * Validate that a netblock has a parent, unless
		 * it is the root of a hierarchy
		 */
		parent_nbid := netblock_utils.find_best_parent_id(
			realnew.ip_address, 
			masklen(realnew.ip_address),
			realnew.netblock_type,
			realnew.ip_universe_id,
			realnew.is_single_address,
			realnew.netblock_id
		);

		IF parent_nbid IS NOT NULL THEN
			SELECT * INTO nbrec FROM jazzhands.netblock WHERE netblock_id =
				parent_nbid;

			RAISE EXCEPTION 'Netblock % (%) has NULL parent; should be % (%)',
				realnew.netblock_id, realnew.ip_address, 
				parent_nbid, nbrec.ip_address USING ERRCODE = 22102;
		END IF;

		/*
		 * Validate that none of the other top-level netblocks should
		 * belong to this netblock
		 */
		PERFORM netblock_id FROM jazzhands.netblock WHERE 
			parent_netblock_id IS NULL AND
			netblock_id != NEW.netblock_id AND
			netblock_type = NEW.netblock_type AND
			ip_universe_id = NEW.ip_universe_id AND
			ip_address <<= NEW.ip_address;
		IF FOUND THEN
			RAISE EXCEPTION 'Other top-level netblocks should belong to this parent'
				USING ERRCODE = 22108;
		END IF;
	ELSE
	 	/*
		 * Reject a block that is self-referential
		 */
	 	IF realnew.parent_netblock_id = realnew.netblock_id THEN
			RAISE EXCEPTION 'Netblock may not have itself as a parent'
				USING ERRCODE = 22101;
		END IF;
		
		SELECT * INTO nbrec FROM jazzhands.netblock WHERE netblock_id = 
			realnew.parent_netblock_id;

		/*
		 * This shouldn't happen, but may because of deferred constraints
		 */
		IF NOT FOUND THEN
			RAISE EXCEPTION 'Parent netblock % does not exist',
			realnew.parent_netblock_id
			USING ERRCODE = 23503;
		END IF;

		IF nbrec.is_single_address = 'Y' THEN
			RAISE EXCEPTION 'Parent netblock % of single address % may not also be a single address',
			nbrec.netblock_id, realnew.ip_address
			USING ERRCODE = 22110;
		END IF;

		IF nbrec.ip_universe_id != realnew.ip_universe_id OR
				nbrec.netblock_type != realnew.netblock_type THEN
			RAISE EXCEPTION 'Netblock children must all be of the same type and universe as the parent'
			USING ERRCODE = 22109;
		END IF;

		IF nbtype.is_validated_hierarchy='N' THEN
			/*
			 * validated hierarchy addresses may not have the best parent as
			 * a parent, but if they have a parent, it should be a superblock
			 */

			IF NOT (realnew.ip_address << nbrec.ip_address OR
					cidr(realnew.ip_address) != nbrec.ip_address) THEN
				RAISE EXCEPTION 'Parent netblock % (%)  is not a valid parent for %',
					nbrec.ip_address, nbrec.netblock_id, realnew.ip_address
					USING ERRCODE = 22102;
			END IF;
		ELSE
			parent_nbid := netblock_utils.find_best_parent_id(
				realnew.ip_address, 
				masklen(realnew.ip_address),
				realnew.netblock_type,
				realnew.ip_universe_id,
				realnew.is_single_address,
				realnew.netblock_id
				);

			IF realnew.can_subnet = 'N' THEN
				PERFORM netblock_id FROM jazzhands.netblock WHERE
					parent_netblock_id = realnew.netblock_id AND
					is_single_address = 'N';
				IF FOUND THEN
					RAISE EXCEPTION 'A non-subnettable netblock (%) may not have child network netblocks',
					realnew.netblock_id
					USING ERRCODE = 22111;
				END IF;
			END IF;
			IF realnew.is_single_address = 'Y' THEN 
				SELECT ip_address INTO ipaddr FROM jazzhands.netblock
					WHERE netblock_id = realnew.parent_netblock_id;
				IF (masklen(realnew.ip_address) != masklen(ipaddr)) THEN
					RAISE 'Parent netblock % does not have same netmask as single address child % (% vs %)',
						parent_nbid, realnew.netblock_id, masklen(ipaddr),
						masklen(realnew.ip_address)
						USING ERRCODE = 22105;
				END IF;
			END IF;
			IF (parent_nbid IS NULL OR realnew.parent_netblock_id != parent_nbid) THEN
				SELECT ip_address INTO parent_ipaddr FROM jazzhands.netblock
				WHERE
					netblock_id = parent_nbid;
				SELECT ip_address INTO ipaddr FROM jazzhands.netblock WHERE
					netblock_id = realnew.parent_netblock_id;

				RAISE EXCEPTION 
					'Parent netblock % (%) for netblock % (%) is not the correct parent (should be % (%))',
					realnew.parent_netblock_id, ipaddr,
					realnew.netblock_id, realnew.ip_address,
					parent_nbid, parent_ipaddr
					USING ERRCODE = 22102;
			END IF;
			/*
			 * Validate that all children are is_single_address='Y' or
			 * all children are is_single_address='N'
			 */
			SELECT count(*) INTO single_count FROM jazzhands.netblock WHERE
				is_single_address='Y' and parent_netblock_id = 
				realnew.parent_netblock_id;
			SELECT count(*) INTO nonsingle_count FROM jazzhands.netblock WHERE
				is_single_address='N' and parent_netblock_id =
				realnew.parent_netblock_id;

			IF (single_count > 0 and nonsingle_count > 0) THEN
				SELECT * INTO nbrec FROM jazzhands.netblock WHERE netblock_id =
					realnew.parent_netblock_id;
				RAISE EXCEPTION 'Netblock % (%) may not have direct children for both single and multiple addresses simultaneously',
					nbrec.netblock_id, nbrec.ip_address
					USING ERRCODE = 22107;
			END IF;
			/*
			 *  If we're updating and we changed our ip_address (including
			 *  netmask bits), then check that our children still belong to
			 *  us
			 */
			 IF (TG_OP = 'UPDATE' AND NEW.ip_address != OLD.ip_address) THEN
				PERFORM netblock_id FROM jazzhands.netblock WHERE 
					parent_netblock_id = realnew.netblock_id AND
					((is_single_address = 'Y' AND NEW.ip_address != 
						ip_address::cidr) OR
					(is_single_address = 'N' AND realnew.netblock_id !=
						netblock_utils.find_best_parent_id(netblock_id)));
				IF FOUND THEN
					RAISE EXCEPTION 'Update for netblock % (%) causes parent to have children that do not belong to it',
						realnew.netblock_id, realnew.ip_address
						USING ERRCODE = 22112;
				END IF;
			END IF;

			/*
			 * Validate that none of the children of the parent netblock are
			 * children of this netblock (e.g. if inserting into the middle
			 * of the hierarchy)
			 */
			IF (realnew.is_single_address = 'N') THEN
				PERFORM netblock_id FROM jazzhands.netblock WHERE 
					parent_netblock_id = realnew.parent_netblock_id AND
					netblock_id != realnew.netblock_id AND
					ip_address <<= realnew.ip_address;
				IF FOUND THEN
					RAISE EXCEPTION 'Other netblocks have children that should belong to parent % (%)',
						realnew.parent_netblock_id, realnew.ip_address
						USING ERRCODE = 22108;
				END IF;
			END IF;
		END IF;
	END IF;

	RETURN NULL;
END;
$function$
;

-- DONE WITH proc validate_netblock_parentage -> validate_netblock_parentage 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc port_utils.setup_device_physical_ports -> setup_device_physical_ports 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('port_utils', 'setup_device_physical_ports', 'setup_device_physical_ports');

-- DROP OLD FUNCTION
-- consider old oid 768787
-- DROP FUNCTION IF EXISTS port_utils.setup_device_physical_ports(in_device_id integer, in_port_type character varying);

-- RECREATE FUNCTION
-- consider NEW oid 755853
CREATE OR REPLACE FUNCTION port_utils.setup_device_physical_ports(in_device_id integer, in_port_type character varying DEFAULT NULL::character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	v_dt_id	device.device_type_id%type;
	v_pt	val_port_type.port_type%type;
	ptypes	RECORD;
BEGIN
	select  device_type_id
	  into	v_dt_id
	  from  device
	 where	device_id = in_device_id;


	FOR ptypes IN select port_type from val_port_type 
	LOOP
		v_pt := ptypes.port_type;
		if(in_port_type is NULL or v_pt = in_port_type) THEN
			if( NOT port_support.has_physical_ports(in_device_id,v_pt) ) then
				insert into physical_port
					(device_id, port_name, port_type, description,
					 port_plug_style,
					 port_medium, port_protocol, port_speed,
					 physical_label, port_purpose, tcp_port, is_hardwired
					)
					select	in_device_id, port_name, port_type, description,
					 		port_plug_style,
					 		port_medium, port_protocol, port_speed,
					 		physical_label, port_purpose, tcp_port,
							is_hardwired
					  from	device_type_phys_port_templt
					 where  device_type_id = v_dt_id
					  and	port_type = v_pt
					  and	is_optional = 'N'
				;
			end if;
		end if;
	END LOOP;
END;
$function$
;

-- DONE WITH proc port_utils.setup_device_physical_ports -> setup_device_physical_ports 
--------------------------------------------------------------------



-- create audit table indexes that aren't there

DO $$

DECLARE
	tbl RECORD;
	tal INTEGER;
	idx varchar;
BEGIN
    FOR tbl IN
        SELECT table_name FROM information_schema.tables
        WHERE table_type = 'BASE TABLE' AND table_schema = 'audit'
        ORDER BY table_name
    LOOP
	idx = tbl.table_name || '_aud#timestamp_idx';
	SELECT count(*) INTO tal FROM pg_catalog.pg_indexes WHERE
		schemaname = 'audit' AND indexname =  idx;
	IF tal = 0 THEN
		RAISE NOTICE 'On table %, creating index %', 
			tbl.table_name, idx;
    		EXECUTE 'CREATE INDEX ' 
			|| quote_ident(idx) || ' ' 
			|| ' ON ' || quote_ident('audit') || '.'
        		|| quote_ident(tbl.table_name) || '("aud#timestamp")';
	END IF;
    END LOOP;
END
$$;

--------------------------------------------------------------------

-- Iniitalization Fixes
UPDATE val_property
set PERMIT_DEVICE_COLLECTION_ID = 'ALLOWED'
where property_name = 'ForceShell' and property_type = 'UnixPasswdFileValue'
and PERMIT_DEVICE_COLLECTION_ID != 'ALLOWED';

DO $$
DECLARE
	_tal INTEGER;
BEGIN
	SELECT COUNT(*) INTO _tal FROM val_property 
	where property_name = 'UnixGroup'
	and property_type = 'MclassUnixProp';

	IF _tal = 0 THEN
		insert into val_property
		(property_name, property_type, is_multivalue,
		permit_account_collection_id, permit_device_collection_id,
		property_data_type
		) values (
		'UnixGroup', 'MclassUnixProp', 'N',
		'REQUIRED', 'REQUIRED',
		'none'
		);
	END IF;
END;
$$;

DO $$
DECLARE
	_tal INTEGER;
BEGIN
	SELECT COUNT(*) INTO _tal FROM val_property 
	where property_name = 'UnixGroupMemberOverride'
	and property_type = 'MclassUnixProp';

	IF _tal = 0 THEN
		insert into val_property
			(property_name, property_type, is_multivalue,
			permit_account_collection_id, 
			permit_device_collection_id,
			property_data_type
		) values (
			'UnixGroupMemberOverride', 'MclassUnixProp', 'N',
			'REQUIRED', 
			'REQUIRED',
			'account_collection_id'
		);
	END IF;
END;
$$;


DO $$
DECLARE
	_tal INTEGER;
BEGIN
	SELECT COUNT(*) INTO _tal FROM val_property 
	where property_name = 'ShouldDeploy'
	and property_type = 'MclassUnixProp';

	IF _tal = 0 THEN
		insert into val_property (
			PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, 
			PROPERTY_DATA_TYPE,
			DESCRIPTION,
			PERMIT_DEVICE_COLLECTION_ID
		) values (
			'ShouldDeploy', 'MclassUnixProp', 'N', 'boolean',
			'If credentials managmeent should deploy files or not',
			'REQUIRED'
		);
	END IF;
END;
$$;

DO $$
DECLARE
	_tal INTEGER;
BEGIN
	SELECT COUNT(*) INTO _tal FROM val_property 
	where property_name = 'PreferLocal'
	and property_type = 'MclassUnixProp';

	IF _tal = 0 THEN
		insert into val_property (
			PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, 
			PROPERTY_DATA_TYPE,
			DESCRIPTION,
			PERMIT_DEVICE_COLLECTION_ID, 
			PERMIT_ACCOUNT_COLLECTION_ID
		) values (
			'PreferLocal', 'MclassUnixProp', 'N', 
			'boolean',
			'If credentials management client should prefer local uid,gid,shell',
			'REQUIRED', 
			'REQUIRED'
		);
	END IF;
END;
$$;

DO $$
DECLARE
	_tal INTEGER;
BEGIN
	SELECT COUNT(*) INTO _tal FROM val_property_type 
	where property_type = 'StabRole';

	IF _tal = 0 THEN
		insert into val_property_type 
		(property_type, description, is_multivalue)
		values
       		('StabRole', 'roles for users in stab', 'Y');
	END IF;
END;
$$;


DO $$
DECLARE
	_tal INTEGER;
BEGIN
	SELECT COUNT(*) INTO _tal FROM val_property 
	where property_name = 'StabAccess'
	and property_type = 'StabRole';

	IF _tal = 0 THEN
		insert into val_property (
			PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, 
			PROPERTY_DATA_TYPE,
		permit_account_collection_id
		) values (
			'StabAccess', 'StabRole', 'N', 'boolean',
			'REQUIRED'
		);

	END IF;
END;
$$;


--------------------------------------------------------------------
--
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_saved_grants();

ALTER TABLE netblock DROP CONSTRAINT fk_netblk_netblk_parid;
ALTER TABLE netblock
	ADD CONSTRAINT fk_netblk_netblk_parid 
	FOREIGN KEY (parent_netblock_id) REFERENCES netblock(netblock_id)
	DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE dns_record
	ALTER COLUMN dns_class set DEFAULT 'IN'::varchar;

RAISE EXCEPTION 'Need to test, test, test....';

-- SELECT schema_support.end_maintenance();
