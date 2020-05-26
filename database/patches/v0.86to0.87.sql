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

/*
Invoked:

	--suffix=v87
	--pre
	pre
	--pre
	../new/database/ddl/schema/pgsql/create_schema_support.sql
	--post
	post87
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance();
select timeofday(), now();


-- BEGIN Misc that does not apply to above

DO $$
BEGIN
        CREATE SCHEMA pgcrypto;
        CREATE EXTENSION IF NOT EXISTS pgcrypto WITH schema pgcrypto;
EXCEPTION WHEN duplicate_schema THEN
        NULL;
END;
$$;

DROP FUNCTION IF EXISTS schema_support.save_dependent_objects_for_replay ( schema character varying, object character varying, dropit boolean, doobjectdeps boolean, tags text[]);
DROP FUNCTION IF EXISTS schema_support.save_trigger_for_replay           ( schema character varying, object character varying, dropit boolean, tags text[]);
DROP FUNCTION IF EXISTS schema_support.save_view_for_replay              ( schema character varying, object character varying, dropit boolean, tags text[]);
DROP FUNCTION IF EXISTS schema_support.save_constraint_for_replay        ( schema character varying, object character varying, dropit boolean, tags text[]);
DROP FUNCTION IF EXISTS schema_support.save_function_for_replay          ( schema character varying, object character varying, dropit boolean, tags text[]);
DROP FUNCTION IF EXISTS schema_support.save_grants_for_replay            (  schema character varying, object character varying, newname character varying);


-- END Misc that does not apply to above


-- BEGIN Misc that does not apply to above
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
	SELECT table_name::text FROM information_schema.tables
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
		ORDER BY CASE WHEN con.contype = 'p' THEN 0 ELSE 1 END, con.conname
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
	SELECT table_name::text FROM information_schema.tables
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
		SELECT b.table_name::text
		FROM information_schema.tables b
			INNER JOIN information_schema.tables a
				USING (table_name,table_type)
		WHERE table_type = 'BASE TABLE'
		AND a.table_schema = aud_schema
		AND b.table_schema = tbl_schema
		ORDER BY table_name
	LOOP
		PERFORM schema_support.save_dependent_objects_for_replay(
			schema := aud_schema::varchar,
			object := table_list.table_name::varchar,
			tags:= ARRAY['rebuild_audit_tables']);
		PERFORM schema_support.save_grants_for_replay(schema := aud_schema,
			object := table_list.table_name,
			tags := ARRAY['rebuild_audit_tables']);
		PERFORM schema_support.rebuild_audit_table
			( aud_schema, tbl_schema, table_list.table_name );
		PERFORM schema_support.replay_object_recreates();
		PERFORM schema_support.replay_saved_grants();
		END LOOP;

	PERFORM schema_support.rebuild_audit_triggers(aud_schema, tbl_schema);
	PERFORM schema_support.replay_object_recreates(tags := ARRAY['rebuild_audit_tables
']);
	PERFORM schema_support.replay_saved_grants(tags := ARRAY['rebuild_audit_tables']);
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
	    SELECT table_name::text FROM information_schema.tables
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
		CREATE TEMPORARY TABLE IF NOT EXISTS __regrants (id SERIAL, schema text, object text, newname text, regrant text, tags text[]);
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
	newname varchar DEFAULT NULL,
	tags text[] DEFAULT NULL
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
			INSERT INTO __regrants (schema, object, newname, regrant, tags) values (schema,object, newname, _fullgrant, tags );
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
			INSERT INTO __regrants (schema, object, newname, regrant, tags) values (schema,object, newname, _fullgrant, tags );
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
	newname varchar DEFAULT NULL,
	tags text[] DEFAULT NULL
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
			INSERT INTO __regrants (schema, object, newname, regrant, tags) values (schema,object, newname, _fullgrant, tags );
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
	newname varchar DEFAULT NULL,
	tags text[] DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
	PERFORM schema_support.save_grants_for_replay_relations(schema, object, newname, tags);
	PERFORM schema_support.save_grants_for_replay_functions(schema, object, newname, tags);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

--
-- replay saved grants, drop temporary tables
--
CREATE OR REPLACE FUNCTION schema_support.replay_saved_grants(
	beverbose	boolean DEFAULT false,
	schema		text DEFAULT NULL,
	tags		text DEFAULT NULL
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
			if tags IS NOT NULL THEN
				CONTINUE WHEN _r.tags IS NULL;
				CONTINUE WHEN NOT _r.tags && tags;
			END IF;
			if schema IS NOT NULL THEN
				CONTINUE WHEN _r.schema IS NULL;
				CONTINUE WHEN _r.schema != schema;
			END IF;
		    IF beverbose THEN
			    RAISE NOTICE 'Regrant Executing: %', _r.regrant;
		    END IF;
		    EXECUTE _r.regrant;
		    DELETE from __regrants where id = _r.id;
	    END LOOP;

	    SELECT count(*) INTO _tally from __regrants;
	    IF _tally > 0 THEN
			IF schema IS NULL AND tags IS NULL THEN
				RAISE EXCEPTION 'Grant extractions were run while replaying grants - %.', _tally;
			END IF;
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
		CREATE TEMPORARY TABLE IF NOT EXISTS __recreate (id SERIAL, schema text, object text, owner text, type text, ddl text, idargs text, tags text[], path text[]);
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
	dropit boolean DEFAULT true,
	tags text[] DEFAULT NULL,
	path text[] DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
	_r		RECORD;
	_c		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
	_mat	TEXT;
	_typ	TEXT;
BEGIN
	path = path || concat(schema, '.', object);
	PERFORM schema_support.prepare_for_object_replay();

	-- implicitly save regrants
	PERFORM schema_support.save_grants_for_replay(schema, object, object, tags);

	-- save any triggers on the view
	PERFORM schema_support.save_trigger_for_replay(schema, object, dropit, tags, path);

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
				INSERT INTO __recreate (schema, object, type, ddl, tags, path )
					VALUES (
						_r.nspname, _r.relname, 'default', _ddl, tags, path
					);
			END IF;
			IF _c.comment IS NOT NULL THEN
				_ddl := 'COMMENT ON COLUMN ' ||
					quote_ident(schema) || '.' || quote_ident(object)
					' IS ''' || _c.comment || '''';
				INSERT INTO __recreate (schema, object, type, ddl, tags, path )
					VALUES (
						_r.nspname, _r.relname, 'colcomment', _ddl, tags, path
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
		INSERT INTO __recreate (schema, object, owner, type, ddl, tags, path )
			VALUES (
				_r.nspname, _r.relname, _r.owner, _typ, _ddl, tags, path
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
	doobjectdeps boolean DEFAULT false,
	tags text[] DEFAULT NULL,
	path text[] DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	RAISE DEBUG 'processing %.%', schema, object;
	path = path || concat(schema, '.', object);
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
		PERFORM schema_support.save_constraint_for_replay(schema := _r.nspname, object := _r.proname, dropit := dropit, tags := tags, path := path);
		PERFORM schema_support.save_dependent_objects_for_replay(_r.nspname, _r.proname, dropit, doobjectdeps, tags, path);
		PERFORM schema_support.save_function_for_replay(_r.nspname, _r.proname, dropit, tags, path);
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
			PERFORM * FROM save_dependent_objects_for_replay(_r.nspname, _r.relname, dropit, doobjectdeps, tags, path);
			PERFORM schema_support.save_view_for_replay(_r.nspname, _r.relname, dropit, tags, path);
		END IF;
	END LOOP;
	IF doobjectdeps THEN
		PERFORM schema_support.save_trigger_for_replay(schema, object, dropit, tags, path);
		PERFORM schema_support.save_constraint_for_replay(schema := 'jazzhands', object := 'table', tags := tags, path := path);
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
	dropit boolean DEFAULT true,
	tags text[] DEFAULT NULL,
	path text[] DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
BEGIN
	path = path || concat(schema, '.', object);
	PERFORM schema_support.prepare_for_object_replay();

	FOR _r in
		SELECT n.nspname, c.relname, trg.tgname,
				pg_get_triggerdef(trg.oid, true) as def
		FROM pg_trigger trg
			INNER JOIN pg_class c on trg.tgrelid =  c.oid
			INNER JOIN pg_namespace n on n.oid = c.relnamespace
		WHERE n.nspname = schema and c.relname = object
	LOOP
		INSERT INTO __recreate (schema, object, type, ddl, tags , path)
			VALUES (
				_r.nspname, _r.relname, 'trigger', _r.def, tags, path
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
	dropit boolean DEFAULT true,
	newobject varchar DEFAULT NULL,
	newmap jsonb DEFAULT NULL,
	tags text[] DEFAULT NULL,
	path text[] DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
	_def	TEXT;
	_cols	TEXT;
	_myname	TEXT;
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

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
		                array_agg(attname) as cols
		        FROM (
		            SELECT con.*, a.attname
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
		                array_agg(attname) as cols
		        FROM (
		            SELECT con.*, a.attname
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
	dropit boolean DEFAULT true,
	tags text[] DEFAULT NULL,
	path text[] DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
BEGIN
	path = path || concat(schema, '.', object);
	PERFORM schema_support.prepare_for_object_replay();

	-- implicitly save regrants
	PERFORM schema_support.save_grants_for_replay(schema, object, object, tags);
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
		INSERT INTO __recreate (schema, object, type, owner,
			ddl, idargs, tags, path
		) VALUES (
			_r.nspname, _r.proname, 'function', _r.owner,
			_r.funcdef, _r.idargs, tags, path
		);
		IF dropit  THEN
			_cmd = 'DROP FUNCTION ' || _r.nspname || '.' ||
				_r.proname || '(' || _r.idargs || ');';
			EXECUTE _cmd;
		END IF;

	END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

--
-- If tags is set, replays just the rows with those tags
-- If object/schema are set, further refines to replay objects
-- if path is set, include objects that have input path in path
-- with those names.
--
CREATE OR REPLACE FUNCTION schema_support.replay_object_recreates(
	beverbose	boolean DEFAULT false,
	tags		text[] DEFAULT NULL,
	schema		text DEFAULT NULL,
	object		text DEFAULT NULL,
	type		text DEFAULT NULL,
	path		text DEFAULT NULL
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
			IF tags IS NOT NULL THEN
				CONTINUE WHEN _r.tags IS NULL;
				CONTINUE WHEN NOT _r.tags && tags;
			END IF;
			IF schema IS NOT NULL THEN
				CONTINUE WHEN _r.schema IS NULL;
				CONTINUE WHEN NOT _r.schema = schema;
			END IF;
			IF type IS NOT NULL THEN
				CONTINUE WHEN _r.type IS NULL;
				CONTINUE WHEN NOT _r.type = type;
			END IF;
			IF object IS NOT NULL THEN
				CONTINUE WHEN _r.object IS NULL;
				IF object ~ '^!' THEN
					object = regexp_replace(object, '^!', '');
					CONTINUE WHEN _r.object = object;
				ELSE
					CONTINUE WHEN NOT _r.object = object;
				END IF;
			END IF;

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
			IF tags IS NULL AND schema IS NULL and object IS NULL THEN
				RAISE EXCEPTION '% objects still exist for recreating after a complete loop', _tally;
			END IF;
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
    _oldschema   TEXT,
    _table1      TEXT,
    _newschema   TEXT,
    _table2      TEXT
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
	    INNER JOIN cols n USING (colname)
		WHERE
			o.schema = $1
		and o.relation = $2
		and n.schema = $3
		and n.relation = $4
		) as prett
	';
	EXECUTE _q INTO cols USING _oldschema, _table1, _newschema, _table2;
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
	_oldschema	TEXT;
	_newschema	TEXT;
BEGIN
	IF old_rel ~ '\.' THEN
		_oldschema := regexp_replace(old_rel, '\..*$', '');
		old_rel := regexp_replace(old_rel, '^[^\.]*\.', '');
	ELSE
		_oldschema:= schema;
	END IF;

	IF new_rel ~ '\.' THEN
		_newschema := regexp_replace(new_rel, '\..*$', '');
		new_rel := regexp_replace(new_rel, '^[^\.]*\.', '');
	ELSE
		_newschema:= schema;
	END IF;

	RAISE NOTICE '% % % %', _oldschema, old_rel, _newschema, new_rel;

	-- do a simple row count
	EXECUTE 'SELECT count(*) FROM ' || _oldschema || '."' || old_rel || '"' INTO _t1;
	EXECUTE 'SELECT count(*) FROM ' || _newschema || '."' || new_rel || '"' INTO _t2;

	_rv := true;

	IF _t1 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', _oldschema, old_rel;
		_rv := false;
	END IF;
	IF _t2 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', _oldschema, new_rel;
		_rv := false;
	END IF;

	IF prikeys IS NULL THEN
		-- read into prikeys the primary key for the table
		IF key_relation IS NULL THEN
			key_relation := old_rel;
		END IF;
		prikeys := schema_support.get_pk_columns(_oldschema, key_relation);
	END IF;

	-- read into _cols the column list in common between old_rel and new_rel
	_cols := schema_support.get_common_columns(_oldschema, old_rel, _newschema, new_rel);

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
		_rv := false;
	END IF;

	_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
		quote_ident(_oldschema) || '.' || quote_ident(old_rel)  ||
		' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
			' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
			quote_ident(_oldschema) || '.' || quote_ident(old_rel)  ||
			' EXCEPT ( '
				' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
				quote_ident(_newschema) || '.' || quote_ident(new_rel)  ||
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
		quote_ident(_newschema) || '.' || quote_ident(new_rel)  ||
		' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
			' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
			quote_ident(_newschema) || '.' || quote_ident(new_rel)  ||
			' EXCEPT ( '
				' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
				quote_ident(_oldschema) || '.' || quote_ident(old_rel)  ||
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
			quote_ident(_oldschema) || '.' || quote_ident(old_rel) || ' ) old ' ||
		' JOIN ' ||
		'( SELECT '  || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(_newschema) || '.' || quote_ident(new_rel) || ' ) new ' ||
		' USING ( ' ||  array_to_string(_pkcol,',') ||
		' ) WHERE (' || array_to_string(_pkcol,',') || ' ) IN (' ||
		'SELECT ' || array_to_string(_pkcol,',')  || ' FROM ( ' ||
			'( SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(_oldschema) || '.' || quote_ident(old_rel) ||
			' EXCEPT ' ||
			'( SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(_newschema) || '.' || quote_ident(new_rel) || ' )) ' ||
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


-- END Misc that does not apply to above
--
-- BEGIN: process_ancillary_schema(schema_support)
--
-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'build_audit_table_pkak_indexes');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.build_audit_table_pkak_indexes ( aud_schema character varying, tbl_schema character varying, table_name character varying );
CREATE OR REPLACE FUNCTION schema_support.build_audit_table_pkak_indexes(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
		ORDER BY CASE WHEN con.contype = 'p' THEN 0 ELSE 1 END, con.conname
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'build_audit_tables');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.build_audit_tables ( aud_schema character varying, tbl_schema character varying );
CREATE OR REPLACE FUNCTION schema_support.build_audit_tables(aud_schema character varying, tbl_schema character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
     table_list RECORD;
BEGIN
    FOR table_list IN
	SELECT table_name::text FROM information_schema.tables
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
		CREATE TEMPORARY TABLE IF NOT EXISTS __regrants (id SERIAL, schema text, object text, newname text, regrant text, tags text[]);
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
		CREATE TEMPORARY TABLE IF NOT EXISTS __recreate (id SERIAL, schema text, object text, owner text, type text, ddl text, idargs text, tags text[], path text[]);
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_table');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_table ( aud_schema character varying, tbl_schema character varying, table_name character varying, finish_rebuild boolean );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_table(aud_schema character varying, tbl_schema character varying, table_name character varying, finish_rebuild boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_tables');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_tables ( aud_schema character varying, tbl_schema character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_tables(aud_schema character varying, tbl_schema character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	 table_list RECORD;
BEGIN
	FOR table_list IN
		SELECT b.table_name::text
		FROM information_schema.tables b
			INNER JOIN information_schema.tables a
				USING (table_name,table_type)
		WHERE table_type = 'BASE TABLE'
		AND a.table_schema = aud_schema
		AND b.table_schema = tbl_schema
		ORDER BY table_name
	LOOP
		PERFORM schema_support.save_dependent_objects_for_replay(
			schema := aud_schema::varchar,
			object := table_list.table_name::varchar,
			tags:= ARRAY['rebuild_audit_tables']);
		PERFORM schema_support.save_grants_for_replay(schema := aud_schema,
			object := table_list.table_name,
			tags := ARRAY['rebuild_audit_tables']);
		PERFORM schema_support.rebuild_audit_table
			( aud_schema, tbl_schema, table_list.table_name );
		PERFORM schema_support.replay_object_recreates();
		PERFORM schema_support.replay_saved_grants();
		END LOOP;

	PERFORM schema_support.rebuild_audit_triggers(aud_schema, tbl_schema);
	PERFORM schema_support.replay_object_recreates(tags := ARRAY['rebuild_audit_tables
']);
	PERFORM schema_support.replay_saved_grants(tags := ARRAY['rebuild_audit_tables']);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_triggers');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_triggers ( aud_schema character varying, tbl_schema character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_triggers(aud_schema character varying, tbl_schema character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    table_list RECORD;
BEGIN
    --
    -- select tables with audit tables
    --
    FOR table_list IN
	SELECT table_name::text FROM information_schema.tables
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
	    SELECT table_name::text FROM information_schema.tables
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
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_diff');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_diff ( schema text, old_rel text, new_rel text, key_relation text, prikeys text[], raise_exception boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_diff(schema text, old_rel text, new_rel text, key_relation text DEFAULT NULL::text, prikeys text[] DEFAULT NULL::text[], raise_exception boolean DEFAULT true)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
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
	_oldschema	TEXT;
	_newschema	TEXT;
BEGIN
	IF old_rel ~ '\.' THEN
		_oldschema := regexp_replace(old_rel, '\..*$', '');
		old_rel := regexp_replace(old_rel, '^[^\.]*\.', '');
	ELSE
		_oldschema:= schema;
	END IF;

	IF new_rel ~ '\.' THEN
		_newschema := regexp_replace(new_rel, '\..*$', '');
		new_rel := regexp_replace(new_rel, '^[^\.]*\.', '');
	ELSE
		_newschema:= schema;
	END IF;

	RAISE NOTICE '% % % %', _oldschema, old_rel, _newschema, new_rel;

	-- do a simple row count
	EXECUTE 'SELECT count(*) FROM ' || _oldschema || '."' || old_rel || '"' INTO _t1;
	EXECUTE 'SELECT count(*) FROM ' || _newschema || '."' || new_rel || '"' INTO _t2;

	_rv := true;

	IF _t1 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', _oldschema, old_rel;
		_rv := false;
	END IF;
	IF _t2 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', _oldschema, new_rel;
		_rv := false;
	END IF;

	IF prikeys IS NULL THEN
		-- read into prikeys the primary key for the table
		IF key_relation IS NULL THEN
			key_relation := old_rel;
		END IF;
		prikeys := schema_support.get_pk_columns(_oldschema, key_relation);
	END IF;

	-- read into _cols the column list in common between old_rel and new_rel
	_cols := schema_support.get_common_columns(_oldschema, old_rel, _newschema, new_rel);

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
		_rv := false;
	END IF;

	_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
		quote_ident(_oldschema) || '.' || quote_ident(old_rel)  ||
		' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
			' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
			quote_ident(_oldschema) || '.' || quote_ident(old_rel)  ||
			' EXCEPT ( '
				' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
				quote_ident(_newschema) || '.' || quote_ident(new_rel)  ||
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
		quote_ident(_newschema) || '.' || quote_ident(new_rel)  ||
		' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
			' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
			quote_ident(_newschema) || '.' || quote_ident(new_rel)  ||
			' EXCEPT ( '
				' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
				quote_ident(_oldschema) || '.' || quote_ident(old_rel)  ||
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
			quote_ident(_oldschema) || '.' || quote_ident(old_rel) || ' ) old ' ||
		' JOIN ' ||
		'( SELECT '  || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(_newschema) || '.' || quote_ident(new_rel) || ' ) new ' ||
		' USING ( ' ||  array_to_string(_pkcol,',') ||
		' ) WHERE (' || array_to_string(_pkcol,',') || ' ) IN (' ||
		'SELECT ' || array_to_string(_pkcol,',')  || ' FROM ( ' ||
			'( SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(_oldschema) || '.' || quote_ident(old_rel) ||
			' EXCEPT ' ||
			'( SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(_newschema) || '.' || quote_ident(new_rel) || ' )) ' ||
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
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.get_common_columns(_oldschema text, _table1 text, _newschema text, _table2 text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
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
	    INNER JOIN cols n USING (colname)
		WHERE
			o.schema = $1
		and o.relation = $2
		and n.schema = $3
		and n.relation = $4
		) as prett
	';
	EXECUTE _q INTO cols USING _oldschema, _table1, _newschema, _table2;
	RETURN cols;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.replay_object_recreates(beverbose boolean DEFAULT false, tags text[] DEFAULT NULL::text[], schema text DEFAULT NULL::text, object text DEFAULT NULL::text, type text DEFAULT NULL::text, path text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
			IF tags IS NOT NULL THEN
				CONTINUE WHEN _r.tags IS NULL;
				CONTINUE WHEN NOT _r.tags && tags;
			END IF;
			IF schema IS NOT NULL THEN
				CONTINUE WHEN _r.schema IS NULL;
				CONTINUE WHEN NOT _r.schema = schema;
			END IF;
			IF type IS NOT NULL THEN
				CONTINUE WHEN _r.type IS NULL;
				CONTINUE WHEN NOT _r.type = type;
			END IF;
			IF object IS NOT NULL THEN
				CONTINUE WHEN _r.object IS NULL;
				IF object ~ '^!' THEN
					object = regexp_replace(object, '^!', '');
					CONTINUE WHEN _r.object = object;
				ELSE
					CONTINUE WHEN NOT _r.object = object;
				END IF;
			END IF;

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
			IF tags IS NULL AND schema IS NULL and object IS NULL THEN
				RAISE EXCEPTION '% objects still exist for recreating after a complete loop', _tally;
			END IF;
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
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.replay_saved_grants(beverbose boolean DEFAULT false, schema text DEFAULT NULL::text, tags text DEFAULT NULL::text)
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
			if tags IS NOT NULL THEN
				CONTINUE WHEN _r.tags IS NULL;
				CONTINUE WHEN NOT _r.tags && tags;
			END IF;
			if schema IS NOT NULL THEN
				CONTINUE WHEN _r.schema IS NULL;
				CONTINUE WHEN _r.schema != schema;
			END IF;
		    IF beverbose THEN
			    RAISE NOTICE 'Regrant Executing: %', _r.regrant;
		    END IF;
		    EXECUTE _r.regrant;
		    DELETE from __regrants where id = _r.id;
	    END LOOP;

	    SELECT count(*) INTO _tally from __regrants;
	    IF _tally > 0 THEN
			IF schema IS NULL AND tags IS NULL THEN
				RAISE EXCEPTION 'Grant extractions were run while replaying grants - %.', _tally;
			END IF;
	    ELSE
		    DROP TABLE __regrants;
	    END IF;
	ELSE
		IF beverbose THEN
			RAISE NOTICE '**** WARNING: replay_saved_grants did NOT have anything to regrant!';
		END IF;
	END IF;

END;
$function$
;

-- New function
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
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

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
		                array_agg(attname) as cols
		        FROM (
		            SELECT con.*, a.attname
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
		                array_agg(attname) as cols
		        FROM (
		            SELECT con.*, a.attname
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
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_dependent_objects_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, doobjectdeps boolean DEFAULT false, tags text[] DEFAULT NULL::text[], path text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	RAISE DEBUG 'processing %.%', schema, object;
	path = path || concat(schema, '.', object);
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
		PERFORM schema_support.save_constraint_for_replay(schema := _r.nspname, object := _r.proname, dropit := dropit, tags := tags, path := path);
		PERFORM schema_support.save_dependent_objects_for_replay(_r.nspname, _r.proname, dropit, doobjectdeps, tags, path);
		PERFORM schema_support.save_function_for_replay(_r.nspname, _r.proname, dropit, tags, path);
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
			PERFORM * FROM save_dependent_objects_for_replay(_r.nspname, _r.relname, dropit, doobjectdeps, tags, path);
			PERFORM schema_support.save_view_for_replay(_r.nspname, _r.relname, dropit, tags, path);
		END IF;
	END LOOP;
	IF doobjectdeps THEN
		PERFORM schema_support.save_trigger_for_replay(schema, object, dropit, tags, path);
		PERFORM schema_support.save_constraint_for_replay(schema := 'jazzhands', object := 'table', tags := tags, path := path);
	END IF;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_function_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, tags text[] DEFAULT NULL::text[], path text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
BEGIN
	path = path || concat(schema, '.', object);
	PERFORM schema_support.prepare_for_object_replay();

	-- implicitly save regrants
	PERFORM schema_support.save_grants_for_replay(schema, object, object, tags);
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
		INSERT INTO __recreate (schema, object, type, owner,
			ddl, idargs, tags, path
		) VALUES (
			_r.nspname, _r.proname, 'function', _r.owner,
			_r.funcdef, _r.idargs, tags, path
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

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay(schema character varying, object character varying, newname character varying DEFAULT NULL::character varying, tags text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
	PERFORM schema_support.save_grants_for_replay_relations(schema, object, newname, tags);
	PERFORM schema_support.save_grants_for_replay_functions(schema, object, newname, tags);
END;
$function$
;

-- New function
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
			_fullgrant := 'GRANT ' ||
				_perm.privilege_type || ' on FUNCTION ' ||
				_schema || '.' ||
				newname || '(' || _procs.args || ')  to ' ||
				_role || _grant;
			-- RAISE DEBUG 'inserting % for %', _fullgrant, _perm;
			INSERT INTO __regrants (schema, object, newname, regrant, tags) values (schema,object, newname, _fullgrant, tags );
		END LOOP;
	END LOOP;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay_relations(schema character varying, object character varying, newname character varying DEFAULT NULL::character varying, tags text[] DEFAULT NULL::text[])
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
			INSERT INTO __regrants (schema, object, newname, regrant, tags) values (schema,object, newname, _fullgrant, tags );
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
			INSERT INTO __regrants (schema, object, newname, regrant, tags) values (schema,object, newname, _fullgrant, tags );
		END LOOP;
	END LOOP;

END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_trigger_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, tags text[] DEFAULT NULL::text[], path text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
BEGIN
	path = path || concat(schema, '.', object);
	PERFORM schema_support.prepare_for_object_replay();

	FOR _r in
		SELECT n.nspname, c.relname, trg.tgname,
				pg_get_triggerdef(trg.oid, true) as def
		FROM pg_trigger trg
			INNER JOIN pg_class c on trg.tgrelid =  c.oid
			INNER JOIN pg_namespace n on n.oid = c.relnamespace
		WHERE n.nspname = schema and c.relname = object
	LOOP
		INSERT INTO __recreate (schema, object, type, ddl, tags , path)
			VALUES (
				_r.nspname, _r.relname, 'trigger', _r.def, tags, path
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

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_view_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, tags text[] DEFAULT NULL::text[], path text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_c		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
	_mat	TEXT;
	_typ	TEXT;
BEGIN
	path = path || concat(schema, '.', object);
	PERFORM schema_support.prepare_for_object_replay();

	-- implicitly save regrants
	PERFORM schema_support.save_grants_for_replay(schema, object, object, tags);

	-- save any triggers on the view
	PERFORM schema_support.save_trigger_for_replay(schema, object, dropit, tags, path);

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
				INSERT INTO __recreate (schema, object, type, ddl, tags, path )
					VALUES (
						_r.nspname, _r.relname, 'default', _ddl, tags, path
					);
			END IF;
			IF _c.comment IS NOT NULL THEN
				_ddl := 'COMMENT ON COLUMN ' ||
					quote_ident(schema) || '.' || quote_ident(object)
					' IS ''' || _c.comment || '''';
				INSERT INTO __recreate (schema, object, type, ddl, tags, path )
					VALUES (
						_r.nspname, _r.relname, 'colcomment', _ddl, tags, path
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
		INSERT INTO __recreate (schema, object, owner, type, ddl, tags, path )
			VALUES (
				_r.nspname, _r.relname, _r.owner, _typ, _ddl, tags, path
			);
		IF dropit  THEN
			_cmd = 'DROP ' || _mat || _r.nspname || '.' || _r.relname || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'build_audit_table_pkak_indexes');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.build_audit_table_pkak_indexes ( aud_schema character varying, tbl_schema character varying, table_name character varying );
CREATE OR REPLACE FUNCTION schema_support.build_audit_table_pkak_indexes(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
		ORDER BY CASE WHEN con.contype = 'p' THEN 0 ELSE 1 END, con.conname
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'build_audit_tables');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.build_audit_tables ( aud_schema character varying, tbl_schema character varying );
CREATE OR REPLACE FUNCTION schema_support.build_audit_tables(aud_schema character varying, tbl_schema character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
     table_list RECORD;
BEGIN
    FOR table_list IN
	SELECT table_name::text FROM information_schema.tables
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
$function$
;

DROP FUNCTION IF EXISTS schema_support.get_common_columns ( _schema text, _table1 text, _table2 text );
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
		CREATE TEMPORARY TABLE IF NOT EXISTS __regrants (id SERIAL, schema text, object text, newname text, regrant text, tags text[]);
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
		CREATE TEMPORARY TABLE IF NOT EXISTS __recreate (id SERIAL, schema text, object text, owner text, type text, ddl text, idargs text, tags text[], path text[]);
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_table');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_table ( aud_schema character varying, tbl_schema character varying, table_name character varying, finish_rebuild boolean );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_table(aud_schema character varying, tbl_schema character varying, table_name character varying, finish_rebuild boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_tables');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_tables ( aud_schema character varying, tbl_schema character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_tables(aud_schema character varying, tbl_schema character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	 table_list RECORD;
BEGIN
	FOR table_list IN
		SELECT b.table_name::text
		FROM information_schema.tables b
			INNER JOIN information_schema.tables a
				USING (table_name,table_type)
		WHERE table_type = 'BASE TABLE'
		AND a.table_schema = aud_schema
		AND b.table_schema = tbl_schema
		ORDER BY table_name
	LOOP
		PERFORM schema_support.save_dependent_objects_for_replay(
			schema := aud_schema::varchar,
			object := table_list.table_name::varchar,
			tags:= ARRAY['rebuild_audit_tables']);
		PERFORM schema_support.save_grants_for_replay(schema := aud_schema,
			object := table_list.table_name,
			tags := ARRAY['rebuild_audit_tables']);
		PERFORM schema_support.rebuild_audit_table
			( aud_schema, tbl_schema, table_list.table_name );
		PERFORM schema_support.replay_object_recreates();
		PERFORM schema_support.replay_saved_grants();
		END LOOP;

	PERFORM schema_support.rebuild_audit_triggers(aud_schema, tbl_schema);
	PERFORM schema_support.replay_object_recreates(tags := ARRAY['rebuild_audit_tables
']);
	PERFORM schema_support.replay_saved_grants(tags := ARRAY['rebuild_audit_tables']);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_triggers');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_triggers ( aud_schema character varying, tbl_schema character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_triggers(aud_schema character varying, tbl_schema character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    table_list RECORD;
BEGIN
    --
    -- select tables with audit tables
    --
    FOR table_list IN
	SELECT table_name::text FROM information_schema.tables
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
	    SELECT table_name::text FROM information_schema.tables
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
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_diff');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_diff ( schema text, old_rel text, new_rel text, key_relation text, prikeys text[], raise_exception boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_diff(schema text, old_rel text, new_rel text, key_relation text DEFAULT NULL::text, prikeys text[] DEFAULT NULL::text[], raise_exception boolean DEFAULT true)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
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
	_oldschema	TEXT;
	_newschema	TEXT;
BEGIN
	IF old_rel ~ '\.' THEN
		_oldschema := regexp_replace(old_rel, '\..*$', '');
		old_rel := regexp_replace(old_rel, '^[^\.]*\.', '');
	ELSE
		_oldschema:= schema;
	END IF;

	IF new_rel ~ '\.' THEN
		_newschema := regexp_replace(new_rel, '\..*$', '');
		new_rel := regexp_replace(new_rel, '^[^\.]*\.', '');
	ELSE
		_newschema:= schema;
	END IF;

	RAISE NOTICE '% % % %', _oldschema, old_rel, _newschema, new_rel;

	-- do a simple row count
	EXECUTE 'SELECT count(*) FROM ' || _oldschema || '."' || old_rel || '"' INTO _t1;
	EXECUTE 'SELECT count(*) FROM ' || _newschema || '."' || new_rel || '"' INTO _t2;

	_rv := true;

	IF _t1 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', _oldschema, old_rel;
		_rv := false;
	END IF;
	IF _t2 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', _oldschema, new_rel;
		_rv := false;
	END IF;

	IF prikeys IS NULL THEN
		-- read into prikeys the primary key for the table
		IF key_relation IS NULL THEN
			key_relation := old_rel;
		END IF;
		prikeys := schema_support.get_pk_columns(_oldschema, key_relation);
	END IF;

	-- read into _cols the column list in common between old_rel and new_rel
	_cols := schema_support.get_common_columns(_oldschema, old_rel, _newschema, new_rel);

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
		_rv := false;
	END IF;

	_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
		quote_ident(_oldschema) || '.' || quote_ident(old_rel)  ||
		' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
			' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
			quote_ident(_oldschema) || '.' || quote_ident(old_rel)  ||
			' EXCEPT ( '
				' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
				quote_ident(_newschema) || '.' || quote_ident(new_rel)  ||
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
		quote_ident(_newschema) || '.' || quote_ident(new_rel)  ||
		' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
			' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
			quote_ident(_newschema) || '.' || quote_ident(new_rel)  ||
			' EXCEPT ( '
				' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
				quote_ident(_oldschema) || '.' || quote_ident(old_rel)  ||
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
			quote_ident(_oldschema) || '.' || quote_ident(old_rel) || ' ) old ' ||
		' JOIN ' ||
		'( SELECT '  || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(_newschema) || '.' || quote_ident(new_rel) || ' ) new ' ||
		' USING ( ' ||  array_to_string(_pkcol,',') ||
		' ) WHERE (' || array_to_string(_pkcol,',') || ' ) IN (' ||
		'SELECT ' || array_to_string(_pkcol,',')  || ' FROM ( ' ||
			'( SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(_oldschema) || '.' || quote_ident(old_rel) ||
			' EXCEPT ' ||
			'( SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(_newschema) || '.' || quote_ident(new_rel) || ' )) ' ||
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
$function$
;

DROP FUNCTION IF EXISTS schema_support.replay_object_recreates ( beverbose boolean );
DROP FUNCTION IF EXISTS schema_support.replay_saved_grants ( beverbose boolean );
DROP FUNCTION IF EXISTS schema_support.save_constraint_for_replay ( schema character varying, object character varying, dropit boolean );
DROP FUNCTION IF EXISTS schema_support.save_dependent_objects_for_replay ( schema character varying, object character varying, dropit boolean, doobjectdeps boolean );
DROP FUNCTION IF EXISTS schema_support.save_function_for_replay ( schema character varying, object character varying, dropit boolean );
DROP FUNCTION IF EXISTS schema_support.save_grants_for_replay ( schema character varying, object character varying, newname character varying );
DROP FUNCTION IF EXISTS schema_support.save_grants_for_replay_functions ( schema character varying, object character varying, newname character varying );
DROP FUNCTION IF EXISTS schema_support.save_grants_for_replay_relations ( schema character varying, object character varying, newname character varying );
DROP FUNCTION IF EXISTS schema_support.save_trigger_for_replay ( schema character varying, object character varying, dropit boolean );
DROP FUNCTION IF EXISTS schema_support.save_view_for_replay ( schema character varying, object character varying, dropit boolean );
-- New function
CREATE OR REPLACE FUNCTION schema_support.get_common_columns(_oldschema text, _table1 text, _newschema text, _table2 text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
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
	    INNER JOIN cols n USING (colname)
		WHERE
			o.schema = $1
		and o.relation = $2
		and n.schema = $3
		and n.relation = $4
		) as prett
	';
	EXECUTE _q INTO cols USING _oldschema, _table1, _newschema, _table2;
	RETURN cols;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.replay_object_recreates(beverbose boolean DEFAULT false, tags text[] DEFAULT NULL::text[], schema text DEFAULT NULL::text, object text DEFAULT NULL::text, type text DEFAULT NULL::text, path text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
			IF tags IS NOT NULL THEN
				CONTINUE WHEN _r.tags IS NULL;
				CONTINUE WHEN NOT _r.tags && tags;
			END IF;
			IF schema IS NOT NULL THEN
				CONTINUE WHEN _r.schema IS NULL;
				CONTINUE WHEN NOT _r.schema = schema;
			END IF;
			IF type IS NOT NULL THEN
				CONTINUE WHEN _r.type IS NULL;
				CONTINUE WHEN NOT _r.type = type;
			END IF;
			IF object IS NOT NULL THEN
				CONTINUE WHEN _r.object IS NULL;
				IF object ~ '^!' THEN
					object = regexp_replace(object, '^!', '');
					CONTINUE WHEN _r.object = object;
				ELSE
					CONTINUE WHEN NOT _r.object = object;
				END IF;
			END IF;

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
			IF tags IS NULL AND schema IS NULL and object IS NULL THEN
				RAISE EXCEPTION '% objects still exist for recreating after a complete loop', _tally;
			END IF;
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
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.replay_saved_grants(beverbose boolean DEFAULT false, schema text DEFAULT NULL::text, tags text DEFAULT NULL::text)
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
			if tags IS NOT NULL THEN
				CONTINUE WHEN _r.tags IS NULL;
				CONTINUE WHEN NOT _r.tags && tags;
			END IF;
			if schema IS NOT NULL THEN
				CONTINUE WHEN _r.schema IS NULL;
				CONTINUE WHEN _r.schema != schema;
			END IF;
		    IF beverbose THEN
			    RAISE NOTICE 'Regrant Executing: %', _r.regrant;
		    END IF;
		    EXECUTE _r.regrant;
		    DELETE from __regrants where id = _r.id;
	    END LOOP;

	    SELECT count(*) INTO _tally from __regrants;
	    IF _tally > 0 THEN
			IF schema IS NULL AND tags IS NULL THEN
				RAISE EXCEPTION 'Grant extractions were run while replaying grants - %.', _tally;
			END IF;
	    ELSE
		    DROP TABLE __regrants;
	    END IF;
	ELSE
		IF beverbose THEN
			RAISE NOTICE '**** WARNING: replay_saved_grants did NOT have anything to regrant!';
		END IF;
	END IF;

END;
$function$
;

-- New function
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
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

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
		                array_agg(attname) as cols
		        FROM (
		            SELECT con.*, a.attname
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
		                array_agg(attname) as cols
		        FROM (
		            SELECT con.*, a.attname
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
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_dependent_objects_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, doobjectdeps boolean DEFAULT false, tags text[] DEFAULT NULL::text[], path text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	RAISE DEBUG 'processing %.%', schema, object;
	path = path || concat(schema, '.', object);
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
		PERFORM schema_support.save_constraint_for_replay(schema := _r.nspname, object := _r.proname, dropit := dropit, tags := tags, path := path);
		PERFORM schema_support.save_dependent_objects_for_replay(_r.nspname, _r.proname, dropit, doobjectdeps, tags, path);
		PERFORM schema_support.save_function_for_replay(_r.nspname, _r.proname, dropit, tags, path);
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
			PERFORM * FROM save_dependent_objects_for_replay(_r.nspname, _r.relname, dropit, doobjectdeps, tags, path);
			PERFORM schema_support.save_view_for_replay(_r.nspname, _r.relname, dropit, tags, path);
		END IF;
	END LOOP;
	IF doobjectdeps THEN
		PERFORM schema_support.save_trigger_for_replay(schema, object, dropit, tags, path);
		PERFORM schema_support.save_constraint_for_replay(schema := 'jazzhands', object := 'table', tags := tags, path := path);
	END IF;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_function_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, tags text[] DEFAULT NULL::text[], path text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
BEGIN
	path = path || concat(schema, '.', object);
	PERFORM schema_support.prepare_for_object_replay();

	-- implicitly save regrants
	PERFORM schema_support.save_grants_for_replay(schema, object, object, tags);
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
		INSERT INTO __recreate (schema, object, type, owner,
			ddl, idargs, tags, path
		) VALUES (
			_r.nspname, _r.proname, 'function', _r.owner,
			_r.funcdef, _r.idargs, tags, path
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

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay(schema character varying, object character varying, newname character varying DEFAULT NULL::character varying, tags text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
	PERFORM schema_support.save_grants_for_replay_relations(schema, object, newname, tags);
	PERFORM schema_support.save_grants_for_replay_functions(schema, object, newname, tags);
END;
$function$
;

-- New function
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
			_fullgrant := 'GRANT ' ||
				_perm.privilege_type || ' on FUNCTION ' ||
				_schema || '.' ||
				newname || '(' || _procs.args || ')  to ' ||
				_role || _grant;
			-- RAISE DEBUG 'inserting % for %', _fullgrant, _perm;
			INSERT INTO __regrants (schema, object, newname, regrant, tags) values (schema,object, newname, _fullgrant, tags );
		END LOOP;
	END LOOP;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay_relations(schema character varying, object character varying, newname character varying DEFAULT NULL::character varying, tags text[] DEFAULT NULL::text[])
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
			INSERT INTO __regrants (schema, object, newname, regrant, tags) values (schema,object, newname, _fullgrant, tags );
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
			INSERT INTO __regrants (schema, object, newname, regrant, tags) values (schema,object, newname, _fullgrant, tags );
		END LOOP;
	END LOOP;

END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_trigger_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, tags text[] DEFAULT NULL::text[], path text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
BEGIN
	path = path || concat(schema, '.', object);
	PERFORM schema_support.prepare_for_object_replay();

	FOR _r in
		SELECT n.nspname, c.relname, trg.tgname,
				pg_get_triggerdef(trg.oid, true) as def
		FROM pg_trigger trg
			INNER JOIN pg_class c on trg.tgrelid =  c.oid
			INNER JOIN pg_namespace n on n.oid = c.relnamespace
		WHERE n.nspname = schema and c.relname = object
	LOOP
		INSERT INTO __recreate (schema, object, type, ddl, tags , path)
			VALUES (
				_r.nspname, _r.relname, 'trigger', _r.def, tags, path
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

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_view_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, tags text[] DEFAULT NULL::text[], path text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_c		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
	_mat	TEXT;
	_typ	TEXT;
BEGIN
	path = path || concat(schema, '.', object);
	PERFORM schema_support.prepare_for_object_replay();

	-- implicitly save regrants
	PERFORM schema_support.save_grants_for_replay(schema, object, object, tags);

	-- save any triggers on the view
	PERFORM schema_support.save_trigger_for_replay(schema, object, dropit, tags, path);

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
				INSERT INTO __recreate (schema, object, type, ddl, tags, path )
					VALUES (
						_r.nspname, _r.relname, 'default', _ddl, tags, path
					);
			END IF;
			IF _c.comment IS NOT NULL THEN
				_ddl := 'COMMENT ON COLUMN ' ||
					quote_ident(schema) || '.' || quote_ident(object)
					' IS ''' || _c.comment || '''';
				INSERT INTO __recreate (schema, object, type, ddl, tags, path )
					VALUES (
						_r.nspname, _r.relname, 'colcomment', _ddl, tags, path
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
		INSERT INTO __recreate (schema, object, owner, type, ddl, tags, path )
			VALUES (
				_r.nspname, _r.relname, _r.owner, _typ, _ddl, tags, path
			);
		IF dropit  THEN
			_cmd = 'DROP ' || _mat || _r.nspname || '.' || _r.relname || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;
END;
$function$
;

-- DONE: process_ancillary_schema(schema_support)
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'account_password_manip';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS account_password_manip;
		CREATE SCHEMA account_password_manip AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA account_password_manip IS 'part of jazzhands';
	END IF;
END;
			$$;DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'obfuscation_utils';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS obfuscation_utils;
		CREATE SCHEMA obfuscation_utils AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA obfuscation_utils IS 'part of jazzhands';
	END IF;
END;
			$$;--
-- Process middle (non-trigger) schema jazzhands_cache
--
--
-- Process middle (non-trigger) schema schema_support
--
-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'build_audit_table_pkak_indexes');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.build_audit_table_pkak_indexes ( aud_schema character varying, tbl_schema character varying, table_name character varying );
CREATE OR REPLACE FUNCTION schema_support.build_audit_table_pkak_indexes(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
		ORDER BY CASE WHEN con.contype = 'p' THEN 0 ELSE 1 END, con.conname
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'build_audit_tables');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.build_audit_tables ( aud_schema character varying, tbl_schema character varying );
CREATE OR REPLACE FUNCTION schema_support.build_audit_tables(aud_schema character varying, tbl_schema character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
     table_list RECORD;
BEGIN
    FOR table_list IN
	SELECT table_name::text FROM information_schema.tables
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
		CREATE TEMPORARY TABLE IF NOT EXISTS __regrants (id SERIAL, schema text, object text, newname text, regrant text, tags text[]);
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
		CREATE TEMPORARY TABLE IF NOT EXISTS __recreate (id SERIAL, schema text, object text, owner text, type text, ddl text, idargs text, tags text[], path text[]);
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_table');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_table ( aud_schema character varying, tbl_schema character varying, table_name character varying, finish_rebuild boolean );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_table(aud_schema character varying, tbl_schema character varying, table_name character varying, finish_rebuild boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_tables');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_tables ( aud_schema character varying, tbl_schema character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_tables(aud_schema character varying, tbl_schema character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	 table_list RECORD;
BEGIN
	FOR table_list IN
		SELECT b.table_name::text
		FROM information_schema.tables b
			INNER JOIN information_schema.tables a
				USING (table_name,table_type)
		WHERE table_type = 'BASE TABLE'
		AND a.table_schema = aud_schema
		AND b.table_schema = tbl_schema
		ORDER BY table_name
	LOOP
		PERFORM schema_support.save_dependent_objects_for_replay(
			schema := aud_schema::varchar,
			object := table_list.table_name::varchar,
			tags:= ARRAY['rebuild_audit_tables']);
		PERFORM schema_support.save_grants_for_replay(schema := aud_schema,
			object := table_list.table_name,
			tags := ARRAY['rebuild_audit_tables']);
		PERFORM schema_support.rebuild_audit_table
			( aud_schema, tbl_schema, table_list.table_name );
		PERFORM schema_support.replay_object_recreates();
		PERFORM schema_support.replay_saved_grants();
		END LOOP;

	PERFORM schema_support.rebuild_audit_triggers(aud_schema, tbl_schema);
	PERFORM schema_support.replay_object_recreates(tags := ARRAY['rebuild_audit_tables
']);
	PERFORM schema_support.replay_saved_grants(tags := ARRAY['rebuild_audit_tables']);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_triggers');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_triggers ( aud_schema character varying, tbl_schema character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_triggers(aud_schema character varying, tbl_schema character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    table_list RECORD;
BEGIN
    --
    -- select tables with audit tables
    --
    FOR table_list IN
	SELECT table_name::text FROM information_schema.tables
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
	    SELECT table_name::text FROM information_schema.tables
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
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_diff');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_diff ( schema text, old_rel text, new_rel text, key_relation text, prikeys text[], raise_exception boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_diff(schema text, old_rel text, new_rel text, key_relation text DEFAULT NULL::text, prikeys text[] DEFAULT NULL::text[], raise_exception boolean DEFAULT true)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
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
	_oldschema	TEXT;
	_newschema	TEXT;
BEGIN
	IF old_rel ~ '\.' THEN
		_oldschema := regexp_replace(old_rel, '\..*$', '');
		old_rel := regexp_replace(old_rel, '^[^\.]*\.', '');
	ELSE
		_oldschema:= schema;
	END IF;

	IF new_rel ~ '\.' THEN
		_newschema := regexp_replace(new_rel, '\..*$', '');
		new_rel := regexp_replace(new_rel, '^[^\.]*\.', '');
	ELSE
		_newschema:= schema;
	END IF;

	RAISE NOTICE '% % % %', _oldschema, old_rel, _newschema, new_rel;

	-- do a simple row count
	EXECUTE 'SELECT count(*) FROM ' || _oldschema || '."' || old_rel || '"' INTO _t1;
	EXECUTE 'SELECT count(*) FROM ' || _newschema || '."' || new_rel || '"' INTO _t2;

	_rv := true;

	IF _t1 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', _oldschema, old_rel;
		_rv := false;
	END IF;
	IF _t2 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', _oldschema, new_rel;
		_rv := false;
	END IF;

	IF prikeys IS NULL THEN
		-- read into prikeys the primary key for the table
		IF key_relation IS NULL THEN
			key_relation := old_rel;
		END IF;
		prikeys := schema_support.get_pk_columns(_oldschema, key_relation);
	END IF;

	-- read into _cols the column list in common between old_rel and new_rel
	_cols := schema_support.get_common_columns(_oldschema, old_rel, _newschema, new_rel);

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
		_rv := false;
	END IF;

	_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
		quote_ident(_oldschema) || '.' || quote_ident(old_rel)  ||
		' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
			' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
			quote_ident(_oldschema) || '.' || quote_ident(old_rel)  ||
			' EXCEPT ( '
				' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
				quote_ident(_newschema) || '.' || quote_ident(new_rel)  ||
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
		quote_ident(_newschema) || '.' || quote_ident(new_rel)  ||
		' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
			' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
			quote_ident(_newschema) || '.' || quote_ident(new_rel)  ||
			' EXCEPT ( '
				' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
				quote_ident(_oldschema) || '.' || quote_ident(old_rel)  ||
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
			quote_ident(_oldschema) || '.' || quote_ident(old_rel) || ' ) old ' ||
		' JOIN ' ||
		'( SELECT '  || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(_newschema) || '.' || quote_ident(new_rel) || ' ) new ' ||
		' USING ( ' ||  array_to_string(_pkcol,',') ||
		' ) WHERE (' || array_to_string(_pkcol,',') || ' ) IN (' ||
		'SELECT ' || array_to_string(_pkcol,',')  || ' FROM ( ' ||
			'( SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(_oldschema) || '.' || quote_ident(old_rel) ||
			' EXCEPT ' ||
			'( SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(_newschema) || '.' || quote_ident(new_rel) || ' )) ' ||
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
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.get_common_columns(_oldschema text, _table1 text, _newschema text, _table2 text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
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
	    INNER JOIN cols n USING (colname)
		WHERE
			o.schema = $1
		and o.relation = $2
		and n.schema = $3
		and n.relation = $4
		) as prett
	';
	EXECUTE _q INTO cols USING _oldschema, _table1, _newschema, _table2;
	RETURN cols;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.replay_object_recreates(beverbose boolean DEFAULT false, tags text[] DEFAULT NULL::text[], schema text DEFAULT NULL::text, object text DEFAULT NULL::text, type text DEFAULT NULL::text, path text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
			IF tags IS NOT NULL THEN
				CONTINUE WHEN _r.tags IS NULL;
				CONTINUE WHEN NOT _r.tags && tags;
			END IF;
			IF schema IS NOT NULL THEN
				CONTINUE WHEN _r.schema IS NULL;
				CONTINUE WHEN NOT _r.schema = schema;
			END IF;
			IF type IS NOT NULL THEN
				CONTINUE WHEN _r.type IS NULL;
				CONTINUE WHEN NOT _r.type = type;
			END IF;
			IF object IS NOT NULL THEN
				CONTINUE WHEN _r.object IS NULL;
				IF object ~ '^!' THEN
					object = regexp_replace(object, '^!', '');
					CONTINUE WHEN _r.object = object;
				ELSE
					CONTINUE WHEN NOT _r.object = object;
				END IF;
			END IF;

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
			IF tags IS NULL AND schema IS NULL and object IS NULL THEN
				RAISE EXCEPTION '% objects still exist for recreating after a complete loop', _tally;
			END IF;
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
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.replay_saved_grants(beverbose boolean DEFAULT false, schema text DEFAULT NULL::text, tags text DEFAULT NULL::text)
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
			if tags IS NOT NULL THEN
				CONTINUE WHEN _r.tags IS NULL;
				CONTINUE WHEN NOT _r.tags && tags;
			END IF;
			if schema IS NOT NULL THEN
				CONTINUE WHEN _r.schema IS NULL;
				CONTINUE WHEN _r.schema != schema;
			END IF;
		    IF beverbose THEN
			    RAISE NOTICE 'Regrant Executing: %', _r.regrant;
		    END IF;
		    EXECUTE _r.regrant;
		    DELETE from __regrants where id = _r.id;
	    END LOOP;

	    SELECT count(*) INTO _tally from __regrants;
	    IF _tally > 0 THEN
			IF schema IS NULL AND tags IS NULL THEN
				RAISE EXCEPTION 'Grant extractions were run while replaying grants - %.', _tally;
			END IF;
	    ELSE
		    DROP TABLE __regrants;
	    END IF;
	ELSE
		IF beverbose THEN
			RAISE NOTICE '**** WARNING: replay_saved_grants did NOT have anything to regrant!';
		END IF;
	END IF;

END;
$function$
;

-- New function
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
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

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
		                array_agg(attname) as cols
		        FROM (
		            SELECT con.*, a.attname
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
		                array_agg(attname) as cols
		        FROM (
		            SELECT con.*, a.attname
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
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_dependent_objects_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, doobjectdeps boolean DEFAULT false, tags text[] DEFAULT NULL::text[], path text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	RAISE DEBUG 'processing %.%', schema, object;
	path = path || concat(schema, '.', object);
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
		PERFORM schema_support.save_constraint_for_replay(schema := _r.nspname, object := _r.proname, dropit := dropit, tags := tags, path := path);
		PERFORM schema_support.save_dependent_objects_for_replay(_r.nspname, _r.proname, dropit, doobjectdeps, tags, path);
		PERFORM schema_support.save_function_for_replay(_r.nspname, _r.proname, dropit, tags, path);
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
			PERFORM * FROM save_dependent_objects_for_replay(_r.nspname, _r.relname, dropit, doobjectdeps, tags, path);
			PERFORM schema_support.save_view_for_replay(_r.nspname, _r.relname, dropit, tags, path);
		END IF;
	END LOOP;
	IF doobjectdeps THEN
		PERFORM schema_support.save_trigger_for_replay(schema, object, dropit, tags, path);
		PERFORM schema_support.save_constraint_for_replay(schema := 'jazzhands', object := 'table', tags := tags, path := path);
	END IF;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_function_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, tags text[] DEFAULT NULL::text[], path text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
BEGIN
	path = path || concat(schema, '.', object);
	PERFORM schema_support.prepare_for_object_replay();

	-- implicitly save regrants
	PERFORM schema_support.save_grants_for_replay(schema, object, object, tags);
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
		INSERT INTO __recreate (schema, object, type, owner,
			ddl, idargs, tags, path
		) VALUES (
			_r.nspname, _r.proname, 'function', _r.owner,
			_r.funcdef, _r.idargs, tags, path
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

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay(schema character varying, object character varying, newname character varying DEFAULT NULL::character varying, tags text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
	PERFORM schema_support.save_grants_for_replay_relations(schema, object, newname, tags);
	PERFORM schema_support.save_grants_for_replay_functions(schema, object, newname, tags);
END;
$function$
;

-- New function
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
			_fullgrant := 'GRANT ' ||
				_perm.privilege_type || ' on FUNCTION ' ||
				_schema || '.' ||
				newname || '(' || _procs.args || ')  to ' ||
				_role || _grant;
			-- RAISE DEBUG 'inserting % for %', _fullgrant, _perm;
			INSERT INTO __regrants (schema, object, newname, regrant, tags) values (schema,object, newname, _fullgrant, tags );
		END LOOP;
	END LOOP;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay_relations(schema character varying, object character varying, newname character varying DEFAULT NULL::character varying, tags text[] DEFAULT NULL::text[])
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
			INSERT INTO __regrants (schema, object, newname, regrant, tags) values (schema,object, newname, _fullgrant, tags );
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
			INSERT INTO __regrants (schema, object, newname, regrant, tags) values (schema,object, newname, _fullgrant, tags );
		END LOOP;
	END LOOP;

END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_trigger_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, tags text[] DEFAULT NULL::text[], path text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
BEGIN
	path = path || concat(schema, '.', object);
	PERFORM schema_support.prepare_for_object_replay();

	FOR _r in
		SELECT n.nspname, c.relname, trg.tgname,
				pg_get_triggerdef(trg.oid, true) as def
		FROM pg_trigger trg
			INNER JOIN pg_class c on trg.tgrelid =  c.oid
			INNER JOIN pg_namespace n on n.oid = c.relnamespace
		WHERE n.nspname = schema and c.relname = object
	LOOP
		INSERT INTO __recreate (schema, object, type, ddl, tags , path)
			VALUES (
				_r.nspname, _r.relname, 'trigger', _r.def, tags, path
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

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_view_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, tags text[] DEFAULT NULL::text[], path text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_c		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
	_mat	TEXT;
	_typ	TEXT;
BEGIN
	path = path || concat(schema, '.', object);
	PERFORM schema_support.prepare_for_object_replay();

	-- implicitly save regrants
	PERFORM schema_support.save_grants_for_replay(schema, object, object, tags);

	-- save any triggers on the view
	PERFORM schema_support.save_trigger_for_replay(schema, object, dropit, tags, path);

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
				INSERT INTO __recreate (schema, object, type, ddl, tags, path )
					VALUES (
						_r.nspname, _r.relname, 'default', _ddl, tags, path
					);
			END IF;
			IF _c.comment IS NOT NULL THEN
				_ddl := 'COMMENT ON COLUMN ' ||
					quote_ident(schema) || '.' || quote_ident(object)
					' IS ''' || _c.comment || '''';
				INSERT INTO __recreate (schema, object, type, ddl, tags, path )
					VALUES (
						_r.nspname, _r.relname, 'colcomment', _ddl, tags, path
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
		INSERT INTO __recreate (schema, object, owner, type, ddl, tags, path )
			VALUES (
				_r.nspname, _r.relname, _r.owner, _typ, _ddl, tags, path
			);
		IF dropit  THEN
			_cmd = 'DROP ' || _mat || _r.nspname || '.' || _r.relname || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;
END;
$function$
;

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
-- Process middle (non-trigger) schema property_utils
--
--
-- Process middle (non-trigger) schema netblock_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'allocate_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock ( parent_netblock_id integer, netmask_bits integer, address_type text, can_subnet boolean, allocation_method text, rnd_masklen_threshold integer, rnd_max_count integer, ip_address inet, description character varying, netblock_status character varying );
CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(parent_netblock_id integer, netmask_bits integer DEFAULT NULL::integer, address_type text DEFAULT 'netblock'::text, can_subnet boolean DEFAULT true, allocation_method text DEFAULT NULL::text, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024, ip_address inet DEFAULT NULL::inet, description character varying DEFAULT NULL::character varying, netblock_status character varying DEFAULT 'Allocated'::character varying)
 RETURNS SETOF jazzhands.netblock
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	netblock_rec	RECORD;
BEGIN
	RETURN QUERY
		SELECT * into netblock_rec FROM netblock_manip.allocate_netblock(
		parent_netblock_list := ARRAY[parent_netblock_id],
		netmask_bits := netmask_bits,
		address_type := address_type,
		can_subnet := can_subnet,
		description := description,
		allocation_method := allocation_method,
		ip_address := ip_address,
		rnd_masklen_threshold := rnd_masklen_threshold,
		rnd_max_count := rnd_max_count,
		netblock_status := netblock_status
	);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'allocate_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock ( parent_netblock_list integer[], netmask_bits integer, address_type text, can_subnet boolean, allocation_method text, rnd_masklen_threshold integer, rnd_max_count integer, ip_address inet, description character varying, netblock_status character varying );
CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(parent_netblock_list integer[], netmask_bits integer DEFAULT NULL::integer, address_type text DEFAULT 'netblock'::text, can_subnet boolean DEFAULT true, allocation_method text DEFAULT NULL::text, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024, ip_address inet DEFAULT NULL::inet, description character varying DEFAULT NULL::character varying, netblock_status character varying DEFAULT 'Allocated'::character varying)
 RETURNS SETOF jazzhands.netblock
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	parent_rec		RECORD;
	netblock_rec	RECORD;
	inet_rec		RECORD;
	loopback_bits	integer;
	inet_family		integer;
	ip_addr			ALIAS FOR ip_address;
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

	IF ip_address IS NOT NULL THEN
		SELECT
			array_agg(netblock_id)
		INTO
			parent_netblock_list
		FROM
			netblock n
		WHERE
			ip_addr <<= n.ip_address AND
			netblock_id = ANY(parent_netblock_list);

		IF parent_netblock_list IS NULL THEN
			RETURN;
		END IF;
	END IF;

	-- Lock the parent row, which should keep parallel processes from
	-- trying to obtain the same address

	FOR parent_rec IN SELECT * FROM jazzhands.netblock WHERE netblock_id =
			ANY(allocate_netblock.parent_netblock_list) ORDER BY netblock_id
			FOR UPDATE LOOP

		IF parent_rec.is_single_address = 'Y' THEN
			RAISE EXCEPTION 'parent_netblock_id refers to a single_address netblock'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF inet_family IS NULL THEN
			inet_family := family(parent_rec.ip_address);
		ELSIF inet_family != family(parent_rec.ip_address)
				AND ip_address IS NULL THEN
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
 		RETURN;
 	END IF;

	IF address_type = 'loopback' THEN
		-- If we're allocating a loopback address, then we need to create
		-- a new parent to hold the single loopback address

		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			netmask_bits := loopback_bits,
			single_address := false,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			max_addresses := 1
			);

		IF NOT FOUND THEN
			RETURN;
		END IF;

		INSERT INTO jazzhands.netblock (
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
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO parent_rec;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			parent_rec.netblock_type,
			'Y',
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		PERFORM dns_utils.add_domains_from_netblock(
			netblock_id := netblock_rec.netblock_id);

		RETURN NEXT netblock_rec;
		RETURN;
	END IF;

	IF address_type = 'single' THEN
		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			single_address := true,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			rnd_masklen_threshold := rnd_masklen_threshold,
			rnd_max_count := rnd_max_count,
			max_addresses := 1
			);

		IF NOT FOUND THEN
			RETURN;
		END IF;

		RAISE DEBUG 'ip_address is %', inet_rec.ip_address;

		INSERT INTO jazzhands.netblock (
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

		RETURN NEXT netblock_rec;
		RETURN;
	END IF;
	IF address_type = 'netblock' THEN
		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			netmask_bits := netmask_bits,
			single_address := false,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			max_addresses := 1);

		IF NOT FOUND THEN
			RETURN;
		END IF;

		INSERT INTO jazzhands.netblock (
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

		RAISE DEBUG 'Allocated netblock_id % for %',
			netblock_rec.netblock_id,
			netblock_rec.ip_address;

		PERFORM dns_utils.add_domains_from_netblock(
			netblock_id := netblock_rec.netblock_id);

		RETURN NEXT netblock_rec;
		RETURN;
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'create_network_range');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.create_network_range ( start_ip_address inet, stop_ip_address inet, network_range_type character varying, parent_netblock_id integer, description character varying, allow_assigned boolean, dns_prefix text, dns_domain_id integer, lease_time integer );
CREATE OR REPLACE FUNCTION netblock_manip.create_network_range(start_ip_address inet, stop_ip_address inet, network_range_type character varying, parent_netblock_id integer DEFAULT NULL::integer, description character varying DEFAULT NULL::character varying, allow_assigned boolean DEFAULT false, dns_prefix text DEFAULT NULL::text, dns_domain_id integer DEFAULT NULL::integer, lease_time integer DEFAULT NULL::integer)
 RETURNS jazzhands.network_range
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	par_netblock	RECORD;
	start_netblock	RECORD;
	stop_netblock	RECORD;
	netrange		RECORD;
	nrtype			ALIAS FOR network_range_type;
	pnbid			ALIAS FOR parent_netblock_id;
BEGIN
	--
	-- If the network range already exists, then just return it
	--
	SELECT
		nr.* INTO netrange
	FROM
		jazzhands.network_range nr JOIN
		jazzhands.netblock startnb ON (nr.start_netblock_id =
			startnb.netblock_id) JOIN
		jazzhands.netblock stopnb ON (nr.stop_netblock_id = stopnb.netblock_id)
	WHERE
		nr.network_range_type = nrtype AND
		host(startnb.ip_address) = host(start_ip_address) AND
		host(stopnb.ip_address) = host(stop_ip_address) AND
		CASE WHEN pnbid IS NOT NULL THEN
			(pnbid = nr.parent_netblock_id)
		ELSE
			true
		END;

	IF FOUND THEN
		RETURN netrange;
	END IF;

	--
	-- If any other network ranges exist that overlap this, then error
	--
	PERFORM
		*
	FROM
		jazzhands.network_range nr JOIN
		jazzhands.netblock startnb ON
			(nr.start_netblock_id = startnb.netblock_id) JOIN
		jazzhands.netblock stopnb ON (nr.stop_netblock_id = stopnb.netblock_id)
	WHERE
		nr.network_range_type = nrtype AND ((
			host(startnb.ip_address)::inet <= host(start_ip_address)::inet AND
			host(stopnb.ip_address)::inet >= host(start_ip_address)::inet
		) OR (
			host(startnb.ip_address)::inet <= host(stop_ip_address)::inet AND
			host(stopnb.ip_address)::inet >= host(stop_ip_address)::inet
		));

	IF FOUND THEN
		RAISE 'create_network_range: a network_range of type % already exists that has addresses between % and %',
			nrtype, start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
	END IF;

	IF parent_netblock_id IS NOT NULL THEN
		SELECT * INTO par_netblock FROM jazzhands.netblock WHERE
			netblock_id = pnbid;
		IF NOT FOUND THEN
			RAISE 'create_network_range: parent_netblock_id % does not exist',
				parent_netblock_id USING ERRCODE = 'foreign_key_violation';
		END IF;
	ELSE
		SELECT * INTO par_netblock FROM jazzhands.netblock WHERE netblock_id = (
			SELECT
				*
			FROM
				netblock_utils.find_best_parent_id(
					in_ipaddress := start_ip_address,
					in_is_single_address := 'Y'
				)
		);

		IF NOT FOUND THEN
			RAISE 'create_network_range: valid parent netblock for start_ip_address % does not exist',
				start_ip_address USING ERRCODE = 'check_violation';
		END IF;
	END IF;

	IF par_netblock.can_subnet != 'N' OR
			par_netblock.is_single_address != 'N' THEN
		RAISE 'create_network_range: parent netblock % must not be subnettable or a single address',
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (start_ip_address <<= par_netblock.ip_address) THEN
		RAISE 'create_network_range: start_ip_address % is not contained by parent netblock % (%)',
			start_ip_address, par_netblock.ip_address,
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (stop_ip_address <<= par_netblock.ip_address) THEN
		RAISE 'create_network_range: stop_ip_address % is not contained by parent netblock % (%)',
			stop_ip_address, par_netblock.ip_address,
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (start_ip_address <= stop_ip_address) THEN
		RAISE 'create_network_range: start_ip_address % is not lower than stop_ip_address %',
			start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
	END IF;

	--
	-- Validate that there are not currently any addresses assigned in the
	-- range, unless allow_assigned is set
	--
	IF NOT allow_assigned THEN
		PERFORM
			*
		FROM
			jazzhands.netblock n
		WHERE
			n.parent_netblock_id = par_netblock.netblock_id AND
			host(n.ip_address)::inet > host(start_ip_address)::inet AND
			host(n.ip_address)::inet < host(stop_ip_address)::inet;

		IF FOUND THEN
			RAISE 'create_network_range: netblocks are already present for parent netblock % betweeen % and %',
			par_netblock.netblock_id,
			start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
		END IF;
	END IF;

	--
	-- Ok, well, we should be able to insert things now
	--

	SELECT
		*
	FROM
		jazzhands.netblock n
	INTO
		start_netblock
	WHERE
		host(n.ip_address)::inet = start_ip_address AND
		n.netblock_type = 'network_range' AND
		n.can_subnet = 'N' AND
		n.is_single_address = 'Y' AND
		n.ip_universe_id = par_netblock.ip_universe_id;

	IF NOT FOUND THEN
		INSERT INTO netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			netblock_status,
			ip_universe_id
		) VALUES (
			host(start_ip_address)::inet,
			'network_range',
			'Y',
			'N',
			'Allocated',
			par_netblock.ip_universe_id
		) RETURNING * INTO start_netblock;
	END IF;

	SELECT
		*
	FROM
		jazzhands.netblock n
	INTO
		stop_netblock
	WHERE
		host(n.ip_address)::inet = stop_ip_address AND
		n.netblock_type = 'network_range' AND
		n.can_subnet = 'N' AND
		n.is_single_address = 'Y' AND
		n.ip_universe_id = par_netblock.ip_universe_id;

	IF NOT FOUND THEN
		INSERT INTO netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			netblock_status,
			ip_universe_id
		) VALUES (
			host(stop_ip_address)::inet,
			'network_range',
			'Y',
			'N',
			'Allocated',
			par_netblock.ip_universe_id
		) RETURNING * INTO stop_netblock;
	END IF;

	INSERT INTO network_range (
		network_range_type,
		description,
		parent_netblock_id,
		start_netblock_id,
		stop_netblock_id,
		dns_prefix,
		dns_domain_id,
		lease_time
	) VALUES (
		nrtype,
		description,
		par_netblock.netblock_id,
		start_netblock.netblock_id,
		stop_netblock.netblock_id,
		create_network_range.dns_prefix,
		create_network_range.dns_domain_id,
		create_network_range.lease_time
	) RETURNING * INTO netrange;

	RETURN netrange;

	RETURN NULL;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'set_interface_addresses');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.set_interface_addresses ( network_interface_id integer, device_id integer, network_interface_name text, network_interface_type text, ip_address_hash jsonb, create_layer3_networks boolean, move_addresses text, address_errors text );
CREATE OR REPLACE FUNCTION netblock_manip.set_interface_addresses(network_interface_id integer DEFAULT NULL::integer, device_id integer DEFAULT NULL::integer, network_interface_name text DEFAULT NULL::text, network_interface_type text DEFAULT 'broadcast'::text, ip_address_hash jsonb DEFAULT NULL::jsonb, create_layer3_networks boolean DEFAULT false, move_addresses text DEFAULT 'if_same_device'::text, address_errors text DEFAULT 'error'::text)
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
	ni_id			ALIAS FOR network_interface_id;
	dev_id			ALIAS FOR device_id;
	ni_name			ALIAS FOR network_interface_name;
	ni_type			ALIAS FOR network_interface_type;

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
	ni_rec			RECORD;
	nin_rec			RECORD;
	nb_id			jazzhands.netblock.netblock_id%TYPE;
	nb_id_ary		integer[];
	ni_id_ary		integer[];
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

	IF network_interface_id IS NULL THEN
		IF device_id IS NULL OR network_interface_name IS NULL THEN
			RAISE 'netblock_manip.assign_shared_netblock: must pass either network_interface_id or device_id and network_interface_name'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;

		SELECT
			ni.network_interface_id INTO ni_id
		FROM
			network_interface ni
		WHERE
			ni.device_id = dev_id AND
			ni.network_interface_name = ni_name;

		IF NOT FOUND THEN
			INSERT INTO network_interface(
				device_id,
				network_interface_name,
				network_interface_type,
				should_monitor
			) VALUES (
				dev_id,
				ni_name,
				ni_type,
				'N'
			) RETURNING network_interface.network_interface_id INTO ni_id;
		END IF;
	END IF;

	SELECT * INTO ni_rec FROM network_interface ni WHERE
		ni.network_interface_id = ni_id;

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
				v_netblock_coll_expanded nce USING (netblock_collection_id)
					JOIN
				property p ON (
					property_name = 'IgnoreProbedNetblocks' AND
					property_type = 'DeviceInventory' AND
					property_value_nblk_coll_id =
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
			-- Look for an is_single_address='Y', can_subnet='N' netblock
			-- with the given ip_address
			--
			SELECT
				* INTO nb_rec
			FROM
				netblock n
			WHERE
				is_single_address = 'Y' AND
				can_subnet = 'N' AND
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
					is_single_address = 'N' AND
					can_subnet = 'N' AND
					n.ip_address >>= ipaddr;

				IF NOT FOUND THEN
					RAISE DEBUG 'Parent netblock with ip_address %, netblock_type %, ip_universe_id % not found',
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					--
					-- Check to see if the netblock exists, but is
					-- marked can_subnet='Y'.  If so, fix it
					--
					SELECT
						* INTO pnb_rec
					FROM
						netblock n
					WHERE
						n.ip_universe_id = universe AND
						n.netblock_type = nb_type AND
						n.is_single_address = 'N' AND
						n.can_subnet = 'Y' AND
						n.ip_address = network(ipaddr);

					IF FOUND THEN
						UPDATE netblock n SET
							can_subnet = 'N'
						WHERE
							n.netblock_id = pnb_rec.netblock_id;
						pnb_rec.can_subnet = 'N';
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
							'N',
							'N',
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
					'Y',
					'N',
					'Allocated'
				) RETURNING * INTO nb_rec;
				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);
			END IF;
			--
			-- Now that we have the netblock and everything, check to see
			-- if this netblock is already assigned to this network_interface
			--
			PERFORM * FROM
				network_interface_netblock nin
			WHERE
				nin.netblock_id = nb_rec.netblock_id AND
				nin.network_interface_id = ni_id;

			IF FOUND THEN
				RAISE DEBUG 'Netblock % already found on network_interface',
					nb_rec.netblock_id;
				CONTINUE;
			END IF;

			--
			-- See if this netblock is on something else, and delete it
			-- if move_addresses is set, otherwise skip it
			--
			SELECT
				ni.network_interface_id,
				ni.network_interface_name,
				nin.netblock_id,
				d.device_id,
				COALESCE(d.device_name, d.physical_label) AS device_name
			INTO nin_rec
			FROM
				network_interface_netblock nin JOIN
				network_interface ni USING (network_interface_id) JOIN
				device d ON (nin.device_id = d.device_id)
			WHERE
				nin.netblock_id = nb_rec.netblock_id AND
				nin.network_interface_id != ni_id;

			IF FOUND THEN
				IF move_addresses = 'always' OR (
					move_addresses = 'if_same_device' AND
					nin_rec.device_id = ni_rec.device_id
				)
				THEN
					DELETE FROM
						network_interface_netblock
					WHERE
						netblock_id = nb_rec.netblock_id;
				ELSE
					IF address_errors = 'ignore' THEN
						RAISE DEBUG 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;

						CONTINUE;
					ELSIF address_errors = 'warn' THEN
						RAISE NOTICE 'Netblock % (%) is assigned to network_interface % (%) on device % (%)',
							nb_rec.netblock_id,
							nb_rec.ip_address,
							nin_rec.network_interface_id,
							nin_rec.network_interface_name,
							nin_rec.device_id,
							nin_rec.device_name;

						CONTINUE;
					ELSE
						RAISE 'Netblock % (%) is assigned to network_interface %(%) on device % (%)',
							nb_rec.netblock_id,
							nb_rec.ip_address,
							nin_rec.network_interface_id,
							nin_rec.network_interface_name,
							nin_rec.device_id,
							nin_rec.device_name;
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
					shared_netblock_network_int snni
				WHERE
					snni.shared_netblock_id = sn_rec.shared_netblock_id;

				DELETE FROM
					shared_network sn
				WHERE
					sn.netblock_id = sn_rec.shared_netblock_id;
			END IF;

			--
			-- Insert the netblock onto the interface using the next
			-- rank
			--
			INSERT INTO network_interface_netblock (
				network_interface_id,
				netblock_id,
				network_interface_rank
			) SELECT
				ni_id,
				nb_rec.netblock_id,
				COALESCE(MAX(network_interface_rank) + 1, 0)
			FROM
				network_interface_netblock nin
			WHERE
				nin.network_interface_id = ni_id
			RETURNING * INTO nin_rec;

			RAISE DEBUG E'Inserted into:\n%',
				jsonb_pretty(to_jsonb(nin_rec));
		END LOOP;
		--
		-- Remove any netblocks that are on the interface that are not
		-- supposed to be (and that aren't ignored).
		--

		FOR nin_rec IN
			DELETE FROM
				network_interface_netblock nin
			WHERE
				(nin.network_interface_id, nin.netblock_id) IN (
				SELECT
					nin2.network_interface_id,
					nin2.netblock_id
				FROM
					network_interface_netblock nin2 JOIN
					netblock n USING (netblock_id)
				WHERE
					nin2.network_interface_id = ni_id AND NOT (
						nin.netblock_id = ANY(nb_id_ary) OR
						n.ip_address <<= ANY ( ARRAY (
							SELECT
								n2.ip_address
							FROM
								netblock n2 JOIN
								netblock_collection_netblock ncn USING
									(netblock_id) JOIN
								v_netblock_coll_expanded nce USING
									(netblock_collection_id) JOIN
								property p ON (
									property_name = 'IgnoreProbedNetblocks' AND
									property_type = 'DeviceInventory' AND
									property_value_nblk_coll_id =
										nce.root_netblock_collection_id
								)
						))
					)
			)
			RETURNING *
		LOOP
			RAISE DEBUG 'Removed netblock % from network_interface %',
				nin_rec.netblock_id,
				nin_rec.network_interface_id;
			--
			-- Remove any DNS records and/or netblocks that aren't used
			--
			BEGIN
				DELETE FROM dns_record WHERE netblock_id = nin_rec.netblock_id;
				DELETE FROM netblock_collection_netblock WHERE
					netblock_id = nin_rec.netblock_id;
				DELETE FROM netblock WHERE netblock_id =
					nin_rec.netblock_id;
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
				v_netblock_coll_expanded nce USING (netblock_collection_id)
					JOIN
				property p ON (
					property_name = 'IgnoreProbedNetblocks' AND
					property_type = 'DeviceInventory' AND
					property_value_nblk_coll_id =
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
			-- Look for an is_single_address='Y', can_subnet='N' netblock
			-- with the given ip_address
			--
			SELECT
				* INTO nb_rec
			FROM
				netblock n
			WHERE
				is_single_address = 'Y' AND
				can_subnet = 'N' AND
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
					is_single_address = 'N' AND
					can_subnet = 'N' AND
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
							'N',
							'N',
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
					'Y',
					'N',
					'Allocated'
				) RETURNING * INTO nb_rec;
				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);
			END IF;

			--
			-- See if this netblock is directly on any network_interface, and
			-- delete it if force is set, otherwise skip it
			--
			ni_id_ary := ARRAY[]::integer[];

			SELECT
				ni.network_interface_id,
				nin.netblock_id,
				ni.device_id
			INTO nin_rec
			FROM
				network_interface_netblock nin JOIN
				network_interface ni USING (network_interface_id)
			WHERE
				nin.netblock_id = nb_rec.netblock_id AND
				nin.network_interface_id != ni_id;

			IF FOUND THEN
				IF move_addresses = 'always' OR (
					move_addresses = 'if_same_device' AND
					nin_rec.device_id = ni_rec.device_id
				)
				THEN
					--
					-- Remove the netblocks from the network_interfaces,
					-- but save them for later so that we can migrate them
					-- after we make sure the shared_netblock exists.
					--
					-- Also, append the network_inteface_id that we
					-- specifically care about, and we'll add them all
					-- below
					--
					WITH z AS (
						DELETE FROM
							network_interface_netblock nin
						WHERE
							nin.netblock_id = nb_rec.netblock_id
						RETURNING nin.network_interface_id
					)
					SELECT array_agg(v.network_interface_id) FROM
						(SELECT z.network_interface_id FROM z) v
					INTO ni_id_ary;
				ELSE
					IF address_errors = 'ignore' THEN
						RAISE DEBUG 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;

						CONTINUE;
					ELSIF address_errors = 'warn' THEN
						RAISE NOTICE 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;

						CONTINUE;
					ELSE
						RAISE 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;
					END IF;
				END IF;

			END IF;

			IF NOT(ni_id = ANY(ni_id_ary)) THEN
				ni_id_ary := array_append(ni_id_ary, ni_id);
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

			INSERT INTO shared_netblock_network_int (
				shared_netblock_id,
				network_interface_id,
				priority
			) SELECT
				sn_rec.shared_netblock_id,
				x.network_interface_id,
				0
			FROM
				unnest(ni_id_ary) x(network_interface_id)
			ON CONFLICT ON CONSTRAINT pk_ip_group_network_interface DO NOTHING;

			RAISE DEBUG E'Inserted shared_netblock % onto interfaces:\n%',
				sn_rec.shared_netblock_id, jsonb_pretty(to_jsonb(ni_id_ary));
		END LOOP;
		--
		-- Remove any shared_netblocks that are on the interface that are not
		-- supposed to be (and that aren't ignored).
		--

		FOR nin_rec IN
			DELETE FROM
				shared_netblock_network_int snni
			WHERE
				(snni.network_interface_id, snni.shared_netblock_id) IN (
				SELECT
					snni2.network_interface_id,
					snni2.shared_netblock_id
				FROM
					shared_netblock_network_int snni2 JOIN
					shared_netblock sn USING (shared_netblock_id) JOIN
					netblock n USING (netblock_id)
				WHERE
					snni2.network_interface_id = ni_id AND NOT (
						sn.netblock_id = ANY(nb_id_ary) OR
						n.ip_address <<= ANY ( ARRAY (
							SELECT
								n2.ip_address
							FROM
								netblock n2 JOIN
								netblock_collection_netblock ncn USING
									(netblock_id) JOIN
								v_netblock_coll_expanded nce USING
									(netblock_collection_id) JOIN
								property p ON (
									property_name = 'IgnoreProbedNetblocks' AND
									property_type = 'DeviceInventory' AND
									property_value_nblk_coll_id =
										nce.root_netblock_collection_id
								)
						))
					)
			)
			RETURNING *
		LOOP
			RAISE DEBUG 'Removed shared_netblock % from network_interface %',
				nin_rec.shared_netblock_id,
				nin_rec.network_interface_id;

			--
			-- Remove any DNS records, netblocks and shared_netblocks
			-- that aren't used
			--
			SELECT netblock_id INTO nb_id FROM shared_netblock sn WHERE
				sn.shared_netblock_id = nin_rec.shared_netblock_id;
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
--
-- Process middle (non-trigger) schema component_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'create_component_template_slots');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.create_component_template_slots ( component_id integer );
CREATE OR REPLACE FUNCTION component_utils.create_component_template_slots(component_id integer)
 RETURNS SETOF jazzhands.slot
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	ctid	jazzhands.component_type.component_type_id%TYPE;
	s		jazzhands.slot%ROWTYPE;
	cid 	ALIAS FOR component_id;
BEGIN
	FOR s IN
		INSERT INTO jazzhands.slot (
			component_id,
			slot_name,
			slot_type_id,
			slot_index,
			component_type_slot_tmplt_id,
			physical_label,
			slot_x_offset,
			slot_y_offset,
			slot_z_offset,
			slot_side
		) SELECT
			cid,
			ctst.slot_name_template,
			ctst.slot_type_id,
			ctst.slot_index,
			ctst.component_type_slot_tmplt_id,
			ctst.physical_label,
			ctst.slot_x_offset,
			ctst.slot_y_offset,
			ctst.slot_z_offset,
			ctst.slot_side
		FROM
			component_type_slot_tmplt ctst JOIN
			component c USING (component_type_id) LEFT JOIN
			slot ON (slot.component_id = cid AND
				slot.component_type_slot_tmplt_id =
				ctst.component_type_slot_tmplt_id
			)
		WHERE
			c.component_id = cid AND
			slot.component_type_slot_tmplt_id IS NULL
		ORDER BY ctst.component_type_slot_tmplt_id
		RETURNING *
	LOOP
		RAISE DEBUG 'Creating slot for component % from template %',
			cid, s.component_type_slot_tmplt_id;
		RETURN NEXT s;
	END LOOP;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'insert_cpu_component');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.insert_cpu_component ( model text, processor_speed bigint, processor_cores bigint, socket_type text, vendor_name text, serial_number text );
CREATE OR REPLACE FUNCTION component_utils.insert_cpu_component(model text, processor_speed bigint, processor_cores bigint, socket_type text, vendor_name text DEFAULT NULL::text, serial_number text DEFAULT NULL::text)
 RETURNS jazzhands.component
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	m			ALIAS FOR model;
	sn			ALIAS FOR serial_number;
	ctid		integer;
	stid		integer;
	c			RECORD;
	cid			integer;
BEGIN
	cid := NULL;

	IF vendor_name IS NOT NULL THEN	
		SELECT 
			company_id INTO cid
		FROM
			company c LEFT JOIN
			property p USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'VendorCPUProbeString' AND
			property_value = vendor_name;
	END IF;

	--
	-- See if we have this component type in the database already.
	--
	SELECT DISTINCT
		component_type_id INTO ctid
	FROM
		component_type ct JOIN
		component_type_component_func ctcf USING (component_type_id)
	WHERE
		component_function = 'CPU' AND
		ct.model = m AND
		CASE WHEN cid IS NOT NULL THEN
			(company_id = cid)
		ELSE
			true
		END;

	--
	-- If the type isn't found, then we need to insert it
	--
	IF NOT FOUND THEN
		--
		-- Fetch the slot type
		--
		SELECT 
			slot_type_id INTO stid
		FROM
			slot_type st
		WHERE
			st.slot_type = socket_type AND
			slot_function = 'CPU';

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type %, function % not found adding component_type',
				socket_type,
				'CPU'
				USING ERRCODE = 'JH501';
		END IF;

		IF cid IS NULL THEN
			SELECT
				company_id INTO cid
			FROM
				company
			WHERE
				company_name = 'unknown';

			IF NOT FOUND THEN
				IF NOT FOUND THEN
					RAISE EXCEPTION 'company_id for unknown company not found adding component_type'
						USING ERRCODE = 'JH501';
				END IF;
			END IF;
		END IF;

		INSERT INTO component_type (
			company_id,
			model,
			slot_type_id,
			asset_permitted,
			description
		) VALUES (
			cid,
			model,
			stid,
			'Y',
			model
		) RETURNING component_type_id INTO ctid;

		--
		-- Insert component properties for the CPU
		--
		INSERT INTO component_property (
			component_property_name,
			component_property_type,
			component_type_id,
			property_value
		) VALUES 
			('ProcessorCores', 'CPU', ctid, processor_cores),
			('ProcessorSpeed', 'CPU', ctid, processor_speed);
		
		--
		-- Insert the component functions
		--

		INSERT INTO component_type_component_func (
			component_type_id,
			component_function
		) SELECT DISTINCT
			ctid,
			cf
		FROM
			unnest(ARRAY['CPU']) x(cf);
	END IF;

	--
	-- We have a component_type_id now, so look to see if this component
	-- serial number already exists
	--
	IF serial_number IS NOT NULL THEN
		SELECT 
			component.* INTO c
		FROM
			component JOIN
			asset a USING (component_id)
		WHERE
			component_type_id = ctid AND
			a.serial_number = sn;

		IF FOUND THEN
			RETURN c;
		END IF;
	END IF;

	INSERT INTO jazzhands.component (
		component_type_id
	) VALUES (
		ctid
	) RETURNING * INTO c;

	IF serial_number IS NOT NULL THEN
		INSERT INTO asset (
			component_id,
			serial_number,
			ownership_status
		) VALUES (
			c.component_id,
			serial_number,
			'unknown'
		);
	END IF;

	RETURN c;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'insert_disk_component');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.insert_disk_component ( model text, bytes bigint, vendor_name text, protocol text, media_type text, serial_number text );
CREATE OR REPLACE FUNCTION component_utils.insert_disk_component(model text, bytes bigint, vendor_name text DEFAULT NULL::text, protocol text DEFAULT 'SATA'::text, media_type text DEFAULT 'Rotational'::text, serial_number text DEFAULT NULL::text)
 RETURNS jazzhands.component
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	m			ALIAS FOR model;
	sn			ALIAS FOR serial_number;
	ctid		integer;
	stid		integer;
	c			RECORD;
	cid			integer;
BEGIN
	cid := NULL;

	IF vendor_name IS NOT NULL THEN	
		SELECT 
			company_id INTO cid
		FROM
			company c LEFT JOIN
			property p USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'VendorDiskProbeString' AND
			property_value = vendor_name;
	END IF;

	--
	-- See if we have this component type in the database already.
	--
	SELECT DISTINCT
		component_type_id INTO ctid
	FROM
		component_type ct JOIN
		component_type_component_func ctcf USING (component_type_id)
	WHERE
		component_function = 'disk' AND
		ct.model = m AND
		CASE WHEN cid IS NOT NULL THEN
			(company_id = cid)
		ELSE
			true
		END;

	--
	-- If the type isn't found, then we need to insert it
	--
	IF NOT FOUND THEN
		--
		-- Fetch the slot type
		--
		SELECT 
			slot_type_id INTO stid
		FROM
			slot_type st
		WHERE
			st.slot_type = protocol AND
			slot_function = 'disk';

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type % with function disk not found adding component_type',
				protocol
				USING ERRCODE = 'JH501';
		END IF;

		IF cid IS NULL THEN
			SELECT
				company_id INTO cid
			FROM
				company
			WHERE
				company_name = 'unknown';

			IF NOT FOUND THEN
				IF NOT FOUND THEN
					RAISE EXCEPTION 'company_id for unknown company not found adding component_type'
						USING ERRCODE = 'JH501';
				END IF;
			END IF;
		END IF;

		INSERT INTO component_type (
			company_id,
			model,
			slot_type_id,
			asset_permitted,
			description
		) VALUES (
			cid,
			model,
			stid,
			'Y',
			concat_ws(' ', vendor_name, model, media_type, 'disk')
		) RETURNING component_type_id INTO ctid;

		--
		-- Insert component properties for the disk
		--
		INSERT INTO component_property (
			component_property_name,
			component_property_type,
			component_type_id,
			property_value
		) VALUES 
			('DiskSize', 'disk', ctid, bytes),
			('DiskProtocol', 'disk', ctid, protocol),
			('MediaType', 'disk', ctid, media_type);
		
		--
		-- Insert the component functions
		--

		INSERT INTO component_type_component_func (
			component_type_id,
			component_function
		) SELECT DISTINCT
			ctid,
			cf
		FROM
			unnest(ARRAY['storage', 'disk']) x(cf);
	END IF;

	--
	-- We have a component_type_id now, so look to see if this component
	-- serial number already exists
	--
	IF serial_number IS NOT NULL THEN
		SELECT 
			component.* INTO c
		FROM
			component JOIN
			asset a USING (component_id)
		WHERE
			component_type_id = ctid AND
			a.serial_number = sn;

		IF FOUND THEN
			RETURN c;
		END IF;
	END IF;

	INSERT INTO jazzhands.component (
		component_type_id
	) VALUES (
		ctid
	) RETURNING * INTO c;

	IF serial_number IS NOT NULL THEN
		INSERT INTO asset (
			component_id,
			serial_number,
			ownership_status
		) VALUES (
			c.component_id,
			serial_number,
			'unknown'
		);
	END IF;

	RETURN c;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'insert_memory_component');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.insert_memory_component ( model text, memory_size bigint, memory_speed bigint, memory_type text, vendor_name text, serial_number text );
CREATE OR REPLACE FUNCTION component_utils.insert_memory_component(model text, memory_size bigint, memory_speed bigint, memory_type text DEFAULT 'DDR3'::text, vendor_name text DEFAULT NULL::text, serial_number text DEFAULT NULL::text)
 RETURNS jazzhands.component
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	m			ALIAS FOR model;
	sn			ALIAS FOR serial_number;
	ctid		integer;
	stid		integer;
	c			RECORD;
	cid			integer;
BEGIN
	cid := NULL;

	IF vendor_name IS NOT NULL THEN	
		SELECT 
			company_id INTO cid
		FROM
			company c LEFT JOIN
			property p USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'VendorMemoryProbeString' AND
			property_value = vendor_name;
	END IF;

	--
	-- See if we have this component type in the database already.
	--
	SELECT DISTINCT
		component_type_id INTO ctid
	FROM
		component_type ct JOIN
		component_type_component_func ctcf USING (component_type_id)
	WHERE
		component_function = 'memory' AND
		ct.model = m AND
		CASE WHEN cid IS NOT NULL THEN
			(company_id = cid)
		ELSE
			true
		END;

	--
	-- If the type isn't found, then we need to insert it
	--
	IF NOT FOUND THEN
		--
		-- Fetch the slot type
		--
		SELECT 
			slot_type_id INTO stid
		FROM
			slot_type st
		WHERE
			st.slot_type = memory_type AND
			slot_function = 'memory';

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type % with function memory not found adding component_type',
				memory_type
				USING ERRCODE = 'JH501';
		END IF;

		IF cid IS NULL THEN
			SELECT
				company_id INTO cid
			FROM
				company
			WHERE
				company_name = 'unknown';

			IF NOT FOUND THEN
				IF NOT FOUND THEN
					RAISE EXCEPTION 'company_id for unknown company not found adding component_type'
						USING ERRCODE = 'JH501';
				END IF;
			END IF;
		END IF;

		INSERT INTO component_type (
			company_id,
			model,
			slot_type_id,
			asset_permitted,
			description
		) VALUES (
			cid,
			model,
			stid,
			'Y',
			concat_ws(' ', vendor_name, model, (memory_size || 'MB'), 'memory')
		) RETURNING component_type_id INTO ctid;

		--
		-- Insert component properties for the memory
		--
		INSERT INTO component_property (
			component_property_name,
			component_property_type,
			component_type_id,
			property_value
		) VALUES 
			('MemorySize', 'memory', ctid, memory_size),
			('MemorySpeed', 'memory', ctid, memory_speed);
		
		--
		-- Insert the component functions
		--

		INSERT INTO component_type_component_func (
			component_type_id,
			component_function
		) SELECT DISTINCT
			ctid,
			cf
		FROM
			unnest(ARRAY['memory']) x(cf);
	END IF;

	--
	-- We have a component_type_id now, so look to see if this component
	-- serial number already exists
	--
	IF serial_number IS NOT NULL THEN
		SELECT 
			component.* INTO c
		FROM
			component JOIN
			asset a USING (component_id)
		WHERE
			component_type_id = ctid AND
			a.serial_number = sn;

		IF FOUND THEN
			RETURN c;
		END IF;
	END IF;

	INSERT INTO jazzhands.component (
		component_type_id
	) VALUES (
		ctid
	) RETURNING * INTO c;

	IF serial_number IS NOT NULL THEN
		INSERT INTO asset (
			component_id,
			serial_number,
			ownership_status
		) VALUES (
			c.component_id,
			serial_number,
			'unknown'
		);
	END IF;

	RETURN c;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'insert_pci_component');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.insert_pci_component ( pci_vendor_id integer, pci_device_id integer, pci_sub_vendor_id integer, pci_subsystem_id integer, pci_vendor_name text, pci_device_name text, pci_sub_vendor_name text, pci_sub_device_name text, component_function_list text[], slot_type text, serial_number text );
CREATE OR REPLACE FUNCTION component_utils.insert_pci_component(pci_vendor_id integer, pci_device_id integer, pci_sub_vendor_id integer DEFAULT NULL::integer, pci_subsystem_id integer DEFAULT NULL::integer, pci_vendor_name text DEFAULT NULL::text, pci_device_name text DEFAULT NULL::text, pci_sub_vendor_name text DEFAULT NULL::text, pci_sub_device_name text DEFAULT NULL::text, component_function_list text[] DEFAULT NULL::text[], slot_type text DEFAULT 'unknown'::text, serial_number text DEFAULT NULL::text)
 RETURNS jazzhands.component
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	sn			ALIAS FOR serial_number;
	ctid		integer;
	comp_id		integer;
	sub_comp_id	integer;
	stid		integer;
	vendor_name	text;
	sub_vendor_name	text;
	model_name	text;
	c			RECORD;
BEGIN
	IF (pci_sub_vendor_id IS NULL AND pci_subsystem_id IS NOT NULL) OR
			(pci_sub_vendor_id IS NOT NULL AND pci_subsystem_id IS NULL) THEN
		RAISE EXCEPTION
			'pci_sub_vendor_id and pci_subsystem_id must be set together';
	END IF;

	--
	-- See if we have this component type in the database already
	--
	SELECT
		vid.component_type_id INTO ctid
	FROM
		component_property vid JOIN
		component_property did ON (
			vid.component_property_name = 'PCIVendorID' AND
			vid.component_property_type = 'PCI' AND
			did.component_property_name = 'PCIDeviceID' AND
			did.component_property_type = 'PCI' AND
			vid.component_type_id = did.component_type_id ) LEFT JOIN
		component_property svid ON (
			svid.component_property_name = 'PCISubsystemVendorID' AND
			svid.component_property_type = 'PCI' AND
			svid.component_type_id = did.component_type_id ) LEFT JOIN
		component_property sid ON (
			sid.component_property_name = 'PCISubsystemID' AND
			sid.component_property_type = 'PCI' AND
			sid.component_type_id = did.component_type_id )
	WHERE
		vid.property_value = pci_vendor_id::varchar AND
		did.property_value = pci_device_id::varchar AND
		svid.property_value IS NOT DISTINCT FROM pci_sub_vendor_id::varchar AND
		sid.property_value IS NOT DISTINCT FROM pci_subsystem_id::varchar;

	--
	-- The device type doesn't exist, so attempt to insert it
	--

	IF NOT FOUND THEN	
		IF pci_device_name IS NULL OR component_function_list IS NULL THEN
			RAISE EXCEPTION 'component_id not found and pci_device_name or component_function_list was not passed' USING ERRCODE = 'JH501';
		END IF;

		--
		-- Ensure that there's a company linkage for the PCI (subsystem)vendor
		--
		SELECT
			company_id, company_name INTO comp_id, vendor_name
		FROM
			property p JOIN
			company c USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'PCIVendorID' AND
			property_value = pci_vendor_id::text;
		
		IF NOT FOUND THEN
			IF pci_vendor_name IS NULL THEN
				RAISE EXCEPTION 'PCI vendor id mapping not found and pci_vendor_name was not passed' USING ERRCODE = 'JH501';
			END IF;
			SELECT company_id INTO comp_id FROM company
			WHERE company_name = pci_vendor_name;
		
			IF NOT FOUND THEN
				SELECT company_manip.add_company(
					_company_name := pci_vendor_name,
					_company_types := ARRAY['hardware provider'],
					 _description := 'PCI vendor auto-insert'
				) INTO comp_id;
			END IF;

			INSERT INTO property (
				property_name,
				property_type,
				property_value,
				company_id
			) VALUES (
				'PCIVendorID',
				'DeviceProvisioning',
				pci_vendor_id,
				comp_id
			);
			vendor_name := pci_vendor_name;
		END IF;

		SELECT
			company_id, company_name INTO sub_comp_id, sub_vendor_name
		FROM
			property JOIN
			company c USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'PCIVendorID' AND
			property_value = pci_sub_vendor_id::text;
		
		IF NOT FOUND THEN
			IF pci_sub_vendor_name IS NULL THEN
				RAISE EXCEPTION 'PCI subsystem vendor id mapping not found and pci_sub_vendor_name was not passed' USING ERRCODE = 'JH501';
			END IF;
			SELECT company_id INTO sub_comp_id FROM company
			WHERE company_name = pci_sub_vendor_name;
		
			IF NOT FOUND THEN
				SELECT company_manip.add_company(
					_company_name := pci_sub_vendor_name,
					_company_types := ARRAY['hardware provider'],
					 _description := 'PCI vendor auto-insert'
				) INTO sub_comp_id;
			END IF;

			INSERT INTO property (
				property_name,
				property_type,
				property_value,
				company_id
			) VALUES (
				'PCIVendorID',
				'DeviceProvisioning',
				pci_sub_vendor_id,
				sub_comp_id
			);
			sub_vendor_name := pci_sub_vendor_name;
		END IF;

		--
		-- Fetch the slot type
		--

		SELECT 
			slot_type_id INTO stid
		FROM
			slot_type st
		WHERE
			st.slot_type = insert_pci_component.slot_type AND
			slot_function = 'PCI';

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type % with function PCI not found adding component_type',
				insert_pci_component.slot_type
				USING ERRCODE = 'JH501';
		END IF;

		--
		-- Figure out the best name/description to insert this component with
		--
		IF pci_sub_device_name IS NOT NULL AND pci_sub_device_name != 'Device' THEN
			model_name = concat_ws(' ', 
				sub_vendor_name, pci_sub_device_name,
				'(' || vendor_name, pci_device_name || ')');
		ELSIF pci_sub_device_name = 'Device' THEN
			model_name = concat_ws(' ', 
				vendor_name, '(' || sub_vendor_name || ')', pci_device_name);
		ELSE
			model_name = concat_ws(' ', vendor_name, pci_device_name);
		END IF;
		INSERT INTO component_type (
			company_id,
			model,
			slot_type_id,
			asset_permitted,
			description
		) VALUES (
			CASE WHEN 
				sub_comp_id IS NULL OR
				pci_sub_device_name IS NULL OR
				pci_sub_device_name = 'Device'
			THEN
				comp_id
			ELSE
				sub_comp_id
			END,
			CASE WHEN
				pci_sub_device_name IS NULL OR
				pci_sub_device_name = 'Device'
			THEN
				pci_device_name
			ELSE
				pci_sub_device_name
			END,
			stid,
			'Y',
			model_name
		) RETURNING component_type_id INTO ctid;
		--
		-- Insert properties for the PCI vendor/device IDs
		--
		INSERT INTO component_property (
			component_property_name,
			component_property_type,
			component_type_id,
			property_value
		) VALUES 
			('PCIVendorID', 'PCI', ctid, pci_vendor_id),
			('PCIDeviceID', 'PCI', ctid, pci_device_id);
		
		IF (pci_subsystem_id IS NOT NULL) THEN
			INSERT INTO component_property (
				component_property_name,
				component_property_type,
				component_type_id,
				property_value
			) VALUES 
				('PCISubsystemVendorID', 'PCI', ctid, pci_sub_vendor_id),
				('PCISubsystemID', 'PCI', ctid, pci_subsystem_id);
		END IF;
		--
		-- Insert the component functions
		--

		INSERT INTO component_type_component_func (
			component_type_id,
			component_function
		) SELECT DISTINCT
			ctid,
			cf
		FROM
			unnest(array_append(component_function_list, 'PCI')) x(cf);
	END IF;


	--
	-- We have a component_type_id now, so look to see if this component
	-- serial number already exists
	--
	IF serial_number IS NOT NULL THEN
		SELECT 
			component.* INTO c
		FROM
			component JOIN
			asset a USING (component_id)
		WHERE
			component_type_id = ctid AND
			a.serial_number = sn;

		IF FOUND THEN
			RETURN c;
		END IF;
	END IF;

	INSERT INTO jazzhands.component (
		component_type_id
	) VALUES (
		ctid
	) RETURNING * INTO c;

	IF serial_number IS NOT NULL THEN
		INSERT INTO asset (
			component_id,
			serial_number,
			ownership_status
		) VALUES (
			c.component_id,
			serial_number,
			'unknown'
		);
	END IF;

	RETURN c;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'migrate_component_template_slots');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.migrate_component_template_slots ( component_id integer );
CREATE OR REPLACE FUNCTION component_utils.migrate_component_template_slots(component_id integer)
 RETURNS SETOF jazzhands.slot
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	cid 	ALIAS FOR component_id;
BEGIN
	-- Ensure all of the new slots have appropriate names

	PERFORM component_utils.set_slot_names(
		slot_id_list := ARRAY(
				SELECT s.slot_id FROM slot s WHERE s.component_id = cid
			)
	);

	-- Move everything from the old slot to the new slot if the slot name
	-- and component functions match up, then delete the old slot

	RETURN QUERY
	WITH old_slot AS (
		SELECT
			s.slot_id,
			s.slot_name,
			s.slot_type_id,
			st.slot_function,
			ctst.component_type_slot_tmplt_id
		FROM
			slot s JOIN 
			slot_type st USING (slot_type_id) JOIN
			component c USING (component_id) LEFT JOIN
			component_type_slot_tmplt ctst USING (component_type_slot_tmplt_id)
		WHERE
			s.component_id = cid AND
			ctst.component_type_id IS DISTINCT FROM c.component_type_id
	), new_slot AS (
		SELECT
			s.slot_id,
			s.slot_name,
			s.slot_type_id,
			st.slot_function
		FROM
			slot s JOIN 
			slot_type st USING (slot_type_id) JOIN
			component c USING (component_id) LEFT JOIN
			component_type_slot_tmplt ctst USING (component_type_slot_tmplt_id)
		WHERE
			s.component_id = cid AND
			ctst.component_type_id IS NOT DISTINCT FROM c.component_type_id
	), slot_map AS (
		SELECT
			o.slot_id AS old_slot_id,
			n.slot_id AS new_slot_id
		FROM
			old_slot o JOIN
			new_slot n ON (
				o.slot_name = n.slot_name AND o.slot_function = n.slot_function)
	), slot_1_upd AS (
		UPDATE
			inter_component_connection ic
		SET
			slot1_id = slot_map.new_slot_id
		FROM
			slot_map
		WHERE
			slot1_id = slot_map.old_slot_id
		RETURNING *
	), slot_2_upd AS (
		UPDATE
			inter_component_connection ic
		SET
			slot2_id = slot_map.new_slot_id
		FROM
			slot_map
		WHERE
			slot2_id = slot_map.old_slot_id
		RETURNING *
	), prop_upd AS (
		UPDATE
			component_property cp
		SET
			slot_id = slot_map.new_slot_id
		FROM
			slot_map
		WHERE
			slot_id = slot_map.old_slot_id
		RETURNING *
	), comp_upd AS (
		UPDATE
			component c
		SET
			parent_slot_id = slot_map.new_slot_id
		FROM
			slot_map
		WHERE
			parent_slot_id = slot_map.old_slot_id
		RETURNING *
	), ni_upd AS (
		UPDATE
			network_interface ni
		SET
			slot_id = slot_map.new_slot_id
		FROM
			slot_map
		WHERE
			physical_port_id = slot_map.old_slot_id OR
			slot_id = slot_map.new_slot_id
		RETURNING *
	), delete_migraged_slots AS (
		DELETE FROM
			slot
		WHERE
			slot_id IN (SELECT old_slot_id FROM slot_map)
		RETURNING *
	), delete_empty_slots AS (
		DELETE FROM
			slot s
		WHERE
			slot_id IN (
				SELECT os.slot_id FROM
					old_slot os LEFT JOIN
					component_property cp ON (os.slot_id = cp.slot_id) LEFT JOIN
					network_interface ni ON (
						ni.slot_id = os.slot_id OR
						ni.physical_port_id = os.slot_id) LEFT JOIN
					inter_component_connection ic ON (
						slot1_id = os.slot_id OR
						slot2_id = os.slot_id) LEFT JOIN
					component c ON (c.parent_slot_id = os.slot_id)
				WHERE
					ic.inter_component_connection_id IS NULL AND
					c.component_id IS NULL AND
					ni.network_interface_id IS NULL AND
					cp.component_property_id IS NULL AND
					os.component_type_slot_tmplt_id IS NOT NULL
			)
	) SELECT s.* FROM slot s JOIN slot_map sm ON s.slot_id = sm.new_slot_id;

	RETURN;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'remove_component_hier');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.remove_component_hier ( component_id integer, really_delete boolean );
CREATE OR REPLACE FUNCTION component_utils.remove_component_hier(component_id integer, really_delete boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	slot_list		integer[];
	shelf_list		integer[];
	delete_list		integer[];
	cid				integer;
BEGIN
	cid := component_id;

	SELECT ARRAY(
		SELECT
			slot_id
		FROM
			v_component_hier h JOIN
			slot s ON (h.child_component_id = s.component_id)
		WHERE
			h.component_id = cid)
	INTO slot_list;

	IF really_delete THEN
		SELECT ARRAY(
			SELECT
				child_component_id
			FROM
				v_component_hier h
			WHERE
				h.component_id = cid)
		INTO delete_list;
	ELSE

		SELECT ARRAY(
			SELECT
				child_component_id
			FROM
				v_component_hier h LEFT JOIN
				asset a on (a.component_id = h.child_component_id)
			WHERE
				h.component_id = cid AND
				serial_number IS NOT NULL
		)
		INTO shelf_list;

		SELECT ARRAY(
			SELECT
				child_component_id
			FROM
				v_component_hier h LEFT JOIN
				asset a on (a.component_id = h.child_component_id)
			WHERE
				h.component_id = cid AND
				serial_number IS NULL
		)
		INTO delete_list;

	END IF;

	DELETE FROM
		inter_component_connection
	WHERE
		slot1_id = ANY (slot_list) OR
		slot2_id = ANY (slot_list);

	UPDATE
		component c
	SET
		parent_slot_id = NULL
	WHERE
		c.component_id = ANY (array_cat(delete_list, shelf_list)) AND
		parent_slot_id IS NOT NULL;

	DELETE FROM component_property cp WHERE
		cp.component_id = ANY (delete_list) OR
		slot_id = ANY (slot_list);
		
	DELETE FROM
		slot s
	WHERE
		slot_id = ANY (slot_list) AND
		s.component_id = ANY(delete_list);
		
	DELETE FROM
		component c
	WHERE
		c.component_id = ANY (delete_list);

	RETURN true;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'replace_component');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.replace_component ( old_component_id integer, new_component_id integer );
CREATE OR REPLACE FUNCTION component_utils.replace_component(old_component_id integer, new_component_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	oc	RECORD;
BEGIN
	SELECT
		* INTO oc
	FROM
		component
	WHERE
		component_id = old_component_id;

	UPDATE
		component
	SET
		parent_slot_id = NULL
	WHERE
		component_id = old_component_id;

	UPDATE 
		component
	SET
		parent_slot_id = oc.parent_slot_id
	WHERE
		component_id = new_component_id;

	UPDATE
		device
	SET
		component_id = new_component_id
	WHERE
		component_id = old_component_id;
	
	UPDATE
		physicalish_volume
	SET
		component_id = new_component_id
	WHERE
		component_id = old_component_id;

	RETURN;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'set_slot_names');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.set_slot_names ( slot_id_list integer[] );
CREATE OR REPLACE FUNCTION component_utils.set_slot_names(slot_id_list integer[] DEFAULT NULL::integer[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	slot_rec	RECORD;
	sn			text;
BEGIN
	-- Get a list of all slots that have replacement values

	FOR slot_rec IN
		SELECT 
			s.slot_id,
			COALESCE(pst.child_slot_name_template, st.slot_name_template)
				AS slot_name_template,
			st.slot_index as slot_index,
			pst.slot_index as parent_slot_index,
			pst.child_slot_offset as child_slot_offset
		FROM
			slot s JOIN
			component_type_slot_tmplt st ON (s.component_type_slot_tmplt_id =
				st.component_type_slot_tmplt_id) JOIN
			component c ON (s.component_id = c.component_id) LEFT JOIN
			slot ps ON (c.parent_slot_id = ps.slot_id) LEFT JOIN
			component_type_slot_tmplt pst ON (ps.component_type_slot_tmplt_id =
				pst.component_type_slot_tmplt_id)
		WHERE
			s.slot_id = ANY(slot_id_list) AND
			(
				st.slot_name_template ~ '%{' OR
				pst.child_slot_name_template ~ '%{'
			)
	LOOP
		sn := slot_rec.slot_name_template;
		IF (slot_rec.slot_index IS NOT NULL) THEN
			sn := regexp_replace(sn,
				'%\{slot_index\}', slot_rec.slot_index::text,
				'g');
		END IF;
		IF (slot_rec.parent_slot_index IS NOT NULL) THEN
			sn := regexp_replace(sn,
				'%\{parent_slot_index\}', slot_rec.parent_slot_index::text,
				'g');
		END IF;
		IF (slot_rec.parent_slot_index IS NOT NULL AND
			slot_rec.slot_index IS NOT NULL) THEN
			sn := regexp_replace(sn,
				'%\{relative_slot_index\}', 
				(slot_rec.parent_slot_index + slot_rec.slot_index)::text,
				'g');
		END IF;
		RAISE DEBUG 'Setting name of slot % to %',
			slot_rec.slot_id,
			sn;
		UPDATE slot SET slot_name = sn WHERE slot_id = slot_rec.slot_id;
	END LOOP;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION component_utils.fetch_component(component_type_id integer, serial_number text, no_create boolean DEFAULT false, ownership_status text DEFAULT 'unknown'::text, parent_slot_id integer DEFAULT NULL::integer)
 RETURNS jazzhands.component
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	ctid		ALIAS FOR component_type_id;
	sn			ALIAS FOR serial_number;
	psid		ALIAS FOR parent_slot_id;
	os			ALIAS FOR ownership_status;
	c			RECORD;
	cid			integer;
BEGIN
	cid := NULL;

	IF sn IS NOT NULL THEN
		SELECT 
			comp.* INTO c
		FROM
			component comp JOIN
			asset a USING (component_id)
		WHERE
			comp.component_type_id = ctid AND
			a.serial_number = sn;

		IF FOUND THEN
			--
			-- Only update the parent slot if it isn't set already
			--
			IF c.parent_slot_id IS NULL THEN
				UPDATE
					component comp
				SET
					parent_slot_id = psid
				WHERE
					comp.component_id = c.component_id;
			END IF;
			RETURN c;
		END IF;
	END IF;

	IF no_create THEN
		RETURN NULL;
	END IF;

	INSERT INTO jazzhands.component (
		component_type_id,
		parent_slot_id
	) VALUES (
		ctid,
		parent_slot_id
	) RETURNING * INTO c;

	IF serial_number IS NOT NULL THEN
		INSERT INTO asset (
			component_id,
			serial_number,
			ownership_status
		) VALUES (
			c.component_id,
			serial_number,
			os
		);
	END IF;

	RETURN c;
END;
$function$
;

--
-- Process middle (non-trigger) schema snapshot_manip
--
--
-- Process middle (non-trigger) schema lv_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('lv_manip', 'delete_lv');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.delete_lv ( logical_volume_id integer, purge_orphans boolean );
CREATE OR REPLACE FUNCTION lv_manip.delete_lv(logical_volume_id integer, purge_orphans boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	PERFORM lv_manip.delete_lv(
		logical_volume_list := ARRAY [ logical_volume_id ],
		purge_orphans := purge_orphans
	);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('lv_manip', 'delete_lv');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.delete_lv ( logical_volume_list integer[], purge_orphans boolean );
CREATE OR REPLACE FUNCTION lv_manip.delete_lv(logical_volume_list integer[], purge_orphans boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	PERFORM lv_manip.delete_pv(
		physicalish_volume_list := (
			SELECT ARRAY (SELECT
				physicalish_volume_id
			FROM
				physicalish_volume pv
			WHERE
				pv.logical_volume_id = ANY(logical_volume_list)
		)),
		purge_orphans := purge_orphans
	);

	DELETE FROM
		logical_volume_property lvp
	WHERE
		lvp.logical_volume_id = ANY(logical_volume_list);
	
	DELETE FROM
		logical_volume_purpose lvp
	WHERE
		lvp.logical_volume_id = ANY(logical_volume_list);
	
	DELETE FROM
		logical_volume lv
	WHERE
		lv.logical_volume_id = ANY(logical_volume_list);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('lv_manip', 'delete_lv_hier');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.delete_lv_hier ( INOUT physicalish_volume_list integer[], INOUT volume_group_list integer[], INOUT logical_volume_list integer[] );
CREATE OR REPLACE FUNCTION lv_manip.delete_lv_hier(INOUT physicalish_volume_list integer[] DEFAULT NULL::integer[], INOUT volume_group_list integer[] DEFAULT NULL::integer[], INOUT logical_volume_list integer[] DEFAULT NULL::integer[])
 RETURNS record
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	pv_list	integer[];
	vg_list	integer[];
	lv_list	integer[];
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_pv_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN physicalish_volume_list IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = ANY (physicalish_volume_list)
			END OR
			CASE WHEN volume_group_list  IS NULL
				THEN false
				ELSE lh.volume_group_id = ANY (volume_group_list)
			END OR
			CASE WHEN logical_volume_list IS NULL
				THEN false
				ELSE lh.logical_volume_id = ANY (logical_volume_list)
			END)
			AND child_pv_id IS NOT NULL
	) INTO pv_list;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_vg_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pv_list IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = ANY (physicalish_volume_list)
			END OR
			CASE WHEN vg_list IS NULL
				THEN false
				ELSE lh.volume_group_id = ANY (volume_group_list)
			END OR
			CASE WHEN lv_list IS NULL
				THEN false
				ELSE lh.logical_volume_id = ANY (logical_volume_list)
			END)
			AND child_vg_id IS NOT NULL
	) INTO vg_list;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_lv_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pv_list IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = ANY (physicalish_volume_list)
			END OR
			CASE WHEN vg_list IS NULL
				THEN false
				ELSE lh.volume_group_id = ANY (volume_group_list)
			END OR
			CASE WHEN lv_list IS NULL
				THEN false
				ELSE lh.logical_volume_id = ANY (logical_volume_list)
			END)
			AND child_lv_id IS NOT NULL
	) INTO lv_list;

	DELETE FROM logical_volume_property WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume_purpose WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM volume_group_physicalish_vol WHERE physicalish_volume_id = ANY(pv_list);
	DELETE FROM volume_group_physicalish_vol WHERE volume_group_id = ANY(vg_list);
	DELETE FROM volume_group WHERE volume_group_id = ANY(vg_list);
	DELETE FROM physicalish_volume WHERE physicalish_volume_id = ANY(pv_list);

	physicalish_volume_list := pv_list;
	volume_group_list := vg_list;
	logical_volume_list := lv_list;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('lv_manip', 'delete_lv_hier');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.delete_lv_hier ( physicalish_volume_id integer, volume_group_id integer, logical_volume_id integer, OUT pv_list integer[], OUT vg_list integer[], OUT lv_list integer[] );
CREATE OR REPLACE FUNCTION lv_manip.delete_lv_hier(physicalish_volume_id integer DEFAULT NULL::integer, volume_group_id integer DEFAULT NULL::integer, logical_volume_id integer DEFAULT NULL::integer, OUT pv_list integer[], OUT vg_list integer[], OUT lv_list integer[])
 RETURNS record
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	pvid ALIAS FOR physicalish_volume_id;
	vgid ALIAS FOR volume_group_id;
	lvid ALIAS FOR logical_volume_id;
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_pv_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = pvid
			END OR
			CASE WHEN vgid IS NULL
				THEN false
				ELSE lh.volume_group_id = vgid
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = lvid
			END)
			AND child_pv_id IS NOT NULL
	) INTO pv_list;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_vg_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = pvid
			END OR
			CASE WHEN vgid IS NULL
				THEN false
				ELSE lh.volume_group_id = vgid
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = lvid
			END)
			AND child_vg_id IS NOT NULL
	) INTO vg_list;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_lv_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = pvid
			END OR
			CASE WHEN vgid IS NULL
				THEN false
				ELSE lh.volume_group_id = vgid
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = lvid
			END)
			AND child_lv_id IS NOT NULL
	) INTO lv_list;

	DELETE FROM logical_volume_property WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume_purpose WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM volume_group_purpose WHERE volume_group_id = ANY(vg_list);
	DELETE FROM volume_group WHERE volume_group_id = ANY(vg_list);
	DELETE FROM physicalish_volume WHERE physicalish_volume_id = ANY(pv_list);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('lv_manip', 'delete_pv');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.delete_pv ( physicalish_volume_list integer[], purge_orphans boolean );
CREATE OR REPLACE FUNCTION lv_manip.delete_pv(physicalish_volume_list integer[], purge_orphans boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	pvid integer;
	vgid integer;
BEGIN
	PERFORM * FROM lv_manip.remove_pv_membership(
		physicalish_volume_list,
		purge_orphans
	);

	DELETE FROM physicalish_volume WHERE
		physicalish_volume_id = ANY(physicalish_volume_list);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('lv_manip', 'delete_vg');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.delete_vg ( volume_group_id integer, purge_orphans boolean );
CREATE OR REPLACE FUNCTION lv_manip.delete_vg(volume_group_id integer, purge_orphans boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	lvids	integer[];
BEGIN
	PERFORM lv_manip.delete_vg(
		volume_group_list := ARRAY [ volume_group_id ],
		purge_orphans := purge_orphans
	);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('lv_manip', 'delete_vg');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.delete_vg ( volume_group_list integer[], purge_orphans boolean );
CREATE OR REPLACE FUNCTION lv_manip.delete_vg(volume_group_list integer[], purge_orphans boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	lvids	integer[];
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	SELECT ARRAY(
		SELECT
			logical_volume_id
		FROM
			logical_volume lv
		WHERE
			lv.volume_group_id = ANY(volume_group_list)
	) INTO lvids;

	PERFORM lv_manip.delete_pv(
		physicalish_volume_list := (
			SELECT ARRAY (SELECT
				physicalish_volume_id
			FROM
				physicalish_volume
			WHERE
				logical_volume_id = ANY(lvids)
		)),
		purge_orphans := purge_orphans
	);

	DELETE FROM
		volume_group_physicalish_vol vgpv
	WHERE
		vgpv.volume_group_id = ANY(volume_group_list);
	
	DELETE FROM
		volume_group_purpose vgp
	WHERE
		vgp.volume_group_id = ANY(volume_group_list);

	DELETE FROM
		logical_volume_property
	WHERE
		logical_volume_id = ANY(lvids);

	DELETE FROM
		logical_volume_purpose
	WHERE
		logical_volume_id = ANY(lvids);
	
	DELETE FROM
		logical_volume
	WHERE
		logical_volume_id = ANY(lvids);
	
	DELETE FROM
		volume_group vg
	WHERE
		vg.volume_group_id = ANY(volume_group_list);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('lv_manip', 'remove_pv_membership');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.remove_pv_membership ( physicalish_volume_list integer[], purge_orphans boolean );
CREATE OR REPLACE FUNCTION lv_manip.remove_pv_membership(physicalish_volume_list integer[], purge_orphans boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	pvid integer;
	vgid integer;
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	FOREACH pvid IN ARRAY physicalish_volume_list LOOP
		DELETE FROM 
			volume_group_physicalish_vol vgpv
		WHERE
			vgpv.physicalish_volume_id = pvid
		RETURNING
			volume_group_id INTO vgid;
		
		IF FOUND AND purge_orphans THEN
			PERFORM * FROM
				volume_group_physicalish_vol vgpv
			WHERE
				volume_group_id = vgid;

			IF NOT FOUND THEN
				PERFORM lv_manip.delete_vg(
					volume_group_id := vgid,
					purge_orphans := purge_orphans
				);
			END IF;
		END IF;

	END LOOP;
END;
$function$
;

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
-- Process middle (non-trigger) schema backend_utils
--
--
-- Process middle (non-trigger) schema rack_utils
--
--
-- Process middle (non-trigger) schema layerx_network_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('layerx_network_manip', 'delete_layer2_networks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS layerx_network_manip.delete_layer2_networks ( layer2_network_id_list integer[], purge_network_interfaces boolean );
CREATE OR REPLACE FUNCTION layerx_network_manip.delete_layer2_networks(layer2_network_id_list integer[], purge_network_interfaces boolean DEFAULT false)
 RETURNS SETOF jazzhands.layer2_network
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	netblock_id_list	integer[];
BEGIN
	IF array_length(layer2_network_id_list, 1) IS NULL THEN
		RETURN;
	END IF;

	BEGIN
		PERFORM local_hooks.delete_layer2_networks_before_hooks(
			layer2_network_id_list := layer2_network_id_list
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

	PERFORM layerx_network_manip.delete_layer3_networks(
		layer3_network_id_list := ARRAY(
				SELECT layer3_network_id
				FROM layer3_network l3n
				WHERE layer2_network_id = ANY(layer2_network_id_list)
			),
		purge_network_interfaces := 
			delete_layer2_networks.purge_network_interfaces
	);

	DELETE FROM
		l2_network_coll_l2_network l2nc
	WHERE
		l2nc.layer2_network_id = ANY(layer2_network_id_list);

	RETURN QUERY DELETE FROM
		layer2_network l2n
	WHERE
		l2n.layer2_network_id = ANY(layer2_network_id_list)
	RETURNING *;

	BEGIN
		PERFORM local_hooks.delete_layer2_networks_after_hooks(
			layer2_network_id_list := layer2_network_id_list
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

END $function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('layerx_network_manip', 'delete_layer3_networks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS layerx_network_manip.delete_layer3_networks ( layer3_network_id_list integer[], purge_network_interfaces boolean );
CREATE OR REPLACE FUNCTION layerx_network_manip.delete_layer3_networks(layer3_network_id_list integer[], purge_network_interfaces boolean DEFAULT false)
 RETURNS SETOF jazzhands.layer3_network
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	netblock_id_list			integer[];
	network_interface_id_list	integer[];
BEGIN
	IF array_length(layer3_network_id_list, 1) IS NULL THEN
		RETURN;
	END IF;

	BEGIN
		PERFORM local_hooks.delete_layer3_networks_before_hooks(
			layer3_network_id_list := layer3_network_id_list
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

	IF (purge_network_interfaces) THEN
		SELECT ARRAY(
			SELECT
				n.netblock_id AS netblock_id
			FROM
				jazzhands.layer3_network l3 JOIN
				jazzhands.netblock p USING (netblock_id) JOIN
				jazzhands.netblock n ON (p.netblock_id = n.parent_netblock_id)
			WHERE
				l3.layer3_network_id = ANY(layer3_network_id_list)
		) INTO netblock_id_list;

		WITH nin_del AS (
			DELETE FROM
				jazzhands.network_interface_netblock 
			WHERE
				netblock_id = ANY(netblock_id_list)
			RETURNING network_interface_id
		), snni_del AS (
			DELETE FROM
				jazzhands.shared_netblock_network_int
			WHERE
				shared_netblock_id IN (
					SELECT shared_netblock_id FROM jazzhands.shared_netblock
					WHERE netblock_id = ANY(netblock_id_list)
				)
			RETURNING network_interface_id
		)
		SELECT ARRAY(
			SELECT network_interface_id FROM nin_del
			UNION
			SELECT network_interface_id FROM snni_del
		) INTO network_interface_id_list;

		DELETE FROM
			network_interface_purpose nip
		WHERE
			nip.network_interface_id IN (
				SELECT
					network_interface_id
				FROM
					network_interface ni
				WHERE
					ni.network_interface_id = ANY(network_interface_id_list)
						AND
					ni.network_interface_id NOT IN (
						SELECT
							network_interface_id
						FROM
							network_interface_netblock
						UNION
						SELECT 
							network_interface_id
						FROM
							shared_netblock_network_int
					)
			);
			
		DELETE FROM
			network_interface ni
		WHERE
			ni.network_interface_id = ANY(network_interface_id_list) AND
			ni.network_interface_id NOT IN (
				SELECT network_interface_id FROM network_interface_netblock
				UNION
				SELECT network_interface_id FROM shared_netblock_network_int
			);
	END IF;

	RETURN QUERY WITH x AS (
		SELECT
			p.netblock_id AS netblock_id,
			l3.layer3_network_id AS layer3_network_id
		FROM
			jazzhands.layer3_network l3 JOIN
			jazzhands.netblock p USING (netblock_id)
		WHERE
			l3.layer3_network_id = ANY(layer3_network_id_list)
	), l3_coll_del AS (
		DELETE FROM
			jazzhands.l3_network_coll_l3_network
		WHERE
			layer3_network_id IN (SELECT layer3_network_id FROM x)
	), l3_del AS (
		DELETE FROM
			jazzhands.layer3_network
		WHERE
			layer3_network_id in (SELECT layer3_network_id FROM x)
		RETURNING *
	), nb_sel AS (
		SELECT
			n.netblock_id
		FROM
			jazzhands.netblock n JOIN
			x ON (n.parent_netblock_id = x.netblock_id)
	), dns_del AS (
		DELETE FROM
			jazzhands.dns_record
		WHERE
			netblock_id IN (SELECT netblock_id FROM nb_sel)
	), nbc_del as (
		DELETE FROM
			jazzhands.netblock_collection_netblock
		WHERE
			netblock_id IN (SELECT netblock_id FROM x
				UNION SELECT netblock_id FROM nb_sel)
	), nb_del as (
		DELETE FROM
			jazzhands.netblock
		WHERE
			netblock_id IN (SELECT netblock_id FROM nb_sel)
	), sn_del as (
		DELETE FROM
			jazzhands.shared_netblock
		WHERE
			netblock_id IN (SELECT netblock_id FROM nb_sel)
	), nrp_del as (
		DELETE FROM
			property
		WHERE
			network_range_id IN (
				SELECT
					network_range_id
				FROM
					network_range nr JOIN
					x ON (nr.parent_netblock_id = x.netblock_id)
			)
	), nr_del as (
		DELETE FROM
			jazzhands.network_range
		WHERE
			parent_netblock_id IN (SELECT netblock_id FROM x)
		RETURNING
			start_netblock_id, stop_netblock_id
	), nrnb_del AS (
		DELETE FROM
			jazzhands.netblock
		WHERE
			netblock_id IN (
				SELECT start_netblock_id FROM nr_del
				UNION
				SELECT stop_netblock_id FROM nr_del
		)
	), nbd AS (
		DELETE FROM
			jazzhands.netblock
		WHERE
			netblock_id IN (SELECT netblock_id FROM x)
	)
	SELECT * FROM l3_del;

	BEGIN
		PERFORM local_hooks.delete_layer3_networks_after_hooks(
			layer3_network_id_list := layer3_network_id_list
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;
	RETURN;
END $function$
;

--
-- Process middle (non-trigger) schema component_connection_utils
--
--
-- Process middle (non-trigger) schema logical_port_manip
--
--
-- Process middle (non-trigger) schema pgcrypto
--
--
-- Process middle (non-trigger) schema jazzhands_legacy
--
-- New function
CREATE OR REPLACE FUNCTION jazzhands_legacy.insert_person_image_into_base_schema(new jazzhands_legacy.person_image)
 RETURNS jazzhands_legacy.person_image
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	INSERT INTO jazzhands.person_image(
		person_image_id,
		person_id,
		person_image_order,
		image_type,
		image_blob,
		image_checksum,
		image_label,
		description
	) VALUES (
		concat(NEW.person_image_id, nextval('jazzhands.person_image_person_image_id_seq'))::integer,
		NEW.person_id,
		NEW.person_image_order,
		NEW.image_type,
		NEW.image_blob,
		NEW.image_checksum,
		NEW.image_label,
		NEW.description
	) RETURNING * INTO NEW;
	RETURN NEW;
END;
$function$
;

--
-- Process middle (non-trigger) schema obfuscation_utils
--
-- New function
CREATE OR REPLACE FUNCTION obfuscation_utils.deobfuscate_text(encoded text, type text, label text DEFAULT 'default'::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_key	BYTEA;
	_de	BYTEA;
	_iv	BYTEA;
	_enc	BYTEA;
	_parts	TEXT[];
	_len	INTEGER;
BEGIN
	_key := obfuscation_utils.get_session_secret(label)::text;
	IF type = 'base64' THEN
		RETURN decode(encoded, 'base64');
	ELSIF type ~ '^pgp' THEN
		IF  type = 'pgp+base64' THEN
			--
			-- not using armor because of compatablity issues with 
			-- Crypt::OpenPGP armoring that I gave up on.
			--
			encoded := decode(encoded, 'base64');
		END IF;
		IF _key IS NULL THEN
			RAISE EXCEPTION 'pgp requries setup';
		END IF;
		_de := pgcrypto.pgp_sym_decrypt_bytea(encoded::bytea, _key::text);
		RETURN encode(_de, 'escape');
	ELSIF type = 'none' THEN
		RETURN encoded;
	ELSIF type ~ 'cbc/pad:pkcs' THEN
		_parts := regexp_matches(encoded, '^([^-]+)-(.+)$');
		_iv := decode(_parts[1], 'base64');
		_enc := decode(_parts[2], 'base64');

		_de := pgcrypto.decrypt_iv(_enc::bytea, _key, _iv, type);
		RETURN encode(_de, 'escape');
	ELSE
		RAISE EXCEPTION 'unknown decryption type %', type
			USING ERRCODE = invalid_paramter;
	END IF;
	RETURN NULL;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION obfuscation_utils.get_session_secret(label text DEFAULT 'default'::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_key TEXT;
BEGIN
	BEGIN
		CREATE TEMPORARY TABLE __jazzhands_session_key__ (
			type text NOT NULL,
			role text NOT NULL,
			key text NOT NULL,
			PRIMARY KEY(type, role)
		);
	EXCEPTION WHEN SQLSTATE '42P07' THEN
		NULL;
	END;

	PERFORM setseed(1-extract(epoch from now())/extract(epoch from clock_timestamp()));
	BEGIN
		_key := substring(
			encode(pgcrypto.digest(random()::text, 'sha256'), 'base64'),
			1, 32);
	EXCEPTION WHEN invalid_schema_name THEN
		_key := substring(md5(random()::text), 1, 32);
	END;

	BEGIN
		-- This means no pgcrypto but we don't want things to fail...
		INSERT INTO __jazzhands_session_key__ (type, role,key) 
			VALUES (label, current_user, _key);
	EXCEPTION WHEN unique_violation THEN
		NULL;
	END;

	SELECT __jazzhands_session_key__.key 
		INTO _key 
		FROM __jazzhands_session_key__ 
		WHERE type = label
		AND role = current_user;
	RETURN(_key);
END;
$function$
;

--
-- Process middle (non-trigger) schema account_password_manip
--
-- New function
CREATE OR REPLACE FUNCTION account_password_manip.authenticate_account(account_id integer, password text, encode_method text DEFAULT 'pgp+base64'::text, label text DEFAULT 'default'::text, raiseexception boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	plainpw	TEXT;
	crypt	TEXT;
	method	TEXT;
	_tally	INTEGER;	
BEGIN
	--
	-- decode the password into plaintext
	--
	plainpw := obfuscation_utils.deobfuscate_text (encoded := password,
		type := encode_method,
		label := label);

	--
	-- go through all of this user's passwords  that the database is capable
	-- of decoding.  This list should probably be expanded.
	--
	_tally := 0;
	FOR crypt, method IN SELECT  a.password, a.password_type
		FROM	account_password a
		WHERE	a.account_id = authenticate_account.account_id
		AND		password_type IN ( 'cryptMD5', 'blowfish', 
					'xdes', 'postgresMD5')
	LOOP
		IF pgcrypto.crypt(plainpw, crypt) = crypt THEN
			RETURN true;
		END IF;
		_tally := _tally+ 1;
	END LOOP;
	IF raiseexception AND _tally = 0 THEN
		RAISE EXCEPTION 'User has no passwords set'
			USING ERRCODE = 'cardinality_violation';
	END IF;
	RETURN false;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION account_password_manip.check_account_password_reuse(account_id integer, password text, encode_method text DEFAULT 'pgp+base64'::text, label text DEFAULT 'default'::text, age interval DEFAULT '00:00:00'::interval)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	plainpw	TEXT;
	crypt	TEXT;
	method	TEXT;
BEGIN
	--
	-- decode the password into plaintext
	--
	plainpw := obfuscation_utils.deobfuscate_text (encoded := password,
		type := encode_method,
		label := label);

	--
	-- go through all of this user's passwords  that the database is capable
	-- of decoding.  This list should probably be expanded.
	--
	FOR crypt, method IN SELECT  a.password, a.password_type
		FROM	audit.account_password a
		WHERE	a.account_id = check_account_password_reuse.account_id
		AND		"aud#action" IN ('INS','UPD')
		AND		password_type IN ( 'cryptMD5', 'blowfish', 
					'xdes', 'postgresMD5')
		AND		"aud#timestamp" <= now() - age
		ORDER BY "aud#timestamp" DESC
	LOOP
		IF pgcrypto.crypt(plainpw, crypt) = crypt THEN
			RETURN false;
		END IF;
	END LOOP;
	RETURN true;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION account_password_manip.set_account_passwords(account_id integer, password text, encode_method text DEFAULT 'pgp+base64'::text, change_time timestamp without time zone DEFAULT now(), expire_time timestamp without time zone DEFAULT NULL::timestamp without time zone, crypts jsonb DEFAULT '{}'::jsonb, label text DEFAULT 'default'::text, purge boolean DEFAULT true, racecatch boolean DEFAULT false)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	len			INTEGER;
	acid		account_collection.account_collection_id%TYPE;
	proplen		INTEGER;
	pwtype		TEXT;
	plainpw		TEXT;
	method		TEXT;
	value		TEXT;
	p_method	TEXT;
	p_value		TEXT;
	cols		TEXT[];
	vals		TEXT[];
	done		TEXT[];
	passed		TEXT[];
	upd			TEXT[];
	login		TEXT;
	curcrypt	TEXT[];
	_tally		INTEGER;
	_r			RECORD;
BEGIN
	--
	-- lock all the passwords for UPDATE.  Also keep track of all the recent
	--
	FOR _r IN SELECT ap.password, now()- ap.change_time <= '5 minutes'::interval AS recent
		FROM account_password ap 
		WHERE ap.account_id = set_account_passwords.account_id FOR UPDATE
	LOOP
		IF _r.recent THEN
			curcrypt := curcrypt || _r.password::text;
		END IF;
	END LOOP;


	--
	-- decode the password into plaintext
	--
	plainpw := obfuscation_utils.deobfuscate_text (encoded := password,
		type := encode_method,
		label := label);
	len := character_length(plainpw);

	IF racecatch AND curcrypt IS NOT NULL THEN
		FOREACH value IN ARRAY curcrypt LOOP
			IF pgcrypto.crypt(plainpw, value) = value THEN
				RETURN 1;
			END IF;
		END LOOP;
	END IF;
	value := NULL;

	-- figure out crypts that need to be added that we can handle
	--
	SELECT array_agg(KEY) INTO passed FROM jsonb_each_text(crypts);
	FOR pwtype IN SELECT property_value_password_type FROM property WHERE property_name = 'managedpwtype' AND property_type = 'Defaults'
	LOOP
		IF pwtype = SOME (passed) THEN
			CONTINUE;
		END IF;
		-- XXX - reallyneed to add SCRAM-SHA-256 for postgres. possibly 
		-- mysql and others since they're probably easy
		IF pwtype = 'cryptMD5' THEN
			crypts := jsonb_insert (crypts,
				ARRAY [ pwtype ],
				concat('"', pgcrypto.crypt(PASSWORD, pgcrypto.gen_salt('md5')), '"')::jsonb);
		ELSIF pwtype = 'blowfish' THEN
			crypts := jsonb_insert (crypts,
				ARRAY [ pwtype ],
				concat('"', pgcrypto.crypt(PASSWORD, pgcrypto.gen_salt('bf')), '"')::jsonb);
		ELSIF pwtype = 'xdes' THEN
			crypts := jsonb_insert (crypts,
				ARRAY [ pwtype ],
				concat('"', pgcrypto.crypt(PASSWORD, pgcrypto.gen_salt('xdes')), '"')::jsonb);
		ELSIF pwtype = 'postgresMD5' THEN
			SELECT	a.login INTO LOGIN
			FROM	account a
			WHERE	a.account_id = set_account_passwords.account_id;
			crypts := jsonb_insert (crypts,
				ARRAY [ pwtype ],
				concat('"md5', md5(concat(PASSWORD, LOGIN)), '"')::jsonb);
		ELSE
			RAISE EXCEPTION 'Unknown pwtype %', pwtype
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END LOOP;

	_tally := 0;
	FOR method, value IN SELECT * FROM jsonb_each_text(crypts)
		LOOP
			IF value IS NULL THEN
				DELETE FROM account_password ap WHERE password_type = method AND ap.account_id = set_account_passwords.account_id;
				CONTINUE;
			END IF;
			p_method := quote_nullable(method);
			p_value := quote_nullable(value);
			cols := ARRAY [ 'password_type', 'password', 'account_id' ];
			vals := ARRAY [ p_method, p_value, '$1' ];
			upd := ARRAY [ 'password_type = ' || p_method, 'password = ' || p_value ];

			IF change_time IS NOT NULL THEN
				cols := cols || quote_ident('change_time');
				vals := vals || quote_nullable(change_time);
				upd := upd || concat('change_time = ',
					 quote_nullable(change_time));

				--
				-- for any password changing, set the expire time so it 
				-- can fall back on default policy, even on NULL
				--
				cols := cols || quote_ident('expire_time');
				vals := vals || quote_nullable(expire_time);
				upd := upd || concat('expire_time = ',
					 quote_nullable(expire_time));
			END IF;
			--
			-- note that account_id is passed in as an argument
			--
			EXECUTE 'INSERT INTO account_password (' || 
					array_to_string(cols, ',') || ' ) VALUES ( ' || 
					array_to_string(vals, ',') || 
					') ON CONFLICT ON CONSTRAINT pk_accunt_password DO UPDATE SET ' || 
					array_to_string(upd, ',')
				USING account_id;
			done := done || method;
			_tally := _tally + 1;
		END LOOP;
	IF purge THEN
		DELETE FROM account_password
		WHERE account_password.account_id = set_account_passwords.account_id
			AND NOT password_type = ANY (done);
	END IF;
	--
	-- This is probably a hack that needs revisiting
	--
	FOR acid, proplen IN SELECT account_collection_id, property_value
		FROM property
		WHERE property_type = 'account-override'
		AND property_name = 'password_expiry_days'
		ORDER BY property_value::integer desc
	LOOP
		IF len >= proplen THEN
			--
			-- conflict means that they are already a part of this.
			--
			INSERT INTO account_collection_account (
				account_collection_id, account_id
			) VALUES (
				acid, set_account_passwords.account_id
			) ON CONFLICT ON CONSTRAINT pk_account_collection_user DO NOTHING;
		ELSE
			DELETE FROM account_collection_account ac 
				WHERE ac.account_collection_id = acid 
				AND ac.account_id = set_account_passwords.account_id;
		END IF;
	END LOOP;
	RETURN _tally;
END;
$function$
;

-- Creating new sequences....


--
-- BEGIN: process_ancillary_schema(jazzhands_cache)
--
-- DONE: process_ancillary_schema(jazzhands_cache)
--------------------------------------------------------------------
-- DEALING WITH TABLE v_dns_fwd
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dns_fwd', 'v_dns_fwd');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_dns_fwd');
DROP VIEW IF EXISTS jazzhands.v_dns_fwd;
CREATE VIEW jazzhands.v_dns_fwd AS
 SELECT u.dns_record_id,
    u.network_range_id,
    u.dns_domain_id,
    u.dns_name,
    u.dns_ttl,
    u.dns_class,
    u.dns_type,
    u.dns_value,
    u.dns_priority,
    u.ip,
    u.netblock_id,
    u.ip_universe_id,
    u.ref_record_id,
    u.dns_srv_service,
    u.dns_srv_protocol,
    u.dns_srv_weight,
    u.dns_srv_port,
    u.is_enabled,
    u.should_generate_ptr,
    u.dns_value_record_id
   FROM ( SELECT d.dns_record_id,
            NULL::integer AS network_range_id,
            d.dns_domain_id,
            COALESCE(rdns.dns_name, d.dns_name) AS dns_name,
            d.dns_ttl,
            d.dns_class,
            d.dns_type,
                CASE
                    WHEN d.dns_value IS NOT NULL THEN d.dns_value::text
                    WHEN (d.dns_type::text = ANY (ARRAY['A'::character varying, 'AAAA'::character varying]::text[])) AND d.netblock_id IS NULL AND d.dns_value_record_id IS NOT NULL THEN NULL::text
                    WHEN d.dns_value_record_id IS NULL THEN d.dns_value::text
                    WHEN dv.dns_domain_id = d.dns_domain_id THEN dv.dns_name::text
                    ELSE concat(dv.dns_name, '.', dv.soa_name, '.')
                END AS dns_value,
            d.dns_priority,
                CASE
                    WHEN d.dns_value_record_id IS NOT NULL AND (d.dns_type::text = ANY (ARRAY['A'::character varying, 'AAAA'::character varying]::text[])) THEN dv.ip_address
                    ELSE ni.ip_address
                END AS ip,
                CASE
                    WHEN d.dns_value_record_id IS NOT NULL AND (d.dns_type::text = ANY (ARRAY['A'::character varying, 'AAAA'::character varying]::text[])) THEN dv.netblock_id
                    ELSE ni.netblock_id
                END AS netblock_id,
            d.ip_universe_id,
            rdns.reference_dns_record_id AS ref_record_id,
            d.dns_srv_service,
            d.dns_srv_protocol,
            d.dns_srv_weight,
            d.dns_srv_port,
            d.is_enabled,
            d.should_generate_ptr,
            d.dns_value_record_id
           FROM jazzhands.dns_record d
             LEFT JOIN jazzhands.netblock ni USING (netblock_id)
             LEFT JOIN ( SELECT dns_record.dns_record_id AS reference_dns_record_id,
                    dns_record.dns_name,
                    dns_record.netblock_id,
                    netblock.ip_address
                   FROM jazzhands.dns_record
                     LEFT JOIN jazzhands.netblock USING (netblock_id)) rdns USING (reference_dns_record_id)
             LEFT JOIN ( SELECT dr.dns_record_id,
                    dr.dns_name,
                    dom.dns_domain_id,
                    dom.soa_name,
                    dr.dns_value,
                    dnb.ip_address AS ip,
                    dnb.ip_address,
                    dnb.netblock_id
                   FROM jazzhands.dns_record dr
                     JOIN jazzhands.dns_domain dom USING (dns_domain_id)
                     LEFT JOIN jazzhands.netblock dnb USING (netblock_id)) dv ON d.dns_value_record_id = dv.dns_record_id
        UNION ALL
         SELECT NULL::integer AS dns_record_id,
            range.network_range_id,
            range.dns_domain_id,
            concat(COALESCE(range.dns_prefix, 'pool'::character varying), '-', replace(host(range.ip), '.'::text, '-'::text)) AS dns_name,
            NULL::integer AS dns_ttl,
            'IN'::character varying AS dns_class,
                CASE
                    WHEN family(range.ip) = 4 THEN 'A'::text
                    ELSE 'AAAA'::text
                END AS dns_type,
            NULL::text AS dns_value,
            NULL::integer AS dns_prority,
            range.ip,
            NULL::integer AS netblock_id,
            range.ip_universe_id,
            NULL::integer AS ref_dns_record_id,
            NULL::character varying AS dns_srv_service,
            NULL::character varying AS dns_srv_protocol,
            NULL::integer AS dns_srv_weight,
            NULL::integer AS dns_srv_port,
            'Y'::bpchar AS is_enabled,
            'N'::character(1) AS should_generate_ptr,
            NULL::integer AS dns_value_record_id
           FROM ( SELECT dr.network_range_id,
                    dr.dns_domain_id,
                    nbstart.ip_universe_id,
                    dr.dns_prefix,
                    nbstart.ip_address + generate_series(0::bigint, nbstop.ip_address - nbstart.ip_address) AS ip
                   FROM jazzhands.network_range dr
                     JOIN jazzhands.netblock nbstart ON dr.start_netblock_id = nbstart.netblock_id
                     JOIN jazzhands.netblock nbstop ON dr.stop_netblock_id = nbstop.netblock_id
                  WHERE dr.dns_domain_id IS NOT NULL) range) u
  WHERE u.dns_type::text <> 'REVERSE_ZONE_BLOCK_PTR'::text
UNION ALL
 SELECT NULL::integer AS dns_record_id,
    NULL::integer AS network_range_id,
    dns_domain.parent_dns_domain_id AS dns_domain_id,
    regexp_replace(dns_domain.soa_name::text, ('\.'::text || pdom.parent_soa_name::text) || '$'::text, ''::text) AS dns_name,
    dns_record.dns_ttl,
    dns_record.dns_class,
    dns_record.dns_type,
        CASE
            WHEN dns_record.dns_value::text ~ '\.$'::text THEN dns_record.dns_value::text
            ELSE concat(dns_record.dns_value, '.', dns_domain.soa_name, '.')
        END AS dns_value,
    dns_record.dns_priority,
    NULL::inet AS ip,
    NULL::integer AS netblock_id,
    dns_record.ip_universe_id,
    NULL::integer AS ref_record_id,
    NULL::text AS dns_srv_service,
    NULL::text AS dns_srv_protocol,
    NULL::integer AS dns_srv_weight,
    NULL::integer AS dns_srv_port,
    dns_record.is_enabled,
    'N'::character(1) AS should_generate_ptr,
    NULL::integer AS dns_value_record_id
   FROM jazzhands.dns_record
     JOIN jazzhands.dns_domain USING (dns_domain_id)
     JOIN ( SELECT dns_domain_1.dns_domain_id AS parent_dns_domain_id,
            dns_domain_1.soa_name AS parent_soa_name
           FROM jazzhands.dns_domain dns_domain_1) pdom USING (parent_dns_domain_id)
  WHERE dns_record.dns_class::text = 'IN'::text AND dns_record.dns_type::text = 'NS'::text AND dns_record.dns_name IS NULL AND dns_domain.parent_dns_domain_id IS NOT NULL;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object = 'v_dns_fwd';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_dns_fwd failed but that is ok';
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
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_dns_fwd (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_dns_rvs
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dns_rvs', 'v_dns_rvs');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_dns_rvs');
DROP VIEW IF EXISTS jazzhands.v_dns_rvs;
CREATE VIEW jazzhands.v_dns_rvs AS
 SELECT NULL::integer AS dns_record_id,
    combo.network_range_id,
    rootd.dns_domain_id,
        CASE
            WHEN family(combo.ip) = 4 THEN regexp_replace(host(combo.ip), '^.*[.](\d+)$'::text, '\1'::text, 'i'::text)
            ELSE regexp_replace(dns_utils.v6_inaddr(combo.ip), ('.'::text || replace(dd.soa_name::text, '.ip6.arpa'::text, ''::text)) || '$'::text, ''::text, 'i'::text)
        END AS dns_name,
    combo.dns_ttl,
    'IN'::text AS dns_class,
    'PTR'::text AS dns_type,
        CASE
            WHEN combo.dns_name IS NULL THEN concat(combo.soa_name, '.')
            ELSE concat(combo.dns_name, '.', combo.soa_name, '.')
        END AS dns_value,
    NULL::integer AS dns_priority,
    combo.ip,
    combo.netblock_id,
    combo.ip_universe_id,
    NULL::integer AS rdns_record_id,
    NULL::text AS dns_srv_service,
    NULL::text AS dns_srv_protocol,
    NULL::integer AS dns_srv_weight,
    NULL::integer AS dns_srv_srv_port,
    combo.is_enabled,
    'N'::character(1) AS should_generate_ptr,
    NULL::integer AS dns_value_record_id
   FROM ( SELECT host(nb.ip_address)::inet AS ip,
            NULL::integer AS network_range_id,
            COALESCE(rdns.dns_name, dns.dns_name) AS dns_name,
            dom.soa_name,
            dns.dns_ttl,
            network(nb.ip_address) AS ip_base,
            nb.ip_universe_id,
            dns.is_enabled,
            'N'::character(1) AS should_generate_ptr,
            nb.netblock_id
           FROM jazzhands.netblock nb
             JOIN jazzhands.dns_record dns ON nb.netblock_id = dns.netblock_id
             JOIN jazzhands.dns_domain dom ON dns.dns_domain_id = dom.dns_domain_id
             LEFT JOIN jazzhands.dns_record rdns ON rdns.dns_record_id = dns.reference_dns_record_id
          WHERE dns.should_generate_ptr = 'Y'::bpchar AND dns.dns_class::text = 'IN'::text AND (dns.dns_type::text = 'A'::text OR dns.dns_type::text = 'AAAA'::text) AND nb.is_single_address = 'Y'::bpchar
        UNION ALL
         SELECT host(range.ip)::inet AS ip,
            range.network_range_id,
            concat(COALESCE(range.dns_prefix, 'pool'::character varying), '-', replace(host(range.ip), '.'::text, '-'::text)) AS dns_name,
            dom.soa_name,
            NULL::integer AS dns_ttl,
            network(range.ip) AS ip_base,
            range.ip_universe_id,
            'Y'::bpchar AS is_enabled,
            'N'::character(1) AS should_generate_ptr,
            NULL::integer AS netblock_id
           FROM ( SELECT dr.network_range_id,
                    nbstart.ip_universe_id,
                    dr.dns_domain_id,
                    dr.dns_prefix,
                    nbstart.ip_address + generate_series(0::bigint, nbstop.ip_address - nbstart.ip_address) AS ip
                   FROM jazzhands.network_range dr
                     JOIN jazzhands.netblock nbstart ON dr.start_netblock_id = nbstart.netblock_id
                     JOIN jazzhands.netblock nbstop ON dr.stop_netblock_id = nbstop.netblock_id
                  WHERE dr.dns_domain_id IS NOT NULL) range
             JOIN jazzhands.dns_domain dom ON range.dns_domain_id = dom.dns_domain_id) combo,
    jazzhands.netblock root
     JOIN jazzhands.dns_record rootd ON rootd.netblock_id = root.netblock_id AND rootd.dns_type::text = 'REVERSE_ZONE_BLOCK_PTR'::text
     JOIN jazzhands.dns_domain dd USING (dns_domain_id)
  WHERE family(root.ip_address) = family(combo.ip) AND set_masklen(combo.ip, masklen(root.ip_address)) <<= root.ip_address;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object = 'v_dns_rvs';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_dns_rvs failed but that is ok';
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
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_dns_rvs (jazzhands)
--------------------------------------------------------------------
--
-- Process drops in jazzhands_cache
--
--
-- Process drops in schema_support
--
-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'build_audit_table_pkak_indexes');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.build_audit_table_pkak_indexes ( aud_schema character varying, tbl_schema character varying, table_name character varying );
CREATE OR REPLACE FUNCTION schema_support.build_audit_table_pkak_indexes(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
		ORDER BY CASE WHEN con.contype = 'p' THEN 0 ELSE 1 END, con.conname
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'build_audit_tables');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.build_audit_tables ( aud_schema character varying, tbl_schema character varying );
CREATE OR REPLACE FUNCTION schema_support.build_audit_tables(aud_schema character varying, tbl_schema character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
     table_list RECORD;
BEGIN
    FOR table_list IN
	SELECT table_name::text FROM information_schema.tables
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
$function$
;

DROP FUNCTION IF EXISTS schema_support.get_common_columns ( _schema text, _table1 text, _table2 text );
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
		CREATE TEMPORARY TABLE IF NOT EXISTS __regrants (id SERIAL, schema text, object text, newname text, regrant text, tags text[]);
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
		CREATE TEMPORARY TABLE IF NOT EXISTS __recreate (id SERIAL, schema text, object text, owner text, type text, ddl text, idargs text, tags text[], path text[]);
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_table');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_table ( aud_schema character varying, tbl_schema character varying, table_name character varying, finish_rebuild boolean );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_table(aud_schema character varying, tbl_schema character varying, table_name character varying, finish_rebuild boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_tables');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_tables ( aud_schema character varying, tbl_schema character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_tables(aud_schema character varying, tbl_schema character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	 table_list RECORD;
BEGIN
	FOR table_list IN
		SELECT b.table_name::text
		FROM information_schema.tables b
			INNER JOIN information_schema.tables a
				USING (table_name,table_type)
		WHERE table_type = 'BASE TABLE'
		AND a.table_schema = aud_schema
		AND b.table_schema = tbl_schema
		ORDER BY table_name
	LOOP
		PERFORM schema_support.save_dependent_objects_for_replay(
			schema := aud_schema::varchar,
			object := table_list.table_name::varchar,
			tags:= ARRAY['rebuild_audit_tables']);
		PERFORM schema_support.save_grants_for_replay(schema := aud_schema,
			object := table_list.table_name,
			tags := ARRAY['rebuild_audit_tables']);
		PERFORM schema_support.rebuild_audit_table
			( aud_schema, tbl_schema, table_list.table_name );
		PERFORM schema_support.replay_object_recreates();
		PERFORM schema_support.replay_saved_grants();
		END LOOP;

	PERFORM schema_support.rebuild_audit_triggers(aud_schema, tbl_schema);
	PERFORM schema_support.replay_object_recreates(tags := ARRAY['rebuild_audit_tables
']);
	PERFORM schema_support.replay_saved_grants(tags := ARRAY['rebuild_audit_tables']);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_triggers');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_triggers ( aud_schema character varying, tbl_schema character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_triggers(aud_schema character varying, tbl_schema character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    table_list RECORD;
BEGIN
    --
    -- select tables with audit tables
    --
    FOR table_list IN
	SELECT table_name::text FROM information_schema.tables
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
	    SELECT table_name::text FROM information_schema.tables
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
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_diff');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_diff ( schema text, old_rel text, new_rel text, key_relation text, prikeys text[], raise_exception boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_diff(schema text, old_rel text, new_rel text, key_relation text DEFAULT NULL::text, prikeys text[] DEFAULT NULL::text[], raise_exception boolean DEFAULT true)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
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
	_oldschema	TEXT;
	_newschema	TEXT;
BEGIN
	IF old_rel ~ '\.' THEN
		_oldschema := regexp_replace(old_rel, '\..*$', '');
		old_rel := regexp_replace(old_rel, '^[^\.]*\.', '');
	ELSE
		_oldschema:= schema;
	END IF;

	IF new_rel ~ '\.' THEN
		_newschema := regexp_replace(new_rel, '\..*$', '');
		new_rel := regexp_replace(new_rel, '^[^\.]*\.', '');
	ELSE
		_newschema:= schema;
	END IF;

	RAISE NOTICE '% % % %', _oldschema, old_rel, _newschema, new_rel;

	-- do a simple row count
	EXECUTE 'SELECT count(*) FROM ' || _oldschema || '."' || old_rel || '"' INTO _t1;
	EXECUTE 'SELECT count(*) FROM ' || _newschema || '."' || new_rel || '"' INTO _t2;

	_rv := true;

	IF _t1 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', _oldschema, old_rel;
		_rv := false;
	END IF;
	IF _t2 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', _oldschema, new_rel;
		_rv := false;
	END IF;

	IF prikeys IS NULL THEN
		-- read into prikeys the primary key for the table
		IF key_relation IS NULL THEN
			key_relation := old_rel;
		END IF;
		prikeys := schema_support.get_pk_columns(_oldschema, key_relation);
	END IF;

	-- read into _cols the column list in common between old_rel and new_rel
	_cols := schema_support.get_common_columns(_oldschema, old_rel, _newschema, new_rel);

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
		_rv := false;
	END IF;

	_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
		quote_ident(_oldschema) || '.' || quote_ident(old_rel)  ||
		' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
			' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
			quote_ident(_oldschema) || '.' || quote_ident(old_rel)  ||
			' EXCEPT ( '
				' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
				quote_ident(_newschema) || '.' || quote_ident(new_rel)  ||
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
		quote_ident(_newschema) || '.' || quote_ident(new_rel)  ||
		' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
			' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
			quote_ident(_newschema) || '.' || quote_ident(new_rel)  ||
			' EXCEPT ( '
				' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
				quote_ident(_oldschema) || '.' || quote_ident(old_rel)  ||
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
			quote_ident(_oldschema) || '.' || quote_ident(old_rel) || ' ) old ' ||
		' JOIN ' ||
		'( SELECT '  || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(_newschema) || '.' || quote_ident(new_rel) || ' ) new ' ||
		' USING ( ' ||  array_to_string(_pkcol,',') ||
		' ) WHERE (' || array_to_string(_pkcol,',') || ' ) IN (' ||
		'SELECT ' || array_to_string(_pkcol,',')  || ' FROM ( ' ||
			'( SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(_oldschema) || '.' || quote_ident(old_rel) ||
			' EXCEPT ' ||
			'( SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(_newschema) || '.' || quote_ident(new_rel) || ' )) ' ||
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
$function$
;

DROP FUNCTION IF EXISTS schema_support.replay_object_recreates ( beverbose boolean );
DROP FUNCTION IF EXISTS schema_support.replay_saved_grants ( beverbose boolean );
DROP FUNCTION IF EXISTS schema_support.save_constraint_for_replay ( schema character varying, object character varying, dropit boolean );
DROP FUNCTION IF EXISTS schema_support.save_dependent_objects_for_replay ( schema character varying, object character varying, dropit boolean, doobjectdeps boolean );
DROP FUNCTION IF EXISTS schema_support.save_function_for_replay ( schema character varying, object character varying, dropit boolean );
DROP FUNCTION IF EXISTS schema_support.save_grants_for_replay ( schema character varying, object character varying, newname character varying );
DROP FUNCTION IF EXISTS schema_support.save_grants_for_replay_functions ( schema character varying, object character varying, newname character varying );
DROP FUNCTION IF EXISTS schema_support.save_grants_for_replay_relations ( schema character varying, object character varying, newname character varying );
DROP FUNCTION IF EXISTS schema_support.save_trigger_for_replay ( schema character varying, object character varying, dropit boolean );
DROP FUNCTION IF EXISTS schema_support.save_view_for_replay ( schema character varying, object character varying, dropit boolean );
-- New function
CREATE OR REPLACE FUNCTION schema_support.get_common_columns(_oldschema text, _table1 text, _newschema text, _table2 text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
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
	    INNER JOIN cols n USING (colname)
		WHERE
			o.schema = $1
		and o.relation = $2
		and n.schema = $3
		and n.relation = $4
		) as prett
	';
	EXECUTE _q INTO cols USING _oldschema, _table1, _newschema, _table2;
	RETURN cols;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.replay_object_recreates(beverbose boolean DEFAULT false, tags text[] DEFAULT NULL::text[], schema text DEFAULT NULL::text, object text DEFAULT NULL::text, type text DEFAULT NULL::text, path text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
			IF tags IS NOT NULL THEN
				CONTINUE WHEN _r.tags IS NULL;
				CONTINUE WHEN NOT _r.tags && tags;
			END IF;
			IF schema IS NOT NULL THEN
				CONTINUE WHEN _r.schema IS NULL;
				CONTINUE WHEN NOT _r.schema = schema;
			END IF;
			IF type IS NOT NULL THEN
				CONTINUE WHEN _r.type IS NULL;
				CONTINUE WHEN NOT _r.type = type;
			END IF;
			IF object IS NOT NULL THEN
				CONTINUE WHEN _r.object IS NULL;
				IF object ~ '^!' THEN
					object = regexp_replace(object, '^!', '');
					CONTINUE WHEN _r.object = object;
				ELSE
					CONTINUE WHEN NOT _r.object = object;
				END IF;
			END IF;

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
			IF tags IS NULL AND schema IS NULL and object IS NULL THEN
				RAISE EXCEPTION '% objects still exist for recreating after a complete loop', _tally;
			END IF;
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
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.replay_saved_grants(beverbose boolean DEFAULT false, schema text DEFAULT NULL::text, tags text DEFAULT NULL::text)
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
			if tags IS NOT NULL THEN
				CONTINUE WHEN _r.tags IS NULL;
				CONTINUE WHEN NOT _r.tags && tags;
			END IF;
			if schema IS NOT NULL THEN
				CONTINUE WHEN _r.schema IS NULL;
				CONTINUE WHEN _r.schema != schema;
			END IF;
		    IF beverbose THEN
			    RAISE NOTICE 'Regrant Executing: %', _r.regrant;
		    END IF;
		    EXECUTE _r.regrant;
		    DELETE from __regrants where id = _r.id;
	    END LOOP;

	    SELECT count(*) INTO _tally from __regrants;
	    IF _tally > 0 THEN
			IF schema IS NULL AND tags IS NULL THEN
				RAISE EXCEPTION 'Grant extractions were run while replaying grants - %.', _tally;
			END IF;
	    ELSE
		    DROP TABLE __regrants;
	    END IF;
	ELSE
		IF beverbose THEN
			RAISE NOTICE '**** WARNING: replay_saved_grants did NOT have anything to regrant!';
		END IF;
	END IF;

END;
$function$
;

-- New function
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
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

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
		                array_agg(attname) as cols
		        FROM (
		            SELECT con.*, a.attname
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
		                array_agg(attname) as cols
		        FROM (
		            SELECT con.*, a.attname
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
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_dependent_objects_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, doobjectdeps boolean DEFAULT false, tags text[] DEFAULT NULL::text[], path text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	RAISE DEBUG 'processing %.%', schema, object;
	path = path || concat(schema, '.', object);
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
		PERFORM schema_support.save_constraint_for_replay(schema := _r.nspname, object := _r.proname, dropit := dropit, tags := tags, path := path);
		PERFORM schema_support.save_dependent_objects_for_replay(_r.nspname, _r.proname, dropit, doobjectdeps, tags, path);
		PERFORM schema_support.save_function_for_replay(_r.nspname, _r.proname, dropit, tags, path);
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
			PERFORM * FROM save_dependent_objects_for_replay(_r.nspname, _r.relname, dropit, doobjectdeps, tags, path);
			PERFORM schema_support.save_view_for_replay(_r.nspname, _r.relname, dropit, tags, path);
		END IF;
	END LOOP;
	IF doobjectdeps THEN
		PERFORM schema_support.save_trigger_for_replay(schema, object, dropit, tags, path);
		PERFORM schema_support.save_constraint_for_replay(schema := 'jazzhands', object := 'table', tags := tags, path := path);
	END IF;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_function_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, tags text[] DEFAULT NULL::text[], path text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
BEGIN
	path = path || concat(schema, '.', object);
	PERFORM schema_support.prepare_for_object_replay();

	-- implicitly save regrants
	PERFORM schema_support.save_grants_for_replay(schema, object, object, tags);
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
		INSERT INTO __recreate (schema, object, type, owner,
			ddl, idargs, tags, path
		) VALUES (
			_r.nspname, _r.proname, 'function', _r.owner,
			_r.funcdef, _r.idargs, tags, path
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

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay(schema character varying, object character varying, newname character varying DEFAULT NULL::character varying, tags text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
	PERFORM schema_support.save_grants_for_replay_relations(schema, object, newname, tags);
	PERFORM schema_support.save_grants_for_replay_functions(schema, object, newname, tags);
END;
$function$
;

-- New function
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
			_fullgrant := 'GRANT ' ||
				_perm.privilege_type || ' on FUNCTION ' ||
				_schema || '.' ||
				newname || '(' || _procs.args || ')  to ' ||
				_role || _grant;
			-- RAISE DEBUG 'inserting % for %', _fullgrant, _perm;
			INSERT INTO __regrants (schema, object, newname, regrant, tags) values (schema,object, newname, _fullgrant, tags );
		END LOOP;
	END LOOP;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay_relations(schema character varying, object character varying, newname character varying DEFAULT NULL::character varying, tags text[] DEFAULT NULL::text[])
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
			INSERT INTO __regrants (schema, object, newname, regrant, tags) values (schema,object, newname, _fullgrant, tags );
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
			INSERT INTO __regrants (schema, object, newname, regrant, tags) values (schema,object, newname, _fullgrant, tags );
		END LOOP;
	END LOOP;

END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_trigger_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, tags text[] DEFAULT NULL::text[], path text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
BEGIN
	path = path || concat(schema, '.', object);
	PERFORM schema_support.prepare_for_object_replay();

	FOR _r in
		SELECT n.nspname, c.relname, trg.tgname,
				pg_get_triggerdef(trg.oid, true) as def
		FROM pg_trigger trg
			INNER JOIN pg_class c on trg.tgrelid =  c.oid
			INNER JOIN pg_namespace n on n.oid = c.relnamespace
		WHERE n.nspname = schema and c.relname = object
	LOOP
		INSERT INTO __recreate (schema, object, type, ddl, tags , path)
			VALUES (
				_r.nspname, _r.relname, 'trigger', _r.def, tags, path
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

-- New function
CREATE OR REPLACE FUNCTION schema_support.save_view_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, tags text[] DEFAULT NULL::text[], path text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_c		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
	_mat	TEXT;
	_typ	TEXT;
BEGIN
	path = path || concat(schema, '.', object);
	PERFORM schema_support.prepare_for_object_replay();

	-- implicitly save regrants
	PERFORM schema_support.save_grants_for_replay(schema, object, object, tags);

	-- save any triggers on the view
	PERFORM schema_support.save_trigger_for_replay(schema, object, dropit, tags, path);

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
				INSERT INTO __recreate (schema, object, type, ddl, tags, path )
					VALUES (
						_r.nspname, _r.relname, 'default', _ddl, tags, path
					);
			END IF;
			IF _c.comment IS NOT NULL THEN
				_ddl := 'COMMENT ON COLUMN ' ||
					quote_ident(schema) || '.' || quote_ident(object)
					' IS ''' || _c.comment || '''';
				INSERT INTO __recreate (schema, object, type, ddl, tags, path )
					VALUES (
						_r.nspname, _r.relname, 'colcomment', _ddl, tags, path
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
		INSERT INTO __recreate (schema, object, owner, type, ddl, tags, path )
			VALUES (
				_r.nspname, _r.relname, _r.owner, _typ, _ddl, tags, path
			);
		IF dropit  THEN
			_cmd = 'DROP ' || _mat || _r.nspname || '.' || _r.relname || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;
END;
$function$
;

--
-- Process drops in jazzhands
--
-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_status_per_row_after_hooks');
CREATE OR REPLACE FUNCTION jazzhands.account_status_per_row_after_hooks()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_al	jazzhands_legacy.account%ROWTYPE;
BEGIN
	BEGIN
		BEGIN
			PERFORM local_hooks.account_status_per_row_after_hooks(account_record => NEW);
		EXCEPTION WHEN undefined_function THEN
			_al := NEW;
			PERFORM local_hooks.account_status_per_row_after_hooks(account_record => _al);
		END;
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;
	RETURN NULL;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'person_company_attr_change_after_row_hooks');
CREATE OR REPLACE FUNCTION jazzhands.person_company_attr_change_after_row_hooks()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	tally			integer;
	_pca			jazzhands_legacy.person_company_attr%ROWTYPE;
BEGIN
	BEGIN
		BEGIN
			PERFORM local_hooks.person_company_attr_change_after_row_hooks(person_company_attr_row => NEW);
		EXCEPTION WHEN undefined_function THEN
			_pca := NEW;
			PERFORM local_hooks.person_company_attr_change_after_row_hooks(person_company_attr_row => _pca);
		END;
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;
	RETURN NULL;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.ins_person_image()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
   b	integer;
   str	varchar;
BEGIN

	--
	-- actually insert the trigger
	--
	NEW := jazzhands_legacy.insert_person_image_into_base_schema(NEW);

	--
	-- This is copied from the jazzhands.fix_person_image_oid_ownership()
	-- trigger
	--

	b := NEW.image_blob;
	BEGIN
		str := 'GRANT SELECT on LARGE OBJECT ' || b || ' to picture_image_ro';
		EXECUTE str;
		str :=  'GRANT UPDATE on LARGE OBJECT ' || b || ' to picture_image_rw';
		EXECUTE str;
	EXCEPTION WHEN OTHERS THEN
		RAISE NOTICE 'Unable to grant on %', b;
	END;

	BEGIN
		EXECUTE 'ALTER large object ' || b || ' owner to jazzhands';
	EXCEPTION WHEN OTHERS THEN
		RAISE NOTICE 'Unable to adjust ownership of %', b;
	END;
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
-- Process drops in obfuscation_utils
--
-- New function
CREATE OR REPLACE FUNCTION obfuscation_utils.deobfuscate_text(encoded text, type text, label text DEFAULT 'default'::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_key	BYTEA;
	_de	BYTEA;
	_iv	BYTEA;
	_enc	BYTEA;
	_parts	TEXT[];
	_len	INTEGER;
BEGIN
	_key := obfuscation_utils.get_session_secret(label)::text;
	IF type = 'base64' THEN
		RETURN decode(encoded, 'base64');
	ELSIF type ~ '^pgp' THEN
		IF  type = 'pgp+base64' THEN
			--
			-- not using armor because of compatablity issues with 
			-- Crypt::OpenPGP armoring that I gave up on.
			--
			encoded := decode(encoded, 'base64');
		END IF;
		IF _key IS NULL THEN
			RAISE EXCEPTION 'pgp requries setup';
		END IF;
		_de := pgcrypto.pgp_sym_decrypt_bytea(encoded::bytea, _key::text);
		RETURN encode(_de, 'escape');
	ELSIF type = 'none' THEN
		RETURN encoded;
	ELSIF type ~ 'cbc/pad:pkcs' THEN
		_parts := regexp_matches(encoded, '^([^-]+)-(.+)$');
		_iv := decode(_parts[1], 'base64');
		_enc := decode(_parts[2], 'base64');

		_de := pgcrypto.decrypt_iv(_enc::bytea, _key, _iv, type);
		RETURN encode(_de, 'escape');
	ELSE
		RAISE EXCEPTION 'unknown decryption type %', type
			USING ERRCODE = invalid_paramter;
	END IF;
	RETURN NULL;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION obfuscation_utils.get_session_secret(label text DEFAULT 'default'::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_key TEXT;
BEGIN
	BEGIN
		CREATE TEMPORARY TABLE __jazzhands_session_key__ (
			type text NOT NULL,
			role text NOT NULL,
			key text NOT NULL,
			PRIMARY KEY(type, role)
		);
	EXCEPTION WHEN SQLSTATE '42P07' THEN
		NULL;
	END;

	PERFORM setseed(1-extract(epoch from now())/extract(epoch from clock_timestamp()));
	BEGIN
		_key := substring(
			encode(pgcrypto.digest(random()::text, 'sha256'), 'base64'),
			1, 32);
	EXCEPTION WHEN invalid_schema_name THEN
		_key := substring(md5(random()::text), 1, 32);
	END;

	BEGIN
		-- This means no pgcrypto but we don't want things to fail...
		INSERT INTO __jazzhands_session_key__ (type, role,key) 
			VALUES (label, current_user, _key);
	EXCEPTION WHEN unique_violation THEN
		NULL;
	END;

	SELECT __jazzhands_session_key__.key 
		INTO _key 
		FROM __jazzhands_session_key__ 
		WHERE type = label
		AND role = current_user;
	RETURN(_key);
END;
$function$
;

--
-- Process drops in person_manip
--
--
-- Process drops in account_password_manip
--
-- New function
CREATE OR REPLACE FUNCTION account_password_manip.authenticate_account(account_id integer, password text, encode_method text DEFAULT 'pgp+base64'::text, label text DEFAULT 'default'::text, raiseexception boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	plainpw	TEXT;
	crypt	TEXT;
	method	TEXT;
	_tally	INTEGER;	
BEGIN
	--
	-- decode the password into plaintext
	--
	plainpw := obfuscation_utils.deobfuscate_text (encoded := password,
		type := encode_method,
		label := label);

	--
	-- go through all of this user's passwords  that the database is capable
	-- of decoding.  This list should probably be expanded.
	--
	_tally := 0;
	FOR crypt, method IN SELECT  a.password, a.password_type
		FROM	account_password a
		WHERE	a.account_id = authenticate_account.account_id
		AND		password_type IN ( 'cryptMD5', 'blowfish', 
					'xdes', 'postgresMD5')
	LOOP
		IF pgcrypto.crypt(plainpw, crypt) = crypt THEN
			RETURN true;
		END IF;
		_tally := _tally+ 1;
	END LOOP;
	IF raiseexception AND _tally = 0 THEN
		RAISE EXCEPTION 'User has no passwords set'
			USING ERRCODE = 'cardinality_violation';
	END IF;
	RETURN false;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION account_password_manip.check_account_password_reuse(account_id integer, password text, encode_method text DEFAULT 'pgp+base64'::text, label text DEFAULT 'default'::text, age interval DEFAULT '00:00:00'::interval)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	plainpw	TEXT;
	crypt	TEXT;
	method	TEXT;
BEGIN
	--
	-- decode the password into plaintext
	--
	plainpw := obfuscation_utils.deobfuscate_text (encoded := password,
		type := encode_method,
		label := label);

	--
	-- go through all of this user's passwords  that the database is capable
	-- of decoding.  This list should probably be expanded.
	--
	FOR crypt, method IN SELECT  a.password, a.password_type
		FROM	audit.account_password a
		WHERE	a.account_id = check_account_password_reuse.account_id
		AND		"aud#action" IN ('INS','UPD')
		AND		password_type IN ( 'cryptMD5', 'blowfish', 
					'xdes', 'postgresMD5')
		AND		"aud#timestamp" <= now() - age
		ORDER BY "aud#timestamp" DESC
	LOOP
		IF pgcrypto.crypt(plainpw, crypt) = crypt THEN
			RETURN false;
		END IF;
	END LOOP;
	RETURN true;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION account_password_manip.set_account_passwords(account_id integer, password text, encode_method text DEFAULT 'pgp+base64'::text, change_time timestamp without time zone DEFAULT now(), expire_time timestamp without time zone DEFAULT NULL::timestamp without time zone, crypts jsonb DEFAULT '{}'::jsonb, label text DEFAULT 'default'::text, purge boolean DEFAULT true, racecatch boolean DEFAULT false)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	len			INTEGER;
	acid		account_collection.account_collection_id%TYPE;
	proplen		INTEGER;
	pwtype		TEXT;
	plainpw		TEXT;
	method		TEXT;
	value		TEXT;
	p_method	TEXT;
	p_value		TEXT;
	cols		TEXT[];
	vals		TEXT[];
	done		TEXT[];
	passed		TEXT[];
	upd			TEXT[];
	login		TEXT;
	curcrypt	TEXT[];
	_tally		INTEGER;
	_r			RECORD;
BEGIN
	--
	-- lock all the passwords for UPDATE.  Also keep track of all the recent
	--
	FOR _r IN SELECT ap.password, now()- ap.change_time <= '5 minutes'::interval AS recent
		FROM account_password ap 
		WHERE ap.account_id = set_account_passwords.account_id FOR UPDATE
	LOOP
		IF _r.recent THEN
			curcrypt := curcrypt || _r.password::text;
		END IF;
	END LOOP;


	--
	-- decode the password into plaintext
	--
	plainpw := obfuscation_utils.deobfuscate_text (encoded := password,
		type := encode_method,
		label := label);
	len := character_length(plainpw);

	IF racecatch AND curcrypt IS NOT NULL THEN
		FOREACH value IN ARRAY curcrypt LOOP
			IF pgcrypto.crypt(plainpw, value) = value THEN
				RETURN 1;
			END IF;
		END LOOP;
	END IF;
	value := NULL;

	-- figure out crypts that need to be added that we can handle
	--
	SELECT array_agg(KEY) INTO passed FROM jsonb_each_text(crypts);
	FOR pwtype IN SELECT property_value_password_type FROM property WHERE property_name = 'managedpwtype' AND property_type = 'Defaults'
	LOOP
		IF pwtype = SOME (passed) THEN
			CONTINUE;
		END IF;
		-- XXX - reallyneed to add SCRAM-SHA-256 for postgres. possibly 
		-- mysql and others since they're probably easy
		IF pwtype = 'cryptMD5' THEN
			crypts := jsonb_insert (crypts,
				ARRAY [ pwtype ],
				concat('"', pgcrypto.crypt(PASSWORD, pgcrypto.gen_salt('md5')), '"')::jsonb);
		ELSIF pwtype = 'blowfish' THEN
			crypts := jsonb_insert (crypts,
				ARRAY [ pwtype ],
				concat('"', pgcrypto.crypt(PASSWORD, pgcrypto.gen_salt('bf')), '"')::jsonb);
		ELSIF pwtype = 'xdes' THEN
			crypts := jsonb_insert (crypts,
				ARRAY [ pwtype ],
				concat('"', pgcrypto.crypt(PASSWORD, pgcrypto.gen_salt('xdes')), '"')::jsonb);
		ELSIF pwtype = 'postgresMD5' THEN
			SELECT	a.login INTO LOGIN
			FROM	account a
			WHERE	a.account_id = set_account_passwords.account_id;
			crypts := jsonb_insert (crypts,
				ARRAY [ pwtype ],
				concat('"md5', md5(concat(PASSWORD, LOGIN)), '"')::jsonb);
		ELSE
			RAISE EXCEPTION 'Unknown pwtype %', pwtype
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END LOOP;

	_tally := 0;
	FOR method, value IN SELECT * FROM jsonb_each_text(crypts)
		LOOP
			IF value IS NULL THEN
				DELETE FROM account_password ap WHERE password_type = method AND ap.account_id = set_account_passwords.account_id;
				CONTINUE;
			END IF;
			p_method := quote_nullable(method);
			p_value := quote_nullable(value);
			cols := ARRAY [ 'password_type', 'password', 'account_id' ];
			vals := ARRAY [ p_method, p_value, '$1' ];
			upd := ARRAY [ 'password_type = ' || p_method, 'password = ' || p_value ];

			IF change_time IS NOT NULL THEN
				cols := cols || quote_ident('change_time');
				vals := vals || quote_nullable(change_time);
				upd := upd || concat('change_time = ',
					 quote_nullable(change_time));

				--
				-- for any password changing, set the expire time so it 
				-- can fall back on default policy, even on NULL
				--
				cols := cols || quote_ident('expire_time');
				vals := vals || quote_nullable(expire_time);
				upd := upd || concat('expire_time = ',
					 quote_nullable(expire_time));
			END IF;
			--
			-- note that account_id is passed in as an argument
			--
			EXECUTE 'INSERT INTO account_password (' || 
					array_to_string(cols, ',') || ' ) VALUES ( ' || 
					array_to_string(vals, ',') || 
					') ON CONFLICT ON CONSTRAINT pk_accunt_password DO UPDATE SET ' || 
					array_to_string(upd, ',')
				USING account_id;
			done := done || method;
			_tally := _tally + 1;
		END LOOP;
	IF purge THEN
		DELETE FROM account_password
		WHERE account_password.account_id = set_account_passwords.account_id
			AND NOT password_type = ANY (done);
	END IF;
	--
	-- This is probably a hack that needs revisiting
	--
	FOR acid, proplen IN SELECT account_collection_id, property_value
		FROM property
		WHERE property_type = 'account-override'
		AND property_name = 'password_expiry_days'
		ORDER BY property_value::integer desc
	LOOP
		IF len >= proplen THEN
			--
			-- conflict means that they are already a part of this.
			--
			INSERT INTO account_collection_account (
				account_collection_id, account_id
			) VALUES (
				acid, set_account_passwords.account_id
			) ON CONFLICT ON CONSTRAINT pk_account_collection_user DO NOTHING;
		ELSE
			DELETE FROM account_collection_account ac 
				WHERE ac.account_collection_id = acid 
				AND ac.account_id = set_account_passwords.account_id;
		END IF;
	END LOOP;
	RETURN _tally;
END;
$function$
;

--
-- Process drops in layerx_network_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('layerx_network_manip', 'delete_layer2_networks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS layerx_network_manip.delete_layer2_networks ( layer2_network_id_list integer[], purge_network_interfaces boolean );
CREATE OR REPLACE FUNCTION layerx_network_manip.delete_layer2_networks(layer2_network_id_list integer[], purge_network_interfaces boolean DEFAULT false)
 RETURNS SETOF jazzhands.layer2_network
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	netblock_id_list	integer[];
BEGIN
	IF array_length(layer2_network_id_list, 1) IS NULL THEN
		RETURN;
	END IF;

	BEGIN
		PERFORM local_hooks.delete_layer2_networks_before_hooks(
			layer2_network_id_list := layer2_network_id_list
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

	PERFORM layerx_network_manip.delete_layer3_networks(
		layer3_network_id_list := ARRAY(
				SELECT layer3_network_id
				FROM layer3_network l3n
				WHERE layer2_network_id = ANY(layer2_network_id_list)
			),
		purge_network_interfaces := 
			delete_layer2_networks.purge_network_interfaces
	);

	DELETE FROM
		l2_network_coll_l2_network l2nc
	WHERE
		l2nc.layer2_network_id = ANY(layer2_network_id_list);

	RETURN QUERY DELETE FROM
		layer2_network l2n
	WHERE
		l2n.layer2_network_id = ANY(layer2_network_id_list)
	RETURNING *;

	BEGIN
		PERFORM local_hooks.delete_layer2_networks_after_hooks(
			layer2_network_id_list := layer2_network_id_list
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

END $function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('layerx_network_manip', 'delete_layer3_networks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS layerx_network_manip.delete_layer3_networks ( layer3_network_id_list integer[], purge_network_interfaces boolean );
CREATE OR REPLACE FUNCTION layerx_network_manip.delete_layer3_networks(layer3_network_id_list integer[], purge_network_interfaces boolean DEFAULT false)
 RETURNS SETOF jazzhands.layer3_network
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	netblock_id_list			integer[];
	network_interface_id_list	integer[];
BEGIN
	IF array_length(layer3_network_id_list, 1) IS NULL THEN
		RETURN;
	END IF;

	BEGIN
		PERFORM local_hooks.delete_layer3_networks_before_hooks(
			layer3_network_id_list := layer3_network_id_list
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

	IF (purge_network_interfaces) THEN
		SELECT ARRAY(
			SELECT
				n.netblock_id AS netblock_id
			FROM
				jazzhands.layer3_network l3 JOIN
				jazzhands.netblock p USING (netblock_id) JOIN
				jazzhands.netblock n ON (p.netblock_id = n.parent_netblock_id)
			WHERE
				l3.layer3_network_id = ANY(layer3_network_id_list)
		) INTO netblock_id_list;

		WITH nin_del AS (
			DELETE FROM
				jazzhands.network_interface_netblock 
			WHERE
				netblock_id = ANY(netblock_id_list)
			RETURNING network_interface_id
		), snni_del AS (
			DELETE FROM
				jazzhands.shared_netblock_network_int
			WHERE
				shared_netblock_id IN (
					SELECT shared_netblock_id FROM jazzhands.shared_netblock
					WHERE netblock_id = ANY(netblock_id_list)
				)
			RETURNING network_interface_id
		)
		SELECT ARRAY(
			SELECT network_interface_id FROM nin_del
			UNION
			SELECT network_interface_id FROM snni_del
		) INTO network_interface_id_list;

		DELETE FROM
			network_interface_purpose nip
		WHERE
			nip.network_interface_id IN (
				SELECT
					network_interface_id
				FROM
					network_interface ni
				WHERE
					ni.network_interface_id = ANY(network_interface_id_list)
						AND
					ni.network_interface_id NOT IN (
						SELECT
							network_interface_id
						FROM
							network_interface_netblock
						UNION
						SELECT 
							network_interface_id
						FROM
							shared_netblock_network_int
					)
			);
			
		DELETE FROM
			network_interface ni
		WHERE
			ni.network_interface_id = ANY(network_interface_id_list) AND
			ni.network_interface_id NOT IN (
				SELECT network_interface_id FROM network_interface_netblock
				UNION
				SELECT network_interface_id FROM shared_netblock_network_int
			);
	END IF;

	RETURN QUERY WITH x AS (
		SELECT
			p.netblock_id AS netblock_id,
			l3.layer3_network_id AS layer3_network_id
		FROM
			jazzhands.layer3_network l3 JOIN
			jazzhands.netblock p USING (netblock_id)
		WHERE
			l3.layer3_network_id = ANY(layer3_network_id_list)
	), l3_coll_del AS (
		DELETE FROM
			jazzhands.l3_network_coll_l3_network
		WHERE
			layer3_network_id IN (SELECT layer3_network_id FROM x)
	), l3_del AS (
		DELETE FROM
			jazzhands.layer3_network
		WHERE
			layer3_network_id in (SELECT layer3_network_id FROM x)
		RETURNING *
	), nb_sel AS (
		SELECT
			n.netblock_id
		FROM
			jazzhands.netblock n JOIN
			x ON (n.parent_netblock_id = x.netblock_id)
	), dns_del AS (
		DELETE FROM
			jazzhands.dns_record
		WHERE
			netblock_id IN (SELECT netblock_id FROM nb_sel)
	), nbc_del as (
		DELETE FROM
			jazzhands.netblock_collection_netblock
		WHERE
			netblock_id IN (SELECT netblock_id FROM x
				UNION SELECT netblock_id FROM nb_sel)
	), nb_del as (
		DELETE FROM
			jazzhands.netblock
		WHERE
			netblock_id IN (SELECT netblock_id FROM nb_sel)
	), sn_del as (
		DELETE FROM
			jazzhands.shared_netblock
		WHERE
			netblock_id IN (SELECT netblock_id FROM nb_sel)
	), nrp_del as (
		DELETE FROM
			property
		WHERE
			network_range_id IN (
				SELECT
					network_range_id
				FROM
					network_range nr JOIN
					x ON (nr.parent_netblock_id = x.netblock_id)
			)
	), nr_del as (
		DELETE FROM
			jazzhands.network_range
		WHERE
			parent_netblock_id IN (SELECT netblock_id FROM x)
		RETURNING
			start_netblock_id, stop_netblock_id
	), nrnb_del AS (
		DELETE FROM
			jazzhands.netblock
		WHERE
			netblock_id IN (
				SELECT start_netblock_id FROM nr_del
				UNION
				SELECT stop_netblock_id FROM nr_del
		)
	), nbd AS (
		DELETE FROM
			jazzhands.netblock
		WHERE
			netblock_id IN (SELECT netblock_id FROM x)
	)
	SELECT * FROM l3_del;

	BEGIN
		PERFORM local_hooks.delete_layer3_networks_after_hooks(
			layer3_network_id_list := layer3_network_id_list
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;
	RETURN;
END $function$
;

--
-- Process drops in auto_ac_manip
--
--
-- Process drops in company_manip
--
--
-- Process drops in component_connection_utils
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
-- Process drops in property_utils
--
--
-- Process drops in netblock_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'allocate_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock ( parent_netblock_id integer, netmask_bits integer, address_type text, can_subnet boolean, allocation_method text, rnd_masklen_threshold integer, rnd_max_count integer, ip_address inet, description character varying, netblock_status character varying );
CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(parent_netblock_id integer, netmask_bits integer DEFAULT NULL::integer, address_type text DEFAULT 'netblock'::text, can_subnet boolean DEFAULT true, allocation_method text DEFAULT NULL::text, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024, ip_address inet DEFAULT NULL::inet, description character varying DEFAULT NULL::character varying, netblock_status character varying DEFAULT 'Allocated'::character varying)
 RETURNS SETOF jazzhands.netblock
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	netblock_rec	RECORD;
BEGIN
	RETURN QUERY
		SELECT * into netblock_rec FROM netblock_manip.allocate_netblock(
		parent_netblock_list := ARRAY[parent_netblock_id],
		netmask_bits := netmask_bits,
		address_type := address_type,
		can_subnet := can_subnet,
		description := description,
		allocation_method := allocation_method,
		ip_address := ip_address,
		rnd_masklen_threshold := rnd_masklen_threshold,
		rnd_max_count := rnd_max_count,
		netblock_status := netblock_status
	);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'allocate_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock ( parent_netblock_list integer[], netmask_bits integer, address_type text, can_subnet boolean, allocation_method text, rnd_masklen_threshold integer, rnd_max_count integer, ip_address inet, description character varying, netblock_status character varying );
CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(parent_netblock_list integer[], netmask_bits integer DEFAULT NULL::integer, address_type text DEFAULT 'netblock'::text, can_subnet boolean DEFAULT true, allocation_method text DEFAULT NULL::text, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024, ip_address inet DEFAULT NULL::inet, description character varying DEFAULT NULL::character varying, netblock_status character varying DEFAULT 'Allocated'::character varying)
 RETURNS SETOF jazzhands.netblock
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	parent_rec		RECORD;
	netblock_rec	RECORD;
	inet_rec		RECORD;
	loopback_bits	integer;
	inet_family		integer;
	ip_addr			ALIAS FOR ip_address;
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

	IF ip_address IS NOT NULL THEN
		SELECT
			array_agg(netblock_id)
		INTO
			parent_netblock_list
		FROM
			netblock n
		WHERE
			ip_addr <<= n.ip_address AND
			netblock_id = ANY(parent_netblock_list);

		IF parent_netblock_list IS NULL THEN
			RETURN;
		END IF;
	END IF;

	-- Lock the parent row, which should keep parallel processes from
	-- trying to obtain the same address

	FOR parent_rec IN SELECT * FROM jazzhands.netblock WHERE netblock_id =
			ANY(allocate_netblock.parent_netblock_list) ORDER BY netblock_id
			FOR UPDATE LOOP

		IF parent_rec.is_single_address = 'Y' THEN
			RAISE EXCEPTION 'parent_netblock_id refers to a single_address netblock'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF inet_family IS NULL THEN
			inet_family := family(parent_rec.ip_address);
		ELSIF inet_family != family(parent_rec.ip_address)
				AND ip_address IS NULL THEN
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
 		RETURN;
 	END IF;

	IF address_type = 'loopback' THEN
		-- If we're allocating a loopback address, then we need to create
		-- a new parent to hold the single loopback address

		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			netmask_bits := loopback_bits,
			single_address := false,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			max_addresses := 1
			);

		IF NOT FOUND THEN
			RETURN;
		END IF;

		INSERT INTO jazzhands.netblock (
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
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO parent_rec;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			parent_rec.netblock_type,
			'Y',
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		PERFORM dns_utils.add_domains_from_netblock(
			netblock_id := netblock_rec.netblock_id);

		RETURN NEXT netblock_rec;
		RETURN;
	END IF;

	IF address_type = 'single' THEN
		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			single_address := true,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			rnd_masklen_threshold := rnd_masklen_threshold,
			rnd_max_count := rnd_max_count,
			max_addresses := 1
			);

		IF NOT FOUND THEN
			RETURN;
		END IF;

		RAISE DEBUG 'ip_address is %', inet_rec.ip_address;

		INSERT INTO jazzhands.netblock (
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

		RETURN NEXT netblock_rec;
		RETURN;
	END IF;
	IF address_type = 'netblock' THEN
		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			netmask_bits := netmask_bits,
			single_address := false,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			max_addresses := 1);

		IF NOT FOUND THEN
			RETURN;
		END IF;

		INSERT INTO jazzhands.netblock (
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

		RAISE DEBUG 'Allocated netblock_id % for %',
			netblock_rec.netblock_id,
			netblock_rec.ip_address;

		PERFORM dns_utils.add_domains_from_netblock(
			netblock_id := netblock_rec.netblock_id);

		RETURN NEXT netblock_rec;
		RETURN;
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'create_network_range');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.create_network_range ( start_ip_address inet, stop_ip_address inet, network_range_type character varying, parent_netblock_id integer, description character varying, allow_assigned boolean, dns_prefix text, dns_domain_id integer, lease_time integer );
CREATE OR REPLACE FUNCTION netblock_manip.create_network_range(start_ip_address inet, stop_ip_address inet, network_range_type character varying, parent_netblock_id integer DEFAULT NULL::integer, description character varying DEFAULT NULL::character varying, allow_assigned boolean DEFAULT false, dns_prefix text DEFAULT NULL::text, dns_domain_id integer DEFAULT NULL::integer, lease_time integer DEFAULT NULL::integer)
 RETURNS jazzhands.network_range
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	par_netblock	RECORD;
	start_netblock	RECORD;
	stop_netblock	RECORD;
	netrange		RECORD;
	nrtype			ALIAS FOR network_range_type;
	pnbid			ALIAS FOR parent_netblock_id;
BEGIN
	--
	-- If the network range already exists, then just return it
	--
	SELECT
		nr.* INTO netrange
	FROM
		jazzhands.network_range nr JOIN
		jazzhands.netblock startnb ON (nr.start_netblock_id =
			startnb.netblock_id) JOIN
		jazzhands.netblock stopnb ON (nr.stop_netblock_id = stopnb.netblock_id)
	WHERE
		nr.network_range_type = nrtype AND
		host(startnb.ip_address) = host(start_ip_address) AND
		host(stopnb.ip_address) = host(stop_ip_address) AND
		CASE WHEN pnbid IS NOT NULL THEN
			(pnbid = nr.parent_netblock_id)
		ELSE
			true
		END;

	IF FOUND THEN
		RETURN netrange;
	END IF;

	--
	-- If any other network ranges exist that overlap this, then error
	--
	PERFORM
		*
	FROM
		jazzhands.network_range nr JOIN
		jazzhands.netblock startnb ON
			(nr.start_netblock_id = startnb.netblock_id) JOIN
		jazzhands.netblock stopnb ON (nr.stop_netblock_id = stopnb.netblock_id)
	WHERE
		nr.network_range_type = nrtype AND ((
			host(startnb.ip_address)::inet <= host(start_ip_address)::inet AND
			host(stopnb.ip_address)::inet >= host(start_ip_address)::inet
		) OR (
			host(startnb.ip_address)::inet <= host(stop_ip_address)::inet AND
			host(stopnb.ip_address)::inet >= host(stop_ip_address)::inet
		));

	IF FOUND THEN
		RAISE 'create_network_range: a network_range of type % already exists that has addresses between % and %',
			nrtype, start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
	END IF;

	IF parent_netblock_id IS NOT NULL THEN
		SELECT * INTO par_netblock FROM jazzhands.netblock WHERE
			netblock_id = pnbid;
		IF NOT FOUND THEN
			RAISE 'create_network_range: parent_netblock_id % does not exist',
				parent_netblock_id USING ERRCODE = 'foreign_key_violation';
		END IF;
	ELSE
		SELECT * INTO par_netblock FROM jazzhands.netblock WHERE netblock_id = (
			SELECT
				*
			FROM
				netblock_utils.find_best_parent_id(
					in_ipaddress := start_ip_address,
					in_is_single_address := 'Y'
				)
		);

		IF NOT FOUND THEN
			RAISE 'create_network_range: valid parent netblock for start_ip_address % does not exist',
				start_ip_address USING ERRCODE = 'check_violation';
		END IF;
	END IF;

	IF par_netblock.can_subnet != 'N' OR
			par_netblock.is_single_address != 'N' THEN
		RAISE 'create_network_range: parent netblock % must not be subnettable or a single address',
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (start_ip_address <<= par_netblock.ip_address) THEN
		RAISE 'create_network_range: start_ip_address % is not contained by parent netblock % (%)',
			start_ip_address, par_netblock.ip_address,
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (stop_ip_address <<= par_netblock.ip_address) THEN
		RAISE 'create_network_range: stop_ip_address % is not contained by parent netblock % (%)',
			stop_ip_address, par_netblock.ip_address,
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (start_ip_address <= stop_ip_address) THEN
		RAISE 'create_network_range: start_ip_address % is not lower than stop_ip_address %',
			start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
	END IF;

	--
	-- Validate that there are not currently any addresses assigned in the
	-- range, unless allow_assigned is set
	--
	IF NOT allow_assigned THEN
		PERFORM
			*
		FROM
			jazzhands.netblock n
		WHERE
			n.parent_netblock_id = par_netblock.netblock_id AND
			host(n.ip_address)::inet > host(start_ip_address)::inet AND
			host(n.ip_address)::inet < host(stop_ip_address)::inet;

		IF FOUND THEN
			RAISE 'create_network_range: netblocks are already present for parent netblock % betweeen % and %',
			par_netblock.netblock_id,
			start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
		END IF;
	END IF;

	--
	-- Ok, well, we should be able to insert things now
	--

	SELECT
		*
	FROM
		jazzhands.netblock n
	INTO
		start_netblock
	WHERE
		host(n.ip_address)::inet = start_ip_address AND
		n.netblock_type = 'network_range' AND
		n.can_subnet = 'N' AND
		n.is_single_address = 'Y' AND
		n.ip_universe_id = par_netblock.ip_universe_id;

	IF NOT FOUND THEN
		INSERT INTO netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			netblock_status,
			ip_universe_id
		) VALUES (
			host(start_ip_address)::inet,
			'network_range',
			'Y',
			'N',
			'Allocated',
			par_netblock.ip_universe_id
		) RETURNING * INTO start_netblock;
	END IF;

	SELECT
		*
	FROM
		jazzhands.netblock n
	INTO
		stop_netblock
	WHERE
		host(n.ip_address)::inet = stop_ip_address AND
		n.netblock_type = 'network_range' AND
		n.can_subnet = 'N' AND
		n.is_single_address = 'Y' AND
		n.ip_universe_id = par_netblock.ip_universe_id;

	IF NOT FOUND THEN
		INSERT INTO netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			netblock_status,
			ip_universe_id
		) VALUES (
			host(stop_ip_address)::inet,
			'network_range',
			'Y',
			'N',
			'Allocated',
			par_netblock.ip_universe_id
		) RETURNING * INTO stop_netblock;
	END IF;

	INSERT INTO network_range (
		network_range_type,
		description,
		parent_netblock_id,
		start_netblock_id,
		stop_netblock_id,
		dns_prefix,
		dns_domain_id,
		lease_time
	) VALUES (
		nrtype,
		description,
		par_netblock.netblock_id,
		start_netblock.netblock_id,
		stop_netblock.netblock_id,
		create_network_range.dns_prefix,
		create_network_range.dns_domain_id,
		create_network_range.lease_time
	) RETURNING * INTO netrange;

	RETURN netrange;

	RETURN NULL;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'set_interface_addresses');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.set_interface_addresses ( network_interface_id integer, device_id integer, network_interface_name text, network_interface_type text, ip_address_hash jsonb, create_layer3_networks boolean, move_addresses text, address_errors text );
CREATE OR REPLACE FUNCTION netblock_manip.set_interface_addresses(network_interface_id integer DEFAULT NULL::integer, device_id integer DEFAULT NULL::integer, network_interface_name text DEFAULT NULL::text, network_interface_type text DEFAULT 'broadcast'::text, ip_address_hash jsonb DEFAULT NULL::jsonb, create_layer3_networks boolean DEFAULT false, move_addresses text DEFAULT 'if_same_device'::text, address_errors text DEFAULT 'error'::text)
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
	ni_id			ALIAS FOR network_interface_id;
	dev_id			ALIAS FOR device_id;
	ni_name			ALIAS FOR network_interface_name;
	ni_type			ALIAS FOR network_interface_type;

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
	ni_rec			RECORD;
	nin_rec			RECORD;
	nb_id			jazzhands.netblock.netblock_id%TYPE;
	nb_id_ary		integer[];
	ni_id_ary		integer[];
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

	IF network_interface_id IS NULL THEN
		IF device_id IS NULL OR network_interface_name IS NULL THEN
			RAISE 'netblock_manip.assign_shared_netblock: must pass either network_interface_id or device_id and network_interface_name'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;

		SELECT
			ni.network_interface_id INTO ni_id
		FROM
			network_interface ni
		WHERE
			ni.device_id = dev_id AND
			ni.network_interface_name = ni_name;

		IF NOT FOUND THEN
			INSERT INTO network_interface(
				device_id,
				network_interface_name,
				network_interface_type,
				should_monitor
			) VALUES (
				dev_id,
				ni_name,
				ni_type,
				'N'
			) RETURNING network_interface.network_interface_id INTO ni_id;
		END IF;
	END IF;

	SELECT * INTO ni_rec FROM network_interface ni WHERE
		ni.network_interface_id = ni_id;

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
				v_netblock_coll_expanded nce USING (netblock_collection_id)
					JOIN
				property p ON (
					property_name = 'IgnoreProbedNetblocks' AND
					property_type = 'DeviceInventory' AND
					property_value_nblk_coll_id =
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
			-- Look for an is_single_address='Y', can_subnet='N' netblock
			-- with the given ip_address
			--
			SELECT
				* INTO nb_rec
			FROM
				netblock n
			WHERE
				is_single_address = 'Y' AND
				can_subnet = 'N' AND
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
					is_single_address = 'N' AND
					can_subnet = 'N' AND
					n.ip_address >>= ipaddr;

				IF NOT FOUND THEN
					RAISE DEBUG 'Parent netblock with ip_address %, netblock_type %, ip_universe_id % not found',
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					--
					-- Check to see if the netblock exists, but is
					-- marked can_subnet='Y'.  If so, fix it
					--
					SELECT
						* INTO pnb_rec
					FROM
						netblock n
					WHERE
						n.ip_universe_id = universe AND
						n.netblock_type = nb_type AND
						n.is_single_address = 'N' AND
						n.can_subnet = 'Y' AND
						n.ip_address = network(ipaddr);

					IF FOUND THEN
						UPDATE netblock n SET
							can_subnet = 'N'
						WHERE
							n.netblock_id = pnb_rec.netblock_id;
						pnb_rec.can_subnet = 'N';
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
							'N',
							'N',
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
					'Y',
					'N',
					'Allocated'
				) RETURNING * INTO nb_rec;
				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);
			END IF;
			--
			-- Now that we have the netblock and everything, check to see
			-- if this netblock is already assigned to this network_interface
			--
			PERFORM * FROM
				network_interface_netblock nin
			WHERE
				nin.netblock_id = nb_rec.netblock_id AND
				nin.network_interface_id = ni_id;

			IF FOUND THEN
				RAISE DEBUG 'Netblock % already found on network_interface',
					nb_rec.netblock_id;
				CONTINUE;
			END IF;

			--
			-- See if this netblock is on something else, and delete it
			-- if move_addresses is set, otherwise skip it
			--
			SELECT
				ni.network_interface_id,
				ni.network_interface_name,
				nin.netblock_id,
				d.device_id,
				COALESCE(d.device_name, d.physical_label) AS device_name
			INTO nin_rec
			FROM
				network_interface_netblock nin JOIN
				network_interface ni USING (network_interface_id) JOIN
				device d ON (nin.device_id = d.device_id)
			WHERE
				nin.netblock_id = nb_rec.netblock_id AND
				nin.network_interface_id != ni_id;

			IF FOUND THEN
				IF move_addresses = 'always' OR (
					move_addresses = 'if_same_device' AND
					nin_rec.device_id = ni_rec.device_id
				)
				THEN
					DELETE FROM
						network_interface_netblock
					WHERE
						netblock_id = nb_rec.netblock_id;
				ELSE
					IF address_errors = 'ignore' THEN
						RAISE DEBUG 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;

						CONTINUE;
					ELSIF address_errors = 'warn' THEN
						RAISE NOTICE 'Netblock % (%) is assigned to network_interface % (%) on device % (%)',
							nb_rec.netblock_id,
							nb_rec.ip_address,
							nin_rec.network_interface_id,
							nin_rec.network_interface_name,
							nin_rec.device_id,
							nin_rec.device_name;

						CONTINUE;
					ELSE
						RAISE 'Netblock % (%) is assigned to network_interface %(%) on device % (%)',
							nb_rec.netblock_id,
							nb_rec.ip_address,
							nin_rec.network_interface_id,
							nin_rec.network_interface_name,
							nin_rec.device_id,
							nin_rec.device_name;
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
					shared_netblock_network_int snni
				WHERE
					snni.shared_netblock_id = sn_rec.shared_netblock_id;

				DELETE FROM
					shared_network sn
				WHERE
					sn.netblock_id = sn_rec.shared_netblock_id;
			END IF;

			--
			-- Insert the netblock onto the interface using the next
			-- rank
			--
			INSERT INTO network_interface_netblock (
				network_interface_id,
				netblock_id,
				network_interface_rank
			) SELECT
				ni_id,
				nb_rec.netblock_id,
				COALESCE(MAX(network_interface_rank) + 1, 0)
			FROM
				network_interface_netblock nin
			WHERE
				nin.network_interface_id = ni_id
			RETURNING * INTO nin_rec;

			RAISE DEBUG E'Inserted into:\n%',
				jsonb_pretty(to_jsonb(nin_rec));
		END LOOP;
		--
		-- Remove any netblocks that are on the interface that are not
		-- supposed to be (and that aren't ignored).
		--

		FOR nin_rec IN
			DELETE FROM
				network_interface_netblock nin
			WHERE
				(nin.network_interface_id, nin.netblock_id) IN (
				SELECT
					nin2.network_interface_id,
					nin2.netblock_id
				FROM
					network_interface_netblock nin2 JOIN
					netblock n USING (netblock_id)
				WHERE
					nin2.network_interface_id = ni_id AND NOT (
						nin.netblock_id = ANY(nb_id_ary) OR
						n.ip_address <<= ANY ( ARRAY (
							SELECT
								n2.ip_address
							FROM
								netblock n2 JOIN
								netblock_collection_netblock ncn USING
									(netblock_id) JOIN
								v_netblock_coll_expanded nce USING
									(netblock_collection_id) JOIN
								property p ON (
									property_name = 'IgnoreProbedNetblocks' AND
									property_type = 'DeviceInventory' AND
									property_value_nblk_coll_id =
										nce.root_netblock_collection_id
								)
						))
					)
			)
			RETURNING *
		LOOP
			RAISE DEBUG 'Removed netblock % from network_interface %',
				nin_rec.netblock_id,
				nin_rec.network_interface_id;
			--
			-- Remove any DNS records and/or netblocks that aren't used
			--
			BEGIN
				DELETE FROM dns_record WHERE netblock_id = nin_rec.netblock_id;
				DELETE FROM netblock_collection_netblock WHERE
					netblock_id = nin_rec.netblock_id;
				DELETE FROM netblock WHERE netblock_id =
					nin_rec.netblock_id;
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
				v_netblock_coll_expanded nce USING (netblock_collection_id)
					JOIN
				property p ON (
					property_name = 'IgnoreProbedNetblocks' AND
					property_type = 'DeviceInventory' AND
					property_value_nblk_coll_id =
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
			-- Look for an is_single_address='Y', can_subnet='N' netblock
			-- with the given ip_address
			--
			SELECT
				* INTO nb_rec
			FROM
				netblock n
			WHERE
				is_single_address = 'Y' AND
				can_subnet = 'N' AND
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
					is_single_address = 'N' AND
					can_subnet = 'N' AND
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
							'N',
							'N',
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
					'Y',
					'N',
					'Allocated'
				) RETURNING * INTO nb_rec;
				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);
			END IF;

			--
			-- See if this netblock is directly on any network_interface, and
			-- delete it if force is set, otherwise skip it
			--
			ni_id_ary := ARRAY[]::integer[];

			SELECT
				ni.network_interface_id,
				nin.netblock_id,
				ni.device_id
			INTO nin_rec
			FROM
				network_interface_netblock nin JOIN
				network_interface ni USING (network_interface_id)
			WHERE
				nin.netblock_id = nb_rec.netblock_id AND
				nin.network_interface_id != ni_id;

			IF FOUND THEN
				IF move_addresses = 'always' OR (
					move_addresses = 'if_same_device' AND
					nin_rec.device_id = ni_rec.device_id
				)
				THEN
					--
					-- Remove the netblocks from the network_interfaces,
					-- but save them for later so that we can migrate them
					-- after we make sure the shared_netblock exists.
					--
					-- Also, append the network_inteface_id that we
					-- specifically care about, and we'll add them all
					-- below
					--
					WITH z AS (
						DELETE FROM
							network_interface_netblock nin
						WHERE
							nin.netblock_id = nb_rec.netblock_id
						RETURNING nin.network_interface_id
					)
					SELECT array_agg(v.network_interface_id) FROM
						(SELECT z.network_interface_id FROM z) v
					INTO ni_id_ary;
				ELSE
					IF address_errors = 'ignore' THEN
						RAISE DEBUG 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;

						CONTINUE;
					ELSIF address_errors = 'warn' THEN
						RAISE NOTICE 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;

						CONTINUE;
					ELSE
						RAISE 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;
					END IF;
				END IF;

			END IF;

			IF NOT(ni_id = ANY(ni_id_ary)) THEN
				ni_id_ary := array_append(ni_id_ary, ni_id);
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

			INSERT INTO shared_netblock_network_int (
				shared_netblock_id,
				network_interface_id,
				priority
			) SELECT
				sn_rec.shared_netblock_id,
				x.network_interface_id,
				0
			FROM
				unnest(ni_id_ary) x(network_interface_id)
			ON CONFLICT ON CONSTRAINT pk_ip_group_network_interface DO NOTHING;

			RAISE DEBUG E'Inserted shared_netblock % onto interfaces:\n%',
				sn_rec.shared_netblock_id, jsonb_pretty(to_jsonb(ni_id_ary));
		END LOOP;
		--
		-- Remove any shared_netblocks that are on the interface that are not
		-- supposed to be (and that aren't ignored).
		--

		FOR nin_rec IN
			DELETE FROM
				shared_netblock_network_int snni
			WHERE
				(snni.network_interface_id, snni.shared_netblock_id) IN (
				SELECT
					snni2.network_interface_id,
					snni2.shared_netblock_id
				FROM
					shared_netblock_network_int snni2 JOIN
					shared_netblock sn USING (shared_netblock_id) JOIN
					netblock n USING (netblock_id)
				WHERE
					snni2.network_interface_id = ni_id AND NOT (
						sn.netblock_id = ANY(nb_id_ary) OR
						n.ip_address <<= ANY ( ARRAY (
							SELECT
								n2.ip_address
							FROM
								netblock n2 JOIN
								netblock_collection_netblock ncn USING
									(netblock_id) JOIN
								v_netblock_coll_expanded nce USING
									(netblock_collection_id) JOIN
								property p ON (
									property_name = 'IgnoreProbedNetblocks' AND
									property_type = 'DeviceInventory' AND
									property_value_nblk_coll_id =
										nce.root_netblock_collection_id
								)
						))
					)
			)
			RETURNING *
		LOOP
			RAISE DEBUG 'Removed shared_netblock % from network_interface %',
				nin_rec.shared_netblock_id,
				nin_rec.network_interface_id;

			--
			-- Remove any DNS records, netblocks and shared_netblocks
			-- that aren't used
			--
			SELECT netblock_id INTO nb_id FROM shared_netblock sn WHERE
				sn.shared_netblock_id = nin_rec.shared_netblock_id;
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
-- Process drops in physical_address_utils
--
--
-- Process drops in component_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'create_component_template_slots');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.create_component_template_slots ( component_id integer );
CREATE OR REPLACE FUNCTION component_utils.create_component_template_slots(component_id integer)
 RETURNS SETOF jazzhands.slot
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	ctid	jazzhands.component_type.component_type_id%TYPE;
	s		jazzhands.slot%ROWTYPE;
	cid 	ALIAS FOR component_id;
BEGIN
	FOR s IN
		INSERT INTO jazzhands.slot (
			component_id,
			slot_name,
			slot_type_id,
			slot_index,
			component_type_slot_tmplt_id,
			physical_label,
			slot_x_offset,
			slot_y_offset,
			slot_z_offset,
			slot_side
		) SELECT
			cid,
			ctst.slot_name_template,
			ctst.slot_type_id,
			ctst.slot_index,
			ctst.component_type_slot_tmplt_id,
			ctst.physical_label,
			ctst.slot_x_offset,
			ctst.slot_y_offset,
			ctst.slot_z_offset,
			ctst.slot_side
		FROM
			component_type_slot_tmplt ctst JOIN
			component c USING (component_type_id) LEFT JOIN
			slot ON (slot.component_id = cid AND
				slot.component_type_slot_tmplt_id =
				ctst.component_type_slot_tmplt_id
			)
		WHERE
			c.component_id = cid AND
			slot.component_type_slot_tmplt_id IS NULL
		ORDER BY ctst.component_type_slot_tmplt_id
		RETURNING *
	LOOP
		RAISE DEBUG 'Creating slot for component % from template %',
			cid, s.component_type_slot_tmplt_id;
		RETURN NEXT s;
	END LOOP;
END;
$function$
;

DROP FUNCTION IF EXISTS component_utils.fetch_component ( component_type_id integer, serial_number text, no_create boolean, ownership_status text );
-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'insert_cpu_component');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.insert_cpu_component ( model text, processor_speed bigint, processor_cores bigint, socket_type text, vendor_name text, serial_number text );
CREATE OR REPLACE FUNCTION component_utils.insert_cpu_component(model text, processor_speed bigint, processor_cores bigint, socket_type text, vendor_name text DEFAULT NULL::text, serial_number text DEFAULT NULL::text)
 RETURNS jazzhands.component
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	m			ALIAS FOR model;
	sn			ALIAS FOR serial_number;
	ctid		integer;
	stid		integer;
	c			RECORD;
	cid			integer;
BEGIN
	cid := NULL;

	IF vendor_name IS NOT NULL THEN	
		SELECT 
			company_id INTO cid
		FROM
			company c LEFT JOIN
			property p USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'VendorCPUProbeString' AND
			property_value = vendor_name;
	END IF;

	--
	-- See if we have this component type in the database already.
	--
	SELECT DISTINCT
		component_type_id INTO ctid
	FROM
		component_type ct JOIN
		component_type_component_func ctcf USING (component_type_id)
	WHERE
		component_function = 'CPU' AND
		ct.model = m AND
		CASE WHEN cid IS NOT NULL THEN
			(company_id = cid)
		ELSE
			true
		END;

	--
	-- If the type isn't found, then we need to insert it
	--
	IF NOT FOUND THEN
		--
		-- Fetch the slot type
		--
		SELECT 
			slot_type_id INTO stid
		FROM
			slot_type st
		WHERE
			st.slot_type = socket_type AND
			slot_function = 'CPU';

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type %, function % not found adding component_type',
				socket_type,
				'CPU'
				USING ERRCODE = 'JH501';
		END IF;

		IF cid IS NULL THEN
			SELECT
				company_id INTO cid
			FROM
				company
			WHERE
				company_name = 'unknown';

			IF NOT FOUND THEN
				IF NOT FOUND THEN
					RAISE EXCEPTION 'company_id for unknown company not found adding component_type'
						USING ERRCODE = 'JH501';
				END IF;
			END IF;
		END IF;

		INSERT INTO component_type (
			company_id,
			model,
			slot_type_id,
			asset_permitted,
			description
		) VALUES (
			cid,
			model,
			stid,
			'Y',
			model
		) RETURNING component_type_id INTO ctid;

		--
		-- Insert component properties for the CPU
		--
		INSERT INTO component_property (
			component_property_name,
			component_property_type,
			component_type_id,
			property_value
		) VALUES 
			('ProcessorCores', 'CPU', ctid, processor_cores),
			('ProcessorSpeed', 'CPU', ctid, processor_speed);
		
		--
		-- Insert the component functions
		--

		INSERT INTO component_type_component_func (
			component_type_id,
			component_function
		) SELECT DISTINCT
			ctid,
			cf
		FROM
			unnest(ARRAY['CPU']) x(cf);
	END IF;

	--
	-- We have a component_type_id now, so look to see if this component
	-- serial number already exists
	--
	IF serial_number IS NOT NULL THEN
		SELECT 
			component.* INTO c
		FROM
			component JOIN
			asset a USING (component_id)
		WHERE
			component_type_id = ctid AND
			a.serial_number = sn;

		IF FOUND THEN
			RETURN c;
		END IF;
	END IF;

	INSERT INTO jazzhands.component (
		component_type_id
	) VALUES (
		ctid
	) RETURNING * INTO c;

	IF serial_number IS NOT NULL THEN
		INSERT INTO asset (
			component_id,
			serial_number,
			ownership_status
		) VALUES (
			c.component_id,
			serial_number,
			'unknown'
		);
	END IF;

	RETURN c;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'insert_disk_component');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.insert_disk_component ( model text, bytes bigint, vendor_name text, protocol text, media_type text, serial_number text );
CREATE OR REPLACE FUNCTION component_utils.insert_disk_component(model text, bytes bigint, vendor_name text DEFAULT NULL::text, protocol text DEFAULT 'SATA'::text, media_type text DEFAULT 'Rotational'::text, serial_number text DEFAULT NULL::text)
 RETURNS jazzhands.component
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	m			ALIAS FOR model;
	sn			ALIAS FOR serial_number;
	ctid		integer;
	stid		integer;
	c			RECORD;
	cid			integer;
BEGIN
	cid := NULL;

	IF vendor_name IS NOT NULL THEN	
		SELECT 
			company_id INTO cid
		FROM
			company c LEFT JOIN
			property p USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'VendorDiskProbeString' AND
			property_value = vendor_name;
	END IF;

	--
	-- See if we have this component type in the database already.
	--
	SELECT DISTINCT
		component_type_id INTO ctid
	FROM
		component_type ct JOIN
		component_type_component_func ctcf USING (component_type_id)
	WHERE
		component_function = 'disk' AND
		ct.model = m AND
		CASE WHEN cid IS NOT NULL THEN
			(company_id = cid)
		ELSE
			true
		END;

	--
	-- If the type isn't found, then we need to insert it
	--
	IF NOT FOUND THEN
		--
		-- Fetch the slot type
		--
		SELECT 
			slot_type_id INTO stid
		FROM
			slot_type st
		WHERE
			st.slot_type = protocol AND
			slot_function = 'disk';

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type % with function disk not found adding component_type',
				protocol
				USING ERRCODE = 'JH501';
		END IF;

		IF cid IS NULL THEN
			SELECT
				company_id INTO cid
			FROM
				company
			WHERE
				company_name = 'unknown';

			IF NOT FOUND THEN
				IF NOT FOUND THEN
					RAISE EXCEPTION 'company_id for unknown company not found adding component_type'
						USING ERRCODE = 'JH501';
				END IF;
			END IF;
		END IF;

		INSERT INTO component_type (
			company_id,
			model,
			slot_type_id,
			asset_permitted,
			description
		) VALUES (
			cid,
			model,
			stid,
			'Y',
			concat_ws(' ', vendor_name, model, media_type, 'disk')
		) RETURNING component_type_id INTO ctid;

		--
		-- Insert component properties for the disk
		--
		INSERT INTO component_property (
			component_property_name,
			component_property_type,
			component_type_id,
			property_value
		) VALUES 
			('DiskSize', 'disk', ctid, bytes),
			('DiskProtocol', 'disk', ctid, protocol),
			('MediaType', 'disk', ctid, media_type);
		
		--
		-- Insert the component functions
		--

		INSERT INTO component_type_component_func (
			component_type_id,
			component_function
		) SELECT DISTINCT
			ctid,
			cf
		FROM
			unnest(ARRAY['storage', 'disk']) x(cf);
	END IF;

	--
	-- We have a component_type_id now, so look to see if this component
	-- serial number already exists
	--
	IF serial_number IS NOT NULL THEN
		SELECT 
			component.* INTO c
		FROM
			component JOIN
			asset a USING (component_id)
		WHERE
			component_type_id = ctid AND
			a.serial_number = sn;

		IF FOUND THEN
			RETURN c;
		END IF;
	END IF;

	INSERT INTO jazzhands.component (
		component_type_id
	) VALUES (
		ctid
	) RETURNING * INTO c;

	IF serial_number IS NOT NULL THEN
		INSERT INTO asset (
			component_id,
			serial_number,
			ownership_status
		) VALUES (
			c.component_id,
			serial_number,
			'unknown'
		);
	END IF;

	RETURN c;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'insert_memory_component');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.insert_memory_component ( model text, memory_size bigint, memory_speed bigint, memory_type text, vendor_name text, serial_number text );
CREATE OR REPLACE FUNCTION component_utils.insert_memory_component(model text, memory_size bigint, memory_speed bigint, memory_type text DEFAULT 'DDR3'::text, vendor_name text DEFAULT NULL::text, serial_number text DEFAULT NULL::text)
 RETURNS jazzhands.component
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	m			ALIAS FOR model;
	sn			ALIAS FOR serial_number;
	ctid		integer;
	stid		integer;
	c			RECORD;
	cid			integer;
BEGIN
	cid := NULL;

	IF vendor_name IS NOT NULL THEN	
		SELECT 
			company_id INTO cid
		FROM
			company c LEFT JOIN
			property p USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'VendorMemoryProbeString' AND
			property_value = vendor_name;
	END IF;

	--
	-- See if we have this component type in the database already.
	--
	SELECT DISTINCT
		component_type_id INTO ctid
	FROM
		component_type ct JOIN
		component_type_component_func ctcf USING (component_type_id)
	WHERE
		component_function = 'memory' AND
		ct.model = m AND
		CASE WHEN cid IS NOT NULL THEN
			(company_id = cid)
		ELSE
			true
		END;

	--
	-- If the type isn't found, then we need to insert it
	--
	IF NOT FOUND THEN
		--
		-- Fetch the slot type
		--
		SELECT 
			slot_type_id INTO stid
		FROM
			slot_type st
		WHERE
			st.slot_type = memory_type AND
			slot_function = 'memory';

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type % with function memory not found adding component_type',
				memory_type
				USING ERRCODE = 'JH501';
		END IF;

		IF cid IS NULL THEN
			SELECT
				company_id INTO cid
			FROM
				company
			WHERE
				company_name = 'unknown';

			IF NOT FOUND THEN
				IF NOT FOUND THEN
					RAISE EXCEPTION 'company_id for unknown company not found adding component_type'
						USING ERRCODE = 'JH501';
				END IF;
			END IF;
		END IF;

		INSERT INTO component_type (
			company_id,
			model,
			slot_type_id,
			asset_permitted,
			description
		) VALUES (
			cid,
			model,
			stid,
			'Y',
			concat_ws(' ', vendor_name, model, (memory_size || 'MB'), 'memory')
		) RETURNING component_type_id INTO ctid;

		--
		-- Insert component properties for the memory
		--
		INSERT INTO component_property (
			component_property_name,
			component_property_type,
			component_type_id,
			property_value
		) VALUES 
			('MemorySize', 'memory', ctid, memory_size),
			('MemorySpeed', 'memory', ctid, memory_speed);
		
		--
		-- Insert the component functions
		--

		INSERT INTO component_type_component_func (
			component_type_id,
			component_function
		) SELECT DISTINCT
			ctid,
			cf
		FROM
			unnest(ARRAY['memory']) x(cf);
	END IF;

	--
	-- We have a component_type_id now, so look to see if this component
	-- serial number already exists
	--
	IF serial_number IS NOT NULL THEN
		SELECT 
			component.* INTO c
		FROM
			component JOIN
			asset a USING (component_id)
		WHERE
			component_type_id = ctid AND
			a.serial_number = sn;

		IF FOUND THEN
			RETURN c;
		END IF;
	END IF;

	INSERT INTO jazzhands.component (
		component_type_id
	) VALUES (
		ctid
	) RETURNING * INTO c;

	IF serial_number IS NOT NULL THEN
		INSERT INTO asset (
			component_id,
			serial_number,
			ownership_status
		) VALUES (
			c.component_id,
			serial_number,
			'unknown'
		);
	END IF;

	RETURN c;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'insert_pci_component');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.insert_pci_component ( pci_vendor_id integer, pci_device_id integer, pci_sub_vendor_id integer, pci_subsystem_id integer, pci_vendor_name text, pci_device_name text, pci_sub_vendor_name text, pci_sub_device_name text, component_function_list text[], slot_type text, serial_number text );
CREATE OR REPLACE FUNCTION component_utils.insert_pci_component(pci_vendor_id integer, pci_device_id integer, pci_sub_vendor_id integer DEFAULT NULL::integer, pci_subsystem_id integer DEFAULT NULL::integer, pci_vendor_name text DEFAULT NULL::text, pci_device_name text DEFAULT NULL::text, pci_sub_vendor_name text DEFAULT NULL::text, pci_sub_device_name text DEFAULT NULL::text, component_function_list text[] DEFAULT NULL::text[], slot_type text DEFAULT 'unknown'::text, serial_number text DEFAULT NULL::text)
 RETURNS jazzhands.component
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	sn			ALIAS FOR serial_number;
	ctid		integer;
	comp_id		integer;
	sub_comp_id	integer;
	stid		integer;
	vendor_name	text;
	sub_vendor_name	text;
	model_name	text;
	c			RECORD;
BEGIN
	IF (pci_sub_vendor_id IS NULL AND pci_subsystem_id IS NOT NULL) OR
			(pci_sub_vendor_id IS NOT NULL AND pci_subsystem_id IS NULL) THEN
		RAISE EXCEPTION
			'pci_sub_vendor_id and pci_subsystem_id must be set together';
	END IF;

	--
	-- See if we have this component type in the database already
	--
	SELECT
		vid.component_type_id INTO ctid
	FROM
		component_property vid JOIN
		component_property did ON (
			vid.component_property_name = 'PCIVendorID' AND
			vid.component_property_type = 'PCI' AND
			did.component_property_name = 'PCIDeviceID' AND
			did.component_property_type = 'PCI' AND
			vid.component_type_id = did.component_type_id ) LEFT JOIN
		component_property svid ON (
			svid.component_property_name = 'PCISubsystemVendorID' AND
			svid.component_property_type = 'PCI' AND
			svid.component_type_id = did.component_type_id ) LEFT JOIN
		component_property sid ON (
			sid.component_property_name = 'PCISubsystemID' AND
			sid.component_property_type = 'PCI' AND
			sid.component_type_id = did.component_type_id )
	WHERE
		vid.property_value = pci_vendor_id::varchar AND
		did.property_value = pci_device_id::varchar AND
		svid.property_value IS NOT DISTINCT FROM pci_sub_vendor_id::varchar AND
		sid.property_value IS NOT DISTINCT FROM pci_subsystem_id::varchar;

	--
	-- The device type doesn't exist, so attempt to insert it
	--

	IF NOT FOUND THEN	
		IF pci_device_name IS NULL OR component_function_list IS NULL THEN
			RAISE EXCEPTION 'component_id not found and pci_device_name or component_function_list was not passed' USING ERRCODE = 'JH501';
		END IF;

		--
		-- Ensure that there's a company linkage for the PCI (subsystem)vendor
		--
		SELECT
			company_id, company_name INTO comp_id, vendor_name
		FROM
			property p JOIN
			company c USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'PCIVendorID' AND
			property_value = pci_vendor_id::text;
		
		IF NOT FOUND THEN
			IF pci_vendor_name IS NULL THEN
				RAISE EXCEPTION 'PCI vendor id mapping not found and pci_vendor_name was not passed' USING ERRCODE = 'JH501';
			END IF;
			SELECT company_id INTO comp_id FROM company
			WHERE company_name = pci_vendor_name;
		
			IF NOT FOUND THEN
				SELECT company_manip.add_company(
					_company_name := pci_vendor_name,
					_company_types := ARRAY['hardware provider'],
					 _description := 'PCI vendor auto-insert'
				) INTO comp_id;
			END IF;

			INSERT INTO property (
				property_name,
				property_type,
				property_value,
				company_id
			) VALUES (
				'PCIVendorID',
				'DeviceProvisioning',
				pci_vendor_id,
				comp_id
			);
			vendor_name := pci_vendor_name;
		END IF;

		SELECT
			company_id, company_name INTO sub_comp_id, sub_vendor_name
		FROM
			property JOIN
			company c USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'PCIVendorID' AND
			property_value = pci_sub_vendor_id::text;
		
		IF NOT FOUND THEN
			IF pci_sub_vendor_name IS NULL THEN
				RAISE EXCEPTION 'PCI subsystem vendor id mapping not found and pci_sub_vendor_name was not passed' USING ERRCODE = 'JH501';
			END IF;
			SELECT company_id INTO sub_comp_id FROM company
			WHERE company_name = pci_sub_vendor_name;
		
			IF NOT FOUND THEN
				SELECT company_manip.add_company(
					_company_name := pci_sub_vendor_name,
					_company_types := ARRAY['hardware provider'],
					 _description := 'PCI vendor auto-insert'
				) INTO sub_comp_id;
			END IF;

			INSERT INTO property (
				property_name,
				property_type,
				property_value,
				company_id
			) VALUES (
				'PCIVendorID',
				'DeviceProvisioning',
				pci_sub_vendor_id,
				sub_comp_id
			);
			sub_vendor_name := pci_sub_vendor_name;
		END IF;

		--
		-- Fetch the slot type
		--

		SELECT 
			slot_type_id INTO stid
		FROM
			slot_type st
		WHERE
			st.slot_type = insert_pci_component.slot_type AND
			slot_function = 'PCI';

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type % with function PCI not found adding component_type',
				insert_pci_component.slot_type
				USING ERRCODE = 'JH501';
		END IF;

		--
		-- Figure out the best name/description to insert this component with
		--
		IF pci_sub_device_name IS NOT NULL AND pci_sub_device_name != 'Device' THEN
			model_name = concat_ws(' ', 
				sub_vendor_name, pci_sub_device_name,
				'(' || vendor_name, pci_device_name || ')');
		ELSIF pci_sub_device_name = 'Device' THEN
			model_name = concat_ws(' ', 
				vendor_name, '(' || sub_vendor_name || ')', pci_device_name);
		ELSE
			model_name = concat_ws(' ', vendor_name, pci_device_name);
		END IF;
		INSERT INTO component_type (
			company_id,
			model,
			slot_type_id,
			asset_permitted,
			description
		) VALUES (
			CASE WHEN 
				sub_comp_id IS NULL OR
				pci_sub_device_name IS NULL OR
				pci_sub_device_name = 'Device'
			THEN
				comp_id
			ELSE
				sub_comp_id
			END,
			CASE WHEN
				pci_sub_device_name IS NULL OR
				pci_sub_device_name = 'Device'
			THEN
				pci_device_name
			ELSE
				pci_sub_device_name
			END,
			stid,
			'Y',
			model_name
		) RETURNING component_type_id INTO ctid;
		--
		-- Insert properties for the PCI vendor/device IDs
		--
		INSERT INTO component_property (
			component_property_name,
			component_property_type,
			component_type_id,
			property_value
		) VALUES 
			('PCIVendorID', 'PCI', ctid, pci_vendor_id),
			('PCIDeviceID', 'PCI', ctid, pci_device_id);
		
		IF (pci_subsystem_id IS NOT NULL) THEN
			INSERT INTO component_property (
				component_property_name,
				component_property_type,
				component_type_id,
				property_value
			) VALUES 
				('PCISubsystemVendorID', 'PCI', ctid, pci_sub_vendor_id),
				('PCISubsystemID', 'PCI', ctid, pci_subsystem_id);
		END IF;
		--
		-- Insert the component functions
		--

		INSERT INTO component_type_component_func (
			component_type_id,
			component_function
		) SELECT DISTINCT
			ctid,
			cf
		FROM
			unnest(array_append(component_function_list, 'PCI')) x(cf);
	END IF;


	--
	-- We have a component_type_id now, so look to see if this component
	-- serial number already exists
	--
	IF serial_number IS NOT NULL THEN
		SELECT 
			component.* INTO c
		FROM
			component JOIN
			asset a USING (component_id)
		WHERE
			component_type_id = ctid AND
			a.serial_number = sn;

		IF FOUND THEN
			RETURN c;
		END IF;
	END IF;

	INSERT INTO jazzhands.component (
		component_type_id
	) VALUES (
		ctid
	) RETURNING * INTO c;

	IF serial_number IS NOT NULL THEN
		INSERT INTO asset (
			component_id,
			serial_number,
			ownership_status
		) VALUES (
			c.component_id,
			serial_number,
			'unknown'
		);
	END IF;

	RETURN c;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'migrate_component_template_slots');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.migrate_component_template_slots ( component_id integer );
CREATE OR REPLACE FUNCTION component_utils.migrate_component_template_slots(component_id integer)
 RETURNS SETOF jazzhands.slot
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	cid 	ALIAS FOR component_id;
BEGIN
	-- Ensure all of the new slots have appropriate names

	PERFORM component_utils.set_slot_names(
		slot_id_list := ARRAY(
				SELECT s.slot_id FROM slot s WHERE s.component_id = cid
			)
	);

	-- Move everything from the old slot to the new slot if the slot name
	-- and component functions match up, then delete the old slot

	RETURN QUERY
	WITH old_slot AS (
		SELECT
			s.slot_id,
			s.slot_name,
			s.slot_type_id,
			st.slot_function,
			ctst.component_type_slot_tmplt_id
		FROM
			slot s JOIN 
			slot_type st USING (slot_type_id) JOIN
			component c USING (component_id) LEFT JOIN
			component_type_slot_tmplt ctst USING (component_type_slot_tmplt_id)
		WHERE
			s.component_id = cid AND
			ctst.component_type_id IS DISTINCT FROM c.component_type_id
	), new_slot AS (
		SELECT
			s.slot_id,
			s.slot_name,
			s.slot_type_id,
			st.slot_function
		FROM
			slot s JOIN 
			slot_type st USING (slot_type_id) JOIN
			component c USING (component_id) LEFT JOIN
			component_type_slot_tmplt ctst USING (component_type_slot_tmplt_id)
		WHERE
			s.component_id = cid AND
			ctst.component_type_id IS NOT DISTINCT FROM c.component_type_id
	), slot_map AS (
		SELECT
			o.slot_id AS old_slot_id,
			n.slot_id AS new_slot_id
		FROM
			old_slot o JOIN
			new_slot n ON (
				o.slot_name = n.slot_name AND o.slot_function = n.slot_function)
	), slot_1_upd AS (
		UPDATE
			inter_component_connection ic
		SET
			slot1_id = slot_map.new_slot_id
		FROM
			slot_map
		WHERE
			slot1_id = slot_map.old_slot_id
		RETURNING *
	), slot_2_upd AS (
		UPDATE
			inter_component_connection ic
		SET
			slot2_id = slot_map.new_slot_id
		FROM
			slot_map
		WHERE
			slot2_id = slot_map.old_slot_id
		RETURNING *
	), prop_upd AS (
		UPDATE
			component_property cp
		SET
			slot_id = slot_map.new_slot_id
		FROM
			slot_map
		WHERE
			slot_id = slot_map.old_slot_id
		RETURNING *
	), comp_upd AS (
		UPDATE
			component c
		SET
			parent_slot_id = slot_map.new_slot_id
		FROM
			slot_map
		WHERE
			parent_slot_id = slot_map.old_slot_id
		RETURNING *
	), ni_upd AS (
		UPDATE
			network_interface ni
		SET
			slot_id = slot_map.new_slot_id
		FROM
			slot_map
		WHERE
			physical_port_id = slot_map.old_slot_id OR
			slot_id = slot_map.new_slot_id
		RETURNING *
	), delete_migraged_slots AS (
		DELETE FROM
			slot
		WHERE
			slot_id IN (SELECT old_slot_id FROM slot_map)
		RETURNING *
	), delete_empty_slots AS (
		DELETE FROM
			slot s
		WHERE
			slot_id IN (
				SELECT os.slot_id FROM
					old_slot os LEFT JOIN
					component_property cp ON (os.slot_id = cp.slot_id) LEFT JOIN
					network_interface ni ON (
						ni.slot_id = os.slot_id OR
						ni.physical_port_id = os.slot_id) LEFT JOIN
					inter_component_connection ic ON (
						slot1_id = os.slot_id OR
						slot2_id = os.slot_id) LEFT JOIN
					component c ON (c.parent_slot_id = os.slot_id)
				WHERE
					ic.inter_component_connection_id IS NULL AND
					c.component_id IS NULL AND
					ni.network_interface_id IS NULL AND
					cp.component_property_id IS NULL AND
					os.component_type_slot_tmplt_id IS NOT NULL
			)
	) SELECT s.* FROM slot s JOIN slot_map sm ON s.slot_id = sm.new_slot_id;

	RETURN;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'remove_component_hier');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.remove_component_hier ( component_id integer, really_delete boolean );
CREATE OR REPLACE FUNCTION component_utils.remove_component_hier(component_id integer, really_delete boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	slot_list		integer[];
	shelf_list		integer[];
	delete_list		integer[];
	cid				integer;
BEGIN
	cid := component_id;

	SELECT ARRAY(
		SELECT
			slot_id
		FROM
			v_component_hier h JOIN
			slot s ON (h.child_component_id = s.component_id)
		WHERE
			h.component_id = cid)
	INTO slot_list;

	IF really_delete THEN
		SELECT ARRAY(
			SELECT
				child_component_id
			FROM
				v_component_hier h
			WHERE
				h.component_id = cid)
		INTO delete_list;
	ELSE

		SELECT ARRAY(
			SELECT
				child_component_id
			FROM
				v_component_hier h LEFT JOIN
				asset a on (a.component_id = h.child_component_id)
			WHERE
				h.component_id = cid AND
				serial_number IS NOT NULL
		)
		INTO shelf_list;

		SELECT ARRAY(
			SELECT
				child_component_id
			FROM
				v_component_hier h LEFT JOIN
				asset a on (a.component_id = h.child_component_id)
			WHERE
				h.component_id = cid AND
				serial_number IS NULL
		)
		INTO delete_list;

	END IF;

	DELETE FROM
		inter_component_connection
	WHERE
		slot1_id = ANY (slot_list) OR
		slot2_id = ANY (slot_list);

	UPDATE
		component c
	SET
		parent_slot_id = NULL
	WHERE
		c.component_id = ANY (array_cat(delete_list, shelf_list)) AND
		parent_slot_id IS NOT NULL;

	DELETE FROM component_property cp WHERE
		cp.component_id = ANY (delete_list) OR
		slot_id = ANY (slot_list);
		
	DELETE FROM
		slot s
	WHERE
		slot_id = ANY (slot_list) AND
		s.component_id = ANY(delete_list);
		
	DELETE FROM
		component c
	WHERE
		c.component_id = ANY (delete_list);

	RETURN true;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'replace_component');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.replace_component ( old_component_id integer, new_component_id integer );
CREATE OR REPLACE FUNCTION component_utils.replace_component(old_component_id integer, new_component_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	oc	RECORD;
BEGIN
	SELECT
		* INTO oc
	FROM
		component
	WHERE
		component_id = old_component_id;

	UPDATE
		component
	SET
		parent_slot_id = NULL
	WHERE
		component_id = old_component_id;

	UPDATE 
		component
	SET
		parent_slot_id = oc.parent_slot_id
	WHERE
		component_id = new_component_id;

	UPDATE
		device
	SET
		component_id = new_component_id
	WHERE
		component_id = old_component_id;
	
	UPDATE
		physicalish_volume
	SET
		component_id = new_component_id
	WHERE
		component_id = old_component_id;

	RETURN;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'set_slot_names');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.set_slot_names ( slot_id_list integer[] );
CREATE OR REPLACE FUNCTION component_utils.set_slot_names(slot_id_list integer[] DEFAULT NULL::integer[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	slot_rec	RECORD;
	sn			text;
BEGIN
	-- Get a list of all slots that have replacement values

	FOR slot_rec IN
		SELECT 
			s.slot_id,
			COALESCE(pst.child_slot_name_template, st.slot_name_template)
				AS slot_name_template,
			st.slot_index as slot_index,
			pst.slot_index as parent_slot_index,
			pst.child_slot_offset as child_slot_offset
		FROM
			slot s JOIN
			component_type_slot_tmplt st ON (s.component_type_slot_tmplt_id =
				st.component_type_slot_tmplt_id) JOIN
			component c ON (s.component_id = c.component_id) LEFT JOIN
			slot ps ON (c.parent_slot_id = ps.slot_id) LEFT JOIN
			component_type_slot_tmplt pst ON (ps.component_type_slot_tmplt_id =
				pst.component_type_slot_tmplt_id)
		WHERE
			s.slot_id = ANY(slot_id_list) AND
			(
				st.slot_name_template ~ '%{' OR
				pst.child_slot_name_template ~ '%{'
			)
	LOOP
		sn := slot_rec.slot_name_template;
		IF (slot_rec.slot_index IS NOT NULL) THEN
			sn := regexp_replace(sn,
				'%\{slot_index\}', slot_rec.slot_index::text,
				'g');
		END IF;
		IF (slot_rec.parent_slot_index IS NOT NULL) THEN
			sn := regexp_replace(sn,
				'%\{parent_slot_index\}', slot_rec.parent_slot_index::text,
				'g');
		END IF;
		IF (slot_rec.parent_slot_index IS NOT NULL AND
			slot_rec.slot_index IS NOT NULL) THEN
			sn := regexp_replace(sn,
				'%\{relative_slot_index\}', 
				(slot_rec.parent_slot_index + slot_rec.slot_index)::text,
				'g');
		END IF;
		RAISE DEBUG 'Setting name of slot % to %',
			slot_rec.slot_id,
			sn;
		UPDATE slot SET slot_name = sn WHERE slot_id = slot_rec.slot_id;
	END LOOP;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION component_utils.fetch_component(component_type_id integer, serial_number text, no_create boolean DEFAULT false, ownership_status text DEFAULT 'unknown'::text, parent_slot_id integer DEFAULT NULL::integer)
 RETURNS jazzhands.component
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	ctid		ALIAS FOR component_type_id;
	sn			ALIAS FOR serial_number;
	psid		ALIAS FOR parent_slot_id;
	os			ALIAS FOR ownership_status;
	c			RECORD;
	cid			integer;
BEGIN
	cid := NULL;

	IF sn IS NOT NULL THEN
		SELECT 
			comp.* INTO c
		FROM
			component comp JOIN
			asset a USING (component_id)
		WHERE
			comp.component_type_id = ctid AND
			a.serial_number = sn;

		IF FOUND THEN
			--
			-- Only update the parent slot if it isn't set already
			--
			IF c.parent_slot_id IS NULL THEN
				UPDATE
					component comp
				SET
					parent_slot_id = psid
				WHERE
					comp.component_id = c.component_id;
			END IF;
			RETURN c;
		END IF;
	END IF;

	IF no_create THEN
		RETURN NULL;
	END IF;

	INSERT INTO jazzhands.component (
		component_type_id,
		parent_slot_id
	) VALUES (
		ctid,
		parent_slot_id
	) RETURNING * INTO c;

	IF serial_number IS NOT NULL THEN
		INSERT INTO asset (
			component_id,
			serial_number,
			ownership_status
		) VALUES (
			c.component_id,
			serial_number,
			os
		);
	END IF;

	RETURN c;
END;
$function$
;

--
-- Process drops in snapshot_manip
--
--
-- Process drops in lv_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('lv_manip', 'delete_lv');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.delete_lv ( logical_volume_id integer, purge_orphans boolean );
CREATE OR REPLACE FUNCTION lv_manip.delete_lv(logical_volume_id integer, purge_orphans boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	PERFORM lv_manip.delete_lv(
		logical_volume_list := ARRAY [ logical_volume_id ],
		purge_orphans := purge_orphans
	);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('lv_manip', 'delete_lv');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.delete_lv ( logical_volume_list integer[], purge_orphans boolean );
CREATE OR REPLACE FUNCTION lv_manip.delete_lv(logical_volume_list integer[], purge_orphans boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	PERFORM lv_manip.delete_pv(
		physicalish_volume_list := (
			SELECT ARRAY (SELECT
				physicalish_volume_id
			FROM
				physicalish_volume pv
			WHERE
				pv.logical_volume_id = ANY(logical_volume_list)
		)),
		purge_orphans := purge_orphans
	);

	DELETE FROM
		logical_volume_property lvp
	WHERE
		lvp.logical_volume_id = ANY(logical_volume_list);
	
	DELETE FROM
		logical_volume_purpose lvp
	WHERE
		lvp.logical_volume_id = ANY(logical_volume_list);
	
	DELETE FROM
		logical_volume lv
	WHERE
		lv.logical_volume_id = ANY(logical_volume_list);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('lv_manip', 'delete_lv_hier');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.delete_lv_hier ( INOUT physicalish_volume_list integer[], INOUT volume_group_list integer[], INOUT logical_volume_list integer[] );
CREATE OR REPLACE FUNCTION lv_manip.delete_lv_hier(INOUT physicalish_volume_list integer[] DEFAULT NULL::integer[], INOUT volume_group_list integer[] DEFAULT NULL::integer[], INOUT logical_volume_list integer[] DEFAULT NULL::integer[])
 RETURNS record
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	pv_list	integer[];
	vg_list	integer[];
	lv_list	integer[];
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_pv_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN physicalish_volume_list IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = ANY (physicalish_volume_list)
			END OR
			CASE WHEN volume_group_list  IS NULL
				THEN false
				ELSE lh.volume_group_id = ANY (volume_group_list)
			END OR
			CASE WHEN logical_volume_list IS NULL
				THEN false
				ELSE lh.logical_volume_id = ANY (logical_volume_list)
			END)
			AND child_pv_id IS NOT NULL
	) INTO pv_list;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_vg_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pv_list IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = ANY (physicalish_volume_list)
			END OR
			CASE WHEN vg_list IS NULL
				THEN false
				ELSE lh.volume_group_id = ANY (volume_group_list)
			END OR
			CASE WHEN lv_list IS NULL
				THEN false
				ELSE lh.logical_volume_id = ANY (logical_volume_list)
			END)
			AND child_vg_id IS NOT NULL
	) INTO vg_list;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_lv_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pv_list IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = ANY (physicalish_volume_list)
			END OR
			CASE WHEN vg_list IS NULL
				THEN false
				ELSE lh.volume_group_id = ANY (volume_group_list)
			END OR
			CASE WHEN lv_list IS NULL
				THEN false
				ELSE lh.logical_volume_id = ANY (logical_volume_list)
			END)
			AND child_lv_id IS NOT NULL
	) INTO lv_list;

	DELETE FROM logical_volume_property WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume_purpose WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM volume_group_physicalish_vol WHERE physicalish_volume_id = ANY(pv_list);
	DELETE FROM volume_group_physicalish_vol WHERE volume_group_id = ANY(vg_list);
	DELETE FROM volume_group WHERE volume_group_id = ANY(vg_list);
	DELETE FROM physicalish_volume WHERE physicalish_volume_id = ANY(pv_list);

	physicalish_volume_list := pv_list;
	volume_group_list := vg_list;
	logical_volume_list := lv_list;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('lv_manip', 'delete_lv_hier');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.delete_lv_hier ( physicalish_volume_id integer, volume_group_id integer, logical_volume_id integer, OUT pv_list integer[], OUT vg_list integer[], OUT lv_list integer[] );
CREATE OR REPLACE FUNCTION lv_manip.delete_lv_hier(physicalish_volume_id integer DEFAULT NULL::integer, volume_group_id integer DEFAULT NULL::integer, logical_volume_id integer DEFAULT NULL::integer, OUT pv_list integer[], OUT vg_list integer[], OUT lv_list integer[])
 RETURNS record
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	pvid ALIAS FOR physicalish_volume_id;
	vgid ALIAS FOR volume_group_id;
	lvid ALIAS FOR logical_volume_id;
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_pv_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = pvid
			END OR
			CASE WHEN vgid IS NULL
				THEN false
				ELSE lh.volume_group_id = vgid
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = lvid
			END)
			AND child_pv_id IS NOT NULL
	) INTO pv_list;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_vg_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = pvid
			END OR
			CASE WHEN vgid IS NULL
				THEN false
				ELSE lh.volume_group_id = vgid
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = lvid
			END)
			AND child_vg_id IS NOT NULL
	) INTO vg_list;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_lv_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = pvid
			END OR
			CASE WHEN vgid IS NULL
				THEN false
				ELSE lh.volume_group_id = vgid
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = lvid
			END)
			AND child_lv_id IS NOT NULL
	) INTO lv_list;

	DELETE FROM logical_volume_property WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume_purpose WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM volume_group_purpose WHERE volume_group_id = ANY(vg_list);
	DELETE FROM volume_group WHERE volume_group_id = ANY(vg_list);
	DELETE FROM physicalish_volume WHERE physicalish_volume_id = ANY(pv_list);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('lv_manip', 'delete_pv');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.delete_pv ( physicalish_volume_list integer[], purge_orphans boolean );
CREATE OR REPLACE FUNCTION lv_manip.delete_pv(physicalish_volume_list integer[], purge_orphans boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	pvid integer;
	vgid integer;
BEGIN
	PERFORM * FROM lv_manip.remove_pv_membership(
		physicalish_volume_list,
		purge_orphans
	);

	DELETE FROM physicalish_volume WHERE
		physicalish_volume_id = ANY(physicalish_volume_list);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('lv_manip', 'delete_vg');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.delete_vg ( volume_group_id integer, purge_orphans boolean );
CREATE OR REPLACE FUNCTION lv_manip.delete_vg(volume_group_id integer, purge_orphans boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	lvids	integer[];
BEGIN
	PERFORM lv_manip.delete_vg(
		volume_group_list := ARRAY [ volume_group_id ],
		purge_orphans := purge_orphans
	);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('lv_manip', 'delete_vg');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.delete_vg ( volume_group_list integer[], purge_orphans boolean );
CREATE OR REPLACE FUNCTION lv_manip.delete_vg(volume_group_list integer[], purge_orphans boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	lvids	integer[];
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	SELECT ARRAY(
		SELECT
			logical_volume_id
		FROM
			logical_volume lv
		WHERE
			lv.volume_group_id = ANY(volume_group_list)
	) INTO lvids;

	PERFORM lv_manip.delete_pv(
		physicalish_volume_list := (
			SELECT ARRAY (SELECT
				physicalish_volume_id
			FROM
				physicalish_volume
			WHERE
				logical_volume_id = ANY(lvids)
		)),
		purge_orphans := purge_orphans
	);

	DELETE FROM
		volume_group_physicalish_vol vgpv
	WHERE
		vgpv.volume_group_id = ANY(volume_group_list);
	
	DELETE FROM
		volume_group_purpose vgp
	WHERE
		vgp.volume_group_id = ANY(volume_group_list);

	DELETE FROM
		logical_volume_property
	WHERE
		logical_volume_id = ANY(lvids);

	DELETE FROM
		logical_volume_purpose
	WHERE
		logical_volume_id = ANY(lvids);
	
	DELETE FROM
		logical_volume
	WHERE
		logical_volume_id = ANY(lvids);
	
	DELETE FROM
		volume_group vg
	WHERE
		vg.volume_group_id = ANY(volume_group_list);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('lv_manip', 'remove_pv_membership');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.remove_pv_membership ( physicalish_volume_list integer[], purge_orphans boolean );
CREATE OR REPLACE FUNCTION lv_manip.remove_pv_membership(physicalish_volume_list integer[], purge_orphans boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	pvid integer;
	vgid integer;
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	FOREACH pvid IN ARRAY physicalish_volume_list LOOP
		DELETE FROM 
			volume_group_physicalish_vol vgpv
		WHERE
			vgpv.physicalish_volume_id = pvid
		RETURNING
			volume_group_id INTO vgid;
		
		IF FOUND AND purge_orphans THEN
			PERFORM * FROM
				volume_group_physicalish_vol vgpv
			WHERE
				volume_group_id = vgid;

			IF NOT FOUND THEN
				PERFORM lv_manip.delete_vg(
					volume_group_id := vgid,
					purge_orphans := purge_orphans
				);
			END IF;
		END IF;

	END LOOP;
END;
$function$
;

--
-- Process drops in logical_port_manip
--
--
-- Process drops in approval_utils
--
--
-- Process drops in rack_utils
--
--
-- Process drops in pgcrypto
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
-- Process drops in jazzhands_legacy
--
-- New function
CREATE OR REPLACE FUNCTION jazzhands_legacy.insert_person_image_into_base_schema(new jazzhands_legacy.person_image)
 RETURNS jazzhands_legacy.person_image
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	INSERT INTO jazzhands.person_image(
		person_image_id,
		person_id,
		person_image_order,
		image_type,
		image_blob,
		image_checksum,
		image_label,
		description
	) VALUES (
		concat(NEW.person_image_id, nextval('jazzhands.person_image_person_image_id_seq'))::integer,
		NEW.person_id,
		NEW.person_image_order,
		NEW.image_type,
		NEW.image_blob,
		NEW.image_checksum,
		NEW.image_label,
		NEW.description
	) RETURNING * INTO NEW;
	RETURN NEW;
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
SELECT schema_support.synchronize_cache_tables();


-- BEGIN Misc that does not apply to above


DO $$ BEGIN CREATE UNIQUE INDEX uq_appaal_name ON jazzhands.appaal USING btree (appaal_name); EXCEPTION WHEN duplicate_table THEN NULL;  END; $$;
DO $$ BEGIN CREATE INDEX xif2shared_netblock ON jazzhands.shared_netblock USING btree (netblock_id); EXCEPTION WHEN duplicate_table THEN NULL; END; $$;
DO $$ BEGIN CREATE INDEX xif_asset_comp_id ON jazzhands.asset USING btree (component_id); EXCEPTION WHEN duplicate_table THEN NULL; END; $$;
DO $$ BEGIN CREATE INDEX xif_component_prnt_slt_id ON jazzhands.component USING btree (parent_slot_id); EXCEPTION WHEN duplicate_table THEN NULL; END; $$;
DO $$ BEGIN CREATE INDEX xif_intercomp_conn_slot1_id ON jazzhands.inter_component_connection USING btree (slot1_id); EXCEPTION WHEN duplicate_table THEN NULL; END; $$;
DO $$ BEGIN CREATE INDEX xif_intercomp_conn_slot2_id ON jazzhands.inter_component_connection USING btree (slot2_id); EXCEPTION WHEN duplicate_table THEN NULL; END; $$;
DO $$ BEGIN CREATE INDEX xif_layer3_network_netblock_id ON jazzhands.layer3_network USING btree (netblock_id); EXCEPTION WHEN duplicate_table THEN NULL; END; $$;
DO $$ BEGIN CREATE UNIQUE INDEX xifunixgrp_uclass_id ON jazzhands.unix_group USING btree (account_collection_id); EXCEPTION WHEN duplicate_table THEN NULL; END; $$;
DO $$ BEGIN CREATE INDEX xif12network_interface ON jazzhands.network_interface USING btree (logical_port_id, device_id); EXCEPTION WHEN duplicate_table THEN NULL; END; $$;
DO $$ BEGIN CREATE INDEX xif3approval_process_chain ON jazzhands.approval_process_chain USING btree (accept_app_process_chain_id); EXCEPTION WHEN duplicate_table THEN NULL; END; $$;
DO $$ BEGIN CREATE UNIQUE INDEX xif5department ON jazzhands.department USING btree (account_collection_id); EXCEPTION WHEN duplicate_table THEN NULL; END; $$;
DO $$ BEGIN CREATE INDEX xif_chasloc_chass_devid ON jazzhands.device USING btree (chassis_location_id); EXCEPTION WHEN duplicate_table THEN NULL; END; $$;
DO $$ BEGIN CREATE INDEX xif_dev_devtp_id ON jazzhands.device USING btree (device_type_id); EXCEPTION WHEN duplicate_table THEN NULL; END; $$;
DO $$ BEGIN CREATE UNIQUE INDEX xif_netint_nb_netint_id ON jazzhands.network_interface_netblock USING btree (netblock_id); EXCEPTION WHEN duplicate_table THEN NULL; END; $$;

--
-- fix the above pk/fk indexes
--
SELECT schema_support.rebuild_audit_table(
        tbl_schema := 'jazzhands',
        aud_schema := 'audit',
        table_name := tbl
) FROM (SELECT unnest(ARRAY[
        'appaal',
        'asset',
        'component',
        'inter_component_connection',
        'inter_component_connection',
        'layer3_network',
        'shared_netblock',
        'unix_group'
]) as tbl) x
;

DROP TRIGGER IF EXISTS trigger_ins_person_image on jazzhands_legacy.person_image;
CREATE TRIGGER trigger_ins_person_image
INSTEAD OF INSERT
    ON jazzhands_legacy.person_image
    FOR EACH ROW
    EXECUTE PROCEDURE ins_person_image();


-- END Misc that does not apply to above
--
-- BEGIN: process_ancillary_schema(jazzhands_legacy)
--
-- New function
CREATE OR REPLACE FUNCTION jazzhands_legacy.insert_person_image_into_base_schema(new jazzhands_legacy.person_image)
 RETURNS jazzhands_legacy.person_image
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	INSERT INTO jazzhands.person_image(
		person_image_id,
		person_id,
		person_image_order,
		image_type,
		image_blob,
		image_checksum,
		image_label,
		description
	) VALUES (
		concat(NEW.person_image_id, nextval('jazzhands.person_image_person_image_id_seq'))::integer,
		NEW.person_id,
		NEW.person_image_order,
		NEW.image_type,
		NEW.image_blob,
		NEW.image_checksum,
		NEW.image_label,
		NEW.description
	) RETURNING * INTO NEW;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands_legacy.insert_person_image_into_base_schema(new jazzhands_legacy.person_image)
 RETURNS jazzhands_legacy.person_image
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	INSERT INTO jazzhands.person_image(
		person_image_id,
		person_id,
		person_image_order,
		image_type,
		image_blob,
		image_checksum,
		image_label,
		description
	) VALUES (
		concat(NEW.person_image_id, nextval('jazzhands.person_image_person_image_id_seq'))::integer,
		NEW.person_id,
		NEW.person_image_order,
		NEW.image_type,
		NEW.image_blob,
		NEW.image_checksum,
		NEW.image_label,
		NEW.description
	) RETURNING * INTO NEW;
	RETURN NEW;
END;
$function$
;

-- DONE: process_ancillary_schema(jazzhands_legacy)
GRANT select on all tables in schema jazzhands to ro_role;
GRANT insert,update,delete on all tables in schema jazzhands to iud_role;
GRANT select on all sequences in schema jazzhands to ro_role;
GRANT usage on all sequences in schema jazzhands to iud_role;
GRANT select on all tables in schema audit to ro_role;
GRANT select on all sequences in schema audit to ro_role;
SELECT schema_support.end_maintenance();
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
--
-- DONE: Fix cache table entries.
--
select timeofday(), now();
