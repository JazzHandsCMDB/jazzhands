/*
 * Copyright (c) 2010-2019 Todd Kover
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

/*
 * Copyright (c) 2010-2019 Matthew Ragan
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
		COMMENT ON SCHEMA schema_support IS 'part of jazzhands';

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

CREATE OR REPLACE FUNCTION schema_support.reset_table_sequence
    ( schema VARCHAR, table_name VARCHAR )
RETURNS VOID AS $$
DECLARE
	_r	RECORD;
	m	BIGINT;
BEGIN
	FOR _r IN
		WITH s AS (
			SELECT	pg_get_serial_sequence(schema||'.'||table_name,
				a.attname) as seq, a.attname as column
			FROM	pg_attribute a
			JOIN pg_class c ON c.oid = a.attrelid
			JOIN pg_namespace n ON n.oid = c.relnamespace
			WHERE	c.relname = table_name
			AND	n.nspname = schema
				AND	a.attnum > 0
				AND	NOT a.attisdropped
		) SELECT s.*, nextval(s.seq) as nv FROM s WHERE seq IS NOT NULL
	LOOP
		EXECUTE 'SELECT max('||quote_ident(_r.column)||')+1 FROM  '
			|| quote_ident(schema)||'.'||quote_ident(table_name)
			INTO m;
		IF m IS NOT NULL THEN
			IF _r.nv > m THEN
				m := _r.nv;
			END IF;
			EXECUTE 'ALTER SEQUENCE ' || _r.seq || ' RESTART WITH '
				|| m;
		END IF;
	END LOOP;
END;
$$
SET search_path=schema_support
LANGUAGE plpgsql SECURITY INVOKER;

CREATE OR REPLACE FUNCTION schema_support.reset_all_schema_table_sequences
    ( schema TEXT )
RETURNS INTEGER AS $$
DECLARE
	_r	RECORD;
	tally INTEGER;
BEGIN
	tally := 0;
	FOR _r IN

		SELECT n.nspname, c.relname, c.relkind
		FROM	pg_class c
				INNER JOIN pg_namespace n ON n.oid = c.relnamespace
		WHERE	n.nspname = schema
		AND		c.relkind = 'r'
	LOOP
		PERFORM schema_support.reset_table_sequence(_r.nspname::text, _r.relname::text);
		tally := tally + 1;
	END LOOP;
	RETURN tally;
END;
$$
SET search_path=schema_support
LANGUAGE plpgsql SECURITY INVOKER;

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

CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_table_finish(
	aud_schema VARCHAR, tbl_schema VARCHAR, table_name VARCHAR
)
RETURNS VOID AS $FUNC$
DECLARE
	cols	text[];
	i	text;
BEGIN
	--
	-- get columns - XXX NOTE:  Need to remove columns not in the new
	-- table...
	--
	SELECT	array_agg(quote_ident(a.attname) ORDER BY a.attnum)
	INTO	cols
	FROM	pg_catalog.pg_attribute a
	INNER JOIN pg_catalog.pg_class c on a.attrelid = c.oid
	INNER JOIN pg_catalog.pg_namespace n on n.oid = c.relnamespace
	LEFT JOIN pg_catalog.pg_description d
			on d.objoid = a.attrelid
			and d.objsubid = a.attnum
	WHERE   n.nspname = quote_ident(aud_schema)
	  AND	c.relname = quote_ident('__old__' || table_name)
	  AND	a.attnum > 0
	  AND	NOT a.attisdropped
	;

	EXECUTE 'INSERT INTO '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident(table_name) || ' ( '
		|| array_to_string(cols, ',') || ' ) SELECT '
		|| array_to_string(cols, ',') || ' FROM '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident('__old__' || table_name)
		|| ' ORDER BY '
		|| quote_ident('aud#seq');


	EXECUTE 'DROP TABLE '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident('__old__' || table_name);

	--
	-- drop audit sequence, in case it was not dropped with table.
	--
	EXECUTE 'DROP SEQUENCE IF EXISTS '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident('_old_' || table_name || '_seq');

	--
	-- drop indexes found before that did not get dropped.
	--
	FOR i IN SELECT	c2.relname
		  FROM	pg_catalog.pg_index i
			LEFT JOIN pg_catalog.pg_class c
				ON c.oid = i.indrelid
			LEFT JOIN pg_catalog.pg_class c2
				ON i.indexrelid = c2.oid
			LEFT JOIN pg_catalog.pg_namespace n
				ON c2.relnamespace = n.oid
			LEFT JOIN pg_catalog.pg_constraint con
				ON (conrelid = i.indrelid
				AND conindid = i.indexrelid
				AND contype IN ('p','u','x'))
		 WHERE n.nspname = quote_ident(aud_schema)
		  AND	c.relname = quote_ident('__old__' || table_name)
		  AND	contype is NULL
	LOOP
		EXECUTE 'DROP INDEX '
			|| quote_ident(aud_schema) || '.'
			|| quote_ident('_' || i);
	END LOOP;
END;
$FUNC$ LANGUAGE plpgsql;

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_table(
	aud_schema VARCHAR, tbl_schema VARCHAR, table_name VARCHAR,
	finish_rebuild BOOLEAN DEFAULT true
)
RETURNS VOID AS $FUNC$
DECLARE
	idx		text[];
	keys		text[];
	i		text;
	seq		integer;
BEGIN
	-- rename all the old indexes and constraints on the old audit table
	SELECT	array_agg(c2.relname)
		INTO	 idx
		  FROM	pg_catalog.pg_index i
			LEFT JOIN pg_catalog.pg_class c
				ON c.oid = i.indrelid
			LEFT JOIN pg_catalog.pg_class c2
				ON i.indexrelid = c2.oid
			LEFT JOIN pg_catalog.pg_namespace n
				ON c2.relnamespace = n.oid
			LEFT JOIN pg_catalog.pg_constraint con
				ON (conrelid = i.indrelid
				AND conindid = i.indexrelid
				AND contype IN ('p','u','x'))
		 WHERE n.nspname = quote_ident(aud_schema)
		  AND	c.relname = quote_ident(table_name)
		  AND	contype is NULL
	;

	SELECT array_agg(con.conname)
	INTO	keys
    FROM pg_catalog.pg_class c
		INNER JOIN pg_namespace n
			ON relnamespace = n.oid
		INNER JOIN pg_catalog.pg_index i
			ON c.oid = i.indrelid
		INNER JOIN pg_catalog.pg_class c2
			ON i.indexrelid = c2.oid
		INNER JOIN pg_catalog.pg_constraint con ON
			(con.conrelid = i.indrelid
			AND con.conindid = i.indexrelid )
	WHERE		n.nspname = quote_ident(aud_schema)
	AND		c.relname = quote_ident(table_name)
	AND con.contype in ('p', 'u')
	;

	IF idx IS NOT NULL THEN
		FOREACH i IN ARRAY idx
		LOOP
			EXECUTE 'ALTER INDEX '
				|| quote_ident(aud_schema) || '.'
				|| quote_ident(i)
				|| ' RENAME TO '
				|| quote_ident('_' || i);
		END LOOP;
	END IF;

	IF array_length(keys, 1) > 0 THEN
		FOREACH i IN ARRAY keys
		LOOP
			EXECUTE 'ALTER TABLE '
				|| quote_ident(aud_schema) || '.'
				|| quote_ident(table_name)
				|| ' RENAME CONSTRAINT '
				|| quote_ident(i)
				|| ' TO '
			|| quote_ident('__old__' || i);
		END LOOP;
	END IF;

	--
	-- rename table
	--
	EXECUTE 'ALTER TABLE '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident(table_name)
		|| ' RENAME TO '
		|| quote_ident('__old__' || table_name);


	--
	-- RENAME sequence
	--
	EXECUTE 'ALTER SEQUENCE '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident(table_name || '_seq')
		|| ' RENAME TO '
		|| quote_ident('_old_' || table_name || '_seq');

	--
	-- create a new audit table
	--
	PERFORM schema_support.build_audit_table(aud_schema,tbl_schema,table_name);

	--
	-- fix sequence primary key to have the correct next value
	--
	EXECUTE 'SELECT max("aud#seq") + 1 FROM	 '
			|| quote_ident(aud_schema) || '.'
			|| quote_ident('__old__' || table_name) INTO seq;
	IF seq IS NOT NULL THEN
		EXECUTE 'ALTER SEQUENCE '
			|| quote_ident(aud_schema) || '.'
			|| quote_ident(table_name || '_seq')
			|| ' RESTART WITH ' || seq;
	END IF;

	IF finish_rebuild THEN
		EXECUTE schema_support.rebuild_audit_table_finish(aud_schema,tbl_schema,table_name);
	END IF;

	--
	-- recreate audit trigger
	--
	PERFORM schema_support.rebuild_audit_trigger (
		aud_schema, tbl_schema, table_name );

END;
$FUNC$ LANGUAGE plpgsql;

-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION schema_support.build_audit_table_pkak_indexes(
	aud_schema VARCHAR, tbl_schema VARCHAR, table_name VARCHAR
)
RETURNS VOID AS $FUNC$
DECLARE
	keys	RECORD;
	count	INTEGER;
	name	TEXT;
BEGIN
	COUNT := 0;
	-- one day, I will want to construct the list of columns by hand rather
	-- than use pg_get_constraintdef.  watch me...
	FOR keys IN
		SELECT con.conname, c2.relname as index_name,
			pg_catalog.pg_get_constraintdef(con.oid, true) as condef,
				regexp_replace(
			pg_catalog.pg_get_constraintdef(con.oid, true),
					'^.*(\([^\)]+\)).*$', '\1') as cols,
			con.condeferrable,
			con.condeferred
		FROM pg_catalog.pg_class c
			INNER JOIN pg_namespace n
				ON relnamespace = n.oid
			INNER JOIN pg_catalog.pg_index i
				ON c.oid = i.indrelid
			INNER JOIN pg_catalog.pg_class c2
				ON i.indexrelid = c2.oid
			INNER JOIN pg_catalog.pg_constraint con ON
				(con.conrelid = i.indrelid
				AND con.conindid = i.indexrelid )
		WHERE c.relname =  table_name
		AND	 n.nspname = tbl_schema
		AND con.contype in ('p', 'u')
	LOOP
		name := 'aud_' || quote_ident( table_name || '_' || keys.conname);
		IF char_length(name) > 63 THEN
			name := 'aud_' || count || quote_ident( table_name || '_' || keys.conname);
			COUNT := COUNT + 1;
		END IF;
		EXECUTE 'CREATE INDEX ' || name
			|| ' ON ' || quote_ident(aud_schema) || '.'
			|| quote_ident(table_name) || keys.cols;
	END LOOP;

END;
$FUNC$ LANGUAGE plpgsql;

-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION schema_support.build_audit_table_other_indexes(
	aud_schema VARCHAR, tbl_schema VARCHAR, table_name VARCHAR
)
RETURNS VOID AS $FUNC$
DECLARE
	_r	RECORD;
	sch	TEXT;
BEGIN
	-- one day, I will want to construct the list of columns by hand rather
	-- than use pg_get_constraintdef.  watch me...

	sch := quote_ident( aud_schema );
	FOR _r IN
		SELECT c2.relname, pg_get_indexdef(i.indexrelid) as def, con.contype
	FROM pg_catalog.pg_class c
	    INNER JOIN pg_namespace n
		ON relnamespace = n.oid
	    INNER JOIN pg_catalog.pg_index i
		ON c.oid = i.indrelid
	    INNER JOIN pg_catalog.pg_class c2
		ON i.indexrelid = c2.oid
	   LEFT JOIN pg_catalog.pg_constraint con ON
		(con.conrelid = i.indrelid
		AND con.conindid = i.indexrelid )
	WHERE c.relname =  table_name
	AND      n.nspname = tbl_schema
	AND	con.contype IS NULL

	LOOP
		_r.def := regexp_replace(_r.def, ' ON ', ' ON ' || sch || '.');
		EXECUTE _r.def;
	END LOOP;

END;
$FUNC$ LANGUAGE plpgsql;


-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION schema_support.build_audit_table(
	aud_schema VARCHAR, tbl_schema VARCHAR, table_name VARCHAR,
	first_time boolean DEFAULT true
)
RETURNS VOID AS $FUNC$
BEGIN
	BEGIN
	EXECUTE 'CREATE SEQUENCE ' || quote_ident(aud_schema) || '.'
		|| quote_ident(table_name || '_seq');
	EXCEPTION WHEN duplicate_table THEN
		NULL;
	END;

	EXECUTE 'CREATE TABLE ' || quote_ident(aud_schema) || '.'
		|| quote_ident(table_name) || ' AS '
		|| 'SELECT *, NULL::char(3) as "aud#action", now() as "aud#timestamp", '
		|| 'clock_timestamp() as "aud#realtime", '
		|| 'txid_current() as "aud#txid", '
		|| 'NULL::varchar(255) AS "aud#user", NULL::integer AS "aud#seq" '
		|| 'FROM ' || quote_ident(tbl_schema) || '.' || quote_ident(table_name)
		|| ' LIMIT 0';

	EXECUTE 'ALTER TABLE ' || quote_ident(aud_schema) || '.'
		|| quote_ident(table_name)
		|| $$ ALTER COLUMN "aud#seq" SET NOT NULL, $$
		|| $$ ALTER COLUMN "aud#seq" SET DEFAULT nextval('$$
		|| quote_ident(aud_schema) || '.' || quote_ident(table_name || '_seq')
		|| $$')$$;

	EXECUTE 'ALTER SEQUENCE ' || quote_ident(aud_schema) || '.'
		|| quote_ident(table_name || '_seq') || ' OWNED BY '
		|| quote_ident(aud_schema) || '.' || quote_ident(table_name)
		|| '.' || quote_ident('aud#seq');


	EXECUTE 'CREATE INDEX '
		|| quote_ident( table_name || '_aud#timestamp_idx')
		|| ' ON ' || quote_ident(aud_schema) || '.'
		|| quote_ident(table_name) || '("aud#timestamp")';

	EXECUTE 'CREATE INDEX '
		|| quote_ident( table_name || '_aud#realtime_idx')
		|| ' ON ' || quote_ident(aud_schema) || '.'
		|| quote_ident(table_name) || '("aud#realtime")';

	EXECUTE 'CREATE INDEX '
		|| quote_ident( table_name || '_aud#txid_idx')
		|| ' ON ' || quote_ident(aud_schema) || '.'
		|| quote_ident(table_name) || '("aud#txid")';

	EXECUTE 'ALTER TABLE ' || quote_ident(aud_schema) || '.'
		|| quote_ident( table_name )
		|| ' ADD PRIMARY KEY ("aud#seq")';

	PERFORM schema_support.build_audit_table_pkak_indexes(
		aud_schema, tbl_schema, table_name);

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

--
-- rebuilds all existing audit tables.  This is used when new columns are
-- added or there's some other reason to want to do it.
--
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_tables
    ( aud_schema varchar, tbl_schema varchar )
RETURNS VOID AS $FUNC$
DECLARE
     table_list RECORD;
BEGIN
    FOR table_list IN
	SELECT b.table_name
	FROM information_schema.tables b
		INNER JOIN information_schema.tables a
			USING (table_name,table_type)
	WHERE table_type = 'BASE TABLE'
	AND a.table_schema = aud_schema
	AND b.table_schema = tbl_schema
	ORDER BY table_name
    LOOP
	PERFORM schema_support.save_dependent_objects_for_replay(aud_schema::varchar, table_list.table_name::varchar);
	PERFORM schema_support.save_grants_for_replay(aud_schema, table_list.table_name);
	PERFORM schema_support.rebuild_audit_table
	    ( aud_schema, tbl_schema, table_list.table_name );
	PERFORM schema_support.replay_object_recreates();
	PERFORM schema_support.replay_saved_grants();
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
	appuser := concat_ws('/', session_user,
		coalesce(
			current_setting('jazzhands.appuser', true),
			current_setting('request.header.x-remote-user', true)
		)
	);
    appuser = substr(appuser, 1, 255);

    IF TG_OP = 'INSERT' THEN
	NEW.data_ins_user = appuser;
	NEW.data_ins_date = 'now';
    END IF;

    IF TG_OP = 'UPDATE' AND OLD != NEW THEN
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

	-- Handle table wide grants
	FOR _tabs IN SELECT  n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'm' THEN 'view'
				WHEN 'v' THEN 'mview'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as "Type",
			c.relacl as privs
		FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
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

	-- Handle column specific wide grants
	FOR _tabs IN SELECT  n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'v' THEN 'view'
				WHEN 'mv' THEN 'mview'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as "Type",
			a.attname as col,
			a.attacl as privs
		FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
			INNER JOIN pg_attribute a
		ON a.attrelid = c.oid
		WHERE c.relkind IN ('r', 'v', 'S', 'f')
		  AND a.attacl IS NOT NULL
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
				_perm.privilege_type || '(' || _tabs.col || ')'
				' on ' ||
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
		IF beverbose THEN
			RAISE NOTICE '**** WARNING: replay_saved_grants did NOT have anything to regrant!';
		END IF;
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
-- dependent views and having a migration script recreate them.
--
CREATE OR REPLACE FUNCTION schema_support.save_view_for_replay(
	schema varchar,
	object varchar,
	dropit boolean DEFAULT true
) RETURNS VOID AS $$
DECLARE
	_r		RECORD;
	_c		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
	_mat	TEXT;
	_typ	TEXT;
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

	-- implicitly save regrants
	PERFORM schema_support.save_grants_for_replay(schema, object);

	-- save any triggers on the view
	PERFORM schema_support.save_trigger_for_replay(schema, object, dropit);

	-- now save the view
	FOR _r in SELECT c.oid, n.nspname, c.relname, 'view',
				coalesce(u.usename, 'public') as owner,
				pg_get_viewdef(c.oid, true) as viewdef, relkind
		FROM pg_class c
		INNER JOIN pg_namespace n on n.oid = c.relnamespace
		LEFT JOIN pg_user u on u.usesysid = c.relowner
		WHERE c.relname = object
		AND n.nspname = schema
	LOOP
		--
		-- iterate through all the columns on this view with comments or
		-- defaults and reserve them
		--
		FOR _c IN SELECT * FROM ( SELECT a.attname AS colname,
					pg_catalog.format_type(a.atttypid, a.atttypmod) AS coltype,
					(
						SELECT substring(pg_catalog.pg_get_expr(d.adbin, d.adrelid)
								FOR 128)
						FROM pg_catalog.pg_attrdef d
						WHERE
							d.adrelid = a.attrelid
							AND d.adnum = a.attnum
							AND a.atthasdef) AS def, a.attnotnull, a.attnum, (
							SELECT c.collname
							FROM pg_catalog.pg_collation c, pg_catalog.pg_type t
							WHERE
								c.oid = a.attcollation
								AND t.oid = a.atttypid
								AND a.attcollation <> t.typcollation) AS attcollation, d.description AS COMMENT
						FROM pg_catalog.pg_attribute a
						LEFT JOIN pg_catalog.pg_description d ON d.objoid = a.attrelid
							AND d.objsubid = a.attnum
					WHERE
						a.attrelid = _r.oid
						AND a.attnum > 0
						AND NOT a.attisdropped
					ORDER BY a.attnum
			) x WHERE def IS NOT NULL OR COMMENT IS NOT NULL
		LOOP
			IF _c.def IS NOT NULL THEN
				_ddl := 'ALTER VIEW ' || quote_ident(schema) || '.' ||
					quote_ident(object) || ' ALTER COLUMN ' ||
					quote_ident(_c.colname) || ' SET DEFAULT ' || _c.def;
				INSERT INTO __recreate (schema, object, type, ddl )
					VALUES (
						_r.nspname, _r.relname, 'default', _ddl
					);
			END IF;
			IF _c.comment IS NOT NULL THEN
				_ddl := 'COMMENT ON COLUMN ' ||
					quote_ident(schema) || '.' || quote_ident(object)
					' IS ''' || _c.comment || '''';
				INSERT INTO __recreate (schema, object, type, ddl )
					VALUES (
						_r.nspname, _r.relname, 'colcomment', _ddl
					);
			END IF;

		END LOOP;

		_mat = ' VIEW ';
		_typ = 'view';
		IF _r.relkind = 'm' THEN
			_mat = ' MATERIALIZED VIEW ';
			_typ = 'materialized view';
		END IF;
		_ddl := 'CREATE ' || _mat || _r.nspname || '.' || _r.relname ||
			' AS ' || _r.viewdef;
		IF _ddl is NULL THEN
			RAISE EXCEPTION 'Unable to define view for %', _r;
		END IF;
		INSERT INTO __recreate (schema, object, owner, type, ddl )
			VALUES (
				_r.nspname, _r.relname, _r.owner, _typ, _ddl
			);
		IF dropit  THEN
			_cmd = 'DROP ' || _mat || _r.nspname || '.' || _r.relname || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

--
-- NEED:  something to drop an object (view or function), save grants and deal with dependencies
-- probably want a restore everything function too
--

--
-- Saves relations dependent on an object for reply.
--
CREATE OR REPLACE FUNCTION schema_support.save_dependent_objects_for_replay(
	schema varchar,
	object varchar,
	dropit boolean DEFAULT true,
	doobjectdeps boolean DEFAULT false
) RETURNS VOID AS $$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	RAISE DEBUG 'processing %.%', schema, object;
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
		-- RAISE NOTICE '1 dealing with  %.%', _r.nspname, _r.proname;
		PERFORM schema_support.save_constraint_for_replay(_r.nspname, _r.proname, dropit);
		PERFORM schema_support.save_dependent_objects_for_replay(_r.nspname, _r.proname, dropit);
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
		IF _r.relkind = 'v' OR _r.relkind = 'm' THEN
			-- RAISE NOTICE '2 dealing with  %.%', _r.nspname, _r.relname;
			PERFORM * FROM save_dependent_objects_for_replay(_r.nspname, _r.relname, dropit);
			PERFORM schema_support.save_view_for_replay(_r.nspname, _r.relname, dropit);
		END IF;
	END LOOP;
	IF doobjectdeps THEN
		PERFORM schema_support.save_trigger_for_replay(schema, object, dropit);
		PERFORM schema_support.save_constraint_for_replay('jazzhands', 'table');
	END IF;
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

	FOR _r in	SELECT n.nspname, c.relname, con.conname,
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
-- dependent functions and having a migration script recreate them.
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
    _origsp TEXT;
BEGIN
	SELECT	count(*)
	  INTO	_tally
	  FROM	pg_catalog.pg_class
	 WHERE	relname = '__recreate'
	   AND	relpersistence = 't';

	SHOW search_path INTO _origsp;

	IF _tally > 0 THEN
		FOR _r in SELECT * from __recreate ORDER BY id DESC FOR UPDATE
		LOOP
			IF beverbose THEN
				RAISE NOTICE 'Recreate % %.%', _r.type, _r.schema, _r.object;
			END IF;
			EXECUTE _r.ddl;
			EXECUTE 'SET search_path = ' || _r.schema || ',jazzhands';
			IF _r.owner is not NULL THEN
				IF _r.type = 'view' OR _r.type = 'materialized view' THEN
					EXECUTE 'ALTER ' || _r.type || ' ' || _r.schema || '.' || _r.object ||
						' OWNER TO ' || _r.owner || ';';
				ELSIF _r.type = 'function' THEN
					EXECUTE 'ALTER FUNCTION ' || _r.schema || '.' || _r.object ||
						'(' || _r.idargs || ') OWNER TO ' || _r.owner || ';';
				ELSE
					RAISE EXCEPTION 'Unable to recreate object for % ', _r;
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
		IF beverbose THEN
			RAISE NOTICE '**** WARNING: replay_object_recreates did NOT have anything to regrant!';
		END IF;
	END IF;

	EXECUTE 'SET search_path = ' || _origsp;

END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

------------------------------------------------------------------------------
-- BEGIN functions to undo audit rows
--
-- schema_support.undo_audit_row is the function that does all the work here;
-- the rest just are support routines
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION schema_support.get_pk_columns(
	_schema		text,
	_table		text
) RETURNS text[] AS $$
DECLARE
	cols		text[];
	_r			RECORD;
BEGIN
	for _r IN SELECT a.attname
			FROM pg_class c
				INNER JOIN pg_namespace n on n.oid = c.relnamespace
				INNER JOIN pg_index i ON i.indrelid = c.oid
				INNER JOIN pg_attribute  a ON   a.attrelid = c.oid AND
								a.attnum = any(i.indkey)
			WHERE	c.relname = _table
			AND		n.nspname = _schema
			AND		indisprimary
	LOOP
		SELECT array_append(cols, _r.attname::text) INTO cols;
	END LOOP;
	RETURN cols;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

--
-- given two relations, returns an array columns they have in common
--
-- runs the column names through quote_ident to ensure it is usable and
-- also will append ::text to adjust mismatches where one side or the other is
-- an enum to force both to text.
--
CREATE OR REPLACE FUNCTION schema_support.get_common_columns(
    _schema     text,
    _table1      text,
    _table2      text
) RETURNS text[] AS $$
DECLARE
	_q			text;
    cols	text[];
BEGIN
    _q := 'WITH cols AS (
	SELECT  n.nspname as schema, c.relname as relation, a.attname as colname, t.typoutput as type,
		a.attnum
	    FROM    pg_catalog.pg_attribute a
		INNER JOIN pg_catalog.pg_class c
		    ON a.attrelid = c.oid
		INNER JOIN pg_catalog.pg_namespace n
		    ON c.relnamespace = n.oid
				INNER JOIN pg_catalog.pg_type t
					ON  t.oid = a.atttypid
	    WHERE   a.attnum > 0
	    AND   NOT a.attisdropped
	    ORDER BY a.attnum
       ) SELECT array_agg(colname ORDER BY attnum) as cols
	FROM ( SELECT CASE WHEN ( o.type::text ~ ''enum'' OR n.type::text ~ ''enum'')  AND o.type != n.type THEN concat(quote_ident(n.colname), ''::text'')
					ELSE quote_ident(n.colname)
					END  AS colname,
				o.attnum
			FROM cols  o
	    INNER JOIN cols n USING (schema, colname)
		WHERE
			o.schema = $1
		and o.relation = $2
		and n.relation = $3
		) as prett
	';
	EXECUTE _q INTO cols USING _schema, _table1, _table2;
	RETURN cols;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION schema_support.get_columns(
	_schema		text,
	_table		text
) RETURNS text[] AS $$
DECLARE
	cols		text[];
	_r			record;
BEGIN
	FOR _r IN SELECT  a.attname as colname,
	    pg_catalog.format_type(a.atttypid, a.atttypmod) as coltype,
	    a.attnotnull, a.attnum
	FROM    pg_catalog.pg_attribute a
				INNER JOIN pg_class c on a.attrelid = c.oid
				INNER JOIN pg_namespace n on n.oid = c.relnamespace
	WHERE   c.relname = _table
		  AND	n.nspname = _schema
	  AND   a.attnum > 0
	  AND   NOT a.attisdropped
		  AND	lower(a.attname) not like 'data_%'
	ORDER BY a.attnum
	LOOP
		SELECT array_append(cols, _r.colname::text) INTO cols;
	END LOOP;
	RETURN cols;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

CREATE OR REPLACE FUNCTION schema_support.quote_ident_array(
	_input		text[]
) RETURNS text[] AS $$
DECLARE
	_rv		text[];
	x		text;
BEGIN
	FOREACH x IN ARRAY _input
	LOOP
		SELECT array_append(_rv, quote_ident(x)) INTO _rv;
	END LOOP;
	RETURN _rv;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- Given a schema and table and (and and audit schema)
-- and some audit characteristics, undo the effects of the record
-- Note that this does not consider foreign keys, so the reply may fail
--
-- note also that the values are AND'd together, not OR'd
--
CREATE OR REPLACE FUNCTION schema_support.undo_audit_row(
	in_table		text,
	in_audit_schema	text DEFAULT 'audit',
	in_schema		text DEFAULT 'jazzhands',
	in_start_time	timestamp DEFAULT NULL,
	in_end_time		timestamp DEFAULT NULL,
	in_aud_user		text DEFAULT NULL,
	in_audit_ids	integer[] DEFAULT NULL,
	in_txids		bigint[] DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
	tally	integer;
	pks		text[];
	cols	text[];
	q		text;
	val		text;
	x		text;
	_whcl	text;
	_eq		text;
	setstr	text;
	_r		record;
	_c		record;
	_br		record;
	_vals	text[];
BEGIN
	tally := 0;
	pks := schema_support.get_pk_columns(in_schema, in_table);
	cols := schema_support.get_columns(in_schema, in_table);
	q = '';
	IF in_start_time is not NULL THEN
		IF q = '' THEN
			q := q || 'WHERE ';
		ELSE
			q := q || 'AND ';
		END IF;
		q := q || quote_ident('aud#timestamp') || ' >= ' || quote_literal(in_start_time);
	END IF;
	IF in_end_time is not NULL THEN
		IF q = '' THEN
			q := q || 'WHERE ';
		ELSE
			q := q || 'AND ';
		END IF;
		q := q || quote_ident('aud#timestamp') || ' <= ' || quote_literal(in_end_time);
	END IF;
	IF in_aud_user is not NULL THEN
		IF q = '' THEN
			q := q || 'WHERE ';
		ELSE
			q := q || 'AND ';
		END IF;
		q := q || quote_ident('aud#user') || ' = ' || quote_literal(in_aud_user);
	END IF;
	IF in_audit_ids is not NULL THEN
		IF q = '' THEN
			q := q || 'WHERE ';
		ELSE
			q := q || 'AND ';
		END IF;
		q := q || quote_ident('aud#seq') || ' = ANY (in_audit_ids)';
	END IF;
	IF in_audit_ids is not NULL THEN
		IF q = '' THEN
			q := q || 'WHERE ';
		ELSE
			q := q || 'AND ';
		END IF;
		q := q || quote_ident('aud#txid') || ' = ANY (in_txids)';
	END IF;

	-- Iterate over all the rows that need to be replayed
	q := 'SELECT * from ' || quote_ident(in_audit_schema) || '.' ||
			quote_ident(in_table) || ' ' || q || ' ORDER BY "aud#seq" desc';
	FOR _r IN EXECUTE q
	LOOP
		IF _r."aud#action" = 'DEL' THEN
			-- Build up a list of rows that need to be inserted
			_vals = NULL;
			FOR _c IN SELECT * FROM json_each_text( row_to_json(_r) )
			LOOP
				IF _c.key !~ 'data|aud' THEN
					IF _c.value IS NULL THEN
						SELECT array_append(_vals, 'NULL') INTO _vals;
					ELSE
						SELECT array_append(_vals, quote_literal(_c.value)) INTO _vals;
					END IF;
				END IF;
			END LOOP;
			_eq := 'INSERT INTO ' || quote_ident(in_schema) || '.' ||
				quote_ident(in_table) || ' ( ' ||
				array_to_string(
					schema_support.quote_ident_array(cols), ',') ||
					') VALUES (' ||  array_to_string(_vals, ',', NULL) || ')';
		ELSIF _r."aud#action" in ('INS', 'UPD') THEN
			-- Build up a where clause for this table to get a unique row
			-- based on the primary key
			FOREACH x IN ARRAY pks
			LOOP
				_whcl := '';
				FOR _c IN SELECT * FROM json_each_text( row_to_json(_r) )
				LOOP
					IF _c.key = x THEN
						IF _whcl != '' THEN
							_whcl := _whcl || ', ';
						END IF;
						IF _c.value IS NULL THEN
							_whcl = _whcl || quote_ident(_c.key) || ' = NULL ';
						ELSE
							_whcl = _whcl || quote_ident(_c.key) || ' =  ' ||
								quote_nullable(_c.value);
						END IF;
					END IF;
				END LOOP;
			END LOOP;

			IF _r."aud#action" = 'INS' THEN
				_eq := 'DELETE FROM ' || quote_ident(in_schema) || '.' ||
					quote_ident(in_table) || ' WHERE ' || _whcl;
			ELSIF _r."aud#action" = 'UPD' THEN
				-- figure out what rows have changed and do an update if
				-- they have.  NOTE:  This may result in no change being
				-- replayed if a row did not actually change
				setstr = '';
				FOR _c IN SELECT * FROM json_each_text( row_to_json(_r) )
				LOOP
					--
					-- Iterate over all the columns and if they have changed,
					-- then build an update statement
					--
					IF _c.key !~ 'aud#|data_(ins|upd)_(user|date)' THEN
						EXECUTE 'SELECT ' || _c.key || ' FROM ' ||
							quote_ident(in_schema) || '.' ||
								quote_ident(in_table)  ||
							' WHERE ' || _whcl
							INTO val;
						IF ( _c.value IS NULL  AND val IS NOT NULL) OR
							( _c.value IS NOT NULL AND val IS NULL) OR
							(_c.value::text NOT SIMILAR TO val::text) THEN
							IF char_length(setstr) > 0 THEN
								setstr = setstr || ',
								';
							END IF;
							IF _c.value IS NOT  NULL THEN
								setstr = setstr || _c.key || ' = ' ||
									quote_nullable(_c.value) || ' ' ;
							ELSE
								setstr = setstr || _c.key || ' = ' ||
									' NULL ' ;
							END IF;
						END IF;
					END IF;
				END LOOP;
				IF char_length(setstr) > 0 THEN
					_eq := 'UPDATE ' || quote_ident(in_schema) || '.' ||
						quote_ident(in_table) ||
						' SET ' || setstr || ' WHERE ' || _whcl;
				END IF;
			END IF;
		END IF;
		IF _eq IS NOT NULL THEN
			tally := tally + 1;
			RAISE NOTICE '%', _eq;
			EXECUTE _eq;
		END IF;
	END LOOP;
	RETURN tally;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;
------------------------------------------------------------------------------
-- DONE functions to undo audit rows
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- START  schema_support.retrieve_functions
--
-- function that returns, and optionally drops all functions of a given
-- name in a schema, regardless of arguments.  The return array can be used
-- to operate on the objects if needed (enough to uniquely id the function)
--
--
CREATE OR REPLACE FUNCTION schema_support.retrieve_functions(
	schema varchar,
	object varchar,
	dropit boolean DEFAULT false
) RETURNS TEXT[] AS $$
DECLARE
	_r		RECORD;
	_fn		TEXT;
	_cmd	TEXT;
	_rv		TEXT[];
BEGIN
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
		_fn = _r.nspname || '.' || _r.proname || '(' || _r.idargs || ')';
		_rv = _rv || _fn;

		IF dropit  THEN
			_cmd = 'DROP FUNCTION ' || _fn || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;
	RETURN _rv;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- DONE  schema_support.retrieve_functions
------------------------------------------------------------------------------


----------------------------------------------------------------------------
--
-- returns true if all common colloms match between two simple relations
-- (define as containing common column that can be auto-converted to text)
--
-- returns false if not.  RAISE NOTICE all problems
--
-- Can raise an exception if desired.
--
-- Usage:
-- SELECT schema_support.relation_diff(
--	schema				- schema name of both objects
--	old_rel				- old relation name
--	new_rel				- new relation name
--	key_relation		- relation to extract pks from
--							- if not set, then defaults to old_rel
--							- will eventually be set to the one that's a table
--	prikeys				- which keys should be considered pks.  can be grabbed
--							based on key_relation; this one always wins
--	raise_exception		- raise an exception on mismatch


create or replace function schema_support.relation_diff(
	schema			text,
	old_rel			text,
	new_rel		text,
	key_relation	text DEFAULT NULL,
	prikeys			text[] DEFAULT NULL,
	raise_exception boolean DEFAULT true
) returns boolean AS
$$
DECLARE
	_r		RECORD;
	_t1		integer;
	_t2		integer;
	_cnt	integer;
	_cols	TEXT[];
	_pkcol	TEXT[];
	_q		TEXT;
	_f		TEXT;
	_c		RECORD;
	_w		TEXT[];
	_ctl		TEXT[];
	_rv	boolean;
	_oj		jsonb;
	_nj		jsonb;
BEGIN
	-- do a simple row count
	EXECUTE 'SELECT count(*) FROM ' || schema || '."' || old_rel || '"' INTO _t1;
	EXECUTE 'SELECT count(*) FROM ' || schema || '."' || new_rel || '"' INTO _t2;

	_rv := true;

	IF _t1 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', schema, old_rel;
		_rv := false;
	END IF;
	IF _t2 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', schema, new_rel;
		_rv := false;
	END IF;

	IF prikeys IS NULL THEN
		-- read into prikeys the primary key for the table
		IF key_relation IS NULL THEN
			key_relation := old_rel;
		END IF;
		prikeys := schema_support.get_pk_columns(schema, key_relation);
	END IF;

	-- read into _cols the column list in common between old_rel and new_rel
	_cols := schema_support.get_common_columns(schema, old_rel, new_rel);

	_ctl := NULL;
	FOREACH _f IN ARRAY prikeys
	LOOP
		SELECT array_append(_ctl, quote_ident(_f) ) INTO _ctl;
	END LOOP;
	_pkcol := _ctl;

	--
	-- Number of rows mismatch.  Show the missing rows based on the
	-- primary key.
	--
	IF _t1 != _t2 THEN
		RAISE NOTICE 'table % has % rows; table % has % rows (%)', old_rel, _t1, new_rel, _t2, _t1 - _t2;
	END IF;

	_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
		quote_ident(schema) || '.' || quote_ident(old_rel)  ||
		' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
			' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
			quote_ident(schema) || '.' || quote_ident(old_rel)  ||
			' EXCEPT ( '
				' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(new_rel)  ||
			' )) ';

	_cnt := 0;
	FOR _r IN EXECUTE 'SELECT row_to_json(x) as r FROM (' || _q || ') x'
	LOOP
		RAISE NOTICE 'InOld/%: %', _cnt, _r;
		_cnt := _cnt + 1;
	END LOOP;

	IF _cnt > 0  THEN
		_rv := false;
	END IF;

	_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
		quote_ident(schema) || '.' || quote_ident(new_rel)  ||
		' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
			' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
			quote_ident(schema) || '.' || quote_ident(new_rel)  ||
			' EXCEPT ( '
				' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(old_rel)  ||
			' )) ';

	_cnt := 0;
	FOR _r IN EXECUTE 'SELECT row_to_json(x) as r FROM (' || _q || ') x'
	LOOP
		RAISE NOTICE 'InNew/%: %', _cnt, _r;
		_cnt := _cnt + 1;
	END LOOP;

	IF _cnt > 0  THEN
		_rv := false;
	END IF;

	IF NOT _rv THEN
		IF raise_exception THEN
			RAISE EXCEPTION 'Relations do not match';
		END IF;
		RETURN false;
	END IF;

	-- At this point, the same number of rows appear in both, so need to
	-- figure out rows that are different between them.

	-- SELECT row_to_json(o) as old, row_to_json(n) as new
	-- FROM ( SELECT cols FROM old WHERE prikeys in Vv ) old,
	-- JOIN ( SELECT cols FROM new WHERE prikeys in Vv ) new
	-- USING (prikeys);
	-- WHERE (prikeys) IN
	-- ( SELECT  prikeys FROM (
	--		( SELECT cols FROM old EXCEPT ( SELECT cols FROM new ) )
	-- ))

	_q := ' SELECT row_to_json(old) as old, row_to_json(new) as new FROM ' ||
		'( SELECT '  || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(schema) || '.' || quote_ident(old_rel) || ' ) old ' ||
		' JOIN ' ||
		'( SELECT '  || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(schema) || '.' || quote_ident(new_rel) || ' ) new ' ||
		' USING ( ' ||  array_to_string(_pkcol,',') ||
		' ) WHERE (' || array_to_string(_pkcol,',') || ' ) IN (' ||
		'SELECT ' || array_to_string(_pkcol,',')  || ' FROM ( ' ||
			'( SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(old_rel) ||
			' EXCEPT ' ||
			'( SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(new_rel) || ' )) ' ||
		' ) subq) ORDER BY ' || array_to_string(_pkcol,',')
	;

	_t1 := 0;
	FOR _r IN EXECUTE _q
	LOOP
		_t1 := _t1 + 1;
		FOR _f IN SELECT json_object_keys(_r.new)
		LOOP
			IF _f = ANY ( prikeys ) OR _r.old->>_f IS DISTINCT FROM _r.new->>_f
			THEN
				IF _oj IS NULL THEN
					_oj := jsonb_build_object(_f, _r.old->>_f);
					_nj := jsonb_build_object(_f, _r.new->>_f);
				ELSE
					_oj := _oj || jsonb_build_object(_f, _r.old->>_f);
					_nj := _nj || jsonb_build_object(_f, _r.new->>_f);
				END IF;
			END IF;
		END LOOP;
		RAISE NOTICE 'mismatched row:';
		RAISE NOTICE 'OLD: %', _oj;
		RAISE NOTICE 'NEW: %', _nj;
		_rv := false;
	END LOOP;


	IF NOT _rv AND raise_exception THEN
		RAISE EXCEPTION 'Relations do not match (% rows)', _t1;
	ELSE
		RAISE NOTICE '% rows mismatch', _t1;
	END IF;
	return _rv;
END;
$$ LANGUAGE plpgsql;

----------------------------------------------------------------------------
-- BEGIN materialized view refresh automation support
----------------------------------------------------------------------------
--
-- These functions are used to better automate refreshing of materialized
-- views.  They are meant to be called by the schema owners and not by
-- mere mortals, which may mean writing wrapper functions
--
-- schema_support.relation_last_changed(table,schema,debug) can be used to
--	tell the last time a table, view or materialized view was updated
--	based on audit tables.  For views and materialized views, it will
--	recursively rifle through dependent tables to find the answer. Note
--	that if a dependency does not have an audit table (such as another
--	materialized view or caching/log table), the functions will just
--	assume they are current.
--
--	Also note that the recursive check is not terribly smart, so if
--	dependant tables had data changed that was not in the object that
--	called it, it will still trigger yes even if the view didn't really
--	change.
--
-- mv_last_updated()/set_mv_last_updated() are largely used internally.
--
-- schema_support.refresh_mv_if_needed(table,schema,debug) is used to
--	refresh a materialized view if tables internal to schema_support
--	reflect that it has not refreshed since the dependant objects were
--	refreshed.  There appears to be no place in the system catalog to
--	tell when a materialized view was last changed, so if the internal
--	tables are out of date, a refresh could happen.
--
--	Note that calls to this in different transactions will block, thus
--	if two things go to rebuild, they will happen serially.  In that
--	case, if there are no changes in a blocking transaction, the code
--	is arranged such that it will return immediately and not try to
--	rebuild the materialized view, so this should result in less churn.

--
-- refiles through internal tables to figure out when an mv or similar was
-- updated; runs as DEFINER to hide objects.
--
CREATE OR REPLACE FUNCTION schema_support.mv_last_updated (
	relation TEXT,
	schema TEXT DEFAULT 'jazzhands',
	debug boolean DEFAULT false
) RETURNS TIMESTAMP AS $$
DECLARE
	rv	timestamp;
BEGIN
	IF debug THEN
		RAISE NOTICE 'schema_support.mv_last_updated(): selecting for update...';
	END IF;

	SELECT	refresh
	INTO	rv
	FROM	schema_support.mv_refresh r
	WHERE	r.schema = mv_last_updated.schema
	AND	r.view = relation
	FOR UPDATE;

	IF debug THEN
		RAISE NOTICE 'schema_support.mv_last_updated(): returning %', rv;
	END IF;

	RETURN rv;
END;
$$
SET search_path=schema_support
LANGUAGE plpgsql SECURITY DEFINER;

--
-- updates internal tables to set last update.
-- runs as DEFINER to hide objects.
--
CREATE OR REPLACE FUNCTION schema_support.set_mv_last_updated (
	relation TEXT,
	schema TEXT DEFAULT 'jazzhands',
	whence timestamp DEFAULT now(),
	debug boolean DEFAULT false
) RETURNS TIMESTAMP AS $$
DECLARE
	rv	timestamp;
BEGIN
	INSERT INTO schema_support.mv_refresh AS r (
		schema, view, refresh
	) VALUES (
		set_mv_last_updated.schema, relation, whence
	) ON CONFLICT ON CONSTRAINT mv_refresh_pkey DO UPDATE
		SET		refresh = whence
		WHERE	r.schema = set_mv_last_updated.schema
		AND		r.view = relation
	;

	RETURN rv;
END;
$$
SET search_path=schema_support
LANGUAGE plpgsql SECURITY DEFINER;

--
-- figures out the last time an object changed based on the audit tables
-- for the object.  This assumes that the schema -> audit mapping is found
-- in schema_support.schema_audit_map, otherwise raises an exception.
--
CREATE OR REPLACE FUNCTION schema_support.relation_last_changed (
	relation TEXT,
	schema TEXT DEFAULT 'jazzhands',
	debug boolean DEFAULT false
) RETURNS TIMESTAMP AS $$
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

	SELECT	relkind
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
			RETURN '-infinity'::timestamp;
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
$$
SET search_path=schema_support
LANGUAGE plpgsql SECURITY INVOKER;

CREATE OR REPLACE FUNCTION schema_support.refresh_mv_if_needed (
	relation TEXT,
	schema TEXT DEFAULT 'jazzhands',
	debug boolean DEFAULT false
) RETURNS void AS $$
DECLARE
	lastref	timestamp;
	lastdat	timestamp;
	whence	timestamp;
BEGIN
	SELECT coalesce(schema_support.mv_last_updated(relation, schema,debug),'-infinity') INTO lastref;
	SELECT coalesce(schema_support.relation_last_changed(relation, schema,debug),'-infinity') INTO lastdat;
	IF lastdat > lastref THEN
		IF debug THEN
			RAISE NOTICE 'schema_support.refresh_mv_if_needed(): refreshing %.%', schema, relation;
		END IF;
		EXECUTE 'REFRESH MATERIALIZED VIEW ' || quote_ident(schema)||'.'||quote_ident(relation);
		--  This can happen with long running transactions.
		whence := now();
		IF lastref > whence THEN
			whence := lastref;
		END IF;
		PERFORM schema_support.set_mv_last_updated(relation, schema, whence, debug);
	END IF;
	RETURN;
END;
$$
SET search_path=schema_support
LANGUAGE plpgsql SECURITY INVOKER;


--
-- This migrates grants from one schema to another for setting up a shadow
-- schema for dealing with migrations.  It still needs to handle functions.
--
-- It also ignores sequences because those really need to move to IDENTITY
-- columns anyway. and sequences are really part of the shadow schema stuff.
--
CREATE OR REPLACE FUNCTION schema_support.migrate_grants (
	username	TEXT,
	direction	TEXT,
	old_schema	TEXT DEFAULT 'jazzhands',
	new_schema	TEXT DEFAULT 'jazzhands_legacy'
) RETURNS TEXT[] AS $$
DECLARE
	_rv	TEXT[];
	_r	RECORD;
	_q	TEXT;
BEGIN
	IF lower(direction) NOT IN ('grant','revoke') THEN
		RAISE EXCEPTION 'direction must be grant or revoke';
	END IF;

	FOR _r IN
		WITH x AS (
		SELECT *
			FROM (
		SELECT oid, schema, name,  typ,
			p->>'privilege_type' as privilege_type,
			col,
			r.usename as grantor, e.usename as grantee,
			r.usesysid as rid,  e.usesysid as eid,
			e.useconfig
		FROM (
			SELECT  c.oid, n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'm' THEN 'view'
				WHEN 'v' THEN 'mview'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as typ,
				NULL::text as col,
			to_jsonb(pg_catalog.aclexplode(acl := c.relacl)) as p
			FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
			WHERE c.relkind IN ('r', 'v', 'S', 'f')
		UNION ALL
		SELECT  c.oid, n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'v' THEN 'view'
				WHEN 'mv' THEN 'mview'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as typ,
			a.attname as col,
			to_jsonb(pg_catalog.aclexplode(a.attacl)) as p
			FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
			INNER JOIN pg_attribute a
				ON a.attrelid = c.oid
			WHERE c.relkind IN ('r', 'v', 'S', 'f')
			AND a.attacl IS NOT NULL
		) x
		LEFT JOIN pg_user r ON r.usesysid = (p->>'grantor')::oid
		LEFT JOIN pg_user e ON e.usesysid = (p->>'grantee')::oid
		) i
		) select *
		FROM x
		WHERE ( schema = old_schema )
		AND grantee = username
		AND typ IN ('table', 'view', 'mview', 'foreign table')
		order by name, col
	LOOP
		IF _r.col IS NOT NULL THEN
			_q = concat(' (', _r.col, ') ');
		ELSE
			_q := NULL;
		END IF;
		IF lower(direction) = 'grant' THEN
			_q := concat('GRANT ', _r.privilege_type, _q, ' ON ', new_schema, '.', _r.name, ' TO ', _r.grantee);
		ELSIF lower(direction) = 'revoke' THEN
			_q := concat('REVOKE ', _r.privilege_type, _q, ' ON ', old_schema, '.', _r.name, ' FROM ', _r.grantee);
		END IF;


		_rv := array_append(_rv, _q);
		EXECUTE _q;
	END LOOP;
	RETURN _rv;
END;
$$
SET search_path=schema_support
LANGUAGE plpgsql SECURITY INVOKER;



----------------------------------------------------------------------------
-- END materialized view support
----------------------------------------------------------------------------

\ir create_schema_support_cache_tables.sql

/**************************************************************
 *  FUNCTIONS

schema_support.begin_maintenance

	- ensures you are running in a transaction
	- ensures you are a superuser (based on argument)

schema_support.end_maintenance
	- revokes superuser from running user (based on argument)


This:
	schema_support.migrate_grants is used to deal with setting up
	shadow schemas for migrations and removing/adding permissions as
	things are moving.

These will save an object for replay, including presering grants
automatically:

SELECT schema_support.save_function_for_replay('jazzhands', 'fncname');
	- saves all function of a given name

SELECT schema_support.save_view_for_replay('jazzhands',  'mytableorview');
	- saves a view includling triggers on the view, for replay

SELECT schema_support.save_constraint_for_replay('jazzhands', 'table');
	- saves constraints pointing to an object for replay

SELECT schema_support.save_trigger_for_replay('jazzhands', 'relation');
	- save triggers poinging to an object for replay

SELECT schema_support.save_dependent_objects_for_replay(schema, object)

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

THIS:
	schema_support.undo_audit_row()

will build and execute a statement to undo changes made in an audit table
against the current state.  It executes the queries in reverse order from
execution so in theory can undo every operation on a table if called without
restriction.  It does not cascade or otherwise do anything with foreign keys.


These setup triggers for the data_{ins,upd}_{user,date} columns on tables

select schema_support.rebuild_stamp_triggers();


Building and manipulating audit tables:

	schema_support.build_audit_table_pkak_indexes (aud_schema, tbl_schema, table_name)
	schema_support.build_audit_table_other_indexes (aud_schema, tbl_schema, table_name)
	schema_support.build_audit_table (aud_schema, tbl_schema, table_name)
	schema_support.build_audit_tables (aud_schema, tbl_schema)

These are used to build various bits about audit tables.
schema_support.build_audit_tables() is just a wrapper that
loops through the list of tables in tbl_schema and runs
schema_support.build_audit_table().  Arguably, the system needs a method
to mark tables as exempt.

schema_support.build_audit_table() also calls table_pkak_indexes().  So
schema_support.build_audit_there is generally no reason to call that.

schema_support.build_audit_table_other_indexes() mirrors all the indexes on
the base table on the audit table and names them the same.  Note that the
rebuild commands DO NOT mirror these (yet).  This should arguably be
considered a bug...

Rebuilding audit tables:

	schema_support.rebuild_audit_trigger(aud_schema, tbl_schema table_name)
	schema_support.rebuild_audit_table(aud_schema, tbl_schema, table_name)

	schema_support.rebuild_audit_tables(aud_schema, tbl_schema)
	schema_support.rebuild_audit_triggers(aud_schema, tbl_schema);

These all work together but can be called individually.
schema_support.rebuild_audit_tables is generally the interface and will
iterate though every base table that has an audit table.
schema_support.rebuild_audit_tables() will also preserve grants and views
on top of the objects via functions in here, which the individual ones do not
do.  This should arguably be changed.

**************************************************************/
