--
-- Copyright (c) 2017 Todd Kover
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

	--preschema
	schema_support
	--suffix=v75
	--post
	post
	--pre
	pre
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance();
select timeofday(), now();


-- BEGIN Misc that does not apply to above
WITH x AS (
        SELECT d.device_id, c.component_id, a.asset_id
        FROM    device d
                JOIN component c USING (component_id)
                JOIN asset a USING (asset_id)
        WHERE   a.component_id IS DISTINCT FROM d.component_id
        AND     device_id NOT IN (
                SELECT  device_id
                FROM    device d
                        JOIN asset a USING (component_id)
                WHERE   d.asset_id IS DISTINCT FROM a.asset_id
        )
)
UPDATE asset a
SET component_id = x.component_id
FROM x
WHERE x.asset_id = a.asset_id;



-- END Misc that does not apply to above
--
-- Process pre-schema schema_support
--
-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'build_audit_table');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.build_audit_table ( aud_schema character varying, tbl_schema character varying, table_name character varying, first_time boolean );
CREATE OR REPLACE FUNCTION schema_support.build_audit_table(aud_schema character varying, tbl_schema character varying, table_name character varying, first_time boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'mv_last_updated');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.mv_last_updated ( relation text, schema text, debug boolean );
CREATE OR REPLACE FUNCTION schema_support.mv_last_updated(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO schema_support
AS $function$
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'refresh_mv_if_needed');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.refresh_mv_if_needed ( relation text, schema text, debug boolean );
CREATE OR REPLACE FUNCTION schema_support.refresh_mv_if_needed(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO schema_support
AS $function$
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_last_changed');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_last_changed ( relation text, schema text, debug boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_last_changed(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SET search_path TO schema_support
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
			RETURN '-infinity'::interval;
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
						FROM '||quote_ident(objaud)||'.'|| quote_ident(obj)
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
				IF _r.type = 'view' OR _r.type = 'materialized view' THEN
					EXECUTE 'ALTER ' || _r.type || ' ' || _r.schema || '.' || _r.object ||
						' OWNER TO ' || _r.owner || ';';
				ELSIF _r.type = 'function' THEN
					EXECUTE 'ALTER FUNCTION ' || _r.schema || '.' || _r.object ||
						'(' || _r.idargs || ') OWNER TO ' || _r.owner || ';';
				ELSE
					RAISE EXCEPTION 'Unable to restore grant for % ', _r;
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
 SET search_path TO schema_support
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
	_mat	TEXT;
	_typ	TEXT;
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

	-- implicitly save regrants
	PERFORM schema_support.save_grants_for_replay(schema, object);

	-- save any triggers on the view
	PERFORM schema_support.save_trigger_for_replay(schema, object, dropit);
	FOR _r in SELECT n.nspname, c.relname, 'view',
				coalesce(u.usename, 'public') as owner,
				pg_get_viewdef(c.oid, true) as viewdef, relkind
		FROM pg_class c
		INNER JOIN pg_namespace n on n.oid = c.relnamespace
		LEFT JOIN pg_user u on u.usesysid = c.relowner
		WHERE c.relname = object
		AND n.nspname = schema
	LOOP
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

-- New function
CREATE OR REPLACE FUNCTION schema_support.set_mv_last_updated(relation text, schema text DEFAULT 'jazzhands'::text, whence timestamp without time zone DEFAULT now(), debug boolean DEFAULT false)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO schema_support
AS $function$
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'build_audit_table');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.build_audit_table ( aud_schema character varying, tbl_schema character varying, table_name character varying, first_time boolean );
CREATE OR REPLACE FUNCTION schema_support.build_audit_table(aud_schema character varying, tbl_schema character varying, table_name character varying, first_time boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'mv_last_updated');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.mv_last_updated ( relation text, schema text, debug boolean );
CREATE OR REPLACE FUNCTION schema_support.mv_last_updated(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO schema_support
AS $function$
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'refresh_mv_if_needed');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.refresh_mv_if_needed ( relation text, schema text, debug boolean );
CREATE OR REPLACE FUNCTION schema_support.refresh_mv_if_needed(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO schema_support
AS $function$
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_last_changed');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_last_changed ( relation text, schema text, debug boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_last_changed(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SET search_path TO schema_support
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
			RETURN '-infinity'::interval;
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
						FROM '||quote_ident(objaud)||'.'|| quote_ident(obj)
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
				IF _r.type = 'view' OR _r.type = 'materialized view' THEN
					EXECUTE 'ALTER ' || _r.type || ' ' || _r.schema || '.' || _r.object ||
						' OWNER TO ' || _r.owner || ';';
				ELSIF _r.type = 'function' THEN
					EXECUTE 'ALTER FUNCTION ' || _r.schema || '.' || _r.object ||
						'(' || _r.idargs || ') OWNER TO ' || _r.owner || ';';
				ELSE
					RAISE EXCEPTION 'Unable to restore grant for % ', _r;
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
 SET search_path TO schema_support
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
	_mat	TEXT;
	_typ	TEXT;
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

	-- implicitly save regrants
	PERFORM schema_support.save_grants_for_replay(schema, object);

	-- save any triggers on the view
	PERFORM schema_support.save_trigger_for_replay(schema, object, dropit);
	FOR _r in SELECT n.nspname, c.relname, 'view',
				coalesce(u.usename, 'public') as owner,
				pg_get_viewdef(c.oid, true) as viewdef, relkind
		FROM pg_class c
		INNER JOIN pg_namespace n on n.oid = c.relnamespace
		LEFT JOIN pg_user u on u.usesysid = c.relowner
		WHERE c.relname = object
		AND n.nspname = schema
	LOOP
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

DROP FUNCTION IF EXISTS schema_support.set_mv_last_updated ( relation text, schema text, debug boolean );
-- New function
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

-- New function
CREATE OR REPLACE FUNCTION schema_support.set_mv_last_updated(relation text, schema text DEFAULT 'jazzhands'::text, whence timestamp without time zone DEFAULT now(), debug boolean DEFAULT false)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO schema_support
AS $function$
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
-- Changed function
SELECT schema_support.save_grants_for_replay('person_manip', 'setup_unix_account');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS person_manip.setup_unix_account ( in_account_id integer, in_account_type character varying, in_uid integer );
CREATE OR REPLACE FUNCTION person_manip.setup_unix_account(in_account_id integer, in_account_type character varying, in_uid integer DEFAULT NULL::integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	acid			account_collection.account_collection_id%TYPE;
	_login			account.login%TYPE;
	new_uid			account_unix_info.unix_uid%TYPE	DEFAULT NULL;
BEGIN
	SELECT login INTO _login FROM account WHERE account_id = in_account_id;

	SELECT account_collection_id
	INTO	acid
	FROM	account_collection
	WHERE	account_collection_name = _login
	AND	account_collection_type = 'unix-group';

	IF NOT FOUND THEN
		INSERT INTO account_collection (
			account_collection_name, account_collection_type)
		values (
			_login, 'unix-group'
		) RETURNING account_collection_id INTO acid;
	END IF;

	PERFORM	*
	FROM	account_collection_account
	WHERE	account_collection_id = acid
	AND	account_id = in_account_id;

	IF NOT FOUND THEN
		insert into account_collection_account (
			account_collection_id, account_id
		) values (
			acid, in_account_id
		);
	END IF;

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

	PERFORM	*
	FROM	unix_group
	WHERE	account_collection_id = acid
	AND	unix_gid = new_uid;

	IF NOT FOUND THEN
		INSERT INTO unix_group (
			account_collection_id,
			unix_gid
		) values (
			acid,
			new_uid
		);
	END IF;
	RETURN in_account_id;
END;
$function$
;

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
-- Changed function
SELECT schema_support.save_grants_for_replay('device_utils', 'retire_device');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_utils.retire_device ( in_device_id integer, retire_modules boolean );
CREATE OR REPLACE FUNCTION device_utils.retire_device(in_device_id integer, retire_modules boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally		INTEGER;
	_r			RECORD;
	_d			DEVICE%ROWTYPE;
	_mgrid		DEVICE.DEVICE_ID%TYPE;
	_purgedev	boolean;
BEGIN
	_purgedev := false;

	BEGIN
		PERFORM local_hooks.device_retire_early(in_Device_Id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	SELECT * INTO _d FROM device WHERE device_id = in_Device_id;
	delete from dns_record where netblock_id in (
		select netblock_id 
		from network_interface where device_id = in_Device_id
	);

	delete from network_interface_purpose where device_id = in_Device_id;

	DELETE FROM network_interface_netblock
	WHERE network_interface_id IN (
			SELECT network_interface_id
		 	FROM network_interface
			WHERE device_id = in_Device_id
	);

	DELETE FROM network_interface WHERE device_id = in_Device_id;

	PERFORM device_utils.purge_physical_ports( in_Device_id);
--	PERFORM device_utils.purge_power_ports( in_Device_id);

	delete from property where device_collection_id in (
		SELECT	dc.device_collection_id 
		  FROM	device_collection dc
				INNER JOIN device_collection_device dcd
		 			USING (device_collection_id)
		WHERE	dc.device_collection_type = 'per-device'
		  AND	dcd.device_id = in_Device_id
	);

	delete from device_collection_device where device_id = in_Device_id
		AND device_collection_id NOT IN (
			select device_collection_id
			FROM device_collection
			WHERE device_collection_type = 'per-device'
		);
	delete from snmp_commstr where device_id = in_Device_id;

		
	IF _d.rack_location_id IS NOT NULL  THEN
		UPDATE device SET rack_location_id = NULL 
		WHERE device_id = in_Device_id;

		-- This should not be permitted based on constraints, but in case
		-- that constraint had to be disabled...
		SELECT	count(*)
		  INTO	tally
		  FROM	device
		 WHERE	rack_location_id = _d.RACK_LOCATION_ID;

		IF tally = 0 THEN
			DELETE FROM rack_location 
			WHERE rack_location_id = _d.RACK_LOCATION_ID;
		END IF;
	END IF;

	IF _d.chassis_location_id IS NOT NULL THEN
		RAISE EXCEPTION 'Retiring modules is not supported yet.';
	END IF;

	SELECT	manager_device_id
	INTO	_mgrid
	 FROM	device_management_controller
	WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc'
	LIMIT 1;

	IF _mgrid IS NOT NULL THEN
		DELETE FROM device_management_controller
		WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc'
			AND manager_device_id = _mgrid;

		PERFORM device_utils.retire_device( manager_device_id)
		  FROM	device_management_controller
		WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc';
	END IF;

	BEGIN
		PERFORM local_hooks.device_retire_late(in_Device_Id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	SELECT count(*)
	INTO tally
	FROM device_note
	WHERE device_id = in_Device_id;

	--
	-- If there is no notes or serial number its save to remove
	-- 
	IF tally = 0 AND _d.ASSET_ID is NULL THEN
		_purgedev := true;
	END IF;

	IF _purgedev THEN
		--
		-- If there is an fk violation, we just preserve the record but
		-- delete all the identifying characteristics
		--
		BEGIN
			DELETE FROM device where device_id = in_Device_Id;
			return false;
		EXCEPTION WHEN foreign_key_violation THEN
			PERFORM 1;
		END;
	END IF;

	UPDATE device SET 
		device_name =NULL,
		service_environment_id = (
			select service_environment_id from service_environment
			where service_environment_name = 'unallocated'),
		device_status = 'removed',
		voe_symbolic_track_id = NULL,
		is_monitored = 'N',
		should_fetch_config = 'N',
		description = NULL
	WHERE device_id = in_Device_id;

	return true;
END;
$function$
;

--
-- Process middle (non-trigger) schema netblock_utils
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
-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'insert_pci_component');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.insert_pci_component ( pci_vendor_id integer, pci_device_id integer, pci_sub_vendor_id integer, pci_subsystem_id integer, pci_vendor_name text, pci_device_name text, pci_sub_vendor_name text, pci_sub_device_name text, component_function_list text[], slot_type text, serial_number text );
CREATE OR REPLACE FUNCTION component_utils.insert_pci_component(pci_vendor_id integer, pci_device_id integer, pci_sub_vendor_id integer DEFAULT NULL::integer, pci_subsystem_id integer DEFAULT NULL::integer, pci_vendor_name text DEFAULT NULL::text, pci_device_name text DEFAULT NULL::text, pci_sub_vendor_name text DEFAULT NULL::text, pci_sub_device_name text DEFAULT NULL::text, component_function_list text[] DEFAULT NULL::text[], slot_type text DEFAULT 'unknown'::text, serial_number text DEFAULT NULL::text)
 RETURNS component
 LANGUAGE plpgsql
 SET search_path TO jazzhands
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

--
-- Process middle (non-trigger) schema snapshot_manip
--
--
-- Process middle (non-trigger) schema lv_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('lv_manip', 'delete_lv_hier');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.delete_lv_hier ( INOUT physicalish_volume_list integer[], INOUT volume_group_list integer[], INOUT logical_volume_list integer[] );
CREATE OR REPLACE FUNCTION lv_manip.delete_lv_hier(INOUT physicalish_volume_list integer[] DEFAULT NULL::integer[], INOUT volume_group_list integer[] DEFAULT NULL::integer[], INOUT logical_volume_list integer[] DEFAULT NULL::integer[])
 RETURNS record
 LANGUAGE plpgsql
 SET search_path TO jazzhands
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
 SET search_path TO jazzhands
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

--
-- Process middle (non-trigger) schema approval_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('approval_utils', 'build_next_approval_item');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS approval_utils.build_next_approval_item ( approval_instance_item_id integer, approval_process_chain_id integer, approval_instance_id integer, approved character, approving_account_id integer, new_value text );
CREATE OR REPLACE FUNCTION approval_utils.build_next_approval_item(approval_instance_item_id integer, approval_process_chain_id integer, approval_instance_id integer, approved character, approving_account_id integer, new_value text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO approval_utils, jazzhands
AS $function$
DECLARE
	_r		RECORD;
	_apc	approval_process_chain%ROWTYPE;	
	_new	approval_instance_item%ROWTYPE;	
	_acid	account.account_id%TYPE;
	_step	approval_instance_step.approval_instance_step_id%TYPE;
	_l		approval_instance_link.approval_instance_link_id%TYPE;
	apptype	text;
	_v			approval_utils.v_account_collection_approval_process%ROWTYPE;
BEGIN
	EXECUTE '
		SELECT apc.*
		FROM approval_process_chain apc
		WHERE approval_process_chain_id=$1
	' INTO _apc USING approval_process_chain_id;

	IF _apc.approval_process_chain_id is NULL THEN
		RAISE EXCEPTION 'Unable to follow this chain: %',
			approval_process_chain_id;
	END IF;

	EXECUTE '
		SELECT aii.*, ais.approver_account_id
		FROM approval_instance_item  aii
			INNER JOIN approval_instance_step ais
				USING (approval_instance_step_id)
		WHERE approval_instance_item_id=$1
	' INTO _r USING approval_instance_item_id;

	IF _apc.approving_entity = 'manager' THEN
		apptype := 'account';
		_acid := NULL;
		EXECUTE '
			SELECT manager_account_id
			FROM	v_account_manager_map
			WHERE	account_id = $1
		' INTO _acid USING approving_account_id;
		--
		-- return NULL because there is no manager for the person
		--
		IF _acid IS NULL THEN
			RETURN NULL;
		END IF;
	ELSIF _apc.approving_entity = 'jira-hr' THEN
		apptype := 'jira-hr';
		_acid :=  _r.approver_account_id;
	ELSIF _apc.approving_entity = 'rt-hr' THEN
		apptype := 'rt-hr';
		_acid :=  _r.approver_account_id;
	ELSIF _apc.approving_entity = 'kace-hr' THEN
		apptype := 'kace-hr';
		_acid :=  _r.approver_account_id;
	ELSIF _apc.approving_entity = 'recertify' THEN
		apptype := 'account';
		EXECUTE '
			SELECT approver_account_id
			FROM approval_instance_item  aii
				INNER JOIN approval_instance_step ais
					USING (approval_instance_step_id)
			WHERE approval_instance_item_id IN (
				SELECT	approval_instance_item_id
				FROM	approval_instance_item
				WHERE	next_approval_instance_item_id = $1
			)
		' INTO _acid USING approval_instance_item_id;
	ELSE
		RAISE EXCEPTION 'Can not handle approving entity %',
			_apc.approving_entity;
	END IF;

	IF _acid IS NULL THEN
		RAISE EXCEPTION 'This whould not happen:  Unable to discern approving account.';
	END IF;

	EXECUTE '
		SELECT	approval_instance_step_id
		FROM	approval_instance_step
		WHERE	approval_process_chain_id = $1
		AND		approval_instance_id = $2
		AND		approver_account_id = $3
		AND		is_completed = ''N''
	' INTO _step USING approval_process_chain_id,
		approval_instance_id, _acid;

	--
	-- _new gets built out for all the fields that should get inserted,
	-- and then at the end is stomped on by what actually gets inserted.
	--

	IF _step IS NULL THEN
		EXECUTE '
			INSERT INTO approval_instance_step (
				approval_instance_id, approval_process_chain_id,
				approval_instance_step_name,
				approver_account_id, approval_type, 
				approval_instance_step_due,
				description
			) VALUES (
				$1, $2, $3, $4, $5, approval_utils.calculate_due_date($6), $7
			) RETURNING approval_instance_step_id
		' INTO _step USING 
			approval_instance_id, approval_process_chain_id,
			_apc.approval_process_chain_name,
			_acid, apptype, 
			_apc.approval_chain_response_period::interval,
			concat(_apc.description, ' for ', _r.approver_account_id, ' by ',
			approving_account_id);
	END IF;

	IF _apc.refresh_all_data = 'Y' THEN
		-- this is called twice, should rethink how to not
		_v := approval_utils.refresh_approval_instance_item(approval_instance_item_id);
		_l := approval_utils.get_or_create_correct_approval_instance_link(
			approval_instance_item_id,
			_r.approval_instance_link_id
		);
		_new.approval_instance_link_id := _l;
		_new.approved_label := _v.approval_label;
		_new.approved_category := _v.approval_category;
		_new.approved_lhs := _v.approval_lhs;
		_new.approved_rhs := _v.approval_rhs;
	ELSE
		_new.approval_instance_link_id := _r.approval_instance_link_id;
		_new.approved_label := _r.approved_label;
		_new.approved_category := _r.approved_category;
		_new.approved_lhs := _r.approved_lhs;
		IF new_value IS NULL THEN
			_new.approved_rhs := _r.approved_rhs;
		ELSE
			_new.approved_rhs := new_value;
		END IF;
	END IF;

	-- RAISE NOTICE 'step is %', _step;
	-- RAISE NOTICE 'acid is %', _acid;

	EXECUTE '
		INSERT INTO approval_instance_item
			(approval_instance_link_id, approved_label, approved_category,
				approved_lhs, approved_rhs, approval_instance_step_id
			) SELECT $2, $3, $4,
				$5, $6, $7
			FROM approval_instance_item
			WHERE approval_instance_item_id = $1
			RETURNING *
	' INTO _new USING approval_instance_item_id, 
		_new.approval_instance_link_id, _new.approved_label, _new.approved_category,
		_new.approved_lhs, _new.approved_rhs,
		_step;

	-- RAISE NOTICE 'returning %', _new.approval_instance_item_id;
	RETURN _new.approval_instance_item_id;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('approval_utils', 'refresh_approval_instance_item');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS approval_utils.refresh_approval_instance_item ( approval_instance_item_id integer );
CREATE OR REPLACE FUNCTION approval_utils.refresh_approval_instance_item(approval_instance_item_id integer)
 RETURNS approval_utils.v_account_collection_approval_process
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO approval_utils, jazzhands
AS $function$
DECLARE
	_i	approval_instance_item.approval_instance_item_id%TYPE;
	_r	approval_utils.v_account_collection_approval_process%ROWTYPE;
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
			RETURN _r;
		END;
		$function$
;

--
-- Process middle (non-trigger) schema account_collection_manip
--
--
-- Process middle (non-trigger) schema script_hooks
--
--
-- Process middle (non-trigger) schema backend_utils
--
-- Creating new sequences....


--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_account_collection_relatio
CREATE TABLE val_account_collection_relatio
(
	account_collection_relation	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_account_collection_relatio', true);
--
-- Copying initialization data
--

INSERT INTO val_account_collection_relatio (
account_collection_relation,description
) VALUES
	('direct','Direct Assignment')
;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_account_collection_relatio ADD CONSTRAINT pk_val_account_collection_rela PRIMARY KEY (account_collection_relation);

-- Table/Column Comments
COMMENT ON TABLE val_account_collection_relatio IS 'Defines type of relationship';
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_account_collection_relatio and account_coll_type_relation
-- Skipping this FK since column does not exist yet
--ALTER TABLE account_coll_type_relation
--	ADD CONSTRAINT fk_acct_coll_rel_type_rel
--	FOREIGN KEY (account_collection_relation) REFERENCES val_account_collection_relatio(account_collection_relation);

-- consider FK between val_account_collection_relatio and account_collection_account
-- Skipping this FK since column does not exist yet
--ALTER TABLE account_collection_account
--	ADD CONSTRAINT fk_acctcollacct_ac_relate
--	FOREIGN KEY (account_collection_relation) REFERENCES val_account_collection_relatio(account_collection_relation);


-- FOREIGN KEYS TO

-- TRIGGERS
-- consider NEW jazzhands.acct_coll_preserve_direct
CREATE OR REPLACE FUNCTION jazzhands.acct_coll_preserve_direct()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF OLD.account_collection_relation = 'direct' THEN
		RAISE EXCEPTION 'Account Collection Relation % may not be removed',
			OLD.account_collection_relation
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE CONSTRAINT TRIGGER trigger_acct_coll_preserve_direct AFTER DELETE OR UPDATE ON val_account_collection_relatio DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE acct_coll_preserve_direct();

-- XXX - may need to include trigger function
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_account_collection_relatio');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'val_account_collection_relatio');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_account_collection_relatio');
-- DONE DEALING WITH TABLE val_account_collection_relatio
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
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pdnsdomid;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_prodstate;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pucls_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_sitec;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_property ON jazzhands.val_property;
DROP TRIGGER IF EXISTS trigger_audit_val_property ON jazzhands.val_property;
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
DROP INDEX IF EXISTS "audit"."val_property_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.val_property TEARDOWN


ALTER TABLE val_property RENAME TO val_property_v75;
ALTER TABLE audit.val_property RENAME TO val_property_v75;

CREATE TABLE val_property
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
	permit_account_collection_id	character(10) NOT NULL,
	permit_account_id	character(10) NOT NULL,
	permit_account_realm_id	character(10) NOT NULL,
	permit_company_id	character(10) NOT NULL,
	permit_company_collection_id	character(10) NOT NULL,
	permit_device_collection_id	character(10) NOT NULL,
	permit_dns_domain_id	character(10) NOT NULL,
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
	permit_x509_signed_cert_id	varchar(50) NOT NULL,
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
	ALTER permit_dns_domain_id
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
	SET DEFAULT 'PROHIBITED'::character varying;
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
	network_range_type,		-- new column (network_range_type)
	property_collection_type,
	service_env_collection_type,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,
	permit_device_collection_id,
	permit_dns_domain_id,
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
	NULL,		-- new column (network_range_type)
	property_collection_type,
	service_env_collection_type,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,
	permit_device_collection_id,
	permit_dns_domain_id,
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
FROM val_property_v75;

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
	network_range_type,		-- new column (network_range_type)
	property_collection_type,
	service_env_collection_type,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,
	permit_device_collection_id,
	permit_dns_domain_id,
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
	NULL,		-- new column (network_range_type)
	property_collection_type,
	service_env_collection_type,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,
	permit_device_collection_id,
	permit_dns_domain_id,
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
FROM audit.val_property_v75;

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
	ALTER permit_dns_domain_id
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
	SET DEFAULT 'PROHIBITED'::character varying;
ALTER TABLE val_property
	ALTER permit_property_rank
	SET DEFAULT 'PROHIBITED'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_property ADD CONSTRAINT pk_val_property PRIMARY KEY (property_name, property_type);

-- Table/Column Comments
COMMENT ON TABLE val_property IS 'valid values and attributes for (name,type) pairs in the property table.  This defines how triggers enforce aspects of the property table';
COMMENT ON COLUMN val_property.property_name IS 'property name for validation purposes';
COMMENT ON COLUMN val_property.property_type IS 'property type for validation purposes';
COMMENT ON COLUMN val_property.account_collection_type IS 'type restriction of the account_collection_id on LHS';
COMMENT ON COLUMN val_property.company_collection_type IS 'type restriction of company_collection_id on LHS';
COMMENT ON COLUMN val_property.device_collection_type IS 'type restriction of device_collection_id on LHS';
COMMENT ON COLUMN val_property.dns_domain_collection_type IS 'type restriction of dns_domain_collection_id restriction on LHS';
COMMENT ON COLUMN val_property.netblock_collection_type IS 'type restriction of netblock_collection_id on LHS';
COMMENT ON COLUMN val_property.property_collection_type IS 'type restriction of property_collection_id on LHS';
COMMENT ON COLUMN val_property.service_env_collection_type IS 'type restriction of service_enviornment_collection_id on LHS';
COMMENT ON COLUMN val_property.is_multivalue IS 'If N, acts like an alternate key on property.(lhs,property_name,property_type)';
COMMENT ON COLUMN val_property.prop_val_acct_coll_type_rstrct IS 'if property_value is account_collection_Id, this limits the account_collection_types that can be used in that column.';
COMMENT ON COLUMN val_property.prop_val_dev_coll_type_rstrct IS 'if property_value is devicet_collection_Id, this limits the devicet_collection_types that can be used in that column.';
COMMENT ON COLUMN val_property.prop_val_nblk_coll_type_rstrct IS 'if property_value isnetblockt_collection_Id, this limits the netblockt_collection_types that can be used in that column.';
COMMENT ON COLUMN val_property.property_data_type IS 'which, if any, of the property_table_* columns should be used for this value.   May turn more complex enforcement via trigger';
COMMENT ON COLUMN val_property.permit_account_collection_id IS 'defines permissibility/requirement of account_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_account_id IS 'defines permissibility/requirement of account_idon LHS of property';
COMMENT ON COLUMN val_property.permit_account_realm_id IS 'defines permissibility/requirement of account_realm_id on LHS of property';
COMMENT ON COLUMN val_property.permit_company_id IS 'defines permissibility/requirement of company_id on LHS of property.  *NOTE*  THIS COLUMN WILL BE REMOVED IN >0.65';
COMMENT ON COLUMN val_property.permit_company_collection_id IS 'defines permissibility/requirement of company_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_device_collection_id IS 'defines permissibility/requirement of device_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_dns_domain_id IS 'defines permissibility/requirement of dns_domain_id on LHS of property. *NOTE*  THIS COLUMN WILL BE REMOVED IN >0.65';
COMMENT ON COLUMN val_property.permit_dns_domain_coll_id IS 'defines permissibility/requirement of dns_domain_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_layer2_network_coll_id IS 'defines permissibility/requirement of layer2_network_id on LHS of property';
COMMENT ON COLUMN val_property.permit_layer3_network_coll_id IS 'defines permissibility/requirement of layer3_network_id on LHS of property';
COMMENT ON COLUMN val_property.permit_netblock_collection_id IS 'defines permissibility/requirement of netblock_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_operating_system_id IS 'defines permissibility/requirement of operating_system_id on LHS of property';
COMMENT ON COLUMN val_property.permit_os_snapshot_id IS 'defines permissibility/requirement of operating_system_snapshot_id on LHS of property';
COMMENT ON COLUMN val_property.permit_person_id IS 'defines permissibility/requirement of person_id on LHS of property';
COMMENT ON COLUMN val_property.permit_property_collection_id IS 'defines permissibility/requirement of property_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_service_env_collection IS 'defines permissibility/requirement of service_env_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_site_code IS 'defines permissibility/requirement of site_code on LHS of property';
COMMENT ON COLUMN val_property.permit_property_rank IS 'defines permissibility of property_rank, and if it should be part of the "lhs" of the given property';
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
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_1494616001
	CHECK (permit_dns_domain_coll_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_1664370664
	CHECK (permit_network_range_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_1804972034
	CHECK (permit_os_snapshot_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_185689986
	CHECK (permit_layer2_network_coll_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_185755522
	CHECK (permit_layer3_network_coll_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_2016888554
	CHECK (permit_account_realm_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_2139007167
	CHECK (permit_property_rank = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_271462566
	CHECK (permit_property_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_354296970
	CHECK (permit_netblock_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_366948481
	CHECK (permit_company_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_606225804
	CHECK (permit_person_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_cmp_id
	CHECK (permit_company_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_ismulti
	CHECK (is_multivalue = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_osid
	CHECK (permit_operating_system_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pacct_id
	CHECK (permit_account_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pdevcol_id
	CHECK (permit_device_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pdnsdomid
	CHECK (permit_dns_domain_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_prodstate
	CHECK (permit_service_env_collection = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pucls_id
	CHECK (permit_account_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_sitec
	CHECK (permit_site_code = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK between val_property and property_collection_property
ALTER TABLE property_collection_property
	ADD CONSTRAINT fk_prop_col_propnamtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
-- consider FK between val_property and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_nmtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
-- consider FK between val_property and val_property_value
ALTER TABLE val_property_value
	ADD CONSTRAINT fk_valproval_namtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);

-- FOREIGN KEYS TO
-- consider FK val_property and val_service_env_coll_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_prop_svcemvcoll_type
	FOREIGN KEY (service_env_collection_type) REFERENCES val_service_env_coll_type(service_env_collection_type);
-- consider FK val_property and val_device_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_prop_val_devcol_typ_rstr_dc
	FOREIGN KEY (prop_val_dev_coll_type_rstrct) REFERENCES val_device_collection_type(device_collection_type);
-- consider FK val_property and val_device_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_prop_val_devcoll_id
	FOREIGN KEY (device_collection_type) REFERENCES val_device_collection_type(device_collection_type);
-- consider FK val_property and val_account_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_acct_coll_type
	FOREIGN KEY (account_collection_type) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK val_property and val_company_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_comp_coll_type
	FOREIGN KEY (company_collection_type) REFERENCES val_company_collection_type(company_collection_type);
-- consider FK val_property and val_layer2_network_coll_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_l2netype
	FOREIGN KEY (layer2_network_collection_type) REFERENCES val_layer2_network_coll_type(layer2_network_collection_type);
-- consider FK val_property and val_layer3_network_coll_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_l3netwok_type
	FOREIGN KEY (layer3_network_collection_type) REFERENCES val_layer3_network_coll_type(layer3_network_collection_type);
-- consider FK val_property and val_netblock_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_nblk_coll_type
	FOREIGN KEY (prop_val_nblk_coll_type_rstrct) REFERENCES val_netblock_collection_type(netblock_collection_type);
-- consider FK val_property and val_dns_domain_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_property_dnsdomcolltype
	FOREIGN KEY (dns_domain_collection_type) REFERENCES val_dns_domain_collection_type(dns_domain_collection_type);
-- consider FK val_property and val_netblock_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_property_netblkcolltype
	FOREIGN KEY (netblock_collection_type) REFERENCES val_netblock_collection_type(netblock_collection_type);
-- consider FK val_property and val_network_range_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valnetrng_val_prop
	FOREIGN KEY (network_range_type) REFERENCES val_network_range_type(network_range_type);
-- consider FK val_property and val_property_data_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_propdttyp
	FOREIGN KEY (property_data_type) REFERENCES val_property_data_type(property_data_type);
-- consider FK val_property and val_property_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_proptyp
	FOREIGN KEY (property_type) REFERENCES val_property_type(property_type);
-- consider FK val_property and val_account_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_pv_actyp_rst
	FOREIGN KEY (prop_val_acct_coll_type_rstrct) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK val_property and val_property_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_vla_property_val_propcollty
	FOREIGN KEY (property_collection_type) REFERENCES val_property_collection_type(property_collection_type);

-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_property');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'val_property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_property');
DROP TABLE IF EXISTS val_property_v75;
DROP TABLE IF EXISTS audit.val_property_v75;
-- DONE DEALING WITH TABLE val_property
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE account_coll_type_relation
CREATE TABLE account_coll_type_relation
(
	account_collection_relation	varchar(50) NOT NULL,
	account_collection_type	varchar(50) NOT NULL,
	max_num_members	integer  NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'account_coll_type_relation', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE account_coll_type_relation ADD CONSTRAINT pk_account_coll_type_relation PRIMARY KEY (account_collection_relation, account_collection_type);

-- Table/Column Comments
COMMENT ON TABLE account_coll_type_relation IS 'Defines types of account collection relations that are permitted for a given account collection type.  This is trigger enforced, and ''direct'' is added here as part of an insert trigger on val_account_collection_type.';
-- INDEXES
CREATE INDEX xifacct_coll_rel_type_rel ON account_coll_type_relation USING btree (account_collection_relation);
CREATE INDEX xifacct_coll_rel_type_type ON account_coll_type_relation USING btree (account_collection_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK account_coll_type_relation and val_account_collection_relatio
ALTER TABLE account_coll_type_relation
	ADD CONSTRAINT fk_acct_coll_rel_type_rel
	FOREIGN KEY (account_collection_relation) REFERENCES val_account_collection_relatio(account_collection_relation);
-- consider FK account_coll_type_relation and val_account_collection_type
ALTER TABLE account_coll_type_relation
	ADD CONSTRAINT fk_acct_coll_rel_type_type
	FOREIGN KEY (account_collection_type) REFERENCES val_account_collection_type(account_collection_type);

-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'account_coll_type_relation');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'account_coll_type_relation');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'account_coll_type_relation');
-- DONE DEALING WITH TABLE account_coll_type_relation
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE account_collection_account
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_collection_account', 'account_collection_account');

-- FOREIGN KEYS FROM
ALTER TABLE account_unix_info DROP CONSTRAINT IF EXISTS fk_acct_unx_info_ac_acct;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.account_collection_account DROP CONSTRAINT IF EXISTS fk_acctcol_usr_ucol_id;
ALTER TABLE jazzhands.account_collection_account DROP CONSTRAINT IF EXISTS fk_acol_account_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'account_collection_account');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.account_collection_account DROP CONSTRAINT IF EXISTS ak_acctcol_acct_rank;
ALTER TABLE jazzhands.account_collection_account DROP CONSTRAINT IF EXISTS pk_account_collection_user;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_account_collection_account_realm ON jazzhands.account_collection_account;
DROP TRIGGER IF EXISTS trig_userlog_account_collection_account ON jazzhands.account_collection_account;
DROP TRIGGER IF EXISTS trigger_account_collection_member_enforce ON jazzhands.account_collection_account;
DROP TRIGGER IF EXISTS trigger_audit_account_collection_account ON jazzhands.account_collection_account;
DROP TRIGGER IF EXISTS trigger_pgnotify_account_collection_account_token_changes ON jazzhands.account_collection_account;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'account_collection_account');
---- BEGIN audit.account_collection_account TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'account_collection_account', 'account_collection_account');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'account_collection_account');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.account_collection_account DROP CONSTRAINT IF EXISTS account_collection_account_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."account_collection_account_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."aud_account_collection_account_ak_acctcol_acct_rank";
DROP INDEX IF EXISTS "audit"."aud_account_collection_account_pk_account_collection_user";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.account_collection_account TEARDOWN


ALTER TABLE account_collection_account RENAME TO account_collection_account_v75;
ALTER TABLE audit.account_collection_account RENAME TO account_collection_account_v75;

CREATE TABLE account_collection_account
(
	account_collection_id	integer NOT NULL,
	account_id	integer NOT NULL,
	account_collection_relation	varchar(50)  NULL,
	account_id_rank	integer  NULL,
	start_date	timestamp without time zone  NULL,
	finish_date	timestamp without time zone  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'account_collection_account', false);
ALTER TABLE account_collection_account
	ALTER account_collection_relation
	SET DEFAULT 'direct'::character varying;
INSERT INTO account_collection_account (
	account_collection_id,
	account_id,
	account_collection_relation,		-- new column (account_collection_relation)
	account_id_rank,
	start_date,
	finish_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	account_collection_id,
	account_id,
	'direct'::character varying,		-- new column (account_collection_relation)
	account_id_rank,
	start_date,
	finish_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM account_collection_account_v75;

INSERT INTO audit.account_collection_account (
	account_collection_id,
	account_id,
	account_collection_relation,		-- new column (account_collection_relation)
	account_id_rank,
	start_date,
	finish_date,
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
	account_collection_id,
	account_id,
	'direct',		-- new column (account_collection_relation)
	account_id_rank,
	start_date,
	finish_date,
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
FROM audit.account_collection_account_v75;

ALTER TABLE account_collection_account
	ALTER account_collection_relation
	SET DEFAULT 'direct'::character varying;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE account_collection_account ADD CONSTRAINT ak_acctcol_acct_rank UNIQUE (account_collection_id, account_id_rank);
ALTER TABLE account_collection_account ADD CONSTRAINT pk_account_collection_user PRIMARY KEY (account_collection_id, account_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xifacctcollacct_ac_relate ON account_collection_account USING btree (account_collection_relation);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between account_collection_account and account_unix_info
ALTER TABLE account_unix_info
	ADD CONSTRAINT fk_acct_unx_info_ac_acct
	FOREIGN KEY (unix_group_acct_collection_id, account_id) REFERENCES account_collection_account(account_collection_id, account_id);

-- FOREIGN KEYS TO
-- consider FK account_collection_account and account_collection
ALTER TABLE account_collection_account
	ADD CONSTRAINT fk_acctcol_usr_ucol_id
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);
-- consider FK account_collection_account and val_account_collection_relatio
ALTER TABLE account_collection_account
	ADD CONSTRAINT fk_acctcollacct_ac_relate
	FOREIGN KEY (account_collection_relation) REFERENCES val_account_collection_relatio(account_collection_relation);
-- consider FK account_collection_account and account
ALTER TABLE account_collection_account
	ADD CONSTRAINT fk_acol_account_id
	FOREIGN KEY (account_id) REFERENCES account(account_id);

-- TRIGGERS
-- consider NEW jazzhands.account_collection_account_realm
CREATE OR REPLACE FUNCTION jazzhands.account_collection_account_realm()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_a	account%ROWTYPE;
	_at	val_account_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	_at
	FROM	val_account_collection_type
		JOIN account_collection USING (account_collection_type)
	WHERE
		account_collection_id = NEW.account_collection_id;

	-- no restrictions, so do not care
	IF _at.account_realm_id IS NULL THEN
		RETURN NEW;
	END IF;

	-- check to see if the account's account realm matches
	IF TG_OP = 'INSERT' OR OLD.account_id != NEW.account_id THEN
		SELECT	*
		INTO	_a
		FROM	account
		WHERE	account_id = NEW.account_id;

		IF _a.account_realm_id != _at.account_realm_id THEN
			RAISE EXCEPTION 'account realm of % does not match account realm restriction on account_collection %',
				NEW.account_id, NEW.account_collection_id
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trig_account_collection_account_realm AFTER INSERT OR UPDATE ON account_collection_account FOR EACH ROW EXECUTE PROCEDURE account_collection_account_realm();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.account_coll_member_relation_enforce
CREATE OR REPLACE FUNCTION jazzhands.account_coll_member_relation_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	act	account_coll_type_relation%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	act
	FROM	account_coll_type_relation
	WHERE	account_collection_type =
		(select account_collection_type from account_collection
			where account_collection_id = NEW.account_collection_id)
	AND		account_collection_relation = NEW.account_collection_relation;

	IF act.MAX_NUM_MEMBERS IS NOT NULL THEN
		SELECT count(*)
		  INTO tally
		  FROM account_collection_account
		  		JOIN account_collection USING (account_collection_id)
		  WHERE account_collection_type = act.account_collection_type
		  AND account_collection_relation = NEW.account_collection_relation;

		IF tally > act.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;
CREATE CONSTRAINT TRIGGER trigger_account_coll_member_relation_enforce AFTER INSERT OR UPDATE ON account_collection_account DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE account_coll_member_relation_enforce();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.account_collection_member_enforce
CREATE OR REPLACE FUNCTION jazzhands.account_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
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
			RAISE EXCEPTION 'Account may not be a member of more than % collections of type %',
				act.MAX_NUM_COLLECTIONS, act.account_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;
CREATE CONSTRAINT TRIGGER trigger_account_collection_member_enforce AFTER INSERT OR UPDATE ON account_collection_account DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE account_collection_member_enforce();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.pgnotify_account_collection_account_token_changes
CREATE OR REPLACE FUNCTION jazzhands.pgnotify_account_collection_account_token_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
		PERFORM	*
		FROM	property_collection
				JOIN property_collection_property pcp
					USING (property_collection_id)
				JOIN property p
					USING (property_name, property_type)
		WHERE	p.account_collection_id = OLD.account_collection_id
		AND		property_collection_type = 'jazzhands-internal'
		AND		property_collection_name = 'notify-account_collection_account'
		;

		IF FOUND THEN
			PERFORM pg_notify('account_change', concat('account_id=', OLD.account_id));
		END IF;
	END IF;
	IF TG_OP = 'UPDATE' OR TG_OP = 'INSERT' THEN
		PERFORM	*
		FROM	property_collection
				JOIN property_collection_property pcp
					USING (property_collection_id)
				JOIN property p
					USING (property_name, property_type)
		WHERE	p.account_collection_id = NEW.account_collection_id
		AND		property_collection_type = 'jazzhands-internal'
		AND		property_collection_name = 'notify-account_collection_account'
		;

		IF FOUND THEN
			PERFORM pg_notify('account_change', concat('account_id=', NEW.account_id));
		END IF;
	END IF;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;
CREATE TRIGGER trigger_pgnotify_account_collection_account_token_changes AFTER INSERT OR DELETE OR UPDATE ON account_collection_account FOR EACH ROW EXECUTE PROCEDURE pgnotify_account_collection_account_token_changes();

-- XXX - may need to include trigger function
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'account_collection_account');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'account_collection_account');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'account_collection_account');
DROP TABLE IF EXISTS account_collection_account_v75;
DROP TABLE IF EXISTS audit.account_collection_account_v75;
-- DONE DEALING WITH TABLE account_collection_account
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE department
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'department', 'department');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS fk_dept_badge_type;
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS fk_dept_company;
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS fk_dept_mgr_acct_id;
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS fk_dept_usr_col_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'department');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS pk_deptid;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_dept_deptcode_companyid";
DROP INDEX IF EXISTS "jazzhands"."xif6department";
DROP INDEX IF EXISTS "jazzhands"."xifdept_badge_type";
DROP INDEX IF EXISTS "jazzhands"."xifdept_company";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS ckc_is_active_dept;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_department ON jazzhands.department;
DROP TRIGGER IF EXISTS trigger_audit_department ON jazzhands.department;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'department');
---- BEGIN audit.department TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'department', 'department');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'department');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.department DROP CONSTRAINT IF EXISTS department_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_department_pk_deptid";
DROP INDEX IF EXISTS "audit"."department_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.department TEARDOWN


ALTER TABLE department RENAME TO department_v75;
ALTER TABLE audit.department RENAME TO department_v75;

CREATE TABLE department
(
	account_collection_id	integer NOT NULL,
	company_id	integer NOT NULL,
	manager_account_id	integer  NULL,
	is_active	character(1) NOT NULL,
	dept_code	varchar(30)  NULL,
	cost_center	varchar(10)  NULL,
	cost_center_name	varchar(255)  NULL,
	cost_center_number	integer  NULL,
	default_badge_type_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'department', false);
ALTER TABLE department
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;
INSERT INTO department (
	account_collection_id,
	company_id,
	manager_account_id,
	is_active,
	dept_code,
	cost_center,
	cost_center_name,
	cost_center_number,
	default_badge_type_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	account_collection_id,
	company_id,
	manager_account_id,
	is_active,
	dept_code,
	cost_center,
	cost_center_name,
	cost_center_number,
	default_badge_type_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM department_v75;

INSERT INTO audit.department (
	account_collection_id,
	company_id,
	manager_account_id,
	is_active,
	dept_code,
	cost_center,
	cost_center_name,
	cost_center_number,
	default_badge_type_id,
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
	account_collection_id,
	company_id,
	manager_account_id,
	is_active,
	dept_code,
	cost_center,
	cost_center_name,
	cost_center_number,
	default_badge_type_id,
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
FROM audit.department_v75;

ALTER TABLE department
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE department ADD CONSTRAINT pk_deptid PRIMARY KEY (account_collection_id);

-- Table/Column Comments
COMMENT ON COLUMN department.cost_center IS 'THIS COLUMN IS DEPRECATED.  It will be removed >= 0.66.  Please use _name and _number.';
-- INDEXES
CREATE INDEX idx_dept_deptcode_companyid ON department USING btree (dept_code, company_id);
CREATE INDEX xif6department ON department USING btree (manager_account_id);
CREATE INDEX xifdept_badge_type ON department USING btree (default_badge_type_id);
CREATE INDEX xifdept_company ON department USING btree (company_id);

-- CHECK CONSTRAINTS
ALTER TABLE department ADD CONSTRAINT ckc_is_active_dept
	CHECK ((is_active = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_active)::text = upper((is_active)::text)));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK department and badge_type
ALTER TABLE department
	ADD CONSTRAINT fk_dept_badge_type
	FOREIGN KEY (default_badge_type_id) REFERENCES badge_type(badge_type_id);
-- consider FK department and company
ALTER TABLE department
	ADD CONSTRAINT fk_dept_company
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK department and account
ALTER TABLE department
	ADD CONSTRAINT fk_dept_mgr_acct_id
	FOREIGN KEY (manager_account_id) REFERENCES account(account_id);
-- consider FK department and account_collection
ALTER TABLE department
	ADD CONSTRAINT fk_dept_usr_col_id
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);

-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'department');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'department');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'department');
DROP TABLE IF EXISTS department_v75;
DROP TABLE IF EXISTS audit.department_v75;
-- DONE DEALING WITH TABLE department
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE dns_record
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_record', 'dns_record');

-- FOREIGN KEYS FROM
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_device_id_dnsrecord;
ALTER TABLE dns_record_relation DROP CONSTRAINT IF EXISTS fk_dns_rec_ref_dns_rec_rltn;
ALTER TABLE dns_record_relation DROP CONSTRAINT IF EXISTS fk_dnsrec_ref_dnsrecrltn_rl_id;
ALTER TABLE network_service DROP CONSTRAINT IF EXISTS fk_netsvc_dnsid_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS fk_dns_record_vdnsclass;
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS fk_dnsid_dnsdom_id;
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS fk_dnsid_nblk_id;
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS fk_dnsrec_ref_dns_ref_id;
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS fk_dnsrec_vdnssrvsrvc;
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS fk_dnsrecord_dnsrecord;
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS fk_dnsrecord_vdnstype;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'dns_record');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS pk_dns_record;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_dns_record_lower_dns_name";
DROP INDEX IF EXISTS "jazzhands"."idx_dnsrec_dnsclass";
DROP INDEX IF EXISTS "jazzhands"."idx_dnsrec_dnssrvservice";
DROP INDEX IF EXISTS "jazzhands"."idx_dnsrec_dnstype";
DROP INDEX IF EXISTS "jazzhands"."idx_dnsrec_refdnsrec";
DROP INDEX IF EXISTS "jazzhands"."ix_dnsid_domid";
DROP INDEX IF EXISTS "jazzhands"."ix_dnsid_netblock_id";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS ckc_dns_srv_protocol_dns_reco;
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS ckc_is_enabled_dns_reco;
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS ckc_should_generate_p_dns_reco;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_dns_record ON jazzhands.dns_record;
DROP TRIGGER IF EXISTS trigger_audit_dns_record ON jazzhands.dns_record;
DROP TRIGGER IF EXISTS trigger_dns_a_rec_validation ON jazzhands.dns_record;
DROP TRIGGER IF EXISTS trigger_dns_non_a_rec_validation ON jazzhands.dns_record;
DROP TRIGGER IF EXISTS trigger_dns_rec_prevent_dups ON jazzhands.dns_record;
DROP TRIGGER IF EXISTS trigger_dns_record_check_name ON jazzhands.dns_record;
DROP TRIGGER IF EXISTS trigger_dns_record_cname_checker ON jazzhands.dns_record;
DROP TRIGGER IF EXISTS trigger_dns_record_update_nontime ON jazzhands.dns_record;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'dns_record');
---- BEGIN audit.dns_record TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'dns_record', 'dns_record');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'dns_record');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.dns_record DROP CONSTRAINT IF EXISTS dns_record_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_dns_record_pk_dns_record";
DROP INDEX IF EXISTS "audit"."dns_record_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.dns_record TEARDOWN


ALTER TABLE dns_record RENAME TO dns_record_v75;
ALTER TABLE audit.dns_record RENAME TO dns_record_v75;

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
	ip_universe_id	integer NOT NULL,
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
	ALTER ip_universe_id
	SET DEFAULT 0;
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
	ip_universe_id,		-- new column (ip_universe_id)
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
	0,		-- new column (ip_universe_id)
	reference_dns_record_id,
	dns_value_record_id,
	should_generate_ptr,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM dns_record_v75;

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
	ip_universe_id,		-- new column (ip_universe_id)
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
	"aud#realtime",
	"aud#txid",
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
	0,		-- new column (ip_universe_id)
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
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM audit.dns_record_v75;

ALTER TABLE dns_record
	ALTER dns_record_id
	SET DEFAULT nextval('dns_record_dns_record_id_seq'::regclass);
ALTER TABLE dns_record
	ALTER dns_class
	SET DEFAULT 'IN'::character varying;
ALTER TABLE dns_record
	ALTER ip_universe_id
	SET DEFAULT 0;
ALTER TABLE dns_record
	ALTER should_generate_ptr
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE dns_record
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE dns_record ADD CONSTRAINT ak_dns_record_dnsrec_domainid UNIQUE (dns_record_id, dns_domain_id);
ALTER TABLE dns_record ADD CONSTRAINT pk_dns_record PRIMARY KEY (dns_record_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX idx_dns_record_lower_dns_name ON dns_record USING btree (lower(dns_name::text));
CREATE INDEX idx_dnsrec_dnsclass ON dns_record USING btree (dns_class);
CREATE INDEX idx_dnsrec_dnssrvservice ON dns_record USING btree (dns_srv_service);
CREATE INDEX idx_dnsrec_dnstype ON dns_record USING btree (dns_type);
CREATE INDEX ix_dnsid_domid ON dns_record USING btree (dns_domain_id);
CREATE INDEX ix_dnsid_netblock_id ON dns_record USING btree (netblock_id);
CREATE INDEX xif8dns_record ON dns_record USING btree (reference_dns_record_id, dns_domain_id);
CREATE INDEX xif9dns_record ON dns_record USING btree (ip_universe_id);

-- CHECK CONSTRAINTS
ALTER TABLE dns_record ADD CONSTRAINT ckc_dns_srv_protocol_dns_reco
	CHECK ((dns_srv_protocol IS NULL) OR (((dns_srv_protocol)::text = ANY ((ARRAY['tcp'::character varying, 'udp'::character varying])::text[])) AND ((dns_srv_protocol)::text = lower((dns_srv_protocol)::text))));
ALTER TABLE dns_record ADD CONSTRAINT ckc_is_enabled_dns_reco
	CHECK ((is_enabled = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_enabled)::text = upper((is_enabled)::text)));
ALTER TABLE dns_record ADD CONSTRAINT ckc_should_generate_p_dns_reco
	CHECK ((should_generate_ptr = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((should_generate_ptr)::text = upper((should_generate_ptr)::text)));

-- FOREIGN KEYS FROM
-- consider FK between dns_record and device
ALTER TABLE device
	ADD CONSTRAINT fk_device_id_dnsrecord
	FOREIGN KEY (identifying_dns_record_id) REFERENCES dns_record(dns_record_id) DEFERRABLE;
-- consider FK between dns_record and dns_record_relation
ALTER TABLE dns_record_relation
	ADD CONSTRAINT fk_dns_rec_ref_dns_rec_rltn
	FOREIGN KEY (dns_record_id) REFERENCES dns_record(dns_record_id);
-- consider FK between dns_record and dns_record_relation
ALTER TABLE dns_record_relation
	ADD CONSTRAINT fk_dnsrec_ref_dnsrecrltn_rl_id
	FOREIGN KEY (related_dns_record_id) REFERENCES dns_record(dns_record_id);
-- consider FK between dns_record and network_service
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_dnsid_id
	FOREIGN KEY (dns_record_id) REFERENCES dns_record(dns_record_id);

-- FOREIGN KEYS TO
-- consider FK dns_record and ip_universe
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dns_rec_ip_universe
	FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id);
-- consider FK dns_record and val_dns_class
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dns_record_vdnsclass
	FOREIGN KEY (dns_class) REFERENCES val_dns_class(dns_class);
-- consider FK dns_record and dns_domain
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsid_dnsdom_id
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);
-- consider FK dns_record and netblock
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsid_nblk_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
-- consider FK dns_record and dns_record
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsrec_ref_dns_ref_id
	FOREIGN KEY (dns_value_record_id) REFERENCES dns_record(dns_record_id);
-- consider FK dns_record and val_dns_srv_service
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsrec_vdnssrvsrvc
	FOREIGN KEY (dns_srv_service) REFERENCES val_dns_srv_service(dns_srv_service);
-- consider FK dns_record and dns_record
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsrecord_dnsrecord
	FOREIGN KEY (reference_dns_record_id, dns_domain_id) REFERENCES dns_record(dns_record_id, dns_domain_id);
-- consider FK dns_record and val_dns_type
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsrecord_vdnstype
	FOREIGN KEY (dns_type) REFERENCES val_dns_type(dns_type);

-- TRIGGERS
-- consider NEW jazzhands.check_ip_universe_dns_record
CREATE OR REPLACE FUNCTION jazzhands.check_ip_universe_dns_record()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	nb	integer[];
BEGIN
	IF TG_OP = 'UPDATE' THEN
		IF NEW.netblock_id != OLD.netblock_id THEN
			nb = ARRAY[OLD.netblock_id, NEW.netblock_id];
		ELSE
			nb = ARRAY[NEW.netblock_id];
		END IF;
	ELSE
		nb = ARRAY[NEW.netblock_id];
	END IF;

	PERFORM *
	FROM netblock
	WHERE netblock_id = ANY(nb)
	AND ip_universe_id != NEW.ip_universe_id;

	IF FOUND THEN
		RAISE EXCEPTION
			'IP Universes for dns_records must match dns records and netblocks'
			USING ERRCODE = 'foreign_key_violation';
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE CONSTRAINT TRIGGER trigger_check_ip_universe_dns_record AFTER INSERT OR UPDATE OF dns_record_id, ip_universe_id ON dns_record DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE check_ip_universe_dns_record();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.dns_a_rec_validation
CREATE OR REPLACE FUNCTION jazzhands.dns_a_rec_validation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_ip		netblock.ip_address%type;
	_sing	netblock.is_single_address%type;
BEGIN
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

		IF ( NEW.should_generate_ptr = 'Y' AND NEW.dns_value_record_id IS NOT NULL ) THEN
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

		IF _sing = 'N' AND NEW.dns_type IN ('A','AAAA') THEN
			RAISE EXCEPTION 'Non-single addresses may not have % records', NEW.dns_type
				USING ERRCODE = 'foreign_key_violation';
		END IF;

	END IF;


	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_dns_a_rec_validation BEFORE INSERT OR UPDATE ON dns_record FOR EACH ROW EXECUTE PROCEDURE dns_a_rec_validation();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.dns_non_a_rec_validation
CREATE OR REPLACE FUNCTION jazzhands.dns_non_a_rec_validation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_ip		netblock.ip_address%type;
BEGIN
	IF NEW.dns_type NOT in ('A', 'AAAA', 'REVERSE_ZONE_BLOCK_PTR') AND
			( NEW.dns_value IS NULL AND NEW.dns_value_record_id IS NULL ) THEN
		RAISE EXCEPTION 'Attempt to set % record without a value',
			NEW.dns_type
			USING ERRCODE = 'not_null_violation';
	END IF;

	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_dns_non_a_rec_validation BEFORE INSERT OR UPDATE ON dns_record FOR EACH ROW EXECUTE PROCEDURE dns_non_a_rec_validation();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.dns_rec_prevent_dups
CREATE OR REPLACE FUNCTION jazzhands.dns_rec_prevent_dups()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	-- should not be able to insert the same record(s) twice
	WITH newref AS (
		SELECT * FROM dns_record
			WHERE NEW.reference_dns_record_id IS NOT NULL
			AND NEW.reference_dns_record_id = dns_record_id
			ORDER BY dns_record_id LIMIT 1
	), dns AS ( SELECT
			db.dns_record_id,
			coalesce(ref.dns_name, db.dns_name) as dns_name,
			db.dns_domain_id, db.dns_ttl,
			db.dns_class, db.dns_type,
			coalesce(val.dns_value, db.dns_value) AS dns_value,
			db.dns_priority, db.dns_srv_service, db.dns_srv_protocol,
			db.dns_srv_weight, db.dns_srv_port,
			coalesce(val.netblock_id, db.netblock_id) AS netblock_id,
			db.reference_dns_record_id, db.dns_value_record_id,
			db.should_generate_ptr, db.is_enabled
		FROM dns_record db
			LEFT JOIN dns_record ref
				ON ( db.reference_dns_record_id = ref.dns_record_id)
			LEFT JOIN dns_record val
				ON ( db.dns_value_record_id = val.dns_record_id )
			LEFT JOIN newref
				ON newref.dns_record_id = NEW.reference_dns_record_id
		WHERE db.dns_record_id != NEW.dns_record_id
		AND (lower(coalesce(ref.dns_name, db.dns_name))
					IS NOT DISTINCT FROM
				lower(coalesce(newref.dns_name, NEW.dns_name)) )
		AND ( db.dns_domain_id = NEW.dns_domain_id )
		AND ( db.dns_class = NEW.dns_class )
		AND ( db.dns_type = NEW.dns_type )
    		AND db.dns_record_id != NEW.dns_record_id
		AND db.dns_srv_service IS NOT DISTINCT FROM NEW.dns_srv_service
		AND db.dns_srv_protocol IS NOT DISTINCT FROM NEW.dns_srv_protocol
		AND db.dns_srv_port IS NOT DISTINCT FROM NEW.dns_srv_port
		AND db.is_enabled = 'Y'
	) SELECT	count(*)
		INTO	_tally
		FROM dns
			LEFT JOIN dns_record val
				ON ( NEW.dns_value_record_id = val.dns_record_id )
		WHERE
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
$function$
;
CREATE TRIGGER trigger_dns_rec_prevent_dups BEFORE INSERT OR UPDATE ON dns_record FOR EACH ROW EXECUTE PROCEDURE dns_rec_prevent_dups();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.dns_record_check_name
CREATE OR REPLACE FUNCTION jazzhands.dns_record_check_name()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF NEW.DNS_NAME IS NOT NULL THEN
		-- rfc rfc952
		IF NEW.DNS_NAME !~ '[-a-zA-Z0-9\._]*' THEN
			RAISE EXCEPTION 'Invalid DNS NAME %',
				NEW.DNS_NAME
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_dns_record_check_name BEFORE INSERT OR UPDATE OF dns_name ON dns_record FOR EACH ROW EXECUTE PROCEDURE dns_record_check_name();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.dns_record_cname_checker
CREATE OR REPLACE FUNCTION jazzhands.dns_record_cname_checker()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
	_dom	TEXT;
BEGIN
	_tally := 0;
	IF TG_OP = 'INSERT' OR NEW.DNS_TYPE != OLD.DNS_TYPE THEN
		IF NEW.DNS_TYPE = 'CNAME' THEN
			IF TG_OP = 'UPDATE' THEN
			SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE
						NEW.dns_domain_id = x.dns_domain_id
				 AND	OLD.dns_record_id != x.dns_record_id
				 AND	(
							NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			ELSE
				-- only difference between above and this is the use of OLD
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE
						NEW.dns_domain_id = x.dns_domain_id
				 AND	(
							NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			END IF;
		-- this clause is basically the same as above except = 'CANME'
		ELSIF NEW.DNS_TYPE != 'CNAME' THEN
			IF TG_OP = 'UPDATE' THEN
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE	x.dns_type = 'CNAME'
				 AND	NEW.dns_domain_id = x.dns_domain_id
				 AND	OLD.dns_record_id != x.dns_record_id
				 AND	(
							NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			ELSE
				-- only difference between above and this is the use of OLD
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE	x.dns_type = 'CNAME'
				 AND	NEW.dns_domain_id = x.dns_domain_id
				 AND	(
							NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			END IF;
		END IF;
	END IF;

	IF _tally > 0 THEN
		SELECT soa_name INTO _dom FROM dns_domain
		WHERE dns_domain_id = NEW.dns_domain_id ;

		if NEW.dns_name IS NULL THEN
			RAISE EXCEPTION '% may not have CNAME and other records (%)',
				_dom, _tally
				USING ERRCODE = 'unique_violation';
		ELSE
			RAISE EXCEPTION '%.% may not have CNAME and other records (%)',
				NEW.dns_name, _dom, _tally
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_dns_record_cname_checker BEFORE INSERT OR UPDATE OF dns_type ON dns_record FOR EACH ROW EXECUTE PROCEDURE dns_record_cname_checker();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.dns_record_enabled_check
CREATE OR REPLACE FUNCTION jazzhands.dns_record_enabled_check()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
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
CREATE TRIGGER trigger_dns_record_enabled_check BEFORE INSERT OR UPDATE OF is_enabled ON dns_record FOR EACH ROW EXECUTE PROCEDURE dns_record_enabled_check();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.dns_record_update_nontime
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

		IF OLD.dns_name IS DISTINCT FROM NEW.dns_name THEN
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

		IF (OLD.netblock_id IS DISTINCT FROM NEW.netblock_id) THEN
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
CREATE TRIGGER trigger_dns_record_update_nontime AFTER INSERT OR DELETE OR UPDATE ON dns_record FOR EACH ROW EXECUTE PROCEDURE dns_record_update_nontime();

-- XXX - may need to include trigger function
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'dns_record');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'dns_record');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'dns_record');
ALTER SEQUENCE dns_record_dns_record_id_seq
	 OWNED BY dns_record.dns_record_id;
DROP TABLE IF EXISTS dns_record_v75;
DROP TABLE IF EXISTS audit.dns_record_v75;
-- DONE DEALING WITH TABLE dns_record
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_unix_passwd_mappings
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_unix_passwd_mappings', 'v_unix_passwd_mappings');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_unix_passwd_mappings');
DROP VIEW IF EXISTS jazzhands.v_unix_passwd_mappings;
CREATE VIEW jazzhands.v_unix_passwd_mappings AS
 WITH passtype AS (
         SELECT ap.account_id,
            ap.password,
            ap.expire_time,
            ap.change_time,
            subq.device_collection_id,
            subq.password_type,
            subq.ord
           FROM ( SELECT dchd.device_collection_id,
                    p.property_value_password_type AS password_type,
                    row_number() OVER (PARTITION BY dchd.device_collection_id) AS ord
                   FROM v_property p
                     JOIN v_device_coll_hier_detail dchd ON dchd.parent_device_collection_id = p.device_collection_id
                  WHERE p.property_name::text = 'UnixPwType'::text AND p.property_type::text = 'MclassUnixProp'::text) subq
             JOIN account_password ap USING (password_type)
             JOIN account_unix_info a USING (account_id)
          WHERE subq.ord = 1
        )
 SELECT s.device_collection_id,
    s.account_id,
    s.login,
    s.crypt,
    s.unix_uid,
    s.unix_group_name,
    regexp_replace(s.gecos, ' +'::text, ' '::text, 'g'::text) AS gecos,
    regexp_replace(
        CASE
            WHEN s.forcehome IS NOT NULL AND s.forcehome::text ~ '/$'::text THEN concat(s.forcehome, s.login)
            WHEN s.home IS NOT NULL AND s.home::text ~ '^/'::text THEN s.home::text
            WHEN s.hometype::text = 'generic'::text THEN concat(COALESCE(s.homeplace, '/home'::character varying), '/', 'generic')
            WHEN s.home IS NOT NULL AND s.home::text ~ '/$'::text THEN concat(s.home, '/', s.login)
            WHEN s.homeplace IS NOT NULL AND s.homeplace::text ~ '/$'::text THEN concat(s.homeplace, '/', s.login)
            ELSE concat(COALESCE(s.homeplace, '/home'::character varying), '/', s.login)
        END, '/+'::text, '/'::text, 'g'::text) AS home,
    s.shell,
    s.ssh_public_key,
    s.setting,
    s.mclass_setting,
    s.group_names AS extra_groups
   FROM ( SELECT o.device_collection_id,
            a.account_id,
            a.login,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceCrypt'::text)]::text,
                CASE
                    WHEN pwt.expire_time IS NOT NULL AND now() < pwt.expire_time OR (now() - pwt.change_time) < concat(COALESCE((( SELECT v_property.property_value
                       FROM v_property
                      WHERE v_property.property_type::text = 'Defaults'::text AND v_property.property_name::text = '_maxpasswdlife'::text))::text, 90::text), 'days')::interval THEN pwt.password
                    ELSE NULL::character varying
                END::text, '*'::text) AS crypt,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceUserUID'::text)]::integer, a.unix_uid) AS unix_uid,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceUserGroup'::text)]::character varying(255), ugac.account_collection_name) AS unix_group_name,
                CASE
                    WHEN a.description IS NOT NULL THEN a.description::text
                    ELSE concat(COALESCE(p.preferred_first_name, p.first_name), ' ',
                    CASE
                        WHEN p.middle_name IS NOT NULL AND length(p.middle_name::text) = 1 THEN concat(p.middle_name, '.')::character varying
                        ELSE p.middle_name
                    END, ' ', COALESCE(p.preferred_last_name, p.last_name))
                END AS gecos,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceHome'::text)], a.default_home) AS home,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceShell'::text)], a.shell) AS shell,
            o.setting,
            mcs.mclass_setting,
            o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceHome'::text)] AS forcehome,
            mcs.mclass_setting[( SELECT i.i + 1
                   FROM generate_subscripts(mcs.mclass_setting, 1) i(i)
                  WHERE mcs.mclass_setting[i.i]::text = 'HomePlace'::text)] AS homeplace,
            mcs.mclass_setting[( SELECT i.i + 1
                   FROM generate_subscripts(mcs.mclass_setting, 1) i(i)
                  WHERE mcs.mclass_setting[i.i]::text = 'UnixHomeType'::text)] AS hometype,
            ssh.ssh_public_key,
            extra_groups.group_names
           FROM ( SELECT a_1.account_id,
                    a_1.login,
                    a_1.person_id,
                    a_1.company_id,
                    a_1.is_enabled,
                    a_1.account_realm_id,
                    a_1.account_status,
                    a_1.account_role,
                    a_1.account_type,
                    a_1.description,
                    a_1.data_ins_user,
                    a_1.data_ins_date,
                    a_1.data_upd_user,
                    a_1.data_upd_date,
                    aui.unix_uid,
                    aui.unix_group_acct_collection_id,
                    aui.shell,
                    aui.default_home
                   FROM account a_1
                     JOIN account_unix_info aui USING (account_id)
                  WHERE a_1.is_enabled = 'Y'::bpchar) a
             JOIN v_device_col_account_cart o USING (account_id)
             JOIN device_collection dc USING (device_collection_id)
             JOIN person p USING (person_id)
             JOIN unix_group ug ON a.unix_group_acct_collection_id = ug.account_collection_id
             JOIN account_collection ugac ON ugac.account_collection_id = ug.account_collection_id
             LEFT JOIN ( SELECT p_1.device_collection_id,
                    acae.account_id,
                    array_agg(ac.account_collection_name) AS group_names
                   FROM v_property p_1
                     JOIN device_collection dc_1 USING (device_collection_id)
                     JOIN account_collection ac USING (account_collection_id)
                     JOIN account_collection pac ON pac.account_collection_id = p_1.property_value_account_coll_id
                     JOIN v_acct_coll_acct_expanded acae ON pac.account_collection_id = acae.account_collection_id
                  WHERE p_1.property_type::text = 'MclassUnixProp'::text AND p_1.property_name::text = 'UnixGroupMemberOverride'::text AND dc_1.device_collection_type::text <> 'mclass'::text
                  GROUP BY p_1.device_collection_id, acae.account_id) extra_groups USING (device_collection_id, account_id)
             LEFT JOIN v_device_collection_account_ssh_key ssh ON a.account_id = ssh.account_id AND (ssh.device_collection_id IS NULL OR ssh.device_collection_id = o.device_collection_id)
             LEFT JOIN v_unix_mclass_settings mcs ON mcs.device_collection_id = dc.device_collection_id
             LEFT JOIN passtype pwt ON o.device_collection_id = pwt.device_collection_id AND a.account_id = pwt.account_id) s
  ORDER BY s.device_collection_id, s.account_id;

