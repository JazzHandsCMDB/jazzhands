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

\set ON_ERROR_STOP

select now();

---------- ========================================================= ----------
--------------------------------------------------------------------
--- BEGIN: ddl/schema/pgsql/create_schema_support.sql
--------------------------------------------------------------------


/*
 * Copyright (c) 2010-2014 Todd Kover
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
 * Copyright (c) 2010 Matthew Ragan
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
		CREATE TEMPORARY TABLE IF NOT EXISTS __recreate (id SERIAL, schema text, object text, owner text, type text, ddl text, idargs text);
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

--
-- given schema.object, save all triggers for replay 
--
CREATE OR REPLACE FUNCTION schema_support.save_trigger_for_replay(
	schema varchar,
	object varchar,
	dropit boolean DEFAULT true
) RETURNS VOID AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;


--
-- given schema.object, look for all constraints to it outside of schema
--
CREATE OR REPLACE FUNCTION schema_support.save_constraint_for_replay(
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
--------------------------------------------------------------------
--- DONE: ddl/schema/pgsql/create_schema_support.sql
--------------------------------------------------------------------

---------- ========================================================= ----------
-- Begin dealing with actual maint.  The above is preliminary work.

SELECT schema_support.begin_maintenance();

drop trigger IF EXISTS trigger_dns_rec_a_type_validation ON dns_record;
drop function dns_rec_type_validation();

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
COMMENT ON COLUMN device_type_module.device_type_id IS 'Device Type of the Container Device (Chassis)';
COMMENT ON COLUMN device_type_module.device_type_module_name IS 'Name used to describe the module programatically.';
COMMENT ON COLUMN device_type_module.device_type_x_offset IS 'Horizontal offset from left to right';
COMMENT ON COLUMN device_type_module.device_type_y_offset IS 'Vertical offset from top to bottom';
COMMENT ON COLUMN device_type_module.device_type_z_offset IS 'Offset inside the device (front to back, yes, that is Z).  Only this or device_type_side may be set.';
COMMENT ON COLUMN device_type_module.device_type_side IS 'Only this or z_offset may be set.  Front or back of the chassis/container device_type';
-- INDEXES
CREATE INDEX xif1device_type_module ON device_type_module USING btree (device_type_id);

-- CHECK CONSTRAINTS
ALTER TABLE device_type_module ADD CONSTRAINT ckc_dt_mod_dt_side
	CHECK (device_type_side = ANY (ARRAY['FRONT'::bpchar, 'BACK'::bpchar]));

-- FOREIGN KEYS FROM
--#ALTER TABLE chassis_location
--#	ADD CONSTRAINT fk_chas_loc_dt_module
--#	FOREIGN KEY (chassis_device_type_id, device_type_module_name) REFERENCES device_type_module(device_type_id, device_type_module_name);

-- FOREIGN KEYS TO
ALTER TABLE device_type_module
	ADD CONSTRAINT fk_devt_mod_dev_type_id
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);

-- TRIGGERS
--- XXX trigger: trigger_device_type_module_sanity_set
--- XXX trigger: trigger_device_type_module_chassis_check
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device_type_module');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device_type_module');
-- DONE DEALING WITH TABLE device_type_module [2239225]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH NEW TABLE chassis_location
CREATE TABLE chassis_location
(
	chassis_location_id	integer NOT NULL,
	chassis_device_type_id	integer NOT NULL,
	device_type_module_name	varchar(255) NOT NULL,
	chassis_device_id	integer NOT NULL,
	module_device_type_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
create sequence chassis_location_chassis_location_id_seq;
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'chassis_location', true);
ALTER TABLE chassis_location
	ALTER chassis_location_id
	SET DEFAULT nextval('chassis_location_chassis_location_id_seq'::regclass);
ALTER SEQUENCE chassis_location_chassis_location_id_seq OWNED BY chassis_location.chassis_location_id;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE chassis_location ADD CONSTRAINT pk_chassis_location PRIMARY KEY (chassis_location_id);
ALTER TABLE chassis_location ADD CONSTRAINT ak_chass_dev_module_name UNIQUE (chassis_device_id, device_type_module_name);
ALTER TABLE chassis_location ADD CONSTRAINT ak_chass_loc_module_enforce UNIQUE (chassis_location_id, chassis_device_id, module_device_type_id);

-- Table/Column Comments
COMMENT ON COLUMN chassis_location.chassis_device_type_id IS 'Device Type of the Container Device (Chassis)';
COMMENT ON COLUMN chassis_location.device_type_module_name IS 'Name used to describe the module programatically.';
-- INDEXES
CREATE INDEX xif3chassis_location ON chassis_location USING btree (module_device_type_id);
CREATE INDEX xif4chassis_location ON chassis_location USING btree (chassis_device_id);
CREATE INDEX xif2chassis_location ON chassis_location USING btree (chassis_device_type_id, device_type_module_name);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
--#ALTER TABLE device
--#	ADD CONSTRAINT fk_chasloc_chass_devid
--#	FOREIGN KEY (chassis_location_id) REFERENCES chassis_location(chassis_location_id) DEFERRABLE;
--#ALTER TABLE device
--#	ADD CONSTRAINT fk_dev_chass_loc_id_mod_enfc
--#	FOREIGN KEY (chassis_location_id, parent_device_id, device_type_id) REFERENCES chassis_location(chassis_location_id, chassis_device_id, module_device_type_id) DEFERRABLE;

-- FOREIGN KEYS TO
ALTER TABLE chassis_location
	ADD CONSTRAINT fk_chass_loc_mod_dev_typ_id
	FOREIGN KEY (module_device_type_id) REFERENCES device_type(device_type_id);
ALTER TABLE chassis_location
	ADD CONSTRAINT fk_chass_loc_chass_devid
	FOREIGN KEY (chassis_device_id) REFERENCES device(device_id) DEFERRABLE;
ALTER TABLE chassis_location
	ADD CONSTRAINT fk_chas_loc_dt_module
	FOREIGN KEY (chassis_device_type_id, device_type_module_name) REFERENCES device_type_module(device_type_id, device_type_module_name);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'chassis_location');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'chassis_location');
-- DONE DEALING WITH TABLE chassis_location [2238693]
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
-- DEALING WITH TABLE location [2251838]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'location', 'rack_location');

-- A view will come back..
SELECT schema_support.save_grants_for_replay('jazzhands', 'location', 'location');

-- FOREIGN KEYS FROM
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_dev_location_id;

-- FOREIGN KEYS TO
ALTER TABLE location DROP CONSTRAINT IF EXISTS fk_location_ref_rack;
ALTER TABLE location DROP CONSTRAINT IF EXISTS fk_location_device_type_id;
ALTER TABLE location DROP CONSTRAINT IF EXISTS ak_uq_rack_offset_sid_location;
ALTER TABLE location DROP CONSTRAINT IF EXISTS pk_location_id;
-- INDEXES
DROP INDEX IF EXISTS xif2location;
-- CHECK CONSTRAINTS, etc
ALTER TABLE location DROP CONSTRAINT IF EXISTS ckc_rack_side_location;
-- TRIGGERS, etc
DROP TRIGGER trig_userlog_location ON location;
DROP TRIGGER trigger_audit_location ON location;
---- BEGIN audit.location TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "location_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
drop function perform_audit_location();
---- DONE audit.location TEARDOWN


ALTER SEQUENCE location_location_id_seq RENAME TO rack_location_rack_location_id_seq;
ALTER SEQUENCE audit.location_seq RENAME TO rack_location_seq;

ALTER TABLE location RENAME TO location_v56;
ALTER TABLE audit.location RENAME TO location_v56;

CREATE TABLE rack_location
(
	rack_location_id	integer NOT NULL,
	rack_id	integer NOT NULL,
	rack_u_offset_of_device_top	integer NULL,
	rack_side	varchar(10) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'rack_location', false);
INSERT INTO rack_location (
	rack_location_id,		-- new column (rack_location_id)
	rack_id,
	rack_u_offset_of_device_top,
	rack_side,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	location_id,		-- new column (rack_location_id)
	rack_id,
	rack_u_offset_of_device_top,
	rack_side,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM location_v56;

INSERT INTO audit.rack_location (
	rack_location_id,		-- new column (rack_location_id)
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
	location_id,		-- new column (rack_location_id)
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
FROM audit.location_v56;

ALTER TABLE rack_location
	ALTER rack_location_id
	SET DEFAULT nextval('rack_location_rack_location_id_seq'::regclass);
ALTER TABLE rack_location
	ALTER rack_side
	SET DEFAULT 'FRONT'::character varying;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE rack_location ADD CONSTRAINT pk_rack_location PRIMARY KEY (rack_location_id);
ALTER TABLE rack_location ADD CONSTRAINT ak_uq_rack_offset_sid_location UNIQUE (rack_id, rack_u_offset_of_device_top, rack_side);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE rack_location ADD CONSTRAINT ckc_rack_side_location
	CHECK (((rack_side)::text = ANY ((ARRAY['FRONT'::character varying, 'BACK'::character varying])::text[])) AND ((rack_side)::text = upper((rack_side)::text)));

-- FOREIGN KEYS FROM
ALTER TABLE device
	ADD CONSTRAINT fk_dev_legacy_location_id
	FOREIGN KEY (location_id) REFERENCES rack_location(rack_location_id);
--#ALTER TABLE device
--#	ADD CONSTRAINT fk_dev_rack_location_id
--#	FOREIGN KEY (rack_location_id) REFERENCES rack_location(rack_location_id);

-- FOREIGN KEYS TO
ALTER TABLE rack_location
	ADD CONSTRAINT fk_rk_location__rack_id
	FOREIGN KEY (rack_id) REFERENCES rack(rack_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'rack_location');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'rack_location');
ALTER SEQUENCE rack_location_rack_location_id_seq
	 OWNED BY rack_location.rack_location_id;
DROP TABLE IF EXISTS location_v56;
DROP TABLE IF EXISTS audit.location_v56;
-- DONE DEALING WITH TABLE rack_location [2240551]
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
-- DEALING WITH TABLE device_power_interface [2252043]
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
ALTER TABLE device_power_interface DROP CONSTRAINT IF EXISTS check_yes_no_2067088750;
-- TRIGGERS, etc
DROP TRIGGER trig_userlog_device_power_interface ON device_power_interface;
DROP TRIGGER trigger_audit_device_power_interface ON device_power_interface;
---- BEGIN audit.device_power_interface TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "device_power_interface_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.device_power_interface TEARDOWN


ALTER TABLE device_power_interface RENAME TO device_power_interface_v56;
ALTER TABLE audit.device_power_interface RENAME TO device_power_interface_v56;

CREATE TABLE device_power_interface
(
	device_id	integer NOT NULL,
	power_interface_port	varchar(20) NOT NULL,
	power_plug_style	varchar(50) NOT NULL,
	voltage	integer NOT NULL,
	max_amperage	integer NOT NULL,
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
	power_plug_style,	-- new column (power_plug_style)
	voltage,		-- new column (voltage)
	max_amperage,		-- new column (max_amperage)
	provides_power,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	dpi.device_id,
	dpi.power_interface_port,
	ppt.power_plug_style,		-- new column (power_plug_style)
	ppt.voltage,			-- new column (voltage)
	ppt.max_amperage,		-- new column (max_amperage)
	ppt.provides_power,
	dpi.data_ins_user,
	dpi.data_ins_date,
	dpi.data_upd_user,
	dpi.data_upd_date
FROM device_power_interface_v56 dpi
	left  join device using (device_id)
	left join device_type_power_port_templt ppt
		using (device_type_id, power_interface_port);

INSERT INTO audit.device_power_interface (
	device_id,
	power_interface_port,
	power_plug_style,		-- new column (power_plug_style)
	voltage,			-- new column (voltage)
	max_amperage,			-- new column (max_amperage)
	provides_power,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	dpi.device_id,
	dpi.power_interface_port,
	ppt.power_plug_style,		-- new column (power_plug_style)
	ppt.voltage,			-- new column (voltage)
	ppt.max_amperage,		-- new column (max_amperage)
	ppt.provides_power,
	dpi.data_ins_user,
	dpi.data_ins_date,
	dpi.data_upd_user,
	dpi.data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.device_power_interface_v56 dpi
	left  join device using (device_id)
	left join device_type_power_port_templt ppt
		using (device_type_id, power_interface_port);

ALTER TABLE device_power_interface
	ALTER provides_power
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device_power_interface ADD CONSTRAINT pk_device_power_interface PRIMARY KEY (device_id, power_interface_port);

-- Table/Column Comments
COMMENT ON COLUMN device_power_interface.power_plug_style IS 'Generally initialized from device_type_power_port_templt';
COMMENT ON COLUMN device_power_interface.voltage IS 'Generally initialized from device_type_power_port_templt';
COMMENT ON COLUMN device_power_interface.max_amperage IS 'Generally initialized from device_type_power_port_templt';
COMMENT ON COLUMN device_power_interface.provides_power IS 'Generally initialized from device_type_power_port_templt';
-- INDEXES
CREATE INDEX xif2device_power_interface ON device_power_interface USING btree (power_plug_style);

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
	ADD CONSTRAINT r_509
	FOREIGN KEY (power_plug_style) REFERENCES val_power_plug_style(power_plug_style);
ALTER TABLE device_power_interface
	ADD CONSTRAINT fk_device_device_power_supp
	FOREIGN KEY (device_id) REFERENCES device(device_id);

-- TRIGGERS
--- XXX trigger: trigger_device_power_port_sanity
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device_power_interface');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device_power_interface');
DROP TABLE IF EXISTS device_power_interface_v56;
DROP TABLE IF EXISTS audit.device_power_interface_v56;
-- DONE DEALING WITH TABLE device_power_interface [2239126]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE device_type [782786]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_type', 'device_type');

-- FOREIGN KEYS FROM
ALTER TABLE chassis_location DROP CONSTRAINT IF EXISTS fk_chass_loc_mod_dev_typ_id;
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
ALTER TABLE chassis_location
	ADD CONSTRAINT fk_chass_loc_mod_dev_typ_id
	FOREIGN KEY (module_device_type_id) REFERENCES device_type(device_type_id);

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
-- DEALING WITH TABLE device [2238303]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'device', 'device');

-- FOREIGN KEYS FROM
ALTER TABLE device_power_interface DROP CONSTRAINT IF EXISTS fk_device_device_power_supp;
ALTER TABLE device_note DROP CONSTRAINT IF EXISTS fk_device_note_device;
ALTER TABLE device_management_controller DROP CONSTRAINT IF EXISTS fk_dev_mgmt_ctlr_dev_id;
ALTER TABLE device_ssh_key DROP CONSTRAINT IF EXISTS fk_dev_ssh_key_ssh_key_id;
ALTER TABLE device_ticket DROP CONSTRAINT IF EXISTS fk_dev_tkt_dev_id;
ALTER TABLE static_route DROP CONSTRAINT IF EXISTS fk_statrt_devsrc_id;
ALTER TABLE snmp_commstr DROP CONSTRAINT IF EXISTS fk_snmpstr_device_id;
ALTER TABLE network_interface DROP CONSTRAINT IF EXISTS fk_netint_device_id;
ALTER TABLE device_management_controller DROP CONSTRAINT IF EXISTS fk_dvc_mgmt_ctrl_mgr_dev_id;
ALTER TABLE physical_port DROP CONSTRAINT IF EXISTS fk_phys_port_dev_id;
ALTER TABLE network_interface_purpose DROP CONSTRAINT IF EXISTS fk_netint_purpose_device_id;
ALTER TABLE device_collection_device DROP CONSTRAINT IF EXISTS fk_devcolldev_dev_id;
ALTER TABLE network_service DROP CONSTRAINT IF EXISTS fk_netsvc_device_id;
ALTER TABLE layer1_connection DROP CONSTRAINT IF EXISTS fk_l1conn_ref_device;

ALTER TABLE chassis_location DROP CONSTRAINT IF EXISTS fk_chass_loc_chass_devid;

-- FOREIGN KEYS TO
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_device_ref_voesymbtrk;
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_device_vownerstatus;
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_device_fk_voe;
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_device_fk_dev_v_svcenv;
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_dev_os_id;
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_dev_location_id;
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_device_fk_dev_val_stat;
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_device_dnsrecord;
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_device_reference_val_devi;
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_device_ref_parent_device;
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_dev_devtp_id;
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_device_site_code;
ALTER TABLE device DROP CONSTRAINT IF EXISTS pk_networkdevice;
-- INDEXES
DROP INDEX IF EXISTS idx_dev_osid;
DROP INDEX IF EXISTS idx_dev_ismonitored;
DROP INDEX IF EXISTS ix_netdev_devtype_id;
DROP INDEX IF EXISTS idx_device_type_location;
DROP INDEX IF EXISTS idx_dev_iddnsrec;
DROP INDEX IF EXISTS idx_dev_voeid;
DROP INDEX IF EXISTS xifdevice_sitecode;
DROP INDEX IF EXISTS idx_dev_dev_status;
DROP INDEX IF EXISTS idx_dev_islclymgd;
DROP INDEX IF EXISTS idx_dev_ownershipstatus;
DROP INDEX IF EXISTS xif13device;
DROP INDEX IF EXISTS idx_dev_svcenv;
DROP INDEX IF EXISTS idx_dev_locationid;
-- CHECK CONSTRAINTS, etc
ALTER TABLE device DROP CONSTRAINT IF EXISTS sys_c0069055;
ALTER TABLE device DROP CONSTRAINT IF EXISTS sys_c0069054;
ALTER TABLE device DROP CONSTRAINT IF EXISTS sys_c0069061;
ALTER TABLE device DROP CONSTRAINT IF EXISTS sys_c0069060;
ALTER TABLE device DROP CONSTRAINT IF EXISTS ckc_should_fetch_conf_device;
ALTER TABLE device DROP CONSTRAINT IF EXISTS ckc_is_virtual_device_device;
ALTER TABLE device DROP CONSTRAINT IF EXISTS sys_c0069057;
ALTER TABLE device DROP CONSTRAINT IF EXISTS sys_c0069051;
ALTER TABLE device DROP CONSTRAINT IF EXISTS ckc_is_locally_manage_device;
ALTER TABLE device DROP CONSTRAINT IF EXISTS ckc_is_baselined_device;
ALTER TABLE device DROP CONSTRAINT IF EXISTS sys_c0069052;
ALTER TABLE device DROP CONSTRAINT IF EXISTS sys_c0069056;
ALTER TABLE device DROP CONSTRAINT IF EXISTS ckc_is_monitored_device;
ALTER TABLE device DROP CONSTRAINT IF EXISTS sys_c0069059;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_device_update_location_fix ON device;
DROP TRIGGER IF EXISTS trigger_verify_device_voe ON device;
DROP TRIGGER IF EXISTS trig_userlog_device ON device;
DROP TRIGGER IF EXISTS trigger_audit_device ON device;
DROP TRIGGER IF EXISTS trigger_update_per_device_device_collection ON device;
DROP TRIGGER IF EXISTS trigger_delete_per_device_device_collection ON device;
---- BEGIN audit.device TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS audit."device_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.device TEARDOWN


ALTER TABLE device RENAME TO device_v56;
ALTER TABLE audit.device RENAME TO device_v56;

CREATE TABLE device
(
	device_id	integer NOT NULL,
	device_type_id	integer NOT NULL,
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
	location_id	integer  NULL,
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
INSERT INTO device (
	device_id,
	device_type_id,
	device_name,
	site_code,
	identifying_dns_record_id,
	serial_number,
	part_number,
	host_id,
	physical_label,
	asset_tag,
	rack_location_id,		-- new column (rack_location_id)
	chassis_location_id,		-- new column (chassis_location_id)
	location_id,
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
	device_name,
	site_code,
	identifying_dns_record_id,
	serial_number,
	part_number,
	host_id,
	physical_label,
	asset_tag,
	location_id,		-- new column (rack_location_id)
	NULL,		-- new column (chassis_location_id)
	location_id,
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
FROM device_v56;

INSERT INTO audit.device (
	device_id,
	device_type_id,
	device_name,
	site_code,
	identifying_dns_record_id,
	serial_number,
	part_number,
	host_id,
	physical_label,
	asset_tag,
	rack_location_id,		-- new column (rack_location_id)
	chassis_location_id,		-- new column (chassis_location_id)
	location_id,
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
	device_name,
	site_code,
	identifying_dns_record_id,
	serial_number,
	part_number,
	host_id,
	physical_label,
	asset_tag,
	location_id,		-- new column (rack_location_id)
	NULL,		-- new column (chassis_location_id)
	location_id,
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
FROM audit.device_v56;

ALTER TABLE device
	ALTER device_id
	SET DEFAULT nextval('device_device_id_seq'::regclass);
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
ALTER TABLE device ADD CONSTRAINT pk_device PRIMARY KEY (device_id);
ALTER TABLE device ADD CONSTRAINT ak_device_chassis_location_id UNIQUE (chassis_location_id);
ALTER TABLE device ADD CONSTRAINT ak_device_rack_location_id UNIQUE (rack_location_id);

-- Table/Column Comments
COMMENT ON COLUMN device.location_id IS 'Legacy LOCATION_ID.  THIS COLUMN WILL BE DROPPED IN THE NEXT RELEASE!';
-- INDEXES
CREATE INDEX xifdevice_sitecode ON device USING btree (site_code);
CREATE INDEX xif16device ON device USING btree (chassis_location_id, parent_device_id, device_type_id);
CREATE INDEX idx_dev_islclymgd ON device USING btree (is_locally_managed);
CREATE INDEX idx_dev_dev_status ON device USING btree (device_status);
CREATE INDEX idx_dev_ismonitored ON device USING btree (is_monitored);
CREATE INDEX idx_dev_osid ON device USING btree (operating_system_id);
CREATE INDEX idx_device_type_location ON device USING btree (device_type_id, location_id);
CREATE INDEX ix_netdev_devtype_id ON device USING btree (device_type_id);
CREATE INDEX idx_dev_iddnsrec ON device USING btree (identifying_dns_record_id);
CREATE INDEX idx_dev_voeid ON device USING btree (voe_id);
CREATE INDEX xif13device ON device USING btree (location_id);
CREATE INDEX idx_dev_svcenv ON device USING btree (service_environment);
CREATE INDEX idx_dev_ownershipstatus ON device USING btree (ownership_status);

-- CHECK CONSTRAINTS
ALTER TABLE device ADD CONSTRAINT ckc_is_monitored_device
	CHECK ((is_monitored = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_monitored)::text = upper((is_monitored)::text)));
ALTER TABLE device ADD CONSTRAINT sys_c0069056
	CHECK (ownership_status IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069059
	CHECK (is_virtual_device IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT ckc_is_locally_manage_device
	CHECK ((is_locally_managed = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_locally_managed)::text = upper((is_locally_managed)::text)));
ALTER TABLE device ADD CONSTRAINT sys_c0069051
	CHECK (device_id IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT ckc_is_baselined_device
	CHECK ((is_baselined = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_baselined)::text = upper((is_baselined)::text)));
ALTER TABLE device ADD CONSTRAINT sys_c0069052
	CHECK (device_type_id IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT ckc_should_fetch_conf_device
	CHECK ((should_fetch_config = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((should_fetch_config)::text = upper((should_fetch_config)::text)));
ALTER TABLE device ADD CONSTRAINT sys_c0069060
	CHECK (should_fetch_config IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069057
	CHECK (is_monitored IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT ckc_is_virtual_device_device
	CHECK ((is_virtual_device = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_virtual_device)::text = upper((is_virtual_device)::text)));
ALTER TABLE device ADD CONSTRAINT sys_c0069055
	CHECK (operating_system_id IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069054
	CHECK (service_environment IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069061
	CHECK (is_baselined IS NOT NULL);

-- FOREIGN KEYS FROM
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE layer1_connection
	ADD CONSTRAINT fk_l1conn_ref_device
	FOREIGN KEY (tcpsrv_device_id) REFERENCES device(device_id);
ALTER TABLE device_collection_device
	ADD CONSTRAINT fk_devcolldev_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE network_interface_purpose
	ADD CONSTRAINT fk_netint_purpose_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE static_route
	ADD CONSTRAINT fk_statrt_devsrc_id
	FOREIGN KEY (device_src_id) REFERENCES device(device_id);
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE snmp_commstr
	ADD CONSTRAINT fk_snmpstr_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE device_management_controller
	ADD CONSTRAINT fk_dvc_mgmt_ctrl_mgr_dev_id
	FOREIGN KEY (manager_device_id) REFERENCES device(device_id);
ALTER TABLE physical_port
	ADD CONSTRAINT fk_phys_port_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE device_ticket
	ADD CONSTRAINT fk_dev_tkt_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE device_note
	ADD CONSTRAINT fk_device_note_device
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE chassis_location
	ADD CONSTRAINT fk_chass_loc_chass_devid
	FOREIGN KEY (chassis_device_id) REFERENCES device(device_id) DEFERRABLE;
ALTER TABLE device_ssh_key
	ADD CONSTRAINT fk_dev_ssh_key_ssh_key_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE device_management_controller
	ADD CONSTRAINT fk_dev_mgmt_ctlr_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE device_power_interface
	ADD CONSTRAINT fk_device_device_power_supp
	FOREIGN KEY (device_id) REFERENCES device(device_id);

-- FOREIGN KEYS TO
ALTER TABLE device
	ADD CONSTRAINT fk_device_reference_val_devi
	FOREIGN KEY (auto_mgmt_protocol) REFERENCES val_device_auto_mgmt_protocol(auto_mgmt_protocol);
ALTER TABLE device
	ADD CONSTRAINT fk_device_dnsrecord
	FOREIGN KEY (identifying_dns_record_id) REFERENCES dns_record(dns_record_id);
ALTER TABLE device
	ADD CONSTRAINT fk_dev_chass_loc_id_mod_enfc
	FOREIGN KEY (chassis_location_id, parent_device_id, device_type_id) REFERENCES chassis_location(chassis_location_id, chassis_device_id, module_device_type_id) DEFERRABLE;
ALTER TABLE device
	ADD CONSTRAINT fk_device_site_code
	FOREIGN KEY (site_code) REFERENCES site(site_code);
ALTER TABLE device
	ADD CONSTRAINT fk_dev_devtp_id
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);
ALTER TABLE device
	ADD CONSTRAINT fk_chasloc_chass_devid
	FOREIGN KEY (chassis_location_id) REFERENCES chassis_location(chassis_location_id) DEFERRABLE;
ALTER TABLE device
	ADD CONSTRAINT fk_device_ref_parent_device
	FOREIGN KEY (parent_device_id) REFERENCES device(device_id);
ALTER TABLE device
	ADD CONSTRAINT fk_device_fk_voe
	FOREIGN KEY (voe_id) REFERENCES voe(voe_id);
ALTER TABLE device
	ADD CONSTRAINT fk_device_vownerstatus
	FOREIGN KEY (ownership_status) REFERENCES val_ownership_status(ownership_status);
ALTER TABLE device
	ADD CONSTRAINT fk_device_ref_voesymbtrk
	FOREIGN KEY (voe_symbolic_track_id) REFERENCES voe_symbolic_track(voe_symbolic_track_id);
ALTER TABLE device
	ADD CONSTRAINT fk_dev_rack_location_id
	FOREIGN KEY (rack_location_id) REFERENCES rack_location(rack_location_id);
ALTER TABLE device
	ADD CONSTRAINT fk_device_fk_dev_val_stat
	FOREIGN KEY (device_status) REFERENCES val_device_status(device_status);
ALTER TABLE device
	ADD CONSTRAINT fk_dev_legacy_location_id
	FOREIGN KEY (location_id) REFERENCES rack_location(rack_location_id);
ALTER TABLE device
	ADD CONSTRAINT fk_dev_os_id
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);
ALTER TABLE device
	ADD CONSTRAINT fk_device_fk_dev_v_svcenv
	FOREIGN KEY (service_environment) REFERENCES service_environment(service_environment);

-- TRIGGERS
--- XXX trigger: trigger_aaa_device_location_migration_1
--- XXX trigger: trigger_device_one_location_validate
--- XXX trigger: trigger_device_update_location_fix
--- XXX trigger: trigger_aaa_device_location_migration_2
--- XXX trigger: trigger_verify_device_voe
--- XXX trigger: trigger_delete_per_device_device_collection
--- XXX trigger: trigger_update_per_device_device_collection
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device');
ALTER SEQUENCE device_device_id_seq
	 OWNED BY device.device_id;
DROP TABLE IF EXISTS device_v56;
DROP TABLE IF EXISTS audit.device_v56;
-- DONE DEALING WITH TABLE device [2238838]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH proc manipulate_netblock_parentage_before -> manipulate_netblock_parentage_before 

-- Save grants for later reapplication
-- SELECT schema_support.save_grants_for_replay('jazzhands', 'manipulate_netblock_parentage_before', 'manipulate_netblock_parentage_before');

-- DROP OLD FUNCTION
-- consider old oid 1495702
-- DROP FUNCTION IF EXISTS manipulate_netblock_parentage_before();

-- RECREATE FUNCTION
-- consider NEW oid 1479478
CREATE OR REPLACE FUNCTION jazzhands.manipulate_netblock_parentage_before()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$

DECLARE
	nbtype				record;
	v_netblock_type		val_netblock_type.netblock_type%TYPE;
BEGIN
	/*
	 * Get the parameters for the given netblock type to see if we need
	 * to do anything
	 */

	RAISE DEBUG 'Performing % on netblock %', TG_OP, NEW.netblock_id;

	SELECT * INTO nbtype FROM val_netblock_type WHERE
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
			netblock
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
			netblock
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
 SET search_path=jazzhands
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
 SET search_path=jazzhands
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

