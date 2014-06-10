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
$$ LANGUAGE plpgsql SECURITY INVOKER;

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
$$ LANGUAGE plpgsql SECURITY INVOKER;

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
$$ LANGUAGE plpgsql SECURITY INVOKER;

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
$$ LANGUAGE plpgsql SECURITY INVOKER;

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
$$ LANGUAGE plpgsql SECURITY INVOKER;

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
$$ LANGUAGE plpgsql SECURITY INVOKER;

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
$$ LANGUAGE plpgsql SECURITY INVOKER;

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
$$ LANGUAGE plpgsql SECURITY INVOKER;

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
$$ LANGUAGE plpgsql SECURITY INVOKER;

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
$$ LANGUAGE plpgsql SECURITY INVOKER;

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
$$ LANGUAGE plpgsql SECURITY INVOKER;

--
-- Saves relations dependant on an object for reply.
--
CREATE OR REPLACE FUNCTION schema_support.save_dependant_objects_for_replay(
	schema varchar,
	object varchar,
	dropit boolean DEFAULT true
) RETURNS VOID AS $$
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
$$ 
SET search_path=schema_support
LANGUAGE plpgsql 
SECURITY INVOKER;

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
$$ LANGUAGE plpgsql SECURITY INVOKER;


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
$$ LANGUAGE plpgsql SECURITY INVOKER;

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
$$ LANGUAGE plpgsql SECURITY INVOKER;

CREATE OR REPLACE FUNCTION schema_support.replay_object_recreates(
	beverbose	boolean DEFAULT false
) 
RETURNS VOID AS $$
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
$$ LANGUAGE plpgsql SECURITY INVOKER;

/**************************************************************
 *  FUNCTIONS

schema_support.begin_maintenance

	- ensures you are running in a transaction
	- ensures you are a superuser (based on argument)

schema_support.end_maintenance
	- revokes superuser from running user (based on argument)


These will save an object for replay, including presering grants
automatically:

SELECT schema_support.save_function_for_replayjazzhands', 'fncname');
	- saves all function of a given name

SELECT schema_support.save_view_for_replay('jazzhands',  'mytableorview');
	- saves a view includling triggers on the view, for replay

SELECT schema_support.save_constraint_for_replay('jazzhands', 'table');
	- saves constraints pointing to an object for replay

SELECT schema_support.save_trigger_for_replay('jazzhands', 'relation');
	- save triggers poinging to an object for replay

SELECT schema_support.save_dependant_objects_for_replay(schema, object)

This will take an option (relation[table/view] or procedure) and figure
out what depends on it, and save the ddl to recreate tehm.

NOTE:  This does not always handle constraints well. (bug, needs to be fixed)
Right now you may also need to call schema_support.save_constraint_for_replay.

NOTE:  All of the aforementioned tables take an optional boolean argument
at the end.  That argument defaults to true and indicates whether or not
the object shouldbe dropped after saveing grants and other info

==== GRANTS ===

This will save grants for later relay on a relation (view, table) or proc:

select schema_support.save_grants_for_replay('jazzhands', 'physical_port');
select schema_support.save_grants_for_replay('port_support', 
	'do_l1_connection_update');

NOTE:  It saves the grants of stored procedures based on the arguments
passed in, so if you change those, you need to update the definitions in 
__regrants (or __recreates)  before replying them.

NOTE:  These procedures end up losing who did the grants originally

THESE:

	SELECT schema_support.replay_object_recreates();
	SELECT schema_support.replay_saved_grants();

will replay object creations and grants on them respectively.  They should
be called in that order at the end of a maintenance script

-------------------------------------------------------------------------------
-- select schema_support.rebuild_stamp_triggers();
-- SELECT schema_support.build_audit_tables();

**************************************************************/
