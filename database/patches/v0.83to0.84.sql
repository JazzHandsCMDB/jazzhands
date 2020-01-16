--
-- Copyright (c) 2019 Todd Kover
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

	--suffix=v84
	--post
	post
	--scan
	device_type_module
	device_type
	--preschema
	schema_support
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance();
select timeofday(), now();
-- BEGIN: process_ancillary_schema(schema_support)
-- =============================================
DO $$
BEGIN
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE cache_table
CREATE TABLE schema_support.cache_table
(
	cache_table_schema	text NOT NULL,
	cache_table	text NOT NULL,
	defining_view_schema	text NOT NULL,
	defining_view	text NOT NULL,
	updates_enabled	boolean NOT NULL
);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE schema_support.cache_table ADD CONSTRAINT cache_table_pkey PRIMARY KEY (cache_table_schema, cache_table);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE cache_table
--------------------------------------------------------------------
EXCEPTION WHEN duplicate_table
	THEN NULL;
END;
$$;

-- =============================================
-- =============================================
DO $$
BEGIN
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE cache_table_update_log
CREATE TABLE schema_support.cache_table_update_log
(
	cache_table_schema	text NOT NULL,
	cache_table	text NOT NULL,
	update_timestamp	timestamp with time zone NOT NULL,
	rows_inserted	integer NOT NULL,
	rows_deleted	integer NOT NULL,
	forced	boolean NOT NULL
);

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE cache_table_update_log
--------------------------------------------------------------------
EXCEPTION WHEN duplicate_table
	THEN NULL;
END;
$$;