delete from __recreate where type = 'view' and object = 'v_unix_passwd_mappings';
-- DONE DEALING WITH TABLE v_unix_passwd_mappings
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_unix_group_mappings
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_unix_group_mappings', 'v_unix_group_mappings');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_unix_group_mappings');
DROP VIEW IF EXISTS jazzhands.v_unix_group_mappings;
CREATE VIEW jazzhands.v_unix_group_mappings AS
 SELECT dc.device_collection_id,
    ac.account_collection_id,
    ac.account_collection_name AS group_name,
    COALESCE(o.setting[( SELECT i.i + 1
           FROM generate_subscripts(o.setting, 1) i(i)
          WHERE o.setting[i.i]::text = 'ForceGroupGID'::text)]::integer, unix_group.unix_gid) AS unix_gid,
    unix_group.group_password,
    o.setting,
    mcs.mclass_setting,
    array_agg(DISTINCT a.login ORDER BY a.login) AS members
   FROM device_collection dc
     JOIN ( SELECT dch.device_collection_id,
            vace.account_collection_id
           FROM v_property p
             JOIN v_device_coll_hier_detail dch ON p.device_collection_id = dch.parent_device_collection_id
             JOIN v_account_collection_expanded vace ON vace.root_account_collection_id = p.account_collection_id
          WHERE p.property_name::text = 'UnixGroup'::text AND p.property_type::text = 'MclassUnixProp'::text
        UNION ALL
         SELECT dch.device_collection_id,
            uag.account_collection_id
           FROM v_property p
             JOIN v_device_coll_hier_detail dch ON p.device_collection_id = dch.parent_device_collection_id
             JOIN v_acct_coll_acct_expanded vace USING (account_collection_id)
             JOIN ( SELECT a_2.account_id,
                    a_2.login,
                    a_2.person_id,
                    a_2.company_id,
                    a_2.is_enabled,
                    a_2.account_realm_id,
                    a_2.account_status,
                    a_2.account_role,
                    a_2.account_type,
                    a_2.description,
                    a_2.data_ins_user,
                    a_2.data_ins_date,
                    a_2.data_upd_user,
                    a_2.data_upd_date
                   FROM account a_2
                     JOIN account_unix_info USING (account_id)
                  WHERE a_2.is_enabled = 'Y'::bpchar) a_1 ON vace.account_id = a_1.account_id
             JOIN account_unix_info aui ON a_1.account_id = aui.account_id
             JOIN unix_group ug ON ug.account_collection_id = aui.unix_group_acct_collection_id
             JOIN account_collection uag ON ug.account_collection_id = uag.account_collection_id
          WHERE p.property_name::text = 'UnixLogin'::text AND p.property_type::text = 'MclassUnixProp'::text) ugmap USING (device_collection_id)
     JOIN account_collection ac USING (account_collection_id)
     JOIN unix_group USING (account_collection_id)
     LEFT JOIN v_device_col_account_col_cart o USING (device_collection_id, account_collection_id)
     LEFT JOIN ( SELECT g.account_id,
            g.device_collection_id,
            g.account_collection_id,
            g.unix_uid,
            g.unix_group_acct_collection_id,
            g.shell,
            g.default_home,
            g.data_ins_user,
            g.data_ins_date,
            g.data_upd_user,
            g.data_upd_date,
            g.login,
            g.person_id,
            g.company_id,
            g.is_enabled,
            g.account_realm_id,
            g.account_status,
            g.account_role,
            g.account_type,
            g.description,
            g.data_ins_user_1 AS data_ins_user,
            g.data_ins_date_1 AS data_ins_date,
            g.data_upd_user_1 AS data_upd_user,
            g.data_upd_date_1 AS data_upd_date
           FROM ( SELECT actoa.account_id,
                    actoa.device_collection_id,
                    actoa.account_collection_id,
                    ui.unix_uid,
                    ui.unix_group_acct_collection_id,
                    ui.shell,
                    ui.default_home,
                    ui.data_ins_user,
                    ui.data_ins_date,
                    ui.data_upd_user,
                    ui.data_upd_date,
                    a_1.login,
                    a_1.person_id,
                    a_1.company_id,
                    a_1.is_enabled,
                    a_1.account_realm_id,
                    a_1.account_status,
                    a_1.account_role,
                    a_1.account_type,
                    a_1.description,
                    a_1.data_ins_user,
                    a_1.data_ins_date,
                    a_1.data_upd_user,
                    a_1.data_upd_date
                   FROM ( SELECT dc_1.device_collection_id,
                            ae.account_collection_id,
                            ae.account_id
                           FROM device_collection dc_1,
                            v_acct_coll_acct_expanded ae
                             JOIN unix_group unix_group_1 USING (account_collection_id)
                             JOIN account_collection inac USING (account_collection_id)
                          WHERE dc_1.device_collection_type::text = 'mclass'::text
                        UNION ALL
                         SELECT dcugm.device_collection_id,
                            dcugm.account_collection_id,
                            dcugm.account_id
                           FROM ( SELECT dch.device_collection_id,
                                    p.account_collection_id,
                                    aca.account_id
                                   FROM v_property p
                                     JOIN unix_group ug USING (account_collection_id)
                                     JOIN v_device_coll_hier_detail dch ON p.device_collection_id = dch.parent_device_collection_id
                                     JOIN v_acct_coll_acct_expanded aca ON p.property_value_account_coll_id = aca.account_collection_id
                                  WHERE p.property_name::text = 'UnixGroupMemberOverride'::text AND p.property_type::text = 'MclassUnixProp'::text) dcugm) actoa
                     JOIN account_unix_info ui USING (account_id)
                     JOIN ( SELECT a_2.account_id,
                            a_2.login,
                            a_2.person_id,
                            a_2.company_id,
                            a_2.is_enabled,
                            a_2.account_realm_id,
                            a_2.account_status,
                            a_2.account_role,
                            a_2.account_type,
                            a_2.description,
                            a_2.data_ins_user,
                            a_2.data_ins_date,
                            a_2.data_upd_user,
                            a_2.data_upd_date
                           FROM account a_2
                             JOIN account_unix_info USING (account_id)
                          WHERE a_2.is_enabled = 'Y'::bpchar) a_1 USING (account_id)) g(account_id, device_collection_id, account_collection_id, unix_uid, unix_group_acct_collection_id, shell, default_home, data_ins_user, data_ins_date, data_upd_user, data_upd_date, login, person_id, company_id, is_enabled, account_realm_id, account_status, account_role, account_type, description, data_ins_user_1, data_ins_date_1, data_upd_user_1, data_upd_date_1)
             JOIN ( SELECT a_1.account_id,
                    a_1.login,
                    a_1.person_id,
                    a_1.company_id,
                    a_1.is_enabled,
                    a_1.account_realm_id,
                    a_1.account_status,
                    a_1.account_role,
                    a_1.account_type,
                    a_1.description,
                    a_1.data_ins_user,
                    a_1.data_ins_date,
                    a_1.data_upd_user,
                    a_1.data_upd_date
                   FROM account a_1
                     JOIN account_unix_info USING (account_id)
                  WHERE a_1.is_enabled = 'Y'::bpchar) accts USING (account_id)
             JOIN v_unix_passwd_mappings USING (device_collection_id, account_id)) a(account_id, device_collection_id, account_collection_id, unix_uid, unix_group_acct_collection_id, shell, default_home, data_ins_user, data_ins_date, data_upd_user, data_upd_date, login, person_id, company_id, is_enabled, account_realm_id, account_status, account_role, account_type, description, data_ins_user_1, data_ins_date_1, data_upd_user_1, data_upd_date_1) USING (device_collection_id, account_collection_id)
     LEFT JOIN v_unix_mclass_settings mcs ON mcs.device_collection_id = dc.device_collection_id
  GROUP BY dc.device_collection_id, ac.account_collection_id, ac.account_collection_name, unix_group.unix_gid, unix_group.group_password, o.setting, mcs.mclass_setting
  ORDER BY dc.device_collection_id, ac.account_collection_id;