ALTER FUNCTION automated_ac() SET search_path = jazzhands;

-- DONE WITH proc automated_ac -> automated_ac 
--------------------------------------------------------------------




--------------------------------------------------------------------
-- DEALING WITH proc automated_ac_on_person -> automated_ac_on_person 

ALTER FUNCTION automated_ac_on_person() set search_path=jazzhands;

-- DONE WITH proc automated_ac_on_person -> automated_ac_on_person 
--------------------------------------------------------------------



--------------------------------------------------------------------
-- DEALING WITH proc automated_ac_on_person_company -> automated_ac_on_person_company 

ALTER FUNCTION automated_ac_on_person_company() set search_path=jazzhands;

-- DONE WITH proc automated_ac_on_person_company -> automated_ac_on_person_company 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc automated_realm_site_ac_pl -> automated_realm_site_ac_pl 

ALTER FUNCTION automated_realm_site_ac_pl() set search_path=jazzhands;

-- DONE WITH proc automated_realm_site_ac_pl -> automated_realm_site_ac_pl 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc check_person_image_usage_mv -> check_person_image_usage_mv 

ALTER FUNCTION jazzhands.check_person_image_usage_mv()
	SET search_path=jazzhands;

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
-- DEALING WITH proc delete_peruser_account_collection -> delete_peruser_account_collection 

