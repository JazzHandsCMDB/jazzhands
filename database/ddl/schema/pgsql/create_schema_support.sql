/*
 * Copyright (c) 2010-2023 Todd Kover, Matthew Ragan
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
 * Copyright (c) 2010-2021 Matthew Ragan
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

-------------------------------------------------------------------
--
-- Reset sequence to the greater of one more than the maximum value or
-- the current nextval of the sequence.  Sets to 1 if the table
-- is empty.  Set lowerseq to false to cause the sequence to be left
-- alone if it would decrement it.
--
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION schema_support.reset_table_sequence
    ( schema VARCHAR, table_name VARCHAR, lowerseq BOOLEAN DEFAULT true )
RETURNS VOID AS $$
DECLARE
	_r	RECORD;
	m	BIGINT;
BEGIN
	FOR _r IN
		SELECT attname AS column, seq_namespace, seq_name,
			nextval(concat_ws('.', quote_ident(seq_namespace), quote_ident(seq_name))) AS nv
		FROM
			pg_attribute a
			JOIN pg_class c ON c.oid = a.attrelid
			JOIN pg_namespace n ON n.oid = c.relnamespace
			INNER JOIN (
				SELECT
					refobjid AS attrelid, refobjsubid AS attnum,
					c.oid AS seq_id, c.relname AS seq_name,
					n.oid AS seq_nspid, n.nspname AS seq_namespace,
					deptype
				FROM
					pg_depend d
					JOIN pg_class c ON c.oid = d.objid
					JOIN pg_namespace n ON n.oid = c.relnamespace
				WHERE c.relkind = 'S'
			) seq USING (attrelid, attnum)
		WHERE nspname = reset_table_sequence.schema
		AND relname = reset_table_sequence.table_name
		AND NOT a.attisdropped
	LOOP
		EXECUTE  format('SELECT coalesce(max(%s), 0)+1 FROM %s.%s',
			quote_ident(_r.column),
			quote_ident(schema),
			quote_ident(table_name)
		) INTO m;

		IF NOT lowerseq AND m < _r.nv  THEN
			m := _r.nv;
		END IF;
		RAISE DEBUG 'resetting to %', m;
		EXECUTE format('ALTER SEQUENCE %s.%s RESTART WITH %s',
			quote_ident(_r.seq_namespace),
			quote_ident(_r.seq_name),
			m
		);
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
			sub TEXT;
			act TEXT;
			appuser TEXT;
			structuser JSONB;
			c JSONB;
	    BEGIN

		c := current_setting('request.jwt.claims', true);

		-- this gets reset later to a more elaborate user. note that the
		-- session user is no longer there.
		appuser := coalesce(
				current_setting('jazzhands.appuser', true),
				current_setting('request.header.x-remote-user', true)
			);
		structuser := coalesce(current_setting('jazzhands.auditaugment',
			true)::jsonb, '{}'::jsonb) ||
			jsonb_build_object('user', current_user);
		IF current_user != session_user THEN
			structuser := structuser || jsonb_build_object('session', session_user);
		ELSE
			structuser := structuser - 'session';
		END IF;

		IF c IS NOT NULL AND c ? 'sub' THEN
			sub := c->'sub';
			structuser := structuser || jsonb_build_object('sub', sub);
		ELSE
			structuser := structuser - 'sub';
		END IF;

		IF c IS NOT NULL AND c ? 'act' AND c->'act' ? 'sub' THEN
			act := c->'act'->'sub';
			structuser := structuser || jsonb_build_object('act', act);
		ELSE
			structuser := structuser - 'act';
		END IF;

		IF appuser IS NOT NULL THEN
			structuser := structuser || jsonb_build_object('appuser', appuser);
		ELSE
			structuser := structuser - 'appuser';
		END IF;

		appuser := concat_ws('/',
			session_user,
			CASE WHEN session_user != current_user THEN current_user ELSE NULL END,
			act,
			CASE WHEN sub IS DISTINCT FROM current_user THEN sub ELSE NULL END,
			appuser
		);
		appuser := substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO $ZZ$ || quote_ident(aud_schema)
			|| '.' || quote_ident(table_name) || $ZZ$
		    VALUES ( OLD.*, 'DEL', now(),
			clock_timestamp(), txid_current(), appuser, structuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
			IF OLD != NEW THEN
				INSERT INTO $ZZ$ || quote_ident(aud_schema)
				|| '.' || quote_ident(table_name) || $ZZ$
				VALUES ( NEW.*, 'UPD', now(),
				clock_timestamp(), txid_current(), appuser, structuser );
			END IF;
			RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO $ZZ$ || quote_ident(aud_schema)
			|| '.' || quote_ident(table_name) || $ZZ$
		    VALUES ( NEW.*, 'INS', now(),
			clock_timestamp(), txid_current(), appuser, structuser );
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
	vals	text[];
	i	text;
	_t	text;
BEGIN
	_t := regexp_replace(rpad(quote_ident('__old__t' || table_name), 63), ' *$', '');
	--
	-- get columns - XXX NOTE:  Need to remove columns not in the new
	-- table...
	--
	SELECT	array_agg(quote_ident(a.attname) ORDER BY a.attnum),
		array_agg(quote_ident(a.attname) ORDER BY a.attnum)
	INTO	cols, vals
	FROM	pg_catalog.pg_attribute a
	INNER JOIN pg_catalog.pg_class c on a.attrelid = c.oid
	INNER JOIN pg_catalog.pg_namespace n on n.oid = c.relnamespace
	LEFT JOIN pg_catalog.pg_description d
			on d.objoid = a.attrelid
			and d.objsubid = a.attnum
	WHERE   n.nspname = quote_ident(aud_schema)
	  AND	c.relname = _t
	  AND	a.attnum > 0
	  AND	NOT a.attisdropped
	;

	-- initial population of aud#actor.  This is digusting.
	IF NOT 'aud#actor' = ANY(cols) THEN
		cols := array_append(cols, '"aud#actor"');
		vals := array_append(vals,
			'jsonb_build_object(''user'', regexp_replace("aud#user", ''/.*$'', '''')) || CASE WHEN "aud#user" ~ ''/'' THEN jsonb_build_object(''appuser'', regexp_replace("aud#user", ''^[^/]*'', '''')) ELSE ''{}'' END'
		);
	END IF;


	IF cols IS NULL THEN
		RAISE EXCEPTION 'Unable to get columns from "%.%"',
			quote_ident(aud_schema), _t;
	END IF;

	EXECUTE 'INSERT INTO '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident(table_name) || ' ( '
		|| array_to_string(cols, ',') || ' ) SELECT '
		|| array_to_string(vals, ',') || ' FROM '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident('__old__t' || table_name)
		|| ' ORDER BY '
		|| quote_ident('aud#seq');


	EXECUTE 'DROP TABLE '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident('__old__t' || table_name);

	--
	-- drop audit sequence, in case it was not dropped with table.
	--
	EXECUTE 'DROP SEQUENCE IF EXISTS '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident('_old_s' || table_name || '_seq');

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
	_seq_ns		TEXT;
	_seq_name	TEXT;
	tmpsn	TEXT;
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
	-- get sequence name before renaming table
	--
	-- this is the same as pg_get_serial_sequence but that
	-- can be weird with special charaters, and also makes
	-- the returnvalue ns.table so they're harder to quote.
	SELECT seq_namespace, seq_name INTO _seq_ns, _seq_name
	FROM
		pg_attribute a
		JOIN pg_class c ON c.oid = a.attrelid
		JOIN pg_namespace n ON n.oid = c.relnamespace
		INNER JOIN (
			SELECT
				refobjid AS attrelid, refobjsubid AS attnum,
				c.oid AS seq_id, c.relname AS seq_name,
				n.oid AS seq_nspid, n.nspname AS seq_namespace,
				deptype
			FROM
				pg_depend d
				JOIN pg_class c ON c.oid = d.objid
				JOIN pg_namespace n ON n.oid = c.relnamespace
			WHERE c.relkind = 'S'
		) seq USING (attrelid, attnum)
	WHERE attname = 'aud#seq'
		AND nspname = aud_schema
		AND relname = table_name
		AND NOT a.attisdropped
	ORDER BY a.attnum;

	--
	-- capture sequence number before renaming table
	--
	EXECUTE format('SELECT max("aud#seq") + 1 FROM %s.%s',
		quote_ident(aud_schema), quote_ident(table_name)) INTO seq;

	--
	-- rename table
	--
	EXECUTE 'ALTER TABLE '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident(table_name)
		|| ' RENAME TO '
		|| quote_ident('__old__t' || table_name);

	--
	-- RENAME sequence
	--
	tmpsn := '_old_s' || table_name || '_seq';
	EXECUTE FORMAT('ALTER SEQUENCE %s.%s RENAME TO %s',
		quote_ident(_seq_ns), quote_ident(_seq_name), tmpsn);

	--
	-- create a new audit table
	--
	PERFORM schema_support.build_audit_table(aud_schema,tbl_schema,table_name);

	--
	-- figure out the new sequence name.  This may be some namel length adjusted
	-- name.  Also, it's possible the old sequence was not an identity column and
	-- this one is.
	--

	--
	-- fix sequence primary key to have the correct next value
	--

	-- this is the same as pg_get_serial_sequence but that
	-- can be weird with special charaters, and also makes
	-- the returnvalue ns.table so they're harder to quote.
	SELECT seq_namespace, seq_name INTO _seq_ns, _seq_name
	FROM pg_attribute a
		JOIN pg_class c ON c.oid = a.attrelid
		JOIN pg_namespace n ON n.oid = c.relnamespace
		INNER JOIN (
			SELECT
				refobjid AS attrelid,
				refobjsubid AS attnum,
				c.oid AS seq_id,
				c.relname AS seq_name,
				n.oid AS seq_nspid,
				n.nspname AS seq_namespace,
				deptype
			FROM pg_depend d
				JOIN pg_class c ON c.oid = d.objid
				JOIN pg_namespace n ON n.oid = c.relnamespace
			WHERE c.relkind = 'S'
		) seq USING (attrelid, attnum)
	WHERE attname = 'aud#seq'
		AND nspname = aud_schema
		AND relname = table_name
		AND NOT a.attisdropped
	ORDER BY a.attnum;

	IF seq IS NOT NULL THEN
		EXECUTE format('ALTER SEQUENCE %s.%s RESTART WITH %s',
			quote_ident(_seq_ns), quote_ident(_seq_name), seq);
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
--
-- delete and recreate all but primary key and unique key indexes on audit
-- tables.   This is because foreign keys are not properly handled, but if
-- that support was added, it could be a thing.
--
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_indexes(
	aud_schema VARCHAR, tbl_schema VARCHAR, table_name VARCHAR
)
RETURNS VOID AS $$
DECLARE
	_r	RECORD;
	sch	TEXT;
	name_base	TEXT;
BEGIN
	FOR _r IN
		SELECT c2.relname, pg_get_indexdef(i.indexrelid) as def, con.contype
			FROM pg_catalog.pg_class c
				INNER JOIN pg_namespace n ON relnamespace = n.oid
				INNER JOIN pg_catalog.pg_index i ON c.oid = i.indrelid
				INNER JOIN pg_catalog.pg_class c2 ON i.indexrelid = c2.oid
			LEFT JOIN pg_catalog.pg_constraint con ON
				(con.conrelid = i.indrelid AND con.conindid = i.indexrelid )
			WHERE c.relname =  table_name
			AND	  n.nspname = aud_schema
			AND	(contype IS NULL OR contype NOT IN ('p','u'))
	LOOP
		EXECUTE format('DROP INDEX %s.%s',
		quote_ident(aud_schema), quote_ident(_r.relname));
	END LOOP;

	name_base := quote_ident( table_name );
	-- 17 is length of _aud#timestmp_idx
	-- md5 is just to make the name unique
	IF char_length(name_base) > 64 - 17 THEN
		-- using lpad as a truncate
		name_base := 'aud_' || lpad(md5(table_name), 10) || lpad(table_name, 64 - 19 - 10 );
	END IF;

	EXECUTE 'CREATE INDEX '
		|| quote_ident( name_base || '_aud#timestamp_idx')
		|| ' ON ' || quote_ident(aud_schema) || '.'
		|| quote_ident(table_name) || '("aud#timestamp")';

	EXECUTE 'CREATE INDEX '
		|| quote_ident( name_base || '_aud#realtime_idx')
		|| ' ON ' || quote_ident(aud_schema) || '.'
		|| quote_ident(table_name) || '("aud#realtime")';

	EXECUTE 'CREATE INDEX '
		|| quote_ident( name_base || '_aud#txid_idx')
		|| ' ON ' || quote_ident(aud_schema) || '.'
		|| quote_ident(table_name) || '("aud#txid")';


	PERFORM schema_support.build_audit_table_pkak_indexes(
		aud_schema := aud_schema,
		tbl_schema := tbl_schema,
		table_name := table_name
	);
END;
$$ LANGUAGE plpgsql;

-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION schema_support.rebuild_all_audit_indexes
	( aud_schema varchar, tbl_schema varchar, beverbose boolean DEFAULT false )
RETURNS VOID AS $FUNC$
DECLARE
	table_list RECORD;
	_tags		text[];
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
		IF beverbose THEN
			RAISE NOTICE '>> Processing ancillary indexes on %.%', aud_schema, table_list.table_name;
		END IF;
		PERFORM schema_support.rebuild_audit_indexes(
			aud_schema := aud_schema,
			tbl_schema := tbl_schema,
			table_name := table_list.table_name
		);
	END LOOP;
END;
$FUNC$ LANGUAGE plpgsql;


-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION schema_support.build_audit_table(
	aud_schema VARCHAR, tbl_schema VARCHAR, table_name VARCHAR,
	first_time boolean DEFAULT true
)
RETURNS VOID AS $FUNC$
DECLARE
	seqns	TEXT;
	seqname	TEXT;
BEGIN
	EXECUTE 'CREATE TABLE ' || quote_ident(aud_schema) || '.'
		|| quote_ident(table_name) || ' AS '
		|| 'SELECT *, NULL::char(3) as "aud#action", now() as "aud#timestamp", '
		|| 'clock_timestamp() as "aud#realtime", '
		|| 'txid_current() as "aud#txid", '
		|| 'NULL::varchar(255) AS "aud#user", '
		|| 'NULL::jsonb AS "aud#actor", '
		|| 'NULL::integer AS "aud#seq" '
		|| 'FROM ' || quote_ident(tbl_schema) || '.' || quote_ident(table_name)
		|| ' LIMIT 0';

	EXECUTE format('ALTER TABLE %s.%s ALTER COLUMN "aud#seq" SET NOT NULL',
		quote_ident(aud_schema),
		quote_ident(table_name)
	);

	EXECUTE format('ALTER TABLE %s.%s ADD PRIMARY KEY("aud#seq")',
		quote_ident(aud_schema),
		quote_ident(table_name)
	);

	--
	-- If the table name is too long, then the sequence name will
	-- definitely be too long, so need to rename to a unique name.
	--
	IF char_length(table_name) >= 60 THEN
		seqname := lpad(table_name, 46) || lpad(md5(table_name), 10) || '_seq';
	ELSE
		seqname := table_name || '_seq';
	END IF;

	EXECUTE format('ALTER TABLE %s.%s ALTER COLUMN "aud#seq" ADD GENERATED BY DEFAULT AS IDENTITY ( SEQUENCE NAME %s.%s )',
		quote_ident(aud_schema), quote_ident(table_name), quote_ident(aud_schema), quote_ident(seqname)
	);


	PERFORM schema_support.rebuild_audit_indexes(
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
	_tags		text[];
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
		_tags := ARRAY[concat('rebuild_audit_tables_', aud_schema, '_', table_list.table_name)];
		PERFORM schema_support.save_dependent_objects_for_replay(
			schema := aud_schema::varchar,
			object := table_list.table_name::varchar,
			tags:= _tags);
		PERFORM schema_support.save_grants_for_replay(schema := aud_schema,
			object := table_list.table_name,
			tags := _tags);
		PERFORM schema_support.rebuild_audit_table
			( aud_schema, tbl_schema, table_list.table_name );
		PERFORM schema_support.replay_object_recreates(tags := _tags);
		PERFORM schema_support.replay_saved_grants(tags := _tags);
		END LOOP;

	PERFORM schema_support.rebuild_audit_triggers(aud_schema, tbl_schema);
END;
$FUNC$ LANGUAGE plpgsql;


-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION schema_support.trigger_ins_upd_generic_func()
RETURNS TRIGGER AS $$
DECLARE
    appuser TEXT;
	c JSONB;
	act TEXT;
	sub TEXT;
BEGIN
	c := current_setting('request.jwt.claims', true);

	IF c IS NOT NULL AND c ? 'sub' THEN
		sub := c->'sub';
	END IF;

	IF c IS NOT NULL AND c ? 'act' AND c->'act' ? 'sub' THEN
		act := c->'act'->'sub';
	END IF;

	appuser := concat_ws('/',
		session_user,
		act,
		CASE WHEN session_user != current_user THEN current_user ELSE NULL END,
		CASE WHEN sub IS DISTINCT FROM current_user THEN sub ELSE NULL END,
		coalesce(
			current_setting('jazzhands.appuser', true),
			current_setting('request.header.x-remote-user', true)
		)
	);
	appuser := substr(appuser, 1, 255);

    IF TG_OP = 'INSERT' THEN
		NEW.data_ins_user = appuser;
		NEW.data_ins_date = 'now';
    ELSIF TG_OP = 'UPDATE' AND OLD != NEW THEN
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
$$ LANGUAGE plpgsql SECURITY INVOKER;

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
	shouldbesuper	BOOLEAN		DEFAULT true
)
RETURNS BOOLEAN AS $$
DECLARE
	issuper	boolean;
	_tally	integer;
BEGIN
	IF shouldbesuper THEN
		SELECT rolsuper INTO issuper FROM pg_role where rolname = current_user;
		IF issuper IS false THEN
			PERFORM groname, rolname
			FROM (
				SELECT groname, unnest(grolist) AS oid
				FROM pg_group ) g
			JOIN pg_roles u USING (oid)
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
		FROM pg_roles u
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
$$ LANGUAGE plpgsql SECURITY INVOKER;

--
-- Revokes superuser if its set on the current user
--
CREATE OR REPLACE FUNCTION schema_support.end_maintenance(
	minnumdiff		INTEGER		DEFAULT 0,
	minpercent		INTEGER		DEFAULT 0,
	skipchecks		BOOLEAN		DEFAULT false
) RETURNS BOOLEAN AS $$
DECLARE
	issuper BOOLEAN;
	_r		RECORD;
	doh	boolean DEFAULT false;
	_myrole	TEXT;
	msg TEXT;
BEGIN
	SELECT rolsuper INTO issuper FROM pg_roles where rolname = current_user;
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
				msg := '!!! view changes not within tolerence';
				doh := 1;
			ELSE
				msg := '... View changes within tolerence;  I will allow it';
			END IF;
			RAISE NOTICE '%: (%/% %%) %/% %%', msg,
						minnumdiff, minpercent,
						_r.viewdelta,
						((_r.viewdelta::float / _r.before_views_count ))*100;
		END IF;
		IF _r.funcdelta > 0 THEN
			IF _r.funcdelta  > minnumdiff OR
				(_r.funcdelta / _r.before_func_count )*100 > minpercent
			THEN
				msg := '!!! function changes not within tolerence';
				doh := 1;
			ELSE
				msg := '... Function changes within tolerence; I will allow it';
			END IF;

			RAISE NOTICE '%:  (%/% %%); %/% %%', msg,
						minnumdiff, minpercent,
						_r.funcdelta,
						((_r.funcdelta::float / _r.before_func_count ))*100;
		END IF;
		IF _r.keydelta > 0 THEN
			IF _r.keydelta  > minnumdiff OR
				((_r.keydelta::float / _r.before_key_count ))*100 > minpercent
			THEN
				msg := '!!! fk constraint changes not within tolerence';
				doh := 1;
			ELSE
				msg := '... Function changes within tolerence; I will allow it';
			END IF;
			RAISE NOTICE '%: (%/% %%) %/% %%', msg,
						minnumdiff, minpercent,
						_r.keydelta,
						((_r.keydelta::float / _r.before_key_count ))*100;
		END IF;
	END LOOP;

	IF doh THEN
		RAISE EXCEPTION 'Too many changes, abort!';
	END IF;

	DROP TABLE IF EXISTS __owner_before_stats;
	DROP TABLE IF EXISTS __owner_after_stats;
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
	_myrole		TEXT;
BEGIN
	_schema := schema;
	_object := object;
	if newname IS NULL THEN
		newname := _object;
	END IF;

	PERFORM schema_support.prepare_for_grant_replay();

	BEGIN
		SELECT current_role INTO _myrole;
		SET ROLE = dba;
	EXCEPTION WHEN insufficient_privilege OR invalid_parameter_value THEN
		RAISE NOTICE 'Failed to raise privilege: % (%), crossing fingers', SQLERRM, SQLSTATE;
	END;

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

	IF _myrole IS NOT NULL THEN
		EXECUTE 'SET role = ' || _myrole;
	END IF;
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
	tags		text[] DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
	_r		RECORD;
	_tally	integer;
	_myrole	TEXT;
BEGIN
	 SELECT  count(*)
      INTO  _tally
      FROM  pg_catalog.pg_class
     WHERE  relname = '__regrants'
       AND  relpersistence = 't';

	BEGIN
		SELECT current_role INTO _myrole;
		SET ROLE = dba;
	EXCEPTION WHEN insufficient_privilege OR invalid_parameter_value THEN
		RAISE NOTICE 'Failed to raise privilege: % (%), crossing fingers', SQLERRM, SQLSTATE;
	END;


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

	IF _myrole IS NOT NULL THEN
		EXECUTE 'SET role = ' || _myrole;
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
	_myrole	TEXT;
BEGIN
	path = path || concat(schema, '.', object);
	PERFORM schema_support.prepare_for_object_replay();

	-- implicitly save regrants
	PERFORM schema_support.save_grants_for_replay(schema, object, object, tags);

	-- save any triggers on the view
	PERFORM schema_support.save_trigger_for_replay(schema, object, dropit, tags, path);

	BEGIN
		SELECT current_role INTO _myrole;
		SET ROLE = dba;
	EXCEPTION WHEN insufficient_privilege OR invalid_parameter_value THEN
		RAISE NOTICE 'Failed to raise privilege: % (%), crossing fingers', SQLERRM, SQLSTATE;
	END;

	-- now save the view
	FOR _r in SELECT c.oid, n.nspname, c.relname, 'view',
				coalesce(u.rolname, 'public') as owner,
				pg_get_viewdef(c.oid, true) as viewdef, relkind
		FROM pg_class c
		INNER JOIN pg_namespace n on n.oid = c.relnamespace
		LEFT JOIN pg_roles u on u.oid = c.relowner
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
					quote_ident(schema) || '.' || quote_ident(object) ||
					'.' || quote_ident(_c.colname) ||
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

	IF _myrole IS NOT NULL THEN
		EXECUTE 'SET role = ' || _myrole;
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
	_myrole TEXT;
BEGIN
	RAISE DEBUG 'processing %.%', schema, object;
	path = path || concat(schema, '.', object);
	-- process stored procedures
	BEGIN
		SELECT current_role INTO _myrole;
		SET ROLE = dba;
	EXCEPTION WHEN insufficient_privilege OR invalid_parameter_value THEN
		RAISE NOTICE 'Failed to raise privilege: % (%), crossing fingers', SQLERRM, SQLSTATE;
	END;

	FOR _r in
			SELECT * FROM (
				-- functions that depend on relations
				SELECT  distinct np.nspname::text AS nspname,
					dependent.proname::text AS dep_object,
						n.nspname as base_namespace,
						dependee.typname as base_object
				FROM   pg_depend dep
					INNER join pg_type dependee on dependee.oid = dep.refobjid
					INNER join pg_namespace n on n.oid = dependee.typnamespace
					INNER join pg_proc dependent on dependent.oid = dep.objid
					INNER join pg_namespace np on np.oid = dependent.pronamespace
				UNION ALL
				-- relations that depend on functions
				-- note dependent and depndee are backwards

				SELECT  distinct n.nspname::text, dependee.relname::text,
					np.nspname, dependent.proname::text
				FROM   pg_depend dep
					INNER JOIN pg_rewrite ON dep.objid = pg_rewrite.oid
					INNER JOIN pg_class as dependee
						ON pg_rewrite.ev_class = dependee.oid
					INNER join pg_namespace n on n.oid = dependee.relnamespace
					INNER join pg_proc dependent on dependent.oid = dep.refobjid
					INNER join pg_namespace np on np.oid = dependent.pronamespace
				) x
	WHERE
			base_object = object
			AND base_namespace = schema
	LOOP
		-- RAISE NOTICE '1 dealing with  %.%', _r.nspname, _r.dep_object;
		PERFORM schema_support.save_constraint_for_replay(schema := _r.nspname, object := _r.dep_object, dropit := dropit, tags := tags, path := path);
		PERFORM schema_support.save_dependent_objects_for_replay(_r.nspname, _r.dep_object, dropit, doobjectdeps, tags, path);
		-- which of these to run depends on which side of the union above
		PERFORM schema_support.save_function_for_replay(_r.nspname, _r.dep_object, dropit, tags, path);
		PERFORM schema_support.save_view_for_replay(_r.nspname, _r.dep_object, dropit, tags, path);
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
	IF _myrole IS NOT NULL THEN
		EXECUTE 'SET role = ' || _myrole;
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
	_myrole TEXT;
BEGIN
	path = path || concat(schema, '.', object);
	PERFORM schema_support.prepare_for_object_replay();

	BEGIN
		SELECT current_role INTO _myrole;
		SET ROLE = dba;
	EXCEPTION WHEN insufficient_privilege OR invalid_parameter_value THEN
		RAISE NOTICE 'Failed to raise privilege: % (%), crossing fingers', SQLERRM, SQLSTATE;
	END;

	FOR _r in
		SELECT n.nspname, c.relname, trg.tgname,
				pg_get_triggerdef(trg.oid, true) as def
		FROM pg_trigger trg
			INNER JOIN pg_class c on trg.tgrelid =  c.oid
			INNER JOIN pg_namespace n on n.oid = c.relnamespace
		WHERE n.nspname = schema and c.relname = object
		AND NOT tgisinternal
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

	IF _myrole IS NOT NULL THEN
		EXECUTE 'SET role = ' || _myrole;
	END IF;
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
				array_agg(attname ORDER BY confkey) as cols
			FROM (
				SELECT con.*, a.attname, a.attnum
				FROM
					( SELECT oid, conrelid, conindid, confrelid,
					contype, connamespace,
					condeferrable, condeferred, conname,
					unnest(conkey) as conkey,
					unnest(confkey) as confkey
					FROM pg_constraint
					) con
				JOIN pg_attribute a ON a.attrelid = con.conrelid
					AND a.attnum = con.conkey
				WHERE contype IN ('f','p')
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
	_myrole TEXT;
BEGIN
	path = path || concat(schema, '.', object);
	PERFORM schema_support.prepare_for_object_replay();

	BEGIN
		SELECT current_role INTO _myrole;
		SET ROLE = dba;
	EXCEPTION WHEN insufficient_privilege OR invalid_parameter_value THEN
		RAISE NOTICE 'Failed to raise privilege: % (%), crossing fingers', SQLERRM, SQLSTATE;
	END;


	-- implicitly save regrants
	PERFORM schema_support.save_grants_for_replay(schema, object, object, tags);
	FOR _r IN SELECT n.nspname, p.proname,
				coalesce(u.rolname, 'public') as owner,
				pg_get_functiondef(p.oid) as funcdef,
				pg_get_function_identity_arguments(p.oid) as idargs
		FROM    pg_catalog.pg_proc  p
				INNER JOIN pg_catalog.pg_namespace n on n.oid = p.pronamespace
				INNER JOIN pg_catalog.pg_language l on l.oid = p.prolang
				INNER JOIN pg_catalog.pg_roles u on u.oid = p.proowner
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

	IF _myrole IS NOT NULL THEN
		EXECUTE 'SET role = ' || _myrole;
	END IF;

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
	_myrole TEXT;
BEGIN
	SELECT	count(*)
	  INTO	_tally
	  FROM	pg_catalog.pg_class
	 WHERE	relname = '__recreate'
	   AND	relpersistence = 't';

	SHOW search_path INTO _origsp;

	BEGIN
		SELECT current_role INTO _myrole;
		SET ROLE = dba;
	EXCEPTION WHEN insufficient_privilege OR invalid_parameter_value THEN
		RAISE NOTICE 'Failed to raise privilege: % (%), crossing fingers', SQLERRM, SQLSTATE;
	END;

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

	IF _myrole IS NOT NULL THEN
		EXECUTE 'SET role = ' || _myrole;
	END IF;

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
	tally				integer;
	pks					text[];
	cols				text[];
	q					text;
	val					text;
	x					text;
	_whcl				text;
	_eq					text;
	setstr				text;
	_r					record;
	_c					record;
	_br					record;
	_vals				text[];
	txt_in_audit_ids	text;
	txt_in_txids		text;
	i					integer;
BEGIN
	IF in_txids IS NOT NULL THEN
		FOREACH i IN ARRAY in_txids LOOP
			IF txt_in_txids IS NULL THEN
				txt_in_txids := i;
			ELSE
				txt_in_txids := txt_in_txids || ',' || i;
			END IF;
		END LOOP;
	END IF;

	IF in_audit_ids IS NOT NULL THEN
		FOREACH i IN ARRAY in_audit_ids LOOP
			IF txt_in_audit_ids IS NULL THEN
				txt_in_audit_ids := i;
			ELSE
				txt_in_audit_ids := txt_in_audit_ids || ',' || i;
			END IF;
		END LOOP;
	END IF;

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
		RAISE NOTICE 'xx -> %', txt_in_audit_ids;
		q := q || quote_ident('aud#seq') || ' = ANY (ARRAY[' || txt_in_audit_ids || '])';
	END IF;
	IF in_txids is not NULL THEN
		IF q = '' THEN
			q := q || 'WHERE ';
		ELSE
			q := q || 'AND ';
		END IF;
		RAISE NOTICE 'xx -> %', txt_in_txids;
		q := q || quote_ident('aud#txid') || ' = ANY (ARRAY[' || txt_in_txids || '])';
	END IF;

	RAISE NOTICE 'q-> %', q;

	-- Iterate over all the rows that need to be replayed
	q := 'SELECT * FROM ' || quote_ident(in_audit_schema) || '.' ||
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
	_myrole TEXT;
BEGIN
	BEGIN
		SELECT current_role INTO _myrole;
		SET ROLE = dba;
	EXCEPTION WHEN insufficient_privilege OR invalid_parameter_value THEN
		RAISE NOTICE 'Failed to raise privilege: % (%), crossing fingers', SQLERRM, SQLSTATE;
	END;
	FOR _r IN SELECT n.nspname, p.proname,
				coalesce(u.usename, 'public') as owner,
				pg_get_functiondef(p.oid) as funcdef,
				pg_get_function_identity_arguments(p.oid) as idargs
		FROM    pg_catalog.pg_proc  p
				INNER JOIN pg_catalog.pg_namespace n on n.oid = p.pronamespace
				INNER JOIN pg_catalog.pg_language l on l.oid = p.prolang
				INNER JOIN pg_catalog.pg_roles u on u.oid = p.proowner
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
	IF _myrole IS NOT NULL THEN
		EXECUTE 'SET role = ' || _myrole;
	END IF;
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


CREATE OR REPLACE FUNCTION schema_support.relation_diff(
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
    _tmpschema	TEXT;
BEGIN
	SELECT nspname
		INTO _tmpschema
		FROM pg_namespace
		WHERE oid = pg_my_temp_schema();

	--
	-- validate that both old and new tables exist.  This has support for
	-- temporary tabels on either end, which kind of ignore schema.
	--
	IF old_rel ~ '\.' THEN
		_oldschema := regexp_replace(old_rel, '\..*$', '');
		old_rel := regexp_replace(old_rel, '^[^\.]*\.', '');
	ELSE
		EXECUTE 'SELECT count(*)
			FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
			WHERE nspname = $1 AND relname = $2'
			INTO _t1 USING schema, old_rel;
		IF _t1 = 1 THEN
			_oldschema:= schema;
		ELSE
			EXECUTE 'SELECT count(*)
				FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
				WHERE nspname = $1 AND relname = $2'
				INTO _t1 USING _tmpschema, old_rel;
			IF _t1 = 1 THEN
				_oldschema:= _tmpschema;
			ELSE
				RAISE EXCEPTION 'table %.% does not seem to exist', _oldschema, old_rel;
			END IF;
		END IF;
	END IF;
	IF new_rel ~ '\.' THEN
		_newschema := regexp_replace(new_rel, '\..*$', '');
		new_rel := regexp_replace(new_rel, '^[^\.]*\.', '');
	ELSE
		EXECUTE 'SELECT count(*)
			FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
			WHERE nspname = $1 AND relname = $2'
			INTO _t1 USING schema, new_rel;
		IF _t1 = 1 THEN
			_newschema:= schema;
		ELSE
			EXECUTE 'SELECT count(*)
				FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
				WHERE nspname = $1 AND relname = $2'
				INTO _t1 USING _tmpschema, new_rel;
			IF _t1 = 1 THEN
				_newschema:= _tmpschema;
			ELSE
				RAISE EXCEPTION 'table %.% does not seem to exist', _newschema, new_rel;
			END IF;
		END IF;
	END IF;

	--
	-- at this point, the proper schemas have been figured out.
	--

	RAISE NOTICE '% % % %', _oldschema, old_rel, _newschema, new_rel;

	-- do a simple row count
	EXECUTE format('SELECT count(*) FROM %s.%s', _oldschema, old_rel) INTO _t1;
	EXECUTE format('SELECT count(*) FROM %s.%s', _newschema, new_rel) INTO _t2;

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
-- BEGIN IDENTITY column migration spuport
----------------------------------------------------------------------------
--
-- These functions are used to convert all the default "next serial"
-- functions to generated by default identity columns.
--
--

CREATE OR REPLACE FUNCTION schema_support.migrate_legacy_serial_to_identity (
	schema TEXT,
	relation TEXT
) RETURNS integer AS $$
DECLARE
	_r	RECORD;
	_d	RECORD;
	_s	RECORD;
	_t	INTEGER;
BEGIN
	_t := 0;
	FOR _r IN SELECT attrelid, attname, seq_id, seq_name, deptype
		FROM pg_attribute a
			JOIN pg_class c ON c.oid = a.attrelid
			JOIN pg_namespace n ON n.oid = c.relnamespace
			INNER JOIN (
				SELECT refobjid AS attrelid, refobjsubid AS attnum,
					c.oid AS seq_id, c.relname AS seq_name,
					n.oid AS seq_nspid, n.nspname AS seq_namespace,
					deptype
				FROM
					pg_depend d
					JOIN pg_class c ON c.oid = d.objid
					JOIN pg_namespace n ON n.oid = c.relnamespace
				WHERE	c.relkind = 'S'
					AND deptype = 'a'
			) seq USING (attrelid, attnum)
		WHERE	NOT a.attisdropped
			AND nspname = SCHEMA
			AND relname = relation
		ORDER BY
			a.attnum
	LOOP
		EXECUTE format('SELECT s.*, coalesce(pg_sequence_last_value(''%s.%s''), nextval(''%s.%s''))  as lastval  FROM pg_sequence s WHERE seqrelid = %s',
			quote_ident(schema), quote_ident(_r.seq_name),
			quote_ident(schema), quote_ident(_r.seq_name),
			_r.seq_id
		) INTO _s;

		EXECUTE format('ALTER TABLE %s.%s ALTER COLUMN %s DROP DEFAULT',
			quote_ident(schema),
			quote_ident(relation),
			quote_ident(_r.attname));

		EXECUTE format('ALTER SEQUENCE %s.%s OWNED BY NONE',
			quote_ident(schema),
			quote_ident(_r.seq_name));

		EXECUTE format('DROP SEQUENCE %s.%s;',
			quote_ident(schema),
			quote_ident(_r.seq_name));

		EXECUTE format('ALTER TABLE %s.%s ALTER COLUMN %s ADD GENERATED BY DEFAULT AS IDENTITY ( SEQUENCE NAME %s INCREMENT BY %s RESTART WITH %s )',
			quote_ident(schema),
			quote_ident(relation),
			quote_ident(_r.attname),
			quote_ident(_r.seq_name),
			_s.seqincrement, _s.lastval + 1
		);
		_t := _t + 1;
	END LOOP;
	RETURN _t;
END;
$$ LANGUAGE plpgsql
SECURITY INVOKER;

CREATE OR REPLACE FUNCTION schema_support.migrate_legacy_serials_to_identities (
	tbl_schema TEXT
) RETURNS INTEGER AS $$
DECLARE
	_r		INTEGER;
	_tally	INTEGER;
	table_list	TEXT;
BEGIN

	_tally := 0;
    FOR table_list IN
		SELECT table_name::text FROM information_schema.tables
		WHERE table_type = 'BASE TABLE' AND table_schema = tbl_schema
		ORDER BY table_name
    LOOP
		SELECT schema_support.migrate_legacy_serial_to_identity(tbl_schema, table_list) INTO _r;
		_tally := _tally + _r;
    END LOOP;
	RETURN _tally;
END;
$$ LANGUAGE plpgsql
SECURITY INVOKER;

--
-- to facilitate rollback of identity to serial.  Undoes the above.
--
CREATE OR REPLACE FUNCTION schema_support.migrate_identity_to_legacy_serial (
	schema TEXT,
	relation TEXT
) RETURNS integer AS $$
DECLARE
	_r	RECORD;
	_d	RECORD;
	_s	RECORD;
	_t	INTEGER;
BEGIN
	_t := 0;
	FOR _r IN SELECT attrelid, attname, seq_id, seq_name, deptype
		FROM pg_attribute a
			JOIN pg_class c ON c.oid = a.attrelid
			JOIN pg_namespace n ON n.oid = c.relnamespace
			INNER JOIN (
				SELECT refobjid AS attrelid, refobjsubid AS attnum,
					c.oid AS seq_id, c.relname AS seq_name,
					n.oid AS seq_nspid, n.nspname AS seq_namespace,
					deptype
				FROM
					pg_depend d
					JOIN pg_class c ON c.oid = d.objid
					JOIN pg_namespace n ON n.oid = c.relnamespace
				WHERE	c.relkind = 'S'
					AND deptype = 'i'
			) seq USING (attrelid, attnum)
		WHERE	NOT a.attisdropped
			AND nspname = SCHEMA
			AND relname = relation
		ORDER BY
			a.attnum
	LOOP
		EXECUTE format('SELECT s.*, coalesce(pg_sequence_last_value(''%s.%s''), nextval(''%s.%s''))  as lastval  FROM pg_sequence s WHERE seqrelid = %s',
			quote_ident(schema), quote_ident(_r.seq_name),
			quote_ident(schema), quote_ident(_r.seq_name),
			_r.seq_id
		) INTO _s;

		EXECUTE format('ALTER TABLE %s.%s ALTER COLUMN %s DROP IDENTITY',
			quote_ident(schema),
			quote_ident(relation),
			quote_ident(_r.attname));

		EXECUTE format('CREATE SEQUENCE %s.%s OWNED BY %s.%s.%s INCREMENT BY %s',
			quote_ident(schema),
			quote_ident(_r.seq_name),
			quote_ident(schema),
			quote_ident(relation),
			quote_ident(_r.attname),
			_s.seqincrement
		);

		EXECUTE format('ALTER SEQUENCE %s.%s RESTART WITH %s',
			quote_ident(schema),
			quote_ident(_r.seq_name),
			_s.lastval + 1
		);

		EXECUTE format('ALTER TABLE %s.%s ALTER COLUMN %s SET DEFAULT nextval(%s)',
			quote_ident(schema),
			quote_ident(relation),
			quote_ident(_r.attname),
			quote_literal(concat_ws('.',
				quote_ident(schema),
				quote_ident(_r.seq_name)
			))
		);

		_t := _t + 1;
	END LOOP;
	RETURN _t;
END;
$$ LANGUAGE plpgsql
SECURITY INVOKER;

CREATE OR REPLACE FUNCTION schema_support.migrate_identity_to_legacy_serials (
	tbl_schema TEXT
) RETURNS INTEGER AS $$
DECLARE
	_r		INTEGER;
	_tally	INTEGER;
	table_list	TEXT;
BEGIN

	_tally := 0;
    FOR table_list IN
		SELECT table_name::text FROM information_schema.tables
		WHERE table_type = 'BASE TABLE' AND table_schema = tbl_schema
		ORDER BY table_name
    LOOP
		SELECT schema_support.migrate_identity_to_legacy_serial(tbl_schema, table_list) INTO _r;
		_tally := _tally + _r;
    END LOOP;
	RETURN _tally;
END;
$$ LANGUAGE plpgsql
SECURITY INVOKER;

----------------------------------------------------------------------------
-- END IDENTITY column migration spuport
----------------------------------------------------------------------------

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
	schema TEXT DEFAULT 'jazzhands_legacy',
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
-- name_map may contain a jsonb hash that maps old name to new name.  When
-- there's no key, they are assumed to be the same.  If the value is null, then
-- it will either raise a NOTICE about it not existing (if
-- name_map_exception is false) or raise an exception, if name_map_exception
-- is true (the default).
--
CREATE OR REPLACE FUNCTION schema_support.migrate_grants (
	username			TEXT,
	direction			TEXT,
	old_schema			TEXT,
	new_schema			TEXT,
	name_map			JSONB DEFAULT NULL,
	name_map_exception	BOOLEAN DEFAULT true
) RETURNS TEXT[] AS $$
DECLARE
	_rv			TEXT[];
	_r			RECORD;
	_q			TEXT;
	_newname	TEXT;
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
			r.oid as rid,  e.oid as eid,
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
		LEFT JOIN pg_roles r ON r.oid = (p->>'grantor')::oid
		LEFT JOIN pg_roles e ON e.oid = (p->>'grantee')::oid
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

		_newname := NULL;
		IF name_map IS NOT NULL AND name_map ? _r.name THEN
			IF name_map->>_r.name IS NULL THEN
				If name_map_exception THEN
					RAISE EXCEPTION '% is not available in the new schema', _r.name;
				ELSE
					RAISE NOTICE '% is not available in the new schema', _r.name;
					CONTINUE;
				END IF;
			ELSE
				_newname := name_map->>_r.name;
			END IF;
		ELSE
			_newname := _r.name;
		END IF;

		IF lower(direction) = 'grant' THEN
			_q := concat('GRANT ', _r.privilege_type, _q, ' ON ', new_schema, '.', _newname, ' TO ', _r.grantee);
		ELSIF lower(direction) = 'revoke' THEN
			_q := concat('REVOKE ', _r.privilege_type, _q, ' ON ', old_schema, '.', _newname, ' FROM ', _r.grantee);
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
--
-- schema versioning
--
----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION schema_support.set_schema_version (
	version		TEXT,
	schema		TEXT
) RETURNS void AS $$
DECLARE
	in_version	ALIAS FOR version;
	in_schema	ALIAS FOR schema;
	_sp			TEXT;
BEGIN
	-- Make sure that the tracking table exists
	BEGIN
		PERFORM count(*)
		FROM schema_support.schema_version v
		WHERE v.schema = in_schema;
	EXCEPTION WHEN undefined_table THEN
		CREATE TABLE schema_support.schema_version (
			schema	TEXT,
			version	TEXT,
			CONSTRAINT schema_version_pkey PRIMARY KEY (schema)
		);
	END;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Unknown schema %', in_schema
			USING ERRCODE = 'invalid_schema_name';
	END IF;

	INSERT INTO schema_support.schema_version (
		schema, version
	) VALUES (
		in_schema, in_version
	) ON CONFLICT ON CONSTRAINT schema_version_pkey DO UPDATE
		SET version = in_version
		WHERE schema_version.schema = in_schema
	;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION schema_support.get_schema_version (
	schema			TEXT DEFAULT NULL,
	raise_exception	boolean DEFAULT true
) RETURNS TEXT AS $$
DECLARE
	in_schema	ALIAS FOR schema;
	chk_schema	TEXT;
	_sp			TEXT;
	s_version	TEXT;
BEGIN
	IF in_schema IS NOT NULL THEN
		chk_schema := in_schema;
	ELSE
		SHOW search_path INTO _sp;
		_sp := regexp_replace(_sp, ',.*$', '');
		PERFORM *
		FROM	pg_namespace
		WHERE	nspname = _sp;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'Unable to discern schema to check'
				USING ERRCODE = 'invalid_schema_name';
		END IF;
		chk_schema := _sp;
	END IF;

	BEGIN
		SELECT version
		INTO s_version
		FROM schema_support.schema_version
		WHERE schema_version.schema = chk_schema;
	EXCEPTION WHEN undefined_table THEN
		IF raise_exception THEN
			RAISE EXCEPTION '%', SQLERRM
				USING ERRCODE = SQLSTATE,
				HINT = 'Version has likely not been set';
		END IF;
	END;

	RETURN s_version;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION schema_support.check_schema_version (
	version			TEXT,
	schema			TEXT DEFAULT NULL,
	raise_exception	boolean DEFAULT true
) RETURNS boolean AS $$
DECLARE
	in_schema	ALIAS FOR schema;
	in_version	ALIAS FOR version;
	chk_schema	TEXT;
	s_version	TEXT;
	exist		INTEGER[];
	want		INTEGER[];
	i			INTEGER;
BEGIN
	s_version := schema_support.get_schema_version(
		schema := in_schema,
		raise_exception := raise_exception
	);

	IF s_version IS NULL  THEN
		IF raise_exception THEN
			RAISE EXCEPTION 'Could not find version'
				USING ERRCODE = 'invalid_parameter_value',
				HINT = 'This should not happen';
		END IF;
		RETURN false;
	END IF;

	-- thx http://sqlfiddle.com/#!15/0d32c/2/0 via stackoverflow
	-- doesn't handle text labels super well, but patches welcome
	exist := regexp_split_to_array(regexp_replace(s_version, '[^0-9.]+',
		'', 'g'), '[-:\.]')::int[];
	want := regexp_split_to_array(regexp_replace(in_version, '[^0-9.]+',
		'', 'g'), '[-:\.]')::int[];

	--
	-- NOTE:  this does not (yet) handle software versions well, since it
	-- cosniders :, ., - to all be the same demiter, so they need the
	-- same number of elements.  Don't let the perfect be the enemy of the
	-- good, although I'm sure that sentiment will come back to bite me.
	--

	RETURN exist >= want;
END;
$$
LANGUAGE plpgsql
-- setting a search_path messes with the function, so do not.
SECURITY DEFINER;


--
-- This migrates grants from one schema to another for setting up a shadow
-- schema for dealing with migrations.  It still needs to handle functions.
--
-- It also ignores sequences because those really need to move to IDENTITY
-- columns anyway. and sequences are really part of the shadow schema stuff.
--

REVOKE USAGE ON SCHEMA schema_support FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA schema_support FROM public;

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
considered a bug...  It does not handle unique indexes well.

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