delete from __recreate where type = 'view' and object = 'v_unix_group_mappings';
-- DONE DEALING WITH TABLE v_unix_group_mappings
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_unix_account_overrides
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_unix_account_overrides', 'v_unix_account_overrides');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_unix_account_overrides');
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
                            COALESCE(p.property_value, p.property_value_password_type) AS property_value,
                            row_number() OVER (PARTITION BY dchd.device_collection_id, acae.account_id, acpe.property_name ORDER BY dchd.device_collection_level, acpe.assign_rank, acpe.property_id) AS ord
                           FROM v_acct_coll_prop_expanded acpe
                             JOIN v_acct_coll_acct_expanded acae USING (account_collection_id)
                             JOIN v_property p USING (property_id)
                             JOIN ( SELECT v_device_coll_hier_detail.device_collection_id,
                                    v_device_coll_hier_detail.parent_device_collection_id,
                                    v_device_coll_hier_detail.device_collection_level
                                   FROM v_device_coll_hier_detail
                                UNION ALL
                                 SELECT p_1.host_device_collection_id AS device_collection_id,
                                    d.parent_device_collection_id,
                                    d.device_collection_level
                                   FROM ( SELECT hdc.device_collection_id AS host_device_collection_id,
    mdc.device_collection_id AS mclass_device_collection_id,
    hdcd.device_id
   FROM device_collection hdc
     JOIN device_collection_device hdcd USING (device_collection_id)
     JOIN device_collection_device mdcd USING (device_id)
     JOIN device_collection mdc ON mdcd.device_collection_id = mdc.device_collection_id
  WHERE hdc.device_collection_type::text = 'per-device'::text AND mdc.device_collection_type::text = 'mclass'::text) p_1
                                     JOIN v_device_coll_hier_detail d ON d.device_collection_id = p_1.mclass_device_collection_id) dchd ON dchd.parent_device_collection_id = p.device_collection_id
                          WHERE (p.property_type::text = ANY (ARRAY['UnixPasswdFileValue'::character varying, 'UnixGroupFileProperty'::character varying, 'MclassUnixProp'::character varying]::text[])) AND (p.property_name::text <> ALL (ARRAY['UnixLogin'::character varying, 'UnixGroup'::character varying, 'UnixGroupMemberOverride'::character varying]::text[]))) dc_acct_prop_list
                  WHERE dc_acct_prop_list.ord = 1) select_for_ordering) property_list
  GROUP BY property_list.device_collection_id, property_list.account_id;