-- Save grants for later reapplication
-- SELECT schema_support.save_grants_for_replay('jazzhands', 'delete_peruser_account_collection', 'delete_peruser_account_collection');

-- DROP OLD FUNCTION
-- consider old oid 1495682
-- DROP FUNCTION IF EXISTS delete_peruser_account_collection();

-- RECREATE FUNCTION
-- consider NEW oid 1479458
CREATE OR REPLACE FUNCTION jazzhands.delete_peruser_account_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	def_acct_rlm	account_realm.account_realm_id%TYPE;
	acid			account_collection.account_collection_id%TYPE;
BEGIN
	IF TG_OP = 'DELETE' THEN
		SELECT	account_realm_id
		  INTO	def_acct_rlm
		  FROM	account_realm_company
		 WHERE	company_id IN
		 		(select property_value_company_id
				   from property
				  where	property_name = '_rootcompanyid'
				    and	property_type = 'Defaults'
				);
		IF def_acct_rlm is not NULL AND OLD.account_realm_id = def_acct_rlm THEN
				SELECT	account_collection_id 
				  FROM	account_collection
				  INTO	acid
				 WHERE	account_collection_name = OLD.login
				   AND	account_collection_type = 'per-user';
	
				 DELETE from account_collection_account
				  where account_collection_id = acid;
	
				 DELETE from account_collection
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

ALTER FUNCTION propagate_person_status_to_account()
	SET search_path=jazzhands;

-- DONE WITH proc propagate_person_status_to_account -> propagate_person_status_to_account 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc update_account_type_account_collection -> update_account_type_account_collection 

ALTER FUNCTION jazzhands.update_account_type_account_collection()
	set search_path=jazzhands;

-- DONE WITH proc update_account_type_account_collection -> update_account_type_account_collection 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc update_per_svc_env_svc_env_collection -> update_per_svc_env_svc_env_collection 

ALTER FUNCTION update_per_svc_env_svc_env_collection()
	set search_path=jazzhands;

-- DONE WITH proc update_per_svc_env_svc_env_collection -> update_per_svc_env_svc_env_collection 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc update_peruser_account_collection -> update_peruser_account_collection 

-- Save grants for later reapplication
-- SELECT schema_support.save_grants_for_replay('jazzhands', 'update_peruser_account_collection', 'update_peruser_account_collection');

-- DROP OLD FUNCTION
-- consider old oid 1495684
-- DROP FUNCTION IF EXISTS update_peruser_account_collection();

-- RECREATE FUNCTION
-- consider NEW oid 1479460
CREATE OR REPLACE FUNCTION jazzhands.update_peruser_account_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	def_acct_rlm	account_realm.account_realm_id%TYPE;
	acid			account_collection.account_collection_id%TYPE;
BEGIN
	SELECT	account_realm_id
	  INTO	def_acct_rlm
	  FROM	account_realm_company
	 WHERE	company_id IN
	 		(select property_value_company_id
			   from property
			  where	property_name = '_rootcompanyid'
			    and	property_type = 'Defaults'
			);
	IF def_acct_rlm is not NULL AND NEW.account_realm_id = def_acct_rlm THEN
		if TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.account_realm_id != NEW.account_realm_id) THEN
			insert into account_collection 
				(account_collection_name, account_collection_type)
			values
				(NEW.login, 'per-user')
			RETURNING account_collection_id INTO acid;
			insert into account_collection_account 
				(account_collection_id, account_id)
			VALUES
				(acid, NEW.account_id);
		END IF;

		IF TG_OP = 'UPDATE' AND OLD.login != NEW.login THEN
			IF OLD.account_realm_id = NEW.account_realm_id THEN
				update	account_collection
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
		      FROM	account_collection
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
-- DEALING WITH proc delete_per_svc_env_svc_env_collection -> delete_per_svc_env_svc_env_collection 

ALTER FUNCTION delete_per_svc_env_svc_env_collection()
	set search_path=jazzhands;

-- DONE WITH proc delete_per_svc_env_svc_env_collection -> delete_per_svc_env_svc_env_collection 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc update_per_device_device_collection -> update_per_device_device_collection 

-- Save grants for later reapplication
-- SELECT schema_support.save_grants_for_replay('jazzhands', 'update_per_device_device_collection', 'update_per_device_device_collection');

-- DROP OLD FUNCTION
-- consider old oid 1495713
-- DROP FUNCTION IF EXISTS update_per_device_device_collection();

-- RECREATE FUNCTION
-- consider NEW oid 1479495
CREATE OR REPLACE FUNCTION jazzhands.update_per_device_device_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	dcid		device_collection.device_collection_id%TYPE;
	newname		device_collection.device_collection_name%TYPE;
BEGIN
	IF NEW.device_name IS NOT NULL THEN
		newname = NEW.device_name || '_' || NEW.device_id;
	ELSE
		newname = 'per_d_dc_contrived_' || NEW.device_id;
	END IF;

	IF TG_OP = 'INSERT' THEN
		insert into device_collection
			(device_collection_name, device_collection_type)
		values
			(newname, 'per-device')
		RETURNING device_collection_id INTO dcid;
		insert into device_collection_device
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
			  FROM	device_collection_device
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
-- DEALING WITH proc validate_property -> validate_property 


-- RECREATE FUNCTION
-- consider NEW oid 1539445
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
-- DEALING WITH proc verify_layer1_connection -> verify_layer1_connection 


-- RECREATE FUNCTION
-- consider NEW oid 1572988
CREATE OR REPLACE FUNCTION jazzhands.verify_layer1_connection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	PERFORM 1 FROM 
		layer1_connection l1 
			JOIN layer1_connection l2 ON 
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
-- DEALING WITH proc verify_physical_connection -> verify_physical_connection 

-- RECREATE FUNCTION
-- consider NEW oid 1572990
CREATE OR REPLACE FUNCTION jazzhands.verify_physical_connection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	PERFORM 1 FROM 
		physical_connection l1 
		JOIN physical_connection l2 ON 
			l1.physical_port1_id = l2.physical_port2_id AND
			l1.physical_port2_id = l2.physical_port1_id;
	IF FOUND THEN
		RAISE EXCEPTION 'Connection already exists in opposite direction';
	END IF;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc verify_physical_connection -> verify_physical_connection 
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
-- DEALING WITH proc verify_device_voe -> verify_device_voe 

-- RECREATE FUNCTION
-- consider NEW oid 1560064
CREATE OR REPLACE FUNCTION jazzhands.verify_device_voe()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	voe_sw_pkg_repos		sw_package_repository.sw_package_repository_id%TYPE;
	os_sw_pkg_repos		operating_system.sw_package_repository_id%TYPE;
	voe_sym_trx_sw_pkg_repo_id	voe_symbolic_track.sw_package_repository_id%TYPE;
BEGIN

	IF (NEW.operating_system_id IS NOT NULL)
	THEN
		SELECT sw_package_repository_id INTO os_sw_pkg_repos
			FROM
				operating_system
			WHERE
				operating_system_id = NEW.operating_system_id;
	END IF;

	IF (NEW.voe_id IS NOT NULL) THEN
		SELECT sw_package_repository_id INTO voe_sw_pkg_repos
			FROM
				voe
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
				voe_symbolic_track
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
-- BEGIN with adding ddl/schema/pgsql/create_dns_triggers.sql
--------------------------------------------------------------------

