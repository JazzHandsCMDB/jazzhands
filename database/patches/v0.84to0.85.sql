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

	--suffix=v85
	--reinsert-dir=i
	--pre
	pre
	--post
	post
	--postschema
	jazzhands_legacy
	--scan
	device_colletion_hier
	v_device_collection_hier_trans
	v_application_role
	v_device_coll_device_expanded
	v_device_coll_hier_detail
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance();
select timeofday(), now();
--
-- BEGIN: process_ancillary_schema(schema_support)
--
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
		RAISE NOTICE 'table % has % rows; table % has % rows (%)', old_rel, _t1, new_rel, _t2, _t1 - _t2;
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

-- New function
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

-- New function
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_table_finish(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
$function$
;

DROP FUNCTION IF EXISTS schema_support.rebuild_audit_table ( aud_schema character varying, tbl_schema character varying, table_name character varying );
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
		RAISE NOTICE 'table % has % rows; table % has % rows (%)', old_rel, _t1, new_rel, _t2, _t1 - _t2;
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

-- New function
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

-- New function
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_table_finish(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
$function$
;

-- DONE: process_ancillary_schema(schema_support)


-- BEGIN Misc that does not apply to above
DELETE FROM operating_system
WHERE operating_system_name = 'Solaris'
AND processor_architecture = 'amd64';



-- END Misc that does not apply to above
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'jazzhands_legacy';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS jazzhands_legacy;
		CREATE SCHEMA jazzhands_legacy AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA jazzhands_legacy IS 'part of jazzhands';
	END IF;
END;
			$$;--
-- Process middle (non-trigger) schema jazzhands_cache
--
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
-- Process middle (non-trigger) schema layerx_network_manip
--
--
-- Process middle (non-trigger) schema auto_ac_manip
--
--
-- Process middle (non-trigger) schema company_manip
--
--
-- Process middle (non-trigger) schema component_connection_utils
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
-- Process middle (non-trigger) schema backend_utils
--
--
-- Process middle (non-trigger) schema schema_support
--
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
		RAISE NOTICE 'table % has % rows; table % has % rows (%)', old_rel, _t1, new_rel, _t2, _t1 - _t2;
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

-- New function
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

-- New function
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_table_finish(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
$function$
;

--
-- Process middle (non-trigger) schema rack_utils
--
-- Creating new sequences....


--------------------------------------------------------------------
-- DEALING WITH TABLE val_dns_domain_type
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_dns_domain_type', 'val_dns_domain_type');

-- FOREIGN KEYS FROM
ALTER TABLE dns_domain DROP CONSTRAINT IF EXISTS fk_dns_dom_dns_dom_typ;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_dns_domain_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_dns_domain_type DROP CONSTRAINT IF EXISTS pkval_dns_domain_type;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_dns_domain_type ON jazzhands.val_dns_domain_type;
DROP TRIGGER IF EXISTS trigger_audit_val_dns_domain_type ON jazzhands.val_dns_domain_type;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_dns_domain_type');
---- BEGIN audit.val_dns_domain_type TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_dns_domain_type', 'val_dns_domain_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_dns_domain_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.val_dns_domain_type DROP CONSTRAINT IF EXISTS val_dns_domain_type_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_val_dns_domain_type_pkval_dns_domain_type";
DROP INDEX IF EXISTS "audit"."val_dns_domain_type_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."val_dns_domain_type_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."val_dns_domain_type_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.val_dns_domain_type TEARDOWN


ALTER TABLE val_dns_domain_type RENAME TO val_dns_domain_type_v85;
ALTER TABLE audit.val_dns_domain_type RENAME TO val_dns_domain_type_v85;

CREATE TABLE jazzhands.val_dns_domain_type
(
	dns_domain_type	varchar(50) NOT NULL,
	can_generate	character(1) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_dns_domain_type', false);
ALTER TABLE val_dns_domain_type
	ALTER can_generate
	SET DEFAULT 'Y'::bpchar;
INSERT INTO val_dns_domain_type (
	dns_domain_type,
	can_generate,		-- new column (can_generate)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	dns_domain_type,
	'Y'::bpchar,		-- new column (can_generate)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_dns_domain_type_v85;

INSERT INTO audit.val_dns_domain_type (
	dns_domain_type,
	can_generate,		-- new column (can_generate)
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
	dns_domain_type,
	NULL,		-- new column (can_generate)
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
FROM audit.val_dns_domain_type_v85;

ALTER TABLE jazzhands.val_dns_domain_type
	ALTER can_generate
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_dns_domain_type ADD CONSTRAINT pkval_dns_domain_type PRIMARY KEY (dns_domain_type);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_dns_domain_type and jazzhands.dns_domain
ALTER TABLE jazzhands.dns_domain
	ADD CONSTRAINT fk_dns_dom_dns_dom_typ
	FOREIGN KEY (dns_domain_type) REFERENCES jazzhands.val_dns_domain_type(dns_domain_type);

-- FOREIGN KEYS TO

-- TRIGGERS
-- consider NEW jazzhands.dns_domain_type_should_generate
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_type_should_generate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_c	INTEGER;
BEGIN
	IF NEW.can_generate = 'N' THEN
		SELECT count(*)
		INTO _c
		FROM dns_domain
		WHERE dns_domain_type = NEW.dns_domain_type
		AND should_generate = 'Y';

		IF _c != 'Y' THEN
			RAISE EXCEPTION 'May not change can_generate with existing autogenerated zones.'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_dns_domain_type_should_generate AFTER UPDATE OF can_generate ON jazzhands.val_dns_domain_type FOR EACH ROW EXECUTE PROCEDURE jazzhands.dns_domain_type_should_generate();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_dns_domain_type');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'val_dns_domain_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_dns_domain_type');
DROP TABLE IF EXISTS val_dns_domain_type_v85;
DROP TABLE IF EXISTS audit.val_dns_domain_type_v85;
-- DONE DEALING WITH TABLE val_dns_domain_type (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE device_collection_hier
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_collection_hier', 'device_collection_hier');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.device_collection_hier DROP CONSTRAINT IF EXISTS fk_devcollhier_devcol_id;
ALTER TABLE jazzhands.device_collection_hier DROP CONSTRAINT IF EXISTS fk_devcollhier_pdevcol_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'device_collection_hier');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.device_collection_hier DROP CONSTRAINT IF EXISTS pk_device_collection_hier;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_device_collection_hier ON jazzhands.device_collection_hier;
DROP TRIGGER IF EXISTS trigger_audit_device_collection_hier ON jazzhands.device_collection_hier;
DROP TRIGGER IF EXISTS trigger_check_device_collection_hier_loop ON jazzhands.device_collection_hier;
DROP TRIGGER IF EXISTS trigger_device_collection_hier_enforce ON jazzhands.device_collection_hier;
DROP TRIGGER IF EXISTS trigger_hier_device_collection_after_hooks ON jazzhands.device_collection_hier;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'device_collection_hier');
---- BEGIN audit.device_collection_hier TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'device_collection_hier', 'device_collection_hier');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'device_collection_hier');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.device_collection_hier DROP CONSTRAINT IF EXISTS device_collection_hier_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_device_collection_hier_pk_device_collection_hier";
DROP INDEX IF EXISTS "audit"."device_collection_hier_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."device_collection_hier_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."device_collection_hier_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.device_collection_hier TEARDOWN


ALTER TABLE device_collection_hier RENAME TO device_collection_hier_v85;
ALTER TABLE audit.device_collection_hier RENAME TO device_collection_hier_v85;

CREATE TABLE jazzhands.device_collection_hier
(
	device_collection_id	integer NOT NULL,
	child_device_collection_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device_collection_hier', false);


-- BEGIN Manually written insert function
INSERT INTO device_collection_hier (
        device_collection_id,
        child_device_collection_id,             -- new column (child_device_collection_id)
        data_ins_user,
        data_ins_date,
        data_upd_user,
        data_upd_date
) SELECT
        parent_device_collection_id,
        device_collection_id,
        data_ins_user,
        data_ins_date,
        data_upd_user,
        data_upd_date
FROM device_collection_hier_v85;

INSERT INTO audit.device_collection_hier (
        device_collection_id,
        child_device_collection_id,             -- new column (child_device_collection_id)
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
        parent_device_collection_id,
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
FROM audit.device_collection_hier_v85;


-- get recreated  later
/*
DELETE FROM __recreate WHERE object IN (
	'v_device_collection_hier_trans',
	'v_application_role',
	'v_device_coll_device_expanded',
	'v_device_coll_hier_detail'
);
 */


-- END Manually written insert function

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.device_collection_hier ADD CONSTRAINT pk_device_collection_hier PRIMARY KEY (device_collection_id, child_device_collection_id);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK device_collection_hier and device_collection
ALTER TABLE jazzhands.device_collection_hier
	ADD CONSTRAINT fk_devcollhier_devcol_id
	FOREIGN KEY (child_device_collection_id) REFERENCES jazzhands.device_collection(device_collection_id);
-- consider FK device_collection_hier and device_collection
ALTER TABLE jazzhands.device_collection_hier
	ADD CONSTRAINT fk_devcollhier_pdevcol_id
	FOREIGN KEY (device_collection_id) REFERENCES jazzhands.device_collection(device_collection_id);

-- TRIGGERS
-- consider NEW jazzhands_cache.device_collection_root_handler
CREATE OR REPLACE FUNCTION jazzhands_cache.device_collection_root_handler()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_r		RECORD;
	_cnt	INTEGER;
BEGIN
	--
	-- Delete any rows that are invalidated due to a parent change.
	--
	IF
		(TG_OP = 'DELETE' OR TG_OP = 'UPDATE')
	THEN
		FOR _r IN
		DELETE FROM jazzhands_cache.ct_device_collection_hier_from_ancestor
		WHERE	OLD.device_collection_id = ANY (path)
		AND		OLD.child_device_collection_id = ANY (path)
		RETURNING *
		LOOP
			RAISE DEBUG '-> rm %', to_json(_r);
		END LOOP
		;
		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Deleting upstream references to netcoll %/% from cache == %',
			OLD.device_collection_id, OLD.child_device_collection_id, _cnt;
	END IF;

	--
	-- Insert any new rows to correspond with a new parent
	--


	--
	-- XXX - NEED TO START OVER SKETCH OUT EXACTLY WHAT NEEDS TO HAPPEN
	-- ON INSERT, UPDATE, DELETE IN ENGLISH, THEN WRITE.
	--

	--
	-- this worked for stuff added on top but I think I need to be more
	-- clever
	--
	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
		RAISE DEBUG '%%Insert: %', to_json(NEW);
		FOR _r IN
		WITH base_device AS (
			SELECT *, 'parent'::text as src
			FROM jazzhands_cache.ct_device_collection_hier_from_ancestor
			WHERE NEW.device_collection_id = ANY (path)
			AND array_length(path, 1) > 1
			AND device_collection_id = NEW.device_collection_id

		), base_child AS (
			-- deal with everything rooted at the child; this handles the case
			-- of something being inserted on top of the child
			SELECT *, 'child'::text as src
			FROM jazzhands_cache.ct_device_collection_hier_from_ancestor
			WHERE NEW.child_device_collection_id = ANY (path)
			AND root_device_collection_id != NEW.child_device_collection_id
			AND device_collection_id != NEW.child_device_collection_id
			AND array_length(path, 1) > 1

		), iparent AS (
			INSERT INTO jazzhands_cache.ct_device_collection_hier_from_ancestor (
				root_device_collection_id,
				intermediate_device_collection_id,
				device_collection_id,
				path,
				cycle
			)  SELECT
				base.root_device_collection_id,
				NEW.device_collection_id,
				NEW.child_device_collection_id,
				array_cat(
					array_cat(
						path[: (array_position(path, NEW.device_collection_id)-1)],
					ARRAY[NEW.child_device_collection_id, NEW.device_collection_id]
					),
					path[(array_position(path, NEW.device_collection_id)+1) :]
				),
				NEW.child_device_collection_id = ANY(base.path)
				FROM base_device AS base
				RETURNING *
		), ichild AS (
			INSERT INTO jazzhands_cache.ct_device_collection_hier_from_ancestor (
				root_device_collection_id,
				intermediate_device_collection_id,
				device_collection_id,
				path,
				cycle
			)  SELECT
				base.root_device_collection_id,
				base.intermediate_device_collection_id,
				base.device_collection_id,
				array_cat(
					array_cat(
						path[: (array_position(path, NEW.child_device_collection_id)-1)],
					ARRAY[NEW.child_device_collection_id, NEW.device_collection_id]
					),
					path[(array_position(path, NEW.child_device_collection_id)+1) :]
				),
				false -- hope... NEW.child_device_collection_id = ANY(base.path)
				FROM base_child AS base
				RETURNING *

		) SELECT 'c' AS q, * FROM ichild UNION SELECT 'p' AS q, * FROM iparent
		LOOP
			RAISE DEBUG 'i/down:%', to_json(_r);
			IF _r.cycle THEN
				RAISE EXCEPTION 'danger!  cycle!';
			END IF;
		END LOOP;

		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Inserting upstream references down for updated netcoll %/% into cache == %',
			NEW.device_collection_id, NEW.child_device_collection_id, _cnt;

		-- walk up and install rows for all the things above due to change
		FOR _r IN
		WITH RECURSIVE tier (
			root_device_collection_id,
			intermediate_device_collection_id,
			device_collection_id,
			path
		)AS (
			SELECT h.device_collection_id,
				h.device_collection_id,
				h.child_device_collection_Id,
				ARRAY[h.child_device_collection_id, h.device_collection_id],
				false as cycle
			FROM device_collection_hier  h
			WHERE h.device_collection_id = NEW.device_collection_id
			AND h.child_device_collection_id = NEW.child_device_collection_id
		UNION ALL
			SELECT tier.root_device_collection_id,
				n.device_collection_id,
				n.child_device_collection_id,
				array_prepend(n.child_device_collection_id, tier.path),
				n.child_device_collection_id = ANY(tier.path) as cycle
			FROM tier
				JOIN device_collection_hier n
					ON n.device_collection_id = tier.device_collection_id
			WHERE	NOT tier.cycle
		) INSERT INTO jazzhands_cache.ct_device_collection_hier_from_ancestor
				SELECT * FROM tier
		RETURNING *
		LOOP
			RAISE DEBUG 'i/up %', to_json(_r);
			IF _r.cycle THEN
				RAISE EXCEPTION 'danger!  cycle!';
			END IF;
		END LOOP;
		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Inserting upstream references up for updated netcol %/% into cache == %',
			NEW.device_collection_id, NEW.child_device_collection_id, _cnt;
	END IF;

	RETURN NULL;
END
$function$
;
CREATE TRIGGER aaa_device_collection_root_handler AFTER INSERT OR DELETE OR UPDATE OF device_collection_id, child_device_collection_id ON jazzhands.device_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.device_collection_root_handler();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.check_device_colllection_hier_loop
CREATE OR REPLACE FUNCTION jazzhands.check_device_colllection_hier_loop()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	IF NEW.device_collection_id = NEW.child_device_collection_id THEN
		RAISE EXCEPTION 'device Collection Loops Not Pernitted '
			USING ERRCODE = 20704;	/* XXX */
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_check_device_collection_hier_loop AFTER INSERT OR UPDATE ON jazzhands.device_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands.check_device_colllection_hier_loop();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.device_collection_hier_enforce
CREATE OR REPLACE FUNCTION jazzhands.device_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	dct	val_device_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_device_collection_type
	WHERE	device_collection_type =
		(select device_collection_type from device_collection
			where device_collection_id = NEW.device_collection_id);

	IF dct.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Device Collections of type % may not be hierarcical',
			dct.device_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE CONSTRAINT TRIGGER trigger_device_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.device_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.device_collection_hier_enforce();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.device_collection_after_hooks
CREATE OR REPLACE FUNCTION jazzhands.device_collection_after_hooks()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	BEGIN
		PERFORM local_hooks.device_collection_after_hooks();
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
			PERFORM 1;
	END;
	RETURN NULL;
END;
$function$
;
CREATE TRIGGER trigger_hier_device_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_hier FOR EACH STATEMENT EXECUTE PROCEDURE jazzhands.device_collection_after_hooks();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device_collection_hier');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'device_collection_hier');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device_collection_hier');
DROP TABLE IF EXISTS device_collection_hier_v85;
DROP TABLE IF EXISTS audit.device_collection_hier_v85;
-- DONE DEALING WITH TABLE device_collection_hier (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE dns_domain_ip_universe
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_domain_ip_universe', 'dns_domain_ip_universe');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.dns_domain_ip_universe DROP CONSTRAINT IF EXISTS fk_dnsdom_ipu_dnsdomid;
ALTER TABLE jazzhands.dns_domain_ip_universe DROP CONSTRAINT IF EXISTS fk_dnsdom_ipu_ipu;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'dns_domain_ip_universe');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.dns_domain_ip_universe DROP CONSTRAINT IF EXISTS pk_dns_domain_ip_universe;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xifdnsdom_ipu_dnsdomid";
DROP INDEX IF EXISTS "jazzhands"."xifdnsdom_ipu_ipu";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.dns_domain_ip_universe DROP CONSTRAINT IF EXISTS check_yes_no_1211652401;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_dns_domain_ip_universe ON jazzhands.dns_domain_ip_universe;
DROP TRIGGER IF EXISTS trigger_audit_dns_domain_ip_universe ON jazzhands.dns_domain_ip_universe;
DROP TRIGGER IF EXISTS trigger_dns_domain_ip_universe_trigger_change ON jazzhands.dns_domain_ip_universe;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'dns_domain_ip_universe');
---- BEGIN audit.dns_domain_ip_universe TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'dns_domain_ip_universe', 'dns_domain_ip_universe');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'dns_domain_ip_universe');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.dns_domain_ip_universe DROP CONSTRAINT IF EXISTS dns_domain_ip_universe_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_dns_domain_ip_universe_pk_dns_domain_ip_universe";
DROP INDEX IF EXISTS "audit"."dns_domain_ip_universe_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."dns_domain_ip_universe_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."dns_domain_ip_universe_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.dns_domain_ip_universe TEARDOWN


ALTER TABLE dns_domain_ip_universe RENAME TO dns_domain_ip_universe_v85;
ALTER TABLE audit.dns_domain_ip_universe RENAME TO dns_domain_ip_universe_v85;

CREATE TABLE jazzhands.dns_domain_ip_universe
(
	dns_domain_id	integer NOT NULL,
	ip_universe_id	integer NOT NULL,
	soa_class	varchar(50)  NULL,
	soa_ttl	integer  NULL,
	soa_serial	integer  NULL,
	soa_refresh	integer  NULL,
	soa_retry	integer  NULL,
	soa_expire	integer  NULL,
	soa_minimum	integer  NULL,
	soa_mname	varchar(255)  NULL,
	soa_rname	varchar(255) NOT NULL,
	should_generate	character(1) NOT NULL,
	last_generated	timestamp with time zone  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'dns_domain_ip_universe', false);
ALTER TABLE dns_domain_ip_universe
	ALTER soa_serial
	SET DEFAULT 0;
INSERT INTO dns_domain_ip_universe (
	dns_domain_id,
	ip_universe_id,
	soa_class,
	soa_ttl,
	soa_serial,
	soa_refresh,
	soa_retry,
	soa_expire,
	soa_minimum,
	soa_mname,
	soa_rname,
	should_generate,
	last_generated,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	dns_domain_id,
	ip_universe_id,
	soa_class,
	soa_ttl,
	soa_serial,
	soa_refresh,
	soa_retry,
	soa_expire,
	soa_minimum,
	soa_mname,
	soa_rname,
	should_generate,
	last_generated,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM dns_domain_ip_universe_v85;

INSERT INTO audit.dns_domain_ip_universe (
	dns_domain_id,
	ip_universe_id,
	soa_class,
	soa_ttl,
	soa_serial,
	soa_refresh,
	soa_retry,
	soa_expire,
	soa_minimum,
	soa_mname,
	soa_rname,
	should_generate,
	last_generated,
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
	dns_domain_id,
	ip_universe_id,
	soa_class,
	soa_ttl,
	soa_serial,
	soa_refresh,
	soa_retry,
	soa_expire,
	soa_minimum,
	soa_mname,
	soa_rname,
	should_generate,
	last_generated,
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
FROM audit.dns_domain_ip_universe_v85;

ALTER TABLE jazzhands.dns_domain_ip_universe
	ALTER soa_serial
	SET DEFAULT 0;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.dns_domain_ip_universe ADD CONSTRAINT pk_dns_domain_ip_universe PRIMARY KEY (dns_domain_id, ip_universe_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xifdnsdom_ipu_dnsdomid ON jazzhands.dns_domain_ip_universe USING btree (dns_domain_id);
CREATE INDEX xifdnsdom_ipu_ipu ON jazzhands.dns_domain_ip_universe USING btree (ip_universe_id);

-- CHECK CONSTRAINTS
ALTER TABLE jazzhands.dns_domain_ip_universe ADD CONSTRAINT check_yes_no_1211652401
	CHECK (should_generate = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK dns_domain_ip_universe and dns_domain
ALTER TABLE jazzhands.dns_domain_ip_universe
	ADD CONSTRAINT fk_dnsdom_ipu_dnsdomid
	FOREIGN KEY (dns_domain_id) REFERENCES jazzhands.dns_domain(dns_domain_id);
-- consider FK dns_domain_ip_universe and ip_universe
ALTER TABLE jazzhands.dns_domain_ip_universe
	ADD CONSTRAINT fk_dnsdom_ipu_ipu
	FOREIGN KEY (ip_universe_id) REFERENCES jazzhands.ip_universe(ip_universe_id);

-- TRIGGERS
-- consider NEW jazzhands.dns_domain_ip_universe_can_generate
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_ip_universe_can_generate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_c	char(1);
BEGIN
	IF NEW.should_generate = 'Y' THEN
		SELECT CAN_GENERATE
		INTO _c
		FROM val_dns_domain_type
		JOIN dns_domain USING (dns_domain_type)
		WHERE dns_domain_id = NEW.dns_domain_id;

		IF _c != 'Y' THEN
			RAISE EXCEPTION 'This dns_domain_type may not be autogenerated.'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_dns_domain_ip_universe_can_generate AFTER INSERT OR UPDATE OF should_generate ON jazzhands.dns_domain_ip_universe FOR EACH ROW EXECUTE PROCEDURE jazzhands.dns_domain_ip_universe_can_generate();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.dns_domain_ip_universe_trigger_change
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_ip_universe_trigger_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF NEW.should_generate = 'Y' THEN
		--
		-- kind of a weird case, but if last_generated matches
		-- the last change date of the zone, then its part of actually
		-- regenerating and should not get a change record otherwise
		-- that would constantly create change records.
		--
		IF TG_OP = 'INSERT' OR NEW.last_generated < NEW.data_upd_date THEN
			INSERT INTO dns_change_record
			(dns_domain_id) VALUES (NEW.dns_domain_id);
		END IF;
    ELSE
		DELETE FROM DNS_CHANGE_RECORD
		WHERE dns_domain_id = NEW.dns_domain_id
		AND ip_universe_id = NEW.ip_universe_id;
	END IF;

	--
	-- When its not a change as part of zone generation, mark it as
	-- something that needs to be addressed by zonegen
	--
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_dns_domain_ip_universe_trigger_change AFTER INSERT OR UPDATE OF soa_class, soa_ttl, soa_serial, soa_refresh, soa_retry, soa_expire, soa_minimum, soa_mname, soa_rname, should_generate ON jazzhands.dns_domain_ip_universe FOR EACH ROW EXECUTE PROCEDURE jazzhands.dns_domain_ip_universe_trigger_change();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'dns_domain_ip_universe');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'dns_domain_ip_universe');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'dns_domain_ip_universe');
DROP TABLE IF EXISTS dns_domain_ip_universe_v85;
DROP TABLE IF EXISTS audit.dns_domain_ip_universe_v85;
-- DONE DEALING WITH TABLE dns_domain_ip_universe (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE operating_system
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'operating_system', 'operating_system');

-- FOREIGN KEYS FROM
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_dev_os_id;
ALTER TABLE operating_system_snapshot DROP CONSTRAINT IF EXISTS fk_os_snap_osid;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_osid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.operating_system DROP CONSTRAINT IF EXISTS fk_os_company;
ALTER TABLE jazzhands.operating_system DROP CONSTRAINT IF EXISTS fk_os_fk_val_dev_arch;
ALTER TABLE jazzhands.operating_system DROP CONSTRAINT IF EXISTS fk_os_os_family;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'operating_system');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.operating_system DROP CONSTRAINT IF EXISTS pk_operating_system;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_os_company";
DROP INDEX IF EXISTS "jazzhands"."xif_os_os_family";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_operating_system ON jazzhands.operating_system;
DROP TRIGGER IF EXISTS trigger_audit_operating_system ON jazzhands.operating_system;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'operating_system');
---- BEGIN audit.operating_system TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'operating_system', 'operating_system');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'operating_system');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.operating_system DROP CONSTRAINT IF EXISTS operating_system_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_operating_system_pk_operating_system";
DROP INDEX IF EXISTS "audit"."operating_system_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."operating_system_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."operating_system_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.operating_system TEARDOWN


ALTER TABLE operating_system RENAME TO operating_system_v85;
ALTER TABLE audit.operating_system RENAME TO operating_system_v85;

CREATE TABLE jazzhands.operating_system
(
	operating_system_id	integer NOT NULL,
	operating_system_name	varchar(255) NOT NULL,
	operating_system_short_name	varchar(255)  NULL,
	company_id	integer  NULL,
	major_version	varchar(50) NOT NULL,
	version	varchar(255) NOT NULL,
	operating_system_family	varchar(50)  NULL,
	processor_architecture	varchar(50)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'operating_system', false);
ALTER TABLE operating_system
	ALTER operating_system_id
	SET DEFAULT nextval('jazzhands.operating_system_operating_system_id_seq'::regclass);
INSERT INTO operating_system (
	operating_system_id,
	operating_system_name,
	operating_system_short_name,		-- new column (operating_system_short_name)
	company_id,
	major_version,
	version,
	operating_system_family,
	processor_architecture,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	operating_system_id,
	operating_system_name,
	NULL,		-- new column (operating_system_short_name)
	company_id,
	major_version,
	version,
	operating_system_family,
	processor_architecture,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM operating_system_v85;

INSERT INTO audit.operating_system (
	operating_system_id,
	operating_system_name,
	operating_system_short_name,		-- new column (operating_system_short_name)
	company_id,
	major_version,
	version,
	operating_system_family,
	processor_architecture,
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
	operating_system_id,
	operating_system_name,
	NULL,		-- new column (operating_system_short_name)
	company_id,
	major_version,
	version,
	operating_system_family,
	processor_architecture,
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
FROM audit.operating_system_v85;

ALTER TABLE jazzhands.operating_system
	ALTER operating_system_id
	SET DEFAULT nextval('jazzhands.operating_system_operating_system_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.operating_system ADD CONSTRAINT ak_operating_system_name_version UNIQUE (operating_system_name, version);
ALTER TABLE jazzhands.operating_system ADD CONSTRAINT pk_operating_system PRIMARY KEY (operating_system_id);
ALTER TABLE jazzhands.operating_system ADD CONSTRAINT uq_operating_system_short_name UNIQUE (operating_system_short_name);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif7operating_system ON jazzhands.operating_system USING btree (processor_architecture);
CREATE INDEX xif_os_company ON jazzhands.operating_system USING btree (company_id);
CREATE INDEX xif_os_os_family ON jazzhands.operating_system USING btree (operating_system_family);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between operating_system and jazzhands.device
ALTER TABLE jazzhands.device
	ADD CONSTRAINT fk_dev_os_id
	FOREIGN KEY (operating_system_id) REFERENCES jazzhands.operating_system(operating_system_id);
-- consider FK between operating_system and jazzhands.operating_system_snapshot
ALTER TABLE jazzhands.operating_system_snapshot
	ADD CONSTRAINT fk_os_snap_osid
	FOREIGN KEY (operating_system_id) REFERENCES jazzhands.operating_system(operating_system_id);
-- consider FK between operating_system and jazzhands.property
ALTER TABLE jazzhands.property
	ADD CONSTRAINT fk_property_osid
	FOREIGN KEY (operating_system_id) REFERENCES jazzhands.operating_system(operating_system_id);

-- FOREIGN KEYS TO
-- consider FK operating_system and company
ALTER TABLE jazzhands.operating_system
	ADD CONSTRAINT fk_os_company
	FOREIGN KEY (company_id) REFERENCES jazzhands.company(company_id) DEFERRABLE;
-- consider FK operating_system and val_operating_system_family
ALTER TABLE jazzhands.operating_system
	ADD CONSTRAINT fk_os_os_family
	FOREIGN KEY (operating_system_family) REFERENCES jazzhands.val_operating_system_family(operating_system_family);
-- consider FK operating_system and val_processor_architecture
ALTER TABLE jazzhands.operating_system
	ADD CONSTRAINT r_819
	FOREIGN KEY (processor_architecture) REFERENCES jazzhands.val_processor_architecture(processor_architecture);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'operating_system');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'operating_system');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'operating_system');
ALTER SEQUENCE jazzhands.operating_system_operating_system_id_seq
	 OWNED BY operating_system.operating_system_id;
DROP TABLE IF EXISTS operating_system_v85;
DROP TABLE IF EXISTS audit.operating_system_v85;
-- DONE DEALING WITH TABLE operating_system (jazzhands)
--------------------------------------------------------------------
--
-- BEGIN: process_ancillary_schema(jazzhands_cache)
--
-- =============================================
DO $$
BEGIN
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE ct_account_collection_hier_from_ancestor (jazzhands_cache)
CREATE TABLE jazzhands_cache.ct_account_collection_hier_from_ancestor
(
	root_account_collection_id	integer  NULL,
	intermediate_account_collection_id	integer  NULL,
	account_collection_id	integer  NULL,
	path	integer[] NOT NULL,
	cycle	boolean  NULL
);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands_cache.ct_account_collection_hier_from_ancestor ADD CONSTRAINT ct_account_collection_hier_from_ancestor_pkey PRIMARY KEY (path);

-- Table/Column Comments
-- INDEXES
CREATE INDEX iix_account_collection_hier_from_ancestor_id ON jazzhands_cache.ct_account_collection_hier_from_ancestor USING btree (account_collection_id);
CREATE INDEX iix_account_collection_hier_from_ancestor_inter_id ON jazzhands_cache.ct_account_collection_hier_from_ancestor USING btree (intermediate_account_collection_id);
CREATE INDEX ix_account_collection_hier_from_ancestor_id ON jazzhands_cache.ct_account_collection_hier_from_ancestor USING btree (root_account_collection_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE ct_account_collection_hier_from_ancestor (jazzhands_cache)
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
-- DEALING WITH NEW TABLE ct_device_collection_hier_from_ancestor (jazzhands_cache)
CREATE TABLE jazzhands_cache.ct_device_collection_hier_from_ancestor
(
	root_device_collection_id	integer  NULL,
	intermediate_device_collection_id	integer  NULL,
	device_collection_id	integer  NULL,
	path	integer[] NOT NULL,
	cycle	boolean  NULL
);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands_cache.ct_device_collection_hier_from_ancestor ADD CONSTRAINT ct_device_collection_hier_from_ancestor_pkey PRIMARY KEY (path);

-- Table/Column Comments
-- INDEXES
CREATE INDEX iix_device_collection_hier_from_ancestor_id ON jazzhands_cache.ct_device_collection_hier_from_ancestor USING btree (device_collection_id);
CREATE INDEX iix_device_collection_hier_from_ancestor_inter_id ON jazzhands_cache.ct_device_collection_hier_from_ancestor USING btree (intermediate_device_collection_id);
CREATE INDEX ix_device_collection_hier_from_ancestor_id ON jazzhands_cache.ct_device_collection_hier_from_ancestor USING btree (root_device_collection_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE ct_device_collection_hier_from_ancestor (jazzhands_cache)
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
-- DEALING WITH NEW TABLE ct_netblock_collection_hier_from_ancestor (jazzhands_cache)
CREATE TABLE jazzhands_cache.ct_netblock_collection_hier_from_ancestor
(
	root_netblock_collection_id	integer  NULL,
	intermediate_netblock_collection_id	integer  NULL,
	netblock_collection_id	integer  NULL,
	path	integer[] NOT NULL,
	cycle	boolean  NULL
);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands_cache.ct_netblock_collection_hier_from_ancestor ADD CONSTRAINT ct_netblock_collection_hier_from_ancestor_pkey PRIMARY KEY (path);

-- Table/Column Comments
-- INDEXES
CREATE INDEX iix_netblock_collection_hier_from_ancestor_id ON jazzhands_cache.ct_netblock_collection_hier_from_ancestor USING btree (netblock_collection_id);
CREATE INDEX iix_netblock_collection_hier_from_ancestor_inter_id ON jazzhands_cache.ct_netblock_collection_hier_from_ancestor USING btree (intermediate_netblock_collection_id);
CREATE INDEX ix_netblock_collection_hier_from_ancestor_id ON jazzhands_cache.ct_netblock_collection_hier_from_ancestor USING btree (root_netblock_collection_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE ct_netblock_collection_hier_from_ancestor (jazzhands_cache)
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
-- DEALING WITH NEW TABLE ct_netblock_hier (jazzhands_cache)
CREATE TABLE jazzhands_cache.ct_netblock_hier
(
	root_netblock_id	integer  NULL,
	intermediate_netblock_id	integer  NULL,
	netblock_id	integer  NULL,
	path	integer[] NOT NULL
);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands_cache.ct_netblock_hier ADD CONSTRAINT ct_netblock_hier_pkey PRIMARY KEY (path);

-- Table/Column Comments
-- INDEXES
CREATE INDEX ix_netblock_hier_netblock_intermediate_id ON jazzhands_cache.ct_netblock_hier USING btree (intermediate_netblock_id);
CREATE INDEX ix_netblock_hier_netblock_netblock_id ON jazzhands_cache.ct_netblock_hier USING btree (netblock_id);
CREATE INDEX ix_netblock_hier_netblock_path ON jazzhands_cache.ct_netblock_hier USING btree (path);
CREATE INDEX ix_netblock_hier_netblock_root_id ON jazzhands_cache.ct_netblock_hier USING btree (root_netblock_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE ct_netblock_hier (jazzhands_cache)
--------------------------------------------------------------------
EXCEPTION WHEN duplicate_table
	THEN NULL;
END;
$$;

-- =============================================
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_account_collection_hier_from_ancestor (jazzhands_cache)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_cache', 'v_account_collection_hier_from_ancestor');
DROP VIEW IF EXISTS jazzhands_cache.v_account_collection_hier_from_ancestor;
CREATE VIEW jazzhands_cache.v_account_collection_hier_from_ancestor AS
 WITH RECURSIVE var_recurse(root_account_collection_id, intermediate_account_collection_id, account_collection_id, path, cycle) AS (
         SELECT u.account_collection_id AS root_account_collection_id,
            u.account_collection_id AS intermediate_account_collection_id,
            u.account_collection_id,
            ARRAY[u.account_collection_id] AS path,
            false AS cycle
           FROM jazzhands.account_collection u
        UNION ALL
         SELECT x.root_account_collection_id,
            uch.account_collection_id AS intermediate_account_collection_id,
            uch.child_account_collection_id AS account_collection_id,
            array_prepend(uch.child_account_collection_id, x.path) AS path,
            uch.child_account_collection_id = ANY (x.path) AS cycle
           FROM var_recurse x
             JOIN jazzhands.account_collection_hier uch ON x.account_collection_id = uch.account_collection_id
          WHERE NOT x.cycle
        )
 SELECT var_recurse.root_account_collection_id,
    var_recurse.intermediate_account_collection_id,
    var_recurse.account_collection_id,
    var_recurse.path,
    var_recurse.cycle
   FROM var_recurse;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_cache' AND type = 'view' AND object = 'v_account_collection_hier_from_ancestor';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_account_collection_hier_from_ancestor failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_account_collection_hier_from_ancestor (jazzhands_cache)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_collection_hier_from_ancestor (jazzhands_cache)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_cache', 'v_device_collection_hier_from_ancestor');
DROP VIEW IF EXISTS jazzhands_cache.v_device_collection_hier_from_ancestor;
CREATE VIEW jazzhands_cache.v_device_collection_hier_from_ancestor AS
 WITH RECURSIVE var_recurse(root_device_collection_id, intermediate_device_collection_id, device_collection_id, path, cycle) AS (
         SELECT u.device_collection_id AS root_device_collection_id,
            u.device_collection_id AS intermediate_device_collection_id,
            u.device_collection_id,
            ARRAY[u.device_collection_id] AS path,
            false AS cycle
           FROM jazzhands.device_collection u
        UNION ALL
         SELECT x.root_device_collection_id,
            uch.device_collection_id AS intermediate_device_collection_id,
            uch.child_device_collection_id AS device_collection_id,
            array_prepend(uch.child_device_collection_id, x.path) AS path,
            uch.child_device_collection_id = ANY (x.path) AS cycle
           FROM var_recurse x
             JOIN jazzhands.device_collection_hier uch ON x.device_collection_id = uch.device_collection_id
          WHERE NOT x.cycle
        )
 SELECT var_recurse.root_device_collection_id,
    var_recurse.intermediate_device_collection_id,
    var_recurse.device_collection_id,
    var_recurse.path,
    var_recurse.cycle
   FROM var_recurse;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_cache' AND type = 'view' AND object = 'v_device_collection_hier_from_ancestor';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_collection_hier_from_ancestor failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_device_collection_hier_from_ancestor (jazzhands_cache)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_netblock_collection_hier_from_ancestor (jazzhands_cache)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_cache', 'v_netblock_collection_hier_from_ancestor');
DROP VIEW IF EXISTS jazzhands_cache.v_netblock_collection_hier_from_ancestor;
CREATE VIEW jazzhands_cache.v_netblock_collection_hier_from_ancestor AS
 WITH RECURSIVE var_recurse(root_netblock_collection_id, intermediate_netblock_collection_id, netblock_collection_id, path, cycle) AS (
         SELECT u.netblock_collection_id AS root_netblock_collection_id,
            u.netblock_collection_id AS intermediate_netblock_collection_id,
            u.netblock_collection_id,
            ARRAY[u.netblock_collection_id] AS path,
            false AS cycle
           FROM jazzhands.netblock_collection u
        UNION ALL
         SELECT x.root_netblock_collection_id,
            uch.netblock_collection_id AS intermediate_netblock_collection_id,
            uch.child_netblock_collection_id AS netblock_collection_id,
            array_prepend(uch.child_netblock_collection_id, x.path) AS path,
            uch.child_netblock_collection_id = ANY (x.path) AS cycle
           FROM var_recurse x
             JOIN jazzhands.netblock_collection_hier uch ON x.netblock_collection_id = uch.netblock_collection_id
          WHERE NOT x.cycle
        )
 SELECT var_recurse.root_netblock_collection_id,
    var_recurse.intermediate_netblock_collection_id,
    var_recurse.netblock_collection_id,
    var_recurse.path,
    var_recurse.cycle
   FROM var_recurse;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_cache' AND type = 'view' AND object = 'v_netblock_collection_hier_from_ancestor';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_netblock_collection_hier_from_ancestor failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_netblock_collection_hier_from_ancestor (jazzhands_cache)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_netblock_hier (jazzhands_cache)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_cache', 'v_netblock_hier');
DROP VIEW IF EXISTS jazzhands_cache.v_netblock_hier;
CREATE VIEW jazzhands_cache.v_netblock_hier AS
 WITH RECURSIVE var_recurse(root_netblock_id, intermediate_netblock_id, netblock_id, path) AS (
         SELECT netblock.netblock_id AS root_netblock_id,
            netblock.netblock_id AS intermediate_netblock_id,
            netblock.netblock_id,
            ARRAY[netblock.netblock_id] AS path
           FROM jazzhands.netblock
          WHERE netblock.is_single_address = 'N'::bpchar
        UNION
         SELECT p.root_netblock_id,
            n.parent_netblock_id,
            n.netblock_id,
            array_prepend(n.netblock_id, p.path) AS array_prepend
           FROM var_recurse p
             JOIN jazzhands.netblock n ON p.netblock_id = n.parent_netblock_id
          WHERE n.is_single_address = 'N'::bpchar
        )
 SELECT var_recurse.root_netblock_id,
    var_recurse.intermediate_netblock_id,
    var_recurse.netblock_id,
    var_recurse.path
   FROM var_recurse;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_cache' AND type = 'view' AND object = 'v_netblock_hier';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_netblock_hier failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_netblock_hier (jazzhands_cache)
--------------------------------------------------------------------
-- DONE: process_ancillary_schema(jazzhands_cache)
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_account_collection_hier_from_ancestor (jazzhands_cache)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_cache', 'v_account_collection_hier_from_ancestor');
DROP VIEW IF EXISTS jazzhands_cache.v_account_collection_hier_from_ancestor;
CREATE VIEW jazzhands_cache.v_account_collection_hier_from_ancestor AS
 WITH RECURSIVE var_recurse(root_account_collection_id, intermediate_account_collection_id, account_collection_id, path, cycle) AS (
         SELECT u.account_collection_id AS root_account_collection_id,
            u.account_collection_id AS intermediate_account_collection_id,
            u.account_collection_id,
            ARRAY[u.account_collection_id] AS path,
            false AS cycle
           FROM jazzhands.account_collection u
        UNION ALL
         SELECT x.root_account_collection_id,
            uch.account_collection_id AS intermediate_account_collection_id,
            uch.child_account_collection_id AS account_collection_id,
            array_prepend(uch.child_account_collection_id, x.path) AS path,
            uch.child_account_collection_id = ANY (x.path) AS cycle
           FROM var_recurse x
             JOIN jazzhands.account_collection_hier uch ON x.account_collection_id = uch.account_collection_id
          WHERE NOT x.cycle
        )
 SELECT var_recurse.root_account_collection_id,
    var_recurse.intermediate_account_collection_id,
    var_recurse.account_collection_id,
    var_recurse.path,
    var_recurse.cycle
   FROM var_recurse;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_cache' AND type = 'view' AND object = 'v_account_collection_hier_from_ancestor';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_account_collection_hier_from_ancestor failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_account_collection_hier_from_ancestor (jazzhands_cache)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_collection_hier_from_ancestor (jazzhands_cache)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_cache', 'v_device_collection_hier_from_ancestor');
DROP VIEW IF EXISTS jazzhands_cache.v_device_collection_hier_from_ancestor;
CREATE VIEW jazzhands_cache.v_device_collection_hier_from_ancestor AS
 WITH RECURSIVE var_recurse(root_device_collection_id, intermediate_device_collection_id, device_collection_id, path, cycle) AS (
         SELECT u.device_collection_id AS root_device_collection_id,
            u.device_collection_id AS intermediate_device_collection_id,
            u.device_collection_id,
            ARRAY[u.device_collection_id] AS path,
            false AS cycle
           FROM jazzhands.device_collection u
        UNION ALL
         SELECT x.root_device_collection_id,
            uch.device_collection_id AS intermediate_device_collection_id,
            uch.child_device_collection_id AS device_collection_id,
            array_prepend(uch.child_device_collection_id, x.path) AS path,
            uch.child_device_collection_id = ANY (x.path) AS cycle
           FROM var_recurse x
             JOIN jazzhands.device_collection_hier uch ON x.device_collection_id = uch.device_collection_id
          WHERE NOT x.cycle
        )
 SELECT var_recurse.root_device_collection_id,
    var_recurse.intermediate_device_collection_id,
    var_recurse.device_collection_id,
    var_recurse.path,
    var_recurse.cycle
   FROM var_recurse;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_cache' AND type = 'view' AND object = 'v_device_collection_hier_from_ancestor';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_collection_hier_from_ancestor failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_device_collection_hier_from_ancestor (jazzhands_cache)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_netblock_collection_hier_from_ancestor (jazzhands_cache)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_cache', 'v_netblock_collection_hier_from_ancestor');
DROP VIEW IF EXISTS jazzhands_cache.v_netblock_collection_hier_from_ancestor;
CREATE VIEW jazzhands_cache.v_netblock_collection_hier_from_ancestor AS
 WITH RECURSIVE var_recurse(root_netblock_collection_id, intermediate_netblock_collection_id, netblock_collection_id, path, cycle) AS (
         SELECT u.netblock_collection_id AS root_netblock_collection_id,
            u.netblock_collection_id AS intermediate_netblock_collection_id,
            u.netblock_collection_id,
            ARRAY[u.netblock_collection_id] AS path,
            false AS cycle
           FROM jazzhands.netblock_collection u
        UNION ALL
         SELECT x.root_netblock_collection_id,
            uch.netblock_collection_id AS intermediate_netblock_collection_id,
            uch.child_netblock_collection_id AS netblock_collection_id,
            array_prepend(uch.child_netblock_collection_id, x.path) AS path,
            uch.child_netblock_collection_id = ANY (x.path) AS cycle
           FROM var_recurse x
             JOIN jazzhands.netblock_collection_hier uch ON x.netblock_collection_id = uch.netblock_collection_id
          WHERE NOT x.cycle
        )
 SELECT var_recurse.root_netblock_collection_id,
    var_recurse.intermediate_netblock_collection_id,
    var_recurse.netblock_collection_id,
    var_recurse.path,
    var_recurse.cycle
   FROM var_recurse;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_cache' AND type = 'view' AND object = 'v_netblock_collection_hier_from_ancestor';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_netblock_collection_hier_from_ancestor failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_netblock_collection_hier_from_ancestor (jazzhands_cache)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_netblock_hier (jazzhands_cache)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_cache', 'v_netblock_hier');
DROP VIEW IF EXISTS jazzhands_cache.v_netblock_hier;
CREATE VIEW jazzhands_cache.v_netblock_hier AS
 WITH RECURSIVE var_recurse(root_netblock_id, intermediate_netblock_id, netblock_id, path) AS (
         SELECT netblock.netblock_id AS root_netblock_id,
            netblock.netblock_id AS intermediate_netblock_id,
            netblock.netblock_id,
            ARRAY[netblock.netblock_id] AS path
           FROM jazzhands.netblock
          WHERE netblock.is_single_address = 'N'::bpchar
        UNION
         SELECT p.root_netblock_id,
            n.parent_netblock_id,
            n.netblock_id,
            array_prepend(n.netblock_id, p.path) AS array_prepend
           FROM var_recurse p
             JOIN jazzhands.netblock n ON p.netblock_id = n.parent_netblock_id
          WHERE n.is_single_address = 'N'::bpchar
        )
 SELECT var_recurse.root_netblock_id,
    var_recurse.intermediate_netblock_id,
    var_recurse.netblock_id,
    var_recurse.path
   FROM var_recurse;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_cache' AND type = 'view' AND object = 'v_netblock_hier';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_netblock_hier failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_netblock_hier (jazzhands_cache)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_device_collection_hier_trans
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_collection_hier_trans', 'v_device_collection_hier_trans');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_device_collection_hier_trans');
DROP VIEW IF EXISTS jazzhands.v_device_collection_hier_trans;
CREATE VIEW jazzhands.v_device_collection_hier_trans AS
 SELECT device_collection_hier.device_collection_id AS parent_device_collection_id,
    device_collection_hier.child_device_collection_id AS device_collection_id,
    device_collection_hier.data_ins_user,
    device_collection_hier.data_ins_date,
    device_collection_hier.data_upd_user,
    device_collection_hier.data_upd_date
   FROM jazzhands.device_collection_hier;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object = 'v_device_collection_hier_trans';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_collection_hier_trans failed but that is ok';
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
-- DONE DEALING WITH TABLE v_device_collection_hier_trans (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_site_netblock_expanded
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_site_netblock_expanded', 'v_site_netblock_expanded');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_site_netblock_expanded');
DROP VIEW IF EXISTS jazzhands.v_site_netblock_expanded;
CREATE VIEW jazzhands.v_site_netblock_expanded AS
 SELECT bizness.site_code,
    netblock.netblock_id
   FROM jazzhands.netblock
     LEFT JOIN ( SELECT miniq.site_code,
            miniq.netblock_id
           FROM ( SELECT p.site_code,
                    n.netblock_id,
                    rank() OVER (PARTITION BY n.netblock_id ORDER BY (array_length(hc.path, 1)), (array_length(n.path, 1))) AS tier
                   FROM jazzhands.property p
                     JOIN jazzhands.netblock_collection nc USING (netblock_collection_id)
                     JOIN jazzhands_cache.ct_netblock_collection_hier_from_ancestor hc USING (netblock_collection_id)
                     JOIN jazzhands.netblock_collection_netblock ncn USING (netblock_collection_id)
                     JOIN jazzhands_cache.ct_netblock_hier n ON ncn.netblock_id = n.root_netblock_id
                  WHERE p.property_name::text = 'per-site-netblock_collection'::text AND p.property_type::text = 'automated'::text) miniq
          WHERE miniq.tier = 1) bizness USING (netblock_id)
  WHERE netblock.is_single_address = 'N'::bpchar
UNION ALL
 SELECT f.site_code,
    n.netblock_id
   FROM ( SELECT bizness.site_code,
            netblock.netblock_id
           FROM jazzhands.netblock
             LEFT JOIN ( SELECT miniq.site_code,
                    miniq.netblock_id
                   FROM ( SELECT p.site_code,
                            n_1.netblock_id,
                            rank() OVER (PARTITION BY n_1.netblock_id ORDER BY (array_length(hc.path, 1)), (array_length(n_1.path, 1))) AS tier
                           FROM jazzhands.property p
                             JOIN jazzhands.netblock_collection nc USING (netblock_collection_id)
                             JOIN jazzhands_cache.ct_netblock_collection_hier_from_ancestor hc USING (netblock_collection_id)
                             JOIN jazzhands.netblock_collection_netblock ncn USING (netblock_collection_id)
                             JOIN jazzhands_cache.ct_netblock_hier n_1 ON ncn.netblock_id = n_1.root_netblock_id
                          WHERE p.property_name::text = 'per-site-netblock_collection'::text AND p.property_type::text = 'automated'::text) miniq
                  WHERE miniq.tier = 1) bizness USING (netblock_id)
          WHERE netblock.is_single_address = 'N'::bpchar) f
     JOIN jazzhands.netblock n ON f.netblock_id = n.parent_netblock_id
  WHERE n.parent_netblock_id IS NOT NULL AND n.is_single_address = 'Y'::bpchar
UNION ALL
 SELECT NULL::character varying AS site_code,
    netblock.netblock_id
   FROM jazzhands.netblock
  WHERE netblock.is_single_address = 'Y'::bpchar AND netblock.parent_netblock_id IS NULL;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object = 'v_site_netblock_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_site_netblock_expanded failed but that is ok';
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
-- DONE DEALING WITH TABLE v_site_netblock_expanded (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_application_role
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_application_role', 'v_application_role');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_application_role');
DROP VIEW IF EXISTS jazzhands.v_application_role;
CREATE VIEW jazzhands.v_application_role AS
 WITH RECURSIVE var_recurse(role_level, role_id, parent_role_id, root_role_id, root_role_name, role_name, role_path, role_is_leaf, array_path, cycle) AS (
         SELECT 0 AS role_level,
            device_collection.device_collection_id AS role_id,
            NULL::integer AS parent_role_id,
            device_collection.device_collection_id AS root_role_id,
            device_collection.device_collection_name AS root_role_name,
            device_collection.device_collection_name AS role_name,
            '/'::text || device_collection.device_collection_name::text AS role_path,
            'N'::text AS role_is_leaf,
            ARRAY[device_collection.device_collection_id] AS array_path,
            false AS cycle
           FROM jazzhands.device_collection
          WHERE device_collection.device_collection_type::text = 'appgroup'::text AND NOT (device_collection.device_collection_id IN ( SELECT v_device_collection_hier_trans.device_collection_id
                   FROM jazzhands.v_device_collection_hier_trans))
        UNION ALL
         SELECT x.role_level + 1 AS role_level,
            dch.device_collection_id AS role_id,
            dch.parent_device_collection_id AS parent_role_id,
            x.root_role_id,
            x.root_role_name,
            dc.device_collection_name AS role_name,
            (((x.role_path || '/'::text) || dc.device_collection_name::text))::character varying(255) AS role_path,
                CASE
                    WHEN lchk.parent_device_collection_id IS NULL THEN 'Y'::text
                    ELSE 'N'::text
                END AS role_is_leaf,
            dch.parent_device_collection_id || x.array_path AS array_path,
            dch.parent_device_collection_id = ANY (x.array_path) AS cycle
           FROM var_recurse x
             JOIN jazzhands.v_device_collection_hier_trans dch ON x.role_id = dch.parent_device_collection_id
             JOIN jazzhands.device_collection dc ON dch.device_collection_id = dc.device_collection_id
             LEFT JOIN jazzhands.v_device_collection_hier_trans lchk ON dch.device_collection_id = lchk.parent_device_collection_id
          WHERE NOT x.cycle
        )
 SELECT DISTINCT var_recurse.role_level,
    var_recurse.role_id,
    var_recurse.parent_role_id,
    var_recurse.root_role_id,
    var_recurse.root_role_name,
    var_recurse.role_name,
    var_recurse.role_path,
    var_recurse.role_is_leaf,
    var_recurse.array_path,
    var_recurse.cycle
   FROM var_recurse;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object = 'v_application_role';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_application_role failed but that is ok';
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
-- DONE DEALING WITH TABLE v_application_role (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_device_coll_device_expanded
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_coll_device_expanded', 'v_device_coll_device_expanded');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_device_coll_device_expanded');
DROP VIEW IF EXISTS jazzhands.v_device_coll_device_expanded;
CREATE VIEW jazzhands.v_device_coll_device_expanded AS
 WITH RECURSIVE var_recurse(root_device_collection_id, device_collection_id, parent_device_collection_id, device_collection_level, array_path, cycle) AS (
         SELECT device_collection.device_collection_id AS root_device_collection_id,
            device_collection.device_collection_id,
            device_collection.device_collection_id AS parent_device_collection_id,
            0 AS device_collection_level,
            ARRAY[device_collection.device_collection_id] AS "array",
            false AS bool
           FROM jazzhands.device_collection
        UNION ALL
         SELECT x.root_device_collection_id,
            dch.device_collection_id,
            dch.parent_device_collection_id,
            x.device_collection_level + 1 AS device_collection_level,
            dch.parent_device_collection_id || x.array_path AS array_path,
            dch.parent_device_collection_id = ANY (x.array_path)
           FROM var_recurse x
             JOIN jazzhands.v_device_collection_hier_trans dch ON x.device_collection_id = dch.parent_device_collection_id
          WHERE NOT x.cycle
        )
 SELECT DISTINCT var_recurse.root_device_collection_id AS device_collection_id,
    device_collection_device.device_id
   FROM var_recurse
     JOIN jazzhands.device_collection_device USING (device_collection_id);

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object = 'v_device_coll_device_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_coll_device_expanded failed but that is ok';
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
-- DONE DEALING WITH TABLE v_device_coll_device_expanded (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_device_coll_hier_detail
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_coll_hier_detail', 'v_device_coll_hier_detail');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_device_coll_hier_detail');
DROP VIEW IF EXISTS jazzhands.v_device_coll_hier_detail;
CREATE VIEW jazzhands.v_device_coll_hier_detail AS
 WITH RECURSIVE var_recurse(root_device_collection_id, device_collection_id, parent_device_collection_id, device_collection_level, array_path, cycle) AS (
         SELECT device_collection.device_collection_id AS root_device_collection_id,
            device_collection.device_collection_id,
            device_collection.device_collection_id AS parent_device_collection_id,
            0 AS device_collection_level,
            ARRAY[device_collection.device_collection_id] AS "array",
            false AS bool
           FROM jazzhands.device_collection
        UNION ALL
         SELECT x.root_device_collection_id,
            dch.device_collection_id,
            dch.parent_device_collection_id,
            x.device_collection_level + 1 AS device_collection_level,
            dch.parent_device_collection_id || x.array_path AS array_path,
            dch.parent_device_collection_id = ANY (x.array_path)
           FROM var_recurse x
             JOIN jazzhands.v_device_collection_hier_trans dch ON x.parent_device_collection_id = dch.device_collection_id
          WHERE NOT x.cycle
        )
 SELECT var_recurse.root_device_collection_id AS device_collection_id,
    var_recurse.parent_device_collection_id,
    var_recurse.device_collection_level
   FROM var_recurse;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object = 'v_device_coll_hier_detail';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_coll_hier_detail failed but that is ok';
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
-- DONE DEALING WITH TABLE v_device_coll_hier_detail (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_account_collection_hier_from_ancestor (jazzhands)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_account_collection_hier_from_ancestor');
DROP VIEW IF EXISTS jazzhands.v_account_collection_hier_from_ancestor;
CREATE VIEW jazzhands.v_account_collection_hier_from_ancestor AS
 SELECT ct_account_collection_hier_from_ancestor.root_account_collection_id,
    ct_account_collection_hier_from_ancestor.intermediate_account_collection_id,
    ct_account_collection_hier_from_ancestor.account_collection_id,
    ct_account_collection_hier_from_ancestor.path,
    ct_account_collection_hier_from_ancestor.cycle
   FROM jazzhands_cache.ct_account_collection_hier_from_ancestor;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object = 'v_account_collection_hier_from_ancestor';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_account_collection_hier_from_ancestor failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_account_collection_hier_from_ancestor (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_collection_hier_from_ancestor (jazzhands)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_device_collection_hier_from_ancestor');
DROP VIEW IF EXISTS jazzhands.v_device_collection_hier_from_ancestor;
CREATE VIEW jazzhands.v_device_collection_hier_from_ancestor AS
 SELECT ct_device_collection_hier_from_ancestor.root_device_collection_id,
    ct_device_collection_hier_from_ancestor.intermediate_device_collection_id,
    ct_device_collection_hier_from_ancestor.device_collection_id,
    ct_device_collection_hier_from_ancestor.path,
    ct_device_collection_hier_from_ancestor.cycle
   FROM jazzhands_cache.ct_device_collection_hier_from_ancestor;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object = 'v_device_collection_hier_from_ancestor';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_collection_hier_from_ancestor failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_device_collection_hier_from_ancestor (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_netblock_collection_hier_from_ancestor (jazzhands)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_netblock_collection_hier_from_ancestor');
DROP VIEW IF EXISTS jazzhands.v_netblock_collection_hier_from_ancestor;
CREATE VIEW jazzhands.v_netblock_collection_hier_from_ancestor AS
 SELECT ct_netblock_collection_hier_from_ancestor.root_netblock_collection_id,
    ct_netblock_collection_hier_from_ancestor.intermediate_netblock_collection_id,
    ct_netblock_collection_hier_from_ancestor.netblock_collection_id,
    ct_netblock_collection_hier_from_ancestor.path,
    ct_netblock_collection_hier_from_ancestor.cycle
   FROM jazzhands_cache.ct_netblock_collection_hier_from_ancestor;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object = 'v_netblock_collection_hier_from_ancestor';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_netblock_collection_hier_from_ancestor failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_netblock_collection_hier_from_ancestor (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_account_name (jazzhands)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_account_name');
DROP VIEW IF EXISTS jazzhands.v_account_name;
CREATE VIEW jazzhands.v_account_name AS
 SELECT a.account_id,
    COALESCE(prp.first_name, p.first_name::text) AS first_name,
    COALESCE(prp.last_name, p.last_name::text) AS last_name,
    COALESCE(prp.display_name, (COALESCE(prp.first_name, p.first_name::text) || ' '::text) || COALESCE(prp.last_name, p.last_name::text)) AS display_name
   FROM jazzhands.account a
     JOIN jazzhands.v_person p USING (person_id)
     LEFT JOIN ( SELECT aca.account_id,
            min(property.property_value::text) FILTER (WHERE property.property_name::text = 'first_name'::text) AS first_name,
            min(property.property_value::text) FILTER (WHERE property.property_name::text = 'last_name'::text) AS last_name,
            min(property.property_value::text) FILTER (WHERE property.property_name::text = 'display_name'::text) AS display_name
           FROM jazzhands.account_collection_account aca
             JOIN jazzhands.property USING (account_collection_id)
          WHERE property.property_type::text = 'account_name_override'::text
          GROUP BY aca.account_id) prp USING (account_id);

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object = 'v_account_name';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_account_name failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_account_name (jazzhands)
--------------------------------------------------------------------
--
-- Process drops in jazzhands_cache
--
-- New function
CREATE OR REPLACE FUNCTION jazzhands_cache.account_collection_base_handler()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	IF TG_OP = 'DELETE' THEN
		DELETE FROM jazzhands_cache.ct_account_collection_hier_from_ancestor
		WHERE root_account_collection_id = OLD.account_collection_id
		AND intermediate_account_collection_id = OLD.account_collection_id
		AND account_collection_id = OLD.account_collection_id;

		RETURN OLD;
	ELSIF TG_OP = 'UPDATE' THEN
		--- XXX - fix path?  write tests!
		UPDATE jazzhands_cache.ct_account_collection_hier_from_ancestor
		SET
			root_account_collection_id = NEW.account_collection_id,
			intermediate_account_collection_id = NEW.intermediate_account_collection_id,
			account_collection_id = NEW.account_collection_id
		WHERE root_account_collection_id = OLD.account_collection_id
		AND intermediate_account_collection_id = OLD.account_collection_id
		AND account_collection_id = OLD.account_collection_id;
	ELSIF TG_OP = 'INSERT' THEN
		INSERT INTO jazzhands_cache.ct_account_collection_hier_from_ancestor (
			root_account_collection_id,
			intermediate_account_collection_id,
			account_collection_id,
			path,
			cycle
		) VALUES (
			NEW.account_collection_id,
			NEW.account_collection_id,
			NEW.account_collection_id,
			ARRAY[NEW.account_collection_id],
			false
		);
	END IF;

	RETURN NEW;
END
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands_cache.account_collection_root_handler()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_r		RECORD;
	_cnt	INTEGER;
BEGIN
	--
	-- Delete any rows that are invalidated due to a parent change.
	--
	IF
		(TG_OP = 'DELETE' OR TG_OP = 'UPDATE')
	THEN
		FOR _r IN
		DELETE FROM jazzhands_cache.ct_account_collection_hier_from_ancestor
		WHERE	OLD.account_collection_id = ANY (path)
		AND		OLD.child_account_collection_id = ANY (path)
		RETURNING *
		LOOP
			RAISE DEBUG '-> rm %', to_json(_r);
		END LOOP
		;
		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Deleting upstream references to netcoll %/% from cache == %',
			OLD.account_collection_id, OLD.child_account_collection_id, _cnt;
	END IF;

	--
	-- Insert any new rows to correspond with a new parent
	--


	--
	-- XXX - NEED TO START OVER SKETCH OUT EXACTLY WHAT NEEDS TO HAPPEN
	-- ON INSERT, UPDATE, DELETE IN ENGLISH, THEN WRITE.
	--

	--
	-- this worked for stuff added on top but I think I need to be more
	-- clever
	--
	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
		RAISE DEBUG '%%Insert: %', to_json(NEW);
		FOR _r IN
		WITH base_account AS (
			SELECT *, 'parent'::text as src
			FROM jazzhands_cache.ct_account_collection_hier_from_ancestor
			WHERE NEW.account_collection_id = ANY (path)
			AND array_length(path, 1) > 1
			AND account_collection_id = NEW.account_collection_id

		), base_child AS (
			-- deal with everything rooted at the child; this handles the case
			-- of something being inserted on top of the child
			SELECT *, 'child'::text as src
			FROM jazzhands_cache.ct_account_collection_hier_from_ancestor
			WHERE NEW.child_account_collection_id = ANY (path)
			AND root_account_collection_id != NEW.child_account_collection_id
			AND account_collection_id != NEW.child_account_collection_id
			AND array_length(path, 1) > 1

		), iparent AS (
			INSERT INTO jazzhands_cache.ct_account_collection_hier_from_ancestor (
				root_account_collection_id,
				intermediate_account_collection_id,
				account_collection_id,
				path,
				cycle
			)  SELECT
				base.root_account_collection_id,
				NEW.account_collection_id,
				NEW.child_account_collection_id,
				array_cat(
					array_cat(
						path[: (array_position(path, NEW.account_collection_id)-1)],
					ARRAY[NEW.child_account_collection_id, NEW.account_collection_id]
					),
					path[(array_position(path, NEW.account_collection_id)+1) :]
				),
				NEW.child_account_collection_id = ANY(base.path)
				FROM base_account AS base
				RETURNING *
		), ichild AS (
			INSERT INTO jazzhands_cache.ct_account_collection_hier_from_ancestor (
				root_account_collection_id,
				intermediate_account_collection_id,
				account_collection_id,
				path,
				cycle
			)  SELECT
				base.root_account_collection_id,
				base.intermediate_account_collection_id,
				base.account_collection_id,
				array_cat(
					array_cat(
						path[: (array_position(path, NEW.child_account_collection_id)-1)],
					ARRAY[NEW.child_account_collection_id, NEW.account_collection_id]
					),
					path[(array_position(path, NEW.child_account_collection_id)+1) :]
				),
				false -- hope... NEW.child_account_collection_id = ANY(base.path)
				FROM base_child AS base
				RETURNING *

		) SELECT 'c' AS q, * FROM ichild UNION SELECT 'p' AS q, * FROM iparent
		LOOP
			RAISE DEBUG 'i/down:%', to_json(_r);
			IF _r.cycle THEN
				RAISE EXCEPTION 'danger!  cycle!';
			END IF;
		END LOOP;

		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Inserting upstream references down for updated netcoll %/% into cache == %',
			NEW.account_collection_id, NEW.child_account_collection_id, _cnt;

		-- walk up and install rows for all the things above due to change
		FOR _r IN
		WITH RECURSIVE tier (
			root_account_collection_id,
			intermediate_account_collection_id,
			account_collection_id,
			path
		)AS (
			SELECT h.account_collection_id,
				h.account_collection_id,
				h.child_account_collection_Id,
				ARRAY[h.child_account_collection_id, h.account_collection_id],
				false as cycle
			FROM account_collection_hier  h
			WHERE h.account_collection_id = NEW.account_collection_id
			AND h.child_account_collection_id = NEW.child_account_collection_id
		UNION ALL
			SELECT tier.root_account_collection_id,
				n.account_collection_id,
				n.child_account_collection_id,
				array_prepend(n.child_account_collection_id, tier.path),
				n.child_account_collection_id = ANY(tier.path) as cycle
			FROM tier
				JOIN account_collection_hier n
					ON n.account_collection_id = tier.account_collection_id
			WHERE	NOT tier.cycle
		) INSERT INTO jazzhands_cache.ct_account_collection_hier_from_ancestor
				SELECT * FROM tier
		RETURNING *
		LOOP
			RAISE DEBUG 'i/up %', to_json(_r);
			IF _r.cycle THEN
				RAISE EXCEPTION 'danger!  cycle!';
			END IF;
		END LOOP;
		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Inserting upstream references up for updated netcol %/% into cache == %',
			NEW.account_collection_id, NEW.child_account_collection_id, _cnt;
	END IF;

	RETURN NULL;
END
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands_cache.cache_netblock_hier_handler()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_cnt	INTEGER;
	_r		RECORD;
BEGIN
	IF NEW.is_single_address = 'Y' THEN
		RETURN NULL;
	END IF;
	--
	-- Delete any rows that are invalidated due to a parent change.
	--
	IF TG_OP = 'DELETE' THEN
		FOR _r IN
		DELETE FROM jazzhands_cache.ct_netblock_hier
		WHERE	OLD.netblock_id = ANY(path)
		RETURNING *
		LOOP
			RAISE DEBUG '-> rm/DEL %', to_json(_r);
		END LOOP;
		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Deleting upstream references to netblock % from cache == %',
			OLD.netblock_id, _cnt;
	ELSIF TG_OP = 'UPDATE' AND OLD.parent_netblock_id IS NOT NULL THEN
		FOR _r IN
		DELETE FROM jazzhands_cache.ct_netblock_hier
		WHERE	OLD.parent_netblock_id IS NOT NULL
					AND		OLD.parent_netblock_id = ANY (path)
					AND		OLD.netblock_id = ANY (path)
					AND		netblock_id = OLD.netblock_id
		RETURNING *
		LOOP
			RAISE DEBUG '-> rm/upd %', to_json(_r);
		END LOOP;
		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Deleting upstream references to netblock %/% from cache == %',
			OLD.netblock_id, OLD.parent_netblock_id, _cnt;
	END IF;

	--
	-- Insert any new rows to correspond with a new parent
	--


	IF TG_OP IN ('INSERT') THEN
		RAISE DEBUG 'Inserting reference for new netblock % into cache [%]',
			NEW.netblock_id, NEW.parent_netblock_id;

		FOR _r IN
		WITH RECURSIVE tier (
			root_netblock_id,
			intermediate_netblock_id,
			netblock_id,
			path
		)AS (
			SELECT parent_netblock_id,
				parent_netblock_id,
				netblock_id,
				ARRAY[netblock_id, parent_netblock_id]
			FROM netblock WHERE netblock_id = NEW.netblock_id
			AND parent_netblock_id IS NOT NULL
		UNION ALL
			SELECT n.parent_netblock_id,
				tier.intermediate_netblock_id,
				tier.netblock_id,
				array_append(tier.path, n.parent_netblock_id)
			FROM tier
				JOIN netblock n ON n.netblock_id = tier.root_netblock_id
			WHERE n.parent_netblock_id IS NOT NULL
		), combo AS (
			 SELECT * FROM tier
			UNION ALL
			SELECT netblock_id, netblock_id, netblock_id, ARRAY[netblock_id]
			FROM netblock WHERE netblock_id = NEW.netblock_id
		) SELECT * FROM combo
		LOOP
			RAISE DEBUG 'nb/ins up %', to_json(_r);
			INSERT INTO jazzhands_cache.ct_netblock_hier (
				root_netblock_id, intermediate_netblock_id, 
				netblock_id, path
			) VALUES (
				_r.root_netblock_id, _r.intermediate_netblock_id, 
				_r.netblock_id, _r.path
			);
		END LOOP;

	ELSIF (TG_OP = 'UPDATE' AND NEW.parent_netblock_id IS NOT NULL) THEN

		FOR _r IN
		WITH base AS (
			SELECT *
			FROM jazzhands_cache.ct_netblock_hier
			WHERE NEW.netblock_id = ANY (path)
			AND array_length(path, 1) > 2

		), inew AS (
			INSERT INTO jazzhands_cache.ct_netblock_hier (
				root_netblock_id,
				intermediate_netblock_id,
				netblock_id,
				path
			)  SELECT
				base.root_netblock_id,
				NEW.parent_netblock_id,
				netblock_id,
				array_cat(
					array_cat(
						path[: (array_position(path, NEW.netblock_id)-1)],
						ARRAY[NEW.netblock_id, NEW.parent_netblock_id]
					),
					path[(array_position(path, NEW.netblock_id)+1) :]
				)
				FROM base
				RETURNING *
		), uold AS (
			UPDATE jazzhands_cache.ct_netblock_hier n
			SET root_netblock_id = base.root_netblock_id,
				intermediate_netblock_id = NEW.parent_netblock_id,
			path = array_replace(base.path, base.root_netblock_id, NEW.parent_netblock_id)
			FROM base
			WHERE n.path = base.path
				RETURNING n.*
		) SELECT 'ins' as "what", * FROM inew
			UNION
			SELECT 'upd' as "what", * FROM uold

		LOOP
			RAISE DEBUG 'down:%', to_json(_r);
		END LOOP;

		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Inserting upstream references down for updated netblock %/% into cache == %',
			NEW.netblock_id, NEW.parent_netblock_id, _cnt;

		-- walk up and install rows for all the things above due to change
		FOR _r IN
		WITH RECURSIVE tier (
			root_netblock_id,
			intermediate_netblock_id,
			netblock_id,
			path,
			cycle
		)AS (
			SELECT parent_netblock_id,
                parent_netblock_id,
                netblock_id,
                ARRAY[netblock_id, parent_netblock_id],
                false
            FROM netblock WHERE netblock_id = NEW.netblock_id
        UNION ALL
            SELECT n.parent_netblock_id,
                n.netblock_Id,
                tier.netblock_id,
                array_append(tier.path, n.parent_netblock_id),
                n.parent_netblock_id = ANY(path)
            FROM tier
                JOIN netblock n ON n.netblock_id = tier.root_netblock_id
            WHERE n.parent_netblock_id IS NOT NULL
			AND NOT cycle
        ) SELECT * FROM tier
		LOOP
			IF _r.cycle THEN
				RAISE EXCEPTION 'Insert Created a netblock loop.'
					USING ERRCODE = 'JH101';
			END IF;
			INSERT INTO jazzhands_cache.ct_netblock_hier (
				root_netblock_id, intermediate_netblock_id, netblock_id, path
			) VALUES (
				_r.root_netblock_id, _r.intermediate_netblock_id, _r.netblock_id, _r.path
			);

			RAISE DEBUG 'nb/upd up %', to_json(_r);
		END LOOP;
		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Inserting upstream references up for updated netblock %/% into cache == %',
			NEW.netblock_id, NEW.parent_netblock_id, _cnt;
	END IF;
	RETURN NULL;
END
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands_cache.cache_netblock_hier_truncate_handler()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	TRUNCATE TABLE jazzhands_cache.ct_netblock_hier;
	RETURN NULL;
END
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands_cache.device_collection_base_handler()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	IF TG_OP = 'DELETE' THEN
		DELETE FROM jazzhands_cache.ct_device_collection_hier_from_ancestor
		WHERE root_device_collection_id = OLD.device_collection_id
		AND intermediate_device_collection_id = OLD.device_collection_id
		AND device_collection_id = OLD.device_collection_id;

		RETURN OLD;
	ELSIF TG_OP = 'UPDATE' THEN
		--- XXX - fix path?  write tests!
		UPDATE jazzhands_cache.ct_device_collection_hier_from_ancestor
		SET
			root_device_collection_id = NEW.device_collection_id,
			intermediate_device_collection_id = NEW.intermediate_device_collection_id,
			device_collection_id = NEW.device_collection_id
		WHERE root_device_collection_id = OLD.device_collection_id
		AND intermediate_device_collection_id = OLD.device_collection_id
		AND device_collection_id = OLD.device_collection_id;
	ELSIF TG_OP = 'INSERT' THEN
		INSERT INTO jazzhands_cache.ct_device_collection_hier_from_ancestor (
			root_device_collection_id,
			intermediate_device_collection_id,
			device_collection_id,
			path,
			cycle
		) VALUES (
			NEW.device_collection_id,
			NEW.device_collection_id,
			NEW.device_collection_id,
			ARRAY[NEW.device_collection_id],
			false
		);
	END IF;

	RETURN NEW;
END
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands_cache.device_collection_root_handler()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_r		RECORD;
	_cnt	INTEGER;
BEGIN
	--
	-- Delete any rows that are invalidated due to a parent change.
	--
	IF
		(TG_OP = 'DELETE' OR TG_OP = 'UPDATE')
	THEN
		FOR _r IN
		DELETE FROM jazzhands_cache.ct_device_collection_hier_from_ancestor
		WHERE	OLD.device_collection_id = ANY (path)
		AND		OLD.child_device_collection_id = ANY (path)
		RETURNING *
		LOOP
			RAISE DEBUG '-> rm %', to_json(_r);
		END LOOP
		;
		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Deleting upstream references to netcoll %/% from cache == %',
			OLD.device_collection_id, OLD.child_device_collection_id, _cnt;
	END IF;

	--
	-- Insert any new rows to correspond with a new parent
	--


	--
	-- XXX - NEED TO START OVER SKETCH OUT EXACTLY WHAT NEEDS TO HAPPEN
	-- ON INSERT, UPDATE, DELETE IN ENGLISH, THEN WRITE.
	--

	--
	-- this worked for stuff added on top but I think I need to be more
	-- clever
	--
	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
		RAISE DEBUG '%%Insert: %', to_json(NEW);
		FOR _r IN
		WITH base_device AS (
			SELECT *, 'parent'::text as src
			FROM jazzhands_cache.ct_device_collection_hier_from_ancestor
			WHERE NEW.device_collection_id = ANY (path)
			AND array_length(path, 1) > 1
			AND device_collection_id = NEW.device_collection_id

		), base_child AS (
			-- deal with everything rooted at the child; this handles the case
			-- of something being inserted on top of the child
			SELECT *, 'child'::text as src
			FROM jazzhands_cache.ct_device_collection_hier_from_ancestor
			WHERE NEW.child_device_collection_id = ANY (path)
			AND root_device_collection_id != NEW.child_device_collection_id
			AND device_collection_id != NEW.child_device_collection_id
			AND array_length(path, 1) > 1

		), iparent AS (
			INSERT INTO jazzhands_cache.ct_device_collection_hier_from_ancestor (
				root_device_collection_id,
				intermediate_device_collection_id,
				device_collection_id,
				path,
				cycle
			)  SELECT
				base.root_device_collection_id,
				NEW.device_collection_id,
				NEW.child_device_collection_id,
				array_cat(
					array_cat(
						path[: (array_position(path, NEW.device_collection_id)-1)],
					ARRAY[NEW.child_device_collection_id, NEW.device_collection_id]
					),
					path[(array_position(path, NEW.device_collection_id)+1) :]
				),
				NEW.child_device_collection_id = ANY(base.path)
				FROM base_device AS base
				RETURNING *
		), ichild AS (
			INSERT INTO jazzhands_cache.ct_device_collection_hier_from_ancestor (
				root_device_collection_id,
				intermediate_device_collection_id,
				device_collection_id,
				path,
				cycle
			)  SELECT
				base.root_device_collection_id,
				base.intermediate_device_collection_id,
				base.device_collection_id,
				array_cat(
					array_cat(
						path[: (array_position(path, NEW.child_device_collection_id)-1)],
					ARRAY[NEW.child_device_collection_id, NEW.device_collection_id]
					),
					path[(array_position(path, NEW.child_device_collection_id)+1) :]
				),
				false -- hope... NEW.child_device_collection_id = ANY(base.path)
				FROM base_child AS base
				RETURNING *

		) SELECT 'c' AS q, * FROM ichild UNION SELECT 'p' AS q, * FROM iparent
		LOOP
			RAISE DEBUG 'i/down:%', to_json(_r);
			IF _r.cycle THEN
				RAISE EXCEPTION 'danger!  cycle!';
			END IF;
		END LOOP;

		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Inserting upstream references down for updated netcoll %/% into cache == %',
			NEW.device_collection_id, NEW.child_device_collection_id, _cnt;

		-- walk up and install rows for all the things above due to change
		FOR _r IN
		WITH RECURSIVE tier (
			root_device_collection_id,
			intermediate_device_collection_id,
			device_collection_id,
			path
		)AS (
			SELECT h.device_collection_id,
				h.device_collection_id,
				h.child_device_collection_Id,
				ARRAY[h.child_device_collection_id, h.device_collection_id],
				false as cycle
			FROM device_collection_hier  h
			WHERE h.device_collection_id = NEW.device_collection_id
			AND h.child_device_collection_id = NEW.child_device_collection_id
		UNION ALL
			SELECT tier.root_device_collection_id,
				n.device_collection_id,
				n.child_device_collection_id,
				array_prepend(n.child_device_collection_id, tier.path),
				n.child_device_collection_id = ANY(tier.path) as cycle
			FROM tier
				JOIN device_collection_hier n
					ON n.device_collection_id = tier.device_collection_id
			WHERE	NOT tier.cycle
		) INSERT INTO jazzhands_cache.ct_device_collection_hier_from_ancestor
				SELECT * FROM tier
		RETURNING *
		LOOP
			RAISE DEBUG 'i/up %', to_json(_r);
			IF _r.cycle THEN
				RAISE EXCEPTION 'danger!  cycle!';
			END IF;
		END LOOP;
		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Inserting upstream references up for updated netcol %/% into cache == %',
			NEW.device_collection_id, NEW.child_device_collection_id, _cnt;
	END IF;

	RETURN NULL;
END
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands_cache.netblock_collection_base_handler()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	IF TG_OP = 'DELETE' THEN
		DELETE FROM jazzhands_cache.ct_netblock_collection_hier_from_ancestor
		WHERE root_netblock_collection_id = OLD.netblock_collection_id
		AND intermediate_netblock_collection_id = OLD.netblock_collection_id
		AND netblock_collection_id = OLD.netblock_collection_id;

		RETURN OLD;
	ELSIF TG_OP = 'UPDATE' THEN
		UPDATE jazzhands_cache.ct_netblock_collection_hier_from_ancestor
		SET
			root_netblock_collection_id = NEW.netblock_collection_id,
			intermediate_netblock_collection_id = NEW.intermediate_netblock_collection_id,
			netblock_collection_id = NEW.netblock_collection_id
		WHERE root_netblock_collection_id = OLD.netblock_collection_id
		AND intermediate_netblock_collection_id = OLD.netblock_collection_id
		AND netblock_collection_id = OLD.netblock_collection_id;
	ELSIF TG_OP = 'INSERT' THEN
		INSERT INTO jazzhands_cache.ct_netblock_collection_hier_from_ancestor (
			root_netblock_collection_id,
			intermediate_netblock_collection_id,
			netblock_collection_id,
			path,
			cycle
		) VALUES (
			NEW.netblock_collection_id,
			NEW.netblock_collection_id,
			NEW.netblock_collection_id,
			ARRAY[NEW.netblock_collection_id],
			false
		);
	END IF;

	RETURN NEW;
END
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands_cache.netblock_collection_root_handler()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_r		RECORD;
	_cnt	INTEGER;
BEGIN
	--
	-- Delete any rows that are invalidated due to a parent change.
	--
	IF
		(TG_OP = 'DELETE' OR TG_OP = 'UPDATE')
	THEN
		FOR _r IN
		DELETE FROM jazzhands_cache.ct_netblock_collection_hier_from_ancestor
		WHERE	OLD.netblock_collection_id = ANY (path)
		AND		OLD.child_netblock_collection_id = ANY (path)
		RETURNING *
		LOOP
			RAISE DEBUG '-> rm %', to_json(_r);
		END LOOP
		;
		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Deleting upstream references to netcoll %/% from cache == %',
			OLD.netblock_collection_id, OLD.child_netblock_collection_id, _cnt;
	END IF;

	--
	-- Insert any new rows to correspond with a new parent
	--


	--
	-- XXX - NEED TO START OVER SKETCH OUT EXACTLY WHAT NEEDS TO HAPPEN
	-- ON INSERT, UPDATE, DELETE IN ENGLISH, THEN WRITE.
	--

	--
	-- this worked for stuff added on top but I think I need to be more
	-- clever
	--
	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
		RAISE DEBUG '%%Insert: %', to_json(NEW);
		FOR _r IN
		WITH base_netblock AS (
			SELECT *, 'parent'::text as src
			FROM jazzhands_cache.ct_netblock_collection_hier_from_ancestor
			WHERE NEW.netblock_collection_id = ANY (path)
			AND array_length(path, 1) > 1
			AND netblock_collection_id = NEW.netblock_collection_id

		), base_child AS (
			-- deal with everything rooted at the child; this handles the case
			-- of something being inserted on top of the child
			SELECT *, 'child'::text as src
			FROM jazzhands_cache.ct_netblock_collection_hier_from_ancestor
			WHERE NEW.child_netblock_collection_id = ANY (path)
			AND root_netblock_collection_id != NEW.child_netblock_collection_id
			AND netblock_collection_id != NEW.child_netblock_collection_id
			AND array_length(path, 1) > 1

		), iparent AS (
			INSERT INTO jazzhands_cache.ct_netblock_collection_hier_from_ancestor (
				root_netblock_collection_id,
				intermediate_netblock_collection_id,
				netblock_collection_id,
				path,
				cycle
			)  SELECT
				base.root_netblock_collection_id,
				NEW.netblock_collection_id,
				NEW.child_netblock_collection_id,
				array_cat(
					array_cat(
						path[: (array_position(path, NEW.netblock_collection_id)-1)],
					ARRAY[NEW.child_netblock_collection_id, NEW.netblock_collection_id]
					),
					path[(array_position(path, NEW.netblock_collection_id)+1) :]
				),
				NEW.child_netblock_collection_id = ANY(base.path)
				FROM base_netblock AS base
				RETURNING *
		), ichild AS (
			INSERT INTO jazzhands_cache.ct_netblock_collection_hier_from_ancestor (
				root_netblock_collection_id,
				intermediate_netblock_collection_id,
				netblock_collection_id,
				path,
				cycle
			)  SELECT
				base.root_netblock_collection_id,
				base.intermediate_netblock_collection_id,
				base.netblock_collection_id,
				array_cat(
					array_cat(
						path[: (array_position(path, NEW.child_netblock_collection_id)-1)],
					ARRAY[NEW.child_netblock_collection_id, NEW.netblock_collection_id]
					),
					path[(array_position(path, NEW.child_netblock_collection_id)+1) :]
				),
				false -- hope... NEW.child_netblock_collection_id = ANY(base.path)
				FROM base_child AS base
				RETURNING *

		) SELECT 'c' AS q, * FROM ichild UNION SELECT 'p' AS q, * FROM iparent
		LOOP
			RAISE DEBUG 'i/down:%', to_json(_r);
			IF _r.cycle THEN
				RAISE EXCEPTION 'danger!  cycle!';
			END IF;
		END LOOP;

		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Inserting upstream references down for updated netcoll %/% into cache == %',
			NEW.netblock_collection_id, NEW.child_netblock_collection_id, _cnt;

		-- walk up and install rows for all the things above due to change
		FOR _r IN
		WITH RECURSIVE tier (
			root_netblock_collection_id,
			intermediate_netblock_collection_id,
			netblock_collection_id,
			path
		)AS (
			SELECT h.netblock_collection_id,
				h.netblock_collection_id,
				h.child_netblock_collection_Id,
				ARRAY[h.child_netblock_collection_id, h.netblock_collection_id],
				false as cycle
			FROM netblock_collection_hier  h
			WHERE h.netblock_collection_id = NEW.netblock_collection_id
			AND h.child_netblock_collection_id = NEW.child_netblock_collection_id
		UNION ALL
			SELECT tier.root_netblock_collection_id,
				n.netblock_collection_id,
				n.child_netblock_collection_id,
				array_prepend(n.child_netblock_collection_id, tier.path),
				n.child_netblock_collection_id = ANY(tier.path) as cycle
			FROM tier
				JOIN netblock_collection_hier n
					ON n.netblock_collection_id = tier.netblock_collection_id
			WHERE	NOT tier.cycle
		) INSERT INTO jazzhands_cache.ct_netblock_collection_hier_from_ancestor
				SELECT * FROM tier
		RETURNING *
		LOOP
			RAISE DEBUG 'i/up %', to_json(_r);
			IF _r.cycle THEN
				RAISE EXCEPTION 'danger!  cycle!';
			END IF;
		END LOOP;
		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Inserting upstream references up for updated netcol %/% into cache == %',
			NEW.netblock_collection_id, NEW.child_netblock_collection_id, _cnt;
	END IF;

	RETURN NULL;
END
$function$
;

--
-- Process drops in jazzhands
--
-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'check_device_colllection_hier_loop');
CREATE OR REPLACE FUNCTION jazzhands.check_device_colllection_hier_loop()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	IF NEW.device_collection_id = NEW.child_device_collection_id THEN
		RAISE EXCEPTION 'device Collection Loops Not Pernitted '
			USING ERRCODE = 20704;	/* XXX */
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_collection_hier_enforce');
CREATE OR REPLACE FUNCTION jazzhands.device_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	dct	val_device_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_device_collection_type
	WHERE	device_collection_type =
		(select device_collection_type from device_collection
			where device_collection_id = NEW.device_collection_id);

	IF dct.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Device Collections of type % may not be hierarcical',
			dct.device_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_record_enabled_check');
CREATE OR REPLACE FUNCTION jazzhands.dns_record_enabled_check()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	IF new.IS_ENABLED = 'N' THEN
		PERFORM *
		FROM dns_record
		WHERE dns_value_record_id = NEW.dns_record_id
		OR reference_dns_record_id = NEW.dns_record_id;

		IF FOUND THEN
			RAISE EXCEPTION 'Can not disabled records referred to by other enabled records.'
				USING ERRCODE = 'JH001';
		END IF;
	END IF;

	IF new.IS_ENABLED = 'Y' THEN
		PERFORM *
		FROM dns_record
		WHERE ( NEW.dns_value_record_id = dns_record_id
				OR NEW.reference_dns_record_id = dns_record_id
		) AND is_enabled = 'N';

		IF FOUND THEN
			RAISE EXCEPTION 'Can not enable records referencing disabled records.'
				USING ERRCODE = 'JH001';
		END IF;
	END IF;


	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'manip_device_collection_bytype');
CREATE OR REPLACE FUNCTION jazzhands.manip_device_collection_bytype()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	IF TG_OP = 'DELETE' OR
		( TG_OP = 'UPDATE' and OLD.device_collection_type = 'per-device')
	THEN
		DELETE FROM v_device_collection_hier_trans
		WHERE device_collection_id = OLD.device_collection_id
		AND parent_device_collection_id IN (
			SELECT device_collection_id
			FROM device_collection
			WHERE device_collection_type = 'by-coll-type'
			AND device_collection_name = OLD.device_collection_type
		);

		IF TG_OP = 'DELETE' THEN
			RETURN OLD;
		ELSE
			RETURN NEW;
		END IF;
	END IF;

	IF NEW.device_collection_type IN ('per-device','by-coll-type') THEN
		RETURN NEW;
	END IF;


	IF TG_OP = 'UPDATE' THEN
		UPDATE v_device_collection_hier_trans
		SET parent_device_collection_id = (
			SELECT device_collection_id
			FROM device_collection
			WHERE device_collection_type = 'by-coll-type'
			AND device_collection_name = NEW.device_collection_type
		),
			device_collection_id = NEW.device_collection_id
		WHERE parent_device_collection_id = (
			SELECT device_collection_id
			FROM device_collection
			WHERE device_collection_type = 'by-coll-type'
			AND device_collection_name = OLD.device_collection_type
		)
		AND device_collection_id = OLD.device_collection_id;
	ELSIF TG_OP = 'INSERT' THEN
		INSERT INTO v_device_collection_hier_trans (
			parent_device_collection_id, device_collection_id
		) SELECT device_collection_id, NEW.device_collection_id
			FROM device_collection
			WHERE device_collection_type = 'by-coll-type'
			AND device_collection_name = NEW.device_collection_type;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'manipulate_netblock_parentage_after');
CREATE OR REPLACE FUNCTION jazzhands.manipulate_netblock_parentage_after()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$

DECLARE
	nbtype				record;
	v_netblock_type		val_netblock_type.netblock_type%TYPE;
	v_row_count			integer;
	v_trigger			record;
	_tally				integer;
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

	RAISE DEBUG 'Setting parent for all child netblocks of parent netblock % that belong to % %',
		NEW.parent_netblock_id,
		NEW.netblock_id,
		NEW.ip_universe_Id;

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
		get diagnostics _tally = row_count;
		RAISE DEBUG '.... % affected', _tally;
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
		get diagnostics _tally = row_count;
		RAISE DEBUG '.... % affected', _tally;
		RETURN NULL;
	END IF;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_ip_universe_can_generate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_c	char(1);
BEGIN
	IF NEW.should_generate = 'Y' THEN
		SELECT CAN_GENERATE
		INTO _c
		FROM val_dns_domain_type
		JOIN dns_domain USING (dns_domain_type)
		WHERE dns_domain_id = NEW.dns_domain_id;

		IF _c != 'Y' THEN
			RAISE EXCEPTION 'This dns_domain_type may not be autogenerated.'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_type_should_generate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_c	INTEGER;
BEGIN
	IF NEW.can_generate = 'N' THEN
		SELECT count(*)
		INTO _c
		FROM dns_domain
		WHERE dns_domain_type = NEW.dns_domain_type
		AND should_generate = 'Y';

		IF _c != 'Y' THEN
			RAISE EXCEPTION 'May not change can_generate with existing autogenerated zones.'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

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
-- Process drops in layerx_network_manip
--
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
-- Process drops in rack_utils
--
--
-- Process drops in schema_support
--
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_table ( aud_schema character varying, tbl_schema character varying, table_name character varying );
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
		RAISE NOTICE 'table % has % rows; table % has % rows (%)', old_rel, _t1, new_rel, _t2, _t1 - _t2;
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

-- New function
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

-- New function
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_table_finish(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
$function$
;

--
-- Process drops in property_utils
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
-- Process post-schema jazzhands_legacy
--
-- Dropping obsoleted sequences....


-- Dropping obsoleted audit sequences....


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
-- index
-- triggers
DROP TRIGGER IF EXISTS aaa_account_collection_base_handler ON account_collection;
CREATE TRIGGER aaa_account_collection_base_handler AFTER INSERT OR DELETE OR UPDATE OF account_collection_id ON jazzhands.account_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.account_collection_base_handler();
DROP TRIGGER IF EXISTS aaa_account_collection_root_handler ON account_collection_hier;
CREATE TRIGGER aaa_account_collection_root_handler AFTER INSERT OR DELETE OR UPDATE OF account_collection_id, child_account_collection_id ON jazzhands.account_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.account_collection_root_handler();
DROP TRIGGER IF EXISTS aaa_device_collection_base_handler ON device_collection;
CREATE TRIGGER aaa_device_collection_base_handler AFTER INSERT OR DELETE OR UPDATE OF device_collection_id ON jazzhands.device_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.device_collection_base_handler();
DROP TRIGGER IF EXISTS trigger_cache_netblock_hier_truncate ON netblock;
CREATE TRIGGER trigger_cache_netblock_hier_truncate AFTER TRUNCATE ON jazzhands.netblock FOR EACH STATEMENT EXECUTE PROCEDURE jazzhands_cache.cache_netblock_hier_truncate_handler();
DROP TRIGGER IF EXISTS zaa_ta_cache_netblock_hier_handler ON netblock;
CREATE TRIGGER zaa_ta_cache_netblock_hier_handler AFTER INSERT OR DELETE OR UPDATE OF parent_netblock_id ON jazzhands.netblock FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.cache_netblock_hier_handler();
DROP TRIGGER IF EXISTS aaa_netblock_collection_base_handler ON netblock_collection;
CREATE TRIGGER aaa_netblock_collection_base_handler AFTER INSERT OR DELETE OR UPDATE OF netblock_collection_id ON jazzhands.netblock_collection FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.netblock_collection_base_handler();
DROP TRIGGER IF EXISTS aaa_netblock_collection_root_handler ON netblock_collection_hier;
CREATE TRIGGER aaa_netblock_collection_root_handler AFTER INSERT OR DELETE OR UPDATE OF netblock_collection_id, child_netblock_collection_id ON jazzhands.netblock_collection_hier FOR EACH ROW EXECUTE PROCEDURE jazzhands_cache.netblock_collection_root_handler();


-- Clean Up
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_saved_grants();


-- BEGIN Misc that does not apply to above
COMMENT ON SCHEMA jazzhands_legacy IS 'part of jazzhands';

-- aborted in favor of cache tables
DROP MATERIALIZED VIEW IF EXISTS jazzhands.mv_dev_col_root;


-- END Misc that does not apply to above
--
-- BEGIN: process_ancillary_schema(jazzhands_legacy)
--
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE account (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'account');
DROP VIEW IF EXISTS jazzhands_legacy.account;
CREATE VIEW jazzhands_legacy.account AS
 SELECT account.account_id,
    account.login,
    account.person_id,
    account.company_id,
    account.is_enabled,
    account.account_realm_id,
    account.account_status,
    account.account_role,
    account.account_type,
    account.description,
    account.external_id,
    account.data_ins_user,
    account.data_ins_date,
    account.data_upd_user,
    account.data_upd_date
   FROM jazzhands.account;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'account';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of account failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE account (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE account_assignd_cert (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'account_assignd_cert');
DROP VIEW IF EXISTS jazzhands_legacy.account_assignd_cert;
CREATE VIEW jazzhands_legacy.account_assignd_cert AS
 SELECT account_assignd_cert.account_id,
    account_assignd_cert.x509_cert_id,
    account_assignd_cert.x509_key_usg,
    account_assignd_cert.key_usage_reason_for_assign,
    account_assignd_cert.data_ins_user,
    account_assignd_cert.data_ins_date,
    account_assignd_cert.data_upd_user,
    account_assignd_cert.data_upd_date
   FROM jazzhands.account_assignd_cert;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'account_assignd_cert';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of account_assignd_cert failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE account_assignd_cert (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE account_auth_log (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'account_auth_log');
DROP VIEW IF EXISTS jazzhands_legacy.account_auth_log;
CREATE VIEW jazzhands_legacy.account_auth_log AS
 SELECT account_auth_log.account_id,
    account_auth_log.account_auth_ts,
    account_auth_log.auth_resource,
    account_auth_log.account_auth_seq,
    account_auth_log.was_auth_success,
    account_auth_log.auth_resource_instance,
    account_auth_log.auth_origin,
    account_auth_log.data_ins_date,
    account_auth_log.data_ins_user
   FROM jazzhands.account_auth_log;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'account_auth_log';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of account_auth_log failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE account_auth_log (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE account_coll_type_relation (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'account_coll_type_relation');
DROP VIEW IF EXISTS jazzhands_legacy.account_coll_type_relation;
CREATE VIEW jazzhands_legacy.account_coll_type_relation AS
 SELECT account_coll_type_relation.account_collection_relation,
    account_coll_type_relation.account_collection_type,
    account_coll_type_relation.max_num_members,
    account_coll_type_relation.max_num_collections,
    account_coll_type_relation.description,
    account_coll_type_relation.data_ins_user,
    account_coll_type_relation.data_ins_date,
    account_coll_type_relation.data_upd_user,
    account_coll_type_relation.data_upd_date
   FROM jazzhands.account_coll_type_relation;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'account_coll_type_relation';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of account_coll_type_relation failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE account_coll_type_relation (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE account_collection (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'account_collection');
DROP VIEW IF EXISTS jazzhands_legacy.account_collection;
CREATE VIEW jazzhands_legacy.account_collection AS
 SELECT account_collection.account_collection_id,
    account_collection.account_collection_name,
    account_collection.account_collection_type,
    account_collection.external_id,
    account_collection.description,
    account_collection.data_ins_user,
    account_collection.data_ins_date,
    account_collection.data_upd_user,
    account_collection.data_upd_date
   FROM jazzhands.account_collection;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'account_collection';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of account_collection failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE account_collection (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE account_collection_account (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'account_collection_account');
DROP VIEW IF EXISTS jazzhands_legacy.account_collection_account;
CREATE VIEW jazzhands_legacy.account_collection_account AS
 SELECT account_collection_account.account_collection_id,
    account_collection_account.account_id,
    account_collection_account.account_collection_relation,
    account_collection_account.account_id_rank,
    account_collection_account.start_date,
    account_collection_account.finish_date,
    account_collection_account.data_ins_user,
    account_collection_account.data_ins_date,
    account_collection_account.data_upd_user,
    account_collection_account.data_upd_date
   FROM jazzhands.account_collection_account;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'account_collection_account';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of account_collection_account failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.account_collection_account
	ALTER account_collection_relation
	SET DEFAULT 'direct'::character varying;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE account_collection_account (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE account_collection_hier (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'account_collection_hier');
DROP VIEW IF EXISTS jazzhands_legacy.account_collection_hier;
CREATE VIEW jazzhands_legacy.account_collection_hier AS
 SELECT account_collection_hier.account_collection_id,
    account_collection_hier.child_account_collection_id,
    account_collection_hier.data_ins_user,
    account_collection_hier.data_ins_date,
    account_collection_hier.data_upd_user,
    account_collection_hier.data_upd_date
   FROM jazzhands.account_collection_hier;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'account_collection_hier';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of account_collection_hier failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE account_collection_hier (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE account_password (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'account_password');
DROP VIEW IF EXISTS jazzhands_legacy.account_password;
CREATE VIEW jazzhands_legacy.account_password AS
 SELECT account_password.account_id,
    account_password.account_realm_id,
    account_password.password_type,
    account_password.password,
    account_password.change_time,
    account_password.expire_time,
    account_password.unlock_time,
    account_password.data_ins_user,
    account_password.data_ins_date,
    account_password.data_upd_user,
    account_password.data_upd_date
   FROM jazzhands.account_password;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'account_password';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of account_password failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE account_password (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE account_realm (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'account_realm');
DROP VIEW IF EXISTS jazzhands_legacy.account_realm;
CREATE VIEW jazzhands_legacy.account_realm AS
 SELECT account_realm.account_realm_id,
    account_realm.account_realm_name,
    account_realm.data_ins_user,
    account_realm.data_ins_date,
    account_realm.data_upd_user,
    account_realm.data_upd_date
   FROM jazzhands.account_realm;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'account_realm';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of account_realm failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE account_realm (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE account_realm_acct_coll_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'account_realm_acct_coll_type');
DROP VIEW IF EXISTS jazzhands_legacy.account_realm_acct_coll_type;
CREATE VIEW jazzhands_legacy.account_realm_acct_coll_type AS
 SELECT account_realm_acct_coll_type.account_realm_id,
    account_realm_acct_coll_type.account_collection_type,
    account_realm_acct_coll_type.data_ins_user,
    account_realm_acct_coll_type.data_ins_date,
    account_realm_acct_coll_type.data_upd_user,
    account_realm_acct_coll_type.data_upd_date
   FROM jazzhands.account_realm_acct_coll_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'account_realm_acct_coll_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of account_realm_acct_coll_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE account_realm_acct_coll_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE account_realm_company (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'account_realm_company');
DROP VIEW IF EXISTS jazzhands_legacy.account_realm_company;
CREATE VIEW jazzhands_legacy.account_realm_company AS
 SELECT account_realm_company.account_realm_id,
    account_realm_company.company_id,
    account_realm_company.data_ins_user,
    account_realm_company.data_ins_date,
    account_realm_company.data_upd_user,
    account_realm_company.data_upd_date
   FROM jazzhands.account_realm_company;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'account_realm_company';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of account_realm_company failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE account_realm_company (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE account_realm_password_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'account_realm_password_type');
DROP VIEW IF EXISTS jazzhands_legacy.account_realm_password_type;
CREATE VIEW jazzhands_legacy.account_realm_password_type AS
 SELECT account_realm_password_type.password_type,
    account_realm_password_type.account_realm_id,
    account_realm_password_type.description,
    account_realm_password_type.data_ins_user,
    account_realm_password_type.data_ins_date,
    account_realm_password_type.data_upd_user,
    account_realm_password_type.data_upd_date
   FROM jazzhands.account_realm_password_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'account_realm_password_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of account_realm_password_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE account_realm_password_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE account_ssh_key (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'account_ssh_key');
DROP VIEW IF EXISTS jazzhands_legacy.account_ssh_key;
CREATE VIEW jazzhands_legacy.account_ssh_key AS
 SELECT account_ssh_key.account_id,
    account_ssh_key.ssh_key_id,
    account_ssh_key.data_ins_user,
    account_ssh_key.data_ins_date,
    account_ssh_key.data_upd_user,
    account_ssh_key.data_upd_date
   FROM jazzhands.account_ssh_key;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'account_ssh_key';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of account_ssh_key failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE account_ssh_key (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE account_token (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'account_token');
DROP VIEW IF EXISTS jazzhands_legacy.account_token;
CREATE VIEW jazzhands_legacy.account_token AS
 SELECT account_token.account_token_id,
    account_token.account_id,
    account_token.token_id,
    account_token.issued_date,
    account_token.description,
    account_token.data_ins_user,
    account_token.data_ins_date,
    account_token.data_upd_user,
    account_token.data_upd_date
   FROM jazzhands.account_token;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'account_token';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of account_token failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE account_token (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE account_unix_info (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'account_unix_info');
DROP VIEW IF EXISTS jazzhands_legacy.account_unix_info;
CREATE VIEW jazzhands_legacy.account_unix_info AS
 SELECT account_unix_info.account_id,
    account_unix_info.unix_uid,
    account_unix_info.unix_group_acct_collection_id,
    account_unix_info.shell,
    account_unix_info.default_home,
    account_unix_info.data_ins_user,
    account_unix_info.data_ins_date,
    account_unix_info.data_upd_user,
    account_unix_info.data_upd_date
   FROM jazzhands.account_unix_info;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'account_unix_info';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of account_unix_info failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE account_unix_info (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE appaal (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'appaal');
DROP VIEW IF EXISTS jazzhands_legacy.appaal;
CREATE VIEW jazzhands_legacy.appaal AS
 SELECT appaal.appaal_id,
    appaal.appaal_name,
    appaal.description,
    appaal.data_ins_user,
    appaal.data_ins_date,
    appaal.data_upd_user,
    appaal.data_upd_date
   FROM jazzhands.appaal;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'appaal';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of appaal failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE appaal (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE appaal_instance (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'appaal_instance');
DROP VIEW IF EXISTS jazzhands_legacy.appaal_instance;
CREATE VIEW jazzhands_legacy.appaal_instance AS
 SELECT appaal_instance.appaal_instance_id,
    appaal_instance.appaal_id,
    appaal_instance.service_environment_id,
    appaal_instance.file_mode,
    appaal_instance.file_owner_account_id,
    appaal_instance.file_group_acct_collection_id,
    appaal_instance.data_ins_user,
    appaal_instance.data_ins_date,
    appaal_instance.data_upd_user,
    appaal_instance.data_upd_date
   FROM jazzhands.appaal_instance;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'appaal_instance';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of appaal_instance failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE appaal_instance (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE appaal_instance_device_coll (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'appaal_instance_device_coll');
DROP VIEW IF EXISTS jazzhands_legacy.appaal_instance_device_coll;
CREATE VIEW jazzhands_legacy.appaal_instance_device_coll AS
 SELECT appaal_instance_device_coll.device_collection_id,
    appaal_instance_device_coll.appaal_instance_id,
    appaal_instance_device_coll.data_ins_user,
    appaal_instance_device_coll.data_ins_date,
    appaal_instance_device_coll.data_upd_user,
    appaal_instance_device_coll.data_upd_date
   FROM jazzhands.appaal_instance_device_coll;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'appaal_instance_device_coll';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of appaal_instance_device_coll failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE appaal_instance_device_coll (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE appaal_instance_property (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'appaal_instance_property');
DROP VIEW IF EXISTS jazzhands_legacy.appaal_instance_property;
CREATE VIEW jazzhands_legacy.appaal_instance_property AS
 SELECT appaal_instance_property.appaal_instance_id,
    appaal_instance_property.app_key,
    appaal_instance_property.appaal_group_name,
    appaal_instance_property.appaal_group_rank,
    appaal_instance_property.app_value,
    appaal_instance_property.encryption_key_id,
    appaal_instance_property.data_ins_user,
    appaal_instance_property.data_ins_date,
    appaal_instance_property.data_upd_user,
    appaal_instance_property.data_upd_date
   FROM jazzhands.appaal_instance_property;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'appaal_instance_property';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of appaal_instance_property failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE appaal_instance_property (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE approval_instance (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'approval_instance');
DROP VIEW IF EXISTS jazzhands_legacy.approval_instance;
CREATE VIEW jazzhands_legacy.approval_instance AS
 SELECT approval_instance.approval_instance_id,
    approval_instance.approval_process_id,
    approval_instance.approval_instance_name,
    approval_instance.description,
    approval_instance.approval_start,
    approval_instance.approval_end,
    approval_instance.data_ins_user,
    approval_instance.data_ins_date,
    approval_instance.data_upd_user,
    approval_instance.data_upd_date
   FROM jazzhands.approval_instance;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'approval_instance';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of approval_instance failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.approval_instance
	ALTER approval_start
	SET DEFAULT now();

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE approval_instance (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE approval_instance_item (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'approval_instance_item');
DROP VIEW IF EXISTS jazzhands_legacy.approval_instance_item;
CREATE VIEW jazzhands_legacy.approval_instance_item AS
 SELECT approval_instance_item.approval_instance_item_id,
    approval_instance_item.approval_instance_link_id,
    approval_instance_item.approval_instance_step_id,
    approval_instance_item.next_approval_instance_item_id,
    approval_instance_item.approved_category,
    approval_instance_item.approved_label,
    approval_instance_item.approved_lhs,
    approval_instance_item.approved_rhs,
    approval_instance_item.is_approved,
    approval_instance_item.approved_account_id,
    approval_instance_item.approval_note,
    approval_instance_item.data_ins_user,
    approval_instance_item.data_ins_date,
    approval_instance_item.data_upd_user,
    approval_instance_item.data_upd_date
   FROM jazzhands.approval_instance_item;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'approval_instance_item';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of approval_instance_item failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE approval_instance_item (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE approval_instance_link (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'approval_instance_link');
DROP VIEW IF EXISTS jazzhands_legacy.approval_instance_link;
CREATE VIEW jazzhands_legacy.approval_instance_link AS
 SELECT approval_instance_link.approval_instance_link_id,
    approval_instance_link.acct_collection_acct_seq_id,
    approval_instance_link.person_company_seq_id,
    approval_instance_link.property_seq_id,
    approval_instance_link.data_ins_user,
    approval_instance_link.data_ins_date,
    approval_instance_link.data_upd_user,
    approval_instance_link.data_upd_date
   FROM jazzhands.approval_instance_link;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'approval_instance_link';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of approval_instance_link failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE approval_instance_link (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE approval_instance_step (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'approval_instance_step');
DROP VIEW IF EXISTS jazzhands_legacy.approval_instance_step;
CREATE VIEW jazzhands_legacy.approval_instance_step AS
 SELECT approval_instance_step.approval_instance_step_id,
    approval_instance_step.approval_instance_id,
    approval_instance_step.approval_process_chain_id,
    approval_instance_step.approval_instance_step_name,
    approval_instance_step.approval_instance_step_due,
    approval_instance_step.approval_type,
    approval_instance_step.description,
    approval_instance_step.approval_instance_step_start,
    approval_instance_step.approval_instance_step_end,
    approval_instance_step.approver_account_id,
    approval_instance_step.external_reference_name,
    approval_instance_step.is_completed,
    approval_instance_step.data_ins_user,
    approval_instance_step.data_ins_date,
    approval_instance_step.data_upd_user,
    approval_instance_step.data_upd_date
   FROM jazzhands.approval_instance_step;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'approval_instance_step';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of approval_instance_step failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.approval_instance_step
	ALTER approval_instance_step_start
	SET DEFAULT now();
ALTER TABLE jazzhands_legacy.approval_instance_step
	ALTER is_completed
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE approval_instance_step (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE approval_instance_step_notify (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'approval_instance_step_notify');
DROP VIEW IF EXISTS jazzhands_legacy.approval_instance_step_notify;
CREATE VIEW jazzhands_legacy.approval_instance_step_notify AS
 SELECT approval_instance_step_notify.approv_instance_step_notify_id,
    approval_instance_step_notify.approval_instance_step_id,
    approval_instance_step_notify.approval_notify_type,
    approval_instance_step_notify.account_id,
    approval_instance_step_notify.approval_notify_whence,
    approval_instance_step_notify.data_ins_user,
    approval_instance_step_notify.data_ins_date,
    approval_instance_step_notify.data_upd_user,
    approval_instance_step_notify.data_upd_date
   FROM jazzhands.approval_instance_step_notify;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'approval_instance_step_notify';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of approval_instance_step_notify failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE approval_instance_step_notify (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE approval_process (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'approval_process');
DROP VIEW IF EXISTS jazzhands_legacy.approval_process;
CREATE VIEW jazzhands_legacy.approval_process AS
 SELECT approval_process.approval_process_id,
    approval_process.approval_process_name,
    approval_process.approval_process_type,
    approval_process.description,
    approval_process.first_apprvl_process_chain_id,
    approval_process.property_collection_id,
    approval_process.approval_expiration_action,
    approval_process.attestation_frequency,
    approval_process.attestation_offset,
    approval_process.max_escalation_level,
    approval_process.escalation_delay,
    approval_process.escalation_reminder_gap,
    approval_process.data_ins_user,
    approval_process.data_ins_date,
    approval_process.data_upd_user,
    approval_process.data_upd_date
   FROM jazzhands.approval_process;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'approval_process';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of approval_process failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE approval_process (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE approval_process_chain (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'approval_process_chain');
DROP VIEW IF EXISTS jazzhands_legacy.approval_process_chain;
CREATE VIEW jazzhands_legacy.approval_process_chain AS
 SELECT approval_process_chain.approval_process_chain_id,
    approval_process_chain.approval_process_chain_name,
    approval_process_chain.approval_chain_response_period,
    approval_process_chain.description,
    approval_process_chain.message,
    approval_process_chain.email_message,
    approval_process_chain.email_subject_prefix,
    approval_process_chain.email_subject_suffix,
    approval_process_chain.max_escalation_level,
    approval_process_chain.escalation_delay,
    approval_process_chain.escalation_reminder_gap,
    approval_process_chain.approving_entity,
    approval_process_chain.refresh_all_data,
    approval_process_chain.accept_app_process_chain_id,
    approval_process_chain.reject_app_process_chain_id,
    approval_process_chain.data_ins_user,
    approval_process_chain.data_ins_date,
    approval_process_chain.data_upd_user,
    approval_process_chain.data_upd_date
   FROM jazzhands.approval_process_chain;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'approval_process_chain';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of approval_process_chain failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.approval_process_chain
	ALTER approval_chain_response_period
	SET DEFAULT '1 week'::character varying;
ALTER TABLE jazzhands_legacy.approval_process_chain
	ALTER refresh_all_data
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE approval_process_chain (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE asset (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'asset');
DROP VIEW IF EXISTS jazzhands_legacy.asset;
CREATE VIEW jazzhands_legacy.asset AS
 SELECT asset.asset_id,
    asset.component_id,
    asset.description,
    asset.contract_id,
    asset.serial_number,
    asset.part_number,
    asset.asset_tag,
    asset.ownership_status,
    asset.lease_expiration_date,
    asset.data_ins_user,
    asset.data_ins_date,
    asset.data_upd_user,
    asset.data_upd_date
   FROM jazzhands.asset;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'asset';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of asset failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE asset (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE badge (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'badge');
DROP VIEW IF EXISTS jazzhands_legacy.badge;
CREATE VIEW jazzhands_legacy.badge AS
 SELECT badge.card_number,
    badge.badge_type_id,
    badge.badge_status,
    badge.date_assigned,
    badge.date_reclaimed,
    badge.data_ins_user,
    badge.data_ins_date,
    badge.data_upd_user,
    badge.data_upd_date
   FROM jazzhands.badge;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'badge';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of badge failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE badge (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE badge_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'badge_type');
DROP VIEW IF EXISTS jazzhands_legacy.badge_type;
CREATE VIEW jazzhands_legacy.badge_type AS
 SELECT badge_type.badge_type_id,
    badge_type.badge_type_name,
    badge_type.description,
    badge_type.badge_color,
    badge_type.badge_template_name,
    badge_type.data_ins_user,
    badge_type.data_ins_date,
    badge_type.data_upd_user,
    badge_type.data_upd_date
   FROM jazzhands.badge_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'badge_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of badge_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE badge_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE certificate_signing_request (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'certificate_signing_request');
DROP VIEW IF EXISTS jazzhands_legacy.certificate_signing_request;
CREATE VIEW jazzhands_legacy.certificate_signing_request AS
 SELECT certificate_signing_request.certificate_signing_request_id,
    certificate_signing_request.friendly_name,
    certificate_signing_request.subject,
    certificate_signing_request.certificate_signing_request,
    certificate_signing_request.private_key_id,
    certificate_signing_request.data_ins_user,
    certificate_signing_request.data_ins_date,
    certificate_signing_request.data_upd_user,
    certificate_signing_request.data_upd_date
   FROM jazzhands.certificate_signing_request;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'certificate_signing_request';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of certificate_signing_request failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE certificate_signing_request (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE chassis_location (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'chassis_location');
DROP VIEW IF EXISTS jazzhands_legacy.chassis_location;
CREATE VIEW jazzhands_legacy.chassis_location AS
 SELECT chassis_location.chassis_location_id,
    chassis_location.chassis_device_type_id,
    chassis_location.device_type_module_name,
    chassis_location.chassis_device_id,
    chassis_location.module_device_type_id,
    chassis_location.data_ins_user,
    chassis_location.data_ins_date,
    chassis_location.data_upd_user,
    chassis_location.data_upd_date
   FROM jazzhands.chassis_location;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'chassis_location';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of chassis_location failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE chassis_location (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE circuit (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'circuit');
DROP VIEW IF EXISTS jazzhands_legacy.circuit;
CREATE VIEW jazzhands_legacy.circuit AS
 SELECT circuit.circuit_id,
    circuit.vendor_company_id,
    circuit.vendor_circuit_id_str,
    circuit.aloc_lec_company_id,
    circuit.aloc_lec_circuit_id_str,
    circuit.aloc_parent_circuit_id,
    circuit.zloc_lec_company_id,
    circuit.zloc_lec_circuit_id_str,
    circuit.zloc_parent_circuit_id,
    circuit.is_locally_managed,
    circuit.data_ins_user,
    circuit.data_ins_date,
    circuit.data_upd_user,
    circuit.data_upd_date
   FROM jazzhands.circuit;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'circuit';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of circuit failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE circuit (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE company (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'company');
DROP VIEW IF EXISTS jazzhands_legacy.company;
CREATE VIEW jazzhands_legacy.company AS
 SELECT company.company_id,
    company.company_name,
    company.company_short_name,
    company.parent_company_id,
    company.description,
    company.external_id,
    company.data_ins_user,
    company.data_ins_date,
    company.data_upd_user,
    company.data_upd_date
   FROM jazzhands.company;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'company';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of company failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE company (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE company_collection (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'company_collection');
DROP VIEW IF EXISTS jazzhands_legacy.company_collection;
CREATE VIEW jazzhands_legacy.company_collection AS
 SELECT company_collection.company_collection_id,
    company_collection.company_collection_name,
    company_collection.company_collection_type,
    company_collection.description,
    company_collection.external_id,
    company_collection.data_ins_user,
    company_collection.data_ins_date,
    company_collection.data_upd_user,
    company_collection.data_upd_date
   FROM jazzhands.company_collection;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'company_collection';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of company_collection failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE company_collection (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE company_collection_company (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'company_collection_company');
DROP VIEW IF EXISTS jazzhands_legacy.company_collection_company;
CREATE VIEW jazzhands_legacy.company_collection_company AS
 SELECT company_collection_company.company_collection_id,
    company_collection_company.company_id,
    company_collection_company.data_ins_user,
    company_collection_company.data_ins_date,
    company_collection_company.data_upd_user,
    company_collection_company.data_upd_date
   FROM jazzhands.company_collection_company;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'company_collection_company';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of company_collection_company failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE company_collection_company (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE company_collection_hier (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'company_collection_hier');
DROP VIEW IF EXISTS jazzhands_legacy.company_collection_hier;
CREATE VIEW jazzhands_legacy.company_collection_hier AS
 SELECT company_collection_hier.company_collection_id,
    company_collection_hier.child_company_collection_id,
    company_collection_hier.data_ins_user,
    company_collection_hier.data_ins_date,
    company_collection_hier.data_upd_user,
    company_collection_hier.data_upd_date
   FROM jazzhands.company_collection_hier;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'company_collection_hier';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of company_collection_hier failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE company_collection_hier (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE company_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'company_type');
DROP VIEW IF EXISTS jazzhands_legacy.company_type;
CREATE VIEW jazzhands_legacy.company_type AS
 SELECT company_type.company_id,
    company_type.company_type,
    company_type.description,
    company_type.data_ins_user,
    company_type.data_ins_date,
    company_type.data_upd_user,
    company_type.data_upd_date
   FROM jazzhands.company_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'company_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of company_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE company_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE component (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'component');
DROP VIEW IF EXISTS jazzhands_legacy.component;
CREATE VIEW jazzhands_legacy.component AS
 SELECT component.component_id,
    component.component_type_id,
    component.component_name,
    component.rack_location_id,
    component.parent_slot_id,
    component.data_ins_user,
    component.data_ins_date,
    component.data_upd_user,
    component.data_upd_date
   FROM jazzhands.component;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'component';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of component failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE component (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE component_property (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'component_property');
DROP VIEW IF EXISTS jazzhands_legacy.component_property;
CREATE VIEW jazzhands_legacy.component_property AS
 SELECT component_property.component_property_id,
    component_property.component_function,
    component_property.component_type_id,
    component_property.component_id,
    component_property.inter_component_connection_id,
    component_property.slot_function,
    component_property.slot_type_id,
    component_property.slot_id,
    component_property.component_property_name,
    component_property.component_property_type,
    component_property.property_value,
    component_property.data_ins_user,
    component_property.data_ins_date,
    component_property.data_upd_user,
    component_property.data_upd_date
   FROM jazzhands.component_property;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'component_property';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of component_property failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE component_property (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE component_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'component_type');
DROP VIEW IF EXISTS jazzhands_legacy.component_type;
CREATE VIEW jazzhands_legacy.component_type AS
 SELECT component_type.component_type_id,
    component_type.company_id,
    component_type.model,
    component_type.slot_type_id,
    component_type.description,
    component_type.part_number,
    component_type.is_removable,
    component_type.asset_permitted,
    component_type.is_rack_mountable,
    component_type.is_virtual_component,
    component_type.size_units,
    component_type.data_ins_user,
    component_type.data_ins_date,
    component_type.data_upd_user,
    component_type.data_upd_date
   FROM jazzhands.component_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'component_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of component_type failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.component_type
	ALTER is_removable
	SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.component_type
	ALTER asset_permitted
	SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.component_type
	ALTER is_rack_mountable
	SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.component_type
	ALTER is_virtual_component
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE component_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE component_type_component_func (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'component_type_component_func');
DROP VIEW IF EXISTS jazzhands_legacy.component_type_component_func;
CREATE VIEW jazzhands_legacy.component_type_component_func AS
 SELECT component_type_component_func.component_function,
    component_type_component_func.component_type_id,
    component_type_component_func.data_ins_user,
    component_type_component_func.data_ins_date,
    component_type_component_func.data_upd_user,
    component_type_component_func.data_upd_date
   FROM jazzhands.component_type_component_func;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'component_type_component_func';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of component_type_component_func failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE component_type_component_func (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE component_type_slot_tmplt (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'component_type_slot_tmplt');
DROP VIEW IF EXISTS jazzhands_legacy.component_type_slot_tmplt;
CREATE VIEW jazzhands_legacy.component_type_slot_tmplt AS
 SELECT component_type_slot_tmplt.component_type_slot_tmplt_id,
    component_type_slot_tmplt.component_type_id,
    component_type_slot_tmplt.slot_type_id,
    component_type_slot_tmplt.slot_name_template,
    component_type_slot_tmplt.child_slot_name_template,
    component_type_slot_tmplt.child_slot_offset,
    component_type_slot_tmplt.slot_index,
    component_type_slot_tmplt.physical_label,
    component_type_slot_tmplt.slot_x_offset,
    component_type_slot_tmplt.slot_y_offset,
    component_type_slot_tmplt.slot_z_offset,
    component_type_slot_tmplt.slot_side,
    component_type_slot_tmplt.data_ins_user,
    component_type_slot_tmplt.data_ins_date,
    component_type_slot_tmplt.data_upd_user,
    component_type_slot_tmplt.data_upd_date
   FROM jazzhands.component_type_slot_tmplt;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'component_type_slot_tmplt';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of component_type_slot_tmplt failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.component_type_slot_tmplt
	ALTER slot_side
	SET DEFAULT 'FRONT'::character varying;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE component_type_slot_tmplt (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE contract (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'contract');
DROP VIEW IF EXISTS jazzhands_legacy.contract;
CREATE VIEW jazzhands_legacy.contract AS
 SELECT contract.contract_id,
    contract.company_id,
    contract.contract_name,
    contract.vendor_contract_name,
    contract.description,
    contract.contract_termination_date,
    contract.data_ins_user,
    contract.data_ins_date,
    contract.data_upd_user,
    contract.data_upd_date
   FROM jazzhands.contract;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'contract';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of contract failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE contract (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE contract_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'contract_type');
DROP VIEW IF EXISTS jazzhands_legacy.contract_type;
CREATE VIEW jazzhands_legacy.contract_type AS
 SELECT contract_type.contract_id,
    contract_type.contract_type,
    contract_type.data_ins_user,
    contract_type.data_ins_date,
    contract_type.data_upd_user,
    contract_type.data_upd_date
   FROM jazzhands.contract_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'contract_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of contract_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE contract_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE department (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'department');
DROP VIEW IF EXISTS jazzhands_legacy.department;
CREATE VIEW jazzhands_legacy.department AS
 SELECT department.account_collection_id,
    department.company_id,
    department.manager_account_id,
    department.is_active,
    department.dept_code,
    department.cost_center_name,
    department.cost_center_number,
    department.default_badge_type_id,
    department.data_ins_user,
    department.data_ins_date,
    department.data_upd_user,
    department.data_upd_date
   FROM jazzhands.department;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'department';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of department failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.department
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE department (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'device');
DROP VIEW IF EXISTS jazzhands_legacy.device;
CREATE VIEW jazzhands_legacy.device AS
 SELECT device.device_id,
    device.component_id,
    device.device_type_id,
    device.device_name,
    device.site_code,
    device.identifying_dns_record_id,
    device.host_id,
    device.physical_label,
    device.rack_location_id,
    device.chassis_location_id,
    device.parent_device_id,
    device.description,
    device.external_id,
    device.device_status,
    device.operating_system_id,
    device.service_environment_id,
    device.auto_mgmt_protocol,
    device.is_locally_managed,
    device.is_monitored,
    device.is_virtual_device,
    device.should_fetch_config,
    device.date_in_service,
    device.data_ins_user,
    device.data_ins_date,
    device.data_upd_user,
    device.data_upd_date
   FROM jazzhands.device;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'device';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of device failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.device
	ALTER is_locally_managed
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE jazzhands_legacy.device
	ALTER is_virtual_device
	SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.device
	ALTER should_fetch_config
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE device (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device_collection (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'device_collection');
DROP VIEW IF EXISTS jazzhands_legacy.device_collection;
CREATE VIEW jazzhands_legacy.device_collection AS
 SELECT device_collection.device_collection_id,
    device_collection.device_collection_name,
    device_collection.device_collection_type,
    device_collection.description,
    device_collection.external_id,
    device_collection.data_ins_user,
    device_collection.data_ins_date,
    device_collection.data_upd_user,
    device_collection.data_upd_date
   FROM jazzhands.device_collection;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'device_collection';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of device_collection failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE device_collection (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device_collection_assignd_cert (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'device_collection_assignd_cert');
DROP VIEW IF EXISTS jazzhands_legacy.device_collection_assignd_cert;
CREATE VIEW jazzhands_legacy.device_collection_assignd_cert AS
 SELECT device_collection_assignd_cert.device_collection_id,
    device_collection_assignd_cert.x509_cert_id,
    device_collection_assignd_cert.x509_key_usg,
    device_collection_assignd_cert.x509_file_format,
    device_collection_assignd_cert.file_location_path,
    device_collection_assignd_cert.key_tool_label,
    device_collection_assignd_cert.file_access_mode,
    device_collection_assignd_cert.file_owner_account_id,
    device_collection_assignd_cert.file_group_acct_collection_id,
    device_collection_assignd_cert.file_passphrase_path,
    device_collection_assignd_cert.key_usage_reason_for_assign,
    device_collection_assignd_cert.data_ins_user,
    device_collection_assignd_cert.data_ins_date,
    device_collection_assignd_cert.data_upd_user,
    device_collection_assignd_cert.data_upd_date
   FROM jazzhands.device_collection_assignd_cert;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'device_collection_assignd_cert';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of device_collection_assignd_cert failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE device_collection_assignd_cert (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device_collection_device (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'device_collection_device');
DROP VIEW IF EXISTS jazzhands_legacy.device_collection_device;
CREATE VIEW jazzhands_legacy.device_collection_device AS
 SELECT device_collection_device.device_id,
    device_collection_device.device_collection_id,
    device_collection_device.device_id_rank,
    device_collection_device.data_ins_user,
    device_collection_device.data_ins_date,
    device_collection_device.data_upd_user,
    device_collection_device.data_upd_date
   FROM jazzhands.device_collection_device;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'device_collection_device';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of device_collection_device failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE device_collection_device (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device_collection_hier (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'device_collection_hier');
DROP VIEW IF EXISTS jazzhands_legacy.device_collection_hier;
CREATE VIEW jazzhands_legacy.device_collection_hier AS
 SELECT device_collection_hier.device_collection_id,
    device_collection_hier.child_device_collection_id,
    device_collection_hier.data_ins_user,
    device_collection_hier.data_ins_date,
    device_collection_hier.data_upd_user,
    device_collection_hier.data_upd_date
   FROM jazzhands.device_collection_hier;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'device_collection_hier';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of device_collection_hier failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE device_collection_hier (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device_collection_ssh_key (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'device_collection_ssh_key');
DROP VIEW IF EXISTS jazzhands_legacy.device_collection_ssh_key;
CREATE VIEW jazzhands_legacy.device_collection_ssh_key AS
 SELECT device_collection_ssh_key.ssh_key_id,
    device_collection_ssh_key.device_collection_id,
    device_collection_ssh_key.account_collection_id,
    device_collection_ssh_key.description,
    device_collection_ssh_key.data_ins_user,
    device_collection_ssh_key.data_ins_date,
    device_collection_ssh_key.data_upd_user,
    device_collection_ssh_key.data_upd_date
   FROM jazzhands.device_collection_ssh_key;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'device_collection_ssh_key';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of device_collection_ssh_key failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE device_collection_ssh_key (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device_encapsulation_domain (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'device_encapsulation_domain');
DROP VIEW IF EXISTS jazzhands_legacy.device_encapsulation_domain;
CREATE VIEW jazzhands_legacy.device_encapsulation_domain AS
 SELECT device_encapsulation_domain.device_id,
    device_encapsulation_domain.encapsulation_type,
    device_encapsulation_domain.encapsulation_domain,
    device_encapsulation_domain.data_ins_user,
    device_encapsulation_domain.data_ins_date,
    device_encapsulation_domain.data_upd_user,
    device_encapsulation_domain.data_upd_date
   FROM jazzhands.device_encapsulation_domain;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'device_encapsulation_domain';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of device_encapsulation_domain failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE device_encapsulation_domain (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device_layer2_network (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'device_layer2_network');
DROP VIEW IF EXISTS jazzhands_legacy.device_layer2_network;
CREATE VIEW jazzhands_legacy.device_layer2_network AS
 SELECT device_layer2_network.device_id,
    device_layer2_network.layer2_network_id,
    device_layer2_network.data_ins_user,
    device_layer2_network.data_ins_date,
    device_layer2_network.data_upd_user,
    device_layer2_network.data_upd_date
   FROM jazzhands.device_layer2_network;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'device_layer2_network';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of device_layer2_network failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE device_layer2_network (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device_management_controller (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'device_management_controller');
DROP VIEW IF EXISTS jazzhands_legacy.device_management_controller;
CREATE VIEW jazzhands_legacy.device_management_controller AS
 SELECT device_management_controller.manager_device_id,
    device_management_controller.device_id,
    device_management_controller.device_mgmt_control_type,
    device_management_controller.description,
    device_management_controller.data_ins_user,
    device_management_controller.data_ins_date,
    device_management_controller.data_upd_user,
    device_management_controller.data_upd_date
   FROM jazzhands.device_management_controller;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'device_management_controller';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of device_management_controller failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE device_management_controller (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device_note (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'device_note');
DROP VIEW IF EXISTS jazzhands_legacy.device_note;
CREATE VIEW jazzhands_legacy.device_note AS
 SELECT device_note.note_id,
    device_note.device_id,
    device_note.note_text,
    device_note.note_date,
    device_note.note_user,
    device_note.data_ins_user,
    device_note.data_ins_date,
    device_note.data_upd_user,
    device_note.data_upd_date
   FROM jazzhands.device_note;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'device_note';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of device_note failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE device_note (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device_power_connection (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'device_power_connection');
DROP VIEW IF EXISTS jazzhands_legacy.device_power_connection;
CREATE VIEW jazzhands_legacy.device_power_connection AS
 SELECT device_power_connection.device_power_connection_id,
    device_power_connection.inter_component_connection_id,
    device_power_connection.rpc_device_id,
    device_power_connection.rpc_power_interface_port,
    device_power_connection.power_interface_port,
    device_power_connection.device_id,
    device_power_connection.data_ins_user,
    device_power_connection.data_ins_date,
    device_power_connection.data_upd_user,
    device_power_connection.data_upd_date
   FROM jazzhands.device_power_connection;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'device_power_connection';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of device_power_connection failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE device_power_connection (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device_power_interface (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'device_power_interface');
DROP VIEW IF EXISTS jazzhands_legacy.device_power_interface;
CREATE VIEW jazzhands_legacy.device_power_interface AS
 SELECT device_power_interface.device_id,
    device_power_interface.power_interface_port,
    device_power_interface.power_plug_style,
    device_power_interface.voltage,
    device_power_interface.max_amperage,
    device_power_interface.provides_power,
    device_power_interface.data_ins_user,
    device_power_interface.data_ins_date,
    device_power_interface.data_upd_user,
    device_power_interface.data_upd_date
   FROM jazzhands.device_power_interface;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'device_power_interface';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of device_power_interface failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE device_power_interface (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device_ssh_key (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'device_ssh_key');
DROP VIEW IF EXISTS jazzhands_legacy.device_ssh_key;
CREATE VIEW jazzhands_legacy.device_ssh_key AS
 SELECT device_ssh_key.device_id,
    device_ssh_key.ssh_key_id,
    device_ssh_key.data_ins_user,
    device_ssh_key.data_ins_date,
    device_ssh_key.data_upd_user,
    device_ssh_key.data_upd_date
   FROM jazzhands.device_ssh_key;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'device_ssh_key';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of device_ssh_key failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE device_ssh_key (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device_ticket (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'device_ticket');
DROP VIEW IF EXISTS jazzhands_legacy.device_ticket;
CREATE VIEW jazzhands_legacy.device_ticket AS
 SELECT device_ticket.device_id,
    device_ticket.ticketing_system_id,
    device_ticket.ticket_number,
    device_ticket.device_ticket_notes,
    device_ticket.data_ins_user,
    device_ticket.data_ins_date,
    device_ticket.data_upd_user,
    device_ticket.data_upd_date
   FROM jazzhands.device_ticket;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'device_ticket';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of device_ticket failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE device_ticket (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'device_type');
DROP VIEW IF EXISTS jazzhands_legacy.device_type;
CREATE VIEW jazzhands_legacy.device_type AS
 SELECT device_type.device_type_id,
    device_type.component_type_id,
    device_type.device_type_name,
    device_type.template_device_id,
    device_type.idealized_device_id,
    device_type.description,
    device_type.company_id,
    device_type.model,
    device_type.device_type_depth_in_cm,
    device_type.processor_architecture,
    device_type.config_fetch_type,
    device_type.rack_units,
    device_type.has_802_3_interface,
    device_type.has_802_11_interface,
    device_type.snmp_capable,
    device_type.is_chassis,
    device_type.data_ins_user,
    device_type.data_ins_date,
    device_type.data_upd_user,
    device_type.data_upd_date
   FROM jazzhands.device_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'device_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of device_type failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.device_type
	ALTER has_802_3_interface
	SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.device_type
	ALTER has_802_11_interface
	SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.device_type
	ALTER snmp_capable
	SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.device_type
	ALTER is_chassis
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE device_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device_type_module (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'device_type_module');
DROP VIEW IF EXISTS jazzhands_legacy.device_type_module;
CREATE VIEW jazzhands_legacy.device_type_module AS
 SELECT device_type_module.device_type_id,
    device_type_module.device_type_module_name,
    device_type_module.description,
    device_type_module.device_type_x_offset,
    device_type_module.device_type_y_offset,
    device_type_module.device_type_z_offset,
    device_type_module.device_type_side,
    device_type_module.data_ins_user,
    device_type_module.data_ins_date,
    device_type_module.data_upd_user,
    device_type_module.data_upd_date
   FROM jazzhands.device_type_module;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'device_type_module';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of device_type_module failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.device_type_module
	ALTER device_type_side
	SET DEFAULT 'FRONT'::character varying;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE device_type_module (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device_type_module_device_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'device_type_module_device_type');
DROP VIEW IF EXISTS jazzhands_legacy.device_type_module_device_type;
CREATE VIEW jazzhands_legacy.device_type_module_device_type AS
 SELECT device_type_module_device_type.module_device_type_id,
    device_type_module_device_type.device_type_id,
    device_type_module_device_type.device_type_module_name,
    device_type_module_device_type.description,
    device_type_module_device_type.data_ins_user,
    device_type_module_device_type.data_ins_date,
    device_type_module_device_type.data_upd_user,
    device_type_module_device_type.data_upd_date
   FROM jazzhands.device_type_module_device_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'device_type_module_device_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of device_type_module_device_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE device_type_module_device_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE dns_change_record (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'dns_change_record');
DROP VIEW IF EXISTS jazzhands_legacy.dns_change_record;
CREATE VIEW jazzhands_legacy.dns_change_record AS
 SELECT dns_change_record.dns_change_record_id,
    dns_change_record.dns_domain_id,
    dns_change_record.ip_universe_id,
    dns_change_record.ip_address,
    dns_change_record.data_ins_user,
    dns_change_record.data_ins_date,
    dns_change_record.data_upd_user,
    dns_change_record.data_upd_date
   FROM jazzhands.dns_change_record;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'dns_change_record';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of dns_change_record failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE dns_change_record (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE dns_domain (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'dns_domain');
DROP VIEW IF EXISTS jazzhands_legacy.dns_domain;
CREATE VIEW jazzhands_legacy.dns_domain AS
 SELECT dns_domain.dns_domain_id,
    dns_domain.soa_name,
    dns_domain.dns_domain_name,
    dns_domain.dns_domain_type,
    dns_domain.parent_dns_domain_id,
    dns_domain.description,
    dns_domain.external_id,
    dns_domain.data_ins_user,
    dns_domain.data_ins_date,
    dns_domain.data_upd_user,
    dns_domain.data_upd_date
   FROM jazzhands.dns_domain;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'dns_domain';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of dns_domain failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE dns_domain (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE dns_domain_collection (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'dns_domain_collection');
DROP VIEW IF EXISTS jazzhands_legacy.dns_domain_collection;
CREATE VIEW jazzhands_legacy.dns_domain_collection AS
 SELECT dns_domain_collection.dns_domain_collection_id,
    dns_domain_collection.dns_domain_collection_name,
    dns_domain_collection.dns_domain_collection_type,
    dns_domain_collection.description,
    dns_domain_collection.external_id,
    dns_domain_collection.data_ins_user,
    dns_domain_collection.data_ins_date,
    dns_domain_collection.data_upd_user,
    dns_domain_collection.data_upd_date
   FROM jazzhands.dns_domain_collection;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'dns_domain_collection';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of dns_domain_collection failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE dns_domain_collection (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE dns_domain_collection_dns_dom (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'dns_domain_collection_dns_dom');
DROP VIEW IF EXISTS jazzhands_legacy.dns_domain_collection_dns_dom;
CREATE VIEW jazzhands_legacy.dns_domain_collection_dns_dom AS
 SELECT dns_domain_collection_dns_dom.dns_domain_collection_id,
    dns_domain_collection_dns_dom.dns_domain_id,
    dns_domain_collection_dns_dom.data_ins_user,
    dns_domain_collection_dns_dom.data_ins_date,
    dns_domain_collection_dns_dom.data_upd_user,
    dns_domain_collection_dns_dom.data_upd_date
   FROM jazzhands.dns_domain_collection_dns_dom;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'dns_domain_collection_dns_dom';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of dns_domain_collection_dns_dom failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE dns_domain_collection_dns_dom (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE dns_domain_collection_hier (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'dns_domain_collection_hier');
DROP VIEW IF EXISTS jazzhands_legacy.dns_domain_collection_hier;
CREATE VIEW jazzhands_legacy.dns_domain_collection_hier AS
 SELECT dns_domain_collection_hier.dns_domain_collection_id,
    dns_domain_collection_hier.child_dns_domain_collection_id,
    dns_domain_collection_hier.data_ins_user,
    dns_domain_collection_hier.data_ins_date,
    dns_domain_collection_hier.data_upd_user,
    dns_domain_collection_hier.data_upd_date
   FROM jazzhands.dns_domain_collection_hier;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'dns_domain_collection_hier';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of dns_domain_collection_hier failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE dns_domain_collection_hier (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE dns_domain_ip_universe (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'dns_domain_ip_universe');
DROP VIEW IF EXISTS jazzhands_legacy.dns_domain_ip_universe;
CREATE VIEW jazzhands_legacy.dns_domain_ip_universe AS
 SELECT dns_domain_ip_universe.dns_domain_id,
    dns_domain_ip_universe.ip_universe_id,
    dns_domain_ip_universe.soa_class,
    dns_domain_ip_universe.soa_ttl,
    dns_domain_ip_universe.soa_serial,
    dns_domain_ip_universe.soa_refresh,
    dns_domain_ip_universe.soa_retry,
    dns_domain_ip_universe.soa_expire,
    dns_domain_ip_universe.soa_minimum,
    dns_domain_ip_universe.soa_mname,
    dns_domain_ip_universe.soa_rname,
    dns_domain_ip_universe.should_generate,
    dns_domain_ip_universe.last_generated,
    dns_domain_ip_universe.data_ins_user,
    dns_domain_ip_universe.data_ins_date,
    dns_domain_ip_universe.data_upd_user,
    dns_domain_ip_universe.data_upd_date
   FROM jazzhands.dns_domain_ip_universe;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'dns_domain_ip_universe';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of dns_domain_ip_universe failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE dns_domain_ip_universe (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE dns_record (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'dns_record');
DROP VIEW IF EXISTS jazzhands_legacy.dns_record;
CREATE VIEW jazzhands_legacy.dns_record AS
 SELECT dns_record.dns_record_id,
    dns_record.dns_name,
    dns_record.dns_domain_id,
    dns_record.dns_ttl,
    dns_record.dns_class,
    dns_record.dns_type,
    dns_record.dns_value,
    dns_record.dns_priority,
    dns_record.dns_srv_service,
    dns_record.dns_srv_protocol,
    dns_record.dns_srv_weight,
    dns_record.dns_srv_port,
    dns_record.netblock_id,
    dns_record.ip_universe_id,
    dns_record.reference_dns_record_id,
    dns_record.dns_value_record_id,
    dns_record.should_generate_ptr,
    dns_record.is_enabled,
    dns_record.data_ins_user,
    dns_record.data_ins_date,
    dns_record.data_upd_user,
    dns_record.data_upd_date
   FROM jazzhands.dns_record;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'dns_record';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of dns_record failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.dns_record
	ALTER dns_class
	SET DEFAULT 'IN'::character varying;
ALTER TABLE jazzhands_legacy.dns_record
	ALTER should_generate_ptr
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE jazzhands_legacy.dns_record
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE dns_record (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE dns_record_relation (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'dns_record_relation');
DROP VIEW IF EXISTS jazzhands_legacy.dns_record_relation;
CREATE VIEW jazzhands_legacy.dns_record_relation AS
 SELECT dns_record_relation.dns_record_id,
    dns_record_relation.related_dns_record_id,
    dns_record_relation.dns_record_relation_type,
    dns_record_relation.data_ins_user,
    dns_record_relation.data_ins_date,
    dns_record_relation.data_upd_user,
    dns_record_relation.data_upd_date
   FROM jazzhands.dns_record_relation;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'dns_record_relation';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of dns_record_relation failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE dns_record_relation (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE encapsulation_domain (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'encapsulation_domain');
DROP VIEW IF EXISTS jazzhands_legacy.encapsulation_domain;
CREATE VIEW jazzhands_legacy.encapsulation_domain AS
 SELECT encapsulation_domain.encapsulation_domain,
    encapsulation_domain.encapsulation_type,
    encapsulation_domain.description,
    encapsulation_domain.data_ins_user,
    encapsulation_domain.data_ins_date,
    encapsulation_domain.data_upd_user,
    encapsulation_domain.data_upd_date
   FROM jazzhands.encapsulation_domain;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'encapsulation_domain';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of encapsulation_domain failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE encapsulation_domain (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE encapsulation_range (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'encapsulation_range');
DROP VIEW IF EXISTS jazzhands_legacy.encapsulation_range;
CREATE VIEW jazzhands_legacy.encapsulation_range AS
 SELECT encapsulation_range.encapsulation_range_id,
    encapsulation_range.parent_encapsulation_range_id,
    encapsulation_range.site_code,
    encapsulation_range.description,
    encapsulation_range.data_ins_user,
    encapsulation_range.data_ins_date,
    encapsulation_range.data_upd_user,
    encapsulation_range.data_upd_date
   FROM jazzhands.encapsulation_range;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'encapsulation_range';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of encapsulation_range failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE encapsulation_range (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE encryption_key (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'encryption_key');
DROP VIEW IF EXISTS jazzhands_legacy.encryption_key;
CREATE VIEW jazzhands_legacy.encryption_key AS
 SELECT encryption_key.encryption_key_id,
    encryption_key.encryption_key_db_value,
    encryption_key.encryption_key_purpose,
    encryption_key.encryption_key_purpose_version,
    encryption_key.encryption_method,
    encryption_key.data_ins_user,
    encryption_key.data_ins_date,
    encryption_key.data_upd_user,
    encryption_key.data_upd_date
   FROM jazzhands.encryption_key;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'encryption_key';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of encryption_key failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE encryption_key (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE inter_component_connection (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'inter_component_connection');
DROP VIEW IF EXISTS jazzhands_legacy.inter_component_connection;
CREATE VIEW jazzhands_legacy.inter_component_connection AS
 SELECT inter_component_connection.inter_component_connection_id,
    inter_component_connection.slot1_id,
    inter_component_connection.slot2_id,
    inter_component_connection.circuit_id,
    inter_component_connection.data_ins_user,
    inter_component_connection.data_ins_date,
    inter_component_connection.data_upd_user,
    inter_component_connection.data_upd_date
   FROM jazzhands.inter_component_connection;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'inter_component_connection';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of inter_component_connection failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE inter_component_connection (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE ip_universe (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'ip_universe');
DROP VIEW IF EXISTS jazzhands_legacy.ip_universe;
CREATE VIEW jazzhands_legacy.ip_universe AS
 SELECT ip_universe.ip_universe_id,
    ip_universe.ip_universe_name,
    ip_universe.ip_namespace,
    ip_universe.should_generate_dns,
    ip_universe.description,
    ip_universe.data_ins_user,
    ip_universe.data_ins_date,
    ip_universe.data_upd_user,
    ip_universe.data_upd_date
   FROM jazzhands.ip_universe;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'ip_universe';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of ip_universe failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE ip_universe (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE ip_universe_visibility (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'ip_universe_visibility');
DROP VIEW IF EXISTS jazzhands_legacy.ip_universe_visibility;
CREATE VIEW jazzhands_legacy.ip_universe_visibility AS
 SELECT ip_universe_visibility.ip_universe_id,
    ip_universe_visibility.visible_ip_universe_id,
    ip_universe_visibility.propagate_dns,
    ip_universe_visibility.data_ins_user,
    ip_universe_visibility.data_ins_date,
    ip_universe_visibility.data_upd_user,
    ip_universe_visibility.data_upd_date
   FROM jazzhands.ip_universe_visibility;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'ip_universe_visibility';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of ip_universe_visibility failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.ip_universe_visibility
	ALTER propagate_dns
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE ip_universe_visibility (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE kerberos_realm (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'kerberos_realm');
DROP VIEW IF EXISTS jazzhands_legacy.kerberos_realm;
CREATE VIEW jazzhands_legacy.kerberos_realm AS
 SELECT kerberos_realm.krb_realm_id,
    kerberos_realm.realm_name,
    kerberos_realm.data_ins_user,
    kerberos_realm.data_ins_date,
    kerberos_realm.data_upd_user,
    kerberos_realm.data_upd_date
   FROM jazzhands.kerberos_realm;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'kerberos_realm';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of kerberos_realm failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE kerberos_realm (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE klogin (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'klogin');
DROP VIEW IF EXISTS jazzhands_legacy.klogin;
CREATE VIEW jazzhands_legacy.klogin AS
 SELECT klogin.klogin_id,
    klogin.account_id,
    klogin.account_collection_id,
    klogin.krb_realm_id,
    klogin.krb_instance,
    klogin.dest_account_id,
    klogin.data_ins_user,
    klogin.data_ins_date,
    klogin.data_upd_user,
    klogin.data_upd_date
   FROM jazzhands.klogin;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'klogin';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of klogin failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE klogin (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE klogin_mclass (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'klogin_mclass');
DROP VIEW IF EXISTS jazzhands_legacy.klogin_mclass;
CREATE VIEW jazzhands_legacy.klogin_mclass AS
 SELECT klogin_mclass.klogin_id,
    klogin_mclass.device_collection_id,
    klogin_mclass.data_ins_user,
    klogin_mclass.data_ins_date,
    klogin_mclass.data_upd_user,
    klogin_mclass.data_upd_date
   FROM jazzhands.klogin_mclass;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'klogin_mclass';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of klogin_mclass failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE klogin_mclass (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE l2_network_coll_l2_network (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'l2_network_coll_l2_network');
DROP VIEW IF EXISTS jazzhands_legacy.l2_network_coll_l2_network;
CREATE VIEW jazzhands_legacy.l2_network_coll_l2_network AS
 SELECT l2_network_coll_l2_network.layer2_network_collection_id,
    l2_network_coll_l2_network.layer2_network_id,
    l2_network_coll_l2_network.layer2_network_id_rank,
    l2_network_coll_l2_network.start_date,
    l2_network_coll_l2_network.finish_date,
    l2_network_coll_l2_network.data_ins_user,
    l2_network_coll_l2_network.data_ins_date,
    l2_network_coll_l2_network.data_upd_user,
    l2_network_coll_l2_network.data_upd_date
   FROM jazzhands.l2_network_coll_l2_network;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'l2_network_coll_l2_network';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of l2_network_coll_l2_network failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE l2_network_coll_l2_network (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE l3_network_coll_l3_network (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'l3_network_coll_l3_network');
DROP VIEW IF EXISTS jazzhands_legacy.l3_network_coll_l3_network;
CREATE VIEW jazzhands_legacy.l3_network_coll_l3_network AS
 SELECT l3_network_coll_l3_network.layer3_network_collection_id,
    l3_network_coll_l3_network.layer3_network_id,
    l3_network_coll_l3_network.layer3_network_id_rank,
    l3_network_coll_l3_network.start_date,
    l3_network_coll_l3_network.finish_date,
    l3_network_coll_l3_network.data_ins_user,
    l3_network_coll_l3_network.data_ins_date,
    l3_network_coll_l3_network.data_upd_user,
    l3_network_coll_l3_network.data_upd_date
   FROM jazzhands.l3_network_coll_l3_network;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'l3_network_coll_l3_network';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of l3_network_coll_l3_network failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE l3_network_coll_l3_network (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE layer1_connection (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'layer1_connection');
DROP VIEW IF EXISTS jazzhands_legacy.layer1_connection;
CREATE VIEW jazzhands_legacy.layer1_connection AS
 SELECT layer1_connection.layer1_connection_id,
    layer1_connection.physical_port1_id,
    layer1_connection.physical_port2_id,
    layer1_connection.circuit_id,
    layer1_connection.baud,
    layer1_connection.data_bits,
    layer1_connection.stop_bits,
    layer1_connection.parity,
    layer1_connection.flow_control,
    layer1_connection.tcpsrv_device_id,
    layer1_connection.is_tcpsrv_enabled,
    layer1_connection.data_ins_user,
    layer1_connection.data_ins_date,
    layer1_connection.data_upd_user,
    layer1_connection.data_upd_date
   FROM jazzhands.layer1_connection;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'layer1_connection';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of layer1_connection failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE layer1_connection (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE layer2_connection (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'layer2_connection');
DROP VIEW IF EXISTS jazzhands_legacy.layer2_connection;
CREATE VIEW jazzhands_legacy.layer2_connection AS
 SELECT layer2_connection.layer2_connection_id,
    layer2_connection.logical_port1_id,
    layer2_connection.logical_port2_id,
    layer2_connection.data_ins_user,
    layer2_connection.data_ins_date,
    layer2_connection.data_upd_user,
    layer2_connection.data_upd_date
   FROM jazzhands.layer2_connection;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'layer2_connection';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of layer2_connection failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE layer2_connection (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE layer2_connection_l2_network (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'layer2_connection_l2_network');
DROP VIEW IF EXISTS jazzhands_legacy.layer2_connection_l2_network;
CREATE VIEW jazzhands_legacy.layer2_connection_l2_network AS
 SELECT layer2_connection_l2_network.layer2_connection_id,
    layer2_connection_l2_network.layer2_network_id,
    layer2_connection_l2_network.encapsulation_mode,
    layer2_connection_l2_network.encapsulation_type,
    layer2_connection_l2_network.description,
    layer2_connection_l2_network.data_ins_user,
    layer2_connection_l2_network.data_ins_date,
    layer2_connection_l2_network.data_upd_user,
    layer2_connection_l2_network.data_upd_date
   FROM jazzhands.layer2_connection_l2_network;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'layer2_connection_l2_network';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of layer2_connection_l2_network failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE layer2_connection_l2_network (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE layer2_network (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'layer2_network');
DROP VIEW IF EXISTS jazzhands_legacy.layer2_network;
CREATE VIEW jazzhands_legacy.layer2_network AS
 SELECT layer2_network.layer2_network_id,
    layer2_network.encapsulation_name,
    layer2_network.encapsulation_domain,
    layer2_network.encapsulation_type,
    layer2_network.encapsulation_tag,
    layer2_network.description,
    layer2_network.external_id,
    layer2_network.encapsulation_range_id,
    layer2_network.data_ins_user,
    layer2_network.data_ins_date,
    layer2_network.data_upd_user,
    layer2_network.data_upd_date
   FROM jazzhands.layer2_network;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'layer2_network';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of layer2_network failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE layer2_network (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE layer2_network_collection (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'layer2_network_collection');
DROP VIEW IF EXISTS jazzhands_legacy.layer2_network_collection;
CREATE VIEW jazzhands_legacy.layer2_network_collection AS
 SELECT layer2_network_collection.layer2_network_collection_id,
    layer2_network_collection.layer2_network_collection_name,
    layer2_network_collection.layer2_network_collection_type,
    layer2_network_collection.description,
    layer2_network_collection.external_id,
    layer2_network_collection.data_ins_user,
    layer2_network_collection.data_ins_date,
    layer2_network_collection.data_upd_user,
    layer2_network_collection.data_upd_date
   FROM jazzhands.layer2_network_collection;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'layer2_network_collection';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of layer2_network_collection failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE layer2_network_collection (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE layer2_network_collection_hier (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'layer2_network_collection_hier');
DROP VIEW IF EXISTS jazzhands_legacy.layer2_network_collection_hier;
CREATE VIEW jazzhands_legacy.layer2_network_collection_hier AS
 SELECT layer2_network_collection_hier.layer2_network_collection_id,
    layer2_network_collection_hier.child_l2_network_coll_id,
    layer2_network_collection_hier.data_ins_user,
    layer2_network_collection_hier.data_ins_date,
    layer2_network_collection_hier.data_upd_user,
    layer2_network_collection_hier.data_upd_date
   FROM jazzhands.layer2_network_collection_hier;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'layer2_network_collection_hier';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of layer2_network_collection_hier failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE layer2_network_collection_hier (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE layer3_network (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'layer3_network');
DROP VIEW IF EXISTS jazzhands_legacy.layer3_network;
CREATE VIEW jazzhands_legacy.layer3_network AS
 SELECT layer3_network.layer3_network_id,
    layer3_network.netblock_id,
    layer3_network.layer2_network_id,
    layer3_network.default_gateway_netblock_id,
    layer3_network.rendezvous_netblock_id,
    layer3_network.description,
    layer3_network.external_id,
    layer3_network.data_ins_user,
    layer3_network.data_ins_date,
    layer3_network.data_upd_user,
    layer3_network.data_upd_date
   FROM jazzhands.layer3_network;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'layer3_network';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of layer3_network failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE layer3_network (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE layer3_network_collection (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'layer3_network_collection');
DROP VIEW IF EXISTS jazzhands_legacy.layer3_network_collection;
CREATE VIEW jazzhands_legacy.layer3_network_collection AS
 SELECT layer3_network_collection.layer3_network_collection_id,
    layer3_network_collection.layer3_network_collection_name,
    layer3_network_collection.layer3_network_collection_type,
    layer3_network_collection.description,
    layer3_network_collection.external_id,
    layer3_network_collection.data_ins_user,
    layer3_network_collection.data_ins_date,
    layer3_network_collection.data_upd_user,
    layer3_network_collection.data_upd_date
   FROM jazzhands.layer3_network_collection;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'layer3_network_collection';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of layer3_network_collection failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE layer3_network_collection (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE layer3_network_collection_hier (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'layer3_network_collection_hier');
DROP VIEW IF EXISTS jazzhands_legacy.layer3_network_collection_hier;
CREATE VIEW jazzhands_legacy.layer3_network_collection_hier AS
 SELECT layer3_network_collection_hier.layer3_network_collection_id,
    layer3_network_collection_hier.child_l3_network_coll_id,
    layer3_network_collection_hier.data_ins_user,
    layer3_network_collection_hier.data_ins_date,
    layer3_network_collection_hier.data_upd_user,
    layer3_network_collection_hier.data_upd_date
   FROM jazzhands.layer3_network_collection_hier;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'layer3_network_collection_hier';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of layer3_network_collection_hier failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE layer3_network_collection_hier (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE logical_port (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'logical_port');
DROP VIEW IF EXISTS jazzhands_legacy.logical_port;
CREATE VIEW jazzhands_legacy.logical_port AS
 SELECT logical_port.logical_port_id,
    logical_port.logical_port_name,
    logical_port.logical_port_type,
    logical_port.parent_logical_port_id,
    logical_port.mac_address,
    logical_port.data_ins_user,
    logical_port.data_ins_date,
    logical_port.data_upd_user,
    logical_port.data_upd_date
   FROM jazzhands.logical_port;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'logical_port';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of logical_port failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE logical_port (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE logical_port_slot (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'logical_port_slot');
DROP VIEW IF EXISTS jazzhands_legacy.logical_port_slot;
CREATE VIEW jazzhands_legacy.logical_port_slot AS
 SELECT logical_port_slot.logical_port_id,
    logical_port_slot.slot_id,
    logical_port_slot.data_ins_user,
    logical_port_slot.data_ins_date,
    logical_port_slot.data_upd_user,
    logical_port_slot.data_upd_date
   FROM jazzhands.logical_port_slot;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'logical_port_slot';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of logical_port_slot failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE logical_port_slot (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE logical_volume (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'logical_volume');
DROP VIEW IF EXISTS jazzhands_legacy.logical_volume;
CREATE VIEW jazzhands_legacy.logical_volume AS
 SELECT logical_volume.logical_volume_id,
    logical_volume.logical_volume_name,
    logical_volume.logical_volume_type,
    logical_volume.volume_group_id,
    logical_volume.device_id,
    logical_volume.logical_volume_size_in_bytes,
    logical_volume.logical_volume_offset_in_bytes,
    logical_volume.filesystem_type,
    logical_volume.data_ins_user,
    logical_volume.data_ins_date,
    logical_volume.data_upd_user,
    logical_volume.data_upd_date
   FROM jazzhands.logical_volume;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'logical_volume';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of logical_volume failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.logical_volume
	ALTER logical_volume_type
	SET DEFAULT 'legacy'::character varying;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE logical_volume (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE logical_volume_property (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'logical_volume_property');
DROP VIEW IF EXISTS jazzhands_legacy.logical_volume_property;
CREATE VIEW jazzhands_legacy.logical_volume_property AS
 SELECT logical_volume_property.logical_volume_property_id,
    logical_volume_property.logical_volume_id,
    logical_volume_property.logical_volume_type,
    logical_volume_property.logical_volume_purpose,
    logical_volume_property.filesystem_type,
    logical_volume_property.logical_volume_property_name,
    logical_volume_property.logical_volume_property_value,
    logical_volume_property.data_ins_user,
    logical_volume_property.data_ins_date,
    logical_volume_property.data_upd_user,
    logical_volume_property.data_upd_date
   FROM jazzhands.logical_volume_property;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'logical_volume_property';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of logical_volume_property failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE logical_volume_property (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE logical_volume_purpose (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'logical_volume_purpose');
DROP VIEW IF EXISTS jazzhands_legacy.logical_volume_purpose;
CREATE VIEW jazzhands_legacy.logical_volume_purpose AS
 SELECT logical_volume_purpose.logical_volume_purpose,
    logical_volume_purpose.logical_volume_id,
    logical_volume_purpose.description,
    logical_volume_purpose.data_ins_user,
    logical_volume_purpose.data_ins_date,
    logical_volume_purpose.data_upd_user,
    logical_volume_purpose.data_upd_date
   FROM jazzhands.logical_volume_purpose;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'logical_volume_purpose';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of logical_volume_purpose failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE logical_volume_purpose (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE mlag_peering (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'mlag_peering');
DROP VIEW IF EXISTS jazzhands_legacy.mlag_peering;
CREATE VIEW jazzhands_legacy.mlag_peering AS
 SELECT mlag_peering.mlag_peering_id,
    mlag_peering.device1_id,
    mlag_peering.device2_id,
    mlag_peering.data_ins_user,
    mlag_peering.data_ins_date,
    mlag_peering.data_upd_user,
    mlag_peering.data_upd_date
   FROM jazzhands.mlag_peering;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'mlag_peering';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of mlag_peering failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE mlag_peering (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE netblock (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'netblock');
DROP VIEW IF EXISTS jazzhands_legacy.netblock;
CREATE VIEW jazzhands_legacy.netblock AS
 SELECT netblock.netblock_id,
    netblock.ip_address,
    netblock.netblock_type,
    netblock.is_single_address,
    netblock.can_subnet,
    netblock.parent_netblock_id,
    netblock.netblock_status,
    netblock.ip_universe_id,
    netblock.description,
    netblock.external_id,
    netblock.data_ins_user,
    netblock.data_ins_date,
    netblock.data_upd_user,
    netblock.data_upd_date
   FROM jazzhands.netblock;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'netblock';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of netblock failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.netblock
	ALTER netblock_type
	SET DEFAULT 'default'::character varying;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE netblock (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE netblock_collection (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'netblock_collection');
DROP VIEW IF EXISTS jazzhands_legacy.netblock_collection;
CREATE VIEW jazzhands_legacy.netblock_collection AS
 SELECT netblock_collection.netblock_collection_id,
    netblock_collection.netblock_collection_name,
    netblock_collection.netblock_collection_type,
    netblock_collection.netblock_ip_family_restrict,
    netblock_collection.description,
    netblock_collection.external_id,
    netblock_collection.data_ins_user,
    netblock_collection.data_ins_date,
    netblock_collection.data_upd_user,
    netblock_collection.data_upd_date
   FROM jazzhands.netblock_collection;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'netblock_collection';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of netblock_collection failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE netblock_collection (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE netblock_collection_hier (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'netblock_collection_hier');
DROP VIEW IF EXISTS jazzhands_legacy.netblock_collection_hier;
CREATE VIEW jazzhands_legacy.netblock_collection_hier AS
 SELECT netblock_collection_hier.netblock_collection_id,
    netblock_collection_hier.child_netblock_collection_id,
    netblock_collection_hier.data_ins_user,
    netblock_collection_hier.data_ins_date,
    netblock_collection_hier.data_upd_user,
    netblock_collection_hier.data_upd_date
   FROM jazzhands.netblock_collection_hier;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'netblock_collection_hier';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of netblock_collection_hier failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE netblock_collection_hier (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE netblock_collection_netblock (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'netblock_collection_netblock');
DROP VIEW IF EXISTS jazzhands_legacy.netblock_collection_netblock;
CREATE VIEW jazzhands_legacy.netblock_collection_netblock AS
 SELECT netblock_collection_netblock.netblock_collection_id,
    netblock_collection_netblock.netblock_id,
    netblock_collection_netblock.netblock_id_rank,
    netblock_collection_netblock.start_date,
    netblock_collection_netblock.finish_date,
    netblock_collection_netblock.data_ins_user,
    netblock_collection_netblock.data_ins_date,
    netblock_collection_netblock.data_upd_user,
    netblock_collection_netblock.data_upd_date
   FROM jazzhands.netblock_collection_netblock;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'netblock_collection_netblock';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of netblock_collection_netblock failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE netblock_collection_netblock (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE network_interface (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'network_interface');
DROP VIEW IF EXISTS jazzhands_legacy.network_interface;
CREATE VIEW jazzhands_legacy.network_interface AS
 SELECT network_interface.network_interface_id,
    network_interface.device_id,
    network_interface.network_interface_name,
    network_interface.description,
    network_interface.parent_network_interface_id,
    network_interface.parent_relation_type,
    network_interface.physical_port_id,
    network_interface.slot_id,
    network_interface.logical_port_id,
    network_interface.network_interface_type,
    network_interface.is_interface_up,
    network_interface.mac_addr,
    network_interface.should_monitor,
    network_interface.should_manage,
    network_interface.data_ins_user,
    network_interface.data_ins_date,
    network_interface.data_upd_user,
    network_interface.data_upd_date
   FROM jazzhands.network_interface;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'network_interface';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of network_interface failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.network_interface
	ALTER is_interface_up
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE jazzhands_legacy.network_interface
	ALTER should_monitor
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE jazzhands_legacy.network_interface
	ALTER should_manage
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE network_interface (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE network_interface_netblock (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'network_interface_netblock');
DROP VIEW IF EXISTS jazzhands_legacy.network_interface_netblock;
CREATE VIEW jazzhands_legacy.network_interface_netblock AS
 SELECT network_interface_netblock.netblock_id,
    network_interface_netblock.network_interface_id,
    network_interface_netblock.device_id,
    network_interface_netblock.network_interface_rank,
    network_interface_netblock.data_ins_user,
    network_interface_netblock.data_ins_date,
    network_interface_netblock.data_upd_user,
    network_interface_netblock.data_upd_date
   FROM jazzhands.network_interface_netblock;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'network_interface_netblock';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of network_interface_netblock failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE network_interface_netblock (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE network_interface_purpose (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'network_interface_purpose');
DROP VIEW IF EXISTS jazzhands_legacy.network_interface_purpose;
CREATE VIEW jazzhands_legacy.network_interface_purpose AS
 SELECT network_interface_purpose.device_id,
    network_interface_purpose.network_interface_purpose,
    network_interface_purpose.network_interface_id,
    network_interface_purpose.description,
    network_interface_purpose.data_ins_user,
    network_interface_purpose.data_ins_date,
    network_interface_purpose.data_upd_user,
    network_interface_purpose.data_upd_date
   FROM jazzhands.network_interface_purpose;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'network_interface_purpose';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of network_interface_purpose failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE network_interface_purpose (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE network_range (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'network_range');
DROP VIEW IF EXISTS jazzhands_legacy.network_range;
CREATE VIEW jazzhands_legacy.network_range AS
 SELECT network_range.network_range_id,
    network_range.network_range_type,
    network_range.description,
    network_range.parent_netblock_id,
    network_range.start_netblock_id,
    network_range.stop_netblock_id,
    network_range.dns_prefix,
    network_range.dns_domain_id,
    network_range.lease_time,
    network_range.data_ins_user,
    network_range.data_ins_date,
    network_range.data_upd_user,
    network_range.data_upd_date
   FROM jazzhands.network_range;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'network_range';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of network_range failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE network_range (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE network_service (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'network_service');
DROP VIEW IF EXISTS jazzhands_legacy.network_service;
CREATE VIEW jazzhands_legacy.network_service AS
 SELECT network_service.network_service_id,
    network_service.name,
    network_service.description,
    network_service.network_service_type,
    network_service.is_monitored,
    network_service.device_id,
    network_service.network_interface_id,
    network_service.dns_record_id,
    network_service.service_environment_id,
    network_service.data_ins_user,
    network_service.data_ins_date,
    network_service.data_upd_user,
    network_service.data_upd_date
   FROM jazzhands.network_service;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'network_service';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of network_service failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE network_service (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE operating_system (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'operating_system');
DROP VIEW IF EXISTS jazzhands_legacy.operating_system;
CREATE VIEW jazzhands_legacy.operating_system AS
 SELECT operating_system.operating_system_id,
    operating_system.operating_system_name,
    operating_system.operating_system_short_name,
    operating_system.company_id,
    operating_system.major_version,
    operating_system.version,
    operating_system.operating_system_family,
    operating_system.data_ins_user,
    operating_system.data_ins_date,
    operating_system.data_upd_user,
    operating_system.data_upd_date
   FROM jazzhands.operating_system;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'operating_system';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of operating_system failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE operating_system (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE operating_system_snapshot (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'operating_system_snapshot');
DROP VIEW IF EXISTS jazzhands_legacy.operating_system_snapshot;
CREATE VIEW jazzhands_legacy.operating_system_snapshot AS
 SELECT operating_system_snapshot.operating_system_snapshot_id,
    operating_system_snapshot.operating_system_snapshot_name,
    operating_system_snapshot.operating_system_snapshot_type,
    operating_system_snapshot.operating_system_id,
    operating_system_snapshot.data_ins_user,
    operating_system_snapshot.data_ins_date,
    operating_system_snapshot.data_upd_user,
    operating_system_snapshot.data_upd_date
   FROM jazzhands.operating_system_snapshot;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'operating_system_snapshot';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of operating_system_snapshot failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE operating_system_snapshot (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE person (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'person');
DROP VIEW IF EXISTS jazzhands_legacy.person;
CREATE VIEW jazzhands_legacy.person AS
 SELECT person.person_id,
    person.description,
    person.first_name,
    person.middle_name,
    person.last_name,
    person.name_suffix,
    person.gender,
    person.preferred_first_name,
    person.preferred_last_name,
    person.nickname,
    person.birth_date,
    person.diet,
    person.shirt_size,
    person.pant_size,
    person.hat_size,
    person.data_ins_user,
    person.data_ins_date,
    person.data_upd_user,
    person.data_upd_date
   FROM jazzhands.person;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'person';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of person failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE person (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE person_account_realm_company (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'person_account_realm_company');
DROP VIEW IF EXISTS jazzhands_legacy.person_account_realm_company;
CREATE VIEW jazzhands_legacy.person_account_realm_company AS
 SELECT person_account_realm_company.person_id,
    person_account_realm_company.company_id,
    person_account_realm_company.account_realm_id,
    person_account_realm_company.data_ins_user,
    person_account_realm_company.data_ins_date,
    person_account_realm_company.data_upd_user,
    person_account_realm_company.data_upd_date
   FROM jazzhands.person_account_realm_company;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'person_account_realm_company';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of person_account_realm_company failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE person_account_realm_company (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE person_auth_question (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'person_auth_question');
DROP VIEW IF EXISTS jazzhands_legacy.person_auth_question;
CREATE VIEW jazzhands_legacy.person_auth_question AS
 SELECT person_auth_question.auth_question_id,
    person_auth_question.person_id,
    person_auth_question.user_answer,
    person_auth_question.is_active,
    person_auth_question.data_ins_user,
    person_auth_question.data_ins_date,
    person_auth_question.data_upd_user,
    person_auth_question.data_upd_date
   FROM jazzhands.person_auth_question;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'person_auth_question';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of person_auth_question failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE person_auth_question (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE person_company (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'person_company');
DROP VIEW IF EXISTS jazzhands_legacy.person_company;
CREATE VIEW jazzhands_legacy.person_company AS
 SELECT person_company.company_id,
    person_company.person_id,
    person_company.person_company_status,
    person_company.person_company_relation,
    person_company.is_exempt,
    person_company.is_management,
    person_company.is_full_time,
    person_company.description,
    person_company.position_title,
    person_company.hire_date,
    person_company.termination_date,
    person_company.manager_person_id,
    person_company.nickname,
    person_company.data_ins_user,
    person_company.data_ins_date,
    person_company.data_upd_user,
    person_company.data_upd_date
   FROM jazzhands.person_company;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'person_company';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of person_company failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.person_company
	ALTER is_exempt
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE jazzhands_legacy.person_company
	ALTER is_management
	SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.person_company
	ALTER is_full_time
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE person_company (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE person_company_attr (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'person_company_attr');
DROP VIEW IF EXISTS jazzhands_legacy.person_company_attr;
CREATE VIEW jazzhands_legacy.person_company_attr AS
 SELECT person_company_attr.company_id,
    person_company_attr.person_id,
    person_company_attr.person_company_attr_name,
    person_company_attr.attribute_value,
    person_company_attr.attribute_value_timestamp,
    person_company_attr.attribute_value_person_id,
    person_company_attr.start_date,
    person_company_attr.finish_date,
    person_company_attr.data_ins_user,
    person_company_attr.data_ins_date,
    person_company_attr.data_upd_user,
    person_company_attr.data_upd_date
   FROM jazzhands.person_company_attr;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'person_company_attr';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of person_company_attr failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE person_company_attr (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE person_company_badge (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'person_company_badge');
DROP VIEW IF EXISTS jazzhands_legacy.person_company_badge;
CREATE VIEW jazzhands_legacy.person_company_badge AS
 SELECT person_company_badge.company_id,
    person_company_badge.person_id,
    person_company_badge.badge_id,
    person_company_badge.description,
    person_company_badge.data_ins_user,
    person_company_badge.data_ins_date,
    person_company_badge.data_upd_user,
    person_company_badge.data_upd_date
   FROM jazzhands.person_company_badge;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'person_company_badge';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of person_company_badge failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE person_company_badge (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE person_contact (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'person_contact');
DROP VIEW IF EXISTS jazzhands_legacy.person_contact;
CREATE VIEW jazzhands_legacy.person_contact AS
 SELECT person_contact.person_contact_id,
    person_contact.person_id,
    person_contact.person_contact_type,
    person_contact.person_contact_technology,
    person_contact.person_contact_location_type,
    person_contact.person_contact_privacy,
    person_contact.person_contact_cr_company_id,
    person_contact.iso_country_code,
    person_contact.phone_number,
    person_contact.phone_extension,
    person_contact.phone_pin,
    person_contact.person_contact_account_name,
    person_contact.person_contact_order,
    person_contact.person_contact_notes,
    person_contact.data_ins_user,
    person_contact.data_ins_date,
    person_contact.data_upd_user,
    person_contact.data_upd_date
   FROM jazzhands.person_contact;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'person_contact';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of person_contact failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE person_contact (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE person_image (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'person_image');
DROP VIEW IF EXISTS jazzhands_legacy.person_image;
CREATE VIEW jazzhands_legacy.person_image AS
 SELECT person_image.person_image_id,
    person_image.person_id,
    person_image.person_image_order,
    person_image.image_type,
    person_image.image_blob,
    person_image.image_checksum,
    person_image.image_label,
    person_image.description,
    person_image.data_ins_user,
    person_image.data_ins_date,
    person_image.data_upd_user,
    person_image.data_upd_date
   FROM jazzhands.person_image;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'person_image';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of person_image failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE person_image (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE person_image_usage (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'person_image_usage');
DROP VIEW IF EXISTS jazzhands_legacy.person_image_usage;
CREATE VIEW jazzhands_legacy.person_image_usage AS
 SELECT person_image_usage.person_image_id,
    person_image_usage.person_image_usage,
    person_image_usage.data_ins_user,
    person_image_usage.data_ins_date,
    person_image_usage.data_upd_user,
    person_image_usage.data_upd_date
   FROM jazzhands.person_image_usage;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'person_image_usage';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of person_image_usage failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE person_image_usage (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE person_location (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'person_location');
DROP VIEW IF EXISTS jazzhands_legacy.person_location;
CREATE VIEW jazzhands_legacy.person_location AS
 SELECT person_location.person_location_id,
    person_location.person_id,
    person_location.person_location_type,
    person_location.site_code,
    person_location.physical_address_id,
    person_location.building,
    person_location.floor,
    person_location.section,
    person_location.seat_number,
    person_location.data_ins_user,
    person_location.data_ins_date,
    person_location.data_upd_user,
    person_location.data_upd_date
   FROM jazzhands.person_location;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'person_location';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of person_location failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE person_location (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE person_note (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'person_note');
DROP VIEW IF EXISTS jazzhands_legacy.person_note;
CREATE VIEW jazzhands_legacy.person_note AS
 SELECT person_note.note_id,
    person_note.person_id,
    person_note.note_text,
    person_note.note_date,
    person_note.note_user,
    person_note.data_ins_user,
    person_note.data_ins_date,
    person_note.data_upd_user,
    person_note.data_upd_date
   FROM jazzhands.person_note;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'person_note';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of person_note failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE person_note (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE person_parking_pass (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'person_parking_pass');
DROP VIEW IF EXISTS jazzhands_legacy.person_parking_pass;
CREATE VIEW jazzhands_legacy.person_parking_pass AS
 SELECT person_parking_pass.person_parking_pass_id,
    person_parking_pass.person_id,
    person_parking_pass.data_ins_user,
    person_parking_pass.data_ins_date,
    person_parking_pass.data_upd_user,
    person_parking_pass.data_upd_date
   FROM jazzhands.person_parking_pass;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'person_parking_pass';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of person_parking_pass failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE person_parking_pass (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE person_vehicle (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'person_vehicle');
DROP VIEW IF EXISTS jazzhands_legacy.person_vehicle;
CREATE VIEW jazzhands_legacy.person_vehicle AS
 SELECT person_vehicle.person_vehicle_id,
    person_vehicle.person_id,
    person_vehicle.vehicle_make,
    person_vehicle.vehicle_model,
    person_vehicle.vehicle_year,
    person_vehicle.vehicle_color,
    person_vehicle.vehicle_license_plate,
    person_vehicle.vehicle_license_state,
    person_vehicle.data_ins_user,
    person_vehicle.data_ins_date,
    person_vehicle.data_upd_user,
    person_vehicle.data_upd_date
   FROM jazzhands.person_vehicle;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'person_vehicle';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of person_vehicle failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE person_vehicle (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE physical_address (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'physical_address');
DROP VIEW IF EXISTS jazzhands_legacy.physical_address;
CREATE VIEW jazzhands_legacy.physical_address AS
 SELECT physical_address.physical_address_id,
    physical_address.physical_address_type,
    physical_address.company_id,
    physical_address.site_rank,
    physical_address.description,
    physical_address.display_label,
    physical_address.address_agent,
    physical_address.address_housename,
    physical_address.address_street,
    physical_address.address_building,
    physical_address.address_pobox,
    physical_address.address_neighborhood,
    physical_address.address_city,
    physical_address.address_subregion,
    physical_address.address_region,
    physical_address.postal_code,
    physical_address.iso_country_code,
    physical_address.address_freeform,
    physical_address.data_ins_user,
    physical_address.data_ins_date,
    physical_address.data_upd_user,
    physical_address.data_upd_date
   FROM jazzhands.physical_address;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'physical_address';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of physical_address failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.physical_address
	ALTER physical_address_type
	SET DEFAULT 'location'::character varying;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE physical_address (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE physical_connection (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'physical_connection');
DROP VIEW IF EXISTS jazzhands_legacy.physical_connection;
CREATE VIEW jazzhands_legacy.physical_connection AS
 SELECT physical_connection.physical_connection_id,
    physical_connection.physical_port1_id,
    physical_connection.physical_port2_id,
    physical_connection.slot1_id,
    physical_connection.slot2_id,
    physical_connection.cable_type,
    physical_connection.data_ins_user,
    physical_connection.data_ins_date,
    physical_connection.data_upd_user,
    physical_connection.data_upd_date
   FROM jazzhands.physical_connection;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'physical_connection';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of physical_connection failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE physical_connection (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE physical_port (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'physical_port');
DROP VIEW IF EXISTS jazzhands_legacy.physical_port;
CREATE VIEW jazzhands_legacy.physical_port AS
 SELECT physical_port.physical_port_id,
    physical_port.device_id,
    physical_port.port_name,
    physical_port.port_type,
    physical_port.description,
    physical_port.port_plug_style,
    physical_port.port_medium,
    physical_port.port_protocol,
    physical_port.port_speed,
    physical_port.physical_label,
    physical_port.port_purpose,
    physical_port.logical_port_id,
    physical_port.tcp_port,
    physical_port.is_hardwired,
    physical_port.data_ins_user,
    physical_port.data_ins_date,
    physical_port.data_upd_user,
    physical_port.data_upd_date
   FROM jazzhands.physical_port;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'physical_port';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of physical_port failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE physical_port (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE physicalish_volume (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'physicalish_volume');
DROP VIEW IF EXISTS jazzhands_legacy.physicalish_volume;
CREATE VIEW jazzhands_legacy.physicalish_volume AS
 SELECT physicalish_volume.physicalish_volume_id,
    physicalish_volume.physicalish_volume_name,
    physicalish_volume.physicalish_volume_type,
    physicalish_volume.device_id,
    physicalish_volume.logical_volume_id,
    physicalish_volume.component_id,
    physicalish_volume.data_ins_user,
    physicalish_volume.data_ins_date,
    physicalish_volume.data_upd_user,
    physicalish_volume.data_upd_date
   FROM jazzhands.physicalish_volume;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'physicalish_volume';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of physicalish_volume failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE physicalish_volume (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE private_key (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'private_key');
DROP VIEW IF EXISTS jazzhands_legacy.private_key;
CREATE VIEW jazzhands_legacy.private_key AS
 SELECT private_key.private_key_id,
    private_key.private_key_encryption_type,
    private_key.is_active,
    private_key.subject_key_identifier,
    private_key.private_key,
    private_key.passphrase,
    private_key.encryption_key_id,
    private_key.data_ins_user,
    private_key.data_ins_date,
    private_key.data_upd_user,
    private_key.data_upd_date
   FROM jazzhands.private_key;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'private_key';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of private_key failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.private_key
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE private_key (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE property (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'property');
DROP VIEW IF EXISTS jazzhands_legacy.property;
CREATE VIEW jazzhands_legacy.property AS
 SELECT property.property_id,
    property.account_collection_id,
    property.account_id,
    property.account_realm_id,
    property.company_collection_id,
    property.company_id,
    property.device_collection_id,
    property.dns_domain_collection_id,
    property.layer2_network_collection_id,
    property.layer3_network_collection_id,
    property.netblock_collection_id,
    property.network_range_id,
    property.operating_system_id,
    property.operating_system_snapshot_id,
    property.person_id,
    property.property_collection_id,
    property.service_env_collection_id,
    property.site_code,
    property.x509_signed_certificate_id,
    property.property_name,
    property.property_type,
    property.property_value,
    property.property_value_timestamp,
    property.property_value_account_coll_id,
    property.property_value_device_coll_id,
    property.property_value_json,
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
   FROM jazzhands.property;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'property';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of property failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.property
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE property (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE property_collection (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'property_collection');
DROP VIEW IF EXISTS jazzhands_legacy.property_collection;
CREATE VIEW jazzhands_legacy.property_collection AS
 SELECT property_collection.property_collection_id,
    property_collection.property_collection_name,
    property_collection.property_collection_type,
    property_collection.description,
    property_collection.data_ins_user,
    property_collection.data_ins_date,
    property_collection.data_upd_user,
    property_collection.data_upd_date
   FROM jazzhands.property_collection;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'property_collection';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of property_collection failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE property_collection (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE property_collection_hier (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'property_collection_hier');
DROP VIEW IF EXISTS jazzhands_legacy.property_collection_hier;
CREATE VIEW jazzhands_legacy.property_collection_hier AS
 SELECT property_collection_hier.property_collection_id,
    property_collection_hier.child_property_collection_id,
    property_collection_hier.data_ins_user,
    property_collection_hier.data_ins_date,
    property_collection_hier.data_upd_user,
    property_collection_hier.data_upd_date
   FROM jazzhands.property_collection_hier;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'property_collection_hier';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of property_collection_hier failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE property_collection_hier (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE property_collection_property (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'property_collection_property');
DROP VIEW IF EXISTS jazzhands_legacy.property_collection_property;
CREATE VIEW jazzhands_legacy.property_collection_property AS
 SELECT property_collection_property.property_collection_id,
    property_collection_property.property_name,
    property_collection_property.property_type,
    property_collection_property.property_id_rank,
    property_collection_property.data_ins_user,
    property_collection_property.data_ins_date,
    property_collection_property.data_upd_user,
    property_collection_property.data_upd_date
   FROM jazzhands.property_collection_property;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'property_collection_property';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of property_collection_property failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE property_collection_property (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE pseudo_klogin (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'pseudo_klogin');
DROP VIEW IF EXISTS jazzhands_legacy.pseudo_klogin;
CREATE VIEW jazzhands_legacy.pseudo_klogin AS
 SELECT pseudo_klogin.pseudo_klogin_id,
    pseudo_klogin.principal,
    pseudo_klogin.dest_account_id,
    pseudo_klogin.data_ins_user,
    pseudo_klogin.data_ins_date,
    pseudo_klogin.data_upd_user,
    pseudo_klogin.data_upd_date
   FROM jazzhands.pseudo_klogin;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'pseudo_klogin';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of pseudo_klogin failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE pseudo_klogin (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE rack (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'rack');
DROP VIEW IF EXISTS jazzhands_legacy.rack;
CREATE VIEW jazzhands_legacy.rack AS
 SELECT rack.rack_id,
    rack.site_code,
    rack.room,
    rack.sub_room,
    rack.rack_row,
    rack.rack_name,
    rack.rack_style,
    rack.rack_type,
    rack.description,
    rack.rack_height_in_u,
    rack.display_from_bottom,
    rack.data_ins_user,
    rack.data_ins_date,
    rack.data_upd_user,
    rack.data_upd_date
   FROM jazzhands.rack;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'rack';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of rack failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE rack (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE rack_location (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'rack_location');
DROP VIEW IF EXISTS jazzhands_legacy.rack_location;
CREATE VIEW jazzhands_legacy.rack_location AS
 SELECT rack_location.rack_location_id,
    rack_location.rack_id,
    rack_location.rack_u_offset_of_device_top,
    rack_location.rack_side,
    rack_location.data_ins_user,
    rack_location.data_ins_date,
    rack_location.data_upd_user,
    rack_location.data_upd_date
   FROM jazzhands.rack_location;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'rack_location';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of rack_location failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.rack_location
	ALTER rack_side
	SET DEFAULT 'FRONT'::character varying;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE rack_location (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE service_environment (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'service_environment');
DROP VIEW IF EXISTS jazzhands_legacy.service_environment;
CREATE VIEW jazzhands_legacy.service_environment AS
 SELECT service_environment.service_environment_id,
    service_environment.service_environment_name,
    service_environment.production_state,
    service_environment.description,
    service_environment.external_id,
    service_environment.data_ins_user,
    service_environment.data_ins_date,
    service_environment.data_upd_user,
    service_environment.data_upd_date
   FROM jazzhands.service_environment;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'service_environment';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of service_environment failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE service_environment (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE service_environment_coll_hier (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'service_environment_coll_hier');
DROP VIEW IF EXISTS jazzhands_legacy.service_environment_coll_hier;
CREATE VIEW jazzhands_legacy.service_environment_coll_hier AS
 SELECT service_environment_coll_hier.service_env_collection_id,
    service_environment_coll_hier.child_service_env_coll_id,
    service_environment_coll_hier.description,
    service_environment_coll_hier.data_ins_user,
    service_environment_coll_hier.data_ins_date,
    service_environment_coll_hier.data_upd_user,
    service_environment_coll_hier.data_upd_date
   FROM jazzhands.service_environment_coll_hier;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'service_environment_coll_hier';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of service_environment_coll_hier failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE service_environment_coll_hier (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE service_environment_collection (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'service_environment_collection');
DROP VIEW IF EXISTS jazzhands_legacy.service_environment_collection;
CREATE VIEW jazzhands_legacy.service_environment_collection AS
 SELECT service_environment_collection.service_env_collection_id,
    service_environment_collection.service_env_collection_name,
    service_environment_collection.service_env_collection_type,
    service_environment_collection.description,
    service_environment_collection.external_id,
    service_environment_collection.data_ins_user,
    service_environment_collection.data_ins_date,
    service_environment_collection.data_upd_user,
    service_environment_collection.data_upd_date
   FROM jazzhands.service_environment_collection;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'service_environment_collection';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of service_environment_collection failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE service_environment_collection (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE shared_netblock (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'shared_netblock');
DROP VIEW IF EXISTS jazzhands_legacy.shared_netblock;
CREATE VIEW jazzhands_legacy.shared_netblock AS
 SELECT shared_netblock.shared_netblock_id,
    shared_netblock.shared_netblock_protocol,
    shared_netblock.netblock_id,
    shared_netblock.description,
    shared_netblock.data_ins_user,
    shared_netblock.data_ins_date,
    shared_netblock.data_upd_user,
    shared_netblock.data_upd_date
   FROM jazzhands.shared_netblock;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'shared_netblock';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of shared_netblock failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE shared_netblock (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE shared_netblock_network_int (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'shared_netblock_network_int');
DROP VIEW IF EXISTS jazzhands_legacy.shared_netblock_network_int;
CREATE VIEW jazzhands_legacy.shared_netblock_network_int AS
 SELECT shared_netblock_network_int.shared_netblock_id,
    shared_netblock_network_int.network_interface_id,
    shared_netblock_network_int.priority,
    shared_netblock_network_int.data_ins_user,
    shared_netblock_network_int.data_ins_date,
    shared_netblock_network_int.data_upd_user,
    shared_netblock_network_int.data_upd_date
   FROM jazzhands.shared_netblock_network_int;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'shared_netblock_network_int';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of shared_netblock_network_int failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE shared_netblock_network_int (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE site (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'site');
DROP VIEW IF EXISTS jazzhands_legacy.site;
CREATE VIEW jazzhands_legacy.site AS
 SELECT site.site_code,
    site.colo_company_id,
    site.physical_address_id,
    site.site_status,
    site.description,
    site.data_ins_user,
    site.data_ins_date,
    site.data_upd_user,
    site.data_upd_date
   FROM jazzhands.site;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'site';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of site failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE site (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE site_netblock (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'site_netblock');
DROP VIEW IF EXISTS jazzhands_legacy.site_netblock;
CREATE VIEW jazzhands_legacy.site_netblock AS
 SELECT site_netblock.site_code,
    site_netblock.netblock_id,
    site_netblock.data_ins_user,
    site_netblock.data_ins_date,
    site_netblock.data_upd_user,
    site_netblock.data_upd_date
   FROM jazzhands.site_netblock;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'site_netblock';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of site_netblock failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE site_netblock (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE slot (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'slot');
DROP VIEW IF EXISTS jazzhands_legacy.slot;
CREATE VIEW jazzhands_legacy.slot AS
 SELECT slot.slot_id,
    slot.component_id,
    slot.slot_name,
    slot.slot_index,
    slot.slot_type_id,
    slot.component_type_slot_tmplt_id,
    slot.is_enabled,
    slot.physical_label,
    slot.mac_address,
    slot.description,
    slot.slot_x_offset,
    slot.slot_y_offset,
    slot.slot_z_offset,
    slot.slot_side,
    slot.data_ins_user,
    slot.data_ins_date,
    slot.data_upd_user,
    slot.data_upd_date
   FROM jazzhands.slot;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'slot';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of slot failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.slot
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE slot (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE slot_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'slot_type');
DROP VIEW IF EXISTS jazzhands_legacy.slot_type;
CREATE VIEW jazzhands_legacy.slot_type AS
 SELECT slot_type.slot_type_id,
    slot_type.slot_type,
    slot_type.slot_function,
    slot_type.slot_physical_interface_type,
    slot_type.description,
    slot_type.remote_slot_permitted,
    slot_type.data_ins_user,
    slot_type.data_ins_date,
    slot_type.data_upd_user,
    slot_type.data_upd_date
   FROM jazzhands.slot_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'slot_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of slot_type failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.slot_type
	ALTER remote_slot_permitted
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE slot_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE slot_type_prmt_comp_slot_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'slot_type_prmt_comp_slot_type');
DROP VIEW IF EXISTS jazzhands_legacy.slot_type_prmt_comp_slot_type;
CREATE VIEW jazzhands_legacy.slot_type_prmt_comp_slot_type AS
 SELECT slot_type_prmt_comp_slot_type.slot_type_id,
    slot_type_prmt_comp_slot_type.component_slot_type_id,
    slot_type_prmt_comp_slot_type.data_ins_user,
    slot_type_prmt_comp_slot_type.data_ins_date,
    slot_type_prmt_comp_slot_type.data_upd_user,
    slot_type_prmt_comp_slot_type.data_upd_date
   FROM jazzhands.slot_type_prmt_comp_slot_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'slot_type_prmt_comp_slot_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of slot_type_prmt_comp_slot_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE slot_type_prmt_comp_slot_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE slot_type_prmt_rem_slot_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'slot_type_prmt_rem_slot_type');
DROP VIEW IF EXISTS jazzhands_legacy.slot_type_prmt_rem_slot_type;
CREATE VIEW jazzhands_legacy.slot_type_prmt_rem_slot_type AS
 SELECT slot_type_prmt_rem_slot_type.slot_type_id,
    slot_type_prmt_rem_slot_type.remote_slot_type_id,
    slot_type_prmt_rem_slot_type.data_ins_user,
    slot_type_prmt_rem_slot_type.data_ins_date,
    slot_type_prmt_rem_slot_type.data_upd_user,
    slot_type_prmt_rem_slot_type.data_upd_date
   FROM jazzhands.slot_type_prmt_rem_slot_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'slot_type_prmt_rem_slot_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of slot_type_prmt_rem_slot_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE slot_type_prmt_rem_slot_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE snmp_commstr (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'snmp_commstr');
DROP VIEW IF EXISTS jazzhands_legacy.snmp_commstr;
CREATE VIEW jazzhands_legacy.snmp_commstr AS
 SELECT snmp_commstr.snmp_commstr_id,
    snmp_commstr.device_id,
    snmp_commstr.snmp_commstr_type,
    snmp_commstr.rd_string,
    snmp_commstr.wr_string,
    snmp_commstr.purpose,
    snmp_commstr.data_ins_user,
    snmp_commstr.data_ins_date,
    snmp_commstr.data_upd_user,
    snmp_commstr.data_upd_date
   FROM jazzhands.snmp_commstr;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'snmp_commstr';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of snmp_commstr failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE snmp_commstr (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE ssh_key (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'ssh_key');
DROP VIEW IF EXISTS jazzhands_legacy.ssh_key;
CREATE VIEW jazzhands_legacy.ssh_key AS
 SELECT ssh_key.ssh_key_id,
    ssh_key.ssh_key_type,
    ssh_key.ssh_public_key,
    ssh_key.ssh_private_key,
    ssh_key.encryption_key_id,
    ssh_key.description,
    ssh_key.data_ins_user,
    ssh_key.data_ins_date,
    ssh_key.data_upd_user,
    ssh_key.data_upd_date
   FROM jazzhands.ssh_key;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'ssh_key';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of ssh_key failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE ssh_key (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE static_route (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'static_route');
DROP VIEW IF EXISTS jazzhands_legacy.static_route;
CREATE VIEW jazzhands_legacy.static_route AS
 SELECT static_route.static_route_id,
    static_route.device_src_id,
    static_route.network_interface_dst_id,
    static_route.netblock_id,
    static_route.data_ins_user,
    static_route.data_ins_date,
    static_route.data_upd_user,
    static_route.data_upd_date
   FROM jazzhands.static_route;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'static_route';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of static_route failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE static_route (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE static_route_template (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'static_route_template');
DROP VIEW IF EXISTS jazzhands_legacy.static_route_template;
CREATE VIEW jazzhands_legacy.static_route_template AS
 SELECT static_route_template.static_route_template_id,
    static_route_template.netblock_src_id,
    static_route_template.network_interface_dst_id,
    static_route_template.netblock_id,
    static_route_template.description,
    static_route_template.data_ins_user,
    static_route_template.data_ins_date,
    static_route_template.data_upd_user,
    static_route_template.data_upd_date
   FROM jazzhands.static_route_template;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'static_route_template';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of static_route_template failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE static_route_template (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE sudo_acct_col_device_collectio (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'sudo_acct_col_device_collectio');
DROP VIEW IF EXISTS jazzhands_legacy.sudo_acct_col_device_collectio;
CREATE VIEW jazzhands_legacy.sudo_acct_col_device_collectio AS
 SELECT sudo_acct_col_device_collectio.sudo_alias_name,
    sudo_acct_col_device_collectio.device_collection_id,
    sudo_acct_col_device_collectio.account_collection_id,
    sudo_acct_col_device_collectio.run_as_account_collection_id,
    sudo_acct_col_device_collectio.requires_password,
    sudo_acct_col_device_collectio.can_exec_child,
    sudo_acct_col_device_collectio.data_ins_user,
    sudo_acct_col_device_collectio.data_ins_date,
    sudo_acct_col_device_collectio.data_upd_user,
    sudo_acct_col_device_collectio.data_upd_date
   FROM jazzhands.sudo_acct_col_device_collectio;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'sudo_acct_col_device_collectio';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of sudo_acct_col_device_collectio failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE sudo_acct_col_device_collectio (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE sudo_alias (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'sudo_alias');
DROP VIEW IF EXISTS jazzhands_legacy.sudo_alias;
CREATE VIEW jazzhands_legacy.sudo_alias AS
 SELECT sudo_alias.sudo_alias_name,
    sudo_alias.sudo_alias_value,
    sudo_alias.data_ins_user,
    sudo_alias.data_ins_date,
    sudo_alias.data_upd_user,
    sudo_alias.data_upd_date
   FROM jazzhands.sudo_alias;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'sudo_alias';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of sudo_alias failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE sudo_alias (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE svc_environment_coll_svc_env (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'svc_environment_coll_svc_env');
DROP VIEW IF EXISTS jazzhands_legacy.svc_environment_coll_svc_env;
CREATE VIEW jazzhands_legacy.svc_environment_coll_svc_env AS
 SELECT svc_environment_coll_svc_env.service_env_collection_id,
    svc_environment_coll_svc_env.service_environment_id,
    svc_environment_coll_svc_env.description,
    svc_environment_coll_svc_env.data_ins_user,
    svc_environment_coll_svc_env.data_ins_date,
    svc_environment_coll_svc_env.data_upd_user,
    svc_environment_coll_svc_env.data_upd_date
   FROM jazzhands.svc_environment_coll_svc_env;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'svc_environment_coll_svc_env';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of svc_environment_coll_svc_env failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE svc_environment_coll_svc_env (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE sw_package (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'sw_package');
DROP VIEW IF EXISTS jazzhands_legacy.sw_package;
CREATE VIEW jazzhands_legacy.sw_package AS
 SELECT sw_package.sw_package_id,
    sw_package.sw_package_name,
    sw_package.sw_package_type,
    sw_package.description,
    sw_package.data_ins_user,
    sw_package.data_ins_date,
    sw_package.data_upd_user,
    sw_package.data_upd_date
   FROM jazzhands.sw_package;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'sw_package';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of sw_package failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE sw_package (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE ticketing_system (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'ticketing_system');
DROP VIEW IF EXISTS jazzhands_legacy.ticketing_system;
CREATE VIEW jazzhands_legacy.ticketing_system AS
 SELECT ticketing_system.ticketing_system_id,
    ticketing_system.ticketing_system_name,
    ticketing_system.ticketing_system_url,
    ticketing_system.description,
    ticketing_system.data_ins_user,
    ticketing_system.data_ins_date,
    ticketing_system.data_upd_user,
    ticketing_system.data_upd_date
   FROM jazzhands.ticketing_system;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'ticketing_system';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of ticketing_system failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE ticketing_system (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE token (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'token');
DROP VIEW IF EXISTS jazzhands_legacy.token;
CREATE VIEW jazzhands_legacy.token AS
 SELECT token.token_id,
    token.token_type,
    token.token_status,
    token.description,
    token.external_id,
    token.token_serial,
    token.zero_time,
    token.time_modulo,
    token.time_skew,
    token.token_key,
    token.encryption_key_id,
    token.token_password,
    token.expire_time,
    token.is_token_locked,
    token.token_unlock_time,
    token.bad_logins,
    token.last_updated,
    token.data_ins_user,
    token.data_ins_date,
    token.data_upd_user,
    token.data_upd_date
   FROM jazzhands.token;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'token';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of token failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.token
	ALTER is_token_locked
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE token (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE token_collection (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'token_collection');
DROP VIEW IF EXISTS jazzhands_legacy.token_collection;
CREATE VIEW jazzhands_legacy.token_collection AS
 SELECT token_collection.token_collection_id,
    token_collection.token_collection_name,
    token_collection.token_collection_type,
    token_collection.description,
    token_collection.external_id,
    token_collection.data_ins_user,
    token_collection.data_ins_date,
    token_collection.data_upd_user,
    token_collection.data_upd_date
   FROM jazzhands.token_collection;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'token_collection';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of token_collection failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE token_collection (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE token_collection_hier (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'token_collection_hier');
DROP VIEW IF EXISTS jazzhands_legacy.token_collection_hier;
CREATE VIEW jazzhands_legacy.token_collection_hier AS
 SELECT token_collection_hier.token_collection_id,
    token_collection_hier.child_token_collection_id,
    token_collection_hier.data_ins_user,
    token_collection_hier.data_ins_date,
    token_collection_hier.data_upd_user,
    token_collection_hier.data_upd_date
   FROM jazzhands.token_collection_hier;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'token_collection_hier';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of token_collection_hier failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE token_collection_hier (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE token_collection_token (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'token_collection_token');
DROP VIEW IF EXISTS jazzhands_legacy.token_collection_token;
CREATE VIEW jazzhands_legacy.token_collection_token AS
 SELECT token_collection_token.token_collection_id,
    token_collection_token.token_id,
    token_collection_token.token_id_rank,
    token_collection_token.data_ins_user,
    token_collection_token.data_ins_date,
    token_collection_token.data_upd_user,
    token_collection_token.data_upd_date
   FROM jazzhands.token_collection_token;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'token_collection_token';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of token_collection_token failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE token_collection_token (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE token_sequence (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'token_sequence');
DROP VIEW IF EXISTS jazzhands_legacy.token_sequence;
CREATE VIEW jazzhands_legacy.token_sequence AS
 SELECT token_sequence.token_id,
    token_sequence.token_sequence,
    token_sequence.last_updated
   FROM jazzhands.token_sequence;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'token_sequence';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of token_sequence failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE token_sequence (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE unix_group (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'unix_group');
DROP VIEW IF EXISTS jazzhands_legacy.unix_group;
CREATE VIEW jazzhands_legacy.unix_group AS
 SELECT unix_group.account_collection_id,
    unix_group.unix_gid,
    unix_group.group_password,
    unix_group.data_ins_user,
    unix_group.data_ins_date,
    unix_group.data_upd_user,
    unix_group.data_upd_date
   FROM jazzhands.unix_group;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'unix_group';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of unix_group failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE unix_group (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_account_collection_account (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_account_collection_account');
DROP VIEW IF EXISTS jazzhands_legacy.v_account_collection_account;
CREATE VIEW jazzhands_legacy.v_account_collection_account AS
 SELECT v_account_collection_account.account_collection_id,
    v_account_collection_account.account_id,
    v_account_collection_account.account_collection_relation,
    v_account_collection_account.account_id_rank,
    v_account_collection_account.start_date,
    v_account_collection_account.finish_date,
    v_account_collection_account.data_ins_user,
    v_account_collection_account.data_ins_date,
    v_account_collection_account.data_upd_user,
    v_account_collection_account.data_upd_date
   FROM jazzhands.v_account_collection_account;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_account_collection_account';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_account_collection_account failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_account_collection_account (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_account_collection_expanded (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_account_collection_expanded');
DROP VIEW IF EXISTS jazzhands_legacy.v_account_collection_expanded;
CREATE VIEW jazzhands_legacy.v_account_collection_expanded AS
 SELECT v_account_collection_expanded.level,
    v_account_collection_expanded.root_account_collection_id,
    v_account_collection_expanded.account_collection_id
   FROM jazzhands.v_account_collection_expanded;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_account_collection_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_account_collection_expanded failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_account_collection_expanded (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_account_manager_hier (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_account_manager_hier');
DROP VIEW IF EXISTS jazzhands_legacy.v_account_manager_hier;
CREATE VIEW jazzhands_legacy.v_account_manager_hier AS
 SELECT v_account_manager_hier.level,
    v_account_manager_hier.account_id,
    v_account_manager_hier.person_id,
    v_account_manager_hier.company_id,
    v_account_manager_hier.login,
    v_account_manager_hier.human_readable,
    v_account_manager_hier.account_realm_id,
    v_account_manager_hier.manager_account_id,
    v_account_manager_hier.manager_login,
    v_account_manager_hier.manager_person_id,
    v_account_manager_hier.manager_company_id,
    v_account_manager_hier.manager_human_readable,
    v_account_manager_hier.array_path
   FROM jazzhands.v_account_manager_hier;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_account_manager_hier';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_account_manager_hier failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_account_manager_hier (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_account_manager_map (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_account_manager_map');
DROP VIEW IF EXISTS jazzhands_legacy.v_account_manager_map;
CREATE VIEW jazzhands_legacy.v_account_manager_map AS
 SELECT v_account_manager_map.login,
    v_account_manager_map.account_id,
    v_account_manager_map.person_id,
    v_account_manager_map.company_id,
    v_account_manager_map.account_realm_id,
    v_account_manager_map.first_name,
    v_account_manager_map.last_name,
    v_account_manager_map.middle_name,
    v_account_manager_map.manager_person_id,
    v_account_manager_map.employee_id,
    v_account_manager_map.human_readable,
    v_account_manager_map.manager_account_id,
    v_account_manager_map.manager_login,
    v_account_manager_map.manager_human_readable,
    v_account_manager_map.manager_last_name,
    v_account_manager_map.manager_middle_name,
    v_account_manager_map.manger_first_name,
    v_account_manager_map.manager_employee_id,
    v_account_manager_map.manager_company_id
   FROM jazzhands.v_account_manager_map;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_account_manager_map';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_account_manager_map failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_account_manager_map (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_acct_coll_acct_expanded (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_acct_coll_acct_expanded');
DROP VIEW IF EXISTS jazzhands_legacy.v_acct_coll_acct_expanded;
CREATE VIEW jazzhands_legacy.v_acct_coll_acct_expanded AS
 SELECT v_acct_coll_acct_expanded.account_collection_id,
    v_acct_coll_acct_expanded.account_id
   FROM jazzhands.v_acct_coll_acct_expanded;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_acct_coll_acct_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_acct_coll_acct_expanded failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_acct_coll_acct_expanded (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_acct_coll_acct_expanded_detail (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_acct_coll_acct_expanded_detail');
DROP VIEW IF EXISTS jazzhands_legacy.v_acct_coll_acct_expanded_detail;
CREATE VIEW jazzhands_legacy.v_acct_coll_acct_expanded_detail AS
 SELECT v_acct_coll_acct_expanded_detail.account_collection_id,
    v_acct_coll_acct_expanded_detail.root_account_collection_id,
    v_acct_coll_acct_expanded_detail.account_id,
    v_acct_coll_acct_expanded_detail.acct_coll_level,
    v_acct_coll_acct_expanded_detail.dept_level,
    v_acct_coll_acct_expanded_detail.assign_method,
    v_acct_coll_acct_expanded_detail.text_path,
    v_acct_coll_acct_expanded_detail.array_path
   FROM jazzhands.v_acct_coll_acct_expanded_detail;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_acct_coll_acct_expanded_detail';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_acct_coll_acct_expanded_detail failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_acct_coll_acct_expanded_detail (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_acct_coll_expanded (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_acct_coll_expanded');
DROP VIEW IF EXISTS jazzhands_legacy.v_acct_coll_expanded;
CREATE VIEW jazzhands_legacy.v_acct_coll_expanded AS
 SELECT v_acct_coll_expanded.level,
    v_acct_coll_expanded.account_collection_id,
    v_acct_coll_expanded.root_account_collection_id,
    v_acct_coll_expanded.text_path,
    v_acct_coll_expanded.array_path,
    v_acct_coll_expanded.rvs_array_path
   FROM jazzhands.v_acct_coll_expanded;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_acct_coll_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_acct_coll_expanded failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_acct_coll_expanded (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_acct_coll_expanded_detail (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_acct_coll_expanded_detail');
DROP VIEW IF EXISTS jazzhands_legacy.v_acct_coll_expanded_detail;
CREATE VIEW jazzhands_legacy.v_acct_coll_expanded_detail AS
 SELECT v_acct_coll_expanded_detail.account_collection_id,
    v_acct_coll_expanded_detail.root_account_collection_id,
    v_acct_coll_expanded_detail.acct_coll_level,
    v_acct_coll_expanded_detail.dept_level,
    v_acct_coll_expanded_detail.assign_method,
    v_acct_coll_expanded_detail.text_path,
    v_acct_coll_expanded_detail.array_path
   FROM jazzhands.v_acct_coll_expanded_detail;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_acct_coll_expanded_detail';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_acct_coll_expanded_detail failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_acct_coll_expanded_detail (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_acct_coll_prop_expanded (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_acct_coll_prop_expanded');
DROP VIEW IF EXISTS jazzhands_legacy.v_acct_coll_prop_expanded;
CREATE VIEW jazzhands_legacy.v_acct_coll_prop_expanded AS
 SELECT v_acct_coll_prop_expanded.account_collection_id,
    v_acct_coll_prop_expanded.property_id,
    v_acct_coll_prop_expanded.property_name,
    v_acct_coll_prop_expanded.property_type,
    v_acct_coll_prop_expanded.property_value,
    v_acct_coll_prop_expanded.property_value_timestamp,
    v_acct_coll_prop_expanded.property_value_account_coll_id,
    v_acct_coll_prop_expanded.property_value_nblk_coll_id,
    v_acct_coll_prop_expanded.property_value_password_type,
    v_acct_coll_prop_expanded.property_value_person_id,
    v_acct_coll_prop_expanded.property_value_token_col_id,
    v_acct_coll_prop_expanded.property_rank,
    v_acct_coll_prop_expanded.is_multivalue,
    v_acct_coll_prop_expanded.assign_rank
   FROM jazzhands.v_acct_coll_prop_expanded;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_acct_coll_prop_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_acct_coll_prop_expanded failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_acct_coll_prop_expanded (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_application_role (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_application_role');
DROP VIEW IF EXISTS jazzhands_legacy.v_application_role;
CREATE VIEW jazzhands_legacy.v_application_role AS
 SELECT v_application_role.role_level,
    v_application_role.role_id,
    v_application_role.parent_role_id,
    v_application_role.root_role_id,
    v_application_role.root_role_name,
    v_application_role.role_name,
    v_application_role.role_path,
    v_application_role.role_is_leaf,
    v_application_role.array_path,
    v_application_role.cycle
   FROM jazzhands.v_application_role;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_application_role';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_application_role failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_application_role (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_application_role_member (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_application_role_member');
DROP VIEW IF EXISTS jazzhands_legacy.v_application_role_member;
CREATE VIEW jazzhands_legacy.v_application_role_member AS
 SELECT v_application_role_member.device_id,
    v_application_role_member.role_id,
    v_application_role_member.data_ins_user,
    v_application_role_member.data_ins_date,
    v_application_role_member.data_upd_user,
    v_application_role_member.data_upd_date
   FROM jazzhands.v_application_role_member;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_application_role_member';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_application_role_member failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_application_role_member (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_approval_instance_step_expanded (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_approval_instance_step_expanded');
DROP VIEW IF EXISTS jazzhands_legacy.v_approval_instance_step_expanded;
CREATE VIEW jazzhands_legacy.v_approval_instance_step_expanded AS
 SELECT v_approval_instance_step_expanded.first_approval_instance_item_id,
    v_approval_instance_step_expanded.root_step_id,
    v_approval_instance_step_expanded.approval_instance_item_id,
    v_approval_instance_step_expanded.approval_instance_step_id,
    v_approval_instance_step_expanded.tier,
    v_approval_instance_step_expanded.level,
    v_approval_instance_step_expanded.is_approved
   FROM jazzhands.v_approval_instance_step_expanded;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_approval_instance_step_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_approval_instance_step_expanded failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_approval_instance_step_expanded (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_company_hier (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_company_hier');
DROP VIEW IF EXISTS jazzhands_legacy.v_company_hier;
CREATE VIEW jazzhands_legacy.v_company_hier AS
 SELECT v_company_hier.root_company_id,
    v_company_hier.company_id
   FROM jazzhands.v_company_hier;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_company_hier';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_company_hier failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_company_hier (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_component_hier (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_component_hier');
DROP VIEW IF EXISTS jazzhands_legacy.v_component_hier;
CREATE VIEW jazzhands_legacy.v_component_hier AS
 SELECT v_component_hier.component_id,
    v_component_hier.child_component_id,
    v_component_hier.component_path,
    v_component_hier.level
   FROM jazzhands.v_component_hier;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_component_hier';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_component_hier failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_component_hier (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_corp_family_account (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_corp_family_account');
DROP VIEW IF EXISTS jazzhands_legacy.v_corp_family_account;
CREATE VIEW jazzhands_legacy.v_corp_family_account AS
 SELECT v_corp_family_account.account_id,
    v_corp_family_account.login,
    v_corp_family_account.person_id,
    v_corp_family_account.company_id,
    v_corp_family_account.account_realm_id,
    v_corp_family_account.account_status,
    v_corp_family_account.account_role,
    v_corp_family_account.account_type,
    v_corp_family_account.description,
    v_corp_family_account.is_enabled,
    v_corp_family_account.data_ins_user,
    v_corp_family_account.data_ins_date,
    v_corp_family_account.data_upd_user,
    v_corp_family_account.data_upd_date
   FROM jazzhands.v_corp_family_account;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_corp_family_account';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_corp_family_account failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_corp_family_account (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_department_company_expanded (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_department_company_expanded');
DROP VIEW IF EXISTS jazzhands_legacy.v_department_company_expanded;
CREATE VIEW jazzhands_legacy.v_department_company_expanded AS
 SELECT v_department_company_expanded.company_id,
    v_department_company_expanded.account_collection_id
   FROM jazzhands.v_department_company_expanded;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_department_company_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_department_company_expanded failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_department_company_expanded (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_dev_col_device_root (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_dev_col_device_root');
DROP VIEW IF EXISTS jazzhands_legacy.v_dev_col_device_root;
CREATE VIEW jazzhands_legacy.v_dev_col_device_root AS
 SELECT v_dev_col_device_root.device_id,
    v_dev_col_device_root.root_id,
    v_dev_col_device_root.root_name,
    v_dev_col_device_root.root_type,
    v_dev_col_device_root.leaf_id,
    v_dev_col_device_root.leaf_name,
    v_dev_col_device_root.leaf_type
   FROM jazzhands.v_dev_col_device_root;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_dev_col_device_root';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_dev_col_device_root failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_dev_col_device_root (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_dev_col_root (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_dev_col_root');
DROP VIEW IF EXISTS jazzhands_legacy.v_dev_col_root;
CREATE VIEW jazzhands_legacy.v_dev_col_root AS
 SELECT v_dev_col_root.root_id,
    v_dev_col_root.root_name,
    v_dev_col_root.root_type,
    v_dev_col_root.leaf_id,
    v_dev_col_root.leaf_name,
    v_dev_col_root.leaf_type
   FROM jazzhands.v_dev_col_root;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_dev_col_root';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_dev_col_root failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_dev_col_root (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_dev_col_user_prop_expanded (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_dev_col_user_prop_expanded');
DROP VIEW IF EXISTS jazzhands_legacy.v_dev_col_user_prop_expanded;
CREATE VIEW jazzhands_legacy.v_dev_col_user_prop_expanded AS
 SELECT v_dev_col_user_prop_expanded.property_id,
    v_dev_col_user_prop_expanded.device_collection_id,
    v_dev_col_user_prop_expanded.account_id,
    v_dev_col_user_prop_expanded.login,
    v_dev_col_user_prop_expanded.account_status,
    v_dev_col_user_prop_expanded.account_realm_id,
    v_dev_col_user_prop_expanded.account_realm_name,
    v_dev_col_user_prop_expanded.is_enabled,
    v_dev_col_user_prop_expanded.property_type,
    v_dev_col_user_prop_expanded.property_name,
    v_dev_col_user_prop_expanded.property_rank,
    v_dev_col_user_prop_expanded.property_value,
    v_dev_col_user_prop_expanded.is_multivalue,
    v_dev_col_user_prop_expanded.is_boolean
   FROM jazzhands.v_dev_col_user_prop_expanded;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_dev_col_user_prop_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_dev_col_user_prop_expanded failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_dev_col_user_prop_expanded (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_col_account_cart (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_device_col_account_cart');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_col_account_cart;
CREATE VIEW jazzhands_legacy.v_device_col_account_cart AS
 SELECT v_device_col_account_cart.device_collection_id,
    v_device_col_account_cart.account_id,
    v_device_col_account_cart.setting
   FROM jazzhands.v_device_col_account_cart;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_device_col_account_cart';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_col_account_cart failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_device_col_account_cart (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_col_account_col_cart (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_device_col_account_col_cart');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_col_account_col_cart;
CREATE VIEW jazzhands_legacy.v_device_col_account_col_cart AS
 SELECT v_device_col_account_col_cart.device_collection_id,
    v_device_col_account_col_cart.account_collection_id,
    v_device_col_account_col_cart.setting
   FROM jazzhands.v_device_col_account_col_cart;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_device_col_account_col_cart';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_col_account_col_cart failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_device_col_account_col_cart (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_col_acct_col_expanded (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_device_col_acct_col_expanded');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_col_acct_col_expanded;
CREATE VIEW jazzhands_legacy.v_device_col_acct_col_expanded AS
 SELECT v_device_col_acct_col_expanded.device_collection_id,
    v_device_col_acct_col_expanded.account_collection_id,
    v_device_col_acct_col_expanded.account_id
   FROM jazzhands.v_device_col_acct_col_expanded;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_device_col_acct_col_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_col_acct_col_expanded failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_device_col_acct_col_expanded (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_col_acct_col_unixgroup (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_device_col_acct_col_unixgroup');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_col_acct_col_unixgroup;
CREATE VIEW jazzhands_legacy.v_device_col_acct_col_unixgroup AS
 SELECT v_device_col_acct_col_unixgroup.device_collection_id,
    v_device_col_acct_col_unixgroup.account_collection_id
   FROM jazzhands.v_device_col_acct_col_unixgroup;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_device_col_acct_col_unixgroup';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_col_acct_col_unixgroup failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_device_col_acct_col_unixgroup (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_col_acct_col_unixlogin (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_device_col_acct_col_unixlogin');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_col_acct_col_unixlogin;
CREATE VIEW jazzhands_legacy.v_device_col_acct_col_unixlogin AS
 SELECT v_device_col_acct_col_unixlogin.device_collection_id,
    v_device_col_acct_col_unixlogin.account_collection_id,
    v_device_col_acct_col_unixlogin.account_id
   FROM jazzhands.v_device_col_acct_col_unixlogin;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_device_col_acct_col_unixlogin';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_col_acct_col_unixlogin failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_device_col_acct_col_unixlogin (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_coll_device_expanded (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_device_coll_device_expanded');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_coll_device_expanded;
CREATE VIEW jazzhands_legacy.v_device_coll_device_expanded AS
 SELECT v_device_coll_device_expanded.device_collection_id,
    v_device_coll_device_expanded.device_id
   FROM jazzhands.v_device_coll_device_expanded;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_device_coll_device_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_coll_device_expanded failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_device_coll_device_expanded (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_coll_hier_detail (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_device_coll_hier_detail');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_coll_hier_detail;
CREATE VIEW jazzhands_legacy.v_device_coll_hier_detail AS
 SELECT v_device_coll_hier_detail.device_collection_id,
    v_device_coll_hier_detail.parent_device_collection_id,
    v_device_coll_hier_detail.device_collection_level
   FROM jazzhands.v_device_coll_hier_detail;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_device_coll_hier_detail';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_coll_hier_detail failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_device_coll_hier_detail (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_collection_account_ssh_key (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_device_collection_account_ssh_key');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_collection_account_ssh_key;
CREATE VIEW jazzhands_legacy.v_device_collection_account_ssh_key AS
 SELECT v_device_collection_account_ssh_key.device_collection_id,
    v_device_collection_account_ssh_key.account_id,
    v_device_collection_account_ssh_key.ssh_public_key
   FROM jazzhands.v_device_collection_account_ssh_key;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_device_collection_account_ssh_key';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_collection_account_ssh_key failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_device_collection_account_ssh_key (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_collection_hier_trans (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_device_collection_hier_trans');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_collection_hier_trans;
CREATE VIEW jazzhands_legacy.v_device_collection_hier_trans AS
 SELECT v_device_collection_hier_trans.parent_device_collection_id,
    v_device_collection_hier_trans.device_collection_id,
    v_device_collection_hier_trans.data_ins_user,
    v_device_collection_hier_trans.data_ins_date,
    v_device_collection_hier_trans.data_upd_user,
    v_device_collection_hier_trans.data_upd_date
   FROM jazzhands.v_device_collection_hier_trans;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_device_collection_hier_trans';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_collection_hier_trans failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_device_collection_hier_trans (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_component_summary (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_device_component_summary');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_component_summary;
CREATE VIEW jazzhands_legacy.v_device_component_summary AS
 SELECT v_device_component_summary.device_id,
    v_device_component_summary.cpu_model,
    v_device_component_summary.cpu_count,
    v_device_component_summary.core_count,
    v_device_component_summary.memory_count,
    v_device_component_summary.total_memory,
    v_device_component_summary.disk_count,
    v_device_component_summary.total_disk
   FROM jazzhands.v_device_component_summary;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_device_component_summary';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_component_summary failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_device_component_summary (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_components (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_device_components');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_components;
CREATE VIEW jazzhands_legacy.v_device_components AS
 SELECT v_device_components.device_id,
    v_device_components.component_id,
    v_device_components.component_path,
    v_device_components.level
   FROM jazzhands.v_device_components;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_device_components';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_components failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_device_components (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_components_expanded (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_device_components_expanded');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_components_expanded;
CREATE VIEW jazzhands_legacy.v_device_components_expanded AS
 SELECT v_device_components_expanded.device_id,
    v_device_components_expanded.component_id,
    v_device_components_expanded.slot_id,
    v_device_components_expanded.vendor,
    v_device_components_expanded.model,
    v_device_components_expanded.serial_number,
    v_device_components_expanded.functions,
    v_device_components_expanded.slot_name,
    v_device_components_expanded.memory_size,
    v_device_components_expanded.memory_speed,
    v_device_components_expanded.disk_size,
    v_device_components_expanded.media_type
   FROM jazzhands.v_device_components_expanded;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_device_components_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_components_expanded failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_device_components_expanded (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_components_json (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_device_components_json');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_components_json;
CREATE VIEW jazzhands_legacy.v_device_components_json AS
 SELECT v_device_components_json.device_id,
    v_device_components_json.components
   FROM jazzhands.v_device_components_json;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_device_components_json';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_components_json failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_device_components_json (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_slot_connections (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_device_slot_connections');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_slot_connections;
CREATE VIEW jazzhands_legacy.v_device_slot_connections AS
 SELECT v_device_slot_connections.inter_component_connection_id,
    v_device_slot_connections.device_id,
    v_device_slot_connections.slot_id,
    v_device_slot_connections.slot_name,
    v_device_slot_connections.slot_index,
    v_device_slot_connections.mac_address,
    v_device_slot_connections.slot_type_id,
    v_device_slot_connections.slot_type,
    v_device_slot_connections.slot_function,
    v_device_slot_connections.remote_device_id,
    v_device_slot_connections.remote_slot_id,
    v_device_slot_connections.remote_slot_name,
    v_device_slot_connections.remote_slot_index,
    v_device_slot_connections.remote_mac_address,
    v_device_slot_connections.remote_slot_type_id,
    v_device_slot_connections.remote_slot_type,
    v_device_slot_connections.remote_slot_function
   FROM jazzhands.v_device_slot_connections;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_device_slot_connections';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_slot_connections failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_device_slot_connections (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_slots (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_device_slots');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_slots;
CREATE VIEW jazzhands_legacy.v_device_slots AS
 SELECT v_device_slots.device_id,
    v_device_slots.device_component_id,
    v_device_slots.component_id,
    v_device_slots.slot_id
   FROM jazzhands.v_device_slots;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_device_slots';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_slots failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_device_slots (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_dns (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_dns');
DROP VIEW IF EXISTS jazzhands_legacy.v_dns;
CREATE VIEW jazzhands_legacy.v_dns AS
 SELECT v_dns.dns_record_id,
    v_dns.network_range_id,
    v_dns.dns_domain_id,
    v_dns.dns_name,
    v_dns.dns_ttl,
    v_dns.dns_class,
    v_dns.dns_type,
    v_dns.dns_value,
    v_dns.dns_priority,
    v_dns.ip,
    v_dns.netblock_id,
    v_dns.ip_universe_id,
    v_dns.ref_record_id,
    v_dns.dns_srv_service,
    v_dns.dns_srv_protocol,
    v_dns.dns_srv_weight,
    v_dns.dns_srv_port,
    v_dns.is_enabled,
    v_dns.should_generate_ptr,
    v_dns.dns_value_record_id
   FROM jazzhands.v_dns;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_dns';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_dns failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_dns (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_dns_changes_pending (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_dns_changes_pending');
DROP VIEW IF EXISTS jazzhands_legacy.v_dns_changes_pending;
CREATE VIEW jazzhands_legacy.v_dns_changes_pending AS
 SELECT v_dns_changes_pending.dns_change_record_id,
    v_dns_changes_pending.dns_domain_id,
    v_dns_changes_pending.ip_universe_id,
    v_dns_changes_pending.should_generate,
    v_dns_changes_pending.last_generated,
    v_dns_changes_pending.soa_name,
    v_dns_changes_pending.ip_address
   FROM jazzhands.v_dns_changes_pending;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_dns_changes_pending';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_dns_changes_pending failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_dns_changes_pending (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_dns_domain_nouniverse (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_dns_domain_nouniverse');
DROP VIEW IF EXISTS jazzhands_legacy.v_dns_domain_nouniverse;
CREATE VIEW jazzhands_legacy.v_dns_domain_nouniverse AS
 SELECT v_dns_domain_nouniverse.dns_domain_id,
    v_dns_domain_nouniverse.soa_name,
    v_dns_domain_nouniverse.soa_class,
    v_dns_domain_nouniverse.soa_ttl,
    v_dns_domain_nouniverse.soa_serial,
    v_dns_domain_nouniverse.soa_refresh,
    v_dns_domain_nouniverse.soa_retry,
    v_dns_domain_nouniverse.soa_expire,
    v_dns_domain_nouniverse.soa_minimum,
    v_dns_domain_nouniverse.soa_mname,
    v_dns_domain_nouniverse.soa_rname,
    v_dns_domain_nouniverse.parent_dns_domain_id,
    v_dns_domain_nouniverse.should_generate,
    v_dns_domain_nouniverse.last_generated,
    v_dns_domain_nouniverse.dns_domain_type,
    v_dns_domain_nouniverse.data_ins_user,
    v_dns_domain_nouniverse.data_ins_date,
    v_dns_domain_nouniverse.data_upd_user,
    v_dns_domain_nouniverse.data_upd_date
   FROM jazzhands.v_dns_domain_nouniverse;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_dns_domain_nouniverse';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_dns_domain_nouniverse failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_dns_domain_nouniverse (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_dns_fwd (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_dns_fwd');
DROP VIEW IF EXISTS jazzhands_legacy.v_dns_fwd;
CREATE VIEW jazzhands_legacy.v_dns_fwd AS
 SELECT v_dns_fwd.dns_record_id,
    v_dns_fwd.network_range_id,
    v_dns_fwd.dns_domain_id,
    v_dns_fwd.dns_name,
    v_dns_fwd.dns_ttl,
    v_dns_fwd.dns_class,
    v_dns_fwd.dns_type,
    v_dns_fwd.dns_value,
    v_dns_fwd.dns_priority,
    v_dns_fwd.ip,
    v_dns_fwd.netblock_id,
    v_dns_fwd.ip_universe_id,
    v_dns_fwd.ref_record_id,
    v_dns_fwd.dns_srv_service,
    v_dns_fwd.dns_srv_protocol,
    v_dns_fwd.dns_srv_weight,
    v_dns_fwd.dns_srv_port,
    v_dns_fwd.is_enabled,
    v_dns_fwd.should_generate_ptr,
    v_dns_fwd.dns_value_record_id
   FROM jazzhands.v_dns_fwd;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_dns_fwd';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_dns_fwd failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_dns_fwd (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_dns_rvs (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_dns_rvs');
DROP VIEW IF EXISTS jazzhands_legacy.v_dns_rvs;
CREATE VIEW jazzhands_legacy.v_dns_rvs AS
 SELECT v_dns_rvs.dns_record_id,
    v_dns_rvs.network_range_id,
    v_dns_rvs.dns_domain_id,
    v_dns_rvs.dns_name,
    v_dns_rvs.dns_ttl,
    v_dns_rvs.dns_class,
    v_dns_rvs.dns_type,
    v_dns_rvs.dns_value,
    v_dns_rvs.dns_priority,
    v_dns_rvs.ip,
    v_dns_rvs.netblock_id,
    v_dns_rvs.ip_universe_id,
    v_dns_rvs.rdns_record_id,
    v_dns_rvs.dns_srv_service,
    v_dns_rvs.dns_srv_protocol,
    v_dns_rvs.dns_srv_weight,
    v_dns_rvs.dns_srv_srv_port,
    v_dns_rvs.is_enabled,
    v_dns_rvs.should_generate_ptr,
    v_dns_rvs.dns_value_record_id
   FROM jazzhands.v_dns_rvs;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_dns_rvs';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_dns_rvs failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_dns_rvs (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_dns_sorted (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_dns_sorted');
DROP VIEW IF EXISTS jazzhands_legacy.v_dns_sorted;
CREATE VIEW jazzhands_legacy.v_dns_sorted AS
 SELECT v_dns_sorted.dns_record_id,
    v_dns_sorted.network_range_id,
    v_dns_sorted.dns_value_record_id,
    v_dns_sorted.dns_name,
    v_dns_sorted.dns_ttl,
    v_dns_sorted.dns_class,
    v_dns_sorted.dns_type,
    v_dns_sorted.dns_value,
    v_dns_sorted.dns_priority,
    v_dns_sorted.ip,
    v_dns_sorted.netblock_id,
    v_dns_sorted.ref_record_id,
    v_dns_sorted.dns_srv_service,
    v_dns_sorted.dns_srv_protocol,
    v_dns_sorted.dns_srv_weight,
    v_dns_sorted.dns_srv_port,
    v_dns_sorted.should_generate_ptr,
    v_dns_sorted.is_enabled,
    v_dns_sorted.dns_domain_id,
    v_dns_sorted.anchor_record_id,
    v_dns_sorted.anchor_rank
   FROM jazzhands.v_dns_sorted;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_dns_sorted';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_dns_sorted failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_dns_sorted (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_hotpants_account_attribute (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_hotpants_account_attribute');
DROP VIEW IF EXISTS jazzhands_legacy.v_hotpants_account_attribute;
CREATE VIEW jazzhands_legacy.v_hotpants_account_attribute AS
 SELECT v_hotpants_account_attribute.property_id,
    v_hotpants_account_attribute.account_id,
    v_hotpants_account_attribute.device_collection_id,
    v_hotpants_account_attribute.login,
    v_hotpants_account_attribute.property_name,
    v_hotpants_account_attribute.property_type,
    v_hotpants_account_attribute.property_value,
    v_hotpants_account_attribute.property_rank,
    v_hotpants_account_attribute.is_boolean
   FROM jazzhands.v_hotpants_account_attribute;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_hotpants_account_attribute';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_hotpants_account_attribute failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_hotpants_account_attribute (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_hotpants_client (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_hotpants_client');
DROP VIEW IF EXISTS jazzhands_legacy.v_hotpants_client;
CREATE VIEW jazzhands_legacy.v_hotpants_client AS
 SELECT v_hotpants_client.device_id,
    v_hotpants_client.device_name,
    v_hotpants_client.ip_address,
    v_hotpants_client.radius_secret
   FROM jazzhands.v_hotpants_client;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_hotpants_client';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_hotpants_client failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_hotpants_client (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_hotpants_dc_attribute (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_hotpants_dc_attribute');
DROP VIEW IF EXISTS jazzhands_legacy.v_hotpants_dc_attribute;
CREATE VIEW jazzhands_legacy.v_hotpants_dc_attribute AS
 SELECT v_hotpants_dc_attribute.property_id,
    v_hotpants_dc_attribute.device_collection_id,
    v_hotpants_dc_attribute.property_name,
    v_hotpants_dc_attribute.property_type,
    v_hotpants_dc_attribute.property_rank,
    v_hotpants_dc_attribute.property_value
   FROM jazzhands.v_hotpants_dc_attribute;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_hotpants_dc_attribute';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_hotpants_dc_attribute failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_hotpants_dc_attribute (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_hotpants_device_collection (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_hotpants_device_collection');
DROP VIEW IF EXISTS jazzhands_legacy.v_hotpants_device_collection;
CREATE VIEW jazzhands_legacy.v_hotpants_device_collection AS
 SELECT v_hotpants_device_collection.device_id,
    v_hotpants_device_collection.device_name,
    v_hotpants_device_collection.device_collection_id,
    v_hotpants_device_collection.device_collection_name,
    v_hotpants_device_collection.device_collection_type,
    v_hotpants_device_collection.ip_address
   FROM jazzhands.v_hotpants_device_collection;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_hotpants_device_collection';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_hotpants_device_collection failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_hotpants_device_collection (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_hotpants_token (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_hotpants_token');
DROP VIEW IF EXISTS jazzhands_legacy.v_hotpants_token;
CREATE VIEW jazzhands_legacy.v_hotpants_token AS
 SELECT v_hotpants_token.token_id,
    v_hotpants_token.token_type,
    v_hotpants_token.token_status,
    v_hotpants_token.token_serial,
    v_hotpants_token.token_key,
    v_hotpants_token.zero_time,
    v_hotpants_token.time_modulo,
    v_hotpants_token.token_password,
    v_hotpants_token.is_token_locked,
    v_hotpants_token.token_unlock_time,
    v_hotpants_token.bad_logins,
    v_hotpants_token.token_sequence,
    v_hotpants_token.last_updated,
    v_hotpants_token.encryption_key_db_value,
    v_hotpants_token.encryption_key_purpose,
    v_hotpants_token.encryption_key_purpose_version,
    v_hotpants_token.encryption_method
   FROM jazzhands.v_hotpants_token;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_hotpants_token';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_hotpants_token failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_hotpants_token (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_l1_all_physical_ports (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_l1_all_physical_ports');
DROP VIEW IF EXISTS jazzhands_legacy.v_l1_all_physical_ports;
CREATE VIEW jazzhands_legacy.v_l1_all_physical_ports AS
 SELECT v_l1_all_physical_ports.layer1_connection_id,
    v_l1_all_physical_ports.physical_port_id,
    v_l1_all_physical_ports.device_id,
    v_l1_all_physical_ports.port_name,
    v_l1_all_physical_ports.port_type,
    v_l1_all_physical_ports.port_purpose,
    v_l1_all_physical_ports.other_physical_port_id,
    v_l1_all_physical_ports.other_device_id,
    v_l1_all_physical_ports.other_port_name,
    v_l1_all_physical_ports.other_port_purpose,
    v_l1_all_physical_ports.baud,
    v_l1_all_physical_ports.data_bits,
    v_l1_all_physical_ports.stop_bits,
    v_l1_all_physical_ports.parity,
    v_l1_all_physical_ports.flow_control
   FROM jazzhands.v_l1_all_physical_ports;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_l1_all_physical_ports';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_l1_all_physical_ports failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_l1_all_physical_ports (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_l2_network_coll_expanded (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_l2_network_coll_expanded');
DROP VIEW IF EXISTS jazzhands_legacy.v_l2_network_coll_expanded;
CREATE VIEW jazzhands_legacy.v_l2_network_coll_expanded AS
 SELECT v_l2_network_coll_expanded.level,
    v_l2_network_coll_expanded.layer2_network_collection_id,
    v_l2_network_coll_expanded.root_l2_network_coll_id,
    v_l2_network_coll_expanded.text_path,
    v_l2_network_coll_expanded.array_path,
    v_l2_network_coll_expanded.rvs_array_path
   FROM jazzhands.v_l2_network_coll_expanded;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_l2_network_coll_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_l2_network_coll_expanded failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_l2_network_coll_expanded (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_l3_network_coll_expanded (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_l3_network_coll_expanded');
DROP VIEW IF EXISTS jazzhands_legacy.v_l3_network_coll_expanded;
CREATE VIEW jazzhands_legacy.v_l3_network_coll_expanded AS
 SELECT v_l3_network_coll_expanded.level,
    v_l3_network_coll_expanded.layer3_network_collection_id,
    v_l3_network_coll_expanded.root_l3_network_coll_id,
    v_l3_network_coll_expanded.text_path,
    v_l3_network_coll_expanded.array_path,
    v_l3_network_coll_expanded.rvs_array_path
   FROM jazzhands.v_l3_network_coll_expanded;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_l3_network_coll_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_l3_network_coll_expanded failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_l3_network_coll_expanded (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_layerx_network_expanded (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_layerx_network_expanded');
DROP VIEW IF EXISTS jazzhands_legacy.v_layerx_network_expanded;
CREATE VIEW jazzhands_legacy.v_layerx_network_expanded AS
 SELECT v_layerx_network_expanded.layer3_network_id,
    v_layerx_network_expanded.layer3_network_description,
    v_layerx_network_expanded.netblock_id,
    v_layerx_network_expanded.ip_address,
    v_layerx_network_expanded.netblock_type,
    v_layerx_network_expanded.ip_universe_id,
    v_layerx_network_expanded.default_gateway_netblock_id,
    v_layerx_network_expanded.default_gateway_ip_address,
    v_layerx_network_expanded.default_gateway_netblock_type,
    v_layerx_network_expanded.default_gateway_ip_universe_id,
    v_layerx_network_expanded.layer2_network_id,
    v_layerx_network_expanded.encapsulation_name,
    v_layerx_network_expanded.encapsulation_domain,
    v_layerx_network_expanded.encapsulation_type,
    v_layerx_network_expanded.encapsulation_tag,
    v_layerx_network_expanded.layer2_network_description
   FROM jazzhands.v_layerx_network_expanded;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_layerx_network_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_layerx_network_expanded failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_layerx_network_expanded (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_lv_hier (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_lv_hier');
DROP VIEW IF EXISTS jazzhands_legacy.v_lv_hier;
CREATE VIEW jazzhands_legacy.v_lv_hier AS
 SELECT v_lv_hier.physicalish_volume_id,
    v_lv_hier.volume_group_id,
    v_lv_hier.logical_volume_id,
    v_lv_hier.child_pv_id,
    v_lv_hier.child_vg_id,
    v_lv_hier.child_lv_id,
    v_lv_hier.pv_path,
    v_lv_hier.vg_path,
    v_lv_hier.lv_path
   FROM jazzhands.v_lv_hier;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_lv_hier';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_lv_hier failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_lv_hier (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_nblk_coll_netblock_expanded (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_nblk_coll_netblock_expanded');
DROP VIEW IF EXISTS jazzhands_legacy.v_nblk_coll_netblock_expanded;
CREATE VIEW jazzhands_legacy.v_nblk_coll_netblock_expanded AS
 SELECT v_nblk_coll_netblock_expanded.netblock_collection_id,
    v_nblk_coll_netblock_expanded.netblock_id
   FROM jazzhands.v_nblk_coll_netblock_expanded;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_nblk_coll_netblock_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_nblk_coll_netblock_expanded failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_nblk_coll_netblock_expanded (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_netblock_coll_expanded (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_netblock_coll_expanded');
DROP VIEW IF EXISTS jazzhands_legacy.v_netblock_coll_expanded;
CREATE VIEW jazzhands_legacy.v_netblock_coll_expanded AS
 SELECT v_netblock_coll_expanded.level,
    v_netblock_coll_expanded.netblock_collection_id,
    v_netblock_coll_expanded.root_netblock_collection_id,
    v_netblock_coll_expanded.text_path,
    v_netblock_coll_expanded.array_path,
    v_netblock_coll_expanded.rvs_array_path
   FROM jazzhands.v_netblock_coll_expanded;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_netblock_coll_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_netblock_coll_expanded failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_netblock_coll_expanded (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_netblock_hier (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_netblock_hier');
DROP VIEW IF EXISTS jazzhands_legacy.v_netblock_hier;
CREATE VIEW jazzhands_legacy.v_netblock_hier AS
 SELECT v_netblock_hier.netblock_level,
    v_netblock_hier.root_netblock_id,
    v_netblock_hier.ip,
    v_netblock_hier.netblock_id,
    v_netblock_hier.ip_address,
    v_netblock_hier.netblock_status,
    v_netblock_hier.is_single_address,
    v_netblock_hier.description,
    v_netblock_hier.parent_netblock_id,
    v_netblock_hier.site_code,
    v_netblock_hier.text_path,
    v_netblock_hier.array_path,
    v_netblock_hier.array_ip_path
   FROM jazzhands.v_netblock_hier;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_netblock_hier';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_netblock_hier failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_netblock_hier (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_network_interface_trans (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_network_interface_trans');
DROP VIEW IF EXISTS jazzhands_legacy.v_network_interface_trans;
CREATE VIEW jazzhands_legacy.v_network_interface_trans AS
 SELECT v_network_interface_trans.network_interface_id,
    v_network_interface_trans.device_id,
    v_network_interface_trans.network_interface_name,
    v_network_interface_trans.description,
    v_network_interface_trans.parent_network_interface_id,
    v_network_interface_trans.parent_relation_type,
    v_network_interface_trans.netblock_id,
    v_network_interface_trans.physical_port_id,
    v_network_interface_trans.slot_id,
    v_network_interface_trans.logical_port_id,
    v_network_interface_trans.network_interface_type,
    v_network_interface_trans.is_interface_up,
    v_network_interface_trans.mac_addr,
    v_network_interface_trans.should_monitor,
    v_network_interface_trans.should_manage,
    v_network_interface_trans.data_ins_user,
    v_network_interface_trans.data_ins_date,
    v_network_interface_trans.data_upd_user,
    v_network_interface_trans.data_upd_date
   FROM jazzhands.v_network_interface_trans;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_network_interface_trans';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_network_interface_trans failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.v_network_interface_trans
	ALTER is_interface_up
	SET DEFAULT 'Y'::text;
ALTER TABLE jazzhands_legacy.v_network_interface_trans
	ALTER should_manage
	SET DEFAULT 'Y'::text;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_network_interface_trans (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_network_range_expanded (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_network_range_expanded');
DROP VIEW IF EXISTS jazzhands_legacy.v_network_range_expanded;
CREATE VIEW jazzhands_legacy.v_network_range_expanded AS
 SELECT v_network_range_expanded.network_range_id,
    v_network_range_expanded.network_range_type,
    v_network_range_expanded.description,
    v_network_range_expanded.parent_netblock_id,
    v_network_range_expanded.ip_address,
    v_network_range_expanded.netblock_type,
    v_network_range_expanded.ip_universe_id,
    v_network_range_expanded.start_netblock_id,
    v_network_range_expanded.start_ip_address,
    v_network_range_expanded.start_netblock_type,
    v_network_range_expanded.start_ip_universe_id,
    v_network_range_expanded.stop_netblock_id,
    v_network_range_expanded.stop_ip_address,
    v_network_range_expanded.stop_netblock_type,
    v_network_range_expanded.stop_ip_universe_id,
    v_network_range_expanded.dns_prefix,
    v_network_range_expanded.dns_domain_id,
    v_network_range_expanded.soa_name
   FROM jazzhands.v_network_range_expanded;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_network_range_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_network_range_expanded failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_network_range_expanded (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_person (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_person');
DROP VIEW IF EXISTS jazzhands_legacy.v_person;
CREATE VIEW jazzhands_legacy.v_person AS
 SELECT v_person.person_id,
    v_person.description,
    v_person.first_name,
    v_person.middle_name,
    v_person.last_name,
    v_person.name_suffix,
    v_person.gender,
    v_person.preferred_first_name,
    v_person.preferred_last_name,
    v_person.legal_first_name,
    v_person.legal_last_name,
    v_person.nickname,
    v_person.birth_date,
    v_person.diet,
    v_person.shirt_size,
    v_person.pant_size,
    v_person.hat_size,
    v_person.data_ins_user,
    v_person.data_ins_date,
    v_person.data_upd_user,
    v_person.data_upd_date
   FROM jazzhands.v_person;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_person';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_person failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_person (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_person_company (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_person_company');
DROP VIEW IF EXISTS jazzhands_legacy.v_person_company;
CREATE VIEW jazzhands_legacy.v_person_company AS
 SELECT v_person_company.company_id,
    v_person_company.person_id,
    v_person_company.person_company_status,
    v_person_company.person_company_relation,
    v_person_company.is_exempt,
    v_person_company.is_management,
    v_person_company.is_full_time,
    v_person_company.description,
    v_person_company.employee_id,
    v_person_company.payroll_id,
    v_person_company.external_hr_id,
    v_person_company.position_title,
    v_person_company.badge_system_id,
    v_person_company.hire_date,
    v_person_company.termination_date,
    v_person_company.manager_person_id,
    v_person_company.supervisor_person_id,
    v_person_company.nickname,
    v_person_company.data_ins_user,
    v_person_company.data_ins_date,
    v_person_company.data_upd_user,
    v_person_company.data_upd_date
   FROM jazzhands.v_person_company;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_person_company';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_person_company failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.v_person_company
	ALTER is_exempt
	SET DEFAULT 'Y'::text;
ALTER TABLE jazzhands_legacy.v_person_company
	ALTER is_management
	SET DEFAULT 'N'::text;
ALTER TABLE jazzhands_legacy.v_person_company
	ALTER is_full_time
	SET DEFAULT 'Y'::text;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_person_company (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_person_company_expanded (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_person_company_expanded');
DROP VIEW IF EXISTS jazzhands_legacy.v_person_company_expanded;
CREATE VIEW jazzhands_legacy.v_person_company_expanded AS
 SELECT v_person_company_expanded.company_id,
    v_person_company_expanded.person_id
   FROM jazzhands.v_person_company_expanded;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_person_company_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_person_company_expanded failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_person_company_expanded (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_person_company_hier (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_person_company_hier');
DROP VIEW IF EXISTS jazzhands_legacy.v_person_company_hier;
CREATE VIEW jazzhands_legacy.v_person_company_hier AS
 SELECT v_person_company_hier.level,
    v_person_company_hier.person_id,
    v_person_company_hier.subordinate_person_id,
    v_person_company_hier.intermediate_person_id,
    v_person_company_hier.person_company_relation,
    v_person_company_hier.array_path,
    v_person_company_hier.rvs_array_path,
    v_person_company_hier.cycle
   FROM jazzhands.v_person_company_hier;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_person_company_hier';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_person_company_hier failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_person_company_hier (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_physical_connection (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_physical_connection');
DROP VIEW IF EXISTS jazzhands_legacy.v_physical_connection;
CREATE VIEW jazzhands_legacy.v_physical_connection AS
 SELECT v_physical_connection.level,
    v_physical_connection.inter_component_connection_id,
    v_physical_connection.layer1_connection_id,
    v_physical_connection.physical_connection_id,
    v_physical_connection.inter_dev_conn_slot1_id,
    v_physical_connection.inter_dev_conn_slot2_id,
    v_physical_connection.layer1_physical_port1_id,
    v_physical_connection.layer1_physical_port2_id,
    v_physical_connection.slot1_id,
    v_physical_connection.slot2_id,
    v_physical_connection.physical_port1_id,
    v_physical_connection.physical_port2_id
   FROM jazzhands.v_physical_connection;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_physical_connection';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_physical_connection failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_physical_connection (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_property (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_property');
DROP VIEW IF EXISTS jazzhands_legacy.v_property;
CREATE VIEW jazzhands_legacy.v_property AS
 SELECT v_property.property_id,
    v_property.account_collection_id,
    v_property.account_id,
    v_property.account_realm_id,
    v_property.company_collection_id,
    v_property.company_id,
    v_property.device_collection_id,
    v_property.dns_domain_collection_id,
    v_property.layer2_network_collection_id,
    v_property.layer3_network_collection_id,
    v_property.netblock_collection_id,
    v_property.network_range_id,
    v_property.operating_system_id,
    v_property.operating_system_snapshot_id,
    v_property.person_id,
    v_property.property_collection_id,
    v_property.service_env_collection_id,
    v_property.site_code,
    v_property.x509_signed_certificate_id,
    v_property.property_name,
    v_property.property_type,
    v_property.property_value,
    v_property.property_value_timestamp,
    v_property.property_value_account_coll_id,
    v_property.property_value_device_coll_id,
    v_property.property_value_json,
    v_property.property_value_nblk_coll_id,
    v_property.property_value_password_type,
    v_property.property_value_person_id,
    v_property.property_value_sw_package_id,
    v_property.property_value_token_col_id,
    v_property.property_rank,
    v_property.start_date,
    v_property.finish_date,
    v_property.is_enabled,
    v_property.data_ins_user,
    v_property.data_ins_date,
    v_property.data_upd_user,
    v_property.data_upd_date
   FROM jazzhands.v_property;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_property';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_property failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_property (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_site_netblock_expanded (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_site_netblock_expanded');
DROP VIEW IF EXISTS jazzhands_legacy.v_site_netblock_expanded;
CREATE VIEW jazzhands_legacy.v_site_netblock_expanded AS
 SELECT v_site_netblock_expanded.site_code,
    v_site_netblock_expanded.netblock_id
   FROM jazzhands.v_site_netblock_expanded;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_site_netblock_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_site_netblock_expanded failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_site_netblock_expanded (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_token (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_token');
DROP VIEW IF EXISTS jazzhands_legacy.v_token;
CREATE VIEW jazzhands_legacy.v_token AS
 SELECT v_token.token_id,
    v_token.token_type,
    v_token.token_status,
    v_token.token_serial,
    v_token.token_sequence,
    v_token.account_id,
    v_token.token_password,
    v_token.zero_time,
    v_token.time_modulo,
    v_token.time_skew,
    v_token.is_token_locked,
    v_token.token_unlock_time,
    v_token.bad_logins,
    v_token.issued_date,
    v_token.token_last_updated,
    v_token.token_sequence_last_updated,
    v_token.lock_status_last_updated
   FROM jazzhands.v_token;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_token';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_token failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_token (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_unix_account_overrides (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_unix_account_overrides');
DROP VIEW IF EXISTS jazzhands_legacy.v_unix_account_overrides;
CREATE VIEW jazzhands_legacy.v_unix_account_overrides AS
 SELECT v_unix_account_overrides.device_collection_id,
    v_unix_account_overrides.account_id,
    v_unix_account_overrides.setting
   FROM jazzhands.v_unix_account_overrides;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_unix_account_overrides';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_unix_account_overrides failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_unix_account_overrides (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_unix_group_mappings (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_unix_group_mappings');
DROP VIEW IF EXISTS jazzhands_legacy.v_unix_group_mappings;
CREATE VIEW jazzhands_legacy.v_unix_group_mappings AS
 SELECT v_unix_group_mappings.device_collection_id,
    v_unix_group_mappings.account_collection_id,
    v_unix_group_mappings.group_name,
    v_unix_group_mappings.unix_gid,
    v_unix_group_mappings.group_password,
    v_unix_group_mappings.setting,
    v_unix_group_mappings.mclass_setting,
    v_unix_group_mappings.members
   FROM jazzhands.v_unix_group_mappings;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_unix_group_mappings';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_unix_group_mappings failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_unix_group_mappings (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_unix_group_overrides (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_unix_group_overrides');
DROP VIEW IF EXISTS jazzhands_legacy.v_unix_group_overrides;
CREATE VIEW jazzhands_legacy.v_unix_group_overrides AS
 SELECT v_unix_group_overrides.device_collection_id,
    v_unix_group_overrides.account_collection_id,
    v_unix_group_overrides.setting
   FROM jazzhands.v_unix_group_overrides;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_unix_group_overrides';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_unix_group_overrides failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_unix_group_overrides (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_unix_mclass_settings (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_unix_mclass_settings');
DROP VIEW IF EXISTS jazzhands_legacy.v_unix_mclass_settings;
CREATE VIEW jazzhands_legacy.v_unix_mclass_settings AS
 SELECT v_unix_mclass_settings.device_collection_id,
    v_unix_mclass_settings.mclass_setting
   FROM jazzhands.v_unix_mclass_settings;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_unix_mclass_settings';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_unix_mclass_settings failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_unix_mclass_settings (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_unix_passwd_mappings (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_unix_passwd_mappings');
DROP VIEW IF EXISTS jazzhands_legacy.v_unix_passwd_mappings;
CREATE VIEW jazzhands_legacy.v_unix_passwd_mappings AS
 SELECT v_unix_passwd_mappings.device_collection_id,
    v_unix_passwd_mappings.account_id,
    v_unix_passwd_mappings.login,
    v_unix_passwd_mappings.crypt,
    v_unix_passwd_mappings.unix_uid,
    v_unix_passwd_mappings.unix_group_name,
    v_unix_passwd_mappings.gecos,
    v_unix_passwd_mappings.home,
    v_unix_passwd_mappings.shell,
    v_unix_passwd_mappings.ssh_public_key,
    v_unix_passwd_mappings.setting,
    v_unix_passwd_mappings.mclass_setting,
    v_unix_passwd_mappings.extra_groups
   FROM jazzhands.v_unix_passwd_mappings;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_unix_passwd_mappings';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_unix_passwd_mappings failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_unix_passwd_mappings (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_account_collection_relatio (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_account_collection_relatio');
DROP VIEW IF EXISTS jazzhands_legacy.val_account_collection_relatio;
CREATE VIEW jazzhands_legacy.val_account_collection_relatio AS
 SELECT val_account_collection_relatio.account_collection_relation,
    val_account_collection_relatio.description,
    val_account_collection_relatio.data_ins_user,
    val_account_collection_relatio.data_ins_date,
    val_account_collection_relatio.data_upd_user,
    val_account_collection_relatio.data_upd_date
   FROM jazzhands.val_account_collection_relatio;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_account_collection_relatio';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_account_collection_relatio failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_account_collection_relatio (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_account_collection_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_account_collection_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_account_collection_type;
CREATE VIEW jazzhands_legacy.val_account_collection_type AS
 SELECT val_account_collection_type.account_collection_type,
    val_account_collection_type.description,
    val_account_collection_type.is_infrastructure_type,
    val_account_collection_type.max_num_members,
    val_account_collection_type.max_num_collections,
    val_account_collection_type.can_have_hierarchy,
    val_account_collection_type.account_realm_id,
    val_account_collection_type.data_ins_user,
    val_account_collection_type.data_ins_date,
    val_account_collection_type.data_upd_user,
    val_account_collection_type.data_upd_date
   FROM jazzhands.val_account_collection_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_account_collection_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_account_collection_type failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.val_account_collection_type
	ALTER is_infrastructure_type
	SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.val_account_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_account_collection_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_account_role (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_account_role');
DROP VIEW IF EXISTS jazzhands_legacy.val_account_role;
CREATE VIEW jazzhands_legacy.val_account_role AS
 SELECT val_account_role.account_role,
    val_account_role.uid_gid_forced,
    val_account_role.description,
    val_account_role.data_ins_user,
    val_account_role.data_ins_date,
    val_account_role.data_upd_user,
    val_account_role.data_upd_date
   FROM jazzhands.val_account_role;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_account_role';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_account_role failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_account_role (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_account_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_account_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_account_type;
CREATE VIEW jazzhands_legacy.val_account_type AS
 SELECT val_account_type.account_type,
    val_account_type.is_person,
    val_account_type.uid_gid_forced,
    val_account_type.description,
    val_account_type.data_ins_user,
    val_account_type.data_ins_date,
    val_account_type.data_upd_user,
    val_account_type.data_upd_date
   FROM jazzhands.val_account_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_account_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_account_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_account_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_app_key (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_app_key');
DROP VIEW IF EXISTS jazzhands_legacy.val_app_key;
CREATE VIEW jazzhands_legacy.val_app_key AS
 SELECT val_app_key.appaal_group_name,
    val_app_key.app_key,
    val_app_key.description,
    val_app_key.data_ins_user,
    val_app_key.data_ins_date,
    val_app_key.data_upd_user,
    val_app_key.data_upd_date
   FROM jazzhands.val_app_key;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_app_key';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_app_key failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_app_key (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_app_key_values (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_app_key_values');
DROP VIEW IF EXISTS jazzhands_legacy.val_app_key_values;
CREATE VIEW jazzhands_legacy.val_app_key_values AS
 SELECT val_app_key_values.appaal_group_name,
    val_app_key_values.app_key,
    val_app_key_values.app_value,
    val_app_key_values.data_ins_user,
    val_app_key_values.data_ins_date,
    val_app_key_values.data_upd_user,
    val_app_key_values.data_upd_date
   FROM jazzhands.val_app_key_values;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_app_key_values';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_app_key_values failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_app_key_values (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_appaal_group_name (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_appaal_group_name');
DROP VIEW IF EXISTS jazzhands_legacy.val_appaal_group_name;
CREATE VIEW jazzhands_legacy.val_appaal_group_name AS
 SELECT val_appaal_group_name.appaal_group_name,
    val_appaal_group_name.description,
    val_appaal_group_name.data_ins_user,
    val_appaal_group_name.data_ins_date,
    val_appaal_group_name.data_upd_user,
    val_appaal_group_name.data_upd_date
   FROM jazzhands.val_appaal_group_name;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_appaal_group_name';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_appaal_group_name failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_appaal_group_name (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_approval_chain_resp_prd (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_approval_chain_resp_prd');
DROP VIEW IF EXISTS jazzhands_legacy.val_approval_chain_resp_prd;
CREATE VIEW jazzhands_legacy.val_approval_chain_resp_prd AS
 SELECT val_approval_chain_resp_prd.approval_chain_response_period,
    val_approval_chain_resp_prd.description,
    val_approval_chain_resp_prd.data_ins_user,
    val_approval_chain_resp_prd.data_ins_date,
    val_approval_chain_resp_prd.data_upd_user,
    val_approval_chain_resp_prd.data_upd_date
   FROM jazzhands.val_approval_chain_resp_prd;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_approval_chain_resp_prd';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_approval_chain_resp_prd failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_approval_chain_resp_prd (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_approval_expiration_action (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_approval_expiration_action');
DROP VIEW IF EXISTS jazzhands_legacy.val_approval_expiration_action;
CREATE VIEW jazzhands_legacy.val_approval_expiration_action AS
 SELECT val_approval_expiration_action.approval_expiration_action,
    val_approval_expiration_action.description,
    val_approval_expiration_action.data_ins_user,
    val_approval_expiration_action.data_ins_date,
    val_approval_expiration_action.data_upd_user,
    val_approval_expiration_action.data_upd_date
   FROM jazzhands.val_approval_expiration_action;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_approval_expiration_action';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_approval_expiration_action failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_approval_expiration_action (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_approval_notifty_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_approval_notifty_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_approval_notifty_type;
CREATE VIEW jazzhands_legacy.val_approval_notifty_type AS
 SELECT val_approval_notifty_type.approval_notify_type,
    val_approval_notifty_type.description,
    val_approval_notifty_type.data_ins_user,
    val_approval_notifty_type.data_ins_date,
    val_approval_notifty_type.data_upd_user,
    val_approval_notifty_type.data_upd_date
   FROM jazzhands.val_approval_notifty_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_approval_notifty_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_approval_notifty_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_approval_notifty_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_approval_process_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_approval_process_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_approval_process_type;
CREATE VIEW jazzhands_legacy.val_approval_process_type AS
 SELECT val_approval_process_type.approval_process_type,
    val_approval_process_type.description,
    val_approval_process_type.data_ins_user,
    val_approval_process_type.data_ins_date,
    val_approval_process_type.data_upd_user,
    val_approval_process_type.data_upd_date
   FROM jazzhands.val_approval_process_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_approval_process_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_approval_process_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_approval_process_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_approval_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_approval_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_approval_type;
CREATE VIEW jazzhands_legacy.val_approval_type AS
 SELECT val_approval_type.approval_type,
    val_approval_type.description,
    val_approval_type.data_ins_user,
    val_approval_type.data_ins_date,
    val_approval_type.data_upd_user,
    val_approval_type.data_upd_date
   FROM jazzhands.val_approval_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_approval_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_approval_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_approval_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_attestation_frequency (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_attestation_frequency');
DROP VIEW IF EXISTS jazzhands_legacy.val_attestation_frequency;
CREATE VIEW jazzhands_legacy.val_attestation_frequency AS
 SELECT val_attestation_frequency.attestation_frequency,
    val_attestation_frequency.description,
    val_attestation_frequency.data_ins_user,
    val_attestation_frequency.data_ins_date,
    val_attestation_frequency.data_upd_user,
    val_attestation_frequency.data_upd_date
   FROM jazzhands.val_attestation_frequency;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_attestation_frequency';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_attestation_frequency failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_attestation_frequency (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_auth_question (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_auth_question');
DROP VIEW IF EXISTS jazzhands_legacy.val_auth_question;
CREATE VIEW jazzhands_legacy.val_auth_question AS
 SELECT val_auth_question.auth_question_id,
    val_auth_question.question_text,
    val_auth_question.data_ins_user,
    val_auth_question.data_ins_date,
    val_auth_question.data_upd_user,
    val_auth_question.data_upd_date
   FROM jazzhands.val_auth_question;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_auth_question';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_auth_question failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_auth_question (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_auth_resource (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_auth_resource');
DROP VIEW IF EXISTS jazzhands_legacy.val_auth_resource;
CREATE VIEW jazzhands_legacy.val_auth_resource AS
 SELECT val_auth_resource.auth_resource,
    val_auth_resource.description,
    val_auth_resource.data_ins_user,
    val_auth_resource.data_ins_date,
    val_auth_resource.data_upd_user,
    val_auth_resource.data_upd_date
   FROM jazzhands.val_auth_resource;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_auth_resource';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_auth_resource failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_auth_resource (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_badge_status (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_badge_status');
DROP VIEW IF EXISTS jazzhands_legacy.val_badge_status;
CREATE VIEW jazzhands_legacy.val_badge_status AS
 SELECT val_badge_status.badge_status,
    val_badge_status.description,
    val_badge_status.data_ins_user,
    val_badge_status.data_ins_date,
    val_badge_status.data_upd_user,
    val_badge_status.data_upd_date
   FROM jazzhands.val_badge_status;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_badge_status';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_badge_status failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_badge_status (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_cable_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_cable_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_cable_type;
CREATE VIEW jazzhands_legacy.val_cable_type AS
 SELECT val_cable_type.cable_type,
    val_cable_type.description,
    val_cable_type.data_ins_user,
    val_cable_type.data_ins_date,
    val_cable_type.data_upd_user,
    val_cable_type.data_upd_date
   FROM jazzhands.val_cable_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_cable_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_cable_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_cable_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_company_collection_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_company_collection_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_company_collection_type;
CREATE VIEW jazzhands_legacy.val_company_collection_type AS
 SELECT val_company_collection_type.company_collection_type,
    val_company_collection_type.description,
    val_company_collection_type.is_infrastructure_type,
    val_company_collection_type.max_num_members,
    val_company_collection_type.max_num_collections,
    val_company_collection_type.can_have_hierarchy,
    val_company_collection_type.data_ins_user,
    val_company_collection_type.data_ins_date,
    val_company_collection_type.data_upd_user,
    val_company_collection_type.data_upd_date
   FROM jazzhands.val_company_collection_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_company_collection_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_company_collection_type failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.val_company_collection_type
	ALTER is_infrastructure_type
	SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.val_company_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_company_collection_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_company_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_company_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_company_type;
CREATE VIEW jazzhands_legacy.val_company_type AS
 SELECT val_company_type.company_type,
    val_company_type.description,
    val_company_type.company_type_purpose,
    val_company_type.data_ins_user,
    val_company_type.data_ins_date,
    val_company_type.data_upd_user,
    val_company_type.data_upd_date
   FROM jazzhands.val_company_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_company_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_company_type failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.val_company_type
	ALTER company_type_purpose
	SET DEFAULT 'default'::character varying;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_company_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_company_type_purpose (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_company_type_purpose');
DROP VIEW IF EXISTS jazzhands_legacy.val_company_type_purpose;
CREATE VIEW jazzhands_legacy.val_company_type_purpose AS
 SELECT val_company_type_purpose.company_type_purpose,
    val_company_type_purpose.description,
    val_company_type_purpose.data_ins_user,
    val_company_type_purpose.data_ins_date,
    val_company_type_purpose.data_upd_user,
    val_company_type_purpose.data_upd_date
   FROM jazzhands.val_company_type_purpose;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_company_type_purpose';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_company_type_purpose failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_company_type_purpose (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_component_function (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_component_function');
DROP VIEW IF EXISTS jazzhands_legacy.val_component_function;
CREATE VIEW jazzhands_legacy.val_component_function AS
 SELECT val_component_function.component_function,
    val_component_function.description,
    val_component_function.data_ins_user,
    val_component_function.data_ins_date,
    val_component_function.data_upd_user,
    val_component_function.data_upd_date
   FROM jazzhands.val_component_function;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_component_function';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_component_function failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_component_function (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_component_property (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_component_property');
DROP VIEW IF EXISTS jazzhands_legacy.val_component_property;
CREATE VIEW jazzhands_legacy.val_component_property AS
 SELECT val_component_property.component_property_name,
    val_component_property.component_property_type,
    val_component_property.description,
    val_component_property.is_multivalue,
    val_component_property.property_data_type,
    val_component_property.permit_component_type_id,
    val_component_property.required_component_type_id,
    val_component_property.permit_component_function,
    val_component_property.required_component_function,
    val_component_property.permit_component_id,
    val_component_property.permit_intcomp_conn_id,
    val_component_property.permit_slot_type_id,
    val_component_property.required_slot_type_id,
    val_component_property.permit_slot_function,
    val_component_property.required_slot_function,
    val_component_property.permit_slot_id,
    val_component_property.data_ins_user,
    val_component_property.data_ins_date,
    val_component_property.data_upd_user,
    val_component_property.data_upd_date
   FROM jazzhands.val_component_property;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_component_property';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_component_property failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.val_component_property
	ALTER permit_component_type_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_component_property
	ALTER permit_component_function
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_component_property
	ALTER permit_component_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_component_property
	ALTER permit_intcomp_conn_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_component_property
	ALTER permit_slot_type_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_component_property
	ALTER permit_slot_function
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_component_property
	ALTER permit_slot_id
	SET DEFAULT 'PROHIBITED'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_component_property (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_component_property_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_component_property_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_component_property_type;
CREATE VIEW jazzhands_legacy.val_component_property_type AS
 SELECT val_component_property_type.component_property_type,
    val_component_property_type.description,
    val_component_property_type.is_multivalue,
    val_component_property_type.data_ins_user,
    val_component_property_type.data_ins_date,
    val_component_property_type.data_upd_user,
    val_component_property_type.data_upd_date
   FROM jazzhands.val_component_property_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_component_property_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_component_property_type failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.val_component_property_type
	ALTER is_multivalue
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_component_property_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_component_property_value (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_component_property_value');
DROP VIEW IF EXISTS jazzhands_legacy.val_component_property_value;
CREATE VIEW jazzhands_legacy.val_component_property_value AS
 SELECT val_component_property_value.component_property_name,
    val_component_property_value.component_property_type,
    val_component_property_value.valid_property_value,
    val_component_property_value.description,
    val_component_property_value.data_ins_user,
    val_component_property_value.data_ins_date,
    val_component_property_value.data_upd_user,
    val_component_property_value.data_upd_date
   FROM jazzhands.val_component_property_value;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_component_property_value';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_component_property_value failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_component_property_value (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_contract_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_contract_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_contract_type;
CREATE VIEW jazzhands_legacy.val_contract_type AS
 SELECT val_contract_type.contract_type,
    val_contract_type.description,
    val_contract_type.data_ins_user,
    val_contract_type.data_ins_date,
    val_contract_type.data_upd_user,
    val_contract_type.data_upd_date
   FROM jazzhands.val_contract_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_contract_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_contract_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_contract_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_country_code (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_country_code');
DROP VIEW IF EXISTS jazzhands_legacy.val_country_code;
CREATE VIEW jazzhands_legacy.val_country_code AS
 SELECT val_country_code.iso_country_code,
    val_country_code.dial_country_code,
    val_country_code.primary_iso_currency_code,
    val_country_code.country_name,
    val_country_code.display_priority,
    val_country_code.data_ins_user,
    val_country_code.data_ins_date,
    val_country_code.data_upd_user,
    val_country_code.data_upd_date
   FROM jazzhands.val_country_code;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_country_code';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_country_code failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_country_code (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_device_auto_mgmt_protocol (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_device_auto_mgmt_protocol');
DROP VIEW IF EXISTS jazzhands_legacy.val_device_auto_mgmt_protocol;
CREATE VIEW jazzhands_legacy.val_device_auto_mgmt_protocol AS
 SELECT val_device_auto_mgmt_protocol.auto_mgmt_protocol,
    val_device_auto_mgmt_protocol.connection_port,
    val_device_auto_mgmt_protocol.description,
    val_device_auto_mgmt_protocol.data_ins_user,
    val_device_auto_mgmt_protocol.data_ins_date,
    val_device_auto_mgmt_protocol.data_upd_user,
    val_device_auto_mgmt_protocol.data_upd_date
   FROM jazzhands.val_device_auto_mgmt_protocol;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_device_auto_mgmt_protocol';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_device_auto_mgmt_protocol failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_device_auto_mgmt_protocol (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_device_collection_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_device_collection_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_device_collection_type;
CREATE VIEW jazzhands_legacy.val_device_collection_type AS
 SELECT val_device_collection_type.device_collection_type,
    val_device_collection_type.description,
    val_device_collection_type.max_num_members,
    val_device_collection_type.max_num_collections,
    val_device_collection_type.can_have_hierarchy,
    val_device_collection_type.data_ins_user,
    val_device_collection_type.data_ins_date,
    val_device_collection_type.data_upd_user,
    val_device_collection_type.data_upd_date
   FROM jazzhands.val_device_collection_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_device_collection_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_device_collection_type failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.val_device_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_device_collection_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_device_mgmt_ctrl_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_device_mgmt_ctrl_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_device_mgmt_ctrl_type;
CREATE VIEW jazzhands_legacy.val_device_mgmt_ctrl_type AS
 SELECT val_device_mgmt_ctrl_type.device_mgmt_control_type,
    val_device_mgmt_ctrl_type.description,
    val_device_mgmt_ctrl_type.data_ins_user,
    val_device_mgmt_ctrl_type.data_ins_date,
    val_device_mgmt_ctrl_type.data_upd_user,
    val_device_mgmt_ctrl_type.data_upd_date
   FROM jazzhands.val_device_mgmt_ctrl_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_device_mgmt_ctrl_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_device_mgmt_ctrl_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_device_mgmt_ctrl_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_device_status (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_device_status');
DROP VIEW IF EXISTS jazzhands_legacy.val_device_status;
CREATE VIEW jazzhands_legacy.val_device_status AS
 SELECT val_device_status.device_status,
    val_device_status.description,
    val_device_status.data_ins_user,
    val_device_status.data_ins_date,
    val_device_status.data_upd_user,
    val_device_status.data_upd_date
   FROM jazzhands.val_device_status;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_device_status';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_device_status failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_device_status (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_diet (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_diet');
DROP VIEW IF EXISTS jazzhands_legacy.val_diet;
CREATE VIEW jazzhands_legacy.val_diet AS
 SELECT val_diet.diet,
    val_diet.data_ins_user,
    val_diet.data_ins_date,
    val_diet.data_upd_user,
    val_diet.data_upd_date
   FROM jazzhands.val_diet;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_diet';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_diet failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_diet (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_dns_class (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_dns_class');
DROP VIEW IF EXISTS jazzhands_legacy.val_dns_class;
CREATE VIEW jazzhands_legacy.val_dns_class AS
 SELECT val_dns_class.dns_class,
    val_dns_class.description,
    val_dns_class.data_ins_user,
    val_dns_class.data_ins_date,
    val_dns_class.data_upd_user,
    val_dns_class.data_upd_date
   FROM jazzhands.val_dns_class;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_dns_class';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_dns_class failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_dns_class (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_dns_domain_collection_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_dns_domain_collection_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_dns_domain_collection_type;
CREATE VIEW jazzhands_legacy.val_dns_domain_collection_type AS
 SELECT val_dns_domain_collection_type.dns_domain_collection_type,
    val_dns_domain_collection_type.description,
    val_dns_domain_collection_type.max_num_members,
    val_dns_domain_collection_type.max_num_collections,
    val_dns_domain_collection_type.can_have_hierarchy,
    val_dns_domain_collection_type.data_ins_user,
    val_dns_domain_collection_type.data_ins_date,
    val_dns_domain_collection_type.data_upd_user,
    val_dns_domain_collection_type.data_upd_date
   FROM jazzhands.val_dns_domain_collection_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_dns_domain_collection_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_dns_domain_collection_type failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.val_dns_domain_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_dns_domain_collection_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_dns_domain_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_dns_domain_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_dns_domain_type;
CREATE VIEW jazzhands_legacy.val_dns_domain_type AS
 SELECT val_dns_domain_type.dns_domain_type,
    val_dns_domain_type.can_generate,
    val_dns_domain_type.description,
    val_dns_domain_type.data_ins_user,
    val_dns_domain_type.data_ins_date,
    val_dns_domain_type.data_upd_user,
    val_dns_domain_type.data_upd_date
   FROM jazzhands.val_dns_domain_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_dns_domain_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_dns_domain_type failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.val_dns_domain_type
	ALTER can_generate
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_dns_domain_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_dns_record_relation_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_dns_record_relation_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_dns_record_relation_type;
CREATE VIEW jazzhands_legacy.val_dns_record_relation_type AS
 SELECT val_dns_record_relation_type.dns_record_relation_type,
    val_dns_record_relation_type.description,
    val_dns_record_relation_type.data_ins_user,
    val_dns_record_relation_type.data_ins_date,
    val_dns_record_relation_type.data_upd_user,
    val_dns_record_relation_type.data_upd_date
   FROM jazzhands.val_dns_record_relation_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_dns_record_relation_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_dns_record_relation_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_dns_record_relation_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_dns_srv_service (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_dns_srv_service');
DROP VIEW IF EXISTS jazzhands_legacy.val_dns_srv_service;
CREATE VIEW jazzhands_legacy.val_dns_srv_service AS
 SELECT val_dns_srv_service.dns_srv_service,
    val_dns_srv_service.description,
    val_dns_srv_service.data_ins_user,
    val_dns_srv_service.data_ins_date,
    val_dns_srv_service.data_upd_user,
    val_dns_srv_service.data_upd_date
   FROM jazzhands.val_dns_srv_service;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_dns_srv_service';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_dns_srv_service failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_dns_srv_service (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_dns_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_dns_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_dns_type;
CREATE VIEW jazzhands_legacy.val_dns_type AS
 SELECT val_dns_type.dns_type,
    val_dns_type.description,
    val_dns_type.id_type,
    val_dns_type.data_ins_user,
    val_dns_type.data_ins_date,
    val_dns_type.data_upd_user,
    val_dns_type.data_upd_date
   FROM jazzhands.val_dns_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_dns_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_dns_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_dns_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_encapsulation_mode (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_encapsulation_mode');
DROP VIEW IF EXISTS jazzhands_legacy.val_encapsulation_mode;
CREATE VIEW jazzhands_legacy.val_encapsulation_mode AS
 SELECT val_encapsulation_mode.encapsulation_mode,
    val_encapsulation_mode.encapsulation_type,
    val_encapsulation_mode.description,
    val_encapsulation_mode.data_ins_user,
    val_encapsulation_mode.data_ins_date,
    val_encapsulation_mode.data_upd_user,
    val_encapsulation_mode.data_upd_date
   FROM jazzhands.val_encapsulation_mode;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_encapsulation_mode';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_encapsulation_mode failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_encapsulation_mode (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_encapsulation_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_encapsulation_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_encapsulation_type;
CREATE VIEW jazzhands_legacy.val_encapsulation_type AS
 SELECT val_encapsulation_type.encapsulation_type,
    val_encapsulation_type.description,
    val_encapsulation_type.data_ins_user,
    val_encapsulation_type.data_ins_date,
    val_encapsulation_type.data_upd_user,
    val_encapsulation_type.data_upd_date
   FROM jazzhands.val_encapsulation_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_encapsulation_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_encapsulation_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_encapsulation_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_encryption_key_purpose (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_encryption_key_purpose');
DROP VIEW IF EXISTS jazzhands_legacy.val_encryption_key_purpose;
CREATE VIEW jazzhands_legacy.val_encryption_key_purpose AS
 SELECT val_encryption_key_purpose.encryption_key_purpose,
    val_encryption_key_purpose.encryption_key_purpose_version,
    val_encryption_key_purpose.description,
    val_encryption_key_purpose.data_ins_user,
    val_encryption_key_purpose.data_ins_date,
    val_encryption_key_purpose.data_upd_user,
    val_encryption_key_purpose.data_upd_date
   FROM jazzhands.val_encryption_key_purpose;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_encryption_key_purpose';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_encryption_key_purpose failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_encryption_key_purpose (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_encryption_method (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_encryption_method');
DROP VIEW IF EXISTS jazzhands_legacy.val_encryption_method;
CREATE VIEW jazzhands_legacy.val_encryption_method AS
 SELECT val_encryption_method.encryption_method,
    val_encryption_method.description,
    val_encryption_method.data_ins_user,
    val_encryption_method.data_ins_date,
    val_encryption_method.data_upd_user,
    val_encryption_method.data_upd_date
   FROM jazzhands.val_encryption_method;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_encryption_method';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_encryption_method failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_encryption_method (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_filesystem_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_filesystem_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_filesystem_type;
CREATE VIEW jazzhands_legacy.val_filesystem_type AS
 SELECT val_filesystem_type.filesystem_type,
    val_filesystem_type.description,
    val_filesystem_type.data_ins_user,
    val_filesystem_type.data_ins_date,
    val_filesystem_type.data_upd_user,
    val_filesystem_type.data_upd_date
   FROM jazzhands.val_filesystem_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_filesystem_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_filesystem_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_filesystem_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_image_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_image_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_image_type;
CREATE VIEW jazzhands_legacy.val_image_type AS
 SELECT val_image_type.image_type,
    val_image_type.description,
    val_image_type.data_ins_user,
    val_image_type.data_ins_date,
    val_image_type.data_upd_user,
    val_image_type.data_upd_date
   FROM jazzhands.val_image_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_image_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_image_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_image_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_ip_namespace (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_ip_namespace');
DROP VIEW IF EXISTS jazzhands_legacy.val_ip_namespace;
CREATE VIEW jazzhands_legacy.val_ip_namespace AS
 SELECT val_ip_namespace.ip_namespace,
    val_ip_namespace.description,
    val_ip_namespace.data_ins_user,
    val_ip_namespace.data_ins_date,
    val_ip_namespace.data_upd_user,
    val_ip_namespace.data_upd_date
   FROM jazzhands.val_ip_namespace;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_ip_namespace';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_ip_namespace failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_ip_namespace (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_iso_currency_code (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_iso_currency_code');
DROP VIEW IF EXISTS jazzhands_legacy.val_iso_currency_code;
CREATE VIEW jazzhands_legacy.val_iso_currency_code AS
 SELECT val_iso_currency_code.iso_currency_code,
    val_iso_currency_code.description,
    val_iso_currency_code.currency_symbol,
    val_iso_currency_code.data_ins_user,
    val_iso_currency_code.data_ins_date,
    val_iso_currency_code.data_upd_user,
    val_iso_currency_code.data_upd_date
   FROM jazzhands.val_iso_currency_code;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_iso_currency_code';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_iso_currency_code failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_iso_currency_code (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_key_usg_reason_for_assgn (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_key_usg_reason_for_assgn');
DROP VIEW IF EXISTS jazzhands_legacy.val_key_usg_reason_for_assgn;
CREATE VIEW jazzhands_legacy.val_key_usg_reason_for_assgn AS
 SELECT val_key_usg_reason_for_assgn.key_usage_reason_for_assign,
    val_key_usg_reason_for_assgn.description,
    val_key_usg_reason_for_assgn.data_ins_user,
    val_key_usg_reason_for_assgn.data_ins_date,
    val_key_usg_reason_for_assgn.data_upd_user,
    val_key_usg_reason_for_assgn.data_upd_date
   FROM jazzhands.val_key_usg_reason_for_assgn;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_key_usg_reason_for_assgn';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_key_usg_reason_for_assgn failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_key_usg_reason_for_assgn (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_layer2_network_coll_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_layer2_network_coll_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_layer2_network_coll_type;
CREATE VIEW jazzhands_legacy.val_layer2_network_coll_type AS
 SELECT val_layer2_network_coll_type.layer2_network_collection_type,
    val_layer2_network_coll_type.description,
    val_layer2_network_coll_type.max_num_members,
    val_layer2_network_coll_type.max_num_collections,
    val_layer2_network_coll_type.can_have_hierarchy,
    val_layer2_network_coll_type.data_ins_user,
    val_layer2_network_coll_type.data_ins_date,
    val_layer2_network_coll_type.data_upd_user,
    val_layer2_network_coll_type.data_upd_date
   FROM jazzhands.val_layer2_network_coll_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_layer2_network_coll_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_layer2_network_coll_type failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.val_layer2_network_coll_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_layer2_network_coll_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_layer3_network_coll_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_layer3_network_coll_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_layer3_network_coll_type;
CREATE VIEW jazzhands_legacy.val_layer3_network_coll_type AS
 SELECT val_layer3_network_coll_type.layer3_network_collection_type,
    val_layer3_network_coll_type.description,
    val_layer3_network_coll_type.max_num_members,
    val_layer3_network_coll_type.max_num_collections,
    val_layer3_network_coll_type.can_have_hierarchy,
    val_layer3_network_coll_type.data_ins_user,
    val_layer3_network_coll_type.data_ins_date,
    val_layer3_network_coll_type.data_upd_user,
    val_layer3_network_coll_type.data_upd_date
   FROM jazzhands.val_layer3_network_coll_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_layer3_network_coll_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_layer3_network_coll_type failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.val_layer3_network_coll_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_layer3_network_coll_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_logical_port_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_logical_port_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_logical_port_type;
CREATE VIEW jazzhands_legacy.val_logical_port_type AS
 SELECT val_logical_port_type.logical_port_type,
    val_logical_port_type.description,
    val_logical_port_type.data_ins_user,
    val_logical_port_type.data_ins_date,
    val_logical_port_type.data_upd_user,
    val_logical_port_type.data_upd_date
   FROM jazzhands.val_logical_port_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_logical_port_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_logical_port_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_logical_port_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_logical_volume_property (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_logical_volume_property');
DROP VIEW IF EXISTS jazzhands_legacy.val_logical_volume_property;
CREATE VIEW jazzhands_legacy.val_logical_volume_property AS
 SELECT val_logical_volume_property.logical_volume_property_name,
    val_logical_volume_property.filesystem_type,
    val_logical_volume_property.description,
    val_logical_volume_property.data_ins_user,
    val_logical_volume_property.data_ins_date,
    val_logical_volume_property.data_upd_user,
    val_logical_volume_property.data_upd_date
   FROM jazzhands.val_logical_volume_property;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_logical_volume_property';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_logical_volume_property failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_logical_volume_property (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_logical_volume_purpose (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_logical_volume_purpose');
DROP VIEW IF EXISTS jazzhands_legacy.val_logical_volume_purpose;
CREATE VIEW jazzhands_legacy.val_logical_volume_purpose AS
 SELECT val_logical_volume_purpose.logical_volume_purpose,
    val_logical_volume_purpose.description,
    val_logical_volume_purpose.data_ins_user,
    val_logical_volume_purpose.data_ins_date,
    val_logical_volume_purpose.data_upd_user,
    val_logical_volume_purpose.data_upd_date
   FROM jazzhands.val_logical_volume_purpose;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_logical_volume_purpose';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_logical_volume_purpose failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_logical_volume_purpose (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_logical_volume_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_logical_volume_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_logical_volume_type;
CREATE VIEW jazzhands_legacy.val_logical_volume_type AS
 SELECT val_logical_volume_type.logical_volume_type,
    val_logical_volume_type.description,
    val_logical_volume_type.data_ins_user,
    val_logical_volume_type.data_ins_date,
    val_logical_volume_type.data_upd_user,
    val_logical_volume_type.data_upd_date
   FROM jazzhands.val_logical_volume_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_logical_volume_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_logical_volume_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_logical_volume_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_netblock_collection_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_netblock_collection_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_netblock_collection_type;
CREATE VIEW jazzhands_legacy.val_netblock_collection_type AS
 SELECT val_netblock_collection_type.netblock_collection_type,
    val_netblock_collection_type.description,
    val_netblock_collection_type.max_num_members,
    val_netblock_collection_type.max_num_collections,
    val_netblock_collection_type.can_have_hierarchy,
    val_netblock_collection_type.netblock_single_addr_restrict,
    val_netblock_collection_type.netblock_ip_family_restrict,
    val_netblock_collection_type.data_ins_user,
    val_netblock_collection_type.data_ins_date,
    val_netblock_collection_type.data_upd_user,
    val_netblock_collection_type.data_upd_date
   FROM jazzhands.val_netblock_collection_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_netblock_collection_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_netblock_collection_type failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.val_netblock_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE jazzhands_legacy.val_netblock_collection_type
	ALTER netblock_single_addr_restrict
	SET DEFAULT 'ANY'::character varying;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_netblock_collection_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_netblock_status (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_netblock_status');
DROP VIEW IF EXISTS jazzhands_legacy.val_netblock_status;
CREATE VIEW jazzhands_legacy.val_netblock_status AS
 SELECT val_netblock_status.netblock_status,
    val_netblock_status.description,
    val_netblock_status.data_ins_user,
    val_netblock_status.data_ins_date,
    val_netblock_status.data_upd_user,
    val_netblock_status.data_upd_date
   FROM jazzhands.val_netblock_status;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_netblock_status';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_netblock_status failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_netblock_status (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_netblock_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_netblock_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_netblock_type;
CREATE VIEW jazzhands_legacy.val_netblock_type AS
 SELECT val_netblock_type.netblock_type,
    val_netblock_type.description,
    val_netblock_type.db_forced_hierarchy,
    val_netblock_type.is_validated_hierarchy,
    val_netblock_type.data_ins_user,
    val_netblock_type.data_ins_date,
    val_netblock_type.data_upd_user,
    val_netblock_type.data_upd_date
   FROM jazzhands.val_netblock_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_netblock_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_netblock_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_netblock_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_network_interface_purpose (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_network_interface_purpose');
DROP VIEW IF EXISTS jazzhands_legacy.val_network_interface_purpose;
CREATE VIEW jazzhands_legacy.val_network_interface_purpose AS
 SELECT val_network_interface_purpose.network_interface_purpose,
    val_network_interface_purpose.description,
    val_network_interface_purpose.data_ins_user,
    val_network_interface_purpose.data_ins_date,
    val_network_interface_purpose.data_upd_user,
    val_network_interface_purpose.data_upd_date
   FROM jazzhands.val_network_interface_purpose;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_network_interface_purpose';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_network_interface_purpose failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_network_interface_purpose (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_network_interface_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_network_interface_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_network_interface_type;
CREATE VIEW jazzhands_legacy.val_network_interface_type AS
 SELECT val_network_interface_type.network_interface_type,
    val_network_interface_type.description,
    val_network_interface_type.data_ins_user,
    val_network_interface_type.data_ins_date,
    val_network_interface_type.data_upd_user,
    val_network_interface_type.data_upd_date
   FROM jazzhands.val_network_interface_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_network_interface_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_network_interface_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_network_interface_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_network_range_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_network_range_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_network_range_type;
CREATE VIEW jazzhands_legacy.val_network_range_type AS
 SELECT val_network_range_type.network_range_type,
    val_network_range_type.description,
    val_network_range_type.dns_domain_required,
    val_network_range_type.default_dns_prefix,
    val_network_range_type.netblock_type,
    val_network_range_type.can_overlap,
    val_network_range_type.require_cidr_boundary,
    val_network_range_type.data_ins_user,
    val_network_range_type.data_ins_date,
    val_network_range_type.data_upd_user,
    val_network_range_type.data_upd_date
   FROM jazzhands.val_network_range_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_network_range_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_network_range_type failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.val_network_range_type
	ALTER dns_domain_required
	SET DEFAULT 'REQUIRED'::bpchar;
ALTER TABLE jazzhands_legacy.val_network_range_type
	ALTER can_overlap
	SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.val_network_range_type
	ALTER require_cidr_boundary
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_network_range_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_network_service_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_network_service_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_network_service_type;
CREATE VIEW jazzhands_legacy.val_network_service_type AS
 SELECT val_network_service_type.network_service_type,
    val_network_service_type.description,
    val_network_service_type.data_ins_user,
    val_network_service_type.data_ins_date,
    val_network_service_type.data_upd_user,
    val_network_service_type.data_upd_date
   FROM jazzhands.val_network_service_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_network_service_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_network_service_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_network_service_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_operating_system_family (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_operating_system_family');
DROP VIEW IF EXISTS jazzhands_legacy.val_operating_system_family;
CREATE VIEW jazzhands_legacy.val_operating_system_family AS
 SELECT val_operating_system_family.operating_system_family,
    val_operating_system_family.description,
    val_operating_system_family.data_ins_user,
    val_operating_system_family.data_ins_date,
    val_operating_system_family.data_upd_user,
    val_operating_system_family.data_upd_date
   FROM jazzhands.val_operating_system_family;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_operating_system_family';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_operating_system_family failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_operating_system_family (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_os_snapshot_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_os_snapshot_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_os_snapshot_type;
CREATE VIEW jazzhands_legacy.val_os_snapshot_type AS
 SELECT val_os_snapshot_type.operating_system_snapshot_type,
    val_os_snapshot_type.description,
    val_os_snapshot_type.data_ins_user,
    val_os_snapshot_type.data_ins_date,
    val_os_snapshot_type.data_upd_user,
    val_os_snapshot_type.data_upd_date
   FROM jazzhands.val_os_snapshot_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_os_snapshot_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_os_snapshot_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_os_snapshot_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_ownership_status (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_ownership_status');
DROP VIEW IF EXISTS jazzhands_legacy.val_ownership_status;
CREATE VIEW jazzhands_legacy.val_ownership_status AS
 SELECT val_ownership_status.ownership_status,
    val_ownership_status.description,
    val_ownership_status.data_ins_user,
    val_ownership_status.data_ins_date,
    val_ownership_status.data_upd_user,
    val_ownership_status.data_upd_date
   FROM jazzhands.val_ownership_status;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_ownership_status';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_ownership_status failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_ownership_status (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_package_relation_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_package_relation_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_package_relation_type;
CREATE VIEW jazzhands_legacy.val_package_relation_type AS
 SELECT val_package_relation_type.package_relation_type,
    val_package_relation_type.description,
    val_package_relation_type.data_ins_user,
    val_package_relation_type.data_ins_date,
    val_package_relation_type.data_upd_user,
    val_package_relation_type.data_upd_date
   FROM jazzhands.val_package_relation_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_package_relation_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_package_relation_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_package_relation_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_password_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_password_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_password_type;
CREATE VIEW jazzhands_legacy.val_password_type AS
 SELECT val_password_type.password_type,
    val_password_type.description,
    val_password_type.data_ins_user,
    val_password_type.data_ins_date,
    val_password_type.data_upd_user,
    val_password_type.data_upd_date
   FROM jazzhands.val_password_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_password_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_password_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_password_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_person_company_attr_dtype (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_person_company_attr_dtype');
DROP VIEW IF EXISTS jazzhands_legacy.val_person_company_attr_dtype;
CREATE VIEW jazzhands_legacy.val_person_company_attr_dtype AS
 SELECT val_person_company_attr_dtype.person_company_attr_data_type,
    val_person_company_attr_dtype.description,
    val_person_company_attr_dtype.data_ins_user,
    val_person_company_attr_dtype.data_ins_date,
    val_person_company_attr_dtype.data_upd_user,
    val_person_company_attr_dtype.data_upd_date
   FROM jazzhands.val_person_company_attr_dtype;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_person_company_attr_dtype';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_person_company_attr_dtype failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_person_company_attr_dtype (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_person_company_attr_name (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_person_company_attr_name');
DROP VIEW IF EXISTS jazzhands_legacy.val_person_company_attr_name;
CREATE VIEW jazzhands_legacy.val_person_company_attr_name AS
 SELECT val_person_company_attr_name.person_company_attr_name,
    val_person_company_attr_name.person_company_attr_data_type,
    val_person_company_attr_name.description,
    val_person_company_attr_name.data_ins_user,
    val_person_company_attr_name.data_ins_date,
    val_person_company_attr_name.data_upd_user,
    val_person_company_attr_name.data_upd_date
   FROM jazzhands.val_person_company_attr_name;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_person_company_attr_name';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_person_company_attr_name failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_person_company_attr_name (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_person_company_attr_value (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_person_company_attr_value');
DROP VIEW IF EXISTS jazzhands_legacy.val_person_company_attr_value;
CREATE VIEW jazzhands_legacy.val_person_company_attr_value AS
 SELECT val_person_company_attr_value.person_company_attr_name,
    val_person_company_attr_value.person_company_attr_value,
    val_person_company_attr_value.description,
    val_person_company_attr_value.data_ins_user,
    val_person_company_attr_value.data_ins_date,
    val_person_company_attr_value.data_upd_user,
    val_person_company_attr_value.data_upd_date
   FROM jazzhands.val_person_company_attr_value;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_person_company_attr_value';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_person_company_attr_value failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_person_company_attr_value (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_person_company_relation (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_person_company_relation');
DROP VIEW IF EXISTS jazzhands_legacy.val_person_company_relation;
CREATE VIEW jazzhands_legacy.val_person_company_relation AS
 SELECT val_person_company_relation.person_company_relation,
    val_person_company_relation.description,
    val_person_company_relation.data_ins_user,
    val_person_company_relation.data_ins_date,
    val_person_company_relation.data_upd_user,
    val_person_company_relation.data_upd_date
   FROM jazzhands.val_person_company_relation;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_person_company_relation';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_person_company_relation failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_person_company_relation (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_person_contact_loc_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_person_contact_loc_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_person_contact_loc_type;
CREATE VIEW jazzhands_legacy.val_person_contact_loc_type AS
 SELECT val_person_contact_loc_type.person_contact_location_type,
    val_person_contact_loc_type.description,
    val_person_contact_loc_type.data_ins_user,
    val_person_contact_loc_type.data_ins_date,
    val_person_contact_loc_type.data_upd_user,
    val_person_contact_loc_type.data_upd_date
   FROM jazzhands.val_person_contact_loc_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_person_contact_loc_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_person_contact_loc_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_person_contact_loc_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_person_contact_technology (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_person_contact_technology');
DROP VIEW IF EXISTS jazzhands_legacy.val_person_contact_technology;
CREATE VIEW jazzhands_legacy.val_person_contact_technology AS
 SELECT val_person_contact_technology.person_contact_technology,
    val_person_contact_technology.person_contact_type,
    val_person_contact_technology.description,
    val_person_contact_technology.data_ins_user,
    val_person_contact_technology.data_ins_date,
    val_person_contact_technology.data_upd_user,
    val_person_contact_technology.data_upd_date
   FROM jazzhands.val_person_contact_technology;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_person_contact_technology';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_person_contact_technology failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_person_contact_technology (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_person_contact_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_person_contact_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_person_contact_type;
CREATE VIEW jazzhands_legacy.val_person_contact_type AS
 SELECT val_person_contact_type.person_contact_type,
    val_person_contact_type.description,
    val_person_contact_type.data_ins_user,
    val_person_contact_type.data_ins_date,
    val_person_contact_type.data_upd_user,
    val_person_contact_type.data_upd_date
   FROM jazzhands.val_person_contact_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_person_contact_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_person_contact_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_person_contact_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_person_image_usage (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_person_image_usage');
DROP VIEW IF EXISTS jazzhands_legacy.val_person_image_usage;
CREATE VIEW jazzhands_legacy.val_person_image_usage AS
 SELECT val_person_image_usage.person_image_usage,
    val_person_image_usage.is_multivalue,
    val_person_image_usage.data_ins_user,
    val_person_image_usage.data_ins_date,
    val_person_image_usage.data_upd_user,
    val_person_image_usage.data_upd_date
   FROM jazzhands.val_person_image_usage;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_person_image_usage';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_person_image_usage failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_person_image_usage (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_person_location_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_person_location_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_person_location_type;
CREATE VIEW jazzhands_legacy.val_person_location_type AS
 SELECT val_person_location_type.person_location_type,
    val_person_location_type.description,
    val_person_location_type.data_ins_user,
    val_person_location_type.data_ins_date,
    val_person_location_type.data_upd_user,
    val_person_location_type.data_upd_date
   FROM jazzhands.val_person_location_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_person_location_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_person_location_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_person_location_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_person_status (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_person_status');
DROP VIEW IF EXISTS jazzhands_legacy.val_person_status;
CREATE VIEW jazzhands_legacy.val_person_status AS
 SELECT val_person_status.person_status,
    val_person_status.description,
    val_person_status.is_enabled,
    val_person_status.propagate_from_person,
    val_person_status.data_ins_user,
    val_person_status.data_ins_date,
    val_person_status.data_upd_user,
    val_person_status.data_upd_date
   FROM jazzhands.val_person_status;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_person_status';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_person_status failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_person_status (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_physical_address_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_physical_address_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_physical_address_type;
CREATE VIEW jazzhands_legacy.val_physical_address_type AS
 SELECT val_physical_address_type.physical_address_type,
    val_physical_address_type.description,
    val_physical_address_type.data_ins_user,
    val_physical_address_type.data_ins_date,
    val_physical_address_type.data_upd_user,
    val_physical_address_type.data_upd_date
   FROM jazzhands.val_physical_address_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_physical_address_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_physical_address_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_physical_address_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_physicalish_volume_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_physicalish_volume_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_physicalish_volume_type;
CREATE VIEW jazzhands_legacy.val_physicalish_volume_type AS
 SELECT val_physicalish_volume_type.physicalish_volume_type,
    val_physicalish_volume_type.description,
    val_physicalish_volume_type.data_ins_user,
    val_physicalish_volume_type.data_ins_date,
    val_physicalish_volume_type.data_upd_user,
    val_physicalish_volume_type.data_upd_date
   FROM jazzhands.val_physicalish_volume_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_physicalish_volume_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_physicalish_volume_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_physicalish_volume_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_processor_architecture (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_processor_architecture');
DROP VIEW IF EXISTS jazzhands_legacy.val_processor_architecture;
CREATE VIEW jazzhands_legacy.val_processor_architecture AS
 SELECT val_processor_architecture.processor_architecture,
    val_processor_architecture.kernel_bits,
    val_processor_architecture.description,
    val_processor_architecture.data_ins_user,
    val_processor_architecture.data_ins_date,
    val_processor_architecture.data_upd_user,
    val_processor_architecture.data_upd_date
   FROM jazzhands.val_processor_architecture;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_processor_architecture';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_processor_architecture failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_processor_architecture (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_production_state (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_production_state');
DROP VIEW IF EXISTS jazzhands_legacy.val_production_state;
CREATE VIEW jazzhands_legacy.val_production_state AS
 SELECT val_production_state.production_state,
    val_production_state.description,
    val_production_state.data_ins_user,
    val_production_state.data_ins_date,
    val_production_state.data_upd_user,
    val_production_state.data_upd_date
   FROM jazzhands.val_production_state;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_production_state';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_production_state failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_production_state (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_property (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_property');
DROP VIEW IF EXISTS jazzhands_legacy.val_property;
CREATE VIEW jazzhands_legacy.val_property AS
 SELECT val_property.property_name,
    val_property.property_type,
    val_property.description,
    val_property.account_collection_type,
    val_property.company_collection_type,
    val_property.device_collection_type,
    val_property.dns_domain_collection_type,
    val_property.layer2_network_collection_type,
    val_property.layer3_network_collection_type,
    val_property.netblock_collection_type,
    val_property.network_range_type,
    val_property.property_collection_type,
    val_property.service_env_collection_type,
    val_property.is_multivalue,
    val_property.prop_val_acct_coll_type_rstrct,
    val_property.prop_val_dev_coll_type_rstrct,
    val_property.prop_val_nblk_coll_type_rstrct,
    val_property.property_data_type,
    val_property.property_value_json_schema,
    val_property.permit_account_collection_id,
    val_property.permit_account_id,
    val_property.permit_account_realm_id,
    val_property.permit_company_id,
    val_property.permit_company_collection_id,
    val_property.permit_device_collection_id,
    val_property.permit_dns_domain_coll_id,
    val_property.permit_layer2_network_coll_id,
    val_property.permit_layer3_network_coll_id,
    val_property.permit_netblock_collection_id,
    val_property.permit_network_range_id,
    val_property.permit_operating_system_id,
    val_property.permit_os_snapshot_id,
    val_property.permit_person_id,
    val_property.permit_property_collection_id,
    val_property.permit_service_env_collection,
    val_property.permit_site_code,
    val_property.permit_x509_signed_cert_id,
    val_property.permit_property_rank,
    val_property.data_ins_user,
    val_property.data_ins_date,
    val_property.data_upd_user,
    val_property.data_upd_date
   FROM jazzhands.val_property;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_property';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_property failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.val_property
	ALTER is_multivalue
	SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_account_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_account_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_account_realm_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_company_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_company_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_device_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_dns_domain_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_layer2_network_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_layer3_network_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_netblock_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_network_range_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_operating_system_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_os_snapshot_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_person_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_property_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_service_env_collection
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_site_code
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_x509_signed_cert_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_property_rank
	SET DEFAULT 'PROHIBITED'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_property (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_property_collection_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_property_collection_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_property_collection_type;
CREATE VIEW jazzhands_legacy.val_property_collection_type AS
 SELECT val_property_collection_type.property_collection_type,
    val_property_collection_type.description,
    val_property_collection_type.max_num_members,
    val_property_collection_type.max_num_collections,
    val_property_collection_type.can_have_hierarchy,
    val_property_collection_type.data_ins_user,
    val_property_collection_type.data_ins_date,
    val_property_collection_type.data_upd_user,
    val_property_collection_type.data_upd_date
   FROM jazzhands.val_property_collection_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_property_collection_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_property_collection_type failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.val_property_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_property_collection_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_property_data_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_property_data_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_property_data_type;
CREATE VIEW jazzhands_legacy.val_property_data_type AS
 SELECT val_property_data_type.property_data_type,
    val_property_data_type.description,
    val_property_data_type.data_ins_user,
    val_property_data_type.data_ins_date,
    val_property_data_type.data_upd_user,
    val_property_data_type.data_upd_date
   FROM jazzhands.val_property_data_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_property_data_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_property_data_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_property_data_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_property_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_property_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_property_type;
CREATE VIEW jazzhands_legacy.val_property_type AS
 SELECT val_property_type.property_type,
    val_property_type.description,
    val_property_type.prop_val_acct_coll_type_rstrct,
    val_property_type.is_multivalue,
    val_property_type.data_ins_user,
    val_property_type.data_ins_date,
    val_property_type.data_upd_user,
    val_property_type.data_upd_date
   FROM jazzhands.val_property_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_property_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_property_type failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.val_property_type
	ALTER is_multivalue
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_property_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_property_value (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_property_value');
DROP VIEW IF EXISTS jazzhands_legacy.val_property_value;
CREATE VIEW jazzhands_legacy.val_property_value AS
 SELECT val_property_value.property_name,
    val_property_value.property_type,
    val_property_value.valid_property_value,
    val_property_value.description,
    val_property_value.data_ins_user,
    val_property_value.data_ins_date,
    val_property_value.data_upd_user,
    val_property_value.data_upd_date
   FROM jazzhands.val_property_value;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_property_value';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_property_value failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_property_value (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_pvt_key_encryption_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_pvt_key_encryption_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_pvt_key_encryption_type;
CREATE VIEW jazzhands_legacy.val_pvt_key_encryption_type AS
 SELECT val_pvt_key_encryption_type.private_key_encryption_type,
    val_pvt_key_encryption_type.description,
    val_pvt_key_encryption_type.data_ins_user,
    val_pvt_key_encryption_type.data_ins_date,
    val_pvt_key_encryption_type.data_upd_user,
    val_pvt_key_encryption_type.data_upd_date
   FROM jazzhands.val_pvt_key_encryption_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_pvt_key_encryption_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_pvt_key_encryption_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_pvt_key_encryption_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_rack_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_rack_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_rack_type;
CREATE VIEW jazzhands_legacy.val_rack_type AS
 SELECT val_rack_type.rack_type,
    val_rack_type.description,
    val_rack_type.data_ins_user,
    val_rack_type.data_ins_date,
    val_rack_type.data_upd_user,
    val_rack_type.data_upd_date
   FROM jazzhands.val_rack_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_rack_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_rack_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_rack_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_raid_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_raid_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_raid_type;
CREATE VIEW jazzhands_legacy.val_raid_type AS
 SELECT val_raid_type.raid_type,
    val_raid_type.description,
    val_raid_type.primary_raid_level,
    val_raid_type.secondary_raid_level,
    val_raid_type.raid_level_qualifier,
    val_raid_type.data_ins_user,
    val_raid_type.data_ins_date,
    val_raid_type.data_upd_user,
    val_raid_type.data_upd_date
   FROM jazzhands.val_raid_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_raid_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_raid_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_raid_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_service_env_coll_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_service_env_coll_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_service_env_coll_type;
CREATE VIEW jazzhands_legacy.val_service_env_coll_type AS
 SELECT val_service_env_coll_type.service_env_collection_type,
    val_service_env_coll_type.description,
    val_service_env_coll_type.max_num_members,
    val_service_env_coll_type.max_num_collections,
    val_service_env_coll_type.can_have_hierarchy,
    val_service_env_coll_type.data_ins_user,
    val_service_env_coll_type.data_ins_date,
    val_service_env_coll_type.data_upd_user,
    val_service_env_coll_type.data_upd_date
   FROM jazzhands.val_service_env_coll_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_service_env_coll_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_service_env_coll_type failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.val_service_env_coll_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_service_env_coll_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_shared_netblock_protocol (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_shared_netblock_protocol');
DROP VIEW IF EXISTS jazzhands_legacy.val_shared_netblock_protocol;
CREATE VIEW jazzhands_legacy.val_shared_netblock_protocol AS
 SELECT val_shared_netblock_protocol.shared_netblock_protocol,
    val_shared_netblock_protocol.data_ins_user,
    val_shared_netblock_protocol.data_ins_date,
    val_shared_netblock_protocol.data_upd_user,
    val_shared_netblock_protocol.data_upd_date
   FROM jazzhands.val_shared_netblock_protocol;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_shared_netblock_protocol';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_shared_netblock_protocol failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_shared_netblock_protocol (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_slot_function (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_slot_function');
DROP VIEW IF EXISTS jazzhands_legacy.val_slot_function;
CREATE VIEW jazzhands_legacy.val_slot_function AS
 SELECT val_slot_function.slot_function,
    val_slot_function.description,
    val_slot_function.can_have_mac_address,
    val_slot_function.data_ins_user,
    val_slot_function.data_ins_date,
    val_slot_function.data_upd_user,
    val_slot_function.data_upd_date
   FROM jazzhands.val_slot_function;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_slot_function';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_slot_function failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.val_slot_function
	ALTER can_have_mac_address
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_slot_function (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_slot_physical_interface (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_slot_physical_interface');
DROP VIEW IF EXISTS jazzhands_legacy.val_slot_physical_interface;
CREATE VIEW jazzhands_legacy.val_slot_physical_interface AS
 SELECT val_slot_physical_interface.slot_physical_interface_type,
    val_slot_physical_interface.slot_function,
    val_slot_physical_interface.data_ins_user,
    val_slot_physical_interface.data_ins_date,
    val_slot_physical_interface.data_upd_user,
    val_slot_physical_interface.data_upd_date
   FROM jazzhands.val_slot_physical_interface;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_slot_physical_interface';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_slot_physical_interface failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_slot_physical_interface (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_snmp_commstr_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_snmp_commstr_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_snmp_commstr_type;
CREATE VIEW jazzhands_legacy.val_snmp_commstr_type AS
 SELECT val_snmp_commstr_type.snmp_commstr_type,
    val_snmp_commstr_type.description,
    val_snmp_commstr_type.data_ins_user,
    val_snmp_commstr_type.data_ins_date,
    val_snmp_commstr_type.data_upd_user,
    val_snmp_commstr_type.data_upd_date
   FROM jazzhands.val_snmp_commstr_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_snmp_commstr_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_snmp_commstr_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_snmp_commstr_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_ssh_key_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_ssh_key_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_ssh_key_type;
CREATE VIEW jazzhands_legacy.val_ssh_key_type AS
 SELECT val_ssh_key_type.ssh_key_type,
    val_ssh_key_type.description,
    val_ssh_key_type.data_ins_user,
    val_ssh_key_type.data_ins_date,
    val_ssh_key_type.data_upd_user,
    val_ssh_key_type.data_upd_date
   FROM jazzhands.val_ssh_key_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_ssh_key_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_ssh_key_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_ssh_key_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_sw_package_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_sw_package_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_sw_package_type;
CREATE VIEW jazzhands_legacy.val_sw_package_type AS
 SELECT val_sw_package_type.sw_package_type,
    val_sw_package_type.description,
    val_sw_package_type.data_ins_user,
    val_sw_package_type.data_ins_date,
    val_sw_package_type.data_upd_user,
    val_sw_package_type.data_upd_date
   FROM jazzhands.val_sw_package_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_sw_package_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_sw_package_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_sw_package_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_token_collection_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_token_collection_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_token_collection_type;
CREATE VIEW jazzhands_legacy.val_token_collection_type AS
 SELECT val_token_collection_type.token_collection_type,
    val_token_collection_type.description,
    val_token_collection_type.max_num_members,
    val_token_collection_type.max_num_collections,
    val_token_collection_type.can_have_hierarchy,
    val_token_collection_type.data_ins_user,
    val_token_collection_type.data_ins_date,
    val_token_collection_type.data_upd_user,
    val_token_collection_type.data_upd_date
   FROM jazzhands.val_token_collection_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_token_collection_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_token_collection_type failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.val_token_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_token_collection_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_token_status (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_token_status');
DROP VIEW IF EXISTS jazzhands_legacy.val_token_status;
CREATE VIEW jazzhands_legacy.val_token_status AS
 SELECT val_token_status.token_status,
    val_token_status.description,
    val_token_status.data_ins_user,
    val_token_status.data_ins_date,
    val_token_status.data_upd_user,
    val_token_status.data_upd_date
   FROM jazzhands.val_token_status;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_token_status';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_token_status failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_token_status (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_token_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_token_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_token_type;
CREATE VIEW jazzhands_legacy.val_token_type AS
 SELECT val_token_type.token_type,
    val_token_type.description,
    val_token_type.token_digit_count,
    val_token_type.data_ins_user,
    val_token_type.data_ins_date,
    val_token_type.data_upd_user,
    val_token_type.data_upd_date
   FROM jazzhands.val_token_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_token_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_token_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_token_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_volume_group_purpose (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_volume_group_purpose');
DROP VIEW IF EXISTS jazzhands_legacy.val_volume_group_purpose;
CREATE VIEW jazzhands_legacy.val_volume_group_purpose AS
 SELECT val_volume_group_purpose.volume_group_purpose,
    val_volume_group_purpose.description,
    val_volume_group_purpose.data_ins_user,
    val_volume_group_purpose.data_ins_date,
    val_volume_group_purpose.data_upd_user,
    val_volume_group_purpose.data_upd_date
   FROM jazzhands.val_volume_group_purpose;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_volume_group_purpose';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_volume_group_purpose failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_volume_group_purpose (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_volume_group_relation (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_volume_group_relation');
DROP VIEW IF EXISTS jazzhands_legacy.val_volume_group_relation;
CREATE VIEW jazzhands_legacy.val_volume_group_relation AS
 SELECT val_volume_group_relation.volume_group_relation,
    val_volume_group_relation.description,
    val_volume_group_relation.data_ins_user,
    val_volume_group_relation.data_ins_date,
    val_volume_group_relation.data_upd_user,
    val_volume_group_relation.data_upd_date
   FROM jazzhands.val_volume_group_relation;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_volume_group_relation';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_volume_group_relation failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_volume_group_relation (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_volume_group_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_volume_group_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_volume_group_type;
CREATE VIEW jazzhands_legacy.val_volume_group_type AS
 SELECT val_volume_group_type.volume_group_type,
    val_volume_group_type.description,
    val_volume_group_type.data_ins_user,
    val_volume_group_type.data_ins_date,
    val_volume_group_type.data_upd_user,
    val_volume_group_type.data_upd_date
   FROM jazzhands.val_volume_group_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_volume_group_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_volume_group_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_volume_group_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_x509_certificate_file_fmt (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_x509_certificate_file_fmt');
DROP VIEW IF EXISTS jazzhands_legacy.val_x509_certificate_file_fmt;
CREATE VIEW jazzhands_legacy.val_x509_certificate_file_fmt AS
 SELECT val_x509_certificate_file_fmt.x509_file_format,
    val_x509_certificate_file_fmt.description,
    val_x509_certificate_file_fmt.data_ins_user,
    val_x509_certificate_file_fmt.data_ins_date,
    val_x509_certificate_file_fmt.data_upd_user,
    val_x509_certificate_file_fmt.data_upd_date
   FROM jazzhands.val_x509_certificate_file_fmt;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_x509_certificate_file_fmt';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_x509_certificate_file_fmt failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_x509_certificate_file_fmt (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_x509_certificate_type (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_x509_certificate_type');
DROP VIEW IF EXISTS jazzhands_legacy.val_x509_certificate_type;
CREATE VIEW jazzhands_legacy.val_x509_certificate_type AS
 SELECT val_x509_certificate_type.x509_certificate_type,
    val_x509_certificate_type.description,
    val_x509_certificate_type.data_ins_user,
    val_x509_certificate_type.data_ins_date,
    val_x509_certificate_type.data_upd_user,
    val_x509_certificate_type.data_upd_date
   FROM jazzhands.val_x509_certificate_type;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_x509_certificate_type';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_x509_certificate_type failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_x509_certificate_type (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_x509_key_usage (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_x509_key_usage');
DROP VIEW IF EXISTS jazzhands_legacy.val_x509_key_usage;
CREATE VIEW jazzhands_legacy.val_x509_key_usage AS
 SELECT val_x509_key_usage.x509_key_usg,
    val_x509_key_usage.description,
    val_x509_key_usage.is_extended,
    val_x509_key_usage.data_ins_user,
    val_x509_key_usage.data_ins_date,
    val_x509_key_usage.data_upd_user,
    val_x509_key_usage.data_upd_date
   FROM jazzhands.val_x509_key_usage;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_x509_key_usage';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_x509_key_usage failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_x509_key_usage (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_x509_key_usage_category (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_x509_key_usage_category');
DROP VIEW IF EXISTS jazzhands_legacy.val_x509_key_usage_category;
CREATE VIEW jazzhands_legacy.val_x509_key_usage_category AS
 SELECT val_x509_key_usage_category.x509_key_usg_cat,
    val_x509_key_usage_category.description,
    val_x509_key_usage_category.data_ins_user,
    val_x509_key_usage_category.data_ins_date,
    val_x509_key_usage_category.data_upd_user,
    val_x509_key_usage_category.data_upd_date
   FROM jazzhands.val_x509_key_usage_category;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_x509_key_usage_category';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_x509_key_usage_category failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_x509_key_usage_category (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_x509_revocation_reason (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_x509_revocation_reason');
DROP VIEW IF EXISTS jazzhands_legacy.val_x509_revocation_reason;
CREATE VIEW jazzhands_legacy.val_x509_revocation_reason AS
 SELECT val_x509_revocation_reason.x509_revocation_reason,
    val_x509_revocation_reason.description,
    val_x509_revocation_reason.data_ins_user,
    val_x509_revocation_reason.data_ins_date,
    val_x509_revocation_reason.data_upd_user,
    val_x509_revocation_reason.data_upd_date
   FROM jazzhands.val_x509_revocation_reason;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_x509_revocation_reason';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_x509_revocation_reason failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_x509_revocation_reason (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE volume_group (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'volume_group');
DROP VIEW IF EXISTS jazzhands_legacy.volume_group;
CREATE VIEW jazzhands_legacy.volume_group AS
 SELECT volume_group.volume_group_id,
    volume_group.device_id,
    volume_group.component_id,
    volume_group.volume_group_name,
    volume_group.volume_group_type,
    volume_group.volume_group_size_in_bytes,
    volume_group.raid_type,
    volume_group.data_ins_user,
    volume_group.data_ins_date,
    volume_group.data_upd_user,
    volume_group.data_upd_date
   FROM jazzhands.volume_group;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'volume_group';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of volume_group failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE volume_group (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE volume_group_physicalish_vol (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'volume_group_physicalish_vol');
DROP VIEW IF EXISTS jazzhands_legacy.volume_group_physicalish_vol;
CREATE VIEW jazzhands_legacy.volume_group_physicalish_vol AS
 SELECT volume_group_physicalish_vol.physicalish_volume_id,
    volume_group_physicalish_vol.volume_group_id,
    volume_group_physicalish_vol.device_id,
    volume_group_physicalish_vol.volume_group_primary_pos,
    volume_group_physicalish_vol.volume_group_secondary_pos,
    volume_group_physicalish_vol.volume_group_relation,
    volume_group_physicalish_vol.data_ins_user,
    volume_group_physicalish_vol.data_ins_date,
    volume_group_physicalish_vol.data_upd_user,
    volume_group_physicalish_vol.data_upd_date
   FROM jazzhands.volume_group_physicalish_vol;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'volume_group_physicalish_vol';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of volume_group_physicalish_vol failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE volume_group_physicalish_vol (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE volume_group_purpose (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'volume_group_purpose');
DROP VIEW IF EXISTS jazzhands_legacy.volume_group_purpose;
CREATE VIEW jazzhands_legacy.volume_group_purpose AS
 SELECT volume_group_purpose.volume_group_id,
    volume_group_purpose.volume_group_purpose,
    volume_group_purpose.description,
    volume_group_purpose.data_ins_user,
    volume_group_purpose.data_ins_date,
    volume_group_purpose.data_upd_user,
    volume_group_purpose.data_upd_date
   FROM jazzhands.volume_group_purpose;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'volume_group_purpose';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of volume_group_purpose failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE volume_group_purpose (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE x509_certificate (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'x509_certificate');
DROP VIEW IF EXISTS jazzhands_legacy.x509_certificate;
CREATE VIEW jazzhands_legacy.x509_certificate AS
 SELECT x509_certificate.x509_cert_id,
    x509_certificate.friendly_name,
    x509_certificate.is_active,
    x509_certificate.is_certificate_authority,
    x509_certificate.signing_cert_id,
    x509_certificate.x509_ca_cert_serial_number,
    x509_certificate.public_key,
    x509_certificate.private_key,
    x509_certificate.certificate_sign_req,
    x509_certificate.subject,
    x509_certificate.subject_key_identifier,
    x509_certificate.valid_from,
    x509_certificate.valid_to,
    x509_certificate.x509_revocation_date,
    x509_certificate.x509_revocation_reason,
    x509_certificate.passphrase,
    x509_certificate.encryption_key_id,
    x509_certificate.ocsp_uri,
    x509_certificate.crl_uri,
    x509_certificate.data_ins_user,
    x509_certificate.data_ins_date,
    x509_certificate.data_upd_user,
    x509_certificate.data_upd_date
   FROM jazzhands.x509_certificate;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'x509_certificate';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of x509_certificate failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.x509_certificate
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE jazzhands_legacy.x509_certificate
	ALTER is_certificate_authority
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE x509_certificate (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE x509_key_usage_attribute (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'x509_key_usage_attribute');
DROP VIEW IF EXISTS jazzhands_legacy.x509_key_usage_attribute;
CREATE VIEW jazzhands_legacy.x509_key_usage_attribute AS
 SELECT x509_key_usage_attribute.x509_cert_id,
    x509_key_usage_attribute.x509_key_usg,
    x509_key_usage_attribute.x509_key_usg_cat,
    x509_key_usage_attribute.data_ins_user,
    x509_key_usage_attribute.data_ins_date,
    x509_key_usage_attribute.data_upd_user,
    x509_key_usage_attribute.data_upd_date
   FROM jazzhands.x509_key_usage_attribute;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'x509_key_usage_attribute';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of x509_key_usage_attribute failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE x509_key_usage_attribute (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE x509_key_usage_categorization (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'x509_key_usage_categorization');
DROP VIEW IF EXISTS jazzhands_legacy.x509_key_usage_categorization;
CREATE VIEW jazzhands_legacy.x509_key_usage_categorization AS
 SELECT x509_key_usage_categorization.x509_key_usg_cat,
    x509_key_usage_categorization.x509_key_usg,
    x509_key_usage_categorization.description,
    x509_key_usage_categorization.data_ins_user,
    x509_key_usage_categorization.data_ins_date,
    x509_key_usage_categorization.data_upd_user,
    x509_key_usage_categorization.data_upd_date
   FROM jazzhands.x509_key_usage_categorization;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'x509_key_usage_categorization';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of x509_key_usage_categorization failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE x509_key_usage_categorization (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE x509_key_usage_default (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'x509_key_usage_default');
DROP VIEW IF EXISTS jazzhands_legacy.x509_key_usage_default;
CREATE VIEW jazzhands_legacy.x509_key_usage_default AS
 SELECT x509_key_usage_default.x509_signed_certificate_id,
    x509_key_usage_default.x509_key_usg,
    x509_key_usage_default.description,
    x509_key_usage_default.data_ins_user,
    x509_key_usage_default.data_ins_date,
    x509_key_usage_default.data_upd_user,
    x509_key_usage_default.data_upd_date
   FROM jazzhands.x509_key_usage_default;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'x509_key_usage_default';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of x509_key_usage_default failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE x509_key_usage_default (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE x509_signed_certificate (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'x509_signed_certificate');
DROP VIEW IF EXISTS jazzhands_legacy.x509_signed_certificate;
CREATE VIEW jazzhands_legacy.x509_signed_certificate AS
 SELECT x509_signed_certificate.x509_signed_certificate_id,
    x509_signed_certificate.x509_certificate_type,
    x509_signed_certificate.subject,
    x509_signed_certificate.friendly_name,
    x509_signed_certificate.subject_key_identifier,
    x509_signed_certificate.is_active,
    x509_signed_certificate.is_certificate_authority,
    x509_signed_certificate.signing_cert_id,
    x509_signed_certificate.x509_ca_cert_serial_number,
    x509_signed_certificate.public_key,
    x509_signed_certificate.private_key_id,
    x509_signed_certificate.certificate_signing_request_id,
    x509_signed_certificate.valid_from,
    x509_signed_certificate.valid_to,
    x509_signed_certificate.x509_revocation_date,
    x509_signed_certificate.x509_revocation_reason,
    x509_signed_certificate.ocsp_uri,
    x509_signed_certificate.crl_uri,
    x509_signed_certificate.data_ins_user,
    x509_signed_certificate.data_ins_date,
    x509_signed_certificate.data_upd_user,
    x509_signed_certificate.data_upd_date
   FROM jazzhands.x509_signed_certificate;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'x509_signed_certificate';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of x509_signed_certificate failed but that is ok';
				NULL;
			END;
$$;

ALTER TABLE jazzhands_legacy.x509_signed_certificate
	ALTER x509_certificate_type
	SET DEFAULT 'default'::character varying;
ALTER TABLE jazzhands_legacy.x509_signed_certificate
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE jazzhands_legacy.x509_signed_certificate
	ALTER is_certificate_authority
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE x509_signed_certificate (jazzhands_legacy)
--------------------------------------------------------------------
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
	) SELECT 'jazzhands_cache' , 'ct_device_components' , 'jazzhands_cache' , 'v_device_components' , '1'  WHERE ('jazzhands_cache' , 'ct_device_components' , 'jazzhands_cache' , 'v_device_components' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
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