delete from __recreate where type = 'view' and object = 'v_unix_account_overrides';
-- DONE DEALING WITH TABLE v_unix_account_overrides
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
    NULL::integer AS rdns_record_id,
    NULL::text AS dns_srv_service,
    NULL::text AS dns_srv_protocol,
    NULL::integer AS dns_srv_weight,
    NULL::integer AS dns_srv_srv_port,
    combo.is_enabled,
    NULL::integer AS dns_value_record_id
   FROM ( SELECT host(nb.ip_address)::inet AS ip,
            NULL::integer AS network_range_id,
            COALESCE(rdns.dns_name, dns.dns_name) AS dns_name,
            dom.soa_name,
            dns.dns_ttl,
            network(nb.ip_address) AS ip_base,
            dns.is_enabled,
            nb.netblock_id
           FROM netblock nb
             JOIN dns_record dns ON nb.netblock_id = dns.netblock_id
             JOIN dns_domain dom ON dns.dns_domain_id = dom.dns_domain_id
             LEFT JOIN dns_record rdns ON rdns.dns_record_id = dns.reference_dns_record_id
          WHERE dns.should_generate_ptr = 'Y'::bpchar AND dns.dns_class::text = 'IN'::text AND (dns.dns_type::text = 'A'::text OR dns.dns_type::text = 'AAAA'::text) AND nb.is_single_address = 'Y'::bpchar
        UNION ALL
         SELECT host(range.ip)::inet AS ip,
            range.network_range_id,
            concat(COALESCE(range.dns_prefix, 'pool'::character varying), '-', replace(host(range.ip), '.'::text, '-'::text)) AS dns_name,
            dom.soa_name,
            NULL::integer AS dns_ttl,
            network(range.ip) AS ip_base,
            'Y'::bpchar AS is_enabled,
            NULL::integer AS netblock_id
           FROM ( SELECT dr.network_range_id,
                    dr.dns_domain_id,
                    dr.dns_prefix,
                    nbstart.ip_address + generate_series(0::bigint, nbstop.ip_address - nbstart.ip_address) AS ip
                   FROM network_range dr
                     JOIN netblock nbstart ON dr.start_netblock_id = nbstart.netblock_id
                     JOIN netblock nbstop ON dr.stop_netblock_id = nbstop.netblock_id) range
             JOIN dns_domain dom ON range.dns_domain_id = dom.dns_domain_id) combo,
    netblock root
     JOIN dns_record rootd ON rootd.netblock_id = root.netblock_id AND rootd.dns_type::text = 'REVERSE_ZONE_BLOCK_PTR'::text
     JOIN dns_domain dd USING (dns_domain_id)
  WHERE family(root.ip_address) = family(combo.ip) AND set_masklen(combo.ip, masklen(root.ip_address)) <<= root.ip_address;