/*
 * Copyright (c) 2012-2014 Todd Kover
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

CREATE OR REPLACE FUNCTION dns_rec_before() 
RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'DELETE' THEN
		PERFORM 1 FROM dns_domain WHERE dns_domain_id IN (
		    OLD.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id)
		)
		FOR UPDATE;

		RETURN OLD;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.netblock_id IS NOT NULL THEN
			PERFORM 1 FROM dns_domain WHERE dns_domain_id IN (
		    	NEW.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
			) FOR UPDATE;
		END IF;

		RETURN NEW;
	ELSE
		IF OLD.netblock_id IS DISTINCT FROM NEW.netblock_id THEN
			IF OLD.netblock_id IS NOT NULL THEN
				PERFORM 1 FROM dns_domain WHERE dns_domain_id IN (
			    	OLD.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id))
				FOR UPDATE;
			END IF;
			IF NEW.netblock_id IS NOT NULL THEN
				PERFORM 1 FROM dns_domain WHERE dns_domain_id IN (
			    	NEW.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
				)
				FOR UPDATE;
			END IF;
		ELSE
			IF NEW.netblock_id IS NOT NULL THEN
				PERFORM 1 FROM dns_domain WHERE dns_domain_id IN (
			    	NEW.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
				) FOR UPDATE;
			END IF;
		END IF;

		RETURN NEW;
	END IF;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_rec_before ON dns_record;
CREATE TRIGGER trigger_dns_rec_before 
	BEFORE INSERT OR DELETE OR UPDATE 
	ON dns_record 
	FOR EACH ROW
	EXECUTE PROCEDURE dns_rec_before();

CREATE OR REPLACE FUNCTION update_dns_zone() 
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
		UPDATE dns_domain SET zone_last_updated = clock_timestamp()
	    WHERE dns_domain_id = NEW.dns_domain_id
			AND ( zone_last_updated < last_generated
			OR zone_last_updated is NULL);

		IF TG_OP = 'UPDATE' THEN
			IF OLD.dns_domain_id != NEW.dns_domain_id THEN
				UPDATE dns_domain SET zone_last_updated = clock_timestamp()
					 WHERE dns_domain_id = OLD.dns_domain_id
					 AND ( zone_last_updated < last_generated or zone_last_updated is NULL );
			END IF;
			IF NEW.netblock_id != OLD.netblock_id THEN
				UPDATE dns_domain SET zone_last_updated = clock_timestamp()
					 WHERE dns_domain_id in (
						 netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id),
						 netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
					)
				     AND ( zone_last_updated < last_generated or zone_last_updated is NULL );
			END IF;
		ELSIF TG_OP = 'INSERT' AND NEW.netblock_id is not NULL THEN
			UPDATE dns_domain SET zone_last_updated = clock_timestamp()
				WHERE dns_domain_id = 
					netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
				AND ( zone_last_updated < last_generated or zone_last_updated is NULL );

		END IF;
	END IF;

    IF TG_OP = 'DELETE' THEN
	UPDATE dns_domain SET zone_last_updated = clock_timestamp()
			WHERE dns_domain_id = OLD.dns_domain_id
			AND ( zone_last_updated < last_generated or zone_last_updated is NULL );

		IF OLD.dns_type = 'A' OR OLD.dns_type = 'AAAA' THEN
			UPDATE dns_domain SET zone_last_updated = clock_timestamp()
		 WHERE  dns_domain_id = netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id)
				 AND ( zone_last_updated < last_generated or zone_last_updated is NULL );
	END IF;
    END IF;
	RETURN NEW;
END;
$$ 
LANGUAGE plpgsql 
SET search_path=jazzhands
SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_dns_zone ON dns_record;
CREATE CONSTRAINT TRIGGER trigger_update_dns_zone 
	AFTER INSERT OR DELETE OR UPDATE 
	ON dns_record 
	INITIALLY DEFERRED
	FOR EACH ROW 
	EXECUTE PROCEDURE update_dns_zone();

---------------------------------------------------------------------------

--
-- This shall replace all the aforementioned triggers
--

CREATE OR REPLACE FUNCTION dns_record_update_nontime() 
RETURNS TRIGGER AS $$
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
		END IF;
		_mkdom := true;

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
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_record_update_nontime ON dns_record;
CREATE TRIGGER trigger_dns_record_update_nontime 
	AFTER INSERT OR UPDATE OR DELETE
	ON dns_record 
	FOR EACH ROW 
	EXECUTE PROCEDURE dns_record_update_nontime();

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION dns_a_rec_validation() RETURNS TRIGGER AS $$
DECLARE
	_ip		netblock.ip_address%type;
BEGIN
	IF NEW.dns_type in ('A', 'AAAA') AND NEW.netblock_id IS NULL THEN
		RAISE EXCEPTION 'Attempt to set % record without a Netblock',
			NEW.dns_type
			USING ERRCODE = 'not_null_violation';
	END IF;

	IF NEW.netblock_Id is not NULL and 
			( NEW.dns_value IS NOT NULL OR NEW.dns_value_record_id IS NOT NULL ) THEN
		RAISE EXCEPTION 'Both dns_value and netblock_id may not be set'
			USING ERRCODE = 'JH001';
	END IF;

	IF NEW.dns_value IS NOT NULL AND NEW.dns_value_record_id IS NOT NULL THEN
		RAISE EXCEPTION 'Both dns_value and dns_value_record_id may not be set'
			USING ERRCODE = 'JH001';
	END IF;

	IF NEW.netblock_id IS NOT NULL AND NEW.dns_value_record_id IS NOT NULL THEN
		RAISE EXCEPTION 'Both netblock_id and dns_value_record_id may not be set'
			USING ERRCODE = 'JH001';
	END IF;

	-- XXX need to deal with changing a netblock type and breaking dns_record.. 
	IF NEW.netblock_id IS NOT NULL THEN
		SELECT ip_address 
		  INTO _ip 
		  FROM netblock
		 WHERE netblock_id = NEW.netblock_id;

		IF NEW.dns_type = 'A' AND family(_ip) != '4' THEN
			RAISE EXCEPTION 'A records must be assigned to non-IPv4 records'
				USING ERRCODE = 'JH200';
		END IF;

		IF NEW.dns_type = 'AAAA' AND family(_ip) != '6' THEN
			RAISE EXCEPTION 'AAAA records must be assigned to non-IPv6 records'
				USING ERRCODE = 'JH200';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_a_rec_validation ON dns_record;
CREATE TRIGGER trigger_dns_a_rec_validation 
	BEFORE INSERT OR UPDATE 
	ON dns_record 
	FOR EACH ROW 
	EXECUTE PROCEDURE dns_a_rec_validation();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_non_a_rec_validation() RETURNS TRIGGER AS $$
DECLARE
	_ip		netblock.ip_address%type;
BEGIN
	IF NEW.dns_type NOT in ('A', 'AAAA') AND NEW.dns_value IS NULL THEN
		RAISE EXCEPTION 'Attempt to set % record without a value',
			NEW.dns_type
			USING ERRCODE = 'not_null_violation';
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_non_a_rec_validation ON dns_record;
CREATE TRIGGER trigger_dns_non_a_rec_validation 
	BEFORE INSERT OR UPDATE 
	ON dns_record 
	FOR EACH ROW 
	EXECUTE PROCEDURE dns_non_a_rec_validation();

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION dns_rec_prevent_dups() 
RETURNS TRIGGER AS $$
DECLARE
	_tally	INTEGER;
BEGIN
	-- should not be able to insert the same record(s) twice
	SELECT	count(*)
	  INTO	_tally
	  FROM	dns_record
	  WHERE
	  		( dns_name = NEW.dns_name OR 
				(DNS_name IS NULL AND NEW.dns_name is NULL)
			)
		AND
	  		( dns_domain_id = NEW.dns_domain_id )
		AND
	  		( dns_class = NEW.dns_class )
		AND
	  		( dns_type = NEW.dns_type )
		AND 
	  		( dns_value = NEW.dns_value OR 
				(dns_value IS NULL and NEW.dns_value is NULL)
			)
		AND
	  		( netblock_id = NEW.netblock_id OR 
				(netblock_id IS NULL AND NEW.netblock_id is NULL)
			)
		AND	is_enabled = 'Y'
	    AND dns_record_id != NEW.dns_record_id
	;

	IF _tally != 0 THEN
		RAISE EXCEPTION 'Attempt to insert the same dns record'
			USING ERRCODE = 'unique_violation';
	END IF;

	IF NEW.DNS_TYPE = 'A' OR NEW.DNS_TYPE = 'AAAA' THEN
		IF NEW.SHOULD_GENERATE_PTR = 'Y' THEN
			SELECT	count(*)
			 INTO	_tally
			 FROM	dns_record
			WHERE dns_class = 'IN' 
			AND dns_type = 'A' 
			AND should_generate_ptr = 'Y'
			AND is_enabled = 'Y'
			AND netblock_id = NEW.NETBLOCK_ID
			AND dns_record_id != NEW.DNS_RECORD_ID;
	
			IF _tally != 0 THEN
				RAISE EXCEPTION 'May not have more than one SHOULD_GENERATE_PTR record on the same IP on netblock_id %', NEW.netblock_id
					USING ERRCODE = 'JH201';
			END IF;
		END IF;
	END IF;

	RETURN NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_rec_prevent_dups ON dns_record;
CREATE TRIGGER trigger_dns_rec_prevent_dups 
	BEFORE INSERT OR UPDATE 
	ON dns_record 
	FOR EACH ROW 
	EXECUTE PROCEDURE dns_rec_prevent_dups();
---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_domain_trigger_change()
RETURNS TRIGGER AS $$
BEGIN
	IF new.SHOULD_GENERATE = 'Y' THEN
		insert into DNS_CHANGE_RECORD
			(dns_domain_id) VALUES (NEW.dns_domain_id);
	END IF;	
	RETURN NEW;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_domain_trigger_change ON dns_domain;
CREATE TRIGGER trigger_dns_domain_trigger_change 
	AFTER INSERT OR UPDATE OF soa_name, soa_class, soa_ttl, 
		soa_refresh, soa_retry, soa_expire, soa_minimum, soa_mname,
		soa_rname, should_generate
	ON dns_domain 
	FOR EACH ROW
	EXECUTE PROCEDURE dns_domain_trigger_change();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_change_record_pgnotify()
RETURNS TRIGGER AS $$
BEGIN
	NOTIFY dns_zone_gen;
	RETURN NEW;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_change_record_pgnotify ON dns_change_record;
CREATE TRIGGER trigger_dns_change_record_pgnotify 
	AFTER INSERT OR UPDATE 
	ON dns_change_record 
	EXECUTE PROCEDURE dns_change_record_pgnotify();

--------------------------------------------------------------------
-- END with adding ddl/schema/pgsql/create_dns_triggers.sql
--------------------------------------------------------------------


--------------------------------------------------------------------
-- BEGIN with adding ddl/schema/pgsql/create_device_type_triggers.sql
--------------------------------------------------------------------

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


-- These next two triggers go away with device.location_id does.

--
-- This trigger enforces that new inserts only set one of location_id or
-- rack_location_id
--
-- It also enforces that if something updates rack_location_id that  it does
-- not also update location_id.
CREATE OR REPLACE FUNCTION aaa_device_location_migration_2() 
RETURNS TRIGGER AS $$
DECLARE
BEGIN
	IF TG_OP = 'INSERT' THEN
		IF NEW.rack_location_id is not null and NEW.location_id is NOT NULL THEN
			RAISE EXCEPTION 'Only rack_location_id should be set.  Location_Id is going away.'
				USING ERRCODE = 'JH0FF';
		ELSIF NEW.rack_location_id IS NOT NULL OR NEW.location_Id IS NOT NULL THEN
			IF NEW.rack_location_id IS NULL THEN
				NEW.rack_location_id = NEW.location_id;
			ELSIF NEW.location_id IS NULL THEN
				NEW.location_id = NEW.rack_location_id;
			ELSE
				RAISE EXCEPTION 'This shold never happen';
			END IF;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		if OLD.RACK_LOCATION_ID != NEW.RACK_LOCATION_ID THEN
			IF NEW.LOCATION_ID != OLD.LOCATION_ID THEN
				RAISE EXCEPTION 'Only rack_location_id should be set.  Location_Id is going away.'
					USING ERRCODE = 'JH0FF';
			END IF;
			NEW.RACK_LOCATION_ID := NEW.LOCATION_ID;
		END IF;
	END IF;

	RETURN NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_aaa_device_location_migration_2 ON device;
CREATE TRIGGER trigger_aaa_device_location_migration_2 
	BEFORE INSERT OR UPDATE of RACK_LOCATION_ID
	ON device 
	FOR EACH ROW
	EXECUTE PROCEDURE aaa_device_location_migration_2();


-- This ensures that if someone is updating location_id that they are not
-- also updating rack_location_id.  It runs before the previous trigger, but it
-- provides a similar sanity chek as the update clause of there.
CREATE OR REPLACE FUNCTION aaa_device_location_migration_1() 
RETURNS TRIGGER AS $$
DECLARE
BEGIN
	-- If location_id did not really change, then there is nothing to do here,
	-- although it is fishy
	if OLD.LOCATION_ID != NEW.LOCATION_ID THEN
		IF NEW.LOCATION_ID = NEW.RACK_LOCATION_ID THEN
			RAISE EXCEPTION 'Only rack_location_id should be set.  Location_Id is going away.'
				USING ERRCODE = 'JH0FF';
		END IF;
		NEW.RACK_LOCATION_ID := NEW.LOCATION_ID;
	else
		RAISE NOTICE 'aaa_device_location_migration_1 called for no apparent reason. This is fishy';
	END IF;
	return NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_aaa_device_location_migration_1 ON device;
CREATE TRIGGER trigger_aaa_device_location_migration_1 
	BEFORE UPDATE of LOCATION_ID
	ON device 
	FOR EACH ROW
	EXECUTE PROCEDURE aaa_device_location_migration_1();


----------------------------------------------------------------------------
----------------------------------------------------------------------------
----------------------------------------------------------------------------
-- 
-- column retirement triggers above, below, not so much.
--
----------------------------------------------------------------------------
----------------------------------------------------------------------------
----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION device_one_location_validate() 
RETURNS TRIGGER AS $$
DECLARE
BEGIN
	IF NEW.RACK_LOCATION_ID IS NOT NULL AND NEW.CHASSIS_LOCATION_ID IS NOT NULL THEN
		RAISE EXCEPTION 'Both Rack_Location_Id and Chassis_Location_Id may not be set.'
			USING ERRCODE = 'unique_violation';
	END IF;

	IF NEW.CHASSIS_LOCATION_ID IS NOT NULL AND NEW.PARENT_DEVICE_ID IS NULL THEN
		RAISE EXCEPTION 'Must set parent_device_id if setting chassis location.'
			USING ERRCODE = 'foreign_key_violation';
	END IF;
	RETURN NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_one_location_validate ON device;
CREATE TRIGGER trigger_device_one_location_validate 
	BEFORE INSERT OR UPDATE -- OF RACK_LOCATION_ID, CHASSIS_LOCATION_ID, PARENT_DEVICE_ID
	ON device 
	FOR EACH ROW
	EXECUTE PROCEDURE device_one_location_validate();


----------------------------------------------------------------------------

-- Only one of device_type_module_z or device_type_side may be set.  If
-- the former, it means the module is inside the device, if the latter, its
-- visible outside of the device.
CREATE OR REPLACE FUNCTION device_type_module_sanity_set() 
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.DEVICE_TYPE_Z_OFFSET IS NOT NULL AND NEW.DEVICE_TYPE_SIDE IS NOT NULL THEN
		RAISE EXCEPTION 'Both Z Offset and Device_Type_Side may not be set'
			USING ERRCODE = 'JH001';
	END IF;
	RETURN NEW;
END;
$$ 
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_type_module_sanity_set 
	ON device_type_module;
CREATE TRIGGER trigger_device_type_module_sanity_set 
	BEFORE INSERT OR UPDATE ON device_type_module 
	FOR EACH ROW
	EXECUTE PROCEDURE device_type_module_sanity_set();

-- 
-- device types marked with is_chassis = 'Y' need to keep that if there
-- are device_type_modules associated.
-- 
CREATE OR REPLACE FUNCTION device_type_chassis_check()
RETURNS TRIGGER AS $$
DECLARE
	_tally	integer;
BEGIN
	IF TG_OP != 'UPDATE' THEN
		RAISE EXCEPTION 'This should not happen %!', TG_OP;
	END IF;
	IF OLD.is_chassis = 'Y' THEN
		IF NEW.is_chassis = 'N' THEN
			SELECT 	count(*)
			  INTO	_tally
			  FROM	device_type_module
			 WHERE	device_type_id = NEW.device_type_id;

			IF _tally >  0 THEN
				RAISE EXCEPTION 'Is_chassis must be Y when a device_type still has device_type_module s'
					USING ERRCODE = 'foreign_key_violation';
			END IF;
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_type_chassis_check 
	ON device_type;
CREATE TRIGGER trigger_device_type_chassis_check 
	BEFORE UPDATE OF is_chassis
	ON device_type
	FOR EACH ROW
	EXECUTE PROCEDURE device_type_chassis_check();

--
-- related to above.  device_type_module.device_type_id must have
-- 
--
CREATE OR REPLACE FUNCTION device_type_module_chassis_check()
RETURNS TRIGGER AS $$
DECLARE
	_ischass	device_type.is_chassis%TYPE;
BEGIN
	SELECT 	is_chassis
	  INTO	_ischass
	  FROM	device_type
	 WHERE	device_type_id = NEW.device_type_id;

	IF _ischass = 'N' THEN
		RAISE EXCEPTION 'Is_chassis must be Y for chassis device_types'
			USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN NEW;

END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_type_module_chassis_check 
	ON device_type_module;
CREATE TRIGGER trigger_device_type_module_chassis_check 
	BEFORE INSERT OR UPDATE of DEVICE_TYPE_ID
	ON device_type_module 
	FOR EACH ROW
	EXECUTE PROCEDURE device_type_module_chassis_check();


--------------------------------------------------------------------
-- DONE with adding ddl/schema/pgsql/create_device_type_triggers.sql
--------------------------------------------------------------------

--------------------------------------------------------------------
-- BEGIN with adding ddl/schema/pgsql/create_device_power_triggers.sql
--------------------------------------------------------------------
/*
 * Copyright (c) 2012-2014 Todd Kover
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

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION device_power_connection_sanity() 
RETURNS TRIGGER AS $$
DECLARE
	_rpcpp	device_power_interface.provides_power%TYPE;
	_conpp	device_power_interface.provides_power%TYPE;
	_rpcpg	device_power_interface.power_plug_style%TYPE;
	_conpg	device_power_interface.power_plug_style%TYPE;
BEGIN
	SELECT	provides_power, power_plug_style
	 INTO	_rpcpp, _rpcpg
	 FROM	device_power_interface dpi
	WHERE	device_id = NEW.rpc_device_id
	  AND	power_interface_port = NEW.rpc_power_interface_port;

	SELECT	provides_power, power_plug_style
	 INTO	_conpp, _conpg
	 FROM	device_power_interface
	WHERE	device_id = NEW.device_id
	  AND	power_interface_port = NEW.power_interface_port;

	IF _rpcpg != _conpg THEN
		RAISE EXCEPTION 'Power Connection Plugs must match'
			USING ERRCODE = 'JH360';
	END IF;

	IF _rpcpp = 'N' THEN
		RAISE EXCEPTION 'RPCs must provide power'
			USING ERRCODE = 'JH362';
	END IF;

	IF _conpp = 'Y' THEN
		RAISE EXCEPTION 'Power Consumers must not provide power'
			USING ERRCODE = 'JH363';
	END IF;

	-- This will probably never happen because the previous two conditionals
	-- will catch all cases.  Its just here in case one of them goes away.
	IF _rpcpp = _conpp THEN
		RAISE EXCEPTION 'Power Connections must be between a power consumer and provider'
			USING ERRCODE = 'JH361';
	END IF;


	RETURN NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_power_connection_sanity 
	ON device_power_connection;
CREATE TRIGGER trigger_device_power_connection_sanity 
	BEFORE INSERT OR UPDATE 
	ON device_power_connection 
	FOR EACH ROW 
	EXECUTE PROCEDURE device_power_connection_sanity();

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION device_power_port_sanity() 
RETURNS TRIGGER AS $$
DECLARE
	_pp	integer;
BEGIN
	IF OLD.PROVIDES_POWER != NEW.PROVIDES_POWER THEN
		IF NEW.PROVIDES_POWER = 'N' THEN
			SELECT	count(*)
			 INTO	_pp
			 FROM	device_power_connection
			WHERE	rpc_device_id = NEW.device_id
			 AND	rpc_power_interface_port = NEW.power_interface_port;

			IF _pp > 0 THEN
				RAISE EXCEPTION 'Power Connections must be between a power consumer and provider'
					USING ERRCODE = 'JH361';
			END IF;
		ELSIF NEW.PROVIDES_POWER = 'Y' THEN
			SELECT	count(*)
			 INTO	_pp
			 FROM	device_power_connection
			WHERE	device_id = NEW.device_id
			 AND	power_interface_port = NEW.power_interface_port;
			IF _pp > 0 THEN
				RAISE EXCEPTION 'Power Connections must be between a power consumer and provider'
					USING ERRCODE = 'JH361';
			END IF;
		ELSE
			RAISE EXCEPTION 'This should never happen';
		END IF;
	END IF;

	IF OLD.POWER_PLUG_STYLE != NEW.POWER_PLUG_STYLE THEN
		SELECT	count(*)
		 INTO	_pp
		 FROM	device_power_connection
		WHERE	
				(device_id, power_interface_port) =
					(NEW.device_id, NEW.power_interface_port)
		  OR
				(rpc_device_id, rpc_power_interface_port) =
					(NEW.device_id, NEW.power_interface_port);
		IF _pp > 0 THEN
			RAISE EXCEPTION 'Power Connection Plugs must match'
				USING ERRCODE = 'JH360';
		END IF;
	END IF;
	RETURN NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_power_port_sanity 
	ON device_power_interface;
CREATE TRIGGER trigger_device_power_port_sanity 
	BEFORE UPDATE OF provides_power, power_plug_style
	ON device_power_interface 
	FOR EACH ROW 
	EXECUTE PROCEDURE device_power_port_sanity();


--------------------------------------------------------------------
-- DONE with adding ddl/schema/pgsql/create_device_power_triggers.sql
--------------------------------------------------------------------

--------------------------------------------------------------------
-- BEGIN with adding ddl/schema/pgsql/create_netblock_triggers-RETIRE.sql
--------------------------------------------------------------------

-- Copyright (c) 2014 Todd M. Kover
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

-- $Id$

-- The following columns are being retired in favor of postgresql functions:
-- 	netmask_bits, is_ipv4_address
--
-- This trigger allows them to not be touched but keeps them set until they
-- go away...
CREATE OR REPLACE FUNCTION retire_netblock_columns()
RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'INSERT' THEN
		IF NEW.NETMASK_BITS IS NULL THEN
			NEW.NETMASK_BITS := masklen(NEW.ip_address);
		END IF;
		IF NEW.IS_IPV4_ADDRESS  IS NULL THEN
			IF family(NEW.ip_address) = 4 THEN
				NEW.IS_IPV4_ADDRESS := 'Y';
			ELSE
				NEW.IS_IPV4_ADDRESS := 'N';
			END IF;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.IP_ADDRESS != OLD.IP_ADDRESS THEN
			IF OLD.NETMASK_BITS = NEW.NETMASK_BITS THEN
				NEW.NETMASK_BITS := masklen(NEW.ip_address);
			END IF;
			IF OLD.IS_IPV4_ADDRESS = NEW.IS_IPV4_ADDRESS THEN
				IF family(NEW.ip_address) = 4 THEN
					NEW.IS_IPV4_ADDRESS := 'Y';
				ELSE
					NEW.IS_IPV4_ADDRESS := 'N';
				END IF;
			END IF;
		END IF;
	ELSE
		RAISE EXCEPTION 'This should never happen.';
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS aaaa_trigger_retire_netblock_columns ON netblock;
CREATE TRIGGER aaaa_trigger_retire_netblock_columns
	BEFORE INSERT OR UPDATE OF ip_address, netmask_bits, is_ipv4_address
	ON netblock 
	FOR EACH ROW EXECUTE PROCEDURE retire_netblock_columns();

--
-- If stuff in inet and netmask_bits/ipv4 mismatch, complain
--
CREATE OR REPLACE FUNCTION netblock_complain_on_mismatch()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.IS_IPV4_ADDRESS IS NULL or NEW.NETMASK_BITS IS NULL THEN
		RAISE EXCEPTION 'IS_IPv4_ADDRESS or NETMASK_BITS may not be NULL'
			USING ERRCODE = 'not_null_violation';
	END IF;

	IF NEW.IS_IPV4_ADDRESS = 'Y' and family(NEW.ip_address) != 4 THEN
		RAISE EXCEPTION 'is_ipv4_address must match family(NEW.ip_address)'
			USING ERRCODE = 'JH0FF';
	END IF;

	IF NEW.IS_IPV4_ADDRESS != 'Y' and family(NEW.ip_address) = 4 THEN
		RAISE EXCEPTION 'is_ipv4_address must match family(NEW.ip_address)'
			USING ERRCODE = 'JH0FF';
	END IF;

	IF NEW.NETMASK_BITS != masklen(NEW.ip_address) THEN
		RAISE EXCEPTION 'netmask_bits must match masklen(NEW.ip_address)'
			USING ERRCODE = 'JH0FF';
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_retire_netblock_columns ON netblock;
CREATE TRIGGER trigger_retire_netblock_columns
	AFTER INSERT OR UPDATE OF ip_address, netmask_bits, is_ipv4_address
	ON netblock 
	FOR EACH ROW EXECUTE PROCEDURE netblock_complain_on_mismatch();

--------------------------------------------------------------------
-- DONE with adding ddl/schema/pgsql/create_netblock_triggers-RETIRE.sql
--------------------------------------------------------------------


--------------------------------------------------------------------
-- BEGIN with adding ddl/schema/pgsql/create_device_triggers.sql
--------------------------------------------------------------------

/*
 * Copyright (c) 2013 Todd Kover
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


-- Manage per-device device collections.
--
-- When a device is added, updated or removed, there is a per-device
-- device-collection that goes along with it

-- XXX Need automated test cases

-- before a device is deleted, remove the per-device device collections,
-- if appropriate
CREATE OR REPLACE FUNCTION delete_per_device_device_collection()
RETURNS TRIGGER AS $$
DECLARE
	dcid			device_collection.device_collection_id%TYPE;
BEGIN
	SELECT	device_collection_id
	  FROM  device_collection
	  INTO	dcid
	 WHERE	device_collection_type = 'per-device'
	   AND	device_collection_id in
		(select device_collection_id
		 from device_collection_device
		where device_id = OLD.device_id
		)
	ORDER BY device_collection_id
	LIMIT 1;

	IF dcid IS NOT NULL THEN
		DELETE FROM device_collection_device
		WHERE device_collection_id = dcid;

		DELETE from device_collection
		WHERE device_collection_id = dcid;
	END IF;

	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_delete_per_device_device_collection ON Device;
CREATE TRIGGER trigger_delete_per_device_device_collection
BEFORE DELETE
ON device
FOR EACH ROW EXECUTE PROCEDURE delete_per_device_device_collection();

------------------------------------------------------------------------------


-- On inserts and updates, ensure the per-device device collection is updated
-- correctly.
CREATE OR REPLACE FUNCTION update_per_device_device_collection()
RETURNS TRIGGER AS $$
DECLARE
	dcid		device_collection.device_collection_id%TYPE;
	newname		device_collection.device_collection_name%TYPE;
BEGIN
	IF NEW.device_name IS NOT NULL THEN
		newname = NEW.device_name || '_' || NEW.device_id;
	ELSE
		newname = 'per_d_dc_contrived_' || NEW.device_id;
	END IF;

	IF TG_OP = 'INSERT' THEN
		insert into device_collection
			(device_collection_name, device_collection_type)
		values
			(newname, 'per-device')
		RETURNING device_collection_id INTO dcid;
		insert into device_collection_device
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
			  FROM	device_collection_device
			 WHERE	device_id = NEW.device_id
			);
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_per_device_device_collection ON device;
CREATE TRIGGER trigger_update_per_device_device_collection
AFTER INSERT OR UPDATE
ON device
FOR EACH ROW EXECUTE PROCEDURE update_per_device_device_collection();

--- Other triggers on device
-- The whole VOE thing is not well supported.

CREATE OR REPLACE FUNCTION verify_device_voe()
RETURNS TRIGGER AS $$
DECLARE
	voe_sw_pkg_repos		sw_package_repository.sw_package_repository_id%TYPE;
	os_sw_pkg_repos		operating_system.sw_package_repository_id%TYPE;
	voe_sym_trx_sw_pkg_repo_id	voe_symbolic_track.sw_package_repository_id%TYPE;
BEGIN

	IF (NEW.operating_system_id IS NOT NULL)
	THEN
		SELECT sw_package_repository_id INTO os_sw_pkg_repos
			FROM
				operating_system
			WHERE
				operating_system_id = NEW.operating_system_id;
	END IF;

	IF (NEW.voe_id IS NOT NULL) THEN
		SELECT sw_package_repository_id INTO voe_sw_pkg_repos
			FROM
				voe
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
				voe_symbolic_track
			WHERE
				voe_symbolic_track_id=NEW.voe_symbolic_track_id;
		IF (voe_sym_trx_sw_pkg_repo_id != os_sw_pkg_repos) THEN
			RAISE EXCEPTION
				'Device OS and VOE track have different SW Pkg Repositories';
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_verify_device_voe ON device;
CREATE TRIGGER trigger_verify_device_voe BEFORE INSERT OR UPDATE
ON device FOR EACH ROW EXECUTE PROCEDURE verify_device_voe();


-- A before trigger will exist such that if you update device_type_id,
-- it will go and update location.device_type_id because that would be
-- super annoying to have to remember if its not a device-in-a-device.

CREATE OR REPLACE FUNCTION device_update_location_fix()
RETURNS TRIGGER AS $$
BEGIN
	IF OLD.DEVICE_TYPE_ID != NEW.DEVICE_TYPE_ID THEN
		IF NEW.location_id IS NOT NULL THEN
			UPDATE location SET devivce_type_id = NEW.device_type_id
			WHERE location_id = NEW.location_id;
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_update_location_fix ON device;
CREATE TRIGGER trigger_device_update_location_fix
	BEFORE UPDATE OF DEVICE_TYPE_ID
	ON device FOR EACH ROW EXECUTE PROCEDURE device_update_location_fix();


--------------------------------------------------------------------
-- DONE with adding ddl/schema/pgsql/create_device_triggers.sql
--------------------------------------------------------------------

--------------------------------------------------------------------
-- BEGIN with adding ddl/schema/pgsql/create_netblock_triggers.sql
--------------------------------------------------------------------

-- Copyright (c) 2012,2013,2014 Matthew Ragan
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

CREATE OR REPLACE FUNCTION validate_netblock()
RETURNS TRIGGER AS $$
DECLARE
	nbtype				RECORD;
	v_netblock_id		netblock.netblock_id%TYPE;
	parent_netblock		RECORD;
BEGIN
	/*
	 * Force netmask_bits to be authoritative.  If netblock_bits is NULL
	 * and this is a validated hierarchy, then set things to match the best
	 * parent
	 */

	IF NEW.ip_address IS NULL THEN
		RAISE EXCEPTION 'Column ip_address may not be null'
			USING ERRCODE = 'not_null_violation';
	END IF;

	IF NEW.netmask_bits IS NULL THEN
		/*
		 * If netmask_bits is not set, and ip_address has a netmask that is
		 * not a /32 (the default), then use that for the netmask.
		 */

		IF (masklen(NEW.ip_address) != 
				CASE WHEN family(NEW.ip_address) = 4 THEN 32 ELSE 128 END) THEN
			NEW.netmask_bits := masklen(NEW.ip_address);
		END IF;

		/*
		 * Don't automatically determine the netmask unless is_single_address
		 * is 'Y'.  If it is, enforce it if it's a managed hierarchy
		 */
		IF NEW.is_single_address = 'Y' THEN
			SELECT * INTO nbtype FROM val_netblock_type WHERE
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
				netblock WHERE netblock_id = v_netblock_id;

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
			USING ERRCODE = 'JH106';
	END IF;

	IF NEW.is_single_address = 'N' AND (NEW.ip_address != cidr(NEW.ip_address))
			THEN
		RAISE EXCEPTION
			'Non-network bits must be zero if is_single_address is N for %',
			NEW.ip_address
			USING ERRCODE = 'JH103';
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
			   FROM netblock
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
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_netblock ON netblock;
DROP TRIGGER IF EXISTS tb_a_validate_netblock ON netblock;

