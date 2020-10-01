--
-- Copyright (c) 2020 Todd Kover
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


\pset pager
/*
Invoked:

	--suffix=v90
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance(false);
select clock_timestamp(), now(), clock_timestamp() - now() AS len;
--
-- BEGIN: process_ancillary_schema(schema_support)
--
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('schema_support', 'begin_maintenance');
SELECT schema_support.save_grants_for_replay('schema_support', 'begin_maintenance');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.begin_maintenance ( boolean );
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
			PERFORM groname, rolname
			FROM (
				SELECT groname, unnest(grolist) AS oid
				FROM pg_group ) g
			JOIN pg_roles r USING (oid)
			WHERE groname = 'dba'
			AND rolname = current_user;

			IF NOT FOUND THEN
				RAISE EXCEPTION 'User must be a super user or have the dba role';
			END IF;
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

	--
	-- Stash counts of things that may relate to this maintenance for
	-- alter verification and statistics
	--
	-- similar code is in end_maintenance (the INSERT query is the same
	--
	CREATE TEMPORARY TABLE __owner_before_stats (
		username					TEXT,
		before_views_count			INTEGER,
		before_func_count		INTEGER,
		before_key_count	INTEGER,
		PRIMARY KEY (username)
	);
	INSERT INTO __owner_before_stats
		SELECT rolname, coalesce(numrels, 0) AS numrels,
		coalesce(numprocs, 0) AS numprocs,
		coalesce(numfks, 0) AS numfks
		FROM pg_roles r
			LEFT JOIN (
		SELECT relowner, count(*) AS numrels
				FROM pg_class
				WHERE relkind IN ('r','v')
				GROUP BY 1
				) c ON r.oid = c.relowner
			LEFT JOIN (SELECT proowner, count(*) AS numprocs
				FROM pg_proc
				GROUP BY 1
				) p ON r.oid = p.proowner
			LEFT JOIN (
				SELECT relowner, count(*) AS numfks
				FROM pg_class r JOIN pg_constraint fk ON fk.confrelid = r.oid
				WHERE contype = 'f'
				GROUP BY 1
			) fk ON r.oid = fk.relowner
		WHERE r.oid > 16384
	AND (numrels IS NOT NULL OR numprocs IS NOT NULL OR numfks IS NOT NULL);

	RETURN true;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'schema_support' AND type = 'function' AND object IN ('begin_maintenance');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc begin_maintenance failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('schema_support', 'end_maintenance');
SELECT schema_support.save_grants_for_replay('schema_support', 'end_maintenance');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.end_maintenance ( integer,integer,boolean );
CREATE OR REPLACE FUNCTION schema_support.end_maintenance(minnumdiff integer DEFAULT 0, minpercent integer DEFAULT 0, skipchecks boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
	issuper BOOLEAN;
	_r		RECORD;
	doh	boolean DEFAULT false;
	_myrole	TEXT;
BEGIN
	SELECT usesuper INTO issuper FROM pg_user where usename = current_user;
	IF issuper THEN
		EXECUTE 'ALTER USER ' || current_user || ' NOSUPERUSER';
	END IF;

	PERFORM groname, rolname
	FROM (
		SELECT groname, unnest(grolist) AS oid
		FROM pg_group ) g
	JOIN pg_roles r USING (oid)
	WHERE groname = 'dba'
	AND rolname = current_user;

	IF FOUND THEN
		SELECT current_role INTO _myrole;
		SET role=dba;
		EXECUTE 'REVOKE dba FROM ' || _myrole;
		EXECUTE 'SET role =' || _myrole;
	END IF;

	--
	-- Stash counts of things that may relate to this maintenance for
	-- alter verification and statistics
	--
	-- similar code is in begin_maintenance (the INSERT query is the same
	--

	CREATE TEMPORARY TABLE __owner_after_stats (
		username			TEXT,
		after_views_count	INTEGER,
		after_func_count	INTEGER,
		after_key_count		INTEGER,
		PRIMARY KEY (username)
	);
	INSERT INTO __owner_after_stats
		SELECT rolname, coalesce(numrels, 0) AS numrels,
		coalesce(numprocs, 0) AS numprocs,
		coalesce(numfks, 0) AS numfks
		FROM pg_roles r
			LEFT JOIN (
		SELECT relowner, count(*) AS numrels
				FROM pg_class
				WHERE relkind IN ('r','v')
				GROUP BY 1
				) c ON r.oid = c.relowner
			LEFT JOIN (SELECT proowner, count(*) AS numprocs
				FROM pg_proc
				GROUP BY 1
				) p ON r.oid = p.proowner
			LEFT JOIN (
				SELECT relowner, count(*) AS numfks
				FROM pg_class r JOIN pg_constraint fk ON fk.confrelid = r.oid
				WHERE contype = 'f'
				GROUP BY 1
			) fk ON r.oid = fk.relowner
		WHERE r.oid > 16384
	AND (numrels IS NOT NULL OR numprocs IS NOT NULL OR numfks IS NOT NULL);

	--
	-- sanity checks
	--
	IF skipchecks THEN
		RETURN true;
	END IF;

	RAISE NOTICE 'Object difference count by username:';
	FOR _r IN SELECT *,
			abs(after_views_count - before_views_count) as viewdelta,
			abs(after_func_count - before_func_count) as funcdelta,
			abs(after_key_count - before_key_count) as keydelta
		FROM __owner_before_stats JOIN __owner_after_stats USING (username)
	LOOP
		IF _r.viewdelta = 0 AND _r.funcdelta = 0 AND _r.keydelta = 0 THEN
			CONTINUE;
		END IF;
		RAISE NOTICE '%: % v % / % v % / % v %',
			_r.username,
			_r.before_views_count,
			_r.after_views_count,
			_r.before_func_count,
			_r.after_func_count,
			_r.before_key_count,
			_r.after_key_count;
		IF _r.username = current_user THEN
			CONTINUE;
		END IF;
		IF _r.viewdelta > 0 THEN
			IF _r.viewdelta  > minnumdiff OR
				(_r.viewdelta / _r.before_views_count )*100 > minpercent
			THEN
				RAISE NOTICE '!!! view changes not within tolerence';
				doh := 1;
			ELSE
				RAISE NOTICE
					'... View changes within tolerence (%/% %%), I will allow it: %/% %%',
						minnumdiff, minpercent,
						_r.viewdelta,
						((_r.viewdelta::float / _r.before_views_count ))*100;
			END IF;
		END IF;
		IF _r.funcdelta > 0 THEN
			IF _r.funcdelta  > minnumdiff OR
				(_r.funcdelta / _r.before_func_count )*100 > minpercent
			THEN
				RAISE NOTICE '!!! function changes not within tolerence';
				doh := 1;
			ELSE
				RAISE NOTICE
					'... Function changes within tolerence (%/% %%), I will allow it: %/% %%',
						minnumdiff, minpercent,
						_r.funcdelta,
						((_r.funcdelta::float / _r.before_func_count ))*100;
			END IF;
		END IF;
		IF _r.keydelta > 0 THEN
			IF _r.keydelta  > minnumdiff OR
				(_r.keydelta / _r.before_key_count )*100 > 100 - minpercent
			THEN
				RAISE NOTICE '!!! fk constraint changes not within tolerence';
				doh := 1;
			ELSE
				RAISE NOTICE
					'... Function changes within tolerence (%/% %%), I will allow it, %/% %%',
						minnumdiff, minpercent,
						_r.keydelta,
						((_r.keydelta::float / _r.before_keys_count ))*100;
			END IF;
		END IF;
	END LOOP;

	IF doh THEN
		RAISE EXCEPTION 'Too many changes, abort!';
	END IF;
	RETURN true;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'schema_support' AND type = 'function' AND object IN ('end_maintenance');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc end_maintenance failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('schema_support', 'rebuild_audit_trigger');
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_trigger');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_trigger ( character varying,character varying,character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_trigger(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    EXECUTE 'CREATE OR REPLACE FUNCTION ' || quote_ident(tbl_schema)
	|| '.' || quote_ident('perform_audit_' || table_name)
	|| $ZZ$() RETURNS TRIGGER AS $TQ$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		appuser := concat_ws('/', session_user,
			coalesce(
				current_setting('jazzhands.appuser', true),
				current_setting('request.header.x-remote-user', true)
			)
		);

		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO $ZZ$ || quote_ident(aud_schema)
			|| '.' || quote_ident(table_name) || $ZZ$
		    VALUES ( OLD.*, 'DEL', now(),
			clock_timestamp(), txid_current(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
			IF OLD != NEW THEN
				INSERT INTO $ZZ$ || quote_ident(aud_schema)
				|| '.' || quote_ident(table_name) || $ZZ$
				VALUES ( NEW.*, 'UPD', now(),
				clock_timestamp(), txid_current(), appuser );
			END IF;
			RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO $ZZ$ || quote_ident(aud_schema)
			|| '.' || quote_ident(table_name) || $ZZ$
		    VALUES ( NEW.*, 'INS', now(),
			clock_timestamp(), txid_current(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$TQ$ LANGUAGE plpgsql SECURITY DEFINER
    $ZZ$;

    EXECUTE format(
	'REVOKE ALL ON FUNCTION %s.%s() FROM public',
		quote_ident(tbl_schema),
		quote_ident('perform_audit_' || table_name)
	);

    EXECUTE 'DROP TRIGGER IF EXISTS ' || quote_ident('trigger_audit_'
	|| table_name) || ' ON ' || quote_ident(tbl_schema) || '.'
	|| quote_ident(table_name);

    EXECUTE 'CREATE TRIGGER ' || quote_ident('trigger_audit_' || table_name)
	|| ' AFTER INSERT OR UPDATE OR DELETE ON ' || quote_ident(tbl_schema)
	|| '.' || quote_ident(table_name) || ' FOR EACH ROW EXECUTE PROCEDURE '
	|| quote_ident(tbl_schema) || '.' || quote_ident('perform_audit_'
	|| table_name) || '()';
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'schema_support' AND type = 'function' AND object IN ('rebuild_audit_trigger');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc rebuild_audit_trigger failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('schema_support', 'save_constraint_for_replay');
SELECT schema_support.save_grants_for_replay('schema_support', 'save_constraint_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_constraint_for_replay ( character varying,character varying,boolean,character varying,jsonb,text[],text[] );
CREATE OR REPLACE FUNCTION schema_support.save_constraint_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, newobject character varying DEFAULT NULL::character varying, newmap jsonb DEFAULT NULL::jsonb, tags text[] DEFAULT NULL::text[], path text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
	_def	TEXT;
	_cols	TEXT;
	_myname	TEXT;
		_myrole TEXT;
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

	BEGIN
		SELECT current_role INTO _myrole;
		SET ROLE = dba;
	EXCEPTION WHEN insufficient_privilege OR invalid_parameter_value THEN
		RAISE NOTICE 'Failed to raise privilege: % (%), crossing fingers', SQLERRM, SQLSTATE;
	END;

	-- This used to be just "def" but a once this was incorporating
	-- tables and columns changing name, had to construct the definition
	-- by hand.  yay.  Most of this query is to match the two sides
	-- together.  This query took way too long to figure out.
	--
	FOR _r in
		SELECT otherside.nspname, otherside.relname, otherside.conname,
		    pg_get_constraintdef(otherside.oid, true) AS def,
		    otherside.conname, otherside.condeferrable, otherside.condeferred,
			otherside.cols as cols,
		    myside.nspname as mynspname, myside.relname as myrelname,
		    myside.cols as mycols, myside.conname as myconname
		FROM
		    (
			SELECT me.oid, n.oid as namespaceid, nspname, relname,
				conrelid, conindid, confrelid, conname, connamespace,
				condeferrable, condeferred,
				array_agg(attname ORDER BY attnum) as cols
			FROM (
			    SELECT con.*, a.attname, a.attnum
			    FROM
				    ( SELECT oid, conrelid, conindid, confrelid,
					contype, connamespace,
					condeferrable, condeferred, conname,
					unnest(conkey) as conkey
					FROM pg_constraint
				    ) con
				JOIN pg_attribute a ON a.attrelid = con.conrelid
					AND a.attnum = con.conkey
				WHERE contype IN ('f')
			) me
				JOIN pg_class c ON c.oid = me.conrelid
				JOIN pg_namespace n ON c.relnamespace = n.oid
			GROUP BY 1,2,3,4,5,6,7,8,9,10,11
		    ) otherside JOIN
		    (
			SELECT me.oid, n.oid as namespaceid, nspname, relname,
				conrelid, conindid, confrelid, conname, connamespace,
				condeferrable, condeferred,
				array_agg(attname ORDER BY attnum) as cols
			FROM (
			    SELECT con.*, a.attname, a.attnum
			    FROM
				    ( SELECT oid, conrelid, conindid, confrelid,
					contype, connamespace,
					condeferrable, condeferred, conname,
					unnest(conkey) as conkey
					FROM pg_constraint
				    ) con
				JOIN pg_attribute a ON a.attrelid = con.conrelid
					AND a.attnum = con.conkey
				WHERE contype IN ('u','p')
			) me
				JOIN pg_class c ON c.oid = me.conrelid
				JOIN pg_namespace n ON c.relnamespace = n.oid
			GROUP BY 1,2,3,4,5,6,7,8,9,10,11
		    ) myside ON myside.conrelid = otherside.confrelid
			    AND myside.conindid = otherside.conindid
		WHERE myside.namespaceid != otherside.namespaceid
		AND myside.nspname = schema
		AND myside.relname = object
	LOOP
		--
		-- if my name is changing, reflect that in the recreation
		--
		IF newobject IS NOT NULL THEN
			_myname := newobject;
		ELSE
			_myname := object;
		END IF;
		_cols := array_to_string(_r.mycols, ',');
		--
		-- If newmap is set *AMD* contains a key of the constraint name
		-- on "my" side, then replace the column list with the new names.
		--
		IF newmap IS NOT NULL AND newmap->>_r.myconname IS NOT NULL THEN
			SELECT string_agg(x::text, ',') INTO _cols
				FROM jsonb_array_elements_text(newmap->_r.myconname->'columns') x;
		END IF;
		_def := concat('FOREIGN KEY (', array_to_string(_r.cols, ','),
			') REFERENCES ',
			schema, '.', _myname, '(', _cols, ')');

		IF _r.condeferrable THEN
			_def := _def || ' DEFERRABLE';
		END IF;

		IF _r.condeferred THEN
			_def := _def || ' INITIALLY DEFERRED';
		ELSE
			_def := _def || ' INITIALLY IMMEDIATE';
		END IF;

		_ddl := 'ALTER TABLE ' || _r.nspname || '.' || _r.relname ||
			' ADD CONSTRAINT ' || _r.conname || ' ' || _def;
		IF _ddl is NULL THEN
			RAISE EXCEPTION 'Unable to define constraint for %', _r;
		END IF;
		INSERT INTO __recreate (schema, object, type, ddl, tags , path)
			VALUES (
				_r.nspname, _r.relname, 'constraint', _ddl, tags, path
			);
		IF dropit  THEN
			_cmd = 'ALTER TABLE ' || _r.nspname || '.' || _r.relname ||
				' DROP CONSTRAINT ' || _r.conname || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;

	IF _myrole IS NOT NULL THEN
		EXECUTE 'SET role = ' || _myrole;
	END IF;

END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'schema_support' AND type = 'function' AND object IN ('save_constraint_for_replay');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc save_constraint_for_replay failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('schema_support', 'save_grants_for_replay_functions');
SELECT schema_support.save_grants_for_replay('schema_support', 'save_grants_for_replay_functions');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_grants_for_replay_functions ( character varying,character varying,character varying,text[] );
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay_functions(schema character varying, object character varying, newname character varying DEFAULT NULL::character varying, tags text[] DEFAULT NULL::text[])
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
			_fullgrant := format(
				'GRANT %s on FUNCTION %s.%s TO %s%s',
				_perm.privilege_type, _schema,
				newname || '(' || _procs.args || ')',
				_role, _grant);
			-- RAISE DEBUG 'inserting % for %', _fullgrant, _perm;
			INSERT INTO __regrants (schema, object, newname, regrant, tags) values (schema,object, newname, _fullgrant, tags );

			-- revoke stuff from public, too
			_fullgrant := format('REVOKE ALL ON FUNCTION %s.%s FROM public',
				_schema, newname || '(' || _procs.args || ')');
			-- RAISE DEBUG 'inserting % for %', _fullgrant, _perm;
			INSERT INTO __regrants (schema, object, newname, regrant, tags) values (schema,object, newname, _fullgrant, tags );
		END LOOP;
	END LOOP;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'schema_support' AND type = 'function' AND object IN ('save_grants_for_replay_functions');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc save_grants_for_replay_functions failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_schema_support']);
-- DONE: process_ancillary_schema(schema_support)
--
-- Process middle (non-trigger) schema jazzhands_cache
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_cache']);
--
-- Process middle (non-trigger) schema schema_support
--
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('schema_support', 'begin_maintenance');
SELECT schema_support.save_grants_for_replay('schema_support', 'begin_maintenance');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.begin_maintenance ( boolean );
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
			PERFORM groname, rolname
			FROM (
				SELECT groname, unnest(grolist) AS oid
				FROM pg_group ) g
			JOIN pg_roles r USING (oid)
			WHERE groname = 'dba'
			AND rolname = current_user;

			IF NOT FOUND THEN
				RAISE EXCEPTION 'User must be a super user or have the dba role';
			END IF;
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

	--
	-- Stash counts of things that may relate to this maintenance for
	-- alter verification and statistics
	--
	-- similar code is in end_maintenance (the INSERT query is the same
	--
	CREATE TEMPORARY TABLE __owner_before_stats (
		username					TEXT,
		before_views_count			INTEGER,
		before_func_count		INTEGER,
		before_key_count	INTEGER,
		PRIMARY KEY (username)
	);
	INSERT INTO __owner_before_stats
		SELECT rolname, coalesce(numrels, 0) AS numrels,
		coalesce(numprocs, 0) AS numprocs,
		coalesce(numfks, 0) AS numfks
		FROM pg_roles r
			LEFT JOIN (
		SELECT relowner, count(*) AS numrels
				FROM pg_class
				WHERE relkind IN ('r','v')
				GROUP BY 1
				) c ON r.oid = c.relowner
			LEFT JOIN (SELECT proowner, count(*) AS numprocs
				FROM pg_proc
				GROUP BY 1
				) p ON r.oid = p.proowner
			LEFT JOIN (
				SELECT relowner, count(*) AS numfks
				FROM pg_class r JOIN pg_constraint fk ON fk.confrelid = r.oid
				WHERE contype = 'f'
				GROUP BY 1
			) fk ON r.oid = fk.relowner
		WHERE r.oid > 16384
	AND (numrels IS NOT NULL OR numprocs IS NOT NULL OR numfks IS NOT NULL);

	RETURN true;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'schema_support' AND type = 'function' AND object IN ('begin_maintenance');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc begin_maintenance failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('schema_support', 'end_maintenance');
SELECT schema_support.save_grants_for_replay('schema_support', 'end_maintenance');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.end_maintenance ( integer,integer,boolean );
CREATE OR REPLACE FUNCTION schema_support.end_maintenance(minnumdiff integer DEFAULT 0, minpercent integer DEFAULT 0, skipchecks boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
	issuper BOOLEAN;
	_r		RECORD;
	doh	boolean DEFAULT false;
	_myrole	TEXT;
BEGIN
	SELECT usesuper INTO issuper FROM pg_user where usename = current_user;
	IF issuper THEN
		EXECUTE 'ALTER USER ' || current_user || ' NOSUPERUSER';
	END IF;

	PERFORM groname, rolname
	FROM (
		SELECT groname, unnest(grolist) AS oid
		FROM pg_group ) g
	JOIN pg_roles r USING (oid)
	WHERE groname = 'dba'
	AND rolname = current_user;

	IF FOUND THEN
		SELECT current_role INTO _myrole;
		SET role=dba;
		EXECUTE 'REVOKE dba FROM ' || _myrole;
		EXECUTE 'SET role =' || _myrole;
	END IF;

	--
	-- Stash counts of things that may relate to this maintenance for
	-- alter verification and statistics
	--
	-- similar code is in begin_maintenance (the INSERT query is the same
	--

	CREATE TEMPORARY TABLE __owner_after_stats (
		username			TEXT,
		after_views_count	INTEGER,
		after_func_count	INTEGER,
		after_key_count		INTEGER,
		PRIMARY KEY (username)
	);
	INSERT INTO __owner_after_stats
		SELECT rolname, coalesce(numrels, 0) AS numrels,
		coalesce(numprocs, 0) AS numprocs,
		coalesce(numfks, 0) AS numfks
		FROM pg_roles r
			LEFT JOIN (
		SELECT relowner, count(*) AS numrels
				FROM pg_class
				WHERE relkind IN ('r','v')
				GROUP BY 1
				) c ON r.oid = c.relowner
			LEFT JOIN (SELECT proowner, count(*) AS numprocs
				FROM pg_proc
				GROUP BY 1
				) p ON r.oid = p.proowner
			LEFT JOIN (
				SELECT relowner, count(*) AS numfks
				FROM pg_class r JOIN pg_constraint fk ON fk.confrelid = r.oid
				WHERE contype = 'f'
				GROUP BY 1
			) fk ON r.oid = fk.relowner
		WHERE r.oid > 16384
	AND (numrels IS NOT NULL OR numprocs IS NOT NULL OR numfks IS NOT NULL);

	--
	-- sanity checks
	--
	IF skipchecks THEN
		RETURN true;
	END IF;

	RAISE NOTICE 'Object difference count by username:';
	FOR _r IN SELECT *,
			abs(after_views_count - before_views_count) as viewdelta,
			abs(after_func_count - before_func_count) as funcdelta,
			abs(after_key_count - before_key_count) as keydelta
		FROM __owner_before_stats JOIN __owner_after_stats USING (username)
	LOOP
		IF _r.viewdelta = 0 AND _r.funcdelta = 0 AND _r.keydelta = 0 THEN
			CONTINUE;
		END IF;
		RAISE NOTICE '%: % v % / % v % / % v %',
			_r.username,
			_r.before_views_count,
			_r.after_views_count,
			_r.before_func_count,
			_r.after_func_count,
			_r.before_key_count,
			_r.after_key_count;
		IF _r.username = current_user THEN
			CONTINUE;
		END IF;
		IF _r.viewdelta > 0 THEN
			IF _r.viewdelta  > minnumdiff OR
				(_r.viewdelta / _r.before_views_count )*100 > minpercent
			THEN
				RAISE NOTICE '!!! view changes not within tolerence';
				doh := 1;
			ELSE
				RAISE NOTICE
					'... View changes within tolerence (%/% %%), I will allow it: %/% %%',
						minnumdiff, minpercent,
						_r.viewdelta,
						((_r.viewdelta::float / _r.before_views_count ))*100;
			END IF;
		END IF;
		IF _r.funcdelta > 0 THEN
			IF _r.funcdelta  > minnumdiff OR
				(_r.funcdelta / _r.before_func_count )*100 > minpercent
			THEN
				RAISE NOTICE '!!! function changes not within tolerence';
				doh := 1;
			ELSE
				RAISE NOTICE
					'... Function changes within tolerence (%/% %%), I will allow it: %/% %%',
						minnumdiff, minpercent,
						_r.funcdelta,
						((_r.funcdelta::float / _r.before_func_count ))*100;
			END IF;
		END IF;
		IF _r.keydelta > 0 THEN
			IF _r.keydelta  > minnumdiff OR
				(_r.keydelta / _r.before_key_count )*100 > 100 - minpercent
			THEN
				RAISE NOTICE '!!! fk constraint changes not within tolerence';
				doh := 1;
			ELSE
				RAISE NOTICE
					'... Function changes within tolerence (%/% %%), I will allow it, %/% %%',
						minnumdiff, minpercent,
						_r.keydelta,
						((_r.keydelta::float / _r.before_keys_count ))*100;
			END IF;
		END IF;
	END LOOP;

	IF doh THEN
		RAISE EXCEPTION 'Too many changes, abort!';
	END IF;
	RETURN true;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'schema_support' AND type = 'function' AND object IN ('end_maintenance');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc end_maintenance failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('schema_support', 'rebuild_audit_trigger');
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_trigger');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_trigger ( character varying,character varying,character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_trigger(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    EXECUTE 'CREATE OR REPLACE FUNCTION ' || quote_ident(tbl_schema)
	|| '.' || quote_ident('perform_audit_' || table_name)
	|| $ZZ$() RETURNS TRIGGER AS $TQ$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		appuser := concat_ws('/', session_user,
			coalesce(
				current_setting('jazzhands.appuser', true),
				current_setting('request.header.x-remote-user', true)
			)
		);

		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO $ZZ$ || quote_ident(aud_schema)
			|| '.' || quote_ident(table_name) || $ZZ$
		    VALUES ( OLD.*, 'DEL', now(),
			clock_timestamp(), txid_current(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
			IF OLD != NEW THEN
				INSERT INTO $ZZ$ || quote_ident(aud_schema)
				|| '.' || quote_ident(table_name) || $ZZ$
				VALUES ( NEW.*, 'UPD', now(),
				clock_timestamp(), txid_current(), appuser );
			END IF;
			RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO $ZZ$ || quote_ident(aud_schema)
			|| '.' || quote_ident(table_name) || $ZZ$
		    VALUES ( NEW.*, 'INS', now(),
			clock_timestamp(), txid_current(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$TQ$ LANGUAGE plpgsql SECURITY DEFINER
    $ZZ$;

    EXECUTE format(
	'REVOKE ALL ON FUNCTION %s.%s() FROM public',
		quote_ident(tbl_schema),
		quote_ident('perform_audit_' || table_name)
	);

    EXECUTE 'DROP TRIGGER IF EXISTS ' || quote_ident('trigger_audit_'
	|| table_name) || ' ON ' || quote_ident(tbl_schema) || '.'
	|| quote_ident(table_name);

    EXECUTE 'CREATE TRIGGER ' || quote_ident('trigger_audit_' || table_name)
	|| ' AFTER INSERT OR UPDATE OR DELETE ON ' || quote_ident(tbl_schema)
	|| '.' || quote_ident(table_name) || ' FOR EACH ROW EXECUTE PROCEDURE '
	|| quote_ident(tbl_schema) || '.' || quote_ident('perform_audit_'
	|| table_name) || '()';
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'schema_support' AND type = 'function' AND object IN ('rebuild_audit_trigger');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc rebuild_audit_trigger failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('schema_support', 'save_constraint_for_replay');
SELECT schema_support.save_grants_for_replay('schema_support', 'save_constraint_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_constraint_for_replay ( character varying,character varying,boolean,character varying,jsonb,text[],text[] );
CREATE OR REPLACE FUNCTION schema_support.save_constraint_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, newobject character varying DEFAULT NULL::character varying, newmap jsonb DEFAULT NULL::jsonb, tags text[] DEFAULT NULL::text[], path text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
	_def	TEXT;
	_cols	TEXT;
	_myname	TEXT;
		_myrole TEXT;
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

	BEGIN
		SELECT current_role INTO _myrole;
		SET ROLE = dba;
	EXCEPTION WHEN insufficient_privilege OR invalid_parameter_value THEN
		RAISE NOTICE 'Failed to raise privilege: % (%), crossing fingers', SQLERRM, SQLSTATE;
	END;

	-- This used to be just "def" but a once this was incorporating
	-- tables and columns changing name, had to construct the definition
	-- by hand.  yay.  Most of this query is to match the two sides
	-- together.  This query took way too long to figure out.
	--
	FOR _r in
		SELECT otherside.nspname, otherside.relname, otherside.conname,
		    pg_get_constraintdef(otherside.oid, true) AS def,
		    otherside.conname, otherside.condeferrable, otherside.condeferred,
			otherside.cols as cols,
		    myside.nspname as mynspname, myside.relname as myrelname,
		    myside.cols as mycols, myside.conname as myconname
		FROM
		    (
			SELECT me.oid, n.oid as namespaceid, nspname, relname,
				conrelid, conindid, confrelid, conname, connamespace,
				condeferrable, condeferred,
				array_agg(attname ORDER BY attnum) as cols
			FROM (
			    SELECT con.*, a.attname, a.attnum
			    FROM
				    ( SELECT oid, conrelid, conindid, confrelid,
					contype, connamespace,
					condeferrable, condeferred, conname,
					unnest(conkey) as conkey
					FROM pg_constraint
				    ) con
				JOIN pg_attribute a ON a.attrelid = con.conrelid
					AND a.attnum = con.conkey
				WHERE contype IN ('f')
			) me
				JOIN pg_class c ON c.oid = me.conrelid
				JOIN pg_namespace n ON c.relnamespace = n.oid
			GROUP BY 1,2,3,4,5,6,7,8,9,10,11
		    ) otherside JOIN
		    (
			SELECT me.oid, n.oid as namespaceid, nspname, relname,
				conrelid, conindid, confrelid, conname, connamespace,
				condeferrable, condeferred,
				array_agg(attname ORDER BY attnum) as cols
			FROM (
			    SELECT con.*, a.attname, a.attnum
			    FROM
				    ( SELECT oid, conrelid, conindid, confrelid,
					contype, connamespace,
					condeferrable, condeferred, conname,
					unnest(conkey) as conkey
					FROM pg_constraint
				    ) con
				JOIN pg_attribute a ON a.attrelid = con.conrelid
					AND a.attnum = con.conkey
				WHERE contype IN ('u','p')
			) me
				JOIN pg_class c ON c.oid = me.conrelid
				JOIN pg_namespace n ON c.relnamespace = n.oid
			GROUP BY 1,2,3,4,5,6,7,8,9,10,11
		    ) myside ON myside.conrelid = otherside.confrelid
			    AND myside.conindid = otherside.conindid
		WHERE myside.namespaceid != otherside.namespaceid
		AND myside.nspname = schema
		AND myside.relname = object
	LOOP
		--
		-- if my name is changing, reflect that in the recreation
		--
		IF newobject IS NOT NULL THEN
			_myname := newobject;
		ELSE
			_myname := object;
		END IF;
		_cols := array_to_string(_r.mycols, ',');
		--
		-- If newmap is set *AMD* contains a key of the constraint name
		-- on "my" side, then replace the column list with the new names.
		--
		IF newmap IS NOT NULL AND newmap->>_r.myconname IS NOT NULL THEN
			SELECT string_agg(x::text, ',') INTO _cols
				FROM jsonb_array_elements_text(newmap->_r.myconname->'columns') x;
		END IF;
		_def := concat('FOREIGN KEY (', array_to_string(_r.cols, ','),
			') REFERENCES ',
			schema, '.', _myname, '(', _cols, ')');

		IF _r.condeferrable THEN
			_def := _def || ' DEFERRABLE';
		END IF;

		IF _r.condeferred THEN
			_def := _def || ' INITIALLY DEFERRED';
		ELSE
			_def := _def || ' INITIALLY IMMEDIATE';
		END IF;

		_ddl := 'ALTER TABLE ' || _r.nspname || '.' || _r.relname ||
			' ADD CONSTRAINT ' || _r.conname || ' ' || _def;
		IF _ddl is NULL THEN
			RAISE EXCEPTION 'Unable to define constraint for %', _r;
		END IF;
		INSERT INTO __recreate (schema, object, type, ddl, tags , path)
			VALUES (
				_r.nspname, _r.relname, 'constraint', _ddl, tags, path
			);
		IF dropit  THEN
			_cmd = 'ALTER TABLE ' || _r.nspname || '.' || _r.relname ||
				' DROP CONSTRAINT ' || _r.conname || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;

	IF _myrole IS NOT NULL THEN
		EXECUTE 'SET role = ' || _myrole;
	END IF;

END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'schema_support' AND type = 'function' AND object IN ('save_constraint_for_replay');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc save_constraint_for_replay failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('schema_support', 'save_grants_for_replay_functions');
SELECT schema_support.save_grants_for_replay('schema_support', 'save_grants_for_replay_functions');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_grants_for_replay_functions ( character varying,character varying,character varying,text[] );
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay_functions(schema character varying, object character varying, newname character varying DEFAULT NULL::character varying, tags text[] DEFAULT NULL::text[])
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
			_fullgrant := format(
				'GRANT %s on FUNCTION %s.%s TO %s%s',
				_perm.privilege_type, _schema,
				newname || '(' || _procs.args || ')',
				_role, _grant);
			-- RAISE DEBUG 'inserting % for %', _fullgrant, _perm;
			INSERT INTO __regrants (schema, object, newname, regrant, tags) values (schema,object, newname, _fullgrant, tags );

			-- revoke stuff from public, too
			_fullgrant := format('REVOKE ALL ON FUNCTION %s.%s FROM public',
				_schema, newname || '(' || _procs.args || ')');
			-- RAISE DEBUG 'inserting % for %', _fullgrant, _perm;
			INSERT INTO __regrants (schema, object, newname, regrant, tags) values (schema,object, newname, _fullgrant, tags );
		END LOOP;
	END LOOP;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'schema_support' AND type = 'function' AND object IN ('save_grants_for_replay_functions');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc save_grants_for_replay_functions failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_schema_support']);
--
-- Process middle (non-trigger) schema jazzhands
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands']);
--
-- Process middle (non-trigger) schema net_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_net_manip']);
--
-- Process middle (non-trigger) schema network_strings
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_network_strings']);
--
-- Process middle (non-trigger) schema time_util
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_time_util']);
--
-- Process middle (non-trigger) schema dns_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_dns_utils']);
--
-- Process middle (non-trigger) schema obfuscation_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_obfuscation_utils']);
--
-- Process middle (non-trigger) schema person_manip
--
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('person_manip', 'change_company');
SELECT schema_support.save_grants_for_replay('person_manip', 'change_company');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS person_manip.change_company ( integer,integer,integer,integer );
CREATE OR REPLACE FUNCTION person_manip.change_company(final_company_id integer, person_id integer, initial_company_id integer, account_realm_id integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	initial_person_company  person_company%ROWTYPE;
	_arid			account_realm.account_realm_id%TYPE;
BEGIN
	IF change_company.account_realm_id IS NULL THEN
		SELECT	p.account_realm_id
		INTO	_arid
		FROM	property p
		WHERE	property_type = 'Defaults'
		AND	property_name = '_root_account_realm_id';
	ELSE
		_arid := change_company.account_realm_id;
	END IF;
	set constraints fk_ac_ac_rlm_cpy_act_rlm_cpy DEFERRED;
	set constraints fk_account_prsn_cmpy_acct DEFERRED;
	set constraints fk_account_company_person DEFERRED;
	set constraints fk_pers_comp_attr_person_comp_id DEFERRED;

	UPDATE person_account_realm_company parm
		SET company_id = final_company_id
	WHERE parm.person_id = change_company.person_id
	AND parm.company_id = initial_company_id
	AND parm.account_realm_id = _arid;

	SELECT *
	INTO initial_person_company
	FROM person_company pc
	WHERE pc.person_id = change_company.person_id
	AND pc.company_id = initial_company_id;

	UPDATE person_company pc
	SET company_id = final_company_id
	WHERE pc.company_id = initial_company_id
	AND pc.person_id = change_company.person_id;

	UPDATE person_company_attribute pca
	SET company_id = final_company_id
	WHERE pca.company_id = initial_company_id
	AND pca.person_id = change_company.person_id;

	UPDATE account a
	SET company_id = final_company_id
	WHERE a.company_id = initial_company_id
	AND a.person_id = change_company.person_id
	AND a.account_realm_id = _arid;

	set constraints fk_ac_ac_rlm_cpy_act_rlm_cpy IMMEDIATE;
	set constraints fk_account_prsn_cmpy_acct IMMEDIATE;
	set constraints fk_account_company_person IMMEDIATE;
	set constraints fk_pers_comp_attr_person_comp_id IMMEDIATE;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'person_manip' AND type = 'function' AND object IN ('change_company');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc change_company failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('person_manip', 'purge_person');
SELECT schema_support.save_grants_for_replay('person_manip', 'purge_person');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS person_manip.purge_person ( integer );
CREATE OR REPLACE FUNCTION person_manip.purge_person(person_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	aid	INTEGER;
BEGIN
	FOR aid IN select account_id
			FROM account a
			WHERE a.person_id = purge_person.person_id
	LOOP
		PERFORM person_manip.purge_account ( aid );
	END LOOP;

	DELETE FROM person_company_attribute pca
		WHERE pca.person_id = purge_person.person_id;
	DELETE FROM person_contact pc WHERE pc.person_id = purge_person.person_id;
	DELETE FROM person_location pl WHERE pl.person_id = purge_person.person_id;
	DELETE FROM person_company pc WHERE pc.person_id = purge_person.person_id;
	DELETE FROM person_account_realm_company pcrc
		WHERE pcrc.person_id = purge_person.person_id;
	DELETE FROM person p WHERE p.person_id = purge_person.person_id;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'person_manip' AND type = 'function' AND object IN ('purge_person');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc purge_person failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_person_manip']);
--
-- Process middle (non-trigger) schema account_password_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_account_password_manip']);
--
-- Process middle (non-trigger) schema audit
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_audit']);
--
-- Process middle (non-trigger) schema auto_ac_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_auto_ac_manip']);
--
-- Process middle (non-trigger) schema port_utils
--
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('port_utils', 'configure_layer1_connect');
SELECT schema_support.save_grants_for_replay('port_utils', 'configure_layer1_connect');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS port_utils.configure_layer1_connect ( integer,integer,integer,integer,integer,text,text,integer );
CREATE OR REPLACE FUNCTION port_utils.configure_layer1_connect(physportid1 integer, physportid2 integer, baud integer DEFAULT '-99'::integer, data_bits integer DEFAULT '-99'::integer, stop_bits integer DEFAULT '-99'::integer, parity text DEFAULT '__unknown__'::text, flw_cntrl text DEFAULT '__unknown__'::text, circuit_id integer DEFAULT '-99'::integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands_legacy'
AS $function$
DECLARE
	tally		integer;
	l1_con_id	jazzhands_legacy.layer1_connection.layer1_connection_id%TYPE;
	l1con		jazzhands_legacy.layer1_connection%ROWTYPE;
	p1_l1_con	jazzhands_legacy.layer1_connection%ROWTYPE;
	p2_l1_con	jazzhands_legacy.layer1_connection%ROWTYPE;
	p1_port		jazzhands_legacy.physical_port%ROWTYPE;
	p2_port		jazzhands_legacy.physical_port%ROWTYPE;
	col_nams	varchar(100) [];
	col_vals	varchar(100) [];
	updateitr	integer;
	i_baud		jazzhands_legacy.layer1_connection.baud%type;
	i_data_bits	jazzhands_legacy.layer1_connection.data_bits%type;
	i_stop_bits	jazzhands_legacy.layer1_connection.stop_bits%type;
	i_parity     	jazzhands_legacy.layer1_connection.parity%type;
	i_flw_cntrl	jazzhands_legacy.layer1_connection.flow_control%type;
	i_circuit_id 	jazzhands_legacy.layer1_connection.circuit_id%type;
BEGIN
	RAISE DEBUG 'looking up % and %', physportid1, physportid2;

	RAISE DEBUG 'min args %:%:% <--', physportid1, physportid2, circuit_id;

	-- First make sure the physical ports exist
	BEGIN
		select	*
		  into	p1_port
		  from	physical_port
		 where	physical_port_id = physportid1;

		select	*
		  into	p2_port
		  from	physical_port
		 where	physical_port_id = physportid2;
	EXCEPTION WHEN no_data_found THEN
		RAISE EXCEPTION 'Two physical ports must be specified'
			USING ERRCODE = -20100;
	END;

	if p1_port.port_type <> p2_port.port_type then
		RAISE EXCEPTION 'Port Types Must match' USING ERRCODE = -20101;
	end if;

	-- see if existing layer1_connection exists
	-- [XXX] probably want to pull out into a cursor
	BEGIN
		select	*
		  into	p1_l1_con
		  from	layer1_connection
		 where	physical_port1_id = physportid1
		    or  physical_port2_id = physportid1;
	EXCEPTION WHEN no_data_found THEN
		NULL;
	END;
	BEGIN
		select	*
		  into	p2_l1_con
		  from	layer1_connection
		 where	physical_port1_id = physportid2
		    or  physical_port2_id = physportid2;

	EXCEPTION WHEN no_data_found THEN
		NULL;
	END;

	updateitr := 0;

	--		need to figure out which ports to reset in some cases
	--		need to check as many combinations as possible.
	--		need to deal with new ids.

	--
	-- If a connection already exists, figure out the right one
	-- If there are two, then remove one.  Favor ones where the left
	-- is this port.
	--
	-- Also falling out of this will be the port needs to be updated,
	-- assuming a port needs to be updated
	--
	RAISE DEBUG 'one is %, the other is %', p1_l1_con.layer1_connection_id,
		p2_l1_con.layer1_connection_id;
	if (p1_l1_con.layer1_connection_id is not NULL) then
		if (p2_l1_con.layer1_connection_id is not NULL) then
			if (p1_l1_con.physical_port1_id = physportid1) then
				--
				-- if this is not true, then the connection already
				-- exists between these two, and layer1_params need to
				-- be set later.  If they are already connected,
				-- this gets discovered here
				--
				if(p1_l1_con.physical_port2_id != physportid2) then
					--
					-- physport1 is connected to something, just not this
					--
					RAISE DEBUG 'physport1 is connected to something, just not this';
					l1_con_id := p1_l1_con.layer1_connection_id;
					--
					-- physport2 is connected to something, which needs to go away, so make it go away
					--
					if(p2_l1_con.layer1_connection_id is not NULL) then
						RAISE DEBUG 'physport2 is connected to something, just not this';
						RAISE DEBUG '>>>> removing %',
							p2_l1_con.layer1_connection_id;
						delete from layer1_connection
							where layer1_connection_id =
								p2_l1_con.layer1_connection_id;
					end if;
				else
					l1_con_id := p1_l1_con.layer1_connection_id;
					RAISE DEBUG 'they''re already connected';
				end if;
			elsif (p1_l1_con.physical_port2_id = physportid1) then
				RAISE DEBUG '>>> connection is backwards!';
				if (p1_l1_con.physical_port1_id != physportid2) then
					if (p2_l1_con.physical_port1_id = physportid1) then
						l1_con_id := p2_l1_con.layer1_connection_id;
						RAISE DEBUG '>>>>+ removing %', p1_l1_con.layer1_connection_id;
						delete from layer1_connection
							where layer1_connection_id =
								p1_l1_con.layer1_connection_id;
					else
						if (p1_l1_con.physical_port1_id = physportid1) then
							l1_con_id := p1_l1_con.layer1_connection_id;
						else
							-- p1_l1_con.physical_port2_id must be physportid1
							l1_con_id := p1_l1_con.layer1_connection_id;
						end if;
						RAISE DEBUG '>>>>- removing %', p2_l1_con.layer1_connection_id;
						delete from layer1_connection
							where layer1_connection_id =
								p2_l1_con.layer1_connection_id;
					end if;
				else
					RAISE DEBUG 'they''re already connected, but backwards';
					l1_con_id := p1_l1_con.layer1_connection_id;
				end if;
			end if;
		else
			RAISE DEBUG 'p1 is connected, bt p2 is not';
			l1_con_id := p1_l1_con.layer1_connection_id;
		end if;
	elsif(p2_l1_con.layer1_connection_id is NULL) then
		-- both are null in this case

		IF (circuit_id = -99) THEN
			i_circuit_id := NULL;
		ELSE
			i_circuit_id := circuit_id;
		END IF;
		IF (baud = -99) THEN
			i_baud := NULL;
		ELSE
			i_baud := baud;
		END IF;
		IF data_bits = -99 THEN
			i_data_bits := NULL;
		ELSE
			i_data_bits := data_bits;
		END IF;
		IF stop_bits = -99 THEN
			i_stop_bits := NULL;
		ELSE
			i_stop_bits := stop_bits;
		END IF;
		IF parity = '__unknown__' THEN
			i_parity := NULL;
		ELSE
			i_parity := parity;
		END IF;
		IF flw_cntrl = '__unknown__' THEN
			i_flw_cntrl := NULL;
		ELSE
			i_flw_cntrl := flw_cntrl;
		END IF;
		IF p1_port.port_type = 'serial' THEN
		        insert into layer1_connection (
			        PHYSICAL_PORT1_ID, PHYSICAL_PORT2_ID,
			        BAUD, DATA_BITS, STOP_BITS, PARITY, FLOW_CONTROL,
			        CIRCUIT_ID, IS_TCPSRV_ENABLED
		        ) values (
			        physportid1, physportid2,
			        i_baud, i_data_bits, i_stop_bits, i_parity, i_flw_cntrl,
			        i_circuit_id, true
		        ) RETURNING layer1_connection_id into l1_con_id;
		ELSE
		        insert into layer1_connection (
			        PHYSICAL_PORT1_ID, PHYSICAL_PORT2_ID,
			        BAUD, DATA_BITS, STOP_BITS, PARITY, FLOW_CONTROL,
			        CIRCUIT_ID
		        ) values (
			        physportid1, physportid2,
			        i_baud, i_data_bits, i_stop_bits, i_parity, i_flw_cntrl,
			        i_circuit_id
		        ) RETURNING layer1_connection_id into l1_con_id;
		END IF;
		RAISE DEBUG 'added, l1_con_id is %', l1_con_id;
		return 1;
	else
		RAISE DEBUG 'p2 is connected but p1 is not';
		l1_con_id := p2_l1_con.layer1_connection_id;
	end if;

	RAISE DEBUG 'l1_con_id is %', l1_con_id;

	-- check to see if both ends are the same type
	-- see if they're already connected.  If not, zap the connection
	--	that doesn't match this port1/port2 config (favor first port)
	-- update various variables
	select	*
	  into	l1con
	  from	layer1_connection
	 where	layer1_connection_id = l1_con_id;

	if (l1con.PHYSICAL_PORT1_ID != physportid1 OR
			l1con.PHYSICAL_PORT2_ID != physportid2) AND
			(l1con.PHYSICAL_PORT1_ID != physportid2 OR
			l1con.PHYSICAL_PORT2_ID != physportid1)  THEN
		-- this means that one end is wrong, now we need to figure out
		-- which end.
		if(l1con.PHYSICAL_PORT1_ID = physportid1) THEN
			RAISE DEBUG 'update port2 to second port';
			updateitr := updateitr + 1;
			col_nams[updateitr] := 'PHYSICAL_PORT2_ID';
			col_vals[updateitr] := physportid2;
		elsif(l1con.PHYSICAL_PORT2_ID = physportid1) THEN
			RAISE DEBUG 'update port1 to second port';
			updateitr := updateitr + 1;
			col_nams[updateitr] := 'PHYSICAL_PORT1_ID';
			col_vals[updateitr] := physportid2;
		elsif(l1con.PHYSICAL_PORT1_ID = physportid2) THEN
			RAISE DEBUG 'update port2 to first port';
			updateitr := updateitr + 1;
			col_nams[updateitr] := 'PHYSICAL_PORT2_ID';
			col_vals[updateitr] := physportid1;
		elsif(l1con.PHYSICAL_PORT2_ID = physportid2) THEN
			RAISE DEBUG 'update port1 to first port';
			updateitr := updateitr + 1;
			col_nams[updateitr] := 'PHYSICAL_PORT1_ID';
			col_vals[updateitr] := physportid1;
		end if;
	end if;

	RAISE DEBUG 'circuit_id -- % v %', circuit_id, l1con.circuit_id;
	if(circuit_id <> -99 and (l1con.circuit_id is NULL or l1con.circuit_id <> circuit_id)) THEN
		RAISE DEBUG 'updating circuit_id';
		updateitr := updateitr + 1;
		col_nams[updateitr] := 'CIRCUIT_ID';
		col_vals[updateitr] := circuit_id;
	end if;

	RAISE DEBUG  'baud: % v %', baud, l1con.baud;
	if(baud <> -99 and (l1con.baud is NULL or l1con.baud <> baud)) THEN
		RAISE DEBUG 'updating baud';
		updateitr := updateitr + 1;
		col_nams[updateitr] := 'BAUD';
		col_vals[updateitr] := baud;
	end if;

	if(data_bits <> -99 and (l1con.data_bits is NULL or l1con.data_bits <> data_bits)) THEN
		RAISE DEBUG 'updating data_bits';
		updateitr := updateitr + 1;
		col_nams[updateitr] := 'DATA_BITS';
		col_vals[updateitr] := data_bits;
	end if;

	if(stop_bits <> -99 and (l1con.stop_bits is NULL or l1con.stop_bits <> stop_bits)) THEN
		RAISE DEBUG 'updating stop bits';
		updateitr := updateitr + 1;
		col_nams[updateitr] := 'STOP_BITS';
		col_vals[updateitr] := stop_bits;
	end if;

	if(parity <> '__unknown__' and (l1con.parity is NULL or l1con.parity <> parity)) THEN
		RAISE DEBUG 'updating parity';
		updateitr := updateitr + 1;
		col_nams[updateitr] := 'PARITY';
		col_vals[updateitr] := quote_literal(parity);
	end if;

	if(flw_cntrl <> '__unknown__' and (l1con.parity is NULL or l1con.parity <> flw_cntrl)) THEN
		RAISE DEBUG 'updating flow control';
		updateitr := updateitr + 1;
		col_nams[updateitr] := 'FLOW_CONTROL';
		col_vals[updateitr] := quote_literal(flw_cntrl);
	end if;

	if(updateitr > 0) then
		RAISE DEBUG 'running do_l1_connection_update';
		PERFORM port_utils.do_l1_connection_update(col_nams, col_vals, l1_con_id);
	end if;

	RAISE DEBUG 'returning %', updateitr;
	return updateitr;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'port_utils' AND type = 'function' AND object IN ('configure_layer1_connect');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc configure_layer1_connect failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_port_utils']);
-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('port_utils', 'do_l1_connection_update');
DROP FUNCTION IF EXISTS port_utils.do_l1_connection_update ( character varying[],character varying[],integer );
CREATE OR REPLACE FUNCTION port_utils.do_l1_connection_update(p_cnames character varying[], p_values character varying[], p_l1_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands_legacy'
AS $function$
DECLARE
	l_stmt  varchar(4096);
	l_rc    integer;
	i       integer;
BEGIN
	l_stmt := 'update layer1_connection set ';
	for i in array_lower(p_cnames, 1) .. array_upper(p_cnames, 1)
	LOOP
		if (i > array_lower(p_cnames, 1) ) then
			l_stmt := l_stmt || ',';
		end if;
		l_stmt := l_stmt || p_cnames[i] || '=' || p_values[i];
	END LOOP;
	l_stmt := l_stmt || ' where layer1_connection_id = ' || p_l1_id;
	RAISE DEBUG '%', l_stmt;
	-- note: bind variables, sadly, are not used here, but the only
	-- thing that is supposed to call it,
	-- port_utils.configure_layer1_connect is expected to use
	-- quote_literal to make sure things are properly quoted to avoid
	-- sql injection type attacks.  I would rather use bind variables,
	-- but this does not appear to work for dynamically built queries
	-- in pl/pgsql.  alas.
	EXECUTE l_stmt;
END;
$function$
;

--
-- Process middle (non-trigger) schema company_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_company_manip']);
--
-- Process middle (non-trigger) schema token_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_token_utils']);
--
-- Process middle (non-trigger) schema device_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_device_manip']);
--
-- Process middle (non-trigger) schema device_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_device_utils']);
--
-- Process middle (non-trigger) schema netblock_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_netblock_utils']);
--
-- Process middle (non-trigger) schema property_utils
--
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('property_utils', 'validate_property');
SELECT schema_support.save_grants_for_replay('property_utils', 'validate_property');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS property_utils.validate_property ( new jazzhands.property );
CREATE OR REPLACE FUNCTION property_utils.validate_property(new jazzhands.property)
 RETURNS jazzhands.property
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	tally				integer;
	v_prop				VAL_Property%ROWTYPE;
	v_proptype			VAL_Property_Type%ROWTYPE;
	v_account_collection		account_collection%ROWTYPE;
	v_company_collection		company_collection%ROWTYPE;
	v_device_collection		device_collection%ROWTYPE;
	v_dns_domain_collection		dns_domain_collection%ROWTYPE;
	v_layer2_network_collection	layer2_network_collection%ROWTYPE;
	v_layer3_network_collection	layer3_network_collection%ROWTYPE;
	v_netblock_collection		netblock_collection%ROWTYPE;
	v_network_range				network_range%ROWTYPE;
	v_property_name_collection		property_name_collection%ROWTYPE;
	v_service_environment_collection	service_environment_collection%ROWTYPE;
	v_num				integer;
	v_listvalue			Property.Property_Value%TYPE;
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
	IF (v_prop.is_multivalue = false) THEN
		PERFORM 1 FROM Property WHERE
			Property_Id != NEW.Property_Id AND
			Property_Name = NEW.Property_Name AND
			Property_Type = NEW.Property_Type AND
			account_collection_id IS NOT DISTINCT FROM NEW.account_collection_id
				AND
			account_id IS NOT DISTINCT FROM NEW.account_id AND
			account_realm_id IS NOT DISTINCT FROM NEW.account_realm_id AND
			company_collection_id IS NOT DISTINCT FROM NEW.company_collection_id AND
			company_id IS NOT DISTINCT FROM NEW.company_id AND
			device_collection_id IS NOT DISTINCT FROM NEW.device_collection_id AND
			dns_domain_collection_id IS NOT DISTINCT FROM
				NEW.dns_domain_collection_id AND
			layer2_network_collection_id IS NOT DISTINCT FROM
				NEW.layer2_network_collection_id AND
			layer3_network_collection_id IS NOT DISTINCT FROM
				NEW.layer3_network_collection_id AND
			netblock_collection_id IS NOT DISTINCT FROM NEW.netblock_collection_id AND
			network_range_id IS NOT DISTINCT FROM NEW.network_range_id AND
			operating_system_id IS NOT DISTINCT FROM NEW.operating_system_id AND
			operating_system_snapshot_id IS NOT DISTINCT FROM
				NEW.operating_system_snapshot_id AND
			property_name_collection_id IS NOT DISTINCT FROM NEW.property_name_collection_id AND
			service_environment_collection_id IS NOT DISTINCT FROM
				NEW.service_environment_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code
		;

		IF FOUND THEN
			RAISE EXCEPTION
				'Property of type (%,%) already exists for given LHS and property is not multivalue',
				NEW.Property_Name, NEW.Property_Type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;
	ELSE
		-- check for the same lhs+rhs existing, which is basically a dup row
		PERFORM 1 FROM Property WHERE
			Property_Id != NEW.Property_Id AND
			Property_Name = NEW.Property_Name AND
			Property_Type = NEW.Property_Type AND
			account_collection_id IS NOT DISTINCT FROM NEW.account_collection_id
				AND
			account_id IS NOT DISTINCT FROM NEW.account_id AND
			account_realm_id IS NOT DISTINCT FROM NEW.account_realm_id AND
			company_collection_id IS NOT DISTINCT FROM NEW.company_collection_id AND
			company_id IS NOT DISTINCT FROM NEW.company_id AND
			device_collection_id IS NOT DISTINCT FROM NEW.device_collection_id AND
			dns_domain_collection_id IS NOT DISTINCT FROM
				NEW.dns_domain_collection_id AND
			layer2_network_collection_id IS NOT DISTINCT FROM
				NEW.layer2_network_collection_id AND
			layer3_network_collection_id IS NOT DISTINCT FROM
				NEW.layer3_network_collection_id AND
			netblock_collection_id IS NOT DISTINCT FROM NEW.netblock_collection_id AND
			network_range_id IS NOT DISTINCT FROM NEW.network_range_id AND
			operating_system_id IS NOT DISTINCT FROM NEW.operating_system_id AND
			operating_system_snapshot_id IS NOT DISTINCT FROM
				NEW.operating_system_snapshot_id AND
			property_name_collection_id IS NOT DISTINCT FROM NEW.property_name_collection_id AND
			service_environment_collection_id IS NOT DISTINCT FROM
				NEW.service_environment_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code AND
			property_value IS NOT DISTINCT FROM NEW.property_value AND
			property_value_json IS NOT DISTINCT FROM
				NEW.property_value_json AND
			property_value_boolean IS NOT DISTINCT FROM
				NEW.property_value_boolean AND
			property_value_timestamp IS NOT DISTINCT FROM
				NEW.property_value_timestamp AND
			property_value_account_collection_id IS NOT DISTINCT FROM
				NEW.property_value_account_collection_id AND
			property_value_device_collection_id IS NOT DISTINCT FROM
				NEW.property_value_device_collection_id AND
			property_value_netblock_collection_id IS NOT DISTINCT FROM
				NEW.property_value_netblock_collection_id AND
			property_value_password_type IS NOT DISTINCT FROM
				NEW.property_value_password_type AND
			property_value_sw_package_id IS NOT DISTINCT FROM
				NEW.property_value_sw_package_id AND
			property_value_token_collection_id IS NOT DISTINCT FROM
				NEW.property_value_token_collection_id AND
			property_value_encryption_key_id IS NOT DISTINCT FROM
				NEW.property_value_encryption_key_id AND
			property_value_private_key_id IS NOT DISTINCT FROM
				NEW.property_value_private_key_id AND
			start_date IS NOT DISTINCT FROM NEW.start_date AND
			finish_date IS NOT DISTINCT FROM NEW.finish_date
		;

		IF FOUND THEN
			RAISE EXCEPTION
				'Property of (n,t) (%,%) already exists for given property',
				NEW.Property_Name, NEW.Property_Type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;

	END IF;

	-- Check to see if the property type is multivalue.  That is, if only
	-- one property and value can be set for any properties with this type
	-- for a specific property LHS

	IF (v_proptype.is_multivalue = false) THEN
		PERFORM 1 FROM Property WHERE
			Property_Id != NEW.Property_Id AND
			Property_Type = NEW.Property_Type AND
			account_collection_id IS NOT DISTINCT FROM NEW.account_collection_id
				AND
			account_id IS NOT DISTINCT FROM NEW.account_id AND
			account_realm_id IS NOT DISTINCT FROM NEW.account_realm_id AND
			company_collection_id IS NOT DISTINCT FROM NEW.company_collection_id AND
			company_id IS NOT DISTINCT FROM NEW.company_id AND
			device_collection_id IS NOT DISTINCT FROM NEW.device_collection_id AND
			dns_domain_collection_id IS NOT DISTINCT FROM
				NEW.dns_domain_collection_id AND
			layer2_network_collection_id IS NOT DISTINCT FROM
				NEW.layer2_network_collection_id AND
			layer3_network_collection_id IS NOT DISTINCT FROM
				NEW.layer3_network_collection_id AND
			netblock_collection_id IS NOT DISTINCT FROM NEW.netblock_collection_id AND
			network_range_id IS NOT DISTINCT FROM NEW.network_range_id AND
			operating_system_id IS NOT DISTINCT FROM NEW.operating_system_id AND
			operating_system_snapshot_id IS NOT DISTINCT FROM
				NEW.operating_system_snapshot_id AND
			property_name_collection_id IS NOT DISTINCT FROM NEW.property_name_collection_id AND
			service_environment_collection_id IS NOT DISTINCT FROM
				NEW.service_environment_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code
		;

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
	IF NEW.Property_Value_JSON IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'json' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be JSON' USING
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
	IF NEW.Property_Value_Token_collection_Id IS NOT NULL THEN
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
	IF NEW.Property_Value_Account_collection_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'account_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be account_collection_id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_netblock_collection_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'netblock_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be netblock_collection_id' USING
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
	IF NEW.Property_Value_Device_collection_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'device_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Device_Collection_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF NEW.property_value_boolean IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'boolean' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be boolean' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF NEW.property_value_encryption_key_id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'encryption_key_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be encryption_key_id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF NEW.property_value_private_key_id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'private_key_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be private_key_id' USING
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
		IF v_prop.Property_Data_Type = 'number' THEN
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

	-- If the LHS contains a account_collection_ID, check to see if it must be a
	-- specific type (e.g. per-account), and verify that if so
	IF NEW.account_collection_id IS NOT NULL THEN
		IF v_prop.account_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_account_collection
					FROM account_collection WHERE
					account_collection_Id = NEW.account_collection_id;
				IF v_account_collection.account_collection_Type != v_prop.account_collection_type
				THEN
					RAISE 'account_collection_id must be of type %',
					v_prop.account_collection_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a company_collection_ID, check to see if it must be a
	-- specific type (e.g. per-company), and verify that if so
	IF NEW.company_collection_id IS NOT NULL THEN
		IF v_prop.company_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_company_collection
					FROM company_collection WHERE
					company_collection_Id = NEW.company_collection_id;
				IF v_company_collection.company_collection_Type != v_prop.company_collection_type
				THEN
					RAISE 'company_collection_id must be of type %',
					v_prop.company_collection_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a device_collection_ID, check to see if it must be a
	-- specific type (e.g. per-device), and verify that if so
	IF NEW.device_collection_id IS NOT NULL THEN
		IF v_prop.device_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_device_collection
					FROM device_collection WHERE
					device_collection_Id = NEW.device_collection_id;
				IF v_device_collection.device_collection_Type != v_prop.device_collection_type
				THEN
					RAISE 'device_collection_id must be of type %',
					v_prop.device_collection_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a dns_domain_collection_ID, check to see if it must be a
	-- specific type (e.g. per-dns_domain), and verify that if so
	IF NEW.dns_domain_collection_id IS NOT NULL THEN
		IF v_prop.dns_domain_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_dns_domain_collection
					FROM dns_domain_collection WHERE
					dns_domain_collection_Id = NEW.dns_domain_collection_id;
				IF v_dns_domain_collection.dns_domain_collection_Type != v_prop.dns_domain_collection_type
				THEN
					RAISE 'dns_domain_collection_id must be of type %',
					v_prop.dns_domain_collection_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a layer2_network_collection_ID, check to see if it must be a
	-- specific type (e.g. per-layer2_network), and verify that if so
	IF NEW.layer2_network_collection_id IS NOT NULL THEN
		IF v_prop.layer2_network_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_layer2_network_collection
					FROM layer2_network_collection WHERE
					layer2_network_collection_Id = NEW.layer2_network_collection_id;
				IF v_layer2_network_collection.layer2_network_collection_Type != v_prop.layer2_network_collection_type
				THEN
					RAISE 'layer2_network_collection_id must be of type %',
					v_prop.layer2_network_collection_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a layer3_network_collection_ID, check to see if it must be a
	-- specific type (e.g. per-layer3_network), and verify that if so
	IF NEW.layer3_network_collection_id IS NOT NULL THEN
		IF v_prop.layer3_network_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_layer3_network_collection
					FROM layer3_network_collection WHERE
					layer3_network_collection_Id = NEW.layer3_network_collection_id;
				IF v_layer3_network_collection.layer3_network_collection_Type != v_prop.layer3_network_collection_type
				THEN
					RAISE 'layer3_network_collection_id must be of type %',
					v_prop.layer3_network_collection_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a netblock_collection_ID, check to see if it must be a
	-- specific type (e.g. per-netblock), and verify that if so
	IF NEW.netblock_collection_id IS NOT NULL THEN
		IF v_prop.netblock_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_netblock_collection
					FROM netblock_collection WHERE
					netblock_collection_Id = NEW.netblock_collection_id;
				IF v_netblock_collection.netblock_collection_Type != v_prop.netblock_collection_type
				THEN
					RAISE 'netblock_collection_id must be of type %',
					v_prop.netblock_collection_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a network_range_id, check to see if it must
	-- be a specific type and verify that if so
	IF NEW.netblock_collection_id IS NOT NULL THEN
		IF v_prop.network_range_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_network_range
					FROM network_range WHERE
					network_range_id = NEW.network_range_id;
				IF v_network_range.network_range_type != v_prop.network_range_type
				THEN
					RAISE 'network_range_id must be of type %',
					v_prop.network_range_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a property_name_collection_ID, check to see if it must be a
	-- specific type (e.g. per-property), and verify that if so
	IF NEW.property_name_collection_id IS NOT NULL THEN
		IF v_prop.property_name_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_property_name_collection
					FROM property_name_collection WHERE
					property_name_collection_Id = NEW.property_name_collection_id;
				IF v_property_name_collection.property_name_collection_Type != v_prop.property_name_collection_type
				THEN
					RAISE 'property_name_collection_id must be of type %',
					v_prop.property_name_collection_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a service_environment_collection_ID, check to see if it must be a
	-- specific type (e.g. per-service_env), and verify that if so
	IF NEW.service_environment_collection_id IS NOT NULL THEN
		IF v_prop.service_environment_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_service_environment_collection
					FROM service_environment_collection WHERE
					service_environment_collection_Id = NEW.service_environment_collection_id;
				IF v_service_environment_collection.service_environment_collection_Type != v_prop.service_environment_collection_type
				THEN
					RAISE 'service_environment_collection_id must be of type %',
					v_prop.service_environment_collection_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the RHS contains a account_collection_ID, check to see if it must be a
	-- specific type (e.g. per-account), and verify that if so
	IF NEW.Property_Value_Account_collection_Id IS NOT NULL THEN
		IF v_prop.property_value_account_collection_type_restriction IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_account_collection
					FROM account_collection WHERE
					account_collection_Id = NEW.Property_Value_Account_collection_Id;
				IF v_account_collection.account_collection_Type != v_prop.property_value_account_collection_type_restriction
				THEN
					RAISE 'Property_Value_Account_collection_Id must be of type %',
					v_prop.property_value_account_collection_type_restriction
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
	IF NEW.Property_Value_netblock_collection_Id IS NOT NULL THEN
		IF v_prop.property_value_account_collection_type_restriction IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_netblock_collection
					FROM netblock_collection WHERE
					netblock_collection_Id = NEW.Property_Value_netblock_collection_Id;
				IF v_netblock_collection.netblock_collection_Type != v_prop.property_value_account_collection_type_restriction
				THEN
					RAISE 'Property_Value_netblock_collection_Id must be of type %',
					v_prop.property_value_account_collection_type_restriction
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the RHS contains a device_collection_id, check to see if it must be a
	-- specific type and verify that if so
	IF NEW.Property_Value_Device_collection_Id IS NOT NULL THEN
		IF v_prop.property_value_device_collection_type_restriction IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_device_collection
					FROM device_collection WHERE
					device_collection_id = NEW.Property_Value_Device_collection_Id;
				IF v_device_collection.device_collection_type !=
					v_prop.property_value_device_collection_type_restriction
				THEN
					RAISE 'Property_Value_Device_collection_Id must be of type %',
					v_prop.property_value_device_collection_type_restriction
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	--
	--
	IF v_prop.property_data_type = 'json' THEN
		IF  NOT validate_json_schema(
				v_prop.property_value_json_schema,
				NEW.property_value_json) THEN
			RAISE EXCEPTION 'JSON provided must match the json schema'
				USING ERRCODE = 'invalid_parameter_value';
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

	IF v_prop.Permit_Company_Collection_Id = 'REQUIRED' THEN
			IF NEW.Company_Collection_Id IS NULL THEN
				RAISE 'Company_Collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Company_Collection_Id = 'PROHIBITED' THEN
			IF NEW.Company_Collection_Id IS NOT NULL THEN
				RAISE 'Company_Collection_Id is prohibited.'
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

	IF v_prop.permit_service_environment_collection = 'REQUIRED' THEN
			IF NEW.service_environment_collection_id IS NULL THEN
				RAISE 'service_environment_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_service_environment_collection = 'PROHIBITED' THEN
			IF NEW.service_environment_collection_id IS NOT NULL THEN
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

	IF v_prop.permit_operating_system_snapshot_id = 'REQUIRED' THEN
			IF NEW.operating_system_snapshot_id IS NULL THEN
				RAISE 'operating_system_snapshot_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_operating_system_snapshot_id = 'PROHIBITED' THEN
			IF NEW.operating_system_snapshot_id IS NOT NULL THEN
				RAISE 'operating_system_snapshot_id is prohibited.'
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

	IF v_prop.permit_layer2_network_collection_id = 'REQUIRED' THEN
			IF NEW.layer2_network_collection_id IS NULL THEN
				RAISE 'layer2_network_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_layer2_network_collection_id = 'PROHIBITED' THEN
			IF NEW.layer2_network_collection_id IS NOT NULL THEN
				RAISE 'layer2_network_collection_id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_layer3_network_collection_id = 'REQUIRED' THEN
			IF NEW.layer3_network_collection_id IS NULL THEN
				RAISE 'layer3_network_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_layer3_network_collection_id = 'PROHIBITED' THEN
			IF NEW.layer3_network_collection_id IS NOT NULL THEN
				RAISE 'layer3_network_collection_id is prohibited.'
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

	IF v_prop.Permit_network_range_id = 'REQUIRED' THEN
			IF NEW.network_range_id IS NULL THEN
				RAISE 'network_range_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_network_range_id = 'PROHIBITED' THEN
			IF NEW.network_range_id IS NOT NULL THEN
				RAISE 'network_range_id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_property_name_collection_Id = 'REQUIRED' THEN
			IF NEW.property_name_collection_Id IS NULL THEN
				RAISE 'property_name_collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_property_name_collection_Id = 'PROHIBITED' THEN
			IF NEW.property_name_collection_Id IS NOT NULL THEN
				RAISE 'property_name_collection_Id is prohibited.'
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

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'property_utils' AND type = 'function' AND object IN ('validate_property');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc validate_property failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_property_utils']);
--
-- Process middle (non-trigger) schema netblock_manip
--
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('netblock_manip', 'set_interface_addresses');
SELECT schema_support.save_grants_for_replay('netblock_manip', 'set_interface_addresses');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.set_interface_addresses ( integer,integer,text,text,jsonb,boolean,text,text );
CREATE OR REPLACE FUNCTION netblock_manip.set_interface_addresses(network_interface_id integer DEFAULT NULL::integer, device_id integer DEFAULT NULL::integer, network_interface_name text DEFAULT NULL::text, network_interface_type text DEFAULT 'broadcast'::text, ip_address_hash jsonb DEFAULT NULL::jsonb, create_layer3_networks boolean DEFAULT false, move_addresses text DEFAULT 'if_same_device'::text, address_errors text DEFAULT 'error'::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	RETURN netblock_manip.set_layer3_interface_addresses(
		layer3_network_id := network_interface_id,
		device_id := device_id,
		layer3_interface_name := network_interface_name,
		layer3_interface_type := network_interface_type,
		ip_address_hash := ip_address_hash,
		create_layer3_networks := create_layer3_networks,
		move_addresses := move_addresses,
		address_errors := address_errors
	);
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'netblock_manip' AND type = 'function' AND object IN ('set_interface_addresses');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc set_interface_addresses failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_netblock_manip']);
-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('netblock_manip', 'set_layer3_interface_addresses');
DROP FUNCTION IF EXISTS netblock_manip.set_layer3_interface_addresses ( integer,integer,text,text,jsonb,boolean,text,text );
CREATE OR REPLACE FUNCTION netblock_manip.set_layer3_interface_addresses(layer3_interface_id integer DEFAULT NULL::integer, device_id integer DEFAULT NULL::integer, layer3_interface_name text DEFAULT NULL::text, layer3_interface_type text DEFAULT 'broadcast'::text, ip_address_hash jsonb DEFAULT NULL::jsonb, create_layer3_networks boolean DEFAULT false, move_addresses text DEFAULT 'if_same_device'::text, address_errors text DEFAULT 'error'::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
--
-- ip_address_hash consists of the following elements
--
--		"ip_addresses" : [ (inet | netblock) ... ]
--		"shared_ip_addresses" : [ (inet | netblock) ... ]
--
-- where inet is a text string that can be legally converted to type inet
-- and netblock is a JSON object with fields:
--		"ip_address" : inet
--		"ip_universe_id" : integer (default 0)
--		"netblock_type" : text (default 'default')
--		"protocol" : text (default 'VRRP')
--
-- If either "ip_addresses" or "shared_ip_addresses" does not exist, it
-- will not be processed.  If the key is present and is an empty array or
-- null, then all IP addresses of those types will be removed from the
-- interface
--
-- 'protocol' is only valid for shared addresses, which is how the address
-- is shared.  Valid values can be found in the val_shared_netblock_protocol
-- table
--
DECLARE
	l3i_id			ALIAS FOR layer3_interface_id;
	dev_id			ALIAS FOR device_id;
	l3i_name		ALIAS FOR layer3_interface_name;
	l3i_type		ALIAS FOR layer3_interface_type;

	addrs_ary		jsonb;
	ipaddr			inet;
	universe		integer;
	nb_type			text;
	protocol		text;

	c				integer;
	i				integer;

	error_rec		RECORD;
	nb_rec			RECORD;
	pnb_rec			RECORD;
	layer3_rec		RECORD;
	sn_rec			RECORD;
	l3i_rec			RECORD;
	l3in_rec		RECORD;
	nb_id			jazzhands.netblock.netblock_id%TYPE;
	nb_id_ary		integer[];
	l3i_id_ary		integer[];
	del_list		integer[];
BEGIN
	--
	-- Validate that we got enough information passed to do things
	--

	IF ip_address_hash IS NULL OR NOT
		(jsonb_typeof(ip_address_hash) = 'object')
	THEN
		RAISE 'Must pass ip_addresses to netblock_manip.set_interface_addresses';
	END IF;

	IF layer3_interface_id IS NULL THEN
		IF device_id IS NULL OR layer3_interface_name IS NULL THEN
			RAISE 'netblock_manip.assign_shared_netblock: must pass either layer3_interface_id or device_id and layer3_interface_name'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;

		SELECT
			l3i.layer3_interface_id INTO l3i_id
		FROM
			layer3_interface l3i
		WHERE
			l3i.device_id = dev_id AND
			l3i.layer3_interface_name = l3i_name;

		IF NOT FOUND THEN
			INSERT INTO layer3_interface(
				device_id,
				layer3_interface_name,
				layer3_interface_type,
				should_monitor
			) VALUES (
				dev_id,
				l3i_name,
				l3i_type,
				false
			) RETURNING layer3_interface.layer3_interface_id INTO l3i_id;
		END IF;
	END IF;

	SELECT * INTO l3i_rec FROM layer3_interface l3i WHERE 
		l3i.layer3_interface_id = l3i_id;

	--
	-- First, loop through ip_addresses passed and process those
	--

	IF ip_address_hash ? 'ip_addresses' AND
		jsonb_typeof(ip_address_hash->'ip_addresses') = 'array'
	THEN
		RAISE DEBUG 'Processing ip_addresses...';
		--
		-- Loop through each member of the ip_addresses array
		-- and process each address
		--
		addrs_ary := ip_address_hash->'ip_addresses';
		c := jsonb_array_length(addrs_ary);
		i := 0;
		nb_id_ary := NULL;
		WHILE (i < c) LOOP
			IF jsonb_typeof(addrs_ary->i) = 'string' THEN
				--
				-- If this is a string, use it as an inet with default
				-- universe and netblock_type
				--
				ipaddr := addrs_ary->>i;
				universe := netblock_utils.find_best_ip_universe(ipaddr);
				nb_type := 'default';
			ELSIF jsonb_typeof(addrs_ary->i) = 'object' THEN
				--
				-- If this is an object, require 'ip_address' key
				-- optionally use 'ip_universe_id' and 'netblock_type' keys
				-- to override the defaults
				--
				IF NOT addrs_ary->i ? 'ip_address' THEN
					RAISE E'Object in array element % of ip_addresses in ip_address_hash in netblock_manip.set_interface_addresses does not contain ip_address key:\n%',
						i, jsonb_pretty(addrs_ary->i);
				END IF;
				ipaddr := addrs_ary->i->>'ip_address';

				IF addrs_ary->i ? 'ip_universe_id' THEN
					universe := addrs_ary->i->'ip_universe_id';
				ELSE
					universe := netblock_utils.find_best_ip_universe(ipaddr);
				END IF;

				IF addrs_ary->i ? 'netblock_type' THEN
					nb_type := addrs_ary->i->>'netblock_type';
				ELSE
					nb_type := 'default';
				END IF;
			ELSE
				RAISE 'Invalid type in array element % of ip_addresses in ip_address_hash in netblock_manip.set_interface_addresses (%)',
					i, jsonb_typeof(addrs_ary->i);
			END IF;
			--
			-- We're done with the array, so increment the counter so
			-- we don't have to deal with it later
			--
			i := i + 1;

			RAISE DEBUG 'Address is %, universe is %, nb type is %',
				ipaddr, universe, nb_type;

			--
			-- This is a hack, because Juniper is really annoying about this.
			-- If masklen < 8, then ignore this netblock (we specifically
			-- want /8, because of 127/8 and 10/8, which someone could
			-- maybe want to not subnet.
			--
			-- This should probably be a configuration parameter, but it's not.
			--
			CONTINUE WHEN masklen(ipaddr) < 8;

			--
			-- Check to see if this is a netblock that we have been
			-- told to explicitly ignore
			--
			PERFORM
				ip_address
			FROM
				netblock n JOIN
				netblock_collection_netblock ncn USING (netblock_id) JOIN
				v_netblock_collection_expanded nce USING (netblock_collection_id)
					JOIN
				property p ON (
					property_name = 'IgnoreProbedNetblocks' AND
					property_type = 'DeviceInventory' AND
					property_value_netblock_collection_id =
						nce.root_netblock_collection_id
				)
			WHERE
				ipaddr <<= n.ip_address AND
				n.ip_universe_id = universe
			;

			--
			-- If we found this netblock in the ignore list, then just
			-- skip it
			--
			IF FOUND THEN
				RAISE DEBUG 'Skipping ignored address %', ipaddr;
				CONTINUE;
			END IF;

			--
			-- Look for an is_single_address=true, can_subnet=false netblock
			-- with the given ip_address
			--
			SELECT
				* INTO nb_rec
			FROM
				netblock n
			WHERE
				is_single_address = true AND
				can_subnet = false AND
				netblock_type = nb_type AND
				ip_universe_id = universe AND
				host(ip_address) = host(ipaddr);

			IF FOUND THEN
				RAISE DEBUG E'Located netblock:\n%',
					jsonb_pretty(to_jsonb(nb_rec));

				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);

				--
				-- Look to see if there's a layer3_network for the
				-- parent netblock
				--
				SELECT
					n.netblock_id,
					n.ip_address,
					layer3_network_id,
					default_gateway_netblock_id
				INTO layer3_rec
				FROM
					netblock n LEFT JOIN
					layer3_network l3 USING (netblock_id)
				WHERE
					n.netblock_id = nb_rec.parent_netblock_id;

				IF FOUND THEN
					RAISE DEBUG E'Located layer3_network:\n%',
						jsonb_pretty(to_jsonb(layer3_rec));
				ELSE
					--
					-- If we're told to create the layer3_network,
					-- then do that, otherwise go to the next address
					--
					CONTINUE WHEN NOT create_layer3_networks;
					INSERT INTO layer3_network(
						netblock_id
					) VALUES (
						layer3_rec.netblock_id
					) RETURNING layer3_network_id INTO
						layer3_rec.layer3_network_id;
				END IF;
			ELSE
				--
				-- If the parent netblock does not exist, then create it
				-- if we were passed the option to
				--
				SELECT
					n.netblock_id,
					n.ip_address,
					layer3_network_id,
					default_gateway_netblock_id
				INTO layer3_rec
				FROM
					netblock n LEFT JOIN
					layer3_network l3 USING (netblock_id)
				WHERE
					n.ip_universe_id = universe AND
					n.netblock_type = nb_type AND
					is_single_address = false AND
					can_subnet = false AND
					n.ip_address >>= ipaddr;

				IF NOT FOUND THEN
					RAISE DEBUG 'Parent netblock with ip_address %, netblock_type %, ip_universe_id % not found',
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					--
					-- Check to see if the netblock exists, but is
					-- marked can_subnet=true.  If so, fix it
					--
					SELECT
						* INTO pnb_rec
					FROM
						netblock n
					WHERE
						n.ip_universe_id = universe AND
						n.netblock_type = nb_type AND
						n.is_single_address = false AND
						n.can_subnet = true AND
						n.ip_address = network(ipaddr);

					IF FOUND THEN
						UPDATE netblock n SET
							can_subnet = false
						WHERE
							n.netblock_id = pnb_rec.netblock_id;
						pnb_rec.can_subnet = false;
					ELSE
						INSERT INTO netblock (
							ip_address,
							netblock_type,
							is_single_address,
							can_subnet,
							ip_universe_id,
							netblock_status
						) VALUES (
							network(ipaddr),
							nb_type,
							false,
							false,
							universe,
							'Allocated'
						) RETURNING * INTO pnb_rec;
					END IF;

					WITH l3_ins AS (
						INSERT INTO layer3_network(
							netblock_id
						) VALUES (
							pnb_rec.netblock_id
						) RETURNING *
					)
					SELECT
						pnb_rec.netblock_id,
						pnb_rec.ip_address,
						l3_ins.layer3_network_id,
						NULL::inet
					INTO layer3_rec
					FROM
						l3_ins;
				ELSIF layer3_rec.layer3_network_id IS NULL THEN
					--
					-- If we're told to create the layer3_network,
					-- then do that, otherwise go to the next address
					--

					RAISE DEBUG 'layer3_network for parent netblock % not found (ip_address %, netblock_type %, ip_universe_id %)',
						layer3_rec.netblock_id,
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					INSERT INTO layer3_network(
						netblock_id
					) VALUES (
						layer3_rec.netblock_id
					) RETURNING layer3_network_id INTO
						layer3_rec.layer3_network_id;
				END IF;
				RAISE DEBUG E'Located layer3_network:\n%',
					jsonb_pretty(to_jsonb(layer3_rec));
				--
				-- Parents should be all set up now.  Insert the netblock
				--
				INSERT INTO netblock (
					ip_address,
					netblock_type,
					ip_universe_id,
					is_single_address,
					can_subnet,
					netblock_status
				) VALUES (
					ipaddr,
					nb_type,
					universe,
					true,
					false,
					'Allocated'
				) RETURNING * INTO nb_rec;
				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);
			END IF;
			--
			-- Now that we have the netblock and everything, check to see
			-- if this netblock is already assigned to this layer3_interface
			--
			PERFORM * FROM
				layer3_interface_netblock l3in
			WHERE
				l3in.netblock_id = nb_rec.netblock_id AND
				l3in.layer3_interface_id = l3i_id;

			IF FOUND THEN
				RAISE DEBUG 'Netblock % already found on layer3_interface',
					nb_rec.netblock_id;
				CONTINUE;
			END IF;

			--
			-- See if this netblock is on something else, and delete it
			-- if move_addresses is set, otherwise skip it
			--
			SELECT 
				l3i.layer3_interface_id,
				l3i.layer3_interface_name,
				l3in.netblock_id,
				d.device_id,
				COALESCE(d.device_name, d.physical_label) AS device_name
			INTO l3in_rec
			FROM
				layer3_interface_netblock l3in JOIN
				layer3_interface l3i USING (layer3_interface_id) JOIN
				device d ON (l3in.device_id = d.device_id)
			WHERE
				l3in.netblock_id = nb_rec.netblock_id AND
				l3in.layer3_interface_id != l3i_id;

			IF FOUND THEN
				IF move_addresses = 'always' OR (
					move_addresses = 'if_same_device' AND
					l3in_rec.device_id = l3i_rec.device_id
				)
				THEN
					DELETE FROM
						layer3_interface_netblock
					WHERE
						netblock_id = nb_rec.netblock_id;
				ELSE
					IF address_errors = 'ignore' THEN
						RAISE DEBUG 'Netblock % is assigned to layer3_interface %',
							nb_rec.netblock_id, l3in_rec.layer3_interface_id;

						CONTINUE;
					ELSIF address_errors = 'warn' THEN
						RAISE NOTICE 'Netblock % (%) is assigned to layer3_interface % (%) on device % (%)',
							nb_rec.netblock_id,
							nb_rec.ip_address,
							l3in_rec.layer3_interface_id,
							l3in_rec.layer3_interface_name,
							l3in_rec.device_id,
							l3in_rec.device_name;

						CONTINUE;
					ELSE
						RAISE 'Netblock % (%) is assigned to layer3_interface %(%) on device % (%)',
							nb_rec.netblock_id,
							nb_rec.ip_address,
							l3in_rec.layer3_interface_id,
							l3in_rec.layer3_interface_name,
							l3in_rec.device_id,
							l3in_rec.device_name;
					END IF;
				END IF;
			END IF;

			--
			-- See if this netblock is on a shared_address somewhere, and
			-- move it only if move_addresses is 'always'
			--
			SELECT * FROM
				shared_netblock sn
			INTO sn_rec
			WHERE
				sn.netblock_id = nb_rec.netblock_id;

			IF FOUND THEN
				IF move_addresses IS NULL OR move_addresses != 'always' THEN
					IF address_errors = 'ignore' THEN
						RAISE DEBUG 'Netblock % is assigned to a shared_network %, but not forcing, so skipping',
							nb_rec.netblock_id, sn.shared_netblock_id;
						CONTINUE;
					ELSIF address_errors = 'warn' THEN
						RAISE NOTICE 'Netblock % (%) is assigned to a shared_network %, but not forcing, so skipping',
							nb_rec.netblock_id, nb_rec.ip_address,
							sn.shared_netblock_id;
						CONTINUE;
					ELSE
						RAISE 'Netblock % (%) is assigned to a shared_network %, but not forcing, so skipping',
							nb_rec.netblock_id, nb_rec.ip_address,
							sn.shared_netblock_id;
						CONTINUE;
					END IF;
				END IF;

				DELETE FROM
					shared_netblock_layer3_interface snl3i
				WHERE
					snl3i.shared_netblock_id = sn_rec.shared_netblock_id;

				DELETE FROM
					shared_network sn
				WHERE
					sn.netblock_id = sn_rec.shared_netblock_id;
			END IF;

			--
			-- Insert the netblock onto the interface using the next
			-- rank
			--
			INSERT INTO layer3_interface_netblock (
				layer3_interface_id,
				netblock_id,
				layer3_interface_rank
			) SELECT
				l3i_id,
				nb_rec.netblock_id,
				COALESCE(MAX(layer3_interface_rank) + 1, 0)
			FROM
				layer3_interface_netblock l3in
			WHERE
				l3in.layer3_interface_id = l3i_id
			RETURNING * INTO l3in_rec;

			RAISE DEBUG E'Inserted into:\n%',
				jsonb_pretty(to_jsonb(l3in_rec));
		END LOOP;
		--
		-- Remove any netblocks that are on the interface that are not
		-- supposed to be (and that aren't ignored).
		--

		FOR l3in_rec IN
			DELETE FROM
				layer3_interface_netblock l3in
			WHERE
				(l3in.layer3_interface_id, l3in.netblock_id) IN (
				SELECT
					l3in2.layer3_interface_id,
					l3in2.netblock_id
				FROM
					layer3_interface_netblock l3in2 JOIN
					netblock n USING (netblock_id)
				WHERE
					l3in2.layer3_interface_id = l3i_id AND NOT (
						l3in.netblock_id = ANY(nb_id_ary) OR
						n.ip_address <<= ANY ( ARRAY (
							SELECT
								n2.ip_address
							FROM
								netblock n2 JOIN
								netblock_collection_netblock ncn USING
									(netblock_id) JOIN
								v_netblock_collection_expanded nce USING
									(netblock_collection_id) JOIN
								property p ON (
									property_name = 'IgnoreProbedNetblocks' AND
									property_type = 'DeviceInventory' AND
									property_value_netblock_collection_id =
										nce.root_netblock_collection_id
								)
						))
					)
			)
			RETURNING *
		LOOP
			RAISE DEBUG 'Removed netblock % from layer3_interface %',
				l3in_rec.netblock_id,
				l3in_rec.layer3_interface_id;
			--
			-- Remove any DNS records and/or netblocks that aren't used
			--
			BEGIN
				DELETE FROM dns_record WHERE netblock_id = l3in_rec.netblock_id;
				DELETE FROM netblock_collection_netblock WHERE
					netblock_id = l3in_rec.netblock_id;
				DELETE FROM netblock WHERE netblock_id =
					l3in_rec.netblock_id;
			EXCEPTION
				WHEN foreign_key_violation THEN NULL;
			END;
		END LOOP;
	END IF;

	--
	-- Loop through shared_ip_addresses passed and process those
	--

	IF ip_address_hash ? 'shared_ip_addresses' AND
		jsonb_typeof(ip_address_hash->'shared_ip_addresses') = 'array'
	THEN
		RAISE DEBUG 'Processing shared_ip_addresses...';
		--
		-- Loop through each member of the shared_ip_addresses array
		-- and process each address
		--
		addrs_ary := ip_address_hash->'shared_ip_addresses';
		c := jsonb_array_length(addrs_ary);
		i := 0;
		nb_id_ary := NULL;
		WHILE (i < c) LOOP
			IF jsonb_typeof(addrs_ary->i) = 'string' THEN
				--
				-- If this is a string, use it as an inet with default
				-- universe and netblock_type
				--
				ipaddr := addrs_ary->>i;
				universe := netblock_utils.find_best_ip_universe(ipaddr);
				nb_type := 'default';
				protocol := 'VRRP';
			ELSIF jsonb_typeof(addrs_ary->i) = 'object' THEN
				--
				-- If this is an object, require 'ip_address' key
				-- optionally use 'ip_universe_id' and 'netblock_type' keys
				-- to override the defaults
				--
				IF NOT addrs_ary->i ? 'ip_address' THEN
					RAISE E'Object in array element % of shared_ip_addresses in ip_address_hash in netblock_manip.set_interface_addresses does not contain ip_address key:\n%',
						i, jsonb_pretty(addrs_ary->i);
				END IF;
				ipaddr := addrs_ary->i->>'ip_address';

				IF addrs_ary->i ? 'ip_universe_id' THEN
					universe := addrs_ary->i->'ip_universe_id';
				ELSE
					universe := netblock_utils.find_best_ip_universe(ipaddr);
				END IF;

				IF addrs_ary->i ? 'netblock_type' THEN
					nb_type := addrs_ary->i->>'netblock_type';
				ELSE
					nb_type := 'default';
				END IF;

				IF addrs_ary->i ? 'shared_netblock_protocol' THEN
					protocol := addrs_ary->i->>'shared_netblock_protocol';
				ELSIF addrs_ary->i ? 'protocol' THEN
					protocol := addrs_ary->i->>'protocol';
				ELSE
					protocol := 'VRRP';
				END IF;
			ELSE
				RAISE 'Invalid type in array element % of shared_ip_addresses in ip_address_hash in netblock_manip.set_interface_addresses (%)',
					i, jsonb_typeof(addrs_ary->i);
			END IF;
			--
			-- We're done with the array, so increment the counter so
			-- we don't have to deal with it later
			--
			i := i + 1;

			RAISE DEBUG 'Address is %, universe is %, nb type is %',
				ipaddr, universe, nb_type;

			--
			-- Check to see if this is a netblock that we have been
			-- told to explicitly ignore
			--
			PERFORM
				ip_address
			FROM
				netblock n JOIN
				netblock_collection_netblock ncn USING (netblock_id) JOIN
				v_netblock_collection_expanded nce USING (netblock_collection_id)
					JOIN
				property p ON (
					property_name = 'IgnoreProbedNetblocks' AND
					property_type = 'DeviceInventory' AND
					property_value_netblock_collection_id =
						nce.root_netblock_collection_id
				)
			WHERE
				ipaddr <<= n.ip_address AND
				n.ip_universe_id = universe AND
				n.netblock_type = nb_type;

			--
			-- If we found this netblock in the ignore list, then just
			-- skip it
			--
			IF FOUND THEN
				RAISE DEBUG 'Skipping ignored address %', ipaddr;
				CONTINUE;
			END IF;

			--
			-- Look for an is_single_address=true, can_subnet=false netblock
			-- with the given ip_address
			--
			SELECT
				* INTO nb_rec
			FROM
				netblock n
			WHERE
				is_single_address = true AND
				can_subnet = false AND
				netblock_type = nb_type AND
				ip_universe_id = universe AND
				host(ip_address) = host(ipaddr);

			IF FOUND THEN
				RAISE DEBUG E'Located netblock:\n%',
					jsonb_pretty(to_jsonb(nb_rec));

				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);

				--
				-- Look to see if there's a layer3_network for the
				-- parent netblock
				--
				SELECT
					n.netblock_id,
					n.ip_address,
					layer3_network_id,
					default_gateway_netblock_id
				INTO layer3_rec
				FROM
					netblock n LEFT JOIN
					layer3_network l3 USING (netblock_id)
				WHERE
					n.netblock_id = nb_rec.parent_netblock_id;

				IF FOUND THEN
					RAISE DEBUG E'Located layer3_network:\n%',
						jsonb_pretty(to_jsonb(layer3_rec));
				ELSE
					--
					-- If we're told to create the layer3_network,
					-- then do that, otherwise go to the next address
					--
					CONTINUE WHEN NOT create_layer3_networks;
					INSERT INTO layer3_network(
						netblock_id
					) VALUES (
						layer3_rec.netblock_id
					) RETURNING layer3_network_id INTO
						layer3_rec.layer3_network_id;
				END IF;
			ELSE
				--
				-- If the parent netblock does not exist, then create it
				-- if we were passed the option to
				--
				SELECT
					n.netblock_id,
					n.ip_address,
					layer3_network_id,
					default_gateway_netblock_id
				INTO layer3_rec
				FROM
					netblock n LEFT JOIN
					layer3_network l3 USING (netblock_id)
				WHERE
					n.ip_universe_id = universe AND
					n.netblock_type = nb_type AND
					is_single_address = false AND
					can_subnet = false AND
					n.ip_address >>= ipaddr;

				IF NOT FOUND THEN
					RAISE DEBUG 'Parent netblock with ip_address %, netblock_type %, ip_universe_id % not found',
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					WITH nb_ins AS (
						INSERT INTO netblock (
							ip_address,
							netblock_type,
							is_single_address,
							can_subnet,
							ip_universe_id,
							netblock_status
						) VALUES (
							network(ipaddr),
							nb_type,
							false,
							false,
							universe,
							'Allocated'
						) RETURNING *
					), l3_ins AS (
						INSERT INTO layer3_network(
							netblock_id
						)
						SELECT
							netblock_id
						FROM
							nb_ins
						RETURNING *
					)
					SELECT
						nb_ins.netblock_id,
						nb_ins.ip_address,
						l3_ins.layer3_network_id,
						NULL
					INTO layer3_rec
					FROM
						nb_ins,
						l3_ins;
				ELSIF layer3_rec.layer3_network_id IS NULL THEN
					--
					-- If we're told to create the layer3_network,
					-- then do that, otherwise go to the next address
					--

					RAISE DEBUG 'layer3_network for parent netblock % not found (ip_address %, netblock_type %, ip_universe_id %)',
						layer3_rec.netblock_id,
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					INSERT INTO layer3_network(
						netblock_id
					) VALUES (
						layer3_rec.netblock_id
					) RETURNING layer3_network_id INTO
						layer3_rec.layer3_network_id;
				END IF;
				RAISE DEBUG E'Located layer3_network:\n%',
					jsonb_pretty(to_jsonb(layer3_rec));
				--
				-- Parents should be all set up now.  Insert the netblock
				--
				INSERT INTO netblock (
					ip_address,
					netblock_type,
					ip_universe_id,
					is_single_address,
					can_subnet,
					netblock_status
				) VALUES (
					ipaddr,
					nb_type,
					universe,
					true,
					false,
					'Allocated'
				) RETURNING * INTO nb_rec;
				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);
			END IF;

			--
			-- See if this netblock is directly on any layer3_interface, and
			-- delete it if force is set, otherwise skip it
			--
			l3i_id_ary := ARRAY[]::integer[];

			SELECT
				l3in.netblock_id,
				l3i.device_id
			INTO l3in_rec
			FROM
				layer3_interface_netblock l3in JOIN
				layer3_interface l3i USING (layer3_interface_id)
			WHERE
				l3in.netblock_id = nb_rec.netblock_id AND
				l3in.layer3_interface_id != l3i_id;

			IF FOUND THEN
				IF move_addresses = 'always' OR (
					move_addresses = 'if_same_device' AND
					l3in_rec.device_id = l3i_rec.device_id
				)
				THEN
					--
					-- Remove the netblocks from the layer3_interfaces,
					-- but save them for later so that we can migrate them
					-- after we make sure the shared_netblock exists.
					--
					-- Also, append the network_inteface_id that we
					-- specifically care about, and we'll add them all
					-- below
					--
					WITH z AS (
						DELETE FROM
							layer3_interface_netblock
						WHERE
							netblock_id = nb_rec.netblock_id
						RETURNING layer3_interface_id
					)
					SELECT array_agg(layer3_interface_id) FROM
						(SELECT layer3_interface_id FROM z) v
					INTO l3i_id_ary;
				ELSE
					IF address_errors = 'ignore' THEN
						RAISE DEBUG 'Netblock % is assigned to layer3_interface %',
							nb_rec.netblock_id, l3in_rec.layer3_interface_id;

						CONTINUE;
					ELSIF address_errors = 'warn' THEN
						RAISE NOTICE 'Netblock % is assigned to layer3_interface %',
							nb_rec.netblock_id, l3in_rec.layer3_interface_id;

						CONTINUE;
					ELSE
						RAISE 'Netblock % is assigned to layer3_interface %',
							nb_rec.netblock_id, l3in_rec.layer3_interface_id;
					END IF;
				END IF;

			END IF;

			IF NOT(l3i_id = ANY(l3i_id_ary)) THEN
				l3i_id_ary := array_append(l3i_id_ary, l3i_id);
			END IF;

			--
			-- See if this netblock already belongs to a shared_network
			--
			SELECT * FROM
				shared_netblock sn
			INTO sn_rec
			WHERE
				sn.netblock_id = nb_rec.netblock_id;

			IF FOUND THEN
				IF sn_rec.shared_netblock_protocol != protocol THEN
					RAISE 'Netblock % (%) is assigned to shared_network %, but the shared_network_protocol does not match (% vs. %)',
						nb_rec.netblock_id,
						nb_rec.ip_address,
						sn_rec.shared_netblock_id,
						sn_rec.shared_netblock_protocol,
						protocol;
				END IF;
			ELSE
				INSERT INTO shared_netblock (
					shared_netblock_protocol,
					netblock_id
				) VALUES (
					protocol,
					nb_rec.netblock_id
				) RETURNING * INTO sn_rec;
			END IF;

			--
			-- Add this to any interfaces that we found above that
			-- need this
			--

			INSERT INTO shared_netblock_layer3_interface (
				shared_netblock_id,
				layer3_interface_id,
				priority
			) SELECT
				sn_rec.shared_netblock_id,
				x.layer3_interface_id,
				0
			FROM
				unnest(l3i_id_ary) x(layer3_interface_id)
			ON CONFLICT ON CONSTRAINT pk_ip_group_network_interface DO NOTHING;

			RAISE DEBUG E'Inserted shared_netblock % onto interfaces:\n%',
				sn_rec.shared_netblock_id, jsonb_pretty(to_jsonb(l3i_id_ary));
		END LOOP;
		--
		-- Remove any shared_netblocks that are on the interface that are not
		-- supposed to be (and that aren't ignored).
		--

		FOR l3in_rec IN
			DELETE FROM
				shared_netblock_layer3_interface snl3i
			WHERE
				(snl3i.layer3_interface_id, snl3i.shared_netblock_id) IN (
				SELECT
					snl3i2.layer3_interface_id,
					snl3i2.shared_netblock_id
				FROM
					shared_netblock_layer3_interface snl3i2 JOIN
					shared_netblock sn USING (shared_netblock_id) JOIN
					netblock n USING (netblock_id)
				WHERE
					snl3i2.layer3_interface_id = l3i_id AND NOT (
						sn.netblock_id = ANY(nb_id_ary) OR
						n.ip_address <<= ANY ( ARRAY (
							SELECT
								n2.ip_address
							FROM
								netblock n2 JOIN
								netblock_collection_netblock ncn USING
									(netblock_id) JOIN
								v_netblock_collection_expanded nce USING
									(netblock_collection_id) JOIN
								property p ON (
									property_name = 'IgnoreProbedNetblocks' AND
									property_type = 'DeviceInventory' AND
									property_value_netblock_collection_id =
										nce.root_netblock_collection_id
								)
						))
					)
			)
			RETURNING *
		LOOP
			RAISE DEBUG 'Removed shared_netblock % from layer3_interface %',
				l3in_rec.shared_netblock_id,
				l3in_rec.layer3_interface_id;

			--
			-- Remove any DNS records, netblocks and shared_netblocks
			-- that aren't used
			--
			SELECT netblock_id INTO nb_id FROM shared_netblock sn WHERE
				sn.shared_netblock_id = l3in_rec.shared_netblock_id;
			BEGIN
				DELETE FROM dns_record WHERE netblock_id = nb_id;
				DELETE FROM netblock_collection_netblock ncn WHERE
					ncn.netblock_id = nb_id;
				DELETE FROM shared_netblock WHERE netblock_id = nb_id;
				DELETE FROM netblock WHERE netblock_id = nb_id;
			EXCEPTION
				WHEN foreign_key_violation THEN NULL;
			END;
		END LOOP;
	END IF;
	RETURN true;
END;
$function$
;

--
-- Process middle (non-trigger) schema physical_address_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_physical_address_utils']);
--
-- Process middle (non-trigger) schema component_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_utils']);
--
-- Process middle (non-trigger) schema snapshot_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_snapshot_manip']);
--
-- Process middle (non-trigger) schema lv_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_lv_manip']);
--
-- Process middle (non-trigger) schema approval_utils
--
SELECT schema_support.save_dependent_objects_for_replay(schema := 'approval_utils'::text, object := 'approve ( integer,boolean,integer,text )'::text, tags := ARRAY['process_all_procs_in_schema_approval_utils'::text]);
DROP FUNCTION IF EXISTS approval_utils.approve ( integer,boolean,integer,text );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'approval_utils'::text, object := 'approve ( integer,text,integer,text )'::text, tags := ARRAY['process_all_procs_in_schema_approval_utils'::text]);
DROP FUNCTION IF EXISTS approval_utils.approve ( integer,text,integer,text );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'approval_utils'::text, object := 'message_replace ( text,timestamp without time zone,timestamp without time zone )'::text, tags := ARRAY['process_all_procs_in_schema_approval_utils'::text]);
DROP FUNCTION IF EXISTS approval_utils.message_replace ( text,timestamp without time zone,timestamp without time zone );
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('approval_utils', 'refresh_approval_instance_item');
SELECT schema_support.save_grants_for_replay('approval_utils', 'refresh_approval_instance_item');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS approval_utils.refresh_approval_instance_item ( integer );
CREATE OR REPLACE FUNCTION approval_utils.refresh_approval_instance_item(approval_instance_item_id integer)
 RETURNS approval_utils.v_account_collection_approval_process
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'approval_utils', 'jazzhands'
AS $function$
DECLARE
	_i	approval_instance_item.approval_instance_item_id%TYPE;
	_r	approval_utils.v_account_collection_approval_process%ROWTYPE;
	enabled	BOOLEAN;
BEGIN
	--
	-- XXX p comes out of one of the three clauses in
	-- v_account_collection_approval_process .  It is likely that that view
	-- needs to be broken into 2 or 3 views joined together so there is no
	-- code redundancy.  This is almost certainly true because it is a pain
	-- to keep column lists in syn everywhere
	EXECUTE '
		WITH p AS (
		SELECT  login,
			account_id,
			person_id,
			mm.company_id,
			manager_account_id,
			manager_login,
			''person_company''::text as audit_table,
			audit_seq_id,
			approval_process_id,
			approval_process_chain_id,
			approving_entity,
				approval_process_description,
				approval_chain_description,
				approval_response_period,
				approval_expiration_action,
				attestation_frequency,
				current_attestation_name,
				current_attestation_begins,
				attestation_offset,
				approval_process_chain_name,
				property_val_rhs AS approval_category,
				CASE
					WHEN property_val_rhs = ''position_title''
						THEN ''Verify Position Title''
					END as approval_label,
			human_readable AS approval_lhs,
			CASE
			    WHEN property_val_rhs = ''position_title'' THEN pcm.position_title
			END as approval_rhs
		FROM    v_account_manager_map mm
			INNER JOIN v_person_company_audit_map pcm
			    USING (person_id, company_id)
			INNER JOIN v_approval_matrix am
			    ON property_val_lhs = ''person_company''
			    AND property_val_rhs = ''position_title''
		), x AS ( select i.approval_instance_item_id, p.*
		from	approval_instance_item i
			inner join approval_instance_step s
				using (approval_instance_step_id)
			inner join approval_instance_link l
				using (approval_instance_link_id)
			inner join audit.account_collection_account res
				on res."aud#seq" = l.acct_collection_acct_seq_id
			 inner join v_account_collection_approval_process p
				on i.approved_label = p.approval_label
				and res.account_id = p.account_id
		UNION
		select i.approval_instance_item_id, p.*
		from	approval_instance_item i
			inner join approval_instance_step s
				using (approval_instance_step_id)
			inner join approval_instance_link l
				using (approval_instance_link_id)
			inner join audit.person_company res
				on res."aud#seq" = l.person_company_seq_id
			 inner join p
				on i.approved_label = p.approval_label
				and res.person_id = p.person_id
		) SELECT
			login,
			account_id,
			person_id,
					company_id,
					manager_account_id,
					manager_login,
					audit_table,
					audit_seq_id,
					approval_process_id,
					approval_process_chain_id,
					approving_entity,
					approval_process_description,
					approval_chain_description,
					approval_response_period,
					approval_expiration_action,
					attestation_frequency,
					current_attestation_name,
					current_attestation_begins,
					attestation_offset,
					approval_process_chain_name,
					approval_category,
					approval_label,
					approval_lhs,
					approval_rhs
				FROM x where	approval_instance_item_id = $1
			' INTO _r USING approval_instance_item_id;

	IF _r IS NULL THEN
		--
		-- This may be because the person referred to has been terminated,
		-- in which case, raise an exception up to cause the path to just
		-- terminate, since this does not handle ex-employees at this time.
		--
		-- XXX - it is possible for terminated people who still have an
		-- active account in a different accout realm to trigger a false
		-- positive on this, which is sad, but all this needs to be rewritten
		-- anyway.
		--
		SELECT	is_enabled
		INTO	enabled
		FROM (
			SELECT is_enabled, approval_instance_item_id
			FROM	account a
					JOIN jazzhands_audit.account_collection_account aca USING (account_id)
					JOIN approval_instance_link al ON aca."aud#seq" = al.acct_collection_acct_seq_id
			WHERE	account_role = 'primary'
			UNION
			SELECT is_enabled, approval_instance_item_id
			FROM	account a
					JOIN jazzhands_audit.person_company pc USING (company_id,person_id)
					JOIN approval_instance_link al ON pc."aud#seq" = al.person_company_seq_id
			WHERE	account_role = 'primary'
		) i WHERE i.approval_instance_item_id = refresh_approval_instance_item.approval_instance_item_id
		LIMIT 1;

		IF enabled IS NOT NULL AND enabled = false THEN
			RAISE EXCEPTION 'Account is no longer active'
				USING ERRCODE = 'invalid_name';
		END IF;
	END IF;
	RETURN _r;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'approval_utils' AND type = 'function' AND object IN ('refresh_approval_instance_item');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc refresh_approval_instance_item failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_approval_utils']);
-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('approval_utils', 'approve');
DROP FUNCTION IF EXISTS approval_utils.approve ( integer,boolean,integer,text,boolean );
CREATE OR REPLACE FUNCTION approval_utils.approve(approval_instance_item_id integer, approved boolean, approving_account_id integer, new_value text DEFAULT NULL::text, terminate_chain boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'approval_utils', 'jazzhands'
AS $function$
DECLARE
	_r		RECORD;
	_aii	approval_instance_item%ROWTYPE;
	_new	approval_instance_item.approval_instance_item_id%TYPE;
	_chid	approval_process_chain.approval_process_chain_id%TYPE;
	_tally	INTEGER;
	_mid	account.account_id%TYPE;
	_d		RECORD;
BEGIN
	EXECUTE '
		SELECT 	aii.approval_instance_item_id,
			ais.approval_instance_step_id,
			ais.approval_instance_id,
			ais.approver_account_id,
			ais.approval_type,
			aii.is_approved,
			ais.is_completed,
			apc.accept_approval_process_chain_id,
			apc.reject_approval_process_chain_id,
			apc.permit_immediate_resolution
   	     FROM    approval_instance ai
   		     INNER JOIN approval_instance_step ais
   			 USING (approval_instance_id)
   		     INNER JOIN approval_instance_item aii
   			 USING (approval_instance_step_id)
   		     INNER JOIN approval_instance_link ail
   			 USING (approval_instance_link_id)
			INNER JOIN approval_process_chain apc
				USING (approval_process_chain_id)
		WHERE approval_instance_item_id = $1
	' USING approval_instance_item_id INTO 	_r;

	--
	-- Ensure that only the person or their management chain can approve
	-- others (or their alternates.
	--
	-- or god mode.
	IF (_r.approval_type = 'account' AND _r.approver_account_id != approving_account_id ) THEN
		BEGIN
			EXECUTE '
				SELECT manager_account_id
				FROM	v_account_manager_hier
				WHERE account_id = $1
				AND manager_account_id = $2
			' INTO _tally USING _r.approver_account_id, approving_account_id;

			--
			-- management chain approval
			--
			IF _tally > 0 THEN
				RAISE EXCEPTION 'permitted by management' USING ERRCODE = 'JH000';
			END IF;
			--------------

			EXECUTE '
				SELECT	count(*)
				FROM	property
						INNER JOIN v_account_collection_account_expanded e
						USING (account_collection_id)
				WHERE	property_type = ''Defaults''
				AND		property_name = ''_can_approve_all''
				AND		e.account_id = $1
			' INTO _tally USING approving_account_id;

			--
			-- god mode approval
			--
			IF _tally > 0 THEN
				RAISE EXCEPTION 'permitted by hierrchy' USING ERRCODE = 'JH000';
			END IF;
			--------------

			--
			-- alternate approval, lhs is people who are permitted to approve
			-- rhs is (all) their alternates.
			--
			EXECUTE '
				SELECT	count(*)
				FROM	property
						INNER JOIN (
							SELECT DISTINCT account_collection_id, unnest(ARRAY[h.account_id, h.manager_account_id]) AS account_Id
							FROM v_account_manager_hier h
								INNER JOIN v_account_collection_account_expanded e
									ON h.manager_account_id = e.account_id
						) lhse USING (account_collection_id)
						INNER JOIN (
							SELECT account_collection_id AS property_value_account_collection_id, account_id
							FROM v_account_collection_account_expanded
						) rhse
							USING (property_value_account_collection_id)
				WHERE	property_type = ''attestation''
				AND		property_name IN ( ''AlternateApprovers'', ''Delegate'')
				AND		lhse.account_id = $1
				AND		rhse.account_id = $2
			' INTO _tally USING _r.approver_account_id, approving_account_id;

			IF _tally > 0 THEN
				RAISE EXCEPTION 'permitted by alternate' USING ERRCODE = 'JH000';
			END IF;

			RAISE EXCEPTION 'Only a person and their management chain may approve others' USING ERRCODE = 'error_in_assignment';
		EXCEPTION WHEN SQLSTATE 'JH000' THEN
			-- inner exceptions are just passed through.
			NULL;
		END;

	END IF;

	IF _r.approval_instance_item_id IS NULL THEN
		RAISE EXCEPTION 'Unknown approval_instance_item_id %',
			approval_instance_item_id;
	END IF;

	IF _r.is_approved IS NOT NULL THEN
		RAISE EXCEPTION 'Approval is already completed.';
	END IF;

	IF approved = false THEN
		IF _r.reject_approval_process_chain_id IS NOT NULL THEN
			_chid := _r.reject_approval_process_chain_id;
		END IF;
	ELSIF approved = true THEN
		IF _r.accept_approval_process_chain_id IS NOT NULL THEN
			_chid := _r.accept_approval_process_chain_id;
		END IF;
	ELSE
		RAISE EXCEPTION 'Approved must be Y or N';
	END IF;

	--
	-- In some cases, there's no point in going through the approval
	-- process.  If this is permitted, then do it, otherwise raise an
	-- exception if asked.
	--
	IF terminate_chain AND NOT _r.permit_immediate_resolution THEN
		RAISE EXCEPTION 'May not terminate the chain prematurely for this result.'
		USING ERRCODE = 'error_in_assignment';
	ELSE
		BEGIN
			IF _chid IS NOT NULL THEN
				_new := approval_utils.build_next_approval_item(
					approval_instance_item_id, _chid,
					_r.approval_instance_id, approved,
					approving_account_id, new_value);

				EXECUTE '
					UPDATE approval_instance_item
					SET next_approval_instance_item_id = $2
					WHERE approval_instance_item_id = $1
				' USING approval_instance_item_id, _new;
			END IF;
		EXCEPTION WHEN invalid_name THEN
			-- This means the user was terminated, so just terminate the
			-- chain
			NULL;
		END;
	END IF;

	--
	-- This needs to happen after the next steps are created
	-- or the entire process gets marked as done on the second to last
	-- update instead of the last.

	EXECUTE '
		UPDATE approval_instance_item
		SET is_approved = $2,
		approved_account_id = $3
		WHERE approval_instance_item_id = $1
	' USING approval_instance_item_id, approved, approving_account_id;

	RETURN true;
END;
$function$
;

-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('approval_utils', 'approve');
DROP FUNCTION IF EXISTS approval_utils.approve ( integer,text,integer,text,boolean );
CREATE OR REPLACE FUNCTION approval_utils.approve(approval_instance_item_id integer, approved text, approving_account_id integer, new_value text DEFAULT NULL::text, terminate_chain boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'approval_utils', 'jazzhands'
AS $function$
DECLARE
	_tf	BOOLEAN;
BEGIN
	IF approved = 'Y' THEN
		_tf = true;
	ELSIF approved = 'N' THEN
		_tf = false;
	ELSE
		RAISE NOTICE 'approved must by y/n or true/false';
	END IF;
	RETURN approval_utils.approve(
		approval_instance_item_id := approval_instance_item_id,
		approved := _tf,
		approving_account_id := approving_account_id,
		new_value := new_value
	);
END;
$function$
;

-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('approval_utils', 'message_replace');
DROP FUNCTION IF EXISTS approval_utils.message_replace ( text,timestamp without time zone,timestamp without time zone,text,text );
CREATE OR REPLACE FUNCTION approval_utils.message_replace(message text, start_time timestamp without time zone DEFAULT NULL::timestamp without time zone, due_time timestamp without time zone DEFAULT NULL::timestamp without time zone, full_stab_url text DEFAULT NULL::text, stab_root text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'approval_utils', 'jazzhands'
AS $function$
DECLARE
	rv	text;
	stabroot	text;
	faqurl	text;
BEGIN
	IF stab_root IS NULL THEN
		SELECT property_value
		INTO stabroot
		FROM property
		WHERE property_name = '_stab_root'
		AND property_type = 'Defaults'
		ORDER BY property_id
		LIMIT 1;
	ELSE
		stabroot := stab_root;
	END IF;

	SELECT property_value
	INTO faqurl
	FROM property
	WHERE property_name = '_approval_faq_site'
	AND property_type = 'Defaults'
	ORDER BY property_id
	LIMIT 1;

	rv := message;
	IF full_stab_url IS NOT NULL THEN
		rv := regexp_replace(rv, '%\{full_stab_url\}', full_stab_url, 'g');
	END IF;
	-- this is going away.
	rv := regexp_replace(rv, '%\{stab_url\}', stabroot, 'g');
	rv := regexp_replace(rv, '%\{effective_date\}', start_time::date::text, 'g');
	rv := regexp_replace(rv, '%\{due_date\}', due_time::date::text, 'g');
	rv := regexp_replace(rv, '%\{stab_root\}', stabroot, 'g');
	rv := regexp_replace(rv, '%\{faq_url\}', faqurl, 'g');

	-- There is also due_threat, which is processed in approval-email.pl

	return rv;
END;
$function$
;

--
-- Process middle (non-trigger) schema account_collection_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_account_collection_manip']);
--
-- Process middle (non-trigger) schema script_hooks
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_script_hooks']);
--
-- Process middle (non-trigger) schema backend_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_backend_utils']);
--
-- Process middle (non-trigger) schema rack_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_rack_utils']);
--
-- Process middle (non-trigger) schema layerx_network_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_layerx_network_manip']);
--
-- Process middle (non-trigger) schema component_connection_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_connection_utils']);
--
-- Process middle (non-trigger) schema logical_port_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_logical_port_manip']);
--
-- Process middle (non-trigger) schema pgcrypto
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_pgcrypto']);
--
-- Process middle (non-trigger) schema jazzhands_legacy
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy']);
-- Creating new sequences....


-- Processing tables in main schema...
select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- DEALING WITH TABLE logical_port
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'logical_port', 'logical_port');

-- FOREIGN KEYS FROM
ALTER TABLE layer2_connection DROP CONSTRAINT IF EXISTS fk_l2_conn_l1port;
ALTER TABLE layer2_connection DROP CONSTRAINT IF EXISTS fk_l2_conn_l2port;
ALTER TABLE logical_port_slot DROP CONSTRAINT IF EXISTS fk_lgl_port_slot_lgl_port_id;
ALTER TABLE layer3_interface DROP CONSTRAINT IF EXISTS fk_net_int_lgl_port_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.logical_port DROP CONSTRAINT IF EXISTS fk_logcal_port_mlag_peering_id;
ALTER TABLE jazzhands.logical_port DROP CONSTRAINT IF EXISTS fk_logical_port_device_id;
ALTER TABLE jazzhands.logical_port DROP CONSTRAINT IF EXISTS fk_logical_port_lg_port_type;
ALTER TABLE jazzhands.logical_port DROP CONSTRAINT IF EXISTS fk_logical_port_parent_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands', object := 'logical_port', newobject := 'logical_port', newmap := '{"pk_logical_port":{"columns":["logical_port_id"],"def":"PRIMARY KEY (logical_port_id)","deferrable":false,"deferred":false,"name":"pk_logical_port","type":"p"},"uq_device_id_logical_port_id":{"columns":["logical_port_id","device_id"],"def":"UNIQUE (logical_port_id, device_id)","deferrable":false,"deferred":false,"name":"uq_device_id_logical_port_id","type":"u"},"uq_lg_port_name_type_device":{"columns":["logical_port_name","logical_port_type","device_id"],"def":"UNIQUE (logical_port_name, logical_port_type, device_id)","deferrable":false,"deferred":false,"name":"uq_lg_port_name_type_device","type":"u"},"uq_lg_port_name_type_mlag":{"columns":["logical_port_name","logical_port_type","mlag_peering_id"],"def":"UNIQUE (logical_port_name, logical_port_type, mlag_peering_id)","deferrable":false,"deferred":false,"name":"uq_lg_port_name_type_mlag","type":"u"},"uq_lport_mlag_peer_id":{"columns":["mlag_id","mlag_peering_id"],"def":"UNIQUE (mlag_id, mlag_peering_id)","deferrable":false,"deferred":false,"name":"uq_lport_mlag_peer_id","type":"u"}}');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.logical_port DROP CONSTRAINT IF EXISTS pk_logical_port;
ALTER TABLE jazzhands.logical_port DROP CONSTRAINT IF EXISTS uq_device_id_logical_port_id;
ALTER TABLE jazzhands.logical_port DROP CONSTRAINT IF EXISTS uq_lg_port_name_type_device;
ALTER TABLE jazzhands.logical_port DROP CONSTRAINT IF EXISTS uq_lg_port_name_type_mlag;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif3logical_port";
DROP INDEX IF EXISTS "jazzhands"."xif4logical_port";
DROP INDEX IF EXISTS "jazzhands"."xif_logical_port_lg_port_type";
DROP INDEX IF EXISTS "jazzhands"."xif_logical_port_parnet_id";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_logical_port ON jazzhands.logical_port;
DROP TRIGGER IF EXISTS trigger_audit_logical_port ON jazzhands.logical_port;
DROP FUNCTION IF EXISTS perform_audit_logical_port();
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'logical_port', tags := ARRAY['table_logical_port']);
---- BEGIN jazzhands_audit.logical_port TEARDOWN
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'logical_port', tags := ARRAY['table_logical_port']);
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_audit', 'logical_port', 'logical_port');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands_audit',  object := 'logical_port');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands_audit.logical_port DROP CONSTRAINT IF EXISTS logical_port_pkey;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands_audit"."aud_logical_port_pk_logical_port";
DROP INDEX IF EXISTS "jazzhands_audit"."aud_logical_port_uq_device_id_logical_port_id";
DROP INDEX IF EXISTS "jazzhands_audit"."aud_logical_port_uq_lg_port_name_type_device";
DROP INDEX IF EXISTS "jazzhands_audit"."aud_logical_port_uq_lg_port_name_type_mlag";
DROP INDEX IF EXISTS "jazzhands_audit"."logical_port_aud#realtime_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."logical_port_aud#timestamp_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."logical_port_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE jazzhands_audit.logical_port TEARDOWN


ALTER TABLE logical_port RENAME TO logical_port_v90;
ALTER TABLE jazzhands_audit.logical_port RENAME TO logical_port_v90;

CREATE TABLE jazzhands.logical_port
(
	logical_port_id	integer NOT NULL,
	logical_port_name	varchar(50) NOT NULL,
	logical_port_type	varchar(50) NOT NULL,
	device_id	integer  NULL,
	mlag_peering_id	integer  NULL,
	mlag_id	integer  NULL,
	parent_logical_port_id	integer  NULL,
	mac_address	macaddr  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'logical_port', false);
ALTER TABLE logical_port
	ALTER logical_port_id
	SET DEFAULT nextval('jazzhands.logical_port_logical_port_id_seq'::regclass);

INSERT INTO logical_port (
	logical_port_id,
	logical_port_name,
	logical_port_type,
	device_id,
	mlag_peering_id,
	mlag_id,		-- new column (mlag_id)
	parent_logical_port_id,
	mac_address,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	logical_port_id,
	logical_port_name,
	logical_port_type,
	device_id,
	mlag_peering_id,
	NULL,		-- new column (mlag_id)
	parent_logical_port_id,
	mac_address,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM logical_port_v90;


INSERT INTO jazzhands_audit.logical_port (
	logical_port_id,
	logical_port_name,
	logical_port_type,
	device_id,
	mlag_peering_id,
	mlag_id,		-- new column (mlag_id)
	parent_logical_port_id,
	mac_address,
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
	logical_port_id,
	logical_port_name,
	logical_port_type,
	device_id,
	mlag_peering_id,
	NULL,		-- new column (mlag_id)
	parent_logical_port_id,
	mac_address,
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
FROM jazzhands_audit.logical_port_v90;

ALTER TABLE jazzhands.logical_port
	ALTER logical_port_id
	SET DEFAULT nextval('jazzhands.logical_port_logical_port_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.logical_port ADD CONSTRAINT pk_logical_port PRIMARY KEY (logical_port_id);
ALTER TABLE jazzhands.logical_port ADD CONSTRAINT uq_device_id_logical_port_id UNIQUE (logical_port_id, device_id);
ALTER TABLE jazzhands.logical_port ADD CONSTRAINT uq_lg_port_name_type_device UNIQUE (logical_port_name, logical_port_type, device_id);
ALTER TABLE jazzhands.logical_port ADD CONSTRAINT uq_lg_port_name_type_mlag UNIQUE (logical_port_name, logical_port_type, mlag_peering_id);
ALTER TABLE jazzhands.logical_port ADD CONSTRAINT uq_lport_mlag_peer_id UNIQUE (mlag_id, mlag_peering_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif3logical_port ON jazzhands.logical_port USING btree (device_id);
CREATE INDEX xif4logical_port ON jazzhands.logical_port USING btree (mlag_peering_id);
CREATE INDEX xif_logical_port_lg_port_type ON jazzhands.logical_port USING btree (logical_port_type);
CREATE INDEX xif_logical_port_parnet_id ON jazzhands.logical_port USING btree (parent_logical_port_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between logical_port and jazzhands.layer2_connection
ALTER TABLE jazzhands.layer2_connection
	ADD CONSTRAINT fk_l2_conn_l1port
	FOREIGN KEY (logical_port1_id) REFERENCES jazzhands.logical_port(logical_port_id);
-- consider FK between logical_port and jazzhands.layer2_connection
ALTER TABLE jazzhands.layer2_connection
	ADD CONSTRAINT fk_l2_conn_l2port
	FOREIGN KEY (logical_port2_id) REFERENCES jazzhands.logical_port(logical_port_id);
-- consider FK between logical_port and jazzhands.logical_port_slot
ALTER TABLE jazzhands.logical_port_slot
	ADD CONSTRAINT fk_lgl_port_slot_lgl_port_id
	FOREIGN KEY (logical_port_id) REFERENCES jazzhands.logical_port(logical_port_id);
-- consider FK between logical_port and jazzhands.layer3_interface
ALTER TABLE jazzhands.layer3_interface
	ADD CONSTRAINT fk_net_int_lgl_port_id
	FOREIGN KEY (logical_port_id, device_id) REFERENCES jazzhands.logical_port(logical_port_id, device_id);

-- FOREIGN KEYS TO
-- consider FK logical_port and mlag_peering
ALTER TABLE jazzhands.logical_port
	ADD CONSTRAINT fk_logcal_port_mlag_peering_id
	FOREIGN KEY (mlag_peering_id) REFERENCES jazzhands.mlag_peering(mlag_peering_id);
-- consider FK logical_port and device
ALTER TABLE jazzhands.logical_port
	ADD CONSTRAINT fk_logical_port_device_id
	FOREIGN KEY (device_id) REFERENCES jazzhands.device(device_id);
-- consider FK logical_port and val_logical_port_type
ALTER TABLE jazzhands.logical_port
	ADD CONSTRAINT fk_logical_port_lg_port_type
	FOREIGN KEY (logical_port_type) REFERENCES jazzhands.val_logical_port_type(logical_port_type);
-- consider FK logical_port and logical_port
ALTER TABLE jazzhands.logical_port
	ADD CONSTRAINT fk_logical_port_parent_id
	FOREIGN KEY (parent_logical_port_id) REFERENCES jazzhands.logical_port(logical_port_id);

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('logical_port');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for logical_port  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'logical_port');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'logical_port');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'logical_port');
ALTER SEQUENCE jazzhands.logical_port_logical_port_id_seq
	 OWNED BY logical_port.logical_port_id;
DROP TABLE IF EXISTS logical_port_v90;
DROP TABLE IF EXISTS jazzhands_audit.logical_port_v90;
-- DONE DEALING WITH TABLE logical_port (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('logical_port');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old logical_port failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('logical_port');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new logical_port failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- DEALING WITH TABLE v_unix_mclass_settings
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_unix_mclass_settings', 'v_unix_mclass_settings');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_unix_mclass_settings', tags := ARRAY['view_v_unix_mclass_settings']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_device_collection_hier_detail', type := 'view');
DROP VIEW IF EXISTS jazzhands.v_unix_mclass_settings;
CREATE VIEW jazzhands.v_unix_mclass_settings AS
 SELECT property_list.device_collection_id,
    array_agg(property_list.setting ORDER BY property_list.rn) AS mclass_setting
   FROM ( SELECT select_for_ordering.device_collection_id,
            select_for_ordering.setting,
            row_number() OVER () AS rn
           FROM ( SELECT dc.device_collection_id,
                    unnest(ARRAY[dc.property_name, dc.property_value]) AS setting
                   FROM ( SELECT dcd.device_collection_id,
                            p.property_name,
                            COALESCE(p.property_value, p.property_value_password_type,
                                CASE
                                    WHEN p.property_value_boolean = true THEN 'Y'::text
                                    WHEN p.property_value_boolean = false THEN 'N'::text
                                    ELSE NULL::text
                                END::character varying) AS property_value,
                            row_number() OVER (PARTITION BY dcd.device_collection_id, p.property_name ORDER BY dcd.device_collection_level, p.property_id) AS ord
                           FROM jazzhands.v_device_collection_hier_detail dcd
                             JOIN jazzhands.v_property p ON p.device_collection_id = dcd.parent_device_collection_id
                          WHERE p.property_type::text = 'MclassUnixProp'::text AND p.account_collection_id IS NULL) dc
                  WHERE dc.ord = 1) select_for_ordering) property_list
  GROUP BY property_list.device_collection_id;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object IN ('v_unix_mclass_settings','v_unix_mclass_settings');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_unix_mclass_settings failed but that is ok';
	NULL;
END;
$$;

-- just in case
SELECT schema_support.prepare_for_object_replay();

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('v_unix_mclass_settings');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_unix_mclass_settings  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_unix_mclass_settings (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_unix_mclass_settings');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old v_unix_mclass_settings failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_unix_mclass_settings');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new v_unix_mclass_settings failed but that is ok';
	NULL;
END;
$$;

--------------------------------------------------------------------
-- DEALING WITH TABLE v_device_collection_account_property_expanded
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_collection_account_property_expanded', 'v_device_collection_account_property_expanded');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_device_collection_account_property_expanded', tags := ARRAY['view_v_device_collection_account_property_expanded']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_device_collection_hier_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_account_expanded_detail', type := 'view');
DROP VIEW IF EXISTS jazzhands.v_device_collection_account_property_expanded;
CREATE VIEW jazzhands.v_device_collection_account_property_expanded AS
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
    COALESCE(upo.property_value_password_type, upo.property_value,
        CASE
            WHEN upo.property_value_boolean IS NULL THEN NULL::text
            WHEN upo.property_value_boolean = true THEN 'Y'::text
            WHEN upo.property_value_boolean = false THEN 'N'::text
            ELSE NULL::text
        END::character varying) AS property_value,
        CASE
            WHEN upn.is_multivalue = false THEN 0
            ELSE 1
        END AS is_multivalue,
        CASE
            WHEN pdt.property_data_type::text = 'boolean'::text THEN 1
            ELSE 0
        END AS is_boolean
   FROM jazzhands.v_account_collection_account_expanded_detail uued
     JOIN jazzhands.account_collection u USING (account_collection_id)
     JOIN jazzhands.v_property upo ON upo.account_collection_id = u.account_collection_id AND (upo.property_type::text = ANY (ARRAY['CCAForceCreation'::character varying, 'CCARight'::character varying, 'ConsoleACL'::character varying, 'RADIUS'::character varying, 'TokenMgmt'::character varying, 'UnixPasswdFileValue'::character varying, 'UserMgmt'::character varying, 'cca'::character varying, 'feed-attributes'::character varying, 'wwwgroup'::character varying, 'HOTPants'::character varying]::text[]))
     JOIN jazzhands.val_property upn ON upo.property_name::text = upn.property_name::text AND upo.property_type::text = upn.property_type::text
     JOIN jazzhands.val_property_data_type pdt ON upn.property_data_type::text = pdt.property_data_type::text
     JOIN jazzhands.account a ON uued.account_id = a.account_id
     JOIN jazzhands.account_realm ar ON a.account_realm_id = ar.account_realm_id
     LEFT JOIN jazzhands.v_device_collection_hier_detail dchd ON dchd.parent_device_collection_id = upo.device_collection_id
  ORDER BY dchd.device_collection_level, (
        CASE
            WHEN u.account_collection_type::text = 'per-account'::text THEN 0
            WHEN u.account_collection_type::text = 'property'::text THEN 1
            WHEN u.account_collection_type::text = 'systems'::text THEN 2
            ELSE 3
        END), (
        CASE
            WHEN uued.assign_method = 'Account_CollectionAssignedToPerson'::text THEN 0
            WHEN uued.assign_method = 'Account_CollectionAssignedToDept'::text THEN 1
            WHEN uued.assign_method = 'ParentAccount_CollectionOfAccount_CollectionAssignedToPerson'::text THEN 2
            WHEN uued.assign_method = 'ParentAccount_CollectionOfAccount_CollectionAssignedToDept'::text THEN 2
            WHEN uued.assign_method = 'Account_CollectionAssignedToParentDept'::text THEN 3
            WHEN uued.assign_method = 'ParentAccount_CollectionOfAccount_CollectionAssignedToParentDep'::text THEN 3
            ELSE 6
        END), uued.dept_level, uued.acct_coll_level, dchd.device_collection_id, u.account_collection_id;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object IN ('v_device_collection_account_property_expanded','v_device_collection_account_property_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_device_collection_account_property_expanded failed but that is ok';
	NULL;
END;
$$;

-- just in case
SELECT schema_support.prepare_for_object_replay();

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('v_device_collection_account_property_expanded');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_device_collection_account_property_expanded  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_device_collection_account_property_expanded (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_account_property_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old v_device_collection_account_property_expanded failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_account_property_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new v_device_collection_account_property_expanded failed but that is ok';
	NULL;
END;
$$;

--------------------------------------------------------------------
-- DEALING WITH TABLE v_unix_group_overrides
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_unix_group_overrides', 'v_unix_group_overrides');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_unix_group_overrides', tags := ARRAY['view_v_unix_group_overrides']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_expanded_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_device_collection_hier_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_property_expanded', type := 'view');
DROP VIEW IF EXISTS jazzhands.v_unix_group_overrides;
CREATE VIEW jazzhands.v_unix_group_overrides AS
 WITH perdevtomclass AS (
         SELECT hdc.device_collection_id AS host_device_collection_id,
            mdc.device_collection_id AS mclass_device_collection_id,
            hdcd.device_id
           FROM jazzhands.device_collection hdc
             JOIN jazzhands.device_collection_device hdcd USING (device_collection_id)
             JOIN jazzhands.device_collection_device mdcd USING (device_id)
             JOIN jazzhands.device_collection mdc ON mdcd.device_collection_id = mdc.device_collection_id
          WHERE hdc.device_collection_type::text = 'per-device'::text AND mdc.device_collection_type::text = 'mclass'::text
        ), dcmap AS (
         SELECT v_device_collection_hier_detail.device_collection_id,
            v_device_collection_hier_detail.parent_device_collection_id,
            v_device_collection_hier_detail.device_collection_level
           FROM jazzhands.v_device_collection_hier_detail
        UNION
         SELECT p.host_device_collection_id AS device_collection_id,
            d.parent_device_collection_id,
            d.device_collection_level
           FROM perdevtomclass p
             JOIN jazzhands.v_device_collection_hier_detail d ON d.device_collection_id = p.mclass_device_collection_id
        )
 SELECT property_list.device_collection_id,
    property_list.account_collection_id,
    array_agg(property_list.setting ORDER BY property_list.rn) AS setting
   FROM ( SELECT select_for_ordering.device_collection_id,
            select_for_ordering.account_collection_id,
            select_for_ordering.setting,
            row_number() OVER () AS rn
           FROM ( SELECT dc_acct_prop_list.device_collection_id,
                    dc_acct_prop_list.account_collection_id,
                    unnest(ARRAY[dc_acct_prop_list.property_name, dc_acct_prop_list.property_value]) AS setting
                   FROM ( SELECT dchd.device_collection_id,
                            acpe.account_collection_id,
                            p.property_name,
                            COALESCE(p.property_value, p.property_value_password_type,
                                CASE
                                    WHEN p.property_value_boolean = true THEN 'Y'::text
                                    WHEN p.property_value_boolean = false THEN 'N'::text
                                    ELSE NULL::text
                                END::character varying) AS property_value,
                            row_number() OVER (PARTITION BY dchd.device_collection_id, acpe.account_collection_id, acpe.property_name ORDER BY dchd.device_collection_level, acpe.assignment_rank, acpe.property_id) AS ord
                           FROM jazzhands.v_account_collection_property_expanded acpe
                             JOIN jazzhands.unix_group ug USING (account_collection_id)
                             JOIN jazzhands.v_property p USING (property_id)
                             JOIN dcmap dchd ON dchd.parent_device_collection_id = p.device_collection_id
                          WHERE (p.property_type::text = ANY (ARRAY['UnixPasswdFileValue'::character varying, 'UnixGroupFileProperty'::character varying, 'MclassUnixProp'::character varying]::text[])) AND (p.property_name::text <> ALL (ARRAY['UnixLogin'::character varying, 'UnixGroup'::character varying, 'UnixGroupMemberOverride'::character varying]::text[]))) dc_acct_prop_list
                  WHERE dc_acct_prop_list.ord = 1) select_for_ordering) property_list
  GROUP BY property_list.device_collection_id, property_list.account_collection_id;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object IN ('v_unix_group_overrides','v_unix_group_overrides');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_unix_group_overrides failed but that is ok';
	NULL;
END;
$$;

-- just in case
SELECT schema_support.prepare_for_object_replay();

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('v_unix_group_overrides');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_unix_group_overrides  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_unix_group_overrides (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_unix_group_overrides');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old v_unix_group_overrides failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_unix_group_overrides');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new v_unix_group_overrides failed but that is ok';
	NULL;
END;
$$;

--------------------------------------------------------------------
-- DEALING WITH TABLE v_unix_account_overrides
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_unix_account_overrides', 'v_unix_account_overrides');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_unix_account_overrides', tags := ARRAY['view_v_unix_account_overrides']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_expanded_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_device_collection_hier_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_account_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_property_expanded', type := 'view');
DROP VIEW IF EXISTS jazzhands.v_unix_account_overrides;
CREATE VIEW jazzhands.v_unix_account_overrides AS
 SELECT property_list.device_collection_id,
    property_list.account_id,
    array_agg(property_list.setting ORDER BY property_list.rn) AS setting
   FROM ( SELECT select_for_ordering.device_collection_id,
            select_for_ordering.account_id,
            select_for_ordering.setting,
            row_number() OVER () AS rn
           FROM ( SELECT dc_acct_prop_list.device_collection_id,
                    dc_acct_prop_list.account_id,
                    unnest(ARRAY[dc_acct_prop_list.property_name, dc_acct_prop_list.property_value]) AS setting
                   FROM ( SELECT dchd.device_collection_id,
                            acae.account_id,
                            p.property_name,
                            COALESCE(p.property_value, p.property_value_password_type,
                                CASE
                                    WHEN p.property_value_boolean = true THEN 'Y'::text
                                    WHEN p.property_value_boolean = false THEN 'N'::text
                                    ELSE NULL::text
                                END::character varying) AS property_value,
                            row_number() OVER (PARTITION BY dchd.device_collection_id, acae.account_id, acpe.property_name ORDER BY dchd.device_collection_level, acpe.assignment_rank, acpe.property_id) AS ord
                           FROM jazzhands.v_account_collection_property_expanded acpe
                             JOIN jazzhands.v_account_collection_account_expanded acae USING (account_collection_id)
                             JOIN jazzhands.v_property p USING (property_id)
                             JOIN ( SELECT v_device_collection_hier_detail.device_collection_id,
                                    v_device_collection_hier_detail.parent_device_collection_id,
                                    v_device_collection_hier_detail.device_collection_level
                                   FROM jazzhands.v_device_collection_hier_detail
                                UNION ALL
                                 SELECT p_1.host_device_collection_id AS device_collection_id,
                                    d.parent_device_collection_id,
                                    d.device_collection_level
                                   FROM ( SELECT hdc.device_collection_id AS host_device_collection_id,
    mdc.device_collection_id AS mclass_device_collection_id,
    hdcd.device_id
   FROM jazzhands.device_collection hdc
     JOIN jazzhands.device_collection_device hdcd USING (device_collection_id)
     JOIN jazzhands.device_collection_device mdcd USING (device_id)
     JOIN jazzhands.device_collection mdc ON mdcd.device_collection_id = mdc.device_collection_id
  WHERE hdc.device_collection_type::text = 'per-device'::text AND mdc.device_collection_type::text = 'mclass'::text) p_1
                                     JOIN jazzhands.v_device_collection_hier_detail d ON d.device_collection_id = p_1.mclass_device_collection_id) dchd ON dchd.parent_device_collection_id = p.device_collection_id
                          WHERE (p.property_type::text = ANY (ARRAY['UnixPasswdFileValue'::character varying, 'UnixGroupFileProperty'::character varying, 'MclassUnixProp'::character varying]::text[])) AND (p.property_name::text <> ALL (ARRAY['UnixLogin'::character varying, 'UnixGroup'::character varying, 'UnixGroupMemberOverride'::character varying]::text[]))) dc_acct_prop_list
                  WHERE dc_acct_prop_list.ord = 1) select_for_ordering) property_list
  GROUP BY property_list.device_collection_id, property_list.account_id;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object IN ('v_unix_account_overrides','v_unix_account_overrides');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_unix_account_overrides failed but that is ok';
	NULL;
END;
$$;

-- just in case
SELECT schema_support.prepare_for_object_replay();

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('v_unix_account_overrides');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_unix_account_overrides  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_unix_account_overrides (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_unix_account_overrides');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old v_unix_account_overrides failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_unix_account_overrides');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new v_unix_account_overrides failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
--
-- Process proc drops in jazzhands_cache
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_cache']);
--
-- Process proc drops in jazzhands
--
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'dns_a_rec_validation');
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_a_rec_validation');
CREATE OR REPLACE FUNCTION jazzhands.dns_a_rec_validation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_ip		netblock.ip_address%type;
	_sing	netblock.is_single_address%type;
BEGIN

	--
	-- arguably, this belongs elsewhere in a non-"validation" trigger,
	-- but that only matters if this wants to be a constraint trigger.
	--
	IF NEW.ip_universe_id IS NULL THEN
		IF NEW.netblock_id IS NOT NULL THEN
			SELECT ip_universe_id INTO NEW.ip_universe_id
			FROM netblock
			WHERE netblock_id = NEW.netblock_id;
		ELSIF NEW.dns_value_record_id IS NOT NULL THEN
			SELECT ip_universe_id INTO NEW.ip_universe_id
			FROM dns_record
			WHERE dns_record_id = NEW.dns_value_record_id;
		ELSE
			-- old default.
			NEW.ip_universe_id = 0;
		END IF;
	END IF;

/*
	IF NEW.dns_type NOT IN ('A', 'AAAA', 'REVERSE_ZONE_BLOCK_PTR') THEN
		IF NEW.netblock_id IS NOT NULL THEN
			RAISE EXCEPTION 'Attempt to set % record with netblock',
				NEW.dns_type
				USING ERRCODE = 'not_null_violation';
		END IF;
		IF TG_OP = 'INSERT' THEN
			RETURN NEW;
		ELSIF TG_OP = 'UPDATE' AND
			OLD.dns_type IS NOT DISTINCT FROM NEW.dns_type
		THEN
			RETURN NEW;
		END IF;
	END IF;
 */

	IF NEW.dns_type in ('A', 'AAAA') THEN
		IF ( NEW.netblock_id IS NULL AND NEW.dns_value_record_id IS NULL ) THEN
			RAISE EXCEPTION 'Attempt to set % record without netblocks',
				NEW.dns_type
				USING ERRCODE = 'not_null_violation';
		ELSIF NEW.dns_value_record_id IS NOT NULL THEN
			PERFORM *
			FROM dns_record d
			WHERE d.dns_record_id = NEW.dns_value_record_id
			AND d.dns_type = NEW.dns_type
			AND d.dns_class = NEW.dns_class;

			IF NOT FOUND THEN
				RAISE EXCEPTION 'Attempt to set % value record without the correct netblock',
					NEW.dns_type
					USING ERRCODE = 'not_null_violation';
			END IF;
		END IF;

		IF ( NEW.should_generate_ptr = true AND NEW.dns_value_record_id IS NOT NULL ) THEN
			RAISE EXCEPTION 'It is not permitted to set should_generate_ptr and use a dns_value_record_id'
				USING ERRCODE = 'foreign_key_violation';
		END IF;
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

	-- XXX need to deal with changing a netblock type and breaking dns_record..
	IF NEW.netblock_id IS NOT NULL THEN
		SELECT ip_address, is_single_address
		  INTO _ip, _sing
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

		IF _sing = false AND NEW.dns_type IN ('A','AAAA') THEN
			RAISE EXCEPTION 'Non-single addresses may not have % records', NEW.dns_type
				USING ERRCODE = 'foreign_key_violation';
		END IF;

	END IF;

	RETURN NEW;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'function' AND object IN ('dns_a_rec_validation');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc dns_a_rec_validation failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'dns_change_record_pgnotify');
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_change_record_pgnotify');
CREATE OR REPLACE FUNCTION jazzhands.dns_change_record_pgnotify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	NOTIFY dns_zone_gen;
	RETURN NEW;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'function' AND object IN ('dns_change_record_pgnotify');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc dns_change_record_pgnotify failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'dns_rec_prevent_dups');
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_rec_prevent_dups');
CREATE OR REPLACE FUNCTION jazzhands.dns_rec_prevent_dups()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	-- should not be able to insert the same record(s) twice
	SELECT	count(*)
		INTO	_tally
		FROM (
			SELECT
					db.dns_record_id,
					coalesce(ref.dns_name, db.dns_name) as dns_name,
					db.dns_domain_id, db.dns_ttl,
					db.dns_class, db.dns_type,
					coalesce(val.dns_value, db.dns_value) AS dns_value,
					db.dns_priority, db.dns_srv_service, db.dns_srv_protocol,
					db.dns_srv_weight, db.dns_srv_port, db.ip_universe_id,
					coalesce(val.netblock_id, db.netblock_id) AS netblock_id,
					db.reference_dns_record_id, db.dns_value_record_id,
					db.should_generate_ptr, db.is_enabled
				FROM dns_record db
					LEFT JOIN (
							SELECT dns_record_id AS reference_dns_record_id,
									dns_name
							FROM dns_record
							WHERE dns_domain_id = NEW.dns_domain_id
						) ref USING (reference_dns_record_id)
					LEFT JOIN (
							SELECT dns_record_id AS dns_value_record_id,
									dns_value, netblock_id
							FROM dns_record
						) val USING (dns_value_record_id)
				WHERE db.dns_record_id != NEW.dns_record_id
				AND (lower(coalesce(ref.dns_name, db.dns_name))
							IS NOT DISTINCT FROM lower(NEW.dns_name))
				AND ( db.dns_domain_id = NEW.dns_domain_id )
				AND ( db.dns_class = NEW.dns_class )
				AND ( db.dns_type = NEW.dns_type )
				AND db.dns_record_id != NEW.dns_record_id
				AND db.dns_srv_service IS NOT DISTINCT FROM NEW.dns_srv_service
				AND db.dns_srv_protocol IS NOT DISTINCT FROM NEW.dns_srv_protocol
				AND db.dns_srv_port IS NOT DISTINCT FROM NEW.dns_srv_port
				AND db.ip_universe_id IS NOT DISTINCT FROM NEW.ip_universe_id
				AND db.is_enabled = true
			) dns
			LEFT JOIN dns_record val
				ON ( NEW.dns_value_record_id = val.dns_record_id )
		WHERE
			dns.dns_domain_id = NEW.dns_domain_id
		AND
			dns.dns_value IS NOT DISTINCT FROM
				coalesce(val.dns_value, NEW.dns_value)
		AND
			dns.netblock_id IS NOT DISTINCT FROM
				coalesce(val.netblock_id, NEW.netblock_id)
	;

	IF _tally != 0 THEN
		RAISE EXCEPTION 'Attempt to insert the same dns record - % %', _tally,
			NEW USING ERRCODE = 'unique_violation';
	END IF;

	IF NEW.DNS_TYPE = 'A' OR NEW.DNS_TYPE = 'AAAA' THEN
		IF NEW.SHOULD_GENERATE_PTR = true THEN
			SELECT	count(*)
			 INTO	_tally
			 FROM	dns_record
			WHERE dns_class = 'IN'
			AND dns_type = 'A'
			AND should_generate_ptr = true
			AND is_enabled = true
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
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'function' AND object IN ('dns_rec_prevent_dups');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc dns_rec_prevent_dups failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'dns_record_cname_checker');
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_record_cname_checker');
CREATE OR REPLACE FUNCTION jazzhands.dns_record_cname_checker()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_r		RECORD;
	_d		RECORD;
	_dom	TEXT;
BEGIN
	--- XXX - need to seriously think about ip_universes here.
	-- These should also move to the v_dns view once it's cached.  They were
	-- there before, but it was too slow here.

	SELECT dns_name, dns_domain_id, dns_class,
		COUNT(*) FILTER (WHERE dns_type = 'CNAME') AS num_cnames,
		COUNT(*) FILTER (WHERE dns_type != 'CNAME') AS num_not_cnames
	INTO _r
	FROM	(
		SELECT dns_name, dns_domain_id, dns_type, dns_class, ip_universe_id
			FROM dns_record
			WHERE reference_dns_record_id IS NULL
			AND is_enabled = 'Y'
		UNION ALL
		SELECT ref.dns_name, d.dns_domain_id, d.dns_type, d.dns_class,
				d.ip_universe_id
			FROM dns_record d
			JOIN dns_record ref
				ON ref.dns_record_id = d.reference_dns_record_id
			WHERE d.is_enabled = 'Y'
	) smash
	WHERE lower(dns_name) IS NOT DISTINCT FROM lower(NEW.dns_name)
	AND dns_domain_id = NEW.dns_domain_id
	-- AND ip_universe_id = NEW.ip_universe_id
	-- AND dns_class = NEW.dns_class
	GROUP BY 1, 2, 3;

	IF ( _r.num_cnames > 0 AND _r.num_not_cnames > 0 ) OR _r.num_cnames > 1 THEN
		SELECT dns_domain_name INTO _dom FROM dns_domain
		WHERE dns_domain_id = NEW.dns_domain_id ;

		if NEW.dns_name IS NULL THEN
			RAISE EXCEPTION '% may not have CNAME and other records (%/%)',
				_dom, _r.num_cnames, _r.num_not_cnames
				USING ERRCODE = 'unique_violation';
		ELSE
			RAISE EXCEPTION '%.% may not have CNAME and other records (%/%)',
				NEW.dns_name, _dom, _r.num_cnames, _r.num_not_cnames
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'function' AND object IN ('dns_record_cname_checker');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc dns_record_cname_checker failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands']);
-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_ip_universe_trigger_del()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE  _r RECORD;
BEGIN
	-- this all needs to be rethunk in light of when this can be NULL
	IF OLD.should_generate THEN
		DELETE FROM dns_change_record
		WHERE dns_domain_id = OLD.dns_domain_id
		AND (
			ip_universe_id = OLD.ip_universe_id
			OR ip_universe_id IS NULL
		);
	END IF;

	FOR _r IN SELECT * FROM dns_change_record
	LOOP
	END LOOP;

	RETURN OLD;
END;
$function$
;

--
-- Process proc drops in net_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_net_manip']);
--
-- Process proc drops in network_strings
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_network_strings']);
--
-- Process proc drops in time_util
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_time_util']);
--
-- Process proc drops in dns_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_dns_utils']);
--
-- Process proc drops in obfuscation_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_obfuscation_utils']);
--
-- Process proc drops in person_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_person_manip']);
--
-- Process proc drops in account_password_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_account_password_manip']);
--
-- Process proc drops in auto_ac_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_auto_ac_manip']);
--
-- Process proc drops in company_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_company_manip']);
--
-- Process proc drops in token_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_token_utils']);
--
-- Process proc drops in device_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_device_manip']);
--
-- Process proc drops in device_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_device_utils']);
--
-- Process proc drops in netblock_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_netblock_utils']);
--
-- Process proc drops in property_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_property_utils']);
--
-- Process proc drops in netblock_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_netblock_manip']);
--
-- Process proc drops in physical_address_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_physical_address_utils']);
--
-- Process proc drops in component_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_utils']);
--
-- Process proc drops in snapshot_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_snapshot_manip']);
--
-- Process proc drops in lv_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_lv_manip']);
--
-- Process proc drops in approval_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'approval_utils'::text, object := 'approve ( integer,boolean,integer,text )'::text, tags := ARRAY['process_all_procs_in_schema_approval_utils'::text]);
DROP FUNCTION IF EXISTS approval_utils.approve ( integer,boolean,integer,text );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'approval_utils'::text, object := 'approve ( integer,text,integer,text )'::text, tags := ARRAY['process_all_procs_in_schema_approval_utils'::text]);
DROP FUNCTION IF EXISTS approval_utils.approve ( integer,text,integer,text );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'approval_utils'::text, object := 'message_replace ( text,timestamp without time zone,timestamp without time zone )'::text, tags := ARRAY['process_all_procs_in_schema_approval_utils'::text]);
DROP FUNCTION IF EXISTS approval_utils.message_replace ( text,timestamp without time zone,timestamp without time zone );
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_approval_utils']);
--
-- Process proc drops in account_collection_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_account_collection_manip']);
--
-- Process proc drops in script_hooks
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_script_hooks']);
--
-- Process proc drops in backend_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_backend_utils']);
--
-- Process proc drops in rack_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_rack_utils']);
--
-- Process proc drops in layerx_network_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_layerx_network_manip']);
--
-- Process proc drops in component_connection_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_connection_utils']);
--
-- Process proc drops in logical_port_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_logical_port_manip']);
--
-- Process proc drops in schema_support
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_schema_support']);
--
-- Process proc drops in pgcrypto
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_pgcrypto']);
--
-- Process proc drops in audit
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_audit']);
--
-- Process proc drops in port_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_port_utils']);
--
-- Process proc drops in jazzhands_legacy
--
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_dns_domain_nouniverse_del');
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_dns_domain_nouniverse_del');
CREATE OR REPLACE FUNCTION jazzhands_legacy.v_dns_domain_nouniverse_del()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_d		jazzhands.dns_domain%rowtype;
	_du		jazzhands.dns_domain_ip_universe%rowtype;
BEGIN
	DELETE FROM jazzhands.dns_domain_ip_universe
	WHERE  dns_domain_id = OLD.dns_domain_id
	AND ip_universe_id = 0
	RETURNING * INTO _du;

	DELETE FROM jazzhands.dns_domain
	WHERE  dns_domain_id = OLD.dns_domain_id
	RETURNING * INTO _d;

	OLD.dns_domain_id = _d.dns_domain_id;
	OLD.soa_name = _d.dns_domain_name;
	OLD.dns_domain_type = _d.dns_domain_type;
	OLD.parent_dns_domain_id = _d.parent_dns_domain_id;

	OLD.soa_class = _du.soa_class;
	OLD.soa_ttl = _du.soa_ttl;
	OLD.soa_serial = _du.soa_serial;
	OLD.soa_refresh = _du.soa_refresh;
	OLD.soa_retry = _du.soa_retry;
	OLD.soa_expire = _du.soa_expire;
	OLD.soa_minimum = _du.soa_minimum;
	OLD.soa_mname = _du.soa_mname;
	OLD.soa_rname = _du.soa_rname;
	OLD.should_generate = CASE WHEN _du.should_generate = true THEN 'Y' WHEN _du.should_generate = false THEN 'N' ELSE NULL END;
	OLD.last_generated = _du.last_generated;

	OLD.data_ins_user = coalesce(_d.data_ins_user, _du.data_ins_user);
	OLD.data_ins_date = coalesce(_d.data_ins_date, _du.data_ins_date);
	OLD.data_upd_user = coalesce(_du.data_upd_user, _d.data_upd_user);
	OLD.data_upd_date = coalesce(_du.data_upd_date, _d.data_upd_date);
	RETURN OLD;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'function' AND object IN ('v_dns_domain_nouniverse_del');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc v_dns_domain_nouniverse_del failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_dns_domain_nouniverse_ins');
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_dns_domain_nouniverse_ins');
CREATE OR REPLACE FUNCTION jazzhands_legacy.v_dns_domain_nouniverse_ins()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_d	jazzhands.dns_domain%rowtype;
	_du	jazzhands.dns_domain_ip_universe%rowtype;
BEGIN
	IF NEW.dns_domain_id IS NULL THEN
		INSERT INTO jazzhands.dns_domain (
			dns_domain_name, dns_domain_type, parent_dns_domain_id
		) VALUES (
			NEW.soa_name, NEW.dns_domain_type, NEW.parent_dns_domain_id
		) RETURNING * INTO _d;
	ELSE
		INSERT INTO jazzhands.dns_domain (
			dns_domain_id, dns_domain_name, dns_domain_type,
			parent_dns_domain_id
		) VALUES (
			NEW.dns_domain_id, NEW.soa_name, NEW.dns_domain_type,
			NEW.parent_dns_domain_id
		) RETURNING * INTO _d;
	END IF;

	INSERT INTO dns_domain_ip_universe (
		dns_domain_id, ip_universe_id,
		soa_class, soa_ttl, soa_serial, soa_refresh,
		soa_retry,
		soa_expire, soa_minimum, soa_mname, soa_rname,
		should_generate,
		last_generated
	) VALUES (
		_d.dns_domain_id, 0,
		NEW.soa_class, NEW.soa_ttl, NEW.soa_serial, NEW.soa_refresh,
		NEW.soa_retry,
		NEW.soa_expire, NEW.soa_minimum, NEW.soa_mname, NEW.soa_rname,
		CASE WHEN NEW.should_generate = 'Y' THEN true
			WHEN NEW.should_generate = 'N' THEN false
			ELSE NULL
			END,
		NEW.last_generated
	) RETURNING * INTO _du;

	NEW.dns_domain_id = _d.dns_domain_id;
	NEW.soa_name = _d.dns_domain_name;
	NEW.soa_class = _du.soa_class;
	NEW.soa_ttl = _du.soa_ttl;
	NEW.soa_serial = _du.soa_serial;
	NEW.soa_refresh = _du.soa_refresh;
	NEW.soa_retry = _du.soa_retry;
	NEW.soa_expire = _du.soa_expire;
	NEW.soa_minimum = _du.soa_minimum;
	NEW.soa_mname = _du.soa_mname;
	NEW.soa_rname = _du.soa_rname;
	NEW.parent_dns_domain_id = _d.parent_dns_domain_id;
	NEW.should_generate = CASE WHEN _du.should_generate = true THEN 'Y' WHEN _du.should_generate = false THEN 'N' ELSE NULL END;
	NEW.last_generated = _du.last_generated;
	NEW.dns_domain_type = _d.dns_domain_type;

	NEW.data_ins_user = coalesce(_d.data_ins_user, _du.data_ins_user);
	NEW.data_ins_date = coalesce(_d.data_ins_date, _du.data_ins_date);
	NEW.data_upd_user = coalesce(_du.data_upd_user, _d.data_upd_user);
	NEW.data_upd_date = coalesce(_du.data_upd_date, _d.data_upd_date);
	RETURN NEW;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'function' AND object IN ('v_dns_domain_nouniverse_ins');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc v_dns_domain_nouniverse_ins failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_dns_domain_nouniverse_upd');
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_dns_domain_nouniverse_upd');
CREATE OR REPLACE FUNCTION jazzhands_legacy.v_dns_domain_nouniverse_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_d		jazzhands.dns_domain%rowtype;
	_du		jazzhands.dns_domain_ip_universe%rowtype;
	_duq	text[];
	_uq		text[];
BEGIN

	IF OLD.dns_domain_id IS DISTINCT FROM NEW.dns_domain_id THEN
		RAISE EXCEPTION 'Can not change dns_domain_id'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF OLD.soa_name IS DISTINCT FROM NEW.soa_name THEN
		_duq := array_append(_duq, 'dns_domain_name = ' || quote_nullable(NEW.soa_name));
	END IF;

	IF OLD.parent_dns_domain_id IS DISTINCT FROM NEW.parent_dns_domain_id THEN
		_duq := array_append(_duq, 'parent_dns_domain_id = ' || quote_nullable(NEW.parent_dns_domain_id));
	END IF;

	IF OLD.dns_domain_type IS DISTINCT FROM NEW.dns_domain_type THEN
		_duq := array_append(_duq, 'dns_domain_type = ' || quote_nullable(NEW.dns_domain_type));
	END IF;

	--

	IF OLD.soa_class IS DISTINCT FROM NEW.soa_class THEN
		_uq := array_append(_uq, 'soa_class = ' || quote_nullable(NEW.soa_class));
	END IF;

	IF OLD.soa_ttl IS DISTINCT FROM NEW.soa_ttl THEN
		_uq := array_append(_uq, 'soa_ttl = ' || quote_nullable(NEW.soa_ttl));
	END IF;

	IF OLD.soa_serial IS DISTINCT FROM NEW.soa_serial THEN
		_uq := array_append(_uq, 'soa_serial = ' || quote_nullable(NEW.soa_serial));
	END IF;

	IF OLD.soa_refresh IS DISTINCT FROM NEW.soa_refresh THEN
		_uq := array_append(_uq, 'soa_refresh = ' || quote_nullable(NEW.soa_refresh));
	END IF;

	IF OLD.soa_retry IS DISTINCT FROM NEW.soa_retry THEN
		_uq := array_append(_uq, 'soa_retry = ' || quote_nullable(NEW.soa_retry));
	END IF;

	IF OLD.soa_expire IS DISTINCT FROM NEW.soa_expire THEN
		_uq := array_append(_uq, 'soa_expire = ' || quote_nullable(NEW.soa_expire));
	END IF;

	IF OLD.soa_minimum IS DISTINCT FROM NEW.soa_minimum THEN
		_uq := array_append(_uq, 'soa_minimum = ' || quote_nullable(NEW.soa_minimum));
	END IF;

	IF OLD.soa_mname IS DISTINCT FROM NEW.soa_mname THEN
		_uq := array_append(_uq, 'soa_mname = ' || quote_nullable(NEW.soa_mname));
	END IF;

	IF OLD.soa_rname IS DISTINCT FROM NEW.soa_rname THEN
		_uq := array_append(_uq, 'soa_rname = ' || quote_nullable(NEW.soa_rname));
	END IF;

	IF OLD.should_generate IS DISTINCT FROM NEW.should_generate THEN
		IF NEW.should_generate = 'Y' THEN
			_uq := array_append(_uq, 'should_generate = true');
		ELSIF NEW.should_generate = 'N' THEN
			_uq := array_append(_uq, 'should_generate = false');
		ELSE
			_uq := array_append(_uq, 'should_generate = NULL');
		END IF;
	END IF;

	IF OLD.last_generated IS DISTINCT FROM NEW.last_generated THEN
		_uq := array_append(_uq, 'last_generated = ' || quote_nullable(NEW.last_generated));
	END IF;

	IF _duq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.dns_domain SET ' ||
			array_to_string(_duq, ', ') ||
			' WHERE  dns_domain_id = $1 RETURNING *'
			USING OLD.dns_domain_id
			INTO _d;

		NEW.dns_domain_id = _d.dns_domain_id;
		NEW.soa_name = _d.soa_name;
		NEW.dns_domain_type = _d.dns_domain_type;
		NEW.parent_dns_domain_id = _d.parent_dns_domain_id;
	ELSE
		SELECT * INTO _d  FROM jazzhands.dns_domain
		WHERE dns_domain_id = NEW.dns_domain_id;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.dns_domain_ip_universe SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  dns_domain_id = $1 AND ip_universe_id = 0 RETURNING *'
			USING OLD.dns_domain_id
			INTO _du;

		NEW.soa_class = _du.soa_class;
		NEW.soa_ttl = _du.soa_ttl;
		NEW.soa_serial = _du.soa_serial;
		NEW.soa_refresh = _du.soa_refresh;
		NEW.soa_retry = _du.soa_retry;
		NEW.soa_expire = _du.soa_expire;
		NEW.soa_minimum = _du.soa_minimum;
		NEW.soa_mname = _du.soa_mname;
		NEW.soa_rname = _du.soa_rname;
		NEW.should_generate = CASE WHEN _du.should_generate = true THEN 'Y' WHEN _du.should_generate = false THEN 'N' ELSE NULL END;
		NEW.last_generated = _du.last_generated;
	ELSE
		SELECT * INTO _du FROM jazzhands.dns_domain_ip_universe
			WHERE dns_domain_id = NEW.dns_domain_id
			AND ip_universe_id = 0;
	END IF;

	NEW.data_ins_user = coalesce(_d.data_ins_user, _du.data_ins_user);
	NEW.data_ins_date = coalesce(_d.data_ins_date, _du.data_ins_date);
	NEW.data_upd_user = coalesce(_du.data_upd_user, _d.data_upd_user);
	NEW.data_upd_date = coalesce(_du.data_upd_date, _d.data_upd_date);

	RETURN NEW;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'function' AND object IN ('v_dns_domain_nouniverse_upd');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc v_dns_domain_nouniverse_upd failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'x509_certificate_ins');
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'x509_certificate_ins');
CREATE OR REPLACE FUNCTION jazzhands_legacy.x509_certificate_ins()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	key	jazzhands.private_key%rowtype;
	csr	jazzhands.certificate_signing_request%rowtype;
	crt	jazzhands.x509_signed_certificate%rowtype;
BEGIN
	IF NEW.private_key IS NOT NULL THEN
		INSERT INTO jazzhands.private_key (
			private_key_encryption_type,
			is_active,
			subject_key_identifier,
			private_key,
			passphrase,
			encryption_key_id
		) VALUES (
			'rsa',
			CASE WHEN NEW.is_active = 'Y' THEN true
				WHEN NEW.is_active = 'N' THEN false
				ELSE NULL END,
			NEW.subject_key_identifier,
			NEW.private_key,
			NEW.passphrase,
			NEW.encryption_key_id
		) RETURNING * INTO key;
		NEW.x509_cert_id := key.private_key_id;
	ELSE
		IF NEW.subject_key_identifier IS NOT NULL THEN
			SELECT *
			INTO key
			FROM private_key
			WHERE subject_key_identifier = NEW.subject_key_identifier;

			SELECT private_key
			INTO NEW.private_key
			FROM private_key
			WHERE private_key_id = key.private_key_id;
		END IF;
	END IF;

	IF NEW.certificate_sign_req IS NOT NULL THEN
		INSERT INTO jazzhands.certificate_signing_request (
			friendly_name,
			subject,
			certificate_signing_request,
			private_key_id
		) VALUES (
			NEW.friendly_name,
			NEW.subject,
			NEW.certificate_sign_req,
			key.private_key_id
		) RETURNING * INTO csr;
		IF NEW.x509_cert_id IS NULL THEN
			NEW.x509_cert_id := csr.certificate_signing_request_id;
		END IF;
	ELSE
		IF NEW.subject_key_identifier IS NOT NULL THEN
			SELECT certificate_signing_request_id
			INTO csr
			FROM certificate_signing_request
				JOIN private_key USING (private_key_id)
			WHERE subject_key_identifier = NEW.subject_key_identifier
			ORDER BY certificate_signing_request_id
			LIMIT 1;

			SELECT certificate_signing_request
			INTO NEW.certificate_sign_req
			FROM certificate_signing_request
			WHERE certificate_signing_request_id  = csr.certificate_signing_request_id;
		END IF;
	END IF;

	IF NEW.public_key IS NOT NULL THEN
		INSERT INTO jazzhands.x509_signed_certificate (
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
			CASE WHEN NEW.is_active = 'Y' THEN true
				WHEN NEW.is_active = 'N' THEN false
				ELSE NULL END,
			CASE WHEN NEW.is_certificate_authority = 'Y' THEN true
				WHEN NEW.is_certificate_authority = 'N' THEN false
				ELSE NULL END,
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
			key.private_key_id,
			csr.certificate_signing_request_id
		) RETURNING * INTO crt;

		NEW.x509_cert_id 		= crt.x509_signed_certificate_id;
		NEW.friendly_name 		= crt.friendly_name;
		NEW.is_active 			= CASE WHEN crt.is_active = true THEN 'Y'
									WHEN crt.is_active = false THEN 'N'
									ELSE NULL END;
		NEW.is_certificate_authority = CASE WHEN crt.is_certificate_authority =
										true THEN 'Y'
									WHEN crt.is_certificate_authority = false
										THEN 'N'
									ELSE NULL END;

		NEW.signing_cert_id 			= crt.signing_cert_id;
		NEW.x509_ca_cert_serial_number	= crt.x509_ca_cert_serial_number;
		NEW.public_key 					= crt.public_key;
		NEW.private_key 				= key.private_key;
		NEW.certificate_sign_req 		= csr.certificate_signing_request;
		NEW.subject 					= crt.subject;
		NEW.subject_key_identifier 		= crt.subject_key_identifier;
		NEW.valid_from 					= crt.valid_from;
		NEW.valid_to 					= crt.valid_to;
		NEW.x509_revocation_date 		= crt.x509_revocation_date;
		NEW.x509_revocation_reason 		= crt.x509_revocation_reason;
		NEW.passphrase 					= key.passphrase;
		NEW.encryption_key_id 			= key.encryption_key_id;
		NEW.ocsp_uri 					= crt.ocsp_uri;
		NEW.crl_uri 					= crt.crl_uri;
		NEW.data_ins_user 				= crt.data_ins_user;
		NEW.data_ins_date 				= crt.data_ins_date;
		NEW.data_upd_user 				= crt.data_upd_user;
		NEW.data_upd_date 				= crt.data_upd_date;
	END IF;
	RETURN NEW;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'function' AND object IN ('x509_certificate_ins');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc x509_certificate_ins failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'x509_certificate_upd');
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'x509_certificate_upd');
CREATE OR REPLACE FUNCTION jazzhands_legacy.x509_certificate_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	crt	jazzhands.x509_signed_certificate%rowtype;
	key	jazzhands.private_key%rowtype;
	csr	jazzhands.certificate_signing_request%rowtype;
	_uq	text[];
BEGIN
	SELECT * INTO crt FROM jazzhands.x509_signed_certificate
        WHERE x509_signed_certificate_id = OLD.x509_cert_id;

	IF crt.private_key_ID IS NULL AND NEW.private_key IS NOT NULL THEN
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
		) RETURNING * INTO key;
	ELSE IF crt.private_key_id IS NOT NULL THEN
		SELECT * INTO key FROM jazzhands.private_key k
			WHERE k.private_key_id =  crt.private_key_id;

		-- delete happens at the end, after update
		IF NEW.private_key IS NOT NULL THEN
			IF OLD.subject_key_identifier IS DISTINCT FROM NEW.subject_key_identifier THEN
				_uq := array_append(_uq,
					'subject_key_identifier = ' || quote_nullable(NEW.subject_key_identifier)
				);
			END IF;
			IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
				IF NEW.is_active = 'Y' THEN
					_uq := array_append(_uq, 'is_active = true');
				ELSIF NEW.is_active = 'N' THEN
					_uq := array_append(_uq, 'is_active = false');
				ELSE
					_uq := array_append(_uq, 'is_active = NULL');
				END IF;
			END IF;
			IF OLD.private_key IS DISTINCT FROM NEW.private_key THEN
				_uq := array_append(_uq,
					'private_key = ' || quote_nullable(NEW.private_key)
				);
			END IF;
			IF OLD.passphrase IS DISTINCT FROM NEW.passphrase THEN
				_uq := array_append(_uq,
					'passphrase = ' || quote_nullable(NEW.passphrase)
				);
			END IF;
			IF OLD.encryption_key_id IS DISTINCT FROM NEW.encryption_key_id THEN
				_uq := array_append(_uq,
					'encryption_key_id = ' || quote_nullable(NEW.encryption_key_id)
				);
			END IF;
			IF array_length(_uq, 1) > 0 THEN
				EXECUTE format('UPDATE private_key SET %s WHERE private_key_id = $1 RETURNING *',
					array_to_string(_uq, ', '))
					USING crt.private_key_id
					INTO key;
			END IF;
		END IF;

		NEW.private_key 		= key.private_key;
		NEW.is_active 			= CASE WHEN key.is_active THEN 'Y' ELSE 'N' END;
		NEW.passphrase 			= key.passphrase;
		NEW.encryption_key_id	= key.encryption_key_id;
	END IF;

	-- private_key pieces are now what it is supposed to be.
	_uq := NULL;

	IF crt.certificate_signing_request_id IS NULL AND NEW.certificate_sign_req IS NOT NULL THEN
		INSERT INTO jazzhands.certificate_signing_request (
			friendly_name,
			subject,
			certificate_signing_request,
			private_key_id
		) VALUES (
			NEW.friendly_name,
			NEW.subject,
			NEW.certificate_sign_req,
			key.private_key_id
		) RETURNING * INTO csr;
	ELSIF crt.certificate_signing_request_id IS NOT NULL THEN
		SELECT * INTO csr FROM jazzhands.certificate_signing_request c
			WHERE c.certificate_sign_req =  crt.certificate_signing_request_id;

		-- delete happens at the end, after update
		IF NEW.certificate_sign_req IS NOT NULL THEN
			IF OLD.certificate_sign_req IS DISTINCT FROM NEW.certificate_sign_req THEN
				_uq := array_append(_uq,
					'certificate_signing_request = ' || quote_nullable(NEW.certificate_sign_req)
				);
			END IF;
			IF OLD.subject IS DISTINCT FROM NEW.subject THEN
				_uq := array_append(_uq,
					'subject = ' || quote_nullable(NEW.subject)
				);
			END IF;
			IF OLD.friendly_name IS DISTINCT FROM NEW.friendly_name THEN
				_uq := array_append(_uq,
					'friendly_name = ' || quote_nullable(NEW.friendly_name)
				);
			END IF;
			IF OLD.private_key_id IS DISTINCT FROM key.private_key_id THEN
				_uq := array_append(_uq,
					'private_key_id = ' || quote_nullable(NEW.private_key_id)
				);
			END IF;

			IF array_length(_uq, 1) > 0 THEN
				EXECUTE format('UPDATE private_key SET %s WHERE private_key_id = $1 RETURNING *',
					array_to_string(_uq, ', '))
					USING crt.private_key_id
					INTO key;
			END IF;
		END IF;

		NEW.certificate_sign_req 	= csr.certificate_signing_request;
	END IF;

	-- csr and private_key pieces are now what it is supposed to be.
	_uq := NULL;

	IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
		IF NEW.is_active = 'Y' THEN
			_uq := array_append(_uq, 'is_active = true');
		ELSIF NEW.is_active = 'N' THEN
			_uq := array_append(_uq, 'is_active = false');
		ELSE
			_uq := array_append(_uq, 'is_active = NULL');
		END IF;
	END IF;

	END IF;
	IF OLD.friendly_name IS DISTINCT FROM NEW.friendly_name THEN
		_uq := array_append(_uq,
			'friendly_name = ' || quote_literal(NEW.friendly_name)
		);
	END IF;
	IF OLD.subject IS DISTINCT FROM NEW.subject THEN
		_uq := array_append(_uq,
			'subject = ' || quote_literal(NEW.subject)
		);
	END IF;
	IF OLD.subject_key_identifier IS DISTINCT FROM NEW.subject_key_identifier THEN
		_uq := array_append(_uq,
			'subject_key_identifier = ' || quote_nullable(NEW.subject_key_identifier)
		);
	END IF;

	IF OLD.is_certificate_authority IS DISTINCT FROM NEW.is_certificate_authority THEN
		IF NEW.is_certificate_authority = 'Y' THEN
			_uq := array_append(_uq, 'is_certificate_authority = true');
		ELSIF NEW.is_certificate_authority = 'N' THEN
			_uq := array_append(_uq, 'is_certificate_authority = false');
		ELSE
			_uq := array_append(_uq, 'is_certificate_authority = NULL');
		END IF;
	END IF;

	IF OLD.signing_cert_id IS DISTINCT FROM NEW.signing_cert_id THEN
		_uq := array_append(_uq,
			'signing_cert_id = ' || quote_nullable(NEW.signing_cert_id)
		);
	END IF;
	IF OLD.x509_ca_cert_serial_number IS DISTINCT FROM NEW.x509_ca_cert_serial_number THEN
		_uq := array_append(_uq,
			'x509_ca_cert_serial_number = ' || quote_nullable(NEW.x509_ca_cert_serial_number)
		);
	END IF;
	IF OLD.public_key IS DISTINCT FROM NEW.public_key THEN
		_uq := array_append(_uq,
			'public_key = ' || quote_nullable(NEW.public_key)
		);
	END IF;
	IF OLD.valid_from IS DISTINCT FROM NEW.valid_from THEN
		_uq := array_append(_uq,
			'valid_from = ' || quote_nullable(NEW.valid_from)
		);
	END IF;
	IF OLD.valid_to IS DISTINCT FROM NEW.valid_to THEN
		_uq := array_append(_uq,
			'valid_to = ' || quote_nullable(NEW.valid_to)
		);
	END IF;
	IF OLD.x509_revocation_date IS DISTINCT FROM NEW.x509_revocation_date THEN
		_uq := array_append(_uq,
			'x509_revocation_date = ' || quote_nullable(NEW.x509_revocation_date)
		);
	END IF;
	IF OLD.x509_revocation_reason IS DISTINCT FROM NEW.x509_revocation_reason THEN
		_uq := array_append(_uq,
			'x509_revocation_reason = ' || quote_nullable(NEW.x509_revocation_reason)
		);
	END IF;
	IF OLD.ocsp_uri IS DISTINCT FROM NEW.ocsp_uri THEN
		_uq := array_append(_uq,
			'ocsp_uri = ' || quote_nullable(NEW.ocsp_uri)
		);
	END IF;
	IF OLD.crl_uri IS DISTINCT FROM NEW.crl_uri THEN
		_uq := array_append(_uq,
			'crl_uri = ' || quote_nullable(NEW.crl_uri)
		);
	END IF;

	IF array_length(_uq, 1) > 0 THEN
		EXECUTE 'UPDATE x509_signed_certificate SET '
			|| array_to_string(_uq, ', ')
			|| ' WHERE x509_signed_certificate_id = '
			|| NEW.x509_cert_id;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.x509_signed_certificate SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  x509_signed_certificate_id = $1 RETURNING *'  USING OLD.x509_cert_id
			INTO crt;

		NEW.x509_cert_id = crt.x509_signed_certificate_id;
		NEW.friendly_name = crt.friendly_name;
		NEW.is_active = CASE WHEN crt.is_active = true THEN 'Y' WHEN crt.is_active = false THEN 'N' ELSE NULL END;
		NEW.is_certificate_authority = CASE WHEN crt.is_certificate_authority = true THEN 'Y' WHEN crt.is_certificate_authority = false THEN 'N' ELSE NULL END;
		NEW.signing_cert_id = crt.signing_cert_id;
		NEW.x509_ca_cert_serial_number = crt.x509_ca_cert_serial_number;
		NEW.public_key = crt.public_key;
		NEW.subject = crt.subject;
		NEW.subject_key_identifier = crt.subject_key_identifier;
		NEW.valid_from = crt.valid_from;
		NEW.valid_to = crt.valid_to;
		NEW.x509_revocation_date = crt.x509_revocation_date;
		NEW.x509_revocation_reason = crt.x509_revocation_reason;
		NEW.ocsp_uri = crt.ocsp_uri;
		NEW.crl_uri = crt.crl_uri;
		NEW.data_ins_user = crt.data_ins_user;
		NEW.data_ins_date = crt.data_ins_date;
		NEW.data_upd_user = crt.data_upd_user;
		NEW.data_upd_date = crt.data_upd_date;
	END IF;

	IF OLD.certificate_sign_req IS NOT NULL AND NEW.certificate_sign_req IS NULL THEN
		DELETE FROM jazzhands.certificate_signing_request
		WHERE certificate_signing_request_id = crt.certificate_signing_request_id;
	END IF;

	IF OLD.private_key IS NOT NULL AND NEW.private_key IS NULL THEN
		DELETE FROM jazzhands.private_key
		WHERE private_key_id = crt.private_key_id;
	END IF;

	RETURN NEW;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'function' AND object IN ('x509_certificate_upd');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc x509_certificate_upd failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy']);
--
-- Recreate the saved views in the base schema
--
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', type := 'view');
--
-- BEGIN: process_ancillary_schema(jazzhands_legacy)
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy']);
-- DONE: process_ancillary_schema(jazzhands_legacy)
--
-- BEGIN: Fix cache table entries.
--
-- removing old
-- adding new cache tables that are not there
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled 
	) SELECT 'jazzhands_cache' , 'ct_netblock_hier' , 'jazzhands_cache' , 'v_netblock_hier' , '1'  WHERE ('jazzhands_cache' , 'ct_netblock_hier' , 'jazzhands_cache' , 'v_netblock_hier' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled 
	) SELECT 'jazzhands_cache' , 'ct_device_components' , 'jazzhands_cache' , 'v_device_components' , '1'  WHERE ('jazzhands_cache' , 'ct_device_components' , 'jazzhands_cache' , 'v_device_components' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled 
	) SELECT 'jazzhands_cache' , 'ct_netblock_hier' , 'jazzhands_cache' , 'v_netblock_hier' , '1'  WHERE ('jazzhands_cache' , 'ct_netblock_hier' , 'jazzhands_cache' , 'v_netblock_hier' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled 
	) SELECT 'jazzhands_cache' , 'ct_account_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_account_collection_hier_from_ancestor' , '1'  WHERE ('jazzhands_cache' , 'ct_account_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_account_collection_hier_from_ancestor' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled 
	) SELECT 'jazzhands_cache' , 'ct_device_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_device_collection_hier_from_ancestor' , '1'  WHERE ('jazzhands_cache' , 'ct_device_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_device_collection_hier_from_ancestor' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled 
	) SELECT 'jazzhands_cache' , 'ct_netblock_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_netblock_collection_hier_from_ancestor' , '1'  WHERE ('jazzhands_cache' , 'ct_netblock_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_netblock_collection_hier_from_ancestor' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled 
	) SELECT 'jazzhands_cache' , 'ct_jazzhands_legacy_device_support' , 'jazzhands_cache' , 'v_jazzhands_legacy_device_support' , '1'  WHERE ('jazzhands_cache' , 'ct_jazzhands_legacy_device_support' , 'jazzhands_cache' , 'v_jazzhands_legacy_device_support' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
--
-- DONE: Fix cache table entries.
--


-- Clean Up
-- Dropping obsoleted sequences....


-- Dropping obsoleted jazzhands_audit sequences....


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
-- index
-- triggers
DROP TRIGGER IF EXISTS trig_account_change_realm_aca_realm ON account;
CREATE TRIGGER trig_account_change_realm_aca_realm BEFORE UPDATE OF account_realm_id ON jazzhands.account FOR EACH ROW EXECUTE PROCEDURE jazzhands.account_change_realm_aca_realm();
DROP TRIGGER IF EXISTS trig_add_account_automated_reporting_ac ON account;
CREATE TRIGGER trig_add_account_automated_reporting_ac AFTER INSERT OR UPDATE OF login, account_status ON jazzhands.account FOR EACH ROW EXECUTE PROCEDURE jazzhands.account_automated_reporting_ac();
DROP TRIGGER IF EXISTS trig_add_automated_ac_on_account ON account;
CREATE TRIGGER trig_add_automated_ac_on_account AFTER INSERT OR UPDATE OF account_type, account_role, account_status ON jazzhands.account FOR EACH ROW EXECUTE PROCEDURE jazzhands.automated_ac_on_account();
DROP TRIGGER IF EXISTS trig_rm_account_automated_reporting_ac ON account;
CREATE TRIGGER trig_rm_account_automated_reporting_ac BEFORE DELETE ON jazzhands.account FOR EACH ROW EXECUTE PROCEDURE jazzhands.account_automated_reporting_ac();
DROP TRIGGER IF EXISTS trig_rm_automated_ac_on_account ON account;
CREATE TRIGGER trig_rm_automated_ac_on_account BEFORE DELETE ON jazzhands.account FOR EACH ROW EXECUTE PROCEDURE jazzhands.automated_ac_on_account();
DROP TRIGGER IF EXISTS trig_userlog_account ON account;
CREATE TRIGGER trig_userlog_account BEFORE INSERT OR UPDATE ON jazzhands.account FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_account_enforce_is_enabled ON account;
CREATE TRIGGER trigger_account_enforce_is_enabled BEFORE INSERT OR UPDATE OF account_status, is_enabled ON jazzhands.account FOR EACH ROW EXECUTE PROCEDURE jazzhands.account_enforce_is_enabled();
DROP TRIGGER IF EXISTS trigger_account_status_per_row_after_hooks ON account;
CREATE TRIGGER trigger_account_status_per_row_after_hooks AFTER UPDATE OF account_status ON jazzhands.account FOR EACH ROW EXECUTE PROCEDURE jazzhands.account_status_per_row_after_hooks();
DROP TRIGGER IF EXISTS trigger_account_validate_login ON account;
CREATE TRIGGER trigger_account_validate_login BEFORE INSERT OR UPDATE OF login ON jazzhands.account FOR EACH ROW EXECUTE PROCEDURE jazzhands.account_validate_login();
DROP TRIGGER IF EXISTS trigger_audit_account ON account;
CREATE TRIGGER trigger_audit_account AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_account();
DROP TRIGGER IF EXISTS trigger_create_new_unix_account ON account;
CREATE TRIGGER trigger_create_new_unix_account AFTER INSERT ON jazzhands.account FOR EACH ROW EXECUTE PROCEDURE jazzhands.create_new_unix_account();
DROP TRIGGER IF EXISTS trigger_delete_peraccount_account_collection ON account;
CREATE TRIGGER trigger_delete_peraccount_account_collection BEFORE DELETE ON jazzhands.account FOR EACH ROW EXECUTE PROCEDURE jazzhands.delete_peraccount_account_collection();
DROP TRIGGER IF EXISTS trigger_update_peraccount_account_collection ON account;
CREATE TRIGGER trigger_update_peraccount_account_collection AFTER INSERT OR UPDATE ON jazzhands.account FOR EACH ROW EXECUTE PROCEDURE jazzhands.update_peraccount_account_collection();
DROP TRIGGER IF EXISTS trig_userlog_account_assigned_certificate ON account_assigned_certificate;
CREATE TRIGGER trig_userlog_account_assigned_certificate BEFORE INSERT OR UPDATE ON jazzhands.account_assigned_certificate FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_assigned_certificate ON account_assigned_certificate;
CREATE TRIGGER trigger_audit_account_assigned_certificate AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_assigned_certificate FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_account_assigned_certificate();
DROP TRIGGER IF EXISTS trig_userlog_account_authentication_log ON account_authentication_log;
CREATE TRIGGER trig_userlog_account_authentication_log BEFORE INSERT OR UPDATE ON jazzhands.account_authentication_log FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_authentication_log ON account_authentication_log;
CREATE TRIGGER trigger_audit_account_authentication_log AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_authentication_log FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_account_authentication_log();
DROP TRIGGER IF EXISTS aaa_account_collection_base_handler ON account_collection;
CREATE TRIGGER aaa_account_collection_base_handler AFTER INSERT OR DELETE OR UPDATE OF account_collection_id ON jazzhands.account_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.account_collection_base_handler();
DROP TRIGGER IF EXISTS trig_account_collection_realm ON account_collection;
CREATE TRIGGER trig_account_collection_realm AFTER UPDATE OF account_collection_type ON jazzhands.account_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.account_collection_realm();
DROP TRIGGER IF EXISTS trig_userlog_account_collection ON account_collection;
CREATE TRIGGER trig_userlog_account_collection BEFORE INSERT OR UPDATE ON jazzhands.account_collection FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_collection ON account_collection;
CREATE TRIGGER trigger_audit_account_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_account_collection();
DROP TRIGGER IF EXISTS trigger_validate_account_collection_type_change ON account_collection;
CREATE TRIGGER trigger_validate_account_collection_type_change BEFORE UPDATE OF account_collection_type ON jazzhands.account_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_account_collection_type_change();
DROP TRIGGER IF EXISTS trig_account_collection_account_realm ON account_collection_account;
CREATE TRIGGER trig_account_collection_account_realm AFTER INSERT OR UPDATE ON jazzhands.account_collection_account FOR EACH ROW EXECUTE PROCEDURE jazzhands.account_collection_account_realm();
DROP TRIGGER IF EXISTS trig_userlog_account_collection_account ON account_collection_account;
CREATE TRIGGER trig_userlog_account_collection_account BEFORE INSERT OR UPDATE ON jazzhands.account_collection_account FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_account_coll_member_relation_enforce ON account_collection_account;
CREATE CONSTRAINT TRIGGER trigger_account_coll_member_relation_enforce AFTER INSERT OR UPDATE ON jazzhands.account_collection_account DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.account_coll_member_relation_enforce();
DROP TRIGGER IF EXISTS trigger_account_collection_member_enforce ON account_collection_account;
CREATE CONSTRAINT TRIGGER trigger_account_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.account_collection_account DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.account_collection_member_enforce();
DROP TRIGGER IF EXISTS trigger_audit_account_collection_account ON account_collection_account;
CREATE TRIGGER trigger_audit_account_collection_account AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_collection_account FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_account_collection_account();
DROP TRIGGER IF EXISTS trigger_pgnotify_account_collection_account_token_changes ON account_collection_account;
CREATE TRIGGER trigger_pgnotify_account_collection_account_token_changes AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_collection_account FOR EACH ROW EXECUTE PROCEDURE jazzhands.pgnotify_account_collection_account_token_changes();
DROP TRIGGER IF EXISTS aaa_account_collection_root_handler ON account_collection_hier;
CREATE TRIGGER aaa_account_collection_root_handler AFTER INSERT OR DELETE OR UPDATE OF account_collection_id, child_account_collection_id ON jazzhands.account_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.account_collection_root_handler();
DROP TRIGGER IF EXISTS trig_account_collection_hier_realm ON account_collection_hier;
CREATE TRIGGER trig_account_collection_hier_realm AFTER INSERT OR UPDATE ON jazzhands.account_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands.account_collection_hier_realm();
DROP TRIGGER IF EXISTS trig_userlog_account_collection_hier ON account_collection_hier;
CREATE TRIGGER trig_userlog_account_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.account_collection_hier FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_account_collection_hier_enforce ON account_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_account_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.account_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.account_collection_hier_enforce();
DROP TRIGGER IF EXISTS trigger_audit_account_collection_hier ON account_collection_hier;
CREATE TRIGGER trigger_audit_account_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_account_collection_hier();
DROP TRIGGER IF EXISTS trigger_check_account_collection_hier_loop ON account_collection_hier;
CREATE TRIGGER trigger_check_account_collection_hier_loop AFTER INSERT OR UPDATE ON jazzhands.account_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands.check_account_colllection_hier_loop();
DROP TRIGGER IF EXISTS trig_userlog_account_collection_type_relation ON account_collection_type_relation;
CREATE TRIGGER trig_userlog_account_collection_type_relation BEFORE INSERT OR UPDATE ON jazzhands.account_collection_type_relation FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_collection_type_relation ON account_collection_type_relation;
CREATE TRIGGER trigger_audit_account_collection_type_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_collection_type_relation FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_account_collection_type_relation();
DROP TRIGGER IF EXISTS trig_userlog_account_password ON account_password;
CREATE TRIGGER trig_userlog_account_password BEFORE INSERT OR UPDATE ON jazzhands.account_password FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_password ON account_password;
CREATE TRIGGER trigger_audit_account_password AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_password FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_account_password();
DROP TRIGGER IF EXISTS trigger_pgnotify_account_password_changes ON account_password;
CREATE TRIGGER trigger_pgnotify_account_password_changes AFTER INSERT OR UPDATE ON jazzhands.account_password FOR EACH ROW EXECUTE PROCEDURE jazzhands.pgnotify_account_password_changes();
DROP TRIGGER IF EXISTS trigger_pull_password_account_realm_from_account ON account_password;
CREATE TRIGGER trigger_pull_password_account_realm_from_account BEFORE INSERT OR UPDATE OF account_id ON jazzhands.account_password FOR EACH ROW EXECUTE PROCEDURE jazzhands.pull_password_account_realm_from_account();
DROP TRIGGER IF EXISTS trigger_unrequire_password_change ON account_password;
CREATE TRIGGER trigger_unrequire_password_change BEFORE INSERT OR UPDATE OF password ON jazzhands.account_password FOR EACH ROW EXECUTE PROCEDURE jazzhands.unrequire_password_change();
DROP TRIGGER IF EXISTS trig_userlog_account_realm ON account_realm;
CREATE TRIGGER trig_userlog_account_realm BEFORE INSERT OR UPDATE ON jazzhands.account_realm FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_realm ON account_realm;
CREATE TRIGGER trigger_audit_account_realm AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_realm FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_account_realm();
DROP TRIGGER IF EXISTS trig_userlog_account_realm_account_collection_type ON account_realm_account_collection_type;
CREATE TRIGGER trig_userlog_account_realm_account_collection_type BEFORE INSERT OR UPDATE ON jazzhands.account_realm_account_collection_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_realm_account_collection_type ON account_realm_account_collection_type;
CREATE TRIGGER trigger_audit_account_realm_account_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_realm_account_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_account_realm_account_collection_type();
DROP TRIGGER IF EXISTS trig_userlog_account_realm_company ON account_realm_company;
CREATE TRIGGER trig_userlog_account_realm_company BEFORE INSERT OR UPDATE ON jazzhands.account_realm_company FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_realm_company ON account_realm_company;
CREATE TRIGGER trigger_audit_account_realm_company AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_realm_company FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_account_realm_company();
DROP TRIGGER IF EXISTS trig_userlog_account_realm_password_type ON account_realm_password_type;
CREATE TRIGGER trig_userlog_account_realm_password_type BEFORE INSERT OR UPDATE ON jazzhands.account_realm_password_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_realm_password_type ON account_realm_password_type;
CREATE TRIGGER trigger_audit_account_realm_password_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_realm_password_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_account_realm_password_type();
DROP TRIGGER IF EXISTS trig_userlog_account_ssh_key ON account_ssh_key;
CREATE TRIGGER trig_userlog_account_ssh_key BEFORE INSERT OR UPDATE ON jazzhands.account_ssh_key FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_ssh_key ON account_ssh_key;
CREATE TRIGGER trigger_audit_account_ssh_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_ssh_key FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_account_ssh_key();
DROP TRIGGER IF EXISTS trig_userlog_account_token ON account_token;
CREATE TRIGGER trig_userlog_account_token BEFORE INSERT OR UPDATE ON jazzhands.account_token FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_token ON account_token;
CREATE TRIGGER trigger_audit_account_token AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_token FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_account_token();
DROP TRIGGER IF EXISTS trigger_pgnotify_account_token_change ON account_token;
CREATE TRIGGER trigger_pgnotify_account_token_change AFTER INSERT OR UPDATE ON jazzhands.account_token FOR EACH ROW EXECUTE PROCEDURE jazzhands.pgnotify_account_token_change();
DROP TRIGGER IF EXISTS trig_userlog_account_unix_info ON account_unix_info;
CREATE TRIGGER trig_userlog_account_unix_info BEFORE INSERT OR UPDATE ON jazzhands.account_unix_info FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_unix_info ON account_unix_info;
CREATE TRIGGER trigger_audit_account_unix_info AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_unix_info FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_account_unix_info();
DROP TRIGGER IF EXISTS trig_userlog_appaal ON appaal;
CREATE TRIGGER trig_userlog_appaal BEFORE INSERT OR UPDATE ON jazzhands.appaal FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_appaal ON appaal;
CREATE TRIGGER trigger_audit_appaal AFTER INSERT OR DELETE OR UPDATE ON jazzhands.appaal FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_appaal();
DROP TRIGGER IF EXISTS trig_userlog_appaal_instance ON appaal_instance;
CREATE TRIGGER trig_userlog_appaal_instance BEFORE INSERT OR UPDATE ON jazzhands.appaal_instance FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_appaal_instance ON appaal_instance;
CREATE TRIGGER trigger_audit_appaal_instance AFTER INSERT OR DELETE OR UPDATE ON jazzhands.appaal_instance FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_appaal_instance();
DROP TRIGGER IF EXISTS trig_userlog_appaal_instance_device_collection ON appaal_instance_device_collection;
CREATE TRIGGER trig_userlog_appaal_instance_device_collection BEFORE INSERT OR UPDATE ON jazzhands.appaal_instance_device_collection FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_appaal_instance_device_collection ON appaal_instance_device_collection;
CREATE TRIGGER trigger_audit_appaal_instance_device_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.appaal_instance_device_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_appaal_instance_device_collection();
DROP TRIGGER IF EXISTS trig_userlog_appaal_instance_property ON appaal_instance_property;
CREATE TRIGGER trig_userlog_appaal_instance_property BEFORE INSERT OR UPDATE ON jazzhands.appaal_instance_property FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_appaal_instance_property ON appaal_instance_property;
CREATE TRIGGER trigger_audit_appaal_instance_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.appaal_instance_property FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_appaal_instance_property();
DROP TRIGGER IF EXISTS trig_userlog_approval_instance ON approval_instance;
CREATE TRIGGER trig_userlog_approval_instance BEFORE INSERT OR UPDATE ON jazzhands.approval_instance FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_approval_instance ON approval_instance;
CREATE TRIGGER trigger_audit_approval_instance AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_instance FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_approval_instance();
DROP TRIGGER IF EXISTS trig_userlog_approval_instance_item ON approval_instance_item;
CREATE TRIGGER trig_userlog_approval_instance_item BEFORE INSERT OR UPDATE ON jazzhands.approval_instance_item FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_approval_instance_item_approval_notify ON approval_instance_item;
CREATE TRIGGER trigger_approval_instance_item_approval_notify AFTER INSERT OR UPDATE OF is_approved ON jazzhands.approval_instance_item FOR EACH STATEMENT EXECUTE PROCEDURE jazzhands.approval_instance_item_approval_notify();
DROP TRIGGER IF EXISTS trigger_approval_instance_item_approved_immutable ON approval_instance_item;
CREATE TRIGGER trigger_approval_instance_item_approved_immutable BEFORE UPDATE OF is_approved ON jazzhands.approval_instance_item FOR EACH ROW EXECUTE PROCEDURE jazzhands.approval_instance_item_approved_immutable();
DROP TRIGGER IF EXISTS trigger_approval_instance_step_auto_complete ON approval_instance_item;
CREATE TRIGGER trigger_approval_instance_step_auto_complete AFTER INSERT OR UPDATE OF is_approved ON jazzhands.approval_instance_item FOR EACH ROW EXECUTE PROCEDURE jazzhands.approval_instance_step_auto_complete();
DROP TRIGGER IF EXISTS trigger_audit_approval_instance_item ON approval_instance_item;
CREATE TRIGGER trigger_audit_approval_instance_item AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_instance_item FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_approval_instance_item();
DROP TRIGGER IF EXISTS trig_userlog_approval_instance_link ON approval_instance_link;
CREATE TRIGGER trig_userlog_approval_instance_link BEFORE INSERT OR UPDATE ON jazzhands.approval_instance_link FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_approval_instance_link ON approval_instance_link;
CREATE TRIGGER trigger_audit_approval_instance_link AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_instance_link FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_approval_instance_link();
DROP TRIGGER IF EXISTS trig_userlog_approval_instance_step ON approval_instance_step;
CREATE TRIGGER trig_userlog_approval_instance_step BEFORE INSERT OR UPDATE ON jazzhands.approval_instance_step FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_approval_instance_step_completed_immutable ON approval_instance_step;
CREATE TRIGGER trigger_approval_instance_step_completed_immutable BEFORE UPDATE OF is_completed ON jazzhands.approval_instance_step FOR EACH ROW EXECUTE PROCEDURE jazzhands.approval_instance_step_completed_immutable();
DROP TRIGGER IF EXISTS trigger_approval_instance_step_resolve_instance ON approval_instance_step;
CREATE TRIGGER trigger_approval_instance_step_resolve_instance AFTER UPDATE OF is_completed ON jazzhands.approval_instance_step FOR EACH ROW EXECUTE PROCEDURE jazzhands.approval_instance_step_resolve_instance();
DROP TRIGGER IF EXISTS trigger_audit_approval_instance_step ON approval_instance_step;
CREATE TRIGGER trigger_audit_approval_instance_step AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_instance_step FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_approval_instance_step();
DROP TRIGGER IF EXISTS trig_userlog_approval_instance_step_notify ON approval_instance_step_notify;
CREATE TRIGGER trig_userlog_approval_instance_step_notify BEFORE INSERT OR UPDATE ON jazzhands.approval_instance_step_notify FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_approval_instance_step_notify ON approval_instance_step_notify;
CREATE TRIGGER trigger_audit_approval_instance_step_notify AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_instance_step_notify FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_approval_instance_step_notify();
DROP TRIGGER IF EXISTS trigger_legacy_approval_instance_step_notify_account ON approval_instance_step_notify;
CREATE TRIGGER trigger_legacy_approval_instance_step_notify_account BEFORE INSERT OR UPDATE OF account_id ON jazzhands.approval_instance_step_notify FOR EACH ROW EXECUTE PROCEDURE jazzhands.legacy_approval_instance_step_notify_account();
DROP TRIGGER IF EXISTS trig_userlog_approval_process ON approval_process;
CREATE TRIGGER trig_userlog_approval_process BEFORE INSERT OR UPDATE ON jazzhands.approval_process FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_approval_process ON approval_process;
CREATE TRIGGER trigger_audit_approval_process AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_process FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_approval_process();
DROP TRIGGER IF EXISTS trig_userlog_approval_process_chain ON approval_process_chain;
CREATE TRIGGER trig_userlog_approval_process_chain BEFORE INSERT OR UPDATE ON jazzhands.approval_process_chain FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_approval_process_chain ON approval_process_chain;
CREATE TRIGGER trigger_audit_approval_process_chain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_process_chain FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_approval_process_chain();
DROP TRIGGER IF EXISTS trig_userlog_asset ON asset;
CREATE TRIGGER trig_userlog_asset BEFORE INSERT OR UPDATE ON jazzhands.asset FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_asset ON asset;
CREATE TRIGGER trigger_audit_asset AFTER INSERT OR DELETE OR UPDATE ON jazzhands.asset FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_asset();
DROP TRIGGER IF EXISTS trigger_validate_asset_component_assignment ON asset;
CREATE CONSTRAINT TRIGGER trigger_validate_asset_component_assignment AFTER INSERT OR UPDATE OF component_id ON jazzhands.asset DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_asset_component_assignment();
DROP TRIGGER IF EXISTS trig_userlog_badge ON badge;
CREATE TRIGGER trig_userlog_badge BEFORE INSERT OR UPDATE ON jazzhands.badge FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_badge ON badge;
CREATE TRIGGER trigger_audit_badge AFTER INSERT OR DELETE OR UPDATE ON jazzhands.badge FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_badge();
DROP TRIGGER IF EXISTS trig_userlog_badge_type ON badge_type;
CREATE TRIGGER trig_userlog_badge_type BEFORE INSERT OR UPDATE ON jazzhands.badge_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_badge_type ON badge_type;
CREATE TRIGGER trigger_audit_badge_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.badge_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_badge_type();
DROP TRIGGER IF EXISTS trig_userlog_certificate_signing_request ON certificate_signing_request;
CREATE TRIGGER trig_userlog_certificate_signing_request BEFORE INSERT OR UPDATE ON jazzhands.certificate_signing_request FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_certificate_signing_request ON certificate_signing_request;
CREATE TRIGGER trigger_audit_certificate_signing_request AFTER INSERT OR DELETE OR UPDATE ON jazzhands.certificate_signing_request FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_certificate_signing_request();
DROP TRIGGER IF EXISTS trig_userlog_chassis_location ON chassis_location;
CREATE TRIGGER trig_userlog_chassis_location BEFORE INSERT OR UPDATE ON jazzhands.chassis_location FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_chassis_location ON chassis_location;
CREATE TRIGGER trigger_audit_chassis_location AFTER INSERT OR DELETE OR UPDATE ON jazzhands.chassis_location FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_chassis_location();
DROP TRIGGER IF EXISTS trig_userlog_circuit ON circuit;
CREATE TRIGGER trig_userlog_circuit BEFORE INSERT OR UPDATE ON jazzhands.circuit FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_circuit ON circuit;
CREATE TRIGGER trigger_audit_circuit AFTER INSERT OR DELETE OR UPDATE ON jazzhands.circuit FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_circuit();
DROP TRIGGER IF EXISTS trig_userlog_company ON company;
CREATE TRIGGER trig_userlog_company BEFORE INSERT OR UPDATE ON jazzhands.company FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_company ON company;
CREATE TRIGGER trigger_audit_company AFTER INSERT OR DELETE OR UPDATE ON jazzhands.company FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_company();
DROP TRIGGER IF EXISTS trigger_company_insert_function_nudge ON company;
CREATE TRIGGER trigger_company_insert_function_nudge BEFORE INSERT ON jazzhands.company FOR EACH ROW EXECUTE PROCEDURE jazzhands.company_insert_function_nudge();
DROP TRIGGER IF EXISTS trigger_delete_per_company_company_collection ON company;
CREATE TRIGGER trigger_delete_per_company_company_collection BEFORE DELETE ON jazzhands.company FOR EACH ROW EXECUTE PROCEDURE jazzhands.delete_per_company_company_collection();
DROP TRIGGER IF EXISTS trigger_update_per_company_company_collection ON company;
CREATE TRIGGER trigger_update_per_company_company_collection AFTER INSERT OR UPDATE ON jazzhands.company FOR EACH ROW EXECUTE PROCEDURE jazzhands.update_per_company_company_collection();
DROP TRIGGER IF EXISTS trig_userlog_company_collection ON company_collection;
CREATE TRIGGER trig_userlog_company_collection BEFORE INSERT OR UPDATE ON jazzhands.company_collection FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_company_collection ON company_collection;
CREATE TRIGGER trigger_audit_company_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.company_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_company_collection();
DROP TRIGGER IF EXISTS trigger_manip_company_collection_bytype_del ON company_collection;
CREATE TRIGGER trigger_manip_company_collection_bytype_del BEFORE DELETE ON jazzhands.company_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_company_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_company_collection_bytype_insup ON company_collection;
CREATE TRIGGER trigger_manip_company_collection_bytype_insup AFTER INSERT OR UPDATE OF company_collection_type ON jazzhands.company_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_company_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_company_collection_type_change ON company_collection;
CREATE TRIGGER trigger_validate_company_collection_type_change BEFORE UPDATE OF company_collection_type ON jazzhands.company_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_company_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_company_collection_company ON company_collection_company;
CREATE TRIGGER trig_userlog_company_collection_company BEFORE INSERT OR UPDATE ON jazzhands.company_collection_company FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_company_collection_company ON company_collection_company;
CREATE TRIGGER trigger_audit_company_collection_company AFTER INSERT OR DELETE OR UPDATE ON jazzhands.company_collection_company FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_company_collection_company();
DROP TRIGGER IF EXISTS trigger_company_collection_member_enforce ON company_collection_company;
CREATE CONSTRAINT TRIGGER trigger_company_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.company_collection_company DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.company_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_company_collection_hier ON company_collection_hier;
CREATE TRIGGER trig_userlog_company_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.company_collection_hier FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_company_collection_hier ON company_collection_hier;
CREATE TRIGGER trigger_audit_company_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.company_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_company_collection_hier();
DROP TRIGGER IF EXISTS trigger_company_collection_hier_enforce ON company_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_company_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.company_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.company_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_company_type ON company_type;
CREATE TRIGGER trig_userlog_company_type BEFORE INSERT OR UPDATE ON jazzhands.company_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_company_type ON company_type;
CREATE TRIGGER trigger_audit_company_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.company_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_company_type();
DROP TRIGGER IF EXISTS aaa_tg_cache_component_parent_handler ON component;
CREATE TRIGGER aaa_tg_cache_component_parent_handler AFTER INSERT OR DELETE OR UPDATE OF parent_slot_id ON jazzhands.component FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.cache_component_parent_handler();
DROP TRIGGER IF EXISTS aab_tg_cache_device_component_component_handler ON component;
CREATE TRIGGER aab_tg_cache_device_component_component_handler AFTER INSERT OR DELETE OR UPDATE OF parent_slot_id ON jazzhands.component FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.cache_device_component_component_handler();
DROP TRIGGER IF EXISTS trig_userlog_component ON component;
CREATE TRIGGER trig_userlog_component BEFORE INSERT OR UPDATE ON jazzhands.component FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_component ON component;
CREATE TRIGGER trigger_audit_component AFTER INSERT OR DELETE OR UPDATE ON jazzhands.component FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_component();
DROP TRIGGER IF EXISTS trigger_create_component_template_slots ON component;
CREATE TRIGGER trigger_create_component_template_slots AFTER INSERT OR UPDATE OF component_type_id ON jazzhands.component FOR EACH ROW EXECUTE PROCEDURE jazzhands.create_component_slots_by_trigger();
DROP TRIGGER IF EXISTS trigger_validate_component_parent_slot_id ON component;
CREATE CONSTRAINT TRIGGER trigger_validate_component_parent_slot_id AFTER INSERT OR UPDATE OF parent_slot_id, component_type_id ON jazzhands.component DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_component_parent_slot_id();
DROP TRIGGER IF EXISTS trigger_validate_component_rack_location ON component;
CREATE CONSTRAINT TRIGGER trigger_validate_component_rack_location AFTER INSERT OR UPDATE OF rack_location_id ON jazzhands.component DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_component_rack_location();
DROP TRIGGER IF EXISTS trigger_zzz_generate_slot_names ON component;
CREATE TRIGGER trigger_zzz_generate_slot_names AFTER INSERT OR UPDATE OF parent_slot_id ON jazzhands.component FOR EACH ROW EXECUTE PROCEDURE jazzhands.set_slot_names_by_trigger();
DROP TRIGGER IF EXISTS trig_userlog_component_property ON component_property;
CREATE TRIGGER trig_userlog_component_property BEFORE INSERT OR UPDATE ON jazzhands.component_property FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_component_property ON component_property;
CREATE TRIGGER trigger_audit_component_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.component_property FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_component_property();
DROP TRIGGER IF EXISTS trigger_validate_component_property ON component_property;
CREATE CONSTRAINT TRIGGER trigger_validate_component_property AFTER INSERT OR UPDATE ON jazzhands.component_property DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_component_property();
DROP TRIGGER IF EXISTS trig_userlog_component_type ON component_type;
CREATE TRIGGER trig_userlog_component_type BEFORE INSERT OR UPDATE ON jazzhands.component_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_component_type ON component_type;
CREATE TRIGGER trigger_audit_component_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.component_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_component_type();
DROP TRIGGER IF EXISTS trig_userlog_component_type_component_function ON component_type_component_function;
CREATE TRIGGER trig_userlog_component_type_component_function BEFORE INSERT OR UPDATE ON jazzhands.component_type_component_function FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_component_type_component_function ON component_type_component_function;
CREATE TRIGGER trigger_audit_component_type_component_function AFTER INSERT OR DELETE OR UPDATE ON jazzhands.component_type_component_function FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_component_type_component_function();
DROP TRIGGER IF EXISTS trig_userlog_component_type_slot_template ON component_type_slot_template;
CREATE TRIGGER trig_userlog_component_type_slot_template BEFORE INSERT OR UPDATE ON jazzhands.component_type_slot_template FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_component_type_slot_template ON component_type_slot_template;
CREATE TRIGGER trigger_audit_component_type_slot_template AFTER INSERT OR DELETE OR UPDATE ON jazzhands.component_type_slot_template FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_component_type_slot_template();
DROP TRIGGER IF EXISTS trig_userlog_contract ON contract;
CREATE TRIGGER trig_userlog_contract BEFORE INSERT OR UPDATE ON jazzhands.contract FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_contract ON contract;
CREATE TRIGGER trigger_audit_contract AFTER INSERT OR DELETE OR UPDATE ON jazzhands.contract FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_contract();
DROP TRIGGER IF EXISTS trig_userlog_contract_type ON contract_type;
CREATE TRIGGER trig_userlog_contract_type BEFORE INSERT OR UPDATE ON jazzhands.contract_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_contract_type ON contract_type;
CREATE TRIGGER trigger_audit_contract_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.contract_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_contract_type();
DROP TRIGGER IF EXISTS trig_userlog_department ON department;
CREATE TRIGGER trig_userlog_department BEFORE INSERT OR UPDATE ON jazzhands.department FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_department ON department;
CREATE TRIGGER trigger_audit_department AFTER INSERT OR DELETE OR UPDATE ON jazzhands.department FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_department();
DROP TRIGGER IF EXISTS tg_cache_device_component_device_handler ON device;
CREATE TRIGGER tg_cache_device_component_device_handler AFTER INSERT OR DELETE OR UPDATE OF component_id ON jazzhands.device FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.cache_device_component_device_handler();
DROP TRIGGER IF EXISTS trig_userlog_device ON device;
CREATE TRIGGER trig_userlog_device BEFORE INSERT OR UPDATE ON jazzhands.device FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device ON device;
CREATE TRIGGER trigger_audit_device AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_device();
DROP TRIGGER IF EXISTS trigger_create_device_component ON device;
CREATE TRIGGER trigger_create_device_component BEFORE INSERT OR UPDATE OF device_type_id ON jazzhands.device FOR EACH ROW EXECUTE PROCEDURE jazzhands.create_device_component_by_trigger();
DROP TRIGGER IF EXISTS trigger_del_jazzhands_legacy_support ON device;
CREATE TRIGGER trigger_del_jazzhands_legacy_support BEFORE DELETE ON jazzhands.device FOR EACH ROW EXECUTE PROCEDURE jazzhands.del_jazzhands_legacy_support();
DROP TRIGGER IF EXISTS trigger_delete_per_device_device_collection ON device;
CREATE TRIGGER trigger_delete_per_device_device_collection BEFORE DELETE ON jazzhands.device FOR EACH ROW EXECUTE PROCEDURE jazzhands.delete_per_device_device_collection();
DROP TRIGGER IF EXISTS trigger_device_one_location_validate ON device;
CREATE TRIGGER trigger_device_one_location_validate BEFORE INSERT OR UPDATE ON jazzhands.device FOR EACH ROW EXECUTE PROCEDURE jazzhands.device_one_location_validate();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_device_del ON device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_device_del BEFORE DELETE ON jazzhands.device FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.jazzhands_legacy_device_columns_device_del();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_device_ins ON device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_device_ins AFTER INSERT ON jazzhands.device FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.jazzhands_legacy_device_columns_device_ins();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_device_upd ON device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_device_upd AFTER UPDATE ON jazzhands.device FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.jazzhands_legacy_device_columns_device_upd();
DROP TRIGGER IF EXISTS trigger_update_per_device_device_collection ON device;
CREATE TRIGGER trigger_update_per_device_device_collection AFTER INSERT OR UPDATE ON jazzhands.device FOR EACH ROW EXECUTE PROCEDURE jazzhands.update_per_device_device_collection();
DROP TRIGGER IF EXISTS trigger_validate_device_component_assignment ON device;
CREATE CONSTRAINT TRIGGER trigger_validate_device_component_assignment AFTER INSERT OR UPDATE OF device_type_id, component_id ON jazzhands.device DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_device_component_assignment();
DROP TRIGGER IF EXISTS aaa_device_collection_base_handler ON device_collection;
CREATE TRIGGER aaa_device_collection_base_handler AFTER INSERT OR DELETE OR UPDATE OF device_collection_id ON jazzhands.device_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.device_collection_base_handler();
DROP TRIGGER IF EXISTS trig_userlog_device_collection ON device_collection;
CREATE TRIGGER trig_userlog_device_collection BEFORE INSERT OR UPDATE ON jazzhands.device_collection FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_collection ON device_collection;
CREATE TRIGGER trigger_audit_device_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_device_collection();
DROP TRIGGER IF EXISTS trigger_manip_device_collection_bytype_del ON device_collection;
CREATE TRIGGER trigger_manip_device_collection_bytype_del BEFORE DELETE ON jazzhands.device_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_device_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_device_collection_bytype_insup ON device_collection;
CREATE TRIGGER trigger_manip_device_collection_bytype_insup AFTER INSERT OR UPDATE OF device_collection_type ON jazzhands.device_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_device_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_device_collection_type_change ON device_collection;
CREATE TRIGGER trigger_validate_device_collection_type_change BEFORE UPDATE OF device_collection_type ON jazzhands.device_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_device_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_device_collection_assigned_certificate ON device_collection_assigned_certificate;
CREATE TRIGGER trig_userlog_device_collection_assigned_certificate BEFORE INSERT OR UPDATE ON jazzhands.device_collection_assigned_certificate FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_collection_assigned_certificate ON device_collection_assigned_certificate;
CREATE TRIGGER trigger_audit_device_collection_assigned_certificate AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_assigned_certificate FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_device_collection_assigned_certificate();
DROP TRIGGER IF EXISTS trig_userlog_device_collection_device ON device_collection_device;
CREATE TRIGGER trig_userlog_device_collection_device BEFORE INSERT OR UPDATE ON jazzhands.device_collection_device FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_collection_device ON device_collection_device;
CREATE TRIGGER trigger_audit_device_collection_device AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_device FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_device_collection_device();
DROP TRIGGER IF EXISTS trigger_device_collection_member_enforce ON device_collection_device;
CREATE CONSTRAINT TRIGGER trigger_device_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.device_collection_device DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.device_collection_member_enforce();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_dcd_del ON device_collection_device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_dcd_del BEFORE DELETE ON jazzhands.device_collection_device FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.jazzhands_legacy_device_columns_dcd_del();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_dcd_ins ON device_collection_device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_dcd_ins AFTER INSERT ON jazzhands.device_collection_device FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.jazzhands_legacy_device_columns_dcd_ins();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_dcd_upd ON device_collection_device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_dcd_upd AFTER UPDATE ON jazzhands.device_collection_device FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.jazzhands_legacy_device_columns_dcd_upd();
DROP TRIGGER IF EXISTS trigger_member_device_collection_after_hooks ON device_collection_device;
CREATE TRIGGER trigger_member_device_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_device FOR EACH STATEMENT EXECUTE PROCEDURE jazzhands.device_collection_after_hooks();
DROP TRIGGER IF EXISTS aaa_device_collection_root_handler ON device_collection_hier;
CREATE TRIGGER aaa_device_collection_root_handler AFTER INSERT OR DELETE OR UPDATE OF device_collection_id, child_device_collection_id ON jazzhands.device_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.device_collection_root_handler();
DROP TRIGGER IF EXISTS trig_userlog_device_collection_hier ON device_collection_hier;
CREATE TRIGGER trig_userlog_device_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.device_collection_hier FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_collection_hier ON device_collection_hier;
CREATE TRIGGER trigger_audit_device_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_device_collection_hier();
DROP TRIGGER IF EXISTS trigger_check_device_collection_hier_loop ON device_collection_hier;
CREATE TRIGGER trigger_check_device_collection_hier_loop AFTER INSERT OR UPDATE ON jazzhands.device_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands.check_device_colllection_hier_loop();
DROP TRIGGER IF EXISTS trigger_device_collection_hier_enforce ON device_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_device_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.device_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.device_collection_hier_enforce();
DROP TRIGGER IF EXISTS trigger_hier_device_collection_after_hooks ON device_collection_hier;
CREATE TRIGGER trigger_hier_device_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_hier FOR EACH STATEMENT EXECUTE PROCEDURE jazzhands.device_collection_after_hooks();
DROP TRIGGER IF EXISTS trig_userlog_device_collection_ssh_key ON device_collection_ssh_key;
CREATE TRIGGER trig_userlog_device_collection_ssh_key BEFORE INSERT OR UPDATE ON jazzhands.device_collection_ssh_key FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_collection_ssh_key ON device_collection_ssh_key;
CREATE TRIGGER trigger_audit_device_collection_ssh_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_ssh_key FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_device_collection_ssh_key();
DROP TRIGGER IF EXISTS trig_userlog_device_encapsulation_domain ON device_encapsulation_domain;
CREATE TRIGGER trig_userlog_device_encapsulation_domain BEFORE INSERT OR UPDATE ON jazzhands.device_encapsulation_domain FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_encapsulation_domain ON device_encapsulation_domain;
CREATE TRIGGER trigger_audit_device_encapsulation_domain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_encapsulation_domain FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_device_encapsulation_domain();
DROP TRIGGER IF EXISTS trig_userlog_device_layer2_network ON device_layer2_network;
CREATE TRIGGER trig_userlog_device_layer2_network BEFORE INSERT OR UPDATE ON jazzhands.device_layer2_network FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_layer2_network ON device_layer2_network;
CREATE TRIGGER trigger_audit_device_layer2_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_layer2_network FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_device_layer2_network();
DROP TRIGGER IF EXISTS trig_userlog_device_management_controller ON device_management_controller;
CREATE TRIGGER trig_userlog_device_management_controller BEFORE INSERT OR UPDATE ON jazzhands.device_management_controller FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_management_controller ON device_management_controller;
CREATE TRIGGER trigger_audit_device_management_controller AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_management_controller FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_device_management_controller();
DROP TRIGGER IF EXISTS trig_userlog_device_note ON device_note;
CREATE TRIGGER trig_userlog_device_note BEFORE INSERT OR UPDATE ON jazzhands.device_note FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_note ON device_note;
CREATE TRIGGER trigger_audit_device_note AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_note FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_device_note();
DROP TRIGGER IF EXISTS trig_userlog_device_ssh_key ON device_ssh_key;
CREATE TRIGGER trig_userlog_device_ssh_key BEFORE INSERT OR UPDATE ON jazzhands.device_ssh_key FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_ssh_key ON device_ssh_key;
CREATE TRIGGER trigger_audit_device_ssh_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_ssh_key FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_device_ssh_key();
DROP TRIGGER IF EXISTS trig_userlog_device_ticket ON device_ticket;
CREATE TRIGGER trig_userlog_device_ticket BEFORE INSERT OR UPDATE ON jazzhands.device_ticket FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_ticket ON device_ticket;
CREATE TRIGGER trigger_audit_device_ticket AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_ticket FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_device_ticket();
DROP TRIGGER IF EXISTS trig_userlog_device_type ON device_type;
CREATE TRIGGER trig_userlog_device_type BEFORE INSERT OR UPDATE ON jazzhands.device_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_type ON device_type;
CREATE TRIGGER trigger_audit_device_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_device_type();
DROP TRIGGER IF EXISTS trigger_device_type_chassis_check ON device_type;
CREATE TRIGGER trigger_device_type_chassis_check BEFORE UPDATE OF is_chassis ON jazzhands.device_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.device_type_chassis_check();
DROP TRIGGER IF EXISTS trigger_device_type_model_to_name ON device_type;
CREATE TRIGGER trigger_device_type_model_to_name BEFORE INSERT OR UPDATE OF device_type_name, model ON jazzhands.device_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.device_type_model_to_name();
DROP TRIGGER IF EXISTS trig_userlog_device_type_module ON device_type_module;
CREATE TRIGGER trig_userlog_device_type_module BEFORE INSERT OR UPDATE ON jazzhands.device_type_module FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_type_module ON device_type_module;
CREATE TRIGGER trigger_audit_device_type_module AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_type_module FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_device_type_module();
DROP TRIGGER IF EXISTS trigger_device_type_module_chassis_check ON device_type_module;
CREATE TRIGGER trigger_device_type_module_chassis_check BEFORE INSERT OR UPDATE OF device_type_id ON jazzhands.device_type_module FOR EACH ROW EXECUTE PROCEDURE jazzhands.device_type_module_chassis_check();
DROP TRIGGER IF EXISTS trigger_device_type_module_sanity_set ON device_type_module;
CREATE TRIGGER trigger_device_type_module_sanity_set BEFORE INSERT OR UPDATE ON jazzhands.device_type_module FOR EACH ROW EXECUTE PROCEDURE jazzhands.device_type_module_sanity_set();
DROP TRIGGER IF EXISTS trig_userlog_device_type_module_device_type ON device_type_module_device_type;
CREATE TRIGGER trig_userlog_device_type_module_device_type BEFORE INSERT OR UPDATE ON jazzhands.device_type_module_device_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_type_module_device_type ON device_type_module_device_type;
CREATE TRIGGER trigger_audit_device_type_module_device_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_type_module_device_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_device_type_module_device_type();
DROP TRIGGER IF EXISTS trig_userlog_dns_change_record ON dns_change_record;
CREATE TRIGGER trig_userlog_dns_change_record BEFORE INSERT OR UPDATE ON jazzhands.dns_change_record FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_change_record ON dns_change_record;
CREATE TRIGGER trigger_audit_dns_change_record AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_change_record FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_dns_change_record();
DROP TRIGGER IF EXISTS trigger_dns_change_record_pgnotify ON dns_change_record;
CREATE TRIGGER trigger_dns_change_record_pgnotify AFTER INSERT OR UPDATE ON jazzhands.dns_change_record FOR EACH STATEMENT EXECUTE PROCEDURE jazzhands.dns_change_record_pgnotify();
DROP TRIGGER IF EXISTS trig_userlog_dns_domain ON dns_domain;
CREATE TRIGGER trig_userlog_dns_domain BEFORE INSERT OR UPDATE ON jazzhands.dns_domain FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_domain ON dns_domain;
CREATE TRIGGER trigger_audit_dns_domain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_domain FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_dns_domain();
DROP TRIGGER IF EXISTS trigger_dns_domain_trigger_change ON dns_domain;
CREATE TRIGGER trigger_dns_domain_trigger_change AFTER INSERT OR UPDATE OF dns_domain_name ON jazzhands.dns_domain FOR EACH ROW EXECUTE PROCEDURE jazzhands.dns_domain_trigger_change();
DROP TRIGGER IF EXISTS trig_userlog_dns_domain_collection ON dns_domain_collection;
CREATE TRIGGER trig_userlog_dns_domain_collection BEFORE INSERT OR UPDATE ON jazzhands.dns_domain_collection FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_domain_collection ON dns_domain_collection;
CREATE TRIGGER trigger_audit_dns_domain_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_domain_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_dns_domain_collection();
DROP TRIGGER IF EXISTS trigger_manip_dns_domain_collection_bytype_del ON dns_domain_collection;
CREATE TRIGGER trigger_manip_dns_domain_collection_bytype_del BEFORE DELETE ON jazzhands.dns_domain_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_dns_domain_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_dns_domain_collection_bytype_insup ON dns_domain_collection;
CREATE TRIGGER trigger_manip_dns_domain_collection_bytype_insup AFTER INSERT OR UPDATE OF dns_domain_collection_type ON jazzhands.dns_domain_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_dns_domain_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_dns_domain_collection_type_change ON dns_domain_collection;
CREATE TRIGGER trigger_validate_dns_domain_collection_type_change BEFORE UPDATE OF dns_domain_collection_type ON jazzhands.dns_domain_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_dns_domain_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_dns_domain_collection_dns_domain ON dns_domain_collection_dns_domain;
CREATE TRIGGER trig_userlog_dns_domain_collection_dns_domain BEFORE INSERT OR UPDATE ON jazzhands.dns_domain_collection_dns_domain FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_domain_collection_dns_domain ON dns_domain_collection_dns_domain;
CREATE TRIGGER trigger_audit_dns_domain_collection_dns_domain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_domain_collection_dns_domain FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_dns_domain_collection_dns_domain();
DROP TRIGGER IF EXISTS trigger_dns_domain_collection_member_enforce ON dns_domain_collection_dns_domain;
CREATE CONSTRAINT TRIGGER trigger_dns_domain_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.dns_domain_collection_dns_domain DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.dns_domain_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_dns_domain_collection_hier ON dns_domain_collection_hier;
CREATE TRIGGER trig_userlog_dns_domain_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.dns_domain_collection_hier FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_domain_collection_hier ON dns_domain_collection_hier;
CREATE TRIGGER trigger_audit_dns_domain_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_domain_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_dns_domain_collection_hier();
DROP TRIGGER IF EXISTS trigger_dns_domain_collection_hier_enforce ON dns_domain_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_dns_domain_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.dns_domain_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.dns_domain_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_dns_domain_ip_universe ON dns_domain_ip_universe;
CREATE TRIGGER trig_userlog_dns_domain_ip_universe BEFORE INSERT OR UPDATE ON jazzhands.dns_domain_ip_universe FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_domain_ip_universe ON dns_domain_ip_universe;
CREATE TRIGGER trigger_audit_dns_domain_ip_universe AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_domain_ip_universe FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_dns_domain_ip_universe();
DROP TRIGGER IF EXISTS trigger_dns_domain_ip_universe_can_generate ON dns_domain_ip_universe;
CREATE TRIGGER trigger_dns_domain_ip_universe_can_generate AFTER INSERT OR UPDATE OF should_generate ON jazzhands.dns_domain_ip_universe FOR EACH ROW EXECUTE PROCEDURE jazzhands.dns_domain_ip_universe_can_generate();
DROP TRIGGER IF EXISTS trigger_dns_domain_ip_universe_trigger_change ON dns_domain_ip_universe;
CREATE TRIGGER trigger_dns_domain_ip_universe_trigger_change AFTER INSERT OR UPDATE OF soa_class, soa_ttl, soa_serial, soa_refresh, soa_retry, soa_expire, soa_minimum, soa_mname, soa_rname, should_generate ON jazzhands.dns_domain_ip_universe FOR EACH ROW EXECUTE PROCEDURE jazzhands.dns_domain_ip_universe_trigger_change();
DROP TRIGGER IF EXISTS trigger_dns_domain_ip_universe_trigger_del ON dns_domain_ip_universe;
CREATE TRIGGER trigger_dns_domain_ip_universe_trigger_del BEFORE DELETE ON jazzhands.dns_domain_ip_universe FOR EACH ROW EXECUTE PROCEDURE jazzhands.dns_domain_ip_universe_trigger_del();
DROP TRIGGER IF EXISTS trig_userlog_dns_record ON dns_record;
CREATE TRIGGER trig_userlog_dns_record BEFORE INSERT OR UPDATE ON jazzhands.dns_record FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_record ON dns_record;
CREATE TRIGGER trigger_audit_dns_record AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_record FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_dns_record();
DROP TRIGGER IF EXISTS trigger_check_ip_universe_dns_record ON dns_record;
CREATE CONSTRAINT TRIGGER trigger_check_ip_universe_dns_record AFTER INSERT OR UPDATE OF dns_record_id, ip_universe_id ON jazzhands.dns_record DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.check_ip_universe_dns_record();
DROP TRIGGER IF EXISTS trigger_dns_a_rec_validation ON dns_record;
CREATE TRIGGER trigger_dns_a_rec_validation BEFORE INSERT OR UPDATE ON jazzhands.dns_record FOR EACH ROW EXECUTE PROCEDURE jazzhands.dns_a_rec_validation();
DROP TRIGGER IF EXISTS trigger_dns_non_a_rec_validation ON dns_record;
CREATE TRIGGER trigger_dns_non_a_rec_validation BEFORE INSERT OR UPDATE ON jazzhands.dns_record FOR EACH ROW EXECUTE PROCEDURE jazzhands.dns_non_a_rec_validation();
DROP TRIGGER IF EXISTS trigger_dns_rec_prevent_dups ON dns_record;
CREATE CONSTRAINT TRIGGER trigger_dns_rec_prevent_dups AFTER INSERT OR UPDATE ON jazzhands.dns_record NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.dns_rec_prevent_dups();
DROP TRIGGER IF EXISTS trigger_dns_record_check_name ON dns_record;
CREATE TRIGGER trigger_dns_record_check_name BEFORE INSERT OR UPDATE OF dns_name, should_generate_ptr ON jazzhands.dns_record FOR EACH ROW EXECUTE PROCEDURE jazzhands.dns_record_check_name();
DROP TRIGGER IF EXISTS trigger_dns_record_cname_checker ON dns_record;
CREATE CONSTRAINT TRIGGER trigger_dns_record_cname_checker AFTER INSERT OR UPDATE OF dns_class, dns_type, dns_name, dns_domain_id, is_enabled ON jazzhands.dns_record NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.dns_record_cname_checker();
DROP TRIGGER IF EXISTS trigger_dns_record_enabled_check ON dns_record;
CREATE TRIGGER trigger_dns_record_enabled_check BEFORE INSERT OR UPDATE OF is_enabled ON jazzhands.dns_record FOR EACH ROW EXECUTE PROCEDURE jazzhands.dns_record_enabled_check();
DROP TRIGGER IF EXISTS trigger_dns_record_update_nontime ON dns_record;
CREATE TRIGGER trigger_dns_record_update_nontime AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_record FOR EACH ROW EXECUTE PROCEDURE jazzhands.dns_record_update_nontime();
DROP TRIGGER IF EXISTS trig_userlog_dns_record_relation ON dns_record_relation;
CREATE TRIGGER trig_userlog_dns_record_relation BEFORE INSERT OR UPDATE ON jazzhands.dns_record_relation FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_record_relation ON dns_record_relation;
CREATE TRIGGER trigger_audit_dns_record_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_record_relation FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_dns_record_relation();
DROP TRIGGER IF EXISTS trig_userlog_encapsulation_domain ON encapsulation_domain;
CREATE TRIGGER trig_userlog_encapsulation_domain BEFORE INSERT OR UPDATE ON jazzhands.encapsulation_domain FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_encapsulation_domain ON encapsulation_domain;
CREATE TRIGGER trigger_audit_encapsulation_domain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.encapsulation_domain FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_encapsulation_domain();
DROP TRIGGER IF EXISTS trig_userlog_encapsulation_range ON encapsulation_range;
CREATE TRIGGER trig_userlog_encapsulation_range BEFORE INSERT OR UPDATE ON jazzhands.encapsulation_range FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_encapsulation_range ON encapsulation_range;
CREATE TRIGGER trigger_audit_encapsulation_range AFTER INSERT OR DELETE OR UPDATE ON jazzhands.encapsulation_range FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_encapsulation_range();
DROP TRIGGER IF EXISTS trig_userlog_encryption_key ON encryption_key;
CREATE TRIGGER trig_userlog_encryption_key BEFORE INSERT OR UPDATE ON jazzhands.encryption_key FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_encryption_key ON encryption_key;
CREATE TRIGGER trigger_audit_encryption_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.encryption_key FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_encryption_key();
DROP TRIGGER IF EXISTS trig_userlog_inter_component_connection ON inter_component_connection;
CREATE TRIGGER trig_userlog_inter_component_connection BEFORE INSERT OR UPDATE ON jazzhands.inter_component_connection FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_inter_component_connection ON inter_component_connection;
CREATE TRIGGER trigger_audit_inter_component_connection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.inter_component_connection FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_inter_component_connection();
DROP TRIGGER IF EXISTS trigger_validate_inter_component_connection ON inter_component_connection;
CREATE CONSTRAINT TRIGGER trigger_validate_inter_component_connection AFTER INSERT OR UPDATE ON jazzhands.inter_component_connection DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_inter_component_connection();
DROP TRIGGER IF EXISTS trig_userlog_ip_universe ON ip_universe;
CREATE TRIGGER trig_userlog_ip_universe BEFORE INSERT OR UPDATE ON jazzhands.ip_universe FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_ip_universe ON ip_universe;
CREATE TRIGGER trigger_audit_ip_universe AFTER INSERT OR DELETE OR UPDATE ON jazzhands.ip_universe FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_ip_universe();
DROP TRIGGER IF EXISTS trig_userlog_ip_universe_visibility ON ip_universe_visibility;
CREATE TRIGGER trig_userlog_ip_universe_visibility BEFORE INSERT OR UPDATE ON jazzhands.ip_universe_visibility FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_ip_universe_visibility ON ip_universe_visibility;
CREATE TRIGGER trigger_audit_ip_universe_visibility AFTER INSERT OR DELETE OR UPDATE ON jazzhands.ip_universe_visibility FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_ip_universe_visibility();
DROP TRIGGER IF EXISTS trig_userlog_kerberos_realm ON kerberos_realm;
CREATE TRIGGER trig_userlog_kerberos_realm BEFORE INSERT OR UPDATE ON jazzhands.kerberos_realm FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_kerberos_realm ON kerberos_realm;
CREATE TRIGGER trigger_audit_kerberos_realm AFTER INSERT OR DELETE OR UPDATE ON jazzhands.kerberos_realm FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_kerberos_realm();
DROP TRIGGER IF EXISTS trig_userlog_klogin ON klogin;
CREATE TRIGGER trig_userlog_klogin BEFORE INSERT OR UPDATE ON jazzhands.klogin FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_klogin ON klogin;
CREATE TRIGGER trigger_audit_klogin AFTER INSERT OR DELETE OR UPDATE ON jazzhands.klogin FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_klogin();
DROP TRIGGER IF EXISTS trig_userlog_klogin_mclass ON klogin_mclass;
CREATE TRIGGER trig_userlog_klogin_mclass BEFORE INSERT OR UPDATE ON jazzhands.klogin_mclass FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_klogin_mclass ON klogin_mclass;
CREATE TRIGGER trigger_audit_klogin_mclass AFTER INSERT OR DELETE OR UPDATE ON jazzhands.klogin_mclass FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_klogin_mclass();
DROP TRIGGER IF EXISTS trig_userlog_layer2_connection ON layer2_connection;
CREATE TRIGGER trig_userlog_layer2_connection BEFORE INSERT OR UPDATE ON jazzhands.layer2_connection FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_connection ON layer2_connection;
CREATE TRIGGER trigger_audit_layer2_connection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_connection FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_layer2_connection();
DROP TRIGGER IF EXISTS trig_userlog_layer2_connection_layer2_network ON layer2_connection_layer2_network;
CREATE TRIGGER trig_userlog_layer2_connection_layer2_network BEFORE INSERT OR UPDATE ON jazzhands.layer2_connection_layer2_network FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_connection_layer2_network ON layer2_connection_layer2_network;
CREATE TRIGGER trigger_audit_layer2_connection_layer2_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_connection_layer2_network FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_layer2_connection_layer2_network();
DROP TRIGGER IF EXISTS trig_userlog_layer2_network ON layer2_network;
CREATE TRIGGER trig_userlog_layer2_network BEFORE INSERT OR UPDATE ON jazzhands.layer2_network FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_network ON layer2_network;
CREATE TRIGGER trigger_audit_layer2_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_layer2_network();
DROP TRIGGER IF EXISTS layer2_net_collection_member_enforce_on_type_change ON layer2_network_collection;
CREATE CONSTRAINT TRIGGER layer2_net_collection_member_enforce_on_type_change AFTER UPDATE OF layer2_network_collection_type ON jazzhands.layer2_network_collection DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.layer2_net_collection_member_enforce_on_type_change();
DROP TRIGGER IF EXISTS trig_userlog_layer2_network_collection ON layer2_network_collection;
CREATE TRIGGER trig_userlog_layer2_network_collection BEFORE INSERT OR UPDATE ON jazzhands.layer2_network_collection FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_network_collection ON layer2_network_collection;
CREATE TRIGGER trigger_audit_layer2_network_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_layer2_network_collection();
DROP TRIGGER IF EXISTS trigger_manip_layer2_network_collection_bytype_del ON layer2_network_collection;
CREATE TRIGGER trigger_manip_layer2_network_collection_bytype_del BEFORE DELETE ON jazzhands.layer2_network_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_layer2_network_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_layer2_network_collection_bytype_insup ON layer2_network_collection;
CREATE TRIGGER trigger_manip_layer2_network_collection_bytype_insup AFTER INSERT OR UPDATE OF layer2_network_collection_type ON jazzhands.layer2_network_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_layer2_network_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_layer2_network_collection_type_change ON layer2_network_collection;
CREATE TRIGGER trigger_validate_layer2_network_collection_type_change BEFORE UPDATE OF layer2_network_collection_type ON jazzhands.layer2_network_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_layer2_network_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_layer2_network_collection_hier ON layer2_network_collection_hier;
CREATE TRIGGER trig_userlog_layer2_network_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.layer2_network_collection_hier FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_network_collection_hier ON layer2_network_collection_hier;
CREATE TRIGGER trigger_audit_layer2_network_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_layer2_network_collection_hier();
DROP TRIGGER IF EXISTS trigger_hier_layer2_network_collection_after_hooks ON layer2_network_collection_hier;
CREATE TRIGGER trigger_hier_layer2_network_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network_collection_hier FOR EACH STATEMENT EXECUTE PROCEDURE jazzhands.layer2_network_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_layer2_network_collection_hier_enforce ON layer2_network_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_layer2_network_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.layer2_network_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.layer2_network_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_layer2_network_collection_layer2_network ON layer2_network_collection_layer2_network;
CREATE TRIGGER trig_userlog_layer2_network_collection_layer2_network BEFORE INSERT OR UPDATE ON jazzhands.layer2_network_collection_layer2_network FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_network_collection_layer2_network ON layer2_network_collection_layer2_network;
CREATE TRIGGER trigger_audit_layer2_network_collection_layer2_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network_collection_layer2_network FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_layer2_network_collection_layer2_network();
DROP TRIGGER IF EXISTS trigger_layer2_network_collection_member_enforce ON layer2_network_collection_layer2_network;
CREATE CONSTRAINT TRIGGER trigger_layer2_network_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.layer2_network_collection_layer2_network DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.layer2_network_collection_member_enforce();
DROP TRIGGER IF EXISTS trigger_member_layer2_network_collection_after_hooks ON layer2_network_collection_layer2_network;
CREATE TRIGGER trigger_member_layer2_network_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network_collection_layer2_network FOR EACH STATEMENT EXECUTE PROCEDURE jazzhands.layer2_network_collection_after_hooks();
DROP TRIGGER IF EXISTS trig_userlog_layer3_interface ON layer3_interface;
CREATE TRIGGER trig_userlog_layer3_interface BEFORE INSERT OR UPDATE ON jazzhands.layer3_interface FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_interface ON layer3_interface;
CREATE TRIGGER trigger_audit_layer3_interface AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_interface FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_layer3_interface();
DROP TRIGGER IF EXISTS trigger_net_int_device_id_upd ON layer3_interface;
CREATE TRIGGER trigger_net_int_device_id_upd AFTER UPDATE OF device_id ON jazzhands.layer3_interface FOR EACH ROW EXECUTE PROCEDURE jazzhands.net_int_device_id_upd();
DROP TRIGGER IF EXISTS trigger_net_int_nb_device_id_ins_before ON layer3_interface;
CREATE TRIGGER trigger_net_int_nb_device_id_ins_before BEFORE UPDATE OF device_id ON jazzhands.layer3_interface FOR EACH ROW EXECUTE PROCEDURE jazzhands.net_int_nb_device_id_ins_before();
DROP TRIGGER IF EXISTS trig_userlog_layer3_interface_netblock ON layer3_interface_netblock;
CREATE TRIGGER trig_userlog_layer3_interface_netblock BEFORE INSERT OR UPDATE ON jazzhands.layer3_interface_netblock FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_interface_netblock ON layer3_interface_netblock;
CREATE TRIGGER trigger_audit_layer3_interface_netblock AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_interface_netblock FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_layer3_interface_netblock();
DROP TRIGGER IF EXISTS trigger_net_int_nb_device_id_ins ON layer3_interface_netblock;
CREATE TRIGGER trigger_net_int_nb_device_id_ins BEFORE INSERT OR UPDATE OF layer3_interface_id ON jazzhands.layer3_interface_netblock FOR EACH ROW EXECUTE PROCEDURE jazzhands.net_int_nb_device_id_ins();
DROP TRIGGER IF EXISTS trigger_net_int_nb_device_id_ins_after ON layer3_interface_netblock;
CREATE TRIGGER trigger_net_int_nb_device_id_ins_after AFTER INSERT OR UPDATE OF layer3_interface_id ON jazzhands.layer3_interface_netblock FOR EACH ROW EXECUTE PROCEDURE jazzhands.net_int_nb_device_id_ins_after();
DROP TRIGGER IF EXISTS trigger_net_int_nb_single_address ON layer3_interface_netblock;
CREATE TRIGGER trigger_net_int_nb_single_address BEFORE INSERT OR UPDATE OF netblock_id ON jazzhands.layer3_interface_netblock FOR EACH ROW EXECUTE PROCEDURE jazzhands.net_int_nb_single_address();
DROP TRIGGER IF EXISTS trig_userlog_layer3_interface_purpose ON layer3_interface_purpose;
CREATE TRIGGER trig_userlog_layer3_interface_purpose BEFORE INSERT OR UPDATE ON jazzhands.layer3_interface_purpose FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_interface_purpose ON layer3_interface_purpose;
CREATE TRIGGER trigger_audit_layer3_interface_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_interface_purpose FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_layer3_interface_purpose();
DROP TRIGGER IF EXISTS trig_userlog_layer3_network ON layer3_network;
CREATE TRIGGER trig_userlog_layer3_network BEFORE INSERT OR UPDATE ON jazzhands.layer3_network FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_network ON layer3_network;
CREATE TRIGGER trigger_audit_layer3_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_layer3_network();
DROP TRIGGER IF EXISTS trigger_layer3_network_validate_netblock ON layer3_network;
CREATE CONSTRAINT TRIGGER trigger_layer3_network_validate_netblock AFTER INSERT OR UPDATE OF netblock_id ON jazzhands.layer3_network NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.layer3_network_validate_netblock();
DROP TRIGGER IF EXISTS layer3_net_collection_member_enforce_on_type_change ON layer3_network_collection;
CREATE CONSTRAINT TRIGGER layer3_net_collection_member_enforce_on_type_change AFTER UPDATE OF layer3_network_collection_type ON jazzhands.layer3_network_collection DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.layer3_net_collection_member_enforce_on_type_change();
DROP TRIGGER IF EXISTS trig_userlog_layer3_network_collection ON layer3_network_collection;
CREATE TRIGGER trig_userlog_layer3_network_collection BEFORE INSERT OR UPDATE ON jazzhands.layer3_network_collection FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_network_collection ON layer3_network_collection;
CREATE TRIGGER trigger_audit_layer3_network_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_layer3_network_collection();
DROP TRIGGER IF EXISTS trigger_manip_layer3_network_collection_bytype_del ON layer3_network_collection;
CREATE TRIGGER trigger_manip_layer3_network_collection_bytype_del BEFORE DELETE ON jazzhands.layer3_network_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_layer3_network_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_layer3_network_collection_bytype_insup ON layer3_network_collection;
CREATE TRIGGER trigger_manip_layer3_network_collection_bytype_insup AFTER INSERT OR UPDATE OF layer3_network_collection_type ON jazzhands.layer3_network_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_layer3_network_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_layer3_network_collection_type_change ON layer3_network_collection;
CREATE TRIGGER trigger_validate_layer3_network_collection_type_change BEFORE UPDATE OF layer3_network_collection_type ON jazzhands.layer3_network_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_layer3_network_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_layer3_network_collection_hier ON layer3_network_collection_hier;
CREATE TRIGGER trig_userlog_layer3_network_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.layer3_network_collection_hier FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_network_collection_hier ON layer3_network_collection_hier;
CREATE TRIGGER trigger_audit_layer3_network_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_layer3_network_collection_hier();
DROP TRIGGER IF EXISTS trigger_hier_layer3_network_collection_after_hooks ON layer3_network_collection_hier;
CREATE TRIGGER trigger_hier_layer3_network_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network_collection_hier FOR EACH STATEMENT EXECUTE PROCEDURE jazzhands.layer3_network_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_layer3_network_collection_hier_enforce ON layer3_network_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_layer3_network_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.layer3_network_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.layer3_network_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_layer3_network_collection_layer3_network ON layer3_network_collection_layer3_network;
CREATE TRIGGER trig_userlog_layer3_network_collection_layer3_network BEFORE INSERT OR UPDATE ON jazzhands.layer3_network_collection_layer3_network FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_network_collection_layer3_network ON layer3_network_collection_layer3_network;
CREATE TRIGGER trigger_audit_layer3_network_collection_layer3_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network_collection_layer3_network FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_layer3_network_collection_layer3_network();
DROP TRIGGER IF EXISTS trigger_layer3_network_collection_member_enforce ON layer3_network_collection_layer3_network;
CREATE CONSTRAINT TRIGGER trigger_layer3_network_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.layer3_network_collection_layer3_network DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.layer3_network_collection_member_enforce();
DROP TRIGGER IF EXISTS trigger_member_layer3_network_collection_after_hooks ON layer3_network_collection_layer3_network;
CREATE TRIGGER trigger_member_layer3_network_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network_collection_layer3_network FOR EACH STATEMENT EXECUTE PROCEDURE jazzhands.layer3_network_collection_after_hooks();
DROP TRIGGER IF EXISTS trig_userlog_logical_port_slot ON logical_port_slot;
CREATE TRIGGER trig_userlog_logical_port_slot BEFORE INSERT OR UPDATE ON jazzhands.logical_port_slot FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_logical_port_slot ON logical_port_slot;
CREATE TRIGGER trigger_audit_logical_port_slot AFTER INSERT OR DELETE OR UPDATE ON jazzhands.logical_port_slot FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_logical_port_slot();
DROP TRIGGER IF EXISTS trig_userlog_logical_volume ON logical_volume;
CREATE TRIGGER trig_userlog_logical_volume BEFORE INSERT OR UPDATE ON jazzhands.logical_volume FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_logical_volume ON logical_volume;
CREATE TRIGGER trigger_audit_logical_volume AFTER INSERT OR DELETE OR UPDATE ON jazzhands.logical_volume FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_logical_volume();
DROP TRIGGER IF EXISTS trig_userlog_logical_volume_property ON logical_volume_property;
CREATE TRIGGER trig_userlog_logical_volume_property BEFORE INSERT OR UPDATE ON jazzhands.logical_volume_property FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_logical_volume_property ON logical_volume_property;
CREATE TRIGGER trigger_audit_logical_volume_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.logical_volume_property FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_logical_volume_property();
DROP TRIGGER IF EXISTS trig_userlog_logical_volume_purpose ON logical_volume_purpose;
CREATE TRIGGER trig_userlog_logical_volume_purpose BEFORE INSERT OR UPDATE ON jazzhands.logical_volume_purpose FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_logical_volume_purpose ON logical_volume_purpose;
CREATE TRIGGER trigger_audit_logical_volume_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.logical_volume_purpose FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_logical_volume_purpose();
DROP TRIGGER IF EXISTS trig_userlog_mlag_peering ON mlag_peering;
CREATE TRIGGER trig_userlog_mlag_peering BEFORE INSERT OR UPDATE ON jazzhands.mlag_peering FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_mlag_peering ON mlag_peering;
CREATE TRIGGER trigger_audit_mlag_peering AFTER INSERT OR DELETE OR UPDATE ON jazzhands.mlag_peering FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_mlag_peering();
DROP TRIGGER IF EXISTS aaa_ta_manipulate_netblock_parentage ON netblock;
CREATE CONSTRAINT TRIGGER aaa_ta_manipulate_netblock_parentage AFTER INSERT OR DELETE ON jazzhands.netblock NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.manipulate_netblock_parentage_after();
DROP TRIGGER IF EXISTS tb_a_validate_netblock ON netblock;
CREATE TRIGGER tb_a_validate_netblock BEFORE INSERT OR UPDATE OF netblock_id, ip_address, netblock_type, is_single_address, can_subnet, parent_netblock_id, ip_universe_id ON jazzhands.netblock FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_netblock();
DROP TRIGGER IF EXISTS tb_manipulate_netblock_parentage ON netblock;
CREATE TRIGGER tb_manipulate_netblock_parentage BEFORE INSERT OR UPDATE OF ip_address, netblock_type, ip_universe_id, netblock_id, can_subnet, is_single_address ON jazzhands.netblock FOR EACH ROW EXECUTE PROCEDURE jazzhands.manipulate_netblock_parentage_before();
DROP TRIGGER IF EXISTS trig_userlog_netblock ON netblock;
CREATE TRIGGER trig_userlog_netblock BEFORE INSERT OR UPDATE ON jazzhands.netblock FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_netblock ON netblock;
CREATE TRIGGER trigger_audit_netblock AFTER INSERT OR DELETE OR UPDATE ON jazzhands.netblock FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_netblock();
DROP TRIGGER IF EXISTS trigger_cache_netblock_hier_truncate ON netblock;
CREATE TRIGGER trigger_cache_netblock_hier_truncate AFTER TRUNCATE ON jazzhands.netblock FOR EACH STATEMENT EXECUTE PROCEDURE jazzhands_cache.cache_netblock_hier_truncate_handler();
DROP TRIGGER IF EXISTS trigger_check_ip_universe_netblock ON netblock;
CREATE CONSTRAINT TRIGGER trigger_check_ip_universe_netblock AFTER UPDATE OF netblock_id, ip_universe_id ON jazzhands.netblock DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.check_ip_universe_netblock();
DROP TRIGGER IF EXISTS trigger_nb_dns_a_rec_validation ON netblock;
CREATE TRIGGER trigger_nb_dns_a_rec_validation BEFORE UPDATE OF ip_address, is_single_address ON jazzhands.netblock FOR EACH ROW EXECUTE PROCEDURE jazzhands.nb_dns_a_rec_validation();
DROP TRIGGER IF EXISTS trigger_netblock_single_address_ni ON netblock;
CREATE TRIGGER trigger_netblock_single_address_ni BEFORE UPDATE OF is_single_address, netblock_type ON jazzhands.netblock FOR EACH ROW EXECUTE PROCEDURE jazzhands.netblock_single_address_ni();
DROP TRIGGER IF EXISTS trigger_netblock_validate_layer3_network_netblock ON netblock;
CREATE CONSTRAINT TRIGGER trigger_netblock_validate_layer3_network_netblock AFTER UPDATE OF can_subnet, is_single_address ON jazzhands.netblock NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.netblock_validate_layer3_network_netblock();
DROP TRIGGER IF EXISTS trigger_validate_netblock_parentage ON netblock;
CREATE CONSTRAINT TRIGGER trigger_validate_netblock_parentage AFTER INSERT OR UPDATE OF netblock_id, ip_address, netblock_type, is_single_address, can_subnet, parent_netblock_id, ip_universe_id ON jazzhands.netblock DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_netblock_parentage();
DROP TRIGGER IF EXISTS trigger_validate_netblock_to_range_changes ON netblock;
CREATE CONSTRAINT TRIGGER trigger_validate_netblock_to_range_changes AFTER UPDATE OF ip_address, is_single_address, can_subnet, netblock_type ON jazzhands.netblock DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_netblock_to_range_changes();
DROP TRIGGER IF EXISTS zaa_ta_cache_netblock_hier_handler ON netblock;
CREATE TRIGGER zaa_ta_cache_netblock_hier_handler AFTER INSERT OR DELETE OR UPDATE OF ip_address, parent_netblock_id ON jazzhands.netblock FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.cache_netblock_hier_handler();
DROP TRIGGER IF EXISTS aaa_netblock_collection_base_handler ON netblock_collection;
CREATE TRIGGER aaa_netblock_collection_base_handler AFTER INSERT OR DELETE OR UPDATE OF netblock_collection_id ON jazzhands.netblock_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.netblock_collection_base_handler();
DROP TRIGGER IF EXISTS trig_userlog_netblock_collection ON netblock_collection;
CREATE TRIGGER trig_userlog_netblock_collection BEFORE INSERT OR UPDATE ON jazzhands.netblock_collection FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_netblock_collection ON netblock_collection;
CREATE TRIGGER trigger_audit_netblock_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.netblock_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_netblock_collection();
DROP TRIGGER IF EXISTS trigger_manip_netblock_collection_bytype_del ON netblock_collection;
CREATE TRIGGER trigger_manip_netblock_collection_bytype_del BEFORE DELETE ON jazzhands.netblock_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_netblock_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_netblock_collection_bytype_insup ON netblock_collection;
CREATE TRIGGER trigger_manip_netblock_collection_bytype_insup AFTER INSERT OR UPDATE OF netblock_collection_type ON jazzhands.netblock_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_netblock_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_netblock_collection_type_change ON netblock_collection;
CREATE TRIGGER trigger_validate_netblock_collection_type_change BEFORE UPDATE OF netblock_collection_type ON jazzhands.netblock_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_netblock_collection_type_change();
DROP TRIGGER IF EXISTS aaa_netblock_collection_root_handler ON netblock_collection_hier;
CREATE TRIGGER aaa_netblock_collection_root_handler AFTER INSERT OR DELETE OR UPDATE OF netblock_collection_id, child_netblock_collection_id ON jazzhands.netblock_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.netblock_collection_root_handler();
DROP TRIGGER IF EXISTS trig_userlog_netblock_collection_hier ON netblock_collection_hier;
CREATE TRIGGER trig_userlog_netblock_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.netblock_collection_hier FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_netblock_collection_hier ON netblock_collection_hier;
CREATE TRIGGER trigger_audit_netblock_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.netblock_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_netblock_collection_hier();
DROP TRIGGER IF EXISTS trigger_check_netblock_collection_hier_loop ON netblock_collection_hier;
CREATE TRIGGER trigger_check_netblock_collection_hier_loop AFTER INSERT OR UPDATE ON jazzhands.netblock_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands.check_netblock_colllection_hier_loop();
DROP TRIGGER IF EXISTS trigger_netblock_collection_hier_enforce ON netblock_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_netblock_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.netblock_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.netblock_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_netblock_collection_netblock ON netblock_collection_netblock;
CREATE TRIGGER trig_userlog_netblock_collection_netblock BEFORE INSERT OR UPDATE ON jazzhands.netblock_collection_netblock FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_netblock_collection_netblock ON netblock_collection_netblock;
CREATE TRIGGER trigger_audit_netblock_collection_netblock AFTER INSERT OR DELETE OR UPDATE ON jazzhands.netblock_collection_netblock FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_netblock_collection_netblock();
DROP TRIGGER IF EXISTS trigger_netblock_collection_member_enforce ON netblock_collection_netblock;
CREATE CONSTRAINT TRIGGER trigger_netblock_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.netblock_collection_netblock DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.netblock_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_network_range ON network_range;
CREATE TRIGGER trig_userlog_network_range BEFORE INSERT OR UPDATE ON jazzhands.network_range FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_network_range ON network_range;
CREATE TRIGGER trigger_audit_network_range AFTER INSERT OR DELETE OR UPDATE ON jazzhands.network_range FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_network_range();
DROP TRIGGER IF EXISTS trigger_validate_network_range_dns ON network_range;
CREATE CONSTRAINT TRIGGER trigger_validate_network_range_dns AFTER INSERT OR UPDATE OF dns_domain_id ON jazzhands.network_range DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_network_range_dns();
DROP TRIGGER IF EXISTS trigger_validate_network_range_ips ON network_range;
CREATE CONSTRAINT TRIGGER trigger_validate_network_range_ips AFTER INSERT OR UPDATE OF start_netblock_id, stop_netblock_id, parent_netblock_id, network_range_type ON jazzhands.network_range DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_network_range_ips();
DROP TRIGGER IF EXISTS trig_userlog_network_service ON network_service;
CREATE TRIGGER trig_userlog_network_service BEFORE INSERT OR UPDATE ON jazzhands.network_service FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_network_service ON network_service;
CREATE TRIGGER trigger_audit_network_service AFTER INSERT OR DELETE OR UPDATE ON jazzhands.network_service FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_network_service();
DROP TRIGGER IF EXISTS trig_userlog_operating_system ON operating_system;
CREATE TRIGGER trig_userlog_operating_system BEFORE INSERT OR UPDATE ON jazzhands.operating_system FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_operating_system ON operating_system;
CREATE TRIGGER trigger_audit_operating_system AFTER INSERT OR DELETE OR UPDATE ON jazzhands.operating_system FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_operating_system();
DROP TRIGGER IF EXISTS trig_userlog_operating_system_snapshot ON operating_system_snapshot;
CREATE TRIGGER trig_userlog_operating_system_snapshot BEFORE INSERT OR UPDATE ON jazzhands.operating_system_snapshot FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_operating_system_snapshot ON operating_system_snapshot;
CREATE TRIGGER trigger_audit_operating_system_snapshot AFTER INSERT OR DELETE OR UPDATE ON jazzhands.operating_system_snapshot FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_operating_system_snapshot();
DROP TRIGGER IF EXISTS trig_userlog_person ON person;
CREATE TRIGGER trig_userlog_person BEFORE INSERT OR UPDATE ON jazzhands.person FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person ON person;
CREATE TRIGGER trigger_audit_person AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_person();
DROP TRIGGER IF EXISTS trig_userlog_person_account_realm_company ON person_account_realm_company;
CREATE TRIGGER trig_userlog_person_account_realm_company BEFORE INSERT OR UPDATE ON jazzhands.person_account_realm_company FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_account_realm_company ON person_account_realm_company;
CREATE TRIGGER trigger_audit_person_account_realm_company AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_account_realm_company FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_person_account_realm_company();
DROP TRIGGER IF EXISTS trig_userlog_person_authentication_question ON person_authentication_question;
CREATE TRIGGER trig_userlog_person_authentication_question BEFORE INSERT OR UPDATE ON jazzhands.person_authentication_question FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_authentication_question ON person_authentication_question;
CREATE TRIGGER trigger_audit_person_authentication_question AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_authentication_question FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_person_authentication_question();
DROP TRIGGER IF EXISTS trig_userlog_person_company ON person_company;
CREATE TRIGGER trig_userlog_person_company BEFORE INSERT OR UPDATE ON jazzhands.person_company FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_company ON person_company;
CREATE TRIGGER trigger_audit_person_company AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_company FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_person_company();
DROP TRIGGER IF EXISTS trigger_propagate_person_status_to_account ON person_company;
CREATE TRIGGER trigger_propagate_person_status_to_account AFTER UPDATE ON jazzhands.person_company FOR EACH ROW EXECUTE PROCEDURE jazzhands.propagate_person_status_to_account();
DROP TRIGGER IF EXISTS trigger_z_automated_ac_on_person_company ON person_company;
CREATE TRIGGER trigger_z_automated_ac_on_person_company AFTER UPDATE OF is_management, is_exempt, is_full_time, person_id, company_id, manager_person_id ON jazzhands.person_company FOR EACH ROW EXECUTE PROCEDURE jazzhands.automated_ac_on_person_company();
DROP TRIGGER IF EXISTS trig_userlog_person_company_attribute ON person_company_attribute;
CREATE TRIGGER trig_userlog_person_company_attribute BEFORE INSERT OR UPDATE ON jazzhands.person_company_attribute FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_company_attribute ON person_company_attribute;
CREATE TRIGGER trigger_audit_person_company_attribute AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_company_attribute FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_person_company_attribute();
DROP TRIGGER IF EXISTS trigger_validate_person_company_attribute ON person_company_attribute;
CREATE TRIGGER trigger_validate_person_company_attribute BEFORE INSERT OR UPDATE ON jazzhands.person_company_attribute FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_person_company_attribute();
DROP TRIGGER IF EXISTS trig_userlog_person_company_badge ON person_company_badge;
CREATE TRIGGER trig_userlog_person_company_badge BEFORE INSERT OR UPDATE ON jazzhands.person_company_badge FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_company_badge ON person_company_badge;
CREATE TRIGGER trigger_audit_person_company_badge AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_company_badge FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_person_company_badge();
DROP TRIGGER IF EXISTS trig_userlog_person_contact ON person_contact;
CREATE TRIGGER trig_userlog_person_contact BEFORE INSERT OR UPDATE ON jazzhands.person_contact FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_contact ON person_contact;
CREATE TRIGGER trigger_audit_person_contact AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_contact FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_person_contact();
DROP TRIGGER IF EXISTS trig_userlog_person_image ON person_image;
CREATE TRIGGER trig_userlog_person_image BEFORE INSERT OR UPDATE ON jazzhands.person_image FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_image ON person_image;
CREATE TRIGGER trigger_audit_person_image AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_image FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_person_image();
DROP TRIGGER IF EXISTS trigger_fix_person_image_oid_ownership ON person_image;
CREATE TRIGGER trigger_fix_person_image_oid_ownership BEFORE INSERT ON jazzhands.person_image FOR EACH ROW EXECUTE PROCEDURE jazzhands.fix_person_image_oid_ownership();
DROP TRIGGER IF EXISTS trig_userlog_person_image_usage ON person_image_usage;
CREATE TRIGGER trig_userlog_person_image_usage BEFORE INSERT OR UPDATE ON jazzhands.person_image_usage FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_image_usage ON person_image_usage;
CREATE TRIGGER trigger_audit_person_image_usage AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_image_usage FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_person_image_usage();
DROP TRIGGER IF EXISTS trigger_check_person_image_usage_mv ON person_image_usage;
CREATE TRIGGER trigger_check_person_image_usage_mv AFTER INSERT OR UPDATE ON jazzhands.person_image_usage FOR EACH ROW EXECUTE PROCEDURE jazzhands.check_person_image_usage_mv();
DROP TRIGGER IF EXISTS trig_automated_realm_site_ac_pl ON person_location;
CREATE TRIGGER trig_automated_realm_site_ac_pl AFTER INSERT OR DELETE OR UPDATE OF site_code, person_id ON jazzhands.person_location FOR EACH ROW EXECUTE PROCEDURE jazzhands.automated_realm_site_ac_pl();
DROP TRIGGER IF EXISTS trig_userlog_person_location ON person_location;
CREATE TRIGGER trig_userlog_person_location BEFORE INSERT OR UPDATE ON jazzhands.person_location FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_location ON person_location;
CREATE TRIGGER trigger_audit_person_location AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_location FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_person_location();
DROP TRIGGER IF EXISTS trig_userlog_person_note ON person_note;
CREATE TRIGGER trig_userlog_person_note BEFORE INSERT OR UPDATE ON jazzhands.person_note FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_note ON person_note;
CREATE TRIGGER trigger_audit_person_note AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_note FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_person_note();
DROP TRIGGER IF EXISTS trig_userlog_person_parking_pass ON person_parking_pass;
CREATE TRIGGER trig_userlog_person_parking_pass BEFORE INSERT OR UPDATE ON jazzhands.person_parking_pass FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_parking_pass ON person_parking_pass;
CREATE TRIGGER trigger_audit_person_parking_pass AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_parking_pass FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_person_parking_pass();
DROP TRIGGER IF EXISTS trig_userlog_person_vehicle ON person_vehicle;
CREATE TRIGGER trig_userlog_person_vehicle BEFORE INSERT OR UPDATE ON jazzhands.person_vehicle FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_vehicle ON person_vehicle;
CREATE TRIGGER trigger_audit_person_vehicle AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_vehicle FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_person_vehicle();
DROP TRIGGER IF EXISTS trig_userlog_physical_address ON physical_address;
CREATE TRIGGER trig_userlog_physical_address BEFORE INSERT OR UPDATE ON jazzhands.physical_address FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_physical_address ON physical_address;
CREATE TRIGGER trigger_audit_physical_address AFTER INSERT OR DELETE OR UPDATE ON jazzhands.physical_address FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_physical_address();
DROP TRIGGER IF EXISTS trig_userlog_physical_connection ON physical_connection;
CREATE TRIGGER trig_userlog_physical_connection BEFORE INSERT OR UPDATE ON jazzhands.physical_connection FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_physical_connection ON physical_connection;
CREATE TRIGGER trigger_audit_physical_connection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.physical_connection FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_physical_connection();
DROP TRIGGER IF EXISTS trigger_verify_physical_connection ON physical_connection;
CREATE TRIGGER trigger_verify_physical_connection AFTER INSERT OR UPDATE ON jazzhands.physical_connection FOR EACH STATEMENT EXECUTE PROCEDURE jazzhands.verify_physical_connection();
DROP TRIGGER IF EXISTS trig_userlog_physicalish_volume ON physicalish_volume;
CREATE TRIGGER trig_userlog_physicalish_volume BEFORE INSERT OR UPDATE ON jazzhands.physicalish_volume FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_physicalish_volume ON physicalish_volume;
CREATE TRIGGER trigger_audit_physicalish_volume AFTER INSERT OR DELETE OR UPDATE ON jazzhands.physicalish_volume FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_physicalish_volume();
DROP TRIGGER IF EXISTS trigger_verify_physicalish_volume ON physicalish_volume;
CREATE TRIGGER trigger_verify_physicalish_volume BEFORE INSERT OR UPDATE ON jazzhands.physicalish_volume FOR EACH ROW EXECUTE PROCEDURE jazzhands.verify_physicalish_volume();
DROP TRIGGER IF EXISTS trig_userlog_private_key ON private_key;
CREATE TRIGGER trig_userlog_private_key BEFORE INSERT OR UPDATE ON jazzhands.private_key FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_private_key ON private_key;
CREATE TRIGGER trigger_audit_private_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.private_key FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_private_key();
DROP TRIGGER IF EXISTS trigger_pvtkey_ski_signed_validate ON private_key;
CREATE TRIGGER trigger_pvtkey_ski_signed_validate AFTER UPDATE OF subject_key_identifier ON jazzhands.private_key FOR EACH ROW EXECUTE PROCEDURE jazzhands.pvtkey_ski_signed_validate();
DROP TRIGGER IF EXISTS trig_userlog_property ON property;
CREATE TRIGGER trig_userlog_property BEFORE INSERT OR UPDATE ON jazzhands.property FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_property ON property;
CREATE TRIGGER trigger_audit_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_property();
DROP TRIGGER IF EXISTS trigger_validate_property ON property;
CREATE TRIGGER trigger_validate_property BEFORE INSERT OR UPDATE ON jazzhands.property FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_property();
DROP TRIGGER IF EXISTS trig_userlog_property_name_collection ON property_name_collection;
CREATE TRIGGER trig_userlog_property_name_collection BEFORE INSERT OR UPDATE ON jazzhands.property_name_collection FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_property_name_collection ON property_name_collection;
CREATE TRIGGER trigger_audit_property_name_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property_name_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_property_name_collection();
DROP TRIGGER IF EXISTS trigger_validate_property_name_collection_type_change ON property_name_collection;
CREATE TRIGGER trigger_validate_property_name_collection_type_change BEFORE UPDATE OF property_name_collection_type ON jazzhands.property_name_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_property_name_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_property_name_collection_hier ON property_name_collection_hier;
CREATE TRIGGER trig_userlog_property_name_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.property_name_collection_hier FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_property_name_collection_hier ON property_name_collection_hier;
CREATE TRIGGER trigger_audit_property_name_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property_name_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_property_name_collection_hier();
DROP TRIGGER IF EXISTS trigger_hier_property_name_collection_after_hooks ON property_name_collection_hier;
CREATE TRIGGER trigger_hier_property_name_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property_name_collection_hier FOR EACH STATEMENT EXECUTE PROCEDURE jazzhands.property_name_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_property_name_collection_hier_enforce ON property_name_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_property_name_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.property_name_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.property_name_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_property_name_collection_property_name ON property_name_collection_property_name;
CREATE TRIGGER trig_userlog_property_name_collection_property_name BEFORE INSERT OR UPDATE ON jazzhands.property_name_collection_property_name FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_property_name_collection_property_name ON property_name_collection_property_name;
CREATE TRIGGER trigger_audit_property_name_collection_property_name AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property_name_collection_property_name FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_property_name_collection_property_name();
DROP TRIGGER IF EXISTS trigger_member_property_name_collection_after_hooks ON property_name_collection_property_name;
CREATE TRIGGER trigger_member_property_name_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property_name_collection_property_name FOR EACH STATEMENT EXECUTE PROCEDURE jazzhands.property_name_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_property_name_collection_member_enforce ON property_name_collection_property_name;
CREATE CONSTRAINT TRIGGER trigger_property_name_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.property_name_collection_property_name DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.property_name_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_pseudo_klogin ON pseudo_klogin;
CREATE TRIGGER trig_userlog_pseudo_klogin BEFORE INSERT OR UPDATE ON jazzhands.pseudo_klogin FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_pseudo_klogin ON pseudo_klogin;
CREATE TRIGGER trigger_audit_pseudo_klogin AFTER INSERT OR DELETE OR UPDATE ON jazzhands.pseudo_klogin FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_pseudo_klogin();
DROP TRIGGER IF EXISTS trig_userlog_rack ON rack;
CREATE TRIGGER trig_userlog_rack BEFORE INSERT OR UPDATE ON jazzhands.rack FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_rack ON rack;
CREATE TRIGGER trigger_audit_rack AFTER INSERT OR DELETE OR UPDATE ON jazzhands.rack FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_rack();
DROP TRIGGER IF EXISTS trig_userlog_rack_location ON rack_location;
CREATE TRIGGER trig_userlog_rack_location BEFORE INSERT OR UPDATE ON jazzhands.rack_location FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_rack_location ON rack_location;
CREATE TRIGGER trigger_audit_rack_location AFTER INSERT OR DELETE OR UPDATE ON jazzhands.rack_location FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_rack_location();
DROP TRIGGER IF EXISTS trig_userlog_service_environment ON service_environment;
CREATE TRIGGER trig_userlog_service_environment BEFORE INSERT OR UPDATE ON jazzhands.service_environment FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_environment ON service_environment;
CREATE TRIGGER trigger_audit_service_environment AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_environment FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_service_environment();
DROP TRIGGER IF EXISTS trigger_delete_per_service_environment_service_environment_coll ON service_environment;
CREATE TRIGGER trigger_delete_per_service_environment_service_environment_coll BEFORE DELETE ON jazzhands.service_environment FOR EACH ROW EXECUTE PROCEDURE jazzhands.delete_per_service_environment_service_environment_collection();
DROP TRIGGER IF EXISTS trigger_update_per_service_environment_service_environment_coll ON service_environment;
CREATE TRIGGER trigger_update_per_service_environment_service_environment_coll AFTER INSERT OR UPDATE ON jazzhands.service_environment FOR EACH ROW EXECUTE PROCEDURE jazzhands.update_per_service_environment_service_environment_collection();
DROP TRIGGER IF EXISTS trig_userlog_service_environment_collection ON service_environment_collection;
CREATE TRIGGER trig_userlog_service_environment_collection BEFORE INSERT OR UPDATE ON jazzhands.service_environment_collection FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_environment_collection ON service_environment_collection;
CREATE TRIGGER trigger_audit_service_environment_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_environment_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_service_environment_collection();
DROP TRIGGER IF EXISTS trigger_manip_service_environment_collection_bytype_del ON service_environment_collection;
CREATE TRIGGER trigger_manip_service_environment_collection_bytype_del BEFORE DELETE ON jazzhands.service_environment_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_service_environment_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_service_environment_collection_bytype_insup ON service_environment_collection;
CREATE TRIGGER trigger_manip_service_environment_collection_bytype_insup AFTER INSERT OR UPDATE OF service_environment_collection_type ON jazzhands.service_environment_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_service_environment_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_service_environment_collection_type_change ON service_environment_collection;
CREATE TRIGGER trigger_validate_service_environment_collection_type_change BEFORE UPDATE OF service_environment_collection_type ON jazzhands.service_environment_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_service_environment_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_service_environment_collection_hier ON service_environment_collection_hier;
CREATE TRIGGER trig_userlog_service_environment_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.service_environment_collection_hier FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_environment_collection_hier ON service_environment_collection_hier;
CREATE TRIGGER trigger_audit_service_environment_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_environment_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_service_environment_collection_hier();
DROP TRIGGER IF EXISTS trigger_check_svcenv_collection_hier_loop ON service_environment_collection_hier;
CREATE TRIGGER trigger_check_svcenv_collection_hier_loop AFTER INSERT OR UPDATE ON jazzhands.service_environment_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands.check_svcenv_colllection_hier_loop();
DROP TRIGGER IF EXISTS trigger_service_environment_collection_hier_enforce ON service_environment_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_service_environment_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.service_environment_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.service_environment_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_service_environment_collection_service_environment ON service_environment_collection_service_environment;
CREATE TRIGGER trig_userlog_service_environment_collection_service_environment BEFORE INSERT OR UPDATE ON jazzhands.service_environment_collection_service_environment FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_environment_collection_service_environmen ON service_environment_collection_service_environment;
CREATE TRIGGER trigger_audit_service_environment_collection_service_environmen AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_environment_collection_service_environment FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_service_environment_collection_service_environmen();
DROP TRIGGER IF EXISTS trigger_service_environment_collection_member_enforce ON service_environment_collection_service_environment;
CREATE CONSTRAINT TRIGGER trigger_service_environment_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.service_environment_collection_service_environment DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.service_environment_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_shared_netblock ON shared_netblock;
CREATE TRIGGER trig_userlog_shared_netblock BEFORE INSERT OR UPDATE ON jazzhands.shared_netblock FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_shared_netblock ON shared_netblock;
CREATE TRIGGER trigger_audit_shared_netblock AFTER INSERT OR DELETE OR UPDATE ON jazzhands.shared_netblock FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_shared_netblock();
DROP TRIGGER IF EXISTS trig_userlog_shared_netblock_layer3_interface ON shared_netblock_layer3_interface;
CREATE TRIGGER trig_userlog_shared_netblock_layer3_interface BEFORE INSERT OR UPDATE ON jazzhands.shared_netblock_layer3_interface FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_shared_netblock_layer3_interface ON shared_netblock_layer3_interface;
CREATE TRIGGER trigger_audit_shared_netblock_layer3_interface AFTER INSERT OR DELETE OR UPDATE ON jazzhands.shared_netblock_layer3_interface FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_shared_netblock_layer3_interface();
DROP TRIGGER IF EXISTS trig_userlog_site ON site;
CREATE TRIGGER trig_userlog_site BEFORE INSERT OR UPDATE ON jazzhands.site FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_site ON site;
CREATE TRIGGER trigger_audit_site AFTER INSERT OR DELETE OR UPDATE ON jazzhands.site FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_site();
DROP TRIGGER IF EXISTS trigger_del_site_netblock_collections ON site;
CREATE TRIGGER trigger_del_site_netblock_collections BEFORE DELETE ON jazzhands.site FOR EACH ROW EXECUTE PROCEDURE jazzhands.del_site_netblock_collections();
DROP TRIGGER IF EXISTS trigger_ins_site_netblock_collections ON site;
CREATE TRIGGER trigger_ins_site_netblock_collections AFTER INSERT ON jazzhands.site FOR EACH ROW EXECUTE PROCEDURE jazzhands.ins_site_netblock_collections();
DROP TRIGGER IF EXISTS trigger_upd_site_netblock_collections ON site;
CREATE TRIGGER trigger_upd_site_netblock_collections AFTER UPDATE ON jazzhands.site FOR EACH ROW EXECUTE PROCEDURE jazzhands.upd_site_netblock_collections();
DROP TRIGGER IF EXISTS trig_userlog_slot ON slot;
CREATE TRIGGER trig_userlog_slot BEFORE INSERT OR UPDATE ON jazzhands.slot FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_slot ON slot;
CREATE TRIGGER trigger_audit_slot AFTER INSERT OR DELETE OR UPDATE ON jazzhands.slot FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_slot();
DROP TRIGGER IF EXISTS trig_userlog_slot_type ON slot_type;
CREATE TRIGGER trig_userlog_slot_type BEFORE INSERT OR UPDATE ON jazzhands.slot_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_slot_type ON slot_type;
CREATE TRIGGER trigger_audit_slot_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.slot_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_slot_type();
DROP TRIGGER IF EXISTS trig_userlog_slot_type_permitted_component_slot_type ON slot_type_permitted_component_slot_type;
CREATE TRIGGER trig_userlog_slot_type_permitted_component_slot_type BEFORE INSERT OR UPDATE ON jazzhands.slot_type_permitted_component_slot_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_slot_type_permitted_component_slot_type ON slot_type_permitted_component_slot_type;
CREATE TRIGGER trigger_audit_slot_type_permitted_component_slot_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.slot_type_permitted_component_slot_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_slot_type_permitted_component_slot_type();
DROP TRIGGER IF EXISTS trig_userlog_slot_type_permitted_remote_slot_type ON slot_type_permitted_remote_slot_type;
CREATE TRIGGER trig_userlog_slot_type_permitted_remote_slot_type BEFORE INSERT OR UPDATE ON jazzhands.slot_type_permitted_remote_slot_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_slot_type_permitted_remote_slot_type ON slot_type_permitted_remote_slot_type;
CREATE TRIGGER trigger_audit_slot_type_permitted_remote_slot_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.slot_type_permitted_remote_slot_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_slot_type_permitted_remote_slot_type();
DROP TRIGGER IF EXISTS trig_userlog_ssh_key ON ssh_key;
CREATE TRIGGER trig_userlog_ssh_key BEFORE INSERT OR UPDATE ON jazzhands.ssh_key FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_ssh_key ON ssh_key;
CREATE TRIGGER trigger_audit_ssh_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.ssh_key FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_ssh_key();
DROP TRIGGER IF EXISTS trig_userlog_static_route ON static_route;
CREATE TRIGGER trig_userlog_static_route BEFORE INSERT OR UPDATE ON jazzhands.static_route FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_static_route ON static_route;
CREATE TRIGGER trigger_audit_static_route AFTER INSERT OR DELETE OR UPDATE ON jazzhands.static_route FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_static_route();
DROP TRIGGER IF EXISTS trig_userlog_static_route_template ON static_route_template;
CREATE TRIGGER trig_userlog_static_route_template BEFORE INSERT OR UPDATE ON jazzhands.static_route_template FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_static_route_template ON static_route_template;
CREATE TRIGGER trigger_audit_static_route_template AFTER INSERT OR DELETE OR UPDATE ON jazzhands.static_route_template FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_static_route_template();
DROP TRIGGER IF EXISTS trig_userlog_sudo_account_collection_device_collection ON sudo_account_collection_device_collection;
CREATE TRIGGER trig_userlog_sudo_account_collection_device_collection BEFORE INSERT OR UPDATE ON jazzhands.sudo_account_collection_device_collection FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_sudo_account_collection_device_collection ON sudo_account_collection_device_collection;
CREATE TRIGGER trigger_audit_sudo_account_collection_device_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.sudo_account_collection_device_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_sudo_account_collection_device_collection();
DROP TRIGGER IF EXISTS trig_userlog_sudo_alias ON sudo_alias;
CREATE TRIGGER trig_userlog_sudo_alias BEFORE INSERT OR UPDATE ON jazzhands.sudo_alias FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_sudo_alias ON sudo_alias;
CREATE TRIGGER trigger_audit_sudo_alias AFTER INSERT OR DELETE OR UPDATE ON jazzhands.sudo_alias FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_sudo_alias();
DROP TRIGGER IF EXISTS trig_userlog_sw_package ON sw_package;
CREATE TRIGGER trig_userlog_sw_package BEFORE INSERT OR UPDATE ON jazzhands.sw_package FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_sw_package ON sw_package;
CREATE TRIGGER trigger_audit_sw_package AFTER INSERT OR DELETE OR UPDATE ON jazzhands.sw_package FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_sw_package();
DROP TRIGGER IF EXISTS trig_userlog_ticketing_system ON ticketing_system;
CREATE TRIGGER trig_userlog_ticketing_system BEFORE INSERT OR UPDATE ON jazzhands.ticketing_system FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_ticketing_system ON ticketing_system;
CREATE TRIGGER trigger_audit_ticketing_system AFTER INSERT OR DELETE OR UPDATE ON jazzhands.ticketing_system FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_ticketing_system();
DROP TRIGGER IF EXISTS trig_userlog_token ON token;
CREATE TRIGGER trig_userlog_token BEFORE INSERT OR UPDATE ON jazzhands.token FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_token ON token;
CREATE TRIGGER trigger_audit_token AFTER INSERT OR DELETE OR UPDATE ON jazzhands.token FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_token();
DROP TRIGGER IF EXISTS trigger_pgnotify_token_change ON token;
CREATE TRIGGER trigger_pgnotify_token_change AFTER INSERT OR UPDATE ON jazzhands.token FOR EACH ROW EXECUTE PROCEDURE jazzhands.pgnotify_token_change();
DROP TRIGGER IF EXISTS trig_userlog_token_collection ON token_collection;
CREATE TRIGGER trig_userlog_token_collection BEFORE INSERT OR UPDATE ON jazzhands.token_collection FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_token_collection ON token_collection;
CREATE TRIGGER trigger_audit_token_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.token_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_token_collection();
DROP TRIGGER IF EXISTS trig_userlog_token_collection_hier ON token_collection_hier;
CREATE TRIGGER trig_userlog_token_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.token_collection_hier FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_token_collection_hier ON token_collection_hier;
CREATE TRIGGER trigger_audit_token_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.token_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_token_collection_hier();
DROP TRIGGER IF EXISTS trigger_check_token_collection_hier_loop ON token_collection_hier;
CREATE TRIGGER trigger_check_token_collection_hier_loop AFTER INSERT OR UPDATE ON jazzhands.token_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands.check_token_colllection_hier_loop();
DROP TRIGGER IF EXISTS trigger_token_collection_hier_enforce ON token_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_token_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.token_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.token_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_token_collection_token ON token_collection_token;
CREATE TRIGGER trig_userlog_token_collection_token BEFORE INSERT OR UPDATE ON jazzhands.token_collection_token FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_token_collection_token ON token_collection_token;
CREATE TRIGGER trigger_audit_token_collection_token AFTER INSERT OR DELETE OR UPDATE ON jazzhands.token_collection_token FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_token_collection_token();
DROP TRIGGER IF EXISTS trigger_token_collection_member_enforce ON token_collection_token;
CREATE CONSTRAINT TRIGGER trigger_token_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.token_collection_token DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.token_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_unix_group ON unix_group;
CREATE TRIGGER trig_userlog_unix_group BEFORE INSERT OR UPDATE ON jazzhands.unix_group FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_unix_group ON unix_group;
CREATE TRIGGER trigger_audit_unix_group AFTER INSERT OR DELETE OR UPDATE ON jazzhands.unix_group FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_unix_group();
DROP TRIGGER IF EXISTS trig_userlog_val_account_collection_relation ON val_account_collection_relation;
CREATE TRIGGER trig_userlog_val_account_collection_relation BEFORE INSERT OR UPDATE ON jazzhands.val_account_collection_relation FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_acct_coll_preserve_direct ON val_account_collection_relation;
CREATE CONSTRAINT TRIGGER trigger_acct_coll_preserve_direct AFTER DELETE OR UPDATE ON jazzhands.val_account_collection_relation DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.acct_coll_preserve_direct();
DROP TRIGGER IF EXISTS trigger_audit_val_account_collection_relation ON val_account_collection_relation;
CREATE TRIGGER trigger_audit_val_account_collection_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_account_collection_relation FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_account_collection_relation();
DROP TRIGGER IF EXISTS trig_account_collection_type_realm ON val_account_collection_type;
CREATE TRIGGER trig_account_collection_type_realm AFTER UPDATE OF account_realm_id ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.account_collection_type_realm();
DROP TRIGGER IF EXISTS trig_userlog_val_account_collection_type ON val_account_collection_type;
CREATE TRIGGER trig_userlog_val_account_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_acct_coll_insert_direct ON val_account_collection_type;
CREATE TRIGGER trigger_acct_coll_insert_direct AFTER INSERT ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.acct_coll_insert_direct();
DROP TRIGGER IF EXISTS trigger_acct_coll_remove_direct ON val_account_collection_type;
CREATE TRIGGER trigger_acct_coll_remove_direct BEFORE DELETE ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.acct_coll_remove_direct();
DROP TRIGGER IF EXISTS trigger_acct_coll_update_direct_before ON val_account_collection_type;
CREATE TRIGGER trigger_acct_coll_update_direct_before AFTER UPDATE OF account_collection_type ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.acct_coll_update_direct_before();
DROP TRIGGER IF EXISTS trigger_audit_val_account_collection_type ON val_account_collection_type;
CREATE TRIGGER trigger_audit_val_account_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_account_collection_type();
DROP TRIGGER IF EXISTS trig_userlog_val_account_role ON val_account_role;
CREATE TRIGGER trig_userlog_val_account_role BEFORE INSERT OR UPDATE ON jazzhands.val_account_role FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_account_role ON val_account_role;
CREATE TRIGGER trigger_audit_val_account_role AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_account_role FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_account_role();
DROP TRIGGER IF EXISTS trig_userlog_val_account_type ON val_account_type;
CREATE TRIGGER trig_userlog_val_account_type BEFORE INSERT OR UPDATE ON jazzhands.val_account_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_account_type ON val_account_type;
CREATE TRIGGER trigger_audit_val_account_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_account_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_account_type();
DROP TRIGGER IF EXISTS trig_userlog_val_appaal_group_name ON val_appaal_group_name;
CREATE TRIGGER trig_userlog_val_appaal_group_name BEFORE INSERT OR UPDATE ON jazzhands.val_appaal_group_name FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_appaal_group_name ON val_appaal_group_name;
CREATE TRIGGER trigger_audit_val_appaal_group_name AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_appaal_group_name FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_appaal_group_name();
DROP TRIGGER IF EXISTS trig_userlog_val_application_key ON val_application_key;
CREATE TRIGGER trig_userlog_val_application_key BEFORE INSERT OR UPDATE ON jazzhands.val_application_key FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_application_key ON val_application_key;
CREATE TRIGGER trigger_audit_val_application_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_application_key FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_application_key();
DROP TRIGGER IF EXISTS trig_userlog_val_application_key_values ON val_application_key_values;
CREATE TRIGGER trig_userlog_val_application_key_values BEFORE INSERT OR UPDATE ON jazzhands.val_application_key_values FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_application_key_values ON val_application_key_values;
CREATE TRIGGER trigger_audit_val_application_key_values AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_application_key_values FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_application_key_values();
DROP TRIGGER IF EXISTS trig_userlog_val_approval_chain_response_period ON val_approval_chain_response_period;
CREATE TRIGGER trig_userlog_val_approval_chain_response_period BEFORE INSERT OR UPDATE ON jazzhands.val_approval_chain_response_period FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_approval_chain_response_period ON val_approval_chain_response_period;
CREATE TRIGGER trigger_audit_val_approval_chain_response_period AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_approval_chain_response_period FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_approval_chain_response_period();
DROP TRIGGER IF EXISTS trig_userlog_val_approval_expiration_action ON val_approval_expiration_action;
CREATE TRIGGER trig_userlog_val_approval_expiration_action BEFORE INSERT OR UPDATE ON jazzhands.val_approval_expiration_action FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_approval_expiration_action ON val_approval_expiration_action;
CREATE TRIGGER trigger_audit_val_approval_expiration_action AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_approval_expiration_action FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_approval_expiration_action();
DROP TRIGGER IF EXISTS trig_userlog_val_approval_notifty_type ON val_approval_notifty_type;
CREATE TRIGGER trig_userlog_val_approval_notifty_type BEFORE INSERT OR UPDATE ON jazzhands.val_approval_notifty_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_approval_notifty_type ON val_approval_notifty_type;
CREATE TRIGGER trigger_audit_val_approval_notifty_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_approval_notifty_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_approval_notifty_type();
DROP TRIGGER IF EXISTS trig_userlog_val_approval_process_type ON val_approval_process_type;
CREATE TRIGGER trig_userlog_val_approval_process_type BEFORE INSERT OR UPDATE ON jazzhands.val_approval_process_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_approval_process_type ON val_approval_process_type;
CREATE TRIGGER trigger_audit_val_approval_process_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_approval_process_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_approval_process_type();
DROP TRIGGER IF EXISTS trig_userlog_val_approval_type ON val_approval_type;
CREATE TRIGGER trig_userlog_val_approval_type BEFORE INSERT OR UPDATE ON jazzhands.val_approval_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_approval_type ON val_approval_type;
CREATE TRIGGER trigger_audit_val_approval_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_approval_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_approval_type();
DROP TRIGGER IF EXISTS trig_userlog_val_attestation_frequency ON val_attestation_frequency;
CREATE TRIGGER trig_userlog_val_attestation_frequency BEFORE INSERT OR UPDATE ON jazzhands.val_attestation_frequency FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_attestation_frequency ON val_attestation_frequency;
CREATE TRIGGER trigger_audit_val_attestation_frequency AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_attestation_frequency FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_attestation_frequency();
DROP TRIGGER IF EXISTS trig_userlog_val_authentication_question ON val_authentication_question;
CREATE TRIGGER trig_userlog_val_authentication_question BEFORE INSERT OR UPDATE ON jazzhands.val_authentication_question FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_authentication_question ON val_authentication_question;
CREATE TRIGGER trigger_audit_val_authentication_question AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_authentication_question FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_authentication_question();
DROP TRIGGER IF EXISTS trig_userlog_val_authentication_resource ON val_authentication_resource;
CREATE TRIGGER trig_userlog_val_authentication_resource BEFORE INSERT OR UPDATE ON jazzhands.val_authentication_resource FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_authentication_resource ON val_authentication_resource;
CREATE TRIGGER trigger_audit_val_authentication_resource AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_authentication_resource FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_authentication_resource();
DROP TRIGGER IF EXISTS trig_userlog_val_badge_status ON val_badge_status;
CREATE TRIGGER trig_userlog_val_badge_status BEFORE INSERT OR UPDATE ON jazzhands.val_badge_status FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_badge_status ON val_badge_status;
CREATE TRIGGER trigger_audit_val_badge_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_badge_status FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_badge_status();
DROP TRIGGER IF EXISTS trig_userlog_val_cable_type ON val_cable_type;
CREATE TRIGGER trig_userlog_val_cable_type BEFORE INSERT OR UPDATE ON jazzhands.val_cable_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_cable_type ON val_cable_type;
CREATE TRIGGER trigger_audit_val_cable_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_cable_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_cable_type();
DROP TRIGGER IF EXISTS trig_userlog_val_company_collection_type ON val_company_collection_type;
CREATE TRIGGER trig_userlog_val_company_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_company_collection_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_company_collection_type ON val_company_collection_type;
CREATE TRIGGER trigger_audit_val_company_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_company_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_company_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_company_collection_type_bytype_del ON val_company_collection_type;
CREATE TRIGGER trigger_manip_company_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_company_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_company_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_company_collection_type_bytype_insup ON val_company_collection_type;
CREATE TRIGGER trigger_manip_company_collection_type_bytype_insup AFTER INSERT OR UPDATE OF company_collection_type ON jazzhands.val_company_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_company_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_company_type ON val_company_type;
CREATE TRIGGER trig_userlog_val_company_type BEFORE INSERT OR UPDATE ON jazzhands.val_company_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_company_type ON val_company_type;
CREATE TRIGGER trigger_audit_val_company_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_company_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_company_type();
DROP TRIGGER IF EXISTS trig_userlog_val_company_type_purpose ON val_company_type_purpose;
CREATE TRIGGER trig_userlog_val_company_type_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_company_type_purpose FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_company_type_purpose ON val_company_type_purpose;
CREATE TRIGGER trigger_audit_val_company_type_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_company_type_purpose FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_company_type_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_component_function ON val_component_function;
CREATE TRIGGER trig_userlog_val_component_function BEFORE INSERT OR UPDATE ON jazzhands.val_component_function FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_component_function ON val_component_function;
CREATE TRIGGER trigger_audit_val_component_function AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_component_function FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_component_function();
DROP TRIGGER IF EXISTS trig_userlog_val_component_property ON val_component_property;
CREATE TRIGGER trig_userlog_val_component_property BEFORE INSERT OR UPDATE ON jazzhands.val_component_property FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_component_property ON val_component_property;
CREATE TRIGGER trigger_audit_val_component_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_component_property FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_component_property();
DROP TRIGGER IF EXISTS trig_userlog_val_component_property_type ON val_component_property_type;
CREATE TRIGGER trig_userlog_val_component_property_type BEFORE INSERT OR UPDATE ON jazzhands.val_component_property_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_component_property_type ON val_component_property_type;
CREATE TRIGGER trigger_audit_val_component_property_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_component_property_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_component_property_type();
DROP TRIGGER IF EXISTS trig_userlog_val_component_property_value ON val_component_property_value;
CREATE TRIGGER trig_userlog_val_component_property_value BEFORE INSERT OR UPDATE ON jazzhands.val_component_property_value FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_component_property_value ON val_component_property_value;
CREATE TRIGGER trigger_audit_val_component_property_value AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_component_property_value FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_component_property_value();
DROP TRIGGER IF EXISTS trig_userlog_val_contract_type ON val_contract_type;
CREATE TRIGGER trig_userlog_val_contract_type BEFORE INSERT OR UPDATE ON jazzhands.val_contract_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_contract_type ON val_contract_type;
CREATE TRIGGER trigger_audit_val_contract_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_contract_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_contract_type();
DROP TRIGGER IF EXISTS trig_userlog_val_country_code ON val_country_code;
CREATE TRIGGER trig_userlog_val_country_code BEFORE INSERT OR UPDATE ON jazzhands.val_country_code FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_country_code ON val_country_code;
CREATE TRIGGER trigger_audit_val_country_code AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_country_code FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_country_code();
DROP TRIGGER IF EXISTS trig_userlog_val_device_collection_type ON val_device_collection_type;
CREATE TRIGGER trig_userlog_val_device_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_device_collection_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_device_collection_type ON val_device_collection_type;
CREATE TRIGGER trigger_audit_val_device_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_device_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_device_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_device_collection_type_bytype_del ON val_device_collection_type;
CREATE TRIGGER trigger_manip_device_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_device_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_device_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_device_collection_type_bytype_insup ON val_device_collection_type;
CREATE TRIGGER trigger_manip_device_collection_type_bytype_insup AFTER INSERT OR UPDATE OF device_collection_type ON jazzhands.val_device_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_device_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_device_management_controller_type ON val_device_management_controller_type;
CREATE TRIGGER trig_userlog_val_device_management_controller_type BEFORE INSERT OR UPDATE ON jazzhands.val_device_management_controller_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_device_management_controller_type ON val_device_management_controller_type;
CREATE TRIGGER trigger_audit_val_device_management_controller_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_device_management_controller_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_device_management_controller_type();
DROP TRIGGER IF EXISTS trig_userlog_val_device_status ON val_device_status;
CREATE TRIGGER trig_userlog_val_device_status BEFORE INSERT OR UPDATE ON jazzhands.val_device_status FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_device_status ON val_device_status;
CREATE TRIGGER trigger_audit_val_device_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_device_status FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_device_status();
DROP TRIGGER IF EXISTS trig_userlog_val_diet ON val_diet;
CREATE TRIGGER trig_userlog_val_diet BEFORE INSERT OR UPDATE ON jazzhands.val_diet FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_diet ON val_diet;
CREATE TRIGGER trigger_audit_val_diet AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_diet FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_diet();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_class ON val_dns_class;
CREATE TRIGGER trig_userlog_val_dns_class BEFORE INSERT OR UPDATE ON jazzhands.val_dns_class FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_class ON val_dns_class;
CREATE TRIGGER trigger_audit_val_dns_class AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_class FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_dns_class();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_domain_collection_type ON val_dns_domain_collection_type;
CREATE TRIGGER trig_userlog_val_dns_domain_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_dns_domain_collection_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_domain_collection_type ON val_dns_domain_collection_type;
CREATE TRIGGER trigger_audit_val_dns_domain_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_domain_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_dns_domain_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_dns_domain_collection_type_bytype_del ON val_dns_domain_collection_type;
CREATE TRIGGER trigger_manip_dns_domain_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_dns_domain_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_dns_domain_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_dns_domain_collection_type_bytype_insup ON val_dns_domain_collection_type;
CREATE TRIGGER trigger_manip_dns_domain_collection_type_bytype_insup AFTER INSERT OR UPDATE OF dns_domain_collection_type ON jazzhands.val_dns_domain_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_dns_domain_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_domain_type ON val_dns_domain_type;
CREATE TRIGGER trig_userlog_val_dns_domain_type BEFORE INSERT OR UPDATE ON jazzhands.val_dns_domain_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_domain_type ON val_dns_domain_type;
CREATE TRIGGER trigger_audit_val_dns_domain_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_domain_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_dns_domain_type();
DROP TRIGGER IF EXISTS trigger_dns_domain_type_should_generate ON val_dns_domain_type;
CREATE TRIGGER trigger_dns_domain_type_should_generate AFTER UPDATE OF can_generate ON jazzhands.val_dns_domain_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.dns_domain_type_should_generate();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_record_relation_type ON val_dns_record_relation_type;
CREATE TRIGGER trig_userlog_val_dns_record_relation_type BEFORE INSERT OR UPDATE ON jazzhands.val_dns_record_relation_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_record_relation_type ON val_dns_record_relation_type;
CREATE TRIGGER trigger_audit_val_dns_record_relation_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_record_relation_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_dns_record_relation_type();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_srv_service ON val_dns_srv_service;
CREATE TRIGGER trig_userlog_val_dns_srv_service BEFORE INSERT OR UPDATE ON jazzhands.val_dns_srv_service FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_srv_service ON val_dns_srv_service;
CREATE TRIGGER trigger_audit_val_dns_srv_service AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_srv_service FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_dns_srv_service();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_type ON val_dns_type;
CREATE TRIGGER trig_userlog_val_dns_type BEFORE INSERT OR UPDATE ON jazzhands.val_dns_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_type ON val_dns_type;
CREATE TRIGGER trigger_audit_val_dns_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_dns_type();
DROP TRIGGER IF EXISTS trig_userlog_val_encapsulation_mode ON val_encapsulation_mode;
CREATE TRIGGER trig_userlog_val_encapsulation_mode BEFORE INSERT OR UPDATE ON jazzhands.val_encapsulation_mode FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_encapsulation_mode ON val_encapsulation_mode;
CREATE TRIGGER trigger_audit_val_encapsulation_mode AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_encapsulation_mode FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_encapsulation_mode();
DROP TRIGGER IF EXISTS trig_userlog_val_encapsulation_type ON val_encapsulation_type;
CREATE TRIGGER trig_userlog_val_encapsulation_type BEFORE INSERT OR UPDATE ON jazzhands.val_encapsulation_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_encapsulation_type ON val_encapsulation_type;
CREATE TRIGGER trigger_audit_val_encapsulation_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_encapsulation_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_encapsulation_type();
DROP TRIGGER IF EXISTS trig_userlog_val_encryption_key_purpose ON val_encryption_key_purpose;
CREATE TRIGGER trig_userlog_val_encryption_key_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_encryption_key_purpose FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_encryption_key_purpose ON val_encryption_key_purpose;
CREATE TRIGGER trigger_audit_val_encryption_key_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_encryption_key_purpose FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_encryption_key_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_encryption_method ON val_encryption_method;
CREATE TRIGGER trig_userlog_val_encryption_method BEFORE INSERT OR UPDATE ON jazzhands.val_encryption_method FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_encryption_method ON val_encryption_method;
CREATE TRIGGER trigger_audit_val_encryption_method AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_encryption_method FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_encryption_method();
DROP TRIGGER IF EXISTS trig_userlog_val_filesystem_type ON val_filesystem_type;
CREATE TRIGGER trig_userlog_val_filesystem_type BEFORE INSERT OR UPDATE ON jazzhands.val_filesystem_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_filesystem_type ON val_filesystem_type;
CREATE TRIGGER trigger_audit_val_filesystem_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_filesystem_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_filesystem_type();
DROP TRIGGER IF EXISTS trig_userlog_val_gender ON val_gender;
CREATE TRIGGER trig_userlog_val_gender BEFORE INSERT OR UPDATE ON jazzhands.val_gender FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_gender ON val_gender;
CREATE TRIGGER trigger_audit_val_gender AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_gender FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_gender();
DROP TRIGGER IF EXISTS trig_userlog_val_image_type ON val_image_type;
CREATE TRIGGER trig_userlog_val_image_type BEFORE INSERT OR UPDATE ON jazzhands.val_image_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_image_type ON val_image_type;
CREATE TRIGGER trigger_audit_val_image_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_image_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_image_type();
DROP TRIGGER IF EXISTS trig_userlog_val_ip_namespace ON val_ip_namespace;
CREATE TRIGGER trig_userlog_val_ip_namespace BEFORE INSERT OR UPDATE ON jazzhands.val_ip_namespace FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_ip_namespace ON val_ip_namespace;
CREATE TRIGGER trigger_audit_val_ip_namespace AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_ip_namespace FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_ip_namespace();
DROP TRIGGER IF EXISTS trig_userlog_val_iso_currency_code ON val_iso_currency_code;
CREATE TRIGGER trig_userlog_val_iso_currency_code BEFORE INSERT OR UPDATE ON jazzhands.val_iso_currency_code FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_iso_currency_code ON val_iso_currency_code;
CREATE TRIGGER trigger_audit_val_iso_currency_code AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_iso_currency_code FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_iso_currency_code();
DROP TRIGGER IF EXISTS trig_userlog_val_key_usage_reason_for_assignment ON val_key_usage_reason_for_assignment;
CREATE TRIGGER trig_userlog_val_key_usage_reason_for_assignment BEFORE INSERT OR UPDATE ON jazzhands.val_key_usage_reason_for_assignment FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_key_usage_reason_for_assignment ON val_key_usage_reason_for_assignment;
CREATE TRIGGER trigger_audit_val_key_usage_reason_for_assignment AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_key_usage_reason_for_assignment FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_key_usage_reason_for_assignment();
DROP TRIGGER IF EXISTS trig_userlog_val_layer2_network_collection_type ON val_layer2_network_collection_type;
CREATE TRIGGER trig_userlog_val_layer2_network_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_layer2_network_collection_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_layer2_network_collection_type ON val_layer2_network_collection_type;
CREATE TRIGGER trigger_audit_val_layer2_network_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_layer2_network_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_layer2_network_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_layer2_network_collection_type_bytype_del ON val_layer2_network_collection_type;
CREATE TRIGGER trigger_manip_layer2_network_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_layer2_network_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_layer2_network_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_layer2_network_collection_type_bytype_insup ON val_layer2_network_collection_type;
CREATE TRIGGER trigger_manip_layer2_network_collection_type_bytype_insup AFTER INSERT OR UPDATE OF layer2_network_collection_type ON jazzhands.val_layer2_network_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_layer2_network_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_layer3_interface_purpose ON val_layer3_interface_purpose;
CREATE TRIGGER trig_userlog_val_layer3_interface_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_layer3_interface_purpose FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_layer3_interface_purpose ON val_layer3_interface_purpose;
CREATE TRIGGER trigger_audit_val_layer3_interface_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_layer3_interface_purpose FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_layer3_interface_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_layer3_interface_type ON val_layer3_interface_type;
CREATE TRIGGER trig_userlog_val_layer3_interface_type BEFORE INSERT OR UPDATE ON jazzhands.val_layer3_interface_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_layer3_interface_type ON val_layer3_interface_type;
CREATE TRIGGER trigger_audit_val_layer3_interface_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_layer3_interface_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_layer3_interface_type();
DROP TRIGGER IF EXISTS trig_userlog_val_layer3_network_collection_type ON val_layer3_network_collection_type;
CREATE TRIGGER trig_userlog_val_layer3_network_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_layer3_network_collection_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_layer3_network_collection_type ON val_layer3_network_collection_type;
CREATE TRIGGER trigger_audit_val_layer3_network_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_layer3_network_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_layer3_network_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_layer3_network_collection_type_bytype_del ON val_layer3_network_collection_type;
CREATE TRIGGER trigger_manip_layer3_network_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_layer3_network_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_layer3_network_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_layer3_network_collection_type_bytype_insup ON val_layer3_network_collection_type;
CREATE TRIGGER trigger_manip_layer3_network_collection_type_bytype_insup AFTER INSERT OR UPDATE OF layer3_network_collection_type ON jazzhands.val_layer3_network_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_layer3_network_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_logical_port_type ON val_logical_port_type;
CREATE TRIGGER trig_userlog_val_logical_port_type BEFORE INSERT OR UPDATE ON jazzhands.val_logical_port_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_logical_port_type ON val_logical_port_type;
CREATE TRIGGER trigger_audit_val_logical_port_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_logical_port_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_logical_port_type();
DROP TRIGGER IF EXISTS trig_userlog_val_logical_volume_property ON val_logical_volume_property;
CREATE TRIGGER trig_userlog_val_logical_volume_property BEFORE INSERT OR UPDATE ON jazzhands.val_logical_volume_property FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_logical_volume_property ON val_logical_volume_property;
CREATE TRIGGER trigger_audit_val_logical_volume_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_logical_volume_property FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_logical_volume_property();
DROP TRIGGER IF EXISTS trig_userlog_val_logical_volume_purpose ON val_logical_volume_purpose;
CREATE TRIGGER trig_userlog_val_logical_volume_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_logical_volume_purpose FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_logical_volume_purpose ON val_logical_volume_purpose;
CREATE TRIGGER trigger_audit_val_logical_volume_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_logical_volume_purpose FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_logical_volume_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_logical_volume_type ON val_logical_volume_type;
CREATE TRIGGER trig_userlog_val_logical_volume_type BEFORE INSERT OR UPDATE ON jazzhands.val_logical_volume_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_logical_volume_type ON val_logical_volume_type;
CREATE TRIGGER trigger_audit_val_logical_volume_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_logical_volume_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_logical_volume_type();
DROP TRIGGER IF EXISTS trig_userlog_val_netblock_collection_type ON val_netblock_collection_type;
CREATE TRIGGER trig_userlog_val_netblock_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_netblock_collection_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_netblock_collection_type ON val_netblock_collection_type;
CREATE TRIGGER trigger_audit_val_netblock_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_netblock_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_netblock_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_netblock_collection_type_bytype_del ON val_netblock_collection_type;
CREATE TRIGGER trigger_manip_netblock_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_netblock_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_netblock_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_netblock_collection_type_bytype_insup ON val_netblock_collection_type;
CREATE TRIGGER trigger_manip_netblock_collection_type_bytype_insup AFTER INSERT OR UPDATE OF netblock_collection_type ON jazzhands.val_netblock_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_netblock_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_netblock_status ON val_netblock_status;
CREATE TRIGGER trig_userlog_val_netblock_status BEFORE INSERT OR UPDATE ON jazzhands.val_netblock_status FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_netblock_status ON val_netblock_status;
CREATE TRIGGER trigger_audit_val_netblock_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_netblock_status FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_netblock_status();
DROP TRIGGER IF EXISTS trig_userlog_val_netblock_type ON val_netblock_type;
CREATE TRIGGER trig_userlog_val_netblock_type BEFORE INSERT OR UPDATE ON jazzhands.val_netblock_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_netblock_type ON val_netblock_type;
CREATE TRIGGER trigger_audit_val_netblock_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_netblock_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_netblock_type();
DROP TRIGGER IF EXISTS trig_userlog_val_network_range_type ON val_network_range_type;
CREATE TRIGGER trig_userlog_val_network_range_type BEFORE INSERT OR UPDATE ON jazzhands.val_network_range_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_network_range_type ON val_network_range_type;
CREATE TRIGGER trigger_audit_val_network_range_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_network_range_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_network_range_type();
DROP TRIGGER IF EXISTS trigger_validate_net_range_toggle_nonoverlap ON val_network_range_type;
CREATE CONSTRAINT TRIGGER trigger_validate_net_range_toggle_nonoverlap AFTER UPDATE OF can_overlap, require_cidr_boundary ON jazzhands.val_network_range_type DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_net_range_toggle_nonoverlap();
DROP TRIGGER IF EXISTS trigger_validate_val_network_range_type ON val_network_range_type;
CREATE CONSTRAINT TRIGGER trigger_validate_val_network_range_type AFTER UPDATE OF dns_domain_required, netblock_type ON jazzhands.val_network_range_type DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_val_network_range_type();
DROP TRIGGER IF EXISTS trig_userlog_val_network_service_type ON val_network_service_type;
CREATE TRIGGER trig_userlog_val_network_service_type BEFORE INSERT OR UPDATE ON jazzhands.val_network_service_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_network_service_type ON val_network_service_type;
CREATE TRIGGER trigger_audit_val_network_service_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_network_service_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_network_service_type();
DROP TRIGGER IF EXISTS trig_userlog_val_operating_system_family ON val_operating_system_family;
CREATE TRIGGER trig_userlog_val_operating_system_family BEFORE INSERT OR UPDATE ON jazzhands.val_operating_system_family FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_operating_system_family ON val_operating_system_family;
CREATE TRIGGER trigger_audit_val_operating_system_family AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_operating_system_family FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_operating_system_family();
DROP TRIGGER IF EXISTS trig_userlog_val_operating_system_snapshot_type ON val_operating_system_snapshot_type;
CREATE TRIGGER trig_userlog_val_operating_system_snapshot_type BEFORE INSERT OR UPDATE ON jazzhands.val_operating_system_snapshot_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_operating_system_snapshot_type ON val_operating_system_snapshot_type;
CREATE TRIGGER trigger_audit_val_operating_system_snapshot_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_operating_system_snapshot_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_operating_system_snapshot_type();
DROP TRIGGER IF EXISTS trig_userlog_val_ownership_status ON val_ownership_status;
CREATE TRIGGER trig_userlog_val_ownership_status BEFORE INSERT OR UPDATE ON jazzhands.val_ownership_status FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_ownership_status ON val_ownership_status;
CREATE TRIGGER trigger_audit_val_ownership_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_ownership_status FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_ownership_status();
DROP TRIGGER IF EXISTS trig_userlog_val_package_relation_type ON val_package_relation_type;
CREATE TRIGGER trig_userlog_val_package_relation_type BEFORE INSERT OR UPDATE ON jazzhands.val_package_relation_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_package_relation_type ON val_package_relation_type;
CREATE TRIGGER trigger_audit_val_package_relation_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_package_relation_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_package_relation_type();
DROP TRIGGER IF EXISTS trig_userlog_val_password_type ON val_password_type;
CREATE TRIGGER trig_userlog_val_password_type BEFORE INSERT OR UPDATE ON jazzhands.val_password_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_password_type ON val_password_type;
CREATE TRIGGER trigger_audit_val_password_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_password_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_password_type();
DROP TRIGGER IF EXISTS trig_userlog_val_person_company_attribute_data_type ON val_person_company_attribute_data_type;
CREATE TRIGGER trig_userlog_val_person_company_attribute_data_type BEFORE INSERT OR UPDATE ON jazzhands.val_person_company_attribute_data_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_company_attribute_data_type ON val_person_company_attribute_data_type;
CREATE TRIGGER trigger_audit_val_person_company_attribute_data_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_company_attribute_data_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_person_company_attribute_data_type();
DROP TRIGGER IF EXISTS trig_userlog_val_person_company_attribute_name ON val_person_company_attribute_name;
CREATE TRIGGER trig_userlog_val_person_company_attribute_name BEFORE INSERT OR UPDATE ON jazzhands.val_person_company_attribute_name FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_company_attribute_name ON val_person_company_attribute_name;
CREATE TRIGGER trigger_audit_val_person_company_attribute_name AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_company_attribute_name FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_person_company_attribute_name();
DROP TRIGGER IF EXISTS trig_userlog_val_person_company_attribute_value ON val_person_company_attribute_value;
CREATE TRIGGER trig_userlog_val_person_company_attribute_value BEFORE INSERT OR UPDATE ON jazzhands.val_person_company_attribute_value FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_company_attribute_value ON val_person_company_attribute_value;
CREATE TRIGGER trigger_audit_val_person_company_attribute_value AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_company_attribute_value FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_person_company_attribute_value();
DROP TRIGGER IF EXISTS trigger_person_company_attribute_change_after_row_hooks ON val_person_company_attribute_value;
CREATE TRIGGER trigger_person_company_attribute_change_after_row_hooks AFTER INSERT OR UPDATE ON jazzhands.val_person_company_attribute_value FOR EACH ROW EXECUTE PROCEDURE jazzhands.person_company_attribute_change_after_row_hooks();
DROP TRIGGER IF EXISTS trigger_validate_pers_comp_attr_value ON val_person_company_attribute_value;
CREATE TRIGGER trigger_validate_pers_comp_attr_value BEFORE DELETE OR UPDATE OF person_company_attribute_name, person_company_attribute_value ON jazzhands.val_person_company_attribute_value FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_pers_comp_attr_value();
DROP TRIGGER IF EXISTS trig_userlog_val_person_company_relation ON val_person_company_relation;
CREATE TRIGGER trig_userlog_val_person_company_relation BEFORE INSERT OR UPDATE ON jazzhands.val_person_company_relation FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_company_relation ON val_person_company_relation;
CREATE TRIGGER trigger_audit_val_person_company_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_company_relation FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_person_company_relation();
DROP TRIGGER IF EXISTS trig_userlog_val_person_contact_location_type ON val_person_contact_location_type;
CREATE TRIGGER trig_userlog_val_person_contact_location_type BEFORE INSERT OR UPDATE ON jazzhands.val_person_contact_location_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_contact_location_type ON val_person_contact_location_type;
CREATE TRIGGER trigger_audit_val_person_contact_location_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_contact_location_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_person_contact_location_type();
DROP TRIGGER IF EXISTS trig_userlog_val_person_contact_technology ON val_person_contact_technology;
CREATE TRIGGER trig_userlog_val_person_contact_technology BEFORE INSERT OR UPDATE ON jazzhands.val_person_contact_technology FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_contact_technology ON val_person_contact_technology;
CREATE TRIGGER trigger_audit_val_person_contact_technology AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_contact_technology FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_person_contact_technology();
DROP TRIGGER IF EXISTS trig_userlog_val_person_contact_type ON val_person_contact_type;
CREATE TRIGGER trig_userlog_val_person_contact_type BEFORE INSERT OR UPDATE ON jazzhands.val_person_contact_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_contact_type ON val_person_contact_type;
CREATE TRIGGER trigger_audit_val_person_contact_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_contact_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_person_contact_type();
DROP TRIGGER IF EXISTS trig_userlog_val_person_image_usage ON val_person_image_usage;
CREATE TRIGGER trig_userlog_val_person_image_usage BEFORE INSERT OR UPDATE ON jazzhands.val_person_image_usage FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_image_usage ON val_person_image_usage;
CREATE TRIGGER trigger_audit_val_person_image_usage AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_image_usage FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_person_image_usage();
DROP TRIGGER IF EXISTS trig_userlog_val_person_location_type ON val_person_location_type;
CREATE TRIGGER trig_userlog_val_person_location_type BEFORE INSERT OR UPDATE ON jazzhands.val_person_location_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_location_type ON val_person_location_type;
CREATE TRIGGER trigger_audit_val_person_location_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_location_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_person_location_type();
DROP TRIGGER IF EXISTS trig_userlog_val_person_status ON val_person_status;
CREATE TRIGGER trig_userlog_val_person_status BEFORE INSERT OR UPDATE ON jazzhands.val_person_status FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_status ON val_person_status;
CREATE TRIGGER trigger_audit_val_person_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_status FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_person_status();
DROP TRIGGER IF EXISTS trig_userlog_val_physical_address_type ON val_physical_address_type;
CREATE TRIGGER trig_userlog_val_physical_address_type BEFORE INSERT OR UPDATE ON jazzhands.val_physical_address_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_physical_address_type ON val_physical_address_type;
CREATE TRIGGER trigger_audit_val_physical_address_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_physical_address_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_physical_address_type();
DROP TRIGGER IF EXISTS trig_userlog_val_physicalish_volume_type ON val_physicalish_volume_type;
CREATE TRIGGER trig_userlog_val_physicalish_volume_type BEFORE INSERT OR UPDATE ON jazzhands.val_physicalish_volume_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_physicalish_volume_type ON val_physicalish_volume_type;
CREATE TRIGGER trigger_audit_val_physicalish_volume_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_physicalish_volume_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_physicalish_volume_type();
DROP TRIGGER IF EXISTS trig_userlog_val_private_key_encryption_type ON val_private_key_encryption_type;
CREATE TRIGGER trig_userlog_val_private_key_encryption_type BEFORE INSERT OR UPDATE ON jazzhands.val_private_key_encryption_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_private_key_encryption_type ON val_private_key_encryption_type;
CREATE TRIGGER trigger_audit_val_private_key_encryption_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_private_key_encryption_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_private_key_encryption_type();
DROP TRIGGER IF EXISTS trig_userlog_val_processor_architecture ON val_processor_architecture;
CREATE TRIGGER trig_userlog_val_processor_architecture BEFORE INSERT OR UPDATE ON jazzhands.val_processor_architecture FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_processor_architecture ON val_processor_architecture;
CREATE TRIGGER trigger_audit_val_processor_architecture AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_processor_architecture FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_processor_architecture();
DROP TRIGGER IF EXISTS trig_userlog_val_production_state ON val_production_state;
CREATE TRIGGER trig_userlog_val_production_state BEFORE INSERT OR UPDATE ON jazzhands.val_production_state FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_production_state ON val_production_state;
CREATE TRIGGER trigger_audit_val_production_state AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_production_state FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_production_state();
DROP TRIGGER IF EXISTS trig_userlog_val_property ON val_property;
CREATE TRIGGER trig_userlog_val_property BEFORE INSERT OR UPDATE ON jazzhands.val_property FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_property ON val_property;
CREATE TRIGGER trigger_audit_val_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_property FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_property();
DROP TRIGGER IF EXISTS trigger_validate_val_property ON val_property;
CREATE TRIGGER trigger_validate_val_property BEFORE INSERT OR UPDATE OF property_data_type, property_value_json_schema, permit_company_id ON jazzhands.val_property FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_val_property();
DROP TRIGGER IF EXISTS trigger_validate_val_property_after ON val_property;
CREATE CONSTRAINT TRIGGER trigger_validate_val_property_after AFTER UPDATE ON jazzhands.val_property DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_val_property_after();
DROP TRIGGER IF EXISTS trig_userlog_val_property_data_type ON val_property_data_type;
CREATE TRIGGER trig_userlog_val_property_data_type BEFORE INSERT OR UPDATE ON jazzhands.val_property_data_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_property_data_type ON val_property_data_type;
CREATE TRIGGER trigger_audit_val_property_data_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_property_data_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_property_data_type();
DROP TRIGGER IF EXISTS trig_userlog_val_property_name_collection_type ON val_property_name_collection_type;
CREATE TRIGGER trig_userlog_val_property_name_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_property_name_collection_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_property_name_collection_type ON val_property_name_collection_type;
CREATE TRIGGER trigger_audit_val_property_name_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_property_name_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_property_name_collection_type();
DROP TRIGGER IF EXISTS trig_userlog_val_property_type ON val_property_type;
CREATE TRIGGER trig_userlog_val_property_type BEFORE INSERT OR UPDATE ON jazzhands.val_property_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_property_type ON val_property_type;
CREATE TRIGGER trigger_audit_val_property_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_property_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_property_type();
DROP TRIGGER IF EXISTS trig_userlog_val_property_value ON val_property_value;
CREATE TRIGGER trig_userlog_val_property_value BEFORE INSERT OR UPDATE ON jazzhands.val_property_value FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_property_value ON val_property_value;
CREATE TRIGGER trigger_audit_val_property_value AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_property_value FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_property_value();
DROP TRIGGER IF EXISTS trigger_val_property_value_del_check ON val_property_value;
CREATE CONSTRAINT TRIGGER trigger_val_property_value_del_check AFTER DELETE ON jazzhands.val_property_value DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.val_property_value_del_check();
DROP TRIGGER IF EXISTS trig_userlog_val_rack_type ON val_rack_type;
CREATE TRIGGER trig_userlog_val_rack_type BEFORE INSERT OR UPDATE ON jazzhands.val_rack_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_rack_type ON val_rack_type;
CREATE TRIGGER trigger_audit_val_rack_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_rack_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_rack_type();
DROP TRIGGER IF EXISTS trig_userlog_val_raid_type ON val_raid_type;
CREATE TRIGGER trig_userlog_val_raid_type BEFORE INSERT OR UPDATE ON jazzhands.val_raid_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_raid_type ON val_raid_type;
CREATE TRIGGER trigger_audit_val_raid_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_raid_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_raid_type();
DROP TRIGGER IF EXISTS trig_userlog_val_service_environment_collection_type ON val_service_environment_collection_type;
CREATE TRIGGER trig_userlog_val_service_environment_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_environment_collection_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_environment_collection_type ON val_service_environment_collection_type;
CREATE TRIGGER trigger_audit_val_service_environment_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_environment_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_service_environment_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_service_environment_collection_type_bytype_del ON val_service_environment_collection_type;
CREATE TRIGGER trigger_manip_service_environment_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_service_environment_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_service_environment_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_service_environment_collection_type_bytype_insup ON val_service_environment_collection_type;
CREATE TRIGGER trigger_manip_service_environment_collection_type_bytype_insup AFTER INSERT OR UPDATE OF service_environment_collection_type ON jazzhands.val_service_environment_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.manip_service_environment_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_service_environment_type ON val_service_environment_type;
CREATE TRIGGER trig_userlog_val_service_environment_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_environment_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_environment_type ON val_service_environment_type;
CREATE TRIGGER trigger_audit_val_service_environment_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_environment_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_service_environment_type();
DROP TRIGGER IF EXISTS trig_userlog_val_shared_netblock_protocol ON val_shared_netblock_protocol;
CREATE TRIGGER trig_userlog_val_shared_netblock_protocol BEFORE INSERT OR UPDATE ON jazzhands.val_shared_netblock_protocol FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_shared_netblock_protocol ON val_shared_netblock_protocol;
CREATE TRIGGER trigger_audit_val_shared_netblock_protocol AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_shared_netblock_protocol FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_shared_netblock_protocol();
DROP TRIGGER IF EXISTS trig_userlog_val_slot_function ON val_slot_function;
CREATE TRIGGER trig_userlog_val_slot_function BEFORE INSERT OR UPDATE ON jazzhands.val_slot_function FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_slot_function ON val_slot_function;
CREATE TRIGGER trigger_audit_val_slot_function AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_slot_function FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_slot_function();
DROP TRIGGER IF EXISTS trig_userlog_val_slot_physical_interface ON val_slot_physical_interface;
CREATE TRIGGER trig_userlog_val_slot_physical_interface BEFORE INSERT OR UPDATE ON jazzhands.val_slot_physical_interface FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_slot_physical_interface ON val_slot_physical_interface;
CREATE TRIGGER trigger_audit_val_slot_physical_interface AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_slot_physical_interface FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_slot_physical_interface();
DROP TRIGGER IF EXISTS trig_userlog_val_ssh_key_type ON val_ssh_key_type;
CREATE TRIGGER trig_userlog_val_ssh_key_type BEFORE INSERT OR UPDATE ON jazzhands.val_ssh_key_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_ssh_key_type ON val_ssh_key_type;
CREATE TRIGGER trigger_audit_val_ssh_key_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_ssh_key_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_ssh_key_type();
DROP TRIGGER IF EXISTS trig_userlog_val_sw_package_type ON val_sw_package_type;
CREATE TRIGGER trig_userlog_val_sw_package_type BEFORE INSERT OR UPDATE ON jazzhands.val_sw_package_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_sw_package_type ON val_sw_package_type;
CREATE TRIGGER trigger_audit_val_sw_package_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_sw_package_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_sw_package_type();
DROP TRIGGER IF EXISTS trig_userlog_val_token_collection_type ON val_token_collection_type;
CREATE TRIGGER trig_userlog_val_token_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_token_collection_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_token_collection_type ON val_token_collection_type;
CREATE TRIGGER trigger_audit_val_token_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_token_collection_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_token_collection_type();
DROP TRIGGER IF EXISTS trig_userlog_val_token_status ON val_token_status;
CREATE TRIGGER trig_userlog_val_token_status BEFORE INSERT OR UPDATE ON jazzhands.val_token_status FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_token_status ON val_token_status;
CREATE TRIGGER trigger_audit_val_token_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_token_status FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_token_status();
DROP TRIGGER IF EXISTS trig_userlog_val_token_type ON val_token_type;
CREATE TRIGGER trig_userlog_val_token_type BEFORE INSERT OR UPDATE ON jazzhands.val_token_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_token_type ON val_token_type;
CREATE TRIGGER trigger_audit_val_token_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_token_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_token_type();
DROP TRIGGER IF EXISTS trig_userlog_val_volume_group_purpose ON val_volume_group_purpose;
CREATE TRIGGER trig_userlog_val_volume_group_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_volume_group_purpose FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_volume_group_purpose ON val_volume_group_purpose;
CREATE TRIGGER trigger_audit_val_volume_group_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_volume_group_purpose FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_volume_group_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_volume_group_relation ON val_volume_group_relation;
CREATE TRIGGER trig_userlog_val_volume_group_relation BEFORE INSERT OR UPDATE ON jazzhands.val_volume_group_relation FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_volume_group_relation ON val_volume_group_relation;
CREATE TRIGGER trigger_audit_val_volume_group_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_volume_group_relation FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_volume_group_relation();
DROP TRIGGER IF EXISTS trig_userlog_val_volume_group_type ON val_volume_group_type;
CREATE TRIGGER trig_userlog_val_volume_group_type BEFORE INSERT OR UPDATE ON jazzhands.val_volume_group_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_volume_group_type ON val_volume_group_type;
CREATE TRIGGER trigger_audit_val_volume_group_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_volume_group_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_volume_group_type();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_certificate_file_format ON val_x509_certificate_file_format;
CREATE TRIGGER trig_userlog_val_x509_certificate_file_format BEFORE INSERT OR UPDATE ON jazzhands.val_x509_certificate_file_format FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_certificate_file_format ON val_x509_certificate_file_format;
CREATE TRIGGER trigger_audit_val_x509_certificate_file_format AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_certificate_file_format FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_x509_certificate_file_format();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_certificate_type ON val_x509_certificate_type;
CREATE TRIGGER trig_userlog_val_x509_certificate_type BEFORE INSERT OR UPDATE ON jazzhands.val_x509_certificate_type FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_certificate_type ON val_x509_certificate_type;
CREATE TRIGGER trigger_audit_val_x509_certificate_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_certificate_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_x509_certificate_type();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_key_usage ON val_x509_key_usage;
CREATE TRIGGER trig_userlog_val_x509_key_usage BEFORE INSERT OR UPDATE ON jazzhands.val_x509_key_usage FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_key_usage ON val_x509_key_usage;
CREATE TRIGGER trigger_audit_val_x509_key_usage AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_key_usage FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_x509_key_usage();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_key_usage_category ON val_x509_key_usage_category;
CREATE TRIGGER trig_userlog_val_x509_key_usage_category BEFORE INSERT OR UPDATE ON jazzhands.val_x509_key_usage_category FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_key_usage_category ON val_x509_key_usage_category;
CREATE TRIGGER trigger_audit_val_x509_key_usage_category AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_key_usage_category FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_x509_key_usage_category();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_revocation_reason ON val_x509_revocation_reason;
CREATE TRIGGER trig_userlog_val_x509_revocation_reason BEFORE INSERT OR UPDATE ON jazzhands.val_x509_revocation_reason FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_revocation_reason ON val_x509_revocation_reason;
CREATE TRIGGER trigger_audit_val_x509_revocation_reason AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_revocation_reason FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_val_x509_revocation_reason();
DROP TRIGGER IF EXISTS trig_userlog_volume_group ON volume_group;
CREATE TRIGGER trig_userlog_volume_group BEFORE INSERT OR UPDATE ON jazzhands.volume_group FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_volume_group ON volume_group;
CREATE TRIGGER trigger_audit_volume_group AFTER INSERT OR DELETE OR UPDATE ON jazzhands.volume_group FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_volume_group();
DROP TRIGGER IF EXISTS trig_userlog_volume_group_physicalish_volume ON volume_group_physicalish_volume;
CREATE TRIGGER trig_userlog_volume_group_physicalish_volume BEFORE INSERT OR UPDATE ON jazzhands.volume_group_physicalish_volume FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_volume_group_physicalish_volume ON volume_group_physicalish_volume;
CREATE TRIGGER trigger_audit_volume_group_physicalish_volume AFTER INSERT OR DELETE OR UPDATE ON jazzhands.volume_group_physicalish_volume FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_volume_group_physicalish_volume();
DROP TRIGGER IF EXISTS trig_userlog_volume_group_purpose ON volume_group_purpose;
CREATE TRIGGER trig_userlog_volume_group_purpose BEFORE INSERT OR UPDATE ON jazzhands.volume_group_purpose FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_volume_group_purpose ON volume_group_purpose;
CREATE TRIGGER trigger_audit_volume_group_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.volume_group_purpose FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_volume_group_purpose();
DROP TRIGGER IF EXISTS trig_userlog_x509_key_usage_attribute ON x509_key_usage_attribute;
CREATE TRIGGER trig_userlog_x509_key_usage_attribute BEFORE INSERT OR UPDATE ON jazzhands.x509_key_usage_attribute FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_x509_key_usage_attribute ON x509_key_usage_attribute;
CREATE TRIGGER trigger_audit_x509_key_usage_attribute AFTER INSERT OR DELETE OR UPDATE ON jazzhands.x509_key_usage_attribute FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_x509_key_usage_attribute();
DROP TRIGGER IF EXISTS trig_userlog_x509_key_usage_categorization ON x509_key_usage_categorization;
CREATE TRIGGER trig_userlog_x509_key_usage_categorization BEFORE INSERT OR UPDATE ON jazzhands.x509_key_usage_categorization FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_x509_key_usage_categorization ON x509_key_usage_categorization;
CREATE TRIGGER trigger_audit_x509_key_usage_categorization AFTER INSERT OR DELETE OR UPDATE ON jazzhands.x509_key_usage_categorization FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_x509_key_usage_categorization();
DROP TRIGGER IF EXISTS trig_userlog_x509_key_usage_default ON x509_key_usage_default;
CREATE TRIGGER trig_userlog_x509_key_usage_default BEFORE INSERT OR UPDATE ON jazzhands.x509_key_usage_default FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_x509_key_usage_default ON x509_key_usage_default;
CREATE TRIGGER trigger_audit_x509_key_usage_default AFTER INSERT OR DELETE OR UPDATE ON jazzhands.x509_key_usage_default FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_x509_key_usage_default();
DROP TRIGGER IF EXISTS trig_userlog_x509_signed_certificate ON x509_signed_certificate;
CREATE TRIGGER trig_userlog_x509_signed_certificate BEFORE INSERT OR UPDATE ON jazzhands.x509_signed_certificate FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_x509_signed_certificate ON x509_signed_certificate;
CREATE TRIGGER trigger_audit_x509_signed_certificate AFTER INSERT OR DELETE OR UPDATE ON jazzhands.x509_signed_certificate FOR EACH ROW EXECUTE PROCEDURE jazzhands.perform_audit_x509_signed_certificate();
DROP TRIGGER IF EXISTS trigger_x509_signed_ski_pvtkey_validate ON x509_signed_certificate;
CREATE TRIGGER trigger_x509_signed_ski_pvtkey_validate AFTER INSERT OR UPDATE OF subject_key_identifier, private_key_id ON jazzhands.x509_signed_certificate FOR EACH ROW EXECUTE PROCEDURE jazzhands.x509_signed_ski_pvtkey_validate();

--
-- BEGIN: Procesing things saved for end
--
SAVEPOINT beforerecreate;

--
-- END: Procesing things saved for end
--

SELECT schema_support.replay_object_recreates(beverbose := true);
SELECT schema_support.replay_saved_grants(beverbose := true);

--
-- BEGIN: Running final cache table sync
SELECT schema_support.synchronize_cache_tables();

--
-- END: Running final cache table sync
SELECT schema_support.reset_all_schema_table_sequences('jazzhands');
SELECT schema_support.reset_all_schema_table_sequences('jazzhands_audit');
GRANT select on all tables in schema jazzhands to ro_role;
GRANT insert,update,delete on all tables in schema jazzhands to iud_role;
GRANT insert,update,delete on all tables in schema jazzhands_legacy to iud_role;
GRANT select on all sequences in schema jazzhands to ro_role;
GRANT usage on all sequences in schema jazzhands to iud_role;
GRANT select on all tables in schema jazzhands_audit to ro_role;
GRANT select on all sequences in schema jazzhands_audit to ro_role;
GRANT select on all tables in schema audit to ro_role;
GRANT select on all sequences in schema audit to ro_role;
SELECT schema_support.end_maintenance();
SAVEPOINT maintend;
select clock_timestamp(), now(), clock_timestamp() - now() AS len;