delete from __recreate where type = 'view' and object = 'v_dns_rvs';
-- DONE DEALING WITH TABLE v_dns_rvs
--------------------------------------------------------------------
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
    u.ref_record_id,
    u.dns_srv_service,
    u.dns_srv_protocol,
    u.dns_srv_weight,
    u.dns_srv_port,
    u.is_enabled,
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
                    WHEN d.dns_value_record_id IS NULL THEN d.dns_value::text
                    WHEN dv.dns_domain_id = d.dns_domain_id THEN dv.dns_name::text
                    ELSE concat(dv.dns_name, '.', dv.soa_name, '.')
                END AS dns_value,
            d.dns_priority,
            COALESCE(rdns.ip_address, ni.ip_address) AS ip,
            COALESCE(rdns.netblock_id, ni.netblock_id) AS netblock_id,
            rdns.reference_dns_record_id AS ref_record_id,
            d.dns_srv_service,
            d.dns_srv_protocol,
            d.dns_srv_weight,
            d.dns_srv_port,
            d.is_enabled,
            d.dns_value_record_id
           FROM dns_record d
             LEFT JOIN netblock ni USING (netblock_id)
             LEFT JOIN ( SELECT dns_record.dns_record_id AS reference_dns_record_id,
                    dns_record.dns_name,
                    dns_record.netblock_id,
                    netblock.ip_address
                   FROM dns_record
                     LEFT JOIN netblock USING (netblock_id)) rdns USING (reference_dns_record_id)
             LEFT JOIN ( SELECT dr.dns_record_id,
                    dr.dns_name,
                    dom.dns_domain_id,
                    dom.soa_name,
                    dr.dns_value,
                    dnb.ip_address AS ip
                   FROM dns_record dr
                     JOIN dns_domain dom USING (dns_domain_id)
                     LEFT JOIN netblock dnb USING (netblock_id)) dv ON d.dns_value_record_id = dv.dns_record_id
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
            NULL::integer AS ref_dns_record_id,
            NULL::character varying AS dns_srv_service,
            NULL::character varying AS dns_srv_protocol,
            NULL::integer AS dns_srv_weight,
            NULL::integer AS dns_srv_port,
            'Y'::bpchar AS is_enabled,
            NULL::integer AS dns_value_record_id
           FROM ( SELECT dr.network_range_id,
                    dr.dns_domain_id,
                    dr.dns_prefix,
                    nbstart.ip_address + generate_series(0::bigint, nbstop.ip_address - nbstart.ip_address) AS ip
                   FROM network_range dr
                     JOIN netblock nbstart ON dr.start_netblock_id = nbstart.netblock_id
                     JOIN netblock nbstop ON dr.stop_netblock_id = nbstop.netblock_id) range) u
  WHERE u.dns_type::text <> 'REVERSE_ZONE_BLOCK_PTR'::text
UNION ALL
 SELECT dns_record.dns_record_id,
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
    NULL::integer AS ref_record_id,
    NULL::text AS dns_srv_service,
    NULL::text AS dns_srv_protocol,
    NULL::integer AS dns_srv_weight,
    NULL::integer AS dns_srv_port,
    dns_record.is_enabled,
    NULL::integer AS dns_value_record_id
   FROM dns_record
     JOIN dns_domain USING (dns_domain_id)
     JOIN ( SELECT dns_domain_1.dns_domain_id AS parent_dns_domain_id,
            dns_domain_1.soa_name AS parent_soa_name
           FROM dns_domain dns_domain_1) pdom USING (parent_dns_domain_id)
  WHERE dns_record.dns_class::text = 'IN'::text AND dns_record.dns_type::text = 'NS'::text AND dns_record.dns_name IS NULL AND dns_domain.parent_dns_domain_id IS NOT NULL;

delete from __recreate where type = 'view' and object = 'v_dns_fwd';
-- DONE DEALING WITH TABLE v_dns_fwd
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_dns_changes_pending
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dns_changes_pending', 'v_dns_changes_pending');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_dns_changes_pending');
DROP VIEW IF EXISTS jazzhands.v_dns_changes_pending;
CREATE VIEW jazzhands.v_dns_changes_pending AS
 WITH chg AS (
         SELECT dns_change_record.dns_change_record_id,
            dns_change_record.dns_domain_id,
                CASE
                    WHEN family(dns_change_record.ip_address) = 4 THEN set_masklen(dns_change_record.ip_address, 24)
                    ELSE set_masklen(dns_change_record.ip_address, 64)
                END AS ip_address,
            dns_utils.get_domain_from_cidr(dns_change_record.ip_address) AS cidrdns
           FROM dns_change_record
          WHERE dns_change_record.ip_address IS NOT NULL
        )
 SELECT DISTINCT x.dns_change_record_id,
    x.dns_domain_id,
    x.should_generate,
    x.last_generated,
    x.soa_name,
    x.ip_address
   FROM ( SELECT chg.dns_change_record_id,
            n.dns_domain_id,
            n.should_generate,
            n.last_generated,
            n.soa_name,
            chg.ip_address
           FROM chg
             JOIN dns_domain n ON chg.cidrdns = n.soa_name::text
        UNION ALL
         SELECT chg.dns_change_record_id,
            d.dns_domain_id,
            d.should_generate,
            d.last_generated,
            d.soa_name,
            NULL::inet
           FROM dns_change_record chg
             JOIN dns_domain d USING (dns_domain_id)
          WHERE chg.dns_domain_id IS NOT NULL) x;

delete from __recreate where type = 'view' and object = 'v_dns_changes_pending';
-- DONE DEALING WITH TABLE v_dns_changes_pending
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_dns
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dns', 'v_dns');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_dns');
DROP VIEW IF EXISTS jazzhands.v_dns;
CREATE VIEW jazzhands.v_dns AS
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
    v_dns_fwd.ref_record_id,
    v_dns_fwd.dns_srv_service,
    v_dns_fwd.dns_srv_protocol,
    v_dns_fwd.dns_srv_weight,
    v_dns_fwd.dns_srv_port,
    v_dns_fwd.is_enabled,
    v_dns_fwd.dns_value_record_id
   FROM v_dns_fwd
UNION ALL
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
    v_dns_rvs.rdns_record_id AS ref_record_id,
    v_dns_rvs.dns_srv_service,
    v_dns_rvs.dns_srv_protocol,
    v_dns_rvs.dns_srv_weight,
    v_dns_rvs.dns_srv_srv_port AS dns_srv_port,
    v_dns_rvs.is_enabled,
    v_dns_rvs.dns_value_record_id
   FROM v_dns_rvs;

delete from __recreate where type = 'view' and object = 'v_dns';
-- DONE DEALING WITH TABLE v_dns
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_device_col_account_col_cart
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_col_account_col_cart', 'v_device_col_account_col_cart');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_device_col_account_col_cart');
DROP VIEW IF EXISTS jazzhands.v_device_col_account_col_cart;
CREATE VIEW jazzhands.v_device_col_account_col_cart AS
 SELECT xx.device_collection_id,
    xx.account_collection_id,
    xx.setting
   FROM ( SELECT x.device_collection_id,
            x.account_collection_id,
            x.setting,
            row_number() OVER (PARTITION BY x.device_collection_id, x.account_collection_id ORDER BY x.setting) AS rn
           FROM ( SELECT v_device_col_acct_col_unixgroup.device_collection_id,
                    v_device_col_acct_col_unixgroup.account_collection_id,
                    NULL::character varying[] AS setting
                   FROM v_device_col_acct_col_unixgroup
                     JOIN account_collection USING (account_collection_id)
                     JOIN unix_group USING (account_collection_id)
                UNION
                 SELECT v_unix_group_overrides.device_collection_id,
                    v_unix_group_overrides.account_collection_id,
                    v_unix_group_overrides.setting
                   FROM v_unix_group_overrides) x) xx
  WHERE xx.rn = 1;

delete from __recreate where type = 'view' and object = 'v_device_col_account_col_cart';
-- DONE DEALING WITH TABLE v_device_col_account_col_cart
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_device_col_account_cart
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_col_account_cart', 'v_device_col_account_cart');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_device_col_account_cart');
DROP VIEW IF EXISTS jazzhands.v_device_col_account_cart;
CREATE VIEW jazzhands.v_device_col_account_cart AS
 SELECT xx.device_collection_id,
    xx.account_id,
    xx.setting
   FROM ( SELECT x.device_collection_id,
            x.account_id,
            x.setting,
            row_number() OVER (PARTITION BY x.device_collection_id, x.account_id ORDER BY x.setting) AS rn
           FROM ( SELECT v_device_col_acct_col_unixlogin.device_collection_id,
                    v_device_col_acct_col_unixlogin.account_id,
                    NULL::character varying[] AS setting
                   FROM v_device_col_acct_col_unixlogin
                     JOIN account USING (account_id)
                     JOIN account_unix_info USING (account_id)
                UNION ALL
                 SELECT v_unix_account_overrides.device_collection_id,
                    v_unix_account_overrides.account_id,
                    v_unix_account_overrides.setting
                   FROM v_unix_account_overrides
                     JOIN account USING (account_id)
                     JOIN account_unix_info USING (account_id)
                     JOIN v_device_col_acct_col_unixlogin USING (device_collection_id, account_id)) x) xx
  WHERE xx.rn = 1;

delete from __recreate where type = 'view' and object = 'v_device_col_account_cart';
-- DONE DEALING WITH TABLE v_device_col_account_cart
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_acct_coll_prop_expanded
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_acct_coll_prop_expanded', 'v_acct_coll_prop_expanded');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_acct_coll_prop_expanded');
DROP VIEW IF EXISTS jazzhands.v_acct_coll_prop_expanded;
CREATE VIEW jazzhands.v_acct_coll_prop_expanded AS
 SELECT v_acct_coll_expanded_detail.root_account_collection_id AS account_collection_id,
    v_property.property_id,
    v_property.property_name,
    v_property.property_type,
    v_property.property_value,
    v_property.property_value_timestamp,
    v_property.property_value_company_id,
    v_property.property_value_account_coll_id,
    v_property.property_value_nblk_coll_id,
    v_property.property_value_password_type,
    v_property.property_value_person_id,
    v_property.property_value_sw_package_id,
    v_property.property_value_token_col_id,
    v_property.property_rank,
        CASE val_property.is_multivalue
            WHEN 'N'::bpchar THEN false
            WHEN 'Y'::bpchar THEN true
            ELSE NULL::boolean
        END AS is_multivalue,
        CASE ac.account_collection_type
            WHEN 'per-account'::text THEN 0
            ELSE
            CASE v_acct_coll_expanded_detail.assign_method
                WHEN 'DirectAccountCollectionAssignment'::text THEN 10
                WHEN 'DirectDepartmentAssignment'::text THEN 200
                WHEN 'DepartmentAssignedToAccountCollection'::text THEN 300 + v_acct_coll_expanded_detail.dept_level + v_acct_coll_expanded_detail.acct_coll_level
                WHEN 'AccountAssignedToChildDepartment'::text THEN 400 + v_acct_coll_expanded_detail.dept_level
                WHEN 'AccountAssignedToChildAccountCollection'::text THEN 500 + v_acct_coll_expanded_detail.acct_coll_level
                WHEN 'DepartmentAssignedToChildAccountCollection'::text THEN 600 + v_acct_coll_expanded_detail.dept_level + v_acct_coll_expanded_detail.acct_coll_level
                WHEN 'ChildDepartmentAssignedToAccountCollection'::text THEN 700 + v_acct_coll_expanded_detail.dept_level + v_acct_coll_expanded_detail.acct_coll_level
                WHEN 'ChildDepartmentAssignedToChildAccountCollection'::text THEN 800 + v_acct_coll_expanded_detail.dept_level + v_acct_coll_expanded_detail.acct_coll_level
                ELSE 999
            END
        END AS assign_rank
   FROM v_acct_coll_expanded_detail
     JOIN account_collection ac USING (account_collection_id)
     JOIN v_property USING (account_collection_id)
     JOIN val_property USING (property_name, property_type);

delete from __recreate where type = 'view' and object = 'v_acct_coll_prop_expanded';
-- DONE DEALING WITH TABLE v_acct_coll_prop_expanded
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_account_collection_account
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_account_collection_account', 'v_account_collection_account');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_account_collection_account');
DROP VIEW IF EXISTS jazzhands.v_account_collection_account;
CREATE VIEW jazzhands.v_account_collection_account AS
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
   FROM account_collection_account
  WHERE account_collection_account.start_date IS NULL AND account_collection_account.finish_date IS NULL OR account_collection_account.start_date IS NULL AND now() <= account_collection_account.finish_date OR account_collection_account.start_date <= now() AND account_collection_account.finish_date IS NULL OR account_collection_account.start_date <= now() AND now() <= account_collection_account.finish_date;

delete from __recreate where type = 'view' and object = 'v_account_collection_account';
-- DONE DEALING WITH TABLE v_account_collection_account
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_network_interface_trans
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_network_interface_trans');
DROP VIEW IF EXISTS jazzhands.v_network_interface_trans;
CREATE VIEW jazzhands.v_network_interface_trans AS
 SELECT network_interface.network_interface_id,
    network_interface.device_id,
    network_interface.network_interface_name,
    network_interface.description,
    network_interface.parent_network_interface_id,
    network_interface.parent_relation_type,
    network_interface.netblock_id,
    network_interface.physical_port_id,
    network_interface.slot_id,
    network_interface.logical_port_id,
    network_interface.network_interface_type,
    network_interface.is_interface_up,
    network_interface.mac_addr,
    network_interface.should_monitor,
    network_interface.provides_nat,
    network_interface.should_manage,
    network_interface.provides_dhcp,
    network_interface.data_ins_user,
    network_interface.data_ins_date,
    network_interface.data_upd_user,
    network_interface.data_upd_date
   FROM network_interface
UNION
 SELECT network_interface.network_interface_id,
    network_interface.device_id,
    network_interface.network_interface_name,
    network_interface.description,
    network_interface.parent_network_interface_id,
    network_interface.parent_relation_type,
    network_interface.netblock_id,
    network_interface.physical_port_id,
    network_interface.slot_id,
    network_interface.logical_port_id,
    network_interface.network_interface_type,
    network_interface.is_interface_up,
    network_interface.mac_addr,
    network_interface.should_monitor,
    network_interface.provides_nat,
    network_interface.should_manage,
    network_interface.provides_dhcp,
    network_interface.data_ins_user,
    network_interface.data_ins_date,
    network_interface.data_upd_user,
    network_interface.data_upd_date
   FROM network_interface;

-- DONE DEALING WITH TABLE v_network_interface_trans
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_dns_sorted
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_dns_sorted');
DROP VIEW IF EXISTS jazzhands.v_dns_sorted;
CREATE VIEW jazzhands.v_dns_sorted AS
 SELECT dns.dns_record_id,
    dns.network_range_id,
    dns.dns_value_record_id,
    dns.dns_name,
    dns.dns_ttl,
    dns.dns_class,
    dns.dns_type,
    dns.dns_value,
    dns.dns_priority,
    dns.ip,
    dns.netblock_id,
    dns.ref_record_id,
    dns.dns_srv_service,
    dns.dns_srv_protocol,
    dns.dns_srv_weight,
    dns.dns_srv_port,
    dns.is_enabled,
    dns.dns_domain_id,
    dns.anchor_record_id,
    dns.anchor_rank
   FROM ( SELECT v_dns.dns_record_id,
            v_dns.network_range_id,
            v_dns.dns_value_record_id,
            v_dns.dns_name,
            v_dns.dns_ttl,
            v_dns.dns_class,
            v_dns.dns_type,
            "substring"(v_dns.dns_value, 1, 50) AS dns_value,
            v_dns.dns_priority,
            host(v_dns.ip) AS ip,
            v_dns.netblock_id,
            v_dns.ref_record_id,
            v_dns.dns_srv_service,
            v_dns.dns_srv_protocol,
            v_dns.dns_srv_weight,
            v_dns.dns_srv_port,
            v_dns.is_enabled,
            v_dns.dns_domain_id,
            COALESCE(v_dns.ref_record_id, v_dns.dns_value_record_id, v_dns.dns_record_id) AS anchor_record_id,
                CASE
                    WHEN v_dns.ref_record_id IS NOT NULL THEN 2
                    WHEN v_dns.dns_value_record_id IS NOT NULL THEN 3
                    ELSE 1
                END AS anchor_rank
           FROM v_dns) dns
  ORDER BY dns.dns_domain_id, (
        CASE
            WHEN dns.dns_name IS NULL THEN 0
            ELSE 1
        END), (
        CASE
            WHEN dns.dns_type::text = 'NS'::text THEN 0
            WHEN dns.dns_type::text = 'PTR'::text THEN 1
            WHEN dns.dns_type::text = 'A'::text THEN 2
            WHEN dns.dns_type::text = 'AAAA'::text THEN 3
            ELSE 4
        END), (
        CASE
            WHEN dns.dns_type::text = 'PTR'::text THEN lpad(dns.dns_name::text, 10, '0'::text)
            ELSE NULL::text
        END), dns.anchor_record_id, dns.anchor_rank, dns.dns_type, dns.ip, dns.dns_value;