/* This should be lexicographically the first trigger to fire */

CREATE TRIGGER tb_a_validate_netblock BEFORE INSERT OR UPDATE ON
	netblock FOR EACH ROW EXECUTE PROCEDURE
	validate_netblock();

CREATE OR REPLACE FUNCTION manipulate_netblock_parentage_before()
RETURNS TRIGGER AS $$

DECLARE
	nbtype				record;
	v_netblock_type		val_netblock_type.netblock_type%TYPE;
BEGIN
	/*
	 * Get the parameters for the given netblock type to see if we need
	 * to do anything
	 */

	RAISE DEBUG 'Performing % on netblock %', TG_OP, NEW.netblock_id;

	SELECT * INTO nbtype FROM val_netblock_type WHERE
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
			netblock
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
			netblock
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
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_manipulate_netblock_parentage ON netblock;
DROP TRIGGER IF EXISTS tb_manipulate_netblock_parentage ON netblock;

CREATE TRIGGER tb_manipulate_netblock_parentage
	BEFORE INSERT OR UPDATE OF
		ip_address, netmask_bits, netblock_type, ip_universe_id
	ON netblock
	FOR EACH ROW EXECUTE PROCEDURE manipulate_netblock_parentage_before();


CREATE OR REPLACE FUNCTION manipulate_netblock_parentage_after()
RETURNS TRIGGER AS $$