-- =============================================
-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'get_common_columns');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.get_common_columns ( _schema text, _table1 text, _table2 text );
CREATE OR REPLACE FUNCTION schema_support.get_common_columns(_schema text, _table1 text, _table2 text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	_q			text;
    cols        text[];
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_table');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_table ( aud_schema character varying, tbl_schema character varying, table_name character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_table(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	idx		text[];
	keys	text[];
	cols	text[];
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
	WHERE  	n.nspname = quote_ident(aud_schema)
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
	WHERE  	n.nspname = quote_ident(aud_schema)
	  AND	c.relname = quote_ident(table_name)
	  AND 	a.attnum > 0
	  AND 	NOT a.attisdropped
	;

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

	EXECUTE 'INSERT INTO '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident(table_name) || ' ( '
		|| array_to_string(cols, ',') || ' ) SELECT '
		|| array_to_string(cols, ',') || ' FROM '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident('__old__' || table_name)
		|| ' ORDER BY '
		|| quote_ident('aud#seq');

	--
	-- fix sequence primary key to have the correct next value
	--
	EXECUTE 'SELECT max("aud#seq") + 1 FROM	 '
			|| quote_ident(aud_schema) || '.'
			|| quote_ident(table_name) INTO seq;
	IF seq IS NOT NULL THEN
		EXECUTE 'ALTER SEQUENCE '
			|| quote_ident(aud_schema) || '.'
			|| quote_ident(table_name || '_seq')
			|| ' RESTART WITH ' || seq;
	END IF;

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


	--
	-- recreate audit trigger
	--
	PERFORM schema_support.rebuild_audit_trigger (
		aud_schema, tbl_schema, table_name );

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
	_cols 	TEXT[];
	_pkcol 	TEXT[];
	_q 		TEXT;
	_f 		TEXT;
	_c 		RECORD;
	_w 		TEXT[];
	_ctl 		TEXT[];
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
		RAISE NOTICE 'table % has % rows; table % has % rows', old_rel, _t1, new_rel, _t2;
		IF _t1 > _t2 THEN
			_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(old_rel)  ||
				' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
					' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
					quote_ident(schema) || '.' || quote_ident(old_rel)  ||
					' EXCEPT ( '
						' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
						quote_ident(schema) || '.' || quote_ident(new_rel)  ||
					' )) ';
		ELSE
			_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(new_rel)  ||
				' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
					' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
					quote_ident(schema) || '.' || quote_ident(new_rel)  ||
					' EXCEPT ( '
						' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
						quote_ident(schema) || '.' || quote_ident(old_rel)  ||
					' )) ';

		END IF;

		FOR _r IN EXECUTE 'SELECT row_to_json(x) as r FROM (' || _q || ') x'
		LOOP
			RAISE NOTICE '%', _r;
		END LOOP;

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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_last_changed');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_last_changed ( relation text, schema text, debug boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_last_changed(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_dependent_objects_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_dependent_objects_for_replay ( schema character varying, object character varying, dropit boolean, doobjectdeps boolean );
CREATE OR REPLACE FUNCTION schema_support.save_dependent_objects_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, doobjectdeps boolean DEFAULT false)
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
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.create_cache_table(cache_table_schema text, cache_table text, defining_view_schema text, defining_view text, force boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	param_cache_table_schema	ALIAS FOR cache_table_schema;
	param_cache_table			ALIAS FOR cache_table;
	param_defining_view_schema	ALIAS FOR defining_view_schema;
	param_defining_view			ALIAS FOR defining_view;
	ct_rec						RECORD;
BEGIN
	--
	-- Ensure that the defining view exists
	--
	PERFORM *
	FROM
		information_schema.views
	WHERE
		table_schema = defining_view_schema AND
		table_name = defining_view;
	
	IF NOT FOUND THEN
		RAISE 'view %.% does not exist',
			defining_view_schema,
			defining_view
			USING ERRCODE = 'foreign_key_violation';
	END IF;

	--
	-- Verify that the cache table does not exist, or if it does that
	-- we have an entry for it in schema_support.cache_table and
	-- force is being passed.
	--

	PERFORM *
	FROM
		information_schema.tables
	WHERE
		table_schema = cache_table_schema AND
		table_name = cache_table;
	
	IF FOUND THEN
		IF NOT force THEN
			RAISE 'cache table %.% already exists',
				cache_table_schema,
				cache_table
				USING ERRCODE = 'unique_violation';
		END IF;

		PERFORM *
		FROM
			schema_support.cache_table ct
		WHERE
			ct.cache_table_schema = param_cache_table_schema AND
			ct.cache_table = param_cache_table;

		IF NOT FOUND THEN
			RAISE '%', concat(
				'cache table ', cache_table_schema, '.', cache_table,
				' already exists, but there is no tracking ',
				'information for it in schema_support.cache_table.  ',
				'This must be corrected manually.')
				USING ERRCODE = 'unique_violation';
		END IF;

		PERFORM schema_support.save_grants_for_replay(
			cache_table_schema, cache_table
		);

		EXECUTE 'DROP TABLE '
			|| quote_ident(cache_table_schema) || '.'
			|| quote_ident(cache_table);
	END IF;

	SELECT * INTO ct_rec
	FROM
		schema_support.cache_table ct
	WHERE
		ct.cache_table_schema = param_cache_table_schema AND
		ct.cache_table = param_cache_table;

	IF NOT FOUND THEN
		INSERT INTO schema_support.cache_table(
			cache_table_schema,
			cache_table,
			defining_view_schema,
			defining_view,
			updates_enabled
		) VALUES (
			param_cache_table_schema,
			param_cache_table,
			param_defining_view_schema,
			param_defining_view,
			'true'
		);
	END IF;

	EXECUTE format('CREATE TABLE %I.%I AS SELECT * FROM %I.%I',
		cache_table_schema,
		cache_table,
		defining_view_schema,
		defining_view
	);
END
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.synchronize_cache_tables(cache_table_schema text DEFAULT NULL::text, cache_table text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	ct_rec			RECORD;
	query			text;
	inserted_rows	integer;
	deleted_rows	integer;
BEGIN
	IF cache_table_schema IS NULL THEN
		IF cache_table IS NOT NULL THEN
			RAISE 'Must specify cache_table_schema if cache_table is passed'
				USING ERRCODE = 'null_value_not_allowed';
		END IF;
		query := '
			SELECT
				*
			FROM
				schema_support.cache_table
			WHERE
				updates_enabled = true
			';
	ELSE
		IF cache_table IS NOT NULL THEN
			query := format($query$
				SELECT
					*
				FROM
					schema_support.cache_table
				WHERE
					quote_ident(cache_table_schema) = '%I' AND
					quote_ident(cache_table) = '%I'
				$query$,
				cache_table_schema,
				cache_table
			);
		ELSE
			query := format($query$
				SELECT
					*
				FROM
					schema_support.cache_table
				WHERE
					quote_ident(cache_table_schema) = '%I' AND
					updates_enabled = true
				$query$,
				cache_table_schema
			);
		END IF;
	END IF;
	FOR ct_rec IN EXECUTE query LOOP
		RAISE DEBUG 'Processing %.%',
			quote_ident(ct_rec.cache_table_schema),
			quote_ident(ct_rec.cache_table);
			
		--
		-- Insert rows that exist in the view that do not exist in the cache
		-- table
		--
		query := format($query$
			INSERT INTO %I.%I
			SELECT * FROM %I.%I z
			WHERE
				(z) IN 
				(
					SELECT (x) FROM 
					(
						SELECT * FROM %I.%I EXCEPT
						SELECT * FROM %I.%I
					) x
				)
			$query$,
			ct_rec.cache_table_schema,
			ct_rec.cache_table,
			ct_rec.defining_view_schema,
			ct_rec.defining_view,
			ct_rec.defining_view_schema,
			ct_rec.defining_view,
			ct_rec.cache_table_schema,
			ct_rec.cache_table
		);
		RAISE DEBUG E'Executing:\n%\n', query;
		EXECUTE query;
		GET DIAGNOSTICS inserted_rows := ROW_COUNT;

		--
		-- Delete rows that exist in the cache table that do not exist in the
		-- defining view
		--
		query := format($query$
			DELETE FROM %I.%I z
			WHERE
				(z) IN 
				(
					SELECT (x) FROM 
					(
						SELECT * FROM %I.%I EXCEPT
						SELECT * FROM %I.%I
					) x
				)
			$query$,
			ct_rec.cache_table_schema,
			ct_rec.cache_table,
			ct_rec.cache_table_schema,
			ct_rec.cache_table,
			ct_rec.defining_view_schema,
			ct_rec.defining_view
		);
		RAISE DEBUG E'Executing:\n%\n', query;
		EXECUTE query;
		GET DIAGNOSTICS deleted_rows := ROW_COUNT;

		IF (inserted_rows > 0 OR deleted_rows > 0) THEN
			INSERT INTO schema_support.cache_table_update_log (
				cache_table_schema,
				cache_table,
				update_timestamp,
				rows_inserted,
				rows_deleted,
				forced
			) VALUES (
				ct_rec.cache_table_schema,
				ct_rec.cache_table,
				current_timestamp,
				inserted_rows,
				deleted_rows,
				false
			);
		END IF;
	END LOOP;
END
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.undo_audit_row(in_table text, in_audit_schema text DEFAULT 'audit'::text, in_schema text DEFAULT 'jazzhands'::text, in_start_time timestamp without time zone DEFAULT NULL::timestamp without time zone, in_end_time timestamp without time zone DEFAULT NULL::timestamp without time zone, in_aud_user text DEFAULT NULL::text, in_audit_ids integer[] DEFAULT NULL::integer[], in_txids bigint[] DEFAULT NULL::bigint[])
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'get_common_columns');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.get_common_columns ( _schema text, _table1 text, _table2 text );
CREATE OR REPLACE FUNCTION schema_support.get_common_columns(_schema text, _table1 text, _table2 text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	_q			text;
    cols        text[];
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_table');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_table ( aud_schema character varying, tbl_schema character varying, table_name character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_table(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	idx		text[];
	keys	text[];
	cols	text[];
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
	WHERE  	n.nspname = quote_ident(aud_schema)
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
	WHERE  	n.nspname = quote_ident(aud_schema)
	  AND	c.relname = quote_ident(table_name)
	  AND 	a.attnum > 0
	  AND 	NOT a.attisdropped
	;

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

	EXECUTE 'INSERT INTO '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident(table_name) || ' ( '
		|| array_to_string(cols, ',') || ' ) SELECT '
		|| array_to_string(cols, ',') || ' FROM '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident('__old__' || table_name)
		|| ' ORDER BY '
		|| quote_ident('aud#seq');

	--
	-- fix sequence primary key to have the correct next value
	--
	EXECUTE 'SELECT max("aud#seq") + 1 FROM	 '
			|| quote_ident(aud_schema) || '.'
			|| quote_ident(table_name) INTO seq;
	IF seq IS NOT NULL THEN
		EXECUTE 'ALTER SEQUENCE '
			|| quote_ident(aud_schema) || '.'
			|| quote_ident(table_name || '_seq')
			|| ' RESTART WITH ' || seq;
	END IF;

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


	--
	-- recreate audit trigger
	--
	PERFORM schema_support.rebuild_audit_trigger (
		aud_schema, tbl_schema, table_name );

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
	_cols 	TEXT[];
	_pkcol 	TEXT[];
	_q 		TEXT;
	_f 		TEXT;
	_c 		RECORD;
	_w 		TEXT[];
	_ctl 		TEXT[];
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
		RAISE NOTICE 'table % has % rows; table % has % rows', old_rel, _t1, new_rel, _t2;
		IF _t1 > _t2 THEN
			_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(old_rel)  ||
				' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
					' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
					quote_ident(schema) || '.' || quote_ident(old_rel)  ||
					' EXCEPT ( '
						' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
						quote_ident(schema) || '.' || quote_ident(new_rel)  ||
					' )) ';
		ELSE
			_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(new_rel)  ||
				' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
					' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
					quote_ident(schema) || '.' || quote_ident(new_rel)  ||
					' EXCEPT ( '
						' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
						quote_ident(schema) || '.' || quote_ident(old_rel)  ||
					' )) ';

		END IF;

		FOR _r IN EXECUTE 'SELECT row_to_json(x) as r FROM (' || _q || ') x'
		LOOP
			RAISE NOTICE '%', _r;
		END LOOP;

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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_last_changed');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_last_changed ( relation text, schema text, debug boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_last_changed(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_dependent_objects_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_dependent_objects_for_replay ( schema character varying, object character varying, dropit boolean, doobjectdeps boolean );
CREATE OR REPLACE FUNCTION schema_support.save_dependent_objects_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, doobjectdeps boolean DEFAULT false)
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
$function$
;

DROP FUNCTION IF EXISTS schema_support.undo_audit_row ( in_table text, in_audit_schema text, in_schema text, in_start_time timestamp without time zone, in_end_time timestamp without time zone, in_aud_user text, in_audit_ids integer[] );
-- New function
CREATE OR REPLACE FUNCTION schema_support.create_cache_table(cache_table_schema text, cache_table text, defining_view_schema text, defining_view text, force boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	param_cache_table_schema	ALIAS FOR cache_table_schema;
	param_cache_table			ALIAS FOR cache_table;
	param_defining_view_schema	ALIAS FOR defining_view_schema;
	param_defining_view			ALIAS FOR defining_view;
	ct_rec						RECORD;
BEGIN
	--
	-- Ensure that the defining view exists
	--
	PERFORM *
	FROM
		information_schema.views
	WHERE
		table_schema = defining_view_schema AND
		table_name = defining_view;
	
	IF NOT FOUND THEN
		RAISE 'view %.% does not exist',
			defining_view_schema,
			defining_view
			USING ERRCODE = 'foreign_key_violation';
	END IF;

	--
	-- Verify that the cache table does not exist, or if it does that
	-- we have an entry for it in schema_support.cache_table and
	-- force is being passed.
	--

	PERFORM *
	FROM
		information_schema.tables
	WHERE
		table_schema = cache_table_schema AND
		table_name = cache_table;
	
	IF FOUND THEN
		IF NOT force THEN
			RAISE 'cache table %.% already exists',
				cache_table_schema,
				cache_table
				USING ERRCODE = 'unique_violation';
		END IF;

		PERFORM *
		FROM
			schema_support.cache_table ct
		WHERE
			ct.cache_table_schema = param_cache_table_schema AND
			ct.cache_table = param_cache_table;

		IF NOT FOUND THEN
			RAISE '%', concat(
				'cache table ', cache_table_schema, '.', cache_table,
				' already exists, but there is no tracking ',
				'information for it in schema_support.cache_table.  ',
				'This must be corrected manually.')
				USING ERRCODE = 'unique_violation';
		END IF;

		PERFORM schema_support.save_grants_for_replay(
			cache_table_schema, cache_table
		);

		EXECUTE 'DROP TABLE '
			|| quote_ident(cache_table_schema) || '.'
			|| quote_ident(cache_table);
	END IF;

	SELECT * INTO ct_rec
	FROM
		schema_support.cache_table ct
	WHERE
		ct.cache_table_schema = param_cache_table_schema AND
		ct.cache_table = param_cache_table;

	IF NOT FOUND THEN
		INSERT INTO schema_support.cache_table(
			cache_table_schema,
			cache_table,
			defining_view_schema,
			defining_view,
			updates_enabled
		) VALUES (
			param_cache_table_schema,
			param_cache_table,
			param_defining_view_schema,
			param_defining_view,
			'true'
		);
	END IF;

	EXECUTE format('CREATE TABLE %I.%I AS SELECT * FROM %I.%I',
		cache_table_schema,
		cache_table,
		defining_view_schema,
		defining_view
	);
END
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.synchronize_cache_tables(cache_table_schema text DEFAULT NULL::text, cache_table text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	ct_rec			RECORD;
	query			text;
	inserted_rows	integer;
	deleted_rows	integer;
BEGIN
	IF cache_table_schema IS NULL THEN
		IF cache_table IS NOT NULL THEN
			RAISE 'Must specify cache_table_schema if cache_table is passed'
				USING ERRCODE = 'null_value_not_allowed';
		END IF;
		query := '
			SELECT
				*
			FROM
				schema_support.cache_table
			WHERE
				updates_enabled = true
			';
	ELSE
		IF cache_table IS NOT NULL THEN
			query := format($query$
				SELECT
					*
				FROM
					schema_support.cache_table
				WHERE
					quote_ident(cache_table_schema) = '%I' AND
					quote_ident(cache_table) = '%I'
				$query$,
				cache_table_schema,
				cache_table
			);
		ELSE
			query := format($query$
				SELECT
					*
				FROM
					schema_support.cache_table
				WHERE
					quote_ident(cache_table_schema) = '%I' AND
					updates_enabled = true
				$query$,
				cache_table_schema
			);
		END IF;
	END IF;
	FOR ct_rec IN EXECUTE query LOOP
		RAISE DEBUG 'Processing %.%',
			quote_ident(ct_rec.cache_table_schema),
			quote_ident(ct_rec.cache_table);
			
		--
		-- Insert rows that exist in the view that do not exist in the cache
		-- table
		--
		query := format($query$
			INSERT INTO %I.%I
			SELECT * FROM %I.%I z
			WHERE
				(z) IN 
				(
					SELECT (x) FROM 
					(
						SELECT * FROM %I.%I EXCEPT
						SELECT * FROM %I.%I
					) x
				)
			$query$,
			ct_rec.cache_table_schema,
			ct_rec.cache_table,
			ct_rec.defining_view_schema,
			ct_rec.defining_view,
			ct_rec.defining_view_schema,
			ct_rec.defining_view,
			ct_rec.cache_table_schema,
			ct_rec.cache_table
		);
		RAISE DEBUG E'Executing:\n%\n', query;
		EXECUTE query;
		GET DIAGNOSTICS inserted_rows := ROW_COUNT;

		--
		-- Delete rows that exist in the cache table that do not exist in the
		-- defining view
		--
		query := format($query$
			DELETE FROM %I.%I z
			WHERE
				(z) IN 
				(
					SELECT (x) FROM 
					(
						SELECT * FROM %I.%I EXCEPT
						SELECT * FROM %I.%I
					) x
				)
			$query$,
			ct_rec.cache_table_schema,
			ct_rec.cache_table,
			ct_rec.cache_table_schema,
			ct_rec.cache_table,
			ct_rec.defining_view_schema,
			ct_rec.defining_view
		);
		RAISE DEBUG E'Executing:\n%\n', query;
		EXECUTE query;
		GET DIAGNOSTICS deleted_rows := ROW_COUNT;

		IF (inserted_rows > 0 OR deleted_rows > 0) THEN
			INSERT INTO schema_support.cache_table_update_log (
				cache_table_schema,
				cache_table,
				update_timestamp,
				rows_inserted,
				rows_deleted,
				forced
			) VALUES (
				ct_rec.cache_table_schema,
				ct_rec.cache_table,
				current_timestamp,
				inserted_rows,
				deleted_rows,
				false
			);
		END IF;
	END LOOP;
END
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.undo_audit_row(in_table text, in_audit_schema text DEFAULT 'audit'::text, in_schema text DEFAULT 'jazzhands'::text, in_start_time timestamp without time zone DEFAULT NULL::timestamp without time zone, in_end_time timestamp without time zone DEFAULT NULL::timestamp without time zone, in_aud_user text DEFAULT NULL::text, in_audit_ids integer[] DEFAULT NULL::integer[], in_txids bigint[] DEFAULT NULL::bigint[])
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
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
	where nspname = 'jazzhands_cache';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS jazzhands_cache;
		CREATE SCHEMA jazzhands_cache AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA jazzhands_cache IS 'part of jazzhands';
	END IF;
END;
			$$;--
-- Process pre-schema schema_support
--
-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'get_common_columns');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.get_common_columns ( _schema text, _table1 text, _table2 text );
CREATE OR REPLACE FUNCTION schema_support.get_common_columns(_schema text, _table1 text, _table2 text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	_q			text;
    cols        text[];
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_table');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_table ( aud_schema character varying, tbl_schema character varying, table_name character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_table(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	idx		text[];
	keys	text[];
	cols	text[];
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
	WHERE  	n.nspname = quote_ident(aud_schema)
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
	WHERE  	n.nspname = quote_ident(aud_schema)
	  AND	c.relname = quote_ident(table_name)
	  AND 	a.attnum > 0
	  AND 	NOT a.attisdropped
	;

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

	EXECUTE 'INSERT INTO '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident(table_name) || ' ( '
		|| array_to_string(cols, ',') || ' ) SELECT '
		|| array_to_string(cols, ',') || ' FROM '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident('__old__' || table_name)
		|| ' ORDER BY '
		|| quote_ident('aud#seq');

	--
	-- fix sequence primary key to have the correct next value
	--
	EXECUTE 'SELECT max("aud#seq") + 1 FROM	 '
			|| quote_ident(aud_schema) || '.'
			|| quote_ident(table_name) INTO seq;
	IF seq IS NOT NULL THEN
		EXECUTE 'ALTER SEQUENCE '
			|| quote_ident(aud_schema) || '.'
			|| quote_ident(table_name || '_seq')
			|| ' RESTART WITH ' || seq;
	END IF;

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


	--
	-- recreate audit trigger
	--
	PERFORM schema_support.rebuild_audit_trigger (
		aud_schema, tbl_schema, table_name );

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
	_cols 	TEXT[];
	_pkcol 	TEXT[];
	_q 		TEXT;
	_f 		TEXT;
	_c 		RECORD;
	_w 		TEXT[];
	_ctl 		TEXT[];
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
		RAISE NOTICE 'table % has % rows; table % has % rows', old_rel, _t1, new_rel, _t2;
		IF _t1 > _t2 THEN
			_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(old_rel)  ||
				' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
					' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
					quote_ident(schema) || '.' || quote_ident(old_rel)  ||
					' EXCEPT ( '
						' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
						quote_ident(schema) || '.' || quote_ident(new_rel)  ||
					' )) ';
		ELSE
			_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(new_rel)  ||
				' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
					' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
					quote_ident(schema) || '.' || quote_ident(new_rel)  ||
					' EXCEPT ( '
						' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
						quote_ident(schema) || '.' || quote_ident(old_rel)  ||
					' )) ';

		END IF;

		FOR _r IN EXECUTE 'SELECT row_to_json(x) as r FROM (' || _q || ') x'
		LOOP
			RAISE NOTICE '%', _r;
		END LOOP;

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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_last_changed');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_last_changed ( relation text, schema text, debug boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_last_changed(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_dependent_objects_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_dependent_objects_for_replay ( schema character varying, object character varying, dropit boolean, doobjectdeps boolean );
CREATE OR REPLACE FUNCTION schema_support.save_dependent_objects_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, doobjectdeps boolean DEFAULT false)
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
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.create_cache_table(cache_table_schema text, cache_table text, defining_view_schema text, defining_view text, force boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	param_cache_table_schema	ALIAS FOR cache_table_schema;
	param_cache_table			ALIAS FOR cache_table;
	param_defining_view_schema	ALIAS FOR defining_view_schema;
	param_defining_view			ALIAS FOR defining_view;
	ct_rec						RECORD;
BEGIN
	--
	-- Ensure that the defining view exists
	--
	PERFORM *
	FROM
		information_schema.views
	WHERE
		table_schema = defining_view_schema AND
		table_name = defining_view;
	
	IF NOT FOUND THEN
		RAISE 'view %.% does not exist',
			defining_view_schema,
			defining_view
			USING ERRCODE = 'foreign_key_violation';
	END IF;

	--
	-- Verify that the cache table does not exist, or if it does that
	-- we have an entry for it in schema_support.cache_table and
	-- force is being passed.
	--

	PERFORM *
	FROM
		information_schema.tables
	WHERE
		table_schema = cache_table_schema AND
		table_name = cache_table;
	
	IF FOUND THEN
		IF NOT force THEN
			RAISE 'cache table %.% already exists',
				cache_table_schema,
				cache_table
				USING ERRCODE = 'unique_violation';
		END IF;

		PERFORM *
		FROM
			schema_support.cache_table ct
		WHERE
			ct.cache_table_schema = param_cache_table_schema AND
			ct.cache_table = param_cache_table;

		IF NOT FOUND THEN
			RAISE '%', concat(
				'cache table ', cache_table_schema, '.', cache_table,
				' already exists, but there is no tracking ',
				'information for it in schema_support.cache_table.  ',
				'This must be corrected manually.')
				USING ERRCODE = 'unique_violation';
		END IF;

		PERFORM schema_support.save_grants_for_replay(
			cache_table_schema, cache_table
		);

		EXECUTE 'DROP TABLE '
			|| quote_ident(cache_table_schema) || '.'
			|| quote_ident(cache_table);
	END IF;

	SELECT * INTO ct_rec
	FROM
		schema_support.cache_table ct
	WHERE
		ct.cache_table_schema = param_cache_table_schema AND
		ct.cache_table = param_cache_table;

	IF NOT FOUND THEN
		INSERT INTO schema_support.cache_table(
			cache_table_schema,
			cache_table,
			defining_view_schema,
			defining_view,
			updates_enabled
		) VALUES (
			param_cache_table_schema,
			param_cache_table,
			param_defining_view_schema,
			param_defining_view,
			'true'
		);
	END IF;

	EXECUTE format('CREATE TABLE %I.%I AS SELECT * FROM %I.%I',
		cache_table_schema,
		cache_table,
		defining_view_schema,
		defining_view
	);
END
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.synchronize_cache_tables(cache_table_schema text DEFAULT NULL::text, cache_table text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	ct_rec			RECORD;
	query			text;
	inserted_rows	integer;
	deleted_rows	integer;
BEGIN
	IF cache_table_schema IS NULL THEN
		IF cache_table IS NOT NULL THEN
			RAISE 'Must specify cache_table_schema if cache_table is passed'
				USING ERRCODE = 'null_value_not_allowed';
		END IF;
		query := '
			SELECT
				*
			FROM
				schema_support.cache_table
			WHERE
				updates_enabled = true
			';
	ELSE
		IF cache_table IS NOT NULL THEN
			query := format($query$
				SELECT
					*
				FROM
					schema_support.cache_table
				WHERE
					quote_ident(cache_table_schema) = '%I' AND
					quote_ident(cache_table) = '%I'
				$query$,
				cache_table_schema,
				cache_table
			);
		ELSE
			query := format($query$
				SELECT
					*
				FROM
					schema_support.cache_table
				WHERE
					quote_ident(cache_table_schema) = '%I' AND
					updates_enabled = true
				$query$,
				cache_table_schema
			);
		END IF;
	END IF;
	FOR ct_rec IN EXECUTE query LOOP
		RAISE DEBUG 'Processing %.%',
			quote_ident(ct_rec.cache_table_schema),
			quote_ident(ct_rec.cache_table);
			
		--
		-- Insert rows that exist in the view that do not exist in the cache
		-- table
		--
		query := format($query$
			INSERT INTO %I.%I
			SELECT * FROM %I.%I z
			WHERE
				(z) IN 
				(
					SELECT (x) FROM 
					(
						SELECT * FROM %I.%I EXCEPT
						SELECT * FROM %I.%I
					) x
				)
			$query$,
			ct_rec.cache_table_schema,
			ct_rec.cache_table,
			ct_rec.defining_view_schema,
			ct_rec.defining_view,
			ct_rec.defining_view_schema,
			ct_rec.defining_view,
			ct_rec.cache_table_schema,
			ct_rec.cache_table
		);
		RAISE DEBUG E'Executing:\n%\n', query;
		EXECUTE query;
		GET DIAGNOSTICS inserted_rows := ROW_COUNT;

		--
		-- Delete rows that exist in the cache table that do not exist in the
		-- defining view
		--
		query := format($query$
			DELETE FROM %I.%I z
			WHERE
				(z) IN 
				(
					SELECT (x) FROM 
					(
						SELECT * FROM %I.%I EXCEPT
						SELECT * FROM %I.%I
					) x
				)
			$query$,
			ct_rec.cache_table_schema,
			ct_rec.cache_table,
			ct_rec.cache_table_schema,
			ct_rec.cache_table,
			ct_rec.defining_view_schema,
			ct_rec.defining_view
		);
		RAISE DEBUG E'Executing:\n%\n', query;
		EXECUTE query;
		GET DIAGNOSTICS deleted_rows := ROW_COUNT;

		IF (inserted_rows > 0 OR deleted_rows > 0) THEN
			INSERT INTO schema_support.cache_table_update_log (
				cache_table_schema,
				cache_table,
				update_timestamp,
				rows_inserted,
				rows_deleted,
				forced
			) VALUES (
				ct_rec.cache_table_schema,
				ct_rec.cache_table,
				current_timestamp,
				inserted_rows,
				deleted_rows,
				false
			);
		END IF;
	END LOOP;
END
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.undo_audit_row(in_table text, in_audit_schema text DEFAULT 'audit'::text, in_schema text DEFAULT 'jazzhands'::text, in_start_time timestamp without time zone DEFAULT NULL::timestamp without time zone, in_end_time timestamp without time zone DEFAULT NULL::timestamp without time zone, in_aud_user text DEFAULT NULL::text, in_audit_ids integer[] DEFAULT NULL::integer[], in_txids bigint[] DEFAULT NULL::bigint[])
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'get_common_columns');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.get_common_columns ( _schema text, _table1 text, _table2 text );
CREATE OR REPLACE FUNCTION schema_support.get_common_columns(_schema text, _table1 text, _table2 text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	_q			text;
    cols        text[];
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_table');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_table ( aud_schema character varying, tbl_schema character varying, table_name character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_table(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	idx		text[];
	keys	text[];
	cols	text[];
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
	WHERE  	n.nspname = quote_ident(aud_schema)
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
	WHERE  	n.nspname = quote_ident(aud_schema)
	  AND	c.relname = quote_ident(table_name)
	  AND 	a.attnum > 0
	  AND 	NOT a.attisdropped
	;

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

	EXECUTE 'INSERT INTO '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident(table_name) || ' ( '
		|| array_to_string(cols, ',') || ' ) SELECT '
		|| array_to_string(cols, ',') || ' FROM '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident('__old__' || table_name)
		|| ' ORDER BY '
		|| quote_ident('aud#seq');

	--
	-- fix sequence primary key to have the correct next value
	--
	EXECUTE 'SELECT max("aud#seq") + 1 FROM	 '
			|| quote_ident(aud_schema) || '.'
			|| quote_ident(table_name) INTO seq;
	IF seq IS NOT NULL THEN
		EXECUTE 'ALTER SEQUENCE '
			|| quote_ident(aud_schema) || '.'
			|| quote_ident(table_name || '_seq')
			|| ' RESTART WITH ' || seq;
	END IF;

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


	--
	-- recreate audit trigger
	--
	PERFORM schema_support.rebuild_audit_trigger (
		aud_schema, tbl_schema, table_name );

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
	_cols 	TEXT[];
	_pkcol 	TEXT[];
	_q 		TEXT;
	_f 		TEXT;
	_c 		RECORD;
	_w 		TEXT[];
	_ctl 		TEXT[];
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
		RAISE NOTICE 'table % has % rows; table % has % rows', old_rel, _t1, new_rel, _t2;
		IF _t1 > _t2 THEN
			_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(old_rel)  ||
				' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
					' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
					quote_ident(schema) || '.' || quote_ident(old_rel)  ||
					' EXCEPT ( '
						' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
						quote_ident(schema) || '.' || quote_ident(new_rel)  ||
					' )) ';
		ELSE
			_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(new_rel)  ||
				' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
					' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
					quote_ident(schema) || '.' || quote_ident(new_rel)  ||
					' EXCEPT ( '
						' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
						quote_ident(schema) || '.' || quote_ident(old_rel)  ||
					' )) ';

		END IF;

		FOR _r IN EXECUTE 'SELECT row_to_json(x) as r FROM (' || _q || ') x'
		LOOP
			RAISE NOTICE '%', _r;
		END LOOP;

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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_last_changed');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_last_changed ( relation text, schema text, debug boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_last_changed(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_dependent_objects_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_dependent_objects_for_replay ( schema character varying, object character varying, dropit boolean, doobjectdeps boolean );
CREATE OR REPLACE FUNCTION schema_support.save_dependent_objects_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, doobjectdeps boolean DEFAULT false)
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
$function$
;

DROP FUNCTION IF EXISTS schema_support.undo_audit_row ( in_table text, in_audit_schema text, in_schema text, in_start_time timestamp without time zone, in_end_time timestamp without time zone, in_aud_user text, in_audit_ids integer[] );
-- New function
CREATE OR REPLACE FUNCTION schema_support.create_cache_table(cache_table_schema text, cache_table text, defining_view_schema text, defining_view text, force boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	param_cache_table_schema	ALIAS FOR cache_table_schema;
	param_cache_table			ALIAS FOR cache_table;
	param_defining_view_schema	ALIAS FOR defining_view_schema;
	param_defining_view			ALIAS FOR defining_view;
	ct_rec						RECORD;
BEGIN
	--
	-- Ensure that the defining view exists
	--
	PERFORM *
	FROM
		information_schema.views
	WHERE
		table_schema = defining_view_schema AND
		table_name = defining_view;
	
	IF NOT FOUND THEN
		RAISE 'view %.% does not exist',
			defining_view_schema,
			defining_view
			USING ERRCODE = 'foreign_key_violation';
	END IF;

	--
	-- Verify that the cache table does not exist, or if it does that
	-- we have an entry for it in schema_support.cache_table and
	-- force is being passed.
	--

	PERFORM *
	FROM
		information_schema.tables
	WHERE
		table_schema = cache_table_schema AND
		table_name = cache_table;
	
	IF FOUND THEN
		IF NOT force THEN
			RAISE 'cache table %.% already exists',
				cache_table_schema,
				cache_table
				USING ERRCODE = 'unique_violation';
		END IF;

		PERFORM *
		FROM
			schema_support.cache_table ct
		WHERE
			ct.cache_table_schema = param_cache_table_schema AND
			ct.cache_table = param_cache_table;

		IF NOT FOUND THEN
			RAISE '%', concat(
				'cache table ', cache_table_schema, '.', cache_table,
				' already exists, but there is no tracking ',
				'information for it in schema_support.cache_table.  ',
				'This must be corrected manually.')
				USING ERRCODE = 'unique_violation';
		END IF;

		PERFORM schema_support.save_grants_for_replay(
			cache_table_schema, cache_table
		);

		EXECUTE 'DROP TABLE '
			|| quote_ident(cache_table_schema) || '.'
			|| quote_ident(cache_table);
	END IF;

	SELECT * INTO ct_rec
	FROM
		schema_support.cache_table ct
	WHERE
		ct.cache_table_schema = param_cache_table_schema AND
		ct.cache_table = param_cache_table;

	IF NOT FOUND THEN
		INSERT INTO schema_support.cache_table(
			cache_table_schema,
			cache_table,
			defining_view_schema,
			defining_view,
			updates_enabled
		) VALUES (
			param_cache_table_schema,
			param_cache_table,
			param_defining_view_schema,
			param_defining_view,
			'true'
		);
	END IF;

	EXECUTE format('CREATE TABLE %I.%I AS SELECT * FROM %I.%I',
		cache_table_schema,
		cache_table,
		defining_view_schema,
		defining_view
	);
END
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.synchronize_cache_tables(cache_table_schema text DEFAULT NULL::text, cache_table text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	ct_rec			RECORD;
	query			text;
	inserted_rows	integer;
	deleted_rows	integer;
BEGIN
	IF cache_table_schema IS NULL THEN
		IF cache_table IS NOT NULL THEN
			RAISE 'Must specify cache_table_schema if cache_table is passed'
				USING ERRCODE = 'null_value_not_allowed';
		END IF;
		query := '
			SELECT
				*
			FROM
				schema_support.cache_table
			WHERE
				updates_enabled = true
			';
	ELSE
		IF cache_table IS NOT NULL THEN
			query := format($query$
				SELECT
					*
				FROM
					schema_support.cache_table
				WHERE
					quote_ident(cache_table_schema) = '%I' AND
					quote_ident(cache_table) = '%I'
				$query$,
				cache_table_schema,
				cache_table
			);
		ELSE
			query := format($query$
				SELECT
					*
				FROM
					schema_support.cache_table
				WHERE
					quote_ident(cache_table_schema) = '%I' AND
					updates_enabled = true
				$query$,
				cache_table_schema
			);
		END IF;
	END IF;
	FOR ct_rec IN EXECUTE query LOOP
		RAISE DEBUG 'Processing %.%',
			quote_ident(ct_rec.cache_table_schema),
			quote_ident(ct_rec.cache_table);
			
		--
		-- Insert rows that exist in the view that do not exist in the cache
		-- table
		--
		query := format($query$
			INSERT INTO %I.%I
			SELECT * FROM %I.%I z
			WHERE
				(z) IN 
				(
					SELECT (x) FROM 
					(
						SELECT * FROM %I.%I EXCEPT
						SELECT * FROM %I.%I
					) x
				)
			$query$,
			ct_rec.cache_table_schema,
			ct_rec.cache_table,
			ct_rec.defining_view_schema,
			ct_rec.defining_view,
			ct_rec.defining_view_schema,
			ct_rec.defining_view,
			ct_rec.cache_table_schema,
			ct_rec.cache_table
		);
		RAISE DEBUG E'Executing:\n%\n', query;
		EXECUTE query;
		GET DIAGNOSTICS inserted_rows := ROW_COUNT;

		--
		-- Delete rows that exist in the cache table that do not exist in the
		-- defining view
		--
		query := format($query$
			DELETE FROM %I.%I z
			WHERE
				(z) IN 
				(
					SELECT (x) FROM 
					(
						SELECT * FROM %I.%I EXCEPT
						SELECT * FROM %I.%I
					) x
				)
			$query$,
			ct_rec.cache_table_schema,
			ct_rec.cache_table,
			ct_rec.cache_table_schema,
			ct_rec.cache_table,
			ct_rec.defining_view_schema,
			ct_rec.defining_view
		);
		RAISE DEBUG E'Executing:\n%\n', query;
		EXECUTE query;
		GET DIAGNOSTICS deleted_rows := ROW_COUNT;

		IF (inserted_rows > 0 OR deleted_rows > 0) THEN
			INSERT INTO schema_support.cache_table_update_log (
				cache_table_schema,
				cache_table,
				update_timestamp,
				rows_inserted,
				rows_deleted,
				forced
			) VALUES (
				ct_rec.cache_table_schema,
				ct_rec.cache_table,
				current_timestamp,
				inserted_rows,
				deleted_rows,
				false
			);
		END IF;
	END LOOP;
END
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.undo_audit_row(in_table text, in_audit_schema text DEFAULT 'audit'::text, in_schema text DEFAULT 'jazzhands'::text, in_start_time timestamp without time zone DEFAULT NULL::timestamp without time zone, in_end_time timestamp without time zone DEFAULT NULL::timestamp without time zone, in_aud_user text DEFAULT NULL::text, in_audit_ids integer[] DEFAULT NULL::integer[], in_txids bigint[] DEFAULT NULL::bigint[])
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
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
-- New function
CREATE OR REPLACE FUNCTION dns_utils.add_ns_records(dns_domain_id integer, purge boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	IF purge THEN
		EXECUTE '
			DELETE FROM dns_record
			WHERE dns_domain_id = $1
			AND dns_name IS NULL
			AND dns_class = $2
			AND dns_type = $3
			AND dns_value NOT IN (
				SELECT property_value
				FROM property
				WHERE property_name = $4
				AND property_type = $5
			)
		' USING dns_domain_id, 'IN', 'NS', '_authdns', 'Defaults';
	END IF;
	EXECUTE '
		INSERT INTO dns_record (
			dns_domain_id, dns_class, dns_type, dns_value
		) select $1, $2, $3, property_value
		FROM property
		WHERE property_name = $4
		AND property_type = $5
		AND property_value NOT IN (
			SELECT dns_value
			FROM dns_record
			WHERE dns_domain_id = $1
			AND dns_class = $2
			AND dns_type = $3
			AND dns_name IS NULL
		)
	' USING dns_domain_id, 'IN', 'NS', '_authdns', 'Defaults';
END;
$function$
;

--
-- Process middle (non-trigger) schema person_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('person_manip', 'add_person');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS person_manip.add_person ( __person_id integer, first_name character varying, middle_name character varying, last_name character varying, name_suffix character varying, gender character varying, preferred_last_name character varying, preferred_first_name character varying, birth_date date, _company_id integer, external_hr_id character varying, person_company_status character varying, is_manager character varying, is_exempt character varying, is_full_time character varying, employee_id character varying, hire_date date, termination_date date, person_company_relation character varying, job_title character varying, department character varying, login character varying, OUT _person_id integer, OUT _account_collection_id integer, OUT _account_id integer );
CREATE OR REPLACE FUNCTION person_manip.add_person(__person_id integer, first_name character varying, middle_name character varying, last_name character varying, name_suffix character varying, gender character varying, preferred_last_name character varying, preferred_first_name character varying, birth_date date, _company_id integer, external_hr_id character varying, person_company_status character varying, is_manager character varying, is_exempt character varying, is_full_time character varying, employee_id character varying, hire_date date, termination_date date, person_company_relation character varying, job_title character varying, department character varying, login character varying, OUT _person_id integer, OUT _account_collection_id integer, OUT _account_id integer)
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

-- Changed function
SELECT schema_support.save_grants_for_replay('person_manip', 'add_user');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS person_manip.add_user ( company_id integer, person_company_relation character varying, login character varying, first_name character varying, middle_name character varying, last_name character varying, name_suffix character varying, gender character varying, preferred_last_name character varying, preferred_first_name character varying, birth_date date, external_hr_id character varying, person_company_status character varying, is_management character varying, is_manager character varying, is_exempt character varying, is_full_time character varying, employee_id text, hire_date date, termination_date date, position_title character varying, job_title character varying, department_name character varying, manager_person_id integer, site_code character varying, physical_address_id integer, person_location_type character varying, description character varying, unix_uid character varying, INOUT person_id integer, OUT dept_account_collection_id integer, OUT account_id integer );
CREATE OR REPLACE FUNCTION person_manip.add_user(company_id integer, person_company_relation character varying, login character varying DEFAULT NULL::character varying, first_name character varying DEFAULT NULL::character varying, middle_name character varying DEFAULT NULL::character varying, last_name character varying DEFAULT NULL::character varying, name_suffix character varying DEFAULT NULL::character varying, gender character varying DEFAULT NULL::character varying, preferred_last_name character varying DEFAULT NULL::character varying, preferred_first_name character varying DEFAULT NULL::character varying, birth_date date DEFAULT NULL::date, external_hr_id character varying DEFAULT NULL::character varying, person_company_status character varying DEFAULT 'enabled'::character varying, is_management character varying DEFAULT 'N'::character varying, is_manager character varying DEFAULT NULL::character varying, is_exempt character varying DEFAULT 'Y'::character varying, is_full_time character varying DEFAULT 'Y'::character varying, employee_id text DEFAULT NULL::text, hire_date date DEFAULT NULL::date, termination_date date DEFAULT NULL::date, position_title character varying DEFAULT NULL::character varying, job_title character varying DEFAULT NULL::character varying, department_name character varying DEFAULT NULL::character varying, manager_person_id integer DEFAULT NULL::integer, site_code character varying DEFAULT NULL::character varying, physical_address_id integer DEFAULT NULL::integer, person_location_type character varying DEFAULT 'office'::character varying, description character varying DEFAULT NULL::character varying, unix_uid character varying DEFAULT NULL::character varying, INOUT person_id integer DEFAULT NULL::integer, OUT dept_account_collection_id integer, OUT account_id integer)
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
	IF is_manager IS NOT NULL THEN
		is_management := is_manager;
	END IF;

	IF job_title IS NOT NULL THEN
		position_title := job_title;
	END IF;

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
                in_account_realm_id := _account_realm_id,
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
        INSERT INTO v_person_company
            (person_id, company_id, external_hr_id, person_company_status, is_management, is_exempt, is_full_time, employee_id, hire_date, termination_date, person_company_relation, position_title, manager_person_id)
            VALUES
            (person_id, company_id, external_hr_id, person_company_status, is_management, is_exempt, is_full_time, employee_id, hire_date, termination_date, person_company_relation, position_title, manager_person_id);
        INSERT INTO person_account_realm_company ( person_id, company_id, account_realm_id) VALUES ( person_id, company_id, _account_realm_id);
    END IF;

    INSERT INTO account ( login, person_id, company_id, account_realm_id, account_status, description, account_role, account_type)
        VALUES (login, person_id, company_id, _account_realm_id, person_company_status, description, 'primary', _account_type)
    RETURNING account.account_id INTO account_id;

    IF department_name IS NOT NULL THEN
        dept_account_collection_id = person_manip.get_account_collection_id(department_name, 'department');
        INSERT INTO account_collection_account (account_collection_id, account_id) VALUES ( dept_account_collection_id, account_id);
    END IF;

    IF site_code IS NOT NULL AND physical_address_id IS NOT NULL THEN
        RAISE EXCEPTION 'You must provide either site_code or physical_address_id NOT both';
    END IF;

    IF site_code IS NULL AND physical_address_id IS NOT NULL THEN
        site_code = person_manip.get_site_code_from_physical_address_id(physical_address_id);
    END IF;

    IF physical_address_id IS NULL AND site_code IS NOT NULL THEN
        physical_address_id = person_manip.get_physical_address_from_site_code(site_code);
    END IF;

    IF physical_address_id IS NOT NULL AND site_code IS NOT NULL THEN
        INSERT INTO person_location
            (person_id, person_location_type, site_code, physical_address_id)
        VALUES
            (person_id, person_location_type, site_code, physical_address_id);
    END IF;


    IF unix_uid IS NOT NULL THEN
        _accountid = account_id;
        SELECT  aui.account_id
          INTO  _uxaccountid
          FROM  account_unix_info aui
        WHERE  aui.account_id = _accountid;

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

-- Changed function
SELECT schema_support.save_grants_for_replay('person_manip', 'change_company');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS person_manip.change_company ( final_company_id integer, _person_id integer, initial_company_id integer, _account_realm_id integer );
CREATE OR REPLACE FUNCTION person_manip.change_company(final_company_id integer, _person_id integer, initial_company_id integer, _account_realm_id integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands', 'pg_temp'
AS $function$
DECLARE
	initial_person_company  person_company%ROWTYPE;
	_arid			account_realm.account_realm_id%TYPE;
BEGIN
	IF _account_realm_id IS NULL THEN
		SELECT	account_realm_id
		INTO	_arid
		FROM	property
		WHERE	property_type = 'Defaults'
		AND	property_name = '_root_account_realm_id';
	ELSE
		_arid := _account_realm_id;
	END IF;
	set constraints fk_ac_ac_rlm_cpy_act_rlm_cpy DEFERRED;
	set constraints fk_account_prsn_cmpy_acct DEFERRED;
	set constraints fk_account_company_person DEFERRED;
	set constraints fk_pers_comp_attr_person_comp_id DEFERRED;

	UPDATE person_account_realm_company
		SET company_id = final_company_id
	WHERE person_id = _person_id
	AND company_id = initial_company_id
	AND account_realm_id = _arid;

	SELECT *
	INTO initial_person_company
	FROM person_company
	WHERE person_id = _person_id
	AND company_id = initial_company_id;

	UPDATE person_company
	SET company_id = final_company_id
	WHERE company_id = initial_company_id
	AND person_id = _person_id;

	UPDATE person_company_attr
	SET company_id = final_company_id
	WHERE company_id = initial_company_id
	AND person_id = _person_id;

	UPDATE account
	SET company_id = final_company_id
	WHERE company_id = initial_company_id
	AND person_id = _person_id
	AND account_realm_id = _arid;

	set constraints fk_ac_ac_rlm_cpy_act_rlm_cpy IMMEDIATE;
	set constraints fk_account_prsn_cmpy_acct IMMEDIATE;
	set constraints fk_account_company_person IMMEDIATE;
	set constraints fk_pers_comp_attr_person_comp_id IMMEDIATE;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('person_manip', 'guess_person_id');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS person_manip.guess_person_id ( first_name text, last_name text, login text, company_id integer );
CREATE OR REPLACE FUNCTION person_manip.guess_person_id(first_name text, last_name text, login text, company_id integer DEFAULT NULL::integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands', 'pg_temp'
AS $function$
DECLARE
	pid		person.person_id%TYPE;
	_l		text;
BEGIN
	-- see if that login name is alradeady associated with someone with the
	-- same first and last name
	EXECUTE '
		SELECT person_id
		FROM	person
				JOIN account USING (person_id,$2)
		WHERE	login = $1
		AND		first_name = $3
		AND		last_name = $4
	' INTO pid USING login, company_id, first_name, last_name;

	IF pid IS NOT NULL THEN
		RETURN pid;
	END IF;

	_l = regexp_replace(login, '@.*$', '');

	IF _l != login THEN
		EXECUTE '
			SELECT person_id
			FROM	person
					JOIN account USING (person_id,$2)
			WHERE	login = $1
			AND		first_name = $3
			AND		last_name = $4
		' INTO pid USING _l, company_id, first_name, last_name;

		IF pid IS NOT NULL THEN
			RETURN pid;
		END IF;
	END IF;

	RETURN NULL;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('person_manip', 'merge_accounts');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS person_manip.merge_accounts ( merge_from_account_id integer, merge_to_account_id integer );
CREATE OR REPLACE FUNCTION person_manip.merge_accounts(merge_from_account_id integer, merge_to_account_id integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	fpc		v_person_company%ROWTYPE;
	tpc		v_person_company%ROWTYPE;
	_account_realm_id INTEGER;
BEGIN
	select	*
	  into	fpc
	  from	v_person_company
	 where	(person_id, company_id) in
		(select person_id, company_id
		   from account where account_id = merge_from_account_id);

	select	*
	  into	tpc
	  from	v_person_company
	 where	(person_id, company_id) in
		(select person_id, company_id
		   from account where account_id = merge_to_account_id);

	IF (fpc.company_id != tpc.company_id) THEN
		RAISE EXCEPTION 'Accounts are in different companies';
	END IF;

	IF (fpc.person_company_relation != tpc.person_company_relation) THEN
		RAISE EXCEPTION 'People have different relationships';
	END IF;

	IF(tpc.external_hr_id is NOT NULL AND fpc.external_hr_id IS NULL) THEN
		RAISE EXCEPTION 'Destination account has an external HR ID and origin account has none';
	END IF;

	-- move any account collections over that are
	-- not infrastructure ones, and the new person is
	-- not in
	UPDATE	account_collection_account
	   SET	ACCOUNT_ID = merge_to_account_id
	 WHERE	ACCOUNT_ID = merge_from_account_id
	  AND	ACCOUNT_COLLECTION_ID IN (
			SELECT ACCOUNT_COLLECTION_ID
			  FROM	ACCOUNT_COLLECTION
				INNER JOIN VAL_ACCOUNT_COLLECTION_TYPE
					USING (ACCOUNT_COLLECTION_TYPE)
			 WHERE	IS_INFRASTRUCTURE_TYPE = 'N'
		)
	  AND	account_collection_id not in (
			SELECT	account_collection_id
			  FROM	account_collection_account
			 WHERE	account_id = merge_to_account_id
	);


	-- Now begin removing the old account
	PERFORM person_manip.purge_account( merge_from_account_id );

	-- Switch person_ids
	DELETE FROM person_account_realm_company WHERE person_id = fpc.person_id AND company_id = tpc.company_id;
	SELECT account_realm_id INTO _account_realm_id FROM account_realm_company WHERE company_id = tpc.company_id;
	INSERT INTO person_account_realm_company (person_id, company_id, account_realm_id) VALUES ( fpc.person_id , tpc.company_id, _account_realm_id);
	UPDATE account SET account_realm_id = _account_realm_id, person_id = fpc.person_id WHERE person_id = tpc.person_id AND company_id = fpc.company_id;
	DELETE FROM person_company_attr WHERE person_id = tpc.person_id AND company_id = tpc.company_id;
	DELETE FROM person_company WHERE person_id = tpc.person_id AND company_id = tpc.company_id;
	DELETE FROM person_account_realm_company WHERE person_id = tpc.person_id AND company_id = tpc.company_id;
	UPDATE person_image SET person_id = fpc.person_id WHERE person_id = tpc.person_id;
	-- if there are other relations that may exist, do not delete the person.
	BEGIN
		delete from person where person_id = tpc.person_id;
	EXCEPTION WHEN foreign_key_violation THEN
		NULL;
	END;

	return merge_to_account_id;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('person_manip', 'purge_account');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS person_manip.purge_account ( in_account_id integer );
CREATE OR REPLACE FUNCTION person_manip.purge_account(in_account_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	-- note the per-account account collection is removed in triggers

	DELETE FROM account_assignd_cert where ACCOUNT_ID = in_account_id;
	DELETE FROM account_token where ACCOUNT_ID = in_account_id;
	DELETE FROM account_unix_info where ACCOUNT_ID = in_account_id;
	DELETE FROM klogin where ACCOUNT_ID = in_account_id;
	DELETE FROM property where ACCOUNT_ID = in_account_id;
	DELETE FROM property where account_collection_id in
		(select account_collection_id from account_collection
			where account_collection_name in
				(select login from account where account_id = in_account_id)
				and account_collection_type in ('per-account')
		);
	DELETE FROM account_password where ACCOUNT_ID = in_account_id;
	DELETE FROM unix_group where account_collection_id in
		(select account_collection_id from account_collection
			where account_collection_name in
				(select login from account where account_id = in_account_id)
				and account_collection_type in ('unix-group')
		);
	DELETE FROM account_collection_account where ACCOUNT_ID = in_account_id;

	DELETE FROM account_collection where account_collection_name in
		(select login from account where account_id = in_account_id)
		and account_collection_type in ('per-account', 'unix-group');

	DELETE FROM account_ssh_key where ACCOUNT_ID = in_account_id;
	DELETE FROM account where ACCOUNT_ID = in_account_id;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('person_manip', 'purge_person');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS person_manip.purge_person ( in_person_id integer );
CREATE OR REPLACE FUNCTION person_manip.purge_person(in_person_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	aid	INTEGER;
BEGIN
	FOR aid IN select account_id
			FROM account
			WHERE person_id = in_person_id
	LOOP
		PERFORM person_manip.purge_account ( aid );
	END LOOP;

	DELETE FROM person_company_attr WHERE person_id = in_person_id;
	DELETE FROM person_contact WHERE person_id = in_person_id;
	DELETE FROM person_location WHERE person_id = in_person_id;
	DELETE FROM v_person_company WHERE person_id = in_person_id;
	DELETE FROM person_account_realm_company WHERE person_id = in_person_id;
	DELETE FROM person WHERE person_id = in_person_id;
END;
$function$
;

--
-- Process middle (non-trigger) schema auto_ac_manip
--
--
-- Process middle (non-trigger) schema component_connection_utils
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
-- Changed function
SELECT schema_support.save_grants_for_replay('device_utils', 'remove_network_interfaces');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_utils.remove_network_interfaces ( network_interface_id_list integer[] );
CREATE OR REPLACE FUNCTION device_utils.remove_network_interfaces(network_interface_id_list integer[])
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	nb_list		integer[];
	sn_list		integer[];
	sn_rec		RECORD;
	nb_id		jazzhands.netblock.netblock_id%TYPE;
BEGIN
	--
	-- Save off some netblock information for now
	--

	RAISE LOG 'Removing network_interfaces with ids %',
		array_to_string(network_interface_id_list, ', ');

	RAISE LOG 'Retrieving netblock information...';

	SELECT
		array_agg(nin.netblock_id) INTO nb_list
	FROM
		network_interface_netblock nin
	WHERE
		nin.network_interface_id = ANY(network_interface_id_list);

	SELECT DISTINCT
		array_agg(shared_netblock_id) INTO sn_list
	FROM
		shared_netblock_network_int snni
	WHERE
		snni.network_interface_id = ANY(network_interface_id_list);

	--
	-- Clean up network bits
	--

	RAISE LOG 'Removing shared netblocks...';

	DELETE FROM shared_netblock_network_int WHERE
		network_interface_id IN (
			SELECT
				network_interface_id
			FROM
				network_interface ni
			WHERE
				ni.network_interface_id = ANY(network_interface_id_list)
		);

	--
	-- Clean up things for any shared_netblocks which are now orphaned
	-- Unfortunately, we have to do these as individual queries to catch
	-- exceptions
	--
	FOR sn_rec IN SELECT
		shared_netblock_id,
		netblock_id
	FROM
		shared_netblock s LEFT JOIN
		shared_netblock_network_int USING (shared_netblock_id)
	WHERE
		shared_netblock_id = ANY(sn_list) AND
		network_interface_id IS NULL
	LOOP
		BEGIN
			DELETE FROM dns_record dr WHERE
				dr.netblock_id = sn_rec.netblock_id;
			DELETE FROM shared_netblock sn WHERE
				sn.shared_netblock_id = sn_rec.shared_netblock_id;
			BEGIN
				DELETE FROM netblock n WHERE
					n.netblock_id = sn_rec.netblock_id;
			EXCEPTION WHEN foreign_key_violation THEN
				NULL;
			END;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	END LOOP;

	RAISE LOG 'Removing directly-assigned netblocks...';

	DELETE FROM network_interface_netblock WHERE network_interface_id IN (
		SELECT
			network_interface_id
	 	FROM
			network_interface ni
		WHERE
			ni.network_interface_id = ANY (network_interface_id_list)
	);

	RAISE LOG 'Removing network_interfaces...';

	DELETE FROM network_interface_purpose nip WHERE
		nip.network_interface_id = ANY(network_interface_id_list);

	DELETE FROM network_interface ni WHERE ni.network_interface_id =
		ANY(network_interface_id_list);

	RAISE LOG 'Removing netblocks (%) ... ', nb_list; 
	IF nb_list IS NOT NULL THEN
		FOREACH nb_id IN ARRAY nb_list LOOP
			BEGIN
				DELETE FROM dns_record WHERE netblock_id = nb_id;

				DELETE FROM netblock n WHERE
					n.netblock_id = nb_id;
			EXCEPTION WHEN foreign_key_violation THEN
				NULL;
			END;
		END LOOP;
	END IF;

	RETURN true;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('device_utils', 'retire_devices');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_utils.retire_devices ( device_id_list integer[] );
CREATE OR REPLACE FUNCTION device_utils.retire_devices(device_id_list integer[])
 RETURNS TABLE(device_id integer, success boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	nb_list		integer[];
	sn_list		integer[];
	sn_rec		RECORD;
	rl_list		integer[];
	dev_id		jazzhands.device.device_id%TYPE;
	se_id		jazzhands.service_environment.service_environment_id%TYPE;
	nb_id		jazzhands.netblock.netblock_id%TYPE;
BEGIN
	BEGIN
		PERFORM local_hooks.retire_devices_early(device_id_list);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;
	--
	-- Add all of the BMCs for any retiring devices to the list in case
	-- they are not specified
	--
	device_id_list := array_cat(
		device_id_list,
		(SELECT
			array_agg(manager_device_id)
		FROM
			device_management_controller dmc
		WHERE
			dmc.device_id = ANY(device_id_list) AND
			device_mgmt_control_type = 'bmc'
		)
	);

	--
	-- Delete network_interfaces
	--
	PERFORM device_utils.remove_network_interfaces(
		network_interface_id_list := ARRAY(
			SELECT
				network_interface_id
			FROM
				network_interface ni
			WHERE
				ni.device_id = ANY(device_id_list)
		)
	);

	RAISE LOG 'Removing inter_component_connections...';

	WITH s AS (
		SELECT DISTINCT
			slot_id
		FROM
			v_device_slots ds
		WHERE
			ds.device_id = ANY(device_id_list)
	)
	DELETE FROM inter_component_connection WHERE
		slot1_id IN (SELECT slot_id FROM s) OR
		slot2_id IN (SELECT slot_id FROM s);

	RAISE LOG 'Removing device properties...';

	DELETE FROM property WHERE device_collection_id IN (
		SELECT
			dc.device_collection_id
		FROM
			device_collection dc JOIN
			device_collection_device dcd USING (device_collection_id)
		WHERE
			dc.device_collection_type = 'per-device' AND
			dcd.device_id = ANY(device_id_list)
	);

	RAISE LOG 'Removing per-device device_collections...';

	DELETE FROM
		device_collection_device dcd
	WHERE
		dcd.device_id = ANY(device_id_list) AND
		device_collection_id NOT IN (
			SELECT
				device_collection_id
			FROM
				device_collection
			WHERE
				device_collection_type = 'per-device'
		);

	--
	-- Make sure all rack_location stuff has been cleared out
	--

	RAISE LOG 'Removing rack_locations...';

	SELECT array_agg(rack_location_id) INTO rl_list FROM (
		SELECT DISTINCT
			rack_location_id
		FROM
			device d
		WHERE
			d.device_id = ANY(device_id_list) AND
			rack_location_id IS NOT NULL
		UNION
		SELECT DISTINCT
			rack_location_id
		FROM
			component c JOIN
			v_device_components dc USING (component_id)
		WHERE
			dc.device_id = ANY(device_id_list) AND
			rack_location_id IS NOT NULL
	) x;

	UPDATE
		device d
	SET
		rack_location_id = NULL
	WHERE
		d.device_id = ANY(device_id_list) AND
		rack_location_id IS NOT NULL;

	UPDATE
		component
	SET
		rack_location_id = NULL
	WHERE
		component_id IN (
			SELECT
				component_id
			FROM
				v_device_components dc
			WHERE
				dc.device_id = ANY(device_id_list)
		) AND
		rack_location_id IS NOT NULL;

	--
	-- Delete any now-abandoned rack_locations
	--
	DELETE FROM
		rack_location rl
	WHERE
		rack_location_id = ANY (rl_list) AND
		rack_location_id NOT IN (
			SELECT
				rack_location_id
			FROM
				device
			WHERE
				rack_location_id IS NOT NULL
			UNION
			SELECT
				rack_location_id
			FROM
				component
			WHERE
				rack_location_id IS NOT NULL
		);

	RAISE LOG 'Removing device_management_controller links...';

	DELETE FROM device_management_controller dmc WHERE
		dmc.device_id = ANY (device_id_list) OR
		manager_device_id = ANY (device_id_list);

	RAISE LOG 'Removing device_encapsulation_domain entries...';

	DELETE FROM device_encapsulation_domain ded WHERE
		ded.device_id = ANY (device_id_list);

	--
	-- Clear out all of the logical_volume crap
	--
	RAISE LOG 'Removing logical volume hierarchies...';
	SET CONSTRAINTS ALL DEFERRED;

	DELETE FROM volume_group_physicalish_vol vgpv WHERE
		vgpv.device_id = ANY (device_id_list);
	DELETE FROM physicalish_volume pv WHERE
		pv.device_id = ANY (device_id_list);

	WITH z AS (
		DELETE FROM volume_group vg
		WHERE vg.device_id = ANY (device_id_list)
		RETURNING vg.volume_group_id
	)
	DELETE FROM volume_group_purpose WHERE
		volume_group_id IN (SELECT volume_group_id FROM z);

	WITH z AS (
		DELETE FROM logical_volume lv
		WHERE lv.device_id = ANY (device_id_list)
		RETURNING lv.logical_volume_id
	), y AS (
		DELETE FROM logical_volume_purpose WHERE
			logical_volume_id IN (SELECT logical_volume_id FROM z)
	)
	DELETE FROM logical_volume_property WHERE
		logical_volume_id IN (SELECT logical_volume_id FROM z);

	SET CONSTRAINTS ALL IMMEDIATE;

	--
	-- Attempt to delete all of the devices
	--
	SELECT service_environment_id INTO se_id FROM service_environment WHERE
		service_environment_name = 'unallocated';

	FOREACH dev_id IN ARRAY device_id_list LOOP
		RAISE LOG 'Deleting device %', dev_id;

		BEGIN
			DELETE FROM device_note dn WHERE dn.device_id = dev_id;

			DELETE FROM device d WHERE d.device_id = dev_id;
			device_id := dev_id;
			success := true;
			RETURN NEXT;
		EXCEPTION
			WHEN foreign_key_violation THEN
				UPDATE device d SET
					device_name = NULL,
					component_id = NULL,
					service_environment_id = se_id,
					device_status = 'removed',
					is_monitored = 'N',
					should_fetch_config = 'N',
					description = NULL
				WHERE
					d.device_id = dev_id;

				device_id := dev_id;
				success := false;
				RETURN NEXT;
		END;
	END LOOP;

	BEGIN
		PERFORM local_hooks.retire_devices_late(device_id_list);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;
	RETURN;
END;
$function$
;

--
-- Process middle (non-trigger) schema netblock_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_free_netblocks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_free_netblocks ( parent_netblock_list integer[], netmask_bits integer, single_address boolean, allocation_method text, max_addresses integer, desired_ip_address inet, rnd_masklen_threshold integer, rnd_max_count integer );
CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblocks(parent_netblock_list integer[], netmask_bits integer DEFAULT NULL::integer, single_address boolean DEFAULT false, allocation_method text DEFAULT NULL::text, max_addresses integer DEFAULT 1024, desired_ip_address inet DEFAULT NULL::inet, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024)
 RETURNS TABLE(ip_address inet, netblock_type character varying, ip_universe_id integer)
 LANGUAGE plpgsql
AS $function$
DECLARE
	parent_nbid		jazzhands.netblock.netblock_id%TYPE;
	netblock_rec	jazzhands.netblock%ROWTYPE;
	netrange_rec	RECORD;
	inet_list		inet[];
	current_ip		inet;
	saved_method	text;
	min_ip			inet;
	max_ip			inet;
	matches			integer;
	rnd_matches		integer;
	max_rnd_value	bigint;
	rnd_value		bigint;
	family_bits		integer;
BEGIN
	matches := 0;
	saved_method = allocation_method;

	IF allocation_method IS NOT NULL AND allocation_method
			NOT IN ('top', 'bottom', 'random', 'default') THEN
		RAISE 'address_type must be one of top, bottom, random, or default'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	--
	-- Sanitize masklen input.  This is a little complicated.
	--
	-- If a single address is desired, we always use a /32 or /128
	-- in the parent loop and everything else is ignored
	--
	-- Otherwise, if netmask_bits is passed, that wins, otherwise
	-- the netmask of whatever is passed with desired_ip_address wins
	--
	-- If none of these are the case, then things are wrong and we
	-- bail
	--

	IF NOT single_address THEN 
		IF desired_ip_address IS NOT NULL AND netmask_bits IS NULL THEN
			netmask_bits := masklen(desired_ip_address);
		ELSIF desired_ip_address IS NOT NULL AND 
				netmask_bits IS NOT NULL THEN
			desired_ip_address := set_masklen(desired_ip_address,
				netmask_bits);
		END IF;
		IF netmask_bits IS NULL THEN
			RAISE EXCEPTION 'netmask_bits must be set'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;
		IF allocation_method = 'random' THEN
			RAISE EXCEPTION 'random netblocks may only be returned for single addresses'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	FOREACH parent_nbid IN ARRAY parent_netblock_list LOOP
		rnd_matches := 0;
		--
		-- Restore this, because we may have overrridden it for a previous
		-- block
		--
		allocation_method = saved_method;
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

		-- If desired_ip_address is passed, then allocation_method is
		-- irrelevant

		IF desired_ip_address IS NOT NULL THEN
			--
			-- If the IP address is not the same family as the parent block,
			-- we aren't going to find it
			--
			IF family(desired_ip_address) != 
					family(netblock_rec.ip_address) THEN
				CONTINUE;
			END IF;
			allocation_method := 'bottom';
		END IF;

		--
		-- If allocation_method is 'default' or NULL, then use 'bottom'
		-- unless it's for a single IPv6 address in a netblock larger than 
		-- rnd_masklen_threshold
		--
		IF allocation_method IS NULL OR allocation_method = 'default' THEN
			allocation_method := 
				CASE WHEN 
					single_address AND 
					family(netblock_rec.ip_address) = 6 AND
					masklen(netblock_rec.ip_address) <= rnd_masklen_threshold
				THEN
					'random'
				ELSE
					'bottom'
				END;
		END IF;

		IF allocation_method = 'random' AND 
				family_bits - masklen(netblock_rec.ip_address) < 2 THEN
			-- Random allocation doesn't work if we don't have enough
			-- bits to play with, so just do sequential.
			allocation_method := 'bottom';
		END IF;

		IF single_address THEN 
			netmask_bits := family_bits;
			IF desired_ip_address IS NOT NULL THEN
				desired_ip_address := set_masklen(desired_ip_address,
					masklen(netblock_rec.ip_address));
			END IF;
		ELSIF netmask_bits <= masklen(netblock_rec.ip_address) THEN
			-- If the netmask is not for a smaller netblock than this parent,
			-- then bounce to the next one, because maybe it's larger
			RAISE DEBUG
				'netblock (%) is not larger than netmask_bits of % - skipping',
				masklen(netblock_rec.ip_address),
				netmask_bits;
			CONTINUE;
		END IF;

		IF netmask_bits > family_bits THEN
			RAISE EXCEPTION 'netmask_bits must be no more than % for netblock %',
				family_bits,
				netblock_rec.ip_address;
		END IF;

		--
		-- Short circuit the check if we're looking for a specific address
		-- and it's not in this netblock
		--

		IF desired_ip_address IS NOT NULL AND
				NOT (desired_ip_address <<= netblock_rec.ip_address) THEN
			RAISE DEBUG 'desired_ip_address % is not in netblock %',
				desired_ip_address,
				netblock_rec.ip_address;
			CONTINUE;
		END IF;

		IF single_address AND netblock_rec.can_subnet = 'Y' THEN
			RAISE EXCEPTION 'single addresses may not be assigned to to a block where can_subnet is Y';
		END IF;

		IF (NOT single_address) AND netblock_rec.can_subnet = 'N' THEN
			RAISE EXCEPTION 'Netblock % (%) may not be subnetted',
				netblock_rec.ip_address,
				netblock_rec.netblock_id;
		END IF;

		RAISE DEBUG 'Searching netblock % (%) using the % allocation method',
			netblock_rec.netblock_id,
			netblock_rec.ip_address,
			allocation_method;

		IF desired_ip_address IS NOT NULL THEN
			min_ip := desired_ip_address;
			max_ip := desired_ip_address + 1;
		ELSE
			min_ip := netblock_rec.ip_address;
			max_ip := broadcast(min_ip) + 1;
		END IF;

		IF allocation_method = 'top' THEN
			current_ip := network(set_masklen(max_ip - 1, netmask_bits));
		ELSIF allocation_method = 'random' THEN
			max_rnd_value := (x'7fffffffffffffff'::bigint >> CASE 
				WHEN family_bits - masklen(netblock_rec.ip_address) >= 63
				THEN 0
				ELSE 63 - (family_bits - masklen(netblock_rec.ip_address))
				END) - 2;
			-- random() appears to only do 32-bits, which is dumb
			-- I'm pretty sure that all of the casts are not required here,
			-- but better to make sure
			current_ip := min_ip + 
					((((random() * x'7fffffff'::bigint)::bigint << 32) + 
					(random() * x'ffffffff'::bigint)::bigint + 1)
					% max_rnd_value) + 1;
		ELSE -- it's 'bottom'
			current_ip := set_masklen(min_ip, netmask_bits);
		END IF;

		-- For single addresses, make the netmask match the netblock of the
		-- containing block, and skip the network and broadcast addresses
		-- We shouldn't need to skip for IPv6 addresses, but some things
		-- apparently suck

		IF single_address THEN
			current_ip := set_masklen(current_ip, 
				masklen(netblock_rec.ip_address));
			--
			-- If we're not allocating a single /31 or /32 for IPv4 or
			-- /127 or /128 for IPv6, then we want to skip the all-zeros
			-- and all-ones addresses
			--
			IF masklen(netblock_rec.ip_address) < (family_bits - 1) AND
					desired_ip_address IS NULL THEN
				current_ip := current_ip + 
					CASE WHEN allocation_method = 'top' THEN -1 ELSE 1 END;
				min_ip := min_ip + 1;
				max_ip := max_ip - 1;
			END IF;
		END IF;

		RAISE DEBUG 'Starting with IP address % with step masklen of %',
			current_ip,
			netmask_bits;

		WHILE (
				current_ip >= min_ip AND
				current_ip < max_ip AND
				matches < max_addresses AND
				rnd_matches < rnd_max_count
		) LOOP
			RAISE DEBUG '   Checking netblock %', current_ip;

			IF single_address THEN
				--
				-- Check to see if netblock is in a network_range, and if it is,
				-- then set the value to the top or bottom of the range, or
				-- another random value as appropriate
				--
				SELECT 
					network_range_id,
					start_nb.ip_address AS start_ip_address,
					stop_nb.ip_address AS stop_ip_address
				INTO netrange_rec
				FROM
					jazzhands.network_range nr,
					jazzhands.netblock start_nb,
					jazzhands.netblock stop_nb
				WHERE
					family(current_ip) = family(start_nb.ip_address) AND
					family(current_ip) = family(stop_nb.ip_address) AND
					(
						nr.start_netblock_id = start_nb.netblock_id AND
						nr.stop_netblock_id = stop_nb.netblock_id AND
						nr.parent_netblock_id = netblock_rec.netblock_id AND
						start_nb.ip_address <=
							set_masklen(current_ip, masklen(start_nb.ip_address))
						AND stop_nb.ip_address >=
							set_masklen(current_ip, masklen(stop_nb.ip_address))
					);

				IF FOUND THEN
					current_ip := CASE 
						WHEN allocation_method = 'bottom' THEN
							netrange_rec.stop_ip_address + 1
						WHEN allocation_method = 'top' THEN
							netrange_rec.start_ip_address - 1
						ELSE min_ip + ((
							((random() * x'7fffffff'::bigint)::bigint << 32) 
							+ 
							(random() * x'ffffffff'::bigint)::bigint + 1
							) % max_rnd_value) + 1 
					END;
					CONTINUE;
				END IF;
			END IF;
							
				
			PERFORM * FROM jazzhands.netblock n WHERE
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
			IF NOT FOUND AND (inet_list IS NULL OR
					NOT (current_ip = ANY(inet_list))) THEN
				find_free_netblocks.netblock_type :=
					netblock_rec.netblock_type;
				find_free_netblocks.ip_universe_id :=
					netblock_rec.ip_universe_id;
				find_free_netblocks.ip_address := current_ip;
				RETURN NEXT;
				inet_list := array_append(inet_list, current_ip);
				matches := matches + 1;
				-- Reset random counter if we found something
				rnd_matches := 0;
			ELSIF allocation_method = 'random' THEN
				-- Increase random counter if we didn't find something
				rnd_matches := rnd_matches + 1;
			END IF;

			-- Select the next IP address
			current_ip := 
				CASE WHEN single_address THEN
					CASE 
						WHEN allocation_method = 'bottom' THEN current_ip + 1
						WHEN allocation_method = 'top' THEN current_ip - 1
						ELSE min_ip + ((
							((random() * x'7fffffff'::bigint)::bigint << 32) 
							+ 
							(random() * x'ffffffff'::bigint)::bigint + 1
							) % max_rnd_value) + 1 
					END
				ELSE
					CASE WHEN allocation_method = 'bottom' THEN 
						network(broadcast(current_ip) + 1)
					ELSE 
						network(current_ip - 1)
					END
				END;
		END LOOP;
	END LOOP;
	RETURN;
END;
$function$
;

--
-- Process middle (non-trigger) schema property_utils
--
--
-- Process middle (non-trigger) schema netblock_manip
--
-- New function
CREATE OR REPLACE FUNCTION netblock_manip.create_network_range(start_ip_address inet, stop_ip_address inet, network_range_type character varying, parent_netblock_id integer DEFAULT NULL::integer, description character varying DEFAULT NULL::character varying, allow_assigned boolean DEFAULT false, dns_prefix text DEFAULT NULL::text, dns_domain_id integer DEFAULT NULL::integer, lease_time integer DEFAULT NULL::integer)
 RETURNS network_range
 LANGUAGE plpgsql
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

--
-- Process middle (non-trigger) schema physical_address_utils
--
--
-- Process middle (non-trigger) schema component_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'insert_component_into_parent_slot');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.insert_component_into_parent_slot ( parent_component_id integer, component_id integer, slot_name text, slot_function text, slot_type text, slot_index integer, physical_label text );
CREATE OR REPLACE FUNCTION component_utils.insert_component_into_parent_slot(parent_component_id integer, component_id integer, slot_name text, slot_function text, slot_type text DEFAULT 'unknown'::text, slot_index integer DEFAULT NULL::integer, physical_label text DEFAULT NULL::text)
 RETURNS slot
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	pcid 	ALIAS FOR parent_component_id;
	cid		ALIAS FOR component_id;
	sf		ALIAS FOR slot_function;
	sn		ALIAS FOR slot_name;
	st		ALIAS FOR slot_type;
	s		RECORD;
	stid	integer;
BEGIN
	--
	-- Look for this slot assigned to the component
	--
	SELECT
		slot.* INTO s
	FROM
		slot JOIN
		slot_type USING (slot_type_id)
	WHERE
		slot.component_id = pcid AND
		slot_type.slot_type = st AND
		slot_type.slot_function = sf AND
		slot.slot_name = sn;

	IF NOT FOUND THEN
		RAISE DEBUG 'Auto-creating slot for component assignment';
		SELECT
			slot_type_id INTO stid
		FROM
			slot_type
		WHERE
			slot_type.slot_type = st AND
			slot_type.slot_function = sf;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type %, function % not found adding component_type',
				st,
				sf
				USING ERRCODE = 'JH501';
		END IF;

		INSERT INTO slot (
			component_id,
			slot_name,
			slot_index,
			slot_type_id,
			physical_label,
			description
		) VALUES (
			pcid,
			sn,
			slot_index,
			stid,
			physical_label,
			'autocreated component slot'
		) RETURNING * INTO s;
	END IF;

	RAISE DEBUG 'Assigning component with component_id % to slot %',
		cid, s.slot_id;

	UPDATE 
		component c
	SET
		parent_slot_id = s.slot_id
	WHERE
		c.component_id = cid;

	RETURN s;
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
-- Process middle (non-trigger) schema backend_utils
--
-- New function
CREATE OR REPLACE FUNCTION backend_utils.relation_last_changed(view text, schema text DEFAULT 'jazzhands'::text)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	RETURN schema_support.relation_last_changed(view, schema);
END;
$function$
;

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
 RETURNS void
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

	DELETE FROM
		layer2_network l2n
	WHERE
		l2n.layer2_network_id = ANY(layer2_network_id_list);

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
 RETURNS void
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

	WITH x AS (
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
	)
	DELETE FROM
		jazzhands.netblock
	WHERE
		netblock_id IN (SELECT netblock_id FROM x);

	BEGIN
		PERFORM local_hooks.delete_layer3_networks_after_hooks(
			layer3_network_id_list := layer3_network_id_list
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

END $function$
;

--
-- Process middle (non-trigger) schema jazzhands_cache
--
-- Creating new sequences....


--------------------------------------------------------------------
-- DEALING WITH TABLE val_auth_resource
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_auth_resource', 'val_auth_resource');

-- FOREIGN KEYS FROM
ALTER TABLE account_auth_log DROP CONSTRAINT IF EXISTS fk_auth_resource;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_auth_resource');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_auth_resource DROP CONSTRAINT IF EXISTS pk_val_auth_resource;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_auth_resource ON jazzhands.val_auth_resource;
DROP TRIGGER IF EXISTS trigger_audit_val_auth_resource ON jazzhands.val_auth_resource;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_auth_resource');
---- BEGIN audit.val_auth_resource TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_auth_resource', 'val_auth_resource');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_auth_resource');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.val_auth_resource DROP CONSTRAINT IF EXISTS val_auth_resource_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_val_auth_resource_pk_val_auth_resource";
DROP INDEX IF EXISTS "audit"."val_auth_resource_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."val_auth_resource_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."val_auth_resource_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.val_auth_resource TEARDOWN


ALTER TABLE val_auth_resource RENAME TO val_auth_resource_v84;
ALTER TABLE audit.val_auth_resource RENAME TO val_auth_resource_v84;

CREATE TABLE jazzhands.val_auth_resource
(
	auth_resource	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_auth_resource', false);
INSERT INTO val_auth_resource (
	auth_resource,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	auth_resource,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_auth_resource_v84;

INSERT INTO audit.val_auth_resource (
	auth_resource,
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
	auth_resource,
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
FROM audit.val_auth_resource_v84;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_auth_resource ADD CONSTRAINT pk_val_auth_resource PRIMARY KEY (auth_resource);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_auth_resource and account_auth_log
ALTER TABLE jazzhands.account_auth_log
	ADD CONSTRAINT fk_auth_resource
	FOREIGN KEY (auth_resource) REFERENCES val_auth_resource(auth_resource);

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_auth_resource');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'val_auth_resource');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_auth_resource');
DROP TABLE IF EXISTS val_auth_resource_v84;
DROP TABLE IF EXISTS audit.val_auth_resource_v84;
-- DONE DEALING WITH TABLE val_auth_resource
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_property
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_property', 'val_property');

-- FOREIGN KEYS FROM
ALTER TABLE property_collection_property DROP CONSTRAINT IF EXISTS fk_prop_col_propnamtyp;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_nmtyp;
ALTER TABLE val_property_value DROP CONSTRAINT IF EXISTS fk_valproval_namtyp;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_prop_svcemvcoll_type;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_prop_val_devcol_typ_rstr_dc;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_prop_val_devcoll_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_prop_acct_coll_type;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_prop_comp_coll_type;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_prop_l2netype;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_prop_l3netwok_type;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_prop_nblk_coll_type;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_property_dnsdomcolltype;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_property_netblkcolltype;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valnetrng_val_prop;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_propdttyp;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_proptyp;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_pv_actyp_rst;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_vla_property_val_propcollty;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_property');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS pk_val_property;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif10val_property";
DROP INDEX IF EXISTS "jazzhands"."xif11val_property";
DROP INDEX IF EXISTS "jazzhands"."xif12val_property";
DROP INDEX IF EXISTS "jazzhands"."xif13val_property";
DROP INDEX IF EXISTS "jazzhands"."xif14val_property";
DROP INDEX IF EXISTS "jazzhands"."xif15val_property";
DROP INDEX IF EXISTS "jazzhands"."xif1val_property";
DROP INDEX IF EXISTS "jazzhands"."xif2val_property";
DROP INDEX IF EXISTS "jazzhands"."xif3val_property";
DROP INDEX IF EXISTS "jazzhands"."xif4val_property";
DROP INDEX IF EXISTS "jazzhands"."xif5val_property";
DROP INDEX IF EXISTS "jazzhands"."xif6val_property";
DROP INDEX IF EXISTS "jazzhands"."xif7val_property";
DROP INDEX IF EXISTS "jazzhands"."xif8val_property";
DROP INDEX IF EXISTS "jazzhands"."xif9val_property";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1494616001;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1664370664;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1804972034;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_185689986;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_185755522;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_2016888554;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_2139007167;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_271462566;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_354296970;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_366948481;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_606225804;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_cmp_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_ismulti;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_osid;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pacct_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pdevcol_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_prodstate;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pucls_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_sitec;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_property ON jazzhands.val_property;
DROP TRIGGER IF EXISTS trigger_audit_val_property ON jazzhands.val_property;
DROP TRIGGER IF EXISTS trigger_validate_val_property ON jazzhands.val_property;
DROP TRIGGER IF EXISTS trigger_validate_val_property_after ON jazzhands.val_property;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_property');
---- BEGIN audit.val_property TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_property', 'val_property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_property');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.val_property DROP CONSTRAINT IF EXISTS val_property_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_val_property_pk_val_property";
DROP INDEX IF EXISTS "audit"."val_property_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."val_property_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."val_property_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.val_property TEARDOWN


ALTER TABLE val_property RENAME TO val_property_v84;
ALTER TABLE audit.val_property RENAME TO val_property_v84;

CREATE TABLE jazzhands.val_property
(
	property_name	varchar(255) NOT NULL,
	property_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	account_collection_type	varchar(50)  NULL,
	company_collection_type	varchar(50)  NULL,
	device_collection_type	varchar(50)  NULL,
	dns_domain_collection_type	varchar(50)  NULL,
	layer2_network_collection_type	varchar(50)  NULL,
	layer3_network_collection_type	varchar(50)  NULL,
	netblock_collection_type	varchar(50)  NULL,
	network_range_type	varchar(50)  NULL,
	property_collection_type	varchar(50)  NULL,
	service_env_collection_type	varchar(50)  NULL,
	is_multivalue	character(1) NOT NULL,
	prop_val_acct_coll_type_rstrct	varchar(50)  NULL,
	prop_val_dev_coll_type_rstrct	varchar(50)  NULL,
	prop_val_nblk_coll_type_rstrct	varchar(50)  NULL,
	property_data_type	varchar(50) NOT NULL,
	property_value_json_schema	jsonb  NULL,
	permit_account_collection_id	character(10) NOT NULL,
	permit_account_id	character(10) NOT NULL,
	permit_account_realm_id	character(10) NOT NULL,
	permit_company_id	character(10) NOT NULL,
	permit_company_collection_id	character(10) NOT NULL,
	permit_device_collection_id	character(10) NOT NULL,
	permit_dns_domain_coll_id	character(10) NOT NULL,
	permit_layer2_network_coll_id	character(10) NOT NULL,
	permit_layer3_network_coll_id	character(10) NOT NULL,
	permit_netblock_collection_id	character(10) NOT NULL,
	permit_network_range_id	character(10) NOT NULL,
	permit_operating_system_id	character(10) NOT NULL,
	permit_os_snapshot_id	character(10) NOT NULL,
	permit_person_id	character(10) NOT NULL,
	permit_property_collection_id	character(10) NOT NULL,
	permit_service_env_collection	character(10) NOT NULL,
	permit_site_code	character(10) NOT NULL,
	permit_x509_signed_cert_id	character(10) NOT NULL,
	permit_property_rank	character(10) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_property', false);
ALTER TABLE val_property
	ALTER is_multivalue
	SET DEFAULT 'N'::bpchar;
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
	ALTER permit_company_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_device_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_dns_domain_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer2_network_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer3_network_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_netblock_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_network_range_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_operating_system_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_os_snapshot_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_person_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_property_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_service_env_collection
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_site_code
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_x509_signed_cert_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_property_rank
	SET DEFAULT 'PROHIBITED'::bpchar;
INSERT INTO val_property (
	property_name,
	property_type,
	description,
	account_collection_type,
	company_collection_type,
	device_collection_type,
	dns_domain_collection_type,
	layer2_network_collection_type,
	layer3_network_collection_type,
	netblock_collection_type,
	network_range_type,
	property_collection_type,
	service_env_collection_type,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	property_value_json_schema,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,
	permit_device_collection_id,
	permit_dns_domain_coll_id,
	permit_layer2_network_coll_id,
	permit_layer3_network_coll_id,
	permit_netblock_collection_id,
	permit_network_range_id,
	permit_operating_system_id,
	permit_os_snapshot_id,
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	permit_x509_signed_cert_id,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	property_name,
	property_type,
	description,
	account_collection_type,
	company_collection_type,
	device_collection_type,
	dns_domain_collection_type,
	layer2_network_collection_type,
	layer3_network_collection_type,
	netblock_collection_type,
	network_range_type,
	property_collection_type,
	service_env_collection_type,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	property_value_json_schema,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,
	permit_device_collection_id,
	permit_dns_domain_coll_id,
	permit_layer2_network_coll_id,
	permit_layer3_network_coll_id,
	permit_netblock_collection_id,
	permit_network_range_id,
	permit_operating_system_id,
	permit_os_snapshot_id,
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	permit_x509_signed_cert_id,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_property_v84;

INSERT INTO audit.val_property (
	property_name,
	property_type,
	description,
	account_collection_type,
	company_collection_type,
	device_collection_type,
	dns_domain_collection_type,
	layer2_network_collection_type,
	layer3_network_collection_type,
	netblock_collection_type,
	network_range_type,
	property_collection_type,
	service_env_collection_type,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	property_value_json_schema,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,
	permit_device_collection_id,
	permit_dns_domain_coll_id,
	permit_layer2_network_coll_id,
	permit_layer3_network_coll_id,
	permit_netblock_collection_id,
	permit_network_range_id,
	permit_operating_system_id,
	permit_os_snapshot_id,
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	permit_x509_signed_cert_id,
	permit_property_rank,
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
	property_name,
	property_type,
	description,
	account_collection_type,
	company_collection_type,
	device_collection_type,
	dns_domain_collection_type,
	layer2_network_collection_type,
	layer3_network_collection_type,
	netblock_collection_type,
	network_range_type,
	property_collection_type,
	service_env_collection_type,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	property_value_json_schema,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,
	permit_device_collection_id,
	permit_dns_domain_coll_id,
	permit_layer2_network_coll_id,
	permit_layer3_network_coll_id,
	permit_netblock_collection_id,
	permit_network_range_id,
	permit_operating_system_id,
	permit_os_snapshot_id,
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	permit_x509_signed_cert_id,
	permit_property_rank,
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
FROM audit.val_property_v84;

ALTER TABLE jazzhands.val_property
	ALTER is_multivalue
	SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_account_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_account_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_account_realm_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_company_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_company_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_device_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_dns_domain_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_layer2_network_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_layer3_network_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_netblock_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_network_range_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_operating_system_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_os_snapshot_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_person_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_property_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_service_env_collection
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_site_code
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_x509_signed_cert_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_property_rank
	SET DEFAULT 'PROHIBITED'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_property ADD CONSTRAINT pk_val_property PRIMARY KEY (property_name, property_type);

-- Table/Column Comments
COMMENT ON TABLE jazzhands.val_property IS 'valid values and attributes for (name,type) pairs in the property table.  This defines how triggers enforce aspects of the property table';
COMMENT ON COLUMN jazzhands.val_property.property_name IS 'property name for validation purposes';
COMMENT ON COLUMN jazzhands.val_property.property_type IS 'property type for validation purposes';
COMMENT ON COLUMN jazzhands.val_property.account_collection_type IS 'type restriction of the account_collection_id on LHS';
COMMENT ON COLUMN jazzhands.val_property.company_collection_type IS 'type restriction of company_collection_id on LHS';
COMMENT ON COLUMN jazzhands.val_property.device_collection_type IS 'type restriction of device_collection_id on LHS';
COMMENT ON COLUMN jazzhands.val_property.dns_domain_collection_type IS 'type restriction of dns_domain_collection_id restriction on LHS';
COMMENT ON COLUMN jazzhands.val_property.netblock_collection_type IS 'type restriction of netblock_collection_id on LHS';
COMMENT ON COLUMN jazzhands.val_property.property_collection_type IS 'type restriction of property_collection_id on LHS';
COMMENT ON COLUMN jazzhands.val_property.service_env_collection_type IS 'type restriction of service_enviornment_collection_id on LHS';
COMMENT ON COLUMN jazzhands.val_property.is_multivalue IS 'If N, acts like an alternate key on property.(lhs,property_name,property_type)';
COMMENT ON COLUMN jazzhands.val_property.prop_val_acct_coll_type_rstrct IS 'if property_value is account_collection_Id, this limits the account_collection_types that can be used in that column.';
COMMENT ON COLUMN jazzhands.val_property.prop_val_dev_coll_type_rstrct IS 'if property_value is devicet_collection_Id, this limits the devicet_collection_types that can be used in that column.';
COMMENT ON COLUMN jazzhands.val_property.prop_val_nblk_coll_type_rstrct IS 'if property_value isnetblockt_collection_Id, this limits the netblockt_collection_types that can be used in that column.';
COMMENT ON COLUMN jazzhands.val_property.property_data_type IS 'which, if any, of the property_table_* columns should be used for this value.   May turn more complex enforcement via trigger';
COMMENT ON COLUMN jazzhands.val_property.permit_account_collection_id IS 'defines permissibility/requirement of account_collection_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_account_id IS 'defines permissibility/requirement of account_idon LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_account_realm_id IS 'defines permissibility/requirement of account_realm_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_company_id IS 'defines permissibility/requirement of company_id on LHS of property.  *NOTE*  THIS COLUMN WILL BE REMOVED IN >0.65';
COMMENT ON COLUMN jazzhands.val_property.permit_company_collection_id IS 'defines permissibility/requirement of company_collection_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_device_collection_id IS 'defines permissibility/requirement of device_collection_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_dns_domain_coll_id IS 'defines permissibility/requirement of dns_domain_collection_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_layer2_network_coll_id IS 'defines permissibility/requirement of layer2_network_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_layer3_network_coll_id IS 'defines permissibility/requirement of layer3_network_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_netblock_collection_id IS 'defines permissibility/requirement of netblock_collection_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_operating_system_id IS 'defines permissibility/requirement of operating_system_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_os_snapshot_id IS 'defines permissibility/requirement of operating_system_snapshot_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_person_id IS 'defines permissibility/requirement of person_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_property_collection_id IS 'defines permissibility/requirement of property_collection_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_service_env_collection IS 'defines permissibility/requirement of service_env_collection_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_site_code IS 'defines permissibility/requirement of site_code on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_property_rank IS 'defines permissibility of property_rank, and if it should be part of the "lhs" of the given property';
-- INDEXES
CREATE INDEX xif10val_property ON val_property USING btree (netblock_collection_type);
CREATE INDEX xif11val_property ON val_property USING btree (property_collection_type);
CREATE INDEX xif12val_property ON val_property USING btree (service_env_collection_type);
CREATE INDEX xif13val_property ON val_property USING btree (layer3_network_collection_type);
CREATE INDEX xif14val_property ON val_property USING btree (layer2_network_collection_type);
CREATE INDEX xif15val_property ON val_property USING btree (network_range_type);
CREATE INDEX xif1val_property ON val_property USING btree (property_data_type);
CREATE INDEX xif2val_property ON val_property USING btree (property_type);
CREATE INDEX xif3val_property ON val_property USING btree (prop_val_acct_coll_type_rstrct);
CREATE INDEX xif4val_property ON val_property USING btree (prop_val_nblk_coll_type_rstrct);
CREATE INDEX xif5val_property ON val_property USING btree (prop_val_dev_coll_type_rstrct);
CREATE INDEX xif6val_property ON val_property USING btree (account_collection_type);
CREATE INDEX xif7val_property ON val_property USING btree (company_collection_type);
CREATE INDEX xif8val_property ON val_property USING btree (device_collection_type);
CREATE INDEX xif9val_property ON val_property USING btree (dns_domain_collection_type);

-- CHECK CONSTRAINTS
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_101782678
	CHECK (permit_device_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_1494616001
	CHECK (permit_dns_domain_coll_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_165332314
	CHECK (permit_service_env_collection = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_1664370664
	CHECK (permit_network_range_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_172970668
	CHECK (permit_company_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_1804972034
	CHECK (permit_os_snapshot_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_185689986
	CHECK (permit_layer2_network_coll_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_185755522
	CHECK (permit_layer3_network_coll_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_2016888554
	CHECK (permit_account_realm_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_2139007167
	CHECK (permit_property_rank = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_271462566
	CHECK (permit_property_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_288767614
	CHECK (permit_site_code = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_351347826
	CHECK (permit_account_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_354296970
	CHECK (permit_netblock_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_366948481
	CHECK (permit_company_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_474170283
	CHECK (permit_account_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_606225804
	CHECK (permit_person_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_943979943
	CHECK (permit_x509_signed_cert_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_yes_no_1460215299
	CHECK (is_multivalue = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT ckc_val_prop_osid
	CHECK (permit_operating_system_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK between val_property and property_collection_property
ALTER TABLE jazzhands.property_collection_property
	ADD CONSTRAINT fk_prop_col_propnamtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
-- consider FK between val_property and property
ALTER TABLE jazzhands.property
	ADD CONSTRAINT fk_property_nmtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
-- consider FK between val_property and val_property_value
ALTER TABLE jazzhands.val_property_value
	ADD CONSTRAINT fk_valproval_namtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);

-- FOREIGN KEYS TO
-- consider FK val_property and val_service_env_coll_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_prop_svcemvcoll_type
	FOREIGN KEY (service_env_collection_type) REFERENCES val_service_env_coll_type(service_env_collection_type);
-- consider FK val_property and val_device_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_prop_val_devcol_typ_rstr_dc
	FOREIGN KEY (prop_val_dev_coll_type_rstrct) REFERENCES val_device_collection_type(device_collection_type);
-- consider FK val_property and val_device_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_prop_val_devcoll_id
	FOREIGN KEY (device_collection_type) REFERENCES val_device_collection_type(device_collection_type);
-- consider FK val_property and val_account_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_val_prop_acct_coll_type
	FOREIGN KEY (account_collection_type) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK val_property and val_company_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_val_prop_comp_coll_type
	FOREIGN KEY (company_collection_type) REFERENCES val_company_collection_type(company_collection_type);
-- consider FK val_property and val_layer2_network_coll_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_val_prop_l2netype
	FOREIGN KEY (layer2_network_collection_type) REFERENCES val_layer2_network_coll_type(layer2_network_collection_type);
-- consider FK val_property and val_layer3_network_coll_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_val_prop_l3netwok_type
	FOREIGN KEY (layer3_network_collection_type) REFERENCES val_layer3_network_coll_type(layer3_network_collection_type);
-- consider FK val_property and val_netblock_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_val_prop_nblk_coll_type
	FOREIGN KEY (prop_val_nblk_coll_type_rstrct) REFERENCES val_netblock_collection_type(netblock_collection_type);
-- consider FK val_property and val_dns_domain_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_val_property_dnsdomcolltype
	FOREIGN KEY (dns_domain_collection_type) REFERENCES val_dns_domain_collection_type(dns_domain_collection_type);
-- consider FK val_property and val_netblock_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_val_property_netblkcolltype
	FOREIGN KEY (netblock_collection_type) REFERENCES val_netblock_collection_type(netblock_collection_type);
-- consider FK val_property and val_network_range_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_valnetrng_val_prop
	FOREIGN KEY (network_range_type) REFERENCES val_network_range_type(network_range_type);
-- consider FK val_property and val_property_data_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_valprop_propdttyp
	FOREIGN KEY (property_data_type) REFERENCES val_property_data_type(property_data_type);
-- consider FK val_property and val_property_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_valprop_proptyp
	FOREIGN KEY (property_type) REFERENCES val_property_type(property_type);
-- consider FK val_property and val_account_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_valprop_pv_actyp_rst
	FOREIGN KEY (prop_val_acct_coll_type_rstrct) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK val_property and val_property_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_vla_property_val_propcolltype
	FOREIGN KEY (property_collection_type) REFERENCES val_property_collection_type(property_collection_type);

-- TRIGGERS
-- consider NEW jazzhands.validate_val_property
CREATE OR REPLACE FUNCTION jazzhands.validate_val_property()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	IF NEW.property_data_type = 'json' AND NEW.property_value_json_schema IS NULL THEN
		RAISE 'property_data_type json requires a schema to be set'
			USING ERRCODE = 'invalid_parameter_value';
	ELSIF NEW.property_data_type != 'json' AND NEW.property_value_json_schema IS NOT NULL THEN
		RAISE 'property_data_type % may not have a json schema set',
			NEW.property_data_type
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF TG_OP = 'UPDATE' AND OLD.property_data_type != NEW.property_data_type THEN
		SELECT	count(*)
		INTO	_tally
		WHERE	property_name = NEW.property_name
		AND		property_type = NEW.property_type;

		IF _tally > 0  THEN
			RAISE 'May not change property type if there are existing proeprties'
				USING ERRCODE = 'foreign_key_violation';

		END IF;
	END IF;

	IF TG_OP = 'INSERT' AND NEW.permit_company_id != 'PROHIBITED' OR
		( TG_OP = 'UPDATE' AND NEW.permit_company_id != 'PROHIBITED' AND
			OLD.permit_company_id IS DISTINCT FROM NEW.permit_company_id )
	THEN
		RAISE 'property.company_id is being retired.  Please use per-company collections'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_validate_val_property BEFORE INSERT OR UPDATE OF property_data_type, property_value_json_schema, permit_company_id ON val_property FOR EACH ROW EXECUTE PROCEDURE validate_val_property();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.validate_val_property_after
CREATE OR REPLACE FUNCTION jazzhands.validate_val_property_after()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_r	property%ROWTYPE;
BEGIN
	FOR _r IN SELECT * FROM property
		WHERE property_name = NEW.property_name
		AND property_type = NEW.property_type
	LOOP
		PERFORM property_utils.validate_property(_r);
	END LOOP;
	RETURN NEW;
END;
$function$
;
CREATE CONSTRAINT TRIGGER trigger_validate_val_property_after AFTER UPDATE ON val_property DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE validate_val_property_after();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_property');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'val_property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_property');
DROP TABLE IF EXISTS val_property_v84;
DROP TABLE IF EXISTS audit.val_property_v84;
-- DONE DEALING WITH TABLE val_property
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_ssh_key_type
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_ssh_key_type', 'val_ssh_key_type');

-- FOREIGN KEYS FROM
ALTER TABLE ssh_key DROP CONSTRAINT IF EXISTS fk_ssh_key_ssh_key_type;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_ssh_key_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_ssh_key_type DROP CONSTRAINT IF EXISTS pk_val_ssh_key_type;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_ssh_key_type ON jazzhands.val_ssh_key_type;
DROP TRIGGER IF EXISTS trigger_audit_val_ssh_key_type ON jazzhands.val_ssh_key_type;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_ssh_key_type');
---- BEGIN audit.val_ssh_key_type TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_ssh_key_type', 'val_ssh_key_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_ssh_key_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.val_ssh_key_type DROP CONSTRAINT IF EXISTS val_ssh_key_type_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_val_ssh_key_type_pk_val_ssh_key_type";
DROP INDEX IF EXISTS "audit"."val_ssh_key_type_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."val_ssh_key_type_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."val_ssh_key_type_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.val_ssh_key_type TEARDOWN


ALTER TABLE val_ssh_key_type RENAME TO val_ssh_key_type_v84;
ALTER TABLE audit.val_ssh_key_type RENAME TO val_ssh_key_type_v84;

CREATE TABLE jazzhands.val_ssh_key_type
(
	ssh_key_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_ssh_key_type', false);
INSERT INTO val_ssh_key_type (
	ssh_key_type,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	ssh_key_type,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_ssh_key_type_v84;

INSERT INTO audit.val_ssh_key_type (
	ssh_key_type,
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
	ssh_key_type,
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
FROM audit.val_ssh_key_type_v84;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_ssh_key_type ADD CONSTRAINT pk_val_ssh_key_type PRIMARY KEY (ssh_key_type);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_ssh_key_type and ssh_key
ALTER TABLE jazzhands.ssh_key
	ADD CONSTRAINT fk_ssh_key_ssh_key_type
	FOREIGN KEY (ssh_key_type) REFERENCES val_ssh_key_type(ssh_key_type);

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_ssh_key_type');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'val_ssh_key_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_ssh_key_type');
DROP TABLE IF EXISTS val_ssh_key_type_v84;
DROP TABLE IF EXISTS audit.val_ssh_key_type_v84;
-- DONE DEALING WITH TABLE val_ssh_key_type
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE appaal_instance_property
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'appaal_instance_property', 'appaal_instance_property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.appaal_instance_property DROP CONSTRAINT IF EXISTS fk_allgrpprop_val_name;
ALTER TABLE jazzhands.appaal_instance_property DROP CONSTRAINT IF EXISTS fk_apalinstprp_enc_id_id;
ALTER TABLE jazzhands.appaal_instance_property DROP CONSTRAINT IF EXISTS fk_appaalins_ref_appaalinsprop;
ALTER TABLE jazzhands.appaal_instance_property DROP CONSTRAINT IF EXISTS fk_appaalinstprop_ref_vappkey;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'appaal_instance_property');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.appaal_instance_property DROP CONSTRAINT IF EXISTS ak_appaal_instance_idkeyrank;
ALTER TABLE jazzhands.appaal_instance_property DROP CONSTRAINT IF EXISTS pk_appaal_instance_property;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."ind_aaiprop_key_value";
DROP INDEX IF EXISTS "jazzhands"."xif4appaal_instance_property";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_appaal_instance_property ON jazzhands.appaal_instance_property;
DROP TRIGGER IF EXISTS trigger_audit_appaal_instance_property ON jazzhands.appaal_instance_property;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'appaal_instance_property');
---- BEGIN audit.appaal_instance_property TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'appaal_instance_property', 'appaal_instance_property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'appaal_instance_property');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.appaal_instance_property DROP CONSTRAINT IF EXISTS appaal_instance_property_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."appaal_instance_property_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."appaal_instance_property_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."appaal_instance_property_aud#txid_idx";
DROP INDEX IF EXISTS "audit"."aud_appaal_instance_property_ak_appaal_instance_idkeyrank";
DROP INDEX IF EXISTS "audit"."aud_appaal_instance_property_pk_appaal_instance_property";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.appaal_instance_property TEARDOWN


ALTER TABLE appaal_instance_property RENAME TO appaal_instance_property_v84;
ALTER TABLE audit.appaal_instance_property RENAME TO appaal_instance_property_v84;

CREATE TABLE jazzhands.appaal_instance_property
(
	appaal_instance_id	integer NOT NULL,
	app_key	varchar(50) NOT NULL,
	appaal_group_name	varchar(50) NOT NULL,
	appaal_group_rank	varchar(50) NOT NULL,
	app_value	varchar(4000) NOT NULL,
	encryption_key_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'appaal_instance_property', false);
INSERT INTO appaal_instance_property (
	appaal_instance_id,
	app_key,
	appaal_group_name,
	appaal_group_rank,
	app_value,
	encryption_key_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	appaal_instance_id,
	app_key,
	appaal_group_name,
	appaal_group_rank,
	app_value,
	encryption_key_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM appaal_instance_property_v84;

INSERT INTO audit.appaal_instance_property (
	appaal_instance_id,
	app_key,
	appaal_group_name,
	appaal_group_rank,
	app_value,
	encryption_key_id,
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
	appaal_instance_id,
	app_key,
	appaal_group_name,
	appaal_group_rank,
	app_value,
	encryption_key_id,
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
FROM audit.appaal_instance_property_v84;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.appaal_instance_property ADD CONSTRAINT ak_appaal_instance_idkeyrank UNIQUE (appaal_instance_id, app_key, appaal_group_rank);
ALTER TABLE jazzhands.appaal_instance_property ADD CONSTRAINT pk_appaal_instance_property PRIMARY KEY (appaal_instance_id, app_key, appaal_group_name, appaal_group_rank);

-- Table/Column Comments
COMMENT ON COLUMN jazzhands.appaal_instance_property.encryption_key_id IS 'encryption information for app_value, if used';
-- INDEXES
CREATE INDEX ind_aaiprop_key_value ON appaal_instance_property USING btree (app_key, app_value);
CREATE INDEX xif4appaal_instance_property ON appaal_instance_property USING btree (appaal_group_name);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK appaal_instance_property and val_appaal_group_name
ALTER TABLE jazzhands.appaal_instance_property
	ADD CONSTRAINT fk_allgrpprop_val_name
	FOREIGN KEY (appaal_group_name) REFERENCES val_appaal_group_name(appaal_group_name);
-- consider FK appaal_instance_property and encryption_key
ALTER TABLE jazzhands.appaal_instance_property
	ADD CONSTRAINT fk_apalinstprp_enc_id_id
	FOREIGN KEY (encryption_key_id) REFERENCES encryption_key(encryption_key_id);
-- consider FK appaal_instance_property and appaal_instance
ALTER TABLE jazzhands.appaal_instance_property
	ADD CONSTRAINT fk_appaalins_ref_appaalinsprop
	FOREIGN KEY (appaal_instance_id) REFERENCES appaal_instance(appaal_instance_id);
-- consider FK appaal_instance_property and val_app_key
ALTER TABLE jazzhands.appaal_instance_property
	ADD CONSTRAINT fk_appaalinstprop_ref_vappkey
	FOREIGN KEY (appaal_group_name, app_key) REFERENCES val_app_key(appaal_group_name, app_key);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'appaal_instance_property');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'appaal_instance_property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'appaal_instance_property');
DROP TABLE IF EXISTS appaal_instance_property_v84;
DROP TABLE IF EXISTS audit.appaal_instance_property_v84;
-- DONE DEALING WITH TABLE appaal_instance_property
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE approval_process
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'approval_process', 'approval_process');

-- FOREIGN KEYS FROM
ALTER TABLE approval_instance DROP CONSTRAINT IF EXISTS fk_approval_proc_inst_aproc_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.approval_process DROP CONSTRAINT IF EXISTS fk_app_prc_propcoll_id;
ALTER TABLE jazzhands.approval_process DROP CONSTRAINT IF EXISTS fk_app_proc_1st_app_proc_chnid;
ALTER TABLE jazzhands.approval_process DROP CONSTRAINT IF EXISTS fk_app_proc_app_proc_typ;
ALTER TABLE jazzhands.approval_process DROP CONSTRAINT IF EXISTS fk_app_proc_expire_action;
ALTER TABLE jazzhands.approval_process DROP CONSTRAINT IF EXISTS fk_appproc_attest_freq;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'approval_process');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.approval_process DROP CONSTRAINT IF EXISTS pk_approval_process;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1approval_process";
DROP INDEX IF EXISTS "jazzhands"."xif2approval_process";
DROP INDEX IF EXISTS "jazzhands"."xif3approval_process";
DROP INDEX IF EXISTS "jazzhands"."xif4approval_process";
DROP INDEX IF EXISTS "jazzhands"."xif5approval_process";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_approval_process ON jazzhands.approval_process;
DROP TRIGGER IF EXISTS trigger_audit_approval_process ON jazzhands.approval_process;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'approval_process');
---- BEGIN audit.approval_process TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'approval_process', 'approval_process');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'approval_process');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.approval_process DROP CONSTRAINT IF EXISTS approval_process_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."approval_process_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."approval_process_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."approval_process_aud#txid_idx";
DROP INDEX IF EXISTS "audit"."aud_approval_process_pk_approval_process";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.approval_process TEARDOWN


ALTER TABLE approval_process RENAME TO approval_process_v84;
ALTER TABLE audit.approval_process RENAME TO approval_process_v84;

CREATE TABLE jazzhands.approval_process
(
	approval_process_id	integer NOT NULL,
	approval_process_name	varchar(50) NOT NULL,
	approval_process_type	varchar(50)  NULL,
	description	varchar(255)  NULL,
	first_apprvl_process_chain_id	integer NOT NULL,
	property_collection_id	integer NOT NULL,
	approval_expiration_action	varchar(50) NOT NULL,
	attestation_frequency	varchar(50)  NULL,
	attestation_offset	integer  NULL,
	max_escalation_level	integer  NULL,
	escalation_delay	varchar(50)  NULL,
	escalation_reminder_gap	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'approval_process', false);
ALTER TABLE approval_process
	ALTER approval_process_id
	SET DEFAULT nextval('approval_process_approval_process_id_seq'::regclass);
INSERT INTO approval_process (
	approval_process_id,
	approval_process_name,
	approval_process_type,
	description,
	first_apprvl_process_chain_id,
	property_collection_id,
	approval_expiration_action,
	attestation_frequency,
	attestation_offset,
	max_escalation_level,
	escalation_delay,
	escalation_reminder_gap,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	approval_process_id,
	approval_process_name,
	approval_process_type,
	description,
	first_apprvl_process_chain_id,
	property_collection_id,
	approval_expiration_action,
	attestation_frequency,
	attestation_offset,
	max_escalation_level,
	escalation_delay,
	escalation_reminder_gap,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM approval_process_v84;

INSERT INTO audit.approval_process (
	approval_process_id,
	approval_process_name,
	approval_process_type,
	description,
	first_apprvl_process_chain_id,
	property_collection_id,
	approval_expiration_action,
	attestation_frequency,
	attestation_offset,
	max_escalation_level,
	escalation_delay,
	escalation_reminder_gap,
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
	approval_process_id,
	approval_process_name,
	approval_process_type,
	description,
	first_apprvl_process_chain_id,
	property_collection_id,
	approval_expiration_action,
	attestation_frequency,
	attestation_offset,
	max_escalation_level,
	escalation_delay,
	escalation_reminder_gap,
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
FROM audit.approval_process_v84;

ALTER TABLE jazzhands.approval_process
	ALTER approval_process_id
	SET DEFAULT nextval('approval_process_approval_process_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.approval_process ADD CONSTRAINT pk_approval_process PRIMARY KEY (approval_process_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1approval_process ON approval_process USING btree (property_collection_id);
CREATE INDEX xif2approval_process ON approval_process USING btree (approval_process_type);
CREATE INDEX xif3approval_process ON approval_process USING btree (approval_expiration_action);
CREATE INDEX xif4approval_process ON approval_process USING btree (attestation_frequency);
CREATE INDEX xif5approval_process ON approval_process USING btree (first_apprvl_process_chain_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between approval_process and approval_instance
ALTER TABLE jazzhands.approval_instance
	ADD CONSTRAINT fk_approval_proc_inst_aproc_id
	FOREIGN KEY (approval_process_id) REFERENCES approval_process(approval_process_id);

-- FOREIGN KEYS TO
-- consider FK approval_process and property_collection
ALTER TABLE jazzhands.approval_process
	ADD CONSTRAINT fk_app_prc_propcoll_id
	FOREIGN KEY (property_collection_id) REFERENCES property_collection(property_collection_id);
-- consider FK approval_process and approval_process_chain
ALTER TABLE jazzhands.approval_process
	ADD CONSTRAINT fk_app_proc_1st_app_proc_chnid
	FOREIGN KEY (first_apprvl_process_chain_id) REFERENCES approval_process_chain(approval_process_chain_id);
-- consider FK approval_process and val_approval_process_type
ALTER TABLE jazzhands.approval_process
	ADD CONSTRAINT fk_app_proc_app_proc_typ
	FOREIGN KEY (approval_process_type) REFERENCES val_approval_process_type(approval_process_type);
-- consider FK approval_process and val_approval_expiration_action
ALTER TABLE jazzhands.approval_process
	ADD CONSTRAINT fk_app_proc_expire_action
	FOREIGN KEY (approval_expiration_action) REFERENCES val_approval_expiration_action(approval_expiration_action);
-- consider FK approval_process and val_attestation_frequency
ALTER TABLE jazzhands.approval_process
	ADD CONSTRAINT fk_appproc_attest_freq
	FOREIGN KEY (attestation_frequency) REFERENCES val_attestation_frequency(attestation_frequency);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'approval_process');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'approval_process');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'approval_process');
ALTER SEQUENCE approval_process_approval_process_id_seq
	 OWNED BY approval_process.approval_process_id;
DROP TABLE IF EXISTS approval_process_v84;
DROP TABLE IF EXISTS audit.approval_process_v84;
-- DONE DEALING WITH TABLE approval_process
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE device_type
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_type', 'device_type');

-- FOREIGN KEYS FROM
ALTER TABLE chassis_location DROP CONSTRAINT IF EXISTS fk_chass_loc_mod_dev_typ_id;
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_dev_devtp_id;
ALTER TABLE device_type_module DROP CONSTRAINT IF EXISTS fk_devt_mod_dev_type_id;
ALTER TABLE device_type_module_device_type DROP CONSTRAINT IF EXISTS fk_dt_mod_dev_type_mod_dtid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS fk_dev_typ_idealized_dev_id;
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS fk_dev_typ_tmplt_dev_typ_id;
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS fk_device_t_fk_device_val_proc;
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS fk_devtyp_company;
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS fk_fevtyp_component_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'device_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS pk_device_type;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif4device_type";
DROP INDEX IF EXISTS "jazzhands"."xif_dev_typ_idealized_dev_id";
DROP INDEX IF EXISTS "jazzhands"."xif_dev_typ_tmplt_dev_typ_id";
DROP INDEX IF EXISTS "jazzhands"."xif_fevtyp_component_id";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS ckc_devtyp_ischs;
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS ckc_has_802_11_interf_device_t;
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS ckc_has_802_3_interfa_device_t;
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS ckc_snmp_capable_device_t;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_device_type ON jazzhands.device_type;
DROP TRIGGER IF EXISTS trigger_audit_device_type ON jazzhands.device_type;
DROP TRIGGER IF EXISTS trigger_device_type_chassis_check ON jazzhands.device_type;
DROP TRIGGER IF EXISTS trigger_device_type_model_to_name ON jazzhands.device_type;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'device_type');
---- BEGIN audit.device_type TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'device_type', 'device_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'device_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.device_type DROP CONSTRAINT IF EXISTS device_type_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_device_type_pk_device_type";
DROP INDEX IF EXISTS "audit"."device_type_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."device_type_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."device_type_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.device_type TEARDOWN


ALTER TABLE device_type RENAME TO device_type_v84;
ALTER TABLE audit.device_type RENAME TO device_type_v84;

CREATE TABLE jazzhands.device_type
(
	device_type_id	integer NOT NULL,
	component_type_id	integer  NULL,
	device_type_name	varchar(50) NOT NULL,
	template_device_id	integer  NULL,
	idealized_device_id	integer  NULL,
	description	varchar(4000)  NULL,
	company_id	integer  NULL,
	model	varchar(255) NOT NULL,
	device_type_depth_in_cm	varchar(50)  NULL,
	processor_architecture	varchar(50)  NULL,
	config_fetch_type	varchar(50)  NULL,
	rack_units	integer  NULL,
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
ALTER TABLE device_type
	ALTER device_type_id
	SET DEFAULT nextval('device_type_device_type_id_seq'::regclass);
ALTER TABLE device_type
	ALTER has_802_3_interface
	SET DEFAULT 'N'::bpchar;
ALTER TABLE device_type
	ALTER has_802_11_interface
	SET DEFAULT 'N'::bpchar;
ALTER TABLE device_type
	ALTER snmp_capable
	SET DEFAULT 'N'::bpchar;
ALTER TABLE device_type
	ALTER is_chassis
	SET DEFAULT 'N'::bpchar;
INSERT INTO device_type (
	device_type_id,
	component_type_id,
	device_type_name,
	template_device_id,
	idealized_device_id,
	description,
	company_id,
	model,
	device_type_depth_in_cm,
	processor_architecture,
	config_fetch_type,
	rack_units,
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
	component_type_id,
	device_type_name,
	template_device_id,
	idealized_device_id,
	description,
	company_id,
	model,
	device_type_depth_in_cm,
	processor_architecture,
	config_fetch_type,
	rack_units,
	has_802_3_interface,
	has_802_11_interface,
	snmp_capable,
	is_chassis,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM device_type_v84;

INSERT INTO audit.device_type (
	device_type_id,
	component_type_id,
	device_type_name,
	template_device_id,
	idealized_device_id,
	description,
	company_id,
	model,
	device_type_depth_in_cm,
	processor_architecture,
	config_fetch_type,
	rack_units,
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
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
) SELECT
	device_type_id,
	component_type_id,
	device_type_name,
	template_device_id,
	idealized_device_id,
	description,
	company_id,
	model,
	device_type_depth_in_cm,
	processor_architecture,
	config_fetch_type,
	rack_units,
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
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM audit.device_type_v84;

ALTER TABLE jazzhands.device_type
	ALTER device_type_id
	SET DEFAULT nextval('device_type_device_type_id_seq'::regclass);
ALTER TABLE jazzhands.device_type
	ALTER has_802_3_interface
	SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands.device_type
	ALTER has_802_11_interface
	SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands.device_type
	ALTER snmp_capable
	SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands.device_type
	ALTER is_chassis
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.device_type ADD CONSTRAINT pk_device_type PRIMARY KEY (device_type_id);

-- Table/Column Comments
COMMENT ON TABLE jazzhands.device_type IS 'Conceptual device type.  This represents how it is typically referred to rather than a specific model number.  There may be many models (components) that are represented by one device type.';
COMMENT ON COLUMN jazzhands.device_type.component_type_id IS 'reference to the type of hardware that underlies this type';
COMMENT ON COLUMN jazzhands.device_type.device_type_name IS 'Human readable name of the device type.  The company and a model can be gleaned from component.';
COMMENT ON COLUMN jazzhands.device_type.template_device_id IS 'Represents a non-real but template device that is used to describe how to setup a device when its inserted into the database with this device type.  Its used to get port names and other information correct when it needs to be inserted before probing.  Probing may deviate from the template.';
COMMENT ON COLUMN jazzhands.device_type.idealized_device_id IS 'Indicates what a device of this type looks like; primarily used for either reverse engineering a probe to a device type or valdating that a device type has all the pieces it is expcted to.  This device is typically not real.';
-- INDEXES
CREATE INDEX xif4device_type ON device_type USING btree (company_id);
CREATE INDEX xif_dev_typ_idealized_dev_id ON device_type USING btree (idealized_device_id);
CREATE INDEX xif_dev_typ_tmplt_dev_typ_id ON device_type USING btree (template_device_id);
CREATE INDEX xif_fevtyp_component_id ON device_type USING btree (component_type_id);

-- CHECK CONSTRAINTS
ALTER TABLE jazzhands.device_type ADD CONSTRAINT check_yes_no_1872258464
	CHECK (is_chassis = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE jazzhands.device_type ADD CONSTRAINT check_yes_no_1941676728
	CHECK (snmp_capable = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE jazzhands.device_type ADD CONSTRAINT check_yes_no_804136729
	CHECK (has_802_3_interface = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE jazzhands.device_type ADD CONSTRAINT check_yes_no_970967695
	CHECK (has_802_11_interface = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK between device_type and chassis_location
ALTER TABLE jazzhands.chassis_location
	ADD CONSTRAINT fk_chass_loc_mod_dev_typ_id
	FOREIGN KEY (module_device_type_id) REFERENCES device_type(device_type_id);
-- consider FK between device_type and device
ALTER TABLE jazzhands.device
	ADD CONSTRAINT fk_dev_devtp_id
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);
-- consider FK between device_type and device_type_module
ALTER TABLE jazzhands.device_type_module
	ADD CONSTRAINT fk_devt_mod_dev_type_id
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);
-- consider FK between device_type and device_type_module_device_type
ALTER TABLE jazzhands.device_type_module_device_type
	ADD CONSTRAINT fk_dt_mod_dev_type_mod_dtid
	FOREIGN KEY (module_device_type_id) REFERENCES device_type(device_type_id);

-- FOREIGN KEYS TO
-- consider FK device_type and device
ALTER TABLE jazzhands.device_type
	ADD CONSTRAINT fk_dev_typ_idealized_dev_id
	FOREIGN KEY (idealized_device_id) REFERENCES device(device_id);
-- consider FK device_type and device
ALTER TABLE jazzhands.device_type
	ADD CONSTRAINT fk_dev_typ_tmplt_dev_typ_id
	FOREIGN KEY (template_device_id) REFERENCES device(device_id);
-- consider FK device_type and val_processor_architecture
ALTER TABLE jazzhands.device_type
	ADD CONSTRAINT fk_device_t_fk_device_val_proc
	FOREIGN KEY (processor_architecture) REFERENCES val_processor_architecture(processor_architecture);
-- consider FK device_type and company
ALTER TABLE jazzhands.device_type
	ADD CONSTRAINT fk_devtyp_company
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK device_type and component_type
ALTER TABLE jazzhands.device_type
	ADD CONSTRAINT fk_fevtyp_component_id
	FOREIGN KEY (component_type_id) REFERENCES component_type(component_type_id);

-- TRIGGERS
-- consider NEW jazzhands.device_type_chassis_check
CREATE OR REPLACE FUNCTION jazzhands.device_type_chassis_check()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
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
$function$
;
CREATE TRIGGER trigger_device_type_chassis_check BEFORE UPDATE OF is_chassis ON device_type FOR EACH ROW EXECUTE PROCEDURE device_type_chassis_check();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.device_type_model_to_name
CREATE OR REPLACE FUNCTION jazzhands.device_type_model_to_name()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	IF TG_OP = 'UPDATE' AND  (NEW.model IS DISTINCT FROM OLD.model AND
			NEW.device_type_name IS DISTINCT FROM OLD.device_type_name) THEN
		RAISE EXCEPTION 'Only device_type_name should be updated.'
			USING ERRCODE = 'integrity_constraint_violation';
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.model IS NOT NULL AND NEW.device_type_name IS NOT NULL THEN
			RAISE EXCEPTION 'Only model should be set.'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

	END IF;

	IF TG_OP = 'UPDATE' THEN
		IF OLD.model IS DISTINCT FROM NEW.model THEN
			NEW.device_type_name = NEW.model;
		ELSIF OLD.device_type_name IS DISTINCT FROM NEW.device_type_name THEN
			NEW.model = NEW.device_type_name;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.model IS NOT NULL THEN
			NEW.device_type_name = NEW.model;
		ELSIF NEW.device_type_name IS NOT NULL THEN
			NEW.model = NEW.device_type_name;
		END IF;
	ELSE
	END IF;

	-- company_id is going away
	IF NEW.company_id IS NULL THEN
		NEW.company_id := 0;
	END IF;

	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_device_type_model_to_name BEFORE INSERT OR UPDATE OF device_type_name, model ON device_type FOR EACH ROW EXECUTE PROCEDURE device_type_model_to_name();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device_type');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'device_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device_type');
ALTER SEQUENCE device_type_device_type_id_seq
	 OWNED BY device_type.device_type_id;
DROP TABLE IF EXISTS device_type_v84;
DROP TABLE IF EXISTS audit.device_type_v84;
-- DONE DEALING WITH TABLE device_type
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE device_type_module
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_type_module', 'device_type_module');

-- FOREIGN KEYS FROM
ALTER TABLE chassis_location DROP CONSTRAINT IF EXISTS fk_chas_loc_dt_module;
ALTER TABLE device_type_module_device_type DROP CONSTRAINT IF EXISTS fk_dt_mod_dev_type_dtmod;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.device_type_module DROP CONSTRAINT IF EXISTS fk_devt_mod_dev_type_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'device_type_module');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.device_type_module DROP CONSTRAINT IF EXISTS pk_device_type_module;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1device_type_module";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.device_type_module DROP CONSTRAINT IF EXISTS ckc_dt_mod_dt_side;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_device_type_module ON jazzhands.device_type_module;
DROP TRIGGER IF EXISTS trigger_audit_device_type_module ON jazzhands.device_type_module;
DROP TRIGGER IF EXISTS trigger_device_type_module_chassis_check ON jazzhands.device_type_module;
DROP TRIGGER IF EXISTS trigger_device_type_module_sanity_set ON jazzhands.device_type_module;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'device_type_module');
---- BEGIN audit.device_type_module TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'device_type_module', 'device_type_module');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'device_type_module');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.device_type_module DROP CONSTRAINT IF EXISTS device_type_module_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_device_type_module_pk_device_type_module";
DROP INDEX IF EXISTS "audit"."device_type_module_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."device_type_module_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."device_type_module_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.device_type_module TEARDOWN


ALTER TABLE device_type_module RENAME TO device_type_module_v84;
ALTER TABLE audit.device_type_module RENAME TO device_type_module_v84;

CREATE TABLE jazzhands.device_type_module
(
	device_type_id	integer NOT NULL,
	device_type_module_name	varchar(255) NOT NULL,
	description	varchar(255)  NULL,
	device_type_x_offset	varchar(50)  NULL,
	device_type_y_offset	varchar(50)  NULL,
	device_type_z_offset	varchar(50)  NULL,
	device_type_side	varchar(50)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device_type_module', false);
ALTER TABLE device_type_module
	ALTER device_type_side
	SET DEFAULT 'FRONT'::character varying;
INSERT INTO device_type_module (
	device_type_id,
	device_type_module_name,
	description,
	device_type_x_offset,
	device_type_y_offset,
	device_type_z_offset,
	device_type_side,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	device_type_id,
	device_type_module_name,
	description,
	device_type_x_offset,
	device_type_y_offset,
	device_type_z_offset,
	device_type_side,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM device_type_module_v84;

INSERT INTO audit.device_type_module (
	device_type_id,
	device_type_module_name,
	description,
	device_type_x_offset,
	device_type_y_offset,
	device_type_z_offset,
	device_type_side,
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
	device_type_id,
	device_type_module_name,
	description,
	device_type_x_offset,
	device_type_y_offset,
	device_type_z_offset,
	device_type_side,
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
FROM audit.device_type_module_v84;

ALTER TABLE jazzhands.device_type_module
	ALTER device_type_side
	SET DEFAULT 'FRONT'::character varying;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.device_type_module ADD CONSTRAINT pk_device_type_module PRIMARY KEY (device_type_id, device_type_module_name);

-- Table/Column Comments
COMMENT ON COLUMN jazzhands.device_type_module.device_type_id IS 'Device Type of the Container Device (Chassis)';
COMMENT ON COLUMN jazzhands.device_type_module.device_type_module_name IS 'Name used to describe the module programatically.';
COMMENT ON COLUMN jazzhands.device_type_module.device_type_x_offset IS 'Horizontal offset from left to right';
COMMENT ON COLUMN jazzhands.device_type_module.device_type_y_offset IS 'Vertical offset from top to bottom';
COMMENT ON COLUMN jazzhands.device_type_module.device_type_z_offset IS 'Offset inside the device (front to back, yes, that is Z).  Only this or device_type_side may be set.';
COMMENT ON COLUMN jazzhands.device_type_module.device_type_side IS 'Only this or z_offset may be set.  Front or back of the chassis/container device_type';
-- INDEXES
CREATE INDEX xif1device_type_module ON device_type_module USING btree (device_type_id);

-- CHECK CONSTRAINTS
ALTER TABLE jazzhands.device_type_module ADD CONSTRAINT ckc_dt_mod_dt_side
	CHECK ((device_type_side)::text = ANY ((ARRAY['FRONT'::character varying, 'BACK'::character varying])::text[]));

-- FOREIGN KEYS FROM
-- consider FK between device_type_module and chassis_location
ALTER TABLE jazzhands.chassis_location
	ADD CONSTRAINT fk_chas_loc_dt_module
	FOREIGN KEY (chassis_device_type_id, device_type_module_name) REFERENCES device_type_module(device_type_id, device_type_module_name);
-- consider FK between device_type_module and device_type_module_device_type
ALTER TABLE jazzhands.device_type_module_device_type
	ADD CONSTRAINT fk_dt_mod_dev_type_dtmod
	FOREIGN KEY (device_type_id, device_type_module_name) REFERENCES device_type_module(device_type_id, device_type_module_name);

-- FOREIGN KEYS TO
-- consider FK device_type_module and device_type
ALTER TABLE jazzhands.device_type_module
	ADD CONSTRAINT fk_devt_mod_dev_type_id
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);

-- TRIGGERS
-- consider NEW jazzhands.device_type_module_chassis_check
CREATE OR REPLACE FUNCTION jazzhands.device_type_module_chassis_check()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
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
$function$
;
CREATE TRIGGER trigger_device_type_module_chassis_check BEFORE INSERT OR UPDATE OF device_type_id ON device_type_module FOR EACH ROW EXECUTE PROCEDURE device_type_module_chassis_check();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.device_type_module_sanity_set
CREATE OR REPLACE FUNCTION jazzhands.device_type_module_sanity_set()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF NEW.DEVICE_TYPE_Z_OFFSET IS NOT NULL AND NEW.DEVICE_TYPE_SIDE IS NOT NULL THEN
		RAISE EXCEPTION 'Both Z Offset and Device_Type_Side may not be set'
			USING ERRCODE = 'JH001';
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_device_type_module_sanity_set BEFORE INSERT OR UPDATE ON device_type_module FOR EACH ROW EXECUTE PROCEDURE device_type_module_sanity_set();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device_type_module');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'device_type_module');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device_type_module');
DROP TABLE IF EXISTS device_type_module_v84;
DROP TABLE IF EXISTS audit.device_type_module_v84;
-- DONE DEALING WITH TABLE device_type_module
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE klogin_mclass
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'klogin_mclass', 'klogin_mclass');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.klogin_mclass DROP CONSTRAINT IF EXISTS fk_klgnmcl_devcoll_id;
ALTER TABLE jazzhands.klogin_mclass DROP CONSTRAINT IF EXISTS fk_klgnmcl_klogn_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'klogin_mclass');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.klogin_mclass DROP CONSTRAINT IF EXISTS pk_klogin_mclass;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idxbm_kloginmclass_inclexclflg";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.klogin_mclass DROP CONSTRAINT IF EXISTS ckc_include_exclude_f_klogin_m;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_klogin_mclass ON jazzhands.klogin_mclass;
DROP TRIGGER IF EXISTS trigger_audit_klogin_mclass ON jazzhands.klogin_mclass;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'klogin_mclass');
---- BEGIN audit.klogin_mclass TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'klogin_mclass', 'klogin_mclass');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'klogin_mclass');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.klogin_mclass DROP CONSTRAINT IF EXISTS klogin_mclass_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_klogin_mclass_pk_klogin_mclass";
DROP INDEX IF EXISTS "audit"."klogin_mclass_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."klogin_mclass_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."klogin_mclass_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.klogin_mclass TEARDOWN


ALTER TABLE klogin_mclass RENAME TO klogin_mclass_v84;
ALTER TABLE audit.klogin_mclass RENAME TO klogin_mclass_v84;

CREATE TABLE jazzhands.klogin_mclass
(
	klogin_id	integer NOT NULL,
	device_collection_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'klogin_mclass', false);
INSERT INTO klogin_mclass (
	klogin_id,
	device_collection_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	klogin_id,
	device_collection_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM klogin_mclass_v84;

INSERT INTO audit.klogin_mclass (
	klogin_id,
	device_collection_id,
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
	klogin_id,
	device_collection_id,
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
FROM audit.klogin_mclass_v84;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.klogin_mclass ADD CONSTRAINT pk_klogin_mclass PRIMARY KEY (klogin_id, device_collection_id);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK klogin_mclass and device_collection
ALTER TABLE jazzhands.klogin_mclass
	ADD CONSTRAINT fk_klgnmcl_devcoll_id
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
-- consider FK klogin_mclass and klogin
ALTER TABLE jazzhands.klogin_mclass
	ADD CONSTRAINT fk_klgnmcl_klogn_id
	FOREIGN KEY (klogin_id) REFERENCES klogin(klogin_id);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'klogin_mclass');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'klogin_mclass');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'klogin_mclass');
DROP TABLE IF EXISTS klogin_mclass_v84;
DROP TABLE IF EXISTS audit.klogin_mclass_v84;
-- DONE DEALING WITH TABLE klogin_mclass
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE network_interface
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'network_interface', 'network_interface');

-- FOREIGN KEYS FROM
ALTER TABLE network_interface_netblock DROP CONSTRAINT IF EXISTS fk_netint_nb_nblk_id;
ALTER TABLE network_interface_purpose DROP CONSTRAINT IF EXISTS fk_netint_purp_dev_ni_id;
ALTER TABLE network_service DROP CONSTRAINT IF EXISTS fk_netsvc_netint_id;
ALTER TABLE shared_netblock_network_int DROP CONSTRAINT IF EXISTS fk_shrdnet_netint_netint_id;
ALTER TABLE static_route_template DROP CONSTRAINT IF EXISTS fk_static_rt_net_interface;
ALTER TABLE static_route DROP CONSTRAINT IF EXISTS fk_statrt_netintdst_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS fk_net_int_lgl_port_id;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS fk_net_int_phys_port_id;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS fk_netint_device_id;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS fk_netint_netinttyp_id;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS fk_netint_ref_parentnetint;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS fk_netint_slot_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'network_interface');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS ak_net_int_devid_netintid;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS fk_netint_devid_name;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS pk_network_interface_id;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_netint_isifaceup";
DROP INDEX IF EXISTS "jazzhands"."idx_netint_shouldmange";
DROP INDEX IF EXISTS "jazzhands"."idx_netint_shouldmonitor";
DROP INDEX IF EXISTS "jazzhands"."xif_net_int_lgl_port_id";
DROP INDEX IF EXISTS "jazzhands"."xif_net_int_phys_port_id";
DROP INDEX IF EXISTS "jazzhands"."xif_netint_netdev_id";
DROP INDEX IF EXISTS "jazzhands"."xif_netint_parentnetint";
DROP INDEX IF EXISTS "jazzhands"."xif_netint_slot_id";
DROP INDEX IF EXISTS "jazzhands"."xif_netint_typeid";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS check_any_yes_no_1926994056;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS ckc_is_interface_up_network_;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS ckc_netint_parent_r_1604677531;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS ckc_should_manage_network_;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_network_interface ON jazzhands.network_interface;
DROP TRIGGER IF EXISTS trigger_audit_network_interface ON jazzhands.network_interface;
DROP TRIGGER IF EXISTS trigger_net_int_device_id_upd ON jazzhands.network_interface;
DROP TRIGGER IF EXISTS trigger_net_int_nb_device_id_ins_before ON jazzhands.network_interface;
DROP TRIGGER IF EXISTS trigger_net_int_physical_id_to_slot_id_enforce ON jazzhands.network_interface;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'network_interface');
---- BEGIN audit.network_interface TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'network_interface', 'network_interface');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'network_interface');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.network_interface DROP CONSTRAINT IF EXISTS network_interface_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_network_interface_ak_net_int_devid_netintid";
DROP INDEX IF EXISTS "audit"."aud_network_interface_fk_netint_devid_name";
DROP INDEX IF EXISTS "audit"."aud_network_interface_pk_network_interface_id";
DROP INDEX IF EXISTS "audit"."network_interface_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."network_interface_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."network_interface_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.network_interface TEARDOWN


ALTER TABLE network_interface RENAME TO network_interface_v84;
ALTER TABLE audit.network_interface RENAME TO network_interface_v84;

CREATE TABLE jazzhands.network_interface
(
	network_interface_id	integer NOT NULL,
	device_id	integer NOT NULL,
	network_interface_name	varchar(255)  NULL,
	description	varchar(255)  NULL,
	parent_network_interface_id	integer  NULL,
	parent_relation_type	varchar(255)  NULL,
	physical_port_id	integer  NULL,
	slot_id	integer  NULL,
	logical_port_id	integer  NULL,
	network_interface_type	varchar(50) NOT NULL,
	is_interface_up	character(1) NOT NULL,
	mac_addr	macaddr  NULL,
	should_monitor	character(1) NOT NULL,
	should_manage	character(1) NOT NULL,
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
	ALTER should_monitor
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE network_interface
	ALTER should_manage
	SET DEFAULT 'Y'::bpchar;
INSERT INTO network_interface (
	network_interface_id,
	device_id,
	network_interface_name,
	description,
	parent_network_interface_id,
	parent_relation_type,
	physical_port_id,
	slot_id,
	logical_port_id,
	network_interface_type,
	is_interface_up,
	mac_addr,
	should_monitor,
	should_manage,
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
	physical_port_id,
	slot_id,
	logical_port_id,
	network_interface_type,
	is_interface_up,
	mac_addr,
	should_monitor,
	should_manage,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM network_interface_v84;

INSERT INTO audit.network_interface (
	network_interface_id,
	device_id,
	network_interface_name,
	description,
	parent_network_interface_id,
	parent_relation_type,
	physical_port_id,
	slot_id,
	logical_port_id,
	network_interface_type,
	is_interface_up,
	mac_addr,
	should_monitor,
	should_manage,
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
	network_interface_id,
	device_id,
	network_interface_name,
	description,
	parent_network_interface_id,
	parent_relation_type,
	physical_port_id,
	slot_id,
	logical_port_id,
	network_interface_type,
	is_interface_up,
	mac_addr,
	should_monitor,
	should_manage,
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
FROM audit.network_interface_v84;

ALTER TABLE jazzhands.network_interface
	ALTER network_interface_id
	SET DEFAULT nextval('network_interface_network_interface_id_seq'::regclass);
ALTER TABLE jazzhands.network_interface
	ALTER is_interface_up
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE jazzhands.network_interface
	ALTER should_monitor
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE jazzhands.network_interface
	ALTER should_manage
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.network_interface ADD CONSTRAINT ak_net_int_devid_netintid UNIQUE (network_interface_id, device_id);
ALTER TABLE jazzhands.network_interface ADD CONSTRAINT fk_netint_devid_name UNIQUE (device_id, network_interface_name);
ALTER TABLE jazzhands.network_interface ADD CONSTRAINT pk_network_interface_id PRIMARY KEY (network_interface_id);

-- Table/Column Comments
COMMENT ON COLUMN jazzhands.network_interface.physical_port_id IS 'historical column to be dropped in the next release after tools use slot_id.  matches slot_id by trigger.';
COMMENT ON COLUMN jazzhands.network_interface.slot_id IS 'to be dropped after transition to logical_ports are complete.';
-- INDEXES
CREATE INDEX idx_netint_isifaceup ON network_interface USING btree (is_interface_up);
CREATE INDEX idx_netint_shouldmange ON network_interface USING btree (should_manage);
CREATE INDEX idx_netint_shouldmonitor ON network_interface USING btree (should_monitor);
CREATE INDEX xif_net_int_lgl_port_id ON network_interface USING btree (logical_port_id);
CREATE INDEX xif_net_int_phys_port_id ON network_interface USING btree (physical_port_id);
CREATE INDEX xif_netint_netdev_id ON network_interface USING btree (device_id);
CREATE INDEX xif_netint_parentnetint ON network_interface USING btree (parent_network_interface_id);
CREATE INDEX xif_netint_slot_id ON network_interface USING btree (slot_id);
CREATE INDEX xif_netint_typeid ON network_interface USING btree (network_interface_type);

-- CHECK CONSTRAINTS
ALTER TABLE jazzhands.network_interface ADD CONSTRAINT check_yes_no_1097883727
	CHECK (is_interface_up = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE jazzhands.network_interface ADD CONSTRAINT check_yes_no_231320279
	CHECK (should_manage = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE jazzhands.network_interface ADD CONSTRAINT check_yes_no_427579194
	CHECK (should_monitor = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE jazzhands.network_interface ADD CONSTRAINT ckc_netint_parent_role_1604677531
	CHECK ((parent_relation_type)::text = ANY ((ARRAY['NONE'::character varying, 'SUBINTERFACE'::character varying, 'SECONDARY'::character varying])::text[]));

-- FOREIGN KEYS FROM
-- consider FK between network_interface and network_interface_netblock
ALTER TABLE jazzhands.network_interface_netblock
	ADD CONSTRAINT fk_netint_nb_nblk_id
	FOREIGN KEY (network_interface_id, device_id) REFERENCES network_interface(network_interface_id, device_id) DEFERRABLE;
-- consider FK between network_interface and network_interface_purpose
ALTER TABLE jazzhands.network_interface_purpose
	ADD CONSTRAINT fk_netint_purp_dev_ni_id
	FOREIGN KEY (network_interface_id, device_id) REFERENCES network_interface(network_interface_id, device_id) DEFERRABLE;
-- consider FK between network_interface and network_service
ALTER TABLE jazzhands.network_service
	ADD CONSTRAINT fk_netsvc_netint_id
	FOREIGN KEY (network_interface_id) REFERENCES network_interface(network_interface_id);
-- consider FK between network_interface and shared_netblock_network_int
ALTER TABLE jazzhands.shared_netblock_network_int
	ADD CONSTRAINT fk_shrdnet_netint_netint_id
	FOREIGN KEY (network_interface_id) REFERENCES network_interface(network_interface_id);
-- consider FK between network_interface and static_route_template
ALTER TABLE jazzhands.static_route_template
	ADD CONSTRAINT fk_static_rt_net_interface
	FOREIGN KEY (network_interface_dst_id) REFERENCES network_interface(network_interface_id);
-- consider FK between network_interface and static_route
ALTER TABLE jazzhands.static_route
	ADD CONSTRAINT fk_statrt_netintdst_id
	FOREIGN KEY (network_interface_dst_id) REFERENCES network_interface(network_interface_id);

-- FOREIGN KEYS TO
-- consider FK network_interface and logical_port
ALTER TABLE jazzhands.network_interface
	ADD CONSTRAINT fk_net_int_lgl_port_id
	FOREIGN KEY (logical_port_id) REFERENCES logical_port(logical_port_id);
-- consider FK network_interface and slot
ALTER TABLE jazzhands.network_interface
	ADD CONSTRAINT fk_net_int_phys_port_id
	FOREIGN KEY (physical_port_id) REFERENCES slot(slot_id);
-- consider FK network_interface and device
ALTER TABLE jazzhands.network_interface
	ADD CONSTRAINT fk_netint_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK network_interface and val_network_interface_type
ALTER TABLE jazzhands.network_interface
	ADD CONSTRAINT fk_netint_netinttyp_id
	FOREIGN KEY (network_interface_type) REFERENCES val_network_interface_type(network_interface_type);
-- consider FK network_interface and network_interface
ALTER TABLE jazzhands.network_interface
	ADD CONSTRAINT fk_netint_ref_parentnetint
	FOREIGN KEY (parent_network_interface_id) REFERENCES network_interface(network_interface_id);
-- consider FK network_interface and slot
ALTER TABLE jazzhands.network_interface
	ADD CONSTRAINT fk_netint_slot_id
	FOREIGN KEY (slot_id) REFERENCES slot(slot_id);

-- TRIGGERS
-- consider NEW jazzhands.net_int_device_id_upd
CREATE OR REPLACE FUNCTION jazzhands.net_int_device_id_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	UPDATE network_interface_netblock
	SET device_id = NEW.device_id
	WHERE	network_interface_id = NEW.network_interface_id;
	SET CONSTRAINTS fk_netint_nb_nblk_id IMMEDIATE;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_net_int_device_id_upd AFTER UPDATE OF device_id ON network_interface FOR EACH ROW EXECUTE PROCEDURE net_int_device_id_upd();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.net_int_nb_device_id_ins_before
CREATE OR REPLACE FUNCTION jazzhands.net_int_nb_device_id_ins_before()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	SET CONSTRAINTS fk_netint_nb_nblk_id DEFERRED;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_net_int_nb_device_id_ins_before BEFORE UPDATE OF device_id ON network_interface FOR EACH ROW EXECUTE PROCEDURE net_int_nb_device_id_ins_before();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.net_int_physical_id_to_slot_id_enforce
CREATE OR REPLACE FUNCTION jazzhands.net_int_physical_id_to_slot_id_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	IF TG_OP = 'UPDATE' AND  (NEW.slot_id IS DISTINCT FROM OLD.slot_ID AND
			NEW.physical_port_id IS DISTINCT FROM OLD.physical_port_id) THEN
		RAISE EXCEPTION 'Only slot_id should be updated.'
			USING ERRCODE = 'integrity_constraint_violation';
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.physical_port_id IS NOT NULL AND NEW.slot_id IS NOT NULL THEN
			RAISE EXCEPTION 'Only slot_id should be set.'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

	END IF;

	IF TG_OP = 'UPDATE' THEN
		IF OLD.slot_id IS DISTINCT FROM NEW.slot_id THEN
			NEW.physical_port_id = NEW.slot_id;
		ELSIF OLD.physical_port_id IS DISTINCT FROM NEW.physical_port_id THEN
			NEW.slot_id = NEW.physical_port_id;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.slot_id IS NOT NULL THEN
			NEW.physical_port_id = NEW.slot_id;
		ELSIF NEW.physical_port_id IS NOT NULL THEN
			NEW.slot_id = NEW.physical_port_id;
		END IF;
	ELSE
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_net_int_physical_id_to_slot_id_enforce BEFORE INSERT OR UPDATE OF physical_port_id, slot_id ON network_interface FOR EACH ROW EXECUTE PROCEDURE net_int_physical_id_to_slot_id_enforce();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'network_interface');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'network_interface');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'network_interface');
ALTER SEQUENCE network_interface_network_interface_id_seq
	 OWNED BY network_interface.network_interface_id;
DROP TABLE IF EXISTS network_interface_v84;
DROP TABLE IF EXISTS audit.network_interface_v84;
-- DONE DEALING WITH TABLE network_interface
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE network_service
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'network_service', 'network_service');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.network_service DROP CONSTRAINT IF EXISTS fk_netsvc_csvcenv;
ALTER TABLE jazzhands.network_service DROP CONSTRAINT IF EXISTS fk_netsvc_device_id;
ALTER TABLE jazzhands.network_service DROP CONSTRAINT IF EXISTS fk_netsvc_dnsid_id;
ALTER TABLE jazzhands.network_service DROP CONSTRAINT IF EXISTS fk_netsvc_netint_id;
ALTER TABLE jazzhands.network_service DROP CONSTRAINT IF EXISTS fk_netsvc_netsvctyp_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'network_service');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.network_service DROP CONSTRAINT IF EXISTS pk_service;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_netsvc_ismonitored";
DROP INDEX IF EXISTS "jazzhands"."idx_netsvc_netsvctype";
DROP INDEX IF EXISTS "jazzhands"."idx_netsvc_svcenv";
DROP INDEX IF EXISTS "jazzhands"."ix_netsvc_dnsidrecid";
DROP INDEX IF EXISTS "jazzhands"."ix_netsvc_netdevid";
DROP INDEX IF EXISTS "jazzhands"."ix_netsvc_netintid";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.network_service DROP CONSTRAINT IF EXISTS ckc_is_monitored_network_;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_network_service ON jazzhands.network_service;
DROP TRIGGER IF EXISTS trigger_audit_network_service ON jazzhands.network_service;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'network_service');
---- BEGIN audit.network_service TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'network_service', 'network_service');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'network_service');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.network_service DROP CONSTRAINT IF EXISTS network_service_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_network_service_pk_service";
DROP INDEX IF EXISTS "audit"."network_service_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."network_service_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."network_service_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.network_service TEARDOWN


ALTER TABLE network_service RENAME TO network_service_v84;
ALTER TABLE audit.network_service RENAME TO network_service_v84;

CREATE TABLE jazzhands.network_service
(
	network_service_id	integer NOT NULL,
	name	varchar(255)  NULL,
	description	varchar(255)  NULL,
	network_service_type	varchar(50) NOT NULL,
	is_monitored	character(1) NOT NULL,
	device_id	integer  NULL,
	network_interface_id	integer  NULL,
	dns_record_id	integer  NULL,
	service_environment_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'network_service', false);
ALTER TABLE network_service
	ALTER network_service_id
	SET DEFAULT nextval('network_service_network_service_id_seq'::regclass);
INSERT INTO network_service (
	network_service_id,
	name,
	description,
	network_service_type,
	is_monitored,
	device_id,
	network_interface_id,
	dns_record_id,
	service_environment_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	network_service_id,
	name,
	description,
	network_service_type,
	is_monitored,
	device_id,
	network_interface_id,
	dns_record_id,
	service_environment_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM network_service_v84;

INSERT INTO audit.network_service (
	network_service_id,
	name,
	description,
	network_service_type,
	is_monitored,
	device_id,
	network_interface_id,
	dns_record_id,
	service_environment_id,
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
	network_service_id,
	name,
	description,
	network_service_type,
	is_monitored,
	device_id,
	network_interface_id,
	dns_record_id,
	service_environment_id,
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
FROM audit.network_service_v84;

ALTER TABLE jazzhands.network_service
	ALTER network_service_id
	SET DEFAULT nextval('network_service_network_service_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.network_service ADD CONSTRAINT pk_service PRIMARY KEY (network_service_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX idx_netsvc_ismonitored ON network_service USING btree (is_monitored);
CREATE INDEX idx_netsvc_netsvctype ON network_service USING btree (network_service_type);
CREATE INDEX idx_netsvc_svcenv ON network_service USING btree (service_environment_id);
CREATE INDEX ix_netsvc_dnsidrecid ON network_service USING btree (dns_record_id);
CREATE INDEX ix_netsvc_netdevid ON network_service USING btree (device_id);
CREATE INDEX ix_netsvc_netintid ON network_service USING btree (network_interface_id);

-- CHECK CONSTRAINTS
ALTER TABLE jazzhands.network_service ADD CONSTRAINT check_yes_no_684393740
	CHECK (is_monitored = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK network_service and service_environment
ALTER TABLE jazzhands.network_service
	ADD CONSTRAINT fk_netsvc_csvcenv
	FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id);
-- consider FK network_service and device
ALTER TABLE jazzhands.network_service
	ADD CONSTRAINT fk_netsvc_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK network_service and dns_record
ALTER TABLE jazzhands.network_service
	ADD CONSTRAINT fk_netsvc_dnsid_id
	FOREIGN KEY (dns_record_id) REFERENCES dns_record(dns_record_id);
-- consider FK network_service and network_interface
ALTER TABLE jazzhands.network_service
	ADD CONSTRAINT fk_netsvc_netint_id
	FOREIGN KEY (network_interface_id) REFERENCES network_interface(network_interface_id);
-- consider FK network_service and val_network_service_type
ALTER TABLE jazzhands.network_service
	ADD CONSTRAINT fk_netsvc_netsvctyp_id
	FOREIGN KEY (network_service_type) REFERENCES val_network_service_type(network_service_type);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'network_service');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'network_service');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'network_service');
ALTER SEQUENCE network_service_network_service_id_seq
	 OWNED BY network_service.network_service_id;
DROP TABLE IF EXISTS network_service_v84;
DROP TABLE IF EXISTS audit.network_service_v84;
-- DONE DEALING WITH TABLE network_service
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE physical_address
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'physical_address', 'physical_address');

-- FOREIGN KEYS FROM
ALTER TABLE person_location DROP CONSTRAINT IF EXISTS fk_persloc_physaddrid;
ALTER TABLE site DROP CONSTRAINT IF EXISTS fk_site_physaddr_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.physical_address DROP CONSTRAINT IF EXISTS fk_physaddr_company_id;
ALTER TABLE jazzhands.physical_address DROP CONSTRAINT IF EXISTS fk_physaddr_iso_cc;
ALTER TABLE jazzhands.physical_address DROP CONSTRAINT IF EXISTS fk_physaddr_type_val;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'physical_address');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.physical_address DROP CONSTRAINT IF EXISTS pk_val_office_site;
ALTER TABLE jazzhands.physical_address DROP CONSTRAINT IF EXISTS uq_physaddr_compid_siterk;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_physaddr_company_id";
DROP INDEX IF EXISTS "jazzhands"."xif_physaddr_iso_cc";
DROP INDEX IF EXISTS "jazzhands"."xif_physaddr_type_val";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_physical_address ON jazzhands.physical_address;
DROP TRIGGER IF EXISTS trigger_audit_physical_address ON jazzhands.physical_address;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'physical_address');
---- BEGIN audit.physical_address TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'physical_address', 'physical_address');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'physical_address');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.physical_address DROP CONSTRAINT IF EXISTS physical_address_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_physical_address_pk_val_office_site";
DROP INDEX IF EXISTS "audit"."aud_physical_address_uq_physaddr_compid_siterk";
DROP INDEX IF EXISTS "audit"."physical_address_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."physical_address_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."physical_address_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.physical_address TEARDOWN


ALTER TABLE physical_address RENAME TO physical_address_v84;
ALTER TABLE audit.physical_address RENAME TO physical_address_v84;

CREATE TABLE jazzhands.physical_address
(
	physical_address_id	integer NOT NULL,
	physical_address_type	varchar(50)  NULL,
	company_id	integer  NULL,
	site_rank	integer  NULL,
	description	varchar(4000)  NULL,
	display_label	varchar(100)  NULL,
	address_agent	varchar(100)  NULL,
	address_housename	varchar(255)  NULL,
	address_street	varchar(255)  NULL,
	address_building	varchar(255)  NULL,
	address_pobox	varchar(255)  NULL,
	address_neighborhood	varchar(255)  NULL,
	address_city	varchar(100)  NULL,
	address_subregion	varchar(50)  NULL,
	address_region	varchar(100)  NULL,
	postal_code	varchar(20)  NULL,
	iso_country_code	character(2) NOT NULL,
	address_freeform	varchar(50)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'physical_address', false);
ALTER TABLE physical_address
	ALTER physical_address_id
	SET DEFAULT nextval('physical_address_physical_address_id_seq'::regclass);
ALTER TABLE physical_address
	ALTER physical_address_type
	SET DEFAULT 'location'::character varying;
INSERT INTO physical_address (
	physical_address_id,
	physical_address_type,
	company_id,
	site_rank,
	description,
	display_label,
	address_agent,
	address_housename,
	address_street,
	address_building,
	address_pobox,
	address_neighborhood,
	address_city,
	address_subregion,
	address_region,
	postal_code,
	iso_country_code,
	address_freeform,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	physical_address_id,
	physical_address_type,
	company_id,
	site_rank,
	description,
	display_label,
	address_agent,
	address_housename,
	address_street,
	address_building,
	address_pobox,
	address_neighborhood,
	address_city,
	address_subregion,
	address_region,
	postal_code,
	iso_country_code,
	address_freeform,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM physical_address_v84;

INSERT INTO audit.physical_address (
	physical_address_id,
	physical_address_type,
	company_id,
	site_rank,
	description,
	display_label,
	address_agent,
	address_housename,
	address_street,
	address_building,
	address_pobox,
	address_neighborhood,
	address_city,
	address_subregion,
	address_region,
	postal_code,
	iso_country_code,
	address_freeform,
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
	physical_address_id,
	physical_address_type,
	company_id,
	site_rank,
	description,
	display_label,
	address_agent,
	address_housename,
	address_street,
	address_building,
	address_pobox,
	address_neighborhood,
	address_city,
	address_subregion,
	address_region,
	postal_code,
	iso_country_code,
	address_freeform,
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
FROM audit.physical_address_v84;

ALTER TABLE jazzhands.physical_address
	ALTER physical_address_id
	SET DEFAULT nextval('physical_address_physical_address_id_seq'::regclass);
ALTER TABLE jazzhands.physical_address
	ALTER physical_address_type
	SET DEFAULT 'location'::character varying;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.physical_address ADD CONSTRAINT pk_val_office_site PRIMARY KEY (physical_address_id);
ALTER TABLE jazzhands.physical_address ADD CONSTRAINT uq_physaddr_compid_siterk UNIQUE (company_id, site_rank);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_physaddr_company_id ON physical_address USING btree (company_id);
CREATE INDEX xif_physaddr_iso_cc ON physical_address USING btree (iso_country_code);
CREATE INDEX xif_physaddr_type_val ON physical_address USING btree (physical_address_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between physical_address and person_location
ALTER TABLE jazzhands.person_location
	ADD CONSTRAINT fk_persloc_physaddrid
	FOREIGN KEY (physical_address_id) REFERENCES physical_address(physical_address_id);
-- consider FK between physical_address and site
ALTER TABLE jazzhands.site
	ADD CONSTRAINT fk_site_physaddr_id
	FOREIGN KEY (physical_address_id) REFERENCES physical_address(physical_address_id);

-- FOREIGN KEYS TO
-- consider FK physical_address and company
ALTER TABLE jazzhands.physical_address
	ADD CONSTRAINT fk_physaddr_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK physical_address and val_country_code
ALTER TABLE jazzhands.physical_address
	ADD CONSTRAINT fk_physaddr_iso_cc
	FOREIGN KEY (iso_country_code) REFERENCES val_country_code(iso_country_code);
-- consider FK physical_address and val_physical_address_type
ALTER TABLE jazzhands.physical_address
	ADD CONSTRAINT fk_physaddr_type_val
	FOREIGN KEY (physical_address_type) REFERENCES val_physical_address_type(physical_address_type);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'physical_address');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'physical_address');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'physical_address');
ALTER SEQUENCE physical_address_physical_address_id_seq
	 OWNED BY physical_address.physical_address_id;
DROP TABLE IF EXISTS physical_address_v84;
DROP TABLE IF EXISTS audit.physical_address_v84;
-- DONE DEALING WITH TABLE physical_address
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE ssh_key
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'ssh_key', 'ssh_key');

-- FOREIGN KEYS FROM
ALTER TABLE account_ssh_key DROP CONSTRAINT IF EXISTS fk_account_ssh_key_account_id;
ALTER TABLE device_collection_ssh_key DROP CONSTRAINT IF EXISTS fk_dev_coll_ssh_key_ssh_key;
ALTER TABLE device_ssh_key DROP CONSTRAINT IF EXISTS fk_dev_ssh_key_device_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.ssh_key DROP CONSTRAINT IF EXISTS fk_ssh_key_enc_key_id;
ALTER TABLE jazzhands.ssh_key DROP CONSTRAINT IF EXISTS fk_ssh_key_ssh_key_type;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'ssh_key');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.ssh_key DROP CONSTRAINT IF EXISTS ak_ssh_key_private_key;
ALTER TABLE jazzhands.ssh_key DROP CONSTRAINT IF EXISTS ak_ssh_key_public_key;
ALTER TABLE jazzhands.ssh_key DROP CONSTRAINT IF EXISTS pk_ssh_key;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1ssh_key";
DROP INDEX IF EXISTS "jazzhands"."xif2ssh_key";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_ssh_key ON jazzhands.ssh_key;
DROP TRIGGER IF EXISTS trigger_audit_ssh_key ON jazzhands.ssh_key;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'ssh_key');
---- BEGIN audit.ssh_key TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'ssh_key', 'ssh_key');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'ssh_key');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.ssh_key DROP CONSTRAINT IF EXISTS ssh_key_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_ssh_key_ak_ssh_key_private_key";
DROP INDEX IF EXISTS "audit"."aud_ssh_key_ak_ssh_key_public_key";
DROP INDEX IF EXISTS "audit"."aud_ssh_key_pk_ssh_key";
DROP INDEX IF EXISTS "audit"."ssh_key_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."ssh_key_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."ssh_key_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.ssh_key TEARDOWN


ALTER TABLE ssh_key RENAME TO ssh_key_v84;
ALTER TABLE audit.ssh_key RENAME TO ssh_key_v84;

CREATE TABLE jazzhands.ssh_key
(
	ssh_key_id	integer NOT NULL,
	ssh_key_type	varchar(50)  NULL,
	ssh_public_key	varchar(4096) NOT NULL,
	ssh_private_key	varchar(4096)  NULL,
	encryption_key_id	integer  NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'ssh_key', false);
ALTER TABLE ssh_key
	ALTER ssh_key_id
	SET DEFAULT nextval('ssh_key_ssh_key_id_seq'::regclass);
INSERT INTO ssh_key (
	ssh_key_id,
	ssh_key_type,
	ssh_public_key,
	ssh_private_key,
	encryption_key_id,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	ssh_key_id,
	ssh_key_type,
	ssh_public_key,
	ssh_private_key,
	encryption_key_id,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM ssh_key_v84;

INSERT INTO audit.ssh_key (
	ssh_key_id,
	ssh_key_type,
	ssh_public_key,
	ssh_private_key,
	encryption_key_id,
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
	ssh_key_id,
	ssh_key_type,
	ssh_public_key,
	ssh_private_key,
	encryption_key_id,
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
FROM audit.ssh_key_v84;

ALTER TABLE jazzhands.ssh_key
	ALTER ssh_key_id
	SET DEFAULT nextval('ssh_key_ssh_key_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.ssh_key ADD CONSTRAINT ak_ssh_key_private_key UNIQUE (ssh_private_key);
ALTER TABLE jazzhands.ssh_key ADD CONSTRAINT ak_ssh_key_public_key UNIQUE (ssh_public_key);
ALTER TABLE jazzhands.ssh_key ADD CONSTRAINT pk_ssh_key PRIMARY KEY (ssh_key_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1ssh_key ON ssh_key USING btree (encryption_key_id);
CREATE INDEX xif2ssh_key ON ssh_key USING btree (ssh_key_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between ssh_key and account_ssh_key
ALTER TABLE jazzhands.account_ssh_key
	ADD CONSTRAINT fk_account_ssh_key_account_id
	FOREIGN KEY (ssh_key_id) REFERENCES ssh_key(ssh_key_id);
-- consider FK between ssh_key and device_collection_ssh_key
ALTER TABLE jazzhands.device_collection_ssh_key
	ADD CONSTRAINT fk_dev_coll_ssh_key_ssh_key
	FOREIGN KEY (ssh_key_id) REFERENCES ssh_key(ssh_key_id);
-- consider FK between ssh_key and device_ssh_key
ALTER TABLE jazzhands.device_ssh_key
	ADD CONSTRAINT fk_dev_ssh_key_device_id
	FOREIGN KEY (ssh_key_id) REFERENCES ssh_key(ssh_key_id);

-- FOREIGN KEYS TO
-- consider FK ssh_key and encryption_key
ALTER TABLE jazzhands.ssh_key
	ADD CONSTRAINT fk_ssh_key_enc_key_id
	FOREIGN KEY (encryption_key_id) REFERENCES encryption_key(encryption_key_id);
-- consider FK ssh_key and val_ssh_key_type
ALTER TABLE jazzhands.ssh_key
	ADD CONSTRAINT fk_ssh_key_ssh_key_type
	FOREIGN KEY (ssh_key_type) REFERENCES val_ssh_key_type(ssh_key_type);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'ssh_key');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'ssh_key');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'ssh_key');
ALTER SEQUENCE ssh_key_ssh_key_id_seq
	 OWNED BY ssh_key.ssh_key_id;
DROP TABLE IF EXISTS ssh_key_v84;
DROP TABLE IF EXISTS audit.ssh_key_v84;
-- DONE DEALING WITH TABLE ssh_key
--------------------------------------------------------------------
-- BEGIN: process_ancillary_schema(jazzhands_cache)
-- =============================================
DO $$
BEGIN
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE ct_component_hier
CREATE TABLE jazzhands_cache.ct_component_hier
(
	component_id	integer  NULL,
	child_component_id	integer  NULL,
	component_path	integer[]  NULL,
	level	integer  NULL
);

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES
CREATE INDEX ix_component_hier_child_component_id ON jazzhands_cache.ct_component_hier USING btree (child_component_id);
CREATE INDEX ix_component_hier_component_id ON jazzhands_cache.ct_component_hier USING btree (component_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE ct_component_hier
--------------------------------------------------------------------
EXCEPTION WHEN duplicate_table
	THEN NULL;
END;
$$;

-- =============================================
-- =============================================
DO $$
BEGIN
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE ct_device_components
CREATE TABLE jazzhands_cache.ct_device_components
(
	device_id	integer  NULL,
	component_id	integer  NULL,
	component_path	integer[]  NULL,
	level	integer  NULL
);

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES
CREATE INDEX ix_device_components_component_id ON jazzhands_cache.ct_device_components USING btree (component_id);
CREATE INDEX ix_device_components_device_id ON jazzhands_cache.ct_device_components USING btree (device_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE ct_device_components
--------------------------------------------------------------------
EXCEPTION WHEN duplicate_table
	THEN NULL;
END;
$$;

-- =============================================
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_component_hier
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_cache', 'v_component_hier');
DROP VIEW IF EXISTS jazzhands_cache.v_component_hier;
CREATE VIEW jazzhands_cache.v_component_hier AS
 WITH RECURSIVE component_hier(component_id, child_component_id, slot_id, component_path) AS (
         SELECT c.component_id,
            c.component_id,
            s.slot_id,
            ARRAY[c.component_id] AS "array"
           FROM component c
             LEFT JOIN slot s USING (component_id)
        UNION
         SELECT p.component_id,
            c.component_id,
            s.slot_id,
            array_prepend(c.component_id, p.component_path) AS array_prepend
           FROM component_hier p
             JOIN component c ON p.slot_id = c.parent_slot_id
             LEFT JOIN slot s ON s.component_id = c.component_id
        )
 SELECT DISTINCT component_hier.component_id,
    component_hier.child_component_id,
    component_hier.component_path,
    array_length(component_hier.component_path, 1) AS level
   FROM component_hier;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_cache' AND type = 'view' AND object = 'v_component_hier';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_component_hier failed but that is ok';
				NULL;
			END;
$$;

-- DONE DEALING WITH TABLE v_component_hier
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_components
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_cache', 'v_device_components');
DROP VIEW IF EXISTS jazzhands_cache.v_device_components;
CREATE VIEW jazzhands_cache.v_device_components AS
 SELECT ch.device_id,
    ch.component_id,
    ch.component_path,
    ch.level
   FROM ( SELECT d.device_id,
            ct_component_hier.child_component_id AS component_id,
            ct_component_hier.component_path,
            ct_component_hier.level,
            min(ct_component_hier.level) OVER (PARTITION BY ct_component_hier.child_component_id) AS min_level
           FROM jazzhands_cache.ct_component_hier
             JOIN device d USING (component_id)) ch
  WHERE ch.level = ch.min_level;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_cache' AND type = 'view' AND object = 'v_device_components';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_components failed but that is ok';
				NULL;
			END;
$$;

-- DONE DEALING WITH TABLE v_device_components
--------------------------------------------------------------------
-- DONE: process_ancillary_schema(jazzhands_cache)
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_component_hier
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_cache', 'v_component_hier');
DROP VIEW IF EXISTS jazzhands_cache.v_component_hier;
CREATE VIEW jazzhands_cache.v_component_hier AS
 WITH RECURSIVE component_hier(component_id, child_component_id, slot_id, component_path) AS (
         SELECT c.component_id,
            c.component_id,
            s.slot_id,
            ARRAY[c.component_id] AS "array"
           FROM component c
             LEFT JOIN slot s USING (component_id)
        UNION
         SELECT p.component_id,
            c.component_id,
            s.slot_id,
            array_prepend(c.component_id, p.component_path) AS array_prepend
           FROM component_hier p
             JOIN component c ON p.slot_id = c.parent_slot_id
             LEFT JOIN slot s ON s.component_id = c.component_id
        )
 SELECT DISTINCT component_hier.component_id,
    component_hier.child_component_id,
    component_hier.component_path,
    array_length(component_hier.component_path, 1) AS level
   FROM component_hier;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_cache' AND type = 'view' AND object = 'v_component_hier';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_component_hier failed but that is ok';
				NULL;
			END;
$$;

-- DONE DEALING WITH TABLE v_component_hier
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_components
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_cache', 'v_device_components');
DROP VIEW IF EXISTS jazzhands_cache.v_device_components;
CREATE VIEW jazzhands_cache.v_device_components AS
 SELECT ch.device_id,
    ch.component_id,
    ch.component_path,
    ch.level
   FROM ( SELECT d.device_id,
            ct_component_hier.child_component_id AS component_id,
            ct_component_hier.component_path,
            ct_component_hier.level,
            min(ct_component_hier.level) OVER (PARTITION BY ct_component_hier.child_component_id) AS min_level
           FROM jazzhands_cache.ct_component_hier
             JOIN device d USING (component_id)) ch
  WHERE ch.level = ch.min_level;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_cache' AND type = 'view' AND object = 'v_device_components';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_components failed but that is ok';
				NULL;
			END;
$$;

-- DONE DEALING WITH TABLE v_device_components
--------------------------------------------------------------------
SELECT schema_support.replay_object_recreates();
--------------------------------------------------------------------
-- DEALING WITH TABLE v_component_hier
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_component_hier', 'v_component_hier');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_component_hier');
DROP VIEW IF EXISTS jazzhands.v_component_hier;
CREATE VIEW jazzhands.v_component_hier AS
 SELECT ct_component_hier.component_id,
    ct_component_hier.child_component_id,
    ct_component_hier.component_path,
    ct_component_hier.level
   FROM jazzhands_cache.ct_component_hier;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object = 'v_component_hier';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_component_hier failed but that is ok';
				NULL;
			END;
$$;

-- just in case
SELECT schema_support.prepare_for_object_replay();
-- DONE DEALING WITH TABLE v_component_hier
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_device_components
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_components', 'v_device_components');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_device_components');
DROP VIEW IF EXISTS jazzhands.v_device_components;
CREATE VIEW jazzhands.v_device_components AS
 SELECT ct_device_components.device_id,
    ct_device_components.component_id,
    ct_device_components.component_path,
    ct_device_components.level
   FROM jazzhands_cache.ct_device_components;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object = 'v_device_components';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_components failed but that is ok';
				NULL;
			END;
$$;

-- just in case
SELECT schema_support.prepare_for_object_replay();
-- DONE DEALING WITH TABLE v_device_components
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_device_slots
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_slots', 'v_device_slots');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_device_slots');
DROP VIEW IF EXISTS jazzhands.v_device_slots;
CREATE VIEW jazzhands.v_device_slots AS
 SELECT d.device_id,
    d.component_id AS device_component_id,
    dc.component_id,
    s.slot_id
   FROM device d
     JOIN jazzhands_cache.ct_device_components dc USING (device_id)
     JOIN slot s ON dc.component_id = s.component_id;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object = 'v_device_slots';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_slots failed but that is ok';
				NULL;
			END;
$$;

-- just in case
SELECT schema_support.prepare_for_object_replay();
-- DONE DEALING WITH TABLE v_device_slots
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_device_components_expanded
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_components_expanded', 'v_device_components_expanded');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_device_components_expanded');
DROP VIEW IF EXISTS jazzhands.v_device_components_expanded;
CREATE VIEW jazzhands.v_device_components_expanded AS
 WITH ctf AS (
         SELECT ctcf.component_type_id,
            array_agg(ctcf.component_function ORDER BY ctcf.component_function) AS functions
           FROM component_type_component_func ctcf
          GROUP BY ctcf.component_type_id
        ), disksize AS (
         SELECT cp.component_type_id,
            cp.property_value::bigint AS disk_size
           FROM component_property cp
          WHERE cp.component_property_name::text = 'DiskSize'::text AND cp.component_property_type::text = 'disk'::text
        ), mediatype AS (
         SELECT cp.component_type_id,
            cp.property_value::text AS media_type
           FROM component_property cp
          WHERE cp.component_property_name::text = 'MediaType'::text AND cp.component_property_type::text = 'disk'::text
        ), memsize AS (
         SELECT cp.component_type_id,
            cp.property_value::bigint AS memory_size
           FROM component_property cp
          WHERE cp.component_property_name::text = 'MemorySize'::text AND cp.component_property_type::text = 'memory'::text
        ), memspeed AS (
         SELECT cp.component_type_id,
            cp.property_value::bigint AS memory_speed
           FROM component_property cp
          WHERE cp.component_property_name::text = 'MemorySpeed'::text AND cp.component_property_type::text = 'memory'::text
        )
 SELECT dc.device_id,
    c.component_id,
    s.slot_id,
    comp.company_name AS vendor,
    ct.model,
    a.serial_number,
    ctf.functions,
    s.slot_name,
    memsize.memory_size,
    memspeed.memory_speed,
    disksize.disk_size,
    mediatype.media_type
   FROM v_device_components dc
     JOIN component c ON dc.component_id = c.component_id
     LEFT JOIN asset a ON c.component_id = a.component_id
     JOIN component_type ct USING (component_type_id)
     JOIN ctf USING (component_type_id)
     LEFT JOIN company comp USING (company_id)
     LEFT JOIN disksize USING (component_type_id)
     LEFT JOIN mediatype USING (component_type_id)
     LEFT JOIN memsize USING (component_type_id)
     LEFT JOIN memspeed USING (component_type_id)
     LEFT JOIN slot s ON c.parent_slot_id = s.slot_id;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object = 'v_device_components_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_components_expanded failed but that is ok';
				NULL;
			END;
$$;

-- just in case
SELECT schema_support.prepare_for_object_replay();
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
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
--
-- Process drops in jazzhands_cache
--
-- New function
CREATE OR REPLACE FUNCTION jazzhands_cache.cache_component_parent_handler()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	--
	-- Delete any rows that are invalidated due to a parent change.
	--
	IF
		(TG_OP = 'DELETE' OR TG_OP = 'UPDATE') AND
		OLD.parent_slot_id IS NOT NULL
	THEN
		RAISE DEBUG 'Deleting upstream references to component % from cache',
			OLD.component_id;

		DELETE FROM
			jazzhands_cache.ct_component_hier
		WHERE
			OLD.component_id = ANY (component_path)
			AND component_id != OLD.component_id;
	END IF;

	--
	-- Insert any new rows to correspond with a new parent
	--

	IF (TG_OP = 'INSERT') THEN
		RAISE DEBUG 'Inserting reference for new component % into cache',
			NEW.component_id;

		INSERT INTO jazzhands_cache.ct_component_hier (
			component_id,
			child_component_id,
			component_path,
			level
		) VALUES (
			NEW.component_id,
			NEW.component_id,
			ARRAY[NEW.component_id],
			1
		);
	END IF;
	IF (
		(TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND
		NEW.parent_slot_id IS NOT NULL
	) THEN
		RAISE DEBUG 'Inserting upstream references for updated component % into cache',
			NEW.component_id;
		INSERT INTO jazzhands_cache.ct_component_hier
		SELECT 
			ch.component_id,
			ch2.child_component_id,
			array_cat(ch2.component_path, ch.component_path),
			array_length(ch2.component_path, 1) + array_length(ch.component_path, 1)
		FROM
			jazzhands.slot s
			JOIN jazzhands_cache.ct_component_hier ch ON (
				s.component_id = ch.child_component_id
			),
			jazzhands_cache.ct_component_hier ch2
		WHERE
			s.slot_id = NEW.parent_slot_id
			AND ch2.component_id = NEW.component_id;
	END IF;
	RETURN NULL;
END
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands_cache.cache_device_component_component_handler()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	dev_rec	RECORD;
	dc_rec	RECORD;
BEGIN
	--
	-- Delete any rows that are invalidated due to a parent slot un/reassignment
	--
	IF
		(TG_OP = 'DELETE' OR TG_OP = 'UPDATE') AND
		OLD.parent_slot_id IS NOT NULL
	THEN
		RAISE DEBUG 'Deleting device assignment for component % from cache',
			OLD.component_id;

		--
		-- If we're the top level of a device, nothing below it is going to
		-- change, so just return
		--
		PERFORM * FROM device d WHERE d.component_id = OLD.component_id;

		IF FOUND THEN
			RETURN NULL;
		END IF;
		--
		-- Only delete things belonging to this immediate device
		--
		SELECT * INTO dc_rec FROM jazzhands_cache.ct_device_components dc
		WHERE
			dc.component_id = OLD.component_id;

		IF dc_rec IS NOT NULL THEN
			DELETE FROM
				jazzhands_cache.ct_device_components dc
			WHERE
				OLD.component_id = ANY (component_path)
				AND dc.device_id = dc_rec.device_id;
		END IF;
	END IF;

	--
	-- Insert any new rows to correspond with a new parent
	--

	IF
		(TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND
		NEW.parent_slot_id IS NOT NULL
	THEN
		RAISE DEBUG 'Inserting upstream device references for component % into cache',
			NEW.component_id;

		
		SELECT d.* INTO dev_rec
		FROM
			jazzhands.slot s JOIN
			jazzhands_cache.v_device_components dc USING (component_id) JOIN
			device d USING (device_id)
		WHERE
			s.slot_id = NEW.parent_slot_id;

		IF FOUND THEN
			INSERT INTO jazzhands_cache.ct_device_components (
				device_id,
				component_id,
				component_path,
				level
			) SELECT 
				dev_rec.device_id,
				ch.child_component_id,
				ch.component_path,
				ch.level
			FROM
				jazzhands_cache.ct_component_hier ch
			WHERE
				ch.component_id = dev_rec.component_id
				AND NEW.component_id = ANY(component_path)
				AND NOT (ch.child_component_id IN (
					SELECT
						component_id
					FROM
						jazzhands.device d
					WHERE
						d.component_id IS NOT NULL AND
						d.device_id != dev_rec.device_id
				));
		END IF;
	END IF;
	RETURN NULL;
END
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands_cache.cache_device_component_device_handler()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	--
	-- Delete any rows that are invalidated due to a device un/reassignment
	--
	IF
		(TG_OP = 'DELETE' OR TG_OP = 'UPDATE') AND
		OLD.component_id IS NOT NULL
	THEN
		RAISE DEBUG 'Deleting device assignment for component % from cache',
			OLD.component_id;

		DELETE FROM
			jazzhands_cache.ct_device_components dc
		WHERE
			dc.device_id = OLD.device_id;
	END IF;

	--
	-- Insert any new rows to correspond with a new parent
	--

	IF
		(TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND
		NEW.component_id IS NOT NULL
	THEN
		RAISE DEBUG 'Inserting upstream references for component % into cache',
			NEW.component_id;

		INSERT INTO jazzhands_cache.ct_device_components (
			device_id,
			component_id,
			component_path,
			level
		) SELECT 
			NEW.device_id,
			ch.child_component_id,
			ch.component_path,
			ch.level
		FROM
			jazzhands_cache.ct_component_hier ch
		WHERE
			ch.component_id = NEW.component_id
			AND NOT (ch.child_component_id IN (
				SELECT
					component_id
				FROM
					jazzhands.device d
				WHERE
					d.component_id IS NOT NULL AND
					d.device_id != NEW.device_id
			));
	END IF;
	RETURN NULL;
END
$function$
;

--
-- Process drops in jazzhands
--
-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'netblock_collection_member_enforce');
CREATE OR REPLACE FUNCTION jazzhands.netblock_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
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
			RAISE EXCEPTION 'Netblock may not be a member of more than % collections of type % (% %)',
				nct.MAX_NUM_COLLECTIONS, nct.netblock_collection_type,
				NEW.netblock_collection_id, NEW.netblock_id
				USING ERRCODE = 'unique_violation';
		END IF;
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
 SET search_path TO 'jazzhands'
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
	ELSIF crt.private_key_id IS NOT NULL THEN
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

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_person_company_upd');
CREATE OR REPLACE FUNCTION jazzhands.v_person_company_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	upd_query	TEXT[];
	_pc		person_company%ROWTYPE;
BEGIN
	upd_query := NULL;

	IF NEW.company_id IS DISTINCT FROM OLD.company_id THEN
		upd_query := array_append(upd_query,
			'company_id = ' || quote_nullable(NEW.company_id));
	END IF;
	IF NEW.person_id IS DISTINCT FROM OLD.person_id THEN
		upd_query := array_append(upd_query,
			'person_id = ' || quote_nullable(NEW.person_id));
	END IF;
	IF NEW.person_company_status IS DISTINCT FROM OLD.person_company_status THEN
		upd_query := array_append(upd_query,
			'person_company_status = ' || quote_nullable(NEW.person_company_status));
	END IF;
	IF NEW.person_company_relation IS DISTINCT FROM OLD.person_company_relation THEN
		upd_query := array_append(upd_query,
			'person_company_relation = ' || quote_nullable(NEW.person_company_relation));
	END IF;
	IF NEW.is_exempt IS DISTINCT FROM OLD.is_exempt THEN
		upd_query := array_append(upd_query,
			'is_exempt = ' || quote_nullable(NEW.is_exempt));
	END IF;
	IF NEW.is_management IS DISTINCT FROM OLD.is_management THEN
		upd_query := array_append(upd_query,
			'is_management = ' || quote_nullable(NEW.is_management));
	END IF;
	IF NEW.is_full_time IS DISTINCT FROM OLD.is_full_time THEN
		upd_query := array_append(upd_query,
			'is_full_time = ' || quote_nullable(NEW.is_full_time));
	END IF;
	IF NEW.description IS DISTINCT FROM OLD.description THEN
		upd_query := array_append(upd_query,
			'description = ' || quote_nullable(NEW.description));
	END IF;
	IF NEW.position_title IS DISTINCT FROM OLD.position_title THEN
		upd_query := array_append(upd_query,
			'position_title = ' || quote_nullable(NEW.position_title));
	END IF;
	IF NEW.hire_date IS DISTINCT FROM OLD.hire_date THEN
		upd_query := array_append(upd_query,
			'hire_date = ' || quote_nullable(NEW.hire_date));
	END IF;
	IF NEW.termination_date IS DISTINCT FROM OLD.termination_date THEN
		upd_query := array_append(upd_query,
			'termination_date = ' || quote_nullable(NEW.termination_date));
	END IF;
	IF NEW.manager_person_id IS DISTINCT FROM OLD.manager_person_id THEN
		upd_query := array_append(upd_query,
			'manager_person_id = ' || quote_nullable(NEW.manager_person_id));
	END IF;
	IF NEW.nickname IS DISTINCT FROM OLD.nickname THEN
		upd_query := array_append(upd_query,
			'nickname = ' || quote_nullable(NEW.nickname));
	END IF;

	IF upd_query IS NOT NULL THEN
		EXECUTE 'UPDATE person_company SET ' ||
		array_to_string(upd_query, ', ') ||
		' WHERE company_id = $1 AND person_id = $2 RETURNING *'
		USING OLD.company_id, OLD.person_id
		INTO _pc;

		NEW.company_id := _pc.company_id;
		NEW.person_id := _pc.person_id;
		NEW.person_company_status := _pc.person_company_status;
		NEW.person_company_relation := _pc.person_company_relation;
		NEW.is_exempt := _pc.is_exempt;
		NEW.is_management := _pc.is_management;
		NEW.is_full_time := _pc.is_full_time;
		NEW.description := _pc.description;
		NEW.position_title := _pc.position_title;
		NEW.hire_date := _pc.hire_date;
		NEW.termination_date := _pc.termination_date;
		NEW.manager_person_id := _pc.manager_person_id;
		NEW.nickname := _pc.nickname;
		NEW.data_ins_user := _pc.data_ins_user;
		NEW.data_ins_date := _pc.data_ins_date;
		NEW.data_upd_user := _pc.data_upd_user;
		NEW.data_upd_date := _pc.data_upd_date;
	END IF;

	IF NEW.employee_id IS NOT NULL AND OLD.employee_id IS DISTINCT FROM NEW.employee_id  THEN
		INSERT INTO person_company_attr AS pca (
			company_id, person_id, person_company_attr_name, attribute_value
		) VALUES (
			NEW.company_id, NEW.person_id, 'employee_id', NEW.employee_id
		) ON CONFLICT ON CONSTRAINT pk_person_company_attr
		DO UPDATE
			SET	attribute_value = NEW.employee_id
			WHERE pca.person_company_attr_name = 'employee_id'
			AND pca.person_id = NEW.person_id
			AND pca.company_id = NEW.company_id;

	END IF;

	IF NEW.payroll_id IS NOT NULL AND OLD.payroll_id IS DISTINCT FROM NEW.payroll_id THEN
		INSERT INTO person_company_attr AS pca (
			company_id, person_id, person_company_attr_name, attribute_value
		) VALUES (
			NEW.company_id, NEW.person_id, 'payroll_id', NEW.payroll_id
		) ON CONFLICT ON CONSTRAINT pk_person_company_attr
		DO
			UPDATE
			SET	attribute_value = NEW.payroll_id
			WHERE pca.person_company_attr_name = 'payroll_id'
			AND pca.person_id = NEW.person_id
			AND pca.company_id = NEW.company_id;
	END IF;

	IF NEW.external_hr_id IS NOT NULL AND OLD.external_hr_id IS DISTINCT FROM NEW.external_hr_id THEN
		INSERT INTO person_company_attr AS pca (
			company_id, person_id, person_company_attr_name, attribute_value
		) VALUES (
			NEW.company_id, NEW.person_id, 'external_hr_id', NEW.external_hr_id
		) ON CONFLICT ON CONSTRAINT pk_person_company_attr
		DO
			UPDATE
			SET	attribute_value = NEW.external_hr_id
			WHERE pca.person_company_attr_name = 'external_hr_id'
			AND pca.person_id = NEW.person_id
			AND pca.company_id = NEW.company_id;
	END IF;

	IF NEW.badge_system_id IS NOT NULL AND OLD.badge_system_id IS DISTINCT FROM NEW.badge_system_id THEN
		INSERT INTO person_company_attr AS pca (
			company_id, person_id, person_company_attr_name, attribute_value
		) VALUES (
			NEW.company_id, NEW.person_id, 'badge_system_id', NEW.badge_system_id
		) ON CONFLICT ON CONSTRAINT pk_person_company_attr
		DO
			UPDATE
			SET	attribute_value = NEW.badge_system_id
			WHERE pca.person_company_attr_name = 'badge_system_id'
			AND pca.person_id = NEW.person_id
			AND pca.company_id = NEW.company_id;
	END IF;

	IF NEW.supervisor_person_id IS NOT NULL AND OLD.supervisor_person_id IS DISTINCT FROM NEW.supervisor_person_id THEN
		INSERT INTO person_company_attr AS pca (
			company_id, person_id, person_company_attr_name, attribute_value
		) VALUES (
			NEW.company_id, NEW.person_id, 'supervisor__id', NEW.supervisor_person_id
		) ON CONFLICT ON CONSTRAINT pk_person_company_attr
		DO
			UPDATE
			SET	attribute_value = NEW.supervisor_person_id
			WHERE pca.person_company_attr_name = 'supervisor_id'
			AND pca.person_id = NEW.person_id
			AND pca.company_id = NEW.company_id;
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
DROP FUNCTION IF EXISTS dns_utils.add_ns_records ( dns_domain_id integer );
-- New function
CREATE OR REPLACE FUNCTION dns_utils.add_ns_records(dns_domain_id integer, purge boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	IF purge THEN
		EXECUTE '
			DELETE FROM dns_record
			WHERE dns_domain_id = $1
			AND dns_name IS NULL
			AND dns_class = $2
			AND dns_type = $3
			AND dns_value NOT IN (
				SELECT property_value
				FROM property
				WHERE property_name = $4
				AND property_type = $5
			)
		' USING dns_domain_id, 'IN', 'NS', '_authdns', 'Defaults';
	END IF;
	EXECUTE '
		INSERT INTO dns_record (
			dns_domain_id, dns_class, dns_type, dns_value
		) select $1, $2, $3, property_value
		FROM property
		WHERE property_name = $4
		AND property_type = $5
		AND property_value NOT IN (
			SELECT dns_value
			FROM dns_record
			WHERE dns_domain_id = $1
			AND dns_class = $2
			AND dns_type = $3
			AND dns_name IS NULL
		)
	' USING dns_domain_id, 'IN', 'NS', '_authdns', 'Defaults';
END;
$function$
;

--
-- Process drops in person_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('person_manip', 'add_person');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS person_manip.add_person ( __person_id integer, first_name character varying, middle_name character varying, last_name character varying, name_suffix character varying, gender character varying, preferred_last_name character varying, preferred_first_name character varying, birth_date date, _company_id integer, external_hr_id character varying, person_company_status character varying, is_manager character varying, is_exempt character varying, is_full_time character varying, employee_id character varying, hire_date date, termination_date date, person_company_relation character varying, job_title character varying, department character varying, login character varying, OUT _person_id integer, OUT _account_collection_id integer, OUT _account_id integer );
CREATE OR REPLACE FUNCTION person_manip.add_person(__person_id integer, first_name character varying, middle_name character varying, last_name character varying, name_suffix character varying, gender character varying, preferred_last_name character varying, preferred_first_name character varying, birth_date date, _company_id integer, external_hr_id character varying, person_company_status character varying, is_manager character varying, is_exempt character varying, is_full_time character varying, employee_id character varying, hire_date date, termination_date date, person_company_relation character varying, job_title character varying, department character varying, login character varying, OUT _person_id integer, OUT _account_collection_id integer, OUT _account_id integer)
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

-- Changed function
SELECT schema_support.save_grants_for_replay('person_manip', 'add_user');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS person_manip.add_user ( company_id integer, person_company_relation character varying, login character varying, first_name character varying, middle_name character varying, last_name character varying, name_suffix character varying, gender character varying, preferred_last_name character varying, preferred_first_name character varying, birth_date date, external_hr_id character varying, person_company_status character varying, is_management character varying, is_manager character varying, is_exempt character varying, is_full_time character varying, employee_id text, hire_date date, termination_date date, position_title character varying, job_title character varying, department_name character varying, manager_person_id integer, site_code character varying, physical_address_id integer, person_location_type character varying, description character varying, unix_uid character varying, INOUT person_id integer, OUT dept_account_collection_id integer, OUT account_id integer );
CREATE OR REPLACE FUNCTION person_manip.add_user(company_id integer, person_company_relation character varying, login character varying DEFAULT NULL::character varying, first_name character varying DEFAULT NULL::character varying, middle_name character varying DEFAULT NULL::character varying, last_name character varying DEFAULT NULL::character varying, name_suffix character varying DEFAULT NULL::character varying, gender character varying DEFAULT NULL::character varying, preferred_last_name character varying DEFAULT NULL::character varying, preferred_first_name character varying DEFAULT NULL::character varying, birth_date date DEFAULT NULL::date, external_hr_id character varying DEFAULT NULL::character varying, person_company_status character varying DEFAULT 'enabled'::character varying, is_management character varying DEFAULT 'N'::character varying, is_manager character varying DEFAULT NULL::character varying, is_exempt character varying DEFAULT 'Y'::character varying, is_full_time character varying DEFAULT 'Y'::character varying, employee_id text DEFAULT NULL::text, hire_date date DEFAULT NULL::date, termination_date date DEFAULT NULL::date, position_title character varying DEFAULT NULL::character varying, job_title character varying DEFAULT NULL::character varying, department_name character varying DEFAULT NULL::character varying, manager_person_id integer DEFAULT NULL::integer, site_code character varying DEFAULT NULL::character varying, physical_address_id integer DEFAULT NULL::integer, person_location_type character varying DEFAULT 'office'::character varying, description character varying DEFAULT NULL::character varying, unix_uid character varying DEFAULT NULL::character varying, INOUT person_id integer DEFAULT NULL::integer, OUT dept_account_collection_id integer, OUT account_id integer)
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
	IF is_manager IS NOT NULL THEN
		is_management := is_manager;
	END IF;

	IF job_title IS NOT NULL THEN
		position_title := job_title;
	END IF;

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
                in_account_realm_id := _account_realm_id,
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
        INSERT INTO v_person_company
            (person_id, company_id, external_hr_id, person_company_status, is_management, is_exempt, is_full_time, employee_id, hire_date, termination_date, person_company_relation, position_title, manager_person_id)
            VALUES
            (person_id, company_id, external_hr_id, person_company_status, is_management, is_exempt, is_full_time, employee_id, hire_date, termination_date, person_company_relation, position_title, manager_person_id);
        INSERT INTO person_account_realm_company ( person_id, company_id, account_realm_id) VALUES ( person_id, company_id, _account_realm_id);
    END IF;

    INSERT INTO account ( login, person_id, company_id, account_realm_id, account_status, description, account_role, account_type)
        VALUES (login, person_id, company_id, _account_realm_id, person_company_status, description, 'primary', _account_type)
    RETURNING account.account_id INTO account_id;

    IF department_name IS NOT NULL THEN
        dept_account_collection_id = person_manip.get_account_collection_id(department_name, 'department');
        INSERT INTO account_collection_account (account_collection_id, account_id) VALUES ( dept_account_collection_id, account_id);
    END IF;

    IF site_code IS NOT NULL AND physical_address_id IS NOT NULL THEN
        RAISE EXCEPTION 'You must provide either site_code or physical_address_id NOT both';
    END IF;

    IF site_code IS NULL AND physical_address_id IS NOT NULL THEN
        site_code = person_manip.get_site_code_from_physical_address_id(physical_address_id);
    END IF;

    IF physical_address_id IS NULL AND site_code IS NOT NULL THEN
        physical_address_id = person_manip.get_physical_address_from_site_code(site_code);
    END IF;

    IF physical_address_id IS NOT NULL AND site_code IS NOT NULL THEN
        INSERT INTO person_location
            (person_id, person_location_type, site_code, physical_address_id)
        VALUES
            (person_id, person_location_type, site_code, physical_address_id);
    END IF;


    IF unix_uid IS NOT NULL THEN
        _accountid = account_id;
        SELECT  aui.account_id
          INTO  _uxaccountid
          FROM  account_unix_info aui
        WHERE  aui.account_id = _accountid;

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

-- Changed function
SELECT schema_support.save_grants_for_replay('person_manip', 'change_company');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS person_manip.change_company ( final_company_id integer, _person_id integer, initial_company_id integer, _account_realm_id integer );
CREATE OR REPLACE FUNCTION person_manip.change_company(final_company_id integer, _person_id integer, initial_company_id integer, _account_realm_id integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands', 'pg_temp'
AS $function$
DECLARE
	initial_person_company  person_company%ROWTYPE;
	_arid			account_realm.account_realm_id%TYPE;
BEGIN
	IF _account_realm_id IS NULL THEN
		SELECT	account_realm_id
		INTO	_arid
		FROM	property
		WHERE	property_type = 'Defaults'
		AND	property_name = '_root_account_realm_id';
	ELSE
		_arid := _account_realm_id;
	END IF;
	set constraints fk_ac_ac_rlm_cpy_act_rlm_cpy DEFERRED;
	set constraints fk_account_prsn_cmpy_acct DEFERRED;
	set constraints fk_account_company_person DEFERRED;
	set constraints fk_pers_comp_attr_person_comp_id DEFERRED;

	UPDATE person_account_realm_company
		SET company_id = final_company_id
	WHERE person_id = _person_id
	AND company_id = initial_company_id
	AND account_realm_id = _arid;

	SELECT *
	INTO initial_person_company
	FROM person_company
	WHERE person_id = _person_id
	AND company_id = initial_company_id;

	UPDATE person_company
	SET company_id = final_company_id
	WHERE company_id = initial_company_id
	AND person_id = _person_id;

	UPDATE person_company_attr
	SET company_id = final_company_id
	WHERE company_id = initial_company_id
	AND person_id = _person_id;

	UPDATE account
	SET company_id = final_company_id
	WHERE company_id = initial_company_id
	AND person_id = _person_id
	AND account_realm_id = _arid;

	set constraints fk_ac_ac_rlm_cpy_act_rlm_cpy IMMEDIATE;
	set constraints fk_account_prsn_cmpy_acct IMMEDIATE;
	set constraints fk_account_company_person IMMEDIATE;
	set constraints fk_pers_comp_attr_person_comp_id IMMEDIATE;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('person_manip', 'guess_person_id');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS person_manip.guess_person_id ( first_name text, last_name text, login text, company_id integer );
CREATE OR REPLACE FUNCTION person_manip.guess_person_id(first_name text, last_name text, login text, company_id integer DEFAULT NULL::integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands', 'pg_temp'
AS $function$
DECLARE
	pid		person.person_id%TYPE;
	_l		text;
BEGIN
	-- see if that login name is alradeady associated with someone with the
	-- same first and last name
	EXECUTE '
		SELECT person_id
		FROM	person
				JOIN account USING (person_id,$2)
		WHERE	login = $1
		AND		first_name = $3
		AND		last_name = $4
	' INTO pid USING login, company_id, first_name, last_name;

	IF pid IS NOT NULL THEN
		RETURN pid;
	END IF;

	_l = regexp_replace(login, '@.*$', '');

	IF _l != login THEN
		EXECUTE '
			SELECT person_id
			FROM	person
					JOIN account USING (person_id,$2)
			WHERE	login = $1
			AND		first_name = $3
			AND		last_name = $4
		' INTO pid USING _l, company_id, first_name, last_name;

		IF pid IS NOT NULL THEN
			RETURN pid;
		END IF;
	END IF;

	RETURN NULL;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('person_manip', 'merge_accounts');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS person_manip.merge_accounts ( merge_from_account_id integer, merge_to_account_id integer );
CREATE OR REPLACE FUNCTION person_manip.merge_accounts(merge_from_account_id integer, merge_to_account_id integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	fpc		v_person_company%ROWTYPE;
	tpc		v_person_company%ROWTYPE;
	_account_realm_id INTEGER;
BEGIN
	select	*
	  into	fpc
	  from	v_person_company
	 where	(person_id, company_id) in
		(select person_id, company_id
		   from account where account_id = merge_from_account_id);

	select	*
	  into	tpc
	  from	v_person_company
	 where	(person_id, company_id) in
		(select person_id, company_id
		   from account where account_id = merge_to_account_id);

	IF (fpc.company_id != tpc.company_id) THEN
		RAISE EXCEPTION 'Accounts are in different companies';
	END IF;

	IF (fpc.person_company_relation != tpc.person_company_relation) THEN
		RAISE EXCEPTION 'People have different relationships';
	END IF;

	IF(tpc.external_hr_id is NOT NULL AND fpc.external_hr_id IS NULL) THEN
		RAISE EXCEPTION 'Destination account has an external HR ID and origin account has none';
	END IF;

	-- move any account collections over that are
	-- not infrastructure ones, and the new person is
	-- not in
	UPDATE	account_collection_account
	   SET	ACCOUNT_ID = merge_to_account_id
	 WHERE	ACCOUNT_ID = merge_from_account_id
	  AND	ACCOUNT_COLLECTION_ID IN (
			SELECT ACCOUNT_COLLECTION_ID
			  FROM	ACCOUNT_COLLECTION
				INNER JOIN VAL_ACCOUNT_COLLECTION_TYPE
					USING (ACCOUNT_COLLECTION_TYPE)
			 WHERE	IS_INFRASTRUCTURE_TYPE = 'N'
		)
	  AND	account_collection_id not in (
			SELECT	account_collection_id
			  FROM	account_collection_account
			 WHERE	account_id = merge_to_account_id
	);


	-- Now begin removing the old account
	PERFORM person_manip.purge_account( merge_from_account_id );

	-- Switch person_ids
	DELETE FROM person_account_realm_company WHERE person_id = fpc.person_id AND company_id = tpc.company_id;
	SELECT account_realm_id INTO _account_realm_id FROM account_realm_company WHERE company_id = tpc.company_id;
	INSERT INTO person_account_realm_company (person_id, company_id, account_realm_id) VALUES ( fpc.person_id , tpc.company_id, _account_realm_id);
	UPDATE account SET account_realm_id = _account_realm_id, person_id = fpc.person_id WHERE person_id = tpc.person_id AND company_id = fpc.company_id;
	DELETE FROM person_company_attr WHERE person_id = tpc.person_id AND company_id = tpc.company_id;
	DELETE FROM person_company WHERE person_id = tpc.person_id AND company_id = tpc.company_id;
	DELETE FROM person_account_realm_company WHERE person_id = tpc.person_id AND company_id = tpc.company_id;
	UPDATE person_image SET person_id = fpc.person_id WHERE person_id = tpc.person_id;
	-- if there are other relations that may exist, do not delete the person.
	BEGIN
		delete from person where person_id = tpc.person_id;
	EXCEPTION WHEN foreign_key_violation THEN
		NULL;
	END;

	return merge_to_account_id;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('person_manip', 'purge_account');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS person_manip.purge_account ( in_account_id integer );
CREATE OR REPLACE FUNCTION person_manip.purge_account(in_account_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	-- note the per-account account collection is removed in triggers

	DELETE FROM account_assignd_cert where ACCOUNT_ID = in_account_id;
	DELETE FROM account_token where ACCOUNT_ID = in_account_id;
	DELETE FROM account_unix_info where ACCOUNT_ID = in_account_id;
	DELETE FROM klogin where ACCOUNT_ID = in_account_id;
	DELETE FROM property where ACCOUNT_ID = in_account_id;
	DELETE FROM property where account_collection_id in
		(select account_collection_id from account_collection
			where account_collection_name in
				(select login from account where account_id = in_account_id)
				and account_collection_type in ('per-account')
		);
	DELETE FROM account_password where ACCOUNT_ID = in_account_id;
	DELETE FROM unix_group where account_collection_id in
		(select account_collection_id from account_collection
			where account_collection_name in
				(select login from account where account_id = in_account_id)
				and account_collection_type in ('unix-group')
		);
	DELETE FROM account_collection_account where ACCOUNT_ID = in_account_id;

	DELETE FROM account_collection where account_collection_name in
		(select login from account where account_id = in_account_id)
		and account_collection_type in ('per-account', 'unix-group');

	DELETE FROM account_ssh_key where ACCOUNT_ID = in_account_id;
	DELETE FROM account where ACCOUNT_ID = in_account_id;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('person_manip', 'purge_person');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS person_manip.purge_person ( in_person_id integer );
CREATE OR REPLACE FUNCTION person_manip.purge_person(in_person_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	aid	INTEGER;
BEGIN
	FOR aid IN select account_id
			FROM account
			WHERE person_id = in_person_id
	LOOP
		PERFORM person_manip.purge_account ( aid );
	END LOOP;

	DELETE FROM person_company_attr WHERE person_id = in_person_id;
	DELETE FROM person_contact WHERE person_id = in_person_id;
	DELETE FROM person_location WHERE person_id = in_person_id;
	DELETE FROM v_person_company WHERE person_id = in_person_id;
	DELETE FROM person_account_realm_company WHERE person_id = in_person_id;
	DELETE FROM person WHERE person_id = in_person_id;
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
 RETURNS void
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

	DELETE FROM
		layer2_network l2n
	WHERE
		l2n.layer2_network_id = ANY(layer2_network_id_list);

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
 RETURNS void
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

	WITH x AS (
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
	)
	DELETE FROM
		jazzhands.netblock
	WHERE
		netblock_id IN (SELECT netblock_id FROM x);

	BEGIN
		PERFORM local_hooks.delete_layer3_networks_after_hooks(
			layer3_network_id_list := layer3_network_id_list
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

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
-- Changed function
SELECT schema_support.save_grants_for_replay('device_utils', 'remove_network_interfaces');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_utils.remove_network_interfaces ( network_interface_id_list integer[] );
CREATE OR REPLACE FUNCTION device_utils.remove_network_interfaces(network_interface_id_list integer[])
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	nb_list		integer[];
	sn_list		integer[];
	sn_rec		RECORD;
	nb_id		jazzhands.netblock.netblock_id%TYPE;
BEGIN
	--
	-- Save off some netblock information for now
	--

	RAISE LOG 'Removing network_interfaces with ids %',
		array_to_string(network_interface_id_list, ', ');

	RAISE LOG 'Retrieving netblock information...';

	SELECT
		array_agg(nin.netblock_id) INTO nb_list
	FROM
		network_interface_netblock nin
	WHERE
		nin.network_interface_id = ANY(network_interface_id_list);

	SELECT DISTINCT
		array_agg(shared_netblock_id) INTO sn_list
	FROM
		shared_netblock_network_int snni
	WHERE
		snni.network_interface_id = ANY(network_interface_id_list);

	--
	-- Clean up network bits
	--

	RAISE LOG 'Removing shared netblocks...';

	DELETE FROM shared_netblock_network_int WHERE
		network_interface_id IN (
			SELECT
				network_interface_id
			FROM
				network_interface ni
			WHERE
				ni.network_interface_id = ANY(network_interface_id_list)
		);

	--
	-- Clean up things for any shared_netblocks which are now orphaned
	-- Unfortunately, we have to do these as individual queries to catch
	-- exceptions
	--
	FOR sn_rec IN SELECT
		shared_netblock_id,
		netblock_id
	FROM
		shared_netblock s LEFT JOIN
		shared_netblock_network_int USING (shared_netblock_id)
	WHERE
		shared_netblock_id = ANY(sn_list) AND
		network_interface_id IS NULL
	LOOP
		BEGIN
			DELETE FROM dns_record dr WHERE
				dr.netblock_id = sn_rec.netblock_id;
			DELETE FROM shared_netblock sn WHERE
				sn.shared_netblock_id = sn_rec.shared_netblock_id;
			BEGIN
				DELETE FROM netblock n WHERE
					n.netblock_id = sn_rec.netblock_id;
			EXCEPTION WHEN foreign_key_violation THEN
				NULL;
			END;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	END LOOP;

	RAISE LOG 'Removing directly-assigned netblocks...';

	DELETE FROM network_interface_netblock WHERE network_interface_id IN (
		SELECT
			network_interface_id
	 	FROM
			network_interface ni
		WHERE
			ni.network_interface_id = ANY (network_interface_id_list)
	);

	RAISE LOG 'Removing network_interfaces...';

	DELETE FROM network_interface_purpose nip WHERE
		nip.network_interface_id = ANY(network_interface_id_list);

	DELETE FROM network_interface ni WHERE ni.network_interface_id =
		ANY(network_interface_id_list);

	RAISE LOG 'Removing netblocks (%) ... ', nb_list; 
	IF nb_list IS NOT NULL THEN
		FOREACH nb_id IN ARRAY nb_list LOOP
			BEGIN
				DELETE FROM dns_record WHERE netblock_id = nb_id;

				DELETE FROM netblock n WHERE
					n.netblock_id = nb_id;
			EXCEPTION WHEN foreign_key_violation THEN
				NULL;
			END;
		END LOOP;
	END IF;

	RETURN true;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('device_utils', 'retire_devices');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_utils.retire_devices ( device_id_list integer[] );
CREATE OR REPLACE FUNCTION device_utils.retire_devices(device_id_list integer[])
 RETURNS TABLE(device_id integer, success boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	nb_list		integer[];
	sn_list		integer[];
	sn_rec		RECORD;
	rl_list		integer[];
	dev_id		jazzhands.device.device_id%TYPE;
	se_id		jazzhands.service_environment.service_environment_id%TYPE;
	nb_id		jazzhands.netblock.netblock_id%TYPE;
BEGIN
	BEGIN
		PERFORM local_hooks.retire_devices_early(device_id_list);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;
	--
	-- Add all of the BMCs for any retiring devices to the list in case
	-- they are not specified
	--
	device_id_list := array_cat(
		device_id_list,
		(SELECT
			array_agg(manager_device_id)
		FROM
			device_management_controller dmc
		WHERE
			dmc.device_id = ANY(device_id_list) AND
			device_mgmt_control_type = 'bmc'
		)
	);

	--
	-- Delete network_interfaces
	--
	PERFORM device_utils.remove_network_interfaces(
		network_interface_id_list := ARRAY(
			SELECT
				network_interface_id
			FROM
				network_interface ni
			WHERE
				ni.device_id = ANY(device_id_list)
		)
	);

	RAISE LOG 'Removing inter_component_connections...';

	WITH s AS (
		SELECT DISTINCT
			slot_id
		FROM
			v_device_slots ds
		WHERE
			ds.device_id = ANY(device_id_list)
	)
	DELETE FROM inter_component_connection WHERE
		slot1_id IN (SELECT slot_id FROM s) OR
		slot2_id IN (SELECT slot_id FROM s);

	RAISE LOG 'Removing device properties...';

	DELETE FROM property WHERE device_collection_id IN (
		SELECT
			dc.device_collection_id
		FROM
			device_collection dc JOIN
			device_collection_device dcd USING (device_collection_id)
		WHERE
			dc.device_collection_type = 'per-device' AND
			dcd.device_id = ANY(device_id_list)
	);

	RAISE LOG 'Removing per-device device_collections...';

	DELETE FROM
		device_collection_device dcd
	WHERE
		dcd.device_id = ANY(device_id_list) AND
		device_collection_id NOT IN (
			SELECT
				device_collection_id
			FROM
				device_collection
			WHERE
				device_collection_type = 'per-device'
		);

	--
	-- Make sure all rack_location stuff has been cleared out
	--

	RAISE LOG 'Removing rack_locations...';

	SELECT array_agg(rack_location_id) INTO rl_list FROM (
		SELECT DISTINCT
			rack_location_id
		FROM
			device d
		WHERE
			d.device_id = ANY(device_id_list) AND
			rack_location_id IS NOT NULL
		UNION
		SELECT DISTINCT
			rack_location_id
		FROM
			component c JOIN
			v_device_components dc USING (component_id)
		WHERE
			dc.device_id = ANY(device_id_list) AND
			rack_location_id IS NOT NULL
	) x;

	UPDATE
		device d
	SET
		rack_location_id = NULL
	WHERE
		d.device_id = ANY(device_id_list) AND
		rack_location_id IS NOT NULL;

	UPDATE
		component
	SET
		rack_location_id = NULL
	WHERE
		component_id IN (
			SELECT
				component_id
			FROM
				v_device_components dc
			WHERE
				dc.device_id = ANY(device_id_list)
		) AND
		rack_location_id IS NOT NULL;

	--
	-- Delete any now-abandoned rack_locations
	--
	DELETE FROM
		rack_location rl
	WHERE
		rack_location_id = ANY (rl_list) AND
		rack_location_id NOT IN (
			SELECT
				rack_location_id
			FROM
				device
			WHERE
				rack_location_id IS NOT NULL
			UNION
			SELECT
				rack_location_id
			FROM
				component
			WHERE
				rack_location_id IS NOT NULL
		);

	RAISE LOG 'Removing device_management_controller links...';

	DELETE FROM device_management_controller dmc WHERE
		dmc.device_id = ANY (device_id_list) OR
		manager_device_id = ANY (device_id_list);

	RAISE LOG 'Removing device_encapsulation_domain entries...';

	DELETE FROM device_encapsulation_domain ded WHERE
		ded.device_id = ANY (device_id_list);

	--
	-- Clear out all of the logical_volume crap
	--
	RAISE LOG 'Removing logical volume hierarchies...';
	SET CONSTRAINTS ALL DEFERRED;

	DELETE FROM volume_group_physicalish_vol vgpv WHERE
		vgpv.device_id = ANY (device_id_list);
	DELETE FROM physicalish_volume pv WHERE
		pv.device_id = ANY (device_id_list);

	WITH z AS (
		DELETE FROM volume_group vg
		WHERE vg.device_id = ANY (device_id_list)
		RETURNING vg.volume_group_id
	)
	DELETE FROM volume_group_purpose WHERE
		volume_group_id IN (SELECT volume_group_id FROM z);

	WITH z AS (
		DELETE FROM logical_volume lv
		WHERE lv.device_id = ANY (device_id_list)
		RETURNING lv.logical_volume_id
	), y AS (
		DELETE FROM logical_volume_purpose WHERE
			logical_volume_id IN (SELECT logical_volume_id FROM z)
	)
	DELETE FROM logical_volume_property WHERE
		logical_volume_id IN (SELECT logical_volume_id FROM z);

	SET CONSTRAINTS ALL IMMEDIATE;

	--
	-- Attempt to delete all of the devices
	--
	SELECT service_environment_id INTO se_id FROM service_environment WHERE
		service_environment_name = 'unallocated';

	FOREACH dev_id IN ARRAY device_id_list LOOP
		RAISE LOG 'Deleting device %', dev_id;

		BEGIN
			DELETE FROM device_note dn WHERE dn.device_id = dev_id;

			DELETE FROM device d WHERE d.device_id = dev_id;
			device_id := dev_id;
			success := true;
			RETURN NEXT;
		EXCEPTION
			WHEN foreign_key_violation THEN
				UPDATE device d SET
					device_name = NULL,
					component_id = NULL,
					service_environment_id = se_id,
					device_status = 'removed',
					is_monitored = 'N',
					should_fetch_config = 'N',
					description = NULL
				WHERE
					d.device_id = dev_id;

				device_id := dev_id;
				success := false;
				RETURN NEXT;
		END;
	END LOOP;

	BEGIN
		PERFORM local_hooks.retire_devices_late(device_id_list);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;
	RETURN;
END;
$function$
;

--
-- Process drops in netblock_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_free_netblocks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_free_netblocks ( parent_netblock_list integer[], netmask_bits integer, single_address boolean, allocation_method text, max_addresses integer, desired_ip_address inet, rnd_masklen_threshold integer, rnd_max_count integer );
CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblocks(parent_netblock_list integer[], netmask_bits integer DEFAULT NULL::integer, single_address boolean DEFAULT false, allocation_method text DEFAULT NULL::text, max_addresses integer DEFAULT 1024, desired_ip_address inet DEFAULT NULL::inet, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024)
 RETURNS TABLE(ip_address inet, netblock_type character varying, ip_universe_id integer)
 LANGUAGE plpgsql
AS $function$
DECLARE
	parent_nbid		jazzhands.netblock.netblock_id%TYPE;
	netblock_rec	jazzhands.netblock%ROWTYPE;
	netrange_rec	RECORD;
	inet_list		inet[];
	current_ip		inet;
	saved_method	text;
	min_ip			inet;
	max_ip			inet;
	matches			integer;
	rnd_matches		integer;
	max_rnd_value	bigint;
	rnd_value		bigint;
	family_bits		integer;
BEGIN
	matches := 0;
	saved_method = allocation_method;

	IF allocation_method IS NOT NULL AND allocation_method
			NOT IN ('top', 'bottom', 'random', 'default') THEN
		RAISE 'address_type must be one of top, bottom, random, or default'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	--
	-- Sanitize masklen input.  This is a little complicated.
	--
	-- If a single address is desired, we always use a /32 or /128
	-- in the parent loop and everything else is ignored
	--
	-- Otherwise, if netmask_bits is passed, that wins, otherwise
	-- the netmask of whatever is passed with desired_ip_address wins
	--
	-- If none of these are the case, then things are wrong and we
	-- bail
	--

	IF NOT single_address THEN 
		IF desired_ip_address IS NOT NULL AND netmask_bits IS NULL THEN
			netmask_bits := masklen(desired_ip_address);
		ELSIF desired_ip_address IS NOT NULL AND 
				netmask_bits IS NOT NULL THEN
			desired_ip_address := set_masklen(desired_ip_address,
				netmask_bits);
		END IF;
		IF netmask_bits IS NULL THEN
			RAISE EXCEPTION 'netmask_bits must be set'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;
		IF allocation_method = 'random' THEN
			RAISE EXCEPTION 'random netblocks may only be returned for single addresses'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	FOREACH parent_nbid IN ARRAY parent_netblock_list LOOP
		rnd_matches := 0;
		--
		-- Restore this, because we may have overrridden it for a previous
		-- block
		--
		allocation_method = saved_method;
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

		-- If desired_ip_address is passed, then allocation_method is
		-- irrelevant

		IF desired_ip_address IS NOT NULL THEN
			--
			-- If the IP address is not the same family as the parent block,
			-- we aren't going to find it
			--
			IF family(desired_ip_address) != 
					family(netblock_rec.ip_address) THEN
				CONTINUE;
			END IF;
			allocation_method := 'bottom';
		END IF;

		--
		-- If allocation_method is 'default' or NULL, then use 'bottom'
		-- unless it's for a single IPv6 address in a netblock larger than 
		-- rnd_masklen_threshold
		--
		IF allocation_method IS NULL OR allocation_method = 'default' THEN
			allocation_method := 
				CASE WHEN 
					single_address AND 
					family(netblock_rec.ip_address) = 6 AND
					masklen(netblock_rec.ip_address) <= rnd_masklen_threshold
				THEN
					'random'
				ELSE
					'bottom'
				END;
		END IF;

		IF allocation_method = 'random' AND 
				family_bits - masklen(netblock_rec.ip_address) < 2 THEN
			-- Random allocation doesn't work if we don't have enough
			-- bits to play with, so just do sequential.
			allocation_method := 'bottom';
		END IF;

		IF single_address THEN 
			netmask_bits := family_bits;
			IF desired_ip_address IS NOT NULL THEN
				desired_ip_address := set_masklen(desired_ip_address,
					masklen(netblock_rec.ip_address));
			END IF;
		ELSIF netmask_bits <= masklen(netblock_rec.ip_address) THEN
			-- If the netmask is not for a smaller netblock than this parent,
			-- then bounce to the next one, because maybe it's larger
			RAISE DEBUG
				'netblock (%) is not larger than netmask_bits of % - skipping',
				masklen(netblock_rec.ip_address),
				netmask_bits;
			CONTINUE;
		END IF;

		IF netmask_bits > family_bits THEN
			RAISE EXCEPTION 'netmask_bits must be no more than % for netblock %',
				family_bits,
				netblock_rec.ip_address;
		END IF;

		--
		-- Short circuit the check if we're looking for a specific address
		-- and it's not in this netblock
		--

		IF desired_ip_address IS NOT NULL AND
				NOT (desired_ip_address <<= netblock_rec.ip_address) THEN
			RAISE DEBUG 'desired_ip_address % is not in netblock %',
				desired_ip_address,
				netblock_rec.ip_address;
			CONTINUE;
		END IF;

		IF single_address AND netblock_rec.can_subnet = 'Y' THEN
			RAISE EXCEPTION 'single addresses may not be assigned to to a block where can_subnet is Y';
		END IF;

		IF (NOT single_address) AND netblock_rec.can_subnet = 'N' THEN
			RAISE EXCEPTION 'Netblock % (%) may not be subnetted',
				netblock_rec.ip_address,
				netblock_rec.netblock_id;
		END IF;

		RAISE DEBUG 'Searching netblock % (%) using the % allocation method',
			netblock_rec.netblock_id,
			netblock_rec.ip_address,
			allocation_method;

		IF desired_ip_address IS NOT NULL THEN
			min_ip := desired_ip_address;
			max_ip := desired_ip_address + 1;
		ELSE
			min_ip := netblock_rec.ip_address;
			max_ip := broadcast(min_ip) + 1;
		END IF;

		IF allocation_method = 'top' THEN
			current_ip := network(set_masklen(max_ip - 1, netmask_bits));
		ELSIF allocation_method = 'random' THEN
			max_rnd_value := (x'7fffffffffffffff'::bigint >> CASE 
				WHEN family_bits - masklen(netblock_rec.ip_address) >= 63
				THEN 0
				ELSE 63 - (family_bits - masklen(netblock_rec.ip_address))
				END) - 2;
			-- random() appears to only do 32-bits, which is dumb
			-- I'm pretty sure that all of the casts are not required here,
			-- but better to make sure
			current_ip := min_ip + 
					((((random() * x'7fffffff'::bigint)::bigint << 32) + 
					(random() * x'ffffffff'::bigint)::bigint + 1)
					% max_rnd_value) + 1;
		ELSE -- it's 'bottom'
			current_ip := set_masklen(min_ip, netmask_bits);
		END IF;

		-- For single addresses, make the netmask match the netblock of the
		-- containing block, and skip the network and broadcast addresses
		-- We shouldn't need to skip for IPv6 addresses, but some things
		-- apparently suck

		IF single_address THEN
			current_ip := set_masklen(current_ip, 
				masklen(netblock_rec.ip_address));
			--
			-- If we're not allocating a single /31 or /32 for IPv4 or
			-- /127 or /128 for IPv6, then we want to skip the all-zeros
			-- and all-ones addresses
			--
			IF masklen(netblock_rec.ip_address) < (family_bits - 1) AND
					desired_ip_address IS NULL THEN
				current_ip := current_ip + 
					CASE WHEN allocation_method = 'top' THEN -1 ELSE 1 END;
				min_ip := min_ip + 1;
				max_ip := max_ip - 1;
			END IF;
		END IF;

		RAISE DEBUG 'Starting with IP address % with step masklen of %',
			current_ip,
			netmask_bits;

		WHILE (
				current_ip >= min_ip AND
				current_ip < max_ip AND
				matches < max_addresses AND
				rnd_matches < rnd_max_count
		) LOOP
			RAISE DEBUG '   Checking netblock %', current_ip;

			IF single_address THEN
				--
				-- Check to see if netblock is in a network_range, and if it is,
				-- then set the value to the top or bottom of the range, or
				-- another random value as appropriate
				--
				SELECT 
					network_range_id,
					start_nb.ip_address AS start_ip_address,
					stop_nb.ip_address AS stop_ip_address
				INTO netrange_rec
				FROM
					jazzhands.network_range nr,
					jazzhands.netblock start_nb,
					jazzhands.netblock stop_nb
				WHERE
					family(current_ip) = family(start_nb.ip_address) AND
					family(current_ip) = family(stop_nb.ip_address) AND
					(
						nr.start_netblock_id = start_nb.netblock_id AND
						nr.stop_netblock_id = stop_nb.netblock_id AND
						nr.parent_netblock_id = netblock_rec.netblock_id AND
						start_nb.ip_address <=
							set_masklen(current_ip, masklen(start_nb.ip_address))
						AND stop_nb.ip_address >=
							set_masklen(current_ip, masklen(stop_nb.ip_address))
					);

				IF FOUND THEN
					current_ip := CASE 
						WHEN allocation_method = 'bottom' THEN
							netrange_rec.stop_ip_address + 1
						WHEN allocation_method = 'top' THEN
							netrange_rec.start_ip_address - 1
						ELSE min_ip + ((
							((random() * x'7fffffff'::bigint)::bigint << 32) 
							+ 
							(random() * x'ffffffff'::bigint)::bigint + 1
							) % max_rnd_value) + 1 
					END;
					CONTINUE;
				END IF;
			END IF;
							
				
			PERFORM * FROM jazzhands.netblock n WHERE
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
			IF NOT FOUND AND (inet_list IS NULL OR
					NOT (current_ip = ANY(inet_list))) THEN
				find_free_netblocks.netblock_type :=
					netblock_rec.netblock_type;
				find_free_netblocks.ip_universe_id :=
					netblock_rec.ip_universe_id;
				find_free_netblocks.ip_address := current_ip;
				RETURN NEXT;
				inet_list := array_append(inet_list, current_ip);
				matches := matches + 1;
				-- Reset random counter if we found something
				rnd_matches := 0;
			ELSIF allocation_method = 'random' THEN
				-- Increase random counter if we didn't find something
				rnd_matches := rnd_matches + 1;
			END IF;

			-- Select the next IP address
			current_ip := 
				CASE WHEN single_address THEN
					CASE 
						WHEN allocation_method = 'bottom' THEN current_ip + 1
						WHEN allocation_method = 'top' THEN current_ip - 1
						ELSE min_ip + ((
							((random() * x'7fffffff'::bigint)::bigint << 32) 
							+ 
							(random() * x'ffffffff'::bigint)::bigint + 1
							) % max_rnd_value) + 1 
					END
				ELSE
					CASE WHEN allocation_method = 'bottom' THEN 
						network(broadcast(current_ip) + 1)
					ELSE 
						network(current_ip - 1)
					END
				END;
		END LOOP;
	END LOOP;
	RETURN;
END;
$function$
;

--
-- Process drops in property_utils
--
--
-- Process drops in netblock_manip
--
DROP FUNCTION IF EXISTS netblock_manip.create_network_range ( start_ip_address inet, stop_ip_address inet, network_range_type character varying, parent_netblock_id integer, description character varying, allow_assigned boolean );
-- New function
CREATE OR REPLACE FUNCTION netblock_manip.create_network_range(start_ip_address inet, stop_ip_address inet, network_range_type character varying, parent_netblock_id integer DEFAULT NULL::integer, description character varying DEFAULT NULL::character varying, allow_assigned boolean DEFAULT false, dns_prefix text DEFAULT NULL::text, dns_domain_id integer DEFAULT NULL::integer, lease_time integer DEFAULT NULL::integer)
 RETURNS network_range
 LANGUAGE plpgsql
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

--
-- Process drops in physical_address_utils
--
--
-- Process drops in component_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'insert_component_into_parent_slot');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.insert_component_into_parent_slot ( parent_component_id integer, component_id integer, slot_name text, slot_function text, slot_type text, slot_index integer, physical_label text );
CREATE OR REPLACE FUNCTION component_utils.insert_component_into_parent_slot(parent_component_id integer, component_id integer, slot_name text, slot_function text, slot_type text DEFAULT 'unknown'::text, slot_index integer DEFAULT NULL::integer, physical_label text DEFAULT NULL::text)
 RETURNS slot
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	pcid 	ALIAS FOR parent_component_id;
	cid		ALIAS FOR component_id;
	sf		ALIAS FOR slot_function;
	sn		ALIAS FOR slot_name;
	st		ALIAS FOR slot_type;
	s		RECORD;
	stid	integer;
BEGIN
	--
	-- Look for this slot assigned to the component
	--
	SELECT
		slot.* INTO s
	FROM
		slot JOIN
		slot_type USING (slot_type_id)
	WHERE
		slot.component_id = pcid AND
		slot_type.slot_type = st AND
		slot_type.slot_function = sf AND
		slot.slot_name = sn;

	IF NOT FOUND THEN
		RAISE DEBUG 'Auto-creating slot for component assignment';
		SELECT
			slot_type_id INTO stid
		FROM
			slot_type
		WHERE
			slot_type.slot_type = st AND
			slot_type.slot_function = sf;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type %, function % not found adding component_type',
				st,
				sf
				USING ERRCODE = 'JH501';
		END IF;

		INSERT INTO slot (
			component_id,
			slot_name,
			slot_index,
			slot_type_id,
			physical_label,
			description
		) VALUES (
			pcid,
			sn,
			slot_index,
			stid,
			physical_label,
			'autocreated component slot'
		) RETURNING * INTO s;
	END IF;

	RAISE DEBUG 'Assigning component with component_id % to slot %',
		cid, s.slot_id;

	UPDATE 
		component c
	SET
		parent_slot_id = s.slot_id
	WHERE
		c.component_id = cid;

	RETURN s;
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
DROP FUNCTION IF EXISTS backend_utils.relation_last_changed ( view text );
-- New function
CREATE OR REPLACE FUNCTION backend_utils.relation_last_changed(view text, schema text DEFAULT 'jazzhands'::text)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	RETURN schema_support.relation_last_changed(view, schema);
END;
$function$
;

--
-- Process drops in rack_utils
--
-- Dropping obsoleted sequences....


-- Dropping obsoleted audit sequences....


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
ALTER TABLE appaal_instance DROP CONSTRAINT IF EXISTS fk_appaal_i_reference_fo_accti;
ALTER TABLE appaal_instance
	ADD CONSTRAINT fk_appaal_i_reference_fo_acctid
	FOREIGN KEY (file_owner_account_id) REFERENCES account(account_id);

ALTER TABLE dns_domain_collection_dns_dom DROP CONSTRAINT IF EXISTS fk_dns_dom_coll_dns_dom_dns_do;
ALTER TABLE dns_domain_collection_dns_dom
	ADD CONSTRAINT fk_dns_dom_coll_dns_dom_dns_dom_id
	FOREIGN KEY (dns_domain_collection_id) REFERENCES dns_domain_collection(dns_domain_collection_id);

ALTER TABLE network_interface_purpose DROP CONSTRAINT IF EXISTS fk_netint_purp_dev_ni_id;
ALTER TABLE network_interface_purpose
	ADD CONSTRAINT fk_netint_purp_dev_ni_id
	FOREIGN KEY (network_interface_id, device_id) REFERENCES network_interface(network_interface_id, device_id) DEFERRABLE;

ALTER TABLE network_interface_purpose DROP CONSTRAINT IF EXISTS fk_netint_purpose_device_id;
ALTER TABLE network_interface_purpose
	ADD CONSTRAINT fk_netint_purpose_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id) DEFERRABLE;

ALTER TABLE network_interface_purpose DROP CONSTRAINT IF EXISTS fk_netint_purpose_val_netint_p;
ALTER TABLE network_interface_purpose
	ADD CONSTRAINT fk_netint_purpose_val_netint_purp
	FOREIGN KEY (network_interface_purpose) REFERENCES val_network_interface_purpose(network_interface_purpose);

ALTER TABLE person_account_realm_company DROP CONSTRAINT IF EXISTS fk_person_acct_rlm_cmpy_persni;
ALTER TABLE person_account_realm_company
	ADD CONSTRAINT fk_person_acct_rlm_cmpy_persnid
	FOREIGN KEY (person_id) REFERENCES person(person_id);

ALTER TABLE person_company DROP CONSTRAINT IF EXISTS fk_person_company_prsncmpy_sta;
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_prsncmpy_status
	FOREIGN KEY (person_company_status) REFERENCES val_person_status(person_status);

ALTER TABLE person_company_attr DROP CONSTRAINT IF EXISTS fk_pers_comp_attr_person_comp_;
ALTER TABLE person_company_attr DROP CONSTRAINT IF EXISTS fk_person_comp_att_pers_person;
ALTER TABLE person_company_attr
	ADD CONSTRAINT fk_pers_comp_attr_person_comp_id
	FOREIGN KEY (company_id, person_id) REFERENCES person_company(company_id, person_id) DEFERRABLE;

ALTER TABLE person_company_attr
	ADD CONSTRAINT fk_person_comp_att_pers_personid
	FOREIGN KEY (attribute_value_person_id) REFERENCES person(person_id);

ALTER TABLE person_image_usage DROP CONSTRAINT IF EXISTS fk_person_img_usg_person_img_i;
ALTER TABLE person_image_usage DROP CONSTRAINT IF EXISTS fk_person_img_usg_val_prsn_img;
ALTER TABLE person_image_usage
	ADD CONSTRAINT fk_person_img_usg_person_img_id
	FOREIGN KEY (person_image_id) REFERENCES person_image(person_image_id);

ALTER TABLE person_image_usage
	ADD CONSTRAINT fk_person_img_usg_val_prsn_img_usg
	FOREIGN KEY (person_image_usage) REFERENCES val_person_image_usage(person_image_usage);

ALTER TABLE person_parking_pass DROP CONSTRAINT IF EXISTS fk_person_parking_pass_personi;
ALTER TABLE person_parking_pass
	ADD CONSTRAINT fk_person_parking_pass_personid
	FOREIGN KEY (person_id) REFERENCES person(person_id);

ALTER TABLE property_collection_hier DROP CONSTRAINT IF EXISTS fk_propcollhier_chldpropcoll_i;
ALTER TABLE property_collection_hier
	ADD CONSTRAINT fk_propcollhier_chldpropcoll_id
	FOREIGN KEY (child_property_collection_id) REFERENCES property_collection(property_collection_id);

ALTER TABLE service_environment_coll_hier DROP CONSTRAINT IF EXISTS fk_svc_env_hier_svc_env_coll_i;
ALTER TABLE service_environment_coll_hier
	ADD CONSTRAINT fk_svc_env_hier_svc_env_coll_id
	FOREIGN KEY (service_env_collection_id) REFERENCES service_environment_collection(service_env_collection_id);

ALTER TABLE account_realm_acct_coll_type
	RENAME CONSTRAINT pk_account_realm_acct_coll_typ TO pk_account_realm_acct_coll_type;

ALTER TABLE approval_instance_step_notify
	RENAME CONSTRAINT pk_approval_instance_step_noti TO pk_approval_instance_step_notify;

ALTER TABLE component_type_component_func
	RENAME CONSTRAINT pk_component_type_component_fu TO pk_component_type_component_func;

ALTER TABLE device_management_controller
	RENAME CONSTRAINT pk_device_management_controlle TO pk_device_management_controller;

ALTER TABLE device_type_module_device_type
	RENAME CONSTRAINT pk_device_type_module_device_t TO pk_device_type_module_device_type;

ALTER TABLE dns_domain_collection
	RENAME CONSTRAINT ak_dns_domain_collection_namty TO ak_dns_domain_collection_namtyp;

ALTER TABLE dns_domain_collection_dns_dom
	RENAME CONSTRAINT pk_dns_domain_collection_dns_d TO pk_dns_domain_collection_dns_dom;

ALTER TABLE layer2_connection_l2_network
	RENAME CONSTRAINT pk_val_layer2_encapsulation_ty TO pk_val_layer2_encapsulation_type;

ALTER TABLE layer2_network_collection_hier
	RENAME CONSTRAINT pk_layer2_network_collection_h TO pk_layer2_network_collection_hier;

ALTER TABLE layer3_network_collection_hier
	RENAME CONSTRAINT pk_layer3_network_collection_h TO pk_layer3_network_collection_hier;

ALTER TABLE netblock_collection_netblock
	RENAME CONSTRAINT pk_netblock_collection_netbloc TO pk_netblock_collection_netblock;

ALTER TABLE network_interface_netblock
	RENAME CONSTRAINT ak_network_interface_nblk_ni_r TO ak_network_interface_nblk_ni_rank;

ALTER TABLE operating_system_snapshot
	RENAME CONSTRAINT pk_val_operating_system_snapsh TO pk_val_operating_system_snapshot;

ALTER TABLE person_account_realm_company
	RENAME CONSTRAINT pk_person_account_realm_compan TO pk_person_account_realm_company;

ALTER TABLE property_collection_property
	RENAME CONSTRAINT pk_property_collection_propert TO pk_property_collection_property;

ALTER TABLE service_environment_collection
	RENAME CONSTRAINT pk_service_environment_collect TO pk_service_environment_collection;

ALTER TABLE slot_type_prmt_comp_slot_type
	RENAME CONSTRAINT pk_slot_type_prmt_comp_slot_ty TO pk_slot_type_prmt_comp_slot_typ;

ALTER TABLE slot_type_prmt_rem_slot_type
	RENAME CONSTRAINT pk_slot_type_prmt_rem_slot_typ TO pk_slot_type_prmt_rem_slot_type;

ALTER TABLE svc_environment_coll_svc_env
	RENAME CONSTRAINT pk_svc_environment_coll_svc_en TO pk_svc_environment_coll_svc_env;

ALTER TABLE val_account_collection_relatio
	RENAME CONSTRAINT pk_val_account_collection_rela TO pk_val_account_collection_relation;

ALTER TABLE val_approval_expiration_action
	RENAME CONSTRAINT pk_val_approval_expiration_act TO pk_val_approval_expiration_action;

ALTER TABLE val_component_property_value
	RENAME CONSTRAINT pk_val_component_property_valu TO pk_val_component_property_value;

ALTER TABLE val_dns_domain_collection_type
	RENAME CONSTRAINT pk_val_dns_domain_collection_t TO pk_val_dns_domain_collection_type;

ALTER TABLE val_layer3_network_coll_type
	RENAME CONSTRAINT pk_val_layer3_network_coll_typ TO pk_val_layer3_network_coll_type;

ALTER TABLE val_netblock_collection_type
	RENAME CONSTRAINT pk_val_netblock_collection_typ TO pk_val_netblock_collection_type;

ALTER TABLE val_person_company_attr_name
	RENAME CONSTRAINT pk_val_person_company_attr_nam TO pk_val_person_company_attr_name;

ALTER TABLE val_person_contact_technology
	RENAME CONSTRAINT pk_val_person_contact_technolo TO pk_val_person_contact_technology;

ALTER TABLE val_shared_netblock_protocol
	RENAME CONSTRAINT pk_val_shared_netblock_protoco TO pk_val_shared_netblock_protocol;

ALTER TABLE volume_group_physicalish_vol
	RENAME CONSTRAINT pk_volume_group_physicalish_vo TO pk_volume_group_physicalish_vol;

ALTER TABLE account_auth_log
DROP CONSTRAINT IF EXISTS ckc_sys_usr_authlg_success;

ALTER TABLE account_auth_log
	DROP CONSTRAINT IF EXISTS check_yes_no_1416198228;
ALTER TABLE account_auth_log
ADD CONSTRAINT check_yes_no_1416198228 CHECK
	(was_auth_success = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

ALTER TABLE circuit
DROP CONSTRAINT IF EXISTS ckc_is_locally_manage_circuit;

ALTER TABLE circuit
	DROP CONSTRAINT IF EXISTS check_yes_no_1243964430;
ALTER TABLE circuit
ADD CONSTRAINT check_yes_no_1243964430 CHECK
	(is_locally_managed = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

ALTER TABLE department
DROP CONSTRAINT IF EXISTS ckc_is_active_dept;

ALTER TABLE department
	DROP CONSTRAINT IF EXISTS check_yes_no_dept_isact;
ALTER TABLE department
ADD CONSTRAINT check_yes_no_dept_isact CHECK
	(is_active = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

ALTER TABLE device
DROP CONSTRAINT IF EXISTS ckc_is_locally_manage_device;

ALTER TABLE device
DROP CONSTRAINT IF EXISTS ckc_is_monitored_device;

ALTER TABLE device
DROP CONSTRAINT IF EXISTS ckc_is_virtual_device_device;

ALTER TABLE device
DROP CONSTRAINT IF EXISTS ckc_should_fetch_conf_device;

ALTER TABLE device
DROP CONSTRAINT IF EXISTS dev_osid_notnull;

ALTER TABLE device
DROP CONSTRAINT IF EXISTS sys_c0069051;

ALTER TABLE device
DROP CONSTRAINT IF EXISTS sys_c0069052;

ALTER TABLE device
DROP CONSTRAINT IF EXISTS sys_c0069057;

ALTER TABLE device
DROP CONSTRAINT IF EXISTS sys_c0069059;

ALTER TABLE device
DROP CONSTRAINT IF EXISTS sys_c0069060;

ALTER TABLE device
	DROP CONSTRAINT IF EXISTS check_yes_no_1430344029;
ALTER TABLE device
ADD CONSTRAINT check_yes_no_1430344029 CHECK
	(is_locally_managed = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

ALTER TABLE device
	DROP CONSTRAINT IF EXISTS check_yes_no_1628986393;
ALTER TABLE device
ADD CONSTRAINT check_yes_no_1628986393 CHECK
	(should_fetch_config = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

ALTER TABLE device
	DROP CONSTRAINT IF EXISTS check_yes_no_1944758924;
ALTER TABLE device
ADD CONSTRAINT check_yes_no_1944758924 CHECK
	(is_virtual_device = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

ALTER TABLE device
	DROP CONSTRAINT IF EXISTS check_yes_no_541352520;
ALTER TABLE device
ADD CONSTRAINT check_yes_no_541352520 CHECK
	(is_monitored = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

ALTER TABLE dns_domain_ip_universe
DROP CONSTRAINT IF EXISTS validation_rule_675_1416260427;

ALTER TABLE dns_domain_ip_universe
	DROP CONSTRAINT IF EXISTS check_yes_no_1211652401;
ALTER TABLE dns_domain_ip_universe
ADD CONSTRAINT check_yes_no_1211652401 CHECK
	(should_generate = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

ALTER TABLE dns_record
DROP CONSTRAINT IF EXISTS ckc_is_enabled_dns_reco;

ALTER TABLE dns_record
DROP CONSTRAINT IF EXISTS ckc_should_generate_p_dns_reco;

ALTER TABLE dns_record
	DROP CONSTRAINT IF EXISTS check_yes_no_135536460;
ALTER TABLE dns_record
ADD CONSTRAINT check_yes_no_135536460 CHECK
	(should_generate_ptr = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

ALTER TABLE dns_record
	DROP CONSTRAINT IF EXISTS check_yes_no_1819304031;
ALTER TABLE dns_record
ADD CONSTRAINT check_yes_no_1819304031 CHECK
	(is_enabled = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

ALTER TABLE netblock
DROP CONSTRAINT IF EXISTS ckc_is_single_address_netblock;

ALTER TABLE netblock
	DROP CONSTRAINT IF EXISTS check_yes_no_909397535;
ALTER TABLE netblock
ADD CONSTRAINT check_yes_no_909397535 CHECK
	(is_single_address = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

ALTER TABLE person
DROP CONSTRAINT IF EXISTS validation_rule_176_1095976282;

ALTER TABLE person
DROP CONSTRAINT IF EXISTS validation_rule_1770_218378485;

ALTER TABLE person
DROP CONSTRAINT IF EXISTS validation_rule_177_1190387970;

ALTER TABLE person
	DROP CONSTRAINT IF EXISTS ckc_gender_legacy_34676316;
ALTER TABLE person
ADD CONSTRAINT ckc_gender_legacy_34676316 CHECK
	((gender IS NULL) OR ((gender = ANY (ARRAY['M'::bpchar, 'F'::bpchar, 'U'::bpchar])) AND ((gender)::text = upper((gender)::text))));

ALTER TABLE person
	DROP CONSTRAINT IF EXISTS ckc_pant_size_387798304;
ALTER TABLE person
ADD CONSTRAINT ckc_pant_size_387798304 CHECK
	((pant_size IS NULL) OR (((pant_size)::text = ANY ((ARRAY['XS'::character varying, 'S'::character varying, 'M'::character varying, 'L'::character varying, 'XL'::character varying, 'XXL'::character varying, 'XXXL'::character varying])::text[])) AND ((pant_size)::text = upper((pant_size)::text))));

ALTER TABLE person
	DROP CONSTRAINT IF EXISTS ckc_shirt_size_876314983;
ALTER TABLE person
ADD CONSTRAINT ckc_shirt_size_876314983 CHECK
	((shirt_size IS NULL) OR (((shirt_size)::text = ANY ((ARRAY['XS'::character varying, 'S'::character varying, 'M'::character varying, 'L'::character varying, 'XL'::character varying, 'XXL'::character varying, 'XXXL'::character varying])::text[])) AND ((shirt_size)::text = upper((shirt_size)::text))));

ALTER TABLE rack
DROP CONSTRAINT IF EXISTS ckc_display_from_bott_rack;

ALTER TABLE rack
	DROP CONSTRAINT IF EXISTS check_yes_no_2128846003;
ALTER TABLE rack
ADD CONSTRAINT check_yes_no_2128846003 CHECK
	(display_from_bottom = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

ALTER TABLE sudo_acct_col_device_collectio
DROP CONSTRAINT IF EXISTS ckc_can_exec_child_sudo_ucl;

ALTER TABLE sudo_acct_col_device_collectio
DROP CONSTRAINT IF EXISTS ckc_requires_password_sudo_ucl;

ALTER TABLE sudo_acct_col_device_collectio
	DROP CONSTRAINT IF EXISTS check_yes_no_1550386694;
ALTER TABLE sudo_acct_col_device_collectio
ADD CONSTRAINT check_yes_no_1550386694 CHECK
	(can_exec_child = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

ALTER TABLE sudo_acct_col_device_collectio
	DROP CONSTRAINT IF EXISTS check_yes_no_785166671;
ALTER TABLE sudo_acct_col_device_collectio
ADD CONSTRAINT check_yes_no_785166671 CHECK
	(requires_password = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

ALTER TABLE token
DROP CONSTRAINT IF EXISTS sys_c0020104;

ALTER TABLE token
DROP CONSTRAINT IF EXISTS sys_c0020105;

ALTER TABLE val_account_type
DROP CONSTRAINT IF EXISTS ckc_is_person_val_syst;

ALTER TABLE val_account_type
	DROP CONSTRAINT IF EXISTS check_yes_no_1276256267;
ALTER TABLE val_account_type
ADD CONSTRAINT check_yes_no_1276256267 CHECK
	(is_person = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

ALTER TABLE val_dns_domain_collection_type
DROP CONSTRAINT IF EXISTS check_yes_no_dnsdom_coll_canhi;

ALTER TABLE val_dns_domain_collection_type
	DROP CONSTRAINT IF EXISTS check_yes_no_dnsdom_coll_canhier;
ALTER TABLE val_dns_domain_collection_type
ADD CONSTRAINT check_yes_no_dnsdom_coll_canhier CHECK
	(can_have_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

ALTER TABLE val_netblock_collection_type
DROP CONSTRAINT IF EXISTS check_any_yes_no_nc_singaddr_r;

ALTER TABLE val_netblock_collection_type
	DROP CONSTRAINT IF EXISTS check_any_yes_no_nc_singaddr_rst;
ALTER TABLE val_netblock_collection_type
ADD CONSTRAINT check_any_yes_no_nc_singaddr_rst CHECK
	((netblock_single_addr_restrict)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying, 'ANY'::character varying])::text[]));

ALTER TABLE val_person_status
DROP CONSTRAINT IF EXISTS check_yes_no_vpers_stat_enable;

ALTER TABLE val_person_status
	DROP CONSTRAINT IF EXISTS check_yes_no_vpers_stat_enabled;
ALTER TABLE val_person_status
ADD CONSTRAINT check_yes_no_vpers_stat_enabled CHECK
	(is_enabled = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

ALTER TABLE val_property_type
DROP CONSTRAINT IF EXISTS ckc_val_prop_typ_ismulti;

ALTER TABLE val_property_type
	DROP CONSTRAINT IF EXISTS check_yes_no_207645004;
ALTER TABLE val_property_type
ADD CONSTRAINT check_yes_no_207645004 CHECK
	(is_multivalue = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

ALTER TABLE val_x509_key_usage
	DROP CONSTRAINT IF EXISTS check_yes_no_771617420;
ALTER TABLE val_x509_key_usage
ADD CONSTRAINT check_yes_no_771617420 CHECK
	(is_extended = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- index
DROP INDEX "jazzhands"."xif1approval_instance_step_not";
DROP INDEX "jazzhands"."xif2approval_instance_step_not";
DROP INDEX "jazzhands"."xif3approval_instance_step_not";
DROP INDEX IF EXISTS "jazzhands"."xif1approval_instance_step_notify";
CREATE INDEX xif1approval_instance_step_notify ON approval_instance_step_notify USING btree (approval_notify_type);
DROP INDEX IF EXISTS "jazzhands"."xif2approval_instance_step_notify";
CREATE INDEX xif2approval_instance_step_notify ON approval_instance_step_notify USING btree (approval_instance_step_id);
DROP INDEX IF EXISTS "jazzhands"."xif3approval_instance_step_notify";
CREATE INDEX xif3approval_instance_step_notify ON approval_instance_step_notify USING btree (account_id);
DROP INDEX "jazzhands"."xifcompany_coll_company_coll_i";
DROP INDEX IF EXISTS "jazzhands"."xifcompany_coll_company_coll_id";
CREATE INDEX xifcompany_coll_company_coll_id ON company_collection_company USING btree (company_collection_id);
DROP INDEX "jazzhands"."xif_comp_typ_slt_tmplt_cmptypi";
DROP INDEX "jazzhands"."xif_comp_typ_slt_tmplt_slttypi";
DROP INDEX IF EXISTS "jazzhands"."xif_comp_typ_slt_tmplt_cmptypid";
CREATE INDEX xif_comp_typ_slt_tmplt_cmptypid ON component_type_slot_tmplt USING btree (component_type_id);
DROP INDEX IF EXISTS "jazzhands"."xif_comp_typ_slt_tmplt_slttypid";
CREATE INDEX xif_comp_typ_slt_tmplt_slttypid ON component_type_slot_tmplt USING btree (slot_type_id);
DROP INDEX "jazzhands"."xif_dev_encap_domain_enc_domty";
DROP INDEX IF EXISTS "jazzhands"."xif_dev_encap_domain_enc_domtyp";
CREATE INDEX xif_dev_encap_domain_enc_domtyp ON device_encapsulation_domain USING btree (encapsulation_domain, encapsulation_type);
DROP INDEX "jazzhands"."xif1device_management_controll";
DROP INDEX "jazzhands"."xif2device_management_controll";
DROP INDEX "jazzhands"."xif3device_management_controll";
DROP INDEX IF EXISTS "jazzhands"."xif1device_management_controller";
CREATE INDEX xif1device_management_controller ON device_management_controller USING btree (manager_device_id);
DROP INDEX IF EXISTS "jazzhands"."xif2device_management_controller";
CREATE INDEX xif2device_management_controller ON device_management_controller USING btree (device_id);
DROP INDEX IF EXISTS "jazzhands"."xif3device_management_controller";
CREATE INDEX xif3device_management_controller ON device_management_controller USING btree (device_mgmt_control_type);
DROP INDEX "jazzhands"."xif1dns_domain_collection_dns_";
DROP INDEX "jazzhands"."xif2dns_domain_collection_dns_";
DROP INDEX IF EXISTS "jazzhands"."xif1dns_domain_collection_dns_dom";
CREATE INDEX xif1dns_domain_collection_dns_dom ON dns_domain_collection_dns_dom USING btree (dns_domain_id);
DROP INDEX IF EXISTS "jazzhands"."xif2dns_domain_collection_dns_dom";
CREATE INDEX xif2dns_domain_collection_dns_dom ON dns_domain_collection_dns_dom USING btree (dns_domain_collection_id);
DROP INDEX "jazzhands"."xif1network_interface_purpose";
DROP INDEX "jazzhands"."xif2network_interface_purpose";
DROP INDEX "jazzhands"."xif3network_interface_purpose";
DROP INDEX IF EXISTS "jazzhands"."xifnetint_purp_dev_ni_id";
CREATE INDEX xifnetint_purp_dev_ni_id ON network_interface_purpose USING btree (network_interface_id, device_id);
DROP INDEX IF EXISTS "jazzhands"."xifnetint_purpose_device_id";
CREATE INDEX xifnetint_purpose_device_id ON network_interface_purpose USING btree (device_id);
DROP INDEX IF EXISTS "jazzhands"."xifnetint_purpose_val_netint_p";
CREATE INDEX xifnetint_purpose_val_netint_p ON network_interface_purpose USING btree (network_interface_purpose);
DROP INDEX "jazzhands"."xif2person_account_realm_compa";
DROP INDEX "jazzhands"."xif3person_account_realm_compa";
DROP INDEX IF EXISTS "jazzhands"."xif2person_account_realm_company";
CREATE INDEX xif2person_account_realm_company ON person_account_realm_company USING btree (account_realm_id, company_id);
DROP INDEX IF EXISTS "jazzhands"."xif3person_account_realm_company";
CREATE INDEX xif3person_account_realm_company ON person_account_realm_company USING btree (person_id);
DROP INDEX "jazzhands"."xif1service_environment_coll_h";
DROP INDEX "jazzhands"."xif2service_environment_coll_h";
DROP INDEX IF EXISTS "jazzhands"."xif1service_environment_coll_hier";
CREATE INDEX xif1service_environment_coll_hier ON service_environment_coll_hier USING btree (child_service_env_coll_id);
DROP INDEX IF EXISTS "jazzhands"."xif2service_environment_coll_hier";
CREATE INDEX xif2service_environment_coll_hier ON service_environment_coll_hier USING btree (service_env_collection_id);
DROP INDEX "jazzhands"."xif1service_environment_collec";
DROP INDEX IF EXISTS "jazzhands"."xif1service_environment_collection";
CREATE INDEX xif1service_environment_collection ON service_environment_collection USING btree (service_env_collection_type);
DROP INDEX "jazzhands"."xif1shared_netblock_network_in";
DROP INDEX "jazzhands"."xif2shared_netblock_network_in";
DROP INDEX IF EXISTS "jazzhands"."xif1shared_netblock_network_int";
CREATE INDEX xif1shared_netblock_network_int ON shared_netblock_network_int USING btree (shared_netblock_id);
DROP INDEX IF EXISTS "jazzhands"."xif2shared_netblock_network_int";
CREATE INDEX xif2shared_netblock_network_int ON shared_netblock_network_int USING btree (network_interface_id);
DROP INDEX "jazzhands"."xif1svc_environment_coll_svc_e";
DROP INDEX "jazzhands"."xif2svc_environment_coll_svc_e";
DROP INDEX IF EXISTS "jazzhands"."xif1svc_environment_coll_svc_env";
CREATE INDEX xif1svc_environment_coll_svc_env ON svc_environment_coll_svc_env USING btree (service_environment_id);
DROP INDEX IF EXISTS "jazzhands"."xif2svc_environment_coll_svc_env";
CREATE INDEX xif2svc_environment_coll_svc_env ON svc_environment_coll_svc_env USING btree (service_env_collection_id);
DROP INDEX "jazzhands"."xif1val_account_collection_typ";
DROP INDEX IF EXISTS "jazzhands"."xif1val_account_collection_type";
CREATE INDEX xif1val_account_collection_type ON val_account_collection_type USING btree (account_realm_id);
DROP INDEX "jazzhands"."xif1val_person_contact_technol";
DROP INDEX IF EXISTS "jazzhands"."xif1val_person_contact_technology";
CREATE INDEX xif1val_person_contact_technology ON val_person_contact_technology USING btree (person_contact_type);
-- triggers
DROP TRIGGER IF EXISTS aaa_tg_cache_component_parent_handler ON component;
CREATE TRIGGER aaa_tg_cache_component_parent_handler AFTER INSERT OR DELETE OR UPDATE OF parent_slot_id ON component FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.cache_component_parent_handler();
DROP TRIGGER IF EXISTS aab_tg_cache_device_component_component_handler ON component;
CREATE TRIGGER aab_tg_cache_device_component_component_handler AFTER INSERT OR DELETE OR UPDATE OF parent_slot_id ON component FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.cache_device_component_component_handler();
DROP TRIGGER IF EXISTS tg_cache_device_component_device_handler ON device;
CREATE TRIGGER tg_cache_device_component_device_handler AFTER INSERT OR DELETE OR UPDATE OF component_id ON device FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.cache_device_component_device_handler();


-- BEGIN Misc that does not apply to above

ALTER TABLE person_note
        ALTER note_id
        SET DEFAULT nextval('note_id_seq'::regclass);

COMMENT ON SCHEMA jazzhands_cache IS 'cache tables for jazzhands views';

--
-- gets all the indexes and friends named properly
--
SELECT schema_support.rebuild_audit_tables('audit', 'jazzhands');

-- it may get manipulated here.
DROP TRIGGER IF EXISTS trigger_audit_token_sequence ON jazzhands.token_sequence;


-- END Misc that does not apply to above


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
--
-- BEGIN: Fix cache table entries.
--
-- removing old
-- adding new that are not there
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled 
	) SELECT 'jazzhands_cache' , 'ct_component_hier' , 'jazzhands_cache' , 'v_component_hier' , '1'  WHERE ('jazzhands_cache' , 'ct_component_hier' , 'jazzhands_cache' , 'v_component_hier' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled 
	) SELECT 'jazzhands_cache' , 'ct_device_components' , 'jazzhands_cache' , 'v_device_components' , '1'  WHERE ('jazzhands_cache' , 'ct_device_components' , 'jazzhands_cache' , 'v_device_components' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
--
-- DONE: Fix cache table entries.
--
select timeofday(), now();