-- DONE DEALING WITH TABLE v_dns_sorted
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_collection_hier_trans
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_device_collection_hier_trans');
DROP VIEW IF EXISTS jazzhands.v_device_collection_hier_trans;
CREATE VIEW jazzhands.v_device_collection_hier_trans AS
 SELECT device_collection_hier.parent_device_collection_id,
    device_collection_hier.device_collection_id,
    device_collection_hier.data_ins_user,
    device_collection_hier.data_ins_date,
    device_collection_hier.data_upd_user,
    device_collection_hier.data_upd_date
   FROM device_collection_hier;

-- DONE DEALING WITH TABLE v_device_collection_hier_trans
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_dev_col_root
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_dev_col_root');
DROP VIEW IF EXISTS jazzhands.v_dev_col_root;
CREATE VIEW jazzhands.v_dev_col_root AS
 WITH x AS (
         SELECT c.device_collection_id AS leaf_id,
            c.device_collection_name AS leaf_name,
            c.device_collection_type AS leaf_type,
            p.device_collection_id AS root_id,
            p.device_collection_name AS root_name,
            p.device_collection_type AS root_type,
            dch.device_collection_level
           FROM device_collection c
             JOIN v_device_coll_hier_detail dch ON dch.device_collection_id = c.device_collection_id
             JOIN device_collection p ON dch.parent_device_collection_id = p.device_collection_id
        )
 SELECT xx.root_id,
    xx.root_name,
    xx.root_type,
    xx.leaf_id,
    xx.leaf_name,
    xx.leaf_type
   FROM ( SELECT x.root_id,
            x.root_name,
            x.root_type,
            x.leaf_id,
            x.leaf_name,
            x.leaf_type,
            x.device_collection_level,
            row_number() OVER (PARTITION BY x.leaf_id ORDER BY x.device_collection_level DESC) AS rn
           FROM x) xx
  WHERE xx.rn = 1;

-- DONE DEALING WITH TABLE v_dev_col_root
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_dev_col_device_root
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_dev_col_device_root');
DROP VIEW IF EXISTS jazzhands.v_dev_col_device_root;
CREATE VIEW jazzhands.v_dev_col_device_root AS
 WITH x AS (
         SELECT dcd.device_id,
            c.device_collection_id AS leaf_id,
            c.device_collection_name AS leaf_name,
            c.device_collection_type AS leaf_type,
            p.device_collection_id AS root_id,
            p.device_collection_name AS root_name,
            p.device_collection_type AS root_type,
            dch.device_collection_level
           FROM v_device_coll_hier_detail dch
             JOIN device_collection_device dcd USING (device_collection_id)
             JOIN device_collection c ON dch.device_collection_id = c.device_collection_id
             JOIN device_collection p ON dch.parent_device_collection_id = p.device_collection_id
        )
 SELECT xx.device_id,
    xx.root_id,
    xx.root_name,
    xx.root_type,
    xx.leaf_id,
    xx.leaf_name,
    xx.leaf_type
   FROM ( SELECT x.device_id,
            x.root_id,
            x.root_name,
            x.root_type,
            x.leaf_id,
            x.leaf_name,
            x.leaf_type,
            row_number() OVER (PARTITION BY x.device_id, x.root_type ORDER BY x.device_collection_level DESC) AS rn
           FROM x) xx
  WHERE xx.rn = 1;

-- DONE DEALING WITH TABLE v_dev_col_device_root
--------------------------------------------------------------------
SELECT schema_support.replay_object_recreates();
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE mv_dev_col_root
DROP MATERIALIZED VIEW IF EXISTS jazzhands.mv_dev_col_root;
CREATE MATERIALIZED VIEW jazzhands.mv_dev_col_root AS
 SELECT v_dev_col_root.root_id,
    v_dev_col_root.root_name,
    v_dev_col_root.root_type,
    v_dev_col_root.leaf_id,
    v_dev_col_root.leaf_name,
    v_dev_col_root.leaf_type
   FROM v_dev_col_root;

-- DONE DEALING WITH TABLE mv_dev_col_root
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
--------------------------------------------------------------------
-- DEALING WITH TABLE v_person_company_audit_map
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('approval_utils', 'v_person_company_audit_map', 'v_person_company_audit_map');
SELECT schema_support.save_dependent_objects_for_replay('approval_utils', 'v_person_company_audit_map');
DROP VIEW IF EXISTS approval_utils.v_person_company_audit_map;
CREATE VIEW approval_utils.v_person_company_audit_map AS
 SELECT all_audrecs."aud#seq" AS audit_seq_id,
    all_audrecs.company_id,
    all_audrecs.person_id,
    all_audrecs.person_company_status,
    all_audrecs.person_company_relation,
    all_audrecs.is_exempt,
    all_audrecs.is_management,
    all_audrecs.is_full_time,
    all_audrecs.description,
    all_audrecs.employee_id,
    all_audrecs.payroll_id,
    all_audrecs.external_hr_id,
    all_audrecs.position_title,
    all_audrecs.badge_system_id,
    all_audrecs.hire_date,
    all_audrecs.termination_date,
    all_audrecs.manager_person_id,
    all_audrecs.supervisor_person_id,
    all_audrecs.nickname,
    all_audrecs.data_ins_user,
    all_audrecs.data_ins_date,
    all_audrecs.data_upd_user,
    all_audrecs.data_upd_date,
    all_audrecs."aud#action",
    all_audrecs."aud#timestamp",
    all_audrecs."aud#realtime",
    all_audrecs."aud#txid",
    all_audrecs."aud#user",
    all_audrecs."aud#seq",
    all_audrecs.rownum
   FROM ( SELECT pca.company_id,
            pca.person_id,
            pca.person_company_status,
            pca.person_company_relation,
            pca.is_exempt,
            pca.is_management,
            pca.is_full_time,
            pca.description,
            pca.employee_id,
            pca.payroll_id,
            pca.external_hr_id,
            pca.position_title,
            pca.badge_system_id,
            pca.hire_date,
            pca.termination_date,
            pca.manager_person_id,
            pca.supervisor_person_id,
            pca.nickname,
            pca.data_ins_user,
            pca.data_ins_date,
            pca.data_upd_user,
            pca.data_upd_date,
            pca."aud#action",
            pca."aud#timestamp",
            pca."aud#realtime",
            pca."aud#txid",
            pca."aud#user",
            pca."aud#seq",
            row_number() OVER (PARTITION BY pc.person_id, pc.company_id ORDER BY pca."aud#seq" DESC) AS rownum
           FROM person_company pc
             JOIN audit.person_company pca USING (person_id, company_id)
          WHERE pca."aud#action" = ANY (ARRAY['UPD'::bpchar, 'INS'::bpchar])) all_audrecs
  WHERE all_audrecs.rownum = 1;

delete from __recreate where type = 'view' and object = 'v_person_company_audit_map';
-- DONE DEALING WITH TABLE v_person_company_audit_map
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_account_collection_account_audit_map
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('approval_utils', 'v_account_collection_account_audit_map', 'v_account_collection_account_audit_map');
SELECT schema_support.save_dependent_objects_for_replay('approval_utils', 'v_account_collection_account_audit_map');
DROP VIEW IF EXISTS approval_utils.v_account_collection_account_audit_map;
CREATE VIEW approval_utils.v_account_collection_account_audit_map AS
 SELECT all_audrecs."aud#seq" AS audit_seq_id,
    all_audrecs.account_collection_id,
    all_audrecs.account_id,
    all_audrecs.account_collection_relation,
    all_audrecs.account_id_rank,
    all_audrecs.start_date,
    all_audrecs.finish_date,
    all_audrecs.data_ins_user,
    all_audrecs.data_ins_date,
    all_audrecs.data_upd_user,
    all_audrecs.data_upd_date,
    all_audrecs."aud#action",
    all_audrecs."aud#timestamp",
    all_audrecs."aud#realtime",
    all_audrecs."aud#txid",
    all_audrecs."aud#user",
    all_audrecs."aud#seq",
    all_audrecs.rownum
   FROM ( SELECT acaa.account_collection_id,
            acaa.account_id,
            acaa.account_collection_relation,
            acaa.account_id_rank,
            acaa.start_date,
            acaa.finish_date,
            acaa.data_ins_user,
            acaa.data_ins_date,
            acaa.data_upd_user,
            acaa.data_upd_date,
            acaa."aud#action",
            acaa."aud#timestamp",
            acaa."aud#realtime",
            acaa."aud#txid",
            acaa."aud#user",
            acaa."aud#seq",
            row_number() OVER (PARTITION BY aca.account_collection_id, aca.account_id ORDER BY acaa."aud#seq" DESC) AS rownum
           FROM account_collection_account aca
             JOIN audit.account_collection_account acaa USING (account_collection_id, account_id)
          WHERE acaa."aud#action" = ANY (ARRAY['UPD'::bpchar, 'INS'::bpchar])) all_audrecs
  WHERE all_audrecs.rownum = 1;

delete from __recreate where type = 'view' and object = 'v_account_collection_account_audit_map';
-- DONE DEALING WITH TABLE v_account_collection_account_audit_map
--------------------------------------------------------------------
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
--
-- Process drops in jazzhands
--
-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_a_rec_validation');
CREATE OR REPLACE FUNCTION jazzhands.dns_a_rec_validation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_ip		netblock.ip_address%type;
	_sing	netblock.is_single_address%type;
BEGIN
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

		IF ( NEW.should_generate_ptr = 'Y' AND NEW.dns_value_record_id IS NOT NULL ) THEN
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

		IF _sing = 'N' AND NEW.dns_type IN ('A','AAAA') THEN
			RAISE EXCEPTION 'Non-single addresses may not have % records', NEW.dns_type
				USING ERRCODE = 'foreign_key_violation';
		END IF;

	END IF;


	RETURN NEW;
END;
$function$
;

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
	IF NEW.dns_type NOT in ('A', 'AAAA', 'REVERSE_ZONE_BLOCK_PTR') AND
			( NEW.dns_value IS NULL AND NEW.dns_value_record_id IS NULL ) THEN
		RAISE EXCEPTION 'Attempt to set % record without a value',
			NEW.dns_type
			USING ERRCODE = 'not_null_violation';
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_rec_prevent_dups');
CREATE OR REPLACE FUNCTION jazzhands.dns_rec_prevent_dups()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	-- should not be able to insert the same record(s) twice
	WITH newref AS (
		SELECT * FROM dns_record
			WHERE NEW.reference_dns_record_id IS NOT NULL
			AND NEW.reference_dns_record_id = dns_record_id
			ORDER BY dns_record_id LIMIT 1
	), dns AS ( SELECT
			db.dns_record_id,
			coalesce(ref.dns_name, db.dns_name) as dns_name,
			db.dns_domain_id, db.dns_ttl,
			db.dns_class, db.dns_type,
			coalesce(val.dns_value, db.dns_value) AS dns_value,
			db.dns_priority, db.dns_srv_service, db.dns_srv_protocol,
			db.dns_srv_weight, db.dns_srv_port,
			coalesce(val.netblock_id, db.netblock_id) AS netblock_id,
			db.reference_dns_record_id, db.dns_value_record_id,
			db.should_generate_ptr, db.is_enabled
		FROM dns_record db
			LEFT JOIN dns_record ref
				ON ( db.reference_dns_record_id = ref.dns_record_id)
			LEFT JOIN dns_record val
				ON ( db.dns_value_record_id = val.dns_record_id )
			LEFT JOIN newref
				ON newref.dns_record_id = NEW.reference_dns_record_id
		WHERE db.dns_record_id != NEW.dns_record_id
		AND (lower(coalesce(ref.dns_name, db.dns_name))
					IS NOT DISTINCT FROM
				lower(coalesce(newref.dns_name, NEW.dns_name)) )
		AND ( db.dns_domain_id = NEW.dns_domain_id )
		AND ( db.dns_class = NEW.dns_class )
		AND ( db.dns_type = NEW.dns_type )
    		AND db.dns_record_id != NEW.dns_record_id
		AND db.dns_srv_service IS NOT DISTINCT FROM NEW.dns_srv_service
		AND db.dns_srv_protocol IS NOT DISTINCT FROM NEW.dns_srv_protocol
		AND db.dns_srv_port IS NOT DISTINCT FROM NEW.dns_srv_port
		AND db.is_enabled = 'Y'
	) SELECT	count(*)
		INTO	_tally
		FROM dns
			LEFT JOIN dns_record val
				ON ( NEW.dns_value_record_id = val.dns_record_id )
		WHERE
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_record_cname_checker');
CREATE OR REPLACE FUNCTION jazzhands.dns_record_cname_checker()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
	_dom	TEXT;