DECLARE
	nbtype				record;
	v_netblock_type		val_netblock_type.netblock_type%TYPE;
	v_row_count			integer;
	v_trigger			record;
BEGIN
	/*
	 * Get the parameters for the given netblock type to see if we need
	 * to do anything
	 */

	IF TG_OP = 'DELETE' THEN
		v_trigger := OLD;
	ELSE
		v_trigger := NEW;
	END IF;

	SELECT * INTO nbtype FROM val_netblock_type WHERE
		netblock_type = v_trigger.netblock_type;

	IF (NOT FOUND) OR nbtype.db_forced_hierarchy != 'Y' THEN
		RETURN NULL;
	END IF;

	/*
	 * If we are deleting, attach all children to the parent and wipe
	 * hands on pants;
	 */
	IF TG_OP = 'DELETE' THEN
		UPDATE
			netblock
		SET
			parent_netblock_id = OLD.parent_netblock_id
		WHERE
			parent_netblock_id = OLD.netblock_id;

		GET DIAGNOSTICS v_row_count = ROW_COUNT;
	--	IF (v_row_count > 0) THEN
			RAISE DEBUG 'Set parent for all child netblocks of deleted netblock % (address %, is_single_address %) to % (% rows updated)',
				OLD.netblock_id,
				OLD.ip_address,
				OLD.is_single_address,
				OLD.parent_netblock_id,
				v_row_count;
	--	END IF;

		RETURN NULL;
	END IF;

	IF NEW.is_single_address = 'Y' THEN
		RETURN NULL;
	END IF;

	RAISE DEBUG 'Setting parent for all child netblocks of parent netblock % that belong to %',
		NEW.parent_netblock_id,
		NEW.netblock_id;

	IF NEW.parent_netblock_id IS NULL THEN
		UPDATE
			netblock
		SET
			parent_netblock_id = NEW.netblock_id
		WHERE
			parent_netblock_id IS NULL AND
			ip_address <<= NEW.ip_address AND
			netblock_id != NEW.netblock_id AND
			netblock_type = NEW.netblock_type AND
			ip_universe_id = NEW.ip_universe_id;
		RETURN NULL;
	ELSE
		-- We don't need to specify the netblock_type or ip_universe_id here
		-- because the parent would have had to match
		UPDATE
			netblock
		SET
			parent_netblock_id = NEW.netblock_id
		WHERE
			parent_netblock_id = NEW.parent_netblock_id AND
			ip_address <<= NEW.ip_address AND
			netblock_id != NEW.netblock_id;
		RETURN NULL;
	END IF;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS ta_manipulate_netblock_parentage ON netblock;
DROP TRIGGER IF EXISTS aaa_ta_manipulate_netblock_parentage ON netblock;

CREATE CONSTRAINT TRIGGER aaa_ta_manipulate_netblock_parentage
	AFTER INSERT OR DELETE ON netblock NOT DEFERRABLE
	FOR EACH ROW EXECUTE PROCEDURE manipulate_netblock_parentage_after();

CREATE OR REPLACE FUNCTION validate_netblock_parentage()
RETURNS TRIGGER AS $$
DECLARE
	nbrec			record;
	realnew			record;
	nbtype			record;
	parent_nbid		netblock.netblock_id%type;
	ipaddr			inet;
	parent_ipaddr	inet;
	single_count	integer;
	nonsingle_count	integer;
	pip	    		netblock.ip_address%type;