BEGIN
	_tally := 0;
	IF TG_OP = 'INSERT' OR NEW.DNS_TYPE != OLD.DNS_TYPE THEN
		IF NEW.DNS_TYPE = 'CNAME' THEN
			IF TG_OP = 'UPDATE' THEN
			SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE
						NEW.dns_domain_id = x.dns_domain_id
				 AND	OLD.dns_record_id != x.dns_record_id
				 AND	(
							NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			ELSE
				-- only difference between above and this is the use of OLD
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE
						NEW.dns_domain_id = x.dns_domain_id
				 AND	(
							NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			END IF;
		-- this clause is basically the same as above except = 'CANME'
		ELSIF NEW.DNS_TYPE != 'CNAME' THEN
			IF TG_OP = 'UPDATE' THEN
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE	x.dns_type = 'CNAME'
				 AND	NEW.dns_domain_id = x.dns_domain_id
				 AND	OLD.dns_record_id != x.dns_record_id
				 AND	(
							NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			ELSE
				-- only difference between above and this is the use of OLD
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE	x.dns_type = 'CNAME'
				 AND	NEW.dns_domain_id = x.dns_domain_id
				 AND	(
							NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			END IF;
		END IF;
	END IF;

	IF _tally > 0 THEN
		SELECT soa_name INTO _dom FROM dns_domain
		WHERE dns_domain_id = NEW.dns_domain_id ;

		if NEW.dns_name IS NULL THEN
			RAISE EXCEPTION '% may not have CNAME and other records (%)',
				_dom, _tally
				USING ERRCODE = 'unique_violation';
		ELSE
			RAISE EXCEPTION '%.% may not have CNAME and other records (%)',
				NEW.dns_name, _dom, _tally
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'nb_dns_a_rec_validation');
CREATE OR REPLACE FUNCTION jazzhands.nb_dns_a_rec_validation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tal	integer;
BEGIN
	IF family(OLD.ip_address) != family(NEW.ip_address) THEN
		--
		-- The dns_value_record_id check is not strictly needed since
		-- the "dns_value_record_id" points to something of the same type
		-- and the trigger would catch that, but its here in case some
		-- assumption later changes and its good to test for..
		IF family(NEW.ip_address) = 6 THEN
			SELECT count(*)
			INTO	_tal
			FROM	dns_record
			WHERE	(
						netblock_id = NEW.netblock_id
						AND		dns_type = 'A'
					)
			OR		(
						dns_value_record_id IN (
							SELECT dns_record_id
							FROM	dns_record
							WHERE	netblock_id = NEW.netblock_id
							AND		dns_type = 'A'
						)
					);

			IF _tal > 0 THEN
				RAISE EXCEPTION 'A records must be assigned to IPv4 records'
					USING ERRCODE = 'JH200';
			END IF;
		END IF;

		IF family(NEW.ip_address) = 4 THEN
			SELECT count(*)
			INTO	_tal
			FROM	dns_record
			WHERE	(
						netblock_id = NEW.netblock_id
						AND		dns_type = 'AAAA'
					)
			OR		(
						dns_value_record_id IN (
							SELECT dns_record_id
							FROM	dns_record
							WHERE	netblock_id = NEW.netblock_id
							AND		dns_type = 'AAAA'
						)
					);

			IF _tal > 0 THEN
				RAISE EXCEPTION 'AAAA records must be assigned to IPv6 records'
					USING ERRCODE = 'JH200';
			END IF;
		END IF;
	END IF;

	IF NEW.is_single_address = 'N' THEN
			SELECT count(*)
			INTO	_tal
			FROM	dns_record
			WHERE	netblock_id = NEW.netblock_id
			AND		dns_type IN ('A', 'AAAA');

		IF _tal > 0 THEN
			RAISE EXCEPTION 'Non-single addresses may not have % records', NEW.dns_type
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_component_property');
CREATE OR REPLACE FUNCTION jazzhands.validate_component_property()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally				INTEGER;
	v_comp_prop			RECORD;
	v_comp_prop_type	RECORD;
	v_num				bigint;
	v_listvalue			TEXT;
	component_attrs		RECORD;
BEGIN

	-- Pull in the data from the property and property_type so we can
	-- figure out what is and is not valid

	BEGIN
		SELECT * INTO STRICT v_comp_prop FROM val_component_property WHERE
			component_property_name = NEW.component_property_name AND
			component_property_type = NEW.component_property_type;

		SELECT * INTO STRICT v_comp_prop_type FROM val_component_property_type
			WHERE component_property_type = NEW.component_property_type;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			RAISE EXCEPTION
				'Component property name or type does not exist'
				USING ERRCODE = 'foreign_key_violation';
			RETURN NULL;
	END;

	-- Check to see if the property itself is multivalue.  That is, if only
	-- one value can be set for this property for a specific property LHS

	IF (v_comp_prop.is_multivalue != 'Y') THEN
		PERFORM 1 FROM component_property WHERE
			component_property_id != NEW.component_property_id AND
			component_property_name = NEW.component_property_name AND
			component_property_type = NEW.component_property_type AND
			component_type_id IS NOT DISTINCT FROM NEW.component_type_id AND
			component_function IS NOT DISTINCT FROM NEW.component_function AND
			component_id iS NOT DISTINCT FROM NEW.component_id AND
			slot_type_id IS NOT DISTINCT FROM NEW.slot_type_id AND
			slot_function IS NOT DISTINCT FROM NEW.slot_function AND
			slot_id IS NOT DISTINCT FROM NEW.slot_id;

		IF FOUND THEN
			RAISE EXCEPTION
				'Property with name % and type % already exists for given LHS and property is not multivalue',
				NEW.component_property_name,
				NEW.component_property_type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;
	END IF;

	-- Check to see if the property type is multivalue.  That is, if only
	-- one property and value can be set for any properties with this type
	-- for a specific property LHS

	IF (v_comp_prop_type.is_multivalue != 'Y') THEN
		PERFORM 1 FROM component_property WHERE
			component_property_id != NEW.component_property_id AND
			component_property_type = NEW.component_property_type AND
			component_type_id IS NOT DISTINCT FROM NEW.component_type_id AND
			component_function IS NOT DISTINCT FROM NEW.component_function AND
			component_id iS NOT DISTINCT FROM NEW.component_id AND
			slot_type_id IS NOT DISTINCT FROM NEW.slot_type_id AND
			slot_function IS NOT DISTINCT FROM NEW.slot_function AND
			slot_id IS NOT DISTINCT FROM NEW.slot_id;

		IF FOUND THEN
			RAISE EXCEPTION
				'Property % of type % already exists for given LHS and property type is not multivalue',
				NEW.component_property_name, NEW.component_property_type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;
	END IF;

	-- now validate the property_value columns.
	tally := 0;

	--
	-- first determine if the property_value is set properly.
	--

	-- at this point, tally will be set to 1 if one of the other property
	-- values is set to something valid.  Now, check the various options for
	-- PROPERTY_VALUE itself.  If a new type is added to the val table, this
	-- trigger needs to be updated or it will be considered invalid.  If a
	-- new PROPERTY_VALUE_* column is added, then it will pass through without
	-- trigger modification.  This should be considered bad.

	IF NEW.property_value IS NOT NULL THEN
		tally := tally + 1;
		IF v_comp_prop.property_data_type = 'boolean' THEN
			IF NEW.Property_Value != 'Y' AND NEW.Property_Value != 'N' THEN
				RAISE 'Boolean property_value must be Y or N' USING
					ERRCODE = 'invalid_parameter_value';
			END IF;
		ELSIF v_comp_prop.property_data_type = 'number' THEN
			BEGIN
				v_num := to_number(NEW.property_value, '9');
			EXCEPTION
				WHEN OTHERS THEN
					RAISE 'property_value must be numeric' USING
						ERRCODE = 'invalid_parameter_value';
			END;
		ELSIF v_comp_prop.property_data_type = 'list' THEN
			BEGIN
				SELECT valid_property_value INTO STRICT v_listvalue FROM
					val_component_property_value WHERE
						component_property_name = NEW.component_property_name AND
						component_property_type = NEW.component_property_type AND
						valid_property_value = NEW.property_value;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					RAISE 'property_value must be a valid value' USING
						ERRCODE = 'invalid_parameter_value';
			END;
		ELSIF v_comp_prop.property_data_type != 'string' THEN
			RAISE 'property_data_type is not a known type' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.property_data_type != 'none' AND tally = 0 THEN
		RAISE 'One of the property_value fields must be set: %',
			NEW
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF tally > 1 THEN
		RAISE 'Only one of the property_value fields may be set.' USING
			ERRCODE = 'invalid_parameter_value';
	END IF;

	--
	-- At this point, the value itself is valid for this property, now
	-- determine whether the property is allowed on the target
	--
	-- There needs to be a stanza here for every "lhs".  If a new column is
	-- added to the component_property table, a new stanza needs to be added
	-- here, otherwise it will not be validated.  This should be considered bad.

	IF v_comp_prop.permit_component_type_id = 'REQUIRED' THEN
		IF NEW.component_type_id IS NULL THEN
			RAISE 'component_type_id is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_component_type_id = 'PROHIBITED' THEN
		IF NEW.component_type_id IS NOT NULL THEN
			RAISE 'component_type_id is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_component_function = 'REQUIRED' THEN
		IF NEW.component_function IS NULL THEN
			RAISE 'component_function is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_component_function = 'PROHIBITED' THEN
		IF NEW.component_function IS NOT NULL THEN
			RAISE 'component_function is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_component_id = 'REQUIRED' THEN
		IF NEW.component_id IS NULL THEN
			RAISE 'component_id is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_component_id = 'PROHIBITED' THEN
		IF NEW.component_id IS NOT NULL THEN
			RAISE 'component_id is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_intcomp_conn_id = 'REQUIRED' THEN
		IF NEW.inter_component_connection_id IS NULL THEN
			RAISE 'inter_component_connection_id is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_intcomp_conn_id = 'PROHIBITED' THEN
		IF NEW.inter_component_connection_id IS NOT NULL THEN
			RAISE 'inter_component_connection_id is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_slot_type_id = 'REQUIRED' THEN
		IF NEW.slot_type_id IS NULL THEN
			RAISE 'slot_type_id is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_slot_type_id = 'PROHIBITED' THEN
		IF NEW.slot_type_id IS NOT NULL THEN
			RAISE 'slot_type_id is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_slot_function = 'REQUIRED' THEN
		IF NEW.slot_function IS NULL THEN
			RAISE 'slot_function is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_slot_function = 'PROHIBITED' THEN
		IF NEW.slot_function IS NOT NULL THEN
			RAISE 'slot_function is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_slot_id = 'REQUIRED' THEN
		IF NEW.slot_id IS NULL THEN
			RAISE 'slot_id is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_slot_id = 'PROHIBITED' THEN
		IF NEW.slot_id IS NOT NULL THEN
			RAISE 'slot_id is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	--
	-- LHS population is verified; now validate any particular restrictions
	-- on individual values
	--

	--
	-- For slot_id, validate that the component_type, component_function,
	-- slot_type, and slot_function are all valid
	--
	IF NEW.slot_id IS NOT NULL AND COALESCE(
			v_comp_prop.required_component_type_id::text,
			v_comp_prop.required_component_function,
			v_comp_prop.required_slot_type_id::text,
			v_comp_prop.required_slot_function) IS NOT NULL THEN

		WITH x AS (
			SELECT
				component_type_id,
				array_agg(component_function) as component_function
			FROM
				component_type_component_func
			GROUP BY
				component_type_id
		) SELECT
			component_type_id,
			component_function,
			st.slot_type_id,
			slot_function
		INTO
			component_attrs
		FROM
			slot cs JOIN
			slot_type st USING (slot_type_id) JOIN
			component c USING (component_id) JOIN
			component_type ct USING (component_type_id) LEFT JOIN
			x USING (component_type_id)
		WHERE
			slot_id = NEW.slot_id;

		IF v_comp_prop.required_component_type_id IS NOT NULL AND
				v_comp_prop.required_component_type_id !=
				component_attrs.component_type_id THEN
			RAISE 'component_type for slot_id must be % (is: %)',
					v_comp_prop.required_component_type_id,
					component_attrs.component_type_id
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF v_comp_prop.required_component_function IS NOT NULL AND
				NOT (v_comp_prop.required_component_function =
					ANY(component_attrs.component_function)) THEN
			RAISE 'component_function for slot_id must be % (is: %)',
					v_comp_prop.required_component_function,
					component_attrs.component_function
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF v_comp_prop.required_slot_type_id IS NOT NULL AND
				v_comp_prop.required_slot_type_id !=
				component_attrs.slot_type_id THEN
			RAISE 'slot_type_id for slot_id must be % (is: %)',
					v_comp_prop.required_slot_type_id,
					component_attrs.slot_type_id
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF v_comp_prop.required_slot_function IS NOT NULL AND
				v_comp_prop.required_slot_function !=
				component_attrs.slot_function THEN
			RAISE 'slot_function for slot_id must be % (is: %)',
					v_comp_prop.required_slot_function,
					component_attrs.slot_function
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF NEW.slot_type_id IS NOT NULL AND
			v_comp_prop.required_slot_function IS NOT NULL THEN

		SELECT
			slot_function
		INTO
			component_attrs
		FROM
			slot_type st
		WHERE
			slot_type_id = NEW.slot_type_id;

		IF v_comp_prop.required_slot_function !=
				component_attrs.slot_function THEN
			RAISE 'slot_function for slot_type_id must be % (is: %)',
					v_comp_prop.required_slot_function,
					component_attrs.slot_function
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF NEW.component_id IS NOT NULL AND COALESCE(
			v_comp_prop.required_component_type_id::text,
			v_comp_prop.required_component_function) IS NOT NULL THEN

		SELECT
			component_type_id,
			array_agg(component_function) as component_function
		INTO
			component_attrs
		FROM
			component c JOIN
			component_type_component_func ctcf USING (component_type_id)
		WHERE
			component_id = NEW.component_id
		GROUP BY
			component_type_id;

		IF v_comp_prop.required_component_type_id IS NOT NULL AND
				v_comp_prop.required_component_type_id !=
				component_attrs.component_type_id THEN
			RAISE 'component_type for component_id must be % (is: %)',
					v_comp_prop.required_component_type_id,
					component_attrs.component_type_id
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF v_comp_prop.required_component_function IS NOT NULL AND
				NOT (v_comp_prop.required_component_function =
					ANY(component_attrs.component_function)) THEN
			RAISE 'component_function for component_id must be % (is: %)',
					v_comp_prop.required_component_function,
					component_attrs.component_function
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF NEW.component_type_id IS NOT NULL AND
			v_comp_prop.required_component_function IS NOT NULL THEN

		SELECT
			component_type_id,
			array_agg(component_function) as component_function
		INTO
			component_attrs
		FROM
			component_type_component_func ctcf
		WHERE
			component_type_id = NEW.component_type_id
		GROUP BY
			component_type_id;

		IF v_comp_prop.required_component_function IS NOT NULL AND
				NOT (v_comp_prop.required_component_function =
					ANY(component_attrs.component_function)) THEN
			RAISE 'component_function for component_type_id must be % (is: %)',
					v_comp_prop.required_component_function,
					component_attrs.component_function
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_netblock_to_range_changes');
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock_to_range_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	PERFORM
	FROM	network_range nr
			JOIN netblock p on p.netblock_id = nr.parent_netblock_id
			JOIN netblock start on start.netblock_id = nr.start_netblock_id
			JOIN netblock stop on stop.netblock_id = nr.stop_netblock_id
			JOIN val_network_range_type vnrt USING (network_range_type)
	WHERE	( p.netblock_id = NEW.netblock_id
				OR start.netblock_id = NEW.netblock_id
				OR stop.netblock_id = NEW.netblock_id
			) AND (
					p.can_subnet = 'Y'
				OR 	start.is_single_address = 'N'
				OR 	stop.is_single_address = 'N'
				OR NOT (
					host(start.ip_address)::inet <<= p.ip_address
					AND host(stop.ip_address)::inet <<= p.ip_address
				)
				OR ( vnrt.netblock_type IS NOT NULL
				AND NOT
					( start.netblock_type IS NOT DISTINCT FROM vnrt.netblock_type
					AND	stop.netblock_type IS NOT DISTINCT FROM vnrt.netblock_type
					)
				)
			)
	;

	IF FOUND THEN
		RAISE EXCEPTION 'Netblock changes conflict with network range requirements '
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END; $function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_property');
CREATE OR REPLACE FUNCTION jazzhands.validate_property()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
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
	v_property_collection		property_collection%ROWTYPE;
	v_service_env_collection	service_environment_collection%ROWTYPE;
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
	IF (v_prop.is_multivalue = 'N') THEN
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
			dns_domain_id IS NOT DISTINCT FROM NEW.dns_domain_id AND
			layer2_network_collection_id IS NOT DISTINCT FROM
				NEW.layer2_network_collection_id AND
			layer3_network_collection_id IS NOT DISTINCT FROM
				NEW.layer3_network_collection_id AND
			netblock_collection_id IS NOT DISTINCT FROM NEW.netblock_collection_id AND
			network_range_id IS NOT DISTINCT FROM NEW.network_range_id AND
			operating_system_id IS NOT DISTINCT FROM NEW.operating_system_id AND
			operating_system_snapshot_id IS NOT DISTINCT FROM
				NEW.operating_system_snapshot_id AND
			person_id IS NOT DISTINCT FROM NEW.person_id AND
			property_collection_id IS NOT DISTINCT FROM NEW.property_collection_id AND
			service_env_collection_id IS NOT DISTINCT FROM
				NEW.service_env_collection_id AND
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
			dns_domain_id IS NOT DISTINCT FROM NEW.dns_domain_id AND
			layer2_network_collection_id IS NOT DISTINCT FROM
				NEW.layer2_network_collection_id AND
			layer3_network_collection_id IS NOT DISTINCT FROM
				NEW.layer3_network_collection_id AND
			netblock_collection_id IS NOT DISTINCT FROM NEW.netblock_collection_id AND
			network_range_id IS NOT DISTINCT FROM NEW.network_range_id AND
			operating_system_id IS NOT DISTINCT FROM NEW.operating_system_id AND
			operating_system_snapshot_id IS NOT DISTINCT FROM
				NEW.operating_system_snapshot_id AND
			person_id IS NOT DISTINCT FROM NEW.person_id AND
			property_collection_id IS NOT DISTINCT FROM NEW.property_collection_id AND
			service_env_collection_id IS NOT DISTINCT FROM
				NEW.service_env_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code AND
			property_value IS NOT DISTINCT FROM NEW.property_value AND
			property_value_timestamp IS NOT DISTINCT FROM
				NEW.property_value_timestamp AND
			property_value_company_id IS NOT DISTINCT FROM
				NEW.property_value_company_id AND
			property_value_account_coll_id IS NOT DISTINCT FROM
				NEW.property_value_account_coll_id AND
			property_value_device_coll_id IS NOT DISTINCT FROM
				NEW.property_value_device_coll_id AND
			property_value_nblk_coll_id IS NOT DISTINCT FROM
				NEW.property_value_nblk_coll_id AND
			property_value_password_type IS NOT DISTINCT FROM
				NEW.property_value_password_type AND
			property_value_person_id IS NOT DISTINCT FROM
				NEW.property_value_person_id AND
			property_value_sw_package_id IS NOT DISTINCT FROM
				NEW.property_value_sw_package_id AND
			property_value_token_col_id IS NOT DISTINCT FROM
				NEW.property_value_token_col_id AND
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

	IF (v_proptype.is_multivalue = 'N') THEN
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
			dns_domain_id IS NOT DISTINCT FROM NEW.dns_domain_id AND
			layer2_network_collection_id IS NOT DISTINCT FROM
				NEW.layer2_network_collection_id AND
			layer3_network_collection_id IS NOT DISTINCT FROM
				NEW.layer3_network_collection_id AND
			netblock_collection_id IS NOT DISTINCT FROM NEW.netblock_collection_id AND
			network_range_id IS NOT DISTINCT FROM NEW.network_range_id AND
			operating_system_id IS NOT DISTINCT FROM NEW.operating_system_id AND
			operating_system_snapshot_id IS NOT DISTINCT FROM
				NEW.operating_system_snapshot_id AND
			person_id IS NOT DISTINCT FROM NEW.person_id AND
			property_collection_id IS NOT DISTINCT FROM NEW.property_collection_id AND
			service_env_collection_id IS NOT DISTINCT FROM
				NEW.service_env_collection_id AND
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
	IF NEW.Property_Value_Person_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'person_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Person_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Device_Coll_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'device_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Device_Collection_Id' USING
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

	-- If the LHS contains a property_collection_ID, check to see if it must be a
	-- specific type (e.g. per-property), and verify that if so
	IF NEW.property_collection_id IS NOT NULL THEN
		IF v_prop.property_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_property_collection
					FROM property_collection WHERE
					property_collection_Id = NEW.property_collection_id;
				IF v_property_collection.property_collection_Type != v_prop.property_collection_type
				THEN
					RAISE 'property_collection_id must be of type %',
					v_prop.property_collection_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a service_env_collection_ID, check to see if it must be a
	-- specific type (e.g. per-service_env), and verify that if so
	IF NEW.service_env_collection_id IS NOT NULL THEN
		IF v_prop.service_env_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_service_env_collection
					FROM service_env_collection WHERE
					service_env_collection_Id = NEW.service_env_collection_id;
				IF v_service_env_collection.service_env_collection_Type != v_prop.service_env_collection_type
				THEN
					RAISE 'service_env_collection_id must be of type %',
					v_prop.service_env_collection_type
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

	-- If the RHS contains a device_collection_id, check to see if it must be a
	-- specific type and verify that if so
	IF NEW.Property_Value_Device_Coll_Id IS NOT NULL THEN
		IF v_prop.prop_val_dev_coll_type_rstrct IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_device_collection
					FROM device_collection WHERE
					device_collection_id = NEW.Property_Value_Device_Coll_Id;
				IF v_device_collection.device_collection_type !=
					v_prop.prop_val_dev_coll_type_rstrct
				THEN
					RAISE 'Property_Value_Device_Coll_Id must be of type %',
					v_prop.prop_val_dev_coll_type_rstrct
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

	IF v_prop.permit_os_snapshot_id = 'REQUIRED' THEN
			IF NEW.operating_system_snapshot_id IS NULL THEN
				RAISE 'operating_system_snapshot_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_os_snapshot_id = 'PROHIBITED' THEN
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

	IF v_prop.permit_layer2_network_coll_id = 'REQUIRED' THEN
			IF NEW.layer2_network_collection_id IS NULL THEN
				RAISE 'layer2_network_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_layer2_network_coll_id = 'PROHIBITED' THEN
			IF NEW.layer2_network_collection_id IS NOT NULL THEN
				RAISE 'layer2_network_collection_id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_layer3_network_coll_id = 'REQUIRED' THEN
			IF NEW.layer3_network_collection_id IS NULL THEN
				RAISE 'layer3_network_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_layer3_network_coll_id = 'PROHIBITED' THEN
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

	IF v_prop.Permit_property_collection_Id = 'REQUIRED' THEN
			IF NEW.property_collection_Id IS NULL THEN
				RAISE 'property_collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_property_collection_Id = 'PROHIBITED' THEN
			IF NEW.property_collection_Id IS NOT NULL THEN
				RAISE 'property_collection_Id is prohibited.'
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
CREATE OR REPLACE FUNCTION jazzhands.account_coll_member_relation_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	act	account_coll_type_relation%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	act
	FROM	account_coll_type_relation
	WHERE	account_collection_type =
		(select account_collection_type from account_collection
			where account_collection_id = NEW.account_collection_id)
	AND		account_collection_relation = NEW.account_collection_relation;

	IF act.MAX_NUM_MEMBERS IS NOT NULL THEN
		SELECT count(*)
		  INTO tally
		  FROM account_collection_account
		  		JOIN account_collection USING (account_collection_id)
		  WHERE account_collection_type = act.account_collection_type
		  AND account_collection_relation = NEW.account_collection_relation;

		IF tally > act.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.acct_coll_insert_direct()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	INSERT INTO account_coll_type_relation (
		account_collection_relation, account_collection_type
	) VALUES (
		'direct', NEW.account_collection_type
	);
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.acct_coll_preserve_direct()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF OLD.account_collection_relation = 'direct' THEN
		RAISE EXCEPTION 'Account Collection Relation % may not be removed',
			OLD.account_collection_relation
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.acct_coll_remove_direct()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	DELETE FROM account_coll_type_relation 
		WHERE account_collection_type = OLD.account_collection_type
		AND account_collection_relation = 'direct'
	;
	RETURN OLD;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.acct_coll_update_direct_before()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	UPDATE account_coll_type_relation
	SET account_collection_type = NEW.account_collection_type
	WHERE account_collection_type = OLD.account_collection_type;

	SET CONSTRAINTS fk_acct_coll_rel_type_type IMMEDIATE;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.asset_component_id_fix()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tal INTEGER;
BEGIN
	IF TG_OP = 'INSERT' AND NEW.component_id IS NULL THEN
		RETURN NEW;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.component_id IS NOT NULL THEN
			IF OLD.asset_id != NEW.asset_id THEN
				RAISE 'Asset id may not change for now' USING
				ERRCODE = 'invalid_parameter_value';
			END IF;
		END IF;
		IF OLD.component_id IS NOT DISTINCT FROM NEW.component_id THEN
			RETURN NEW;
		END IF;
	END IF;

	--
	-- component id was changed to NULL, so clear from device
	--
	IF TG_OP = 'INSERT' THEN
		UPDATE device
		SET asset_id = NEW.asset_id
		WHERE component_id = NEW.component_id;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.component_id IS NULL THEN
			UPDATE device d
			SET component_id = NEW.component_id
			WHERE asset_id = NEW.asset_id
			AND NEW.component_id IS DISTINCT FROM d.component_id;
		ELSE		-- IF NEW.component_id IS NOT NULL THEN
			IF OLD.component_id IS NOT NULL THEN
				SELECT count(*)
				INTO	_tal
				FROM	device d
				WHERE	d.component_id = OLD.component_id
				OR		d.component_id = NEW.component_id;

				IF _tal > 1 THEN
					RAISE EXCEPTION 'This component already has a device.'
						USING ERRCODE = 'invalid_parameter_value';
				END IF;
			END IF;

			UPDATE device d
			SET component_id = NEW.component_id
			WHERE d.asset_id = NEW.asset_id 
			AND NEW.component_id IS DISTINCT FROM d.component_id;
		END IF;
	END IF;

	UPDATE device d
	SET	asset_id = NEW.asset_id
	WHERE d.component_id = NEW.component_id
	AND d.asset_id IS DISTINCT FROM NEW.asset_id;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.check_ip_universe_dns_record()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	nb	integer[];
BEGIN
	IF TG_OP = 'UPDATE' THEN
		IF NEW.netblock_id != OLD.netblock_id THEN
			nb = ARRAY[OLD.netblock_id, NEW.netblock_id];
		ELSE
			nb = ARRAY[NEW.netblock_id];
		END IF;
	ELSE
		nb = ARRAY[NEW.netblock_id];
	END IF;

	PERFORM *
	FROM netblock
	WHERE netblock_id = ANY(nb)
	AND ip_universe_id != NEW.ip_universe_id;

	IF FOUND THEN
		RAISE EXCEPTION
			'IP Universes for dns_records must match dns records and netblocks'
			USING ERRCODE = 'foreign_key_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.check_ip_universe_netblock()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	PERFORM *
	FROM dns_record
	WHERE netblock_id IN (NEW.netblock_id, OLD.netblock_id)
	AND ip_universe_id != NEW.ip_universe_id;

	IF FOUND THEN
		RAISE EXCEPTION
			'IP Universes for netblocks must match dns records and netblocks'
			USING ERRCODE = 'foreign_key_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.device_asset_id_fix()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	v_asset	asset%ROWTYPE;
BEGIN
	IF TG_OP = 'INSERT' AND 
				NEW.asset_id IS NULL AND 
				NEW.component_id IS NULL THEN
		RETURN NEW;
	ELSIF ( TG_OP = 'UPDATE' AND 
				OLD.asset_id IS NOT DISTINCT FROM NEW.asset_id AND
				OLD.component_id IS NOT DISTINCT FROM NEW.component_id ) THEN
		RETURN NEW;
	END IF;

	IF NEW.asset_id IS NULL and NEW.component_id IS NOT NULL THEN
		SELECT a.asset_id
		INTO	NEW.asset_id
		FROM	asset a
		WHERE	a.component_id = NEW.component_id;
	ELSIF NEW.asset_id IS NOT NULL and NEW.component_id IS NULL THEN
		SELECT a.component_id
		INTO	NEW.component_id
		FROM	asset a
		WHERE	a.asset_id = NEW.asset_id;
	END IF;

	IF TG_OP = 'UPDATE' AND NEW.asset_id IS NOT NULL AND 
			OLD.component_id IS DISTINCT FROM NEW.component_id AND
			OLD.asset_id IS NOT DISTINCT FROM NEW.asset_id THEN
		SELECT	asset_id
		INTO	NEW.asset_id
		FROM	asset
		WHERE	component_id = NEW.component_id;

		IF NEW.asset_id IS NULL THEN
			RAISE 'If component id changes, there must be an asset for the new component' 
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	-- UPDATE asset a
	-- SET	component_id = NEW.component_id
	-- WHERE a.asset_id = NEW.asset_id
	-- AND a.component_id IS DISTINCT FROM NEW.component_id;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.dns_record_enabled_check()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
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
-- Changed function
SELECT schema_support.save_grants_for_replay('person_manip', 'setup_unix_account');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS person_manip.setup_unix_account ( in_account_id integer, in_account_type character varying, in_uid integer );
CREATE OR REPLACE FUNCTION person_manip.setup_unix_account(in_account_id integer, in_account_type character varying, in_uid integer DEFAULT NULL::integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	acid			account_collection.account_collection_id%TYPE;
	_login			account.login%TYPE;
	new_uid			account_unix_info.unix_uid%TYPE	DEFAULT NULL;
BEGIN
	SELECT login INTO _login FROM account WHERE account_id = in_account_id;

	SELECT account_collection_id
	INTO	acid
	FROM	account_collection
	WHERE	account_collection_name = _login
	AND	account_collection_type = 'unix-group';

	IF NOT FOUND THEN
		INSERT INTO account_collection (
			account_collection_name, account_collection_type)
		values (
			_login, 'unix-group'
		) RETURNING account_collection_id INTO acid;
	END IF;

	PERFORM	*
	FROM	account_collection_account
	WHERE	account_collection_id = acid
	AND	account_id = in_account_id;

	IF NOT FOUND THEN
		insert into account_collection_account (
			account_collection_id, account_id
		) values (
			acid, in_account_id
		);
	END IF;

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

	PERFORM	*
	FROM	unix_group
	WHERE	account_collection_id = acid
	AND	unix_gid = new_uid;

	IF NOT FOUND THEN
		INSERT INTO unix_group (
			account_collection_id,
			unix_gid
		) values (
			acid,
			new_uid
		);
	END IF;
	RETURN in_account_id;
END;
$function$
;

--
-- Process drops in auto_ac_manip
--
--
-- Process drops in company_manip
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
SELECT schema_support.save_grants_for_replay('device_utils', 'retire_device');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_utils.retire_device ( in_device_id integer, retire_modules boolean );
CREATE OR REPLACE FUNCTION device_utils.retire_device(in_device_id integer, retire_modules boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally		INTEGER;
	_r			RECORD;
	_d			DEVICE%ROWTYPE;
	_mgrid		DEVICE.DEVICE_ID%TYPE;
	_purgedev	boolean;
BEGIN
	_purgedev := false;

	BEGIN
		PERFORM local_hooks.device_retire_early(in_Device_Id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	SELECT * INTO _d FROM device WHERE device_id = in_Device_id;
	delete from dns_record where netblock_id in (
		select netblock_id 
		from network_interface where device_id = in_Device_id
	);

	delete from network_interface_purpose where device_id = in_Device_id;

	DELETE FROM network_interface_netblock
	WHERE network_interface_id IN (
			SELECT network_interface_id
		 	FROM network_interface
			WHERE device_id = in_Device_id
	);

	DELETE FROM network_interface WHERE device_id = in_Device_id;

	PERFORM device_utils.purge_physical_ports( in_Device_id);
--	PERFORM device_utils.purge_power_ports( in_Device_id);

	delete from property where device_collection_id in (
		SELECT	dc.device_collection_id 
		  FROM	device_collection dc
				INNER JOIN device_collection_device dcd
		 			USING (device_collection_id)
		WHERE	dc.device_collection_type = 'per-device'
		  AND	dcd.device_id = in_Device_id
	);

	delete from device_collection_device where device_id = in_Device_id
		AND device_collection_id NOT IN (
			select device_collection_id
			FROM device_collection
			WHERE device_collection_type = 'per-device'
		);
	delete from snmp_commstr where device_id = in_Device_id;

		
	IF _d.rack_location_id IS NOT NULL  THEN
		UPDATE device SET rack_location_id = NULL 
		WHERE device_id = in_Device_id;

		-- This should not be permitted based on constraints, but in case
		-- that constraint had to be disabled...
		SELECT	count(*)
		  INTO	tally
		  FROM	device
		 WHERE	rack_location_id = _d.RACK_LOCATION_ID;

		IF tally = 0 THEN
			DELETE FROM rack_location 
			WHERE rack_location_id = _d.RACK_LOCATION_ID;
		END IF;
	END IF;

	IF _d.chassis_location_id IS NOT NULL THEN
		RAISE EXCEPTION 'Retiring modules is not supported yet.';
	END IF;

	SELECT	manager_device_id
	INTO	_mgrid
	 FROM	device_management_controller
	WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc'
	LIMIT 1;

	IF _mgrid IS NOT NULL THEN
		DELETE FROM device_management_controller
		WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc'
			AND manager_device_id = _mgrid;

		PERFORM device_utils.retire_device( manager_device_id)
		  FROM	device_management_controller
		WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc';
	END IF;

	BEGIN
		PERFORM local_hooks.device_retire_late(in_Device_Id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	SELECT count(*)
	INTO tally
	FROM device_note
	WHERE device_id = in_Device_id;

	--
	-- If there is no notes or serial number its save to remove
	-- 
	IF tally = 0 AND _d.ASSET_ID is NULL THEN
		_purgedev := true;
	END IF;

	IF _purgedev THEN
		--
		-- If there is an fk violation, we just preserve the record but
		-- delete all the identifying characteristics
		--
		BEGIN
			DELETE FROM device where device_id = in_Device_Id;
			return false;
		EXCEPTION WHEN foreign_key_violation THEN
			PERFORM 1;
		END;
	END IF;

	UPDATE device SET 
		device_name =NULL,
		service_environment_id = (
			select service_environment_id from service_environment
			where service_environment_name = 'unallocated'),
		device_status = 'removed',
		voe_symbolic_track_id = NULL,
		is_monitored = 'N',
		should_fetch_config = 'N',
		description = NULL
	WHERE device_id = in_Device_id;

	return true;
END;
$function$
;

--
-- Process drops in netblock_utils
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
-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'insert_pci_component');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.insert_pci_component ( pci_vendor_id integer, pci_device_id integer, pci_sub_vendor_id integer, pci_subsystem_id integer, pci_vendor_name text, pci_device_name text, pci_sub_vendor_name text, pci_sub_device_name text, component_function_list text[], slot_type text, serial_number text );
CREATE OR REPLACE FUNCTION component_utils.insert_pci_component(pci_vendor_id integer, pci_device_id integer, pci_sub_vendor_id integer DEFAULT NULL::integer, pci_subsystem_id integer DEFAULT NULL::integer, pci_vendor_name text DEFAULT NULL::text, pci_device_name text DEFAULT NULL::text, pci_sub_vendor_name text DEFAULT NULL::text, pci_sub_device_name text DEFAULT NULL::text, component_function_list text[] DEFAULT NULL::text[], slot_type text DEFAULT 'unknown'::text, serial_number text DEFAULT NULL::text)
 RETURNS component
 LANGUAGE plpgsql
 SET search_path TO jazzhands
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

--
-- Process drops in snapshot_manip
--
--
-- Process drops in lv_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('lv_manip', 'delete_lv_hier');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.delete_lv_hier ( INOUT physicalish_volume_list integer[], INOUT volume_group_list integer[], INOUT logical_volume_list integer[] );
CREATE OR REPLACE FUNCTION lv_manip.delete_lv_hier(INOUT physicalish_volume_list integer[] DEFAULT NULL::integer[], INOUT volume_group_list integer[] DEFAULT NULL::integer[], INOUT logical_volume_list integer[] DEFAULT NULL::integer[])
 RETURNS record
 LANGUAGE plpgsql
 SET search_path TO jazzhands
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
 SET search_path TO jazzhands
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

--
-- Process drops in approval_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('approval_utils', 'build_next_approval_item');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS approval_utils.build_next_approval_item ( approval_instance_item_id integer, approval_process_chain_id integer, approval_instance_id integer, approved character, approving_account_id integer, new_value text );
CREATE OR REPLACE FUNCTION approval_utils.build_next_approval_item(approval_instance_item_id integer, approval_process_chain_id integer, approval_instance_id integer, approved character, approving_account_id integer, new_value text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO approval_utils, jazzhands
AS $function$
DECLARE
	_r		RECORD;
	_apc	approval_process_chain%ROWTYPE;	
	_new	approval_instance_item%ROWTYPE;	
	_acid	account.account_id%TYPE;
	_step	approval_instance_step.approval_instance_step_id%TYPE;
	_l		approval_instance_link.approval_instance_link_id%TYPE;
	apptype	text;
	_v			approval_utils.v_account_collection_approval_process%ROWTYPE;
BEGIN
	EXECUTE '
		SELECT apc.*
		FROM approval_process_chain apc
		WHERE approval_process_chain_id=$1
	' INTO _apc USING approval_process_chain_id;

	IF _apc.approval_process_chain_id is NULL THEN
		RAISE EXCEPTION 'Unable to follow this chain: %',
			approval_process_chain_id;
	END IF;

	EXECUTE '
		SELECT aii.*, ais.approver_account_id
		FROM approval_instance_item  aii
			INNER JOIN approval_instance_step ais
				USING (approval_instance_step_id)
		WHERE approval_instance_item_id=$1
	' INTO _r USING approval_instance_item_id;

	IF _apc.approving_entity = 'manager' THEN
		apptype := 'account';
		_acid := NULL;
		EXECUTE '
			SELECT manager_account_id
			FROM	v_account_manager_map
			WHERE	account_id = $1
		' INTO _acid USING approving_account_id;
		--
		-- return NULL because there is no manager for the person
		--
		IF _acid IS NULL THEN
			RETURN NULL;
		END IF;
	ELSIF _apc.approving_entity = 'jira-hr' THEN
		apptype := 'jira-hr';
		_acid :=  _r.approver_account_id;
	ELSIF _apc.approving_entity = 'rt-hr' THEN
		apptype := 'rt-hr';
		_acid :=  _r.approver_account_id;
	ELSIF _apc.approving_entity = 'kace-hr' THEN
		apptype := 'kace-hr';
		_acid :=  _r.approver_account_id;
	ELSIF _apc.approving_entity = 'recertify' THEN
		apptype := 'account';
		EXECUTE '
			SELECT approver_account_id
			FROM approval_instance_item  aii
				INNER JOIN approval_instance_step ais
					USING (approval_instance_step_id)
			WHERE approval_instance_item_id IN (
				SELECT	approval_instance_item_id
				FROM	approval_instance_item
				WHERE	next_approval_instance_item_id = $1
			)
		' INTO _acid USING approval_instance_item_id;
	ELSE
		RAISE EXCEPTION 'Can not handle approving entity %',
			_apc.approving_entity;
	END IF;

	IF _acid IS NULL THEN
		RAISE EXCEPTION 'This whould not happen:  Unable to discern approving account.';
	END IF;

	EXECUTE '
		SELECT	approval_instance_step_id
		FROM	approval_instance_step
		WHERE	approval_process_chain_id = $1
		AND		approval_instance_id = $2
		AND		approver_account_id = $3
		AND		is_completed = ''N''
	' INTO _step USING approval_process_chain_id,
		approval_instance_id, _acid;

	--
	-- _new gets built out for all the fields that should get inserted,
	-- and then at the end is stomped on by what actually gets inserted.
	--

	IF _step IS NULL THEN
		EXECUTE '
			INSERT INTO approval_instance_step (
				approval_instance_id, approval_process_chain_id,
				approval_instance_step_name,
				approver_account_id, approval_type, 
				approval_instance_step_due,
				description
			) VALUES (
				$1, $2, $3, $4, $5, approval_utils.calculate_due_date($6), $7
			) RETURNING approval_instance_step_id
		' INTO _step USING 
			approval_instance_id, approval_process_chain_id,
			_apc.approval_process_chain_name,
			_acid, apptype, 
			_apc.approval_chain_response_period::interval,
			concat(_apc.description, ' for ', _r.approver_account_id, ' by ',
			approving_account_id);
	END IF;

	IF _apc.refresh_all_data = 'Y' THEN
		-- this is called twice, should rethink how to not
		_v := approval_utils.refresh_approval_instance_item(approval_instance_item_id);
		_l := approval_utils.get_or_create_correct_approval_instance_link(
			approval_instance_item_id,
			_r.approval_instance_link_id
		);
		_new.approval_instance_link_id := _l;
		_new.approved_label := _v.approval_label;
		_new.approved_category := _v.approval_category;
		_new.approved_lhs := _v.approval_lhs;
		_new.approved_rhs := _v.approval_rhs;
	ELSE
		_new.approval_instance_link_id := _r.approval_instance_link_id;
		_new.approved_label := _r.approved_label;
		_new.approved_category := _r.approved_category;
		_new.approved_lhs := _r.approved_lhs;
		IF new_value IS NULL THEN
			_new.approved_rhs := _r.approved_rhs;
		ELSE
			_new.approved_rhs := new_value;
		END IF;
	END IF;

	-- RAISE NOTICE 'step is %', _step;
	-- RAISE NOTICE 'acid is %', _acid;

	EXECUTE '
		INSERT INTO approval_instance_item
			(approval_instance_link_id, approved_label, approved_category,
				approved_lhs, approved_rhs, approval_instance_step_id
			) SELECT $2, $3, $4,
				$5, $6, $7
			FROM approval_instance_item
			WHERE approval_instance_item_id = $1
			RETURNING *
	' INTO _new USING approval_instance_item_id, 
		_new.approval_instance_link_id, _new.approved_label, _new.approved_category,
		_new.approved_lhs, _new.approved_rhs,
		_step;

	-- RAISE NOTICE 'returning %', _new.approval_instance_item_id;
	RETURN _new.approval_instance_item_id;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('approval_utils', 'refresh_approval_instance_item');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS approval_utils.refresh_approval_instance_item ( approval_instance_item_id integer );
CREATE OR REPLACE FUNCTION approval_utils.refresh_approval_instance_item(approval_instance_item_id integer)
 RETURNS approval_utils.v_account_collection_approval_process
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO approval_utils, jazzhands
AS $function$
DECLARE
	_i	approval_instance_item.approval_instance_item_id%TYPE;
	_r	approval_utils.v_account_collection_approval_process%ROWTYPE;
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
			RETURN _r;
		END;
		$function$
;

--
-- Process drops in account_collection_manip
--
--
-- Process drops in script_hooks
--
--
-- Process drops in backend_utils
--
-- Dropping obsoleted sequences....


-- Dropping obsoleted audit sequences....


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
-- index
DROP INDEX "jazzhands"."idx_acctcol_acctcoltype";
DROP INDEX IF EXISTS "jazzhands"."xif_acctcol_acctcoltype";
CREATE INDEX xif_acctcol_acctcoltype ON account_collection USING btree (account_collection_type);
DROP INDEX IF EXISTS "jazzhands"."xi_volume_group_name";
CREATE INDEX xi_volume_group_name ON volume_group USING btree (volume_group_name);
-- triggers
DROP TRIGGER IF EXISTS aaa_trigger_asset_component_id_fix ON asset;
CREATE TRIGGER aaa_trigger_asset_component_id_fix AFTER INSERT OR UPDATE OF component_id, asset_id ON asset FOR EACH ROW EXECUTE PROCEDURE asset_component_id_fix();
DROP TRIGGER IF EXISTS aaa_trigger_device_asset_id_fix ON device;
CREATE TRIGGER aaa_trigger_device_asset_id_fix BEFORE INSERT OR UPDATE OF asset_id, component_id ON device FOR EACH ROW EXECUTE PROCEDURE device_asset_id_fix();
DROP TRIGGER IF EXISTS trigger_check_ip_universe_netblock ON netblock;
CREATE CONSTRAINT TRIGGER trigger_check_ip_universe_netblock AFTER UPDATE OF netblock_id, ip_universe_id ON netblock DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE check_ip_universe_netblock();
DROP TRIGGER IF EXISTS trigger_acct_coll_insert_direct ON val_account_collection_type;
CREATE TRIGGER trigger_acct_coll_insert_direct AFTER INSERT ON val_account_collection_type FOR EACH ROW EXECUTE PROCEDURE acct_coll_insert_direct();
DROP TRIGGER IF EXISTS trigger_acct_coll_remove_direct ON val_account_collection_type;
CREATE TRIGGER trigger_acct_coll_remove_direct BEFORE DELETE ON val_account_collection_type FOR EACH ROW EXECUTE PROCEDURE acct_coll_remove_direct();
DROP TRIGGER IF EXISTS trigger_acct_coll_update_direct_before ON val_account_collection_type;
CREATE TRIGGER trigger_acct_coll_update_direct_before AFTER UPDATE OF account_collection_type ON val_account_collection_type FOR EACH ROW EXECUTE PROCEDURE acct_coll_update_direct_before();


-- BEGIN Misc that does not apply to above
-- no longer needed due to rebuilding dns_record
--CREATE INDEX aud_dns_record_ak_dns_record_dnsrec_domainid 
--	ON audit.dns_record 
--	USING btree (dns_record_id, dns_domain_id);

CREATE UNIQUE INDEX mv_dev_col_root_leaf_id_idx 
	ON mv_dev_col_root USING btree (leaf_id);
CREATE INDEX mv_dev_col_root_leaf_type_idx 
	ON mv_dev_col_root USING btree (leaf_type);
CREATE INDEX mv_dev_col_root_root_id_idx 
	ON mv_dev_col_root USING btree (root_id);
CREATE INDEX mv_dev_col_root_root_type_idx 
	ON mv_dev_col_root USING btree (root_type);


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
select timeofday(), now();