BEGIN

	RAISE DEBUG 'Validating % of netblock %', TG_OP, NEW.netblock_id;

	SELECT * INTO nbtype FROM val_netblock_type WHERE
		netblock_type = NEW.netblock_type;

	IF (NOT FOUND) THEN
		RETURN NULL;
	END IF;

	/*
	 * It's possible that due to delayed triggers that what is stored in
	 * NEW is not current, so fetch the current values
	 */

	SELECT * INTO realnew FROM netblock WHERE netblock_id =
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
	PERFORM netblock_id FROM netblock WHERE
		parent_netblock_id = realnew.netblock_id AND
		netblock_type != realnew.netblock_type AND
		ip_universe_id != realnew.ip_universe_id;

	IF FOUND THEN
		RAISE EXCEPTION 'Netblock children must all be of the same type and universe as the parent'
			USING ERRCODE = 'JH109';
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
			RAISE 'A single address (%) must be the child of a parent netblock, which must have can_subnet=N',
				realnew.ip_address
				USING ERRCODE = 'JH105';
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
			SELECT * INTO nbrec FROM netblock WHERE netblock_id =
				parent_nbid;

			RAISE EXCEPTION 'Netblock % (%) has NULL parent; should be % (%)',
				realnew.netblock_id, realnew.ip_address,
				parent_nbid, nbrec.ip_address USING ERRCODE = 'JH102';
		END IF;

		/*
		 * Validate that none of the other top-level netblocks should
		 * belong to this netblock
		 */
		PERFORM netblock_id FROM netblock WHERE
			parent_netblock_id IS NULL AND
			netblock_id != NEW.netblock_id AND
			netblock_type = NEW.netblock_type AND
			ip_universe_id = NEW.ip_universe_id AND
			ip_address <<= NEW.ip_address;
		IF FOUND THEN
			RAISE EXCEPTION 'Other top-level netblocks should belong to this parent'
				USING ERRCODE = 'JH108';
		END IF;
	ELSE
	 	/*
		 * Reject a block that is self-referential
		 */
	 	IF realnew.parent_netblock_id = realnew.netblock_id THEN
			RAISE EXCEPTION 'Netblock may not have itself as a parent'
				USING ERRCODE = 'JH101';
		END IF;

		SELECT * INTO nbrec FROM netblock WHERE netblock_id =
			realnew.parent_netblock_id;

		/*
		 * This shouldn't happen, but may because of deferred constraints
		 */
		IF NOT FOUND THEN
			RAISE EXCEPTION 'Parent netblock % does not exist',
			realnew.parent_netblock_id
			USING ERRCODE = 'foreign_key_violation';
		END IF;

		IF nbrec.is_single_address = 'Y' THEN
			RAISE EXCEPTION 'A parent netblock (% for %) may not be a single address',
			nbrec.netblock_id, realnew.ip_address
			USING ERRCODE = 'JH10A';
		END IF;

		IF nbrec.ip_universe_id != realnew.ip_universe_id OR
				nbrec.netblock_type != realnew.netblock_type THEN
			RAISE EXCEPTION 'Netblock children must all be of the same type and universe as the parent'
			USING ERRCODE = 'JH109';
		END IF;

		IF nbtype.is_validated_hierarchy='N' THEN
			/*
			 * non-validated hierarchy addresses may not have the best parent as
			 * a parent, but if they have a parent, it should be a superblock
			 */

			IF NOT (realnew.ip_address << nbrec.ip_address OR
					cidr(realnew.ip_address) != nbrec.ip_address) THEN
				RAISE EXCEPTION 'Parent netblock % (%) is not a valid parent for %',
					nbrec.ip_address, nbrec.netblock_id, realnew.ip_address
					USING ERRCODE = 'JH104';
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
				PERFORM netblock_id FROM netblock WHERE
					parent_netblock_id = realnew.netblock_id AND
					is_single_address = 'N';
				IF FOUND THEN
					RAISE EXCEPTION 'A non-subnettable netblock (%) may not have child network netblocks',
					realnew.netblock_id
					USING ERRCODE = 'JH10B';
				END IF;
			END IF;
			IF realnew.is_single_address = 'Y' THEN
				SELECT * INTO nbrec FROM netblock
					WHERE netblock_id = realnew.parent_netblock_id;
				IF (nbrec.can_subnet = 'Y') THEN
					RAISE 'Parent netblock % for single-address % must have can_subnet=N',
						nbrec.netblock_id,
						realnew.ip_address
						USING ERRCODE = 'JH10D';
				END IF;
				IF (masklen(realnew.ip_address) != 
						masklen(nbrec.ip_address)) THEN
					RAISE 'Parent netblock % does not have same netmask as single-address child % (% vs %)',
						parent_nbid, realnew.netblock_id, masklen(ipaddr),
						masklen(realnew.ip_address)
						USING ERRCODE = 'JH105';
				END IF;
			END IF;
			IF (parent_nbid IS NULL OR realnew.parent_netblock_id != parent_nbid) THEN
				SELECT ip_address INTO parent_ipaddr FROM netblock
				WHERE
					netblock_id = parent_nbid;
				SELECT ip_address INTO ipaddr FROM netblock WHERE
					netblock_id = realnew.parent_netblock_id;

				RAISE EXCEPTION
					'Parent netblock % (%) for netblock % (%) is not the correct parent (should be % (%))',
					realnew.parent_netblock_id, ipaddr,
					realnew.netblock_id, realnew.ip_address,
					parent_nbid, parent_ipaddr
					USING ERRCODE = 'JH102';
			END IF;
			/*
			 * Validate that all children are is_single_address='Y' or
			 * all children are is_single_address='N'
			 */
			SELECT count(*) INTO single_count FROM netblock WHERE
				is_single_address='Y' and parent_netblock_id =
				realnew.parent_netblock_id;
			SELECT count(*) INTO nonsingle_count FROM netblock WHERE
				is_single_address='N' and parent_netblock_id =
				realnew.parent_netblock_id;

			IF (single_count > 0 and nonsingle_count > 0) THEN
				SELECT * INTO nbrec FROM netblock WHERE netblock_id =
					realnew.parent_netblock_id;
				RAISE EXCEPTION 'Netblock % (%) may not have direct children for both single and multiple addresses simultaneously',
					nbrec.netblock_id, nbrec.ip_address
					USING ERRCODE = 'JH107';
			END IF;
			/*
			 *  If we're updating and we changed our ip_address (including
			 *  netmask bits), then check that our children still belong to
			 *  us
			 */
			 IF (TG_OP = 'UPDATE' AND NEW.ip_address != OLD.ip_address) THEN
				PERFORM netblock_id FROM netblock WHERE
					parent_netblock_id = realnew.netblock_id AND
					((is_single_address = 'Y' AND NEW.ip_address !=
						ip_address::cidr) OR
					(is_single_address = 'N' AND realnew.netblock_id !=
						netblock_utils.find_best_parent_id(netblock_id)));
				IF FOUND THEN
					RAISE EXCEPTION 'Update for netblock % (%) causes parent to have children that do not belong to it',
						realnew.netblock_id, realnew.ip_address
						USING ERRCODE = 'JH10E';
				END IF;
			END IF;

			/*
			 * Validate that none of the children of the parent netblock are
			 * children of this netblock (e.g. if inserting into the middle
			 * of the hierarchy)
			 */
			IF (realnew.is_single_address = 'N') THEN
				PERFORM netblock_id FROM netblock WHERE
					parent_netblock_id = realnew.parent_netblock_id AND
					netblock_id != realnew.netblock_id AND
					ip_address <<= realnew.ip_address;
				IF FOUND THEN
					RAISE EXCEPTION 'Other netblocks have children that should belong to parent % (%)',
						realnew.parent_netblock_id, realnew.ip_address
						USING ERRCODE = 'JH108';
				END IF;
			END IF;
		END IF;
	END IF;

	RETURN NULL;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

/*
 * NOTE: care needs to be taken to make this trigger name come
 * lexicographically last, since it needs to check what happened in the
 * other triggers
 */

DROP TRIGGER IF EXISTS trigger_validate_netblock_parentage ON netblock;
CREATE CONSTRAINT TRIGGER trigger_validate_netblock_parentage
	AFTER INSERT OR UPDATE ON netblock DEFERRABLE INITIALLY DEFERRED
	FOR EACH ROW EXECUTE PROCEDURE validate_netblock_parentage();


--------------------------------------------------------------------
-- DONE with adding ddl/schema/pgsql/create_netblock_triggers.sql
--------------------------------------------------------------------

---------- =========== DONE WITH TRIGGERS ========= ----------------
---------- =========== STARTING  PKGS ========= ----------------

--------------------------------------------------------------------
-- BEGIN with adding pkg/pgsql/device_utils.sql
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

-- Create schema if it does not exist, do nothing otherwise.
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'device_utils';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS device_utils;
		CREATE SCHEMA device_utils AUTHORIZATION jazzhands;
	END IF;
END;
$$;


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
	v_loc_id	rack_location.rack_location_id%type;
BEGIN
	delete from device_collection_device where device_id = in_Device_id;
	delete from snmp_commstr where device_id = in_Device_id;

	select	rack_location_id
	  into	v_loc_id
	  from	device
	 where	device_id = in_Device_id;

	IF v_loc_id is not NULL  THEN
		update device set rack_location_Id = NULL where device_id = in_device_id;
		delete from rack_location where rack_location_id = v_loc_id;
	END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
--end of retire_device_ancillary id_tag
-------------------------------------------------------------------

--------------------------------------------------------------------
-- END with adding pkg/pgsql/device_utils.sql
--------------------------------------------------------------------

--------------------------------------------------------------------
-- BEGIN with adding pkg/pgsql/netblock_utils.sql
--------------------------------------------------------------------

-- Copyright (c) 2012-2014 Matthew Ragan
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
 * $Id$
 */

drop schema if exists netblock_utils cascade;
create schema netblock_utils authorization jazzhands;

-------------------------------------------------------------------
-- returns the Id tag for CM
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION netblock_utils.id_tag()
RETURNS VARCHAR AS $$
BEGIN
	RETURN('<-- $Id -->');
END;
$$ LANGUAGE plpgsql;
-- end of procedure id_tag
-------------------------------------------------------------------

CREATE OR REPLACE FUNCTION netblock_utils.find_best_parent_id(
	in_IpAddress jazzhands.netblock.ip_address%type,
	in_Netmask_Bits jazzhands.netblock.netmask_bits%type DEFAULT NULL,
	in_netblock_type jazzhands.netblock.netblock_type%type DEFAULT 'default',
	in_ip_universe_id jazzhands.ip_universe.ip_universe_id%type DEFAULT 0,
	in_is_single_address jazzhands.netblock.is_single_address%type DEFAULT 'N',
	in_netblock_id jazzhands.netblock.netblock_id%type DEFAULT NULL
) RETURNS jazzhands.netblock.netblock_id%type AS $$
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
				(in_is_single_address = 'Y' AND can_subnet = 'N' AND
					(in_Netmask_Bits IS NULL OR netmask_bits = in_Netmask_Bits))
			)
			and (in_netblock_id IS NULL OR
				netblock_id != in_netblock_id)
		order by netmask_bits desc
	) subq LIMIT 1;

	return par_nbid;
END;
$$ 
-- SET search_path=jazzhands
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION netblock_utils.find_best_parent_id(
	in_netblock_id jazzhands.netblock.netblock_id%type
) RETURNS jazzhands.netblock.netblock_id%type AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION netblock_utils.delete_netblock(
	in_netblock_id	jazzhands.netblock.netblock_id%type
) RETURNS VOID AS $$
DECLARE
	par_nbid	jazzhands.netblock.netblock_id%type;
BEGIN
	/*
	 * Update netblocks that use this as a parent to point to my parent
	 */
	SELECT
		netblock_id INTO par_nbid
	FROM
		jazzhands.netblock
	WHERE 
		netblock_id = in_netblock_id;
	
	UPDATE
		jazzhands.netblock
	SET
		parent_netblock_id = par_nbid
	WHERE
		parent_netblock_id = in_netblock_id;
	
	/*
	 * Now delete the record
	 */
	DELETE FROM jazzhands.netblock WHERE netblock_id = in_netblock_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION netblock_utils.recalculate_parentage(
	in_netblock_id	jazzhands.netblock.netblock_id%type
) RETURNS INTEGER AS $$
DECLARE
	nbrec		RECORD;
	childrec	RECORD;
	nbid		jazzhands.netblock.netblock_id%type;
	ipaddr		inet;

BEGIN
	SELECT * INTO nbrec FROM jazzhands.netblock WHERE 
		netblock_id = in_netblock_id;

	nbid := netblock_utils.find_best_parent_id(in_netblock_id);

	UPDATE jazzhands.netblock SET parent_netblock_id = nbid
		WHERE netblock_id = in_netblock_id;
	
	FOR childrec IN SELECT * FROM jazzhands.netblock WHERE 
		parent_netblock_id = nbid
		AND netblock_id != in_netblock_id
	LOOP
		IF (childrec.ip_address <<= nbrec.ip_address) THEN
			UPDATE jazzhands.netblock SET parent_netblock_id = in_netblock_id
				WHERE netblock_id = childrec.netblock_id;
		END IF;
	END LOOP;
	RETURN nbid;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION netblock_utils.find_rvs_zone_from_netblock_id(
	in_netblock_id	jazzhands.netblock.netblock_id%type
) RETURNS jazzhands.dns_domain.dns_domain_id%type AS $$
DECLARE
	v_rv	jazzhands.dns_domain.dns_domain_id%type;
	v_domid	jazzhands.dns_domain.dns_domain_id%type;
	v_lhsip	jazzhands.netblock.ip_address%type;
	v_rhsip	jazzhands.netblock.ip_address%type;
	nb_match CURSOR ( in_nb_id jazzhands.netblock.netblock_id%type) FOR
		-- The query used to include this in the where clause, but
		-- oracle was uber slow 
		--	net_manip.inet_base(nb.ip_address, root.netmask_bits) =  
		--		net_manip.inet_base(root.ip_address, root.netmask_bits) 
		select  rootd.dns_domain_id,
				 net_manip.inet_base(nb.ip_address, root.netmask_bits),
				 net_manip.inet_base(root.ip_address, root.netmask_bits)
		  from  jazzhands.netblock nb,
			jazzhands.netblock root
				inner join jazzhands.dns_record rootd
					on rootd.netblock_id = root.netblock_id
					and rootd.dns_type = 'REVERSE_ZONE_BLOCK_PTR'
		 where
		  	nb.netblock_id = in_nb_id;
BEGIN
	v_rv := NULL;
	OPEN nb_match(in_netblock_id);
	LOOP
		FETCH  nb_match INTO v_domid, v_lhsip, v_rhsip;
		if NOT FOUND THEN
			EXIT;
		END IF;

		if v_lhsip = v_rhsip THEN
			v_rv := v_domid;
			EXIT;
		END IF;
	END LOOP;
	CLOSE nb_match;
	return v_rv;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblock(
	parent_netblock_id		jazzhands.netblock.netblock_id%TYPE,
	netmask_bits			integer DEFAULT NULL,
	single_address			boolean DEFAULT false,
	allocate_from_bottom	boolean DEFAULT true
) RETURNS TABLE (
	ip_address	inet
) AS $$
BEGIN
	RETURN QUERY SELECT netblock_utils.find_free_netblocks(
		parent_netblock_id := parent_netblock_id,
		netmask_bits := netmask_bits,
		single_address := single_address,
		allocate_from_bottom := allocate_from_bottom,
		max_addresses := 1);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblocks(
	parent_netblock_id		jazzhands.netblock.netblock_id%TYPE,
	netmask_bits			integer DEFAULT NULL,
	single_address			boolean DEFAULT false,
	allocate_from_bottom	boolean DEFAULT true,
	max_addresses			integer DEFAULT 1024
) RETURNS TABLE (
	ip_address	inet
) AS $$
DECLARE
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
	SELECT 
		* INTO netblock_rec
	FROM
		jazzhands.netblock n
	WHERE
		n.netblock_id = find_free_netblocks.parent_netblock_id;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Netblock % does not exist', 
			find_free_netblocks.parent_netblock_id;
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
		RETURN;
	END IF;

	IF (NOT single_address) AND netblock_rec.can_subnet = 'N' THEN
		RAISE EXCEPTION 'Netblock % (%) may not be subnetted',
			netblock_rec.ip_address,
			netblock_rec.netblock_id;
		RETURN;
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

	matches := 0;
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
			find_free_netblocks.ip_address := current_ip;
			RETURN NEXT;
			matches := matches + 1;
		END IF;

		current_ip := current_ip + nb_size;
	END LOOP;
	RETURN;
END;
$$ LANGUAGE 'plpgsql';

GRANT USAGE ON SCHEMA netblock_utils TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA netblock_utils TO PUBLIC;
--------------------------------------------------------------------
-- DONE with adding pkg/pgsql/netblock_utils.sql
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

-------------------------------------------------------------------
-- sets up power ports for a device if they are not there.
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION port_utils.setup_device_power (
	in_Device_id device.device_id%type
) RETURNS VOID AS $$
DECLARE
	dt_id	device.device_type_id%type;
BEGIN
	if( port_support.has_power_ports(in_device_id) ) then
		return;
	end if;

	select  device_type_id
	  into	dt_id
	  from  device
	 where	device_id = in_device_id;

	 insert into device_power_interface (
		device_id, power_interface_port, 
		 power_plug_style,
		 voltage, max_amperage, provides_power
		)
		select in_device_id, power_interface_port,
		 	power_plug_style,
		 	voltage, max_amperage, provides_power
		  from device_type_power_port_templt
		 where device_type_id = dt_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--------------------------------------------------------------------
-- BEGIN with adding pkg/pgsql/netblock_manip.sql
--------------------------------------------------------------------

DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'netblock_manip';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS netblock_manip;
		CREATE SCHEMA netblock_manip AUTHORIZATION jazzhands;
	END IF;
END;
$$;


-- Copyright (c) 2014 Matthew Ragan
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

CREATE OR REPLACE FUNCTION netblock_manip.delete_netblock(
	in_netblock_id	jazzhands.netblock.netblock_id%type
) RETURNS VOID AS $$
DECLARE
	par_nbid	jazzhands.netblock.netblock_id%type;
BEGIN
	/*
	 * Update netblocks that use this as a parent to point to my parent
	 */
	SELECT
		netblock_id INTO par_nbid
	FROM
		jazzhands.netblock
	WHERE 
		netblock_id = in_netblock_id;
	
	UPDATE
		jazzhands.netblock
	SET
		parent_netblock_id = par_nbid
	WHERE
		parent_netblock_id = in_netblock_id;
	
	/*
	 * Now delete the record
	 */
	DELETE FROM jazzhands.netblock WHERE netblock_id = in_netblock_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION netblock_manip.recalculate_parentage(
	in_netblock_id	jazzhands.netblock.netblock_id%type
) RETURNS INTEGER AS $$
DECLARE
	nbrec		RECORD;
	childrec	RECORD;
	nbid		jazzhands.netblock.netblock_id%type;
	ipaddr		inet;

BEGIN
	SELECT * INTO nbrec FROM jazzhands.netblock WHERE 
		netblock_id = in_netblock_id;

	nbid := netblock_utils.find_best_parent_id(in_netblock_id);

	UPDATE jazzhands.netblock SET parent_netblock_id = nbid
		WHERE netblock_id = in_netblock_id;
	
	FOR childrec IN SELECT * FROM jazzhands.netblock WHERE 
		parent_netblock_id = nbid
		AND netblock_id != in_netblock_id
	LOOP
		IF (childrec.ip_address <<= nbrec.ip_address) THEN
			UPDATE jazzhands.netblock SET parent_netblock_id = in_netblock_id
				WHERE netblock_id = childrec.netblock_id;
		END IF;
	END LOOP;
	RETURN nbid;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(
	parent_netblock_id		jazzhands.netblock.netblock_id%TYPE,
	netmask_bits			integer DEFAULT NULL,
	address_type			text DEFAULT 'netblock',
	-- alternatvies: 'single', 'loopback'
	can_subnet				boolean DEFAULT true,
	allocate_from_bottom	boolean DEFAULT true,
	description				jazzhands.netblock.description%TYPE DEFAULT NULL,
	netblock_status			jazzhands.netblock.netblock_status%TYPE
								DEFAULT NULL
) RETURNS jazzhands.netblock AS $$
DECLARE
	parent_rec		RECORD;
	netblock_rec	RECORD;
	inet_rec		inet;
	loopback_bits	integer;
BEGIN
	IF parent_netblock_id IS NULL THEN
		RAISE 'parent_netblock_id must be specified'
		USING ERRCODE = 'null_value_not_allowed';
	END IF;

	IF address_type NOT IN ('netblock', 'single', 'loopback') THEN
		RAISE 'address_type must be one of netblock, single, or loopback'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;
		
	-- Lock the parent row, which should keep parallel processes from
	-- trying to obtain the same address

	SELECT * INTO parent_rec FROM netblock WHERE netblock_id = 
		allocate_netblock.parent_netblock_id FOR UPDATE;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'parent_netblock_id % is not valid',
			allocate_netblock.parent_netblock_id
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF parent_rec.is_single_address = 'Y' THEN
		RAISE EXCEPTION 'parent_netblock_id refers to a single_address netblock'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF netmask_bits IS NULL AND address_type = 'netblock' THEN
		RAISE EXCEPTION
			'You must either specify a netmask when address_type is netblock'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF address_type = 'loopback' THEN
		IF parent_rec.can_subnet = 'N' THEN
			RAISE EXCEPTION 'parent subnet must have can_subnet set to Y'
				USING ERRCODE = 'JH10B';
		END IF;

		-- If we're allocating a loopback address, then we need to create
		-- a new parent to hold the single loopback address

		loopback_bits := 
			CASE WHEN family(parent_rec.ip_address) = 4 THEN 32 ELSE 128 END;

		SELECT netblock_utils.find_free_netblock(
			parent_netblock_id := parent_netblock_id,
			netmask_bits := loopback_bits,
			single_address := false,
			allocate_from_bottom := allocate_from_bottom) INTO inet_rec;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'No valid netblocks found to allocate'
			USING ERRCODE = 'JH110';
		END IF;

		INSERT INTO netblock (
			ip_address,
			netmask_bits,
			netblock_type,
			is_ipv4_address,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec,
			loopback_bits,
			parent_rec.netblock_type,
			parent_rec.is_ipv4_address,
			'N',
			'N',
			parent_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO parent_rec;

		INSERT INTO netblock (
			ip_address,
			netmask_bits,
			netblock_type,
			is_ipv4_address,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec,
			masklen(inet_rec),
			parent_rec.netblock_type,
			parent_rec.is_ipv4_address,
			'Y',
			'N',
			parent_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		RETURN netblock_rec;
	END IF;

	IF address_type = 'single' THEN
		IF parent_rec.can_subnet = 'Y' THEN
			RAISE EXCEPTION
				'parent subnet for single address must have can_subnet set to N'
				USING ERRCODE = 'JH10B';
		END IF;

		SELECT netblock_utils.find_free_netblock(
			parent_netblock_id := parent_rec.netblock_id,
			single_address := true,
			allocate_from_bottom := allocate_from_bottom) INTO inet_rec;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'No valid netblocks found to allocate'
			USING ERRCODE = 'JH110';
		END IF;

		INSERT INTO netblock (
			ip_address,
			netmask_bits,
			netblock_type,
			is_ipv4_address,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec,
			masklen(inet_rec),
			parent_rec.netblock_type,
			parent_rec.is_ipv4_address,
			'Y',
			'N',
			parent_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		RETURN netblock_rec;
	END IF;
	IF address_type = 'netblock' THEN
		IF parent_rec.can_subnet = 'N' THEN
			RAISE EXCEPTION 'parent subnet must have can_subnet set to Y'
				USING ERRCODE = 'JH10B';
		END IF;

		SELECT netblock_utils.find_free_netblock(
			parent_netblock_id := parent_rec.netblock_id,
			netmask_bits := netmask_bits,
			single_address := false,
			allocate_from_bottom := allocate_from_bottom) INTO inet_rec;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'No valid netblocks found to allocate'
			USING ERRCODE = 'JH110';
		END IF;

		INSERT INTO netblock (
			ip_address,
			netmask_bits,
			netblock_type,
			is_ipv4_address,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec,
			masklen(inet_rec),
			parent_rec.netblock_type,
			parent_rec.is_ipv4_address,
			'N',
			CASE WHEN can_subnet THEN 'Y' ELSE 'N' END,
			parent_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		RETURN netblock_rec;
	END IF;
END;
$$ LANGUAGE plpgsql;

GRANT USAGE ON SCHEMA netblock_manip TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA netblock_manip TO iud_role;

--------------------------------------------------------------------
-- DONE with adding pkg/pgsql/netblock_manip.sql
--------------------------------------------------------------------

---------- =========== DONE WITH PKGS ========= ----------------

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

CREATE VIEW location AS
 SELECT rack_location.rack_location_id AS location_id,
    rack_location.rack_id,
    rack_location.rack_u_offset_of_device_top,
    rack_location.rack_side,
    NULL::integer AS inter_device_offset,
    rack_location.data_ins_user,
    rack_location.data_ins_date,
    rack_location.data_upd_user,
    rack_location.data_upd_date
   FROM rack_location;

SELECT schema_support.replay_object_recreates(true);
SELECT schema_support.replay_saved_grants(true);

ALTER TABLE netblock DROP CONSTRAINT fk_netblk_netblk_parid;
ALTER TABLE netblock
	ADD CONSTRAINT fk_netblk_netblk_parid 
	FOREIGN KEY (parent_netblock_id) REFERENCES netblock(netblock_id)
	DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE dns_record
	ALTER COLUMN dns_class set DEFAULT 'IN'::varchar;

-- rename some trigger names to not suck
DROP TRIGGER IF EXISTS trig_automated_ac ON person_company;
DROP TRIGGER IF EXISTS trigger_automated_ac_on_person_company ON person_company;
CREATE TRIGGER trigger_automated_ac_on_person_company
	AFTER UPDATE ON person_company
	FOR EACH ROW EXECUTE PROCEDURE
	automated_ac_on_person_company();

DROP TRIGGER IF EXISTS trig_automated_ac ON person;
DROP TRIGGER IF EXISTS trigger_automated_ac_on_person ON person;
CREATE TRIGGER trigger_automated_ac_on_person
	AFTER UPDATE ON person
	FOR EACH ROW
	EXECUTE PROCEDURE automated_ac_on_person();


-- RAISE EXCEPTION 'Need to test, test, test....';
-- SELECT schema_support.end_maintenance();

select now();
